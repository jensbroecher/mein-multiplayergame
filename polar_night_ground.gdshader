shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Terrain shader for Northlight Caverns: a moonlit polar icefield with a frozen lake on
// the start/finish straight and bare rock wherever the ground is too steep to hold snow.
//
// The lake is a blend by ellipse in world space rather than a second mesh, so the shoreline
// is a real gradient in the surface rather than a seam between two coplanar meshes. The
// ellipse is passed in from the generator that built the heightfield, so the two can never
// disagree about where the lake is.

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 snow_color : source_color = vec4(0.80, 0.86, 0.96, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.52, 0.62, 0.80, 1.0);
uniform float rock_gain : hint_range(0.1, 4.0) = 2.1;
uniform vec4 lake_ice_color : source_color = vec4(0.13, 0.30, 0.42, 1.0);
uniform vec4 lake_deep_color : source_color = vec4(0.05, 0.14, 0.24, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.16, 0.24, 0.40, 1.0);
uniform vec4 aurora_tint : source_color = vec4(0.16, 0.55, 0.48, 1.0);

uniform vec2 lake_center = vec2(0.0);
uniform vec2 lake_radius = vec2(200.0, 200.0);
uniform float lake_feather : hint_range(1.0, 200.0) = 26.0;
uniform float snow_line : hint_range(-80.0, 400.0) = 34.0;
uniform float snow_roughness : hint_range(0.0, 1.0) = 0.70;
uniform float rock_roughness : hint_range(0.0, 1.0) = 0.92;
uniform float lake_roughness : hint_range(0.0, 1.0) = 0.10;
uniform float horizon_start : hint_range(100.0, 4000.0) = 520.0;
uniform float horizon_end : hint_range(200.0, 6000.0) = 1150.0;
uniform float normal_strength : hint_range(0.0, 4.0) = 0.7;
uniform float aurora_amount : hint_range(0.0, 2.0) = 0.22;

