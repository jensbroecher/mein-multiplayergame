// The time trial's ghost car (TimeTrialGhost.gd): the best run's car as a see-through hologram in `tint`, bright at its
// silhouette, faint scan lines drifting up it, additive (as the menu tile's ghost, menu_ghost.gdshader). It fades out
// close to the camera, so driving through it never fills the view, and by `strength` (in at the green light, out at
// the end of its run).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float strength = 1.0;
uniform float near_fade = 4.0;
uniform float near_full = 11.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float scan = 0.65 + 0.35 * sin(w_pos.y * 40.0 - TIME * 3.0);
	float a = (0.07 + 0.8 * pow(rim, 2.2)) * scan;
	float near = smoothstep(near_fade, near_full, length(w_pos - CAMERA_POSITION_WORLD));
	ALBEDO = tint.rgb * a * 1.5 * strength * near;
}
