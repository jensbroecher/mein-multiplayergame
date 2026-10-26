shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The Lakeside Course's banked board track (regenerate_lakeside.gd, _build_banked_turn): narrow planks
// laid along the lap on joists, nailed down, weathered, a dark band of rubber along the low racing line,
// and painted bands across it. UV.x runs along the lap, UV.y across from the bank's inner edge, both in
// world metres. COLOR.rgb is the paint and COLOR.a how much of it there is (0 bare wood).
// Nothing here is mipmapped, so each pattern fades to its average by the pixel's size in metres (`fw`):
// drawn sharp, the seams and nail heads shimmered across the far side of the bend.

uniform float plank_width = 0.16;
uniform float plank_length = 6.4;
uniform float joist_spacing = 1.9;
uniform float rubber_lat = 3.8;
uniform float rubber_width = 4.5;
uniform vec3 wood_color : source_color = vec3(0.62, 0.46, 0.30);
uniform vec3 rubber_color : source_color = vec3(0.10, 0.09, 0.08);

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

// How much of a line `w` wide is in a pixel `fw` across at distance `d` from its middle, faded to its
// share of the area once the pixel is wider than the line.
float line_cover(float d, float w, float fw) {
	float aa = max(fw, 1e-4);
	float c = 1.0 - smoothstep(w * 0.5 - aa * 0.5, w * 0.5 + aa * 0.5, d);
	return mix(c, w / max(w, aa), smoothstep(w, w * 4.0, fw));
}

void fragment() {
	vec2 q = UV;
	float fw = length(fwidth(q));
	float along = q.x;
	float across = q.y;

	// Planks: each row has its butt joints somewhere else.
	float row = floor(across / plank_width);
	float fa = fract(across / plank_width);
	float shift = hash12(vec2(row, 3.7)) * plank_length;
	float seg = floor((along + shift) / plank_length);
	float fs = fract((along + shift) / plank_length);
	float r1 = hash12(vec2(row, seg));
	float r2 = hash12(vec2(seg * 1.3, row + 7.1));
	float d_side = min(fa, 1.0 - fa) * plank_width;
	float d_end = min(fs, 1.0 - fs) * plank_length;

	// Grain streaks along the plank and a broad tone per plank, faded with distance.
	float detail = 1.0 - smoothstep(0.01, 0.05, fw);
	float grain = vnoise(vec2(across * 60.0 + r1 * 40.0, along * 1.2)) * 0.6
			+ vnoise(vec2(across * 14.0 + r2 * 20.0, along * 0.35)) * 0.4;
	float tone = mix(1.0, 0.80 + 0.36 * r1, 1.0 - smoothstep(plank_width, plank_width * 6.0, fw));
	tone += (grain - 0.5) * 0.35 * detail;
	vec3 wood = wood_color * tone;

	// Weathering: silvered patches, darker toward the low edge where the rain runs.
	float silver = vnoise(q * vec2(0.35, 0.8) + 4.0) * 0.6 + vnoise(q * 1.7 + 9.0) * 0.4;
	wood = mix(wood, vec3(0.42, 0.40, 0.37) * (0.85 + 0.3 * r2), smoothstep(0.45, 0.85, silver) * 0.3);
	wood *= mix(0.86, 1.0, smoothstep(0.0, 2.5, across));

	// Paint, worn through along the plank edges and where the tyres run.
	float paint = COLOR.a;
	vec3 col = wood;
	float rough = 0.82;
	if (paint > 0.01) {
		vec3 pc = pow(COLOR.rgb, vec3(2.2));
		float wear = smoothstep(0.62, 0.9, vnoise(q * vec2(1.4, 9.0) + 2.0) + (1.0 - smoothstep(0.0, 0.012, d_side)) * 0.3);
		col = mix(wood, pc * (0.92 + 0.12 * r1), paint * (1.0 - wear * 0.75));
		rough = mix(rough, 0.62, paint);
	}

	// Rubber on the racing line: a broad dark band, streaky along the lap.
	float band = 1.0 - smoothstep(0.0, rubber_width * 0.5, abs(across - rubber_lat));
	float streak = vnoise(vec2(across * 3.0, along * 0.08)) * 0.6 + vnoise(vec2(across * 0.7, along * 0.02)) * 0.4;
	float rubber = band * (0.35 + 0.5 * streak);
	col = mix(col, rubber_color, rubber * 0.55);
	rough = mix(rough, 0.7, rubber * 0.5);

	// The gaps between the planks, the butt joints, and two nails into every joist.
	float gap = max(line_cover(d_side, 0.012, fw), line_cover(d_end, 0.010, fw));
	col *= 1.0 - 0.6 * gap;
	float jd = abs(fract(along / joist_spacing + 0.5) - 0.5) * joist_spacing;
	float nail_x = min(abs(fa - 0.25), abs(fa - 0.75)) * plank_width;
	float nail = line_cover(length(vec2(jd, nail_x)), 0.022, fw * 1.5);
	col = mix(col, vec3(0.16, 0.15, 0.14), nail * 0.8);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
