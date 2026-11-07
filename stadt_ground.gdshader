// Quer durch Kronburg's ground (regenerate_stadtrallye.gd): the city, its Botanischer Garten and the docks on a late
// summer morning. Derived from kronburg_ground.gdshader. UV is world xz in metres; the vertex colour carries masks the
// generator works out per vertex:
//   R  stone: the steep faces (the Alpinum's limestone in the garden, cuttings), grey and weathered
//   G  the docks' ground: dark slag gravel, old concrete slabs, oil, rust
//   B  the garden's lawns: fine mown grass in stripes, lusher than the verges
//   A  bed soil and mulch: planting beds, shrubberies, under the trees
// UV2.x mud (the building site and the scrapyard: wet brown earth, tyre tracks, puddles mirroring the sky), UV2.y city
// paving (squares and forecourts the road ribbons don't cover: grey concrete flags and granite bands). Grass everywhere
// else. Patterns come from world positions only (never a hash of an interpolated colour).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float water_y = 2.0;
uniform vec3 rock_tint = vec3(1.02, 1.0, 0.94);

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;
varying vec2 masks2;

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

float stripe(float d, float w, float aa) {
	aa = max(aa, 1e-4);
	float cov = clamp((w * 0.5 - abs(d)) / aa + 0.5, 0.0, 1.0);
	return mix(cov, clamp(w / (aa * 2.0), 0.0, 1.0), smoothstep(w * 0.6, w * 1.6, aa));
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
	masks2 = UV2;
}

