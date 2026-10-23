shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// The gold "?" inside an item box (ItemBox.gd sweeps the mesh, facing +z). It turns about the vertical
// to face the camera, swaying a little either side so it reads as solid, so it can be read from any side
// of the spinning box and on every viewport of a split screen. It glows, lit by a key light fixed on
// screen (up and to the left) with a glint: lit by the scene, its specular took the blue sky into the gold
// and turned it salmon. `pop` (0 -> 1) flares it as the box bursts.

instance uniform float phase = 0.0;
instance uniform float pop = 0.0;
uniform vec3 core_colour : source_color = vec3(1.0, 0.78, 0.16);
uniform vec3 rim_colour : source_color = vec3(1.0, 0.5, 0.0);
uniform vec3 glint_colour : source_color = vec3(1.0, 0.95, 0.75);
uniform float glow = 1.0;
uniform float gain = 1.0;          // 1 / the level's exposure (ItemBox.gd)
uniform float sway = 0.38;

void vertex() {
	float a = sin(TIME * 1.2 + phase * 6.2832) * sway;
	float c = cos(a);
	float s = sin(a);
	VERTEX = vec3(VERTEX.x * c + VERTEX.z * s, VERTEX.y, VERTEX.z * c - VERTEX.x * s);
	NORMAL = vec3(NORMAL.x * c + NORMAL.z * s, NORMAL.y, NORMAL.z * c - NORMAL.x * s);
	// Billboard about world up, keeping the node's scale (StandardMaterial3D's BILLBOARD_FIXED_Y).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float key = clamp(dot(NORMAL, normalize(vec3(-0.35, 0.75, 0.55))), 0.0, 1.0);
	float glint = pow(key, 24.0);
	vec3 col = mix(rim_colour, core_colour, smoothstep(0.0, 1.0, facing * 0.6 + key * 0.5));
	col = col * (0.6 + 0.55 * key) + glint_colour * glint * 0.5;
	float breathe = 1.0 + 0.1 * sin(TIME * 3.0 + phase * 6.2832);
	ALBEDO = col * glow * gain * breathe * (1.0 + pop * 2.5);
}
