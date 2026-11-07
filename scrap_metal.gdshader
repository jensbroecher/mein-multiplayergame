// Scrap steel for the Kronburg GP finale's demolition site and scrapyard (ScrapKit.gd, keys "scrap" and "scrapm"): wrecked
// cars and their bales, the scrap heaps, skips, drums and containers, the wrecking ball, the material handler and its
// magnet. The vertex colour is the paint (sRGB) and its alpha how worn it is: under 0.2 a working machine's paint with
// scuffs and the odd chip, 0.3 to 0.7 a wreck's paint flaking off round rust patches and runs, 1 rusted through. Worn
// sheet is crumpled too: dents from a bump through screen-space derivatives, none on a machine's paint.
// No UVs: the pattern lies on the plane the face looks along (the horizontal coordinate eased between x and z by the
// normal, faces looking up or down on the ground plane), from the world position ("scrap": every instanced wreck comes out
// different) or the model's own (`object_space`, "scrapm": what moves, so its rust doesn't slide through it). The fine
// detail fades to its average by the pixel's size in metres.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform bool object_space = false;
uniform vec3 rust_color : source_color = vec3(0.46, 0.22, 0.09);
uniform vec3 rust_dark : source_color = vec3(0.20, 0.10, 0.06);
// The size of the rust patches, in metres.
uniform float patch_size = 0.75;
// How deep the dents of worn sheet are (0: none).
uniform float crumple = 1.0;

varying vec3 ppos;
varying vec3 pnrm;

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

// The normal tipped by the gradient of a height h (metres) over the surface, from screen-space derivatives.
vec3 bump_normal(vec3 n, vec3 pos, float h, float k) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - k * grad);
}

void vertex() {
	if (object_space) {
		ppos = VERTEX;
		pnrm = NORMAL;
	} else {
		ppos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		pnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	}
}

void fragment() {
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	float wear = clamp(COLOR.a, 0.0, 1.0);
	vec3 n = normalize(pnrm);
	float fw = length(fwidth(ppos));
	float fine = 1.0 - smoothstep(0.02, 0.2, fw);
	float mid = 1.0 - smoothstep(0.1, 0.8, fw);
	// The plane the pattern lies on.
	float h = mix(ppos.x, ppos.z, smoothstep(-0.2, 0.2, abs(n.x) - abs(n.z)));
	vec2 q = vec2(h, ppos.y);
	float flat_face = step(0.72, abs(n.y));
	q = mix(q, ppos.xz, flat_face);
	vec2 pq = q / patch_size;
	float patches = vnoise(pq + 3.1) * 0.55 + vnoise(pq * 2.7 + 7.7) * 0.3 + mix(0.5, vnoise(pq * 7.9 + 1.9), mid) * 0.15;
	// Runs: long down the faces, narrow across (blotches on flat faces).
	vec2 sq = mix(vec2(q.x * 3.0, q.y * 0.3), q * 1.6, flat_face);
	float streak = vnoise(sq + 5.3);
	float speck = mix(0.5, vnoise(q * 31.0), fine);

	// Rust where the patches beat what is left of the paint: none at wear 0, all over at 1.
	float thr = 1.02 - wear * 1.04;
	float rv = patches + (streak - 0.5) * 0.22 + (speck - 0.5) * 0.12;
	float rmask = smoothstep(thr - 0.035, thr + 0.035, rv);
	// The flaking edge round each patch (primer and bare steel), and scratches through the paint.
	float edge = smoothstep(thr - 0.11, thr - 0.04, rv) * (1.0 - rmask);
	float sc = abs(fract(q.x * 2.3 + q.y * 0.7 + vnoise(q * 1.7) * 2.5) - 0.5);
	float scratch = (1.0 - smoothstep(0.0, 0.025, sc)) * fine * smoothstep(0.55, 0.8, vnoise(q * 1.1 + 11.0)) * smoothstep(0.04, 0.3, wear);
	// Chips in a machine's paint (wear 0.05 to 0.2): small, sharp, few.
	float chip = smoothstep(0.83, 0.86, vnoise(q * 9.0 + 3.0)) * mid * smoothstep(0.02, 0.12, wear);

	vec3 col = paint * (0.9 + 0.18 * speck);
	// Faded, chalky paint on old wrecks.
	col = mix(col, col * 0.72 + vec3(0.05), smoothstep(0.25, 0.9, wear) * 0.6 * vnoise(pq * 1.3 + 2.0));
	// Dirt down the faces.
	col *= 1.0 - 0.28 * smoothstep(0.45, 0.9, streak) * (0.35 + 0.65 * wear);
	vec3 bare = vec3(0.30, 0.30, 0.31) * (0.8 + 0.35 * speck);
	vec3 primer = vec3(0.36, 0.20, 0.15) * (0.85 + 0.3 * speck);
	float bm = max(max(edge * 0.85, scratch * 0.75), chip);
	col = mix(col, mix(primer, bare, step(0.5, vnoise(q * 4.0 + 6.0))), bm);
	vec3 rc = mix(rust_dark, rust_color, vnoise(pq * 3.3 + 4.0) * 0.8 + streak * 0.2) * (0.72 + 0.5 * speck);
	col = mix(col, rc, rmask);
	// Rust bleeding down from the patches on upright faces.
	float bleed = smoothstep(thr - 0.25, thr, vnoise(vec2(q.x * 2.2, q.y * 0.18 + 2.0) / patch_size)) * (1.0 - flat_face) * wear * 0.45;
	col = mix(col, rust_color * 0.8, bleed * (1.0 - rmask));
	ALBEDO = col;
	float ro = mix(0.48 + 0.25 * wear, 0.93, rmask);
	ro = mix(ro, 0.42, bm * (1.0 - rmask));
	ROUGHNESS = ro;
	METALLIC = mix(0.12, 0.0, rmask) + bm * 0.45 * (1.0 - rmask);
	// Dents: broad crumples on worn sheet.
	float bh = (vnoise(q * 1.4 + 2.0) * 0.6 + vnoise(q * 3.7 + 9.0) * 0.3 + vnoise(q * 9.0) * 0.1 * mid) * 0.045;
	float dent = crumple * smoothstep(0.22, 0.55, wear);
	NORMAL = bump_normal(NORMAL, VERTEX, bh, dent);
}
