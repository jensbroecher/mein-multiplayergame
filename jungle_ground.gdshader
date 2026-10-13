shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Msitu Falls ground: one heightfield carrying the rainforest floor, the red laterite road, the
// mud of the Matope, the wet rock of the gorge and the river banks.
//
// As on Mara Crossing, the road is not a separate mesh: the generator grades the heightfield flat
// under it and bakes the signed distance across the road into the vertex colour, so the edge
// drawn here stays sharp on a coarse grid. The masks:
//   r - rock: the cliffs round the falls, the river's slot and every steep cut, 0..1
//   g - road band: 1 within reach of a road centreline, so `a` is valid there
//   b - wet: 0 dry, ~0.6 the Matope's mud, 1 on a submerged bed
//   a - signed metres across the road, as a / 24 + 0.5
// `wetness` (0 dry .. 1 soaked) is driven at runtime by the rain (JungleRain.gd): everything
// darkens and turns glossy, and water stands in the ruts and hollows of the road.

uniform sampler2D soil_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D laterite_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 litter_color : source_color = vec4(0.22, 0.17, 0.10, 1.0);
uniform vec4 litter_dry_color : source_color = vec4(0.36, 0.27, 0.15, 1.0);
uniform vec4 moss_color : source_color = vec4(0.12, 0.22, 0.06, 1.0);
uniform vec4 verge_color : source_color = vec4(0.17, 0.30, 0.07, 1.0);
uniform vec4 laterite_tint : source_color = vec4(1.02, 0.62, 0.50, 1.0);
uniform vec4 rut_tint : source_color = vec4(0.74, 0.64, 0.60, 1.0);
uniform vec4 mud_color : source_color = vec4(0.30, 0.20, 0.11, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.62, 0.62, 0.58, 1.0);
uniform vec4 rock_moss_color : source_color = vec4(0.16, 0.26, 0.09, 1.0);
uniform float road_half_width = 7.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

// Seen from afar the forest is a carpet of crowns: the ground beyond the planted forest is
// painted as one, darkening into the hollows.
uniform vec4 canopy_color : source_color = vec4(0.10, 0.19, 0.06, 1.0);
uniform vec4 canopy_light_color : source_color = vec4(0.20, 0.32, 0.10, 1.0);
uniform vec2 forest_min = vec2(-330.0, -560.0);
uniform vec2 forest_max = vec2(330.0, 220.0);
uniform vec4 horizon_color : source_color = vec4(0.74, 0.80, 0.76, 1.0);
uniform vec2 horizon_center = vec2(0.0, -150.0);
uniform float horizon_start = 900.0;
uniform float horizon_end = 2600.0;

// How much of the fine detail to draw (wheel tracks, the bump of the soil, the red cut banks):
// 1 at the higher levels of detail, lower on slow machines (JungleDetail.gd).
uniform float fine_detail : hint_range(0.0, 1.0) = 1.0;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;
// Broad noise, sampled per vertex (the grid is 2.5m round the lap) and interpolated: the patches
// it drives span metres to tens of metres, and per pixel it cost more than the rest of the shader.
//   noise_a: x moss drifts, y litter and laterite shade, z road edge wobble, w wheel track wander
//   noise_b: x worn-track patches, y hollows the puddles lie in, z/w the far canopy's crowns
varying vec4 noise_a;
varying vec4 noise_b;

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

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
	vec2 xz = w_pos.xz;
	noise_a = vec4(fbm(xz * 0.012), fbm(xz * 0.05 + 31.0), fbm(xz * 0.08), fbm(xz * 0.031 + 11.0));
	noise_b = vec4(fbm(xz * 0.018 + 3.0), fbm(xz * 0.11 + 7.0), fbm(xz * 0.09), fbm(xz * 0.021));
}

