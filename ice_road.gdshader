shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Northlight Caverns road surface: a ploughed ice road at night.
//
// The trunk is packed snow with the polished blue glacier ice showing through where cars
// have scraped it, plus the two wheel ruts every car cuts. Alternative routes are narrower
// and unmarked. UV.x runs 0 (left bank) to 1 (right bank), UV.y is metres along the road,
// so every marking here is authored in normalised road coordinates and scaled back to
// metres with the road's own width.

// Neutral tiling grain only: the colour of this surface comes entirely from the
// procedural snow/ice mix below, so the concrete maps' greyscale detail is used as a
// multiplier and the fracture relief as a normal, and nothing else.
uniform sampler2D grain_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 snow_color : source_color = vec4(0.86, 0.90, 0.98, 1.0);
uniform vec4 ice_color : source_color = vec4(0.48, 0.66, 0.82, 1.0);
uniform vec4 deep_ice_color : source_color = vec4(0.26, 0.44, 0.62, 1.0);
uniform vec4 marker_color : source_color = vec4(0.62, 0.92, 1.00, 1.0);
uniform float trunk_width = 15.0;
uniform float ramp_width = 11.0;
uniform float uv_scale : hint_range(0.01, 2.0) = 0.30;
uniform float ice_exposure : hint_range(0.0, 1.0) = 0.34;
uniform float rut_depth : hint_range(0.0, 1.0) = 0.70;
uniform float snow_roughness : hint_range(0.0, 1.0) = 0.72;
uniform float ice_roughness : hint_range(0.0, 1.0) = 0.26;
uniform float crack_strength : hint_range(0.0, 1.0) = 0.35;
// Metres either side of the start/finish seam left free of paint and scour, so the
// starting grid reads against clean road. The circuit is closed, so this clears the
// run-in and the run-out at both ends of UV.y.
uniform float clear_zone : hint_range(0.0, 200.0) = 32.0;
uniform float circuit_length : hint_range(0.0, 100000.0) = 0.0;
// Aurora fill: the snow is never lit by the moon alone, it picks up the curtain above.
uniform vec4 aurora_tint : source_color = vec4(0.34, 0.58, 0.72, 1.0);
uniform float aurora_amount : hint_range(0.0, 2.0) = 0.35;

varying vec3 w_pos;

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + 11.3;
		a *= 0.5;
	}
	return v;
}

