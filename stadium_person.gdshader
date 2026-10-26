shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Nyota Stadium's crowd up close: a spectator in 3D (CrowdKit.gd's mesh, one MultiMesh per cell), posed and
// animated here. The far level of detail is stadium_crowd.gdshader's card; the two crossfade by dither
// (tree_lod.gdshaderinc: lod_mode 1 here, 2 on the card) and read the same INSTANCE_CUSTOM
// (crowd_common.gdshaderinc), so a spectator is the same person at either distance.
//
// The mesh is a standing rest pose with arms hanging. Per vertex: COLOR.r the part, COLOR.g the region,
// COLOR.b the style (which hair, clothes and prop it belongs to), COLOR.a the flag cloth's wave; UV and UV2 the
// limb's two joints (or a head part's position in head units). Poses bend the joints here.
// The constants below are CrowdKit's.

#include "res://tree_lod.gdshaderinc"
#include "res://crowd_common.gdshaderinc"

const float HIP_Y = 1.65;
const float NECK_Y = 2.80;
const vec3 HEAD_C = vec3(0.0, 3.07, 0.02);
const vec3 HEAD_R = vec3(0.200, 0.245, 0.215);
// A seated spectator's pelvis is this high over the seat.
const float SEAT_HIP = 0.10;
const float DEG = 0.0174533;

// Per pose: shoulder pitch (forward), roll (out), elbow and yaw (in toward the middle), in degrees, for the
// left and the right arm. A forearm's direction from straight down is pitch + elbow: 90 is level.
const vec4 ARM_L[16] = vec4[](
	vec4(12.0, 8.0, 72.0, 0.0),    // 0 sit idle: hands on the thighs
	vec4(42.0, 0.0, 60.0, 34.0),   // 1 sit clap
	vec4(12.0, 8.0, 72.0, 0.0),    // 2 sit film
	vec4(14.0, 10.0, 70.0, 0.0),   // 3 sit talk
	vec4(28.0, 0.0, 68.0, 56.0),   // 4 sit arms crossed
	vec4(10.0, 150.0, 8.0, 0.0),   // 5 sit cheer
	vec4(12.0, 8.0, 72.0, 0.0),    // 6 sit drink
	vec4(4.0, 6.0, 14.0, 0.0),     // 7 stand idle
	vec4(48.0, 0.0, 56.0, 34.0),   // 8 stand clap
	vec4(10.0, 152.0, 6.0, 0.0),   // 9 stand cheer
	vec4(6.0, 8.0, 18.0, 0.0),     // 10 stand film
	vec4(30.0, 0.0, 70.0, 56.0),   // 11 stand arms crossed
	vec4(-6.0, 45.0, 88.0, 0.0),   // 12 stand flag: hand on the hip
	vec4(-8.0, 46.0, 88.0, 0.0),   // 13 hands on hips
	vec4(4.0, 6.0, 14.0, 0.0),     // 14 stand wave
	vec4(-6.0, 45.0, 88.0, 0.0)    // 15 stand drink
);
const vec4 ARM_R[16] = vec4[](
	vec4(12.0, 8.0, 72.0, 0.0),
	vec4(42.0, 0.0, 60.0, 34.0),
	vec4(72.0, -4.0, 88.0, 26.0),
	vec4(14.0, 10.0, 70.0, 0.0),
	vec4(38.0, 0.0, 66.0, 56.0),
	vec4(10.0, 150.0, 8.0, 0.0),
	vec4(58.0, -6.0, 118.0, 40.0),
	vec4(4.0, 6.0, 14.0, 0.0),
	vec4(48.0, 0.0, 56.0, 34.0),
	vec4(10.0, 152.0, 6.0, 0.0),
	vec4(76.0, -4.0, 84.0, 26.0),
	vec4(38.0, 0.0, 70.0, 56.0),
	vec4(6.0, 150.0, 6.0, 0.0),
	vec4(-8.0, 46.0, 88.0, 0.0),
	vec4(6.0, 142.0, 28.0, 0.0),
	vec4(62.0, -6.0, 116.0, 40.0)
);
// Per pose: how far each upper arm (left, right) turns in about its own length before the shoulder swings it
// (degrees). A hand on the hip needs it: the elbow only bends forward, so without the turn the forearm
// pointed ahead and the hand stood off beside the hip.
const vec2 TWIST[16] = vec2[](
	vec2(0.0), vec2(0.0), vec2(0.0), vec2(0.0), vec2(0.0), vec2(0.0), vec2(0.0),
	vec2(0.0), vec2(0.0), vec2(0.0), vec2(0.0), vec2(0.0),
	vec2(90.0, 0.0), vec2(90.0, 90.0), vec2(0.0), vec2(90.0, 0.0)
);
// Per pose: hip and knee bend for the left and the right leg (degrees). Seated poses bend both to a right angle.
const vec4 LEGS[16] = vec4[](
	vec4(88.0, 88.0, 84.0, 90.0), vec4(88.0, 88.0, 84.0, 90.0), vec4(86.0, 90.0, 90.0, 86.0), vec4(88.0, 88.0, 94.0, 96.0),
	vec4(86.0, 90.0, 86.0, 90.0), vec4(88.0, 88.0, 88.0, 88.0), vec4(88.0, 88.0, 92.0, 94.0),
	vec4(4.0, 8.0, -2.0, 0.0), vec4(0.0, 0.0, 0.0, 0.0), vec4(0.0, 0.0, 0.0, 0.0), vec4(2.0, 4.0, -3.0, 0.0),
	vec4(0.0, 0.0, 4.0, 8.0), vec4(0.0, 0.0, 0.0, 0.0), vec4(2.0, 3.0, 2.0, 3.0), vec4(-3.0, 0.0, 4.0, 8.0),
	vec4(0.0, 0.0, 2.0, 6.0)
);

