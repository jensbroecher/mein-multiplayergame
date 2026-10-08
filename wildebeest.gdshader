shader_type spatial;
render_mode cull_back, diffuse_burley;

// Galloping wildebeest for the Mara Crossing migration (WildebeestHerd.gd). The mesh is built by
// the level generator facing -Z, with the animation rig packed into its vertex data:
//   COLOR.r - swing weight: 0 on the body, rising to 1 down each leg (or along the tail)
//   COLOR.g - gait phase of that leg, 0..1
//   COLOR.b - 1 on the head and neck, which nod with the stride
//   UV2     - the pivot (y, z) the leg or head turns about
//   UV.x    - which coat colour: 0 body, 0.5 dark (mane, face, lower legs), 1 horn
// Per instance, INSTANCE_CUSTOM.x offsets the gait so the herd does not move in lockstep and
// INSTANCE_CUSTOM.y is the gait strength (1 galloping, 0 standing).

uniform float stride_hz = 2.1;
uniform vec4 coat_color : source_color = vec4(0.30, 0.27, 0.25, 1.0);
uniform vec4 dark_color : source_color = vec4(0.10, 0.09, 0.09, 1.0);
uniform vec4 horn_color : source_color = vec4(0.62, 0.58, 0.50, 1.0);

varying float coat;
varying float band_y;
varying float band_z;

vec3 rot_x(vec3 v, vec2 pivot, float a) {
	float c = cos(a);
	float s = sin(a);
	float y = v.y - pivot.x;
	float z = v.z - pivot.y;
	return vec3(v.x, pivot.x + y * c - z * s, pivot.y + y * s + z * c);
}

void vertex() {
	coat = UV.x;
	band_y = VERTEX.y;
	band_z = VERTEX.z;
	float run = INSTANCE_CUSTOM.y;
	float p = TIME * stride_hz + INSTANCE_CUSTOM.x;
	if (COLOR.r > 0.001) {
		float a = sin((p + COLOR.g) * TAU) * 0.62 * run * COLOR.r;
		VERTEX = rot_x(VERTEX, UV2, a);
	}
	if (COLOR.b > 0.5) {
		VERTEX = rot_x(VERTEX, UV2, sin(p * TAU + 1.2) * 0.16 * run);
	}
	// The whole body rises and pitches through the stride.
	VERTEX.y += abs(sin(p * TAU * 0.5)) * 0.14 * run;
	VERTEX = rot_x(VERTEX, vec2(0.9, 0.0), sin(p * TAU) * 0.05 * run);
}

void fragment() {
	vec3 c = coat_color.rgb;
	// Dark vertical bands down the neck and fore-body.
	float bands = smoothstep(0.35, 0.65, sin(band_z * 9.0)) * smoothstep(0.75, 1.05, band_y) * (1.0 - smoothstep(-0.2, 0.5, band_z));
	c = mix(c, dark_color.rgb, bands * 0.55);
	c = mix(c, dark_color.rgb, smoothstep(0.25, 0.5, coat));
	c = mix(c, horn_color.rgb, smoothstep(0.75, 1.0, coat));
	ALBEDO = c;
	ROUGHNESS = mix(0.85, 0.45, smoothstep(0.75, 1.0, coat));
}
