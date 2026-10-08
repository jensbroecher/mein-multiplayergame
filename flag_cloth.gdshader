shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// A cloth flag waving in the wind. The mesh is a subdivided rectangle in its local XY plane with
// the hoist (the edge tied to the pole) at UV.x = 0: the wave grows toward the free end, travels
// away from the pole, and each flag is phase-shifted by where it stands so a row of them does not
// flap in lockstep.

uniform vec4 color_a : source_color = vec4(1.0, 0.30, 0.06, 1.0);
uniform vec4 color_b : source_color = vec4(0.97, 0.97, 0.95, 1.0);
uniform float wave_speed = 7.0;
uniform float wave_amp = 0.22;
uniform float waves = 1.6;
uniform float droop = 0.12;

float wave(float x, float y, float ph) {
	// A main ripple plus a faster, smaller one running at a slight angle.
	return sin(x * waves * 6.2832 - ph) * wave_amp + sin(x * 11.0 + y * 2.5 - ph * 1.7) * 0.05;
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = TIME * wave_speed + dot(o.xz, vec2(0.37, 0.21));
	float x = UV.x;
	float y = UV.y;
	// Free end flaps, the hoist stays still.
	float reach = x * (0.4 + 0.6 * x);
	VERTEX.z += wave(x, y, ph) * reach;
	VERTEX.y -= x * x * droop;
	// Normal from the slope of the wave along the flag.
	float e = 0.02;
	float dz = (wave(x + e, y, ph) * (x + e) * (0.4 + 0.6 * (x + e)) - wave(x, y, ph) * reach) / e;
	NORMAL = normalize(vec3(-dz / 1.6, 0.0, 1.0));
}

void fragment() {
	// White diagonal stripe across the orange, like a course-marker pennant.
	float stripe = abs(UV.x * 0.9 - UV.y * 0.75 + 0.05) < 0.11 ? 1.0 : 0.0;
	vec3 col = mix(color_a.rgb, color_b.rgb, stripe);
	// Fabric weave catching the light a little.
	col *= 0.92 + 0.08 * sin(UV.x * 220.0) * sin(UV.y * 140.0);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	// Thin cloth: some sun shows through from behind, and the colour stays readable in shade.
	BACKLIGHT = col * 0.45;
	EMISSION = col * 0.06;
}
