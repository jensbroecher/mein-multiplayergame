shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Heaped broken rock on Mina del Viento (regenerate_mina.gd): the safety berms along the haul road, the muck piles
// at the pit's face, the ore in the trucks and the stockpile. The colour is the vertex colour (sRGB) times the
// pebble rubble's grain, laid triplanar in world metres, with its normal map.

uniform sampler2D pebble_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebble_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scale = 0.42;
uniform float grain = 1.9;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(wn), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 t = texture(pebble_tex, wp.zy * scale).rgb * w.x + texture(pebble_tex, wp.xz * scale).rgb * w.y
			+ texture(pebble_tex, wp.xy * scale).rgb * w.z;
	float lum = dot(t, vec3(0.3, 0.59, 0.11));
	float far = smoothstep(60.0, 260.0, length(wp - CAMERA_POSITION_WORLD));
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = base * mix(0.42 + lum * grain, 0.42 + 0.3 * grain, far);
	ROUGHNESS = 0.95;
	SPECULAR = 0.25;
	NORMAL_MAP = texture(pebble_normal, wp.xz * scale).rgb * w.y + texture(pebble_normal, wp.zy * scale).rgb * w.x
			+ texture(pebble_normal, wp.xy * scale).rgb * w.z;
	NORMAL_MAP_DEPTH = 0.8 * (1.0 - far);
}
