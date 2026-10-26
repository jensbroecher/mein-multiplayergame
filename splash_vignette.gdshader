shader_type canvas_item;

// splash_vignette.gdshader: darkens the corners of the title card, and takes a little of the frame's
// brightness off with `dim` (the intro and the outro).

uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform float dim : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float v = smoothstep(0.5, 1.5, length(p * vec2(0.9, 1.0)));
	COLOR = vec4(0.0, 0.004, 0.02, clamp(v * vignette + dim, 0.0, 1.0));
}
