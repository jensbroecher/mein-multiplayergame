// The sea of cloud round the Yamabushi Trail's mountain (regenerate_yamabushi.gd, CloudLayer.gd): a great level sheet at
// the cloud band's top, seen from above. Billows from world-space noise drifting slowly, lit from the low sun's side,
// soft where the mountain comes up through it (the depth behind). Unshaded: its light is drawn here.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec3 lit : source_color = vec3(1.0, 0.93, 0.82);
uniform vec3 shade : source_color = vec3(0.62, 0.66, 0.80);
uniform vec2 sun_dir = vec2(0.9, 0.3);
uniform float drift = 1.2;

varying vec3 w_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = w_pos.xz / 260.0 + vec2(TIME * drift * 0.004, 0.0);
	float h = fbm(p);
	float hx = fbm(p + sun_dir * 0.06);
	float slope = clamp((h - hx) * 6.0 + 0.5, 0.0, 1.0);
	vec3 col = mix(shade, lit, slope) * (0.82 + 0.3 * h);
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 vf = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	float behind = -vf.z / vf.w + VERTEX.z;
	ALBEDO = col;
	ALPHA = smoothstep(0.0, 26.0, behind) * 0.97;
}
