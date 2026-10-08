shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_mix, specular_schlick_ggx;

// Falling water for the Frostfall Gorge falls. The curtain mesh is a ribbon hung from the lip:
//   UV.x - 0..1 across the falls
//   UV.y - 0 at the lip, 1 at the plunge pool
// Water accelerates as it falls, so the streaks are stretched and sped up toward the bottom, and
// the curtain thins into ragged strands at its sides and breaks up into spray where it lands.

uniform sampler2D streak_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 body_color : source_color = vec3(0.55, 0.74, 0.80);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
uniform float fall_speed = 0.55;
uniform float opacity = 0.92;
uniform float strand_count = 7.0;
// The outer veil layer is the same shader with more spray and less body.
uniform float veil = 0.0;

void fragment() {
	// Accelerating fall: position along a constant-acceleration drop is ~t^2, so the texture
	// coordinate runs on sqrt(y) - slow streaks at the lip, fast ones near the pool.
	float y = UV.y;
	float fall = sqrt(max(y, 0.0));
	vec2 uv1 = vec2(UV.x * strand_count, fall * 1.6 - TIME * fall_speed);
	vec2 uv2 = vec2(UV.x * strand_count * 2.3 + 0.37, fall * 2.4 - TIME * fall_speed * 1.45);
	float s1 = texture(streak_noise, uv1 * vec2(1.0, 0.35)).r;
	float s2 = texture(streak_noise, uv2 * vec2(1.0, 0.45)).r;
	float streak = s1 * 0.6 + s2 * 0.4;

	// Ragged sides: the curtain frays into separate strands toward its edges.
	float edge = min(UV.x, 1.0 - UV.x);
	float strands = texture(streak_noise, vec2(UV.x * 23.0, fall * 0.4 - TIME * fall_speed * 0.8)).r;
	float side = smoothstep(0.0, 0.10 + strands * 0.12, edge);

	// Smooth glassy water just over the lip, white turmoil further down.
	float aeration = smoothstep(0.02, 0.35, y) * 0.75 + smoothstep(0.75, 1.0, y) * 0.25;
	float foam = clamp(smoothstep(0.35, 0.80, streak) * (0.45 + aeration) + veil * 0.6, 0.0, 1.0);
	vec3 col = mix(body_color, foam_color, foam);

	float a = opacity * side * mix(0.55 + streak * 0.6, 0.25 + streak * 0.55, veil);
	// The bottom metres disappear into the spray rather than meeting the pool with a hard edge.
	a *= 1.0 - smoothstep(0.86, 1.0, y) * 0.75;
	// The lip itself is solid water, never transparent.
	a = max(a, (1.0 - smoothstep(0.0, 0.06, y)) * side * opacity * (1.0 - veil));

	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = mix(0.15, 0.6, foam);
	SPECULAR = 0.5;
	// Falling water catches the sky from every angle; keep it bright even in the gorge's shade.
	EMISSION = col * (0.10 + foam * 0.14);
	BACKLIGHT = vec3(0.35, 0.45, 0.5) * (1.0 - foam);
}
