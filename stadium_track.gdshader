shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Nyota Stadium track ribbon: groomed supercross dirt in the bowl, tarmac on the streets
// outside, and the steel deck of the Drop-In kicker.
//
// UV.x is metres across the ribbon (0 on the centreline), UV.y metres along the lap, so ruts
// and wheel tracks run along the track whatever its heading. The vertex colour:
//   r - tarmac weight (0 dirt, 1 tarmac; blends where the ramp leaves the bowl)
//   g - steel kicker deck
//   b - shoulder: the side slopes of jumps and the edges down to the floor
//   a - berm weight through the hairpins
// The arena floor uses this shader too, with `infield` set: UV is then world XZ.

uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform bool infield = false;
// Red-brown clay (multipliers on dirt.png): the groomed track, darker and smoother where wheels
// pack it and where it was watered; the loose dirt of the shoulders and the infield lighter.
uniform vec3 dirt_mul = vec3(1.55, 1.12, 0.98);
uniform vec3 packed_mul = vec3(0.70, 0.66, 0.66);
uniform vec3 loose_mul = vec3(2.1, 1.68, 1.45);
uniform vec4 asphalt_tint : source_color = vec4(0.42, 0.42, 0.43, 1.0);
uniform vec4 line_color : source_color = vec4(0.92, 0.91, 0.86, 1.0);
uniform float street_half_width = 7.0;

varying vec3 w_pos;
varying vec4 vcol;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
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

void fragment() {
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(60.0, 320.0, cam_dist);
	vec2 xz = w_pos.xz;
	float lat = UV.x;
	float along = UV.y;
	float tarmac = infield ? 0.0 : vcol.r;
	float steel = infield ? 0.0 : vcol.g;
	float shoulder = infield ? 1.0 : vcol.b;
	float berm = infield ? 0.0 : vcol.a;

	// --- Dirt ----------------------------------------------------------------------------
	vec3 tex = texture(dirt_tex, xz * 0.31).rgb;
	vec3 tex_far = texture(dirt_tex, xz * 0.061).rgb;
	// The close-up texture only adds a little grain: groomed track dirt is fine, not gravel.
	vec3 base = mix(tex_far, mix(tex_far, tex, 0.4), detail);
	// dirt.png's stones read as rocks at this scale: keep a little of its variation (more on the
	// loose infield), and add a fine grain of our own.
	const vec3 DIRT_MEAN = vec3(0.137, 0.078, 0.041);
	base = mix(DIRT_MEAN, base, infield ? 0.65 : 0.38);
	base *= 0.9 + vnoise(xz * 7.0) * 0.12 * detail + vnoise(xz * 23.0) * 0.08 * detail;
	float patches = fbm(xz * 0.035);
	float damp = smoothstep(0.52, 0.78, fbm(xz * 0.018 + 7.3));
	vec3 dirt = base * dirt_mul * (0.92 + patches * 0.16);
	float rough = 0.9;
	vec3 nmap = texture(dirt_normal, xz * 0.31).rgb;
	float pack = 0.0;
	if (!infield) {
		// Packed racing surface: darker in a broad band, with wheel tracks running along it.
		float wob = (vnoise(vec2(along * 0.05, 3.1)) - 0.5) * 2.5;
		float band = 1.0 - smoothstep(2.0, 5.5, abs(lat - wob));
		float tracks = 0.0;
		for (int k = 0; k < 3; k++) {
			float c = (hash21(vec2(float(k), floor(along / 23.0))) - 0.5) * 7.0;
			float wav = sin(along * (0.11 + float(k) * 0.03) + float(k) * 2.0) * 1.2;
			tracks += smoothstep(0.32, 0.0, abs(lat - c - wav)) * 0.6;
		}
		// Streaks of loose dirt lying along the line of travel.
		float streak = vnoise(vec2(lat * 3.0, along * 0.15));
		pack = clamp(band * 0.55 + tracks * detail * 0.8 + berm * 0.3, 0.0, 1.0) * (1.0 - shoulder);
		dirt = mix(dirt, dirt * packed_mul, pack);
		dirt *= 0.95 + streak * 0.1 * detail;
		// Watered patches: darker and a little glossy.
		dirt = mix(dirt, dirt * 0.72, damp * 0.6 * (1.0 - shoulder));
		// Loose dirt on the shoulders and the sides of the jumps.
		dirt = mix(dirt, base * loose_mul, shoulder * 0.55);
		rough = mix(0.92, 0.78, pack) - damp * 0.18 * (1.0 - shoulder);
	} else {
		// Raked infield: dry and dusty, faint parallel drag marks along x.
		float rake = smoothstep(0.35, 0.5, abs(fract(xz.y * 0.8 + vnoise(xz * 0.05) * 2.0) - 0.5));
		dirt = base * loose_mul * (0.9 + patches * 0.2);
		dirt = mix(dirt, dirt * 1.06, rake * 0.6 * detail);
		rough = 0.96;
	}

	// --- Tarmac --------------------------------------------------------------------------
	vec3 asphalt = texture(asphalt_tex, xz * 0.14).rgb;
	asphalt = mix(asphalt_tint.rgb, asphalt * asphalt_tint.rgb * 2.2, 0.6);
	asphalt *= 0.9 + fbm(xz * 0.07) * 0.2;
	float wear = smoothstep(1.4, 0.2, abs(abs(lat) - 2.6)) * 0.12;
	asphalt *= 1.0 - wear;
	float edge_line = smoothstep(0.14, 0.06, abs(abs(lat) - (street_half_width - 0.45)));
	float dash = step(0.5, fract(along / 9.0));
	float centre_line = smoothstep(0.1, 0.04, abs(lat)) * dash;
	asphalt = mix(asphalt, line_color.rgb, max(edge_line, centre_line) * 0.85);
	// Dirt carried out of the bowl on the tyres: thins out along the street.
	float spill = smoothstep(0.55, 1.0, tarmac) ;
	float clumps = smoothstep(0.45, 0.75, fbm(xz * 0.4) + (1.0 - spill) * 0.6);
	vec3 surf = mix(dirt, asphalt, tarmac);
	surf = mix(surf, dirt * 0.9, clumps * (1.0 - spill) * tarmac);
	rough = mix(rough, 0.86, tarmac);

	// --- Steel kicker deck: diamond plate, with chevrons toward the lip --------------------
	if (steel > 0.5) {
		vec2 g = vec2(lat, along) * 3.0;
		float diamond = abs(fract(g.x + g.y) - 0.5) + abs(fract(g.x - g.y) - 0.5);
		vec3 plate = vec3(0.46, 0.47, 0.48) * (0.85 + smoothstep(0.4, 0.6, diamond) * 0.2);
		float chev = step(0.5, fract((along - abs(lat) * 0.6) / 1.6));
		vec3 stripe = mix(vec3(0.95, 0.72, 0.05), vec3(0.06, 0.06, 0.06), chev);
		float edge = smoothstep(0.6, 0.9, abs(lat) / max(street_half_width, 1.0));
		surf = mix(plate, stripe, max(edge, shoulder));
		rough = 0.5;
		METALLIC = 0.6;
	}

	ALBEDO = surf;
	ROUGHNESS = rough;
	NORMAL_MAP = mix(nmap, vec3(0.5, 0.5, 1.0), max(tarmac * 0.7, steel));
	NORMAL_MAP_DEPTH = mix(0.35, 0.15, pack) * detail;
}
