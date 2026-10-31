shader_type spatial;
render_mode cull_back, unshaded;

// The LED wall behind Club Kilele's DJ booth (Mtaa Nights): abstract visuals on the clock, drawn as
// a grid of LED pixels that fade to their average where a pixel is smaller than a screen pixel. UV
// spans 0..1 over the wall; `aspect` is its width over its height. ClubLights.gd sets `clock` (the
// wall clock, so the floor, the lights and the screen share the beat).

uniform float aspect = 2.6;
uniform float bpm = 124.0;
uniform float energy = 1.6;
uniform vec2 pixels = vec2(160.0, 62.0);
uniform float clock = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec2 px = floor(UV * pixels) / pixels;
	float beat_t = clock * bpm / 60.0;
	float bar = floor(beat_t / 4.0);
	vec2 p = (px - 0.5) * vec2(aspect, 1.0);
	float pulse = 0.6 + 0.4 * exp(-fract(beat_t) * 3.0);
	float scene = mod(floor(bar / 4.0), 3.0);
	vec3 col;
	if (scene < 0.5) {
		// Rings out from the middle, the hue drifting.
		float r = length(p);
		float rings = smoothstep(0.35, 0.65, sin(r * 18.0 - beat_t * 3.1416) * 0.5 + 0.5);
		col = hue(r * 0.4 + clock * 0.05) * rings;
	} else if (scene < 1.5) {
		// An equaliser: bars rising and falling with the beat.
		float b = floor(px.x * 32.0);
		float h = 0.25 + 0.6 * abs(sin(b * 0.7 + beat_t * 1.5708 + hash21(vec2(b, bar)) * 3.0)) * pulse;
		float on = step(px.y, h) * step(0.15, fract(px.x * 32.0));
		col = mix(vec3(1.0, 0.15, 0.6), vec3(0.1, 0.8, 1.0), px.y / max(h, 0.01)) * on;
	} else {
		// A slow tunnel of stripes.
		float a = atan(p.y, p.x);
		float r = length(p) + 0.05;
		float s = sin(a * 6.0 + 1.0 / r * 2.0 - beat_t * 1.2);
		col = hue(0.75 + 0.15 * sin(clock * 0.2)) * smoothstep(0.2, 0.8, s * 0.5 + 0.5) * smoothstep(0.0, 0.4, r);
	}
	col *= pulse;
	// The LED grid: round pixels with dark gaps, blending to their average far away.
	vec2 f = fract(UV * pixels) - 0.5;
	float dot_mask = 1.0 - smoothstep(0.32, 0.46, length(f));
	float tiny = clamp(length(fwidth(UV * pixels)) * 0.8, 0.0, 1.0);
	float m = mix(dot_mask, 0.55, tiny);
	ALBEDO = col * energy * m;
}
