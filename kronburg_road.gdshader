// Kronburger Hütte's roads (regenerate_kronburg.gd, _build_roads): every surface the lap runs on, laid as ribbons a few
// centimetres over the graded ground, plus the market square's paving. UV: x metres right of the lap's line, y metres
// along it. UV2.x the kind, UV2.y the carriageway's half width (the ribbon may be wider: pavements):
//   0 country road: German markings (a dashed centre line, 6m in 18m, solid edge lines), a gravel shoulder strip
//   1 the old town's cobbles: setts laid in segmental arcs (Bogenpflaster), a gutter of three rows of small setts,
//     granite kerbs, sandstone flag pavements beyond the half width
//   2 the colliery estate's street: asphalt, granite kerbs and a sett gutter, grey 30cm concrete flag pavements
//   3 the works' roads: concrete slabs with joints, rust-red ore dust, oil, yellow edge lines
//   4 the rolling mill's floor: dark trowelled concrete, steel scale, yellow walkway lines and a dashed centre line
//   5 the market square: big granite setts in arcs laid in world space, bands of dark basalt every 12m
//   6 the canal's towpath (Leinpfad): fine pale gravel, two worn wheel tracks, grassy edges (dressing only, no collider)
//   7 Autobahn (Rheinufer): a carriageway of three lanes and a hard shoulder, UV.x right of its own travel: a solid
//     inner edge line by the median, 6m-in-18m lane lines, the broad solid line before the shoulder; ramps (half
//     width under 6m) get an edge line each side
//   8 town street asphalt (Rheinufer's old bridge): a sett gutter strip, narrow edge lines, a 3m-in-9m centre line
// COLOR.r is the distance to where the kind changes (metres / 4, 1 past 4m): a granite threshold across the road.
// The vertices are pulled toward the eye along their own rays (as the skid marks are), so each ribbon wins the depth
// test against the ground under it at any distance. Patterns come from floor() of world positions and UVs only.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sett_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sett_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 w_pos;
varying vec3 w_nrm;
varying flat int v_kind;
varying float v_half;
varying float v_edge;

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Coverage of a line `w` wide at signed distance `d`: the share of a pixel `aa` wide (box filtered) it covers, so a
// line thinner than a pixel fades out to its share at the line and to nothing beside it.
float stripe(float d, float w, float aa) {
	aa = max(aa, 1e-4);
	float lo = max(d - aa * 0.5, -w * 0.5);
	float hi = min(d + aa * 0.5, w * 0.5);
	return clamp((hi - lo) / aa, 0.0, 1.0);
}

// Setts laid in segmental arcs: arcs `aw` wide, rows `rh` deep following the arc, stones about `sw` long.
// p.x across, p.y along. Returns (stone id, joint coverage).
vec2 arc_setts(vec2 p, float aw, float rise, float rh, float sw, float fw) {
	float cell = floor(p.x / aw);
	float u = fract(p.x / aw) - 0.5;
	float v = p.y + rise * 4.0 * u * u;
	float row = floor(v / rh);
	float fv = fract(v / rh);
	float s = u * aw * (1.0 + 2.0 * rise * abs(u) / aw) + hash12(vec2(row, cell)) * sw;
	float ci = floor(s / sw);
	float fs = fract(s / sw);
	float id = hash12(vec2(ci + cell * 37.0, row));
	float jd = min(min(fv, 1.0 - fv) * rh, min(fs, 1.0 - fs) * sw);
	jd = min(jd, (0.5 - abs(u)) * aw);
	float joint = 1.0 - smoothstep(0.004, 0.011 + fw * 0.5, jd);
	// Once a stone is under a few pixels the joints fade to their share.
	joint = mix(joint, 0.28, smoothstep(sw * 0.15, sw * 0.6, fw));
	return vec2(id, joint);
}

