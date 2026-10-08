shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Mara Crossing ground: one heightfield carrying the dry savanna, the red murram road, the
// granite of the kopje and the mud of the river banks.
//
// The road is not a separate mesh. The generator grades the heightfield flat under it and bakes
// the signed distance across the road into the vertex colour; distance across a road is linear
// over a triangle, so the edge drawn here stays sharp however coarse the grid is. The masks:
//   r - granite: exposed rock on the kopje and its boulder aprons
//   g - road band: 1 within reach of a road centreline, so `a` is valid there
//   b - wet: mud on the river banks and lake shore, 1 on the submerged bed
//   a - on the road band: signed metres across the road, as a / 24 + 0.5

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 straw_color : source_color = vec4(0.80, 0.64, 0.36, 1.0);
uniform vec4 pale_straw_color : source_color = vec4(0.88, 0.77, 0.52, 1.0);
uniform vec4 green_grass_color : source_color = vec4(0.50, 0.50, 0.25, 1.0);
uniform vec4 bare_earth_tint : source_color = vec4(1.18, 0.78, 0.56, 1.0);

// Murram: laterite gravel, the red-orange dirt of East African country roads.
uniform vec4 murram_tint : source_color = vec4(1.30, 0.74, 0.52, 1.0);
uniform vec4 rut_tint : source_color = vec4(0.78, 0.66, 0.60, 1.0);
uniform float road_half_width = 7.0;

uniform vec4 granite_color : source_color = vec4(0.64, 0.57, 0.52, 1.0);
uniform vec4 lichen_color : source_color = vec4(0.86, 0.62, 0.30, 1.0);
uniform vec4 mud_color : source_color = vec4(0.25, 0.18, 0.12, 1.0);

uniform vec4 horizon_color : source_color = vec4(0.90, 0.76, 0.58, 1.0);
uniform vec2 horizon_center = vec2(0.0, -40.0);
uniform float horizon_start = 1100.0;
uniform float horizon_end = 2600.0;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
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

