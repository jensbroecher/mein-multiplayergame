shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Harbor Pier's quays (TerrainGenerator's harbor boxes, regenerate_harbor_pier.gd): everything is drawn from the
// world position and normal, because the piers, junctions and platforms are plain BoxMeshes whose own UVs are
// per face. `mode` picks the material:
//   0  quay: the top a cast concrete deck in slabs (expansion joints, tone per slab, tyre wear, oil and rust
//      stains); the sides a concrete quay wall, wet and green below the tide line, a crust of barnacles at it, rust
//      streaks running down from the coping; the underside dark and damp.
//   1  piles: concrete piles, green and black below the tide line, barnacled at it.
//   2  timber: the jump ramps, sawn planks across the run (gaps, nail rows, grey weathering), beams on the sides.
//   3  steel: the channel bridges and the skyway's rails: painted steel, chequer plate on what faces up, the paint
//      worn to rust on the edges and under the tide line.
//   4  barrier: the quays' crash barriers, concrete faced with yellow and black hazard chevrons, scuffed.
//   5  land: the shores round the harbour (regenerate_harbor_pier.gd's heightfield). COLOR.rgb tints it, COLOR.a says
//      paved (1: the quaysides, the terminal, the town's streets) or grown (0: grass, scrub and woods on the hills);
//      steep faces are bare earth and rock.
// Colours are written as sRGB and linearised here.

uniform int mode = 0;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// The water's surface and how far the wet reaches up from it (tide).
uniform float water_y = 1.55;
uniform float tide = 0.9;
uniform float slab = 6.0;
uniform float deck_y = 3.55;

varying vec3 w_pos;
varying vec3 w_nrm;

vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

// A line of width `w` (metres) at every multiple of `period` along x, faded to its average once it is under a pixel.
float grid_line(float x, float period, float w, float fw) {
	float d = abs(fract(x / period + 0.5) - 0.5) * period;
	float aa = max(fw, 1e-4);
	float l = 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, d);
	return mix(l, w / period, smoothstep(w * 0.6, w * 2.5, fw));
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

