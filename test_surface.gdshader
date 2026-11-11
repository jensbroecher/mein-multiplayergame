shader_type spatial;
render_mode cull_back, diffuse_burley;

// The Test Track's surface strip (regenerate_test_track.gd): a patch of one surface laid over the road, one material per
// kind. UV is in metres: x along the road, y across it (0 on the centreline).
//   0 sand  1 snow  2 ice  3 mud  4 grass  5 gravel  6 dirt  7 wood (planks across)  8 cobbles (rock)

uniform int kind = 0;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wood_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cobble_tex : source_color, filter_linear_mipmap, repeat_enable;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.1) * 0.27 + vnoise(p * 4.3) * 0.15 + vnoise(p * 8.7) * 0.08;
}

void fragment() {
	vec2 p = UV;
	vec3 col = vec3(0.5);
	float rough = 0.9;
	float spec = 0.4;
	if (kind == 0) {
		col = texture(sand_tex, p / 3.0).rgb * vec3(1.05, 1.0, 0.92);
		col *= 0.9 + 0.2 * fbm(p * 0.4);
		// Ripples across the road.
		col *= 0.94 + 0.06 * sin(p.x * 2.6 + fbm(p * 0.7) * 4.0);
	} else if (kind == 1) {
		float n = fbm(p * 0.6);
		col = mix(vec3(0.70, 0.75, 0.82), vec3(0.86, 0.88, 0.92), n);
		// Two packed wheel tracks, a little greyer and smoother.
		float track = smoothstep(1.2, 0.4, abs(abs(p.y) - 2.6));
		col = mix(col, col * vec3(0.86, 0.88, 0.92), track * 0.6);
		rough = mix(0.85, 0.6, track);
		spec = 0.5;
		col += step(0.985, hash21(floor(p * 40.0))) * 0.25;
	} else if (kind == 2) {
		float n = fbm(p * 0.35);
		// Blue-grey glare ice: brighter, it mirrored the sky and read as white as the snow before it.
		col = mix(vec3(0.24, 0.40, 0.52), vec3(0.42, 0.58, 0.68), n);
		// White cracks and frost.
		float c = abs(vnoise(p * 0.9) - 0.5);
		col = mix(col, vec3(0.85, 0.90, 0.95), (1.0 - smoothstep(0.0, 0.03, c)) * 0.7);
		col = mix(col, vec3(0.80, 0.86, 0.92), smoothstep(0.55, 0.8, fbm(p * 1.7)) * 0.35);
		rough = 0.18 + 0.25 * smoothstep(0.55, 0.8, fbm(p * 1.7));
		spec = 0.45;
	} else if (kind == 3) {
		col = texture(dirt_tex, p / 2.5).rgb * vec3(0.55, 0.45, 0.36);
		float wet = smoothstep(0.45, 0.65, fbm(p * 0.3));
		col = mix(col, col * 0.6, wet);
		rough = mix(0.75, 0.12, wet);
		spec = mix(0.3, 0.7, wet);
		// Ruts.
		col *= 1.0 - 0.25 * smoothstep(0.9, 0.2, abs(abs(p.y) - 2.6));
	} else if (kind == 4) {
		col = texture(grass_tex, p / 3.0).rgb;
		col *= 0.85 + 0.25 * fbm(p * 0.5);
		col = mix(col, col * vec3(0.8, 0.75, 0.55), smoothstep(0.9, 0.3, abs(abs(p.y) - 2.6)) * 0.5);
	} else if (kind == 5) {
		col = texture(gravel_tex, p / 2.0).rgb * vec3(1.35, 1.3, 1.25);
		col *= 0.9 + 0.2 * fbm(p * 0.6);
	} else if (kind == 6) {
		col = texture(dirt_tex, p / 2.5).rgb * vec3(0.95, 0.85, 0.72);
		col *= 0.88 + 0.24 * fbm(p * 0.4);
	} else if (kind == 7) {
		// Planks across the road, 0.3m wide, their ends staggered.
		vec2 q = vec2(p.y / 2.4, p.x / 0.3);
		float row = floor(q.y);
		q.x += hash21(vec2(row, 3.0)) * 3.0;
		col = texture(wood_tex, vec2(fract(q.x), fract(q.y)) * vec2(1.0, 0.25) + vec2(0.0, hash21(vec2(row, 7.0)))).rgb;
		col *= 0.8 + 0.35 * hash21(vec2(row, floor(q.x)));
		float seam = min(fract(q.y), 1.0 - fract(q.y));
		col *= mix(0.45, 1.0, smoothstep(0.0, 0.07, seam));
		float butt = min(fract(q.x), 1.0 - fract(q.x)) * 2.4 / 0.3;
		col *= mix(0.5, 1.0, smoothstep(0.0, 0.25, butt));
		rough = 0.7;
	} else {
		col = texture(cobble_tex, p / 1.6).rgb;
		rough = 0.8;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
