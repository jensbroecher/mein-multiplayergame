// Lumps of coke for Kokerei Kronprinz (KokereiKit.gd, key "coke"): the heaps on the coke wharf, the quench car's load,
// the belt. Two Voronoi layers laid from the world position (on the ground plane for heaps, on the vertical plane a wall
// faces): lumps `lump` across, and clods of them four times that (so a heap still reads lumpy from 20-40m), each its own
// grey with coke's dull silvery sheen, dark crevices between them, each face tipped toward its own middle so it reads as
// rounded; broad darker and lighter drifts over a heap. Under a few pixels a layer fades to its mean (no shimmer).
// The vertex colour is the coke's grey (sRGB); ALPHA is how wet it is (fresh from the quench: darker, glossier).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// A lump's size in world metres.
uniform float lump = 0.2;

varying vec3 wpos;
varying vec3 wnrm;

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

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

// x: crevice (1 at an edge), y: the cell's own shade 0..1, zw: the offset to the cell's middle.
vec4 cells(vec2 q) {
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 best = vec2(0.0);
	vec2 bid = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(cell + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = r;
				bid = cell + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	return vec4(1.0 - smoothstep(0.02, 0.24, edge), hash12(bid), best);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float wet = COLOR.a;
	vec3 n = normalize(wnrm);
	float fw = length(fwidth(wpos));
	float fine = 1.0 - smoothstep(lump * 0.25, lump * 0.9, fw);
	float mid = 1.0 - smoothstep(lump, lump * 3.6, fw);
	float flat_face = smoothstep(0.45, 0.7, abs(n.y));
	float axis_z = smoothstep(-0.2, 0.2, abs(n.x) - abs(n.z));
	float h = mix(wpos.x, wpos.z, axis_z);
	vec2 p = mix(vec2(h, wpos.y), wpos.xz, flat_face);
	// Warped, so the clods don't line up into a paving.
	vec2 warp = vec2(vnoise(p * 0.9 + 1.3), vnoise(p * 0.9 + 7.9)) - 0.5;
	vec4 c1 = cells(p / lump + warp * 1.5);
	vec4 c2 = cells(p / (lump * 2.6) + 17.0 + warp * 2.2);
	float drift = vnoise(p * 0.12) * 0.6 + vnoise(p * 0.45 + 3.0) * 0.4;
	float grain = vnoise(p * 2.3 + 5.0);
	float shade = (0.7 + 0.55 * drift) * mix(1.0, 0.8 + 0.4 * grain, 1.0 - fine);
	shade *= mix(1.0, (0.82 + 0.36 * c2.y) * (1.0 - 0.3 * c2.x), mid);
	shade *= mix(1.0, (0.65 + 0.7 * c1.y) * (1.0 - 0.7 * c1.x), fine);
	vec3 col = base * shade * mix(1.0, 0.6, wet);
	ALBEDO = col;
	// Coke's sheen: silvery on the lumps up close, dull grey further off and in the crevices; glossier when wet.
	METALLIC = mix(0.08, 0.35 * (1.0 - c1.x), fine);
	ROUGHNESS = mix(0.86, mix(0.5, 0.95, c1.x), fine) * mix(1.0, 0.75, wet);
	vec2 tilt2 = c1.zw * 0.9 * fine + c2.zw * 0.3 * mid;
	vec3 wall_tilt = vec3(tilt2.x * (1.0 - axis_z), tilt2.y, tilt2.x * axis_z);
	vec3 tilt = mix(wall_tilt, vec3(tilt2.x, 0.0, tilt2.y), flat_face);
	vec3 bumped = normalize(n - tilt);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
}