// A texture laid on the planes the face is closest to, so a cliff or a cut bank is never a
// smear of a texture projected from above.
vec3 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 x = texture(tex, p.zy * scale).rgb;
	vec3 y = texture(tex, p.xz * scale).rgb;
	vec3 z = texture(tex, p.xy * scale).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(60.0, 500.0, cam_dist);
	vec2 xz = w_pos.xz;
	float face_ny = abs(normalize(cross(dFdx(w_pos), dFdy(w_pos))).y);
	float slope_ny = min(n.y, face_ny);

	// --- Forest floor ------------------------------------------------------------------------
	// Leaf litter in browns and ochres, darker humus between, and moss in drifts across it.
	float s_lum = dot(texture(soil_tex, xz * 0.22).rgb, vec3(0.30, 0.59, 0.11));
	float s_far = dot(texture(soil_tex, xz * 0.035).rgb, vec3(0.30, 0.59, 0.11));
	float s_l = mix(s_far, mix(s_far, s_lum, 0.7), detail) * 2.2;
	float patch = noise_a.x;
	float patch2 = noise_a.y;
	vec3 litter = mix(litter_color.rgb, litter_dry_color.rgb, smoothstep(0.45, 0.8, patch2));
	litter *= 0.62 + s_l * 0.5;
	float m_lum = dot(texture(moss_tex, xz * 0.17).rgb, vec3(0.30, 0.59, 0.11));
	vec3 moss = moss_color.rgb * (0.7 + m_lum * 0.8);
	float moss_w = smoothstep(0.42, 0.68, patch) * 0.85;
	vec3 albedo = mix(litter, moss, moss_w);
	float rough = 0.9;

	// Red earth on the banks the road was cut through, and on any steep slope.
	float bank = 1.0 - smoothstep(0.62, 0.84, slope_ny);
	if (bank > 0.01) {
		vec3 earth = (fine_detail > 0.5 ? triplanar(laterite_tex, w_pos, n, 0.09) : texture(laterite_tex, xz * 0.09).rgb) * laterite_tint.rgb * 0.8;
		albedo = mix(albedo, mix(earth, earth * moss_color.rgb * 3.0, smoothstep(0.5, 0.8, patch2) * 0.4), bank);
	}

	// --- Laterite road ------------------------------------------------------------------------
	float band = masks.g;
	float on_road = 0.0;
	float ruts = 0.0;
	if (band > 0.01) {
		float lat = (masks.a - 0.5) * 24.0;
		float wob = (noise_a.z - 0.5) * 0.9;
		float a = abs(lat);
		float edge = road_half_width + wob;
		on_road = (1.0 - smoothstep(edge - 0.35, edge + 0.25, a)) * band;
		vec3 lat_col = texture(laterite_tex, xz * 0.16).rgb * laterite_tint.rgb;
		lat_col = mix(lat_col, texture(laterite_tex, xz * 0.043).rgb * laterite_tint.rgb, 0.4);
		lat_col *= 0.86 + patch2 * 0.28;
		// Wheel tracks wander and come and go: worn in where everyone takes the same line,
		// faint where the field spreads out.
		float wob2 = (noise_a.w - 0.5) * 2.4;
		float r1 = smoothstep(0.9, 0.2, abs(a - 1.8 + wob2));
		float r2 = smoothstep(0.9, 0.2, abs(a - 4.6 + wob2 * 0.7));
		ruts = max(r1, r2) * smoothstep(0.32, 0.62, noise_b.x) * (0.6 + 0.4 * clamp(s_lum * 2.0, 0.0, 1.0)) * detail * fine_detail;
		lat_col = mix(lat_col, lat_col * rut_tint.rgb, ruts * 0.7);
		// The verges: light reaches the forest floor along the road, so it grows green.
		float verge = (1.0 - smoothstep(edge + 0.2, edge + 5.5 + wob * 2.0, a)) * band * (1.0 - bank);
		vec3 verge_col = verge_color.rgb * (0.65 + m_lum * 0.7);
		albedo = mix(albedo, verge_col, verge * 0.8 * (1.0 - on_road));
		// Red dust and splash on the first metre of the verge.
		float dust = (1.0 - smoothstep(edge, edge + 1.6, a)) * band;
		albedo = mix(albedo, mix(albedo, lat_col * 0.8, 0.5), dust);
		albedo = mix(albedo, lat_col, on_road);
		rough = mix(rough, mix(0.86, 0.72, ruts), on_road);
	}

	// --- Rock --------------------------------------------------------------------------------
	// Anything steeper than ~60 degrees is bare rock, whatever the mask says (the vertex normals the
	// mask was made from are smoothed over two cells, and miss the sharpest faces).
	float rock_w = max(smoothstep(0.05, 0.6, masks.r), 1.0 - smoothstep(0.42, 0.6, slope_ny)) * (1.0 - on_road);
	if (rock_w > 0.01) {
		vec3 rock = triplanar(rock_tex, w_pos, n, 0.07) * rock_tint.rgb;
		rock = mix(rock, triplanar(rock_tex, w_pos, n, 0.017) * rock_tint.rgb, 0.4);
		// Moss on every ledge and on the gentler faces; wet black streaks running down.
		float ledge = smoothstep(0.35, 0.8, n.y);
		float mpatch = smoothstep(0.35, 0.7, fbm(w_pos.xz * 0.11 + w_pos.y * 0.07));
		rock = mix(rock, rock_moss_color.rgb * (0.7 + m_lum * 0.6), max(ledge * 0.8, mpatch * 0.35));
		float streak = smoothstep(0.55, 0.85, vnoise(vec2(w_pos.x * 0.6 + w_pos.z * 0.6, w_pos.y * 0.04)));
		rock *= 1.0 - streak * 0.35 * (1.0 - ledge);
		albedo = mix(albedo, rock, rock_w);
		rough = mix(rough, 0.6, rock_w);
	}

	// --- Mud and wet ground -------------------------------------------------------------------
	float wet = masks.b;
	float mud = smoothstep(0.3, 0.6, wet) * (1.0 - smoothstep(0.85, 1.0, wet));
	// Rain soaks everything a little, and the mud a lot.
	float soak = clamp(wetness * 0.75 + smoothstep(0.0, 0.45, wet), 0.0, 1.0);
	vec3 mud_col = mud_color.rgb * (0.75 + s_l * 0.35);
	// Churned by tyres: darker, smoother bands where the wheels run.
	mud_col = mix(mud_col, mud_col * 0.7, ruts);
	albedo = mix(albedo, mud_col, mud * (0.65 + 0.35 * on_road));
	albedo = mix(albedo, mud_color.rgb * 0.7, smoothstep(0.85, 1.0, wet));
	albedo *= 1.0 - soak * 0.32;
	// Wet, not polished: mud and soaked earth stay fairly matte, or at a racing camera's grazing
	// angle they mirror the whole sky.
	rough = mix(rough, mix(0.62, 0.48, wetness), soak * 0.8);

	// Standing water: in the ruts and hollows of the road when it rains, in a few hollows of
	// the mud always. Muddy water, brown and only half a mirror.
	float hollow = noise_b.y + ruts * 0.18;
	float water_level = 1.12 - wetness * 0.4 - mud * 0.2;
	float puddle = smoothstep(water_level, water_level + 0.04, hollow) * max(on_road, mud) * detail;
	albedo = mix(albedo, vec3(0.05, 0.04, 0.03), puddle * 0.9);
	rough = mix(rough, 0.2, puddle);

	// The forest carpet beyond the planted trees.
	vec2 outside = max(forest_min - xz, xz - forest_max);
	float carpet = smoothstep(-20.0, 40.0, max(outside.x, outside.y)) * (1.0 - rock_w * 0.7);
	if (carpet > 0.001) {
		float crowns = noise_b.z * 0.6 + noise_b.w * 0.4;
		vec3 canopy = mix(canopy_color.rgb, canopy_light_color.rgb, smoothstep(0.35, 0.75, crowns));
		canopy *= 0.75 + 0.5 * clamp(n.y, 0.0, 1.0);
		albedo = mix(albedo, canopy, carpet);
		rough = mix(rough, 0.85, carpet);
	}
	albedo = mix(albedo, horizon_color.rgb,
			clamp((length(xz - horizon_center) - horizon_start) / max(horizon_end - horizon_start, 1.0), 0.0, 1.0));

	ALBEDO = albedo;
	ROUGHNESS = rough;
	NORMAL_MAP = texture(soil_normal, xz * 0.16).rgb;
	NORMAL_MAP_DEPTH = 0.4 * (1.0 - rock_w * 0.6) * (1.0 - puddle) * detail * fine_detail;
	SPECULAR = mix(0.25, 0.36, max(soak * 0.5, puddle));
}
