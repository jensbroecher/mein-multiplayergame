// Rusty chain-link mesh for Zeche Kronprinz's industrial fences (ZechenKit.gd industrial_fence, key "zfence"). One quad
// per panel, two-sided; UV in life metres (u along the fence, v up). The diamonds are drawn here: between the wires the
// pixel is discarded. Once the wires are thinner than a pixel, their coverage is kept as a dither on the screen (an
// opaque pipeline, no sorting), so a far fence reads as a faint rusty veil instead of shimmering. The vertex colour tints
// the wire (sRGB); rust and the odd bright galvanised wire come from the position.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The diamond's side and the wire's thickness, in life metres.
uniform float mesh_size = 0.06;
uniform float wire = 0.0045;
uniform vec3 rust_color : source_color = vec3(0.42, 0.22, 0.12);

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

void fragment() {
	vec2 r = vec2(UV.x + UV.y, UV.x - UV.y) * 0.70710678 / mesh_size;
	vec2 f = abs(fract(r) - 0.5);
	float d = (0.5 - max(f.x, f.y)) * mesh_size;
	float fw = length(fwidth(UV));
	float w = wire * 0.5;
	float cov = 1.0 - smoothstep(w - fw * 0.5, w + fw * 0.5, d);
	float mean = clamp(2.0 * wire / mesh_size, 0.0, 1.0) * 1.5;
	cov = mix(cov, mean, smoothstep(wire * 0.6, wire * 2.5, fw));
	// Interleaved gradient noise on the screen: a stable dither for the coverage.
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (cov < dither * 0.98 + 0.01) {
		discard;
	}
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float rn = vnoise(UV * vec2(1.3, 2.2)) * 0.6 + vnoise(UV * 7.0) * 0.4;
	vec3 rc = pow(rust_color, vec3(2.2)) * (0.75 + 0.5 * vnoise(UV * 23.0));
	vec3 col = mix(tint, rc, smoothstep(0.3, 0.7, rn));
	ALBEDO = col;
	ROUGHNESS = mix(0.45, 0.9, smoothstep(0.3, 0.7, rn));
	METALLIC = mix(0.6, 0.1, smoothstep(0.3, 0.7, rn));
}
