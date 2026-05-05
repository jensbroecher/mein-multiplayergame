shader_type spatial;
render_mode cull_disabled; // See water from both sides

uniform vec3 water_color : source_color = vec3(0.005, 0.015, 0.04); // Deeper blue
uniform vec3 shallow_color : source_color = vec3(0.1, 0.4, 0.6);
uniform float transparency : hint_range(0.0, 1.0) = 0.92;
uniform float metallic : hint_range(0.0, 1.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;

uniform sampler2D noise_tex;
uniform sampler2D normal_tex; 
uniform float wave_speed = 0.03; // Even slower for calm water
uniform float wave_strength = 0.8;
uniform float wave_height = 0.6; // Reduced height for more stable look

varying float height_val;
varying float world_y;

void vertex() {
	vec2 uv = UV * 40.0;
	vec2 motion = vec2(TIME * wave_speed);
	
	float h1 = texture(noise_tex, uv + motion).r;
	float h2 = texture(noise_tex, uv * 0.5 - motion * 0.7).r;
	height_val = (h1 + h2) * 0.5;
	
	VERTEX.y += height_val * wave_height;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec2 uv = UV * 100.0;
	vec2 motion = vec2(TIME * wave_speed);
	
	// Two sets of scrolling normals
	vec3 norm1 = texture(noise_tex, uv + motion).rgb;
	vec3 norm2 = texture(noise_tex, uv * 2.0 - motion * 1.8 + vec2(0.5)).rgb;
	vec3 combined_normal = mix(norm1, norm2, 0.5);
	
	// Determine if we are looking at the top or bottom of the water
	bool is_front = FRONT_FACING;
	
	// Color mixing
	vec3 final_color = mix(water_color, shallow_color, height_val * 0.4);
	
	if (!is_front) {
		// UNDERWATER LOOK: Make it much darker and murkier
		final_color = water_color * 0.5;
		ALBEDO = final_color;
		ALPHA = 0.98; // Very opaque when looking from below
		NORMAL = -NORMAL; // Correct normals for back side
	} else {
		// SURFACE LOOK
		ALBEDO = final_color;
		NORMAL_MAP = combined_normal;
		NORMAL_MAP_DEPTH = wave_strength;
		
		// Foam highlights at crests
		float foam = smoothstep(0.78, 1.0, height_val);
		ALBEDO = mix(ALBEDO, vec3(0.8, 0.9, 1.0), foam * 0.3);
		
		// Fresnel effect
		float fresnel = pow(1.0 - dot(NORMAL, VIEW), 4.0);
		ALPHA = mix(transparency, 1.0, fresnel);
	}
	
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.8;
}