varying flat vec4 cd;
varying float cam_dist;
varying vec4 vcol;
varying vec3 head_p;
varying vec3 rest_pos;

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

bool is_female(vec4 c) {
	return crowd_rand(c, 10.0) < 0.48;
}

void vertex() {
	cd = INSTANCE_CUSTOM;
	vcol = COLOR;
	rest_pos = VERTEX;
	head_p = vec3(UV, UV2.x);
	vec3 origin = MODEL_MATRIX[3].xyz;
	cam_dist = lod_distance(origin, CAMERA_POSITION_WORLD);

	int part = int(floor(COLOR.r * 16.0 + 0.5));
	int style = int(floor(COLOR.b * 16.0 + 0.5));
	int pose = crowd_pose(cd);
	bool sitting = !pose_standing(pose);
	int group;
	crowd_skin(cd, group);
	bool female = is_female(cd);
	int hair = crowd_hair_style(cd, group, female);
	bool dress = female && crowd_rand(cd, 11.0) > 0.60;

	// What this spectator has: hair, a dress, a prop for the pose.
	bool show = true;
	if (style == 1) show = hair == 1 || hair == 3;
	else if (style == 2) show = hair == 2;
	else if (style == 3) show = hair == 3;
	else if (style == 4) show = hair == 4;
	else if (style == 5) show = hair == 5;
	else if (style == 6) show = dress;
	else if (style == 7) show = pose == 2 || pose == 10;
	else if (style == 8) show = pose == 6 || pose == 15;
	else if (style == 9) show = pose == 12;
	// Beyond the near range there is only the card.
	if (lod_mode == 1 && cam_dist > lod_fade_end) show = false;
	if (!show) {
		VERTEX = vec3(0.0);
	} else {
		vec3 v = VERTEX;
		vec3 n = NORMAL;
		float ph = cd.a * 6.2831853;
		float tp = TIME + cd.a * 23.0;

		// Pose and animation.
		vec4 al = ARM_L[pose];
		vec4 ar = ARM_R[pose];
		vec4 lg = LEGS[pose];
		float head_yaw = 0.0;
		float head_pitch = 0.0;
		float lean = sitting ? -0.05 : 0.0;
		float twist = 0.0;
		float bob = 0.012 * sin(tp * 1.7);
		float wave_l = 0.0;
		float wave_r = 0.0;
		float clap = 0.0;
		if (pose == 0 || pose == 7) {
			head_yaw = sin(tp * 0.45) * 0.28;
			lean += sin(tp * 0.8) * 0.018;
		} else if (pose == 1 || pose == 8) {
			clap = sin(tp * 8.0 + ph);
			head_pitch = -0.05;
		} else if (pose == 3) {
			head_yaw = sin(tp * 0.7) * 0.55;
			twist = sin(tp * 0.45) * 0.14;
		} else if (pose == 5 || pose == 9) {
			wave_l = sin(tp * 5.2 + ph) * 0.22;
			wave_r = sin(tp * 5.2 + ph + 2.0) * 0.22;
			head_pitch = -0.18;
			if (pose == 9) bob += abs(sin(tp * 3.3 + ph)) * 0.34;
		} else if (pose == 12) {
			wave_r = sin(tp * 4.0 + ph) * 0.20;
			head_pitch = -0.1;
		} else if (pose == 14) {
			wave_r = sin(tp * 6.5 + ph) * 0.30;
			head_yaw = sin(tp * 0.8) * 0.2;
		} else if (pose == 2 || pose == 10) {
			head_pitch = 0.12;
			head_yaw = sin(tp * 0.5) * 0.12;
		} else if (pose == 6 || pose == 15) {
			head_pitch = -0.22;
		}

		// Flag cloth waves.
		if (style == 9 && vcol.a > 0.0 && int(floor(vcol.g * 16.0 + 0.5)) == 9) {
			v.z += sin(TIME * 7.0 - vcol.a * 6.0 + ph) * 0.12 * vcol.a;
		}

		if (part >= 2 && part <= 5) {
			bool left = part == 2 || part == 3;
			bool fore = part == 3 || part == 5;
			vec4 a = left ? al : ar;
			float side = left ? 1.0 : -1.0;
			float pitch = a.x * DEG;
			float roll = a.y * DEG + (left ? wave_l : wave_r);
			float elbow = a.z * DEG;
			float yaw = a.w * DEG;
			float arm_twist = (left ? TWIST[pose].x : TWIST[pose].y) * DEG;
			if (clap != 0.0) {
				elbow += clap * 0.10;
				yaw += clap * 0.16;
			}
			vec3 sh = vec3(UV.x, UV.y, 0.0);
			vec3 el = vec3(UV2.x, UV2.y, 0.0);
			if (fore) {
				mat3 Re = rot_x(-elbow);
				v = el + Re * (v - el);
				n = Re * n;
			}
			mat3 Rs = rot_y(-side * yaw) * rot_z(side * roll) * rot_x(-pitch) * rot_y(-side * arm_twist);
			v = sh + Rs * (v - sh);
			n = Rs * n;
		} else if (part >= 6) {
			bool left = part == 6 || part == 7;
			bool lower = part == 7 || part == 9;
			vec2 l = left ? lg.xy : lg.zw;
			vec3 hip = vec3(UV.x, UV.y, 0.0);
			vec3 knee = vec3(UV2.x, UV2.y, 0.0);
			if (lower) {
				mat3 Rk = rot_x(l.y * DEG);
				v = knee + Rk * (v - knee);
				n = Rk * n;
			}
			mat3 Rh = rot_x(-l.x * DEG);
			v = hip + Rh * (v - hip);
			n = Rh * n;
		} else if (part == 1) {
			vec3 neck = vec3(0.0, NECK_Y, 0.0);
			mat3 Rn = rot_y(head_yaw) * rot_x(head_pitch);
			v = neck + Rn * (v - neck);
			n = Rn * n;
		}
		// Everything above the hips leans and twists with the body.
		if (part < 6) {
			vec3 hipc = vec3(0.0, HIP_Y, 0.0);
			mat3 Rb = rot_x(lean) * rot_y(twist);
			v = hipc + Rb * (v - hipc);
			n = Rb * n;
		}
		// Seated: the whole figure drops until the pelvis is on the seat.
		if (sitting) v.y -= HIP_Y - SEAT_HIP;
		v.y += bob;
		// Build.
		bool kid;
		float h = crowd_height(cd, kid);
		float w = (is_female(cd) ? 0.92 : 1.03) * (0.94 + 0.12 * crowd_rand(cd, 12.0));
		if (kid) w = h;
		v = vec3(v.x * w, v.y * h, v.z * w);
		VERTEX = v;
		NORMAL = normalize(n);
	}
}

