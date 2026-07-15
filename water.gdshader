shader_type spatial;
// Opaque-leaning water so sky specular actually shows (full transparency kills reflections).
render_mode cull_disabled, depth_draw_opaque, blend_mix, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.005, 0.015, 0.04);
uniform vec3 shallow_color : source_color = vec3(0.1, 0.4, 0.6);
/// Sky/horizon tint for fresnel mirror (also boosted by low roughness + metallic).
uniform vec3 sky_tint : source_color = vec3(0.55, 0.62, 0.68);
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.55;
/// 0 = solid opaque, 1 = fully see-through. Keep low for sky reflection.
uniform float transparency : hint_range(0.0, 1.0) = 0.35;
uniform float metallic : hint_range(0.0, 1.0) = 0.65;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;

uniform sampler2D noise_tex;
uniform sampler2D normal_tex;
uniform float wave_speed = 0.028;
uniform float wave_strength = 0.65;
uniform float wave_height = 0.0;
/// Scales world-space UV for wave size (lower = bigger waves).
uniform float wave_scale = 1.0;

varying float height_val;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 w = world_pos.xz * wave_scale;

	vec2 motion = vec2(TIME * wave_speed);

	// Large swells
	float h1 = texture(noise_tex, w * 0.012 + motion * 0.45).r * 0.65;
	// Medium rollers
	float h2 = texture(noise_tex, w * 0.035 - motion * 0.9).r * 0.85;
	// Smaller chop
	float h3 = texture(noise_tex, w * 0.09 + motion * 1.8 + vec2(0.3)).r * 0.4;

	height_val = (h1 + h2 + h3) * 0.5;
	VERTEX.y += height_val * wave_height;
}

void fragment() {
	vec2 uv = UV * 40.0 * wave_scale;
	vec2 motion = vec2(TIME * wave_speed);

	vec3 norm1 = texture(noise_tex, uv + motion).rgb;
	vec3 norm2 = texture(noise_tex, uv * 1.7 - motion * 1.5 + vec2(0.4)).rgb;
	vec3 combined_normal = mix(norm1, norm2, 0.5);

	vec3 final_color = mix(water_color, shallow_color, height_val * 0.35);

	if (!FRONT_FACING) {
		// Underside of the water plane
		ALBEDO = water_color * 0.45;
		ALPHA = 0.98;
		NORMAL = -NORMAL;
		METALLIC = 0.2;
		ROUGHNESS = 0.55;
		SPECULAR = 0.3;
	} else {
		NORMAL_MAP = combined_normal;
		NORMAL_MAP_DEPTH = wave_strength;

		float foam = smoothstep(0.72, 0.95, height_val);
		final_color = mix(final_color, mix(shallow_color, vec3(0.7, 0.75, 0.55), 0.35), foam * 0.28);

		// Strong fresnel sky mirror (works even without SSR when metallic/roughness are set)
		float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		float fresnel = pow(1.0 - ndotv, 2.4);
		float refl = clamp(fresnel * sky_reflect + sky_reflect * 0.15, 0.0, 1.0);

		// Bright sky/horizon reflection tint
		vec3 mirror = mix(sky_tint * 1.15, vec3(0.85, 0.9, 0.95), fresnel * 0.35);
		ALBEDO = mix(final_color, mirror, refl);

		// Mostly opaque so PBR specular from the environment/sky is visible
		ALPHA = mix(1.0 - transparency * 0.85, 0.97, refl);

		METALLIC = mix(metallic * 0.45, min(metallic + 0.25, 1.0), refl);
		ROUGHNESS = mix(max(roughness, 0.06), 0.03, refl);
		SPECULAR = mix(0.6, 1.0, refl);
	}
}
