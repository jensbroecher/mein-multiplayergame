// Ruhr industrial brick for the Kronburger Hütte (SteelworksKit.gd, key "brick"): running bond with lighter mortar, each
// brick its own shade, now and then a dark clinker, soot and rain streaks down the walls from the world position. UV is in
// game metres (life x 1.6, SteelworksKit.uvk), u along the wall, v up; the vertex colour is the brick's tint.
// Filtered: the joints fade to their mean as a course gets smaller than a few pixels (hut_masonry's brick aliased into
// moiré across a 240m hall).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float course = 0.12;
uniform float brick_len = 0.38;
uniform float joint = 0.011;
uniform vec3 mortar : source_color = vec3(0.55, 0.52, 0.47);
uniform float soot = 0.4;

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
	vec2 q = UV;
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	vec2 fq = fwidth(q);
	float aa = max(fq.x, fq.y);
	float row = floor(q.y / course);
	float bx = q.x / brick_len + 0.5 * mod(row, 2.0);
	vec2 cell = vec2(floor(bx), row);
	vec2 f = vec2(fract(bx) * brick_len, fract(q.y / course) * course);
	float d = min(min(f.x, brick_len - f.x), min(f.y, course - f.y));
	float m = 1.0 - smoothstep(joint - aa * 0.7, joint + aa * 0.7, d);
	float id = hash12(cell);
	vec3 brick = tint * (0.74 + 0.42 * id);
	brick = mix(brick, tint * vec3(0.42, 0.40, 0.44), step(0.9, hash12(cell + 7.7)));
	vec3 mc = pow(mortar, vec3(2.2));
	vec3 col = mix(brick, mc, m * 0.85);
	// Under a few pixels a course: its mean (the mortar's share of the face).
	float share = clamp(joint * 2.0 * (1.0 / course + 1.0 / brick_len), 0.0, 1.0) * 0.85;
	vec3 mean = mix(tint * 0.93, mc, share);
	col = mix(col, mean, smoothstep(course * 0.12, course * 0.45, aa));
	// Soot and rain streaks down the walls, a few broad blotches.
	float hcoord = wpos.x + wpos.z;
	float streak = vnoise(vec2(hcoord * 0.7, wpos.y * 0.045)) * 0.7 + vnoise(vec2(hcoord * 0.13, wpos.y * 0.02 + 3.0)) * 0.3;
	col *= 1.0 - soot * smoothstep(0.45, 0.95, streak);
	col *= 0.9 + 0.1 * vnoise(wpos.xz * 0.05 + wpos.y * 0.03);
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
