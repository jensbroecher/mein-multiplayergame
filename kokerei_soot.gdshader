// Soot on concrete, brick and steel for Kokerei Kronprinz (KokereiKit.gd, key "soot"): the quench tower's shaft and
// chimney, the coke oven battery's top, the coal tower's underside. No UVs: everything is laid from the world position, on
// the vertical plane the surface faces (the horizontal coordinate eased between x and z by the normal, as in
// industrial_paint) or, on faces looking up or down, on the ground plane.
// The vertex colour is the material's own colour (sRGB); its ALPHA is how sooted that vertex is (the builder paints it:
// 1 at the top of the quench tower, where the steam comes out, fading toward its foot), so the black runs down the walls in
// long streaks that thin out lower down. Fine detail fades to its mean by the pixel's size in metres.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float soot = 1.0;
uniform vec3 soot_color : source_color = vec3(0.045, 0.04, 0.036);
uniform float rough = 0.9;
// Faint shuttering lines on concrete (0: none), every `board_h` metres up the wall.
uniform float board = 0.0;
uniform float board_h = 0.48;

varying vec3 wpos;
varying vec3 wnrm;

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float amount = clamp(COLOR.a * soot, 0.0, 1.0);
	vec3 n = normalize(wnrm);
	float fw = length(fwidth(wpos));
	float fine = 1.0 - smoothstep(0.05, 0.45, fw);
	float h = mix(wpos.x, wpos.z, smoothstep(-0.2, 0.2, abs(n.x) - abs(n.z)));
	vec2 q = vec2(h, wpos.y);
	float flat_face = step(0.72, abs(n.y));
	q = mix(q, wpos.xz, flat_face);
	// Streaks: narrow across, very long down the wall (on flat faces: blotches and patches).
	vec2 sq = mix(vec2(q.x * 0.55, q.y * 0.035), q * 0.35, flat_face);
	float wob = vnoise(vec2(q.x * 0.2, q.y * 0.08)) * 1.6;
	float st = vnoise(sq + vec2(wob, 1.7)) * 0.55 + vnoise(sq * vec2(2.7, 1.6) + vec2(wob * 0.5, 4.1)) * 0.25 + mix(0.1, vnoise(sq * vec2(7.0, 3.0) + 9.0) * 0.2, fine);
	float blot = vnoise(q * 0.21 + 5.3);
	float s = amount * (0.35 + 1.1 * st) + (blot - 0.5) * 0.45 * amount;
	s = smoothstep(0.22, 0.92, s);
	float speck = mix(0.5, vnoise(q * 7.0), fine);
	vec3 col = base * (0.86 + 0.26 * speck) * (0.93 + 0.14 * vnoise(q * 0.6 + 2.0));
	// Shuttering lines (concrete): a thin dark line every board_h up the wall, faded with distance.
	if (board > 0.0) {
		float by = fract(wpos.y / board_h);
		float line = 1.0 - smoothstep(0.0, 0.06, min(by, 1.0 - by));
		col *= 1.0 - board * 0.18 * line * fine * (1.0 - flat_face);
	}
	col = mix(col, soot_color * (0.8 + 0.4 * speck), s);
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.97, s);
	METALLIC = 0.0;
	SPECULAR = mix(0.5, 0.25, s);
}
