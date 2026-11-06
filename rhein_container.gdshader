// Containers on Rhine ships (RheinShipKit.gd's "container"): UV is in life metres on each face (u along it, v up it; on
// the roof u along, v across), and u is offset by 100 on the door end, 200 on the closed end, 300 on the roof. The vertex
// colour is the paint (sRGB), its alpha a seed per box (a flat varying: a hash of an interpolated value speckles on
// some GPUs). Drawn here: the walls' trapezoid corrugation (by the shading, no normal map), the doors' seam and panels,
// a band of made-up lettering on some sides, rust streaks from the top rail, grime toward the bottom.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float pitch = 0.278;

varying flat float seed;
varying vec3 lnrm;

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
	seed = COLOR.a;
	lnrm = NORMAL;
}

void fragment() {
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	float face = floor(UV.x / 100.0 + 0.001);
	vec2 uv = vec2(UV.x - face * 100.0, UV.y);
	float fw = max(fwidth(uv.x), fwidth(uv.y));
	float detail = 1.0 - smoothstep(0.03, 0.12, fw);
	vec3 col = paint;
	if (face < 0.5 || (face > 1.5 && face < 2.5)) {
		// Corrugation: crests lighter, the slopes either side shaded one lighter one darker.
		float f = fract(uv.x / pitch);
		float shade = (f < 0.35) ? 1.0 : ((f < 0.5) ? 0.82 : ((f < 0.85) ? 0.93 : 1.06));
		col *= mix(0.96, shade, detail);
	} else if (face < 1.5) {
		// The doors: two leaves with three pressed panels each, a seam down the middle.
		float leaf_x = fract(uv.x / 1.22);
		float panel = fract(uv.y / 0.86);
		float press = smoothstep(0.08, 0.14, leaf_x) * (1.0 - smoothstep(0.86, 0.92, leaf_x)) * smoothstep(0.08, 0.14, panel) * (1.0 - smoothstep(0.86, 0.92, panel));
		col *= mix(0.97, 0.9 + 0.12 * press, detail);
		float seam = 1.0 - smoothstep(0.0, 0.025, abs(uv.x - 1.22));
		col *= 1.0 - 0.6 * seam * detail;
	} else {
		col *= 0.88 + 0.12 * vnoise(uv * 1.3 + seed * 20.0);
	}
	// A line's lettering on about half the sides: a band of letter blocks, pale or dark.
	if (face < 0.5 && hash12(vec2(seed * 91.0, 3.0)) > 0.45) {
		float lx = uv.x - 1.0;
		float ly = uv.y - 1.6;
		float word_len = 3.0 + 2.6 * hash12(vec2(seed * 17.0, 1.0));
		float in_word = step(0.0, lx) * step(lx, word_len) * step(abs(ly), 0.28);
		float letter = floor(lx / 0.44);
		float gap = step(0.09, fract(lx / 0.44));
		float shape = step(0.3, vnoise(vec2(letter * 3.7 + seed * 11.0, floor((ly + 0.28) / 0.14))));
		vec3 ink = hash12(vec2(seed * 7.0, 5.0)) > 0.5 ? vec3(0.9, 0.9, 0.86) : vec3(0.05, 0.05, 0.06);
		col = mix(col, ink, in_word * gap * shape * detail * 0.92);
	}
	// Weather.
	float n = vnoise(vec2(uv.x * 3.0, uv.y * 0.35) + seed * 37.0);
	float streak = smoothstep(0.62, 0.9, vnoise(vec2(uv.x * 7.0 + seed * 13.0, 0.5))) * smoothstep(0.4, 2.6, uv.y) * (0.35 + 0.65 * n);
	float rustiness = 0.2 + 0.7 * hash12(vec2(seed * 29.0, 7.0));
	vec3 rust = vec3(0.30, 0.12, 0.05);
	col = mix(col, rust, streak * rustiness * 0.5 * detail);
	float patch = smoothstep(0.72, 0.92, vnoise(uv * 2.1 + seed * 53.0)) * rustiness;
	col = mix(col, rust * 0.8, patch * 0.55);
	if (face < 2.5) {
		col = mix(col, col * vec3(0.55, 0.5, 0.45), (1.0 - smoothstep(0.0, 0.9, uv.y)) * 0.4);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.85, patch);
	METALLIC = mix(0.2, 0.05, patch);
}
