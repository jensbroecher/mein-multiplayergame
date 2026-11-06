// The airliners' paint (AirlinerKit.gd's airframes, flown by Airliners.gd): every part of an airframe in one material,
// a livery in its uniforms, so one mesh takes any livery. COLOR.r is the part (AirlinerKit.P_*, (id + 0.5) / 16). The
// fuselage's cabin windows, doors, cockpit glazing, cheatlines and belly, the tail's art and the sweep of the tail's
// colour over the rear fuselage are drawn from the model position (`mpos`, life-size metres, nose toward -z) and UV2
// (x the angle round the fuselage from its top). What differs between airframes comes per instance (`door_z`, `win_z`,
// `art_c`, `nose_z`). At night (`night`) the cabin windows glow and the tail is floodlit, as an airliner's logo lights
// do. It fades out by dither toward the race cameras' 4000m far plane (`fade_begin`..`fade_end`) and as a flight
// begins or ends (`vis`), so nothing pops.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 body_col : source_color = vec3(0.95, 0.95, 0.94);
// The belly's colour below this height (model metres); -99 for none.
uniform vec3 belly_col : source_color = vec3(0.78, 0.79, 0.81);
uniform float belly_y = -1.9;
// Cheatlines along the fuselage: their middle's height and width (-99: none).
uniform vec3 cheat_col : source_color = vec3(0.80, 0.60, 0.24);
uniform float cheat_y = -0.32;
uniform float cheat_w = 0.16;
uniform vec3 cheat2_col : source_color = vec3(0.1);
uniform float cheat2_y = -99.0;
uniform float cheat2_w = 0.1;
// The tail: its colour, its art (0 none, 1 an eight-pointed star, 2 a sun, 3 waves, 4 a band, 5 a crescent) and how
// far ahead of the art's middle the tail's colour starts sweeping over the rear fuselage (99: no sweep).
uniform vec3 fin_col : source_color = vec3(0.42, 0.06, 0.10);
uniform vec3 art_col : source_color = vec3(0.86, 0.66, 0.28);
uniform int art = 1;
uniform float sweep_ahead = 99.0;
uniform vec3 engine_col : source_color = vec3(0.42, 0.06, 0.10);
uniform vec3 wing_col : source_color = vec3(0.71, 0.73, 0.76);
uniform vec3 stab_col : source_color = vec3(0.95, 0.95, 0.94);
uniform vec3 winglet_col : source_color = vec3(0.42, 0.06, 0.10);
// 0 for a freighter: no cabin windows.
uniform float windows = 1.0;
uniform float night = 0.0;
uniform float fade_begin = 3300.0;
uniform float fade_end = 3900.0;

instance uniform float vis = 1.0;
instance uniform vec4 door_z = vec4(-24.0, -12.5, 4.6, 14.6);
instance uniform vec2 win_z = vec2(-25.0, 15.6);
instance uniform vec2 art_c = vec2(25.4, 8.0);
instance uniform float nose_z = -31.5;

varying flat int part;
varying vec3 mpos;

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int idx = q.x + q.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[idx]) + 0.5) / 16.0;
}

// Coverage of a band |d| < w/2, antialiased over `aa`.
float band(float d, float w, float aa) {
	return clamp((w * 0.5 - abs(d)) / max(aa, 1e-4) + 0.5, 0.0, 1.0);
}

// Coverage inside a signed distance (negative inside).
float inside(float sd, float aa) {
	return clamp(0.5 - sd / max(aa, 1e-4), 0.0, 1.0);
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	return sd_box(p, b - vec2(r)) - r;
}

