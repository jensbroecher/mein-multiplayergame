shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// The light an item box throws on the ground under it (a quad ItemBox.gd lays on the ground, UV 0..1
// across it): a soft pool, and a ring of dashes turning slowly round it. While the box is away
// (`present` 0) the pool is out and the ring fills round as its return nears (`charge` 0 -> 1). `pop`
// (0 -> 1) sends a shock ring out as the box bursts.

instance uniform float phase = 0.0;
instance uniform float pop = 1.0;
instance uniform float present = 1.0;
instance uniform float charge = 0.0;
uniform vec3 glow_colour : source_color = vec3(0.22, 0.82, 1.0);
uniform float strength = 1.0;
uniform float gain = 1.0;          // 1 / the level's exposure (ItemBox.gd)
uniform float fade_begin = 130.0;
uniform float fade_end = 200.0;

float ring(float r, float at, float w) {
	float aa = fwidth(r) * 1.2;
	return 1.0 - smoothstep(w - aa, w + aa, abs(r - at));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x) / 6.2832 + 0.5;
	float pulse = 0.85 + 0.15 * sin(TIME * 2.2 + phase * 6.2832);
	float pool = exp(-r * r * 5.0) * (1.0 - smoothstep(0.8, 1.0, r));
	float df = fract(ang * 24.0 - TIME * 0.5);
	float daa = fwidth(ang * 24.0);
	float dashes = smoothstep(0.2 - daa, 0.2 + daa, df) * (1.0 - smoothstep(0.7 - daa, 0.7 + daa, df));
	float rings = ring(r, 0.7, 0.02) * dashes + ring(r, 0.78, 0.006) * 0.6;
	float filled = mix(0.12, 1.0, step(ang, charge));
	float shock = ring(r, mix(0.25, 0.97, pop), mix(0.07, 0.015, pop)) * (1.0 - pop) * (1.0 - pop);
	float dist_fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	float light = pool * 0.6 * present * pulse + rings * mix(filled * 0.8, pulse * 0.25, present) + shock * 2.5;
	ALBEDO = glow_colour * light * strength * gain * dist_fade;
}
