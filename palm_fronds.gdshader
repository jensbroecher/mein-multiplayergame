shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://camera_xray.gdshaderinc"

// Coconut palm fronds on Bloombay Dunes (regenerate_bloombay_dunes.gd, _palm_mesh). Each frond is a
// pair of cards hung from its midrib in a V, each textured with one side's leaflets (the generator
// draws the atlas, _palm_frond_texture), alpha-tested. From the mesh:
//   UV     - into the atlas
//   UV2.x  - how far along the frond, 0 at the crown and 1 at the tip
//   UV2.y  - the frond's own phase for the flutter, 0..1
//   COLOR  - rgb a tint per frond (old ones yellower), a the shade (dark inside the crown)
// The fronds bob and swing in the breeze, more toward their tips; the leaflets shiver.

#include "res://tree_lod.gdshaderinc"

uniform sampler2D frond_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform vec4 backlight_color : source_color = vec4(0.62, 0.70, 0.22, 1.0);
// Metres a frond's tip moves, and how fast.
uniform float flutter = 0.22;
uniform float flutter_speed = 1.6;

varying float cam_dist;
varying float tree_seed;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tree_seed = lod_seed(origin);
	cam_dist = lod_distance(origin, CAMERA_POSITION_WORLD);
	float t = UV2.x;
	float ph = TIME * flutter_speed + (UV2.y + tree_seed) * 6.2832;
	float a = flutter * t * t;
	VERTEX.y += sin(ph) * a;
	VERTEX.x += sin(ph * 0.73 + 1.3) * a * 0.45;
	VERTEX.z += cos(ph * 0.61 + 0.4) * a * 0.45;
	VERTEX.y += sin(TIME * 6.0 + VERTEX.x * 3.1 + VERTEX.z * 2.3) * 0.02 * t;
}

void fragment() {
	if (xray_hidden(VERTEX, VIEW_MATRIX, CAMERA_POSITION_WORLD, PROJECTION_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	if (lod_hidden(cam_dist, FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	vec4 tex = texture(frond_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// Some palms greener, some more golden.
	vec3 tint = COLOR.rgb * mix(vec3(0.95, 1.03, 1.0), vec3(1.06, 1.0, 0.86), tree_seed);
	float shade = COLOR.a;
	ALBEDO = tex.rgb * tint * mix(0.5, 1.0, shade);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.7;
	SPECULAR = 0.22;
	// Thin leaflets: the sun shines through them from behind.
	BACKLIGHT = backlight_color.rgb * 0.45 * shade;
	AO = mix(0.45, 1.0, shade);
	AO_LIGHT_AFFECT = 0.2;
}
