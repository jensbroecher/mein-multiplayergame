shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Nyota Stadium's city: box buildings with the facade drawn here. Walls carry UV = (metres along
// the wall, metres up from the street), roofs UV = world XZ. Each wall's length is a whole number of
// bays in UV.x (and of shop fronts in UV2.x, which has the shop fronts' own count), so a window never
// straddles a corner; the generator stretches them by a few percent to make it so. The vertex colour is the wall paint;
// COLOR.a picks the facade: below 0.5 a concrete block (storeys of punched windows, a shopfront
// on the ground floor; 0.25 a low one with a painted iron roof), above it a glass curtain wall
// (the towers in town).

uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float storey = 4.6;
uniform float bay = 4.0;
uniform float shop_h = 6.0;
uniform vec4 sky_reflect : source_color = vec4(0.58, 0.70, 0.86, 1.0);
uniform vec4 glass_dark : source_color = vec4(0.10, 0.13, 0.17, 1.0);
// What the glass reflects: a made-up sky from the reflected direction (no real reflection is computed). The
// generator sets these to the level's sky.
uniform vec3 refl_top : source_color = vec3(0.14, 0.38, 0.80);
uniform vec3 refl_horizon : source_color = vec3(0.80, 0.86, 0.93);
uniform vec3 refl_ground : source_color = vec3(0.34, 0.32, 0.30);
uniform vec3 refl_cloud : source_color = vec3(1.0, 0.98, 0.95);
// How strongly the panes reflect face-on (the Fresnel term rises to 1 at a grazing angle).
uniform float refl_base = 0.11;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 vcol;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The reflected sky: a gradient to the horizon with soft cloud puffs, and darker ground below it.
vec3 reflected_sky(vec3 r) {
	float h = r.y;
	vec3 sky = mix(refl_horizon, refl_top, pow(clamp(h, 0.0, 1.0), 0.5));
	vec2 uv = r.xz / (max(h, 0.0) + 0.3) * 1.6;
	float cl = vnoise(uv * 1.3) * 0.65 + vnoise(uv * 2.9 + 7.0) * 0.35;
	sky = mix(sky, refl_cloud, smoothstep(0.52, 0.78, cl) * 0.85 * smoothstep(0.0, 0.25, h));
	vec3 ground = mix(refl_ground, refl_ground * 0.35, clamp(-h * 2.5, 0.0, 1.0));
	return mix(ground, sky, smoothstep(-0.06, 0.06, h));
}

