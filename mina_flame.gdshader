shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

// A balloon's burner flame (MinaKit.gd): a cone whose UV.y runs from the burner (0) to its tip (1). `burn` (instance
// uniform, BalloonFiesta.gd) is how hard it fires; at 0 it is gone.

instance uniform float burn = 0.0;
uniform vec4 core : source_color = vec4(1.0, 0.86, 0.5, 1.0);
uniform vec4 outer : source_color = vec4(1.0, 0.42, 0.1, 1.0);

void fragment() {
	float h = UV.y;
	float flick = 0.85 + 0.15 * sin(TIME * 31.0 + UV.x * 12.0) * sin(TIME * 17.0);
	vec3 c = mix(core.rgb, outer.rgb, smoothstep(0.1, 0.8, h));
	float a = (1.0 - smoothstep(0.35, 1.0, h)) * burn * flick;
	ALBEDO = c * a * 3.0;
}
