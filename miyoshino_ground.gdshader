// The Miyoshino GP's ground (MiyoshinoStage.gd, all four stages): the heightfield round the roads, which are ribbons of
// their own (miyoshino_road.gdshader). UV is world xz in metres, UV2.x the distance to the nearest road's centreline
// (metres; 99 far off), UV2.y how wet the ground is (0 dry .. 1 at a river's edge: shingle, wet sand, dark stones).
// The vertex colour carries the masks:
//   R  rock: steep faces and crags (grey-brown mountain rock in beds, mossy where it lies back)
//   G  bare ground: trodden earth and fine gravel (yards, precincts, lay-bys, the river's shingle with UV2.y)
//   B  cherry groves: fallen petals over the grass (pale pink drifts and flecks), and from afar the groves' own colour
//   A  cedar forest floor: brown needle litter, moss, ferns' shade; from afar the forest's dark green
// Spring grass elsewhere: fresh, with clover and dandelion flecks. Past `canopy_from` metres from the eye the forest and
// grove masks turn the ground into the canopy's colour, so hillsides beyond the planted trees still read as forest
// and blossom. Everything from world positions (never a hash of an interpolated colour).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 grass_a : source_color = vec3(0.26, 0.40, 0.15);
uniform vec3 grass_b : source_color = vec3(0.40, 0.50, 0.20);
uniform vec3 rock_tint : source_color = vec3(0.52, 0.49, 0.45);
uniform vec3 earth_tint : source_color = vec3(0.52, 0.45, 0.36);
uniform vec3 petal_color : source_color = vec3(0.97, 0.72, 0.80);
uniform vec3 canopy_forest : source_color = vec3(0.10, 0.19, 0.11);
uniform vec3 canopy_grove : source_color = vec3(0.93, 0.74, 0.80);
// Where the far canopy colour fades in (metres from the eye) and how much of the ground it takes.
uniform float canopy_from = 520.0;
uniform float canopy_full = 1500.0;
uniform float canopy_amount = 0.9;
// How much blossom lies on the ground under the groves (stage 1 full bloom 1.0; later stages more, petals falling).
uniform float petal_amount = 1.0;
// Moss on rock and earth (the high, damp trail).
uniform float moss_amount = 0.5;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;
varying float road_d;
varying float wet;

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

// A round fleck of radius r (metres) in some of the cells (`share` of them), anti-aliased by the pixel's size fw; it
// shrinks to nothing as the pixel grows past it.
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
	road_d = UV2.x;
	wet = UV2.y;
}

