// Riveted, painted steel plate (StadtKit.gd, key "rivet"): the railway bridge's plate girders and its trough. UV is in game
// metres (life x 1.6), u along the plate, v up from its bottom edge; the vertex colour is the paint. Rivet heads stand in
// rows along the flange lines (every `row_pitch` up from `row0`) and in pairs of columns either side of every stiffener
// (every `col_pitch` along u), each a little dome with a dark ring round it; under a pixel the rows fade to their mean.
// The paint is weathered from the world position: soot and dirt streaks, rust bleeding from the rivet rows.
// The mesh needs tangents (StadtKit.commit makes them).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float pitch = 0.15;
uniform float rivet_r = 0.03;
uniform float row0 = 0.1;
uniform float row_pitch = 0.62;
uniform float col_pitch = 2.4;
uniform float col_off = 0.1;
uniform vec3 rust_color : source_color = vec3(0.42, 0.22, 0.12);
uniform float rust = 0.35;

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
	float aa = length(fwidth(q));
	// The nearest rivet on a row (rows along u) and on a stiffener's columns (along v).
	float ry = row0 + max(round((q.y - row0) / row_pitch), 0.0) * row_pitch;
	vec2 dr = vec2(q.x - round(q.x / pitch) * pitch, q.y - ry);
	float sx = round(q.x / col_pitch) * col_pitch;
	float cx = sx + (q.x > sx ? col_off : -col_off);
	vec2 dc = vec2(q.x - cx, q.y - round(q.y / pitch) * pitch);
	vec2 dv = dot(dr, dr) < dot(dc, dc) ? dr : dc;
	float d = length(dv);
	float head = 1.0 - smoothstep(rivet_r - aa, rivet_r + aa, d);
	float ring = smoothstep(rivet_r * 0.6, rivet_r, d) * (1.0 - smoothstep(rivet_r, rivet_r * 1.5 + aa, d));
	float far = smoothstep(rivet_r * 0.5, rivet_r * 2.0, aa);
	head *= 1.0 - far;
	ring *= 1.0 - far;
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	// Weathering: broad blotches, streaks down the plate, rust bleeding under the rivet rows.
	float hcoord = wpos.x + wpos.z;
	float st = vnoise(vec2(hcoord * 3.0, wpos.y * 0.25)) * 0.6 + vnoise(vec2(hcoord * 0.4, wpos.y * 0.1 + 2.0)) * 0.4;
	vec3 col = paint * (0.88 + 0.16 * vnoise(wpos.xz * 0.3 + wpos.y * 0.2));
	col *= 1.0 - 0.22 * smoothstep(0.55, 0.95, st);
	float below = clamp((ry - q.y) / 0.5, 0.0, 1.0) * step(q.y, ry) * (1.0 - smoothstep(0.0, 0.5, ry - q.y));
	float bleed = smoothstep(0.55, 0.85, vnoise(vec2(q.x * 9.0, q.y * 1.2))) * below;
	col = mix(col, pow(rust_color, vec3(2.2)), clamp(rust * (bleed * 0.8 + 0.25 * smoothstep(0.7, 1.0, st)), 0.0, 1.0));
	col = mix(col, col * 1.12, head);
	col *= 1.0 - 0.45 * ring;
	ALBEDO = col;
	ROUGHNESS = 0.62;
	METALLIC = 0.18;
	vec2 tilt = d > 1e-5 ? dv / d * 0.9 * head * smoothstep(0.0, rivet_r, d) : vec2(0.0);
	NORMAL_MAP = normalize(vec3(tilt, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
