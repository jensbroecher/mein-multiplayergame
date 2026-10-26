// splash_sky.gdshader: the title card's sky, which is also what the logo and the paint reflect. A deep blue
// dome with an orange glow along the horizon, widest toward -Z where the logo stands, and a low sun. Soft
// boxes for the reflections are kept out of the camera's view: behind it, overhead and to the sides (a warm
// strip to the left, a cool one to the right, which tint the gloss at the cars' flanks). No TIME: the
// radiance map is built once.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.004, 0.011, 0.048);
uniform vec3 mid_color : source_color = vec3(0.018, 0.06, 0.20);
uniform vec3 glow_color : source_color = vec3(1.0, 0.36, 0.06);
uniform vec3 ground_color : source_color = vec3(0.010, 0.013, 0.032);
uniform vec3 box_color : source_color = vec3(1.0, 0.96, 0.90);
uniform vec3 warm_color : source_color = vec3(1.0, 0.55, 0.20);
uniform vec3 cool_color : source_color = vec3(0.35, 0.65, 1.0);
uniform float box_energy = 2.0;

// A soft-edged box on the sky: `centre` and `size` in (azimuth, elevation) radians.
float soft_box(vec2 ae, vec2 centre, vec2 size, float soft) {
	vec2 d = abs(ae - centre) - size;
	return 1.0 - smoothstep(0.0, soft, max(d.x, d.y));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float az = atan(d.x, d.z);    // 0 toward +Z, where the camera stands; PI toward -Z, the logo
	float toward_logo = 0.5 - 0.5 * cos(az);
	vec3 col = mix(mid_color, top_color, smoothstep(0.03, 0.7, el));
	// The horizon's glow: a low band, strong only behind the logo.
	float low = exp(-max(el, 0.0) * 20.0);
	col = mix(col, glow_color * 0.6, low * (0.05 + 0.95 * pow(toward_logo, 6.0)));
	// A low sun behind the logo: a hot core, a halo, a wide faint wash.
	float s = max(dot(d, normalize(vec3(0.0, 0.04, -1.0))), 0.0);
	col += glow_color * (pow(s, 600.0) * 3.0 + pow(s, 120.0) * 0.55 + pow(s, 26.0) * 0.06);
	col = mix(col, ground_color, smoothstep(0.0, -0.07, el));

	// The soft boxes the gloss reflects. A flat floor reflects low parts of the sky and a car's flank
	// the horizon, so the boxes sit above them: they are for hoods, roofs and the letters' faces.
	vec3 boxes = vec3(0.0);
	boxes += box_color * smoothstep(1.0, 1.14, el) * (1.0 - smoothstep(0.22, 0.34, abs(d.x)));
	boxes += box_color * soft_box(vec2(az, el), vec2(0.0, 0.70), vec2(0.55, 0.14), 0.08);
	boxes += warm_color * soft_box(vec2(az, el), vec2(-1.2, 0.62), vec2(0.30, 0.20), 0.10) * 0.7;
	boxes += cool_color * soft_box(vec2(az, el), vec2(1.2, 0.62), vec2(0.30, 0.20), 0.10) * 0.7;
	COLOR = col + boxes * box_energy;
}
