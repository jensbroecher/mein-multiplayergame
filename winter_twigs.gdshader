shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://camera_xray.gdshaderinc"

// The bare crowns of SnowTreeKit's winter birches: WoodlandBuilder's hanging birch cards, textured with a
// drawn spray of fine forking twigs (SnowTreeKit.twig_atlas), alpha-tested. The vertex data is the
// leaf cards' (WoodlandBuilder.cluster_cards):
//   NORMAL - the crown's, so a crown shades as one mass, brighter on top
//   COLOR  - rgb the leaf tint (unused: the twigs carry their own colour), a the shade inside the crown
// Frost and a little snow lie on the twigs that face up.

#include "res://tree_lod.gdshaderinc"

uniform sampler2D twig_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform vec4 frost_color : source_color = vec4(0.86, 0.89, 0.95, 1.0);
uniform float frost : hint_range(0.0, 1.0) = 0.45;
uniform float sway = 0.08;
uniform float sway_height = 14.0;

varying float cam_dist;
varying float tree_seed;
varying vec3 w_nrm;
varying vec3 local_pos;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tree_seed = lod_seed(origin);
	cam_dist = lod_distance(origin, CAMERA_POSITION_WORLD);
	local_pos = VERTEX;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float ph = TIME * 0.8 + tree_seed * 6.28;
	VERTEX.x += sin(ph) * sway * h * h;
	VERTEX.z += cos(ph * 0.83) * sway * h * h;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (xray_hidden(VERTEX, VIEW_MATRIX, CAMERA_POSITION_WORLD, PROJECTION_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	if (lod_hidden(cam_dist, FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	vec4 tex = texture(twig_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	float shade = COLOR.a;
	// Some crowns redder, some greyer.
	vec3 twigs = tex.rgb * mix(vec3(1.08, 0.96, 0.98), vec3(0.94, 0.96, 1.04), tree_seed) * 1.15;
	// Frost on the twigs facing up, in patches through the crown.
	float up = smoothstep(0.1, 0.9, normalize(w_nrm).y + 0.2);
	float patches = vnoise3(local_pos * 0.9 + tree_seed * 11.0);
	float f = clamp(frost * (up * 0.7 + patches * 0.5), 0.0, 1.0);
	ALBEDO = mix(twigs, frost_color.rgb, f * 0.75) * mix(0.55, 1.0, shade);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = mix(0.8, 0.6, f);
	SPECULAR = 0.25;
	AO = mix(0.45, 1.0, shade);
	AO_LIGHT_AFFECT = 0.25;
}
