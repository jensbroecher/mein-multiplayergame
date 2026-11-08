shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The sides of Frostpeak Creek's roads where they stand over the ground (TerrainGenerator's Visual_Road_Sides,
// the shortcuts' embankments): grey granite blocks in courses, as a Norwegian mountain road's retaining walls,
// with frost lodged on the top edge of each block, darker damp blocks low down and wet streaks running down.
// Laid out in world space on the two upright planes (x and z, blended by the normal), since the meshes'
// UVs aren't in metres. The joints fade to their average once a pixel is wider than they are.

uniform vec4 stone_color : source_color = vec4(0.40, 0.41, 0.43, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.19, 0.19, 0.20, 1.0);
uniform vec4 frost_color : source_color = vec4(0.84, 0.87, 0.93, 1.0);
uniform float course_h = 0.62;
uniform float block_l = 1.35;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// One plane of ashlar: x along the wall, y up, in metres. Returns (joint 0..1, block tone, frost on the
// block's top edge, the block's height in its course 0..1).
vec4 ashlar(vec2 p, float px) {
	float row = floor(p.y / course_h);
	float x = p.x + hash21(vec2(row, 7.1)) * block_l;
	// Blocks of uneven length: each cell is split once at a jittered point.
	float cell = floor(x / block_l);
	float split = 0.3 + 0.4 * hash21(vec2(cell, row));
	float lx = fract(x / block_l);
	float bid = cell * 2.0 + step(split, lx);
	float edge_x = min(min(lx, 1.0 - lx), abs(lx - split)) * block_l;
	float ly = fract(p.y / course_h);
	float edge_y = min(ly, 1.0 - ly) * course_h;
	float w = 0.025 + px * 0.5;
	float joint = 1.0 - smoothstep(w, w + 0.02 + px, min(edge_x, edge_y));
	float tone = hash21(vec2(bid, row + 3.3));
	float frost = smoothstep(0.86, 0.97, ly) * (0.5 + 0.5 * hash21(vec2(bid, row + 9.7)));
	return vec4(joint, tone, frost, ly);
}

void fragment() {
	// The faces' own facing: the road-side meshes' vertex normals lean up toward the road's surface, so the
	// blocks' planes weighed almost nothing and the frost whitened the whole face.
	vec3 n = normalize(cross(dFdx(w_pos), dFdy(w_pos)));
	if (dot(n, w_nrm) < 0.0) {
		n = -n;
	}
	float px = length(fwidth(w_pos));
	float fade = 1.0 - smoothstep(0.06, 0.2, px);
	vec3 bw = pow(abs(n), vec3(8.0));
	vec4 ax = ashlar(vec2(w_pos.z, w_pos.y), px);
	vec4 az = ashlar(vec2(w_pos.x, w_pos.y), px);
	vec4 a = (ax * bw.x + az * bw.z) / max(bw.x + bw.z, 0.0001);
	vec3 stone = stone_color.rgb * (0.72 + a.y * 0.45) * (0.85 + vnoise(w_pos.xz * 0.7 + w_pos.y) * 0.3);
	// Some blocks warmer, some bluer.
	stone *= mix(vec3(1.05, 1.0, 0.94), vec3(0.95, 0.98, 1.05), step(0.5, fract(a.y * 7.0)));
	vec3 col = mix(stone, mortar_color.rgb, a.x * fade);
	col = mix(col, frost_color.rgb, a.z * fade * 0.8);
	// Wet streaks down the face.
	float streak = smoothstep(0.62, 0.9, vnoise(vec2((w_pos.x + w_pos.z) * 1.8, w_pos.y * 0.15)));
	col *= 1.0 - streak * 0.25;
	// Whatever faces up (a wall's top, a ledge) is snow.
	col = mix(col, frost_color.rgb, smoothstep(0.55, 0.8, n.y));
	ALBEDO = col;
	ROUGHNESS = mix(0.86, 0.6, streak);
	SPECULAR = 0.25;
}