// The tail's art, in metres about its middle (q.x along, q.y up): its coverage.
float tail_art(vec2 q, float aa) {
	if (art == 1) {
		// An eight-pointed star: two squares, one turned 45 degrees, with a ring of the tail's colour in it.
		float s = 1.75;
		vec2 r = vec2(q.x - q.y, q.x + q.y) * 0.70710678;
		float d = min(sd_box(q, vec2(s)), sd_box(r, vec2(s)));
		float star = inside(d, aa);
		float ring = band(length(q) - 0.95, 0.32, aa);
		return star * (1.0 - ring);
	} else if (art == 2) {
		// A sun: a disc and a ring round it.
		float l = length(q);
		return max(inside(l - 1.7, aa), band(l - 2.45, 0.38, aa));
	} else if (art == 3) {
		// Waves across the tail's foot.
		float w1 = -1.4 + 0.55 * sin(q.x * 1.25 + 0.4);
		float w2 = -0.2 + 0.55 * sin(q.x * 1.25 + 1.3);
		float lower = inside(q.y - w1, aa);
		float stripe = band(q.y - w2, 0.42, aa);
		return max(lower, stripe);
	} else if (art == 4) {
		// A broad band raked with the tail's leading edge, and a narrow one behind it.
		float b = q.x - q.y * 0.86;
		return max(band(b + 0.6, 1.5, aa), band(b - 1.15, 0.38, aa));
	} else if (art == 5) {
		// A crescent and a small star by it.
		float c = inside(length(q - vec2(-0.4, 0.0)) - 2.2, aa) * (1.0 - inside(length(q - vec2(0.45, 0.35)) - 1.9, aa));
		vec2 sq = q - vec2(1.05, 0.25);
		vec2 sr = vec2(sq.x - sq.y, sq.x + sq.y) * 0.70710678;
		float st = inside(min(sd_box(sq, vec2(0.42)), sd_box(sr, vec2(0.42))), aa);
		return max(c, st);
	}
	return 0.0;
}

void vertex() {
	part = int(COLOR.r * 16.0);
	mpos = VERTEX;
}

