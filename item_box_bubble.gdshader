shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// The soap bubble round an item box (a sphere, ItemBox.gd). Clear in the middle; toward the rim the
// thin-film colours, drifting slowly over it, and two window highlights that stay put on screen. Its
// surface wobbles a little. `build` fades it in, `pop` out.

instance uniform float phase = 0.0;
instance uniform float pop = 0.0;
instance uniform float build = 1.0;
uniform vec3 tint : source_color = vec3(0.45, 0.9, 1.0);
uniform float strength = 0.7;
uniform float gain = 1.0;          // 1 / the level's exposure (ItemBox.gd)
uniform float fade_begin = 90.0;
uniform float fade_end = 140.0;

varying vec3 obj;

void vertex() {
	obj = VERTEX;
	float t = TIME * 1.6 + phase * 6.2832;
	float w = sin(VERTEX.y * 3.5 + t) * 0.5 + sin(VERTEX.x * 3.0 - t * 1.3) * 0.3 + sin(VERTEX.z * 4.0 + t * 0.7) * 0.2;
	VERTEX += NORMAL * w * 0.025;
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.5);
	float film = (1.0 - ndv) * 1.6 + obj.y * 0.6 + sin(obj.x * 2.5 + TIME * 0.6 + phase * 6.2832) * 0.25 + TIME * 0.05;
	vec3 irid = 0.55 + 0.45 * cos(6.2832 * (film + vec3(0.0, 0.33, 0.67)));
	vec3 col = mix(tint, irid, 0.65) * rim * strength;
	float hl = pow(clamp(dot(NORMAL, normalize(vec3(-0.5, 0.55, 0.67))), 0.0, 1.0), 70.0) * 1.2
			+ pow(clamp(dot(NORMAL, normalize(vec3(0.45, -0.35, 0.82))), 0.0, 1.0), 160.0) * 0.5;
	col += vec3(hl) + tint * 0.015;
	float fade = build * (1.0 - pop) * (1.0 - smoothstep(fade_begin, fade_end, length(VERTEX)));
	ALBEDO = col * fade * gain;
}
