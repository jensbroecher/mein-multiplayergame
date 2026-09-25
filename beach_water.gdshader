shader_type spatial;
render_mode cull_back, depth_draw_never, blend_mix, specular_schlick_ggx;

// Beach ocean water with physical rolling swell waves and whitecap foam
uniform vec3 deep_water_color : source_color = vec3(0.025, 0.18, 0.38);
uniform vec3 mid_water_color : source_color = vec3(0.06, 0.44, 0.58);
uniform vec3 shallow_color : source_color = vec3(0.14, 0.68, 0.74);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
uniform vec3 sky_tint : source_color = vec3(0.60, 0.74, 0.88);

uniform float sky_reflect : hint_range(0.0, 1.0) = 0.50;
uniform float transparency : hint_range(0.0, 1.0) = 0.25;
uniform float metallic : hint_range(0.0, 1.0) = 0.55;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;

// Rolling waves parameters (waves roll in +X direction towards the beach shore)
// Slower, majestic speed so water level rises and falls realistically
uniform float wave_speed : hint_range(0.05, 2.0) = 0.28;
uniform float wave_amplitude_mult : hint_range(0.0, 3.0) = 1.0;
uniform float wave_steepness : hint_range(1.0, 4.0) = 1.8;

uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform float depth_fade_distance : hint_range(0.5, 30.0) = 6.0;
uniform float shore_foam_threshold : hint_range(0.1, 8.0) = 2.4;

varying float v_wave_height;
varying float v_crest_factor;
varying vec3 v_world_pos;
varying vec3 v_wave_normal;
varying float v_ocean_mask;

const float PI_VAL = 3.14159265359;

// Single Gerstner / trochoidal wave calculation
// Returns vec4(disp_x, disp_y, disp_z, crest_sharpness)
vec4 calc_gerstner_wave(vec2 dir, float wavelength, float amp, float speed, vec2 pos, float time, float steepness) {
	vec2 d = normalize(dir);
	float k = 2.0 * PI_VAL / max(wavelength, 0.1);
	float c = sqrt(9.8 / k); // dispersion relation phase speed
	float f = k * (dot(d, pos) - c * time * speed);
	
	// Trochoidal peaked crest: sharper crests, flatter troughs
	float sin_f = sin(f);
	float cos_f = cos(f);
	float crest = pow(clamp((sin_f + 1.0) * 0.5, 0.0, 1.0), steepness) * 2.0 - 1.0;
	
	// Lateral displacement pulling water toward wave crests
	float q = 0.30;
	vec2 xz_disp = d * (q * amp * cos_f);
	
	float crest_factor = clamp((sin_f + 1.0) * 0.5, 0.0, 1.0);
	return vec4(xz_disp.x, amp * crest, xz_disp.y, crest_factor);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = v_world_pos.xz;
	float t = TIME;

	// Ocean vs Inland mask:
	// The beach shoreline runs around X = -46 to -34.
	// Waves roll at full strength across open ocean and right onto the beach sand (up to X = -32.0),
	// smoothly fading out between X = -32.0 and X = -16.0 as terrain enters the inland dunes.
	// Inland ponds (X > -16.0) receive 0.0 wave displacement so they remain perfectly calm and flat.
	float ocean_mask = 1.0 - smoothstep(-32.0, -16.0, v_world_pos.x);
	v_ocean_mask = ocean_mask;

	// 1. Primary majestic ocean roller (long 52m wavelength, gentle realistic period)
	vec4 w1 = calc_gerstner_wave(vec2(1.0, 0.04), 52.0, 0.52 * wave_amplitude_mult, wave_speed, p, t, wave_steepness);

	// 2. Secondary angled coastal swell (30m wavelength)
	vec4 w2 = calc_gerstner_wave(vec2(0.96, -0.22), 30.0, 0.24 * wave_amplitude_mult, wave_speed * 1.1, p, t, wave_steepness);

	// 3. Shorter surf breaker ripple (15m wavelength)
	vec4 w3 = calc_gerstner_wave(vec2(1.0, 0.02), 15.0, 0.12 * wave_amplitude_mult, wave_speed * 1.25, p, t, wave_steepness * 1.1);

	// In shallow beach water (approaching beach line X = -46), wave height amplifies as swells shoal
	float shore_t = clamp((v_world_pos.x + 95.0) / 50.0, 0.0, 1.0);
	float shoaling = 1.0 + shore_t * 0.40;

	// Total displacements masked by ocean_mask so inland ponds are 100% calm and flat!
	vec2 total_disp_xz = (vec2(w1.x, w1.z) + vec2(w2.x, w2.z) + vec2(w3.x, w3.z)) * shoaling * ocean_mask;
	float total_height = (w1.y + w2.y + w3.y) * shoaling * ocean_mask;

	// Displace vertex mesh
	VERTEX.x -= total_disp_xz.x;
	VERTEX.z -= total_disp_xz.y;
	VERTEX.y += total_height;

	v_wave_height = total_height;
	v_crest_factor = (w1.w * 0.55 + w2.w * 0.3 + w3.w * 0.15) * ocean_mask;

	// Wave normal from derivatives
	float d_eps = 0.6;
	vec4 w1_nx = calc_gerstner_wave(vec2(1.0, 0.04), 52.0, 0.52 * wave_amplitude_mult, wave_speed, p + vec2(d_eps, 0.0), t, wave_steepness);
	vec4 w1_nz = calc_gerstner_wave(vec2(1.0, 0.04), 52.0, 0.52 * wave_amplitude_mult, wave_speed, p + vec2(0.0, d_eps), t, wave_steepness);
	float h_center = total_height;
	float h_x = (w1_nx.y + w2.y + w3.y) * shoaling * ocean_mask;
	float h_z = (w1_nz.y + w2.y + w3.y) * shoaling * ocean_mask;
	vec3 tangent_x = normalize(vec3(d_eps, h_x - h_center, 0.0));
	vec3 tangent_z = normalize(vec3(0.0, h_z - h_center, d_eps));
	v_wave_normal = normalize(cross(tangent_z, tangent_x));
}

