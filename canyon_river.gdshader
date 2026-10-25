shader_type spatial;
render_mode cull_back, depth_draw_never, blend_mix, specular_schlick_ggx, ambient_light_disabled;

// The Canyon Course's river (regenerate_canyon.gd): a desert river carrying silt, olive-green where it
// runs deep and slow, tan-brown where it is shallow or stirred up, never the blue of the sky. The mesh
// is a flat ribbon laid along the river, wider than the water (the banks hide the rest):
//   UV.x    - metres across, + east;  UV.y - metres downstream, so the surface flows with the river
//   COLOR.r - turbulence: 0 in a slow pool, up to 1 over the ford's riffle
//   COLOR.g - current, how fast the surface runs downstream
//
// Ambient light and the sky's radiance map are off: lit by the sky, the water mirrored a blue that a
// canyon river shows only straight up. Its ambient is the shade's colour (EMISSION), and what it
// reflects is drawn here: the sky above a skyline of canyon walls, warm rock below it.

uniform sampler2D noise_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
// Unfiltered: averaged across the banks' silhouettes (filter_linear_mipmap), it read them as deep water and
// painted a dark smear of each bank along the shore.
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

// Silt-laden water lit by the sun (sRGB): tan where it is shallow, olive where it runs deep.
uniform vec3 shallow_color : source_color = vec3(0.47, 0.42, 0.28);
uniform vec3 silt_color : source_color = vec3(0.36, 0.35, 0.22);
uniform vec3 deep_color : source_color = vec3(0.17, 0.21, 0.12);
uniform vec3 foam_color : source_color = vec3(0.86, 0.84, 0.76);
// What the surface reflects: the sky overhead and at the skyline, the canyon's walls below it.
uniform vec3 sky_top : source_color = vec3(0.32, 0.50, 0.78);
uniform vec3 sky_low : source_color = vec3(0.78, 0.78, 0.80);
uniform vec3 wall_color : source_color = vec3(0.50, 0.27, 0.17);
// The shade's light (the ambient the water no longer takes from the sky).
uniform vec3 shade_light : source_color = vec3(0.40, 0.40, 0.44);
// How many metres of water before the bed is lost in the silt.
uniform float visibility = 0.5;
uniform float flow_speed = 1.3;
uniform float ripple_scale = 0.075;
uniform float normal_depth = 0.55;

