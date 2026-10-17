shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Grass thatch for the ranger post's rondavel (RangerPostBuilder.gd). UV: u round the cone in
// metres of arc at the eave, v the slant distance down from the apex, so the straw runs along v.
// The vertex colour is a tint (alpha is the darkness under the eave). Needs tangents.

uniform vec3 straw_new : source_color = vec3(0.58, 0.46, 0.27);
uniform vec3 straw_old : source_color = vec3(0.25, 0.19, 0.12);
uniform float age : hint_range(0.0, 1.0) = 0.5;

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

float strands(vec2 q) {
	return vnoise(vec2(q.x * 20.0, q.y * 1.5)) * 0.6 + vnoise(vec2(q.x * 6.5 + 3.0, q.y * 0.55)) * 0.4;
}

void fragment() {
	vec2 q = UV;
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float s = strands(q);
	vec3 col = mix(straw_old, straw_new, smoothstep(0.25, 0.75, s));
	// Bundles are laid in courses, each one darker where the next course overlaps it.
	float course = fract(q.y / 0.55 + hash12(vec2(floor(q.x / 1.1), 4.0)) * 0.3);
	col *= mix(0.6, 1.08, smoothstep(0.0, 0.4, course));
	// Old thatch goes dark, and green where it stays damp.
	float damp = smoothstep(0.5, 0.8, vnoise(q * 0.8 + 9.0)) * age;
	col = mix(col, col * vec3(0.55, 0.65, 0.4), damp * 0.6);
	col = mix(col, straw_old * 0.8, age * 0.35 * vnoise(q * 0.45 + 1.0));
	col *= tint;
	col *= COLOR.a;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
	// The straw's relief: tilt the normal by the strands' gradient across the cone.
	float e = 0.02;
	float dh = strands(q + vec2(e, 0.0)) - strands(q - vec2(e, 0.0));
	vec3 n = normalize(vec3(-dh * 2.2, 0.0, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
