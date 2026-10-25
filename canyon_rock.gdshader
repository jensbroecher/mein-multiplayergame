shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Sandstone for the Canyon Course's rock meshes (regenerate_canyon.gd): the walls of La Garganta,
// El Arco del Viento and the hoodoos. Their beds come from canyon_strata.gdshaderinc, the same as
// the ground's cliffs, so a bed runs on from the ground into a wall at the same height. Sand lies on
// whatever faces up; varnish streaks the faces; COLOR.r darkens a mesh where it is shaded inside
// (the slot's floor-facing overhangs, the arch's soffit).

uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 sand_tint : source_color = vec4(0.86, 0.60, 0.44, 1.0);
uniform float grain_scale = 0.11;

varying vec3 w_pos;
varying vec3 w_nrm;
varying float occlusion;

#include "res://canyon_strata.gdshaderinc"

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	occlusion = COLOR.r;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(60.0, 500.0, cam_dist);
	float steep = 1.0 - smoothstep(0.55, 0.85, abs(n.y));
	float fw = length(fwidth(w_pos));
	vec3 rock = strata_color(w_pos, fw);
	float grain = strata_grain(w_pos, n, grain_scale);
	rock *= mix(1.0, clamp(grain, 0.45, 1.5), 0.75 * detail + 0.3);
	rock *= 1.0 - 0.45 * strata_varnish(w_pos, steep, fw);
	// Sand on whatever faces up.
	float up = smoothstep(0.7, 0.92, n.y) * smoothstep(0.35, 0.65, cs_fbm(w_pos.xz * 0.12));
	vec3 sand = texture(sand_tex, w_pos.xz * 0.19).rgb;
	sand = sand_tint.rgb * (0.7 + dot(sand, vec3(0.3, 0.59, 0.11)) * 0.8);
	rock = mix(rock, sand, up * 0.8);
	ALBEDO = rock * (1.0 - 0.55 * occlusion);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	// The grain's normal map, triplanar.
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 nx = texture(rock_normal, w_pos.zy * grain_scale).rgb;
	vec3 ny = texture(rock_normal, w_pos.xz * grain_scale).rgb;
	vec3 nz = texture(rock_normal, w_pos.xy * grain_scale).rgb;
	NORMAL_MAP = nx * w.x + ny * w.y + nz * w.z;
	NORMAL_MAP_DEPTH = 0.9 * detail;
}