void fragment() {
	vec2 xz = w_pos.xz;
	float fw = length(fwidth(w_pos));
	float dist = length(VERTEX);
	vec3 nw = normalize(w_nrm);
	float near = 1.0 - smoothstep(60.0, 220.0, dist);

	// ---- Grass: the city's verges and the rough ground: two scales of the texture, dry and lush patches.
	vec3 g1 = texture(grass_tex, xz / 7.0).rgb;
	vec3 g2 = texture(grass_tex, vec2(xz.y, -xz.x) / 23.0).rgb;
	vec3 gt = mix(g2, g1, 0.55 + 0.25 * near);
	float gl = dot(gt, vec3(0.3, 0.59, 0.11));
	float patch = fbm(xz / 48.0);
	vec3 grass = mix(lin(vec3(0.33, 0.42, 0.16)), lin(vec3(0.42, 0.48, 0.20)), smoothstep(0.35, 0.7, patch));
	// Late summer: dry, straw-coloured patches on the rough grass.
	grass = mix(grass, lin(vec3(0.55, 0.52, 0.28)), smoothstep(0.6, 0.85, fbm(xz / 90.0 + 7.0)) * 0.55);
	grass *= 0.62 + 0.38 * clamp(gl / 0.36, 0.4, 1.5);
	grass *= 0.88 + 0.24 * vnoise(xz * 0.7);
	vec3 col = grass;
	float rough = 0.93;
	float spec = 0.35;

	// ---- Dirt on the steeper banks.
	float slope = 1.0 - nw.y;
	vec3 dirt = texture(dirt_tex, xz / 5.0).rgb * lin(vec3(0.95, 0.85, 0.72)) * 1.3;
	float dirt_w = smoothstep(0.12, 0.32, slope + (vnoise(xz / 6.0) - 0.5) * 0.12) * (1.0 - masks.g) * (1.0 - masks.b * 0.7);
	col = mix(col, dirt, dirt_w * 0.7);

	// ---- The garden's lawns: fine, dense, deep green, mown in stripes 2.5m wide that run east-west.
	if (masks.b > 0.01) {
		vec3 lawn = mix(lin(vec3(0.24, 0.42, 0.13)), lin(vec3(0.30, 0.50, 0.16)), smoothstep(0.3, 0.7, fbm(xz / 30.0 + 2.0)));
		lawn *= 0.75 + 0.3 * clamp(dot(texture(grass_tex, xz / 3.0).rgb, vec3(0.33)) / 0.33, 0.5, 1.4);
		float band = step(0.5, fract(xz.y / 5.0));
		lawn *= mix(0.9, 1.08, mix(band, 0.5, smoothstep(0.4, 1.6, fw)));
		col = mix(col, lawn, masks.b);
		rough = mix(rough, 0.86, masks.b);
	}

	// ---- Bed soil and mulch.
	if (masks.a > 0.01) {
		vec3 soil = dirt * lin(vec3(0.42, 0.34, 0.27)) * (0.7 + 0.4 * vnoise(xz * 1.3));
		vec3 bark = lin(vec3(0.30, 0.20, 0.13)) * (0.7 + 0.5 * hash12(floor(xz * 7.0)));
		vec3 bed = mix(soil, bark, smoothstep(0.35, 0.6, fbm(xz / 6.0)) * (1.0 - smoothstep(0.03, 0.1, fw)) * 0.7 + 0.15);
		vec3 moss = lin(vec3(0.20, 0.30, 0.10)) * (0.8 + 0.3 * vnoise(xz * 0.9));
		bed = mix(bed, moss, smoothstep(0.55, 0.8, fbm(xz / 9.0)) * 0.5);
		col = mix(col, bed, masks.a);
		rough = mix(rough, 0.95, masks.a);
	}

	// ---- The docks' ground: slag gravel, old concrete, oil, rust.
	if (masks.g > 0.01) {
		vec3 gr = texture(gravel_tex, xz / 3.2).rgb;
		float gl2 = dot(gr, vec3(0.33));
		vec3 slag = lin(vec3(0.33, 0.32, 0.30)) * (0.5 + gl2 * 1.6);
		float rust = smoothstep(0.58, 0.8, fbm(xz / 26.0 + 3.0));
		slag = mix(slag, lin(vec3(0.40, 0.24, 0.16)) * (0.6 + gl2), rust * 0.55);
		vec2 sc = xz / vec2(6.0, 4.0);
		vec2 sf = fract(sc);
		float slabs = smoothstep(0.52, 0.58, fbm(xz / 40.0 + 11.0));
		vec3 conc = texture(concrete_tex, xz / 4.0).rgb * lin(vec3(0.42, 0.41, 0.39)) * (0.85 + 0.25 * hash12(floor(sc)));
		float jt = 1.0 - smoothstep(0.0, 0.03 + fw * 0.2, min(min(sf.x, 1.0 - sf.x) * 6.0, min(sf.y, 1.0 - sf.y) * 4.0));
		conc *= 1.0 - 0.5 * jt * (1.0 - smoothstep(0.05, 0.2, fw));
		vec3 works = mix(slag, conc, slabs);
		float oil = smoothstep(0.66, 0.82, vnoise(xz / 7.0 + 40.0));
		works *= 1.0 - oil * 0.5;
		works = mix(works, grass * 0.8, smoothstep(0.72, 0.9, fbm(xz / 15.0 + 2.0)) * 0.5 * (1.0 - slabs));
		col = mix(col, works, masks.g);
		rough = mix(rough, 0.85, masks.g);
		vec3 gn = texture(gravel_normal, xz / 3.2).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(gn.x, 0.0, gn.y) * 0.5 * masks.g * (1.0 - slabs));
	}

	// ---- Mud: the building site and the scrapyard, churned by machines, with puddles.
	if (masks2.x > 0.01) {
		vec3 dm = texture(dirt_tex, xz / 4.0).rgb;
		vec3 mud = lin(vec3(0.40, 0.31, 0.22)) * (0.6 + 0.7 * dot(dm, vec3(0.33)));
		mud *= 0.8 + 0.3 * vnoise(xz / 9.0);
		// Caterpillar tracks: bands of ribs along a few directions.
		float trk = stripe((fract(dot(xz, vec2(0.8, 0.6)) / 7.0) - 0.5) * 7.0, 2.2, fw) * smoothstep(0.5, 0.65, vnoise(xz / 20.0));
		float ribs = step(0.5, fract(dot(xz, vec2(-0.6, 0.8)) * 2.4)) * (1.0 - smoothstep(0.03, 0.08, fw));
		mud *= 1.0 - 0.18 * trk * (0.6 + 0.4 * ribs);
		float pud = smoothstep(0.66, 0.70, vnoise(xz / 7.0 + 31.0) * 0.8 + (1.0 - nw.y) * -2.0 + 0.12);
		mud = mix(mud, lin(vec3(0.08, 0.07, 0.055)), pud * 0.85);
		col = mix(col, mud, masks2.x);
		rough = mix(rough, mix(0.9, 0.04, pud), masks2.x);
		spec = mix(spec, mix(0.35, 0.7, pud), masks2.x);
		vec3 dn2 = texture(dirt_normal, xz / 4.0).rgb * 2.0 - 1.0;
		nw = normalize(mix(nw + vec3(dn2.x, 0.0, dn2.y) * 0.45 * masks2.x, normalize(w_nrm), pud * masks2.x));
	}

	// ---- City paving: 0.5m grey concrete flags with granite bands every 8m.
	if (masks2.y > 0.01) {
		vec2 pg = xz / 0.5;
		vec2 pf = fract(pg);
		vec3 flag = texture(concrete_tex, xz / 3.0).rgb * lin(vec3(0.62, 0.61, 0.58)) * (0.86 + 0.2 * hash12(floor(pg)));
		float pj = 1.0 - smoothstep(0.003, 0.008 + fw * 0.5, min(min(pf.x, 1.0 - pf.x), min(pf.y, 1.0 - pf.y)) * 0.5);
		flag *= 1.0 - 0.4 * pj * (1.0 - smoothstep(0.03, 0.12, fw));
		float bands = max(stripe((fract(xz.x / 8.0) - 0.5) * 8.0, 0.32, fw), stripe((fract(xz.y / 8.0) - 0.5) * 8.0, 0.32, fw));
		flag = mix(flag, lin(vec3(0.33, 0.32, 0.31)) * (0.85 + 0.25 * hash12(floor(xz * 2.5))), bands);
		col = mix(col, flag, masks2.y);
		rough = mix(rough, 0.8, masks2.y);
		nw = normalize(mix(nw, normalize(w_nrm), masks2.y));
	}

	// ---- Stone on the steep faces: weathered limestone.
	if (masks.r > 0.01) {
		vec3 rk = texture(rock_tex, xz / 9.0 + vec2(w_pos.y / 7.0, 0.0)).rgb;
		vec3 stone = mix(vec3(dot(rk, vec3(0.33))), rk, 0.35) * lin(rock_tint) * 1.6;
		stone *= 0.8 + 0.3 * vnoise(vec2(xz.x + xz.y, w_pos.y * 3.0) / 2.5);
		stone = mix(stone, lin(vec3(0.22, 0.30, 0.12)), smoothstep(0.6, 0.85, fbm(xz / 5.0 + w_pos.y * 0.1)) * 0.35);
		col = mix(col, stone, masks.r);
		rough = mix(rough, 0.88, masks.r);
	}

	// ---- Wet silt by the water (the canal and the garden's pond).
	float wet = 1.0 - smoothstep(water_y + 0.05, water_y + 0.6, w_pos.y);
	col = mix(col, lin(vec3(0.20, 0.19, 0.14)) * (0.8 + 0.3 * vnoise(xz)), wet * 0.85);
	rough = mix(rough, 0.45, wet);

	vec3 dn = texture(dirt_normal, xz / 5.0).rgb * 2.0 - 1.0;
	nw = normalize(nw + vec3(dn.x, 0.0, dn.y) * 0.35 * max(dirt_w, masks.a) * near);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
