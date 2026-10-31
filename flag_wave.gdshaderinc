// The wave of flag_wave.gdshader, shared with logo_flag.gdshader: see flag_wave.gdshader for the mesh it
// expects (a vertical plane facing along NORMAL, UV.x hoist to fly, UV2 the phase and length).

uniform float amplitude = 0.18;     // at the fly, as a share of the flag's length
uniform float wavelength = 0.85;    // in flag lengths
uniform float speed = 7.5;          // radians per second

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
