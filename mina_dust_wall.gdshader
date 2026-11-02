shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// The haboob's wall of dust over Mina del Viento's escarpment (regenerate_mina.gd, HaboobWeather.gd): curtains of dust
// standing along the storm's front, UV.x metres along the curtain, UV.y 0 at its foot and 1 at its top. Billows roll up
// and along it, the top edge a cauliflower line, lit from the low sun at the top and dark at the foot. A curtain fades
// away as the camera comes within `fade_near` of it, where the weather's own dust (fog, sheets of dust) takes over.

uniform vec4 lit : source_color = vec4(0.86, 0.60, 0.40, 1.0);
uniform vec4 shade : source_color = vec4(0.46, 0.30, 0.22, 1.0);
uniform float opacity = 0.92;
uniform float fade_near = 140.0;
uniform float fade_far = 420.0;
// Higher curtains behind are paler, lower in front darker: `layer` 0 at the front.
uniform float layer = 0.0;
// How deep in the storm the camera is (HaboobWeather.gd): inside it the curtains are gone and the fog is the dust.
uniform float inside = 0.0;

varying vec3 wp;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * n2(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = UV.x + layer * 731.0;
	float v = UV.y;
	float t = TIME;
	// Billows: big rounded heads rolling up, smaller ones on them.
	float big = fbm(vec2(u * 0.0045 - t * 0.0035, v * 1.4 - t * 0.010));
	float small = fbm(vec2(u * 0.017 + t * 0.006, v * 5.0 - t * 0.035));
	float n = big * 0.7 + small * 0.3;
	// The cauliflower top, higher here and lower there along the front.
	float top = 0.52 + 0.32 * fbm(vec2(u * 0.0022 - t * 0.0016, 3.0 + layer)) + 0.1 * (small - 0.5);
	float edge = v - top;
	float body = 1.0 - smoothstep(-0.16, 0.02, edge + (big - 0.5) * 0.18);
	// The foot thins where the dust drags along the ground.
	body *= smoothstep(-0.02, 0.08, v);
	float a = body * opacity * (0.7 + 0.3 * smoothstep(0.3, 0.7, n));
	float lightness = smoothstep(0.05, 0.85, v + (n - 0.5) * 0.35) * (0.8 + 0.4 * small);
	vec3 c = mix(shade.rgb, lit.rgb, clamp(lightness, 0.0, 1.0));
	c = mix(c, lit.rgb * 1.08, layer * 0.18);
	float d = length(wp - CAMERA_POSITION_WORLD);
	a *= smoothstep(fade_near, fade_far, d);
	// Seen edge on, a curtain is a thin hard band: fade it at grazing angles.
	a *= smoothstep(0.08, 0.45, abs(dot(normalize(NORMAL), VIEW)));
	a *= 1.0 - smoothstep(0.12, 0.45, inside);
	// COLOR.a fades the curtain out toward its ends.
	ALBEDO = c;
	ALPHA = clamp(a * COLOR.a, 0.0, 1.0);
}
