shader_type spatial;

uniform vec3 color_a : source_color = vec3(1.0, 1.0, 1.0); // White
uniform vec3 color_b : source_color = vec3(0.8, 0.1, 0.1); // Red
uniform float stripe_length = 2.0; // Meters per stripe pair
uniform float roughness = 0.8;

void fragment() {
	// UV.y is the distance along the track in meters
	float dist = UV.y;
	
	// Anti-aliased stripes using fwidth to calculate blur based on distance
	float v = fract(dist / stripe_length);
	float delta = fwidth(v);
	float stripe = smoothstep(0.5 - delta, 0.5 + delta, v);
	
	ALBEDO = mix(color_a, color_b, stripe);
	ROUGHNESS = roughness;
}
