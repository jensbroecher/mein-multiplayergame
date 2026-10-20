shader_type spatial;
render_mode cull_disabled;

// Dune grass tufts (regenerate_bloombay_dunes.gd, _grass_tuft): vertex colour is the blade's colour,
// its alpha how far up the blade the vertex is. The blades sway in the sea wind, more toward their
// tips, each tuft a little out of step with the next by where it stands. Reading TIME is fine here:
// it's sky shaders that must not, because there it rebuilds the radiance map every frame.

uniform float sway = 0.20;
uniform float speed = 1.6;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = COLOR.a * COLOR.a;
	float g = sin(TIME * speed + wp.x * 0.23 + wp.z * 0.31) + 0.45 * sin(TIME * speed * 2.3 + wp.x * 0.9 - wp.z * 0.7);
	VERTEX.x += g * sway * w;
	VERTEX.z += g * sway * 0.5 * w;
}

void fragment() {
	// Vertex colours are sRGB.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
