// The Botanischer Garten's tropical plants and trunks (GardenKit.gd, key "gleaf"): the Palmenhaus's palms, bananas,
// tree ferns and aroids, the water lilies, the hanging baskets' trailers. Two-sided, opaque, cut out by discard.
// COLOR.rgb is the colour (sRGB), COLOR.a picks what a face is (constant over a face):
//   1.0   solid: stems, petioles, banana pseudostems; their backs a little paler.
//   0.9   a palm trunk: UV.x round it, UV.y up it, both in life metres; leaf-scar rings, fibres between them.
//   0.8   a tree fern's trunk: UV as 0.9; a shaggy mat of brown root fibres with old frond bases in a diamond lay.
//   0.7   a pinnate palm frond (a card): fract(UV.x) across (0.5 the rachis), UV.y from its base (0) to its tip (1),
//         floor(UV.x) the frond's id; leaflets leave the rachis angled toward the tip, longest mid-frond.
//   0.6   a fan palm's leaf (a disc): fract(UV.x) the angle across the fan, UV.y the radius (0 the hastula, 1 the rim);
//         pleated segments, split apart over their outer part into drooping pointed tips.
//   0.5   a banana leaf: as 0.7; an oblong blade with a pale midrib, fine parallel veins and wind tears along them.
//   0.45  a simple ovate leaf (rubber plant, philodendron; a croton's, yellow-veined and blotched, on half the ids).
//   0.4   an elephant's ear (Alocasia): as 0.7; a heart-shaped blade with lobes behind the petiole's attachment
//         (UV.y 0.22) and pale veins radiating from it.
//   0.35  a Swiss cheese plant (Monstera): 0.4's heart, cut by slits from the edge toward the midrib and holes.
//   0.3   a tree fern frond: as 0.7; finer pinnae, each toothed (pinnules).
//   0.2   a strap leaf (bird of paradise, clivia, cordyline): as 0.7; a lance with a midrib and parallel veins.
//   0.1   a water lily pad: UV 0..1 over its quad, a disc with a slit to its middle, radial veins, a red rim.
// Every pattern fades to its mean once it is under a pixel, and cut-outs widen so a far card keeps its body.
// No TIME: nothing moves under the glass. camera_xray thins what stands between the race camera and the cart.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://camera_xray.gdshaderinc"

varying float mode;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	mode = COLOR.a;
}

// A pinnate frond's leaflets. u -1..1 across (0 the rachis), v 0..1 along, `n` leaflets a side, `k` their forward
// sweep, `aa` the pixel in v; out: coverage, the leaflet's midrib (1 on it) and its tone. `teeth` serrates them (ferns).
float pinnae(float u, float v, float n, float k, float aa, float id, float teeth, out float rib, out float tone) {
	float au = abs(u);
	// The frond's outline: short leaflets at the base, longest past the middle, short to the tip.
	float env = pow(sin(3.14159 * clamp(pow(v, 0.85), 0.0, 1.0)), 0.55) * smoothstep(0.0, 0.08, v);
	float s = (v - au * k) * n;
	float i = floor(s + 0.5);
	float hv = hash12(vec2(i * 1.7 + id * 3.1, sign(u) + id));
	float d = (s - i) / n;
	float len = env * (0.82 + 0.18 * hv) * step(0.08, hv + 0.2);
	float x = au / max(len, 1e-3);
	float w = (0.48 / n) * smoothstep(0.0, 0.12, x) * pow(clamp(1.0 - x, 0.0, 1.0), 0.6);
	w *= 1.0 + teeth * 0.35 * sin(au * 140.0 + id);
	float far = smoothstep(0.25 / n, 0.9 / n, aa);
	w = mix(w, 0.5 / n, far * step(x, 1.0));
	float cov = step(x, 1.0) * (1.0 - smoothstep(w - aa * 0.5, w + aa * 0.5, abs(d)));
	rib = 1.0 - clamp(abs(d) / max(w, 1e-4), 0.0, 1.0);
	tone = hv;
	return cov;
}

