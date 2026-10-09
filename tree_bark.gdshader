shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Bark for Mara Crossing's trees: plates split by fissures that run along the branch, done in the
// shader from the tube's UVs (regenerate_mara_crossing.gd, _bark_tube):
//   UV.x  - around the branch, in bark cells; it wraps after UV2.x cells, so the noise is made
//           periodic there and the seam doesn't show
//   UV.y  - along the branch, in the same cells
//   COLOR - rgb a tint per branch (young twigs redder), a the shade inside the canopy
// The acacias' umbrella thorn bark is dark grey and deeply fissured; the baobab's is smooth and
// pale, with shallow folds (same shader, other uniforms).

#include "res://tree_lod.gdshaderinc"

uniform vec4 bark_color : source_color = vec4(0.36, 0.32, 0.29, 1.0);
uniform vec4 fissure_color : source_color = vec4(0.13, 0.11, 0.10, 1.0);
// How much of the bark is fissure, and how deep the fissures look (metres).
uniform float fissure_width : hint_range(0.0, 1.0) = 0.45;
uniform float fissure_depth = 0.05;
// Plates are this many times longer along the branch than across it.
uniform float plate_stretch = 3.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;

varying float cam_dist;
varying vec3 w_pos;

float b_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise that repeats every `period` cells in x.
float b_noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	float a = b_hash(vec2(x0, i.y));
	float b = b_hash(vec2(x1, i.y));
	float c = b_hash(vec2(x0, i.y + 1.0));
	float d = b_hash(vec2(x1, i.y + 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 b_bump(vec3 n_view, vec3 pos_view, float h, float strength) {
	vec3 dpdx = dFdx(pos_view);
	vec3 dpdy = dFdy(pos_view);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n_view);
	vec3 r2 = cross(n_view, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n_view - strength * grad);
}

void vertex() {
	cam_dist = lod_distance(MODEL_MATRIX[3].xyz, CAMERA_POSITION_WORLD);
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (lod_hidden(cam_dist, FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	float period = max(UV2.x, 1.0);
	vec2 uv = vec2(UV.x, UV.y / plate_stretch);
	// Plates: cells of noise; fissures where it is low, wandering along the branch.
	float n1 = b_noise(uv * vec2(1.0, 1.0), period);
	float n2 = b_noise(uv * vec2(2.0, 2.0) + vec2(0.0, 3.7), period * 2.0);
	float n3 = b_noise(uv * vec2(4.0, 6.0) + vec2(0.0, 9.1), period * 4.0);
	float plate = n1 * 0.6 + n2 * 0.3 + n3 * 0.1;
	float h = smoothstep(fissure_width - 0.15, fissure_width + 0.15, plate);
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(20.0, 120.0, dist);
	vec3 col = mix(fissure_color.rgb, bark_color.rgb * (0.8 + n3 * 0.4), h);
	// Pale weathered edges on the plates, and the odd lichen patch.
	col = mix(col, col * 1.25, smoothstep(0.75, 0.95, n2) * h * 0.6);
	col *= COLOR.rgb * 1.25;
	ALBEDO = col * mix(0.45, 1.0, COLOR.a);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
	AO = mix(0.5, 1.0, COLOR.a);
	AO_LIGHT_AFFECT = 0.3;
	NORMAL = b_bump(NORMAL, VERTEX, h * fissure_depth, mix(0.3, 1.0, detail));
}