// Cheap ridged noise, used for the fracture lines in the exposed ice.
float ridge(vec2 p) {
	return 1.0 - abs(vnoise(p) * 2.0 - 1.0);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float px = UV.x;
	float py = UV.y;
	bool is_ramp = COLOR.b > 0.5;
	float road_width = mix(trunk_width, ramp_width, is_ramp ? 1.0 : 0.0);

	// Keep the surface isotropic in world space: stretching UV.x by a constant instead
	// smears every feature along the road into long thin bands.
	vec2 base_uv = vec2(px * road_width, py) * uv_scale;
	vec4 grain = texture(grain_texture, base_uv);
	vec3 grain_n = texture(grain_normal, base_uv).rgb;

	// Seam-relative distance from the start/finish line.
	float seam = circuit_length > 1.0 ? min(py, circuit_length - py) : py;
	float scour = smoothstep(clear_zone, clear_zone + 3.0, seam);

	// --- Snow / ice mix ------------------------------------------------------------------
	// Wind packs the drifts down the middle of the road and scours the edges, so the ice
	// exposure is a large-scale pattern rather than uniform noise.
	float drift = fbm(w_pos.xz * vec2(0.055, 0.017));
	float patch = fbm(w_pos.xz * 0.016 + 5.1);
	float streak = fbm(vec2(w_pos.x * 0.9, w_pos.z * 0.16));
	float exposed = clamp((drift - 0.42) * 1.9 + (patch - 0.5) * 0.7 + (streak - 0.5) * 0.5, 0.0, 1.0);
	exposed *= ice_exposure;

	// The two ruts every car cuts: compacted, darker, and far more polished than the
	// untouched snow between them. They follow the lanes rather than the road centre.
	float rut_l = 1.0 - smoothstep(0.0, 0.11, abs(px - 0.30));
	float rut_r = 1.0 - smoothstep(0.0, 0.11, abs(px - 0.70));
	float ruts = clamp(rut_l + rut_r, 0.0, 1.0) * rut_depth * scour;
	exposed = clamp(exposed + ruts * 0.85, 0.0, 1.0);

	// Fine fracture lines, only where the ice is actually showing.
	float cracks = pow(ridge(w_pos.xz * 0.34), 7.0) * exposed;
	float cracks2 = pow(ridge(w_pos.xz * 0.11 + 31.0), 9.0) * exposed * 0.7;

	// --- Markings -----------------------------------------------------------------------
	float dx = fwidth(px) * 1.4;
	float white = 0.0;
	float edge_l_mode = COLOR.r;
	float edge_r_mode = COLOR.g;
	float gore = COLOR.a;

	if (!is_ramp) {
		// Ice-edge markers: short dashes, the way a ploughed ice road is staked out. They
		// break up (and fade out) where a junction opens the bank.
		float dash = step(0.45, fract(py / 4.0));
		float raw_l = 1.0 - smoothstep(0.008, 0.008 + dx, abs(px - 0.075));
		float raw_r = 1.0 - smoothstep(0.008, 0.008 + dx, abs(px - 0.925));
		float act_l = mix(raw_l * dash, raw_l, smoothstep(0.65, 0.85, edge_l_mode));
		float act_r = mix(raw_r * dash, raw_r, smoothstep(0.65, 0.85, edge_r_mode));
		white += act_l * smoothstep(0.20, 0.35, edge_l_mode);
		white += act_r * smoothstep(0.20, 0.35, edge_r_mode);

		// Centre line: a single dashed guide, worn away in the ruts' shadow.
		float cdash = step(0.55, fract(py / 8.0));
		white += (1.0 - smoothstep(0.007, 0.007 + dx, abs(px - 0.5))) * cdash * 0.8;

		// V-shaped chevrons in the gore at a split or merge.
		if (gore > 0.05) {
			float chev = step(0.5, fract((px * 3.2 + py * 0.30) / 1.6));
			float shoulder = clamp(step(0.90, px) + (1.0 - step(0.10, px)), 0.0, 1.0);
			white = max(white, chev * shoulder * gore * 1.6);
		}
	} else {
		// Alternative routes are a bare scraped line: two wheel tracks and nothing else.
		float t1 = 1.0 - smoothstep(0.0, 0.14, abs(px - 0.31));
		float t2 = 1.0 - smoothstep(0.0, 0.14, abs(px - 0.69));
		exposed = clamp(exposed + (t1 + t2) * 0.55 * scour, 0.0, 1.0);
	}

	// --- Albedo --------------------------------------------------------------------------
	float grain_tint = 0.86 + grain.r * 0.28;
	vec3 snow = snow_color.rgb * grain_tint * (0.90 + drift * 0.20 + streak * 0.10);
	vec3 ice = mix(ice_color.rgb, deep_ice_color.rgb, clamp(patch * 1.2, 0.0, 1.0));
	ice *= grain_tint;
	// Ice reads darker in the ruts, where the ice is wet with road film.
	ice = mix(ice, ice * 0.72, ruts);

	vec3 albedo = mix(snow, ice, smoothstep(0.18, 0.78, exposed));
	albedo = mix(albedo, vec3(0.10, 0.22, 0.34), clamp(cracks * crack_strength + cracks2 * crack_strength * 0.6, 0.0, 0.6));
	albedo = mix(albedo, marker_color.rgb, clamp(white, 0.0, 1.0) * scour * (1.0 - exposed * 0.55));

	ALBEDO = albedo;
	ROUGHNESS = mix(snow_roughness, ice_roughness, smoothstep(0.10, 0.65, exposed));
	METALLIC = 0.0;
	SPECULAR = mix(0.25, 0.62, smoothstep(0.10, 0.65, exposed));

	NORMAL_MAP = grain_n;
	// Fade the surface detail out with the texel footprint, otherwise the grain aliases
	// into crawling bands at a grazing angle down the long straights.
	NORMAL_MAP_DEPTH = 0.55 * clamp(1.0 - fwidth(UV.y) * 1.1, 0.10, 1.0);

	// The aurora is the brightest thing in the sky, so the road picks up its colour as a
	// broad tint. Deliberately not tied to any light: it stands in for the sky fill.
	EMISSION = aurora_tint.rgb * aurora_amount * 0.6 * (0.55 + 0.45 * exposed) * albedo;
}