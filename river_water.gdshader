shader_type spatial;
render_mode cull_back, depth_draw_never, blend_mix, specular_schlick_ggx;

// Flowing river water for Frostfall Gorge. The mesh is a ribbon laid along the river:
//   UV.x   - 0..1 across the river
//   UV.y   - metres downstream, so the ripples flow with the current however the river bends
//   COLOR.r - turbulence: 0 in a calm pool, 1 in white rapids and at the falls
//   COLOR.g - current speed, scaling how fast the surface pattern runs downstream
//   COLOR.b - edge fade: 1 where this surface lies over another water surface and should melt
//             into it (pool rim over the river, a gully inlet's mouth), 0 everywhere else

uniform sampler2D noise_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform vec3 deep_color : source_color = vec3(0.010, 0.060, 0.080);
uniform vec3 shallow_color : source_color = vec3(0.035, 0.17, 0.19);
uniform vec3 foam_color : source_color = vec3(0.92, 0.96, 1.0);
uniform vec3 sky_tint : source_color = vec3(0.42, 0.54, 0.64);
uniform float flow_speed = 2.2;
uniform float ripple_scale = 0.11;
uniform float normal_depth = 0.75;
uniform float shore_foam_depth = 0.9;
uniform float clarity_depth = 2.4;

varying vec3 w_pos;
varying float turbulence;
varying float current;
varying float edge_fade;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	turbulence = COLOR.r;
	current = COLOR.g;
	edge_fade = COLOR.b;
	// Standing waves in the rapids: a small bob that drifts slowly, never a flat sheet over rocks.
	float bob = sin(UV.y * 0.9 + TIME * 1.7) * sin(UV.x * 17.0 + UV.y * 0.31);
	VERTEX.y += bob * 0.10 * turbulence;
}

void fragment() {
	float spd = flow_speed * (0.35 + current);
	vec2 flow_uv = vec2(UV.x * 4.0, UV.y * ripple_scale);
	vec3 n1 = texture(noise_tex, flow_uv + vec2(0.0, -TIME * spd * ripple_scale)).rgb;
	vec3 n2 = texture(noise_tex, flow_uv * vec2(1.9, 2.3) + vec2(0.37, -TIME * spd * ripple_scale * 1.6)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5) * 2.0 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_depth * (0.7 + turbulence * 1.6);

	// How much water lies between this surface and the river bed / bank behind it.
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 view_far = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	view_far.xyz /= view_far.w;
	float water_depth = max(0.0, -view_far.z + VERTEX.z);

	float clear = clamp(water_depth / clarity_depth, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, clear));

	// Foam: streaks pulled downstream, densest in rapids, plus a lace where the water meets rock.
	vec2 foam_uv = vec2(UV.x * 3.0, UV.y * 0.045 - TIME * spd * 0.045);
	float streak = texture(foam_noise, foam_uv).r * 0.6 + texture(foam_noise, foam_uv * vec2(2.7, 3.1) + 0.21).r * 0.4;
	float rapid_foam = smoothstep(1.0 - turbulence * 0.85, 1.05 - turbulence * 0.55, streak + turbulence * 0.35);
	float shore = 1.0 - smoothstep(0.0, shore_foam_depth, water_depth);
	float shore_foam = shore * smoothstep(0.35, 0.65, streak + 0.25);
	float foam = clamp(max(rapid_foam, shore_foam * 0.85) + turbulence * 0.25, 0.0, 1.0);

	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 3.0);
	col = mix(col, sky_tint, fresnel * 0.35);
	col = mix(col, foam_color, foam);

	ALBEDO = col;
	ROUGHNESS = mix(0.04, 0.55, foam);
	SPECULAR = mix(0.75, 0.3, foam);
	METALLIC = 0.0;
	// Clear at the very edge so the bank shows through, opaque once there is depth or foam.
	ALPHA = clamp(mix(0.7, 0.97, smoothstep(0.0, 0.8, water_depth)) + foam, 0.0, 1.0);
	// Where two water surfaces overlap, the upper one fades out so they meet without a seam.
	ALPHA *= 1.0 - edge_fade * edge_fade * (3.0 - 2.0 * edge_fade);
	// Foam stays readable in the gorge's shade.
	EMISSION = foam_color * foam * 0.08;
}
