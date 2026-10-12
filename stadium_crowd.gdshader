shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Nyota Stadium's crowd: one card per spectator (a MultiMesh per stand), facing the arena, the
// figure drawn here rather than textured. The card is CARD_W x CARD_H metres (twice life size,
// like the stands), its bottom at the seat. INSTANCE_CUSTOM per spectator:
//   r - shirt (picks from the palette), g - skin and hair, b - pose (sitting, standing,
//   cheering with arms up), a - phase of the bob and the wave.

const float CARD_W = 1.1;
const float CARD_H = 2.6;

uniform float detail_fade_start = 90.0;
uniform float detail_fade_end = 260.0;

varying vec4 cd;
varying float cam_d;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	cd = INSTANCE_CUSTOM;
	float ph = cd.a * 6.2831;
	float bob = 0.0;
	if (cd.b > 0.8) {
		// Cheering: bouncing on the spot.
		bob = abs(sin(TIME * 3.4 + ph)) * 0.22;
	} else if (cd.b > 0.55) {
		bob = sin(TIME * 1.2 + ph) * 0.03;
	}
	VERTEX.y += bob;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cam_d = length(w - CAMERA_POSITION_WORLD);
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
	vec2 p = vec2((UV.x - 0.5) * CARD_W, (1.0 - UV.y) * CARD_H);
	float pose = cd.b;
	// Standing fans are taller on the card; everyone a little different in build.
	float lift = pose > 0.55 ? 0.55 : 0.0;
	float build = 0.9 + hash11(cd.r * 91.0) * 0.2;
	vec2 q = vec2(p.x / build, p.y - lift);

	float torso = sd_box(q - vec2(0.0, 0.55), vec2(0.40, 0.62), 0.16);
	float neck = sd_box(q - vec2(0.0, 1.22), vec2(0.08, 0.1), 0.03);
	float head = length(q - vec2(0.0, 1.43)) - 0.21;
	float d = min(min(torso, neck), head);
	float arms = 10.0;
	if (pose > 0.8) {
		float wave = sin(TIME * 5.0 + cd.a * 40.0) * 0.12;
		arms = min(sd_seg(q, vec2(-0.34, 1.0), vec2(-0.52 + wave, 1.95), 0.075),
				sd_seg(q, vec2(0.34, 1.0), vec2(0.52 + wave, 1.95), 0.075));
		d = min(d, arms);
	}
	// Some hold up a flag in the GP's colours.
	float flag = 10.0;
	bool has_flag = pose > 0.8 && hash11(cd.a * 57.0) > 0.82;
	vec2 fq = q - vec2(0.55, 2.1);
	if (has_flag) {
		flag = sd_box(fq, vec2(0.32, 0.2), 0.02);
		d = min(d, flag);
	}

	float aa = max(fwidth(d), 0.002);
	ALPHA = clamp(0.5 - d / aa, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.4;

	// Colours.
	vec3 shirts[10] = vec3[](
		vec3(0.95, 0.42, 0.06), vec3(0.08, 0.42, 0.20), vec3(0.96, 0.78, 0.12), vec3(0.92, 0.92, 0.90),
		vec3(0.78, 0.10, 0.10), vec3(0.12, 0.25, 0.62), vec3(0.08, 0.08, 0.09), vec3(0.55, 0.56, 0.58),
		vec3(0.90, 0.45, 0.62), vec3(0.45, 0.70, 0.90));
	int si = int(floor(cd.r * 10.0)) % 10;
	vec3 shirt = shirts[si];
	float skin_t = cd.g;
	vec3 skin = mix(vec3(0.20, 0.12, 0.08), vec3(0.42, 0.27, 0.17), skin_t);
	if (skin_t > 0.92) {
		skin = vec3(0.80, 0.60, 0.48);
	}
	vec3 hair = vec3(0.05, 0.04, 0.04);
	vec3 col = shirt;
	// Shirt shading: a little darker at the bottom and at the sides, a collar.
	col *= 0.78 + 0.22 * smoothstep(0.0, 1.0, q.y);
	col *= 1.0 - 0.25 * smoothstep(0.2, 0.42, abs(q.x));
	if (neck < 0.0 || head < 0.0) {
		col = skin;
		// Hair, or a cap in a third of the crowd.
		float top = q.y - 1.48 - (q.x * q.x) * 0.6;
		bool cap = hash11(cd.g * 77.0) > 0.68;
		if (top > 0.0) {
			col = cap ? shirts[(si + 3) % 10] : hair;
		}
		// Face shading.
		col *= 0.85 + 0.15 * (1.0 - abs(q.x) / 0.21);
	}
	if (arms < 0.0 && torso > 0.0 && head > 0.0) {
		col = q.y > 1.62 ? skin : shirt * 0.9;
	}
	if (has_flag && flag < 0.0) {
		float band = step(0.0, fq.y);
		col = mix(vec3(0.95, 0.42, 0.06), vec3(0.08, 0.42, 0.20), band);
	}
	// Far away the figures are a few pixels: fade the detail into the shirt colour.
	float far = smoothstep(detail_fade_start, detail_fade_end, cam_d);
	col = mix(col, mix(shirt, skin, 0.35), far * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