vec4 triplanar(sampler2D tex, vec3 p, vec3 w, float s) {
	vec3 bw = pow(abs(w), vec3(6.0));
	bw /= max(bw.x + bw.y + bw.z, 0.0001);
	return texture(tex, p.zy * s) * bw.x + texture(tex, p.xz * s) * bw.y + texture(tex, p.xy * s) * bw.z;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(80.0, 600.0, cam_dist);
	vec2 xz = w_pos.xz;

	// --- Dry savanna grass ------------------------------------------------------------------
	// grass.png is green turf; only its light and shade are used, recoloured to straw.
	float g_near = dot(texture(grass_tex, xz * 0.21).rgb, vec3(0.30, 0.59, 0.11));
	float g_far = dot(texture(grass_tex, xz * 0.031).rgb, vec3(0.30, 0.59, 0.11));
	float g_lum = mix(g_far, mix(g_far, g_near, 0.65), detail) * 2.1;
	float patch = fbm(xz * 0.006);
	float patch2 = fbm(xz * 0.021 + 17.0);
	vec3 grass = mix(straw_color.rgb, pale_straw_color.rgb, smoothstep(0.35, 0.75, patch));
	// Greener where water lies longer: low ground and a few drainage lines.
	grass = mix(grass, green_grass_color.rgb, smoothstep(0.55, 0.85, patch2) * 0.55);
	grass *= 0.72 + g_lum * 0.42;

	// Bare red earth: patches between the tussocks, and every steep bank.
	vec3 earth = texture(dirt_tex, xz * 0.12).rgb * bare_earth_tint.rgb;
	float face_ny = abs(normalize(cross(dFdx(w_pos), dFdy(w_pos))).y);
	float slope_ny = min(n.y, face_ny);
	float bare = smoothstep(0.62, 0.80, fbm(xz * 0.035 + 5.0)) * 0.75;
	bare = max(bare, 1.0 - smoothstep(0.70, 0.86, slope_ny));
	vec3 albedo = mix(grass, earth, bare);
	float rough = 0.94;

	// --- Murram road ------------------------------------------------------------------------
	float band = masks.g;
	if (band > 0.01) {
		float lat = (masks.a - 0.5) * 24.0;
		float wob = (fbm(xz * 0.09) - 0.5) * 0.9;
		float a = abs(lat);
		float edge = road_half_width + wob;
		float on_road = 1.0 - smoothstep(edge - 0.35, edge + 0.25, a);
		vec3 murram = texture(dirt_tex, xz * 0.16).rgb * murram_tint.rgb;
		murram = mix(murram, texture(dirt_tex, xz * 0.045).rgb * murram_tint.rgb, 0.4);
		murram *= 0.88 + fbm(xz * 0.05) * 0.24;
		// Compacted wheel tracks: two per direction, a little darker and smoother.
		float r1 = smoothstep(0.75, 0.15, abs(a - 1.6 + wob * 0.4));
		float r2 = smoothstep(0.75, 0.15, abs(a - 4.6 + wob * 0.4));
		float ruts = max(r1, r2) * (0.6 + 0.4 * fbm(xz * 0.3)) * detail;
		murram = mix(murram, murram * rut_tint.rgb, ruts * 0.75);
		// Loose gravel thrown to the edges by traffic: a lighter windrow just inside the verge.
		float windrow = smoothstep(1.6, 0.3, abs(a - (edge - 0.9))) * 0.35;
		murram = mix(murram, murram * vec3(1.18, 1.10, 1.02), windrow);
		// Red dust settles on the verge grass.
		float dust = (1.0 - smoothstep(edge, edge + 4.5 + wob * 2.0, a)) * band;
		albedo = mix(albedo, mix(albedo, murram * 0.95, 0.55), dust);
		albedo = mix(albedo, murram, on_road * band);
		rough = mix(rough, mix(0.86, 0.74, ruts), on_road * band);
	}

	// --- Granite ----------------------------------------------------------------------------
	float rock_w = masks.r;
	if (rock_w > 0.01) {
		// dark_rock.png only lends its detail: pale weathered granite, grey with a pink cast.
		float r_lum = dot(triplanar(rock_tex, w_pos, n, 0.09).rgb, vec3(0.33));
		float r_lum2 = dot(triplanar(rock_tex, w_pos * 0.31, n, 0.09).rgb, vec3(0.33));
		vec3 granite = granite_color.rgb * (0.55 + 1.6 * mix(r_lum, r_lum2, 0.45));
		granite *= 0.85 + fbm(xz * 0.03 + w_pos.y * 0.05) * 0.3;
		// Streaks of dark weathering down the faces, and soft orange lichen on the tops.
		granite *= 1.0 - smoothstep(0.55, 0.8, fbm(vec2(xz.x + xz.y, w_pos.y * 0.15) * 0.5)) * 0.35 * (1.0 - slope_ny);
		float lichen = smoothstep(0.66, 0.82, fbm(xz * 0.25 + w_pos.y * 0.2)) * smoothstep(0.7, 0.95, slope_ny);
		granite = mix(granite, lichen_color.rgb, lichen * 0.25);
		albedo = mix(albedo, granite, smoothstep(0.0, 0.6, rock_w));
		rough = mix(rough, 0.82, rock_w);
	}

	// --- River mud --------------------------------------------------------------------------
	float wet = masks.b;
	albedo = mix(albedo, albedo * 0.55 + mud_color.rgb * 0.45, smoothstep(0.0, 0.5, wet));
	albedo = mix(albedo, mud_color.rgb * 0.8, smoothstep(0.85, 1.0, wet));
	rough = mix(rough, 0.45, smoothstep(0.3, 0.9, wet));

	albedo = mix(albedo, horizon_color.rgb,
			clamp((length(xz - horizon_center) - horizon_start) / max(horizon_end - horizon_start, 1.0), 0.0, 1.0));

	ALBEDO = albedo;
	ROUGHNESS = rough;
	vec3 nm_dirt = texture(dirt_normal, xz * 0.16).rgb;
	vec3 nm_rock = triplanar(rock_normal, w_pos, n, 0.09).rgb;
	NORMAL_MAP = mix(nm_dirt, nm_rock, smoothstep(0.0, 0.6, rock_w));
	NORMAL_MAP_DEPTH = mix(0.35, 0.9, rock_w) * detail;
	SPECULAR = mix(0.22, 0.45, smoothstep(0.3, 0.9, wet));
}
