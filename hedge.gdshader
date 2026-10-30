shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// A clipped hedge (beech, yew or box: RidgecrestKit.gd's "hedge"), drawn on a plain box. UV is in
// metres on every face and the vertex colour is the foliage's tint (sRGB). The leaves are a cell
// pattern at two scales, each cell a leaf facing a little its own way (the normal map), darker in the
// gaps between them, with sun-bleached tips on the top face and shade toward the foot.

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 17.31));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Distance to the nearest leaf centre and that leaf's id.
vec3 leaves(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			float d = length(g + o - f);
			if (d < best) {
				best = d;
				id = i + g;
			}
		}
	}
	return vec3(best, id);
}

void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	vec2 q = UV;
	vec3 big = leaves(q * 7.0);
	vec3 small = leaves(q * 16.0 + 3.7);
	float gap = smoothstep(0.35, 0.75, big.x) * 0.6 + smoothstep(0.45, 0.8, small.x) * 0.4;
	float lid = hash(big.yz);
	vec3 col = tint * (0.75 + 0.45 * lid) * (1.0 - 0.55 * gap);
	col *= 0.85 + 0.3 * vnoise(q * 0.8);
	// Fresh growth paler on top, the foot in shade.
	float up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	col = mix(col, tint * vec3(1.35, 1.4, 0.95), 0.3 * smoothstep(0.6, 0.9, up) * smoothstep(0.4, 0.8, vnoise(q * 3.0)));
	vec2 tilt = (hash2(big.yz + 5.0) - 0.5) * 0.9;
	NORMAL_MAP = normalize(vec3(tilt * (1.0 - gap), 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = col;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
	BACKLIGHT = tint * 0.25;
}
