// Painted steel on the Rhine's ships and river furniture (RheinShipKit.gd: keys "hull", "paint", "white", "deck").
// The vertex colour is the paint (sRGB). Patterns lie in the mesh's own space, in life metres (VERTEX / `unit`, the kit's
// scale): the ships move (SeaBoat.gd), and in world space the rust and grime would slide over them.
//   hull_uv (the hull's loft, key "hull"): UV is (metres along the ship, metres over the waterline), life size. A band of
//     river scum along the waterline, scrapes where the ship lay against quays and lock walls, rust runs down the side.
//   deck: walked-on deck paint, worn lighter along the middle of the gangboards, oil and dirt in blotches.
// Faces turned up or down take the pattern on the horizontal plane, walls on the vertical plane they face; streaks run
// straight down. Everything fine fades to its mean once it is under a pixel (fwidth), so far ships don't shimmer.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float unit = 1.6;
uniform bool hull_uv = false;
uniform bool deck = false;
uniform float rust_amount : hint_range(0.0, 1.0) = 0.2;
uniform float grime : hint_range(0.0, 1.0) = 0.35;
uniform float rough = 0.5;
uniform float metal = 0.12;
uniform vec3 rust_color : source_color = vec3(0.40, 0.18, 0.08);
uniform vec3 scum_color : source_color = vec3(0.20, 0.19, 0.13);
// The patches' size, life metres.
uniform float patch_size = 2.5;

varying vec3 lpos;
varying vec3 lnrm;

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
	lpos = VERTEX / unit;
	lnrm = NORMAL;
}

void fragment() {
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	vec3 n = normalize(lnrm);
	float flat_face = step(0.72, abs(n.y));
	float h = mix(lpos.x, lpos.z, smoothstep(-0.2, 0.2, abs(n.x) - abs(n.z)));
	vec2 q = mix(vec2(h, lpos.y), lpos.xz, flat_face);
	float over_wl = lpos.y;
	if (hull_uv) {
		q = UV;
		over_wl = UV.y;
		flat_face = 0.0;
	}
	// The pixel's size in life metres, taken outside any branch.
	float fw = length(fwidth(q));
	float fine = 1.0 - smoothstep(0.03, 0.25, fw);
	float mid = 1.0 - smoothstep(0.2, 1.2, fw);
	vec2 pq = q / patch_size;
	float patches = vnoise(pq + 3.1) * 0.65 + vnoise(pq * 3.1 + 7.7) * 0.35;
	vec2 sq = mix(vec2(q.x * 2.4, q.y * 0.12), q * 0.7, flat_face);
	float streak = mix(0.5, vnoise(sq + 1.3), mid);
	float speck = mix(0.5, vnoise(q * 9.0), fine);

	vec3 col = paint * (0.93 + 0.14 * speck);
	// Grime: streaks down the walls, blotches on flat faces.
	float g = grime * smoothstep(0.35, 0.95, streak * 0.75 + patches * 0.35);
	col *= 1.0 - 0.45 * g;
	// Rust: patches out of the streaks, and runs.
	float r = rust_amount * smoothstep(0.58, 0.88, patches + streak * 0.25 - 0.1 + speck * 0.08);
	vec3 rc = rust_color * (0.75 + 0.5 * speck) * (0.85 + 0.3 * patches);
	float ro = rough;
	float me = metal;
	if (hull_uv) {
		// Scum along the waterline: a brownish band to 0.25-0.45m up, its top ragged, darkest at the water.
		float top = 0.26 + 0.18 * vnoise(vec2(q.x * 0.45, 2.0)) + 0.05 * speck;
		float sc = (1.0 - smoothstep(top - 0.14, top, over_wl)) * smoothstep(-0.6, -0.2, over_wl);
		col = mix(col, scum_color * (0.75 + 0.35 * speck), sc * (0.45 + 0.35 * (1.0 - smoothstep(0.0, top, over_wl))));
		// Scrapes along the side at fender height: long scratches where the paint has gone to rust and bare steel.
		float sline = vnoise(vec2(q.x * 0.22, q.y * 7.0)) * vnoise(vec2(q.x * 0.05 + 4.0, 1.0));
		float scr = smoothstep(0.5, 0.66, sline) * smoothstep(0.15, 0.5, over_wl) * mid;
		col = mix(col, mix(rust_color * 0.7, vec3(0.12, 0.12, 0.12), step(0.5, speck)), scr * 0.45 * clamp(rust_amount * 2.5, 0.0, 1.0));
		// Rust runs from the deck edge, narrow and long.
		float run = smoothstep(0.7, 0.92, vnoise(vec2(q.x * 3.1, 0.5))) * smoothstep(-0.2, 1.4, over_wl) * mid;
		r = max(r, run * rust_amount * 1.4);
		ro = mix(ro, 0.85, sc);
	}
	if (deck) {
		// Worn paths: lighter, rougher where boots walk; dark oil blotches; the non-slip grit.
		float worn = smoothstep(0.45, 0.8, vnoise(q * 0.35 + 11.0));
		col = mix(col, col * 1.25 + vec3(0.02), worn * 0.35);
		float oil = smoothstep(0.72, 0.9, vnoise(q * 0.6 + 5.0));
		col *= 1.0 - 0.4 * oil * grime;
		ro = mix(ro, 0.95, worn * 0.5);
	}
	col = mix(col, rc, clamp(r, 0.0, 1.0));
	ro = mix(ro, 0.9, r);
	me = mix(me, 0.05, r);
	ALBEDO = col;
	ROUGHNESS = ro;
	METALLIC = me;
}
