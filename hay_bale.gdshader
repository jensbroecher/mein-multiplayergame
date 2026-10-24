shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Big square straw bales (regenerate_lakeside.gd, _hay_bale): pressed straw drawn in the shader, no
// texture. The bale is built of flakes, slices across its length, so the long faces show the strands
// lying lengthwise broken by a seam every 10cm or so; the cut ends show the chopped stalks end-on.
// Weathered: rain greys the top, the foot is darker where it sits in the damp.
//   UV     - metres across the face: along the bale (u) on the long faces, across it on the ends
//   COLOR  - r how weathered the bale is, g a random per bale, b the face (0 side, 0.5 top, 1 end)
// Bumps come from the strands' height through screen-space derivatives (no tangents needed).

uniform vec4 straw_gold : source_color = vec4(0.80, 0.65, 0.33, 1.0);
uniform vec4 straw_pale : source_color = vec4(0.93, 0.85, 0.58, 1.0);
uniform vec4 straw_dark : source_color = vec4(0.45, 0.35, 0.17, 1.0);
uniform vec4 weathered : source_color = vec4(0.60, 0.57, 0.49, 1.0);
uniform vec4 damp : source_color = vec4(0.30, 0.26, 0.16, 1.0);
uniform float flake = 0.105;
uniform float bump_strength = 0.9;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Strands lying mostly along x, wavy and of all lengths, in bundles lighter or darker than the
// next, with a few lying across them.
float strands(vec2 p, float seed) {
	vec2 q = vec2(p.x, p.y + (vnoise(p * vec2(1.7, 3.0) + seed * 13.0) - 0.5) * 0.12);
	float s1 = vnoise(q * vec2(10.0, 110.0) + seed * 7.0);
	float s2 = vnoise(q * vec2(22.0, 210.0) + 3.1);
	float bundle = vnoise(q * vec2(2.0, 14.0) + seed * 3.0);
	vec2 r = vec2(p.x * 0.6 - p.y * 0.8, p.x * 0.8 + p.y * 0.6);
	float stray = vnoise(r * vec2(12.0, 160.0) + 5.0);
	float s = s1 * 0.42 + s2 * 0.28 + bundle * 0.2 + stray * 0.1;
	return smoothstep(0.15, 0.85, s);
}

// Chopped stalks seen end-on: little bright ends and dark gaps.
float stubble(vec2 p, float seed) {
	float a = vnoise(p * 70.0 + seed * 9.0);
	float b = vnoise(p * 150.0 + 2.7);
	float c = vnoise(p * vec2(12.0, 30.0));
	return a * 0.45 + b * 0.35 + c * 0.2;
}

vec3 bump_normal(vec3 n, vec3 pos, float h, float k) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - k * grad);
}

void fragment() {
	float seed = COLOR.g;
	float face = COLOR.b;
	vec2 uv = UV;
	float h;
	float seam = 0.0;
	if (face > 0.75) {
		h = stubble(uv, seed);
	} else {
		h = strands(uv, seed);
		// The flakes: a seam across the bale every `flake`, wandering a little.
		float x = uv.x / flake + (vnoise(vec2(uv.y * 2.5, uv.x * 0.7) + seed * 5.0) - 0.5) * 0.9;
		float f = fract(x);
		// Every flake is its own thickness: some seams barely show.
		float strength = smoothstep(0.35, 0.9, hash12(vec2(floor(x), seed * 17.0)));
		seam = (1.0 - smoothstep(0.0, 0.04, min(f, 1.0 - f))) * strength * mix(0.4, 1.0, vnoise(vec2(uv.y * 7.0, x)));
		h -= seam * 0.3;
	}
	// Colour: gold with pale and dark strands, coarser patches over the bale.
	float patch = vnoise(uv * 2.3 + seed * 31.0);
	vec3 c = mix(straw_dark.rgb, straw_gold.rgb, smoothstep(0.15, 0.6, h));
	c = mix(c, straw_pale.rgb, smoothstep(0.62, 0.85, h) * 0.8);
	c *= mix(0.86, 1.08, patch);
	c *= 1.0 - seam * 0.16;
	// Weathered grey on top (and a little down the sides), damp at the foot.
	float rain = (face > 0.25 && face < 0.75 ? 1.0 : 0.35) * COLOR.r * smoothstep(0.3, 0.7, vnoise(uv * 1.4 + seed * 17.0) * 0.6 + 0.4);
	c = mix(c, weathered.rgb * mix(0.85, 1.05, h), rain * 0.7);
	if (face < 0.25 || face > 0.75) {
		float foot = 1.0 - smoothstep(0.0, 0.16 + vnoise(vec2(uv.x * 3.0, 0.0)) * 0.08, uv.y);
		c = mix(c, damp.rgb, foot * 0.75);
	}
	ALBEDO = c;
	// The strands' relief fades out where it would only shimmer.
	float fade = 1.0 - smoothstep(0.004, 0.02, fwidth(uv.x) + fwidth(uv.y));
	NORMAL = bump_normal(NORMAL, VERTEX, h * 0.012, bump_strength * fade);
	ROUGHNESS = mix(0.78, 0.95, h);
	SPECULAR = 0.3;
	AO = mix(0.55, 1.0, smoothstep(0.0, 0.5, h + 0.3)) * (1.0 - seam * 0.3);
	AO_LIGHT_AFFECT = 0.3;
	BACKLIGHT = c * 0.12;
}
