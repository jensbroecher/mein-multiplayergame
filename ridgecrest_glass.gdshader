shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Ridgecrest's window glass (RidgecrestKit.gd's "pane"): opaque, the houses have no insides. The
// vertex colour is the glass's tint (sRGB): a dark room behind it with a little of the tint, and its
// alpha the share of a curtain drawn across the pane (a warm pale cloth). What it reflects is made up,
// as on Nyota's towers (city_building.gdshader): a sky gradient with a few clouds over a far skyline of
// wooded ridges, the ground below that, scaled by a Fresnel term, in EMISSION; the sun's glint is the
// real specular. A metallic albedo reflecting the radiance map read as flat pale haze from above.

uniform vec3 refl_top : source_color = vec3(0.16, 0.38, 0.76);
uniform vec3 refl_horizon : source_color = vec3(0.72, 0.84, 0.94);
uniform vec3 refl_ridge : source_color = vec3(0.30, 0.38, 0.34);
uniform vec3 refl_ground : source_color = vec3(0.22, 0.27, 0.18);
uniform vec3 refl_cloud : source_color = vec3(1.0, 0.99, 0.96);
uniform float refl_base = 0.16;
uniform float refl_gain = 1.1;

varying vec3 w_pos;
varying vec3 w_nrm;

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

vec3 reflected(vec3 r) {
	float h = r.y;
	vec3 sky = mix(refl_horizon, refl_top, pow(clamp(h, 0.0, 1.0), 0.5));
	vec2 uv = r.xz / (max(h, 0.0) + 0.3) * 1.6;
	float cl = vnoise(uv * 1.3) * 0.65 + vnoise(uv * 2.9 + 7.0) * 0.35;
	sky = mix(sky, refl_cloud, smoothstep(0.52, 0.78, cl) * 0.8 * smoothstep(0.02, 0.25, h));
	// The far ridges along the horizon, rolling with the bearing.
	float az = atan(r.z, r.x);
	float ridge = 0.03 + 0.05 * vnoise(vec2(az * 3.0, 1.0)) + 0.02 * vnoise(vec2(az * 11.0, 5.0));
	vec3 land = mix(refl_ridge, refl_ground, smoothstep(ridge, -0.25, h));
	return mix(land, sky, smoothstep(ridge - 0.01, ridge + 0.01, h));
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	vec3 n = normalize(w_nrm);
	vec3 view_w = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 r = reflect(-view_w, n);
	float fresnel = refl_base + (1.0 - refl_base) * pow(1.0 - clamp(dot(n, view_w), 0.0, 1.0), 4.0);
	// A curtain: pale cloth in folds over part of the pane, reflecting less.
	float curtain = COLOR.a < 0.99 ? (1.0 - COLOR.a) : 0.0;
	float folds = 0.75 + 0.25 * sin(w_pos.x * 31.0 + w_pos.z * 31.0);
	vec3 room = tint * 0.3;
	ALBEDO = mix(room, vec3(0.62, 0.55, 0.44) * folds, curtain);
	ROUGHNESS = mix(0.05, 0.85, curtain);
	SPECULAR = mix(0.7, 0.3, curtain);
	EMISSION = reflected(r) * clamp(fresnel * refl_gain, 0.0, 1.0) * (1.0 - curtain * 0.85);
}
