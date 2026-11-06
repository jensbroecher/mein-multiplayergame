// Yellow-and-black safety striping for the Kronburger Hütte (SteelworksKit.gd, key "hazard"): the hall's gateway posts
// and barrier, the control pulpit's legs, the crane's hook block, the gate's barrier arm. Diagonal stripes laid from
// the world position (no UVs), worn and dirty in places. The vertex colour tints the yellow (white: the plain colours;
// red for red-and-white).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The width of a stripe pair, in world metres.
uniform float period = 0.5;

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
	float d = (wpos.x + wpos.y + wpos.z) / period;
	float fw = fwidth(d);
	float s = smoothstep(0.5 - fw, 0.5 + fw, abs(fract(d) - 0.5) * 2.0);
	s = mix(s, 0.5, smoothstep(0.3, 0.8, fw));
	vec3 yellow = pow(COLOR.rgb, vec3(2.2)) * vec3(0.93, 0.7, 0.06);
	vec3 black = vec3(0.025, 0.025, 0.028);
	vec3 col = mix(black, yellow, s);
	float wear = vnoise(wpos.xy * 3.0 + wpos.zx * 2.1);
	col = mix(col, vec3(0.16, 0.14, 0.12), smoothstep(0.72, 0.9, wear) * 0.7);
	col *= 0.85 + 0.15 * vnoise(wpos.xz * 0.9 + wpos.y * 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.55 + 0.3 * wear;
	METALLIC = 0.1;
}