varying vec3 w_pos;
varying float turbulence;
varying float current;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	turbulence = COLOR.r;
	current = COLOR.g;
	// Standing waves over the riffle: rows across the current that hold their place and shimmer.
	float bob = sin(UV.y * 1.3 + sin(UV.x * 0.4) * 1.5 + TIME * 0.9) * sin(UV.x * 0.9 + UV.y * 0.23 - TIME * 0.6);
	VERTEX.y += bob * 0.05 * turbulence;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float spd = flow_speed * (0.4 + current);
	float t = TIME * spd;
	// Ripples in world metres, carried downstream; a finer chop where it runs fast.
	vec2 uv1 = vec2(UV.x, UV.y) * ripple_scale + vec2(0.0, -t * ripple_scale);
	vec2 uv2 = vec2(UV.x * 1.7 + 3.1, UV.y * 2.3) * ripple_scale + vec2(0.13, -t * ripple_scale * 1.5);
	vec2 uv3 = vec2(UV.x * 5.0, UV.y * 6.5) * ripple_scale + vec2(0.0, -t * ripple_scale * 3.0);
	vec3 n = texture(noise_tex, uv1).rgb * 0.45 + texture(noise_tex, uv2).rgb * 0.35 + texture(noise_tex, uv3).rgb * 0.2;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_depth * (0.6 + turbulence * 2.4 + current * 0.3);

	// Water between this surface and the bed behind it: along the view ray (how much silt the light
	// crosses), and straight down (how shallow it is there: the riffle foams only over the bar).
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 view_far = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	view_far.xyz /= view_far.w;
	float water_depth = max(0.0, -view_far.z + VERTEX.z);
	vec3 bed_w = (INV_VIEW_MATRIX * vec4(view_far.xyz, 1.0)).xyz;
	float vdepth = max(0.0, w_pos.y - bed_w.y);

	// The colour of the water itself: tan in the shallows, olive green with depth, with plumes of
	// silt drifting down it, lighter and browner, and greener slack water along the edges.
	vec2 plume_uv = vec2(UV.x * 0.012, UV.y * 0.006 - t * 0.006);
	float plume = texture(foam_noise, plume_uv).r * 0.6 + texture(foam_noise, plume_uv * 2.3 + 0.37).r * 0.4;
	vec3 col = mix(shallow_color, silt_color, smoothstep(0.05, 0.8, water_depth));
	col = mix(col, deep_color, smoothstep(0.8, 3.0, water_depth));
	col = mix(col, silt_color * vec3(1.12, 1.04, 0.92), smoothstep(0.45, 0.8, plume) * 0.5);
	col = mix(col, deep_color * vec3(0.9, 1.1, 0.9), smoothstep(0.4, 0.15, plume) * 0.25 * (1.0 - turbulence));
	col *= 0.94 + 0.12 * hash12(floor(UV * 0.5));

	// Over the ford's bar the riffle runs rough and lighter, the silt stirred up, with thin broken
	// crests across the current and a little foam where the water spills over the gravel's edge.
	float over_bar = turbulence * (1.0 - smoothstep(0.25, 0.75, vdepth));
	col = mix(col, shallow_color * 1.12, over_bar * 0.5);
	vec2 crest_uv = vec2(UV.x * 0.05, UV.y * 0.2 - t * 0.02);
	float crest_n = texture(foam_noise, crest_uv).r;
	float crests = smoothstep(0.6, 0.9, sin(UV.y * 2.2 + crest_n * 22.0 + sin(UV.x * 0.3) * 2.0) * 0.5 + 0.5) * smoothstep(0.45, 0.75, crest_n);
	// In patches, where the gravel lies highest: not rows across the whole river.
	crests *= smoothstep(0.4, 0.7, texture(foam_noise, vec2(UV.x * 0.02 + 0.5, UV.y * 0.012)).r);
	vec2 foam_uv = vec2(UV.x * 0.09, UV.y * 0.025 - t * 0.025);
	float streak = texture(foam_noise, foam_uv).r * 0.6 + texture(foam_noise, foam_uv * vec2(2.7, 3.1) + 0.21).r * 0.4;
	float spill = smoothstep(0.62, 0.9, streak) * (1.0 - smoothstep(0.05, 0.3, vdepth));
	float foam = clamp((crests * 0.55 + spill * 0.6) * over_bar, 0.0, 1.0);
	col = mix(col, foam_color, foam);

	// The reflection: sky above a skyline of canyon walls (higher one way, lower another), rock below.
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-vw, nw);
	float az = atan(r.x, r.z);
	// A low, gently rolling skyline, blurred: it is made up, so a sharp, wavy one (two sines, up to 0.23
	// high) read as a dark wavy smear along every far shore that matched none of the real banks.
	float skyline = 0.07 + 0.02 * sin(az * 2.0 + 1.3);
	vec3 sky = mix(sky_low, sky_top, smoothstep(skyline, 0.75, r.y));
	vec3 refl = mix(wall_color * (0.8 + 0.2 * smoothstep(-0.2, skyline, r.y)), sky, smoothstep(skyline - 0.09, skyline + 0.12, r.y));
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - ndotv, 5.0);
	fresnel *= 0.75 * (1.0 - foam);

	ALBEDO = col * (1.0 - fresnel);
	ROUGHNESS = mix(0.16 + over_bar * 0.12, 0.6, foam);
	SPECULAR = mix(0.32, 0.15, foam);
	EMISSION = col * shade_light * (1.0 - fresnel) + refl * fresnel * 0.9;
	// The bed shows through only where the water is a hand deep; past that the silt hides it.
	ALPHA = clamp(mix(0.18, 0.96, smoothstep(0.0, visibility, water_depth)) + foam * 0.8 + fresnel, 0.0, 1.0);
}