void fragment() {
	if (xray_hidden(VERTEX, VIEW_MATRIX, CAMERA_POSITION_WORLD, PROJECTION_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec2 fwu = fwidth(UV);
	float aa = max(max(fwu.x, fwu.y), 1e-4);
	vec3 col = base;
	float rough = 0.62;
	float spec = 0.35;
	float back = 0.45;
	float id = floor(UV.x);
	float u = fract(UV.x) * 2.0 - 1.0;
	float v = UV.y;
	if (mode > 0.95) {
		col = base;
		rough = 0.7;
		back = 0.2;
		if (!FRONT_FACING) {
			col *= 1.15;
		}
	} else if (mode > 0.85) {
		// Palm trunk: rings 12-22cm apart (each ring's own spacing), a groove and a lip, fibres up between them.
		float rs = 0.17;
		float ri = floor(UV.y / rs);
		float rf = fract(UV.y / rs);
		float fade = smoothstep(0.02, 0.08, fwu.y);
		float groove = (1.0 - smoothstep(0.0, 0.16, rf)) * (1.0 - fade);
		float lip = smoothstep(0.75, 0.98, rf) * (1.0 - fade);
		float fib = vnoise(vec2(UV.x * 28.0, UV.y * 2.0 + ri * 3.0));
		col = base * (0.86 + 0.2 * hash12(vec2(ri, 2.0))) * (0.9 + 0.2 * mix(fib, 0.5, smoothstep(0.01, 0.04, fwu.x)));
		col *= 1.0 - 0.38 * groove;
		col *= 1.0 + 0.12 * lip;
		col *= 0.85 + 0.15 * vnoise(UV * vec2(1.5, 0.4));
		rough = 0.88;
		spec = 0.2;
		back = 0.0;
	} else if (mode > 0.75) {
		// Tree fern trunk: matted root fibres, frond bases in a diamond lay.
		vec2 q = vec2(UV.x * 3.2, UV.y * 4.0);
		vec2 g = vec2(q.x + q.y * 0.5, q.y);
		vec2 f = fract(g) - 0.5;
		float scar = 1.0 - smoothstep(0.22, 0.42, length(f * vec2(1.0, 1.6)));
		float fib = vnoise(vec2(UV.x * 40.0, UV.y * 6.0)) * 0.6 + vnoise(UV * 9.0) * 0.4;
		float fade = smoothstep(0.03, 0.12, max(fwu.x, fwu.y));
		col = base * (0.7 + 0.5 * mix(fib, 0.5, fade));
		col = mix(col, base * vec3(1.25, 1.1, 0.9), scar * 0.5 * (1.0 - fade));
		rough = 0.95;
		spec = 0.15;
		back = 0.0;
	} else if (mode > 0.65 || (mode > 0.25 && mode < 0.35)) {
		// Pinnate frond (a palm's, or a tree fern's with toothed pinnae).
		bool fern = mode < 0.5;
		float n = fern ? 30.0 : 34.0;
		float rib;
		float tone;
		float cov = pinnae(u, v, n, fern ? 0.10 : 0.16, fwu.y, id, fern ? 1.0 : 0.0, rib, tone);
		float rach = 1.0 - smoothstep(0.018, 0.03 + fwu.x, abs(u));
		rach *= step(v, 0.98);
		if (max(cov, rach) < 0.5) {
			discard;
		}
		col = base * (0.82 + 0.3 * tone) * (0.9 + 0.1 * (1.0 - rib));
		col = mix(col, col * 1.3 + vec3(0.01, 0.012, 0.0), smoothstep(0.85, 0.97, rib) * (1.0 - smoothstep(0.004, 0.012, fwu.y)));
		// Older leaflets yellow toward their tips.
		col = mix(col, base * vec3(1.25, 1.15, 0.5), smoothstep(0.75, 1.0, abs(u) / max(1e-3, 1.0)) * 0.25 * tone);
		col = mix(col, base * vec3(1.15, 1.12, 0.65), rach);
		rough = fern ? 0.75 : 0.55;
		back = 0.5;
	} else if (mode > 0.55) {
		// Fan leaf: pleated segments, split over their outer part.
		float t = fract(UV.x);
		float r = UV.y;
		float ns = 38.0;
		float s = t * ns;
		float si = floor(s);
		float f = fract(s) - 0.5;
		float hv = hash12(vec2(si, id + 3.0));
		float split = 0.5 + 0.18 * hv;
		float tipr = 0.86 + 0.14 * hash12(vec2(si * 1.3, id + 7.0));
		float sw = mix(0.5, 0.14, smoothstep(split, tipr, r));
		float faa = fwu.x * ns;
		sw = mix(sw, 0.5, smoothstep(0.3, 0.9, faa));
		float cov = (1.0 - smoothstep(sw - faa * 0.5, sw + faa * 0.5, abs(f))) * step(r, tipr);
		if (r < split) {
			cov = 1.0;
		}
		if (cov < 0.5) {
			discard;
		}
		float pleat = cos(f * 6.28318);
		float pf = smoothstep(0.25, 0.8, faa);
		col = base * (0.86 + 0.28 * hv) * mix(0.82 + 0.18 * pleat, 0.92, pf);
		// Dry brown tips on a few segments.
		col = mix(col, vec3(0.32, 0.22, 0.10), step(0.86, hv) * smoothstep(tipr - 0.12, tipr, r));
		col = mix(col, base * vec3(1.2, 1.18, 0.8), (1.0 - smoothstep(0.03, 0.08, r)));
		rough = 0.5;
		spec = 0.4;
		back = 0.4;
	} else if (mode > 0.47) {
		// Banana leaf.
		float au = abs(u);
		float vv = clamp(v, 0.0, 1.0);
		float env = sqrt(max(0.0, 1.0 - pow(abs(vv - 0.48) / 0.52, 5.0))) * smoothstep(0.0, 0.05, vv);
		float cov = 1.0 - smoothstep(env - fwu.x, env + fwu.x, au);
		// Tears along the veins from the edge in: the veins leave the midrib swept toward the tip.
		float vs = (vv + au * 0.22) * 46.0;
		float vi = floor(vs);
		float vf = fract(vs) - 0.5;
		float th = hash12(vec2(vi, id + sign(u) * 5.0));
		float tear_from = mix(0.25, 0.9, hash12(vec2(vi * 2.1, id + 1.0)));
		float tear = step(0.62, th) * step(tear_from, au) * (1.0 - smoothstep(0.03, 0.06 + fwu.y * 46.0, abs(vf)));
		tear *= 1.0 - smoothstep(0.3, 0.9, fwu.y * 46.0);
		cov *= 1.0 - tear;
		if (cov < 0.5) {
			discard;
		}
		float mid = 1.0 - smoothstep(0.035, 0.05 + fwu.x, au);
		float vein = 0.5 + 0.5 * cos(vs * 6.28318);
		col = base * (0.92 + 0.08 * mix(vein, 0.5, smoothstep(0.004, 0.015, fwu.y))) * (0.9 + 0.2 * vnoise(vec2(u * 3.0, v * 12.0 + id)));
		col = mix(col, base * vec3(1.35, 1.3, 0.8), mid);
		// Brown, dried edges where it tore.
		col = mix(col, vec3(0.30, 0.24, 0.10), smoothstep(env * 0.9, env, au) * 0.6);
		rough = 0.45;
		spec = 0.45;
		back = 0.55;
	} else if (mode > 0.42) {
		// A simple ovate leaf (rubber plant, philodendron, croton): a midrib, pinnate veins; every other id a croton's,
		// its veins yellow and its blade blotched red and orange.
		float au = abs(u);
		float vv = clamp(v, 0.0, 1.0);
		float env = pow(max(sin(3.14159 * pow(vv, 0.75)), 0.0), 0.85);
		float cov = 1.0 - smoothstep(env - fwu.x, env + fwu.x, au);
		if (cov < 0.5) {
			discard;
		}
		float hv = hash12(vec2(id, 5.0));
		float vs = (vv + au * 0.35) * 9.0;
		float vein = (1.0 - smoothstep(0.03, 0.08, abs(fract(vs) - 0.5) * 0.5)) * (1.0 - smoothstep(0.01, 0.04, fwu.y * 9.0));
		float mid = 1.0 - smoothstep(0.03, 0.05 + fwu.x, au);
		col = base * (0.88 + 0.2 * vnoise(vec2(u * 3.0, v * 5.0 + id)));
		if (hv > 0.55) {
			float bl = vnoise(vec2(u * 2.5 + id, v * 4.0));
			vec3 warm = mix(vec3(0.75, 0.12, 0.05), vec3(0.95, 0.55, 0.05), vnoise(vec2(v * 3.0, id)));
			col = mix(col, warm, smoothstep(0.45, 0.7, bl) * 0.85);
			col = mix(col, vec3(0.85, 0.75, 0.10), max(vein * 0.8, mid));
		} else {
			col = mix(col, base * 1.35, max(vein * 0.35, mid * 0.6));
		}
		rough = 0.35;
		spec = 0.55;
		back = 0.35;
	} else if (mode > 0.32) {
		// Elephant's ear (0.4) and Swiss cheese plant (0.35): a heart.
		bool monstera = mode < 0.38;
		float au = abs(u);
		float a0 = 0.22;
		float env;
		if (v < a0) {
			env = mix(0.62, 0.96, smoothstep(0.0, a0, v));
		} else {
			env = 0.98 * pow(clamp(1.0 - (v - a0) / (1.0 - a0), 0.0, 1.0), 0.75) * (1.0 - 0.15 * smoothstep(0.0, 0.4, v - a0));
			env = max(env, 0.0);
		}
		// The sinus between the lobes behind the attachment.
		float sinus = step(v, a0) * step(au, 0.32 * (a0 - v) / a0);
		float cov = (1.0 - smoothstep(env - fwu.x, env + fwu.x, au)) * (1.0 - sinus);
		vec2 p = vec2(u, v - a0);
		float ang = atan(p.x, p.y);
		float rr = length(p);
		float vc = ang / 0.42;
		float vfrac = abs(fract(vc) - 0.5);
		if (monstera) {
			float hv = hash12(vec2(floor(vc), id));
			// Slits from the edge toward the midrib between the veins, holes in rows inside.
			float edge_frac = au / max(env, 1e-3);
			float cut = step(0.42, edge_frac) * (1.0 - smoothstep(0.06, 0.12, vfrac)) * step(0.25, hv);
			vec2 hc = vec2(fract(vc) - 0.5, rr * 6.0 - floor(rr * 6.0) - 0.5);
			float hole = step(0.18, rr) * step(edge_frac, 0.4) * step(0.45, hash12(vec2(floor(vc), floor(rr * 6.0) + id)))
					* (1.0 - smoothstep(0.16, 0.22, length(hc * vec2(1.6, 1.0))));
			cov *= 1.0 - max(cut, hole) * (1.0 - smoothstep(0.004, 0.02, fwu.x));
		}
		if (cov < 0.5) {
			discard;
		}
		float vein = (1.0 - smoothstep(0.02, 0.05, vfrac * 0.42 * max(rr, 0.05) * 4.0)) * step(0.02, rr);
		float mid = (1.0 - smoothstep(0.02, 0.035 + fwu.x, au)) * step(0.0, v - a0);
		float vfade = smoothstep(0.006, 0.02, max(fwu.x, fwu.y));
		col = base * (0.85 + 0.2 * vnoise(vec2(u * 4.0, v * 4.0 + id * 7.0)));
		vec3 pale = monstera ? base * 1.25 : mix(base * 2.6, vec3(0.75, 0.82, 0.70), 0.5);
		col = mix(col, pale, max(vein, mid) * (1.0 - vfade) * (monstera ? 0.5 : 0.85));
		col = mix(col, base * (monstera ? 1.04 : 1.12), vfade * (monstera ? 0.0 : 0.15));
		rough = 0.35;
		spec = 0.55;
		back = 0.35;
	} else if (mode > 0.15) {
		// Strap leaf.
		float au = abs(u);
		float env = pow(clamp(1.0 - v, 0.0, 1.0), 0.45) * smoothstep(0.0, 0.06, v + 0.02);
		float cov = 1.0 - smoothstep(env - fwu.x, env + fwu.x, au);
		if (cov < 0.5) {
			discard;
		}
		float mid = 1.0 - smoothstep(0.04, 0.07 + fwu.x, au);
		float lines = 0.5 + 0.5 * cos(au * 40.0);
		col = base * (0.9 + 0.1 * mix(lines, 0.5, smoothstep(0.01, 0.04, fwu.x))) * (0.9 + 0.2 * hash12(vec2(id, 1.0)));
		col = mix(col, base * 1.3, mid * 0.6);
		col = mix(col, vec3(0.42, 0.33, 0.14), smoothstep(0.9, 1.0, v) * 0.6);
		rough = 0.45;
		spec = 0.45;
		back = 0.45;
	} else {
		// Water lily pad.
		vec2 p = fract(UV) - 0.5;
		float rr = length(p);
		float ang = atan(p.y, p.x) + id * 2.3;
		float slit = (1.0 - smoothstep(0.02, 0.05, abs(sin(ang * 0.5)) * rr)) * step(0.0, cos(ang * 0.5));
		float cov = (1.0 - smoothstep(0.48 - fwu.x, 0.48 + fwu.x, rr)) * (1.0 - slit * (1.0 - smoothstep(0.004, 0.02, fwu.x)));
		if (cov < 0.5) {
			discard;
		}
		float vein = 1.0 - smoothstep(0.0, 0.08, abs(fract(ang * 2.5) - 0.5));
		col = base * (0.85 + 0.25 * vnoise(p * 9.0 + id));
		col = mix(col, base * 1.25, vein * 0.25 * (1.0 - smoothstep(0.004, 0.02, fwu.x)));
		col = mix(col, vec3(0.42, 0.12, 0.08), smoothstep(0.42, 0.48, rr) * 0.7);
		rough = 0.25;
		spec = 0.6;
		back = 0.1;
	}
	if (!FRONT_FACING && mode < 0.95 && mode < 0.75) {
		// Undersides paler and greyer.
		col = mix(col, col * vec3(1.15, 1.2, 1.05) + vec3(0.01), 0.45);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	BACKLIGHT = col * back;
}
