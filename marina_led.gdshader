// Marina Nights' LED strips (MarinaKit's "ledchase", the glass tube's ribs and lines): unshaded light in the vertex colour
// times `energy` (over 1, so the glow blooms it). `mode` 1 lets the colours drift along the strip (UV.x metres along it)
// through the city's palette, slowly: `speed` m/s, a cycle every `period` metres, blended softly (nothing blinks).
// `cam_fade_far` > 0 dithers the strip away within that of the camera (fully gone inside `cam_fade_near`), so the
// tube's ribs never sweep through the lens of a camera riding under them.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform int mode = 0;
uniform float energy = 3.0;
uniform float speed = 4.0;
uniform float period = 120.0;
uniform float cam_fade_near = 0.0;
uniform float cam_fade_far = 0.0;

vec3 palette(float t) {
	// Gold, rose, cyan, deep blue, white gold: round and round.
	vec3 c0 = vec3(1.0, 0.70, 0.30);
	vec3 c1 = vec3(1.0, 0.35, 0.60);
	vec3 c2 = vec3(0.25, 0.85, 1.0);
	vec3 c3 = vec3(0.30, 0.40, 1.0);
	vec3 c4 = vec3(1.0, 0.92, 0.75);
	float k = t * 5.0;
	float f = smoothstep(0.0, 1.0, fract(k));
	int i = int(floor(k));
	vec3 a = i == 0 ? c0 : i == 1 ? c1 : i == 2 ? c2 : i == 3 ? c3 : c4;
	vec3 b = i == 0 ? c1 : i == 1 ? c2 : i == 2 ? c3 : i == 3 ? c4 : c0;
	return mix(a, b, f);
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int idx = q.x + q.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[idx]) + 0.5) / 16.0;
}

void fragment() {
	if (cam_fade_far > 0.0) {
		float dist = length(VERTEX);
		float keep = smoothstep(cam_fade_near, cam_fade_far, dist);
		if (keep < bayer4(FRAGCOORD.xy)) {
			discard;
		}
	}
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	if (mode == 1) {
		c = palette(fract((UV.x - TIME * speed) / period));
	}
	ALBEDO = c * energy;
}
