// Painted structural steel for Rheinufer's bridges and the Autobahn's furniture (RheinBridgeKit.gd: keys "bsteel", "rivet",
// "msteel", "galv"). The vertex colour is the paint (sRGB). Weathering is laid from the world position as in
// industrial_paint.gdshader (patches, rust and dirt streaks running down the faces; no UVs needed), and with `rivets` on,
// rows of rivet heads are drawn from the UVs (metres, rows along u): the gusset and cover plates of the old bridge. The rivets
// fade to their average once a pitch gets smaller than a few pixels, so a plate far off doesn't shimmer.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float rust_amount : hint_range(0.0, 1.0) = 0.15;
uniform float grime : hint_range(0.0, 1.0) = 0.4;
uniform float rough = 0.6;
uniform float metal = 0.2;
uniform vec3 rust_color : source_color = vec3(0.42, 0.20, 0.09);
uniform float patch_size = 3.5;
uniform float rivets = 0.0;
// Rivets along u every rivet_pitch, in pairs of rows (at 18% and 82% of rivet_row) repeating every rivet_row along v.
uniform float rivet_pitch = 0.12;
uniform float rivet_row = 0.5;
uniform float rivet_r = 0.026;

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
	float h = mix(wpos.x, wpos.z, smoothstep(-0.2, 0.2, abs(n.x) - abs(n.z)));
	vec2 q = vec2(h, wpos.y);
	float flat_face = step(0.72, abs(n.y));
	q = mix(q, wpos.xz, flat_face);
	vec2 pq = q / patch_size;
	float patches = vnoise(pq + 3.1) * 0.65 + vnoise(pq * 3.1 + 7.7) * 0.35;
	vec2 sq = mix(vec2(q.x * 2.2, q.y * 0.09), q * 0.7, flat_face);
	float streak = vnoise(sq + 1.3);
	float speck = mix(0.5, vnoise(q * 9.0), fine);

	vec3 col = paint * (0.9 + 0.2 * speck);
	float g = grime * smoothstep(0.35, 0.95, streak * 0.75 + patches * 0.35);
	col *= 1.0 - 0.5 * g;
	float r = rust_amount * smoothstep(0.55, 0.85, patches + streak * 0.25 - 0.1 + speck * 0.08);
	vec3 rc = rust_color * (0.7 + 0.55 * speck) * (0.85 + 0.3 * patches);

	// Rivet heads: a dark ring round a lit dome on a grid in UV metres (taken outside any branch: fwidth).
	float ufw = length(fwidth(UV));
	float fu = fract(UV.x / rivet_pitch) - 0.5;
	float vv = fract(UV.y / rivet_row);
	float fv = (abs(vv - 0.18) < abs(vv - 0.82) ? vv - 0.18 : vv - 0.82) * rivet_row / rivet_pitch;
	vec2 f = vec2(fu, fv);
	float d = length(f) * rivet_pitch;
	float vis = rivets * (1.0 - smoothstep(rivet_pitch * 0.12, rivet_pitch * 0.45, ufw));
	float dome = 1.0 - smoothstep(rivet_r * 0.55, rivet_r, d);
	float ring = smoothstep(rivet_r * 0.75, rivet_r, d) * (1.0 - smoothstep(rivet_r, rivet_r * 1.35, d));
	float lit = clamp(0.5 - (f.x - f.y) * 2.2, 0.0, 1.0);
	col *= 1.0 - vis * (0.35 * ring - 0.12 * dome * lit);
	r *= 1.0 + vis * ring * 1.5;

	col = mix(col, rc, clamp(r, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.9, r);
	METALLIC = mix(metal, 0.05, r);
}
