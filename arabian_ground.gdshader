shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The Al-Raihana GP's ground (Mountain Pass and Desert Wadi, TerrainGenerator's heightfield, dressed by
// regenerate_mountain_dressing.gd / regenerate_wadi_dressing.gd): warm orange dune sand with wind ripples
// across the shamal, the dark brown rock of the jebel where the ground is steep or high, gravel pans
// (serir) between the dunes, a compacted piste along a lap with no road (Desert Wadi), wet sand by water.
//
// Most of it comes from the world position and normal. What the generator knows and the shader can't
// work out is in `ground_map` (world xz over map_min..map_max):
//   R - the piste: 1 - (metres from the lap's line) / piste_reach, 0 past it (Desert Wadi; 0 on Mountain Pass)
//   G - gravel pan (ArabianTerrain.serir), and the verges the dresser clears
//   B - a yard: packed earth under the buildings, camps and the start (graded pads)
//   A - 1 where the map is valid (outside it everything reads 0)
// Distant detail fades by the pixel's size in metres (fwidth): sharp ripples shimmer.

uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_map : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-1000.0);
uniform vec2 map_max = vec2(1000.0);
uniform bool use_map = false;
// The map's R is the rock (Jebel Sahar: baked from the ground's slope over several metres, so its edge follows the
// mountain, not the 2m grid's triangles, which drew a saw-tooth edge) instead of the piste.
uniform bool map_rock = false;
// With map_rock, the piste comes from a map of its own (R as the ground map's would be): Jebel Sahar's town lanes.
uniform sampler2D piste_map : filter_linear, repeat_disable;
uniform bool use_piste_map = false;
// The piste: packed within piste_in of the lap's line, loose sand again by piste_reach.
uniform float piste_in = 6.0;
uniform float piste_reach = 11.0;

uniform vec4 sand_light : source_color = vec4(0.93, 0.70, 0.47, 1.0);
uniform vec4 sand_deep : source_color = vec4(0.80, 0.52, 0.31, 1.0);
uniform vec4 sand_pale : source_color = vec4(0.95, 0.82, 0.64, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.25, 0.20, 0.17, 1.0);
uniform vec4 rock_light : source_color = vec4(0.48, 0.39, 0.31, 1.0);
uniform vec4 gravel_tint : source_color = vec4(0.70, 0.58, 0.46, 1.0);
uniform vec4 piste_tint : source_color = vec4(0.78, 0.60, 0.43, 1.0);
uniform vec4 yard_tint : source_color = vec4(0.76, 0.64, 0.50, 1.0);
uniform vec4 wet_sand : source_color = vec4(0.48, 0.36, 0.26, 1.0);
// The shamal, which the ripples lie across, and their spacing in metres.
uniform vec2 wind_dir = vec2(0.78, 0.62);
uniform float ripple_spacing = 0.85;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.55;
// Rock: on faces steeper than rock_slope (1 - normal.y), and everywhere over rock_height on slopes
// steeper than high_slope (sand lies only in the hollows of the jebel).
uniform float rock_slope = 0.30;
uniform float rock_height = 1000.0;
uniform float high_slope = 0.07;
// Salt flats (sabkha): level ground below salt_height (Ramlat Hamra's corridors).
uniform float salt_height = -1000.0;
uniform vec4 salt_tint : source_color = vec4(0.86, 0.80, 0.70, 1.0);
// Water's surface (wet sand under rock_height); -1000 for none.
uniform float water_y = -1000.0;

uniform vec4 horizon_color : source_color = vec4(0.86, 0.76, 0.64, 1.0);
uniform float horizon_start = 1500.0;
uniform float horizon_end = 3600.0;

