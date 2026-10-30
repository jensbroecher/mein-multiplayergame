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
// Bare rock on the steepest faces (the cut banks between switchbacks), off without rock_tex.
uniform sampler2D rock_tex : source_color, hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 rock_tint : source_color = vec3(1.55, 1.45, 1.32);
uniform float rock_tile = 9.0;
uniform float rock_start = 0.5;
uniform float rock_full = 0.68;
uniform float rock_amount = 0.0;

// Pinecrest Ridge's painted ground (regenerate_pinecrest_ridge.gd, _build_ground_map), all off until
// the maps are set. ground_map over ground_rect (x0, z0, width, depth): R the forest trail's bed, G
// across it (0.5 + lateral / 16: the ruts are drawn from it), B Ridgecrest's lanes, A its lawns.
// woods_map over woods_rect: R the forest floor under the trees (needles, moss, little grass).
group_uniforms painted;
uniform sampler2D ground_map : hint_default_black, filter_linear, repeat_disable;
uniform vec4 ground_rect = vec4(0.0);
uniform sampler2D woods_map : hint_default_black, filter_linear, repeat_disable;
uniform vec4 woods_rect = vec4(0.0);
uniform sampler2D lane_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 trail_tint : source_color = vec3(0.80, 0.70, 0.58);
uniform vec3 litter_tint : source_color = vec3(0.62, 0.46, 0.32);
uniform vec3 moss_tint : source_color = vec3(0.42, 0.52, 0.26);
uniform vec3 lane_tint : source_color = vec3(0.78, 0.76, 0.73);
uniform vec3 lawn_tint : source_color = vec3(0.86, 1.05, 0.78);
// The lake's edge: a dark wet band up to wet_height over the water and silt under it (off at -1000).
uniform float water_level = -1000.0;
uniform float wet_height = 0.7;
uniform vec3 silt_tint : source_color = vec3(0.55, 0.48, 0.36);

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

	vec3 col = mix(grass, dirt, dirt_amt);
	float rough = mix(grass_roughness, dirt_roughness, dirt_amt);
	// How much of the dirt normal map shows.
	float bump = dirt_amt;
	if (rock_amount > 0.0) {
		// The steepest of the dirt: weathered rock, its strata level (the side projections), with
		// grass clinging on along ledges where the face eases.
		float rock = smoothstep(rock_start, rock_full, slope + edge_noise * 1.6) * dirt_amt * rock_amount;
		vec3 stone = triplanar(rock_tex, world_pos * vec3(1.0, 1.6, 1.0), w, rock_tile).rgb * rock_tint;
		stone *= 0.85 + 0.3 * fbm3(world_pos.xz / 6.0 + world_pos.y * 0.1);
		col = mix(col, stone, rock);
		rough = mix(rough, 0.82, rock);
		bump *= 1.0 - rock * 0.5;
	}

	// The forest floor: needles and cones, with moss in the damper hollows and a little grass.
	if (woods_rect.z > 0.0) {
		vec2 wuv = (world_pos.xz - woods_rect.xy) / woods_rect.zw;
		float inside = step(0.0, wuv.x) * step(0.0, wuv.y) * step(wuv.x, 1.0) * step(wuv.y, 1.0);
		float woods = texture(woods_map, wuv).r * inside;
		woods = smoothstep(0.15, 0.85, woods + (fbm3(world_pos.xz / 3.1 + 17.0) - 0.5) * 0.5);
		if (woods > 0.0) {
			vec3 litter = triplanar(dirt_tex, p2, w, dirt_tile * 0.7).rgb * litter_tint;
			litter *= 0.8 + 0.35 * vnoise(world_pos.xz * 5.0);
			float moss = smoothstep(0.5, 0.75, fbm3(world_pos.xz / 5.0 + 3.0));
			litter = mix(litter, grass * moss_tint * 1.3, moss * 0.6);
			float keep = smoothstep(0.55, 0.8, fbm3(world_pos.xz / 2.3 + 40.0)) * 0.5;
			col = mix(col, litter, woods * (1.0 - keep) * (1.0 - dirt_amt * 0.5));
			rough = mix(rough, 0.97, woods);
			bump = max(bump, woods * 0.6);
		}
	}

	if (ground_rect.z > 0.0) {
		vec2 guv = (world_pos.xz - ground_rect.xy) / ground_rect.zw;
		if (guv.x >= 0.0 && guv.y >= 0.0 && guv.x <= 1.0 && guv.y <= 1.0) {
			vec4 gm = texture(ground_map, guv);
			// The trail: packed dirt and grit, worn into ruts along two lines each side of the middle,
			// grass holding on along its crowns, its edge ragged into the meadow.
			float trail = smoothstep(0.3, 0.7, gm.r + (fbm3(world_pos.xz / 1.9 + 13.0) - 0.5) * 0.55);
			if (trail > 0.0) {
				float lat = (gm.g - 0.5) * 16.0 + (vnoise(world_pos.xz * 0.35) - 0.5) * 0.8;
				float ruts = 0.0;
				for (int k = 0; k < 4; k++) {
					float at = (k < 2) ? 1.9 : 5.2;
					float side = (k % 2 == 0) ? -1.0 : 1.0;
					ruts = max(ruts, 1.0 - smoothstep(0.3, 0.95, abs(lat - side * at)));
				}
				vec3 bed = triplanar(dirt_tex, world_pos, w, dirt_tile).rgb * trail_tint;
				bed *= 0.86 + 0.26 * vnoise(world_pos.xz * 7.0);
				// Loose grit between the ruts, lighter; the ruts packed and darker.
				bed = mix(bed * 1.1, bed * 0.74, ruts);
				float crown = (1.0 - ruts) * smoothstep(0.55, 0.72, fbm3(world_pos.xz / 1.3 + 61.0));
				crown *= mix(0.55, 1.0, smoothstep(6.0, 7.5, abs(lat)));
				bed = mix(bed, grass * 0.8, crown * 0.75);
				col = mix(col, bed, trail);
				rough = mix(rough, mix(0.97, 0.88, ruts), trail);
				bump = max(bump, trail * (1.0 - crown));
			}
			// Ridgecrest's lanes: fine pale asphalt with a darker line down each edge.
			float lane = smoothstep(0.42, 0.58, gm.b);
			if (lane > 0.0) {
				vec3 tar = texture(lane_tex, world_pos.xz / 4.0).rgb * lane_tint;
				tar *= 1.0 - 0.25 * (1.0 - smoothstep(0.5, 0.75, gm.b));
				col = mix(col, tar, lane);
				rough = mix(rough, 0.8, lane);
				bump *= 1.0 - lane;
			}
			// The gardens' lawns: lusher, even, mown in stripes.
			float lawn = smoothstep(0.35, 0.65, gm.a) * (1.0 - lane);
			if (lawn > 0.0) {
				vec3 turf = mix(g1, g2, 0.5);
				turf = mix(vec3(dot(turf, vec3(0.299, 0.587, 0.114))), turf, grass_saturation * 1.1) * grass_tint * lawn_tint;
				turf *= 1.0 + 0.07 * sign(sin(world_pos.x * 1.9 + world_pos.z * 0.6));
				col = mix(col, turf, lawn * (1.0 - dirt_amt));
				rough = mix(rough, 0.86, lawn);
			}
		}
	}

	// The lake's edge: wet and dark just over the water, silt under it.
	if (world_pos.y < water_level + wet_height) {
		float wet = 1.0 - smoothstep(water_level, water_level + wet_height, world_pos.y + (vnoise(world_pos.xz * 0.8) - 0.5) * 0.25);
		vec3 silt = triplanar(dirt_tex, world_pos, w, dirt_tile).rgb * silt_tint;
		col = mix(col, silt * 0.7, wet * 0.75);
		col *= 1.0 - 0.3 * wet;
		rough = mix(rough, 0.35, wet * step(water_level - 0.05, world_pos.y));
		col = mix(col, silt * 0.55, smoothstep(water_level, water_level - 0.8, world_pos.y));
		bump = max(bump, wet * 0.5);
	}

	// The country past Pinecrest Ridge's rim shades its near hills as the terrain and hands over to its
	// vertex colour (sRGB) further out: its alpha says how much stays the terrain's (the terrain itself
	// has no vertex colours, so its alpha reads 1).
	float far_w = 1.0 - COLOR.a;
	col = mix(col, pow(COLOR.rgb, vec3(2.2)), far_w);
	rough = mix(rough, 0.95, far_w);
	bump *= 1.0 - far_w;

	ALBEDO = col;
	ROUGHNESS = rough;

	// The dirt normal map only where there is dirt; the grass texture has no normal map.
	vec3 dn = triplanar(dirt_normal, world_pos, w, dirt_tile).rgb;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), dn, bump);
	NORMAL_MAP_DEPTH = 1.0;
}
