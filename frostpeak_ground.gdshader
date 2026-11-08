shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Frostpeak Creek's ground (regenerate_frostpeak_dressing.gd sets it on TerrainGenerator's Terrain_Visual).
// Snow over the whole valley: wind-packed drifts and crust, grey rock where the ground is too steep to
// hold it (the creek's ravine, the cuttings: fractured blocks, drill-hole grooves within a few metres of a
// road, curtains of frozen seepage), and three things only the generator knows, baked into
// `ground_map` (one texel per ~1.8m over the island, map_origin .. map_origin + map_size):
//   r - metres from the nearest road's edge (the trunk's curbs, the shortcuts' decks) / road_reach:
//       the plough's grey spray and slush right beside the road, then the bright windrow it threw up
//   g - woods: how much crown is overhead (needle litter, shade, less fresh snow)
//   b - the village's lanes (Svartvik): trodden, greyer snow with grit
// By its height: shore ice along the waterline (the creek, the fjord round the island), wet dark stones
// just above it, the stony bed under the water.

uniform sampler2D ground_map : filter_linear, repeat_disable;
uniform vec2 map_origin = vec2(-460.0, -460.0);
uniform float map_size = 920.0;
uniform float road_reach = 40.0;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 snow_color : source_color = vec4(0.84, 0.87, 0.93, 1.0);
uniform vec4 crust_color : source_color = vec4(0.76, 0.81, 0.90, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.93, 0.95, 1.0, 1.0);
uniform vec4 slush_color : source_color = vec4(0.50, 0.50, 0.50, 1.0);
uniform vec4 grit_color : source_color = vec4(0.36, 0.32, 0.28, 1.0);
uniform vec4 litter_color : source_color = vec4(0.30, 0.24, 0.17, 1.0);
uniform vec4 ice_color : source_color = vec4(0.66, 0.78, 0.86, 1.0);
uniform vec4 bed_color : source_color = vec4(0.13, 0.14, 0.14, 1.0);
uniform float water_y = -1.2;
uniform float rock_scale : hint_range(0.005, 2.0) = 0.16;
// n.y under which the ground sheds its snow.
uniform float snow_slope : hint_range(0.0, 1.0) = 0.70;
// 0 at the Detail Level's Off: the fine pattern (litter specks, grit, crust ripples) is left out.
uniform float fine_detail : hint_range(0.0, 1.0) = 1.0;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// 3D cellular noise: (distance to the nearest feature point, to the second nearest, the nearest cell's hash).
vec3 cells3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash31(i + g), hash31(i + g + 19.1), hash31(i + g + 47.3));
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = hash31(i + g + 7.7);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 w, float s) {
	vec3 bw = pow(abs(w), vec3(6.0));
	bw /= max(bw.x + bw.y + bw.z, 0.0001);
	vec4 cx = texture(tex, p.zy * s);
	vec4 cy = texture(tex, p.xz * s);
	vec4 cz = texture(tex, p.xy * s);
	return cx * bw.x + cy * bw.y + cz * bw.z;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = (1.0 - smoothstep(70.0, 420.0, cam_dist)) * fine_detail;
	// How many metres a pixel spans here: fine patterns fade to their average once they're smaller.
	float px_m = length(fwidth(w_pos));

	vec4 gm = texture(ground_map, (w_pos.xz - map_origin) / map_size);
	float road_d = gm.r * road_reach;
	float woods = gm.g;

	// --- Snow ------------------------------------------------------------------------------
	float drift = fbm(w_pos.xz * 0.021);
	float patch = fbm(w_pos.xz * 0.0055);
	// Wind crust: streaks along the wind (from the south-west), smoother and bluer than the powder.
	vec2 wd = normalize(vec2(0.62, 0.78));
	vec2 wp = vec2(dot(w_pos.xz, wd), dot(w_pos.xz, vec2(-wd.y, wd.x)));
	float streak = fbm(wp * vec2(0.010, 0.075));
	float crust = smoothstep(0.48, 0.70, streak) * (0.55 + 0.45 * patch);
	vec3 snow_col = snow_color.rgb * (0.91 + drift * 0.13);
	snow_col = mix(snow_col, crust_color.rgb * (0.94 + drift * 0.08), crust * 0.7);
	// Fine ripples in the crust, faded out before they're under a pixel.
	float ripple = vnoise(wp * vec2(0.9, 5.5));
	snow_col *= 1.0 + (ripple - 0.5) * 0.07 * crust * detail * (1.0 - smoothstep(0.04, 0.12, px_m));

	// Woods: needle litter and twigs on the snow, and less fresh powder under the crowns.
	float litter = smoothstep(0.62, 0.92, vnoise(w_pos.xz * 3.1) * 0.6 + fbm(w_pos.xz * 0.4) * 0.6);
	litter *= woods * detail * (1.0 - smoothstep(0.03, 0.10, px_m));
	snow_col = mix(snow_col, snow_col * vec3(0.88, 0.89, 0.92), woods * 0.55);
	snow_col = mix(snow_col, litter_color.rgb, litter * 0.55);
	// The village's lanes: trodden, greyer snow with grit in it.
	float lane = gm.b;
	vec3 trod = snow_col * vec3(0.80, 0.82, 0.86) * (0.9 + vnoise(w_pos.xz * 0.9) * 0.16);
	trod = mix(trod, grit_color.rgb * 1.3, smoothstep(0.7, 0.95, vnoise(w_pos.xz * 2.3)) * 0.3 * detail);
	snow_col = mix(snow_col, trod, lane * 0.9);

	// --- The roads' edges: grey spray and slush, then the plough's windrow -----------------
	float wob = (fbm(w_pos.xz * 0.16) - 0.5) * 1.8;
	float spray = 1.0 - smoothstep(0.4, 3.2, road_d + wob);
	float grit = smoothstep(0.45, 0.85, vnoise(w_pos.xz * 1.7) * 0.5 + fbm(w_pos.xz * 0.6) * 0.6);
	vec3 slush = mix(slush_color.rgb, grit_color.rgb, grit * 0.6) * (0.88 + drift * 0.2);
	slush = mix(slush, snow_col * 0.8, smoothstep(1.2, 3.2, road_d + wob) * 0.6);
	// The windrow: thrown-up snow, brighter and clumpier, a few metres out.
	float windrow = smoothstep(1.8, 3.6, road_d + wob) * (1.0 - smoothstep(5.0, 9.0, road_d + wob * 1.5));
	float clumps = vnoise(w_pos.xz * 1.3);
	snow_col *= 1.0 + windrow * (0.05 + (clumps - 0.5) * 0.10 * detail);
	snow_col = mix(snow_col, slush, spray);

	// --- Snow cover against the slope --------------------------------------------------------
	float breakup = (fbm(w_pos.xz * 0.05) - 0.5) * 0.35 + (drift - 0.5) * 0.2;
	// The steeper of the vertex normal and the triangle's own face: where the terrain's grid meets a road's
	// side wall its triangles stand up in spikes that the averaged vertex normals call gentle.
	vec3 fnrm = normalize(cross(dFdx(w_pos), dFdy(w_pos)));
	float face_ny = abs(fnrm.y);
	float snow = smoothstep(snow_slope - 0.16, snow_slope + 0.10, min(n.y, face_ny) + breakup);

	// --- Rock ------------------------------------------------------------------------------
	vec3 wq = w_pos + (vec3(fbm(w_pos.xz * 0.011), fbm(w_pos.xz * 0.011 + 37.1), fbm(w_pos.xz * 0.011 + 91.7)) - 0.5) * 6.0;
	float tone = 0.78 + fbm(w_pos.xz * 0.006) * 0.35;
	// Grey gneiss: the texture's grain only (its red-brown and its darkness left out), on a lighter grey,
	// the faces broken by 3D noise into blocks and cracks.
	vec3 lum_w = vec3(0.3, 0.55, 0.15);
	float grain = dot(triplanar(rock_albedo, wq, n, rock_scale).rgb, lum_w);
	float grain_far = dot(triplanar(rock_albedo, wq, n, rock_scale * 0.11).rgb, lum_w);
	grain = mix(grain_far, grain, 0.35 + 0.65 * detail);
	vec3 rock = rock_tint.rgb * 0.42 * (0.55 + grain * 1.5) * tone;
	float seep = 0.0;
	float blocks = 0.5;
	// Only where rock shows (a dynamic branch: nothing in it takes derivatives or samples a texture).
	if (snow < 0.995) {
		// Fractured rock: angular blocks in beds (a 3D cellular pattern, wider than tall), each its own shade,
		// dark cracks between them.
		// Coordinates warped a little, so the blocks aren't a regular crazy paving.
		vec3 cp = w_pos * vec3(0.3, 0.55, 0.3) + (vec3(vnoise3(w_pos * 0.4), vnoise3(w_pos * 0.4 + 5.1), vnoise3(w_pos * 0.4 + 9.7)) - 0.5) * 0.6;
		vec3 cl = cells3(cp);
		blocks = cl.z;
		float crack = 1.0 - smoothstep(0.0, 0.05, cl.y - cl.x);
		crack *= 0.4 + 0.6 * vnoise3(w_pos * 1.3);
		rock *= (0.82 + blocks * 0.3) * (1.0 - crack * 0.32 * detail);
		// Blasted road cuttings show the drill holes' half pipes: grooves straight down the face every 0.8m,
		// in broken lengths. Only near a road (the creek's ravine is natural rock).
		float along = abs(fnrm.x) > abs(fnrm.z) ? w_pos.z : w_pos.x;
		float hole_id = floor(along / 0.8);
		float ds = abs(fract(along / 0.8) - 0.5) * 0.8;
		float groove = 1.0 - smoothstep(0.03, 0.07, 0.4 - ds);
		groove *= step(0.35, hash21(vec2(hole_id, floor(w_pos.y / 2.2 + hash21(vec2(hole_id, 3.0)))))) ;
		groove *= (1.0 - smoothstep(6.0, 14.0, road_d)) * (1.0 - smoothstep(0.25, 0.5, abs(fnrm.y))) * detail;
		rock *= 1.0 - groove * 0.35;
		// Frozen seepage: curtains of blue-white ice down the faces of the cuttings and the ravine.
		seep = smoothstep(0.64, 0.78, vnoise3(vec3(w_pos.x * 0.45, w_pos.y * 0.05, w_pos.z * 0.45)) * 0.75
				+ vnoise3(w_pos * vec3(1.4, 0.15, 1.4)) * 0.25);
		rock = mix(rock, ice_color.rgb * (0.85 + blocks * 0.25), seep * 0.85);
		// Snow caught on the blocks' tops.
		float ledge = smoothstep(0.7, 0.9, blocks * 0.6 + n.y * 0.6);
		rock = mix(rock, snow_col * 0.92, ledge * 0.45);
	}

	vec3 albedo = mix(rock, snow_col, snow);
	float rough = mix(mix(0.92, 0.2, seep), mix(0.80, 0.55, crust), snow);
	rough = mix(rough, 0.62, spray * snow);

	// --- The waterline -----------------------------------------------------------------------
	float above = w_pos.y - water_y;
	float shore_n = (fbm(w_pos.xz * 0.09) - 0.5) * 0.5;
	// Wet stones a little above the water, where the snow has melted off.
	float wet = (1.0 - smoothstep(0.25, 1.1, above + shore_n)) * smoothstep(-0.2, 0.15, above);
	float stones = vnoise(w_pos.xz * 2.2) * 0.5 + vnoise(w_pos.xz * 0.7) * 0.5;
	vec3 wet_rock = mix(bed_color.rgb * 1.6, rock * 0.55, 0.5) * (0.7 + stones * 0.5);
	albedo = mix(albedo, wet_rock, wet * (0.55 + 0.45 * smoothstep(0.35, 0.65, stones)));
	rough = mix(rough, 0.35, wet);
	// Shore ice: a rim of ice at the water's edge, wider where the bank is flat.
	float ice = (1.0 - smoothstep(0.02, 0.35, above + shore_n * 0.6)) * smoothstep(-0.55, -0.15, above);
	float cracks = pow(1.0 - abs(fbm(w_pos.xz * 0.12) * 2.0 - 1.0), 12.0);
	vec3 ice_col = ice_color.rgb * (0.88 + fbm(w_pos.xz * 0.05) * 0.2) + vec3(0.25, 0.28, 0.30) * cracks * detail;
	ice_col = mix(ice_col, snow_col, smoothstep(0.55, 0.85, fbm(w_pos.xz * vec2(0.03, 0.12) + 7.0)) * 0.6);
	albedo = mix(albedo, ice_col, ice);
	rough = mix(rough, 0.18, ice);
	// The bed under the water: dark stones and silt.
	float bed = 1.0 - smoothstep(-0.7, -0.35, above);
	albedo = mix(albedo, bed_color.rgb * (0.75 + stones * 0.5), bed);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	vec3 snow_nm = texture(snow_normal, wp * 0.16).rgb;
	vec3 rock_nm = triplanar(rock_normal, wq, n, rock_scale * 1.8).rgb;
	NORMAL_MAP = mix(rock_nm, snow_nm, snow);
	float fade = clamp(1.0 - px_m * 0.25, 0.15, 1.0);
	NORMAL_MAP_DEPTH = mix(0.9, 0.35 + windrow * 0.35, snow) * fade * (1.0 - ice * 0.8) * (0.3 + 0.7 * detail);
	SPECULAR = mix(0.12, mix(0.32, 0.45, crust), snow);
	SPECULAR = mix(SPECULAR, 0.6, max(ice, wet * 0.6));
}