varying vec3 w_pos;
varying vec3 w_nrm;

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

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy * scale).rgb * w.x + texture(tex, p.xz * scale).rgb * w.y + texture(tex, p.xy * scale).rgb * w.z;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float fw = length(fwidth(w_pos));
	float steep = 1.0 - n.y;
	vec2 xz = w_pos.xz;

	vec4 gm = vec4(0.0);
	if (use_map) {
		vec2 muv = (xz - map_min) / (map_max - map_min);
		if (muv.x > 0.0 && muv.y > 0.0 && muv.x < 1.0 && muv.y < 1.0) {
			gm = texture(ground_map, muv);
		}
	}
	float pr = gm.r * gm.a;
	if (use_piste_map) {
		vec2 puv = (xz - map_min) / (map_max - map_min);
		pr = (puv.x > 0.0 && puv.y > 0.0 && puv.x < 1.0 && puv.y < 1.0) ? texture(piste_map, puv).r : 0.0;
	}
	float lat = (1.0 - pr) * piste_reach;
	float piste = (map_rock && !use_piste_map) ? 0.0 : 1.0 - smoothstep(piste_in - 1.0, piste_reach - 1.0, lat);
	float gravel = gm.g * gm.a;
	float yard = gm.b * gm.a;

	// --- Sand: broad tone patches, pale on crests and windward faces, deeper in the hollows and slip faces.
	float broad = fbm(xz * 0.004);
	float mid = fbm(xz * 0.03 + 7.0);
	vec3 sand = mix(sand_deep.rgb, sand_light.rgb, smoothstep(0.3, 0.7, broad));
	vec2 wd = normalize(wind_dir);
	float windward = dot(n.xz, -wd);
	sand = mix(sand, sand_pale.rgb, clamp(windward * 1.6, 0.0, 0.35));
	sand *= 0.92 + 0.16 * mid;
	vec3 grain = texture(sand_tex, xz * 0.25).rgb;
	sand *= mix(vec3(1.0), grain / vec3(0.62, 0.55, 0.45), 0.25 * (1.0 - smoothstep(0.05, 0.4, fw)));

	// --- Ripples: asymmetric crests across the wind, wavering, none on slip faces or where driven.
	float q = dot(xz, wd) / ripple_spacing + (vnoise(xz * 0.21) - 0.5) * 5.0 + (vnoise(xz * 1.3) - 0.5) * 0.8;
	float ph = fract(q);
	// Gentle stoss, steep lee: the slope of the profile along the wind.
	float slope_r = ph < 0.72 ? 1.0 : -2.6;
	float rip_fade = (1.0 - smoothstep(0.08, 0.32, fw / ripple_spacing)) * (1.0 - smoothstep(0.12, 0.28, steep));
	float rip_amt = ripple_strength * rip_fade * (1.0 - piste) * (1.0 - yard) * (1.0 - gravel * 0.8);
	vec3 nrm_world = n;
	nrm_world.xz -= wd * slope_r * 0.22 * rip_amt;
	sand *= 1.0 + (ph < 0.72 ? 0.03 : -0.05) * rip_amt;

	// --- Gravel pans: desert pavement, stones in a sandy matrix.
	vec3 pebbles = triplanar(gravel_tex, w_pos, n, 0.22) * gravel_tint.rgb * 1.5;
	// Stones scattered on a sandy pan: their colour comes through in specks, the pan itself only a little greyer.
	float specks = smoothstep(0.42, 0.62, vnoise(xz * 3.1) * 0.6 + vnoise(xz * 9.7) * 0.4) * (1.0 - smoothstep(0.05, 0.3, fw));
	float gpatch = smoothstep(0.35, 0.65, gravel + (fbm(xz * 0.05) - 0.5) * 0.5);
	vec3 pan = mix(sand * vec3(0.93, 0.92, 0.94), pebbles, 0.25 + 0.4 * specks);
	vec3 col = mix(sand, pan, gpatch * 0.85);

	// --- The piste: compacted, darker sand with tyre tracks along the lap, a soft broken edge.
	float pedge = smoothstep(0.25, 0.75, piste + (vnoise(xz * 0.3) - 0.5) * 0.35);
	// Ruts: tyre tracks at set distances either side of the line, wandering a little; tread within them.
	float wob = (vnoise(xz * 0.07) - 0.5) * 1.6;
	float l2 = lat + wob;
	float ruts = exp(-pow((l2 - 1.3) / 0.45, 2.0)) + exp(-pow((l2 - 3.6) / 0.5, 2.0)) + 0.6 * exp(-pow((l2 - 5.6) / 0.6, 2.0));
	float fine = (0.5 + 0.5 * sin(l2 * 26.0)) * clamp(ruts, 0.0, 1.0);
	float rut_fade = 1.0 - smoothstep(0.1, 0.6, fw);
	vec3 pcol = piste_tint.rgb * (0.88 + 0.14 * fbm(xz * 0.4)) * (1.0 - (0.16 * ruts + 0.05 * fine) * rut_fade);
	col = mix(col, pcol, pedge * 0.92);

	// --- Yards: packed earth with grit.
	float yedge = smoothstep(0.3, 0.7, yard + (vnoise(xz * 0.4) - 0.5) * 0.3);
	col = mix(col, yard_tint.rgb * (0.88 + 0.2 * fbm(xz * 0.6)) * mix(vec3(1.0), pebbles / max(gravel_tint.rgb * 1.5, vec3(0.01)), 0.18), yedge);

	// --- Rock: steep faces, and the jebel above rock_height wherever it isn't a sand-filled hollow.
	float high = smoothstep(rock_height - 8.0, rock_height + 10.0, w_pos.y + (fbm(xz * 0.02) - 0.5) * 14.0);
	// Below the rock line steep sand (slip faces, a pad's graded bank) stays sand, darker; only real cliffs
	// (steeper than sand can stand) are rock there.
	float high_zone = smoothstep(rock_height - 24.0, rock_height, w_pos.y);
	float rock = smoothstep(rock_slope - 0.06, rock_slope + 0.06, steep) * mix(smoothstep(0.55, 0.7, steep), 1.0, high_zone);
	rock = max(rock, high * smoothstep(high_slope - 0.04, high_slope + 0.06, steep + (fbm(xz * 0.09) - 0.5) * 0.12));
	if (map_rock) {
		// Broken up by noise at two scales, so the edge wanders and sand runs up the gullies.
		float mr = gm.r * gm.a + (fbm(xz * 0.045) - 0.5) * 0.45 + (vnoise(xz * 0.4) - 0.5) * 0.12;
		rock = smoothstep(0.42, 0.62, mr);
	}
	col *= 1.0 - 0.12 * smoothstep(0.15, 0.45, steep) * (1.0 - high_zone);
	rock *= 1.0 - yard;
	vec3 rtex = triplanar(rock_tex, w_pos, n, 0.09);
	float strata = fbm(vec2(w_pos.y * 0.35, dot(xz, vec2(0.7, 0.7)) * 0.01));
	vec3 rcol = mix(rock_dark.rgb, rock_light.rgb, smoothstep(0.25, 0.75, strata * 0.6 + fbm(xz * 0.05) * 0.4));
	rcol *= mix(vec3(1.0), rtex / vec3(0.35), 0.45);
	// Wind-blown sand caught on ledges (up-facing rock).
	float dust = smoothstep(0.75, 0.95, n.y) * 0.6;
	rcol = mix(rcol, sand * 0.95, dust);
	col = mix(col, rcol, rock);

	// --- Salt flats: a white crust broken into polygons with darker, damp cracks, sand drifting over its edges.
	if (salt_height > -999.0) {
		float salt = (1.0 - smoothstep(salt_height - 0.6, salt_height + 1.4, w_pos.y + (fbm(xz * 0.03) - 0.5) * 1.6)) * (1.0 - smoothstep(0.03, 0.1, steep));
		salt *= (1.0 - piste) * (1.0 - yard);
		// In patches, not a sheet: crust where the water stood longest, sand blown over the rest.
		salt *= smoothstep(0.38, 0.62, fbm(xz * 0.012 + 3.0) * 0.75 + fbm(xz * 0.07) * 0.25);
		vec2 cell = xz * 0.28;
		vec2 ci = floor(cell);
		float f1 = 9.0;
		float f2 = 9.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 o = vec2(float(i), float(j));
				vec2 pt = o + vec2(hash12(ci + o), hash12(ci + o + 31.7)) * 0.8 + 0.1;
				float dd = length(fract(cell) - pt);
				if (dd < f1) { f2 = f1; f1 = dd; } else if (dd < f2) { f2 = dd; }
			}
		}
		// Ridges of salt pushed up along the polygons' edges (F2 - F1 small), fading with distance.
		float crack = (1.0 - smoothstep(0.0, 0.07, f2 - f1)) * (1.0 - smoothstep(0.05, 0.25, fw));
		vec3 scol = salt_tint.rgb * (0.92 + 0.1 * fbm(xz * 0.2));
		scol = mix(scol, scol * vec3(0.78, 0.74, 0.68), crack * 0.6);
		col = mix(col, scol, salt * 0.85);
		nrm_world = mix(nrm_world, n, salt);
	}

	// --- Wet sand by water.
	if (water_y > -999.0) {
		float wet = 1.0 - smoothstep(water_y + 0.05, water_y + 0.9, w_pos.y);
		col = mix(col, wet_sand.rgb, wet * (1.0 - rock));
	}

	// --- Haze toward the horizon (the fog does most of it).
	float dist = length(w_pos.xz - CAMERA_POSITION_WORLD.xz);
	col = mix(col, horizon_color.rgb, smoothstep(horizon_start, horizon_end, dist) * 0.6);

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.93, 0.86, piste), 0.8, rock);
	SPECULAR = 0.3;
	// Detail normals: the rock's texture, the sand's grain close up.
	vec3 rn = triplanar(rock_normal, w_pos, n, 0.09) * 2.0 - 1.0;
	vec3 sn = texture(sand_normal, xz * 0.25).rgb * 2.0 - 1.0;
	nrm_world += vec3(rn.x, 0.0, rn.y) * 0.35 * rock * (1.0 - smoothstep(0.1, 0.6, fw));
	nrm_world += vec3(sn.x, 0.0, sn.y) * 0.15 * (1.0 - rock) * (1.0 - smoothstep(0.03, 0.2, fw));
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(nrm_world), 0.0)).xyz);
}
