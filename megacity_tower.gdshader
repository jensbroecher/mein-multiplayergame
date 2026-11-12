shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Tianqiao's buildings at night (MegacityKit.gd, regenerate_tianqiao.gd). Walls carry UV = (metres along the wall plus
// 1000 x the building's number, metres up from the street); roofs UV = world XZ. The vertex colour is the facade's tint,
// COLOR.a x 8 picks the facade:
//   0 office curtain wall: dark blue-green glass, mullions, whole floors lit (cool or warm), spandrels
//   1 residential slab: tiled wall, punched windows lit warm or cool (a few TV-blue), AC units under them
//   2 media facade: glass under a grid of LEDs running a light show (bands, waves, ripples, sparkle, the palette turning)
//   3 shop fronts: lit shop windows to 5.5m, a glowing sign band over each bay, residential floors above
//   4 lit interior wall (the mall): cream panels, a light strip at every floor, shop windows on the floors
//   5 concrete (roofs, parapets, piers): no lights
//   6 dark cladding with a cyan LED line at every storey (the skyways' and the crown's)
// Window detail fades to its average with distance, so it never aliases.

uniform float storey = 4.2;
uniform float bay = 3.6;
uniform float lit_energy = 2.4;
uniform float led_energy = 3.2;
uniform float show_speed = 1.0;

