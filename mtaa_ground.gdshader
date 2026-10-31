shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Mtaa Nights' ground: one heightfield (regenerate_mtaa_nights.gd, in tiles) carrying the tarmac
// streets, the red murram back roads, the gravel of the backstage road, the pavements, the park's lawn,
// the bare earth of the jua kali yard and the club's paving.
//
// There is no road mesh. Every road is painted here from data the generator bakes per vertex:
//   CUSTOM0.x  metres from the nearest road's edge (negative on the road), the smooth minimum over all
//              of them, so junction corners are round and the edge is sharp however coarse the grid
//   CUSTOM0.y  metres across the nearest road (signed), CUSTOM0.z metres along it: the lane lines
//   CUSTOM0.w  where the lane lines are drawn (not at junctions, the start grid or the club)
//   COLOR      r murram, g gravel (else tarmac), b lawn, a bare earth (else pavement)
//   UV         x the club's paving, y the nearest road's half width
//   UV2        x a soft pool of lamplight baked from the street lamps (the real lights reach only
//              the road)

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 murram_tint : source_color = vec4(1.30, 0.70, 0.48, 1.0);
uniform vec4 gravel_tint : source_color = vec4(0.78, 0.74, 0.68, 1.0);
uniform vec4 lawn_color : source_color = vec4(0.30, 0.42, 0.16, 1.0);
uniform vec4 earth_tint : source_color = vec4(1.12, 0.72, 0.52, 1.0);
uniform vec4 lamp_color : source_color = vec4(1.0, 0.78, 0.52, 1.0);
uniform float lamp_energy = 0.22;

varying vec3 w_pos;
varying vec4 masks;
varying vec4 road;
varying vec2 extra;
varying vec2 extra2;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	masks = COLOR;
	road = CUSTOM0;
	extra = UV;
	extra2 = UV2;
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
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
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

// A line `w` wide centred on `c`, anti-aliased by the pixel's footprint `fw`.
float line(float x, float c, float w, float fw) {
	return 1.0 - smoothstep(w * 0.5 - fw, w * 0.5 + fw, abs(x - c));
}

