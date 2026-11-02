shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Mina del Viento's ground (regenerate_mina.gd): one heightfield carrying the plateau's desert floor, the
// escarpment's sandstone, the open pit's benches in copper ore, and both kinds of road, painted (as on the Canyon
// Course: canyon_ground.gdshader, whose desert floor and roads this keeps).
//   COLOR.r - rock: cliffs, cut faces and rubble
//   COLOR.g - road band: 1 near the route's centreline, where COLOR.a is valid
//   COLOR.b - pale sand: the wash's bed and blown patches
//   COLOR.a - on the road band: signed metres across the road, as a / 24 + 0.5
//   UV.x    - how deep the mine has cut here (0 natural ground, 1 a metre or two down): the pit's rock and rubble
//   UV.y    - sand the haboob has drifted over the road
//   UV2.x   - metres along the route; UV2.y - 1 where the road is paved, 0 on gravel
// `storm` (0..1, set by HaboobWeather.gd every frame) blows sand across the ground along `wind_dir`.

uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 sand_tint : source_color = vec4(0.80, 0.60, 0.44, 1.0);
uniform vec4 pale_sand : source_color = vec4(0.90, 0.76, 0.58, 1.0);
uniform vec4 gravel_tint : source_color = vec4(1.0, 0.93, 0.86, 1.0);
uniform vec4 scrub_tint : source_color = vec4(0.50, 0.48, 0.32, 1.0);
uniform vec4 asphalt_tint : source_color = vec4(0.46, 0.44, 0.43, 1.0);
uniform vec4 line_white : source_color = vec4(0.90, 0.89, 0.84, 1.0);
uniform vec4 line_yellow : source_color = vec4(0.92, 0.70, 0.18, 1.0);
// The haul road: crushed rock rolled hard by the trucks, a paler dust over it.
uniform vec4 road_gravel : source_color = vec4(0.78, 0.68, 0.60, 1.0);
uniform vec4 road_dust : source_color = vec4(0.82, 0.70, 0.58, 1.0);
uniform vec4 drift_sand : source_color = vec4(0.88, 0.70, 0.50, 1.0);
uniform float road_half_width = 7.5;
uniform float face_slope : hint_range(0.0, 1.0) = 0.0;
uniform float edge_line = 6.6;
uniform float centre_gap = 0.13;

// The pit: its floor and the plateau's height at its rim, between which the ore's zones lie; the sump's water.
uniform float floor_y = -30.0;
uniform float rim_y = 46.0;
uniform float sump_y = -31.2;
// The sump's middle (x, z) and how far its wet ground reaches.
uniform vec3 sump = vec3(-150.0, -88.0, 60.0);

uniform vec4 horizon_color : source_color = vec4(0.86, 0.72, 0.60, 1.0);
uniform vec2 horizon_center = vec2(-600.0, 50.0);
uniform float horizon_start = 1700.0;
uniform float horizon_end = 4600.0;

// The haboob: how hard sand is blowing here (0..1) and which way (unit, xz).
uniform float storm = 0.0;
uniform vec2 wind_dir = vec2(-0.6, -0.8);

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;
varying vec2 mine_uv;
varying vec2 road_uv;

#include "res://canyon_strata.gdshaderinc"

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
	mine_uv = UV;
	road_uv = UV2;
}

