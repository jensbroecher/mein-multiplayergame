// Loose cargo and riprap on the Rhine (RheinShipKit.gd: "bulk", the gravel and ore heaps in the holds; "riprap", the
// groynes' stones). The vertex colour is the material's tone (sRGB). Grains are drawn in the mesh's own space, in life
// metres (VERTEX / `unit`), on the plane each face mostly looks along, so a moving ship's cargo moves with it: lumps of
// `grain` metres, lighter and darker, with dark gaps between them, faded to their mean under a pixel. `stones` adds
// lichen on the faces turned up and dark moss low down (riprap).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float unit = 1.6;
uniform float grain = 0.06;
uniform float contrast = 0.35;
uniform float stones = 0.0;
uniform vec3 lichen : source_color = vec3(0.62, 0.62, 0.50);

varying vec3 lpos;
varying vec3 lnrm;

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
	lpos = VERTEX / unit;
	lnrm = NORMAL;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 n = normalize(lnrm);
	vec3 an = abs(n);
	vec2 q = an.y > 0.6 ? lpos.xz : (an.x > an.z ? lpos.zy : lpos.xy);
	float fw = length(fwidth(q));
	float g = vnoise(q / grain);
	float g2 = vnoise(q / (grain * 0.45) + 17.0);
	float big = vnoise(q / (grain * 9.0) + 3.0);
	float fine = 1.0 - smoothstep(grain * 0.3, grain * 1.5, fw);
	float mid = 1.0 - smoothstep(grain * 3.0, grain * 14.0, fw);
	float lumps = mix(0.5, g * 0.65 + g2 * 0.35, fine);
	float gaps = mix(0.0, smoothstep(0.32, 0.18, g), fine);
	vec3 col = base * (1.0 + contrast * (lumps - 0.5) * 2.0) * (0.85 + 0.3 * mix(0.5, big, mid));
	col *= 1.0 - 0.45 * gaps;
	// Some lighter, some redder stones among them.
	col = mix(col, col * vec3(1.25, 1.1, 0.95), smoothstep(0.78, 0.9, g2) * 0.5 * fine);
	if (stones > 0.0) {
		float lc = smoothstep(0.55, 0.8, vnoise(q * 1.7 + 9.0)) * smoothstep(0.2, 0.7, n.y);
		col = mix(col, pow(lichen, vec3(2.2)) * (0.8 + 0.3 * g), lc * 0.6 * stones);
		float moss = smoothstep(0.5, 0.8, vnoise(q * 0.9 + 2.0)) * (1.0 - smoothstep(-0.4, 0.4, n.y));
		col = mix(col, vec3(0.05, 0.06, 0.03), moss * 0.35 * stones);
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.35;
}
