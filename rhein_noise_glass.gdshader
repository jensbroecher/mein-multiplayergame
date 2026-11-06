// A noise wall's clear acrylic panels (RheinBridgeKit.gd, key "glasswall"): faintly tinted, glossy, see-through, with
// vertical bird-strike stripes (2cm wide every 10cm, life size) from the UVs (game metres: u along the wall, v up). The
// stripes fade to their average share once they get smaller than a pixel. The vertex colour is the tint; its alpha the
// clear glass's opacity.
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

uniform float stripe_pitch = 0.16;
uniform float stripe_w = 0.032;

void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float fw = fwidth(UV.x);
	float x = (fract(UV.x / stripe_pitch) - 0.5) * stripe_pitch;
	float sharp = 1.0 - smoothstep(stripe_w * 0.5 - fw, stripe_w * 0.5 + fw, abs(x));
	float avg = stripe_w / stripe_pitch;
	float s = mix(sharp, avg, smoothstep(stripe_pitch * 0.2, stripe_pitch * 0.6, fw));
	ALBEDO = mix(tint * 0.6, vec3(0.02), s);
	ALPHA = mix(COLOR.a, 0.92, s);
	ROUGHNESS = mix(0.04, 0.6, s);
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
