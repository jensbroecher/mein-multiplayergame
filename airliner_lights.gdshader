// The airliners' lights (AirlinerKit.lights_mesh, flown by Airliners.gd): each light a sprite whose four corners all
// sit at the light (UV the corner, UV2.x its size in life-size metres, UV2.y its kind, COLOR its colour and in alpha
// its flash phase), opened out here to face the camera and never under a few pixels across however far off, so a
// light reads at any distance as it does in the sky: the navigation lights steady, the strobes double-flashing, the
// beacons blinking red, the landing lights blazing at whoever is ahead of them (`landing` per instance: on with the
// gear). All brighter at night. Faded like the airframe toward the far plane and as a flight begins or ends (`vis`).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;

uniform float night = 0.0;
uniform float fade_begin = 3300.0;
uniform float fade_end = 3950.0;

instance uniform float landing = 1.0;
instance uniform float phase = 0.0;
instance uniform float vis = 1.0;

varying vec3 v_col;
varying float v_int;
varying vec2 v_uv;

void vertex() {
	int kind = int(UV2.y + 0.5);
	vec3 c = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(c);
	float model_scale = length(MODEL_MATRIX[0].xyz);
	// A pixel's size in metres at that depth.
	float px = 2.0 * d / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float min_px = kind == 3 ? 5.0 : (kind == 1 ? 4.0 : (kind == 2 ? 3.2 : 2.4));
	min_px *= mix(1.0, 1.45, night);
	float size = max(UV2.x * model_scale, px * min_px);
	float t = TIME + phase;
	float inten = 1.0;
	if (kind == 0) {
		inten = mix(0.4, 1.0, night);
	} else if (kind == 1) {
		// A double flash every 1.3s.
		float ft = fract(t / 1.3);
		inten = (step(ft, 0.035) + step(0.12, ft) * step(ft, 0.155)) * mix(1.6, 2.2, night);
	} else if (kind == 2) {
		// A red blink a second, the belly's half a beat after the back's (COLOR.a).
		float ft = fract(t / 1.05 + COLOR.a);
		inten = smoothstep(0.0, 0.04, ft) * (1.0 - smoothstep(0.08, 0.32, ft)) * mix(0.8, 1.6, night);
	} else {
		// The landing lights shine ahead and a little down: dim from the side, blazing from in front.
		vec3 fwd = normalize((MODELVIEW_MATRIX * vec4(0.0, -0.12, -1.0, 0.0)).xyz);
		float facing = max(dot(fwd, normalize(-c)), 0.0);
		inten = landing * (mix(0.18, 1.0, pow(facing, 4.0)) + 2.5 * pow(facing, 40.0)) * mix(1.0, 2.6, night);
		size *= 1.0 + 0.8 * pow(facing, 10.0);
	}
	float fade = (1.0 - smoothstep(fade_begin, fade_end, d)) * vis;
	v_int = inten * fade;
	v_col = COLOR.rgb;
	v_uv = UV;
	c.xy += UV * size;
	VERTEX = c;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float r2 = dot(v_uv, v_uv);
	float core = exp(-r2 * 10.0);
	float halo = exp(-r2 * 3.0) * 0.3;
	ALBEDO = v_col * (core + halo) * v_int;
}
