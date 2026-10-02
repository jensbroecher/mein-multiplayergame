shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Alpine snow / rock blend for the Glacier Highway massif.
// Rock is triplanar-mapped from world space so cliffs never smear, snow settles on
// anything shallow enough to hold it, and a noise-broken snow line keeps the
// transition ragged instead of drawing a contour ring around the mountains.

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 snow_color : source_color = vec4(0.93, 0.96, 1.0, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.58, 0.61, 0.68, 1.0);
uniform float rock_scale : hint_range(0.005, 2.0) = 0.34;
uniform float normal_strength : hint_range(0.0, 4.0) = 0.75;

// Shallow slopes hold snow; the snow line rises so high rock reads as bare stone.
uniform float snow_slope : hint_range(0.0, 1.0) = 0.66;
uniform float snow_line : hint_range(-50.0, 400.0) = 52.0;
uniform float snow_line_falloff : hint_range(1.0, 120.0) = 34.0;
uniform float snow_roughness : hint_range(0.0, 1.0) = 0.74;
uniform float rock_roughness : hint_range(0.0, 1.0) = 0.95;

// Distant terrain melts into the polar haze so the range reads as endless.
uniform vec4 horizon_color : source_color = vec4(0.74, 0.83, 0.93, 1.0);
uniform float horizon_start : hint_range(100.0, 4000.0) = 700.0;
uniform float horizon_end : hint_range(200.0, 6000.0) = 1400.0;

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

	// Macro variation: large drifts and wind-scoured hollows across the snowfields.
	float patch = fbm(w_pos.xz * 0.0075);
	float drift = fbm(w_pos.xz * 0.022);
	float ripple = fbm(w_pos.xz * vec2(0.10, 0.016));

	// Shallow ground holds snow, steep faces shed it.
	float slope_mask = smoothstep(snow_slope - 0.22, snow_slope + 0.26, n.y);
	// High ground is scoured thinner, with a noisy snow line rather than a clean contour.
	float altitude = 1.0 - smoothstep(snow_line - snow_line_falloff, snow_line + snow_line_falloff, w_pos.y);
	float breakup = (fbm(w_pos.xz * 0.011) - 0.5) * 0.85 + (drift - 0.5) * 0.45;
	float snow = clamp(slope_mask * (0.48 + altitude * 0.5) + breakup, 0.0, 1.0);
	snow = smoothstep(0.08, 0.72, snow);

	// Two rock octaves blended by a very low frequency mask. The second octave samples a
	// rotated copy of the world position, otherwise both octaves share the same grid and the
	// tiling reads as a regular pattern across the whole face.
	float rock_blend = smoothstep(0.32, 0.68, fbm(w_pos.xz * 0.0035));
	vec3 rot_p = vec3(w_pos.x * 0.8 - w_pos.z * 0.6, w_pos.y, w_pos.x * 0.6 + w_pos.z * 0.8);
	vec3 rock = triplanar(rock_albedo, w_pos, n, rock_scale).rgb;
	rock = mix(rock, triplanar(rock_albedo, rot_p, n, rock_scale * 0.29).rgb, rock_blend);
	// Broad tonal variation so the rock is not one flat value per face, and so the eye does
	// not lock onto the texture's own repeat across a big wall.
	rock *= 0.70 + fbm(w_pos.xz * 0.004) * 0.42 + fbm(w_pos.xz * 0.022) * 0.22;
	rock *= rock_tint.rgb;
	// Snow is not flat white: crests catch the light, hollows go blue and pick up the rock.
	vec3 snow_col = snow_color.rgb * (0.80 + drift * 0.26 + ripple * 0.10);
	snow_col = mix(snow_col, snow_col * vec3(0.90, 0.94, 1.04), patch * 0.6);

	vec3 albedo = mix(rock, snow_col, snow);
	albedo = mix(albedo, horizon_color.rgb,
			clamp((length(w_pos.xz) - horizon_start) / max(horizon_end - horizon_start, 1.0), 0.0, 1.0));

	ALBEDO = albedo;
	ROUGHNESS = mix(rock_roughness, snow_roughness, snow);

	NORMAL_MAP = triplanar(rock_normal, rot_p, n, rock_scale * 1.6).rgb;
	// Surface detail has to fade with the texel footprint or it crawls at a distance.
	float detail_fade = clamp(1.0 - fwidth(w_pos.x) * 0.03 - fwidth(w_pos.z) * 0.03, 0.1, 1.0);
	// Snow keeps a whisper of relief so the glacier floor is not a mirror-flat sheet.
	float snow_relief = (1.0 - snow) * 0.9 + snow * 0.12;
	NORMAL_MAP_DEPTH = normal_strength * snow_relief * detail_fade;
	SPECULAR = mix(0.10, 0.28, snow);
}
