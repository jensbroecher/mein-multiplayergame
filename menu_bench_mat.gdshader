// The Options tile's anti-static mat (MenuPropKit.build_bench): dark blue-grey rubber with a fine grid every
// 2cm and a stronger one every 10cm in the tile's colour, a worn sheen, all in UV metres of a 1.3 x 0.8m plane.
shader_type spatial;

uniform vec4 line : source_color = vec4(0.15, 0.75, 0.92, 1.0);
uniform vec2 size = vec2(1.3, 0.8);

float grid(vec2 p, float step_m, float w) {
	vec2 g = abs(fract(p / step_m + 0.5) - 0.5) * step_m;
	vec2 fw = fwidth(p);
	vec2 a = 1.0 - smoothstep(vec2(w) - fw, vec2(w) + fw, g);
	// Fade a grid out where its lines come closer than a few pixels.
	float fade = 1.0 - smoothstep(0.15, 0.4, max(fw.x, fw.y) / step_m);
	return max(a.x, a.y) * fade;
}

void fragment() {
	vec2 p = UV * size;
	vec3 col = vec3(0.07, 0.085, 0.1);
	col = mix(col, vec3(0.16, 0.18, 0.21), grid(p, 0.02, 0.0004) * 0.6);
	col = mix(col, line.rgb * 0.55, grid(p, 0.1, 0.0008) * 0.75);
	// A border line 2cm in from the edge.
	vec2 e = min(p, size - p);
	float border = 1.0 - smoothstep(0.0, 0.002, abs(min(e.x, e.y) - 0.02));
	col = mix(col, line.rgb * 0.7, border);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
}
