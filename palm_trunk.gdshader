shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Coconut palm trunks on Bloombay Dunes (regenerate_bloombay_dunes.gd, _palm_mesh): smooth grey bark
// banded by the rings old fronds leave when they fall, over fine fibres running up the trunk, and a
// brown fibrous boot just under the crown. From the tube:
//   UV.x  - around the trunk, 0..1
//   UV.y  - metres up the trunk from the ground
//   COLOR - rgb a tint per tree, a the boot (0 bark, 1 the fibre wrapped round the crown's base)

#include "res://tree_lod.gdshaderinc"

uniform vec4 bark_color : source_color = vec4(0.50, 0.46, 0.40, 1.0);
uniform vec4 ring_color : source_color = vec4(0.30, 0.27, 0.23, 1.0);
uniform vec4 boot_color : source_color = vec4(0.36, 0.26, 0.16, 1.0);
// Metres between rings.
uniform float ring_spacing = 0.15;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

varying float cam_dist;
varying vec3 w_pos;

float p_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise that repeats every `period` cells in x (round the trunk).
float p_noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(mix(p_hash(vec2(x0, i.y)), p_hash(vec2(x1, i.y)), f.x),
			mix(p_hash(vec2(x0, i.y + 1.0)), p_hash(vec2(x1, i.y + 1.0)), f.x), f.y);
}

vec3 p_bump(vec3 n_view, vec3 pos_view, float h, float strength) {
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
	float s = UV.y;
	// Rings: not quite level and not quite evenly spaced, each a thin dark groove with a lip.
	float tilt = (p_noise(vec2(UV.x * 3.0, floor(s / ring_spacing) * 1.7), 3.0) - 0.5) * 0.35;
	float phase = s / ring_spacing + tilt + p_noise(vec2(0.0, s * 1.3), 1.0) * 0.6;
	float d = abs(fract(phase) - 0.5) * 2.0;
	float groove = smoothstep(0.78, 0.97, d);
	// Fibres up the trunk, and weathered patches.
	float fib = p_noise(vec2(UV.x * 90.0, s * 2.2), 90.0);
	float patch = p_noise(vec2(UV.x * 6.0, s * 0.45), 6.0);
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(15.0, 90.0, dist);
	vec3 col = bark_color.rgb * (0.86 + fib * 0.22 * detail + patch * 0.16);
	col = mix(col, ring_color.rgb, groove * mix(0.55, 0.85, detail));
	// The boot: coarse brown fibre and the stubs of old frond bases.
	float boot = COLOR.a;
	float shag = p_noise(vec2(UV.x * 40.0, s * 9.0), 40.0);
	vec3 boot_col = boot_color.rgb * (0.7 + shag * 0.6);
	col = mix(col, boot_col, boot);
	ALBEDO = col * COLOR.rgb;
	float h = (1.0 - groove) * 0.8 + fib * 0.2 * detail + boot * shag * 0.6;
	NORMAL = p_bump(NORMAL, VERTEX, h, mix(0.015, 0.05, boot) * detail);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
}
