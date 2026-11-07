// The Botanischer Garten's flowers (GardenKit.gd, key "gflower"): the carpet bedding (Teppichbeete), the mixed
// borders, the roses on the pergola and in the beds, the urns' geraniums, the Alpinum's cushion plants. The planting is a
// low mounded surface (or a lumpy clump) whose vertex colours make the pattern; this draws the plants on it from UV in
// LIFE metres: a mat of small leaves, and over it individual blossoms of the kind COLOR.a names, in COLOR.rgb (sRGB):
//   kind = floor(COLOR.a * 16):
//    0 foliage only (green)          1 begonia (glossy dark leaves, dense small flowers)    2 salvia (red spikes from above)
//    3 marigold (pompoms)            4 ageratum (soft blue puffs)                           5 silver foliage (dusty miller)
//    6 coloured foliage (leaves in COLOR: alternanthera, coleus)                            7 dahlia (big double flowers)
//    8 aster (daisies, yellow eye)   9 alyssum (tiny florets)                              10 rudbeckia (yellow, dark eye)
//   11 rose (cupped blooms, glossy leaves)  12 lavender (grey foliage, small spikes)       13 alpine cushion (dense tiny)
//   14 geranium (round umbels)      15 a spire card: delphinium, foxglove, hollyhock (UV.x across 0..1 plus its id, UV.y up)
// Each kind is a grid (two layers, offset) with at most one blossom a cell, jittered; their petals, eyes and the
// gaps' shade are drawn when a blossom is a few pixels across and fade to the kind's mean colour once it is under one,
// so a bed seen from 40m is an even, saturated colour and from 10m a carpet of flowers.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying float kindv;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash12(p), hash12(p + 17.31));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	kindv = COLOR.a;
}

// One layer of blossoms: cell size `cell`, blossom radius `rb`, share of cells with one `cover`, `petals` (0: a puff),
// `eye_r` the eye's share of the radius. Out: coverage, eye coverage, tone, tilt.
void blossoms(vec2 uv, float layer, float cell, float rb, float cover, float petals, float eye_r, float aa,
		out float cov, out float eye, out float tone, out vec2 tilt) {
	vec2 q = uv / cell + vec2(layer * 0.5, layer * 0.37);
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash12(id + vec2(layer * 13.1, 4.7));
	cov = 0.0;
	eye = 0.0;
	tone = hash12(id + vec2(2.3, layer));
	tilt = vec2(0.0);
	if (h > cover) {
		return;
	}
	float rr = rb * (0.8 + 0.4 * hash12(id + vec2(9.1, layer)));
	vec2 c = (hash22(id + vec2(layer, 1.7)) - 0.5) * max(0.0, 1.0 - 2.0 * rr / cell);
	vec2 d = (f - c) * cell;
	float r = length(d);
	float a = atan(d.y, d.x) + h * 31.0;
	float edge;
	if (petals > 0.5) {
		edge = rr * (0.74 + 0.26 * abs(cos(petals * 0.5 * a)));
	} else {
		edge = rr * (0.86 + 0.14 * vnoise(vec2(a * 2.0, h * 40.0)));
	}
	cov = 1.0 - smoothstep(edge - aa * 0.7, edge + aa * 0.7, r);
	eye = 1.0 - smoothstep(rr * eye_r - aa * 0.7, rr * eye_r + aa * 0.7, r);
	tilt = d / max(rr, 1e-3) * 0.6 * cov;
}

