shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float max_dist = 350.0;
uniform float fade_r = 60.0;

varying float height_val;

void vertex() {
	height_val = VERTEX.y;
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(view_pos);
	if (dist > max_dist) {
		VERTEX = vec3(0.0);
		height_val = 0.0;
	} else {
		if (dist > max_dist - fade_r) {
			float fade = (max_dist - dist) / fade_r;
			VERTEX *= fade;
		}
	}
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = tex_color.rgb * albedo_tint.rgb;
	ALPHA = tex_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 1.0;
	EMISSION = ALBEDO * 0.12;
}
