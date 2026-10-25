shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The Canyon Course's ground (regenerate_canyon.gd): one heightfield carrying the desert floor, the
// sandstone of every cliff and ledge, the river's sand bars, and both kinds of road, the tarmac and
// the gravel. The roads are painted, not separate meshes: the generator grades the ground flat under
// them and bakes where they are into the vertex data (as on Mara Crossing), so the road is exactly
// the surface the cars drive on and the edges stay sharp however coarse the grid.
//   COLOR.r - rock: cliffs, ledges and rubble (the sandstone beds of canyon_strata.gdshaderinc)
//   COLOR.g - road band: 1 near a road centreline, where COLOR.a is valid
//   COLOR.b - sand: the river's bars and banks, wind-blown drifts
//   COLOR.a - on the road band: signed metres across the road, as a / 24 + 0.5
//   UV2.x   - metres along the lap; UV2.y - 1 where the road is paved, 0 on gravel
// The Puente's deck carries the same data and this material, so its tarmac matches the road's.

uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Red rubble: the desert pavement of stones over most of the flats.
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 sand_tint : source_color = vec4(0.78, 0.49, 0.34, 1.0);
uniform vec4 pale_sand : source_color = vec4(0.85, 0.66, 0.50, 1.0);
uniform vec4 gravel_tint : source_color = vec4(1.0, 0.92, 0.86, 1.0);
uniform vec4 scrub_tint : source_color = vec4(0.46, 0.44, 0.30, 1.0);
uniform vec4 river_sand : source_color = vec4(0.74, 0.63, 0.50, 1.0);
uniform vec4 wet_sand : source_color = vec4(0.42, 0.33, 0.25, 1.0);
// The river's cobbles (a tint on the pebble rubble), the silt over its bed, and its surface's height.
uniform vec4 river_gravel : source_color = vec4(0.62, 0.58, 0.54, 1.0);
uniform vec4 silt_bed : source_color = vec4(0.40, 0.36, 0.26, 1.0);
uniform float river_y = 0.0;
uniform vec4 asphalt_tint : source_color = vec4(0.46, 0.44, 0.43, 1.0);
uniform vec4 line_white : source_color = vec4(0.90, 0.89, 0.84, 1.0);
uniform vec4 line_yellow : source_color = vec4(0.92, 0.70, 0.18, 1.0);
uniform vec4 road_gravel : source_color = vec4(0.84, 0.70, 0.58, 1.0);
uniform vec4 road_dust : source_color = vec4(0.82, 0.64, 0.50, 1.0);
uniform float road_half_width = 7.0;
// Edge lines this far out from the centre; the yellow pair this far either side of it.
uniform float edge_line = 6.3;
uniform float centre_gap = 0.13;

uniform vec4 horizon_color : source_color = vec4(0.78, 0.72, 0.70, 1.0);
uniform vec2 horizon_center = vec2(200.0, -100.0);
uniform float horizon_start = 1600.0;
uniform float horizon_end = 4200.0;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;
varying vec2 road_uv;

