shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Foliage of Mara Crossing's umbrella-thorn acacias: cards textured with sprays of fine bipinnate
// leaves on zigzag twigs (the generator draws the texture, _acacia_leaf_texture), alpha-tested.
// The generator lays the cards in thin flat pads and gives them:
//   NORMAL - the crown's, not the card's: a flattened sphere round the canopy, tipped up, so
//            the canopy shades as one lacy mass, bright on top and on the sun's side
//   COLOR  - rgb a tint per pad and card, a the shade inside the canopy (dark underneath)
// The texture's mipmaps keep their coverage, so distant canopies don't thin out.

#include "res://tree_lod.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform vec4 backlight_color : source_color = vec4(0.62, 0.66, 0.30, 1.0);
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
	if (lod_hidden(cam_dist, FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	vec4 tex = texture(leaf_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// Some trees greener, some greyer and more olive.
	vec3 tint = COLOR.rgb * 1.25 * mix(vec3(0.94, 1.02, 1.04), vec3(1.06, 1.0, 0.86), tree_seed);
	float shade = COLOR.a;
	ALBEDO = tex.rgb * tint * mix(0.42, 1.0, shade);
	// The crown's normal on both faces of a card.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.82;
	SPECULAR = 0.22;
	BACKLIGHT = backlight_color.rgb * 0.35 * shade;
	AO = mix(0.35, 1.0, shade);
	AO_LIGHT_AFFECT = 0.25;
}