// The tide line and what grows under it, on any upright face: `v` is the height in metres.
void wet_band(float v, vec2 along, inout vec3 col, inout float rough, float fw) {
	float tide_top = water_y + tide + 0.25 * (vnoise(along * vec2(0.35, 0.0)) - 0.5);
	float wet = 1.0 - smoothstep(tide_top - 0.05, tide_top + 0.35, v);
	float slime = 1.0 - smoothstep(water_y + 0.15, tide_top - 0.1, v);
	float n = fbm(vec2(along.x * 1.7, v * 2.2));
	vec3 algae = mix(srgb(vec3(0.16, 0.20, 0.10)), srgb(vec3(0.08, 0.12, 0.07)), n);
	col = mix(col, col * 0.52, wet);
	col = mix(col, algae, slime * smoothstep(0.25, 0.6, n + 0.2));
	// Barnacles: a pale crust of dots in a band just under the tide line.
	float band = smoothstep(tide_top - 0.75, tide_top - 0.35, v) * (1.0 - smoothstep(tide_top - 0.1, tide_top + 0.05, v));
	vec2 cell = vec2(along.x, v) * 26.0;
	vec2 ci = floor(cell);
	vec2 cf = fract(cell) - 0.5 - (vec2(hash12(ci), hash12(ci + 3.1)) - 0.5) * 0.5;
	float dot_r = 0.18 + 0.2 * hash12(ci + 7.7);
	float barn = (1.0 - smoothstep(dot_r - 0.08, dot_r, length(cf))) * step(0.35, hash12(ci + 1.3));
	barn = mix(barn, 0.25, smoothstep(0.008, 0.03, fw));
	col = mix(col, srgb(vec3(0.58, 0.57, 0.52)), barn * band * 0.5);
	rough = mix(rough, 0.35, wet * (1.0 - band));
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float fw = length(fwidth(w_pos));
	vec3 col;
	float rough = 0.9;
	float spec = 0.4;
	float metal = 0.0;
	vec3 nmap = vec3(0.5, 0.5, 1.0);
	float nmap_depth = 0.0;
	bool up = n.y > 0.6;
	bool down = n.y < -0.6;
	// Along-the-face coordinate of an upright face (axis-aligned or not).
	vec2 hz = normalize(vec2(-n.z, n.x) + vec2(1e-5, 0.0));
	float u = dot(w_pos.xz, hz);
	float v = w_pos.y;

	if (mode == 0) {
		vec3 tex = texture(concrete_tex, w_pos.xz * 0.21).rgb;
		float lum = dot(tex, vec3(0.33));
		if (up) {
			vec2 p = w_pos.xz;
			vec2 sid = floor(p / slab);
			float tone = hash12(sid);
			col = srgb(vec3(0.60, 0.58, 0.54)) * (0.82 + 0.3 * lum) * (0.95 + 0.07 * tone);
			// Large patches of grime and cement wash.
			float patch = fbm(p * 0.045);
			col = mix(col, col * vec3(0.78, 0.76, 0.72), smoothstep(0.45, 0.75, patch));
			col = mix(col, col * 1.12, smoothstep(0.55, 0.8, fbm(p * 0.11 + 31.0)) * 0.6);
			// Oil and rust: a few stains per slab.
			vec2 sp = fract(p / slab) - 0.5;
			vec2 so = (vec2(hash12(sid + 5.0), hash12(sid + 9.0)) - 0.5) * 0.6;
			float stain = 1.0 - smoothstep(0.05, 0.22 + 0.1 * hash12(sid + 2.0), length((sp - so) * vec2(1.0, 1.4)) + 0.12 * vnoise(p * 1.3));
			stain *= step(0.62, hash12(sid + 11.0));
			vec3 oil = srgb(vec3(0.20, 0.19, 0.18));
			vec3 rust = srgb(vec3(0.42, 0.26, 0.15));
			col = mix(col, mix(oil, rust, step(0.8, hash12(sid + 4.0))), stain * 0.55);
			// Tyre polish: smoother, darker streaks along the quays' long axes.
			float wear = smoothstep(0.55, 0.85, vnoise(vec2(p.x * 0.08, p.y * 1.4))) + smoothstep(0.55, 0.85, vnoise(vec2(p.x * 1.4, p.y * 0.08)));
			col *= 1.0 - 0.07 * clamp(wear, 0.0, 1.0);
			rough = mix(0.9, 0.62, clamp(wear, 0.0, 1.0) * 0.6 + stain * 0.4);
			// Expansion joints: sealed dark lines between the slabs, a saw cut halfway along each.
			float joint = max(grid_line(p.x, slab, 0.035, fw), grid_line(p.y, slab, 0.035, fw));
			float cut = max(grid_line(p.x + slab * 0.5, slab, 0.012, fw), grid_line(p.y + slab * 0.5, slab, 0.012, fw)) * 0.6;
			col *= 1.0 - 0.6 * joint - 0.35 * cut;
			nmap = texture(concrete_nrm, p * 0.21).rgb;
			nmap_depth = 0.55;
		} else if (down) {
			col = srgb(vec3(0.20, 0.21, 0.20)) * (0.8 + 0.3 * lum);
			rough = 0.95;
		} else {
			vec2 p = vec2(u, v);
			col = srgb(vec3(0.55, 0.54, 0.50)) * (0.8 + 0.32 * texture(concrete_tex, p * 0.25).r);
			// Shuttering: horizontal board lines and the lift joints of the pour.
			col *= 1.0 - 0.08 * grid_line(v, 0.3, 0.02, fw) - 0.2 * grid_line(u, 4.0, 0.03, fw);
			// Rust streaks from the coping's fittings.
			float streak = smoothstep(0.7, 0.95, vnoise(vec2(u * 2.2, 0.0))) * smoothstep(0.0, 1.5, v - water_y) * (0.4 + 0.6 * vnoise(vec2(u * 6.0, v * 0.6)));
			col = mix(col, srgb(vec3(0.40, 0.26, 0.17)), streak * 0.4);
			// The coping: the top 0.3m a paler cast band with a worn yellow safety edge.
			// Only on the quays' own walls (their tops at deck height): the breakwaters' crown walls stand higher.
			float at_edge = 1.0 - smoothstep(deck_y + 0.005, deck_y + 0.02, v);
			float top = smoothstep(-0.32, -0.30, v - deck_y) * at_edge;
			col = mix(col, srgb(vec3(0.66, 0.64, 0.60)), top);
			float paint = smoothstep(-0.13, -0.11, v - deck_y) * at_edge * step(0.25, vnoise(vec2(u * 0.9, 3.0)) + 0.2);
			col = mix(col, srgb(vec3(0.86, 0.66, 0.12)), paint * 0.85);
			wet_band(v, vec2(u, v), col, rough, fw);
			nmap = texture(concrete_nrm, p * 0.25).rgb;
			nmap_depth = 0.4;
		}
	} else if (mode == 1) {
		col = srgb(vec3(0.50, 0.49, 0.46)) * (0.75 + 0.35 * texture(concrete_tex, vec2(u, v) * 0.4).r);
		wet_band(v, vec2(u + w_pos.x * 3.1, v), col, rough, fw);
		col *= 1.0 - 0.25 * smoothstep(water_y + 0.2, water_y - 1.0, v);
	} else if (mode == 2) {
		// Planks across the run: the ramps run along x, so a plank is a band of x.
		vec2 p = up || down ? w_pos.xz : vec2(u, v);
		float plank_w = 0.28;
		float along = up ? w_pos.x : u;
		float pid = floor(along / plank_w);
		float tone = hash12(vec2(pid, 3.0));
		vec3 wood = mix(srgb(vec3(0.46, 0.36, 0.25)), srgb(vec3(0.56, 0.50, 0.42)), tone);
		float grain = vnoise(vec2(pid * 13.0, (up ? w_pos.z : v) * 4.0)) * 0.5 + vnoise(vec2(pid * 7.0, (up ? w_pos.z : v) * 19.0)) * 0.5;
		col = wood * (0.78 + 0.32 * grain);
		// Grey weathering, heavier toward the planks' ends and where the carts don't run.
		col = mix(col, srgb(vec3(0.50, 0.49, 0.46)), 0.3 * fbm(p * 0.35));
		float gap = grid_line(along, plank_w, 0.018, fw);
		col *= 1.0 - 0.7 * gap;
		// Nails: two rows of dark dots on each plank over the stringers.
		if (up) {
			float across = w_pos.z;
			vec2 q = vec2(fract(along / plank_w) - 0.5, fract(across / 1.2) - 0.5);
			float nail = 1.0 - smoothstep(0.012, 0.022, length(vec2(abs(q.x * plank_w) - 0.07, q.y * 1.2)));
			col = mix(col, srgb(vec3(0.12, 0.11, 0.10)), nail * (1.0 - smoothstep(0.004, 0.02, fw)));
		}
		rough = 0.85;
		wet_band(v, vec2(u, v), col, rough, fw);
	} else if (mode == 3) {
		vec3 paint = srgb(vec3(0.22, 0.30, 0.34));
		col = paint;
		metal = 0.35;
		rough = 0.5;
		vec2 p = up ? w_pos.xz : vec2(u, v);
		if (up) {
			// Chequer plate: raised diamond lugs in a herringbone.
			vec2 q = p * 3.2;
			vec2 qi = floor(q);
			vec2 qf = fract(q) - 0.5;
			float flip = mod(qi.x + qi.y, 2.0);
			vec2 r = flip > 0.5 ? vec2(qf.x + qf.y, qf.x - qf.y) : vec2(qf.x - qf.y, qf.x + qf.y);
			float lug = 1.0 - smoothstep(0.08, 0.12, abs(r.y)) ;
			lug *= 1.0 - smoothstep(0.32, 0.36, abs(r.x));
			lug = mix(lug, 0.2, smoothstep(0.03, 0.1, fw));
			col = mix(srgb(vec3(0.34, 0.35, 0.36)), srgb(vec3(0.52, 0.53, 0.54)), lug);
			metal = 0.6;
			rough = mix(0.55, 0.32, lug);
			// Paint left round the edges, worn away down the middle.
			col = mix(col, paint, 0.35 * fbm(p * 0.3));
		} else {
			float wear = smoothstep(0.62, 0.82, fbm(p * 0.8));
			col = mix(paint, srgb(vec3(0.36, 0.20, 0.11)), wear * 0.8);
			rough = mix(0.5, 0.85, wear);
			wet_band(v, vec2(u, v), col, rough, fw);
		}
	} else if (mode == 5) {
		vec3 tint = pow(COLOR.rgb, vec3(2.2));
		float paved = smoothstep(0.0, 0.5, COLOR.a);
		float slabs = smoothstep(0.5, 1.0, COLOR.a);
		vec2 p = w_pos.xz;
		float lum = texture(concrete_tex, p * 0.13).r;
		// Paved: asphalt with patches and the odd seam, concrete toward the quays.
		vec3 asphalt = srgb(vec3(0.30, 0.30, 0.31)) * (0.8 + 0.35 * lum);
		asphalt = mix(asphalt, asphalt * 1.25, smoothstep(0.55, 0.8, fbm(p * 0.03)) * 0.5);
		asphalt *= 1.0 - 0.3 * max(grid_line(p.x, 12.0, 0.05, fw), grid_line(p.y, 12.0, 0.05, fw));
		// Grown: grass, drier on the rises, darker in the woods' clumps (the far hills read as wooded).
		float g = fbm(p * 0.02);
		vec3 grass = mix(srgb(vec3(0.30, 0.38, 0.17)), srgb(vec3(0.45, 0.44, 0.24)), smoothstep(0.45, 0.7, g));
		float woods = smoothstep(0.48, 0.62, fbm(p * 0.006 + 13.0));
		grass = mix(grass, srgb(vec3(0.11, 0.17, 0.08)) * (0.8 + 0.4 * fbm(p * 0.25)), woods);
		grass *= 0.85 + 0.3 * vnoise(p * 0.7);
		// Concrete slabs on the quaysides and the terminal's yard, joints every 6m.
		vec3 conc = srgb(vec3(0.62, 0.61, 0.57)) * (0.8 + 0.3 * lum) * (0.94 + 0.08 * hash12(floor(p / slab)));
		conc *= 1.0 - 0.5 * max(grid_line(p.x, slab, 0.04, fw), grid_line(p.y, slab, 0.04, fw));
		conc = mix(conc, conc * vec3(0.8, 0.78, 0.74), smoothstep(0.5, 0.8, fbm(p * 0.04)) * 0.6);
		asphalt = mix(asphalt, conc, slabs);
		col = mix(grass, asphalt, paved) * tint;
		float steep = 1.0 - smoothstep(0.55, 0.8, n.y);
		col = mix(col, srgb(vec3(0.42, 0.38, 0.32)) * (0.75 + 0.4 * lum), steep);
		rough = mix(0.95, 0.85, paved);
	} else {
		// Barrier: chevrons along the run.
		vec2 p = vec2(u, v);
		float stripe = step(0.5, fract((u + v * 0.9) / 1.1));
		vec3 yellow = srgb(vec3(0.92, 0.70, 0.10));
		vec3 black = srgb(vec3(0.07, 0.07, 0.07));
		col = mix(yellow, black, stripe);
		if (up) {
			col = srgb(vec3(0.62, 0.60, 0.56)) * (0.8 + 0.3 * texture(concrete_tex, w_pos.xz * 0.3).r);
		}
		// Scuffs and cart rubber low down, chips showing the concrete.
		float scuff = smoothstep(0.6, 0.85, fbm(p * vec2(1.3, 3.0))) * (1.0 - smoothstep(3.6, 4.5, v));
		col = mix(col, srgb(vec3(0.55, 0.54, 0.50)), scuff * 0.7);
		float rub = smoothstep(0.72, 0.9, vnoise(vec2(u * 0.6, v * 9.0))) * (1.0 - smoothstep(4.0, 4.4, v));
		col = mix(col, black, rub * 0.5);
		rough = 0.7;
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	// The concrete's normal map tipped onto the face in world space: the skyway's deck is a SurfaceTool mesh with no
	// tangents, so NORMAL_MAP would read garbage there.
	if (nmap_depth > 0.0) {
		vec2 t = (nmap.xy * 2.0 - 1.0) * nmap_depth;
		vec3 wn = up ? normalize(n + vec3(t.x, 0.0, t.y)) : normalize(n + vec3(hz.x, 0.0, hz.y) * t.x + vec3(0.0, t.y, 0.0));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}