void fragment() {
	int kind = int(floor(kindv * 16.0));
	vec3 bloom = pow(COLOR.rgb, vec3(2.2));
	vec2 uv = UV;
	vec2 fw = fwidth(uv);
	float aa = max(length(fw), 1e-4);
	vec3 col;
	float rough = 0.8;
	float spec = 0.3;
	if (kind == 15) {
		// A spire card: a stem with a few leaves below, a tapering spike of florets above.
		float u = fract(uv.x) - 0.5;
		float v = uv.y;
		float sid = floor(uv.x);
		float faa = max(fw.x, 1e-3);
		float stem = (1.0 - smoothstep(0.025, 0.04 + faa, abs(u))) * step(v, 0.4);
		float lv = v * 7.0;
		float lf = fract(lv);
		float leafw = 0.3 * sin(3.14159 * lf) * step(v, 0.38);
		float leafside = (floor(lv) - 2.0 * floor(lv * 0.5)) * 2.0 - 1.0;
		float leaf = step(0.0, u * leafside) * (1.0 - smoothstep(leafw - faa, leafw + faa, abs(u) + (1.0 - lf) * 0.05));
		float t = clamp((v - 0.32) / 0.68, 0.0, 1.0);
		float sw = (0.36 * pow(1.0 - t, 0.7) + 0.04) * step(0.32, v) * step(v, 0.995);
		vec2 fq = vec2(u * 7.0 + 0.5 * floor(v * 26.0), v * 26.0);
		vec2 ff = fract(fq) - 0.5;
		float hv = hash12(floor(fq) + sid);
		float floret = 1.0 - smoothstep(0.32, 0.5, length(ff));
		floret = mix(floret, 0.85, smoothstep(0.35, 0.9, max(fw.y * 26.0, faa * 7.0)));
		float spike = (1.0 - smoothstep(sw - faa, sw + faa, abs(u))) * max(floret, 0.4);
		float c = max(max(stem, leaf), spike);
		if (c < 0.5) {
			discard;
		}
		vec3 green = vec3(0.05, 0.12, 0.03);
		col = spike > 0.5 ? bloom * (0.75 + 0.45 * hv) * mix(0.65, 1.0, floret) : green * (0.8 + 0.4 * lf);
		ALBEDO = col;
		ROUGHNESS = 0.7;
		SPECULAR = 0.3;
		BACKLIGHT = col * 0.4;
	} else {
		// Kind parameters: blossom cell and radius (life metres), cover, petals, eye share, leaf size and colour.
		float cell = 0.06;
		float rb = 0.02;
		float cover = 0.8;
		float petals = 5.0;
		float eye_r = 0.25;
		vec3 eye_col = vec3(0.6, 0.45, 0.05);
		float leaf_s = 0.05;
		vec3 leaf = vec3(0.045, 0.11, 0.03);
		float layers = 2.0;
		bool foliage = false;
		if (kind == 0) {
			foliage = true;
			leaf = bloom;
		} else if (kind == 1) {
			cell = 0.055; rb = 0.017; cover = 0.85; petals = 4.0; eye_r = 0.22; eye_col = vec3(0.75, 0.6, 0.05);
			leaf = vec3(0.05, 0.10, 0.03); leaf_s = 0.06; rough = 0.45; spec = 0.45;
		} else if (kind == 2) {
			cell = 0.05; rb = 0.02; cover = 0.75; petals = 0.0; eye_r = 0.0; leaf = vec3(0.05, 0.13, 0.03);
		} else if (kind == 3) {
			cell = 0.07; rb = 0.026; cover = 0.85; petals = 14.0; eye_r = 0.28; eye_col = bloom * 0.55; leaf = vec3(0.04, 0.10, 0.025);
		} else if (kind == 4) {
			cell = 0.06; rb = 0.026; cover = 0.9; petals = 0.0; eye_r = 0.0; leaf = vec3(0.05, 0.12, 0.04);
		} else if (kind == 5) {
			foliage = true;
			leaf = bloom;
			leaf_s = 0.07;
		} else if (kind == 6) {
			foliage = true;
			leaf = bloom;
			leaf_s = 0.035;
		} else if (kind == 7) {
			cell = 0.2; rb = 0.065; cover = 0.6; petals = 16.0; eye_r = 0.18; eye_col = vec3(0.7, 0.55, 0.1) * bloom;
			leaf = vec3(0.04, 0.09, 0.03); leaf_s = 0.09; layers = 1.0;
		} else if (kind == 8) {
			cell = 0.055; rb = 0.018; cover = 0.85; petals = 18.0; eye_r = 0.3; eye_col = vec3(0.85, 0.62, 0.05);
		} else if (kind == 9) {
			cell = 0.03; rb = 0.011; cover = 0.9; petals = 4.0; eye_r = 0.2; eye_col = vec3(0.8, 0.7, 0.3);
			leaf = vec3(0.07, 0.13, 0.05); leaf_s = 0.025;
		} else if (kind == 10) {
			cell = 0.13; rb = 0.042; cover = 0.7; petals = 13.0; eye_r = 0.3; eye_col = vec3(0.12, 0.06, 0.02);
			leaf = vec3(0.05, 0.11, 0.03); leaf_s = 0.07; layers = 1.0;
		} else if (kind == 11) {
			cell = 0.16; rb = 0.04; cover = 0.6; petals = 7.0; eye_r = 0.45; eye_col = bloom * 0.6;
			leaf = vec3(0.035, 0.08, 0.025); leaf_s = 0.045; rough = 0.45; spec = 0.45; layers = 1.0;
		} else if (kind == 12) {
			cell = 0.05; rb = 0.012; cover = 0.6; petals = 0.0; eye_r = 0.0; leaf = vec3(0.17, 0.21, 0.15); leaf_s = 0.03;
		} else if (kind == 13) {
			cell = 0.022; rb = 0.008; cover = 0.75; petals = 5.0; eye_r = 0.25; eye_col = vec3(0.85, 0.75, 0.2);
			leaf = vec3(0.06, 0.13, 0.04); leaf_s = 0.018;
		} else if (kind == 14) {
			cell = 0.13; rb = 0.05; cover = 0.75; petals = 0.0; eye_r = 0.0; leaf = vec3(0.05, 0.12, 0.03); leaf_s = 0.07;
			layers = 1.0;
		}
		// The leaves: a cell pattern, each leaf its own tone, the gaps between them in shade.
		vec2 lq = uv / leaf_s;
		vec2 li = floor(lq);
		vec2 lf = fract(lq);
		float best = 8.0;
		vec2 lid = vec2(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 g = vec2(float(x), float(y));
				float dd = length(g + hash22(li + g) - lf);
				if (dd < best) {
					best = dd;
					lid = li + g;
				}
			}
		}
		float lfade = smoothstep(leaf_s * 0.25, leaf_s * 0.9, aa);
		float ltone = hash12(lid);
		float lgap = smoothstep(0.45, 0.8, best);
		vec3 lcol = leaf * mix((0.78 + 0.45 * ltone) * (1.0 - 0.5 * lgap), 0.92, lfade);
		if (kind == 5) {
			// Felted silver leaves, deeply lobed: paler on the lobes, a little green at the heart.
			lcol = mix(lcol, leaf * 1.2, 0.3 * (1.0 - lfade));
		}
		vec2 ltilt = (hash22(lid + 5.0) - 0.5) * 0.7 * (1.0 - lfade) * (1.0 - lgap);
		// Clumps: each plant a low dome, darker between them.
		float clump = vnoise(uv * 4.5);
		lcol *= 0.78 + 0.32 * clump;
		col = lcol;
		vec2 tilt = ltilt;
		if (!foliage) {
			float bfade = smoothstep(rb * 0.35, rb * 1.4, aa);
			float c0;
			float e0;
			float t0;
			vec2 tl0;
			blossoms(uv, 0.0, cell, rb, cover, petals, eye_r, aa, c0, e0, t0, tl0);
			float c1 = 0.0;
			float e1 = 0.0;
			float t1 = 0.0;
			vec2 tl1 = vec2(0.0);
			if (layers > 1.5) {
				blossoms(uv, 1.0, cell, rb, cover, petals, eye_r, aa, c1, e1, t1, tl1);
			}
			float bc = max(c0, c1);
			float be = c1 > c0 ? e1 : e0;
			float bt = c1 > c0 ? t1 : t0;
			vec3 bcol = bloom * (0.82 + 0.3 * bt);
			if (kind == 2 || kind == 12) {
				// Spikes seen from above: florets in a short row.
				bcol *= 0.85 + 0.25 * vnoise(uv * 60.0);
			}
			if (kind == 4) {
				bcol *= 0.8 + 0.3 * vnoise(uv * 140.0);
			}
			if (kind == 7 || kind == 11) {
				// Double flowers: rings of petals darker toward the heart.
				bcol *= 0.75 + 0.3 * smoothstep(0.0, 1.0, 1.0 - be * 0.8);
			}
			vec3 eye_lin = (kind == 3 || kind == 7 || kind == 11) ? eye_col : pow(eye_col, vec3(2.2));
			bcol = mix(bcol, eye_lin, be * (eye_r > 0.0 ? 0.85 : 0.0));
			// The mean: the blossoms' share of the surface.
			float share = clamp(cover * 3.14159 * rb * rb * 0.85 / (cell * cell) * (layers > 1.5 ? 1.7 : 1.0), 0.0, 0.92);
			vec3 mean = mix(leaf * 0.9, bloom * 0.97, share);
			col = mix(mix(lcol * (1.0 - 0.25 * bc), bcol, bc), mean * (0.78 + 0.32 * clump), bfade);
			tilt = mix(mix(ltilt, max(tl0, tl1), bc), vec2(0.0), bfade);
			rough = mix(rough, 0.75, bc);
		}
		// A bump from the leaves' and blossoms' tilts, in the model's frame (the planting lies roughly flat in it).
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		nw = normalize(nw + vec3(tilt.x, 0.0, tilt.y) * 0.8);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
		ALBEDO = col;
		ROUGHNESS = rough;
		SPECULAR = spec;
		BACKLIGHT = col * 0.25;
	}
}