varying vec3 w_pos;
varying vec3 w_nrm;

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
		p = p * 2.09 + 17.1;
		a *= 0.5;
	}
	return v;
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 w, float s) {
	vec3 bw = pow(abs(w), vec3(6.0));
	bw /= max(bw.x + bw.y + bw.z, 0.0001);
	vec4 cx = texture(tex, p.zy * s);
	vec4 cy = texture(tex, p.xz * s);
	vec4 cz = texture(tex, p.xy * s);
	return cx * bw.x + cy * bw.y + cz * bw.z;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(w_nrm);

	// --- Frozen lake ---------------------------------------------------------------------
	// 1 inside the ellipse, 0 on the snowfield, feathered across the shoreline.
	vec2 lp = (w_pos.xz - lake_center) / max(lake_radius, vec2(1.0));
	float lake_r = length(lp);
	float lake = 1.0 - smoothstep(1.0, 1.0 + lake_feather / max(lake_radius.x, 1.0), lake_r);

	// --- Snow ---------------------------------------------------------------------------
	// Macro drifts, medium hollows, and sastrugi: wind-carved ridges stretched along the
	// prevailing direction so the icefield is not a featureless white sheet.
	float patch = fbm(w_pos.xz * 0.0075);
	float drift = fbm(w_pos.xz * 0.024);
	float sastrugi = fbm(w_pos.xz * vec2(0.32, 0.055));
	float hollow = fbm(w_pos.xz * 0.09 + 3.7);

	float slope_mask = smoothstep(0.42, 0.82, n.y);
	float altitude = 1.0 - smoothstep(snow_line - 26.0, snow_line + 34.0, w_pos.y);
	float breakup = (fbm(w_pos.xz * 0.012) - 0.5) * 0.9 + (drift - 0.5) * 0.4;
	float snow = clamp(slope_mask * (0.5 + altitude * 0.45) + breakup, 0.0, 1.0);
	snow = smoothstep(0.06, 0.70, snow);

	// Snow is not flat white: crests catch the moon, hollows go blue and pick up the rock.
	vec3 snow_col = snow_color.rgb * (0.78 + drift * 0.26 + sastrugi * 0.16 + patch * 0.08);
	snow_col = mix(snow_col, snow_col * vec3(0.88, 0.94, 1.08), hollow * 0.55);

	// --- Rock ---------------------------------------------------------------------------
	float detail = 1.0 - smoothstep(120.0, 620.0, length(w_pos - CAMERA_POSITION_WORLD));
	// Domain-warp the rock sample position, capped because an over-large warp inflates the
	// UV derivative and the engine answers with mip speckle instead of a grid.
	const float rock_scale = 0.085;
	float warp_amp = clamp(2.0 / rock_scale, 0.0, 8.0);
	vec3 wq = w_pos + (vec3(
			fbm(w_pos.xz * 0.011),
			fbm(w_pos.xz * 0.011 + 41.3),
			fbm(w_pos.xz * 0.011 + 87.9)) - 0.5) * warp_amp;
	vec3 rot = vec3(wq.x * 0.82 - wq.z * 0.57, wq.y, wq.x * 0.57 + wq.z * 0.82);
	float tone = 0.70 + fbm(w_pos.xz * 0.004) * 0.44 + fbm(w_pos.xz * 0.023) * 0.22;
	vec3 rock_far = vec3(0.34) * tone * rock_tint.rgb;
	// Half of the tiled rock is collapsed toward its own mean: a single 12m texture repeated
	// across a 50m ice face reads as a honeycomb, and no amount of domain warping hides a repeat
	// this regular. Keeping the mean and dropping the contrast keeps the large tonal variation
	// (which is what actually makes rock look like rock) and loses the pattern.
	vec3 rock_near = mix(vec3(0.55), triplanar(rock_albedo, rot, n, rock_scale).rgb, 0.5) * rock_tint.rgb * rock_gain;
	vec3 rock = mix(rock_far, rock_near, detail);
	rock = mix(rock, rock_near * 0.9, smoothstep(0.35, 0.75, fbm(w_pos.xz * 0.0042)) * detail);
	// Collapse the tiling on the steepest faces. On a near-vertical wall the triplanar projection
	// degenerates towards a single axis and the texture smears into long vertical streaks, which
	// is worse than having no texture at all - so the cliffs get the flat tone and the snow, which
	// is noise-based and directionless, keeps the detail.
	rock = mix(rock, vec3(0.34) * tone * rock_tint.rgb, smoothstep(0.42, 0.86, 1.0 - n.y) * 0.75);

	vec3 albedo = mix(rock, snow_col, snow);
	float rough = mix(rock_roughness, snow_roughness, snow);

	// --- Lake ice -----------------------------------------------------------------------
	// A frozen lake is not water and not snow: it is a dark, very smooth plate with cracks
	// running through it and wind-blown snow lying on top in drifts.
	float crack = pow(1.0 - abs(fbm(w_pos.xz * 0.06 + 13.0) * 2.0 - 1.0), 9.0);
	float crack2 = pow(1.0 - abs(fbm(w_pos.xz * 0.017 + 5.0) * 2.0 - 1.0), 13.0);
	float bubble = smoothstep(0.62, 0.86, fbm(w_pos.xz * 0.30));
	float depth_tint = clamp(fbm(w_pos.xz * 0.012 + 41.0) * 1.3, 0.0, 1.0);
	vec3 lake_col = mix(lake_deep_color.rgb, lake_ice_color.rgb, depth_tint * 0.7 + 0.3);
	lake_col = mix(lake_col, vec3(0.42, 0.55, 0.66), (crack + crack2 * 0.7) * 0.55);
	// Snow blown across the lake collects in the middle and along the shore.
	float lake_snow = clamp(smoothstep(0.52, 0.86, fbm(w_pos.xz * vec2(0.010, 0.030) + 61.0))
			+ (1.0 - smoothstep(0.80, 1.0, lake_r)) * 0.35 + bubble * 0.25, 0.0, 1.0);
	lake_snow *= smoothstep(0.0, 0.35, lake);
	lake_col = mix(lake_col, snow_col * 0.92, clamp(lake_snow, 0.0, 1.0));

	albedo = mix(albedo, lake_col, lake);
	rough = mix(rough, mix(lake_roughness, snow_roughness, clamp(lake_snow, 0.0, 1.0)), lake);

	// Distant terrain melts into the polar night so the range reads as endless rather than
	// as a 1.4km plate with a visible edge.
	albedo = mix(albedo, horizon_color.rgb,
			clamp((length(w_pos.xz) - horizon_start) / max(horizon_end - horizon_start, 1.0), 0.0, 1.0));

	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.03, 1.0);
	METALLIC = 0.0;
	SPECULAR = mix(0.14, 0.55, lake * (1.0 - clamp(lake_snow, 0.0, 1.0)));
	NORMAL_MAP = triplanar(rock_normal, rot, n, 0.11).rgb;
	// The sastrugi relief is authored from the same noise fields that tint the snow, so the
	// bumps line up with the drifts instead of drifting across them.
	// Sastrugi relief only exists where snow can lie: on a cliff face the same pattern smears
	// vertically down the slope and reads as dripping streaks rather than as wind-carved snow.
	float relief = snow * (0.35 + sastrugi * 0.9) * (1.0 - lake * 0.8) * smoothstep(0.30, 0.72, n.y);
	NORMAL_MAP_DEPTH = normal_strength * relief * detail * smoothstep(0.30, 0.62, n.y) * clamp(1.0 - fwidth(w_pos.x) * 0.02 - fwidth(w_pos.z) * 0.02, 0.1, 1.0);

	EMISSION = aurora_tint.rgb * aurora_amount * 0.7 * albedo * (0.6 + 0.4 * lake);
}