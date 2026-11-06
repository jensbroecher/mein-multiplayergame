shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Still water in a fountain's basin (KronburgTownKit.gd, key "kwater"): opaque, a deep blue-green that mirrors the
// sky, a few slow ripples running out from points on a 3m grid (about where spouts fall) and a light chop. Everything
// from the world position, so a basin moved anywhere ripples the same; TIME only moves the normals (not a sky shader).
// The vertex colour tints it (white: the uniforms' colours).

uniform vec4 deep : source_color = vec4(0.03, 0.11, 0.11, 1.0);
uniform vec4 shallow : source_color = vec4(0.10, 0.24, 0.21, 1.0);
// How far apart the ripples' rings are, in world metres, and how fast they run.
uniform float ring_spacing = 0.5;
uniform float ring_speed = 0.35;

varying vec3 v_world;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float fw = length(fwidth(p));
	float fade = smoothstep(0.05, 0.4, fw);
	// A chop of two noise layers drifting different ways, read as slopes.
	vec2 e = vec2(0.08, 0.0);
	vec2 a = p * 1.7 + vec2(TIME * 0.11, -TIME * 0.07);
	vec2 b = p * 3.1 + vec2(-TIME * 0.09, TIME * 0.13);
	float n0 = vn(a) + 0.5 * vn(b);
	float nx = vn(a + e.xy) + 0.5 * vn(b + e.xy) - n0;
	float nz = vn(a + e.yx) + 0.5 * vn(b + e.yx) - n0;
	// Rings out from the middle of each cell of a coarse grid (the spouts' splashes land about there).
	vec2 cell = floor(p / 3.0);
	vec2 c = (cell + 0.5 + (vec2(h21(cell), h21(cell + 7.0)) - 0.5) * 0.6) * 3.0;
	vec2 d = p - c;
	float r = length(d);
	float wave = sin(r / ring_spacing * 6.2832 - TIME * ring_speed * 12.0) * exp(-r * 0.9);
	vec2 rg = (r > 0.001 ? d / r : vec2(0.0)) * wave * 0.25;
	vec3 n = normalize(vec3(-(nx * 1.6 + rg.x), 1.0, -(nz * 1.6 + rg.y)));
	n = mix(n, vec3(0.0, 1.0, 0.0), fade * 0.7);
	// The normal map in tangent space: the basin is flat (normal up), so world x and z map onto it.
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.3 + 0.3 * n0) * tint;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.45;
}
