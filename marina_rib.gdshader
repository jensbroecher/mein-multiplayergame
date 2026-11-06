// The glass tube's steel (regenerate_marina_nights.gd, _build_tube): its ribs and purlins in painted steel (vertex
// colour), dithered away within `cam_fade_far` of the camera so they never sweep through the lens of a camera riding
// under the vault (the race cameras run 5-10m over the deck; the crown is 13.5m up).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float cam_fade_near = 2.5;
uniform float cam_fade_far = 6.0;
uniform float metallic_v = 0.55;
uniform float roughness_v = 0.34;

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int idx = q.x + q.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[idx]) + 0.5) / 16.0;
}

void fragment() {
	float dist = length(VERTEX);
	if (smoothstep(cam_fade_near, cam_fade_far, dist) < bayer4(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	METALLIC = metallic_v;
	ROUGHNESS = roughness_v;
}
