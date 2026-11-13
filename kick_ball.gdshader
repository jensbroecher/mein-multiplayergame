shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

// The balls carts kick about (KickBall.gd), drawn on a plain sphere from the direction out of its
// centre, so the pattern turns with the ball.
//
// style 0, a football: the classic 32 panels of a truncated icosahedron, black pentagons and white
// hexagons. A point belongs to the face its ray from the centre meets first: the face maximising
// dot(n, centre) / that face's distance from the middle (pentagons stand a little further out than
// hexagons). Seams where the best two are close, sized in pixels so they stay thin from afar.
// style 1, a beach ball: six vinyl gores round its axis, white caps at both poles.
// style 2, the arena ball (ArenaGame.gd's football): the football's panels, navy and white, its seams glowing lime so
// it reads across the bowl.

uniform int style = 0;
uniform vec3 dirt : source_color = vec3(0.45, 0.33, 0.22);
uniform float dirt_amount = 0.18;
// A glow over the ball's own colours for a moment (KickBall.set_fx: the arena's goal and kick-off effects).
instance uniform float fx_glow = 0.0;
instance uniform vec3 fx_tint : source_color = vec3(1.0);

varying vec3 v_dir;

void vertex() {
	v_dir = normalize(VERTEX);
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Score a face of unit centre c whose plane stands d from the middle; keep the best two.
void face(vec3 n, vec3 c, float d, bool pent, inout float best, inout float second, inout bool best_pent) {
	float s = dot(n, normalize(c)) / d;
	if (s > best) {
		second = best;
		best = s;
		best_pent = pent;
	} else if (s > second) {
		second = s;
	}
}

void fragment() {
	vec3 n = normalize(v_dir);
	vec3 col;
	float rough;
	vec3 emit = vec3(0.0);
	if (style == 0 || style == 2) {
		// Icosahedron vertices (pentagons) are the cyclic permutations of (0, +-1, +-phi); its faces'
		// centres (hexagons) its dual's vertices: (+-1, +-1, +-1) and the cyclic permutations of
		// (+-1/phi, 0, +-phi), the other way round.
		const float PHI = 1.6180340;
		const float IPHI = 0.6180340;
		// Face distances for an edge of 1: pentagons 2.3274, hexagons 2.2673.
		const float DP = 2.3274;
		const float DH = 2.2673;
		float best = -10.0;
		float second = -10.0;
		bool pent = false;
		for (int i = 0; i < 4; i++) {
			float a = (i & 1) == 0 ? 1.0 : -1.0;
			float b = (i & 2) == 0 ? PHI : -PHI;
			face(n, vec3(0.0, a, b), DP, true, best, second, pent);
			face(n, vec3(a, b, 0.0), DP, true, best, second, pent);
			face(n, vec3(b, 0.0, a), DP, true, best, second, pent);
			float c = (i & 1) == 0 ? IPHI : -IPHI;
			face(n, vec3(c, 0.0, b), DH, false, best, second, pent);
			face(n, vec3(0.0, b, c), DH, false, best, second, pent);
			face(n, vec3(b, c, 0.0), DH, false, best, second, pent);
		}
		for (int i = 0; i < 8; i++) {
			vec3 s = vec3((i & 1) == 0 ? 1.0 : -1.0, (i & 2) == 0 ? 1.0 : -1.0, (i & 4) == 0 ? 1.0 : -1.0);
			face(n, s, DH, false, best, second, pent);
		}
		float gap = best - second;
		float w = max(fwidth(gap), 1e-5);
		float seam = 1.0 - smoothstep(0.004, 0.004 + w * 1.5, gap);
		col = pent ? vec3(0.035, 0.035, 0.04) : vec3(0.92, 0.92, 0.90);
		col = mix(col, vec3(0.30, 0.30, 0.30), seam * (pent ? 0.3 : 0.75));
		// Scuffed from the dirt: blotches, most where the leather is white.
		float d = smoothstep(0.45, 0.85, vnoise(n * 5.0) * 0.7 + vnoise(n * 13.0) * 0.3);
		col = mix(col, dirt, d * dirt_amount * (pent ? 0.3 : 1.0));
		rough = mix(0.42, 0.75, d) + seam * 0.2;
		if (style == 2) {
			float glow = 1.0 - smoothstep(0.004, 0.004 + w * 3.0 + 0.012, gap);
			col = pent ? vec3(0.03, 0.05, 0.14) : vec3(0.93, 0.95, 0.97);
			col = mix(col, vec3(0.5, 1.0, 0.2), glow);
			emit = vec3(0.5, 1.0, 0.18) * glow * 2.2 + (pent ? vec3(0.0) : vec3(0.08));
			rough = 0.35;
		}
	} else {
		const vec3 GORES[6] = vec3[](vec3(0.88, 0.10, 0.10), vec3(0.97, 0.97, 0.95), vec3(0.98, 0.78, 0.08),
			vec3(0.08, 0.36, 0.86), vec3(0.97, 0.97, 0.95), vec3(0.10, 0.66, 0.30));
		float a = atan(n.z, n.x) / 6.2831853 * 6.0;
		int k = int(floor(mod(a, 6.0)));
		col = GORES[k];
		float f = fract(a);
		float edge = min(f, 1.0 - f) * sqrt(max(1.0 - n.y * n.y, 0.0));
		float we = max(fwidth(edge), 1e-5);
		col *= 1.0 - 0.18 * (1.0 - smoothstep(0.004, 0.004 + we * 1.5, edge));
		float cap = abs(n.y);
		float wc = max(fwidth(cap), 1e-5);
		col = mix(col, vec3(0.97, 0.97, 0.95), smoothstep(0.935, 0.935 + wc, cap));
		col *= 1.0 - 0.2 * smoothstep(0.928, 0.932, cap) * (1.0 - smoothstep(0.936, 0.94, cap));
		rough = 0.22;
	}
	ALBEDO = col;
	EMISSION = emit + fx_tint * fx_glow * (0.35 + 0.65 * dot(col, vec3(0.333)));
	ROUGHNESS = rough;
	SPECULAR = 0.5;
}
