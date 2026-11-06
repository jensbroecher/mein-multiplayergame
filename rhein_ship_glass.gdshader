// Ship windows (RheinShipKit.gd's "rglass"): opaque, the ships have no insides. UV runs 0..1 across and up each pane.
// COLOR.rgb is the curtains' colour (sRGB) and COLOR.a how far they are drawn: 0 none (a wheelhouse, a saloon), 0.3 a
// third of the pane hidden, half from each side, with a valance along the top. Behind the glass a dark room.
// What the glass reflects is made up, as on Ridgecrest's (ridgecrest_glass.gdshader): the sky with clouds over a far
// bank of trees, the river under the horizon, by a Fresnel term, in EMISSION; the sun's glint is the real specular.
// No hashes of interpolated values: the curtains come from UV alone and the per-pane draws from the vertex colour.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 room : source_color = vec3(0.075, 0.085, 0.09);
uniform vec3 refl_top : source_color = vec3(0.24, 0.42, 0.74);
uniform vec3 refl_horizon : source_color = vec3(0.86, 0.84, 0.78);
uniform vec3 refl_trees : source_color = vec3(0.34, 0.40, 0.34);
uniform vec3 refl_river : source_color = vec3(0.22, 0.27, 0.27);
uniform vec3 refl_cloud : source_color = vec3(1.0, 0.95, 0.88);
uniform float refl_base = 0.28;
uniform float refl_gain = 1.0;

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
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 reflected(vec3 r) {
	float h = r.y;
	vec3 sky = mix(refl_horizon, refl_top, pow(clamp(h, 0.0, 1.0), 0.55));
	vec2 uv = r.xz / (max(h, 0.0) + 0.3) * 1.5;
	float cl = vnoise(uv * 1.2) * 0.65 + vnoise(uv * 2.7 + 7.0) * 0.35;
	sky = mix(sky, refl_cloud, smoothstep(0.55, 0.8, cl) * 0.7 * smoothstep(0.02, 0.25, h));
	// The far bank: a line of trees rolling with the bearing, the river below it.
	float az = atan(r.z, r.x);
	float bank = 0.01 + 0.03 * vnoise(vec2(az * 4.0, 1.0)) + 0.015 * vnoise(vec2(az * 15.0, 5.0));
	vec3 below = mix(refl_trees, refl_river, smoothstep(0.0, -0.06, h));
	return mix(below, sky, smoothstep(bank - 0.008, bank + 0.008, h));
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 view_w = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec3 r = reflect(-view_w, n);
	float fresnel = refl_base + (1.0 - refl_base) * pow(1.0 - clamp(dot(n, view_w), 0.0, 1.0), 4.0);
	float c = clamp(COLOR.a, 0.0, 1.0);
	vec2 fw = fwidth(UV);
	float side = min(UV.x, 1.0 - UV.x);
	float drawn = step(0.01, c);
	float cur = drawn * (1.0 - smoothstep(c * 0.5 - fw.x, c * 0.5 + fw.x, side));
	float valance = drawn * smoothstep(0.86 - fw.y, 0.86 + fw.y, UV.y);
	cur = max(cur, valance);
	// Folds: a few per curtain, faded once they are under a pixel.
	float fold_f = UV.x * 26.0;
	float folds = mix(0.85, 0.72 + 0.28 * abs(sin(fold_f)), 1.0 - smoothstep(0.08, 0.3, fw.x * 26.0));
	vec3 cloth = pow(COLOR.rgb, vec3(2.2)) * mix(folds, 0.92, valance);
	// The room: darker at the top, a little light at the sill.
	vec3 rm = room * (0.8 + 0.4 * (1.0 - UV.y));
	ALBEDO = mix(rm, cloth * 0.85, cur);
	ROUGHNESS = mix(0.04, 0.85, cur);
	SPECULAR = mix(0.75, 0.3, cur);
	EMISSION = reflected(r) * clamp(fresnel * refl_gain, 0.0, 1.0) * (1.0 - cur * 0.85);
}
