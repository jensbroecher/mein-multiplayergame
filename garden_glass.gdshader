// The Botanischer Garten's glasshouses (GardenKit.gd, key "gglass"): the Palmenhaus and the small glasshouse. One
// sheet per pane plane, seen from outside and from inside (both faces, the normal turned toward the eye): thin glass
// with a faint green tint, clear face on and mirror-like at a grazing angle (a Fresnel term). What it reflects is
// made up, in EMISSION: a late-summer sky with fair-weather clouds over a far line of trees and the ground below it,
// by the reflected ray in world space; the sun's glint is the real specular.
// UV is in LIFE metres (u across the bars, v along them): the white-painted glazing bars run along v every `bar_u`,
// the panes' laps cross them every `lap_v`; a few panes are whitewashed against the sun or misted. The bars are
// opaque and lit; every pattern fades to its mean once it is under a pixel, so a far roof doesn't shimmer.
// Drawn after the opaque world, no depth write: the palms behind it show. Ironwork that frames the panes is real
// geometry (GardenKit's ribs); this only draws the fine bars between them.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.74, 0.90, 0.82);
uniform float base_alpha = 0.21;
uniform float edge_alpha = 0.8;
uniform vec3 sky_top : source_color = vec3(0.32, 0.50, 0.80);
uniform vec3 sky_horizon : source_color = vec3(0.80, 0.85, 0.90);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 trees_color : source_color = vec3(0.22, 0.30, 0.20);
uniform vec3 ground_color : source_color = vec3(0.30, 0.33, 0.26);
uniform float refl = 0.95;
// Glazing bars: spacing across them, their width (life metres); the laps along them.
uniform float bar_u = 0.6;
uniform float bar_w = 0.045;
uniform float lap_v = 0.72;
uniform vec3 bar_color : source_color = vec3(0.93, 0.93, 0.90);
// Share of panes whitewashed (shading paint) or misted.
uniform float washed = 0.08;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Box-filtered coverage of a line `w` wide at signed distance d, faded to its mean (w over the spacing) once the pixel
// is wider than the line.
float stripe(float d, float w, float aa, float spacing) {
	aa = max(aa, 1e-4);
	float cov = clamp((w * 0.5 - abs(d)) / aa + 0.5, 0.0, 1.0);
	return mix(cov, clamp(w / spacing, 0.0, 1.0), smoothstep(w * 0.7, w * 2.5, aa));
}

vec3 reflected(vec3 r) {
	float h = r.y;
	vec3 sky = mix(pow(sky_horizon, vec3(2.2)), pow(sky_top, vec3(2.2)), pow(clamp(h, 0.0, 1.0), 0.6));
	vec2 cuv = r.xz / (max(h, 0.0) + 0.25) * 1.4;
	float cl = vnoise(cuv * 1.1) * 0.6 + vnoise(cuv * 2.9 + 7.0) * 0.4;
	sky = mix(sky, pow(cloud_color, vec3(2.2)), smoothstep(0.56, 0.8, cl) * 0.8 * smoothstep(0.03, 0.3, h));
	// A far line of trees rolling with the bearing, the ground below it.
	float az = atan(r.z, r.x);
	float line = 0.02 + 0.04 * vnoise(vec2(az * 5.0, 1.0)) + 0.02 * vnoise(vec2(az * 19.0, 4.0));
	vec3 below = mix(pow(trees_color, vec3(2.2)), pow(ground_color, vec3(2.2)), smoothstep(0.0, -0.12, h));
	return mix(below, sky, smoothstep(line - 0.01, line + 0.01, h));
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	if (dot(n, v) < 0.0) {
		n = -n;
	}
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(1.0 - ndv, 5.0);
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-v, n), 0.0)).xyz;
	vec3 sky = reflected(normalize(r));

	vec2 fw = fwidth(UV);
	float bar = stripe((fract(UV.x / bar_u + 0.5) - 0.5) * bar_u, bar_w, fw.x, bar_u);
	float lap = stripe((fract(UV.y / lap_v) - 0.03) * lap_v, 0.03, fw.y, lap_v);
	vec2 pid = floor(vec2(UV.x / bar_u, UV.y / lap_v));
	float h = hash12(pid + vec2(3.7, 11.3));
	float far = smoothstep(bar_u * 0.2, bar_u * 0.7, max(fw.x, fw.y));
	float milky = step(1.0 - washed, h) * (0.55 + 0.45 * hash12(pid * 1.37 + 2.1));
	milky = mix(milky, washed * 0.75, far);
	// A pane's wash is never even: brushed on, thinner toward its edges.
	milky *= 0.75 + 0.25 * vnoise(UV * 3.0);
	float frame = max(bar, lap * 0.45);

	vec3 glass = pow(tint, vec3(2.2)) * 0.34 + vec3(0.55, 0.58, 0.55) * milky * 0.6;
	ALBEDO = mix(glass, pow(bar_color, vec3(2.2)), frame);
	ROUGHNESS = mix(mix(0.04, 0.35, milky), 0.55, frame);
	METALLIC = 0.0;
	SPECULAR = mix(0.55, 0.3, frame);
	EMISSION = sky * refl * fres * (1.0 - frame) * (1.0 - milky * 0.6);
	ALPHA = clamp(mix(mix(base_alpha, edge_alpha, fres) + milky * 0.35, 1.0, frame), 0.0, 1.0);
	NORMAL = n;
}
