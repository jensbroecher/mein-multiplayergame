shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// Morning mist lying on the rivers (Shuangjiang, regenerate_shuangjiang.gd): flat sheets a few metres over the water,
// drifting downstream (+x) in wisps, each layer `layer` (0..1) its own; thinning where it nears the eye (so a car
// driving through doesn't see a wall), fading with the depth texture where it meets the banks and the boats.

uniform vec3 mist : source_color = vec3(0.86, 0.84, 0.82);
uniform float density = 0.55;
uniform float drift = 1.6;
uniform float layer = 0.0;
uniform float soft = 6.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = w_pos.xz / 140.0 + vec2(TIME * drift / 140.0, layer * 7.3);
	float n = fbm(p + vec2(fbm(p * 0.5 + layer), 0.0));
	float wisps = smoothstep(0.38, 0.8, n);
	float cam_d = length(w_pos - CAMERA_POSITION_WORLD);
	float near = smoothstep(4.0, 45.0, cam_d);
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_z = -vp.z / vp.w;
	float edge = clamp((scene_z + VERTEX.z) / soft, 0.0, 1.0);
	ALBEDO = mist;
	ALPHA = wisps * density * near * edge;
}
