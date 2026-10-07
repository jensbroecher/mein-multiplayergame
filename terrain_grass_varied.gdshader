// Grass terrain without visible tiling.
//
// A single grass texture tiled every few metres shows as a grid across a whole hillside. This hides it
// three ways, all in world space so it needs no UVs:
// - the grass is sampled at two scales, the second rotated, and the two are blended by a soft noise
//   mask, so no tile repeats the same way twice;
// - large, slow noise tints the meadow into lighter, darker and drier patches;
// - steep ground turns to dirt, the way grass gives out on a bank.
// Steep faces use triplanar projection so the texture does not smear down cliffs.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms grass;
uniform vec3 grass_tint : source_color = vec3(0.82, 0.92, 0.74);
// 0 = grey, 1 = the texture's own (quite neon) saturation.
uniform float grass_saturation : hint_range(0.0, 1.5) = 0.72;
// Metres per grass tile (near scale); the far scale is 2.7x larger and rotated.
uniform float grass_tile = 8.0;
uniform float grass_roughness = 0.92;

group_uniforms variation;
// Colour of the drier, yellower patches and of the lush, darker ones.
uniform vec3 dry_tint : source_color = vec3(1.08, 1.0, 0.72);
uniform vec3 lush_tint : source_color = vec3(0.72, 0.88, 0.70);
uniform float patch_size = 55.0;
uniform float patch_strength : hint_range(0.0, 1.0) = 0.8;
// Beyond this distance the small grass tile fades out and only the large, rotated layer is used,
// so the 8m repeat cannot line up into a grid across a distant hillside.
uniform float near_tile_fade_start = 30.0;
uniform float near_tile_fade_end = 90.0;
// Brightness wobble at a smaller scale than the patches.
uniform float mottle_strength : hint_range(0.0, 0.5) = 0.18;

group_uniforms slopes;
uniform vec3 dirt_tint : source_color = vec3(0.92, 0.86, 0.78);
uniform float dirt_tile = 6.0;
// Slope (1 - normal.y) where dirt starts and where it has fully taken over.
uniform float dirt_start = 0.22;
uniform float dirt_full = 0.42;
uniform float dirt_roughness = 0.95;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm3(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.15;
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// Triplanar sample: top projection from xz, side projections from zy / xy.
vec4 triplanar(sampler2D tex, vec3 p, vec3 w, float tile) {
	vec4 x = texture(tex, p.zy / tile);
	vec4 y = texture(tex, p.xz / tile);
	vec4 z = texture(tex, p.xy / tile);
	return x * w.x + y * w.y + z * w.z;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// The face normal, not the interpolated vertex normal: on this coarse terrain mesh a steep bank's
	// vertex normals swing between flat and steep from one vertex to the next, so slope tests and
	// projection weights based on them came out as a zigzag of grass and dirt triangles up the wall.
	vec3 n = normalize(cross(dFdy(world_pos), dFdx(world_pos)));
	if (dot(n, world_normal) < 0.0) {
		n = -n;
	}
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);

	// Two grass layers: the near scale as-is, the far scale rotated 37 degrees and offset, mixed by
	// noise so the seams of either layer never line up into a grid.
	vec3 p2 = vec3(world_pos.x, world_pos.y, world_pos.z);
	vec2 r = rot(0.65) * world_pos.xz;
	p2.x = r.x + 17.3;
	p2.z = r.y - 41.9;
	vec3 g1 = triplanar(grass_tex, world_pos, w, grass_tile).rgb;
	vec3 g2 = triplanar(grass_tex, p2, w, grass_tile * 2.7).rgb;
	float layer_mix = smoothstep(0.3, 0.7, fbm3(world_pos.xz / 23.0));
	float cam_dist = length(world_pos - CAMERA_POSITION_WORLD);
	layer_mix = max(layer_mix, smoothstep(near_tile_fade_start, near_tile_fade_end, cam_dist));
	vec3 grass = mix(g1, g2, layer_mix);
	float lum = dot(grass, vec3(0.299, 0.587, 0.114));
	grass = mix(vec3(lum), grass, grass_saturation) * grass_tint;

	// Meadow patches and mottling.
	float patches = fbm3(world_pos.xz / patch_size + 5.0);
	vec3 patch_tint = mix(lush_tint, dry_tint, smoothstep(0.25, 0.75, patches));
	grass *= mix(vec3(1.0), patch_tint, patch_strength);
	grass *= 1.0 + (fbm3(world_pos.xz / 9.0 + 31.0) - 0.5) * 2.0 * mottle_strength;

	// Dirt on steep ground, with a noisy edge so the boundary is not a contour line.
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	float edge_noise = (fbm3(world_pos.xz / 4.0 + 71.0) - 0.5) * 0.12;
	float dirt_amt = smoothstep(dirt_start, dirt_full, slope + edge_noise);
	// Gated by the smooth vertex-normal slope as well: a lone steep triangle in a seam of the terrain
	// grid is steep as a face but not as a surface, and on its own it drew hard sawtooth strips of
	// dirt across the meadow. Real banks are steep by both measures.
	float vslope = 1.0 - clamp(normalize(world_normal).y, 0.0, 1.0);
	dirt_amt *= smoothstep(dirt_start * 0.5, dirt_full, vslope + edge_noise);
	vec3 dirt = triplanar(dirt_tex, world_pos, w, dirt_tile).rgb * dirt_tint;

	ALBEDO = mix(grass, dirt, dirt_amt);
	ROUGHNESS = mix(grass_roughness, dirt_roughness, dirt_amt);

	// The dirt normal map only where there is dirt; the grass texture has no normal map.
	vec3 dn = triplanar(dirt_normal, world_pos, w, dirt_tile).rgb;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), dn, dirt_amt);
	NORMAL_MAP_DEPTH = 1.0;
}
