shader_type spatial;
// The city's name in gold on Marina Nights (regenerate_marina_nights.gd, _build_raihana): polished gold that the
// scene's lights catch, plus what makes it read at night from anywhere on the lap (the uplights' real light fades past
// 150m): a glow as if uplit, brightest at the letters' feet (by the mesh's own height, y0 to y1), and a made-up
// reflection of the night (the city's warm glow along the horizon, a deep blue sky above, the dark sea below) by the
// reflected view ray, stronger at grazing angles, so fronts, sides and tops of the strokes each catch their own.

uniform vec3 gold : source_color = vec3(1.0, 0.75, 0.32);
uniform float y0 = -1.5;
uniform float y1 = 1.8;
uniform float wash_foot = 0.55;
uniform float wash_top = 0.10;
uniform float reflect_strength = 0.85;
uniform float energy = 1.0;

varying float hy;

void vertex() {
	hy = clamp((VERTEX.y - y0) / max(y1 - y0, 0.001), 0.0, 1.0);
}

void fragment() {
	ALBEDO = gold;
	METALLIC = 1.0;
	ROUGHNESS = 0.3;
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	vec3 glow = vec3(1.0, 0.60, 0.30);
	vec3 sky = mix(glow, vec3(0.05, 0.07, 0.16), smoothstep(-0.02, 0.45, r.y));
	sky = mix(vec3(0.03, 0.035, 0.05), sky, smoothstep(-0.22, 0.0, r.y));
	float fres = 0.55 + 0.45 * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	float wash = mix(wash_foot, wash_top, smoothstep(0.0, 1.0, hy));
	EMISSION = gold * (sky * fres * reflect_strength + vec3(wash)) * energy;
}
