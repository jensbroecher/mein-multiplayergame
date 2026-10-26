shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://camera_xray.gdshaderinc"

// The needle fronds of Frostfall Gorge's spruces (spruce.gdshader draws their trunks). Each frond is a
// curved, folded card (regenerate_frostfall_gorge.gd, _spruce_frond) textured with a drawn spray of
// shoots and needles from the shared atlas, alpha-tested, so a crown has a ragged outline and
// light between the branches. The generator bakes into the vertex colour:
//   rgb - the frond's tint, already darker toward the trunk and the shaded underside
//   a   - how much snow the frond can hold: high on the upper side of a branch, 0 underneath
// NORMAL is the crown's (rounded outward from the trunk), so a crown still shades as one mass.
// Snow lies in clumps on top of the needles, thickest along each shoot's spine, and the needles
// show through where it is thin.

#include "res://tree_lod.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float needle_boost : hint_range(0.5, 4.0) = 1.7;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform vec4 snow_color : source_color = vec4(0.86, 0.90, 0.97, 1.0);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.9;
uniform float sway : hint_range(0.0, 0.3) = 0.06;
uniform float sway_height = 11.0;

varying vec3 local_pos;
varying vec3 w_nrm;
varying float tree_seed;
varying float cam_dist;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local_pos = VERTEX;
	vec3 origin = MODEL_MATRIX[3].xyz;
	tree_seed = lod_seed(origin);
	cam_dist = lod_distance(origin, CAMERA_POSITION_WORLD);
	// Tips move, the trunk does not: sway grows with height and with distance from the trunk.
	float bend = pow(max(VERTEX.y, 0.0) / sway_height, 2.0) + length(VERTEX.xz) * 0.04;
	float phase = TIME * (0.9 + tree_seed * 0.4) + tree_seed * 6.28;
	VERTEX.xz += vec2(sin(phase), cos(phase * 0.83)) * sway * bend;
	// Fronds also bob a little on their own.
	VERTEX.y += sin(TIME * 1.7 + local_pos.x * 1.3 + local_pos.z * 1.1 + tree_seed * 9.0) * 0.025 * length(VERTEX.xz) * 0.3;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (xray_hidden(VERTEX, VIEW_MATRIX, CAMERA_POSITION_WORLD, PROJECTION_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	if (lod_hidden(cam_dist, FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	vec4 tex = texture(leaf_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;

	// Per-tree tint: some trees bluer, some more olive, some darker.
	vec3 tint = COLOR.rgb * mix(vec3(0.86, 0.96, 1.04), vec3(1.10, 1.04, 0.86), tree_seed) * (0.85 + tree_seed * 0.3);
	float clumps = vnoise3(local_pos * 1.7 + tree_seed * 13.0);
	vec3 needles = tex.rgb * needle_boost * tint * (0.85 + clumps * 0.30);

	// Snow: on the upper side of a branch, in clumps. The atlas cell is u 0.5..1, v 0.5..1; the
	// shoots' spine runs up its middle, where the snow settles first.
	float up = smoothstep(0.30, 0.85, normalize(w_nrm).y + 0.25);
	float spine = 1.0 - smoothstep(0.05, 0.55, abs(fract(UV.x * 2.0) - 0.5) * 2.0);
	float clump_snow = vnoise3(local_pos * vec3(2.6, 3.4, 2.6) + 3.1);
	float fine = vnoise3(vec3(UV * 64.0, tree_seed * 7.0));
	float cover = clump_snow * 0.50 + spine * 0.20 + fine * 0.15 + up * 0.55;
	float snow = COLOR.a * smoothstep(0.62 - snow_amount * 0.45, 0.88 - snow_amount * 0.30, cover);
	// A few small gaps, from noise, so the snow is not a uniform coat. (Not from the texture: its needle
	// strokes showed through as dark lines on the upper side of every branch.)
	snow *= 1.0 - smoothstep(0.62, 0.92, fine) * 0.55;
	snow = clamp(snow, 0.0, 1.0);

	// Under the snow the needle spray only shows as the faintest relief.
	vec3 snow_col = snow_color.rgb * (0.90 + fine * 0.10) * mix(0.90, 1.0, smoothstep(0.1, 0.5, tex.r));
	ALBEDO = mix(needles, snow_col, snow);
	ROUGHNESS = mix(0.88, 0.72, snow);
	SPECULAR = mix(0.18, 0.32, snow);
	BACKLIGHT = vec3(0.10, 0.16, 0.08) * (1.0 - snow);
	// The crown's normal on both faces of a card.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
