shader_type spatial;
render_mode cull_disabled;

// A flag waving in the wind (regenerate_bloombay_dunes.gd, _flag). The mesh is in world space, the flag
// a vertical plane facing along NORMAL and streaming along cross(up, NORMAL). UV.x runs from the hoist
// (0) to the fly (1), UV.y from the top down. UV2.x is this flag's phase, UV2.y its length in metres.
// Waves run out from the pole and grow toward the fly, with a quicker flutter on top, and the normal is
// tilted with them so the folds catch the light. In a MultiMesh (Bloombay's flags on spring bases,
// SpringProps.gd) every instance shares one mesh, so INSTANCE_CUSTOM.x adds each flag's own phase.
// Reading TIME here is fine: it's sky shaders that must not, because there it rebuilds the radiance
// map every frame.

uniform float amplitude = 0.18;     // at the fly, as a share of the flag's length
uniform float wavelength = 0.85;    // in flag lengths
uniform float speed = 7.5;          // radians per second
uniform float roughness_value = 0.85;

void vertex() {
	float u = UV.x;
	float len = max(UV2.y, 0.01);
	vec3 along = normalize(cross(vec3(0.0, 1.0, 0.0), NORMAL));
	float k = 6.2831853 / (wavelength * len);
	float s = u * len;
	float phase = UV2.x + INSTANCE_CUSTOM.x * 6.2831853;
	float ph = s * k - TIME * speed + phase;
	float ph2 = s * k * 2.3 - TIME * speed * 1.8 + phase * 1.3 + UV.y * 1.5;
	float wave = sin(ph) + 0.25 * sin(ph2);
	// Pinned at the hoist, free at the fly.
	float env = 0.7 * u * u + 0.3 * u;
	float a = amplitude * len;
	VERTEX += NORMAL * (a * env * wave);
	// The cloth doesn't stretch: as it folds, the fly draws back toward the pole. It also droops a little.
	VERTEX -= along * (a * env * 0.3 * (1.0 - cos(ph)) * 0.5);
	VERTEX.y -= u * u * 0.03 * len;
	float slope = a * ((1.4 * u + 0.3) / len * wave + env * (k * cos(ph) + 0.25 * k * 2.3 * cos(ph2)));
	NORMAL = normalize(NORMAL - along * slope);
}

void fragment() {
	// Vertex colours are sRGB.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = roughness_value;
}