void fragment() {
	// Sample micro-ripple normals from noise
	vec2 uv_ripple = v_world_pos.xz * 0.10;
	vec2 motion1 = vec2(TIME * wave_speed * 0.05, TIME * wave_speed * 0.03);
	vec2 motion2 = vec2(-TIME * wave_speed * 0.04, TIME * wave_speed * 0.05);

	vec3 n_tex1 = texture(noise_tex, uv_ripple + motion1).rgb * 2.0 - 1.0;
	vec3 n_tex2 = texture(noise_tex, uv_ripple * 1.6 - motion2).rgb * 2.0 - 1.0;
	vec3 micro_n = normalize(mix(n_tex1, n_tex2, 0.5));

	// Combine wave normal with micro normal
	vec3 base_normal = mix(v_wave_normal, vec3(0.0, 1.0, 0.0), 0.25);
	vec3 final_normal = normalize(base_normal + vec3(micro_n.x, 0.0, micro_n.y) * 0.30);

	// Sample depth buffer to find depth below water surface
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_coords.xyz /= view_coords.w;
	float linear_depth = max(0.0, -view_coords.z + VERTEX.z);

	// Water depth coloring (shallow crystal aqua -> mid turquoise -> deep marine)
	float depth_t = clamp(linear_depth / depth_fade_distance, 0.0, 1.0);
	depth_t = depth_t * depth_t * (3.0 - 2.0 * depth_t);
	vec3 water_col = mix(shallow_color, mid_water_color, clamp(depth_t * 1.5, 0.0, 1.0));
	water_col = mix(water_col, deep_water_color, clamp((depth_t - 0.3) * 1.4, 0.0, 1.0));

	// 1. Shoreline surf foam wash (where water meets the beach sand, only on ocean/beach)
	float shore_foam = (1.0 - smoothstep(0.0, shore_foam_threshold, linear_depth)) * v_ocean_mask;
	// Slow, relaxed tidal rhythm
	float shore_pulse = sin(TIME * wave_speed * 0.8 + v_world_pos.z * 0.12) * 0.5 + 0.5;
	float shore_foam_total = clamp(shore_foam * (0.65 + 0.35 * shore_pulse), 0.0, 1.0);

	// 2. Rolling wave crest whitecaps (traveling with the wave peaks, only on ocean/beach)
	float crest_foam = smoothstep(0.74, 0.94, v_crest_factor);
	float foam_noise = texture(noise_tex, v_world_pos.xz * 0.20 + vec2(TIME * wave_speed * 0.15, 0.0)).r;
	float wave_whitecap = crest_foam * smoothstep(0.35, 0.7, foam_noise) * v_ocean_mask;

	// Combine foam
	float total_foam = clamp(shore_foam_total + wave_whitecap * 0.85, 0.0, 1.0);
	vec3 col_with_foam = mix(water_col, foam_color, total_foam);

	// Fresnel mirror & sun reflection
	float ndotv = clamp(dot(final_normal, normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.5);
	float refl = clamp(fresnel * sky_reflect + sky_reflect * 0.12, 0.0, 1.0);

	vec3 mirror = mix(sky_tint * 1.2, vec3(0.90, 0.95, 1.0), fresnel * 0.4);
	vec3 out_albedo = mix(col_with_foam, mirror, refl * (1.0 - total_foam * 0.8));

	ALBEDO = out_albedo;
	NORMAL = (VIEW_MATRIX * vec4(final_normal, 0.0)).xyz;

	// Transparency: deep water and foamed water are opaque; shallow calm water is slightly translucent
	float base_alpha = mix(1.0 - transparency, 0.98, depth_t);
	ALPHA = mix(base_alpha, 1.0, clamp(total_foam + refl * 0.5, 0.0, 1.0));

	METALLIC = mix(metallic * 0.4, min(metallic + 0.3, 1.0), refl);
	ROUGHNESS = mix(roughness, 0.65, total_foam); // Foam is diffuse rough, water surface is glassy smooth
	SPECULAR = mix(0.7, 0.2, total_foam);
}
