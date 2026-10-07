shader_type spatial;

uniform vec3 color_a : source_color = vec3(1.0, 1.0, 1.0); // White
uniform vec3 color_b : source_color = vec3(0.8, 0.1, 0.1); // Red
uniform float stripe_length = 2.0; // Meters per stripe pair
uniform float roughness = 0.8;
// Straights: a plain shoulder with a painted line along the asphalt edge instead of a kerb.
uniform vec3 shoulder_color : source_color = vec3(0.30, 0.31, 0.33);
uniform vec3 line_color : source_color = vec3(0.92, 0.92, 0.90);
// Line width as a fraction of the strip's UV.x span (each side strip spans 0.25 UV, ~1m).
uniform float line_width = 0.04;

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
	vec3 kerb = mix(color_a, color_b, stripe);

	// UV.x: 0..0.25 is the left strip, 0.75..1 the right one; 0.25 and 0.75 are the asphalt edges.
	float to_edge = min(abs(UV.x - 0.25), abs(UV.x - 0.75));
	float aa = fwidth(UV.x);
	float line = 1.0 - smoothstep(line_width - aa, line_width + aa, to_edge);
	vec3 shoulder = mix(shoulder_color, line_color, line);

	// Vertex colour red = corner weight, written per stripe pair by TerrainGenerator. Meshes made
	// before that existed have no vertex colour, which reads as white -> kerb everywhere, as before.
	float corner = step(0.5, COLOR.r);
	ALBEDO = mix(shoulder, kerb, corner);
	ROUGHNESS = roughness;
}
