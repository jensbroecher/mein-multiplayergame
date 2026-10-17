shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Corrugated iron roofing for the Msitu Falls ranger post (RangerPostBuilder.gd). UV is in world
// metres: u runs across the sheets, v up the slope, so the ribs run along v. The vertex colour is
// the paint (faded green, red oxide, bare galvanised). Needs tangents, which the builder generates.

uniform float pitch = 0.17;
uniform float sheet_w = 1.35;
uniform float sheet_len = 3.8;
uniform float rust_amount : hint_range(0.0, 1.0) = 0.5;
uniform vec3 rust_color : source_color = vec3(0.45, 0.2, 0.08);

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 q = UV;
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	float ph = q.x / pitch * TAU;
	float rib = 0.5 + 0.5 * sin(ph);
	float slope = cos(ph);

	// Sheets: each one a little different in tone, lapped every sheet_w across and sheet_len up.
	float sid = floor(q.x / sheet_w);
	float sf = fract(q.x / sheet_w);
	float off = hash12(vec2(sid, 3.3)) * sheet_len;
	float cid = floor((q.y + off) / sheet_len);
	float cf = fract((q.y + off) / sheet_len);
	float tone = 0.84 + 0.22 * hash12(vec2(sid, cid));
	float lap_x = 1.0 - smoothstep(0.0, 0.025, sf);
	float lap_y = 1.0 - smoothstep(0.0, 0.03, cf);
	float lap = max(lap_x, lap_y);

	// Rust: patches that grow from the laps and the lower edge, and streaks running downhill.
	float patch = vnoise(q * 0.9 + 5.0) * 0.6 + vnoise(q * 3.3 + 1.0) * 0.4;
	float streaks = vnoise(vec2(q.x * 7.0, q.y * 0.5));
	float rust = smoothstep(0.55, 0.8, patch + lap * 0.25 + streaks * 0.2 - 0.15) * rust_amount;
	rust = clamp(rust + lap * 0.12 * rust_amount, 0.0, 1.0);

	vec3 col = paint * tone * (0.78 + 0.3 * rib);
	col *= 1.0 - 0.3 * lap;
	vec3 rust_col = rust_color * (0.7 + 0.5 * vnoise(q * 11.0));
	col = mix(col, rust_col, rust);

	ALBEDO = col;
	METALLIC = mix(0.5, 0.05, rust);
	ROUGHNESS = mix(0.4, 0.85, rust);
	SPECULAR = 0.5;
	// The corrugations: a tangent-space normal that rocks across each rib.
	vec3 n = normalize(vec3(-0.85 * slope, 0.0, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
