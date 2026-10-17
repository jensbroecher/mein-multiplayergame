// showroom_floor.gdshader: the car select screen's floor round the turntable: a faint grid that
// fades out with distance into the backdrop behind it (the showroom renders over a clear
// background, drawn by CarSelection's Control).
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 floor_color : source_color = vec4(0.055, 0.065, 0.09, 1.0);
uniform vec4 line_color : source_color = vec4(0.15, 0.75, 0.92, 1.0);
uniform float cell = 0.5;
uniform float radius = 6.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / cell;
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(1e-4));
	float line = 1.0 - clamp(min(g.x, g.y), 0.0, 1.0);
	float r = length(world_pos.xz);
	float fade = 1.0 - smoothstep(radius * 0.15, radius, r);
	ALBEDO = mix(floor_color.rgb, line_color.rgb, line * 0.16);
	ALPHA = fade * mix(0.9, 1.0, line);
}
