// Clear winter sky with high cirrus: long thin streaks combed out along the wind, hooked ends from a
// domain warp, gathered into fields with clear blue between them, and lit brighter towards the sun.
//
// Static on purpose: a sky shader that reads TIME forces Godot to rebuild the radiance map every
// frame, and cirrus barely moves over the length of a race anyway.
shader_type sky;
render_mode use_debanding;

group_uniforms sky;
uniform vec3 sky_top : source_color = vec3(0.28, 0.55, 0.92);
uniform vec3 sky_horizon : source_color = vec3(0.72, 0.84, 0.94);
uniform vec3 ground_horizon : source_color = vec3(0.78, 0.88, 0.95);
uniform vec3 ground_bottom : source_color = vec3(0.85, 0.90, 0.96);
// How quickly the horizon haze gives way to the deep blue overhead (higher = thinner haze band).
uniform float sky_curve : hint_range(0.1, 2.0) = 0.45;
uniform float sky_energy = 1.0;

group_uniforms sun;
uniform vec3 sun_tint : source_color = vec3(1.0, 0.97, 0.92);
// Angular radius of the sun disc, degrees.
uniform float sun_disc_degrees = 0.8;
uniform float sun_glow = 0.35;

group_uniforms clouds;
uniform vec3 cloud_lit : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.78, 0.85, 0.95);
// Share of the sky inside a cloud field (0 = clear, 1 = streaked everywhere).
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.75;
// Size of the cloud pattern on the sky; larger = finer, more numerous streaks.
uniform float cloud_scale = 3.2;
// Direction the streaks are combed along, on the ground plane (x, z).
uniform vec2 wind_dir = vec2(0.82, 0.57);
// How much longer a streak is than it is wide.
uniform float streak_length = 6.0;
uniform float cloud_seed = 3.7;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		sum += amp * vnoise(p);
		p = rot * p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return sum;
}

// Cirrus density at a point on the cloud plane.
float cirrus(vec2 uv) {
	vec2 w = normalize(wind_dir);
	vec2 n = vec2(-w.y, w.x);
	vec2 q = vec2(dot(uv, w), dot(uv, n)) * cloud_scale;
	// Domain warp bends the streaks into the hooks and curls cirrus uncinus has.
	vec2 warp = vec2(fbm(q * 0.45 + cloud_seed), fbm(q * 0.45 + cloud_seed + 5.2));
	q += (warp - 0.5) * 0.9;
	// Squashed along the wind and stretched across it, so the noise turns into long fibres.
	float fibres = fbm(vec2(q.x * 0.55, q.y * streak_length));
	float c = smoothstep(0.42, 0.70, fibres);
	// Fine combing inside each streak.
	c *= 0.6 + 0.4 * fbm(vec2(q.x * 1.6, q.y * streak_length * 3.0) + 7.0);
	// Large-scale fields: streaks come in bands and patches with open sky between them.
	float field = fbm(q * 0.12 + vec2(11.0, -4.0));
	c *= smoothstep(1.0 - cloud_coverage - 0.08, 1.0 - cloud_coverage + 0.10, field);
	return clamp(c, 0.0, 1.0);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;

	vec3 col;
	if (h >= 0.0) {
		col = mix(sky_horizon, sky_top, pow(clamp(h, 0.0, 1.0), sky_curve));
	} else {
		col = mix(ground_horizon, ground_bottom, pow(clamp(-h, 0.0, 1.0), 0.5));
	}

	float to_sun = 0.0;
	if (LIGHT0_ENABLED) {
		to_sun = clamp(dot(d, LIGHT0_DIRECTION), -1.0, 1.0);
		float ang = acos(to_sun);
		float r = radians(sun_disc_degrees);
		float disc = 1.0 - smoothstep(r * 0.85, r, ang);
		float glow = pow(max(to_sun, 0.0), 48.0) * sun_glow + pow(max(to_sun, 0.0), 6.0) * sun_glow * 0.25;
		col += sun_tint * LIGHT0_COLOR * (glow + disc * 12.0) * min(LIGHT0_ENERGY, 2.0);
	}

	if (h > 0.0) {
		// Project onto a high flat cloud layer: small streaks near the horizon, large overhead.
		vec2 uv = d.xz / (h + 0.05);
		float c = cirrus(uv);
		// Thin out towards the horizon where the layer is seen through haze.
		c *= smoothstep(0.0, 0.3, h);
		// Ice-crystal cloud: bright and slightly silvery towards the sun, faintly blue-grey away from it.
		float forward = pow(max(to_sun, 0.0), 5.0);
		vec3 cloud = mix(cloud_shade, cloud_lit, 0.55 + 0.45 * forward);
		cloud += sun_tint * pow(max(to_sun, 0.0), 40.0) * 0.6;
		col = mix(col, cloud, c * cloud_opacity);
	}

	COLOR = col * sky_energy;
}
