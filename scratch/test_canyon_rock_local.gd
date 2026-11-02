extends SceneTree

func _init() -> void:
	var code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 sand_tint : source_color = vec4(0.86, 0.60, 0.44, 1.0);
uniform float grain_scale = 0.11;
uniform bool vertex_occlusion = true;
uniform float tint_amount = 0.0;
uniform vec4 tint : source_color = vec4(0.72, 0.70, 0.66, 1.0);
uniform float moss = 0.0;
uniform vec4 moss_tint : source_color = vec4(0.30, 0.42, 0.12, 1.0);
uniform bool local_coords = false;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec3 obj_pos;
varying vec3 obj_nrm;
varying float occlusion;

#include "res://canyon_strata.gdshaderinc"

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	occlusion = vertex_occlusion ? COLOR.r : 0.0;
}

void fragment() {
	vec3 pos = local_coords ? obj_pos : w_pos;
	vec3 n = normalize(local_coords ? obj_nrm : w_nrm);
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(60.0, 500.0, cam_dist);
	float steep = 1.0 - smoothstep(0.55, 0.85, abs(n.y));
	float fw = length(fwidth(pos));
	vec3 rock = strata_color(pos, fw);
	float grain = strata_grain(pos, n, grain_scale);
	rock *= mix(1.0, clamp(grain, 0.45, 1.5), 0.75 * detail + 0.3);
	rock *= 1.0 - 0.45 * strata_varnish(pos, steep, fw);
	// Sand on whatever faces up.
	float up = smoothstep(0.7, 0.92, n.y) * smoothstep(0.35, 0.65, cs_fbm(pos.xz * 0.12));
	vec3 sand = texture(sand_tex, pos.xz * 0.19).rgb;
	sand = sand_tint.rgb * (0.7 + dot(sand, vec3(0.3, 0.59, 0.11)) * 0.8);
	rock = mix(rock, sand, up * 0.8);
	if (tint_amount > 0.0) {
		float lum = dot(rock, vec3(0.3, 0.59, 0.11));
		rock = mix(rock, tint.rgb * lum / 0.2, tint_amount);
	}
	ALBEDO = rock * (1.0 - 0.55 * occlusion);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 nx = texture(rock_normal, pos.zy * grain_scale).rgb;
	vec3 ny = texture(rock_normal, pos.xz * grain_scale).rgb;
	vec3 nz = texture(rock_normal, pos.xy * grain_scale).rgb;
	NORMAL_MAP = nx * w.x + ny * w.y + nz * w.z;
	NORMAL_MAP_DEPTH = 0.9 * detail;
}
"""
	var shader = Shader.new()
	shader.code = code
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("local_coords", true)
	var mi = MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	print("Test dynamic rock shader compiled successfully!")
	quit()