void fragment() {
	float dist = length(VERTEX);
	float f = (1.0 - smoothstep(fade_begin, fade_end, dist)) * vis;
	if (f < 0.999 && f < bayer4(FRAGCOORD.xy)) {
		discard;
	}
	float aa = max(length(fwidth(mpos)), 0.004);
	vec3 col = body_col;
	float rough = 0.3;
	float metal = 0.0;
	float spec = 0.5;
	vec3 emit = vec3(0.0);
	float flood = 0.0;
	if (part == 0) {
		// The fuselage.
		if (belly_y > -90.0) {
			col = mix(col, belly_col, inside(mpos.y - belly_y, aa));
		}
		if (cheat_y > -90.0) {
			col = mix(col, cheat_col, band(mpos.y - cheat_y, cheat_w, aa));
		}
		if (cheat2_y > -90.0) {
			col = mix(col, cheat2_col, band(mpos.y - cheat2_y, cheat2_w, aa));
		}
		// The tail's colour sweeping forward over the rear fuselage, edged by a line of the art's colour.
		float sz = art_c.x - sweep_ahead;
		if (sweep_ahead < 90.0 && mpos.z > sz) {
			float line_y = 3.6 - (mpos.z - sz) * 0.42;
			float over = inside(line_y - mpos.y, aa);
			col = mix(col, fin_col, over);
			col = mix(col, art_col, band(mpos.y - (line_y - 0.16), 0.13, aa) * step(0.0, mpos.z - sz - 1.0));
			flood = over * 0.6;
		}
		// The doors: an outline each, with its own window.
		float door_line = 0.0;
		float in_door = 0.0;
		for (int i = 0; i < 4; i++) {
			float dz = door_z[i];
			float d = sd_round_box(vec2(mpos.z - dz, mpos.y - 0.25), vec2(0.56, 1.0), 0.22);
			door_line = max(door_line, band(d, 0.045, aa));
			in_door = max(in_door, inside(d - 0.15, aa));
		}
		// The cabin windows, every 0.53m between the first and the last, a door's width clear of each door but for
		// the window in it.
		float win = 0.0;
		if (windows > 0.5 && mpos.z > win_z.x && mpos.z < win_z.y) {
			float cell = (mpos.z - win_z.x) / 0.53;
			float wz = (fract(cell) - 0.5) * 0.53;
			float w = inside(sd_round_box(vec2(wz, mpos.y - 0.62), vec2(0.13, 0.19), 0.1), aa);
			win = w * (1.0 - in_door);
		}
		for (int i = 0; i < 4; i++) {
			win = max(win, inside(sd_round_box(vec2(mpos.z - door_z[i], mpos.y - 0.62), vec2(0.12, 0.17), 0.09), aa));
		}
		// The cockpit's glazing on the nose: one band between a forward edge and an aft edge that both sweep back down
		// the nose's sides, from the centre post at the top to the side windows' sills, cut into panes by posts (in
		// distance from the nose's tip, metres, and angle from the top, radians).
		float a = UV2.x;
		float dn = mpos.z - nose_z;
		float aa_g = max(max(fwidth(dn), fwidth(a) * 2.6), 0.004);
		float fwd_e = 3.18 + 0.52 * a * a;
		float aft_e = 4.38 + 0.62 * a;
		float glaze = inside(max(max(fwd_e - dn, dn - aft_e), max(0.035 - a, a - 1.12)) * 1.0, aa_g);
		float posts = max(band(a - 0.53, 0.055, max(fwidth(a), 1e-4)), band(a - 0.87, 0.05, max(fwidth(a), 1e-4)));
		float pane = glaze * (1.0 - posts);
		col = mix(col, vec3(0.22, 0.23, 0.25), door_line * (1.0 - win) * 0.75);
		vec3 glass = vec3(0.025, 0.03, 0.04);
		col = mix(col, glass, max(win, pane));
		rough = mix(0.28, 0.05, max(win, pane));
		spec = mix(0.5, 0.9, max(win, pane));
		emit += vec3(1.0, 0.78, 0.48) * win * night * 1.5;
		emit += vec3(0.45, 0.55, 0.75) * pane * night * 0.12;
	} else if (part == 1 || part == 13) {
		col = wing_col;
		rough = 0.42;
		metal = 0.15;
	} else if (part == 2) {
		col = fin_col;
		vec2 q = vec2(mpos.z - art_c.x, mpos.y - art_c.y);
		col = mix(col, art_col, tail_art(q, aa));
		flood = 1.0;
	} else if (part == 3) {
		col = stab_col;
		rough = 0.35;
	} else if (part == 4) {
		col = engine_col;
		rough = 0.25;
	} else if (part == 5) {
		col = vec3(0.80, 0.81, 0.83);
		metal = 0.9;
		rough = 0.22;
	} else if (part == 6) {
		col = vec3(0.02);
		rough = 0.6;
	} else if (part == 7) {
		col = vec3(0.22, 0.21, 0.20);
		metal = 0.6;
		rough = 0.45;
	} else if (part == 8) {
		col = body_col;
	} else if (part == 9) {
		col = vec3(0.62, 0.63, 0.65);
		metal = 0.55;
		rough = 0.4;
	} else if (part == 10) {
		col = vec3(0.03);
		rough = 0.85;
		spec = 0.3;
	} else if (part == 11) {
		col = belly_y > -90.0 ? belly_col : body_col;
	} else if (part == 12) {
		col = winglet_col;
		flood = 0.3;
	} else if (part == 14) {
		col = vec3(0.55, 0.56, 0.58);
		metal = 0.5;
		rough = 0.35;
	} else if (part == 15) {
		col = vec3(0.05);
		metal = 0.5;
		rough = 0.3;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	// The logo lights: floodlights on the tailplane wash the tail from below.
	float wash = flood * (0.2 + 0.6 * (1.0 - smoothstep(2.0, 14.0, mpos.y)));
	EMISSION = emit + col * wash * night * 0.55;
}
