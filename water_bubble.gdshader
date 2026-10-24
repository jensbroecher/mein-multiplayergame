shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Air bubbles rising from a cart sinking in deep water (WaterFx.gd): billboard particles drawn as a
// thin bright rim with a highlight, cut off at the water's surface so none show above it when the
// camera is in the air. The surface height is the emitter's instance parameter.

instance uniform float surface_y = 0.0;
uniform vec4 tint : source_color = vec4(0.82, 0.94, 1.0, 1.0);

varying float v_y;

void vertex() {
	// Face the camera, keeping the particle's scale.
	mat4 m = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * m * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_y = MODEL_MATRIX[3].y;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || v_y > surface_y - 0.05) {
		discard;
	}
	float rim = smoothstep(0.62, 0.92, r) * (1.0 - smoothstep(0.92, 1.0, r));
	float spot = 1.0 - smoothstep(0.0, 0.28, length(p - vec2(-0.32, 0.34)));
	ALBEDO = tint.rgb * (0.8 + spot * 0.6);
	ALPHA = clamp((rim * 0.85 + spot * 0.9 + 0.06) * COLOR.a, 0.0, 1.0);
}
