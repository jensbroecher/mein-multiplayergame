shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float max_dist = 350.0;
uniform float fade_r = 60.0;

uniform vec3 player_positions[8];
uniform int player_count = 0;

void vertex() {
	// Distance fade & cull
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(view_pos);
	if (dist > max_dist) {
		VERTEX = vec3(0.0);
	} else {
		if (dist > max_dist - fade_r) {
			float fade = (max_dist - dist) / fade_r;
			VERTEX *= fade;
		}
		
		// Fast procedural bending away from vehicles passing through
		float height_factor = clamp(1.0 - UV.y, 0.0, 1.0);
		if (player_count > 0 && height_factor > 0.05) {
			vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
			vec3 total_push = vec3(0.0);
			for (int i = 0; i < player_count; i++) {
				vec3 p_pos = player_positions[i];
				vec3 diff = world_pos - p_pos;
				float d_xz_sq = diff.x * diff.x + diff.z * diff.z;
				float radius = 2.4;
				if (d_xz_sq < radius * radius && abs(diff.y) < 2.0) {
					float d = sqrt(max(d_xz_sq, 0.0001));
					float push = (1.0 - d / radius);
					push = push * push * height_factor;
					vec2 dir = diff.xz / d;
					total_push.x += dir.x * push * 1.6;
					total_push.z += dir.y * push * 1.6;
					total_push.y -= push * 0.45;
				}
			}
			if (dot(total_push, total_push) > 0.0001) {
				mat3 model_rot = mat3(MODEL_MATRIX);
				float sq_scale = max(dot(model_rot[0], model_rot[0]), 0.0001);
				vec3 local_delta = (total_push * model_rot) / sq_scale;
				VERTEX += local_delta;
			}
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

