shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

// Tussocks of dry savanna grass (Mara Crossing). Each tuft is a fan of blade triangles: vertex
// colour is the blade colour, UV.y the height up the blade (0 root, 1 tip), so the tips sway in
// the wind and catch the low sun while the roots stay put.

uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind_strength = 0.22;
uniform vec4 tip_tint : source_color = vec4(1.08, 0.96, 0.78, 1.0);

varying float tip;

void vertex() {
	tip = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 1.3 + wp.x * 0.07 + wp.z * 0.05) * 0.6 + sin(TIME * 2.9 + wp.x * 0.21 - wp.z * 0.17) * 0.4;
	float bend = UV.y * UV.y * wind_strength * (0.55 + 0.45 * gust);
	vec3 wdir = vec3(wind_dir.x, 0.0, wind_dir.y);
	// Wind in world space, converted back to the instance's local frame.
	vec3 local_w = (inverse(MODEL_MATRIX) * vec4(wdir, 0.0)).xyz;
	VERTEX += local_w * bend;
	VERTEX.y -= bend * 0.3;
}

void fragment() {
	// The generator's palette is sRGB.
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	c = mix(c * 0.55, c * tip_tint.rgb, tip);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	// Thin blades let light through; backlit by the low sun the tops glow.
	BACKLIGHT = c * 0.55 * tip;
}
