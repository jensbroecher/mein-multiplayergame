shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Painted tyres of a tyre wall (regenerate_lakeside.gd, _tyre). Old road tyres: tread blocks with
// grooves round and across, sidewall ribs and a band of raised lettering, then brushed with paint that
// has worn off the tread and the edges, with scuffs and dust. No texture; bumps come from a height
// through screen-space derivatives.
//   UV.x   - round the tyre, 0..1
//   UV.y   - across its section: 0..0.3 the lower sidewall, 0.3..0.7 the tread, 0.7..1 the upper
//            sidewall, over 1 the inside of the ring
//   COLOR  - rgb the paint (black: not painted), a a random per tyre

uniform vec4 rubber : source_color = vec4(0.05, 0.05, 0.055, 1.0);
uniform vec4 dust : source_color = vec4(0.42, 0.38, 0.31, 1.0);
uniform float bump_strength = 1.0;

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

vec3 bump_normal(vec3 n, vec3 pos, float h, float k) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - k * grad);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float seed = COLOR.a;
	float inside = step(1.0, v);
	float tread = smoothstep(0.3, 0.33, v) * (1.0 - smoothstep(0.67, 0.7, v)) * (1.0 - inside);
	float side = (1.0 - tread) * (1.0 - inside);
	// Tread: two grooves round it, slanted grooves across every 1/56 of a turn, a sipe in each block.
	float tv = (v - 0.3) / 0.4;
	float ring = max(1.0 - smoothstep(0.0, 0.025, abs(tv - 0.33)), 1.0 - smoothstep(0.0, 0.025, abs(tv - 0.67)));
	float across = fract(u * 56.0 + (tv - 0.5) * (tv < 0.5 ? 1.2 : -1.2) + seed);
	float cross_g = 1.0 - smoothstep(0.06, 0.12, min(across, 1.0 - across));
	float sipe = 1.0 - smoothstep(0.0, 0.03, abs(fract(u * 112.0 + seed) - 0.5));
	float groove = tread * max(max(ring, cross_g * step(0.06, tv) * step(tv, 0.94)), sipe * 0.4);
	// Sidewalls: fine ribs round them and a band of raised lettering on each.
	float sv = v < 0.5 ? v / 0.3 : (1.0 - v) / 0.3;
	float ribs = side * smoothstep(0.35, 1.0, sin(sv * 90.0)) * step(0.15, sv) * 0.35;
	float band = side * step(0.42, sv) * step(sv, 0.62);
	vec2 cell = floor(vec2(u * 260.0, sv * 28.0));
	float word = step(0.35, fract(u * 9.0 + seed * 3.0));
	float letters = band * word * step(0.45, hash12(cell + seed * 91.0));
	float h = -groove * 1.0 + ribs + letters * 0.6;
	// Paint, worn off the tread's blocks and edges, flaking in patches; black tyres are bare rubber.
	float painted = step(0.25, max(COLOR.r, max(COLOR.g, COLOR.b)));
	float wear = vnoise(vec2(u * 70.0, v * 16.0) + seed * 40.0) * 0.55 + vnoise(vec2(u * 260.0, v * 60.0) + seed * 7.0) * 0.45;
	float edge = 1.0 - smoothstep(0.0, 0.06, min(abs(v - 0.3), abs(v - 0.7)));
	// Chips and scrapes: most of the paint holds, it wears through on the tread's blocks and edges.
	float bare = smoothstep(0.84, 0.88, wear + tread * 0.08 + edge * 0.2 + letters * 0.1);
	bare = max(bare, inside);
	// Vertex colours are sRGB.
	vec3 paint = pow(COLOR.rgb, vec3(2.2)) * mix(0.72, 0.92, vnoise(vec2(u * 6.0, v * 3.0) + seed * 11.0));
	// Brushed on: streaks of thinner paint where the rubber shows through a little.
	paint = mix(paint, rubber.rgb * 2.0, smoothstep(0.55, 0.9, vnoise(vec2(u * 120.0, v * 3.0) + seed * 5.0)) * 0.25);
	vec3 rub = rubber.rgb * mix(0.85, 1.6, smoothstep(0.4, 0.9, vnoise(vec2(u * 80.0, v * 20.0)))) * (1.0 - groove * 0.4);
	vec3 c = mix(paint, rub, painted > 0.5 ? bare : 1.0);
	// Dust settles on the upper sidewall; scuffs streak the tread.
	float dusty = smoothstep(0.75, 1.0, v) * (1.0 - inside) * vnoise(vec2(u * 12.0, v * 4.0) + seed * 3.0);
	c = mix(c, dust.rgb, dusty * 0.35);
	float scuff = tread * smoothstep(0.7, 0.9, vnoise(vec2(u * 18.0, v * 60.0) + seed * 13.0));
	c = mix(c, rubber.rgb * 1.8, scuff * 0.5);
	c *= 1.0 - inside * 0.5;
	ALBEDO = c;
	float fade = 1.0 - smoothstep(0.003, 0.012, fwidth(u) * 0.3 + fwidth(v) * 0.15);
	NORMAL = bump_normal(NORMAL, VERTEX, h * 0.006, bump_strength * fade);
	float gloss = painted > 0.5 ? (1.0 - bare) : 0.0;
	ROUGHNESS = mix(0.86, 0.42, gloss) + groove * 0.08;
	SPECULAR = mix(0.25, 0.45, gloss);
	AO = 1.0 - groove * 0.45 - inside * 0.3;
}
