// Steel-framed industrial glazing (SteelworksKit.gd): the many-paned windows of the rolling mill hall, its roof
// monitor and roof lights, the cast house, the engine house and the crane cabs. UV is in life-size metres (u across,
// v up), and the shader draws the glazing bars and the panes itself, so a window is one quad.
//   inside = false ("glass"): seen from outside: dark panes that mirror the sky, some milky (wired glass), a few
//     replaced darker or lighter, the bars in grey-green paint.
//   inside = true ("skylight"): seen from inside: daylight through the panes as emission (no lighting), the bars
//     dark against it, so a hall's windows read bright from within.
// Pane picks hash floor(UV / pane), which is the same over a pane's interior (the bars cover its edges).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform bool inside = false;
uniform vec2 pane = vec2(0.56, 0.42);
uniform float bar = 0.045;
uniform vec3 bar_color : source_color = vec3(0.24, 0.29, 0.27);
uniform vec3 sky_color : source_color = vec3(0.86, 0.90, 0.95);
uniform float sky_energy = 1.35;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 q = UV / pane;
	vec2 f = fract(q);
	vec2 id = floor(q);
	// Bars: distance to the pane's edge in metres, faded to their mean coverage once they are under a pixel.
	vec2 dm = min(f, 1.0 - f) * pane;
	vec2 fw = fwidth(UV);
	float aa = max(fw.x, fw.y);
	float b = 1.0 - smoothstep(bar * 0.5 - aa * 0.5, bar * 0.5 + aa * 0.5, min(dm.x, dm.y));
	float mean_bar = clamp(bar * (pane.x + pane.y) / (pane.x * pane.y), 0.0, 1.0);
	b = mix(b, mean_bar, smoothstep(bar * 0.6, bar * 2.0, aa));
	float h = hash12(id + vec2(3.7, 11.3));
	float h2 = hash12(id * 1.37 + vec2(7.1, 2.9));
	// Under a pane a pixel: the panes' mean, so a far facade doesn't sparkle.
	float far = smoothstep(min(pane.x, pane.y) * 0.25, min(pane.x, pane.y) * 0.8, aa);
	h = mix(h, 0.5, far);
	h2 = mix(h2, 0.0, far);
	if (inside) {
		// Daylight: frosted panes warmer, dirty ones dim, a few boarded or painted over.
		vec3 day = pow(sky_color, vec3(2.2)) * sky_energy;
		day *= 0.9 + 0.14 * h;
		day = mix(day, day * vec3(1.04, 0.99, 0.9), step(0.75, h2));
		day *= mix(1.0, 0.3, step(0.98, h));
		vec3 bars = vec3(0.03, 0.035, 0.035);
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = mix(day, bars, b);
	} else {
		// Glass: dark and reflective; wired (milky) panes and odd replacements.
		vec3 g = vec3(0.05, 0.065, 0.072) * (0.88 + 0.24 * h);
		float milky = step(0.88, h2);
		g = mix(g, vec3(0.13, 0.145, 0.15), milky * 0.6);
		g = mix(g, vec3(0.03, 0.033, 0.036), step(0.97, h));
		vec3 bc = pow(bar_color, vec3(2.2));
		ALBEDO = mix(g, bc, b);
		METALLIC = mix(0.55, 0.2, max(b, milky * 0.6));
		ROUGHNESS = mix(0.06, 0.6, max(b, milky * 0.7));
	}
}
