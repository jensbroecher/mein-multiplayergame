// Rubber laid on the road by SkidMarks.gd: a strip of quads per wheel, one MultiMesh for the world.
// A quad's four corners ride in its instance transform's columns (the node itself stays at the
// identity, so MODEL_MATRIX is the instance transform): 0 start-left, 1 start-right, 2 end-left,
// 3 end-right. The mesh is a unit quad whose UV picks the corner. Neighbouring quads share corners,
// so a mark has no gaps or overlaps through a bend.
//
// Blended by multiplication: the mark darkens whatever the road's own lighting made of it, and two
// marks crossing are darker still, as laid rubber is.
shader_type spatial;
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, fog_disabled;

// SkidMarks.gd's clock, so a mark's age is now - its birth (custom.x).
uniform float now = 0.0;
uniform float fade_time = 40.0;
// How dark full-strength rubber makes the road (two marks across each other multiply).
uniform vec3 rubber = vec3(0.40, 0.385, 0.375);
// Marks fade out between these distances from the camera.
uniform float fade_near = 90.0;
uniform float fade_far = 150.0;

varying float v_strength;
varying float v_age;
varying float v_along;

void vertex() {
	int corner = int(UV.x + 0.5) + 2 * int(UV.y + 0.5);
	vec3 p = MODEL_MATRIX[3].xyz;
	if (corner == 0) {
		p = MODEL_MATRIX[0].xyz;
	} else if (corner == 1) {
		p = MODEL_MATRIX[1].xyz;
	} else if (corner == 2) {
		p = MODEL_MATRIX[2].xyz;
	}
	vec3 view = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	// Pulled toward the eye along its own ray: the same pixels on screen, but it wins the depth test
	// against the road it lies on, at any distance, without standing off it.
	float d = length(view);
	view *= max(d - (0.025 + d * 0.0012), 0.0) / max(d, 1e-4);
	VERTEX = view;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	// COLOR is the instance colour: r the strength at the start, g at the end.
	v_strength = mix(COLOR.r, COLOR.g, UV.y);
	v_age = now - INSTANCE_CUSTOM.x;
	v_along = mix(INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z, UV.y);
}

void fragment() {
	float across = UV.x;
	// Soft edges, heavier in the middle where the tyre bears.
	float edge = smoothstep(0.0, 0.25, across) * smoothstep(1.0, 0.75, across);
	// The tread's grooves run round the tyre, so a sliding tyre leaves lighter lines along its mark.
	float groove = 0.8 + 0.2 * smoothstep(0.02, 0.07, abs(fract(across * 4.0 + 0.5) - 0.5));
	// Rubber goes down unevenly along the mark.
	float mottle = 0.86 + 0.14 * sin(v_along * 2.3 + across * 3.0) * sin(v_along * 5.9 + 1.7);
	float age_fade = 1.0 - smoothstep(fade_time * 0.55, fade_time, v_age);
	float dist_fade = 1.0 - smoothstep(fade_near, fade_far, length(VERTEX));
	float a = clamp(v_strength, 0.0, 1.0) * edge * groove * mottle * age_fade * dist_fade;
	ALBEDO = mix(vec3(1.0), rubber, a);
}
