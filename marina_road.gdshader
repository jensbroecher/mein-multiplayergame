// Marina Nights' roads (regenerate_marina_nights.gd, _build_roads): every surface the lap runs on, laid as ribbons a few
// centimetres over the ground (or as a bridge's or the tube's deck). No TerrainGenerator road on this stage.
// UV: x metres right of the lap's line, y metres along it. UV2.x the kind:
//   0 the city's asphalt: three lanes, white edge lines, studs on the lane lines, granite kerb stones
//   1 the souk's setts (cobblestone texture, warm limestone), flat gutter stones along the edges
//   2 the palm avenue's pavers, two tones in a diagonal bond, framed by basalt setts
//   3 a bridge deck: new asphalt, blue LED studs along the edge lines breathing slowly, steel joints at its ends
//   4 the glass tube's deck: dark resin with pale chips, LED lines along the lane's edges, the walkways either side
//   5 the fountain plaza (a disc, not a ribbon: polar about `plaza_c`): sandstone in rings, a band of eight-point
//     stars round the fountain, rays of dark stone, flush uplights, a basalt rim
// COLOR.r is the distance to where the kind changes (metres / 4, 1 past 4m): a stone threshold across the road there
// (on a deck, a steel expansion joint).
// The vertices are pulled toward the eye along their own rays (as the skid marks are): the same pixels, but each surface
// wins the depth test against the ground under it at any distance. Nothing here hashes an interpolated value: cells
// come from floor() of world positions and UVs, which are continuous.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sett_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sett_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 plaza_c = vec2(250.0, -215.0);
uniform float plaza_r0 = 25.5;
uniform float plaza_r1 = 64.0;
uniform float half_w = 7.5;

varying vec3 w_pos;
varying vec3 w_nrm;
varying flat int v_kind;
varying float v_edge;

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

// Coverage of a stripe `w` wide centred `d` away, antialiased over `aa` (the pixel's size in the same units), faded to
// its average share once the stripe is thinner than a pixel.
float stripe(float d, float w, float aa) {
	aa = max(aa, 1e-4);
	float cov = clamp((w * 0.5 - abs(d)) / aa + 0.5, 0.0, 1.0);
	return mix(cov, clamp(w / (aa * 2.0), 0.0, 1.0), smoothstep(w * 0.6, w * 1.6, aa));
}