// The copper deposit's rock at `wp` (linear albedo): by depth below the rim, the leached cap (pale, stained orange
// and yellow by iron), the oxide zone (rust and brown, with green malachite and blue-green chrysocolla), and the
// primary ore (grey porphyry, darker and greener with depth). The zones' boundaries wander, and every bench reads
// a shade apart from its neighbours.
vec3 copper_rock(vec3 wp, vec3 n, float fw) {
	float depth = clamp((rim_y - wp.y) / (rim_y - floor_y), 0.0, 1.0);
	float warp = (cs_fbm(wp.xz * 0.011) - 0.5) * 0.22 + (cs_fbm(wp.xz * 0.05 + 3.0) - 0.5) * 0.08;
	float z = depth + warp;
	vec3 cap = mix(vec3(0.84, 0.76, 0.60), vec3(0.80, 0.66, 0.36), smoothstep(0.4, 0.7, cs_fbm(wp.xz * 0.03 + vec2(wp.y * 0.1, 0.0))));
	cap = mix(cap, vec3(0.74, 0.40, 0.22), smoothstep(0.55, 0.78, cs_fbm(vec2(wp.x * 0.02 + wp.y * 0.05, wp.z * 0.02))) * 0.8);
	vec3 oxide = mix(vec3(0.60, 0.32, 0.20), vec3(0.74, 0.48, 0.26), cs_fbm(wp.xz * 0.025 + vec2(0.0, wp.y * 0.08)));
	// Malachite and chrysocolla in streaks along the fractures, not blobs.
	float frac = cs_fbm(vec2(dot(wp.xz, vec2(0.8, 0.6)) * 0.09, wp.y * 0.35) + 8.0);
	float mal = smoothstep(0.68, 0.78, frac) * smoothstep(0.45, 0.65, cs_fbm(wp.xz * 0.02 + 2.0));
	oxide = mix(oxide, vec3(0.30, 0.54, 0.40), mal * 0.7);
	float chr = smoothstep(0.72, 0.8, cs_fbm(vec2(dot(wp.xz, vec2(-0.6, 0.8)) * 0.1, wp.y * 0.4) + 21.0));
	oxide = mix(oxide, vec3(0.26, 0.50, 0.54), chr * 0.55);
	// The primary ore: grey-brown porphyry, greener with depth, stained rust where water ran.
	vec3 primary = mix(vec3(0.60, 0.53, 0.46), vec3(0.47, 0.47, 0.42), smoothstep(0.75, 1.0, z));
	primary *= 0.88 + 0.24 * cs_fbm(wp.xz * 0.04 + vec2(wp.y * 0.07, 9.0));
	primary = mix(primary, vec3(0.62, 0.40, 0.26), smoothstep(0.55, 0.75, cs_fbm(vec2(wp.x * 0.05, wp.y * 0.02 + wp.z * 0.05) + 5.0)) * 0.5);
	vec3 c = mix(cap, oxide, smoothstep(0.24, 0.36, z));
	c = mix(c, primary, smoothstep(0.58, 0.7, z));
	// A shade apart bench by bench (12m apart), and fine darker veins.
	c *= 0.92 + 0.16 * cs_hash(vec2(floor((wp.y - floor_y) / 12.0), 4.0));
	float vein = smoothstep(0.92, 0.98, cs_noise(vec2(dot(wp.xz, vec2(0.7, 0.7)) * 0.3, wp.y * 0.9)));
	c *= 1.0 - 0.25 * vein * (1.0 - smoothstep(0.1, 0.4, fw));
	return cs_srgb(c);
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(90.0, 700.0, cam_dist);
	vec2 xz = w_pos.xz;
	float face_ny = abs(normalize(cross(dFdx(w_pos), dFdy(w_pos))).y);
	float slope_ny = mix(n.y, min(n.y, face_ny), face_slope);
	float fw = length(fwidth(w_pos));
	float mined = mine_uv.x;

	// --- Desert floor: red-tan sand under a pavement of stones, a little dry scrub --------------
	float patch = cs_fbm(xz * 0.0055);
	float patch2 = cs_fbm(xz * 0.021 + 11.0);
	float patch3 = cs_fbm(xz * 0.09 + 5.0);
	vec3 sand_c = mix(sand_tint.rgb, pale_sand.rgb, smoothstep(0.5, 0.85, patch) * 0.6);
	sand_c *= 0.88 + 0.2 * patch3;
	vec3 g_near = texture(gravel_tex, xz * 0.31).rgb;
	vec3 g_far = texture(gravel_tex, xz * 0.047).rgb;
	vec3 grav = mix(g_far, mix(g_far, g_near, 0.7), detail) * gravel_tint.rgb * 2.3;
	float pave = smoothstep(0.30, 0.62, patch2) * 0.6;
	vec3 floor_col = mix(sand_c, grav, pave);
	float varnished = smoothstep(0.55, 0.75, cs_fbm(xz * 0.013 + 41.0)) * pave;
	floor_col = mix(floor_col, grav * vec3(0.62, 0.55, 0.50), varnished * 0.35);
	float scrub = smoothstep(0.62, 0.78, cs_fbm(xz * 0.17 + 23.0)) * smoothstep(0.35, 0.7, patch) * 0.55;
	floor_col = mix(floor_col, scrub_tint.rgb * (0.7 + patch3 * 0.4), scrub * detail);
	float far_mottle = cs_fbm(xz * 0.045 + 13.0);
	floor_col *= mix(1.0, 0.9 + 0.16 * far_mottle, 1.0 - detail * 0.6);
	// Pale blown sand and the wash's bed.
	floor_col = mix(floor_col, pale_sand.rgb * (0.9 + patch3 * 0.15), masks.b * (0.7 + 0.3 * patch2));

	// --- The mine's ground: blasted rubble on the floor and the berms, in the colour of its rock -----------------
	vec3 ore = copper_rock(w_pos, n, fw);
	if (mined > 0.01) {
		vec3 peb = texture(gravel_tex, xz * 0.4).rgb;
		float lum = dot(peb, vec3(0.3, 0.59, 0.11));
		vec3 rubble = ore * (0.55 + lum * 1.6);
		// Fine dust settles on everything the trucks don't scrape: a warm tan over the ore's colour.
		rubble = mix(rubble, mix(ore, vec3(0.62, 0.48, 0.38), 0.6), 0.35 + 0.25 * patch3);
		floor_col = mix(floor_col, rubble, mined);
	}
	vec3 albedo = floor_col;
	float rough = 0.95;

	// --- Rock: the escarpment's sandstone, or the pit's ore where the mine has cut ------------------------------
	float outcrop = cs_fbm(xz * 0.05 + vec2(w_pos.y * 0.05, 0.0));
	float steep = 1.0 - smoothstep(0.62 + outcrop * 0.18, 0.86 + outcrop * 0.1, slope_ny);
	float rock_w = clamp(max(masks.r, steep), 0.0, 1.0);
	float rock_h = 0.0;
	if (rock_w > 0.01) {
		float grain = strata_grain(w_pos, n, 0.07);
		vec3 sand_rock = strata_color(w_pos, fw);
		sand_rock *= 1.0 - 0.45 * strata_varnish(w_pos, steep, fw);
		// The pit's faces: presplit drilling leaves half barrels a metre apart down every face, and water and dust
		// streak it.
		vec2 h_dir = normalize(n.xz + vec2(1e-4));
		float along = dot(xz, vec2(-h_dir.y, h_dir.x));
		float barrel = 0.5 + 0.5 * cos(along * 6.2832 / 1.1);
		vec3 cut = ore * (1.0 - 0.12 * barrel * steep * (1.0 - smoothstep(0.02, 0.09, fw)));
		cut *= 1.0 - 0.2 * strata_varnish(w_pos * vec3(1.0, 1.6, 1.0), steep, fw);
		vec3 rock = mix(sand_rock, cut, smoothstep(0.1, 0.6, mined));
		rock *= mix(1.0, clamp(grain, 0.45, 1.5), 0.75 * detail + 0.3);
		float ledge = smoothstep(0.75, 0.92, slope_ny) * smoothstep(0.3, 0.7, cs_fbm(xz * 0.09));
		rock = mix(rock, albedo, ledge * 0.7);
		albedo = mix(albedo, rock, smoothstep(0.0, 0.7, rock_w));
		rough = mix(rough, 0.9, rock_w);
		rock_h = rock_w;
	}

	// --- The sump: water the pit gathers in its low corner, its edge stained blue-green --------------------------
	float above = w_pos.y - sump_y;
	if (mined > 0.3 && above < 0.8 && length(xz - sump.xy) < sump.z) {
		float wet = 1.0 - smoothstep(0.02, 0.5, above + (cs_noise(xz * 0.8) - 0.5) * 0.1);
		albedo = mix(albedo, albedo * vec3(0.5, 0.62, 0.6), wet);
		float stain = 1.0 - smoothstep(0.0, 0.8, above);
		albedo = mix(albedo, vec3(0.16, 0.42, 0.40), stain * 0.35 * (1.0 - wet));
		albedo = mix(albedo, vec3(0.10, 0.30, 0.30), smoothstep(0.0, -0.6, above));
		rough = mix(rough, 0.35, wet);
	}

	// --- The roads ------------------------------------------------------------------------------
	float band = masks.g;
	float lat = (masks.a - 0.5) * 24.0;
	float lw = fwidth(lat) * 0.75 + 0.002;
	float on_road_w = 0.0;
	float paved = 0.0;
	if (band > 0.01) {
		float a = abs(lat);
		float wob = (cs_fbm(xz * 0.11) - 0.5) * 0.7;
		paved = smoothstep(0.42, 0.58, road_uv.y + (cs_fbm(xz * 0.22) - 0.5) * 0.9 + (cs_noise(xz * 1.3) - 0.5) * 0.2);
		// Tarmac: sun-bleached, sand blown in along its edges, the lanes darker where tyres run.
		float t_edge = road_half_width - 0.05 + wob * 0.15;
		float on_tar = 1.0 - smoothstep(t_edge - 0.12, t_edge + 0.1, a);
		vec3 tar = texture(asphalt_tex, xz * 0.21).rgb * asphalt_tint.rgb * 2.0;
		tar = mix(tar, texture(asphalt_tex, xz * 0.043).rgb * asphalt_tint.rgb * 2.0, 0.35);
		float lane_wear = smoothstep(1.3, 0.3, abs(a - 3.3)) * detail;
		tar *= 1.0 - 0.12 * lane_wear;
		float drift_edge = smoothstep(road_half_width - 1.6, road_half_width, a + wob) * smoothstep(0.35, 0.7, cs_fbm(xz * 0.2 + 3.0));
		tar = mix(tar, floor_col * 0.95, drift_edge * 0.55);
		float white = smoothstep(0.09 + lw, 0.075 - lw, abs(a - edge_line));
		float yellow = smoothstep(0.065 + lw, 0.05 - lw, abs(a - centre_gap));
		float wear = 0.75 + 0.25 * smoothstep(0.25, 0.6, cs_fbm(vec2(road_uv.x * 0.5, lat * 2.0)));
		tar = mix(tar, line_white.rgb, white * wear * (1.0 - drift_edge * 0.6));
		tar = mix(tar, line_yellow.rgb, yellow * wear);

		// Haul road: crushed rock rolled hard, pale dust, the trucks' wheel tracks, its edges in the ground's colour.
		float g_edge = road_half_width + 0.5 + wob;
		float on_grav = 1.0 - smoothstep(g_edge - 0.6, g_edge + 0.5, a);
		vec3 g = texture(dirt_tex, xz * 0.34).rgb * road_gravel.rgb * 1.75;
		g = mix(g, texture(dirt_tex, xz * 0.071).rgb * road_gravel.rgb * 1.75, 0.35);
		g = mix(g, road_dust.rgb * (0.9 + patch3 * 0.15), 0.45);
		// In the pit the road takes the ore's colour, dulled by dust.
		g = mix(g, mix(g, ore * 1.25, 0.45), smoothstep(0.2, 0.8, mined));
		g *= 0.92 + cs_fbm(xz * 0.06) * 0.16;
		float ruts = max(smoothstep(0.9, 0.2, abs(a - 1.9 + wob * 0.4)), smoothstep(0.9, 0.2, abs(a - 5.0 + wob * 0.4)));
		ruts *= (0.6 + 0.4 * cs_fbm(xz * 0.3)) * detail;
		g *= 1.0 - 0.18 * ruts;

		vec3 road = mix(g, tar, paved);
		float on_road = mix(on_grav, on_tar, paved) * band;
		float dust = (1.0 - smoothstep(g_edge, g_edge + 4.0 + wob * 2.0, a)) * band * (1.0 - paved * 0.6);
		albedo = mix(albedo, mix(albedo, g, 0.45), dust * (1.0 - rock_w * 0.5));
		albedo = mix(albedo, road, on_road);
		rough = mix(rough, mix(mix(0.9, 0.8, ruts), 0.86, paved), on_road);
		rock_h *= 1.0 - on_road;
		on_road_w = on_road;
	}

	// --- Sand the haboob drifted over the road: wind ripples across it ---------------------------------------
	float drift = mine_uv.y;
	if (drift > 0.01) {
		vec2 wd = normalize(wind_dir);
		float rip = 0.5 + 0.5 * sin(dot(xz, wd) * 9.0 + cs_noise(xz * 0.6) * 4.0);
		vec3 ds = drift_sand.rgb * (0.9 + 0.1 * rip * detail) * (0.92 + 0.12 * patch3);
		albedo = mix(albedo, ds, smoothstep(0.0, 0.6, drift + (cs_noise(xz * 0.9) - 0.5) * 0.4));
		rough = mix(rough, 0.97, drift);
		rock_h *= 1.0 - drift;
	}

	// --- Blowing sand: ribbons of it snaking along the ground with the wind ----------------------------------
	if (storm > 0.01) {
		vec2 wd = normalize(wind_dir);
		vec2 q = vec2(dot(xz, wd), dot(xz, vec2(-wd.y, wd.x)));
		// Streaks long along the wind, narrow across it, racing downwind; a slower pattern gathers them into gusts.
		vec2 sq = vec2((q.x - TIME * 14.0) * 0.045, q.y * 0.42);
		float streak = cs_fbm(sq + vec2(0.0, cs_noise(vec2(q.x * 0.02 - TIME * 0.4, q.y * 0.05)) * 1.5));
		float gust = smoothstep(0.3, 0.7, cs_fbm(vec2(q.x * 0.008 - TIME * 0.35, q.y * 0.01)));
		float flat_g = smoothstep(0.55, 0.85, slope_ny);
		float near = 1.0 - smoothstep(60.0, 140.0, cam_dist);
		float s_amt = smoothstep(0.45, 0.75, streak) * (0.45 + 0.55 * gust) * flat_g * near * storm;
		albedo = mix(albedo, drift_sand.rgb * 1.08, s_amt * 0.75);
		rough = mix(rough, 1.0, s_amt);
	}

	albedo = mix(albedo, horizon_color.rgb,
			clamp((length(xz - horizon_center) - horizon_start) / max(horizon_end - horizon_start, 1.0), 0.0, 1.0) * 0.85);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	NORMAL_MAP = texture(gravel_normal, xz * 0.31).rgb;
	NORMAL_MAP_DEPTH = 0.7 * detail * (1.0 - rock_h * 0.7) * (1.0 - steep * 0.75);
	SPECULAR = 0.3;
}
