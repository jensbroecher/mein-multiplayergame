shader_type spatial;
render_mode cull_back;

// The glacier tongue in Glacier Highway's north wall (regenerate_glacier_dressing.gd, _build_glacier).
// UV.x runs across the ice (-1 at its left margin, 1 at its right), UV.y up the glacier in metres from the snout.
// COLOR.r is how broken the ice is (1 in the icefall, where the wall steepens), COLOR.g how much old snow lies on it (the
// firn up high, none on the tongue).
//
// Bare glacier ice is pale: grey-white where it is weathered, blue only in its cracks and where it is thick and clean.
// Crevasses are the dark blue slots across it (bowing upstream in the middle, as the faster centre drags them), broken
// into lengths, widest in the icefall; below it the ogives (dirt bands) arc down the tongue, and the margins carry the
// lateral moraines' rubble. Every pattern fades to its average by the pixel's size in metres, or it crawls at distance.

uniform vec3 ice_light : source_color = vec3(0.80, 0.86, 0.91);
uniform vec3 ice_blue : source_color = vec3(0.42, 0.62, 0.78);
uniform vec3 crevasse_col : source_color = vec3(0.10, 0.22, 0.36);
uniform vec3 dirt : source_color = vec3(0.27, 0.26, 0.25);
uniform vec3 snow_col : source_color = vec3(0.90, 0.92, 0.96);
uniform float crevasse_pitch = 7.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float u = UV.x;
	float s = UV.y;
	float fw = length(fwidth(w_pos));
	float breakup = fbm(w_pos.xz * 0.03);

	// The ice: weathered grey-white, bluer in long streaks of cleaner ice along the flow.
	float streak = fbm(vec2(u * 9.0, s * 0.012));
	vec3 ice = mix(ice_light, ice_blue, 0.18 + 0.45 * smoothstep(0.45, 0.8, streak));
	ice *= 0.92 + 0.12 * vnoise(w_pos.xz * 0.25);

	// Ogives below the icefall: darker bands arcing down the tongue, one a year's flow apart.
	float og = 0.5 + 0.5 * sin((s + 34.0 * u * u) * (6.2832 / 40.0));
	float og_fade = 1.0 - smoothstep(4.0, 12.0, fw);
	ice = mix(ice, ice * 0.78 + dirt * 0.12, smoothstep(0.62, 0.95, og) * 0.55 * (1.0 - COLOR.r) * og_fade);

	// A medial moraine: a dark stripe of rubble down the tongue from the icefall's foot, where two ice streams meet.
	float med = 1.0 - smoothstep(0.02, 0.07, abs(u - 0.28 - (vnoise(vec2(s * 0.01, 3.0)) - 0.5) * 0.12));
	med *= (1.0 - smoothstep(120.0, 160.0, s)) * (0.6 + 0.4 * vnoise(w_pos.xz * 0.4));
	ice = mix(ice, dirt * 0.9, med * 0.8 * (1.0 - smoothstep(3.0, 9.0, fw) * 0.5));
	// The snout: dirty, the ice there full of the rock it has scraped up.
	ice = mix(ice, dirt * (0.85 + 0.3 * vnoise(w_pos.xz * 0.7)), (1.0 - smoothstep(8.0, 30.0, s + (vnoise(vec2(u * 7.0, 1.0)) - 0.5) * 14.0)) * 0.75);
	// The margins: the lateral moraines' rubble, ragged.
	float m = smoothstep(0.66, 0.95, abs(u) + (fbm(w_pos.xz * 0.07) - 0.5) * 0.3);
	vec3 rubble = dirt * (0.75 + 0.5 * vnoise(w_pos.xz * 0.9));
	ice = mix(ice, rubble, m);

	// Crevasses: transverse slots bowing upstream at the centre, broken into lengths, wider in the icefall.
	float cs = s / crevasse_pitch - u * u * 1.4 + (vnoise(vec2(u * 5.0, s * 0.04)) - 0.5) * 0.7;
	float id = floor(cs);
	float f = abs(fract(cs) - 0.5);
	float w = (0.01 + 0.06 * COLOR.r) * (0.4 + 0.9 * hash21(vec2(id, floor(u * 4.0 + 7.0))));
	float aa = fw / crevasse_pitch;
	float crev = 1.0 - smoothstep(w, w + aa + 0.002, f);
	crev *= step(0.3, vnoise(vec2(id * 3.1, u * 3.5)));
	// In the icefall, and along the margins (where the ice drags on the walls); the tongue between is whole.
	crev *= (1.0 - m) * max(COLOR.r, smoothstep(0.42, 0.62, abs(u)) * 0.7);
	// Too fine to resolve: the slots' share of the surface, as an even darkening.
	float far_share = (w * 2.0) * 0.35 * (1.0 - m);
	crev = mix(crev, far_share, smoothstep(0.6, 2.5, fw));
	vec3 col = mix(ice, crevasse_col, crev);

	// Old snow: the firn up high, and drifts lying in hollows lower down.
	float snow = smoothstep(0.3, 0.75, COLOR.g + (breakup - 0.5) * 0.6);
	snow = max(snow, smoothstep(0.72, 0.9, breakup) * 0.5 * (1.0 - m));
	col = mix(col, snow_col * (0.93 + 0.07 * breakup), snow * (1.0 - crev * 0.7));

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.38, 0.92, m), 0.78, snow);
	SPECULAR = mix(mix(0.55, 0.3, m), 0.35, snow);
}
