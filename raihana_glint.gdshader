shader_type spatial;
// The gold word's glint on the sea before it (regenerate_marina_nights.gd, _build_raihana): a quad on the water, UV.x
// across the word, UV.y away from its plinth, drawn additively as long thin streaks of glitter that drift, fading with
// distance from the plinth and toward the word's ends. Pulled toward the eye along its own ray (same pixels), so a
// quad a few centimetres over the sea wins the depth test at any distance.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.70, 0.34);
uniform float strength = 0.6;

varying vec2 uv;

void vertex() {
	uv = UV;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vp.xyz *= 0.995;
	POSITION = PROJECTION_MATRIX * vp;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// Long thin highlights running toward the viewer (along v), broken up across (u), drifting slowly: value noise
	// stretched 15 times along v (a hash per column and ripple row had drawn a grid of dashes).
	vec2 q = vec2(uv.x * 110.0, uv.y * 7.0 - TIME * 0.35);
	float n = vnoise(q) * 0.65 + vnoise(q * vec2(2.3, 1.9) + vec2(5.2, 1.3)) * 0.35;
	float streak = smoothstep(0.55, 0.86, n);
	float across = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
	float fade = pow(1.0 - uv.y, 2.5) * smoothstep(0.0, 0.05, uv.y);
	ALBEDO = color * strength * streak * fade * across;
}
