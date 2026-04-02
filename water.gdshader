shader_type spatial;

uniform vec3 water_color : source_color = vec3(0.01, 0.03, 0.08); // Deeper blue
uniform vec3 shallow_color : source_color = vec3(0.0, 0.5, 0.8);
uniform float transparency : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;

uniform sampler2D noise_tex;
uniform sampler2D normal_tex; // Dedicated normal map
uniform float wave_speed = 0.1;
uniform float wave_strength = 0.6;
uniform float wave_height = 1.2;

varying float height_val;

void vertex() {
	vec2 uv = UV * 40.0;
	vec2 motion = vec2(TIME * wave_speed);
	
	float h1 = texture(noise_tex, uv + motion).r;
	float h2 = texture(noise_tex, uv * 0.5 - motion * 0.7).r;
	height_val = (h1 + h2) * 0.5;
	
	VERTEX.y += height_val * wave_height;
}

void fragment() {
	vec2 uv = UV * 100.0;
	vec2 motion = vec2(TIME * wave_speed);
	
	// Complex normal blending for that "flowing" look
	vec3 norm1 = texture(noise_tex, uv + motion).rgb;
	vec3 norm2 = texture(noise_tex, uv * 1.5 - motion * 1.2 + vec2(0.3)).rgb;
	vec3 combined_normal = mix(norm1, norm2, 0.5);
	
	// Color based on height (simulating depth/foam)
	vec3 final_color = mix(water_color, shallow_color, height_val * 0.6);
	
	ALBEDO = final_color;
	NORMAL_MAP = combined_normal;
	NORMAL_MAP_DEPTH = wave_strength;
	
	// Add some highlights on top of waves
	float foam = smoothstep(0.7, 1.0, height_val);
	ALBEDO = mix(ALBEDO, vec3(0.9, 0.9, 1.0), foam * 0.3);
	
	ALPHA = transparency;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 1.0;
	
	// Fresnel effect for transparency
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
	ALPHA = mix(transparency, 1.0, fresnel);
}
