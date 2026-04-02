shader_type spatial;

uniform vec3 water_color : source_color = vec3(0.0, 0.4, 0.7);
uniform float transparency : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;

uniform sampler2D noise_tex;
uniform float wave_speed = 0.05;
uniform float wave_strength = 0.1;

void fragment() {
	// Increased tiling (100.0) so waves are visible on the large 2000m surface
	vec2 uv = UV * 100.0;
	vec2 motion = vec2(TIME * wave_speed);
	
	// Create two scrolling noise samples for a more dynamic "moving water" look
	vec3 normal1 = texture(noise_tex, uv + motion).rgb;
	vec3 normal2 = texture(noise_tex, uv - motion * 0.5 + vec2(0.2)).rgb;
	
	vec3 combined_normal = mix(normal1, normal2, 0.5);
	
	ALBEDO = water_color;
	NORMAL_MAP = combined_normal;
	NORMAL_MAP_DEPTH = wave_strength;
	
	ALPHA = transparency;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	// Simple specular highlight for sun reflection
	SPECULAR = 0.5;
}
