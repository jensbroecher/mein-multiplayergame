shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Marina Nights' ground (regenerate_marina_nights.gd, TerrainGenerator's heightfield): the city's pavements and
// plazas in large sandstone slabs laid in courses with darker joints (UVs from the world position), polished a
// little by feet so the lamps glint in them; dressed stone on the quays' faces (steep), silt under the water.
// `ground_map` (world xz over map_min..map_max): R the corniche's promenade (a patterned border of darker stone, a
// lighter field), G planted beds (sand and gravel round the palms).

uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_map : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-1000.0);
uniform vec2 map_max = vec2(1000.0);
uniform vec4 slab_a : source_color = vec4(0.62, 0.56, 0.48, 1.0);
uniform vec4 slab_b : source_color = vec4(0.52, 0.47, 0.41, 1.0);
uniform vec4 joint : source_color = vec4(0.30, 0.27, 0.24, 1.0);
uniform vec4 promenade : source_color = vec4(0.72, 0.66, 0.58, 1.0);
uniform vec4 border : source_color = vec4(0.42, 0.34, 0.30, 1.0);
uniform vec4 quay : source_color = vec4(0.62, 0.56, 0.48, 1.0);
uniform vec4 silt : source_color = vec4(0.22, 0.24, 0.20, 1.0);
uniform vec4 bed_sand : source_color = vec4(0.70, 0.60, 0.46, 1.0);
uniform float water_y = 0.0;
uniform float land_y = 2.2;

varying vec3 w_pos;
varying vec3 w_nrm;

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

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec2 xz = w_pos.xz;
	float fw = length(fwidth(w_pos));
	vec2 muv = (xz - map_min) / (map_max - map_min);
	vec4 gm = (muv.x > 0.0 && muv.y > 0.0 && muv.x < 1.0 && muv.y < 1.0) ? texture(ground_map, muv) : vec4(0.0);

	// Slabs 1.2 x 0.8m in running courses, each its own shade, joints fading with distance.
	vec2 g = xz / vec2(1.2, 0.8);
	float row = floor(g.y);
	g.x += 0.5 * mod(row, 2.0);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = hash12(id);
	vec3 slab = mix(slab_a.rgb, slab_b.rgb, h) * (0.9 + 0.2 * vnoise(xz * 0.7));
	slab *= mix(vec3(1.0), texture(concrete_tex, xz * 0.35).rgb / 0.6, 0.35);
	float jd = min(min(f.x, 1.0 - f.x) * 1.2, min(f.y, 1.0 - f.y) * 0.8);
	float jt = (1.0 - smoothstep(0.012, 0.03, jd)) * (1.0 - smoothstep(0.02, 0.12, fw));
	vec3 col = mix(slab, joint.rgb, jt * 0.8);
	// The promenade: a light field framed by bands of dark stone, set out across the map's R as a distance.
	float pr = gm.r;
	// A border of dark stone along both edges; the field's slabs set diagonally in two tones.
	float band = 1.0 - smoothstep(0.06, 0.08, min(pr, 1.0 - pr));
	vec2 dg = floor(vec2(xz.x + xz.y, xz.x - xz.y) / 1.7);
	float chk = mod(dg.x + dg.y, 2.0);
	vec3 field = promenade.rgb * (0.86 + 0.1 * chk + 0.06 * h);
	col = mix(col, mix(field, border.rgb, band), smoothstep(0.01, 0.03, pr));
	// Planted beds round the palms.
	vec3 bed = texture(sand_tex, xz * 0.25).rgb * vec3(0.95, 0.82, 0.66);
	col = mix(col, bed, smoothstep(0.3, 0.6, gm.g));
	float rough = mix(0.62, 0.9, smoothstep(0.3, 0.6, gm.g)) - 0.12 * (1.0 - jt) * (1.0 - gm.g);

	// Quays: dressed stone courses on the steep faces.
	float steep = 1.0 - n.y;
	float qf = smoothstep(0.35, 0.6, steep);
	vec3 st = texture(stone_tex, vec2(xz.x + xz.y, w_pos.y) * 0.3).rgb;
	float course = 1.0 - smoothstep(0.0, 0.05, abs(fract(w_pos.y / 0.6) - 0.5) - 0.42);
	vec3 qcol = quay.rgb * (st / 0.55) * (1.0 - 0.35 * course);
	// The tide line and weed near the water.
	qcol = mix(qcol, vec3(0.14, 0.16, 0.12), 1.0 - smoothstep(water_y + 0.1, water_y + 0.6, w_pos.y));
	col = mix(col, qcol, qf);
	rough = mix(rough, 0.85, qf);
	// Under the water: silt over sand.
	float under = 1.0 - smoothstep(water_y - 0.4, water_y + 0.1, w_pos.y);
	col = mix(col, mix(bed_sand.rgb, silt.rgb, smoothstep(water_y - 1.0, water_y - 5.0, w_pos.y)) * 0.8, under * (1.0 - qf * 0.5));

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	vec3 sn = texture(stone_normal, vec2(xz.x + xz.y, w_pos.y) * 0.3).rgb * 2.0 - 1.0;
	vec3 nw = n + vec3(sn.x, 0.0, sn.y) * 0.35 * qf;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(nw), 0.0)).xyz);
}