// Granite kerb stones along an edge: blocks a metre long.
vec3 kerb(float y, float side, float fw) {
	float row = floor(y / 1.0);
	float h = hash12(vec2(row, side * 7.0));
	vec3 c = mix(lin(vec3(0.56, 0.56, 0.55)), lin(vec3(0.66, 0.65, 0.62)), h);
	float joint = stripe((fract(y + 0.5) - 0.5), 0.02, fw);
	return c * mix(1.0, 0.6, joint);
}

// Concrete flags (Gehwegplatten) `size` square, grey, a few cracked and darker.
vec3 flags(vec2 p, float size, vec3 base, float fw) {
	vec2 g = p / size;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = hash12(id);
	vec3 c = base * (0.88 + 0.2 * h);
	float jd = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * size;
	float joint = 1.0 - smoothstep(0.003, 0.008 + fw * 0.5, jd);
	joint = mix(joint, 0.1, smoothstep(size * 0.1, size * 0.4, fw));
	return c * (1.0 - 0.4 * joint);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_kind = int(UV2.x + 0.5);
	v_half = UV2.y;
	v_edge = COLOR.r * 4.0;
	vec3 view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(view);
	view *= max(d - (0.03 + d * 0.0015), 0.0) / max(d, 1e-4);
	POSITION = PROJECTION_MATRIX * vec4(view, 1.0);
}

