shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Koi (KoiFish.gd's MultiMesh, Yoshino Rapids' garden pool and stream). The mesh is a fish at life size, its nose toward
// +z: UV.x runs along it (0 the nose, 1 the tail's tip), UV.y is 1 on the fins. The body swishes from behind the head to
// the tail, faster as it swims faster. INSTANCE_CUSTOM: r the variety (0 kohaku: white with red patches, 1 ogon: gold,
// 2 orange, 3 showa: black with red and white, 4 shiro bekko: white with black spots), g a seed for its patches, b the
// tail's phase, a how hard it swims (0..1).

varying vec3 v_obj;
varying float v_fin;
varying float v_along;
varying flat vec4 v_cd;

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

void vertex() {
	v_cd = INSTANCE_CUSTOM;
	float t = UV.x;
	float amp = smoothstep(0.2, 1.0, t) * (0.05 + 0.06 * INSTANCE_CUSTOM.a);
	float ph = INSTANCE_CUSTOM.b * 6.2832 + TIME * (4.0 + 5.0 * INSTANCE_CUSTOM.a);
	VERTEX.x += sin(ph - t * 4.5) * amp;
	v_obj = VERTEX;
	v_fin = UV.y;
	v_along = t;
}

void fragment() {
	int pat = int(v_cd.r + 0.5);
	vec3 white = vec3(0.92, 0.90, 0.86);
	vec3 red = vec3(0.82, 0.14, 0.05);
	vec3 orange = vec3(0.96, 0.46, 0.08);
	vec3 gold = vec3(0.96, 0.74, 0.26);
	vec3 black = vec3(0.04, 0.04, 0.05);
	vec2 q = v_obj.zx * vec2(5.0, 7.0) + v_cd.g * 37.0;
	float n = vnoise(q) * 0.65 + vnoise(q * 2.3 + 5.1) * 0.35;
	float n2 = vnoise(q * 1.7 + 11.3) * 0.6 + vnoise(q * 3.9) * 0.4;
	vec3 col = white;
	if (pat == 0) {
		col = mix(white, red, smoothstep(0.48, 0.55, n));
	} else if (pat == 1) {
		col = gold;
	} else if (pat == 2) {
		col = mix(orange, white, smoothstep(0.7, 0.76, n) * 0.6);
	} else if (pat == 3) {
		col = mix(black, red, smoothstep(0.50, 0.56, n));
		col = mix(col, white, smoothstep(0.62, 0.68, n2));
	} else {
		col = mix(white, black, smoothstep(0.66, 0.72, n));
	}
	// A paler belly, the scales' net, translucent pale fins.
	col = mix(col, white * 0.95, smoothstep(0.0, -0.06, v_obj.y) * 0.5);
	float scale_net = smoothstep(0.38, 0.5, abs(fract(v_obj.z * 22.0 + abs(v_obj.x) * 11.0) - 0.5));
	col *= 0.9 + 0.1 * scale_net;
	col = mix(col, mix(col, white, 0.55), v_fin);
	ALBEDO = col;
	ROUGHNESS = pat == 1 ? 0.25 : 0.4;
	METALLIC = pat == 1 ? 0.45 : 0.0;
	SPECULAR = 0.6;
}
