// The Miyoshino GP's roads (MiyoshinoStage.gd, _build_roads): every surface the laps run on, laid as ribbons a few
// centimetres over the graded ground. UV: x metres right of the lap's line, y metres along it. UV2.x the kind, UV2.y the
// carriageway's half width:
//   0 mountain road (touge): fine dark asphalt, white edge lines, an orange centre line (solid: no overtaking), a
//     concrete gutter strip along both edges, moss and earth creeping in from the verge, patched repairs
//   1 ishidatami: the temple town's stone paving, granite flags in courses across the street, a band of long kerb
//     stones along both edges, worn smooth and darker down the middle
//   2 the pilgrims' trail: trodden earth with stones and roots showing, leaf litter and moss at the edges
//   3 planks: boards laid across the way on a timber deck (bridges, the cliff walkways, the timber slide), nail heads,
//     gaps, a kerb beam along both edges
//   4 forestry road: pale river gravel, two worn wheel tracks, a grassy crown and edges
//   5 temple precinct: fine raked gravel, pale, with the rake's lines along the way
// COLOR.r is the distance to where the kind changes (metres / 4, 1 past 4m): a granite threshold across the road.
// COLOR.g is how much fallen blossom lies on the road (0..1): drifts along both edges, single petals everywhere.
// The vertices are pulled toward the eye along their own rays (as the skid marks are), so each ribbon wins the depth
// test against the ground under it at any distance. Patterns come from floor() of world positions and UVs only.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 petal_color : source_color = vec3(0.97, 0.72, 0.80);
uniform vec3 centre_line : source_color = vec3(0.95, 0.58, 0.10);
uniform vec3 earth_tint : source_color = vec3(0.52, 0.45, 0.36);
uniform vec3 plank_tint : source_color = vec3(0.58, 0.46, 0.34);
// Wet look (the misty trail): darker, glossier.
uniform float wetness = 0.0;

varying vec3 w_pos;
varying vec3 w_nrm;
varying flat int v_kind;
varying float v_half;
varying float v_edge;
varying float v_petals;

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	return vec2(hash12(p), hash12(p + 19.19));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}

// Coverage of a line `w` wide at signed distance `d`: the share of a pixel `aa` wide (box filtered) it covers.
float stripe(float d, float w, float aa) {
	aa = max(aa, 1e-4);
	float lo = max(d - aa * 0.5, -w * 0.5);
	float hi = min(d + aa * 0.5, w * 0.5);
	return clamp((hi - lo) / aa, 0.0, 1.0);
}

float fleck(vec2 p, float density, float r, float share, float salt, float fw) {
	vec2 q = p * density;
	vec2 cell = floor(q);
	vec2 c = 0.25 + 0.5 * hash22(cell + salt);
	float d = length(fract(q) - c) / density;
	float on = step(1.0 - share, hash12(cell + salt * 3.1));
	return on * (1.0 - smoothstep(r - fw * 0.5, r + fw * 0.5, d)) * (1.0 - smoothstep(r * 0.6, r * 1.6, fw));
}

