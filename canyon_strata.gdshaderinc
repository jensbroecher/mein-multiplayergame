// The Canyon Course's sandstone (regenerate_canyon.gd), shared by its ground (canyon_ground.gdshader)
// and every rock mesh (canyon_rock.gdshader: the slot canyon's walls, the arch, the hoodoos), so a
// bed of rock shows at the same height on all of them.
//
// The beds are laid flat and read from the world height, warped a little so they pinch and swell:
// mostly deep red, rust and salmon, higher up now and then a buff or cream bed, and pale cap rock on
// the mesas' rims. Fine laminations run through each bed. rock_tex (a cracked rock face) supplies the grain,
// its light and shade only; dark desert varnish streaks run down the faces.
//
// None of it is mipmapped, so each pattern fades to its average where a pixel covers too much of it
// (`fw`, the pixel's size in metres: length(fwidth(world position)), taken outside any branch). Drawn
// sharp, the laminations, partings and streaks shimmered on every distant cliff as the camera moved.

uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Height of an average bed, and where the walls turn from red to the pale cap rock.
uniform float bed_height = 1.7;
uniform float cap_rock_y = 34.0;
// Buff and cream beds only from this height up: below it is the red formation. A cream bed ran
// along the slot canyon's floor (11-14m) on both walls, and in their shade it read as a dusty smear.
uniform float pale_from = 22.0;

float cs_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float cs_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = cs_hash(i);
	float b = cs_hash(i + vec2(1.0, 0.0));
	float c = cs_hash(i + vec2(0.0, 1.0));
	float d = cs_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cs_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * cs_noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 cs_srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

// The sandstone colours a bed can take (sRGB), picked by the bed's hash: neighbours differ by a
// shade, not a stripe.
vec3 cs_bed_color(float h) {
	if (h < 0.32) return vec3(0.60, 0.29, 0.18);  // deep red
	if (h < 0.66) return vec3(0.67, 0.34, 0.20);  // rust
	if (h < 0.91) return vec3(0.73, 0.41, 0.26);  // salmon
	if (h < 0.97) return vec3(0.78, 0.52, 0.35);  // buff
	return vec3(0.82, 0.62, 0.45);                // cream
}

// The colour of bed `i` (counted up from y = 0).
vec3 cs_bed(float i) {
	float h = cs_hash(vec2(i, 17.0));
	h *= mix(0.9, 1.0, step(pale_from, (i + 1.0) * bed_height));
	return cs_bed_color(h);
}

// Linear albedo of the rock at world position `wp`, seen with pixels `fw` metres across.
vec3 strata_color(vec3 wp, float fw) {
	float warp = (cs_fbm(wp.xz * 0.012) - 0.5) * 5.0 + (cs_fbm(wp.xz * 0.07 + 31.0) - 0.5) * 1.6;
	float y = wp.y + warp;
	float b = y / bed_height;
	float i = floor(b);
	float f = fract(b);
	vec3 c0 = cs_bed(i);
	vec3 c1 = cs_bed(i + 1.0);
	vec3 c = mix(c0, c1, smoothstep(0.72, 1.0, f));
	// Beds only a pixel or two thick take the mean of the palette (cs_bed_color's shares, averaged
	// in linear light).
	c = mix(c, vec3(0.68, 0.37, 0.235), smoothstep(0.3, 0.8, fw / bed_height));
	// Formations: runs of beds a shade darker or paler, the banding that still reads from afar.
	c *= 0.93 + 0.14 * cs_noise(vec2(y * 0.09, 5.0));
	// Cross-bedding: each set of three beds has laminations dipping its own way, the sweeping lines
	// of old dunes (set by set; flipping with every bed, they read as a herringbone weave). They
	// are 0.7m apart, so they go once a pixel spans a third of that.
	float set_i = floor(b / 3.0);
	float hb = cs_hash(vec2(set_i, 3.0));
	vec2 dip = vec2(cos(hb * 6.283), sin(hb * 6.283)) * (0.12 + 0.36 * cs_hash(vec2(set_i, 9.0)));
	float lam = sin((y + dot(wp.xz, dip)) * 9.0 + cs_noise(wp.xz * 0.25) * 2.5);
	c *= 0.93 + 0.07 * lam * (1.0 - smoothstep(0.1, 0.25, fw));
	// A faint dark parting between beds: at least a pixel wide, and paler as it widens, so a far
	// one is a soft line of the same weight rather than a broken one.
	float pw = max(0.05, fw / bed_height);
	c *= 1.0 - 0.12 * (0.05 / pw) * smoothstep(1.0 - pw, 1.0, f);
	// The cliffs that cap the mesas are paler.
	float cap = smoothstep(cap_rock_y - 4.0, cap_rock_y + 5.0, y);
	c = mix(c, mix(c, vec3(0.86, 0.72, 0.56), 0.55), cap);
	return cs_srgb(c);
}

// The rock texture's grain on a face of normal `n` (triplanar, world metres), 1 on average.
float strata_grain(vec3 wp, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	float gx = dot(texture(rock_tex, wp.zy * scale).rgb, vec3(0.3, 0.59, 0.11));
	float gy = dot(texture(rock_tex, wp.xz * scale).rgb, vec3(0.3, 0.59, 0.11));
	float gz = dot(texture(rock_tex, wp.xy * scale).rgb, vec3(0.3, 0.59, 0.11));
	return (gx * w.x + gy * w.y + gz * w.z) * 3.9;
}

// Desert varnish: dark streaks down a steep face (0 none, 1 darkest). They are about 2m across, so
// from afar they give way to their average cover (0.14).
float strata_varnish(vec3 wp, float steep, float fw) {
	vec2 q = vec2(wp.x * 0.31 + wp.z * 0.37, wp.y * 0.018);
	float s = cs_fbm(q * vec2(1.0, 1.0)) * cs_fbm(q * vec2(2.3, 0.6) + 7.0);
	return mix(smoothstep(0.18, 0.42, s), 0.14, smoothstep(0.35, 1.0, fw)) * steep;
}