void fragment() {
	vec3 paint = pow(vcol.rgb, vec3(2.2));
	float cam_d = length(w_pos - CAMERA_POSITION_WORLD);
	// Window detail fades out before it can alias.
	float detail = 1.0 - smoothstep(250.0, 900.0, cam_d);
	vec3 n = normalize(w_nrm);
	vec3 conc = texture(concrete_tex, UV * 0.15).rgb;
	vec3 col = paint * (0.8 + conc * 0.35);
	float rough = 0.9;
	float metal = 0.0;
	vec3 emis = vec3(0.0);
	float spec = 0.5;
	vec3 view_w = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 refl_dir = reflect(-view_w, n);
	float fresnel = refl_base + (1.0 - refl_base) * pow(1.0 - clamp(dot(n, view_w), 0.0, 1.0), 4.0);
	if (n.y > 0.6) {
		// Roofs: concrete on the blocks and towers; painted corrugated iron (mabati) on the low
		// buildings, rusty red, green, blue or bare.
		float rid = hash21(floor(w_pos.xz / 7.0) * 0.0 + vcol.rg * 97.0 + vcol.b * 13.0);
		col = vec3(0.24, 0.235, 0.23) * (0.8 + conc * 0.4);
		if (vcol.a > 0.12 && vcol.a < 0.5 && rid > 0.3) {
			vec3 mabati[4] = vec3[](vec3(0.32, 0.11, 0.07), vec3(0.12, 0.24, 0.16), vec3(0.14, 0.20, 0.32), vec3(0.36, 0.36, 0.37));
			float rib = 0.85 + 0.15 * sin(w_pos.x * 6.0 + w_pos.z * 0.3);
			col = mabati[int(rid * 37.0) % 4] * rib;
			rough = 0.55;
			metal = 0.3;
		}
	} else if (vcol.a > 0.5 && vcol.a <= 0.9) {
		// Plain concrete: cornices, balconies, pilasters, canopies, plant rooms (no windows). 0.8 is railing:
		// vertical bars with gaps between them.
		if (vcol.a > 0.75) {
			if (fract(UV.x * 4.0 / 0.42) > 0.20) {
				discard;
			}
			col = paint * 0.7;
		}
		rough = 0.8;
	} else if (vcol.a > 0.9) {
		// Curtain wall: glass panels in a mullion grid, a different tint floor by floor.
		vec2 g = vec2(UV.x / (bay * 0.5), UV.y / 4.0);  // two panels a bay: a mullion falls on every corner
		vec2 f = fract(g);
		float mull = step(0.06, f.x) * step(0.08, f.y);
		float floor_v = hash21(vec2(floor(g.y), vcol.r * 13.0));
		// Dark glass, mirror-like: a reflected sky scaled by the Fresnel term (and a glint from the real specular).
		vec3 tint = mix(vec3(0.05, 0.08, 0.12), vec3(0.04, 0.10, 0.09), step(0.55, hash21(vec2(floor(g.y), vcol.g * 29.0))));
		vec3 glass = tint * (0.8 + 0.8 * floor_v) + paint * 0.04;
		col = mix(paint * 0.6, glass, mull);
		rough = mix(0.5, 0.04, mull);
		spec = mix(0.5, 1.0, mull);
		emis = reflected_sky(refl_dir) * clamp(fresnel * 1.5, 0.0, 1.0) * (0.7 + 0.5 * floor_v) * mull * detail;
		col = mix(col, mix(glass_dark.rgb, sky_reflect.rgb, 0.4) * (0.8 + paint * 0.4), 1.0 - detail);
	} else {
		float y = UV.y;
		vec2 cellid = vec2(floor(UV.x / bay), floor((y - shop_h) / storey));
		float rnd = hash21(cellid + vcol.rg * 31.0);
		if (y < shop_h) {
			// Ground floor: shop fronts behind rolled-up shutters, a sign band over them.
			float u = fract(UV2.x / (bay * 1.5));
			float opening = step(0.08, u) * step(u, 0.92) * step(0.2, y) * step(y, shop_h - 1.6);
			float sign_band = step(shop_h - 1.4, y) * step(y, shop_h - 0.3);
			float shop_rnd = hash21(vec2(floor(UV2.x / (bay * 1.5)), vcol.b * 17.0));
			vec3 inside = mix(vec3(0.08, 0.07, 0.06), vec3(0.35, 0.30, 0.24), shop_rnd * 0.6);
			vec3 sign_cols[6] = vec3[](vec3(0.85, 0.15, 0.10), vec3(0.10, 0.45, 0.75), vec3(0.95, 0.75, 0.10),
					vec3(0.10, 0.55, 0.25), vec3(0.95, 0.95, 0.92), vec3(0.85, 0.40, 0.08));
			vec3 sgn = pow(sign_cols[int(shop_rnd * 6.0) % 6], vec3(1.0));
			col = mix(col, inside, opening * detail);
			col = mix(col, sgn * 0.8, sign_band * detail);
		} else {
			// Punched windows, a few with curtains or open; a ledge under every storey.
			vec2 f = vec2(fract(UV.x / bay), fract((y - shop_h) / storey));
			// The window's shape in the bay, by the building's style (UV2.y): punched, a ribbon, a narrow pair, tall.
			float style = UV2.y;
			float wx0 = 0.22;
			float wx1 = 0.78;
			float wy0 = 0.30;
			float wy1 = 0.82;
			if (style > 0.5 && style < 1.5) {
				wx0 = 0.04; wx1 = 0.96; wy0 = 0.40; wy1 = 0.76;
			} else if (style > 2.5) {
				wx0 = 0.30; wx1 = 0.70; wy0 = 0.14; wy1 = 0.88;
			}
			float pair_gap = (style > 1.5 && style < 2.5) ? step(0.14, f.x) * step(f.x, 0.40) + step(0.60, f.x) * step(f.x, 0.86) : 1.0;
			if (style > 1.5 && style < 2.5) {
				wx0 = 0.14; wx1 = 0.86; wy0 = 0.26; wy1 = 0.86;
			}
			float win = step(wx0, f.x) * step(f.x, wx1) * step(wy0, f.y) * step(f.y, wy1) * min(pair_gap, 1.0);
			// Glass: dark, with a tint (blue, green, bronze, grey), reflecting the sky. A pane with a curtain is dull.
			float tint_pick = hash21(cellid * 1.7 + vcol.b * 53.0);
			vec3 tint = tint_pick < 0.45 ? vec3(0.05, 0.09, 0.14) : (tint_pick < 0.70 ? vec3(0.04, 0.11, 0.10) : (tint_pick < 0.88 ? vec3(0.12, 0.09, 0.06) : vec3(0.08, 0.09, 0.10)));
			vec3 glass = tint * (0.7 + 0.8 * rnd);
			float curtain = step(0.8, rnd);
			if (curtain > 0.5) {
				glass = mix(glass, vec3(0.55, 0.30, 0.20) * (0.6 + rnd * 0.4), 0.6);
			}
			float frame = win * (1.0 - step(wx0 + 0.03, f.x) * step(f.x, wx1 - 0.03) * step(wy0 + 0.03, f.y) * step(f.y, wy1 - 0.03));
			// The window is set back in the wall: its glass is shaded along the top and the left inside the opening
			// (the reveal), and the wall has a lit sill under it, a dark line under that and a lintel over it.
			float reveal = win * max(smoothstep(wy1 - 0.10, wy1, f.y), 1.0 - smoothstep(wx0, wx0 + 0.09, f.x));
			glass *= 1.0 - 0.5 * reveal;
			float in_x = step(wx0 - 0.05, f.x) * step(f.x, wx1 + 0.05);
			float sill = in_x * step(wy0 - 0.05, f.y) * step(f.y, wy0);
			float sill_shadow = in_x * step(wy0 - 0.11, f.y) * step(f.y, wy0 - 0.05);
			float lintel = in_x * step(wy1, f.y) * step(f.y, wy1 + 0.06);
			col = mix(col, glass, win * detail);
			col = mix(col, vec3(0.78, 0.77, 0.74), frame * detail * 0.55);
			col = mix(col, min(col * 1.22 + 0.04, vec3(1.0)), sill * detail);
			col *= 1.0 - (0.22 * sill_shadow + 0.14 * lintel) * detail;
			float ledge = step(0.0, f.y) * step(f.y, 0.05);
			col *= 1.0 - ledge * 0.25 * detail;
			// Reflective glass: low roughness for the sun's glint, and the reflected sky as emission, brighter
			// toward the top of each pane (and brighter on some floors than others).
			rough = mix(rough, mix(0.05, 0.6, curtain), win * detail);
			spec = mix(spec, mix(1.0, 0.3, curtain), win * detail);
			float pane_grad = mix(0.65, 1.15, smoothstep(wy0, wy1, f.y));
			// A fifth of the panes look into a dark room and reflect less.
			float room = mix(1.0, 0.35, step(0.8, hash21(cellid * 5.3 + 1.0)));
			emis = reflected_sky(refl_dir) * clamp(fresnel * 1.5, 0.0, 1.0) * pane_grad * (0.75 + 0.5 * hash21(cellid * 3.1 + 5.0)) * room * (1.0 - curtain * 0.9) * (1.0 - 0.6 * reveal) * win * detail;
			// Rain streaks down from the roof line, darker under the windows.
			float streak = hash21(vec2(floor(UV.x * 1.3), vcol.g * 7.0));
			col *= 1.0 - 0.12 * streak * (1.0 - win) * detail;
		}
		// Far away: the average of wall and windows.
		col = mix(col, paint * 0.7 + glass_dark.rgb * 0.2, (1.0 - detail) * 0.6);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	EMISSION = emis;
}
