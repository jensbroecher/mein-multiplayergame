shader_type spatial;
render_mode cull_back, unshaded;

// Tianqiao's LED strips (skyway edges, railing feet, the spiral ramp's rim, the crown's lines): self-lit, a pulse
// chasing along them in the direction the race runs, and where COLOR.a is over 0 the colour drifting round the
// spectrum with position and time (COLOR.a how much). The vertex colour is sRGB; `energy` scales it.

uniform float energy = 3.2;
uniform float chase_speed = 5.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + (w_pos.x + w_pos.z) * 0.0025 + TIME * 0.05));
	vec3 c = mix(base, rainbow, COLOR.a);
	float pulse = 0.62 + 0.38 * sin((w_pos.x - w_pos.z) * 0.09 - TIME * chase_speed);
	ALBEDO = c * energy * pulse;
}
