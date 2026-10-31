shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

// Impostor trees: Pinecrest Ridge's far forest (regenerate_pinecrest_ridge.gd, _build_far_forest).
// Each tree is a quad whose four corners all sit at its foot (VERTEX); UV2 is the corner's offset in
// metres (x across, y up), and the vertex shader opens the quad out across the line to the camera,
// turned about the upright only, so the tree always stands. The sprite is the woods' own tree baked
// from the side (regenerate_pinecrest_impostors.gd): albedo_tex its unlit colour and outline (mipmaps
// that keep the outline's coverage), normal_tex its crown's normals in the baking camera's frame, so it
// shades as the 3D tree does (acacia_leaves.gdshader: bright on top and on the sun's side).
//   COLOR.r - a seed (the tint: greener or more olive, as the 3D trees vary)
//   COLOR.g - 1 where the sprite is mirrored (its normals' x flips with it)
//   COLOR.b - a rank: trees ranked over `density` aren't drawn (the Detail Level, JungleDetail.gd)

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float density : hint_range(0.0, 1.0) = 1.0;
uniform vec4 backlight_color : source_color = vec4(0.62, 0.74, 0.30, 1.0);

varying vec3 v_right;
varying vec3 v_fwd;
varying float v_seed;
varying float v_flip;

void vertex() {
	vec3 foot = VERTEX;
	vec3 to_cam = CAMERA_POSITION_WORLD - foot;
	to_cam.y = 0.0;
	vec3 fwd = normalize(to_cam + vec3(1e-4, 0.0, 0.0));
	vec3 right = vec3(fwd.z, 0.0, -fwd.x);
	// A tree the Detail Level leaves out folds to a point.
	float shown = step(COLOR.b, density);
	VERTEX = foot + (right * UV2.x + vec3(0.0, UV2.y, 0.0)) * shown;
	NORMAL = fwd;
	v_right = right;
	v_fwd = fwd;
	v_seed = COLOR.r;
	v_flip = COLOR.g;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 n = texture(normal_tex, UV).rgb * 2.0 - 1.0;
	n.x *= v_flip > 0.5 ? -1.0 : 1.0;
	vec3 wn = normalize(v_right * n.x + vec3(0.0, n.y, 0.0) + v_fwd * n.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = tex.rgb * mix(vec3(0.94, 1.02, 1.04), vec3(1.06, 1.0, 0.86), v_seed);
	ROUGHNESS = 0.82;
	SPECULAR = 0.22;
	BACKLIGHT = backlight_color.rgb * 0.25;
}
