// The time trial tile's ghost car (MenuTileStage.gd): the car drawn as a see-through hologram in `tint`,
// bright at its silhouette, faint scan lines drifting up it, additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.18, 1.0);

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float scan = 0.65 + 0.35 * sin(w_pos.y * 40.0 - TIME * 3.0);
	float a = (0.08 + 0.85 * pow(rim, 2.2)) * scan;
	ALBEDO = tint.rgb * a * 1.6;
}