float ellipse(vec2 p, vec2 r) {
	return length(p / r) - 1.0;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	if (lod_hidden(cam_dist, FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	int part = int(floor(vcol.r * 16.0 + 0.5));
	int region = int(floor(vcol.g * 16.0 + 0.5));
	int pose = crowd_pose(cd);
	int group;
	vec3 skin = crowd_skin(cd, group);
	bool female = is_female(cd);
	vec3 hair_col = crowd_hair_colour(cd, group);
	vec3 shirt = crowd_shirt(cd);
	int shirt_i = int(floor(crowd_rand(cd, 1.0) * 12.0)) % 12;
	vec3 shirt2 = shirt_at(shirt_i + 5);
	vec3 trousers = crowd_trousers(cd);
	bool long_sleeves = crowd_rand(cd, 13.0) > 0.62;
	bool long_trousers = crowd_rand(cd, 14.0) > 0.18;
	bool dress = female && crowd_rand(cd, 11.0) > 0.60;
	int pattern = int(floor(crowd_rand(cd, 15.0) * 8.0));

	vec3 col = skin;
	if (region == 1) {
		col = shirt;
		float y = rest_pos.y;
		if (pattern == 3) {
			col = mix(shirt, shirt2, step(0.5, fract(y * 3.6)));
		} else if (pattern == 4) {
			col = mix(shirt, shirt2, step(0.5, fract(rest_pos.x * 5.5 + 0.25)));
		} else if (pattern == 5) {
			col = mix(shirt, shirt2, step(2.28, y) * step(y, 2.50));
		} else if (pattern == 6) {
			// A shirt with a badge on the chest.
			float badge = 1.0 - smoothstep(0.0, 0.03, ellipse(rest_pos.xy - vec2(0.17, 2.42), vec2(0.07, 0.07)));
			col = mix(shirt, shirt2, badge * step(0.0, rest_pos.z));
		}
		if (part == 0 && rest_pos.y < 1.80) {
			col = trousers;
		}
	} else if (region == 2) {
		col = long_sleeves ? shirt : skin;
	} else if (region == 3) {
		col = trousers;
	} else if (region == 4) {
		col = long_trousers && !dress ? trousers : skin;
		// Socks and trainers.
	} else if (region == 11) {
		col = dress ? skin : trousers;
	} else if (region == 5) {
		col = crowd_rand(cd, 16.0) > 0.35 ? vec3(0.85, 0.85, 0.83) : vec3(0.07, 0.06, 0.06);
	} else if (region == 6) {
		col = hair_col;
		col *= 0.85 + 0.3 * hash11(floor(rest_pos.x * 40.0) + floor(rest_pos.y * 40.0) * 7.0);
	} else if (region == 7) {
		col = (part == 1 && crowd_hair_style(cd, group, female) == 5) ? shirt_at(shirt_i + 7) : shirt_at(shirt_i + 3);
	} else if (region == 8) {
		col = vec3(0.05, 0.05, 0.06);
		if (rest_pos.z > 0.0 && rest_pos.y > 1.40 && rest_pos.y < 1.60) col = vec3(0.22, 0.30, 0.38);
	} else if (region == 9) {
		float band = step(0.35, rest_pos.y);
		int fi = int(floor(crowd_rand(cd, 17.0) * 3.0));
		vec3 a = fi == 0 ? vec3(0.95, 0.42, 0.06) : (fi == 1 ? vec3(0.78, 0.10, 0.10) : vec3(0.12, 0.25, 0.62));
		vec3 b = fi == 0 ? vec3(0.08, 0.42, 0.20) : (fi == 1 ? vec3(0.92, 0.92, 0.90) : vec3(0.96, 0.78, 0.12));
		col = clothes_tone(mix(a, b, band));
	} else if (region == 10) {
		col = shirt2;
		col = mix(col, shirt, step(0.5, fract(rest_pos.y * 2.5)) * float(pattern == 3));
	}

	// The face: eyes, brows, nose, mouth, an ear, stubble and sunglasses, painted on the head's skin.
	if (part == 1 && region == 0) {
		vec3 h = head_p;
		float front = smoothstep(0.05, 0.30, h.z);
		vec2 p = h.xy;
		float ax = abs(p.x);
		float side = sign(p.x);
		// Skin shading: a little darker at the sides, a flush on the cheeks.
		col *= 0.88 + 0.12 * h.z;
		col = mix(col, col * vec3(1.06, 0.92, 0.90), front * smoothstep(0.35, 0.0, length(vec2(ax - 0.52, p.y + 0.18))) * 0.5);
		float t = TIME + cd.a * 31.0;
		bool open = pose == 5 || pose == 9 || pose == 12 || pose == 14 || (pose == 3 && sin(t * 5.0) > 0.4) || ((pose == 1 || pose == 8) && sin(t * 4.0) > 0.0);
		// Eyes: white, an iris, a lid line above.
		vec2 eye_c = vec2(0.40, 0.10);
		float e = ellipse(vec2(ax, p.y) - eye_c, vec2(0.17, 0.095));
		float blink = step(0.97, fract(t * 0.23 + crowd_rand(cd, 18.0)));
		vec3 sclera = vec3(0.92, 0.90, 0.86);
		vec3 iris = group == 3 ? vec3(0.07, 0.05, 0.04) : (group == 2 && crowd_rand(cd, 19.0) > 0.5 ? vec3(0.20, 0.35, 0.50) : vec3(0.10, 0.06, 0.04));
		float look = 0.02 * sin(t * 0.6);
		float iris_d = length((vec2(ax, p.y) - eye_c - vec2(side * -0.02 + look, 0.0)) / vec2(0.075, 0.085));
		float eye_mask = (1.0 - smoothstep(0.0, 0.12, e)) * front * (1.0 - blink);
		col = mix(col, mix(sclera, iris, 1.0 - smoothstep(0.85, 1.05, iris_d)), eye_mask);
		float lid = abs(ellipse(vec2(ax, p.y - 0.035) - eye_c, vec2(0.19, 0.11)));
		col = mix(col, col * 0.45, front * (1.0 - smoothstep(0.0, 0.07, lid)) * step(eye_c.y - 0.01, p.y));
		// Brows.
		float brow_up = open ? 0.05 : (pose == 4 || pose == 11 ? -0.03 : 0.0);
		float bd = seg_dist(vec2(ax, p.y), vec2(0.20, 0.33 + brow_up * 0.4), vec2(0.62, 0.36 + brow_up));
		col = mix(col, hair_col * 0.8 + 0.02, front * (1.0 - smoothstep(0.03, 0.065, bd)) * 0.9);
		// Nose: a lighter bridge and the shadow under it.
		float nose = ellipse(p - vec2(0.0, -0.12), vec2(0.10, 0.20));
		col = mix(col, col * 1.12, front * (1.0 - smoothstep(0.0, 0.6, nose)) * 0.5);
		float nostrils = ellipse(vec2(ax, p.y) - vec2(0.07, -0.27), vec2(0.045, 0.03));
		col = mix(col, col * 0.4, front * (1.0 - smoothstep(0.0, 0.5, nostrils)));
		float nose_shadow = ellipse(p - vec2(0.0, -0.31), vec2(0.17, 0.05));
		col = mix(col, col * 0.78, front * (1.0 - smoothstep(0.0, 0.8, nose_shadow)) * 0.6);
		// Mouth: a smile or a line, open and shouting when cheering.
		float smile = open ? 0.0 : (crowd_rand(cd, 20.0) > 0.45 ? 1.0 : 0.0);
		vec2 mp = vec2(p.x, p.y + 0.52);
		float mouth_curve = mp.y - (smile * 0.10 * (mp.x * mp.x / 0.09) - smile * 0.045);
		vec3 lip = mix(col, vec3(0.30, 0.10, 0.10), 0.55);
		if (open) {
			float m = ellipse(mp, vec2(0.25, 0.14));
			col = mix(col, vec3(0.22, 0.05, 0.06), front * (1.0 - smoothstep(0.0, 0.18, m)));
			col = mix(col, vec3(0.92, 0.9, 0.86), front * (1.0 - smoothstep(0.0, 0.12, m)) * step(0.05, mp.y) * 0.9);
		} else {
			float line = abs(mouth_curve) - 0.018;
			col = mix(col, lip, front * (1.0 - smoothstep(0.0, 0.02, line)) * step(abs(mp.x), 0.26));
		}
		// Ears.
		float ear = ellipse(vec2(ax - 1.0, p.y + 0.02), vec2(0.15, 0.30));
		col = mix(col, col * 0.78, (1.0 - smoothstep(0.0, 0.5, ear)) * (1.0 - front));
		// Stubble or a beard on some men; sunglasses on a few.
		if (!female && crowd_rand(cd, 21.0) > 0.86) {
			float lower = smoothstep(-0.2, -0.55, p.y) * front * step(0.15, ax + 0.4 * (p.y + 0.9));
			float grain = hash11(floor(p.x * 60.0) * 3.7 + floor(p.y * 60.0) * 11.3);
			col = mix(col, hair_col, lower * (0.5 + 0.4 * grain));
		}
		if (crowd_rand(cd, 22.0) > 0.93) {
			float band = 1.0 - smoothstep(0.0, 0.05, ellipse(vec2(ax, p.y) - vec2(0.38, 0.10), vec2(0.24, 0.15)));
			band = max(band, 1.0 - smoothstep(0.0, 0.04, seg_dist(vec2(ax, p.y), vec2(0.0, 0.13), vec2(0.18, 0.13)) - 0.02));
			col = mix(col, vec3(0.03, 0.03, 0.04), band * front);
		}
	}
	// A little ambient occlusion low down.
	col *= 0.85 + 0.15 * smoothstep(0.0, 1.0, rest_pos.y);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
