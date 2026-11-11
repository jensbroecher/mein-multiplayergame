// Shared by Nyota Stadium's two crowd levels: stadium_person.gdshader (a real 3D spectator, near) and
// stadium_crowd.gdshader (a flat card, far). Both read the same INSTANCE_CUSTOM, so a spectator is the same
// person at either distance:
//   r - a seed (shirt, trousers, build, hair, ...),  g - the draw for skin tone (2 more: in a yukata, crowd_yukata),
//   b - the pose, (id + 0.5) / 16,                   a - a second seed and the animation phase.
//
// Poses: 0-6 sit (0 idle, 1 clap, 2 film on a phone, 3 talk, 4 arms crossed, 5 cheer, 6 drink), 7-15 stand
// (7 idle, 8 clap, 9 cheer, 10 phone, 11 arms crossed, 12 wave a flag, 13 hands on hips, 14 wave, 15 drink).

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float crowd_rand(vec4 cd, float k) {
	return hash11(cd.r * 127.13 + cd.a * 311.71 + k * 17.31);
}

int crowd_pose(vec4 cd) {
	return clamp(int(floor(cd.b * 16.0)), 0, 15);
}

bool pose_standing(int p) {
	return p >= 7;
}

// Arms up: the poses a card draws with raised arms.
bool pose_arms_up(int p) {
	return p == 5 || p == 9 || p == 12 || p == 14;
}

// Skin: about 80% of the crowd is African (dark to medium brown), the rest South Asian, European, East
// Asian and Arab or mixed. `group`: 0 African, 1 South Asian, 2 European, 3 East Asian, 4 Arab or mixed.
vec3 crowd_skin(vec4 cd, out int group) {
	float g = cd.g >= 1.5 ? cd.g - 2.0 : cd.g;
	float v = crowd_rand(cd, 3.0);
	vec3 c;
	if (g < 0.80) {
		group = 0;
		float t = pow(g / 0.80, 1.5);
		c = mix(vec3(0.14, 0.085, 0.055), vec3(0.28, 0.17, 0.105), smoothstep(0.0, 0.55, t));
		c = mix(c, vec3(0.42, 0.27, 0.17), smoothstep(0.55, 1.0, t));
	} else if (g < 0.86) {
		group = 1;
		c = mix(vec3(0.42, 0.27, 0.17), vec3(0.58, 0.38, 0.25), v);
	} else if (g < 0.93) {
		group = 2;
		c = mix(vec3(0.80, 0.58, 0.46), vec3(0.93, 0.74, 0.64), v);
	} else if (g < 0.96) {
		group = 3;
		c = mix(vec3(0.74, 0.55, 0.36), vec3(0.88, 0.70, 0.50), v);
	} else {
		group = 4;
		c = mix(vec3(0.55, 0.37, 0.25), vec3(0.72, 0.52, 0.38), v);
	}
	return c * (0.94 + 0.12 * crowd_rand(cd, 4.0));
}

const vec3 SHIRTS[12] = vec3[](
	vec3(0.95, 0.42, 0.06), vec3(0.08, 0.42, 0.20), vec3(0.96, 0.78, 0.12), vec3(0.92, 0.92, 0.90),
	vec3(0.78, 0.10, 0.10), vec3(0.12, 0.25, 0.62), vec3(0.08, 0.08, 0.09), vec3(0.55, 0.56, 0.58),
	vec3(0.90, 0.45, 0.62), vec3(0.45, 0.70, 0.90), vec3(0.50, 0.15, 0.55), vec3(0.15, 0.55, 0.55));

const vec3 TROUSERS[8] = vec3[](
	vec3(0.14, 0.20, 0.34), vec3(0.08, 0.08, 0.09), vec3(0.50, 0.43, 0.30), vec3(0.30, 0.31, 0.33),
	vec3(0.18, 0.28, 0.45), vec3(0.62, 0.60, 0.55), vec3(0.14, 0.26, 0.17), vec3(0.28, 0.18, 0.12));

// The palettes are written the way they should look; lit as they are they come out washed out, so clothes go
// through a gamma.
vec3 clothes_tone(vec3 c) {
	return pow(c, vec3(1.7));
}

vec3 shirt_at(int i) {
	return clothes_tone(SHIRTS[((i % 12) + 12) % 12]);
}

vec3 crowd_shirt(vec4 cd) {
	return shirt_at(int(floor(crowd_rand(cd, 1.0) * 12.0)));
}

