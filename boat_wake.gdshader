shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_disabled;
// A boat's wake (SeaBoat.gd): a ribbon laid on the water along the way the boat came. UV.x runs across it (0 and 1 its
// edges, the two arms of the wake), UV.y its age (0 at the stern, 1 where it has died away); COLOR.a how hard the
// boat was driving there. Foam gathers in the arms and churns down the middle behind the stern, broken up by noise
// drifting with the water, and fades with age. A bow wave uses the same (UV.y 0 at the stem). Drawn after the water.

uniform vec3 foam : source_color = vec3(0.90, 0.94, 0.95);
uniform float strength = 0.75;

varying vec3 w_pos;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = UV.x;
	float age = clamp(UV.y, 0.0, 1.0);
	vec2 p = w_pos.xz;
	vec2 drift = vec2(TIME * 0.12, -TIME * 0.08);
	float n = vnoise(p * 0.35 + drift) * 0.5 + vnoise(p * 0.9 - drift * 1.7) * 0.3 + vnoise(p * 2.3 + drift * 2.3) * 0.2;
	float fine = vnoise(p * 3.1 - drift * 3.0);
	// The arms: thin, broken lines of foam along both edges, softer and patchier as they age.
	float arm_w = mix(0.05, 0.14, age);
	float arms = (1.0 - smoothstep(0.0, arm_w, x)) + smoothstep(1.0 - arm_w, 1.0, x);
	arms *= smoothstep(0.3, 0.75, n + 0.2 * (1.0 - age)) * (0.6 + 0.4 * fine);
	// The churn behind the stern: a narrow band of white water down the middle, dying away first.
	float mid = 1.0 - smoothstep(0.0, mix(0.2, 0.06, age), abs(x - 0.5));
	float churn = mid * (1.0 - smoothstep(0.0, 0.35, age)) * smoothstep(0.25, 0.7, n * 0.7 + fine * 0.3 + 0.15);
	// A faint wash of disturbed water across the whole wake, paler than the sea round it.
	float wash = 0.12 * (1.0 - smoothstep(0.0, 0.6, age)) * smoothstep(0.0, 0.15, min(x, 1.0 - x));
	float f = max(max(arms, churn * 0.85), wash);
	f *= pow(1.0 - age, 1.3) * smoothstep(0.0, 0.03, age + 0.02);
	ALBEDO = foam;
	// Lit from above whichever way the strip winds (seen from its back it came out dark grey).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 0.9;
	ALPHA = clamp(f * strength * COLOR.a, 0.0, 1.0);
}
