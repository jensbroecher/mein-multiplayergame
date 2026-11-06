// Weathered paint, rust, weathering steel and grimy concrete for the Kronburger Hütte's big surfaces (SteelworksKit.gd:
// keys "rusty", "corten", "grime", "floor"): the blast furnace's shell, the hot-blast stoves, the gas holder, pipes,
// the cooling tower, the hall floor. No UVs: everything is laid from the world position, on the vertical plane the
// surface faces (the horizontal coordinate eased between x and z by the normal, so round tanks have no seam) or, on
// faces looking up or down, on the ground plane. Streaks run straight down the walls.
// The vertex colour is the paint (sRGB).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Rust patches and runs (0: none).
uniform float rust_amount : hint_range(0.0, 1.0) = 0.3;
// Soot and dirt streaks down the walls, oil stains on floors.
uniform float grime : hint_range(0.0, 1.0) = 0.4;
uniform float rough = 0.62;
uniform float metal = 0.2;
uniform vec3 rust_color : source_color = vec3(0.42, 0.19, 0.08);
// Weathering steel: rust all over, mottled from orange-brown to purple-brown, the vertex colour only a tint.
uniform float corten : hint_range(0.0, 1.0) = 0.0;
// The size of the patches, in metres.
uniform float patch_size = 3.0;

varying vec3 wpos;
varying vec3 wnrm;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	vec3 n = normalize(wnrm);
	float fw = length(fwidth(wpos));
	float fine = 1.0 - smoothstep(0.05, 0.4, fw);
	// The plane the pattern lies on.
	float h = mix(wpos.x, wpos.z, smoothstep(-0.2, 0.2, abs(n.x) - abs(n.z)));
	vec2 q = vec2(h, wpos.y);
	float flat_face = step(0.72, abs(n.y));
	q = mix(q, wpos.xz, flat_face);
	vec2 pq = q / patch_size;
	float patches = vnoise(pq + 3.1) * 0.65 + vnoise(pq * 3.1 + 7.7) * 0.35;
	// Streaks: long in y, narrow across (on flat faces: blotches).
	vec2 sq = mix(vec2(q.x * 2.2, q.y * 0.09), q * 0.7, flat_face);
	float streak = vnoise(sq + 1.3);
	float speck = mix(0.5, vnoise(q * 9.0), fine);

	vec3 col = paint * (0.9 + 0.2 * speck);
	// Grime: streaks darken down the walls, and stains on floors.
	float g = grime * smoothstep(0.35, 0.95, streak * 0.75 + patches * 0.35);
	col *= 1.0 - 0.55 * g;
	// Rust: patches growing out of the streaks.
	float r = rust_amount * smoothstep(0.55, 0.85, patches + streak * 0.25 - 0.1 + speck * 0.08);
	vec3 rc = rust_color * (0.7 + 0.55 * speck) * (0.85 + 0.3 * patches);
	col = mix(col, rc, clamp(r, 0.0, 1.0));
	float ro = mix(rough, 0.9, r);
	float me = mix(metal, 0.05, r);
	// Weathering steel.
	vec3 ct = rust_color * mix(vec3(1.15, 0.92, 0.8), vec3(0.62, 0.42, 0.42), patches) * (0.8 + 0.4 * speck);
	ct *= mix(vec3(1.0), paint * 2.0, 0.25);
	ct *= 1.0 - 0.35 * g;
	col = mix(col, ct, corten);
	ro = mix(ro, 0.82 + 0.12 * speck, corten);
	me = mix(me, 0.1, corten);
	ALBEDO = col;
	ROUGHNESS = ro;
	METALLIC = me;
}
