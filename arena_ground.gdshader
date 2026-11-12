shader_type spatial;
render_mode cull_back;

// The capture-the-flag arena's ground (regenerate_arena_ctf.gd): vertex colour r grass, g rock, b packed dirt (the
// tracks between the bases and round them), a = sand (the trench's floor). Textures in world metres, the rock across
// the slope's face.

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 grass_tint : source_color = vec3(0.42, 0.52, 0.31);
uniform vec3 rock_tint : source_color = vec3(0.78, 0.72, 0.66);
uniform vec3 dirt_tint : source_color = vec3(0.86, 0.72, 0.56);
uniform vec3 sand_tint : source_color = vec3(0.92, 0.84, 0.66);

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 g = texture(grass_tex, w_pos.xz / 5.0).rgb * grass_tint;
	g *= 0.9 + 0.2 * texture(grass_tex, w_pos.xz / 37.0).g;
	vec3 bw = pow(abs(w_nrm), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	vec3 r = (texture(rock_tex, w_pos.zy / 9.0).rgb * bw.x + texture(rock_tex, w_pos.xz / 9.0).rgb * bw.y
		+ texture(rock_tex, w_pos.xy / 9.0).rgb * bw.z) * rock_tint;
	vec3 d = texture(dirt_tex, w_pos.xz / 6.0).rgb * dirt_tint;
	vec3 s = texture(dirt_tex, w_pos.xz / 3.0).rgb * sand_tint;
	vec4 w = COLOR;
	float steep = 1.0 - smoothstep(0.68, 0.84, w_nrm.y);
	float rock = max(w.g, steep);
	vec3 col = g;
	col = mix(col, d, w.b);
	col = mix(col, s, w.a);
	col = mix(col, r, rock);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
