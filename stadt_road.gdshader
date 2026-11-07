// Quer durch Kronburg's roads (regenerate_stadtrallye.gd, _build_roads), a copy of Kronburger Hütte's
// kronburg_road.gdshader with this stage's own kinds added (9 to 14); kinds 0 to 8 are as there. Every surface the route
// runs on is laid as ribbons a few centimetres over the graded ground. UV: x metres right of the line, y metres along it.
// UV2.x the kind, UV2.y the carriageway's half width (the ribbon may be wider: pavements):
//   9 the Ring: two lanes each way either side of a paved tram median (two tracks with grooved rails), kerbs, a red
//     cycle path and flags; UV.x from the Ring's middle. Where the route crosses it (`cross_z`, `cross_half`, world z)
//     the kerbs are lowered and the pavement is asphalt.
//  10 the Botanischer Garten's paths: a pale water-bound gravel surface (wassergebundene Wegedecke), worn by the race
//     into tyre tracks, granite edging stones along both edges
//  11 the building site's haul road: compacted earth, ruts, puddles, gravel patches, steel road plates every so often
//  12 the palm house's floor: stone and terracotta tiles in a pattern laid in world space
//  13 the scrapyard: oily concrete slabs half under mud, rust and swarf
//  14 the pedestrian zone: concrete paving stones in a herringbone, granite bands every 6m, a drainage channel, no kerbs
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
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cross_z = -200.0;
uniform float cross_half = 7.5;

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
	} else if (v_kind == 9) {
		// The Ring: asphalt lanes either side of the tram median; at the crossing the pavement is asphalt too.
		vec3 tex9 = texture(asphalt_tex, xz * 0.16).rgb;
		float lum9 = dot(tex9, vec3(0.299, 0.587, 0.114)) / 0.35;
		vec3 asph = lin(vec3(0.19, 0.19, 0.195)) * mix(1.0, lum9, 0.7) * (0.9 + 0.18 * vnoise(xz * 0.05));
		float wear9 = 0.72 + 0.28 * vnoise(vec2(y * 0.8, x * 3.0));
		bool crossing = abs(w_pos.z - cross_z) < cross_half;
		float med = 5.5;
		float carr = 16.7;
		if (ax < med) {
			// Grey setts in straight rows across the median.
			vec2 st9 = arc_setts(vec2(x, y), 1.4, 0.0, 0.12, 0.14, fw);
			vec3 sett9 = mix(lin(vec3(0.37, 0.36, 0.35)), lin(vec3(0.50, 0.48, 0.45)), st9.x) * (0.88 + 0.2 * vnoise(xz * 0.12));
			col = mix(sett9, lin(vec3(0.15, 0.14, 0.13)), st9.y);
			rough = 0.75;
			// Two tracks at +-2.4, each with two grooved rails 1.15 either side of its middle.
			for (int tr = -1; tr <= 1; tr += 2) {
				float tcx = float(tr) * 2.4;
				for (int rs = -1; rs <= 1; rs += 2) {
					float rx = tcx + float(rs) * 1.15;
					float groove = stripe(x - (rx - float(rs) * 0.085), 0.06, fx);
					float head = stripe(x - rx, 0.10, fx);
					col = mix(col, lin(vec3(0.04, 0.04, 0.04)), groove);
					col = mix(col, lin(vec3(0.60, 0.60, 0.61)) * (0.85 + 0.2 * vnoise(vec2(y * 2.0, rx))), head);
					rough = mix(rough, 0.22, head);
					spec = mix(spec, 0.8, head);
				}
			}
			if (!crossing) {
				float kb9 = smoothstep(med - 0.32, med - 0.28, ax);
				col = mix(col, kerb(y, sign(x), fw), kb9);
			}
		} else if (ax < carr || crossing) {
			col = asph;
			rough = 0.78;
			// Wheel tracks in each lane.
			float tracks9 = 0.0;
			for (int li = 0; li < 2; li++) {
				float lc = med + 0.3 + 2.8 + float(li) * 5.6;
				tracks9 += stripe(ax - lc - 0.95, 0.7, fx) + stripe(ax - lc + 0.95, 0.7, fx);
			}
			col *= 1.0 - 0.10 * clamp(tracks9, 0.0, 1.0);
			if (!crossing) {
				float lines9 = stripe(ax - (med + 0.3), 0.15, fx);
				float dash9 = stripe((fract(y / 9.0) - 0.17) * 9.0, 3.0, fy);
				lines9 += stripe(ax - (med + 0.3 + 5.6), 0.13, fx) * dash9;
				lines9 += stripe(ax - (carr - 0.35), 0.15, fx);
				col = mix(col, lin(vec3(0.88, 0.88, 0.85)), clamp(lines9, 0.0, 1.0) * wear9);
			}
			// The stop lines before the crossing: northbound (x > 0) south of it, southbound north of it.
			float sz = x > 0.0 ? cross_z + cross_half + 3.0 : cross_z - cross_half - 3.0;
			float stopl = stripe(w_pos.z - sz, 0.5, fw) * step(med + 0.3, ax) * step(ax, carr - 0.3);
			col = mix(col, lin(vec3(0.90, 0.90, 0.87)), stopl * wear9);
		} else {
			// The pavement: a granite kerb, the red cycle path, grey flags.
			float kb = 1.0 - smoothstep(carr + 0.28, carr + 0.32, ax);
			col = kerb(y, sign(x), fw);
			float cyc = smoothstep(carr + 0.28, carr + 0.32, ax) * (1.0 - smoothstep(carr + 2.3, carr + 2.34, ax));
			vec3 red = lin(vec3(0.52, 0.22, 0.18)) * (0.85 + 0.2 * vnoise(xz * 0.4)) * mix(1.0, lum9, 0.4);
			col = mix(col, red, cyc);
			float pav9 = smoothstep(carr + 2.3, carr + 2.34, ax);
			col = mix(col, flags(vec2(ax, y), 0.3, lin(vec3(0.58, 0.58, 0.56)) * (0.9 + 0.1 * tex_c / 0.6), fw), pav9);
			rough = 0.82;
			col = mix(col, kerb(y, sign(x), fw), kb);
		}
	} else if (v_kind == 10) {
		// The garden's paths: pale water-bound gravel, tyre tracks where the race runs, granite edging stones.
		vec3 gr10 = texture(gravel_tex, xz / 1.6).rgb;
		float gl10 = dot(gr10, vec3(0.33));
		vec3 base10 = lin(vec3(0.72, 0.66, 0.55)) * (0.78 + 0.45 * gl10) * (0.9 + 0.15 * vnoise(xz * 0.5));
		float speck = step(0.86, hash12(floor(xz * 13.0))) * (1.0 - smoothstep(0.02, 0.06, fw));
		base10 = mix(base10, lin(vec3(0.40, 0.37, 0.33)), speck * 0.5);
		float tracks10 = 0.0;
		for (int ti = 0; ti < 4; ti++) {
			float off = (float(ti) - 1.5) * 1.9 + (vnoise(vec2(y / 9.0, float(ti) * 7.0)) - 0.5) * 2.2;
			tracks10 += stripe(x - off, 0.55, fx);
		}
		base10 *= 1.0 - 0.16 * clamp(tracks10, 0.0, 1.0);
		// Loose grit pushed to the edges: lighter there.
		base10 *= 1.0 + 0.10 * smoothstep(half_w * 0.55, half_w * 0.9, ax);
		col = base10;
		rough = 0.95;
		// Granite edging stones (Kantensteine): a row of blocks 0.5m long, 0.18m wide, at the very edge.
		float eg = smoothstep(half_w - 0.24, half_w - 0.2, ax);
		float eb = floor(y / 0.5);
		vec3 ec = mix(lin(vec3(0.46, 0.45, 0.44)), lin(vec3(0.60, 0.58, 0.55)), hash12(vec2(eb, sign(x))));
		float ej = stripe((fract(y / 0.5) - 0.5) * 0.5, 0.012, fy);
		col = mix(col, ec * (1.0 - 0.5 * ej), eg);
		rough = mix(rough, 0.8, eg);
	} else if (v_kind == 11) {
		// The building site's haul road: compacted earth, ruts, puddles, gravel, steel road plates.
		vec3 d11 = texture(dirt_tex, xz / 4.0).rgb;
		vec3 earth = lin(vec3(0.43, 0.34, 0.25)) * (0.62 + 0.7 * dot(d11, vec3(0.33)));
		earth *= 0.85 + 0.25 * vnoise(xz / 7.0);
		vec3 gr11 = texture(gravel_tex, xz / 2.2).rgb;
		float gpatch = smoothstep(0.55, 0.7, vnoise(xz / 11.0 + 3.0));
		earth = mix(earth, lin(vec3(0.46, 0.44, 0.41)) * (0.6 + dot(gr11, vec3(0.5))), gpatch * 0.8);
		float ruts = 0.0;
		for (int ri = -1; ri <= 1; ri += 2) {
			float rc = float(ri) * (2.1 + (vnoise(vec2(y / 13.0, float(ri))) - 0.5) * 1.2);
			ruts += stripe(x - rc, 0.75, fx) + stripe(x - rc * 2.35, 0.7, fx) * 0.6;
		}
		earth *= 1.0 - 0.22 * clamp(ruts, 0.0, 1.0);
		col = earth;
		rough = 0.92;
		vec3 dn11 = texture(dirt_normal, xz / 4.0).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(dn11.x, 0.0, dn11.y) * 0.4);
		// Puddles in the ruts and hollows: still brown water mirroring the sky.
		float pud = smoothstep(0.64, 0.69, vnoise(xz / 5.5 + 11.0) * 0.7 + clamp(ruts, 0.0, 1.0) * 0.32);
		col = mix(col, lin(vec3(0.09, 0.08, 0.06)), pud * 0.85);
		rough = mix(rough, 0.04, pud);
		spec = mix(spec, 0.7, pud);
		nw = normalize(mix(nw, normalize(w_nrm), pud));
		// Steel road plates (Baustraßenplatten): two side by side, 4m long, every 46m.
		float py = fract((y + 9.0) / 46.0) * 46.0;
		float plate = step(py, 4.0) * step(ax, 4.6);
		vec2 pc = vec2(fract(x / 2.3) * 2.3, py);
		float diamond = step(0.5, fract((pc.x + pc.y) * 3.0)) * step(0.5, fract((pc.x - pc.y) * 3.0));
		vec3 steel = lin(vec3(0.24, 0.22, 0.20)) * (0.8 + 0.3 * vnoise(xz * 2.0)) * (1.0 + 0.12 * diamond * (1.0 - smoothstep(0.02, 0.05, fw)));
		steel = mix(steel, lin(vec3(0.40, 0.22, 0.12)), smoothstep(0.55, 0.8, vnoise(xz * 0.9)) * 0.5);
		float pedge = stripe((fract(x / 2.3) - 0.5) * 2.3, 0.04, fx);
		col = mix(col, steel * (1.0 - 0.6 * clamp(pedge, 0.0, 1.0)), plate);
		rough = mix(rough, 0.55, plate);
		spec = mix(spec, 0.6, plate);
	} else if (v_kind == 12) {
		// The palm house: 0.5m terracotta tiles with small slate insets at their corners, in world space; a sandstone
		// border along the beds.
		vec2 g12 = xz / 0.5;
		vec2 gi = floor(g12);
		vec2 gf = fract(g12);
		vec3 terra = mix(lin(vec3(0.62, 0.36, 0.26)), lin(vec3(0.70, 0.44, 0.32)), hash12(gi)) * (0.9 + 0.12 * vnoise(xz * 0.7));
		vec2 cd = min(gf, 1.0 - gf);
		float inset = step(cd.x + cd.y, 0.24);
		vec3 slate12 = lin(vec3(0.20, 0.23, 0.26)) * (0.85 + 0.25 * hash12(gi + 0.5));
		col = mix(terra, slate12, inset * (1.0 - smoothstep(0.03, 0.08, fw)));
		float jt = 1.0 - smoothstep(0.004, 0.012 + fw * 0.5, min(cd.x, cd.y) * 0.5);
		col *= 1.0 - 0.35 * jt * (1.0 - smoothstep(0.03, 0.12, fw));
		float border = smoothstep(half_w - 0.75, half_w - 0.7, ax);
		col = mix(col, flags(vec2(ax, y), 0.6, lin(vec3(0.66, 0.60, 0.50)), fw), border);
		rough = 0.6;
		spec = 0.5;
	} else if (v_kind == 13) {
		// The scrapyard: concrete slabs half under mud, rust stains, oil, swarf.
		vec3 c13 = tex_c / 0.62 * lin(vec3(0.46, 0.45, 0.43));
		vec2 sg13 = vec2(x / 5.0, y / 5.0);
		vec2 sf13 = fract(sg13);
		c13 *= 0.85 + 0.2 * hash12(floor(sg13));
		float j13 = 1.0 - smoothstep(0.01, 0.03 + fw * 0.5, min(min(sf13.x, 1.0 - sf13.x), min(sf13.y, 1.0 - sf13.y)) * 5.0);
		c13 = mix(c13, lin(vec3(0.08, 0.08, 0.08)), j13 * 0.8);
		vec3 d13 = texture(dirt_tex, xz / 4.0).rgb;
		vec3 mud = lin(vec3(0.30, 0.25, 0.19)) * (0.6 + 0.7 * dot(d13, vec3(0.33)));
		float mw = smoothstep(0.45, 0.62, vnoise(xz / 8.0 + 5.0) + smoothstep(half_w * 0.6, half_w, ax) * 0.3);
		c13 = mix(c13, mud, mw);
		float rust = smoothstep(0.6, 0.8, vnoise(xz / 3.0 + 17.0));
		c13 = mix(c13, lin(vec3(0.42, 0.20, 0.10)) * (0.7 + 0.5 * vnoise(xz * 3.0)), rust * 0.6);
		float oil13 = smoothstep(0.62, 0.78, vnoise(xz / 4.5 + 40.0));
		c13 *= 1.0 - 0.5 * oil13;
		float swarf = step(0.93, hash12(floor(xz * 17.0))) * (1.0 - smoothstep(0.02, 0.05, fw));
		c13 = mix(c13, lin(vec3(0.55, 0.55, 0.56)), swarf * 0.6);
		col = c13;
		rough = mix(0.85, 0.35, oil13);
		spec = mix(0.4, 0.6, oil13);
		float pud13 = smoothstep(0.7, 0.74, vnoise(xz / 6.0 + 23.0)) * mw;
		col = mix(col, lin(vec3(0.07, 0.065, 0.055)), pud13 * 0.8);
		rough = mix(rough, 0.04, pud13);
	} else if (v_kind == 14) {
		// The pedestrian zone: concrete pavers in a herringbone (world space), granite bands every 6m, a channel down
		// the middle with a grate every 8m.
		vec2 p14 = vec2(xz.x + xz.y, xz.x - xz.y) * 0.70710678;
		vec2 hb = p14 / vec2(0.24, 0.12);
		float row14 = floor(hb.y);
		float sh14 = mod(row14, 2.0) * 0.5;
		vec2 hi = vec2(floor(hb.x + sh14), row14);
		vec2 hf = vec2(fract(hb.x + sh14), fract(hb.y));
		float tone = hash12(hi);
		vec3 pav14 = mix(lin(vec3(0.46, 0.45, 0.43)), lin(vec3(0.60, 0.58, 0.55)), tone);
		pav14 = mix(pav14, lin(vec3(0.33, 0.33, 0.33)), step(0.82, tone) * 0.7);
		pav14 *= 0.92 + 0.12 * tex_c.r / 0.6;
		float j14 = 1.0 - smoothstep(0.003, 0.009 + fw * 0.5, min(min(hf.x, 1.0 - hf.x) * 0.24, min(hf.y, 1.0 - hf.y) * 0.12));
		pav14 *= 1.0 - 0.35 * j14 * (1.0 - smoothstep(0.02, 0.08, fw));
		float bandy = stripe((fract(y / 6.0) - 0.5) * 6.0, 0.4, fy);
		vec3 gran = lin(vec3(0.30, 0.29, 0.29)) * (0.85 + 0.25 * hash12(floor(vec2(x / 0.4, y / 0.4))));
		col = mix(pav14, gran, bandy);
		float chan = stripe(x, 0.36, fx);
		vec3 chc = lin(vec3(0.26, 0.25, 0.25));
		float grate = step(fract((y + 2.0) / 8.0) * 8.0, 0.6) * chan * step(0.5, fract(x * 12.0 + 0.25));
		col = mix(col, chc, chan);
		col = mix(col, lin(vec3(0.06, 0.06, 0.06)), grate);
		rough = 0.78;
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
