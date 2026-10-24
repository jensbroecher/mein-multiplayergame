shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// White water left on the surface where something hit it hard (WaterFx.gd): a disc a little above
// the water whose foam is a churned patch in the middle and a ring at its edge that breaks up into
// streaks as it spreads, fading out over its life. `age` (0..1) is the instance's own.

instance uniform float age = 0.0;
instance uniform float seed = 0.0;
uniform vec4 foam_color : source_color = vec4(0.94, 0.97, 1.0, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	vec2 polar = vec2(a * 3.0, r * 6.0 - age * 2.0);
	float n = vnoise(p * 7.0 + seed * 13.0) * 0.55 + vnoise(p * 19.0 - seed * 7.0) * 0.3 + vnoise(polar * vec2(2.0, 1.0)) * 0.15;
	// The ring rides out to the edge; the middle churns, then clears first.
	float ring_r = mix(0.55, 0.9, age);
	float ring = 1.0 - smoothstep(0.0, mix(0.12, 0.2, age), abs(r - ring_r));
	float middle = (1.0 - smoothstep(0.0, mix(0.6, 0.25, age), r)) * (1.0 - age);
	float foam = max(ring * 0.95, middle);
	// Broken up into lace by the noise, more as it ages.
	foam *= smoothstep(0.25 + age * 0.3, 0.6 + age * 0.2, n);
	ALBEDO = foam_color.rgb;
	ALPHA = foam * pow(1.0 - age, 1.3) * 0.92;
}
