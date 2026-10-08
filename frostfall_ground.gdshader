shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Frostfall Gorge ground: one heightfield carrying snowfields, the gorge's rock walls, two frozen
// lakes and the racing line, which has no road on it - only packed snow and tyre ruts.
//
// Snow and rock follow the slope like alpine_snow.gdshader. The generator bakes three masks into
// the vertex colour, because only it knows where the water and the racing line are:
//   r - frozen lake ice (1 on the ice sheet, feathered at the shore)
//   g - packed snow on the racing line (1 on the line, 0 a few metres outside it)
//   b - spray zone: rock and snow near open water, glazed with ice and darker
//   a - signed distance across the racing line, so the ruts can follow it

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 snow_color : source_color = vec4(0.83, 0.87, 0.94, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.92, 0.94, 1.0, 1.0);
uniform float rock_scale : hint_range(0.005, 2.0) = 0.13;
uniform float normal_strength : hint_range(0.0, 4.0) = 0.6;
uniform float snow_slope : hint_range(0.0, 1.0) = 0.70;
uniform float snow_roughness : hint_range(0.0, 1.0) = 0.76;
uniform float rock_roughness : hint_range(0.0, 1.0) = 0.93;

uniform vec4 ice_color : source_color = vec4(0.52, 0.72, 0.84, 1.0);
uniform vec4 ice_deep_color : source_color = vec4(0.16, 0.36, 0.52, 1.0);
uniform float ice_roughness : hint_range(0.0, 1.0) = 0.12;

// Packed snow is greyer and smoother than fresh powder; ruts are where tyres have cut through.
uniform vec4 packed_color : source_color = vec4(0.72, 0.76, 0.82, 1.0);
uniform float rut_strength : hint_range(0.0, 1.0) = 0.55;

uniform vec4 spray_color : source_color = vec4(0.36, 0.44, 0.52, 1.0);