void fragment() {
	vec2 xz = w_pos.xz;
	float fw = length(fwidth(w_pos));
	float dist = length(VERTEX);
	vec3 nw = normalize(w_nrm);
	float near = 1.0 - smoothstep(60.0, 220.0, dist);
	float slope = 1.0 - nw.y;

	// ---- Spring grass: fresh, mottled, clover-white and dandelion-yellow flecks.
	vec3 g1 = texture(grass_tex, xz / 7.0).rgb;
	vec3 g2 = texture(grass_tex, vec2(xz.y, -xz.x) / 23.0).rgb;
	vec3 gt = mix(g2, g1, 0.55 + 0.25 * near);
	float gl = dot(gt, vec3(0.3, 0.59, 0.11));
	float patch = fbm(xz / 46.0);
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.32, 0.72, patch));
	grass *= 0.62 + 0.38 * clamp(gl / 0.36, 0.4, 1.5);
	grass *= 0.88 + 0.24 * vnoise(xz * 0.7);
	float bloom = smoothstep(0.42, 0.7, vnoise(xz / 13.0));
	float fy = fleck(xz, 3.0, 0.045, 0.09, 7.0, fw) * bloom;
	float fwh = fleck(xz + 0.17, 3.0, 0.035, 0.10, 13.0, fw) * bloom;
	grass = mix(grass, lin(vec3(0.92, 0.80, 0.14)), fy * 0.85);
	grass = mix(grass, lin(vec3(0.90, 0.90, 0.84)), fwh * 0.8);
	vec3 col = grass;
	float rough = 0.93;

	// ---- Earth on the steeper banks (road cuts and fills).
	vec3 dt = texture(dirt_tex, xz / 5.0).rgb;
	vec3 dirt = dt * earth_tint * 1.5;
	float dirt_w = smoothstep(0.14, 0.34, slope + (vnoise(xz / 6.0) - 0.5) * 0.12);
	col = mix(col, dirt, dirt_w * 0.65);

	// ---- Cedar forest floor: needle litter, moss.
	if (masks.a > 0.01) {
		vec3 litter = dt * lin(vec3(0.40, 0.33, 0.22)) * 1.35 * (0.75 + 0.4 * vnoise(xz * 1.3));
		vec3 moss = lin(vec3(0.20, 0.34, 0.10)) * (0.8 + 0.3 * vnoise(xz * 0.9));
		col = mix(col, mix(litter, moss, smoothstep(0.22, 0.55, fbm(xz / 9.0)) * (0.5 + 0.5 * moss_amount)), masks.a);
	}

	// ---- Bare ground: trodden earth and fine gravel; by the water, shingle and wet sand.
	if (masks.g > 0.01) {
		vec3 gr = texture(gravel_tex, xz / 3.0).rgb;
		float g3 = dot(gr, vec3(0.33));
		vec3 bare = mix(dirt * 1.05, earth_tint * (0.55 + g3 * 1.1), 0.5);
		bare *= 0.9 + 0.2 * vnoise(xz / 5.0);
		vec3 shingle = lin(vec3(0.66, 0.66, 0.62)) * (0.45 + g3 * 1.5);
		shingle = mix(shingle, lin(vec3(0.74, 0.70, 0.60)), smoothstep(0.45, 0.7, fbm(xz / 11.0)) * 0.6);
		shingle *= mix(1.0, 0.55, smoothstep(0.7, 1.0, wet));
		bare = mix(bare, shingle, smoothstep(0.05, 0.45, wet));
		col = mix(col, bare, masks.g);
		rough = mix(rough, mix(0.9, 0.45, smoothstep(0.75, 1.0, wet)), masks.g);
		vec3 gn = texture(gravel_normal, xz / 3.0).rgb * 2.0 - 1.0;
		nw = normalize(nw + vec3(gn.x, 0.0, gn.y) * 0.3 * masks.g * near);
	}

	// ---- Rock: bedded mountain rock on the steep faces, moss where it lies back.
	float rock_w = max(masks.r, smoothstep(0.42, 0.6, slope + (vnoise(xz / 4.0) - 0.5) * 0.1));
	if (rock_w > 0.01) {
		// Triplanar on the two upright planes (a top-down lookup smears down a cliff).
		vec3 bw = abs(nw);
		float wx = bw.x / max(bw.x + bw.z, 1e-4);
		vec3 r1 = texture(rock_tex, w_pos.zy / 6.0).rgb;
		vec3 r2 = texture(rock_tex, w_pos.xy / 6.0).rgb;
		vec3 r3 = texture(rock_tex, xz / 6.0).rgb;
		vec3 rt = mix(mix(r2, r1, wx), r3, smoothstep(0.55, 0.85, bw.y));
		float rl = dot(rt, vec3(0.33));
		float beds = vnoise(vec2(w_pos.y * 1.7 + vnoise(xz / 9.0) * 2.5, (xz.x + xz.y) / 30.0));
		vec3 rock = rock_tint * (0.5 + rl * 1.5) * (0.82 + 0.3 * beds);
		rock = mix(rock, rock * lin(vec3(0.62, 0.58, 0.52)), smoothstep(0.6, 0.8, fbm(vec2(xz.x + xz.y, w_pos.y * 3.0) / 7.0)) * 0.6);
		float mossy = smoothstep(0.35, 0.7, fbm(xz / 6.0 + w_pos.y * 0.13)) * smoothstep(0.75, 0.3, slope) * moss_amount;
		rock = mix(rock, lin(vec3(0.24, 0.36, 0.12)) * (0.7 + rl), mossy * 0.85);
		col = mix(col, rock, rock_w);
		rough = mix(rough, 0.88, rock_w);
	}

	// ---- Fallen blossom under the groves: drifts and single petals.
	float pm = masks.b * petal_amount * (1.0 - rock_w) * smoothstep(0.5, 0.2, slope);
	if (pm > 0.01) {
		float drift = smoothstep(0.5, 0.82, fbm(xz / 3.4 + 7.0)) * 0.6;
		float p1 = fleck(xz, 9.0, 0.028, 0.32, 3.0, fw);
		float p2 = fleck(xz + 0.31, 6.0, 0.032, 0.25, 11.0, fw);
		float cover = clamp(drift * 0.8 + max(p1, p2), 0.0, 1.0) * pm;
		// Past where single petals resolve, their average: a pink bloom on the grass.
		cover = mix(cover, pm * 0.16, smoothstep(0.03, 0.12, fw));
		col = mix(col, petal_color * (0.86 + 0.14 * vnoise(xz * 2.0)), cover * 0.8);
	}

	// The dirt's normal map on bare ground.
	vec3 dn = texture(dirt_normal, xz / 5.0).rgb * 2.0 - 1.0;
	nw = normalize(nw + vec3(dn.x, 0.0, dn.y) * 0.35 * max(dirt_w, masks.a) * near);

	// ---- From afar the woods are their canopies: the forest dark green, the groves blossom, mottled by big noise.
	float far = smoothstep(canopy_from, canopy_full, dist) * canopy_amount * (1.0 - rock_w * 0.8);
	if (far > 0.001) {
		float mot = fbm(xz / 60.0 + 31.0);
		vec3 forest = canopy_forest * (0.75 + 0.5 * mot);
		vec3 grove = canopy_grove * (0.85 + 0.25 * fbm(xz / 35.0 + 5.0));
		// Groves come in clouds on the forest: single big crowns and stands.
		float gcloud = smoothstep(0.38, 0.62, fbm(xz / 26.0 + 3.0));
		vec3 canopy = mix(forest, grove, clamp(masks.b * (0.35 + 0.65 * gcloud), 0.0, 1.0));
		col = mix(col, canopy, far * max(masks.a, masks.b));
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
