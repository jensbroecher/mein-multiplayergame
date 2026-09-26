shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D concrete_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 concrete_color : source_color = vec4(0.85, 0.87, 0.90, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.96, 0.97, 1.0, 1.0);
uniform vec4 yellow_color : source_color = vec4(0.98, 0.82, 0.18, 1.0);
uniform float uv_scale = 0.20;
uniform float normal_strength = 0.75;

// UV.x: 0.0 (left barrier) to 1.0 (right barrier)
// UV.y: distance along track in meters
void fragment() {
	vec2 base_uv = vec2(UV.x * 4.0, UV.y * uv_scale);
	vec4 tex_albedo = texture(concrete_texture, base_uv);
	vec3 tex_norm = texture(concrete_normal, base_uv).rgb;
	float tex_rough = texture(concrete_roughness, base_uv).r;

	vec3 albedo = tex_albedo.rgb * concrete_color.rgb;

	// Transverse concrete slab expansion joints every 8.0 meters
	float joint_y = fract(UV.y / 8.0);
	float joint = 1.0 - smoothstep(0.0, 0.02, joint_y) * (1.0 - smoothstep(0.02, 0.04, joint_y));
	albedo = mix(albedo * 0.65, albedo, joint);

	// Highway Lane Markings (Clean, crisp, anti-aliased with fwidth):
	// Road has 4 lanes:
	// - Left shoulder: 0.0 to 0.06
	// - Solid White Fog Line (Left): 0.06
	// - Lane Divider 1 (Dashed White): 0.28
	// - Center Double Yellow Lines: 0.49 and 0.51
	// - Lane Divider 2 (Dashed White): 0.72
	// - Solid White Fog Line (Right): 0.94
	// - Right shoulder: 0.94 to 1.0

	float px = UV.x;
	float py = UV.y;
	float dx = fwidth(px) * 1.5;

	// 1. Solid White Edge Lines (Left: 0.06, Right: 0.94)
	float edge_l = 1.0 - smoothstep(0.008, 0.008 + dx, abs(px - 0.06));
	float edge_r = 1.0 - smoothstep(0.008, 0.008 + dx, abs(px - 0.94));
	float white_edges = clamp(edge_l + edge_r, 0.0, 1.0);

	// 2. Dashed White Lane Dividers at 0.28 and 0.72 (3m dash, 3m gap)
	float dash = step(0.50, fract(py / 6.0));
	float lane_l = (1.0 - smoothstep(0.007, 0.007 + dx, abs(px - 0.28))) * dash;
	float lane_r = (1.0 - smoothstep(0.007, 0.007 + dx, abs(px - 0.72))) * dash;
	float white_dashes = clamp(lane_l + lane_r, 0.0, 1.0);

	// 3. Double Yellow Center Line at 0.488 and 0.512
	float y_line1 = 1.0 - smoothstep(0.006, 0.006 + dx, abs(px - 0.490));
	float y_line2 = 1.0 - smoothstep(0.006, 0.006 + dx, abs(px - 0.510));
	float yellow_lines = clamp(y_line1 + y_line2, 0.0, 1.0);

	// Subtle tire wear in lane centers (0.17, 0.38, 0.62, 0.83)
	float wear1 = 1.0 - smoothstep(0.0, 0.08, abs(px - 0.17));
	float wear2 = 1.0 - smoothstep(0.0, 0.08, abs(px - 0.38));
	float wear3 = 1.0 - smoothstep(0.0, 0.08, abs(px - 0.62));
	float wear4 = 1.0 - smoothstep(0.0, 0.08, abs(px - 0.83));
	float total_wear = clamp(wear1 + wear2 + wear3 + wear4, 0.0, 1.0);
	albedo = mix(albedo, albedo * 0.82, total_wear * 0.40);

	// Apply markings
	albedo = mix(albedo, stripe_color.rgb, white_edges + white_dashes);
	albedo = mix(albedo, yellow_color.rgb, yellow_lines);

	ALBEDO = albedo;
	NORMAL_MAP = tex_norm;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = tex_rough * 0.88;
	METALLIC = 0.02;
}
