shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Still, dark water for Northlight Caverns: the pool in the crevasse and the water under the Thin
// Ice. It is always seen from close by, a few metres down a hole or over a bridge rail, so the
// ripples are sized in world metres and drift slowly. The ocean shader (water.gdshader) tiles its
// fine chop forty times across whatever mesh it is on, which at this range read as a sea seen from
// a great height.
//
// Opaque: the pool and the holes are deep and dark, so nothing under the surface needs to show,
// and an opaque surface needs no depth read and sorts like any other.

uniform sampler2D noise_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 water_color : source_color = vec4(0.004, 0.012, 0.026, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.30, 0.48, 0.66, 1.0);
// How much of the sky the surface mirrors at a grazing angle.
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.35;
// Metres covered by one repeat of the ripple texture; the two layers are this and 0.6 of it.
uniform float ripple_tile = 30.0;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.18;
// Drift of the ripples, in metres per second.
uniform float drift = 0.12;
uniform float roughness : hint_range(0.0, 1.0) = 0.16;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = w_pos.xz / ripple_tile;
	vec2 m = vec2(TIME * drift / ripple_tile);
	vec3 n1 = texture(noise_tex, p + m).rgb;
	vec3 n2 = texture(noise_tex, p / 0.6 - m * 1.4 + vec2(0.37, 0.71)).rgb;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = ripple_strength;

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	ALBEDO = mix(water_color.rgb, sky_tint.rgb * 0.55, fresnel * sky_reflect);
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
