shader_type spatial;

uniform vec3 color_a : source_color = vec3(1.0, 1.0, 1.0); // White
uniform vec3 color_b : source_color = vec3(0.8, 0.1, 0.1); // Red
uniform float stripe_length = 2.0; // Meters per stripe pair
uniform float roughness = 0.8;

void fragment() {
	// UV.y is the distance along the track in meters
	float dist = UV.y;
	
	float continuous_coord = dist / stripe_length;
	float v = fract(continuous_coord);
	float delta = fwidth(continuous_coord);
	
	// Anti-alias both the transition in the middle (0.5) and the cell wrap boundaries (0.0 / 1.0)
	float edge1 = smoothstep(0.5 - delta, 0.5 + delta, v);
	float edge2 = smoothstep(1.0 - delta, 1.0, v) + (1.0 - smoothstep(0.0, delta, v));
	float stripe = clamp(edge1 - edge2, 0.0, 1.0);
	
	ALBEDO = mix(color_a, color_b, stripe);
	ROUGHNESS = roughness;
}
