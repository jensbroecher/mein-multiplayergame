shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://camera_xray.gdshaderinc"

// Foliage of Mara Crossing's umbrella-thorn acacias: cards textured with sprays of fine bipinnate
// leaves on zigzag twigs (the generator draws the texture, _acacia_leaf_texture), alpha-tested.
// The generator lays the cards in thin flat pads and gives them:
//   NORMAL - the crown's, not the card's: a flattened sphere round the canopy, tipped up, so
//            the canopy shades as one lacy mass, bright on top and on the sun's side
//   COLOR  - rgb a tint per pad and card, a the shade inside the canopy (dark underneath)
// The texture's mipmaps keep their coverage, so distant canopies don't thin out. The baobabs'
// leaf clusters use it too, with a texture of their own (_baobab_leaf_texture).

#include "res://tree_lod.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
// Pulls the leaves toward their grey (0: as drawn): the Al-Raihana GP's ghaf and thorn trees are dusty grey-green.
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform vec4 backlight_color : source_color = vec4(0.62, 0.66, 0.30, 1.0);
// 1: what shines through a card is its own colour times backlight_color, not backlight_color alone (the Miyoshino
// GP's blossom: a leaf green behind pale pink petals read as grey).
uniform float backlight_albedo : hint_range(0.0, 1.0) = 0.0;
// The colour drift from tree to tree (tree_seed 0 to 1): greener to more olive as it was; blossom sets whiter to pinker.
uniform vec3 seed_tint_a = vec3(0.94, 1.02, 1.04);
uniform vec3 seed_tint_b = vec3(1.06, 1.0, 0.86);
// A share of the cards' own colour given off as light (0: none): blossom lights itself from petal to petal, and in
// the tree's own shadow it stays pale instead of going the sky's blue-grey.
uniform float glow : hint_range(0.0, 1.0) = 0.0;
// Metres the canopy sways at its top, and the height that sways fully.
uniform float sway = 0.15;
uniform float sway_height = 16.0;

varying float cam_dist;
varying float tree_seed;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tree_seed = lod_seed(origin);
	cam_dist = lod_distance(origin, CAMERA_POSITION_WORLD);
	// The crown sways as a whole, slowly; each card flutters a little on its own.
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float ph = TIME * 0.7 + tree_seed * 6.28;
	VERTEX.x += sin(ph) * sway * h * h;
	VERTEX.z += cos(ph * 0.83) * sway * h * h;
	VERTEX.y += sin(TIME * 2.1 + VERTEX.x * 0.9 + VERTEX.z * 0.7) * 0.04 * h;
}

void fragment() {
	if (xray_hidden(VERTEX, VIEW_MATRIX, CAMERA_POSITION_WORLD, PROJECTION_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	if (lod_hidden(cam_dist, FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	vec4 tex = texture(leaf_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// Some trees greener, some greyer and more olive.
	vec3 tint = COLOR.rgb * 1.25 * mix(seed_tint_a, seed_tint_b, tree_seed);
	float shade = COLOR.a;
	ALBEDO = tex.rgb * tint * mix(0.42, 1.0, shade);
	ALBEDO = mix(ALBEDO, vec3(dot(ALBEDO, vec3(0.3, 0.55, 0.15))) * vec3(1.0, 1.02, 0.9), desaturate);
	// The crown's normal on both faces of a card.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	EMISSION = ALBEDO * glow;
	ROUGHNESS = 0.82;
	SPECULAR = 0.22;
	BACKLIGHT = mix(backlight_color.rgb, backlight_color.rgb * tex.rgb * tint, backlight_albedo) * 0.35 * shade;
	AO = mix(0.35, 1.0, shade);
	AO_LIGHT_AFFECT = 0.25;
}
