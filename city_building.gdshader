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
	} else if (vcol.a > 0.5) {
		// Curtain wall: glass panels in a mullion grid, a different tint floor by floor.
		vec2 g = vec2(UV.x / (bay * 0.5), UV.y / 4.0);  // two panels a bay: a mullion falls on every corner
		vec2 f = fract(g);
		float mull = step(0.06, f.x) * step(0.08, f.y);
		float floor_v = hash21(vec2(floor(g.y), vcol.r * 13.0));
		vec3 glass = mix(glass_dark.rgb, sky_reflect.rgb * paint * 1.6, 0.35 + 0.3 * floor_v);
		col = mix(paint * 0.6, glass, mull);
		rough = mix(0.5, 0.12, mull);
		metal = 0.3 * mull;
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
			float win = step(0.22, f.x) * step(f.x, 0.78) * step(0.3, f.y) * step(f.y, 0.82);
			vec3 glass = mix(glass_dark.rgb, sky_reflect.rgb * 0.7, 0.25 + 0.25 * rnd);
			if (rnd > 0.8) {
				glass = mix(glass, vec3(0.55, 0.30, 0.20) * (0.6 + rnd * 0.4), 0.6);
			}
			float frame = win * (1.0 - step(0.25, f.x) * step(f.x, 0.75) * step(0.33, f.y) * step(f.y, 0.79));
			col = mix(col, glass, win * detail);
			col = mix(col, vec3(0.8), frame * detail * 0.6);
			float ledge = step(0.0, f.y) * step(f.y, 0.05);
			col *= 1.0 - ledge * 0.25 * detail;
			rough = mix(rough, 0.2, win * detail);
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
}
