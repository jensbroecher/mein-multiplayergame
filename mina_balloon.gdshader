shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Hot air balloons' envelopes (MinaKit.gd): the panel's colour in the vertex colour (sRGB); UV.x round the envelope
// in gores (one a unit), UV.y up it, 0 at the mouth and 1 at the crown. Seams between the gores and the horizontal
// load tapes, a soft sheen, and the low sun shining through the nylon. `burn` (an instance uniform, 0..1, set by
// BalloonFiesta.gd while the burner fires) lights the envelope from inside, strongest at the mouth.

instance uniform float burn = 0.0;
uniform vec4 flame_color : source_color = vec4(1.0, 0.62, 0.22, 1.0);

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float seam_u = abs(fract(UV.x) - 0.5) * 2.0;
	float lw = fwidth(UV.x) * 1.2 + 0.004;
	float seam = smoothstep(1.0 - lw * 2.0, 1.0, seam_u);
	float tape = 1.0 - smoothstep(0.0, fwidth(UV.y * 9.0) * 1.5 + 0.01, abs(fract(UV.y * 9.0) - 0.5) * 2.0 - 0.94);
	tape = clamp(1.0 - tape, 0.0, 1.0);
	base *= 1.0 - 0.18 * max(seam, tape * 0.6);
	// The inside of the envelope is in its own shade.
	if (!FRONT_FACING) {
		base *= 0.55;
	}
	ALBEDO = base;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = base * 0.65;
	float glow = burn * (1.0 - smoothstep(0.0, 0.75, UV.y)) * (FRONT_FACING ? 0.35 : 1.0);
	EMISSION = flame_color.rgb * base * 3.0 * glow + flame_color.rgb * glow * 0.15;
}
