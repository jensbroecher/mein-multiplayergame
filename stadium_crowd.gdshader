shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Nyota Stadium's crowd at a distance: one card per spectator (a MultiMesh per cell), facing the arena, the
// figure drawn here rather than textured. Up close the same spectator is a 3D figure
// (stadium_person.gdshader); the two crossfade by dither (tree_lod.gdshaderinc, lod_mode 2 here) and read the
// same INSTANCE_CUSTOM (crowd_common.gdshaderinc), so it is the same person at either distance.
//
// Drawn in person space: x across, y up with the pelvis at 0 (a seated spectator's seat plane, or a standing
// one's hip, 1.65 over the ground). The card is a rectangle sized to its pose (the generator has a mesh for
// each: a standing one reaches the ground, one with its arms up is wider): `card_w` x `card_h`, its bottom
// `card_below` under the pelvis, its middle `card_x` along. The figure has the 3D one's proportions.
//
// Cost: the stands are many layers of overlapping cards, so a pixel is shaded many times. Everything about a
// spectator is worked out once per card in vertex(), and fragment() draws its outline first and gives up
// before choosing any colour for the pixels outside it.

#include "res://tree_lod.gdshaderinc"
#include "res://crowd_common.gdshaderinc"

uniform float card_w = 1.1;
uniform float card_h = 2.75;
uniform float card_below = 0.9;
uniform float card_x = 0.0;