uniform vec4 horizon_color : source_color = vec4(0.80, 0.87, 0.95, 1.0);
uniform vec2 horizon_center = vec2(0.0, -200.0);
uniform float horizon_start : hint_range(100.0, 4000.0) = 900.0;
uniform float horizon_end : hint_range(200.0, 6000.0) = 1500.0;

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
	vec4 cx = texture(tex, p.zy * s);
	vec4 cy = texture(tex, p.xz * s);
	vec4 cz = texture(tex, p.xy * s);
	return cx * bw.x + cy * bw.y + cz * bw.z;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(90.0, 520.0, cam_dist);

	float patch = fbm(w_pos.xz * 0.0075);
	float drift = fbm(w_pos.xz * 0.022);
	float ripple = fbm(w_pos.xz * vec2(0.10, 0.016));

	// --- Snow cover: shallow ground holds it, steep rock sheds it ---------------------------
	float slope_mask = smoothstep(snow_slope - 0.20, snow_slope + 0.18, n.y);
	float breakup = (fbm(w_pos.xz * 0.013) - 0.5) * 0.7 + (drift - 0.5) * 0.35;
	float snow = smoothstep(0.10, 0.70, clamp(slope_mask * 0.98 + breakup * (1.0 - slope_mask * 0.6), 0.0, 1.0));

	// --- Rock -------------------------------------------------------------------------------
	float warp_amp = clamp(3.0 / max(rock_scale, 0.005), 0.0, 9.0);
	vec3 wq = w_pos + (vec3(
			fbm(w_pos.xz * 0.010),
			fbm(w_pos.xz * 0.010 + 37.1),
			fbm(w_pos.xz * 0.010 + 91.7)) - 0.5) * warp_amp;
	vec3 rot1 = vec3(wq.x * 0.80 - wq.z * 0.60, wq.y, wq.x * 0.60 + wq.z * 0.80);
	vec3 rot2 = vec3(wq.x * 0.36 + wq.z * 0.93, wq.y, -wq.x * 0.93 + wq.z * 0.36);
	float tone = 0.70 + fbm(w_pos.xz * 0.004) * 0.42 + fbm(w_pos.xz * 0.022) * 0.22;
	vec3 rock_far = triplanar(rock_albedo, rot2, n, rock_scale * 0.083).rgb * rock_tint.rgb;
	vec3 rock_near = triplanar(rock_albedo, wq, n, rock_scale).rgb * rock_tint.rgb;
	rock_near = mix(rock_near, triplanar(rock_albedo, rot1, n, rock_scale * 0.29).rgb * rock_tint.rgb,
			smoothstep(0.30, 0.70, fbm(w_pos.xz * 0.0040)));
	vec3 rock = mix(rock_far, rock_near, detail);
	rock = mix(vec3(0.30) * tone * rock_tint.rgb, rock, 0.45 + 0.55 * detail);
	// Horizontal banding on the walls, so the gorge reads as sediment layers cut by the river.
	rock *= 0.92 + 0.10 * sin(w_pos.y * 0.45 + fbm(w_pos.xz * 0.02) * 6.0);

	vec3 snow_col = snow_color.rgb * (0.82 + drift * 0.24 + ripple * 0.10);
	snow_col = mix(snow_col, snow_col * vec3(0.90, 0.94, 1.04), patch * 0.6);

	// --- Racing line: packed snow with tyre ruts, no road ----------------------------------
	float line_w = masks.g;
	float ruts = 0.0;
	if (line_w > 0.02) {
		// Signed metres across the line, baked by the generator into alpha (0.5 = centre).
		float lat = (masks.a - 0.5) * 24.0 + (fbm(w_pos.xz * 0.06) - 0.5) * 1.4;
		float a = abs(lat);
		// Two lanes' worth of wheel tracks, wobbling a little the way real ruts do.
		float r1 = smoothstep(0.42, 0.10, abs(a - 0.85));
		float r2 = smoothstep(0.42, 0.10, abs(a - 2.65));
		float r3 = smoothstep(0.50, 0.15, abs(a - 4.6)) * 0.5;
		ruts = max(max(r1, r2), r3) * smoothstep(0.15, 0.6, line_w) * detail;
		ruts *= 0.65 + 0.35 * fbm(w_pos.xz * 0.4);
	}
	vec3 packed = packed_color.rgb * (0.90 + drift * 0.14);
	packed = mix(packed, packed * vec3(0.78, 0.81, 0.86), ruts * rut_strength);
	snow_col = mix(snow_col, packed, smoothstep(0.0, 0.85, line_w) * 0.85);

	vec3 albedo = mix(rock, snow_col, snow);
	float rough = mix(rock_roughness, snow_roughness, snow);
	rough = mix(rough, 0.62, line_w * snow * 0.6);

	// --- Spray zone: glazed, dark, wet-looking near open water -----------------------------
	float spray = masks.b;
	albedo = mix(albedo, albedo * spray_color.rgb * 1.6, spray * 0.75);
	// The generator marks the submerged river bed as full spray: dark wet stone under the water.
	albedo = mix(albedo, spray_color.rgb * 0.45, smoothstep(0.92, 1.0, spray));
	rough = mix(rough, 0.25, spray * 0.8);

	// --- Frozen lakes ----------------------------------------------------------------------
	float ice = masks.r;
	if (ice > 0.001) {
		float cracks = pow(1.0 - abs(fbm(w_pos.xz * 0.045) * 2.0 - 1.0), 14.0);
		float clouds = fbm(w_pos.xz * 0.018);
		vec3 ice_col = mix(ice_deep_color.rgb, ice_color.rgb, 0.35 + clouds * 0.55);
		ice_col += vec3(0.55, 0.65, 0.72) * cracks * 0.55;
		// Wind-blown snow lies in streaks across the ice.
		float dusting = smoothstep(0.55, 0.85, fbm(w_pos.xz * vec2(0.02, 0.09) + 11.0));
		ice_col = mix(ice_col, snow_col, dusting * 0.75);
		float on_ice = smoothstep(0.0, 1.0, ice);
		albedo = mix(albedo, ice_col, on_ice);
		rough = mix(rough, mix(ice_roughness, snow_roughness, dusting), on_ice);
	}

	albedo = mix(albedo, horizon_color.rgb,
			clamp((length(w_pos.xz - horizon_center) - horizon_start) / max(horizon_end - horizon_start, 1.0), 0.0, 1.0));

	ALBEDO = albedo;
	ROUGHNESS = rough;
	NORMAL_MAP = triplanar(rock_normal, rot2, n, rock_scale * 2.2).rgb;
	float detail_fade = clamp(1.0 - fwidth(w_pos.x) * 0.03 - fwidth(w_pos.z) * 0.03, 0.1, 1.0);
	float relief = (1.0 - snow) * 0.9 + snow * 0.14;
	relief = mix(relief, 0.05, ice);
	NORMAL_MAP_DEPTH = normal_strength * relief * detail_fade * (0.25 + 0.75 * detail);
	SPECULAR = mix(mix(0.10, 0.28, snow), 0.55, max(ice, spray * 0.7));
}
