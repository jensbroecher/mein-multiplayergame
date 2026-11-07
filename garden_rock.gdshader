// The Alpinum's stones (GardenKit.gd, key "grock"): weathered limestone and tuff boulders set into the rock garden on
// the hill. Drawn from the model's own position in LIFE metres (the varying `lp`, the kit's frame divided by the
// caller's scale through `inv_scale`), so no UVs are needed: a pale grey-cream stone, faint bedding planes, the tuff's
// pores, grey and yellow lichen in patches, moss on what faces up and in the crevices, darker where COLOR.a says the
// stone is hollowed (1 open face, 0 deep in a fold). COLOR.rgb tints it per stone. Fine patterns fade by fwidth.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://camera_xray.gdshaderinc"

// 1 / the scale the kit was grown by (GardenKit builds at life size and the caller grows it by PROP_SCALE 1.6).
uniform float inv_scale = 0.625;
uniform vec3 moss_color : source_color = vec3(0.28, 0.38, 0.14);
uniform vec3 lichen_color : source_color = vec3(0.80, 0.78, 0.62);
uniform vec3 lichen_gold : source_color = vec3(0.82, 0.62, 0.18);
uniform float moss = 0.55;

varying vec3 lp;
varying vec3 wn;

float hash13(vec3 p) {
	p = fract(p * vec3(123.34, 456.21, 289.17));
	p += dot(p, p.yzx + 45.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), u.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), u.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

void vertex() {
	lp = VERTEX * inv_scale;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (xray_hidden(VERTEX, VIEW_MATRIX, CAMERA_POSITION_WORLD, PROJECTION_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float fw = length(fwidth(lp));
	float fine = 1.0 - smoothstep(0.01, 0.05, fw);
	float n1 = vnoise3(lp * 1.3);
	float n2 = vnoise3(lp * 4.1 + 3.0);
	float n3 = vnoise3(lp * 13.0 + 7.0);
	vec3 col = tint * (0.8 + 0.25 * n1) * (0.92 + 0.12 * mix(n2, 0.5, smoothstep(0.03, 0.12, fw)));
	// Bedding planes: faint darker bands, wavering.
	float bed = sin((lp.y + 0.12 * n1) * 21.0);
	col *= 1.0 - 0.08 * smoothstep(0.7, 1.0, bed) * (1.0 - smoothstep(0.02, 0.08, fw));
	// Tuff's pores: small dark pits.
	float pore = smoothstep(0.72, 0.86, n3) * fine;
	col *= 1.0 - 0.45 * pore;
	// Lichen: pale grey crusts and a few gold ones, in patches.
	float lich = smoothstep(0.62, 0.7, vnoise3(lp * 2.2 + 11.0));
	col = mix(col, pow(lichen_color, vec3(2.2)) * (0.85 + 0.2 * n3), lich * 0.6);
	float gold = smoothstep(0.78, 0.84, vnoise3(lp * 3.3 + 21.0));
	col = mix(col, pow(lichen_gold, vec3(2.2)), gold * 0.55);
	// Moss on the tops and in the folds.
	float up = clamp(wn.y, 0.0, 1.0);
	float mz = smoothstep(0.45, 0.85, up) * smoothstep(0.35, 0.6, n1 + 0.25 * n2) + (1.0 - COLOR.a) * 0.7;
	col = mix(col, pow(moss_color, vec3(2.2)) * (0.75 + 0.4 * n3), clamp(mz * moss, 0.0, 1.0));
	col *= 0.55 + 0.45 * COLOR.a;
	ALBEDO = col;
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
