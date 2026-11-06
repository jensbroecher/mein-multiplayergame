shader_type spatial;
render_mode cull_back, depth_draw_never, blend_mix, diffuse_burley, specular_schlick_ggx;
// Rheinufer's Rhine (regenerate_rheinufer.gd, _build_rhine): a broad, fast lowland river under a low evening sun. The
// current runs along `flow_dir` at `flow_speed`: ripples in world metres stretched along it and carried downstream,
// slow boils welling up and drifting with it, long smooth "current lanes" where the surface is glassier, and the
// olive-brown body of a river that carries silt. The sky and the sun come from Godot's reflections (low roughness,
// Fresnel); the colour under them is the water's body. Where it meets the bank, a groyne or a hull (the depth
// texture, read unfiltered) it laps in a lighter line. A pixel along a silhouette counts as deep (CLAUDE.md, water
// edges), so nothing in front of the water gets a white rim.

uniform sampler2D noise_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec3 body_color : source_color = vec3(0.075, 0.085, 0.055);
uniform vec3 deep_color : source_color = vec3(0.035, 0.050, 0.040);
uniform vec3 shallow_color : source_color = vec3(0.17, 0.16, 0.10);
uniform vec3 lap_color : source_color = vec3(0.42, 0.40, 0.32);
uniform vec2 flow_dir = vec2(0.0, -1.0);
uniform float flow_speed = 1.6;
// Metres covered by one repeat of the ripple texture (across the current; along it they are stretched).
uniform float ripple_tile = 18.0;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
// The river's middle and half width (world x): shallower, lighter water toward the banks.
uniform float river_mid = 0.0;
uniform float river_half = 180.0;

varying vec3 w_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 fd = normalize(flow_dir);
	vec2 fs = vec2(-fd.y, fd.x);
	vec2 p = w_pos.xz;
	// Flow coordinates: u along the current, v across it.
	float u = dot(p, fd);
	float v = dot(p, fs);
	float t = TIME * flow_speed;
	// Two layers carried downstream at different speeds (the surface shears), stretched along the current, and a
	// slow cross layer; blended over a period so the texture never visibly slides as one sheet.
	float ph = fract(TIME * 0.05);
	float wa = abs(ph * 2.0 - 1.0);
	vec2 q1 = vec2(v / ripple_tile, (u - t * 1.0) / (ripple_tile * 2.2));
	vec2 q2 = vec2(v / (ripple_tile * 0.47) + 0.31, (u - t * 1.35) / (ripple_tile * 1.1));
	vec3 n1a = texture(noise_tex, q1 + vec2(0.0, ph * 0.6)).rgb;
	vec3 n1b = texture(noise_tex, q1 + vec2(0.5, fract(ph + 0.5) * 0.6)).rgb;
	vec3 n1 = mix(n1a, n1b, wa);
	vec3 n2 = texture(noise_tex, q2).rgb;
	vec3 n3 = texture(noise_tex, vec2(v, u - t * 0.6) / (ripple_tile * 5.0) + 0.17).rgb;
	vec3 nm = (n1 * 2.0 - 1.0) + (n2 * 2.0 - 1.0) * 0.6 + (n3 * 2.0 - 1.0) * 0.7;
	// Boils: slow rings of smooth water welling up and drifting downstream (low-frequency noise carried with the flow).
	float boil = smoothstep(0.62, 0.8, vnoise(vec2(v / 24.0, (u - t * 0.9) / 30.0)));
	// Current lanes: long glassy streaks along the flow.
	float lanes = smoothstep(0.55, 0.75, vnoise(vec2(v / 9.0, (u - t * 1.2) / 140.0)));
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float calm = smoothstep(150.0, 900.0, dist);
	float strength = ripple_strength * mix(1.0, 0.35, calm) * (1.0 - 0.6 * boil) * (1.0 - 0.45 * lanes);
	nm = normalize(vec3(nm.xy * strength, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	// The body: olive brown, darker in the channel, lighter and siltier toward the banks.
	float to_bank = clamp((river_half - abs(w_pos.x - river_mid)) / 45.0, 0.0, 1.0);
	vec3 col = mix(shallow_color, body_color, smoothstep(0.0, 1.0, to_bank));
	col = mix(col, deep_color, 0.35 * smoothstep(0.4, 1.0, (river_half - abs(w_pos.x - river_mid)) / river_half));
	col *= 0.92 + 0.12 * vnoise(vec2(v / 30.0, (u - t * 0.7) / 60.0));
	col = mix(col, col * 1.12, boil * 0.5);

	// Lapping against what stands in the water: the banks, groynes, piers and hulls.
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 vc = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vc.xyz /= vc.w;
	float behind = -vc.z + VERTEX.z;
	if (behind < -0.05) {
		behind = 10.0;
	}
	behind = max(behind, 0.0);
	float lap = 1.0 - smoothstep(0.0, 0.5 + 0.25 * sin(TIME * 1.9 + u * 0.3 + v * 0.2), behind);
	float froth = lap * (0.55 + 0.45 * texture(noise_tex, vec2(v, u - t) * 0.3).r);
	col = mix(col, lap_color, froth * 0.55 * (1.0 - calm));

	ALBEDO = col;
	ROUGHNESS = mix(roughness * (1.0 - 0.5 * lanes), roughness + 0.12, froth);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = mix(0.88, 1.0, smoothstep(0.0, 2.5, behind));
}