varying vec3 w_pos;
varying flat vec4 vkey;
varying flat float seed;
varying vec2 wuv;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vkey = COLOR;
	float k = floor(UV.x / 1000.0);
	seed = fract(k * 0.61803 + 0.137);
	wuv = vec2(UV.x - k * 1000.0, UV.y);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 palette(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

// The LED show on a media facade at (u, v) metres: 0..1 brightness and a colour.
vec4 led_show(vec2 uv, float s) {
	float t = TIME * show_speed + s * 97.0;
	float mode = floor(mod(t / 14.0 + s * 9.0, 5.0));
	float v = 0.0;
	if (mode < 0.5) {
		v = 0.5 + 0.5 * sin(uv.y * 0.18 - t * 2.2);
	} else if (mode < 1.5) {
		v = 0.5 + 0.5 * sin(uv.x * 0.22 + t * 1.7 + sin(uv.y * 0.05) * 2.0);
	} else if (mode < 2.5) {
		float r = length(vec2(uv.x - 20.0, (uv.y - 60.0) * 0.6));
		v = 0.5 + 0.5 * sin(r * 0.25 - t * 3.0);
	} else if (mode < 3.5) {
		float cell = hash21(floor(uv / 1.8) + floor(t * 3.0));
		v = step(0.82, cell);
	} else {
		// A rising bar graph.
		float col = floor(uv.x / 2.4);
		float h = (0.5 + 0.5 * sin(t * 1.3 + col * 0.7)) * 90.0 + 10.0;
		v = step(uv.y, h) * (0.4 + 0.6 * step(h - 4.0, uv.y));
	}
	vec3 c = palette(uv.y * 0.004 + t * 0.03 + s);
	return vec4(c, v);
}

// Far off, where single windows would alias: how lit a
// stretch of one floor (six bays) is, so a far tower reads as bands of lit and dark floors, not a flat glow.
float far_lit(vec2 uv, float s) {
	vec2 cell = floor(uv / vec2(bay * 6.0, storey));
	float h = hash21(cell + s * 53.0);
	return 0.12 + 0.45 * smoothstep(0.3, 0.95, h);
}

void fragment() {
	vec3 tint = pow(vkey.rgb, vec3(2.2));
	int style = int(vkey.a * 8.0 + 0.5);
	vec2 uv = wuv;
	float cam_d = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(180.0, 700.0, cam_d);
	float fl = floor(uv.y / storey);
	float fy = fract(uv.y / storey);
	float bx = floor(uv.x / bay);
	float fx = fract(uv.x / bay);
	vec3 alb = tint;
	vec3 emi = vec3(0.0);
	float rough = 0.85;
	float metal = 0.0;
	float spec = 0.4;
	if (style == 0) {
		float mull = 1.0 - step(0.05, fx) * step(fx, 0.95);
		float span = step(fy, 0.2);
		float floor_on = step(0.42, hash21(vec2(fl, seed * 97.0 + floor(uv.x / 60.0))));
		float room = hash21(vec2(floor(uv.x / (bay * 2.0)), fl + seed * 31.0));
		vec3 light = mix(vec3(0.75, 0.88, 1.0), vec3(1.0, 0.82, 0.58), step(0.7, room));
		float on = floor_on * step(0.18, room);
		vec3 near_e = light * on * (1.0 - span) * (1.0 - mull) * (0.6 + 0.4 * room);
		vec3 far_e = vec3(0.85, 0.9, 1.0) * far_lit(uv, seed) * 0.62;
		emi = mix(far_e, near_e, detail) * lit_energy * 0.55;
		alb = mix(tint * 0.22, tint * 0.5, max(span, mull));
		rough = mix(0.08, 0.6, max(span, mull));
		metal = 0.5;
		spec = 0.7;
	} else if (style == 1) {
		float win = step(0.22, fx) * step(fx, 0.78) * step(0.3, fy) * step(fy, 0.82);
		float r = hash21(vec2(bx + seed * 61.0, fl));
		float on = step(0.42, r);
		vec3 light = mix(vec3(1.0, 0.74, 0.46), vec3(0.85, 0.92, 1.0), step(0.72, r));
		light = mix(light, vec3(0.35, 0.5, 1.0), step(0.95, r));
		float ac = step(0.6, fx) * step(fx, 0.82) * step(0.12, fy) * step(fy, 0.26) * step(0.5, hash21(vec2(bx, fl + 3.0)));
		vec3 near_e = light * on * win * (0.7 + 0.3 * hash21(vec2(r, 2.0)));
		vec3 far_e = vec3(1.0, 0.8, 0.6) * far_lit(uv, seed) * 0.3;
		emi = mix(far_e, near_e, detail) * lit_energy * 0.6;
		alb = mix(tint * 0.55, vec3(0.03), win * detail);
		alb = mix(alb, vec3(0.45), ac * detail);
		rough = mix(0.8, 0.15, win * detail);
	} else if (style == 2) {
		vec4 show = led_show(uv, seed);
		vec2 dot_uv = fract(uv / 0.9) - 0.5;
		float dotm = mix(0.55, smoothstep(0.42, 0.18, length(dot_uv)), detail);
		emi = show.rgb * show.a * dotm * led_energy;
		alb = tint * 0.15;
		rough = 0.1;
		metal = 0.6;
		spec = 0.7;
	} else if (style == 3) {
		float sh = 5.5;
		if (uv.y < sh) {
			float frame = 1.0 - step(0.06, fx) * step(fx, 0.94) * step(0.35, uv.y) * step(uv.y, sh - 0.5);
			float r = hash21(vec2(bx + seed * 13.0, 7.0));
			vec3 light = mix(vec3(1.0, 0.86, 0.62), vec3(0.9, 0.95, 1.0), step(0.5, r));
			float shelves = 0.75 + 0.25 * step(0.5, fract(uv.y * 1.6));
			emi = light * (1.0 - frame) * shelves * lit_energy * mix(0.6, 0.9, detail);
			alb = mix(vec3(0.05), tint * 0.4, frame);
			rough = mix(0.1, 0.7, frame);
		} else if (uv.y < sh + 1.6) {
			float r2 = hash21(vec2(floor(uv.x / (bay * 2.0)) + seed * 5.0, 3.0));
			vec3 c = palette(r2);
			float edge = step(0.05, fract(uv.x / (bay * 2.0))) * step(sh + 0.15, uv.y) * step(uv.y, sh + 1.45);
			emi = c * edge * led_energy * 0.7;
			alb = tint * 0.2;
		} else {
			float win = step(0.25, fx) * step(fx, 0.75) * step(0.3, fy) * step(fy, 0.8);
			float r3 = hash21(vec2(bx + seed * 61.0, fl));
			vec3 light = mix(vec3(1.0, 0.74, 0.46), vec3(0.85, 0.92, 1.0), step(0.7, r3));
			emi = mix(vec3(1.0, 0.8, 0.6) * far_lit(uv, seed) * 0.3, light * step(0.45, r3) * win, detail) * lit_energy * 0.55;
			alb = mix(tint * 0.5, vec3(0.03), win * detail);
		}
	} else if (style == 4) {
		float strip = smoothstep(0.06, 0.0, abs(fy - 0.02));
		float shopw = step(0.08, fx) * step(fx, 0.92) * step(0.12, fy) * step(fy, 0.78) * step(0.3, hash21(vec2(bx + seed * 7.0, fl)));
		float r4 = hash21(vec2(bx, fl + seed * 3.0));
		vec3 light = mix(vec3(1.0, 0.9, 0.72), palette(r4) * 0.6 + 0.4, step(0.75, r4));
		emi = (vec3(1.0, 0.95, 0.85) * strip * 1.4 + light * shopw) * lit_energy * 0.6;
		alb = mix(tint, vec3(0.06), shopw);
		rough = mix(0.5, 0.15, shopw);
	} else if (style == 5) {
		float n = hash21(floor(uv * 2.0)) * 0.08;
		alb = tint * (0.92 + n);
		rough = 0.9;
	} else {
		float line = smoothstep(0.08, 0.0, abs(fy - 0.5)) * detail + (1.0 - detail) * 0.12;
		emi = vec3(0.2, 0.85, 1.0) * line * led_energy * 0.8;
		alb = tint * 0.3;
		rough = 0.3;
		metal = 0.6;
	}
	// Far off the walls lose their colour into the night (lit only by their windows' average glow).
	if (style <= 1 || style == 3) {
		alb *= mix(0.35, 1.0, detail);
		emi *= 1.0;
	}
	ALBEDO = alb;
	EMISSION = emi;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
}
