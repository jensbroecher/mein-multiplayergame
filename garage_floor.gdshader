// garage_floor.gdshader: the garage's (Garage.gd) polished concrete floor, laid in square slabs by
// world position (`slab` metres), mottled by two octaves of value noise, glossy so the studio sky and the
// lights shine in it. The seams fade to their average as they get thinner than a pixel.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.21, 0.215, 0.225);
uniform float slab = 3.0;
uniform float seam_width = 0.008;
uniform float gloss = 0.14;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = w_pos.xz;
	float fw = length(fwidth(p));
	float n = vnoise(p * 0.45) * 0.65 + vnoise(p * 2.3) * 0.35;
	// Each slab a shade apart, as if poured on different days.
	float tone = hash(floor(p / slab)) - 0.5;
	vec3 col = base_color * (0.86 + 0.24 * n + 0.07 * tone);
	vec2 g = abs(fract(p / slab) - 0.5) * slab;
	float d = slab * 0.5 - max(g.x, g.y);
	float seam = (1.0 - smoothstep(seam_width, seam_width + fw, d)) * (1.0 - smoothstep(0.02, 0.08, fw));
	col *= 1.0 - 0.5 * seam;
	ALBEDO = col;
	ROUGHNESS = clamp(gloss + 0.12 * n + 0.5 * seam, 0.0, 1.0);
	SPECULAR = 0.5;
}