vec3 crowd_trousers(vec4 cd) {
	return clothes_tone(TROUSERS[int(floor(crowd_rand(cd, 2.0) * 8.0)) % 8]);
}

// A yukata (the summer kimono of a festival: Yoshino Rapids' cherry-blossom fair): the spectator's skin draw carries 2
// more. The robe to the ankles in one of YUKATA's colours with a small pattern of YUKATA_FIGURE's, wide sleeves, an
// obi round the waist.
bool crowd_yukata(vec4 cd) {
	return cd.g >= 1.5;
}

const vec3 YUKATA[8] = vec3[](
	vec3(0.12, 0.17, 0.42), vec3(0.93, 0.92, 0.88), vec3(0.95, 0.62, 0.72), vec3(0.08, 0.10, 0.20),
	vec3(0.72, 0.12, 0.16), vec3(0.62, 0.52, 0.80), vec3(0.20, 0.42, 0.40), vec3(0.98, 0.86, 0.52));
const vec3 YUKATA_FIGURE[8] = vec3[](
	vec3(0.93, 0.93, 0.90), vec3(0.16, 0.25, 0.55), vec3(0.85, 0.20, 0.35), vec3(0.95, 0.60, 0.70),
	vec3(0.98, 0.90, 0.70), vec3(0.95, 0.95, 0.92), vec3(0.95, 0.75, 0.30), vec3(0.80, 0.25, 0.20));
const vec3 OBI[6] = vec3[](
	vec3(0.85, 0.20, 0.16), vec3(0.95, 0.78, 0.25), vec3(0.10, 0.10, 0.12), vec3(0.30, 0.50, 0.75),
	vec3(0.95, 0.55, 0.70), vec3(0.55, 0.20, 0.45));

int yukata_i(vec4 cd) {
	return int(floor(crowd_rand(cd, 21.0) * 8.0)) % 8;
}

vec3 yukata_robe(vec4 cd) {
	return clothes_tone(YUKATA[yukata_i(cd)]);
}

vec3 yukata_figure(vec4 cd) {
	return clothes_tone(YUKATA_FIGURE[yukata_i(cd)]);
}

vec3 yukata_obi(vec4 cd) {
	return clothes_tone(OBI[int(floor(crowd_rand(cd, 22.0) * 6.0)) % 6]);
}

// The robe's pattern at a point of the figure (metres, about): small round flowers on a staggered grid.
float yukata_pattern(vec2 p, vec4 cd) {
	float k = 6.0 + 4.0 * crowd_rand(cd, 23.0);
	vec2 q = p * k;
	q.x += 0.5 * mod(floor(q.y), 2.0);
	vec2 f = fract(q) - 0.5;
	return 1.0 - smoothstep(0.16, 0.24, length(f));
}

// Hair: 0 bald, 1 short, 2 afro, 3 long, 4 cap, 5 headscarf. African hair is black and tightly curled
// (short or an afro); the others vary, and a few have gone grey.
int crowd_hair_style(vec4 cd, int group, bool female) {
	float h = crowd_rand(cd, 5.0);
	if (female) {
		if (h < 0.05) return 5;
		if (h < 0.30) return group == 0 ? 2 : 3;
		if (h < 0.60) return 3;
		if (h < 0.72) return 4;
		return 1;
	}
	if (h < 0.07) return 0;
	if (h < 0.22) return 4;
	if (h < 0.30) return group == 0 ? 2 : 3;
	if (h < 0.38 && group != 0) return 3;
	return 1;
}

vec3 crowd_hair_colour(vec4 cd, int group) {
	float h = crowd_rand(cd, 6.0);
	vec3 c = vec3(0.04, 0.035, 0.035);
	if (group == 2) {
		c = h < 0.35 ? vec3(0.45, 0.30, 0.16) : (h < 0.55 ? vec3(0.78, 0.62, 0.34) : (h < 0.65 ? vec3(0.55, 0.20, 0.08) : vec3(0.12, 0.08, 0.06)));
	} else if (group == 4) {
		c = vec3(0.07, 0.05, 0.04);
	}
	// A few have gone grey.
	if (crowd_rand(cd, 7.0) > 0.93) {
		c = mix(c, vec3(0.62, 0.62, 0.62), 0.8);
	}
	return c;
}

// Height scale: children are 6% of the crowd, adults vary a few percent.
float crowd_height(vec4 cd, out bool kid) {
	kid = crowd_rand(cd, 8.0) > 0.94;
	return kid ? 0.62 + 0.16 * crowd_rand(cd, 9.0) : 0.95 + 0.11 * crowd_rand(cd, 9.0);
}