// Kerb stones along an edge: blocks a metre long, light granite, darker joints.
vec3 kerb(vec2 uv, float fw) {
	float row = floor(uv.y / 0.9);
	float h = hash12(vec2(row, sign(uv.x) * 7.0));
	vec3 c = mix(vec3(0.50, 0.50, 0.49), vec3(0.60, 0.59, 0.56), h);
	float joint = stripe((fract(uv.y / 0.9 + 0.5) - 0.5) * 0.9, 0.05, fw);
	return c * mix(1.0, 0.62, joint);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_kind = int(UV2.x + 0.5);
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
	vec3 col = vec3(0.1);
	vec3 emit = vec3(0.0);
	float rough = 0.7;
	float spec = 0.5;
	vec3 nw = normalize(w_nrm);

	if (v_kind == 5) {
		// The plaza: polar about its middle.
		vec2 d = xz - plaza_c;
		float r = length(d);
		float a = atan(d.y, d.x);
		float ring = floor((r - plaza_r0) / 1.25);
		float rf = fract((r - plaza_r0) / 1.25);
		float n = max(8.0, floor(TAU * (plaza_r0 + ring * 1.25 + 0.6) / 1.6));
		float seg = floor((a / TAU + 0.5) * n + 0.5 * mod(ring, 2.0));
		float h = hash12(vec2(ring, seg));
		col = mix(vec3(0.64, 0.57, 0.47), vec3(0.74, 0.67, 0.56), h) * (0.88 + 0.2 * vnoise(xz * 0.6));
		col *= mix(vec3(1.0), texture(concrete_tex, xz * 0.3).rgb / 0.72, 0.4);
		float fa = fract((a / TAU + 0.5) * n + 0.5 * mod(ring, 2.0));
		float ja = stripe((fract(fa + 0.5) - 0.5) * TAU * r / n, 0.035, fw);
		float jr = stripe((fract(rf + 0.5) - 0.5) * 1.25, 0.035, fw);
		col *= mix(1.0, 0.55, max(ja, jr));
		rough = 0.48;
		// A band of eight-point stars in white marble on dark stone round the fountain's steps.
		float band_in = plaza_r0 + 1.0;
		float band_out = plaza_r0 + 5.0;
		if (r > band_in - 0.6 && r < band_out + 0.6) {
			float stars = floor(TAU * (band_in + band_out) * 0.5 / 4.0);
			float sa = fract((a / TAU + 0.5) * stars) - 0.5;
			vec2 q = vec2(sa * TAU * r / stars, r - (band_in + band_out) * 0.5);
			// An eight-point star: two squares, one turned 45 degrees.
			float s1 = max(abs(q.x), abs(q.y));
			float s2 = (abs(q.x) + abs(q.y)) * 0.7071;
			float star = 1.0 - smoothstep(1.35 - fw, 1.35 + fw, min(s1, s2));
			float inner = 1.0 - smoothstep(0.55 - fw, 0.55 + fw, min(s1, s2));
			float in_band = smoothstep(band_in - fw, band_in + fw, r) * (1.0 - smoothstep(band_out - fw, band_out + fw, r));
			vec3 dark = vec3(0.16, 0.15, 0.17);
			vec3 marble = vec3(0.86, 0.84, 0.80);
			vec3 gold = vec3(0.78, 0.58, 0.26);
			vec3 bc = mix(dark, marble, star);
			bc = mix(bc, gold, inner);
			col = mix(col, bc, in_band);
			// Gold rims either side of the band.
			float rim = max(stripe(r - band_in, 0.18, fw), stripe(r - band_out, 0.18, fw));
			col = mix(col, gold, rim);
			rough = mix(rough, 0.3, in_band);
		}
		// Sixteen rays of dark stone from the band to the rim.
		float rays = 16.0;
		float ra = (fract((a / TAU + 0.5) * rays + 0.5) - 0.5) * TAU * r / rays;
		float ray = stripe(ra, 0.35, fw) * smoothstep(plaza_r0 + 5.5, plaza_r0 + 6.5, r) * (1.0 - smoothstep(plaza_r1 - 2.5, plaza_r1 - 1.5, r));
		col = mix(col, vec3(0.20, 0.18, 0.17), ray);
		// Flush uplights along the rays, a ring of them.
		float lr = 47.0;
		vec2 lq = vec2(ra, r - lr);
		float lamp = 1.0 - smoothstep(0.16, 0.22 + fw, length(lq));
		col = mix(col, vec3(0.9), lamp);
		emit += vec3(1.0, 0.82, 0.55) * 3.5 * lamp;
		// The basalt rim.
		float rim2 = smoothstep(plaza_r1 - 1.4 - fw, plaza_r1 - 1.4 + fw, r);
		col = mix(col, vec3(0.13, 0.12, 0.12) * (0.9 + 0.2 * vnoise(xz * 2.0)), rim2);
	} else if (v_kind == 4) {
		// The tube's deck: dark resin with pale chips; the lane's edges and the walkways.
		col = vec3(0.035, 0.04, 0.055);
		// Pale chips in the resin: few, small, low contrast, gone before they get smaller than a pixel.
		float chip = step(0.94, hash12(floor(xz * 14.0)));
		col = mix(col, vec3(0.16, 0.17, 0.20), chip * (1.0 - smoothstep(0.01, 0.04, fw)));
		rough = 0.22;
		spec = 0.6;
		float walk = smoothstep(half_w + 0.05, half_w + 0.15, ax);
		col = mix(col, vec3(0.20, 0.21, 0.24) * (0.9 + 0.2 * vnoise(xz * 1.5)), walk);
		// LED lines: cyan along the lane's edges, gold dots along the walkways' outer edges.
		float edge = stripe(ax - (half_w - 0.15), 0.14, fx);
		emit += vec3(0.25, 0.85, 1.0) * 4.0 * edge;
		col = mix(col, vec3(0.7, 0.9, 1.0), edge);
		float fy = max(fwidth(y), 1e-4);
		float dots = stripe(ax - (half_w + 1.2), 0.16, fx) * stripe((fract(y / 2.0) - 0.5) * 2.0, 0.16, fy);
		emit += vec3(1.0, 0.75, 0.4) * 3.0 * dots;
		// A slow swell of light drifting along the deck (5 m/s, wide and soft: no flicker).
		float swell = 0.5 + 0.5 * sin(y * TAU / 60.0 - TIME * TAU * 5.0 / 60.0);
		emit *= 0.75 + 0.35 * swell;
		// A row of small studs down the middle.
		float stud = stripe(x, 0.12, fx) * stripe((fract(y / 4.0) - 0.5) * 4.0, 0.14, fy);
		emit += vec3(0.5, 0.8, 1.0) * 1.5 * stud;
	} else if (v_kind == 1) {
		// The souk's setts.
		vec3 tex = texture(sett_tex, xz * 0.6).rgb;
		col = tex / 0.374 * vec3(0.46, 0.40, 0.32);
		col *= 0.9 + 0.2 * vnoise(xz * 0.15);
		rough = mix(0.82, 0.6, 1.0 - smoothstep(1.5, 5.0, ax));
		vec3 sn = texture(sett_normal, xz * 0.6).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(sn.x, 0.0, sn.y) * 0.6);
		// Flat gutter stones along both edges.
		float gut = smoothstep(half_w - 0.9, half_w - 0.85, ax);
		float row = floor(y / 0.7);
		vec3 gc = mix(vec3(0.42, 0.38, 0.33), vec3(0.52, 0.47, 0.40), hash12(vec2(row, sign(x))));
		gc *= mix(1.0, 0.6, stripe((fract(y / 0.7 + 0.5) - 0.5) * 0.7, 0.05, fw));
		col = mix(col, gc, gut);
		nw = normalize(mix(nw, normalize(w_nrm), gut));
	} else if (v_kind == 2) {
		// The palm avenue: pavers 0.6 x 0.3m in a diagonal running bond, two tones, a basalt frame.
		vec2 q = vec2(xz.x + xz.y, xz.x - xz.y) * 0.7071;
		vec2 g = q / vec2(0.6, 0.3);
		float row = floor(g.y);
		g.x += 0.5 * mod(row, 2.0);
		vec2 id = floor(g);
		vec2 f = fract(g);
		float h = hash12(id);
		vec3 terra = vec3(0.56, 0.36, 0.26);
		vec3 sandc = vec3(0.70, 0.60, 0.46);
		col = mix(terra, sandc, step(0.45, h)) * (0.85 + 0.25 * fract(h * 7.3));
		col *= mix(vec3(1.0), texture(concrete_tex, xz * 0.4).rgb / 0.72, 0.5);
		float jd = min(min(f.x, 1.0 - f.x) * 0.6, min(f.y, 1.0 - f.y) * 0.3);
		float jt = (1.0 - smoothstep(0.008, 0.02, jd)) * (1.0 - smoothstep(0.02, 0.1, fw));
		col = mix(col, vec3(0.20, 0.17, 0.15), jt * 0.8);
		rough = 0.66;
		float frame = smoothstep(half_w - 0.75, half_w - 0.7, ax);
		vec3 bas = vec3(0.16, 0.15, 0.15) * (0.85 + 0.3 * hash12(floor(vec2(y / 0.35, x * 3.0))));
		col = mix(col, bas, frame);
		// A sandstone line down the middle.
		col = mix(col, vec3(0.76, 0.70, 0.60), stripe(x, 0.5, fx));
	} else {
		// Asphalt (0) and the bridge deck (3).
		vec3 tex = texture(asphalt_tex, xz * 0.16).rgb;
		float lum = dot(tex, vec3(0.299, 0.587, 0.114)) / 0.35;
		bool deck = v_kind == 3;
		col = (deck ? vec3(0.055, 0.056, 0.062) : vec3(0.075, 0.075, 0.078)) * mix(1.0, lum, 0.75);
		col *= 0.9 + 0.2 * vnoise(xz * 0.05);
		rough = deck ? 0.5 : 0.58;
		// Lane lines: two dashed (3m in 9m), solid edge lines.
		float fy = max(fwidth(y), 1e-4);
		float dash = stripe((fract(y / 9.0) - 0.17) * 9.0, 3.0, fy);
		float lanes = stripe(ax - 2.5, 0.15, fx) * dash;
		float edges = stripe(ax - (half_w - 0.75), 0.18, fx);
		float wear = 0.75 + 0.25 * vnoise(vec2(y * 0.8, x * 3.0));
		col = mix(col, vec3(0.78, 0.78, 0.74), clamp(lanes + edges, 0.0, 1.0) * wear);
		rough = mix(rough, 0.45, clamp(lanes + edges, 0.0, 1.0));
		if (deck) {
			// Blue LED studs along the edge lines, breathing in a slow wave along the bridge.
			float st = stripe(ax - (half_w - 0.75), 0.16, fx) * stripe((fract(y / 3.0) - 0.5) * 3.0, 0.16, fy);
			float wave = 0.55 + 0.45 * sin(y * TAU / 40.0 - TIME * 0.9);
			emit += vec3(0.2, 0.55, 1.0) * 5.0 * st * wave;
			col = mix(col, vec3(0.5, 0.7, 1.0), st);
		} else {
			// Reflective studs on the lane lines (they glint in the lamps).
			float st = stripe(ax - 2.5, 0.14, fx) * stripe((fract(y / 9.0) - 0.5) * 9.0, 0.14, fy);
			emit += vec3(0.9, 0.9, 0.85) * 0.5 * st;
			col = mix(col, vec3(0.8), st);
		}
		// Kerb stones along both edges, a gutter just inside them.
		float gutter = stripe(ax - (half_w - 0.48), 0.12, fx);
		col = mix(col, col * 0.6, gutter);
		float kb = smoothstep(half_w - 0.4, half_w - 0.37, ax);
		col = mix(col, deck ? vec3(0.42, 0.42, 0.44) : kerb(UV, fw), kb);
		rough = mix(rough, 0.7, kb);
	}

	// Where the kind changes: a stone threshold across the road (on decks and in the tube, a steel joint).
	if (v_edge < 0.6) {
		float th = 1.0 - smoothstep(0.45, 0.55, v_edge);
		bool steel = v_kind == 3 || v_kind == 4;
		vec3 tc = steel ? vec3(0.30, 0.31, 0.33) * (0.8 + 0.4 * step(0.5, fract(x * 4.0))) : vec3(0.52, 0.50, 0.47) * (0.85 + 0.25 * hash12(floor(vec2(x / 0.6, 3.0))));
		col = mix(col, tc, th);
		rough = mix(rough, steel ? 0.35 : 0.7, th);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