void fragment() {
	vec2 xz = w_pos.xz;
	float cam_dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(60.0, 420.0, cam_dist);
	float edge = road.x;
	float lat = road.y;
	float along = road.z;
	float half_w = max(extra.y, 1.0);
	// Pixel footprint in metres, taken outside every branch (derivatives need the whole quad).
	float fw = max(length(fwidth(w_pos)) * 0.7, 0.01);
	float fw_edge = max(fwidth(edge), 0.01);

	// --- Off the road: pavement, lawn, bare earth, the club's paving --------------------------
	vec3 conc = texture(concrete_tex, xz * 0.18).rgb;
	vec3 pave = conc * vec3(0.78, 0.76, 0.73);
	// Slabs: a grid of 1.2m flags, joints darker, some flags a shade off.
	vec2 slab = xz / 1.2;
	vec2 sf = fract(slab);
	float joint = max(line(sf.x, 0.0, 0.05, fw / 1.2) + line(sf.x, 1.0, 0.05, fw / 1.2), line(sf.y, 0.0, 0.05, fw / 1.2) + line(sf.y, 1.0, 0.05, fw / 1.2));
	pave *= 0.86 + 0.22 * hash21(floor(slab));
	pave = mix(pave, pave * 0.55, clamp(joint, 0.0, 1.0) * detail);
	// Red dust from the back roads and grime in the gutters.
	pave = mix(pave, pave * vec3(1.08, 0.86, 0.74), smoothstep(0.55, 0.85, fbm(xz * 0.04)) * 0.5);

	float g_lum = dot(texture(grass_tex, xz * 0.23).rgb, vec3(0.30, 0.59, 0.11));
	float g_far = dot(texture(grass_tex, xz * 0.037).rgb, vec3(0.30, 0.59, 0.11));
	vec3 lawn = lawn_color.rgb * (0.62 + mix(g_far, g_lum, detail) * 0.75);
	// Mown stripes, and worn, browner patches where people cross.
	lawn *= 0.92 + 0.10 * step(0.5, fract(xz.x / 6.0));
	lawn = mix(lawn, vec3(0.36, 0.30, 0.18) * (0.8 + g_lum * 0.4), smoothstep(0.62, 0.86, fbm(xz * 0.03 + 3.0)) * 0.55);

	vec3 earth = texture(dirt_tex, xz * 0.14).rgb * earth_tint.rgb;
	earth = mix(earth, earth * vec3(0.55, 0.50, 0.46), smoothstep(0.6, 0.9, fbm(xz * 0.07 + 11.0)) * 0.6);

	// The club: warm grey pavers in a running bond, a scatter of darker ones.
	vec2 pv = xz / vec2(0.6, 0.3);
	pv.x += step(1.0, mod(floor(pv.y), 2.0)) * 0.5;
	vec2 pf = fract(pv);
	float pjoint = max(line(pf.x, 0.0, 0.08, fw / 0.6) + line(pf.x, 1.0, 0.08, fw / 0.6), line(pf.y, 0.0, 0.10, fw / 0.3) + line(pf.y, 1.0, 0.10, fw / 0.3));
	vec3 pavers = vec3(0.42, 0.38, 0.35) * (0.80 + 0.35 * hash21(floor(pv) * 0.37)) * (0.85 + conc * 0.3);
	pavers = mix(pavers, pavers * 0.45, clamp(pjoint, 0.0, 1.0) * detail * 0.8);

	vec3 ground = pave;
	float rough = 0.85;
	ground = mix(ground, lawn, masks.b);
	ground = mix(ground, earth, masks.a);
	ground = mix(ground, pavers, extra.x);
	rough = mix(rough, 0.95, max(masks.b, masks.a));

	// Kerb stones along every road's edge, outside the club and the back roads.
	float paved_road = (1.0 - masks.r) * (1.0 - masks.g);
	float kerb = (smoothstep(-fw_edge, fw_edge, edge) - smoothstep(0.38 - fw_edge, 0.38 + fw_edge, edge)) * paved_road * (1.0 - max(masks.b, masks.a));
	ground = mix(ground, vec3(0.62, 0.61, 0.58) * (0.85 + conc * 0.3), kerb);

	// --- The roads ---------------------------------------------------------------------------
	vec3 asph = texture(asphalt_tex, xz * 0.12).rgb * 0.75;
	asph = mix(asph, texture(asphalt_tex, xz * 0.031).rgb * 0.75, 0.35);
	asph *= 0.82 + 0.3 * fbm(xz * 0.05);
	// Worn patches and repairs.
	float patchy = smoothstep(0.62, 0.70, fbm(xz * 0.025 + 31.0)) * detail;
	asph = mix(asph, asph * vec3(0.72, 0.72, 0.74), patchy * 0.7);
	// Tyre-polished lanes: darker, smoother bands where the traffic runs.
	float lane_pos = abs(abs(lat) - half_w * 0.5);
	float polish = (1.0 - smoothstep(0.6, 1.8, lane_pos)) * detail;
	asph *= 1.0 - 0.12 * polish;
	float a_rough = mix(0.72, 0.55, polish);
	// Lane lines: a white edge line each side, a dashed yellow centre line (3m dashes, 6m gaps).
	float mark_w = clamp(road.w, 0.0, 1.0);
	float edge_line = line(abs(lat), half_w - 0.55, 0.16, fw);
	float dash = step(fract(along / 9.0), 0.34);
	float centre = line(lat, 0.0, 0.14, fw) * dash;
	float paint_wear = 0.55 + 0.45 * smoothstep(0.25, 0.6, fbm(xz * 0.6));
	asph = mix(asph, vec3(0.80, 0.80, 0.76), edge_line * mark_w * paint_wear);
	asph = mix(asph, vec3(0.86, 0.66, 0.16), centre * mark_w * paint_wear);
	// Inside the club the lane is paved like the grounds, edged with a painted line.
	asph = mix(asph, pavers * 0.9, extra.x);
	asph = mix(asph, vec3(0.75, 0.72, 0.66), edge_line * extra.x * 0.8);

	// Murram: red laterite, two compacted wheel tracks each way, loose windrows at the edges,
	// potholes holding water.
	float wob = (fbm(xz * 0.09) - 0.5) * 0.8;
	float al = abs(lat) + wob * 0.4;
	vec3 murram = texture(dirt_tex, xz * 0.16).rgb * murram_tint.rgb;
	murram = mix(murram, texture(dirt_tex, xz * 0.045).rgb * murram_tint.rgb, 0.4);
	murram *= 0.86 + fbm(xz * 0.05) * 0.26;
	float ruts = max(1.0 - smoothstep(0.15, 0.75, abs(al - half_w * 0.28)), 1.0 - smoothstep(0.15, 0.75, abs(al - half_w * 0.68)));
	ruts *= (0.6 + 0.4 * fbm(xz * 0.3)) * detail;
	murram = mix(murram, murram * vec3(0.74, 0.62, 0.56), ruts * 0.7);
	float windrow = (1.0 - smoothstep(0.3, 1.4, abs(al - (half_w - 0.8)))) * 0.35;
	murram = mix(murram, murram * vec3(1.16, 1.08, 1.0), windrow);
	float pot = smoothstep(0.80, 0.86, fbm(xz * 0.21 + 47.0)) * detail;
	murram = mix(murram, vec3(0.06, 0.05, 0.05), pot * 0.85);
	float m_rough = mix(mix(0.9, 0.78, ruts), 0.08, pot);

	vec3 gravel = texture(dirt_tex, xz * 0.25).rgb * gravel_tint.rgb;
	gravel = mix(gravel, vec3(0.30, 0.29, 0.28), smoothstep(0.4, 0.7, vnoise(xz * 3.1)) * 0.35 * detail);
	gravel *= 0.85 + 0.25 * fbm(xz * 0.08);

	vec3 rd = asph;
	float rd_rough = a_rough;
	rd = mix(rd, murram, masks.r);
	rd_rough = mix(rd_rough, m_rough, masks.r);
	rd = mix(rd, gravel, masks.g);
	rd_rough = mix(rd_rough, 0.92, masks.g);

	// The edge: tarmac stops sharp at its kerb; murram and gravel fray into the verge.
	float loose = max(masks.r, masks.g);
	float fray = (fbm(xz * 0.35) - 0.5) * 1.2 * loose;
	float soft = mix(fw_edge, 0.45, loose);
	float on_road = 1.0 - smoothstep(-soft, soft, edge - fray);
	// Murram dust settles on whatever lies beside it.
	ground = mix(ground, mix(ground, murram * 0.9, 0.55), (1.0 - smoothstep(0.0, 3.5, edge)) * masks.r);

	vec3 albedo = mix(ground, rd, on_road);
	rough = mix(rough, rd_rough, on_road);

	// A soft pool of lamplight on the pavements and verges round each street lamp (baked per vertex):
	// the real lights are few and reach the road, not the far side of every pavement.
	vec3 emis = lamp_color.rgb * lamp_energy * extra2.x * albedo;

	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = mix(0.35, 0.6, pot * masks.r * on_road);
	NORMAL_MAP = texture(dirt_normal, xz * 0.16).rgb;
	NORMAL_MAP_DEPTH = 0.4 * max(loose * on_road, masks.a) * detail;
	EMISSION = emis;
}
