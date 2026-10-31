shader_type spatial;
render_mode cull_back, unshaded;

// Self-lit vertex colour, brighter than white so the glow picks it up: neon tubes, festoon bulbs, LED
// strips and lit kiosk windows (Mtaa Nights). The vertex colour is sRGB; `energy` scales it.

uniform float energy = 3.0;

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * energy;
}
