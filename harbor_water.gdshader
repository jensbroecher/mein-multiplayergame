shader_type spatial;
render_mode cull_back, depth_draw_never, blend_mix, diffuse_burley, specular_schlick_ggx;
// Harbor Pier's water (TerrainGenerator.add_harbor_water): a sheltered harbour, green and murky, under a low
// afternoon sun. Ripples are sized in world metres (two layers of the noise normal map drifting across each other,
// and a slow swell of long crests from the harbour mouth), so they read the same at the quay's foot and across the
// basin; the ocean shader tiled its chop across the 1400m plane. The sky and the sun come from Godot's own
// reflections (low roughness, Fresnel); the colour under them is the water's body. Where the water meets a quay,
// a pile or a hull (the depth texture, read unfiltered) it laps: a lighter line of churned water. A pixel along a
// silhouette, where something stands in front of the water, counts as deep (CLAUDE.md, water edges).

uniform sampler2D noise_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec3 body_color : source_color = vec3(0.045, 0.105, 0.098);
uniform vec3 deep_color : source_color = vec3(0.018, 0.055, 0.058);
uniform vec3 lap_color : source_color = vec3(0.36, 0.42, 0.38);
// Metres covered by one repeat of the ripple texture; the second layer is 0.43 of it.
uniform float ripple_tile = 26.0;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.42;
uniform float drift = 0.35;
uniform float swell_height = 0.05;
uniform vec2 swell_dir = vec2(0.25, -0.97);
uniform float roughness : hint_range(0.0, 1.0) = 0.06;
// Past this distance from the harbour's middle the colour eases to the open sea's.
uniform vec3 sea_color : source_color = vec3(0.03, 0.09, 0.12);
uniform float sea_from = 260.0;
uniform float sea_to = 520.0;

varying vec3 w_pos;
varying float swell;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float a = dot(w_pos.xz, normalize(swell_dir));
	swell = sin(a * 0.11 - TIME * 0.9) * 0.6 + sin(a * 0.23 + w_pos.x * 0.03 - TIME * 1.3) * 0.4;
	VERTEX.y += swell * swell_height;
}

void fragment() {
	vec2 p = w_pos.xz;
	float t = TIME * drift;
	vec3 n1 = texture(noise_tex, p / ripple_tile + vec2(t, t * 0.6) / ripple_tile).rgb;
	vec3 n2 = texture(noise_tex, p / (ripple_tile * 0.43) - vec2(t * 0.7, -t) / (ripple_tile * 0.43) + 0.37).rgb;
	vec3 n3 = texture(noise_tex, p / (ripple_tile * 4.1) + vec2(-t, t * 0.3) / (ripple_tile * 4.1)).rgb;
	vec3 nm = normalize((n1 * 2.0 - 1.0) + (n2 * 2.0 - 1.0) * 0.7 + (n3 * 2.0 - 1.0) * 0.8);
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	// Far off, the ripples are under a pixel: calm them to their average, or the glitter crawls.
	float calm = smoothstep(120.0, 700.0, dist);
	nm.xy *= ripple_strength * mix(1.0, 0.35, calm);
	nm = normalize(vec3(nm.xy, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	float r = length(p - vec2(5.0, 15.0));
	vec3 col = mix(body_color, sea_color, smoothstep(sea_from, sea_to, r));
	col = mix(col, deep_color, 0.35 + 0.25 * swell);

	// Lapping against what stands in the water.
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 vc = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vc.xyz /= vc.w;
	float behind = -vc.z + VERTEX.z;
	if (behind < -0.05) {
		behind = 10.0;
	}
	behind = max(behind, 0.0);
	float lap = 1.0 - smoothstep(0.0, 0.55 + 0.25 * sin(TIME * 1.7 + p.x * 0.4 + p.y * 0.3), behind);
	float froth = lap * (0.55 + 0.45 * texture(noise_tex, p * 0.35 + vec2(t * 0.5)).r);
	col = mix(col, lap_color, froth * 0.55 * (1.0 - calm));

	ALBEDO = col;
	ROUGHNESS = mix(roughness, roughness + 0.12, froth);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = mix(0.9, 1.0, smoothstep(0.0, 3.0, behind));
}
