// Zeche Kronprinz's ground (regenerate_zeche.gd): an off-road stage, no road mesh. UV is world xz in metres, UV2.x the
// distance to the lap's centreline (metres; 99 far off). The vertex colour carries the masks:
//   R  spoil (Bergematerial): the Halde's dark grey shale, lighter fragments, rusty streaks, sparse grass and moss
//   G  the works' ground: slag and coal dust, patches of old concrete slabs (the yard, the Kokerei, along the railway)
//   B  the track: compacted dirt and grit, two pairs of ruts, gravel thrown to the edges, puddles in the hollows
//   A  woodland floor (the birch scrub)
// Grass elsewhere: dry, tufty ruderal meadow with goldenrod-yellow and clover-white speckles. Everything from world
// positions (never a hash of an interpolated colour).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float track_half = 8.0;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;
varying float lat;

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	return vec2(hash12(p), hash12(p + 19.19));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}


// A round fleck of radius r (metres) in some of the cells density a metre across (share of them), anti-aliased by fw;
// a fleck shrinks to nothing as the pixel grows past it.
float fleck(vec2 xz, float density, float r, float share, float salt, float fw) {
	vec2 q = xz * density;
	vec2 cell = floor(q);
	vec2 c = 0.25 + 0.5 * hash22(cell + salt);
	float d = length(fract(q) - c) / density;
	float on = step(1.0 - share, hash12(cell + salt * 3.1));
	return on * (1.0 - smoothstep(r - fw * 0.5, r + fw * 0.5, d)) * (1.0 - smoothstep(r * 0.6, r * 1.6, fw));
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
	lat = UV2.x;
}

