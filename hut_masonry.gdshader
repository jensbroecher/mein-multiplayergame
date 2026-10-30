shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Stone, plaster and brick for the Msitu Falls ranger post (RangerPostBuilder.gd). UV is in world
// metres; the vertex colour is the tint (the plaster's colour, the brick's red).
//   0  rubble stone: irregular blocks with mortar between, mossy at the foot
//   1  lime-washed plaster: mottled, hairline cracks, splashed with mud toward the ground (v = 0)
//   2  brick in running bond, sooted toward the top of a chimney
//   3  desert adobe mud-plaster: sun-baked plaster with flaked patches exposing stone cobbles
//   4  Mediterranean whitewashed stucco: bright plaster with subtle trowel mottle and hairline cracks
//   5  Spanish terracotta barrel tiles (tejas): half-round ribs along u, lapped courses along v
//   6  alpine slate / stone shingles (Ridgecrest's chalets): staggered courses up v, lichen and wear
//   7  standing-seam zinc (Ridgecrest's modern houses): flat pans along v between raised seams across u
//   8  board-formed concrete: smooth grey with the shuttering's board lines along u and tie holes

uniform int style = 0;

// Colours below are written as sRGB and linearised here.
vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

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
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Voronoi: x the distance to the nearest cell border, y the cell's id (0..1).
vec2 voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash22(n + g) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + hash22(n + g) - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec2(md, hash12(n + mg));
}