void fragment() {
	vec2 xz = w_pos.xz;
	float fw = length(fwidth(w_pos));
	float x = UV.x;
	float ax = abs(x);
	float y = UV.y;
	float fx = max(fwidth(x), 1e-4);
	float fy = max(fwidth(y), 1e-4);
	float half_w = v_half;
	vec3 col = vec3(0.1);
	float rough = 0.7;
	float spec = 0.45;
	vec3 nw = normalize(w_nrm);
	vec3 tex_c = texture(concrete_tex, xz * 0.25).rgb;

	if (v_kind == 1 || v_kind == 5) {
		// Cobbles: setts in segmental arcs (the square's in world space, bigger, with pale bands).
		vec2 p = v_kind == 5 ? vec2(xz.x, xz.y) : vec2(x, y);
		vec2 st = v_kind == 5 ? arc_setts(p, 2.0, 0.42, 0.13, 0.13, fw) : arc_setts(p, 1.6, 0.34, 0.105, 0.105, fw);
		vec3 sett = mix(lin(vec3(0.40, 0.39, 0.38)), lin(vec3(0.56, 0.53, 0.50)), st.x);
		sett = mix(sett, lin(vec3(0.52, 0.44, 0.38)), step(0.86, st.x) * 0.7);
		sett *= mix(vec3(1.0), texture(sett_tex, xz * 0.9).rgb / 0.42, 0.35);
		sett *= 0.88 + 0.2 * vnoise(xz * 0.12);
		col = mix(sett, lin(vec3(0.15, 0.14, 0.13)), st.y);
		rough = mix(0.62, 0.9, st.y);
		vec3 sn = texture(sett_normal, xz * 0.9).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(sn.x, 0.0, sn.y) * 0.35);
		if (v_kind == 5) {
			// Bands of dark basalt setts every 12m both ways, as the square's old drainage lines.
			float band = max(stripe(fract(xz.x / 12.0 + 0.5) * 12.0 - 6.0, 0.36, fw), stripe(fract(xz.y / 12.0 + 0.5) * 12.0 - 6.0, 0.36, fw));
			col = mix(col, lin(vec3(0.27, 0.26, 0.25)) * (0.85 + 0.3 * hash12(floor(xz * 3.0))), band * 0.85);
		} else {
			// The gutter: three rows of small setts along the edge, then the kerb, then sandstone flags.
			float gut = smoothstep(half_w - 0.62, half_w - 0.58, ax) * (1.0 - smoothstep(half_w - 0.02, half_w + 0.02, ax));
			float grow_ = floor(ax / 0.18);
			float gcol = floor(y / 0.16 + 0.5 * mod(grow_, 2.0));
			vec3 gc = mix(lin(vec3(0.34, 0.33, 0.32)), lin(vec3(0.46, 0.45, 0.43)), hash12(vec2(gcol, grow_ + sign(x) * 9.0)));
			float gj = max(stripe(fract(ax / 0.18 + 0.5) * 0.18 - 0.09, 0.012, fw), stripe(fract(y / 0.16 + 0.5 * mod(grow_, 2.0) + 0.5) * 0.16 - 0.08, 0.012, fw));
			gc = mix(gc, gc * 0.45, gj * (1.0 - smoothstep(0.02, 0.06, fw)));
			col = mix(col, gc * 0.85, gut);
			float kb = smoothstep(half_w - 0.02, half_w + 0.02, ax) * (1.0 - smoothstep(half_w + 0.30, half_w + 0.34, ax));
			col = mix(col, kerb(y, sign(x), fw), kb);
			// Sandstone flags: 0.6 x 0.45m, warm grey.
			float pav = smoothstep(half_w + 0.30, half_w + 0.34, ax);
			vec2 pp = vec2(ax - half_w, y);
			vec2 g = pp / vec2(0.6, 0.45);
			g.x += 0.5 * mod(floor(g.y), 2.0);
			vec2 gid = floor(g);
			vec2 gf = fract(g);
			vec3 fc = mix(lin(vec3(0.58, 0.54, 0.48)), lin(vec3(0.68, 0.63, 0.55)), hash12(gid + sign(x) * 3.0)) * (0.9 + 0.1 * tex_c / 0.6);
			float fj = 1.0 - smoothstep(0.004, 0.01 + fw * 0.5, min(min(gf.x, 1.0 - gf.x) * 0.6, min(gf.y, 1.0 - gf.y) * 0.45));
			fc *= 1.0 - 0.45 * fj * (1.0 - smoothstep(0.03, 0.12, fw));
			col = mix(col, fc, pav);
			rough = mix(rough, 0.8, max(kb, pav));
			nw = normalize(mix(nw, normalize(w_nrm), max(kb, pav)));
		}
	} else if (v_kind == 6) {
		// The towpath: fine gravel, darker in two worn tracks, its edges ragged into the grass.
		float n1 = vnoise(xz * 2.3);
		float n2 = vnoise(xz * 9.0 + 4.0);
		col = lin(vec3(0.62, 0.57, 0.48)) * (0.82 + 0.22 * n1) * (0.9 + 0.15 * n2);
		float speck = step(0.82, hash12(floor(xz * 11.0))) * (1.0 - smoothstep(0.02, 0.06, fw));
		col = mix(col, lin(vec3(0.38, 0.35, 0.32)), speck * 0.6);
		float tracks = stripe(ax - half_w * 0.45, half_w * 0.3, fx);
		col *= 1.0 - 0.12 * tracks;
		float edge = smoothstep(half_w * 0.7, half_w * 1.0, ax + (vnoise(vec2(y * 0.6, x)) - 0.5) * 0.8);
		col = mix(col, lin(vec3(0.30, 0.40, 0.15)) * (0.8 + 0.3 * n1), edge);
		rough = 0.95;
	} else if (v_kind == 3) {
		// The works' concrete: slabs 5m along and half the road across, dark joints sealed with bitumen.
		vec3 c = tex_c / 0.62 * lin(vec3(0.62, 0.61, 0.58));
		vec2 sg = vec2(x / max(half_w, 1.0), y / 5.0);
		vec2 sid = floor(sg);
		vec2 sf = fract(sg);
		c *= 0.88 + 0.18 * hash12(sid);
		float jd = min(min(sf.x, 1.0 - sf.x) * half_w, min(sf.y, 1.0 - sf.y) * 5.0);
		float joint = 1.0 - smoothstep(0.012, 0.03 + fw * 0.5, jd);
		c = mix(c, lin(vec3(0.10, 0.10, 0.10)), joint * 0.85);
		// Tyre wear in two bands each lane, ore dust drifting in from the edges, oil drips down the middle of a lane.
		float wear = stripe(ax - half_w * 0.5 - 0.8, 1.2, fx) + stripe(ax - half_w * 0.5 + 0.8, 1.2, fx);
		c *= 1.0 - 0.12 * clamp(wear, 0.0, 1.0);
		float ore = smoothstep(half_w * 0.45, half_w * 0.95, ax) * smoothstep(0.35, 0.7, vnoise(xz / 9.0));
		c = mix(c, lin(vec3(0.48, 0.25, 0.16)) * (0.7 + 0.4 * vnoise(xz * 1.5)), ore * 0.55);
		float oil = stripe(ax - half_w * 0.5, 0.7, fx) * smoothstep(0.55, 0.75, vnoise(vec2(y / 3.0, x)));
		c *= 1.0 - 0.35 * oil;
		// Yellow edge lines.
		float edge = stripe(ax - (half_w - 0.45), 0.15, fx) * (0.8 + 0.2 * vnoise(vec2(y * 0.7, x * 4.0)));
		c = mix(c, lin(vec3(0.85, 0.66, 0.10)), edge);
		col = c;
		rough = 0.82;
	} else if (v_kind == 4) {
		// The mill hall's floor: dark trowelled concrete, steel scale and soot, yellow walkway lines.
		vec3 c = tex_c / 0.62 * lin(vec3(0.36, 0.35, 0.34));
		c *= 0.85 + 0.25 * vnoise(xz / 3.5);
		float scale_ = smoothstep(0.6, 0.85, vnoise(xz / 2.0 + 13.0));
		c = mix(c, lin(vec3(0.20, 0.15, 0.12)), scale_ * 0.6);
		float wear = stripe(ax - half_w * 0.5, 2.0, fx);
		c *= 1.0 + 0.15 * clamp(wear, 0.0, 1.0);
		float edge = stripe(ax - (half_w - 0.4), 0.2, fx);
		float dash = stripe((fract(y / 6.0) - 0.5) * 6.0, 3.0, fy);
		float centre = stripe(x, 0.15, fx) * dash;
		c = mix(c, lin(vec3(0.90, 0.70, 0.08)), clamp(edge + centre, 0.0, 1.0) * 0.9);
		col = c;
		rough = 0.55;
		spec = 0.55;
	} else {
		// Asphalt: the country road (0) and the estate's street (2).
		vec3 tex = texture(asphalt_tex, xz * 0.16).rgb;
		float lum = dot(tex, vec3(0.299, 0.587, 0.114)) / 0.35;
		col = lin(vec3(0.20, 0.20, 0.205)) * mix(1.0, lum, 0.7);
		col *= 0.9 + 0.18 * vnoise(xz * 0.05);
		// Patches of repair: darker rectangles here and there.
		float patch_id = hash12(floor(vec2(x / 3.5, y / 7.0)));
		col *= 1.0 - 0.18 * step(0.93, patch_id);
		rough = 0.78;
		float wear = 0.75 + 0.25 * vnoise(vec2(y * 0.8, x * 3.0));
		if (v_kind == 7) {
			// Darker, newer asphalt; worn in the wheel tracks of each lane.
			col *= 0.82;
			float lane_w = 3.75;
			if (half_w > 6.0) {
				float inner = -half_w + 0.75;
				float tracks = 0.0;
				for (int li = 0; li < 3; li++) {
					float c = inner + lane_w * (float(li) + 0.5);
					tracks += stripe(x - c - 0.9, 0.7, fx) + stripe(x - c + 0.9, 0.7, fx);
				}
				col *= 1.0 - 0.10 * clamp(tracks, 0.0, 1.0) * (0.6 + 0.4 * vnoise(vec2(y * 0.3, x)));
				float lines = stripe(x - inner, 0.15, fx);
				float dash = stripe((fract(y / 18.0) - 0.17) * 18.0, 6.0, fy);
				lines += (stripe(x - (inner + lane_w), 0.15, fx) + stripe(x - (inner + lane_w * 2.0), 0.15, fx)) * dash;
				float outer = inner + lane_w * 3.0;
				lines += stripe(x - outer, 0.25, fx);
				col = mix(col, lin(vec3(0.88, 0.88, 0.85)), clamp(lines, 0.0, 1.0) * wear);
				// The hard shoulder: a little paler, dusty.
				float sh = smoothstep(outer + 0.15, outer + 0.3, x);
				col = mix(col, col * 1.12 + lin(vec3(0.03, 0.028, 0.024)), sh * 0.7);
			} else {
				float lines = stripe(ax - (half_w - 0.45), 0.15, fx);
				col = mix(col, lin(vec3(0.88, 0.88, 0.85)), clamp(lines, 0.0, 1.0) * wear);
			}
		} else if (v_kind == 8) {
			float edges = stripe(ax - (half_w - 0.7), 0.12, fx);
			float dash = stripe((fract(y / 9.0) - 0.17) * 9.0, 3.0, fy);
			float centre = stripe(x, 0.12, fx) * dash;
			col = mix(col, lin(vec3(0.86, 0.86, 0.82)), clamp(edges + centre, 0.0, 1.0) * wear);
			float gut = smoothstep(half_w - 0.42, half_w - 0.38, ax);
			float grow_ = floor(ax / 0.16);
			vec3 gc = mix(lin(vec3(0.33, 0.32, 0.31)), lin(vec3(0.45, 0.44, 0.42)), hash12(vec2(floor(y / 0.16 + 0.5 * mod(grow_, 2.0)), grow_)));
			col = mix(col, gc, gut);
		} else if (v_kind == 0) {
			// German markings: edge lines 0.12m, a centre Leitlinie of 6m dashes with 12m gaps.
			float edges = stripe(ax - (half_w - 0.55), 0.13, fx);
			float dash = stripe((fract(y / 18.0) - 0.17) * 18.0, 6.0, fy);
			float centre = stripe(x, 0.12, fx) * dash;
			col = mix(col, lin(vec3(0.86, 0.86, 0.82)), clamp(edges + centre, 0.0, 1.0) * wear);
			// The gravel shoulder strip (Bankett) along the outer edge.
			float sh = smoothstep(half_w - 0.3, half_w - 0.25, ax);
			vec3 gv = lin(vec3(0.42, 0.40, 0.36)) * (0.7 + 0.5 * hash12(floor(xz * 9.0)));
			col = mix(col, mix(gv, lin(vec3(0.42, 0.40, 0.36)), smoothstep(0.03, 0.1, fw)), sh);
		} else {
			// The estate: a sett gutter, granite kerbs, grey concrete flags.
			float gut = smoothstep(half_w - 0.52, half_w - 0.48, ax) * (1.0 - smoothstep(half_w - 0.02, half_w + 0.02, ax));
			float grow_ = floor(ax / 0.17);
			vec3 gc = mix(lin(vec3(0.34, 0.33, 0.32)), lin(vec3(0.46, 0.45, 0.43)), hash12(vec2(floor(y / 0.16 + 0.5 * mod(grow_, 2.0)), grow_)));
			col = mix(col, gc, gut);
			float kb = smoothstep(half_w - 0.02, half_w + 0.02, ax) * (1.0 - smoothstep(half_w + 0.28, half_w + 0.32, ax));
			col = mix(col, kerb(y, sign(x), fw), kb);
			float pav = smoothstep(half_w + 0.28, half_w + 0.32, ax);
			col = mix(col, flags(vec2(ax, y), 0.3, lin(vec3(0.58, 0.58, 0.56)) * (0.9 + 0.1 * tex_c / 0.6), fw), pav);
			rough = mix(rough, 0.82, max(kb, pav));
		}
	}

	// Where the kind changes: a granite threshold across the road.
	if (v_edge < 0.6) {
		float th = 1.0 - smoothstep(0.45, 0.55, v_edge);
		vec3 tc = lin(vec3(0.55, 0.54, 0.52)) * (0.85 + 0.25 * hash12(floor(vec2(x / 0.5, 3.0))));
		col = mix(col, tc, th);
		rough = mix(rough, 0.7, th);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
