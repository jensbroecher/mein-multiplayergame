shader_type spatial;
render_mode cull_disabled;

// Dune grass tufts (regenerate_bloombay_dunes.gd, _grass_tuft): vertex colour is the blade's colour,
// its alpha how far up the blade the vertex is. The blades sway in the sea wind, more toward their
// tips, each tuft a little out of step with the next by where it stands. Reading TIME is fine here:
// it's sky shaders that must not, because there it rebuilds the radiance map every frame.

uniform float sway = 0.20;
uniform float speed = 1.6;
// Carts push the blades aside and down as they pass through (Level.gd feeds their positions to the
// materials of the "grass_push" group: DuneDetail.gd on Bloombay Dunes; elsewhere player_count stays 0).
uniform vec3 player_positions[8];
uniform int player_count = 0;
uniform float push_radius = 2.6;
uniform float push_strength = 1.3;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = COLOR.a * COLOR.a;
	float g = sin(TIME * speed + wp.x * 0.23 + wp.z * 0.31) + 0.45 * sin(TIME * speed * 2.3 + wp.x * 0.9 - wp.z * 0.7);
	VERTEX.x += g * sway * w;
	VERTEX.z += g * sway * 0.5 * w;
	if (player_count > 0 && COLOR.a > 0.02) {
		vec2 push = vec2(0.0);
		float down = 0.0;
		for (int i = 0; i < player_count; i++) {
			vec3 diff = wp - player_positions[i];
			float dd = dot(diff.xz, diff.xz);
			if (dd < push_radius * push_radius && abs(diff.y) < 2.5) {
				float dist = sqrt(max(dd, 0.0001));
				float p = 1.0 - dist / push_radius;
				p = p * p * COLOR.a;
				push += diff.xz / dist * p * push_strength;
				down += p * 0.7;
			}
		}
		// The push is in the world: into the instance's frame (a turn and an even scale).
		mat3 m = mat3(MODEL_MATRIX);
		float s2 = max(dot(m[0], m[0]), 1e-6);
		VERTEX += transpose(m) * vec3(push.x, -down, push.y) / s2;
	}
}

void fragment() {
	// Vertex colours are sRGB.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
