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
// Transverse slab expansion joints: darkened concrete, anti-aliased so they fade out with
// distance instead of shimmering into a z-fighting looking mess.
uniform float joint_spacing = 8.0;
uniform float joint_strength : hint_range(0.0, 1.0) = 0.35;

// UV.x: 0.0 (left barrier) to 1.0 (right barrier)
// UV.y: distance along track in meters
void fragment() {
	// Keep the concrete isotropic in world space. Stretching UV.x by a fixed factor instead
	// smears every texture feature along the road into long thin bands.
	float road_width = mix(16.0, 11.5, step(0.5, COLOR.b));
	vec2 base_uv = vec2(UV.x * road_width, UV.y) * uv_scale;
	vec4 tex_albedo = texture(concrete_texture, base_uv);
	vec3 tex_norm = texture(concrete_normal, base_uv).rgb;
	float tex_rough = texture(concrete_roughness, base_uv).r;

	vec3 albedo = tex_albedo.rgb * concrete_color.rgb;

	// Transverse concrete slab expansion joints. The joint is narrower than a pixel at
	// distance, so widen its falloff to the texel footprint and let it dissolve rather than
	// alias into hard stair-stepped bands.
	float joint_coord = UV.y / max(joint_spacing, 0.5);
	float joint_footprint = fwidth(joint_coord);
	float joint_soft = clamp(joint_footprint * 1.5, 0.004, 0.05);
	float joint = smoothstep(0.0, joint_soft, fract(joint_coord));
	joint = mix(1.0, joint, clamp(1.0 - joint_footprint * 6.0, 0.0, 1.0));
	albedo = mix(albedo, albedo * (1.0 - joint_strength), joint);

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

	// Alternative routes are plain concrete: no lane lines, no edge lines, no gore hatching.
	// The main highway keeps its full 4-lane marking set.
	float road_type = COLOR.b; // 0.0 = 4-lane main highway, 1.0 = unmarked ramp
	float is_gore = COLOR.a;
	bool is_ramp = road_type > 0.5;

	float white_edges = 0.0;
	float white_dashes = 0.0;
	float yellow_lines = 0.0;
	float total_wear = 0.0;

	if (is_ramp) {
		// --- RAMP: bare concrete, only the wear of two wheel tracks ---
		float rw1 = 1.0 - smoothstep(0.0, 0.13, abs(px - 0.30));
		float rw2 = 1.0 - smoothstep(0.0, 0.13, abs(px - 0.70));
		total_wear = clamp(rw1 + rw2, 0.0, 1.0);
	} else {
		float edge_l_mode = COLOR.r;
		float edge_r_mode = COLOR.g;

		// Edge line dash pattern for exit/entrance: 1.5m dash, 1.5m gap (period 3m)
		float edge_dash = step(0.50, fract(py / 3.0));

		// Left Edge Line at px = 0.06:
		// mode >= 0.75: solid; 0.25 <= mode < 0.75: dashed; mode < 0.25: open (no line)
		float raw_edge_l = 1.0 - smoothstep(0.008, 0.008 + dx, abs(px - 0.06));
		float active_edge_l = mix(raw_edge_l * edge_dash, raw_edge_l, smoothstep(0.65, 0.85, edge_l_mode));
		white_edges += active_edge_l * smoothstep(0.20, 0.35, edge_l_mode);

		// Right Edge Line at px = 0.94:
		float raw_edge_r = 1.0 - smoothstep(0.008, 0.008 + dx, abs(px - 0.94));
		float active_edge_r = mix(raw_edge_r * edge_dash, raw_edge_r, smoothstep(0.65, 0.85, edge_r_mode));
		white_edges += active_edge_r * smoothstep(0.20, 0.35, edge_r_mode);

		// --- 4-LANE MAIN HIGHWAY (16m width) ---
		// 1. Dashed White Lane Dividers at 0.28 and 0.72 (3m dash, 3m gap)
		float dash = step(0.50, fract(py / 6.0));
		float lane_l = (1.0 - smoothstep(0.007, 0.007 + dx, abs(px - 0.28))) * dash;
		float lane_r = (1.0 - smoothstep(0.007, 0.007 + dx, abs(px - 0.72))) * dash;
		white_dashes = clamp(lane_l + lane_r, 0.0, 1.0);

		// 2. Double Yellow Center Line at 0.490 and 0.510 (Separating northbound/southbound or inner median)
		float y_line1 = 1.0 - smoothstep(0.006, 0.006 + dx, abs(px - 0.490));
		float y_line2 = 1.0 - smoothstep(0.006, 0.006 + dx, abs(px - 0.510));
		yellow_lines = clamp(y_line1 + y_line2, 0.0, 1.0);

		// 4-lane tire wear
		float wear1 = 1.0 - smoothstep(0.0, 0.08, abs(px - 0.17));
		float wear2 = 1.0 - smoothstep(0.0, 0.08, abs(px - 0.38));
		float wear3 = 1.0 - smoothstep(0.0, 0.08, abs(px - 0.62));
		float wear4 = 1.0 - smoothstep(0.0, 0.08, abs(px - 0.83));
		total_wear = clamp(wear1 + wear2 + wear3 + wear4, 0.0, 1.0);

		// Gore chevron markings if active (diagonal warning stripes on shoulder)
		if (is_gore > 0.05) {
			float chevron = step(0.50, fract((px * 4.0 + py * 0.3) / 1.5));
			float shoulder_mask = clamp(step(0.88, px) + (1.0 - step(0.12, px)), 0.0, 1.0);
			yellow_lines = max(yellow_lines, chevron * shoulder_mask * is_gore);
		}
	}

	// Apply markings
	albedo = mix(albedo, stripe_color.rgb, clamp(white_edges + white_dashes, 0.0, 1.0));
	albedo = mix(albedo, yellow_color.rgb, clamp(yellow_lines, 0.0, 1.0));

	ALBEDO = albedo;
	NORMAL_MAP = tex_norm;
	// Fade the surface detail out with the texel footprint, otherwise the concrete grain
	// aliases into crawling bands at a grazing angle.
	NORMAL_MAP_DEPTH = normal_strength * clamp(1.0 - fwidth(UV.y) * 1.2, 0.12, 1.0);
	ROUGHNESS = tex_rough * 0.88;
	METALLIC = 0.02;
}
