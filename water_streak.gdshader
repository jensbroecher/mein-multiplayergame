shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// A falling drop of water for GPUParticles3D (Yoshino Rapids' mill wheel: the pour, the buckets' spills, the splash,
// the drips). The draw pass is a quad (its size the drop's width and length); the process material aligns each
// particle's Y with its velocity (particle_flag_align_y), and this turns the quad about that axis to face the camera, so
// a drop is a streak along its fall seen from any side. COLOR comes from the particles (their colour ramp's alpha fades
// them).

uniform vec3 body : source_color = vec3(0.70, 0.83, 0.86);
uniform vec3 glint : source_color = vec3(1.0, 1.0, 1.0);
uniform float opacity = 0.55;

varying float v_rnd;

void vertex() {
	vec3 ya = MODEL_MATRIX[1].xyz;
	float sy = length(ya);
	ya /= max(sy, 1e-5);
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 org = MODEL_MATRIX[3].xyz;
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - org);
	vec3 xa = cross(ya, to_cam);
	if (dot(xa, xa) < 1e-6) {
		xa = INV_VIEW_MATRIX[0].xyz;
	}
	xa = normalize(xa);
	vec3 wp = org + xa * VERTEX.x * sx + ya * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	v_rnd = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	// A drop: round at its head (the lower end), thinning to a tail behind.
	float along = q.y * 0.5 + 0.5;
	float w = mix(1.0, 0.25, along);
	float shape = (1.0 - smoothstep(0.45, 1.0, abs(q.x) / max(w, 0.05))) * (1.0 - smoothstep(0.6, 1.0, abs(q.y)));
	float core = 1.0 - smoothstep(0.0, 0.5, abs(q.x) / max(w, 0.05));
	ALBEDO = mix(body, glint, core * (0.35 + 0.45 * v_rnd)) * COLOR.rgb;
	ALPHA = shape * opacity * COLOR.a * (0.7 + 0.3 * v_rnd);
}
