shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D concrete_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 concrete_color : source_color = vec4(0.78, 0.77, 0.74, 1.0);
uniform float uv_scale = 0.25;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.8;
uniform float roughness_mult : hint_range(0.0, 2.0) = 1.0;

// Weathering controls
uniform float streak_strength : hint_range(0.0, 1.0) = 0.45;
uniform float formwork_strength : hint_range(0.0, 1.0) = 0.25;
uniform float tire_wear_strength : hint_range(0.0, 1.0) = 0.35;
uniform float ground_dirt_strength : hint_range(0.0, 1.0) = 0.40;

varying vec3 v_local_pos;
varying vec3 v_world_pos;
varying vec3 v_normal;

// Simple fast pseudo-random hash & value noise
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Triplanar sampling
vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = NORMAL;
}

void fragment() {
	// Triplanar blend weights
	vec3 blend_weights = abs(v_normal);
	blend_weights = pow(blend_weights, vec3(4.0));
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);

	vec3 tri_pos = v_local_pos * uv_scale;

	vec4 tex_alb = triplanar_texture(concrete_albedo, blend_weights, tri_pos);
	vec4 tex_norm = triplanar_texture(concrete_normal, blend_weights, tri_pos);
	vec4 tex_rough = triplanar_texture(concrete_roughness, blend_weights, tri_pos);

	vec3 col = tex_alb.rgb * concrete_color.rgb;
	float rough = tex_rough.r * roughness_mult;

	// 1. Vertical rain / water drainage streaks on side & back walls
	float wall_mask = clamp(1.0 - abs(v_normal.y) * 1.8, 0.0, 1.0);
	if (wall_mask > 0.01) {
		float wall_u = (abs(v_normal.x) > abs(v_normal.z)) ? v_local_pos.z : v_local_pos.x;
		float wall_v = v_local_pos.y;
		
		// Multi-octave vertical runoff streaks
		float s1 = vnoise(vec2(wall_u * 3.5, wall_v * 0.12));
		float s2 = vnoise(vec2(wall_u * 8.0, wall_v * 0.25));
		float s3 = vnoise(vec2(wall_u * 16.0, wall_v * 0.5));
		float streaks = s1 * 0.5 + s2 * 0.35 + s3 * 0.15;
		
		// Dripping stains below top ledges
		float top_drip = smoothstep(1.5, 0.0, abs(fract(wall_v / 1.5) - 0.95)) * 0.3;
		float dark_streak = smoothstep(0.38, 0.72, streaks + top_drip);

		// Formwork board seams: horizontal boards every 1.5m, vertical panel breaks every 2.8m
		float board_coord = wall_v / 1.5;
		float board_dist = abs(fract(board_coord) - 0.5) * 2.0;
		float board_seam = 1.0 - smoothstep(0.01, 0.07, board_dist);

		float panel_coord = (wall_u + 10.0) / 2.8;
		float panel_dist = abs(fract(panel_coord) - 0.5) * 2.0;
		float panel_seam = 1.0 - smoothstep(0.01, 0.07, panel_dist);
		float formwork = max(board_seam * 0.7, panel_seam * 0.5);

		// Apply wall weathering
		col = mix(col, col * (1.0 - streak_strength * 0.75), dark_streak * wall_mask);
		col = mix(col, col * 0.65, formwork * formwork_strength * wall_mask);
		rough = mix(rough, clamp(rough + 0.2, 0.0, 1.0), dark_streak * wall_mask);
	}

	// 2. Tire wear tracks & deck weathering on upward facing road deck
	float deck_mask = clamp(v_normal.y * 1.6 - 0.2, 0.0, 1.0);
	if (deck_mask > 0.01) {
		float z = v_local_pos.z;
		// Two distinct wheel wear paths: centered at z = -1.6m and z = +1.6m (width ~1.4m each)
		float track_l = 1.0 - smoothstep(0.0, 0.85, abs(z - (-1.65)));
		float track_r = 1.0 - smoothstep(0.0, 0.85, abs(z - 1.65));
		float tire_track = clamp(track_l + track_r, 0.0, 1.0);
		
		// Noise along track length to simulate patchy rubber build-up and skid wear
		float track_noise = 0.75 + 0.25 * vnoise(vec2(v_local_pos.x * 0.7, z * 2.5));
		tire_track *= track_noise;

		// Center strip between tires is slightly lighter / cleaner
		float center_strip = 1.0 - smoothstep(0.0, 0.6, abs(z));
		col = mix(col, col * 1.08, center_strip * 0.25 * deck_mask);

		// Darken rubber wear tracks and make slightly smoother
		col = mix(col, col * 0.58, tire_track * tire_wear_strength * deck_mask);
		rough = mix(rough, rough * 0.75, tire_track * tire_wear_strength * deck_mask);

		// Grime / moss accumulation along curb gutters
		float gutter = smoothstep(2.9, 3.5, abs(z));
		col = mix(col, col * vec3(0.62, 0.65, 0.55), gutter * 0.45 * deck_mask);
	}

	// 3. Ground contact splash / dirt darkening along base
	float ground_factor = 1.0 - smoothstep(-0.2, 0.8, v_local_pos.y);
	col = mix(col, col * vec3(0.55, 0.52, 0.48), ground_factor * ground_dirt_strength);

	// 4. Subtle edge highlight on top corners
	if (v_local_pos.y > 0.5 && (abs(v_local_pos.z) > 3.4 || v_local_pos.x > 7.9)) {
		float edge_noise = vnoise(v_local_pos.xz * 4.0);
		col = mix(col, col * 1.15, edge_noise * 0.3);
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.1, 0.95);
	SPECULAR = 0.25;
	
	// Triplanar normal mapping
	vec3 nm = tex_norm.rgb * 2.0 - 1.0;
	NORMAL = normalize(mix(NORMAL, NORMAL + (TANGENT * nm.x + BINORMAL * nm.y) * normal_strength, 0.6));
}