// Stone flags in courses `ch` deep along q.y, each stone a random length along q.x (about `sw`); returns the stone's
// id hash in x and the joint's coverage in y.
vec2 courses(vec2 q, float ch, float sw, float fw) {
	float row = floor(q.y / ch);
	float off = hash12(vec2(row, 3.7)) * sw;
	float u = (q.x + off) / sw;
	float col = floor(u);
	// Stones of uneven length: the joint wanders inside its cell.
	float j0 = (hash12(vec2(col, row)) - 0.5) * 0.5;
	float j1 = (hash12(vec2(col + 1.0, row)) - 0.5) * 0.5;
	float fu = fract(u);
	float du = min(fu - j0 + 0.0, 1.0 + j1 - fu);
	float id = du < 0.0 ? (fu < 0.5 ? col - 1.0 : col + 1.0) : col;
	float dj = min(abs(fu - j0), abs(1.0 + j1 - fu)) * sw;
	float fv = fract(q.y / ch);
	float dr = min(fv, 1.0 - fv) * ch;
	float jw = 0.012;
	float joint = 1.0 - smoothstep(jw, jw + 0.008 + fw * 0.6, min(dj, dr));
	joint = mix(joint, 0.12, smoothstep(ch * 0.12, ch * 0.5, fw));
	return vec2(hash12(vec2(id, row) + 0.37), joint);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_kind = int(UV2.x + 0.5);
	v_half = UV2.y;
	v_edge = COLOR.r * 4.0;
	v_petals = COLOR.g;
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
	float hw = v_half;
	vec3 col = vec3(0.1);
	float rough = 0.8;
	float spec = 0.4;
	vec3 nw = normalize(w_nrm);
	float petals_edge = 1.0;

	if (v_kind == 0) {
		// ---- Mountain road.
		vec3 at = texture(asphalt_tex, xz * 0.22).rgb;
		float al = dot(at, vec3(0.33));
		col = lin(vec3(0.20, 0.20, 0.21)) * (0.55 + al * 1.3);
		// Repairs: darker rectangles here and there, and a paler worn band in each lane.
		vec2 pc = vec2(floor(x / 2.4), floor(y / 9.0));
		float patch = step(0.9, hash12(pc + 5.0));
		col *= mix(1.0, 0.72, patch * (1.0 - smoothstep(0.2, 0.9, fw)));
		float lane = 1.0 - smoothstep(0.5, 1.5, abs(ax - hw * 0.45));
		col = mix(col, col * 1.18, lane * 0.5);
		col *= 0.9 + 0.2 * vnoise(xz / 9.0);
		// The gutter strip: concrete, with a joint every 2m, a little moss.
		float gut0 = hw - 0.55;
		float gutter = smoothstep(gut0 - fx, gut0 + fx, ax);
		vec3 conc = lin(vec3(0.60, 0.59, 0.56)) * (0.8 + 0.3 * al);
		float gj = 1.0 - smoothstep(0.01, 0.03 + fy, abs(fract(y / 2.0) - 0.5) * 2.0);
		conc *= 1.0 - 0.3 * gj * (1.0 - smoothstep(0.1, 0.5, fw));
		conc = mix(conc, lin(vec3(0.26, 0.36, 0.14)), smoothstep(0.5, 0.8, fbm(vec2(x * 2.0, y * 0.3))) * 0.6);
		col = mix(col, conc, gutter);
		// Markings: white edge lines, the orange centre line.
		vec3 white = lin(vec3(0.90, 0.90, 0.86));
		float wear = 0.7 + 0.3 * smoothstep(0.25, 0.6, vnoise(vec2(x * 3.0, y * 0.6)));
		float el = stripe(ax - (hw - 0.95), 0.15, fx);
		col = mix(col, white, el * wear * (1.0 - gutter));
		float cl = stripe(x, 0.15, fx);
		col = mix(col, centre_line, cl * wear);
		// Earth and moss creeping in over the gutter from the verge.
		float creep = smoothstep(hw - 0.5, hw + 0.1, ax + (vnoise(vec2(y * 0.35, x)) - 0.5) * 0.9);
		col = mix(col, lin(vec3(0.24, 0.30, 0.14)) * (0.7 + al), creep * 0.75);
		rough = mix(0.86, 0.9, gutter);
		spec = 0.35;
	} else if (v_kind == 1) {
		// ---- Ishidatami.
		vec3 st = texture(stone_tex, xz * 0.3).rgb;
		float sl = dot(st, vec3(0.33));
		float kerb0 = hw - 0.6;
		vec2 cj;
		if (ax > kerb0) {
			// Kerb stones: long, along the street.
			cj = courses(vec2(y, ax - kerb0), 0.6, 1.9, fw);
		} else {
			cj = courses(vec2(x + 40.0, y), 0.62, 1.05, fw);
		}
		vec3 granite = mix(lin(vec3(0.56, 0.55, 0.53)), lin(vec3(0.66, 0.63, 0.58)), cj.x);
		granite = mix(granite, lin(vec3(0.50, 0.50, 0.52)), step(0.8, cj.x) * 0.6);
		granite *= 0.6 + sl * 1.1;
		// Worn smooth and a little darker where everyone walks and drives.
		float worn = 1.0 - smoothstep(hw * 0.25, hw * 0.75, ax);
		granite *= mix(1.0, 0.88, worn);
		col = granite * (1.0 - 0.55 * cj.y);
		// Moss in the joints toward the edges.
		col = mix(col, lin(vec3(0.22, 0.32, 0.12)), cj.y * smoothstep(hw * 0.5, hw, ax) * 0.7);
		rough = mix(0.72, 0.55, worn * (1.0 - cj.y));
		spec = 0.45;
	} else if (v_kind == 2) {
		// ---- The pilgrims' trail.
		vec3 dt = texture(dirt_tex, xz / 3.5).rgb;
		vec3 earth = dt * earth_tint * 1.5;
		earth *= 0.86 + 0.24 * vnoise(xz / 7.0);
		// Trodden paler down the middle, darker damp edges.
		float mid = 1.0 - smoothstep(hw * 0.2, hw * 0.8, ax + (vnoise(vec2(y * 0.2, 3.0)) - 0.5) * 1.5);
		earth *= mix(0.8, 1.12, mid);
		// Stones bedded in the path.
		float s1 = fleck(vec2(x, y), 0.7, 0.16, 0.10, 5.0, fw);
		float s2 = fleck(vec2(x, y) + 0.4, 2.2, 0.06, 0.12, 9.0, fw);
		vec3 gr = texture(gravel_tex, xz / 2.0).rgb;
		earth = mix(earth, lin(vec3(0.40, 0.39, 0.37)) * (0.5 + dot(gr, vec3(0.33))), max(s1, s2) * 0.6);
		// Roots across the way: thin dark sinuous lines.
		float rt = abs(fract((y + sin(x * 1.3 + floor(y / 11.0) * 2.1) * 0.5) / 11.0) - 0.5) * 11.0;
		float root = (1.0 - smoothstep(0.03, 0.07 + fw, rt)) * step(0.6, hash12(vec2(floor(y / 11.0), 1.0)));
		earth = mix(earth, lin(vec3(0.20, 0.14, 0.10)), root * 0.8);
		// Litter and moss at the edges.
		float edge = smoothstep(hw - 2.0, hw - 0.2, ax + (vnoise(vec2(y * 0.3, x * 0.5)) - 0.5) * 1.6);
		vec3 litter = mix(lin(vec3(0.36, 0.25, 0.16)), lin(vec3(0.22, 0.32, 0.12)), smoothstep(0.4, 0.65, fbm(xz / 3.0)));
		earth = mix(earth, litter * (0.7 + 0.5 * dt.r), edge * 0.8);
		col = earth;
		rough = 0.95;
		spec = 0.25;
		vec3 dn = texture(dirt_normal, xz / 3.5).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(dn.x, 0.0, dn.y) * 0.4);
	} else if (v_kind == 3) {
		// ---- Planks across the way.
		float bw = 0.3;
		float bi = floor(y / bw);
		float bf = fract(y / bw);
		float bh = hash12(vec2(bi, 7.0));
		vec3 wt = texture(wood_tex, vec2(x * 0.5 + bh * 9.0, y * 1.6)).rgb;
		vec3 wood = plank_tint * (0.55 + dot(wt, vec3(0.33)) * 1.1) * (0.82 + 0.3 * bh);
		// A plank's grain runs across the road: streak it along x.
		wood *= 0.9 + 0.2 * vnoise(vec2(x * 0.6 + bh * 31.0, bi * 3.3 + bf * 6.0));
		float gap = 1.0 - smoothstep(0.012, 0.03 + fy * 0.7, min(bf, 1.0 - bf) * bw);
		gap = mix(gap, 0.1, smoothstep(bw * 0.15, bw * 0.6, fw));
		wood *= 1.0 - 0.75 * gap;
		// Nail heads over the stringers.
		float nx = abs(fract((ax + 0.5) / 2.2) - 0.5) * 2.2;
		float nail = (1.0 - smoothstep(0.02, 0.035 + fw, length(vec2(nx, (bf - 0.5) * bw)))) * (1.0 - smoothstep(0.02, 0.08, fw));
		wood = mix(wood, lin(vec3(0.12, 0.10, 0.09)), nail * 0.8);
		// The kerb beam along each edge and wear down the middle.
		float kerb = smoothstep(hw - 0.42 - fx, hw - 0.42 + fx, ax);
		wood = mix(wood, plank_tint * 0.55 * (0.6 + wt.r), kerb);
		wood *= mix(1.0, 1.15, 1.0 - smoothstep(1.0, hw * 0.8, ax));
		col = wood;
		rough = 0.82;
		spec = 0.3;
		petals_edge = 0.6;
	} else if (v_kind == 4) {
		// ---- Forestry road: river gravel.
		vec3 gr = texture(gravel_tex, xz / 2.4).rgb;
		float gl = dot(gr, vec3(0.33));
		vec3 gravel = lin(vec3(0.62, 0.60, 0.55)) * (0.5 + gl * 1.4);
		gravel = mix(gravel, lin(vec3(0.70, 0.64, 0.52)) * (0.6 + gl), smoothstep(0.4, 0.7, fbm(xz / 9.0)) * 0.5);
		float trackd = abs(ax - hw * 0.42);
		float wheel = 1.0 - smoothstep(0.5, 1.3, trackd + (vnoise(vec2(y * 0.15, 1.0)) - 0.5) * 0.5);
		vec3 dt = texture(dirt_tex, xz / 3.0).rgb;
		gravel = mix(gravel, dt * earth_tint * 2.0, wheel * 0.55);
		float crown = (1.0 - smoothstep(0.2, 1.0, ax + (vnoise(vec2(y * 0.4, 5.0)) - 0.5) * 0.8)) * smoothstep(0.35, 0.6, vnoise(vec2(y * 0.08, 2.0)));
		float edge = smoothstep(hw - 1.4, hw - 0.1, ax + (vnoise(vec2(y * 0.3, x * 0.4)) - 0.5) * 1.4);
		vec3 grass = lin(vec3(0.30, 0.44, 0.16)) * (0.7 + gl);
		gravel = mix(gravel, grass, max(crown * 0.7, edge * 0.85));
		col = gravel;
		rough = 0.94;
		spec = 0.25;
	} else {
		// ---- Temple precinct: fine raked gravel.
		vec3 gr = texture(gravel_tex, xz / 1.3).rgb;
		float gl = dot(gr, vec3(0.33));
		col = lin(vec3(0.80, 0.78, 0.72)) * (0.62 + gl * 0.9);
		float rake = sin(x * 22.0) * 0.5 + 0.5;
		col *= 1.0 - 0.14 * rake * (1.0 - smoothstep(0.004, 0.03, fw));
		col *= 0.92 + 0.14 * vnoise(xz / 6.0);
		rough = 0.95;
		spec = 0.2;
	}

	// A granite threshold where the surface changes.
	float th = 1.0 - smoothstep(0.32 - fy, 0.32 + fy, v_edge);
	if (th > 0.001) {
		vec3 st2 = texture(stone_tex, xz * 0.4).rgb;
		vec3 thr = lin(vec3(0.60, 0.59, 0.57)) * (0.6 + dot(st2, vec3(0.33)));
		float tj = 1.0 - smoothstep(0.01, 0.03 + fx, abs(fract(x / 1.4) - 0.5) * 1.4);
		thr *= 1.0 - 0.4 * tj * (1.0 - smoothstep(0.1, 0.5, fw));
		col = mix(col, thr, th);
		rough = mix(rough, 0.7, th);
	}

	// Fallen blossom: drifts gathered along both edges (and in the gutters), single petals all over.
	if (v_petals > 0.01) {
		vec2 p = vec2(x, y);
		float drift = smoothstep(hw - 2.6, hw - 0.3, ax + (fbm(vec2(y * 0.22, x * 0.6)) - 0.5) * 2.4) * petals_edge;
		drift *= smoothstep(0.25, 0.6, fbm(vec2(y * 0.11, 7.0)));
		float p1 = fleck(p, 7.0, 0.03, 0.22, 3.0, fw);
		float p2 = fleck(p + 0.37, 3.6, 0.034, 0.14, 11.0, fw);
		float cover = clamp(drift * 0.85 + max(p1, p2) * 0.9, 0.0, 1.0) * v_petals;
		cover = mix(cover, v_petals * (0.03 + 0.4 * drift), smoothstep(0.03, 0.12, fw));
		col = mix(col, petal_color * (0.88 + 0.12 * vnoise(p * 3.0)), cover * 0.9);
		rough = mix(rough, 0.9, cover);
	}

	col *= 1.0 - 0.3 * wetness;
	rough = mix(rough, rough * 0.55, wetness);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
