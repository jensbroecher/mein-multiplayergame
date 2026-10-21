// Humid tropical sky: a saturated blue overhead sinking into a milky, green-tinged haze at the horizon,
// with heaped cumulus that are lit from the sun's side and grey-blue underneath.
//
// Static on purpose, like sky_winter_cirrus.gdshader: a sky shader that reads TIME forces Godot to
// rebuild the radiance map every frame. Storm transitions are driven smoothly via the rain_sky_blend
// global uniform (JungleRain.gd), avoiding radiance rebuild stalls while smoothly animating the visible sky.
shader_type sky;
render_mode use_debanding;

global uniform float rain_sky_blend;

group_uniforms storm;
uniform vec3 storm_sky_top : source_color = vec3(0.30, 0.34, 0.38);
uniform vec3 storm_sky_horizon : source_color = vec3(0.46, 0.50, 0.50);
uniform vec3 storm_cloud_lit : source_color = vec3(0.55, 0.58, 0.60);
uniform float storm_cloud_coverage : hint_range(0.0, 1.0) = 0.95;
uniform float storm_cloud_opacity : hint_range(0.0, 1.0) = 0.95;
uniform float storm_sun_glow : hint_range(0.0, 1.0) = 0.05;
uniform float storm_sky_energy : hint_range(0.0, 2.0) = 0.6;

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
// A warm glow along the horizon on the sun's side, as in a late afternoon (0 = none; Msitu Falls has none).
uniform vec3 sun_horizon_tint : source_color = vec3(1.0, 0.80, 0.55);
uniform float sun_horizon_glow : hint_range(0.0, 1.0) = 0.0;
uniform float sun_horizon_height : hint_range(0.02, 0.6) = 0.22;

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
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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
	float k = clamp(rain_sky_blend, 0.0, 1.0);
	vec3 cur_sky_top = mix(sky_top, storm_sky_top, k);
	vec3 cur_sky_horizon = mix(sky_horizon, storm_sky_horizon, k);
	vec3 cur_cloud_lit = mix(cloud_lit, storm_cloud_lit, k);
	float cur_cloud_coverage = mix(cloud_coverage, storm_cloud_coverage, k);
	float cur_cloud_opacity = mix(cloud_opacity, storm_cloud_opacity, k);
	float cur_sun_glow = mix(sun_glow, storm_sun_glow, k);
	float cur_sky_energy = mix(sky_energy, storm_sky_energy, k);

	vec3 d = normalize(EYEDIR);
	float h = d.y;

	vec3 col;
	if (h >= 0.0) {
		col = mix(cur_sky_horizon, cur_sky_top, pow(clamp(h, 0.0, 1.0), sky_curve));
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
		float glow = pow(max(to_sun, 0.0), 48.0) * cur_sun_glow + pow(max(to_sun, 0.0), 6.0) * cur_sun_glow * 0.25;
		col += sun_tint * LIGHT0_COLOR * (glow + disc * 12.0) * min(LIGHT0_ENERGY, 2.0);
		sun_flat = LIGHT0_DIRECTION.xz;
		if (dot(sun_flat, sun_flat) < 0.0001) {
			sun_flat = vec2(0.6, 0.8);
		}
	}

	if (h > 0.0) {
		// Project onto a flat cloud deck: small clouds piled up near the horizon, large overhead.
		vec2 uv = d.xz / (h + 0.14);
		vec2 w = wind_dir;
		if (dot(w, w) < 0.0001) {
			w = vec2(0.82, 0.57);
		}
		w = normalize(w);
		vec2 n = vec2(-w.y, w.x);
		// A little longer along the wind than across it.
		vec2 q = vec2(dot(uv, w) * 0.9, dot(uv, n)) * cloud_scale + cloud_seed;
		vec2 warp = (vec2(fbm(q * 0.7 + 3.1, 3), fbm(q * 0.7 + 8.3, 3)) - 0.5) * 0.5;

		// Coverage is not linear in the threshold: the top of its range closes the sky over completely.
		float thresh = mix(0.80, -0.15, pow(cur_cloud_coverage, 1.8));
		float overcast = smoothstep(0.65, 0.95, cur_cloud_coverage);
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
			vec3 cloud = mix(shade, cur_cloud_lit, bright);
			// Silver lining where thin cloud sits near the sun.
			cloud += sun_tint * pow(max(to_sun, 0.0), 14.0) * (1.0 - thick) * 0.5;

			// The deck thins into the horizon haze and its far edge fades out.
			float fade = smoothstep(0.0, 0.14, h);
			col = mix(col, cloud, body * cur_cloud_opacity * fade);
		}
	}

	col = mix(col, horizon_haze, haze_strength * (1.0 - smoothstep(0.0, haze_height, abs(h))));
	if (sun_horizon_glow > 0.0 && h > -0.05) {
		// Strongest low in the sun's direction, fading round the sky and up.
		float az = max(dot(normalize(d.xz + vec2(0.0001)), normalize(sun_flat)), 0.0);
		float band = 1.0 - smoothstep(0.0, sun_horizon_height, max(h, 0.0));
		col = mix(col, sun_tint * sun_horizon_tint, sun_horizon_glow * pow(az, 2.5) * band);
	}
	COLOR = col * cur_sky_energy;
}

