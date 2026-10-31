// garage_sky.gdshader: the garage's (Garage.gd) sky, two skies in one. What the radiance cubemap sees (the
// cars' reflections and the ambient light, AT_CUBEMAP_PASS) is the car select screen's studio
// (showroom_sky.gdshader: soft boxes that put long highlights on the paint), since the galleries are closed
// rooms. What the eye sees, through the concourse's glass roof and the entrance doors, is a summer
// afternoon: a blue gradient, the sun (LIGHT0) and fair-weather cumulus. No TIME: the radiance map is built once.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.16, 0.18, 0.23);
uniform vec3 horizon_color : source_color = vec3(0.09, 0.10, 0.13);
uniform vec3 ground_color : source_color = vec3(0.02, 0.022, 0.028);
uniform vec3 box_color : source_color = vec3(1.0, 0.97, 0.92);
uniform float box_energy = 2.6;

uniform vec3 sky_zenith : source_color = vec3(0.20, 0.42, 0.82);
uniform vec3 sky_horizon : source_color = vec3(0.68, 0.80, 0.92);
uniform vec3 sky_ground : source_color = vec3(0.36, 0.40, 0.34);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.99, 0.97);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.67, 0.76);
uniform float cloud_cover = 0.5;

float soft_box(vec2 ae, vec2 centre, vec2 size, float soft) {
	vec2 d = abs(ae - centre) - size;
	return 1.0 - smoothstep(0.0, soft, max(d.x, d.y));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.4);
		a *= 0.5;
	}
	return v;
}

vec3 studio(vec3 d) {
	float el = asin(clamp(d.y, -1.0, 1.0));
	float az = atan(d.x, d.z);
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.9, el));
	col = mix(col, ground_color, smoothstep(0.0, -0.35, el));
	float boxes = 0.0;
	boxes += smoothstep(1.05, 1.18, el) * (1.0 - smoothstep(0.22, 0.30, abs(d.x)));
	boxes += soft_box(vec2(az, el), vec2(0.0, 0.42), vec2(0.55, 0.16), 0.08);
	boxes += soft_box(vec2(abs(az), el), vec2(1.57, 0.30), vec2(0.10, 0.30), 0.06) * 0.8;
	boxes += soft_box(vec2(abs(az), el), vec2(3.14159, 0.35), vec2(0.45, 0.10), 0.08) * 0.6;
	return col + box_color * box_energy * clamp(boxes, 0.0, 1.0);
}

vec3 outdoors(vec3 d) {
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon, sky_zenith, pow(up, 0.55));
	// The ground beyond the forecourt, hazed.
	col = mix(col, sky_ground, smoothstep(0.0, -0.08, d.y));
	// Cumulus on a plane overhead: dense where the noise is high, shaded underneath.
	if (d.y > 0.02) {
		vec2 p = d.xz / (d.y + 0.08) * 2.2;
		float n = fbm(p * 0.6 + vec2(3.0, 7.0));
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, n);
		float body = fbm(p * 1.4 + vec2(-4.0, 2.0));
		vec3 cl = mix(cloud_shade, cloud_color, smoothstep(0.35, 0.75, body));
		c *= smoothstep(0.02, 0.18, d.y);
		col = mix(col, cl, c * 0.92);
	}
	// The sun and its glow.
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float s = max(dot(d, sd), 0.0);
	col += LIGHT0_COLOR * (pow(s, 900.0) * 18.0 + pow(s, 12.0) * 0.18);
	return col;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	if (AT_CUBEMAP_PASS) {
		COLOR = studio(d);
	} else {
		COLOR = outdoors(d);
	}
}