void fragment() {
	vec2 q = UV;
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	vec3 col = tint;
	float rough = 0.9;

	if (style == 0) {
		// Flat-ish stones, wider than they are tall, about a third of a metre.
		vec2 vc = voronoi(vec2(q.x / 0.62, q.y / 0.40));
		float mortar = 1.0 - smoothstep(0.02, 0.09, vc.x);
		float tone = 0.62 + 0.55 * vc.y + 0.2 * (vnoise(q * 9.0) - 0.5);
		vec3 stone = mix(srgb(vec3(0.52, 0.47, 0.40)), srgb(vec3(0.40, 0.38, 0.36)), fract(vc.y * 7.0));
		col = stone * tone * mix(vec3(1.0), tint, 0.5);
		// Round the stones' faces: darker toward their edges.
		col *= 0.78 + 0.22 * smoothstep(0.02, 0.2, vc.x);
		col = mix(col, srgb(vec3(0.30, 0.28, 0.25)), mortar * 0.85);
		// Moss and mud near the foot.
		float foot = 1.0 - smoothstep(0.1, 0.9, q.y);
		float moss = smoothstep(0.45, 0.7, vnoise(q * 3.0 + 4.0)) * foot;
		col = mix(col, srgb(vec3(0.28, 0.40, 0.20)), moss * 0.6);
		rough = 0.95;
	} else if (style == 1) {
		float mottle = vnoise(q * 2.2 + 3.0) * 0.55 + vnoise(q * 7.5) * 0.3 + vnoise(q * 21.0) * 0.15;
		col = tint * (0.7 + 0.35 * mottle);
		// Hairline cracks.
		vec2 vc = voronoi(q * 1.6 + 5.0);
		float crack = 1.0 - smoothstep(0.0, 0.018, vc.x);
		col *= 1.0 - crack * 0.12;
		// Mud splashed up from the ground, and a few patches where the wash has gone.
		float splash = (1.0 - smoothstep(0.0, 0.55 + 0.4 * vnoise(vec2(q.x * 2.0, 1.0)), q.y));
		col = mix(col, srgb(vec3(0.45, 0.33, 0.22)), splash * 0.7);
		float bare = smoothstep(0.72, 0.84, vnoise(q * 1.3 + 21.0));
		col = mix(col, srgb(vec3(0.50, 0.34, 0.24)), bare * 0.45);
		// Rain streaks down from the roof.
		col *= 1.0 - 0.18 * smoothstep(0.55, 0.85, vnoise(vec2(q.x * 3.0, q.y * 0.2)));
		rough = 0.95;
	} else if (style == 2) {
		// Running bond: courses of 7cm, bricks of 22cm, in world metres at 1.6x.
		float bh = 0.12;
		float bwid = 0.37;
		float row = floor(q.y / bh);
		float bx = q.x / bwid + 0.5 * mod(row, 2.0);
		float fx = fract(bx);
		float fy = fract(q.y / bh);
		float id = hash12(vec2(floor(bx), row));
		float mortar = 1.0 - smoothstep(0.0, 0.07, min(min(fx, 1.0 - fx) * bwid, min(fy, 1.0 - fy) * bh));
		vec3 brick = tint * (0.7 + 0.5 * id) * (0.9 + 0.2 * vnoise(q * 25.0));
		col = mix(brick, srgb(vec3(0.62, 0.59, 0.53)), mortar * 0.8);
		// Soot toward the top, where the smoke comes out.
		col *= 1.0 - 0.45 * smoothstep(0.55, 1.0, vnoise(vec2(q.x * 2.0, 3.0)) * 0.4 + 0.6 * smoothstep(0.0, 6.0, q.y) );
		rough = 0.9;
	} else if (style == 3) {
		// Desert adobe mud-plaster with weathered patches exposing stone cobbles underneath.
		float mottle = vnoise(q * 0.55 + 2.1) * 0.55 + vnoise(q * 2.1 + 7.3) * 0.30 + vnoise(q * 7.5) * 0.15;
		float warm_drift = vnoise(q * 0.22 + 4.8);
		vec3 plaster = tint * mix(vec3(0.95, 0.91, 0.86), vec3(1.04, 1.00, 0.94), warm_drift) * (0.86 + 0.22 * mottle);
		// Flaked patches revealing pale desert cobbles in recessed mortar (confined to flat wall interiors via COLOR.a).
		float patch_n = vnoise(q * 0.24 + vec2(11.3, 5.7)) * 0.65 + vnoise(q * 0.72 + 3.1) * 0.35;
		float patch_mask = smoothstep(0.67, 0.73, patch_n) * COLOR.a;
		float rim = smoothstep(0.63, 0.67, patch_n) * (1.0 - patch_mask) * COLOR.a;
		vec2 warp = vec2(vnoise(q * 1.1 + 1.3), vnoise(q * 1.1 + 6.7)) - 0.5;
		vec2 vc_stone = voronoi(vec2(q.x / 0.85, q.y / 0.62) + warp * 0.42 + 9.0);
		float mortar = 1.0 - smoothstep(0.03, 0.12, vc_stone.x);
		vec3 cobble = mix(srgb(vec3(0.91, 0.85, 0.73)), srgb(vec3(0.79, 0.71, 0.58)), vc_stone.y);
		cobble *= 0.86 + 0.14 * smoothstep(0.03, 0.24, vc_stone.x);
		vec3 exposed = mix(cobble, srgb(vec3(0.54, 0.45, 0.35)), mortar * 0.72);
		col = mix(plaster * (1.0 - rim * 0.16), exposed, patch_mask);
		// Subtle warm ground dust at the foot and streaks from the parapets.
		float foot = 1.0 - smoothstep(0.0, 1.4, q.y);
		col = mix(col, srgb(vec3(0.62, 0.50, 0.38)), foot * 0.22);
		col *= 1.0 - 0.08 * smoothstep(0.55, 0.85, vnoise(vec2(q.x * 0.7, q.y * 0.08 + 1.7)));
		rough = 0.94;
	} else if (style == 4) {
		// Mediterranean whitewashed stucco: bright plaster with fine trowel texture.
		float mottle = vnoise(q * 0.7 + 1.3) * 0.5 + vnoise(q * 2.8) * 0.35 + vnoise(q * 9.5) * 0.15;
		col = tint * (0.92 + 0.11 * mottle);
		float foot = 1.0 - smoothstep(0.0, 0.9, q.y);
		col = mix(col, srgb(vec3(0.72, 0.64, 0.55)), foot * 0.18);
		rough = 0.92;
	} else if (style == 6) {
		// Slate shingles: u along the ridge, v up the slope; courses of 0.22m, each tile 0.3-0.45m wide,
		// every course offset, the lower edge of each a shadowed lip.
		float course = 0.22;
		float row = floor(q.y / course);
		float rf = fract(q.y / course);
		float tw = 0.3 + 0.15 * hash12(vec2(row, 3.0));
		float tx = q.x / tw + 0.5 * mod(row, 2.0) + hash12(vec2(row, 9.0));
		float tid = hash12(vec2(floor(tx), row));
		float tf = fract(tx);
		vec3 slate = tint * (0.78 + 0.34 * tid) * (0.9 + 0.2 * vnoise(q * 11.0));
		float joint = 1.0 - smoothstep(0.0, 0.06, min(tf, 1.0 - tf));
		float lip = 1.0 - smoothstep(0.0, 0.16, rf);
		col = slate * (1.0 - 0.35 * joint) * (1.0 - 0.32 * lip);
		// Pale lichen and a few chipped corners.
		float lichen = smoothstep(0.66, 0.8, vnoise(q * 1.7 + 8.0)) * smoothstep(0.4, 0.7, vnoise(q * 9.0));
		col = mix(col, srgb(vec3(0.62, 0.64, 0.50)), lichen * 0.4);
		rough = 0.78;
		NORMAL_MAP = normalize(vec3(0.0, -0.6 * lip, 1.0)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 1.0;
	} else if (style == 7) {
		// Standing seam: pans 0.5m wide across u, a raised seam between, faint oil-canning along v.
		float pan = 0.5;
		float f = fract(q.x / pan);
		float seam = 1.0 - smoothstep(0.0, 0.035, min(f, 1.0 - f));
		col = tint * (0.92 + 0.12 * vnoise(vec2(floor(q.x / pan) * 3.1, q.y * 0.4)));
		col *= 1.0 + 0.35 * seam;
		col *= 1.0 - 0.12 * smoothstep(0.6, 1.0, vnoise(vec2(q.x * 0.5, q.y * 0.15)));
		rough = mix(0.42, 0.3, seam);
		METALLIC = 0.6;
		float side = (f < 0.5) ? 1.0 : -1.0;
		NORMAL_MAP = normalize(vec3(side * seam * 0.9, 0.0, 1.0)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 1.0;
	} else if (style == 8) {
		// Board-formed concrete: boards 0.15m tall along u, a joint between them, tie holes on a grid.
		float bh = 0.15;
		float row = floor(q.y / bh);
		float f = fract(q.y / bh);
		float joint = 1.0 - smoothstep(0.0, 0.06, min(f, 1.0 - f));
		col = tint * (0.86 + 0.12 * hash12(vec2(row, 1.0)) + 0.1 * vnoise(vec2(q.x * 1.5, row * 2.0)));
		col *= 0.92 + 0.12 * vnoise(q * 6.0);
		col *= 1.0 - 0.18 * joint;
		vec2 tie = fract(q / vec2(0.9, 0.6)) - 0.5;
		col *= 1.0 - 0.45 * (1.0 - smoothstep(0.012, 0.022, length(tie * vec2(0.9, 0.6))));
		// Rain streaks.
		col *= 1.0 - 0.1 * smoothstep(0.55, 0.85, vnoise(vec2(q.x * 2.5, q.y * 0.15)));
		rough = 0.85;
	} else {
		// Spanish terracotta barrel tiles (tejas): u across the slope, v up the slope.
		float pitch = 0.42;
		float course_h = 0.62;
		float cid = floor(q.x / pitch);
		float cf = fract(q.x / pitch);
		float rid = floor(q.y / course_h);
		float rf = fract(q.y / course_h);
		float ph = cf * TAU;
		float rib = 0.5 + 0.5 * sin(ph - PI * 0.5);
		float slope = cos(ph - PI * 0.5);
		float tile_id = hash12(vec2(cid, rid));
		float tile_id2 = hash12(vec2(cid + 19.3, rid + 7.1));
		// Blend warm terracotta, sun-bleached buff clay, and deeper sienna per tile.
		vec3 clay_a = tint * (0.82 + 0.32 * tile_id);
		vec3 clay_b = srgb(vec3(0.76, 0.58, 0.44)) * (0.85 + 0.25 * tile_id2);
		vec3 tile_col = mix(clay_a, clay_b, smoothstep(0.25, 0.85, tile_id2) * 0.55);
		// Fine clay grain and weathering along the barrel.
		float grain = vnoise(vec2(q.x * 14.0, q.y * 6.0)) * 0.6 + vnoise(q * 2.2) * 0.4;
		tile_col *= 0.86 + 0.26 * grain;
		// Shading in the troughs between barrels and under each course overlap lip.
		float lap = 1.0 - smoothstep(0.0, 0.11, rf);
		float trough = 1.0 - rib;
		col = tile_col * (0.68 + 0.38 * rib) * (1.0 - 0.38 * lap) * (1.0 - 0.18 * trough * trough);
		rough = 0.84;
		vec3 n = normalize(vec3(-0.75 * slope, -0.35 * lap, 1.0));
		NORMAL_MAP = n * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 1.0;
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
}