#include "res://canyon_strata.gdshaderinc"

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
	road_uv = UV2;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(90.0, 700.0, cam_dist);
	vec2 xz = w_pos.xz;
	float face_ny = abs(normalize(cross(dFdx(w_pos), dFdy(w_pos))).y);
	float slope_ny = min(n.y, face_ny);
	// The pixel's size in metres, for the rock's patterns (taken here: the rock is drawn in a branch).
	float fw = length(fwidth(w_pos));

	// --- Desert floor: red sand under a pavement of stones, a little dry scrub --------------
	// sand.png is near flat colour: the floor's grain comes from the rubble and the noise.
	float patch = cs_fbm(xz * 0.0055);
	float patch2 = cs_fbm(xz * 0.021 + 11.0);
	float patch3 = cs_fbm(xz * 0.09 + 5.0);
	vec3 sand_c = mix(sand_tint.rgb, pale_sand.rgb, smoothstep(0.5, 0.85, patch) * 0.6);
	sand_c *= 0.88 + 0.2 * patch3;
	vec3 g_near = texture(gravel_tex, xz * 0.31).rgb;
	vec3 g_far = texture(gravel_tex, xz * 0.047).rgb;
	vec3 grav = mix(g_far, mix(g_far, g_near, 0.7), detail) * gravel_tint.rgb * 2.3;
	float pave = smoothstep(0.30, 0.62, patch2) * 0.85;
	vec3 floor_col = mix(sand_c, grav, pave);
	// Varnished pavement: patches where the stones have weathered dark brown.
	float varnished = smoothstep(0.55, 0.75, cs_fbm(xz * 0.013 + 41.0)) * pave;
	floor_col = mix(floor_col, grav * vec3(0.55, 0.48, 0.44), varnished * 0.7);
	// Pale washes of fine sand where water ran.
	float wash = smoothstep(0.6, 0.8, cs_fbm(vec2(xz.x * 0.004 + xz.y * 0.003, xz.y * 0.011 - xz.x * 0.002) + 7.0));
	floor_col = mix(floor_col, pale_sand.rgb * (0.95 + patch3 * 0.1), wash * 0.55);
	// Sparse scrub: darker, greyish-olive specks where the ground holds a little water.
	float scrub = smoothstep(0.62, 0.78, cs_fbm(xz * 0.17 + 23.0)) * smoothstep(0.35, 0.7, patch) * 0.55;
	floor_col = mix(floor_col, scrub_tint.rgb * (0.7 + patch3 * 0.4), scrub * detail);
	// From afar the floor is mottled: patches of scrub, stones and sand too fine to draw one by one.
	float far_mottle = cs_fbm(xz * 0.045 + 13.0);
	floor_col *= mix(1.0, 0.82 + 0.3 * far_mottle, 1.0 - detail * 0.6);
	vec3 albedo = floor_col;
	float rough = 0.95;

	// --- Sandstone: cliffs, ledges and the rubble at their feet -----------------------------
	// Rock shows on the cliffs, and in outcrops and scree on the steeper slopes.
	float outcrop = cs_fbm(xz * 0.05 + vec2(w_pos.y * 0.05, 0.0));
	float steep = 1.0 - smoothstep(0.62 + outcrop * 0.18, 0.86 + outcrop * 0.1, slope_ny);
	float rock_w = clamp(max(masks.r, steep), 0.0, 1.0);
	float rock_h = 0.0;
	if (rock_w > 0.01) {
		vec3 rock = strata_color(w_pos, fw);
		float grain = strata_grain(w_pos, n, 0.07);
		rock *= mix(1.0, clamp(grain, 0.45, 1.5), 0.75 * detail + 0.3);
		rock *= 1.0 - 0.45 * strata_varnish(w_pos, steep, fw);
		// Sand blown onto the ledges.
		float ledge = smoothstep(0.75, 0.92, slope_ny) * smoothstep(0.3, 0.7, cs_fbm(xz * 0.09));
		rock = mix(rock, floor_col, ledge * 0.7);
		albedo = mix(albedo, rock, smoothstep(0.0, 0.7, rock_w));
		rough = mix(rough, 0.9, rock_w);
		rock_h = rock_w;
	}

	// --- The river: bars and beaches, the wet margin, the bed under the water -------------------
	// Bars of river cobbles (rounder and greyer than the red desert pavement) with sand drifted
	// between them, a dark wet band along the waterline, and under the water silt over the cobbles,
	// greener with depth.
	float sand = masks.b;
	float above = w_pos.y - river_y;
	float under = smoothstep(0.02, -0.22, above);
	if (sand > 0.01 || above < 0.6) {
		// The pebble rubble half washed out of its red: river stones are every colour the canyon has.
		vec3 peb = texture(gravel_tex, xz * 0.62).rgb;
		peb = mix(vec3(dot(peb, vec3(0.3, 0.59, 0.11))), peb, 0.45);
		vec3 cobble = peb * river_gravel.rgb * 3.1;
		cobble = mix(cobble, river_sand.rgb * 0.8, 0.25);
		float sandy = smoothstep(0.3, 0.75, cs_fbm(xz * 0.11 + 9.0) + (cs_noise(xz * 0.7) - 0.5) * 0.25);
		vec3 bar = mix(cobble, river_sand.rgb * (0.85 + patch3 * 0.2), sandy * 0.7);
		albedo = mix(albedo, bar, smoothstep(0.0, 0.5, sand) * (1.0 - rock_w * 0.6));
		float edge_wobble = (cs_noise(xz * 0.9) - 0.5) * 0.08;
		float wet = 1.0 - smoothstep(0.03, 0.4, above + edge_wobble);
		// The drift line: a faint band of dried silt and twigs a hand over the water.
		float drift_line = smoothstep(0.32, 0.4, above + edge_wobble) * (1.0 - smoothstep(0.42, 0.55, above + edge_wobble));
		albedo = mix(albedo, albedo * vec3(0.52, 0.50, 0.47), wet);
		albedo = mix(albedo, river_sand.rgb * 0.8, drift_line * 0.35 * smoothstep(0.0, 0.5, sand));
		rough = mix(rough, 0.4, wet);
		vec3 bed = mix(cobble * 0.62, silt_bed.rgb * (0.9 + patch3 * 0.2), smoothstep(-0.15, -0.9, above) * 0.8 + sandy * 0.2);
		bed = mix(bed, bed * vec3(0.72, 0.88, 0.62), smoothstep(-0.3, -1.6, above) * 0.7);
		albedo = mix(albedo, bed, under);
	}

	// --- The roads ------------------------------------------------------------------------------
	float band = masks.g;
	// Derivatives outside the branch: they need every pixel of the quad (CLAUDE.md).
	float lat = (masks.a - 0.5) * 24.0;
	float lw = fwidth(lat) * 0.75 + 0.002;
	if (band > 0.01) {
		float a = abs(lat);
		float wob = (cs_fbm(xz * 0.11) - 0.5) * 0.7;
		// Where the tarmac gives out it crumbles into the gravel rather than stopping on a line.
		float paved = smoothstep(0.42, 0.58, road_uv.y + (cs_fbm(xz * 0.22) - 0.5) * 0.9 + (cs_noise(xz * 1.3) - 0.5) * 0.2);

		// Tarmac: sun-bleached, sand blown in along its edges, the lanes darker where tyres run.
		float t_edge = road_half_width - 0.05 + wob * 0.15;
		float on_tar = 1.0 - smoothstep(t_edge - 0.12, t_edge + 0.1, a);
		vec3 tar = texture(asphalt_tex, xz * 0.21).rgb * asphalt_tint.rgb * 2.0;
		tar = mix(tar, texture(asphalt_tex, xz * 0.043).rgb * asphalt_tint.rgb * 2.0, 0.35);
		float lane_wear = smoothstep(1.3, 0.3, abs(a - 3.2)) * detail;
		tar *= 1.0 - 0.12 * lane_wear;
		float drift = smoothstep(road_half_width - 1.6, road_half_width, a + wob) * smoothstep(0.35, 0.7, cs_fbm(xz * 0.2 + 3.0));
		tar = mix(tar, floor_col * 0.95, drift * 0.55);
		// Lines: white at the edges, a pair of yellow down the middle.
		float white = smoothstep(0.09 + lw, 0.075 - lw, abs(a - edge_line));
		float yellow = smoothstep(0.065 + lw, 0.05 - lw, abs(a - centre_gap));
		float wear = 0.75 + 0.25 * smoothstep(0.25, 0.6, cs_fbm(vec2(road_uv.x * 0.5, lat * 2.0)));
		tar = mix(tar, line_white.rgb, white * wear * (1.0 - drift * 0.6));
		tar = mix(tar, line_yellow.rgb, yellow * wear);

		// Gravel road: compacted dust over small stones, two pairs of wheel tracks, loose stones
		// windrowed to the edges.
		float g_edge = road_half_width + 0.4 + wob;
		float on_grav = 1.0 - smoothstep(g_edge - 0.5, g_edge + 0.4, a);
		vec3 g = texture(dirt_tex, xz * 0.34).rgb * road_gravel.rgb * 1.75;
		g = mix(g, texture(dirt_tex, xz * 0.071).rgb * road_gravel.rgb * 1.75, 0.35);
		// Traffic grinds the surface to a pale dust that lies over the stones.
		g = mix(g, road_dust.rgb * (0.9 + patch3 * 0.15), 0.5);
		g *= 0.92 + cs_fbm(xz * 0.06) * 0.16;
		float ruts = max(smoothstep(0.8, 0.2, abs(a - 1.7 + wob * 0.4)), smoothstep(0.8, 0.2, abs(a - 4.7 + wob * 0.4)));
		ruts *= (0.6 + 0.4 * cs_fbm(xz * 0.3)) * detail;
		g *= 1.0 - 0.2 * ruts;
		float windrow = smoothstep(1.4, 0.3, abs(a - (g_edge - 0.8))) * 0.3;
		g = mix(g, g * vec3(1.12, 1.08, 1.04), windrow);

		vec3 road = mix(g, tar, paved);
		// Under the river the track is only the bed it crosses: no edges in the water.
		float on_road = mix(on_grav, on_tar, paved) * band * (1.0 - under * 0.9);
		// Dust from the traffic settles on the verges.
		float dust = (1.0 - smoothstep(g_edge, g_edge + 4.0 + wob * 2.0, a)) * band * (1.0 - paved * 0.6) * (1.0 - under);
		albedo = mix(albedo, mix(albedo, g, 0.45), dust * (1.0 - rock_w * 0.5));
		albedo = mix(albedo, road, on_road);
		rough = mix(rough, mix(mix(0.9, 0.8, ruts), 0.86, paved), on_road);
		rock_h *= 1.0 - on_road;
		sand *= 1.0 - on_road;
	}

	albedo = mix(albedo, horizon_color.rgb,
			clamp((length(xz - horizon_center) - horizon_start) / max(horizon_end - horizon_start, 1.0), 0.0, 1.0) * 0.85);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	// The stones' normal map, laid from above: it fades on rock and on steep faces, where it would
	// streak.
	NORMAL_MAP = texture(gravel_normal, xz * 0.31).rgb;
	NORMAL_MAP_DEPTH = 0.7 * detail * (1.0 - rock_h * 0.7) * (1.0 - steep * 0.75);
	SPECULAR = 0.3;
}
