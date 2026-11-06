// Glowing hot steel for the Kronburger Hütte (SteelworksKit.gd, key "hot"): slabs on the roller tables, the steel in
// the mill stands' roll gaps, bars on the cooling bed, the reheating furnace's door slots, the blast furnace's iron
// runner and the torpedo cars' mouths.
// The vertex colour is the glow's colour (sRGB; SteelworksKit.hot_colour(t): dark red through cherry and orange to
// yellow-white), so its brightness follows the temperature by itself. Scale (oxide) crusts over it in patches that
// glow less, laid from the world position (no UVs needed), and a faint slow shimmer runs through it.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float energy = 3.4;
// How much the scale patches dim the glow (0: none).
uniform float crust = 0.55;
// The shimmer's speed and depth.
uniform float shimmer_speed = 0.7;
uniform float shimmer = 0.12;

varying vec3 wpos;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 glow = pow(COLOR.rgb, vec3(2.2));
	// Past a few metres a pixel spans the fine octave: fade it to its mean (outside any branch).
	float fw = length(fwidth(wpos));
	float fine = 1.0 - smoothstep(0.06, 0.35, fw);
	vec2 q = wpos.xz + vec2(wpos.y * 0.73, -wpos.y * 0.51);
	float n = vnoise(q * 1.6) * 0.62 + mix(0.19, vnoise(q * 5.3 + 3.1) * 0.38, fine);
	float scale_patch = smoothstep(0.5, 0.74, n);
	float t = TIME * shimmer_speed;
	float sh = 1.0 - shimmer + shimmer * sin(t + vnoise(q * 0.7 + vec2(t * 0.13, 1.7)) * 6.283);
	float hot = 1.0 - crust * scale_patch;
	ALBEDO = mix(vec3(0.045, 0.04, 0.036), glow * 0.12, 0.5) * (1.0 - 0.4 * scale_patch);
	METALLIC = 0.35;
	ROUGHNESS = mix(0.42, 0.85, scale_patch);
	EMISSION = glow * energy * sh * hot;
}
