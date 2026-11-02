shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The mining trucks' tyres (MinaKit.gd, through PropKit.painted_tyre's UVs): chevron lugs across the tread, a solid
// rib down its middle, the sidewall's raised bands, and the pit's dust caked into the grooves and over the lower half.
//   UV.x - round the tyre, 0..1; UV.y - across its section: 0..0.3 one sidewall, 0.3..0.7 the tread, 0.7..1 the other,
//   past 1 the inside of the ring.

uniform vec4 rubber : source_color = vec4(0.075, 0.072, 0.07, 1.0);
uniform vec4 dust : source_color = vec4(0.62, 0.48, 0.38, 1.0);
uniform float lugs = 34.0;
// Where the tyre's lower half is in the mesh's frame (the dust caked over it), metres.
uniform float dust_top = 2.2;

varying float my;

void vertex() {
	my = VERTEX.y;
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float inside = step(1.0, v);
	float tread = smoothstep(0.27, 0.31, v) * (1.0 - smoothstep(0.69, 0.73, v)) * (1.0 - inside);
	float tv = clamp((v - 0.3) / 0.4, 0.0, 1.0);
	float x = abs(tv - 0.5) * 2.0;
	float offset = tv > 0.5 ? 0.5 : 0.0;
	float g = fract(u * lugs + x * 1.1 + offset);
	float lw = fwidth(u * lugs) * 1.5 + 0.02;
	float groove = smoothstep(0.0, lw, g) * (1.0 - smoothstep(0.38 - lw, 0.38 + lw, g));
	groove *= smoothstep(0.14, 0.22, x) * tread;
	// Sidewall: two raised rings and the bead.
	float sv = v < 0.5 ? v / 0.3 : (1.0 - v) / 0.3;
	float rings = (smoothstep(0.42, 0.45, sv) * (1.0 - smoothstep(0.5, 0.53, sv)) + smoothstep(0.78, 0.8, sv) * (1.0 - smoothstep(0.84, 0.86, sv))) * (1.0 - tread) * (1.0 - inside);
	vec3 col = rubber.rgb * (1.0 - 0.55 * groove) * (1.0 + 0.6 * rings);
	float low = 1.0 - smoothstep(0.0, dust_top, my);
	float caked = clamp(low * 0.75 + groove * 0.5 + 0.12, 0.0, 0.9);
	col = mix(col, dust.rgb * (0.85 + 0.15 * groove), caked * 0.7);
	ALBEDO = col;
	ROUGHNESS = mix(0.82, 0.97, caked);
	SPECULAR = 0.3;
}
