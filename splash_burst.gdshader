shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// splash_burst.gdshader: the light behind the logo: a glow, orange at its heart and blue toward the
// edge, with rays that turn slowly. Added to what is behind it, on a quad standing across the view.

uniform vec3 inner_color : source_color = vec3(1.0, 0.72, 0.32);
uniform vec3 outer_color : source_color = vec3(1.0, 0.32, 0.06);
uniform float rays = 17.0;
uniform float spin = 0.012;
// 0 = dark, 1 = shown: the script fades it in.
uniform float strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	float wob = 1.6 * sin(a * 3.0 + TIME * 0.11);
	float ray = pow(0.5 + 0.5 * sin(a * rays + TIME * spin * 6.2832 + wob), 4.0);
	float fall = exp(-r * 4.4);
	float mask = smoothstep(1.0, 0.35, r);
	vec3 col = mix(inner_color, outer_color, smoothstep(0.0, 0.55, r));
	float k = (fall * 0.40 + ray * fall * 1.1 + ray * 0.025) * mask * strength;
	ALBEDO = col * k;
	ALPHA = 1.0;
}
