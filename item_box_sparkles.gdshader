shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Sparkles drifting round an item box, all drawn by the shader from one mesh of quads (ItemBox.gd): no
// particle system. Every vertex of a quad carries the sparkle's seeds in COLOR.rgb and its colour in
// COLOR.a, and its corner in UV. Each sparkle rises round the box on an orbit, twinkling, and takes a
// new orbit every life. The quad faces the camera. `pop` (0 -> 1) flings them all outward as the box
// bursts, `build` grows them in.

instance uniform float phase = 0.0;
instance uniform float pop = 0.0;
instance uniform float build = 1.0;
uniform float brightness = 1.6;
uniform float gain = 1.0;          // 1 / the level's exposure (ItemBox.gd)

varying vec2 corner;
varying vec3 tint;
varying float fade;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float s1 = COLOR.r;
	float s2 = COLOR.g;
	float s3 = COLOR.b;
	corner = UV * 2.0 - 1.0;
	float span = 2.2 + s1 * 1.8;
	float t = TIME + phase * 13.0 + s2 * 40.0;
	float life = fract(t / span);
	float fresh = hash(floor(t / span) + s3 * 91.0);
	float turn = (s2 > 0.5 ? 1.0 : -1.0) * (0.35 + s1 * 0.5);
	float ang = (s3 + fresh) * 6.2832 + TIME * turn;
	float rad = mix(0.8, 1.5, fract(s1 * 7.0 + fresh));
	float y = mix(-0.95, 1.05, life) + 0.08 * sin(TIME * 3.0 + s2 * 30.0);
	vec3 p = vec3(cos(ang) * rad, y, sin(ang) * rad);
	p += normalize(p + vec3(0.0, 0.4, 0.0)) * (1.0 - (1.0 - pop) * (1.0 - pop)) * (2.5 + s1 * 3.0);
	float size = mix(0.05, 0.1, s2) * sin(life * 3.1416) * (0.65 + 0.35 * sin(TIME * 9.0 + s3 * 50.0));
	size *= build * (1.0 + pop * 1.5);
	fade = (1.0 - pop * pop) * (1.0 + pop * 2.0);
	int k = int(COLOR.a * 5.0);
	tint = k == 0 ? vec3(0.2, 0.9, 1.0) : k == 1 ? vec3(1.0, 0.25, 0.75) : k == 2 ? vec3(1.0, 0.75, 0.15)
			: k == 3 ? vec3(0.6, 0.35, 1.0) : vec3(1.0);
	vec4 vc = MODELVIEW_MATRIX * vec4(p, 1.0);
	vc.xy += corner * size * 2.5;
	POSITION = PROJECTION_MATRIX * vc;
}

void fragment() {
	vec2 c = corner;
	float r2 = dot(c, c);
	float core = exp(-r2 * 30.0);
	float halo = exp(-r2 * 7.0) * 0.3;
	float star = exp(-abs(c.x) * 26.0) * exp(-abs(c.y) * 3.0) + exp(-abs(c.y) * 26.0) * exp(-abs(c.x) * 3.0);
	ALBEDO = tint * (core * 1.2 + halo * 1.5 + star * 0.5) * brightness * gain * fade;
}