varying flat vec4 v_skin;     // skin rgb, hair style
varying flat vec4 v_hair;     // hair rgb, dress (0 or 1)
varying flat vec4 v_shirt;    // shirt rgb, shirt pattern
varying flat vec4 v_shirt2;   // second colour rgb, long sleeves (0 or 1)
varying flat vec4 v_trousers; // trousers rgb, long trousers (0 or 1)
varying flat vec4 v_misc;     // height scale, build, pose, wave phase
varying flat vec4 v_acc;      // cap or headscarf rgb, flag colour index
varying float cam_dist;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	int pose = crowd_pose(cd);
	float ph = cd.a * 6.2831;
	float bob = 0.012 * sin(TIME * 1.7 + ph);
	if (pose == 9) {
		bob += abs(sin(TIME * 3.3 + ph)) * 0.34;
	}
	VERTEX.y += bob;
	cam_dist = lod_distance(MODEL_MATRIX[3].xyz, CAMERA_POSITION_WORLD);

	bool kid;
	float hs = crowd_height(cd, kid);
	int group;
	vec3 skin = crowd_skin(cd, group);
	bool female = crowd_rand(cd, 10.0) < 0.48;
	bool dress = female && crowd_rand(cd, 11.0) > 0.60;
	int hair = crowd_hair_style(cd, group, female);
	int shirt_i = int(floor(crowd_rand(cd, 1.0) * 12.0)) % 12;
	float build = (female ? 0.92 : 1.03) * (0.94 + 0.12 * crowd_rand(cd, 12.0));
	if (kid) build = hs;
	v_skin = vec4(skin, float(hair));
	v_hair = vec4(crowd_hair_colour(cd, group), dress ? 1.0 : 0.0);
	v_shirt = vec4(shirt_at(shirt_i), float(int(floor(crowd_rand(cd, 15.0) * 8.0))));
	v_shirt2 = vec4(shirt_at(shirt_i + 5), crowd_rand(cd, 13.0) > 0.62 ? 1.0 : 0.0);
	v_trousers = vec4(crowd_trousers(cd), crowd_rand(cd, 14.0) > 0.18 ? 1.0 : 0.0);
	v_misc = vec4(hs, build, float(pose), ph);
	v_acc = vec4(hair == 5 ? shirt_at(shirt_i + 7) : shirt_at(shirt_i + 3), float(int(floor(crowd_rand(cd, 17.0) * 3.0))));
}

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_seg(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

void fragment() {
	if (lod_hidden(cam_dist, FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	int pose = int(v_misc.z + 0.5);
	bool standing = pose >= 7;
	int hair = int(v_skin.w + 0.5);
	bool dress = v_hair.w > 0.5;
	float hs = v_misc.x;
	float build = v_misc.y;

	// Person space: the pelvis at 0, scaled about the feet (standing) or the seat (sitting).
	vec2 p = vec2((UV.x - 0.5) * card_w + card_x, (1.0 - UV.y) * card_h - card_below);
	float base_y = standing ? 1.65 : 0.0;
	vec2 q = vec2(p.x / build, (p.y + base_y) / hs - base_y);
	vec2 m = vec2(abs(q.x), q.y);

	// The outline, the cheap shapes first.
	float torso = sd_box(q - vec2(0.0, 0.52), vec2(0.36, 0.62), 0.16);
	float neck = sd_box(q - vec2(0.0, 1.20), vec2(0.08, 0.12), 0.03);
	float head = length((q - vec2(0.0, 1.42)) / vec2(0.20, 0.245)) * 0.22 - 0.22;
	float d = min(min(torso, neck), head);
	float hair_d = 10.0;
	if (hair == 2) {
		hair_d = length((q - vec2(0.0, 1.47)) / vec2(0.29, 0.32)) * 0.30 - 0.30;
	} else if (hair == 3) {
		hair_d = sd_box(q - vec2(0.0, 1.12), vec2(0.23, 0.34), 0.08);
	} else if (hair == 5) {
		hair_d = length((q - vec2(0.0, 1.43)) / vec2(0.25, 0.29)) * 0.26 - 0.26;
	}
	d = min(d, hair_d);
	// Arms: down, they are in the torso's outline; raised, a V (or one arm waving, the other down).
	float arm = 10.0;
	float wave = sin(TIME * 5.2 + v_misc.w * 6.0) * 0.12;
	if (pose == 5 || pose == 9) {
		arm = sd_seg(m, vec2(0.36, 0.96), vec2(0.95 + wave, 1.95), 0.085);
	} else if (pose == 12 || pose == 14) {
		arm = sd_seg(q, vec2(-0.36, 0.96), vec2(-0.90 - wave, 1.90), 0.085);
	}
	d = min(d, arm);
	float flag = 10.0;
	vec2 fq = q - vec2(-1.30, 2.55);
	if (pose == 12) {
		flag = min(sd_seg(q, vec2(-0.95, 1.95), vec2(-1.05, 3.00), 0.02), sd_box(fq, vec2(0.40, 0.28), 0.02));
		d = min(d, flag);
	}
	// Legs: the two are mirror images. Standing: straight to the ground; seated: the knees and the shins down.
	float legs = 10.0;
	float shoes = 10.0;
	float skirt = 10.0;
	if (q.y < 0.1) {
		float lx = 0.16;
		if (standing) {
			legs = sd_seg(m, vec2(lx, -0.05), vec2(lx, -1.52), 0.12);
			shoes = sd_box(m - vec2(lx, -1.56), vec2(0.10, 0.08), 0.05);
			if (dress) {
				skirt = sd_box(q - vec2(0.0, -0.45), vec2(0.36, 0.35), 0.08);
			}
		} else {
			legs = min(sd_box(m - vec2(lx + 0.01, -0.10), vec2(0.15, 0.12), 0.08), sd_seg(m, vec2(lx + 0.01, -0.18), vec2(lx + 0.01, -0.70), 0.095));
			shoes = sd_box(m - vec2(lx + 0.01, -0.76), vec2(0.09, 0.07), 0.04);
		}
		d = min(d, min(min(legs, shoes), skirt));
	}

	float aa = max(fwidth(d), 0.002);
	// Outside the outline, nothing more to do.
	if (d > aa) {
		discard;
	}
	ALPHA = clamp(0.5 - d / aa, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.4;

	// Colours.
	vec3 skin = v_skin.rgb;
	vec3 shirt = v_shirt.rgb;
	int pattern = int(v_shirt.w + 0.5);
	vec3 col = skin;
	if (torso < 0.0) {
		col = shirt;
		if (pattern == 3) {
			col = mix(shirt, v_shirt2.rgb, step(0.5, fract(q.y * 3.6 + 0.4)));
		} else if (pattern == 4) {
			col = mix(shirt, v_shirt2.rgb, step(0.5, fract(q.x * 5.5 + 0.25)));
		} else if (pattern == 5) {
			col = mix(shirt, v_shirt2.rgb, step(0.63, q.y) * step(q.y, 0.86));
		}
		col *= 0.80 + 0.20 * smoothstep(0.0, 1.0, q.y);
		col *= 1.0 - 0.22 * smoothstep(0.2, 0.40, abs(q.x));
		// Trousers over the waist.
		if (q.y < 0.15) {
			col = v_trousers.rgb;
		}
	}
	if (neck < 0.0 || head < 0.0) {
		col = skin;
		float top = q.y - 1.50 - q.x * q.x * 0.9;
		if (top > 0.0 && hair != 0) {
			col = hair == 4 || hair == 5 ? v_acc.rgb : v_hair.rgb;
		}
		col *= 0.88 + 0.12 * (1.0 - abs(q.x) / 0.22);
	}
	if (hair_d < 0.0 && head > 0.0) {
		col = hair == 5 ? v_acc.rgb : v_hair.rgb;
	}
	if (arm < 0.0 && torso > 0.0 && head > 0.0) {
		col = (v_shirt2.w > 0.5 || q.y < 1.30) ? shirt * 0.95 : skin;
	}
	if (legs < 0.0) {
		col = ((v_trousers.w > 0.5 && !dress) || q.y > (standing ? -0.78 : -0.20)) ? v_trousers.rgb : skin;
		if (dress && standing) col = skin;
	}
	if (skirt < 0.0) {
		col = v_shirt2.rgb;
	}
	if (shoes < 0.0) {
		col = v_acc.w > 0.5 ? vec3(0.85, 0.85, 0.83) : vec3(0.07, 0.06, 0.06);
	}
	if (pose == 12 && flag < 0.0) {
		int fi = int(v_acc.w + 0.5);
		vec3 fa = fi == 0 ? vec3(0.95, 0.42, 0.06) : (fi == 1 ? vec3(0.78, 0.10, 0.10) : vec3(0.12, 0.25, 0.62));
		vec3 fb = fi == 0 ? vec3(0.08, 0.42, 0.20) : (fi == 1 ? vec3(0.92, 0.92, 0.90) : vec3(0.96, 0.78, 0.12));
		col = fq.x > -0.38 && fq.y > -0.3 && fq.y < 0.3 ? clothes_tone(mix(fa, fb, step(0.0, fq.y))) : vec3(0.1);
	}
	// A little ambient occlusion low down, as the 3D figure has.
	col *= 0.9 + 0.1 * smoothstep(-1.6, 0.0, q.y);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
