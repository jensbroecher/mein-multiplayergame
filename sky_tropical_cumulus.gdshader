// Humid tropical sky: a saturated blue overhead sinking into a milky, green-tinged haze at the horizon,
// with heaped cumulus that are lit from the sun's side and grey-blue underneath.
//
// Static on purpose, like sky_winter_cirrus.gdshader: a sky shader that reads TIME forces Godot to
// rebuild the radiance map every frame. The uniform names match that shader's (JungleRain.gd drives
// the sky_top, sky_horizon, cloud_*, sun_glow and sky_energy ones to cloud the sky over in a storm).
shader_type sky;
render_mode use_debanding;

group_uniforms sky;
uniform vec3 sky_top : source_color = vec3(0.16, 0.40, 0.78);
uniform vec3 sky_horizon : source_color = vec3(0.74, 0.84, 0.84);
uniform vec3 ground_horizon : source_color = vec3(0.66, 0.74, 0.70);
uniform vec3 ground_bottom : source_color = vec3(0.30, 0.38, 0.30);
// How quickly the horizon haze gives way to the blue overhead (higher = thinner haze band).
uniform float sky_curve : hint_range(0.1, 2.0) = 0.5;
uniform float sky_energy = 1.0;
// Wet air along the horizon, matched to the level's distance fog colour so the far hills and the
// sky behind them meet without a seam.
uniform vec3 horizon_haze : source_color = vec3(0.66, 0.74, 0.70);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.8;
uniform float haze_height : hint_range(0.01, 0.6) = 0.24;

group_uniforms sun;
uniform vec3 sun_tint : source_color = vec3(1.0, 0.95, 0.84);
// Angular radius of the sun disc, degrees.
uniform float sun_disc_degrees = 1.0;
uniform float sun_glow = 0.5;

group_uniforms clouds;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 cloud_shade : source_color = vec3(0.42, 0.50, 0.62);
// Share of the sky under cumulus (0 = clear, 1 = overcast).
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.95;
// Size of the cloud pattern on the sky; larger = smaller, more numerous clouds.
uniform float cloud_scale = 1.9;
// Direction the cloud field is stretched along, on the ground plane (x, z).
uniform vec2 wind_dir = vec2(0.82, 0.57);
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

float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < octaves; i++) {
		sum += amp * vnoise(p);
		p = rot * p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return sum;
}

// Cloud height field at a point on the cloud plane: a broad shape with rounded lumps heaped on it.
float heap(vec2 q, vec2 warp) {
	vec2 p = q + warp;
	float broad = fbm(p, 5);
	float lump = vnoise(p * 2.6 + 17.0);
	return broad + (lump * lump - 0.33) * 0.30;
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
	vec2 sun_flat = vec2(0.6, 0.8);
	if (LIGHT0_ENABLED) {
		to_sun = clamp(dot(d, LIGHT0_DIRECTION), -1.0, 1.0);
		float ang = acos(to_sun);
		float r = radians(sun_disc_degrees);
		float disc = 1.0 - smoothstep(r * 0.85, r, ang);
		float glow = pow(max(to_sun, 0.0), 48.0) * sun_glow + pow(max(to_sun, 0.0), 6.0) * sun_glow * 0.25;
		col += sun_tint * LIGHT0_COLOR * (glow + disc * 12.0) * min(LIGHT0_ENERGY, 2.0);
		sun_flat = LIGHT0_DIRECTION.xz;
		if (dot(sun_flat, sun_flat) < 0.0001) {
			sun_flat = vec2(0.6, 0.8);
		}
	}

	if (h > 0.0) {
		// Project onto a flat cloud deck: small clouds piled up near the horizon, large overhead.
		vec2 uv = d.xz / (h + 0.14);
		vec2 w = normalize(wind_dir);
		vec2 n = vec2(-w.y, w.x);
		// A little longer along the wind than across it.
		vec2 q = vec2(dot(uv, w) * 0.9, dot(uv, n)) * cloud_scale + cloud_seed;
		vec2 warp = (vec2(fbm(q * 0.7 + 3.1, 3), fbm(q * 0.7 + 8.3, 3)) - 0.5) * 0.5;

		// Coverage is not linear in the threshold: the top of its range closes the sky over completely.
		float thresh = mix(0.80, -0.15, pow(cloud_coverage, 1.8));
		float overcast = smoothstep(0.65, 0.95, cloud_coverage);
		float ht = heap(q, warp);
		float body = smoothstep(thresh, thresh + 0.09, ht);

		if (body > 0.0) {
			// Look a step towards the sun: where the cloud is thinner there, this face is lit; where
			// it is thicker, it sits in its own shadow.
			vec2 toward = normalize(sun_flat);
			vec2 off = vec2(dot(toward, w) * 0.9, dot(toward, n)) * 0.10;
			float lit_ht = heap(q + off, warp);
			float lit = clamp(0.62 + (ht - lit_ht) * 9.0 * (1.0 - 0.8 * overcast), 0.0, 1.0);
			// Thick centres are darker grey underneath; thin edges let the light through.
			float thick = smoothstep(thresh, thresh + 0.30, ht);
			float bright = clamp(lit * (1.0 - 0.5 * thick) + 0.35 * (1.0 - thick), 0.0, 1.0);
			// A storm deck is dark underneath whatever the sun does.
			vec3 shade = mix(cloud_shade, vec3(0.30, 0.34, 0.36), overcast);
			vec3 cloud = mix(shade, cloud_lit, bright);
			// Silver lining where thin cloud sits near the sun.
			cloud += sun_tint * pow(max(to_sun, 0.0), 14.0) * (1.0 - thick) * 0.5;

			// The deck thins into the horizon haze and its far edge fades out.
			float fade = smoothstep(0.0, 0.14, h);
			col = mix(col, cloud, body * cloud_opacity * fade);
		}
	}

	col = mix(col, horizon_haze, haze_strength * (1.0 - smoothstep(0.0, haze_height, abs(h))));
	COLOR = col * sky_energy;
}
