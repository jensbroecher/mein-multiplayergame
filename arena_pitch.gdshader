shader_type spatial;
render_mode cull_back;

// The Hex Bowl's pitch (regenerate_arena_hexbowl.gd): artificial turf mown in bands, the lines in world space: the
// hexagon's touchline `inradius` - 1.2 in from the walls, the centre circle and spot, a line from the centre circle
// toward each goal and an arc round each goal's mouth.

uniform float inradius = 48.0;
uniform vec3 turf_a : source_color = vec3(0.13, 0.42, 0.16);
uniform vec3 turf_b : source_color = vec3(0.16, 0.5, 0.2);
uniform vec3 line_col : source_color = vec3(0.92, 0.94, 0.95);
uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float line_mask(float d, float half_w) {
	float fw = max(fwidth(d), 1e-4);
	return 1.0 - smoothstep(half_w - fw, half_w + fw, abs(d));
}

void fragment() {
	vec2 p = w_pos.xz;
	float band = mod(floor((p.x * 0.5 + p.y * 0.866) / 5.0), 2.0);
	vec3 col = mix(turf_a, turf_b, band);
	col *= 0.85 + 0.3 * texture(grain, p / 3.0).g;
	float lines = 0.0;
	float r = length(p);
	lines = max(lines, line_mask(r - 9.0, 0.14));
	lines = max(lines, 1.0 - smoothstep(0.35, 0.5, r));
	float hexd = 0.0;
	for (int k = 0; k < 6; k++) {
		float a = float(k) * 1.0471976;
		vec2 n = vec2(cos(a), sin(a));
		float along = dot(p, n);
		hexd = max(hexd, along);
		float across = dot(p, vec2(-n.y, n.x));
		if (along > 9.0 && along < inradius - 15.0) {
			lines = max(lines, line_mask(across, 0.12));
		}
		vec2 mouth = n * inradius;
		float dm = length(p - mouth);
		if (along < inradius - 1.2) {
			lines = max(lines, line_mask(dm - 14.0, 0.14));
		}
	}
	lines = max(lines, line_mask(hexd - (inradius - 1.2), 0.16));
	col = mix(col, line_col, lines * 0.9);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.6, lines);
	SPECULAR = 0.3;
}
