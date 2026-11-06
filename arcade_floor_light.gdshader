// The light of Qaysariyyat al-Manara's lattice vault laid on its floor and the road through it
// (regenerate_marina_nights.gd, _build_arcade): soft eight-pointed stars of warm light, as the lanterns over the
// vault throw the screen's pattern down, added over whatever lies under it. A ribbon laid just over the road, its
// vertices pulled toward the eye (as the skid marks' and the road's own, but further) so it wins the depth test against
// the road at any distance. UV is world metres; COLOR.a fades it out toward the hall's ends.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled, skip_vertex_transform, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.70, 0.36);
uniform float strength = 0.32;
uniform float cell = 3.6;
uniform float fade_far = 220.0;

varying float v_fade;

float sd_star8(vec2 p, float s) {
	vec2 q = abs(p);
	float a = max(q.x, q.y) - s;
	vec2 r = vec2(p.x - p.y, p.x + p.y) * 0.70710678;
	vec2 rq = abs(r);
	float b = max(rq.x, rq.y) - s;
	return min(a, b);
}

void vertex() {
	vec3 view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(view);
	view *= max(d - (0.06 + d * 0.002), 0.0) / max(d, 1e-4);
	VERTEX = view;
	NORMAL = (MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	v_fade = COLOR.a * (1.0 - smoothstep(fade_far * 0.6, fade_far, d));
}

void fragment() {
	vec2 uv = UV / cell;
	vec2 p = fract(uv) - 0.5;
	// Stars where the screen's holes let the light through, blurred as a pattern thrown 20m down is.
	float star = 1.0 - smoothstep(-0.06, 0.08, sd_star8(p, 0.30));
	float ring = 1.0 - smoothstep(0.0, 0.07, abs(length(p) - 0.43));
	float l = max(star * 0.85, ring * 0.35);
	// Larger, softer pools under each lantern row.
	float pool = 0.35 + 0.65 * (0.5 + 0.5 * cos(UV.y * 6.2831853 / 10.0));
	ALBEDO = tint * strength * l * pool * v_fade;
}
