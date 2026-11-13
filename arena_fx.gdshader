shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// The arena football's light effects (ArenaFx.gd), all additive, each a plain mesh grown and faded by the script
// through its instance uniforms:
//   mode 0, a shell: a sphere lit round its rim (the ball bursting, the pop as it appears).
//   mode 1, a beam: an open cylinder, brightest at its foot, bands of light running down it (the kick-off's column).
//   mode 2, a ring: a flat quad with a ring that runs outward from its middle as `phase` goes 0..1, a faint disc
//           inside it (on the pitch under a kick-off, on the goal line after a goal).

uniform int mode = 0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float phase = 0.0;

void fragment() {
	float a = 0.0;
	if (mode == 0) {
		float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
		a = pow(f, 2.2) + 0.08;
	} else if (mode == 1) {
		float f = abs(dot(normalize(NORMAL), normalize(VIEW)));
		// A CylinderMesh's side runs v 0 (top) to 0.5 (foot).
		float v = clamp(UV.y * 2.0, 0.0, 1.0);
		a = f * f * mix(0.12, 1.0, v * v);
		a *= 0.72 + 0.28 * sin(v * 34.0 - phase * 26.0);
	} else {
		float r = length(UV - 0.5) * 2.0;
		float edge = max(phase, 0.02);
		a = smoothstep(edge - 0.2, edge, r) * (1.0 - smoothstep(edge, edge + 0.03, r));
		a += 0.22 * (1.0 - smoothstep(0.0, edge, r)) * (1.0 - phase);
		a *= 1.0 - smoothstep(0.94, 1.0, r);
	}
	ALBEDO = tint.rgb * tint.a;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
