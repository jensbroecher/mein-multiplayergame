// Kronburger Hütte's ground (regenerate_kronburg.gd): the Ruhr valley in summer. UV is world xz in metres; the vertex
// colour carries the masks the generator works out per vertex:
//   R  bare sandstone (steep faces: cuttings, the castle hill's crags)
//   G  the works' ground: dark slag gravel with rust-red ore dust, oil and patches of old concrete
//   B  farmland: a patchwork of fields (meadow, wheat, rapeseed, maize, ploughed earth) in cells with hedgerows
//   A  woodland floor: leaf litter and moss
// Grass everywhere else, with mown and lush patches and dirt on the steeper banks. The canal's banks go to wet silt
// under `water_y`. Fields, rows and slabs come from world positions only (never a hash of an interpolated colour).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float water_y = 0.6;
// Rheinufer (regenerate_rheinufer.gd) reuses this shader: there G is the Rhine's gravel and sand beach, not the works'
// ground, and R the dark basalt riprap of the banks. Off by default (Kronburger Hütte's look is unchanged).
uniform bool g_beach = false;
uniform vec3 rock_tint = vec3(1.25, 1.12, 0.92);

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;

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

// Voronoi over field cells: x the distance to the nearest border (metres), yz the cell's seed point (an id).
vec3 fields(vec2 p, float size) {
	vec2 q = p / size;
	vec2 n = floor(q);
	vec2 f = fract(q);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			// Cells stretched a little and jittered: fields are longer than wide.
			vec2 o = hash22(n + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = hash22(n + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec3(md * size, n + mg);
}

// Coverage of a line `w` wide at signed distance d, antialiased over aa and faded to its share below a pixel.
float stripe(float d, float w, float aa) {
	aa = max(aa, 1e-4);
	float cov = clamp((w * 0.5 - abs(d)) / aa + 0.5, 0.0, 1.0);
	return mix(cov, clamp(w / (aa * 2.0), 0.0, 1.0), smoothstep(w * 0.6, w * 1.6, aa));
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
}

void fragment() {
	vec2 xz = w_pos.xz;
	float fw = length(fwidth(w_pos));
	float dist = length(VERTEX);
	vec3 nw = normalize(w_nrm);
	float near = 1.0 - smoothstep(60.0, 220.0, dist);

	// ---- Grass: two scales of the texture, patches of lush and dry, a mown sheen.
	vec3 g1 = texture(grass_tex, xz / 7.0).rgb;
	vec3 g2 = texture(grass_tex, vec2(xz.y, -xz.x) / 23.0).rgb;
	vec3 gt = mix(g2, g1, 0.55 + 0.25 * near);
	float gl = dot(gt, vec3(0.3, 0.59, 0.11));
	float patch = fbm(xz / 48.0);
	vec3 grass = mix(lin(vec3(0.30, 0.43, 0.15)), lin(vec3(0.40, 0.50, 0.19)), smoothstep(0.35, 0.7, patch));
	grass = mix(grass, lin(vec3(0.47, 0.50, 0.24)), smoothstep(0.62, 0.85, fbm(xz / 130.0 + 7.0)) * 0.6);
	grass *= 0.62 + 0.38 * clamp(gl / 0.36, 0.4, 1.5);
	grass *= 0.88 + 0.24 * vnoise(xz * 0.7);
	vec3 col = grass;
	float rough = 0.93;

	// ---- Dirt on the steeper banks.
	float slope = 1.0 - nw.y;
	vec3 dirt = texture(dirt_tex, xz / 5.0).rgb * lin(vec3(0.95, 0.85, 0.72)) * 1.3;
	float dirt_w = smoothstep(0.10, 0.30, slope + (vnoise(xz / 6.0) - 0.5) * 0.12) * (1.0 - masks.g);
	col = mix(col, dirt, dirt_w * 0.75);

	// ---- Farmland: field cells ~110m, each a crop with rows along its own bearing; hedgerows on the borders.
	if (masks.b > 0.01) {
		vec3 fc = fields(xz, 115.0);
		float id = hash12(fc.yz);
		float kind = floor(id * 6.0);
		float ang = hash12(fc.yz + 3.7) * 3.14159;
		vec2 dir = vec2(cos(ang), sin(ang));
		float across = dot(xz, vec2(-dir.y, dir.x));
		float rows = 0.0;
		vec3 crop;
		if (kind < 1.5) {
			// Meadow (two of six): grass of its own tint, mown in broad swathes.
			crop = mix(grass, lin(vec3(0.36, 0.48, 0.17)), 0.5) * (0.9 + 0.12 * step(0.5, fract(across / 9.0)));
		} else if (kind < 2.5) {
			// Wheat: golden green, rows 0.25m.
			crop = lin(vec3(0.66, 0.60, 0.30));
			rows = 0.25;
		} else if (kind < 3.5) {
			// Rapeseed in flower: bright yellow over green.
			crop = mix(lin(vec3(0.85, 0.76, 0.12)), lin(vec3(0.42, 0.50, 0.14)), 0.25 * vnoise(xz * 0.4));
			rows = 0.3;
		} else if (kind < 4.5) {
			// Maize: dark green rows 0.75m apart, earth between.
			crop = lin(vec3(0.20, 0.34, 0.10));
			rows = 0.75;
		} else {
			// Ploughed: brown furrows.
			crop = dirt * lin(vec3(0.62, 0.55, 0.48)) * 0.8;
			rows = 0.4;
		}
		if (rows > 0.0) {
			float rf = fract(across / rows);
			float furrow = smoothstep(0.25, 0.5, abs(rf - 0.5));
			float fade = 1.0 - smoothstep(rows * 0.25, rows * 0.9, fw);
			vec3 between = kind > 4.5 ? crop * 0.6 : dirt * 0.8;
			crop = mix(crop, mix(crop, between, 0.45), mix(0.5, furrow, fade) * 0.7);
		}
		crop *= 0.9 + 0.18 * vnoise(xz / 13.0 + id * 31.0);
		// Hedgerows and field margins along the borders.
		float hedge = 1.0 - smoothstep(1.2, 2.6 + fw, fc.x);
		float margin = 1.0 - smoothstep(2.6, 4.0 + fw, fc.x);
		crop = mix(crop, grass * 0.95, margin);
		crop = mix(crop, lin(vec3(0.12, 0.22, 0.07)) * (0.8 + 0.4 * vnoise(xz * 0.8)), hedge);
		col = mix(col, crop, masks.b * (1.0 - dirt_w * 0.6));
	}

	// ---- Woodland floor.
	if (masks.a > 0.01) {
		vec3 litter = dirt * lin(vec3(0.46, 0.42, 0.34)) * (0.75 + 0.4 * vnoise(xz * 1.3));
		vec3 moss = lin(vec3(0.20, 0.30, 0.10)) * (0.8 + 0.3 * vnoise(xz * 0.9));
		vec3 floor_c = mix(litter, moss, smoothstep(0.3, 0.65, fbm(xz / 9.0)));
		col = mix(col, floor_c, masks.a);
	}

	// ---- The works' ground: slag gravel, ore dust, oil, old concrete.
	if (masks.g > 0.01 && g_beach) {
		// The Rhine's beach: pale sand with gravel bands where the water left them, driftwood-grey pebbles, dried
		// mud and tufts of grass up the shore.
		vec3 gr = texture(gravel_tex, xz / 2.6).rgb;
		float gl2 = dot(gr, vec3(0.33));
		vec3 sand = lin(vec3(0.70, 0.63, 0.50)) * (0.8 + 0.3 * vnoise(xz * 0.6)) * (0.92 + 0.12 * vnoise(xz * 4.0));
		vec3 pebbles = lin(vec3(0.55, 0.52, 0.48)) * (0.55 + gl2 * 1.5);
		float band = smoothstep(0.35, 0.75, vnoise(vec2(dot(xz, vec2(0.95, 0.3)) / 7.0, w_pos.y * 2.5)));
		vec3 beach = mix(sand, pebbles, band * 0.75);
		float mud = (1.0 - smoothstep(water_y + 0.2, water_y + 1.2, w_pos.y)) * smoothstep(0.5, 0.7, vnoise(xz / 9.0 + 5.0));
		beach = mix(beach, lin(vec3(0.33, 0.30, 0.24)), mud * 0.6);
		beach = mix(beach, grass * 0.9, smoothstep(0.62, 0.85, fbm(xz / 11.0 + 4.0)) * smoothstep(water_y + 1.2, water_y + 2.6, w_pos.y));
		col = mix(col, beach, masks.g);
		rough = mix(rough, 0.9, masks.g);
		vec3 gn = texture(gravel_normal, xz / 2.6).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(gn.x, 0.0, gn.y) * 0.35 * masks.g * band);
	} else if (masks.g > 0.01) {
		vec3 gr = texture(gravel_tex, xz / 3.2).rgb;
		float gl2 = dot(gr, vec3(0.33));
		vec3 slag = lin(vec3(0.30, 0.29, 0.28)) * (0.5 + gl2 * 1.6);
		float ore = smoothstep(0.55, 0.8, fbm(xz / 26.0 + 3.0));
		slag = mix(slag, lin(vec3(0.42, 0.22, 0.14)) * (0.6 + gl2), ore * 0.7);
		// Old concrete slabs in 6 x 4m panels, in patches.
		vec2 sc = xz / vec2(6.0, 4.0);
		vec2 sf = fract(sc);
		float slabs = smoothstep(0.56, 0.62, fbm(xz / 40.0 + 11.0));
		vec3 conc = texture(concrete_tex, xz / 4.0).rgb * lin(vec3(0.38, 0.37, 0.35)) * (0.85 + 0.25 * hash12(floor(sc)));
		float jt = 1.0 - smoothstep(0.0, 0.03 + fw * 0.2, min(min(sf.x, 1.0 - sf.x) * 6.0, min(sf.y, 1.0 - sf.y) * 4.0));
		conc *= 1.0 - 0.5 * jt * (1.0 - smoothstep(0.05, 0.2, fw));
		vec3 works = mix(slag, conc, slabs);
		// Oil and soot.
		float oil = smoothstep(0.66, 0.82, vnoise(xz / 7.0 + 40.0));
		works *= 1.0 - oil * 0.55;
		// A little grass where it is left alone.
		works = mix(works, grass * 0.8, smoothstep(0.7, 0.9, fbm(xz / 15.0 + 2.0)) * 0.45 * (1.0 - slabs));
		col = mix(col, works, masks.g);
		rough = mix(rough, 0.85, masks.g);
		vec3 gn = texture(gravel_normal, xz / 3.2).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(gn.x, 0.0, gn.y) * 0.5 * masks.g * (1.0 - slabs));
	}

	// ---- Sandstone on the steep faces.
	if (masks.r > 0.01) {
		vec3 rk = texture(rock_tex, xz / 9.0 + vec2(w_pos.y / 7.0, 0.0)).rgb;
		vec3 stone = rk * lin(rock_tint) * 1.4;
		stone *= 0.8 + 0.3 * vnoise(vec2(xz.x + xz.y, w_pos.y * 3.0) / 2.5);
		col = mix(col, stone, masks.r);
		rough = mix(rough, 0.88, masks.r);
	}

	// ---- The canal's banks: wet silt under the waterline and just over it.
	float wet = 1.0 - smoothstep(water_y + 0.05, water_y + 0.6, w_pos.y);
	col = mix(col, lin(vec3(0.20, 0.19, 0.14)) * (0.8 + 0.3 * vnoise(xz)), wet * 0.85);
	rough = mix(rough, 0.45, wet);

	// The dirt's normal map on bare ground.
	vec3 dn = texture(dirt_normal, xz / 5.0).rgb * 2.0 - 1.0;
	nw = normalize(nw + vec3(dn.x, 0.0, dn.y) * 0.35 * max(dirt_w, masks.a) * near);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
