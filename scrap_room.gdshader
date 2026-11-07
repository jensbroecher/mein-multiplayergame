// The finishes of the 1960s office block being demolished on the Kronburg GP finale (ScrapKit.gd, key "room"): what the
// wrecking ball lays open (wallpaper, tiles, paint, floor coverings, ceilings), the block's own skin (glass mosaic
// spandrels, exposed-aggregate panels) and the raw concrete of every broken edge. UV is in game metres (life x `unit`):
// u along a wall, v up it (in plan on floors and ceilings). The vertex colour is the tint and its alpha picks the finish,
// (id + 0.5) / 16:
//    0  emulsion paint            5  glass mosaic (2.5cm), facade panels   10  ceiling plaster, water stains
//    1  striped wallpaper         6  exposed aggregate (Waschbeton)        11  broken concrete
//    2  1970s circles wallpaper   7  lino                                  12  stairwell oil paint: a dado to 1.5m
//    3  sprigged wallpaper        8  wood strip floor
//    4  15cm wall tiles           9  carpet
// Walls (0 to 4, 12) are torn and stained where `damage` says, showing the plaster under the paper. Every pattern fades to
// its average by the pixel's size in metres (fwidth). The id is read from a value equal at a face's three corners and
// floored at the middle of its band, so the drift of interpolation never changes it; nothing is hashed from it.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// UV units a life metre (the props' scale).
uniform float unit = 1.6;
uniform float damage : hint_range(0.0, 1.0) = 0.45;
// The block's storeys (for the stairwell's dado): the ground floor's level and the storey height, life metres.
uniform float floor0 = 0.45;
uniform float storey = 3.5;

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

// 1 on the lines of a grid of cells `c` (metres), lines `w` wide, faded to their share as they shrink under a pixel.
float grid_lines(vec2 q, vec2 c, float w, float fw) {
	vec2 g = abs(fract(q / c + 0.5) - 0.5) * c;
	float d = min(g.x, g.y);
	float aa = max(fw, 1e-4);
	float l = 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, d);
	float share = clamp(w / min(c.x, c.y) * 2.0, 0.0, 1.0);
	return mix(l, share, smoothstep(w * 0.6, w * 3.0, fw));
}