void fragment() {
	vec2 xz = w_pos.xz;
	float fw = length(fwidth(w_pos));
	float dist = length(VERTEX);
	vec3 nw = normalize(w_nrm);
	float near = 1.0 - smoothstep(60.0, 220.0, dist);

	// ---- Ruderal grass: dry and tufty, flecks of yellow and white flowers.
	vec3 g1 = texture(grass_tex, xz / 7.0).rgb;
	vec3 g2 = texture(grass_tex, vec2(xz.y, -xz.x) / 23.0).rgb;
	vec3 gt = mix(g2, g1, 0.55 + 0.25 * near);
	float gl = dot(gt, vec3(0.3, 0.59, 0.11));
	float patch = fbm(xz / 40.0);
	vec3 grass = mix(lin(vec3(0.34, 0.42, 0.17)), lin(vec3(0.50, 0.50, 0.24)), smoothstep(0.35, 0.75, patch));
	grass *= 0.62 + 0.38 * clamp(gl / 0.36, 0.4, 1.5);
	grass *= 0.88 + 0.24 * vnoise(xz * 0.7);
	float bloom = smoothstep(0.45, 0.7, vnoise(xz / 12.0));
	float fy = fleck(xz, 3.0, 0.045, 0.10, 7.0, fw) * bloom;
	float fwh = fleck(xz + 0.17, 3.0, 0.035, 0.08, 13.0, fw) * bloom;
	grass = mix(grass, lin(vec3(0.85, 0.72, 0.12)), fy * 0.85);
	grass = mix(grass, lin(vec3(0.86, 0.86, 0.80)), fwh * 0.8);
	vec3 col = grass;
	float rough = 0.93;

	// ---- Dirt on the steeper banks.
	float slope = 1.0 - nw.y;
	vec3 dirt = texture(dirt_tex, xz / 5.0).rgb * lin(vec3(0.92, 0.84, 0.74)) * 1.25;
	float dirt_w = smoothstep(0.12, 0.32, slope + (vnoise(xz / 6.0) - 0.5) * 0.12) * (1.0 - masks.g);
	col = mix(col, dirt, dirt_w * 0.7);

	// ---- Woodland floor.
	if (masks.a > 0.01) {
		vec3 litter = dirt * lin(vec3(0.48, 0.44, 0.34)) * (0.75 + 0.4 * vnoise(xz * 1.3));
		vec3 moss = lin(vec3(0.22, 0.32, 0.11)) * (0.8 + 0.3 * vnoise(xz * 0.9));
		col = mix(col, mix(litter, moss, smoothstep(0.3, 0.65, fbm(xz / 9.0))), masks.a);
	}

	// ---- Spoil (Bergematerial): dark grey shale in flakes, lighter sandstone fragments, rust streaks, green creeping in.
	if (masks.r > 0.01) {
		vec3 gr = texture(gravel_tex, xz / 2.8 + vec2(w_pos.y * 0.07, 0.0)).rgb;
		float gl2 = dot(gr, vec3(0.33));
		vec3 shale = lin(vec3(0.36, 0.34, 0.32)) * (0.6 + gl2 * 1.4);
		float frag = max(fleck(xz, 2.6, 0.09, 0.22, 3.0, fw), fleck(xz + 0.21, 1.3, 0.14, 0.12, 9.0, fw));
		shale = mix(shale, lin(vec3(0.50, 0.46, 0.40)) * (0.7 + gl2), frag * 0.6);
		float rust = smoothstep(0.62, 0.85, fbm(vec2(xz.x + xz.y * 0.3, w_pos.y * 4.0) / 6.0));
		shale = mix(shale, lin(vec3(0.42, 0.24, 0.14)) * (0.6 + gl2), rust * 0.5);
		float green = smoothstep(0.42, 0.72, fbm(xz / 14.0 + 3.0)) * (0.35 + 0.65 * smoothstep(0.35, 0.08, slope)) * 0.8;
		shale = mix(shale, grass * 0.85, green);
		col = mix(col, shale, masks.r);
		rough = mix(rough, 0.92, masks.r);
		vec3 gn = texture(gravel_normal, xz / 2.8).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(gn.x, 0.0, gn.y) * 0.45 * masks.r);
	}

	// ---- The works' ground: slag and coal dust, old concrete slabs in patches.
	if (masks.g > 0.01) {
		vec3 gr3 = texture(gravel_tex, xz / 3.2).rgb;
		float g3 = dot(gr3, vec3(0.33));
		vec3 slag = lin(vec3(0.30, 0.28, 0.25)) * (0.5 + g3 * 1.2);
		slag = mix(slag, lin(vec3(0.10, 0.10, 0.095)), smoothstep(0.62, 0.82, fbm(xz / 18.0 + 5.0)) * 0.7);
		vec2 sc = xz / vec2(6.0, 4.0);
		vec2 sf = fract(sc);
		float slabs = smoothstep(0.5, 0.58, fbm(xz / 34.0 + 11.0));
		vec3 conc = texture(concrete_tex, xz / 4.0).rgb * lin(vec3(0.40, 0.39, 0.37)) * (0.85 + 0.25 * hash12(floor(sc)));
		float jt = 1.0 - smoothstep(0.0, 0.03 + fw * 0.2, min(min(sf.x, 1.0 - sf.x) * 6.0, min(sf.y, 1.0 - sf.y) * 4.0));
		conc *= 1.0 - 0.5 * jt * (1.0 - smoothstep(0.05, 0.2, fw));
		vec3 works = mix(slag, conc, slabs);
		works = mix(works, grass * 0.8, smoothstep(0.6, 0.85, fbm(xz / 12.0 + 2.0)) * 0.7 * (1.0 - slabs));
		col = mix(col, works, masks.g);
		rough = mix(rough, 0.86, masks.g);
	}

	// ---- The track: compacted dirt and grit, ruts, gravel thrown out to the edges, puddles.
	if (masks.b > 0.01) {
		float a = lat;
		vec3 dt = texture(dirt_tex, xz / 3.5).rgb;
		vec3 grit = texture(gravel_tex, xz / 2.2).rgb;
		vec3 track = mix(dt * lin(vec3(0.70, 0.60, 0.50)) * 1.15, lin(vec3(0.30, 0.28, 0.26)) * (0.6 + dot(grit, vec3(0.33)) * 1.3), 0.45);
		track *= 0.88 + 0.2 * vnoise(xz / 8.0);
		// Ruts: two pairs worn darker and smoother, wandering a little.
		float wob = (vnoise(vec2(xz.x * 0.05, xz.y * 0.05)) - 0.5) * 1.2;
		float rut = 0.0;
		for (int i = 0; i < 2; i++) {
			float c = (i == 0 ? 1.4 : 4.6) + wob;
			rut = max(rut, 1.0 - smoothstep(0.25, 0.7 + fw, abs(a - c)));
		}
		track = mix(track, track * 0.7, rut * 0.6);
		// Coarse gravel pushed to the edges, the grass creeping in.
		float edge = smoothstep(track_half - 1.6, track_half - 0.2, a + (vnoise(xz * 0.4) - 0.5) * 1.2);
		track = mix(track, lin(vec3(0.42, 0.40, 0.37)) * (0.6 + dot(grit, vec3(0.33)) * 1.2), edge * 0.6);
		track = mix(track, grass * 0.85, smoothstep(track_half - 0.4, track_half + 1.2, a + (vnoise(xz * 0.6) - 0.5) * 1.6));
		// Puddles in the ruts and hollows: dark, smooth, reflecting.
		float pud = smoothstep(0.72, 0.8, vnoise(xz / 7.0 + 3.0)) * (0.3 + 0.7 * rut) * (1.0 - edge);
		track = mix(track, lin(vec3(0.07, 0.07, 0.065)), pud * 0.8);
		col = mix(col, track, masks.b);
		rough = mix(rough, mix(0.9, 0.3, pud), masks.b);
		vec3 dn2 = texture(dirt_normal, xz / 3.5).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(dn2.x, 0.0, dn2.y) * 0.3 * masks.b * (1.0 - pud));
	}

	// The dirt's normal map on bare ground.
	vec3 dn = texture(dirt_normal, xz / 5.0).rgb * 2.0 - 1.0;
	nw = normalize(nw + vec3(dn.x, 0.0, dn.y) * 0.35 * max(dirt_w, masks.a) * near);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
