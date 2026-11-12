shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Tianqiao's glass skyways (regenerate_tianqiao.gd, `_glass_roads`): the road ribbon (MiyoshinoStage's: UV.x the lateral
// in metres, UV.y metres along the lap, UV2.y the half width) drawn as panes of toughened glass on a steel grid, the
// city showing through, an LED line along each edge and a dashed one down the middle. Collision is the road's as usual.

uniform vec3 tint : source_color = vec3(0.45, 0.72, 0.86);
uniform float clarity = 0.26;
uniform float panel_len = 3.0;
uniform float panel_w = 2.5;
uniform vec3 led : source_color = vec3(0.35, 0.85, 1.0);
uniform float led_energy = 2.4;

void fragment() {
	float lat = UV.x;
	float s = UV.y;
	float hw = max(UV2.y, 1.0);
	float fw = max(fwidth(s), 0.002);
	float sl = abs(fract(s / panel_len + 0.5) - 0.5) * panel_len;
	float sw = abs(fract((lat + hw) / panel_w + 0.5) - 0.5) * panel_w;
	float seam = 1.0 - smoothstep(0.05, 0.05 + fw * 1.5, min(sl, sw));
	float edge = smoothstep(hw - 0.4, hw - 0.28, abs(lat));
	float centre = (1.0 - smoothstep(0.07, 0.07 + fw, abs(lat))) * step(0.55, fract(s / 6.0));
	// A faint frit of dots on the panes (anti-slip), fading out with distance.
	vec2 dots = fract(vec2(lat, s) / 0.35) - 0.5;
	float frit = (1.0 - smoothstep(0.08, 0.12, length(dots))) * (1.0 - smoothstep(0.02, 0.08, fw));
	ALBEDO = mix(tint * 0.35 + frit * 0.15, vec3(0.08, 0.09, 0.1), seam);
	ROUGHNESS = mix(0.04, 0.5, max(seam, frit * 0.5));
	METALLIC = mix(0.15, 0.7, seam);
	SPECULAR = 0.9;
	ALPHA = clamp(mix(clarity + frit * 0.15, 0.95, seam) + edge, 0.0, 1.0);
	EMISSION = led * (edge * 1.0 + centre * 0.5) * led_energy;
}