void fragment() {
	vec2 q = UV / unit;
	float fw = max(length(fwidth(q)), 1e-5);
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	int id = int(floor(COLOR.a * 16.0));
	float fine = 1.0 - smoothstep(0.004, 0.03, fw);
	float mid = 1.0 - smoothstep(0.02, 0.12, fw);
	float n1 = vnoise(q * 1.3);
	float n2 = vnoise(q * 6.0 + 3.0);
	float n3 = mix(0.5, vnoise(q * 40.0 + 7.0), fine);
	vec3 col = tint;
	float rough = 0.85;
	bool wall = false;
	if (id == 0) {
		col = tint * (0.93 + 0.07 * n1 + 0.05 * n3);
		wall = true;
	} else if (id == 1) {
		float s = fract(q.x / 0.16);
		float band = smoothstep(0.08, 0.1, s) * (1.0 - smoothstep(0.44, 0.46, s));
		float pin = smoothstep(0.58, 0.6, s) * (1.0 - smoothstep(0.63, 0.65, s));
		float b = mix(band * 0.55 + pin * 0.12, 0.3, smoothstep(0.01, 0.05, fw));
		col = mix(tint, tint * 0.68, b) + vec3(0.08) * pin * mid;
		col *= 0.95 + 0.05 * n3;
		wall = true;
	} else if (id == 2) {
		vec2 c = fract(q / 0.32) - 0.5;
		float r = length(c) * 0.32;
		float aa = fw * 1.2;
		float disc = 1.0 - smoothstep(0.125 - aa, 0.125 + aa, r);
		float ring = disc * smoothstep(0.075 - aa, 0.075 + aa, r);
		float dot_ = 1.0 - smoothstep(0.035 - aa, 0.035 + aa, r);
		vec3 bg = tint * 0.42;
		vec3 accent = vec3(tint.r * 1.05, tint.g * 0.82, tint.b * 0.55);
		vec3 c2 = mix(bg, accent, ring);
		c2 = mix(c2, tint * 0.25 + vec3(0.06, 0.03, 0.0), disc - ring - dot_);
		c2 = mix(c2, accent * 1.1, dot_);
		col = mix(c2, bg * 0.5 + accent * 0.45, smoothstep(0.03, 0.09, fw));
		wall = true;
	} else if (id == 3) {
		vec2 c = fract(q / vec2(0.1, 0.12) + vec2(0.5 * floor(q.y / 0.12), 0.0)) - 0.5;
		float d = length(c * vec2(0.1, 0.12));
		float aa = fw;
		float sprig = 1.0 - smoothstep(0.016 - aa, 0.016 + aa, d);
		float leaf = (1.0 - smoothstep(0.01 - aa, 0.01 + aa, length((c + vec2(0.3, -0.25)) * vec2(0.1, 0.06)))) * 0.8;
		float s = max(sprig, leaf);
		s = mix(s, 0.12, smoothstep(0.01, 0.04, fw));
		vec3 ink = mix(tint * 0.45, vec3(0.42, 0.18, 0.12), 0.4);
		col = mix(tint * (0.95 + 0.05 * n3), mix(ink, tint * 0.6 + vec3(0.06, 0.1, 0.03), leaf), s);
		wall = true;
	} else if (id == 4) {
		float t = 0.15;
		vec2 cell = floor(q / t);
		float g = grid_lines(q, vec2(t), 0.004, fw);
		vec3 tile = tint * (0.93 + 0.1 * hash12(cell));
		col = mix(tile, vec3(0.62, 0.61, 0.58) * (0.9 + 0.2 * n2), g);
		rough = mix(0.18, 0.85, g);
		wall = true;
	} else if (id == 5) {
		float t = 0.025;
		vec2 cell = floor(q / t);
		float hv = mix(0.5, hash12(cell), (1.0 - smoothstep(0.004, 0.012, fw)));
		float g = grid_lines(q, vec2(t), 0.002, fw);
		vec3 tile = tint * (0.78 + 0.44 * hv);
		tile = mix(tile, tile.bgr * 0.9, step(0.88, hv) * 0.5);
		col = mix(tile, vec3(0.5, 0.5, 0.48), g * 0.8);
		// The facade's panel joints and rain streaks.
		float pj = grid_lines(q, vec2(1.5, 1.45), 0.012, fw);
		col *= 1.0 - 0.45 * pj;
		col *= 1.0 - 0.3 * smoothstep(0.5, 0.95, vnoise(vec2(q.x * 2.4, q.y * 0.12)));
		col *= 1.0 - 0.18 * smoothstep(0.55, 0.85, n1);
		rough = mix(0.25, 0.8, g);
	} else if (id == 6) {
		vec2 cell = floor(q / 0.022);
		float hv = mix(0.5, hash12(cell), (1.0 - smoothstep(0.004, 0.012, fw)));
		float pebble = mix(0.55, smoothstep(0.35, 0.7, vnoise(q / 0.022 * 0.9)), (1.0 - smoothstep(0.005, 0.012, fw)));
		vec3 matrix_c = tint * 0.82;
		vec3 stone = tint * (0.75 + 0.5 * hv) * mix(vec3(1.0), vec3(1.08, 0.98, 0.88), step(0.6, hv));
		col = mix(matrix_c, stone, pebble);
		float pj = grid_lines(q, vec2(1.5, 1.2), 0.015, fw);
		col *= 1.0 - 0.5 * pj;
		col *= 1.0 - 0.3 * smoothstep(0.5, 0.95, vnoise(vec2(q.x * 2.4, q.y * 0.12)));
		rough = 0.95;
	} else if (id == 7) {
		col = tint * (0.9 + 0.12 * n2 + 0.08 * n3);
		col = mix(col, tint * 1.25, smoothstep(0.6, 0.8, vnoise(q * 18.0)) * fine * 0.4);
		col *= 1.0 - 0.3 * grid_lines(q, vec2(2.0, 20.0), 0.004, fw);
		rough = 0.55;
	} else if (id == 8) {
		float w = 0.07;
		float row = floor(q.y / w);
		float x = q.x + hash12(vec2(row, 1.0)) * 0.42;
		float id8 = hash12(vec2(floor(x / 0.42), row));
		col = tint * (0.78 + 0.35 * mix(0.5, id8, mid));
		float g = max(grid_lines(vec2(x, q.y), vec2(0.42, w), 0.003, fw), 0.0);
		col *= 1.0 - 0.45 * g;
		col *= 0.9 + 0.12 * vnoise(vec2(x * 3.0, q.y * 60.0)) * fine;
		rough = 0.6;
	} else if (id == 9) {
		col = tint * (0.82 + 0.25 * n3 + 0.1 * n2);
		rough = 1.0;
	} else if (id == 10) {
		col = tint * (0.95 + 0.05 * n2);
		float st = vnoise(q * 0.6 + 4.0);
		float ring = smoothstep(0.62, 0.66, st) * (1.0 - smoothstep(0.68, 0.74, st));
		col = mix(col, col * vec3(0.78, 0.68, 0.52), smoothstep(0.66, 0.8, st) * 0.45 + ring * 0.35);
		rough = 0.95;
	} else if (id == 11) {
		float agg = mix(0.5, smoothstep(0.4, 0.75, vnoise(q * 28.0)), mid);
		col = tint * (0.72 + 0.18 * n2 + 0.22 * agg) * (0.92 + 0.12 * n3);
		col = mix(col, col * vec3(0.95, 0.88, 0.8), agg * 0.3);
		rough = 0.97;
	} else {
		float lv = mod(q.y - floor0, storey);
		float dado = 1.0 - smoothstep(1.48, 1.5 + fw, lv);
		float line = (1.0 - smoothstep(0.0, 0.012 + fw, abs(lv - 1.5)));
		vec3 low = tint;
		vec3 up = vec3(0.86, 0.84, 0.76);
		col = mix(up, low, dado) * (0.94 + 0.06 * n1);
		col = mix(col, tint * 0.4, line * 0.8);
		rough = mix(0.8, 0.45, dado);
		wall = true;
	}
	if (wall) {
		// Torn and stained: the paper ripped off in patches down to the plaster, damp stains running down, dust.
		float t = vnoise(q * 0.9 + 17.0) * 0.7 + vnoise(q * 3.5 + 5.0) * 0.3;
		float torn = smoothstep(0.7 - damage * 0.25, 0.73 - damage * 0.25, t) * step(0.5, damage + 0.3);
		vec3 plaster = vec3(0.74, 0.71, 0.65) * (0.9 + 0.12 * n3);
		float edge = smoothstep(0.66 - damage * 0.25, 0.7 - damage * 0.25, t) * (1.0 - torn);
		col = mix(col, col * 0.75 + vec3(0.04), edge * 0.6);
		col = mix(col, plaster, torn);
		float stain = smoothstep(0.55, 0.9, vnoise(vec2(q.x * 2.0, q.y * 0.2) + 3.0)) * damage;
		col *= 1.0 - 0.3 * stain;
		rough = mix(rough, 0.95, torn);
	}
	// Dust over everything.
	col = mix(col, vec3(0.55, 0.53, 0.5) * (0.9 + 0.1 * n2), smoothstep(0.62, 0.9, vnoise(q * 0.5 + 8.0)) * 0.25);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
}
