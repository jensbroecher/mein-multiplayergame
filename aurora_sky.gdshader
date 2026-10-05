shader_type sky;

// Northlight Caverns sky: a polar night dome with a star field and two slow aurora
// curtains. Written as a sky shader rather than a ProceduralSkyMaterial because the
// stage's whole look is the aurora, and a two-colour procedural sky cannot express one.
//
// The moon is a uniform direction rather than LIGHT0_DIRECTION: the stage's directional
// light is a dim blue fill whose energy is tuned for the snow, and reading the disc off
// it would tie the moon's apparent brightness to that tuning.

uniform float star_brightness : hint_range(0.0, 4.0) = 0.0;
uniform float aurora_intensity : hint_range(0.0, 4.0) = 1.25;
uniform float aurora_center : hint_range(-0.1, 1.2) = 0.34;
uniform float horizon_glow : hint_range(0.0, 2.0) = 0.35;
uniform float moon_brightness : hint_range(0.0, 6.0) = 1.0;

uniform vec3 moon_dir = vec3(-0.55, 0.36, 0.75);

uniform vec4 sky_zenith : source_color = vec4(0.017, 0.032, 0.080, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.062, 0.098, 0.180, 1.0);
uniform vec4 sky_ground : source_color = vec4(0.012, 0.018, 0.034, 1.0);
uniform vec4 aurora_low : source_color = vec4(0.10, 0.95, 0.55, 1.0);
uniform vec4 aurora_high : source_color = vec4(0.48, 0.40, 1.00, 1.0);
uniform vec4 moon_color : source_color = vec4(0.74, 0.82, 1.00, 1.0);

float hash13(vec3 p) {
	vec3 q = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	q *= 17.0;
	return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
			mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise3(p);
		p = p * 2.07 + 11.3;
		a *= 0.5;
	}
	return v;
}

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + 13.7;
		a *= 0.5;
	}
	return v;
}

// One star candidate per cell of a 3D grid laid on the view direction, jittered inside
// its own cell. A 2D lat/long grid pinches at the poles; a 3D one cannot.
float star_field(vec3 d) {
	vec3 sp = d * 96.0;
	vec3 cell = floor(sp);
	vec3 f = fract(sp) - 0.5;
	float h = hash13(cell);
	vec3 jitter = vec3(hash13(cell + 3.1), hash13(cell + 7.7), hash13(cell + 11.3)) - 0.5;
	float dist = length(f - jitter * 0.55);
	float present = step(0.955, h);
	float bright = 0.22 + 0.78 * fract(h * 137.31);
	float twinkle = 0.70 + 0.30 * sin(TIME * (1.1 + 3.0 * fract(h * 51.7)) + h * 40.0);
	return present * smoothstep(0.30, 0.02, dist) * bright * twinkle;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float elev = asin(clamp(d.y, -1.0, 1.0));

	// --- Aurora ---------------------------------------------------------------------------
	// Two curtains at different heights, each a slow travelling wave along the horizon. Their
	// vertical structure comes from the striation term: without it a gaussian in elevation reads
	// as a glow around the horizon rather than as a hanging curtain.
	//
	// Everything here is sampled on the view DIRECTION `d`, never on an azimuth. atan(d.z, d.x)
	// wraps from -pi to +pi at one bearing (yaw 90 for a level camera), and every term built on
	// that angle is discontinuous across it - which is the hard vertical seam that was visible in
	// the sky. A field sampled on the unit vector has no privileged bearing and so no seam: the
	// striation noise becomes 3D, and the travelling waves become sin() of the vector's own
	// components, which wrap with it.
	vec3 cur = d * 2.6;
	float c1 = aurora_center + 0.085 * sin(cur.x * 1.3 + cur.z * 0.9 + TIME * 0.050)
			+ 0.050 * sin(cur.x * 2.1 - cur.z * 1.7 - TIME * 0.031);
	float c2 = aurora_center - 0.190 + 0.070 * sin(cur.x * 1.1 + cur.y * 0.8 - TIME * 0.043 + 2.0);
	const float w1 = 0.150;
	const float w2 = 0.115;

	float band1 = exp(-pow((elev - c1) / w1, 2.0));
	float band2 = exp(-pow((elev - c2) / w2, 2.0)) * 0.72;
	// Real curtains have a sharp lower lip and a diffuse top, so the gaussian is gated
	// from below rather than simply squashed.
	float foot1 = smoothstep(0.0, 0.055, elev - (c1 - w1));
	float foot2 = smoothstep(0.0, 0.045, elev - (c2 - w2));

	float stri1 = 0.40 + 0.80 * fbm3(d * 6.0 + vec3(TIME * 0.030, -TIME * 0.045, 0.0));
	float stri2 = 0.40 + 0.80 * fbm3(d * 10.5 - vec3(TIME * 0.022, -TIME * 0.033, 0.0) + 9.0);
	// Slow, very large brightness waves along the curtain: without these the two
	// curtains read as one continuous band instead of as separate events.
	float pulse = 0.55 + 0.65 * fbm3(d * 2.0 + vec3(-TIME * 0.014, 0.0, TIME * 0.011));

	float veil = (band1 * stri1 * foot1 + band2 * stri2 * foot2) * pulse;
	veil *= smoothstep(-0.02, 0.10, d.y);
	vec3 aurora_tint = mix(aurora_low.rgb, aurora_high.rgb,
			clamp((elev - (c1 - w1)) / (2.6 * w1), 0.0, 1.0));
	vec3 aurora = aurora_tint * veil * aurora_intensity;

	// --- Base dome -----------------------------------------------------------------------
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon.rgb, sky_zenith.rgb, pow(up, 0.42));
	col = mix(sky_ground.rgb, col, smoothstep(-0.06, 0.03, d.y));
	// Residual twilight hugging the skyline, so the horizon is a gradient rather than a cut.
	col += sky_horizon.rgb * horizon_glow * pow(1.0 - clamp(abs(d.y) * 3.4, 0.0, 1.0), 3.0);

	// --- Moon ---------------------------------------------------------------------------
	vec3 md = normalize(moon_dir);
	float m = max(dot(d, md), 0.0);
	float mm = max(m, 1e-4);
	float disc = smoothstep(0.99962, 0.99986, m);
	float halo = pow(mm, 900.0) * 0.55 + pow(mm, 40.0) * 0.075 + pow(mm, 7.0) * 0.016;
	col += moon_color.rgb * (disc * 2.6 + halo) * moon_brightness;

	// --- Stars --------------------------------------------------------------------------
	// Drawn after the aurora's veil is known so the curtains wash them out where they are
	// bright, and added on top of the dome.
	//
	// star_brightness is a uniform so this can go to zero without editing the shader: the stage
	// sets it from the generator, and setting it to 0 is the same as deleting the call.
	float stars = star_field(d) * star_brightness * (1.0 - 0.80 * clamp(veil * aurora_intensity, 0.0, 1.0));
	col += vec3(0.86, 0.90, 1.0) * stars;

	COLOR = max(col + aurora, vec3(0.0));
}