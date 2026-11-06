shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Pantiles (Hohlpfannen) for the Lower Rhine's farmsteads (NiederrheinKit.gd, Rheinufer): S-shaped clay tiles in courses up
// the slope, their rolls lining up in straight columns down the roof (pantiles aren't staggered). UV in world metres times
// the kit's scale (u along the eave, v up the slope); the vertex colour is the clay's tint (orange-red, or a darker
// engobe). Each tile's pan, roll and lower edge shade it, the course above throws a shadow over its top, and the pattern
// fades to its average by the pixel's size in metres (as hut_masonry's styles 9 to 12) so a roof far off doesn't crawl.

// A tile's cover width and a course's height up the slope, in UV units (life metres x 1.6: 0.22m and 0.33m).
uniform float tile_w = 0.36;
uniform float course = 0.52;

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

void fragment() {
	vec2 q = UV;
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float fw = length(fwidth(q));
	float fade = smoothstep(0.03, 0.12, fw);
	float col_id = floor(q.x / tile_w);
	float x = fract(q.x / tile_w);
	float row = floor(q.y / course);
	float y = fract(q.y / course);
	// The S across a tile: a broad pan (down) from x 0 to 0.62, then the roll (up) to 1, which laps over the next pan.
	float h;
	float dh;
	if (x < 0.62) {
		float t = x / 0.62;
		h = -0.55 * sin(PI * t);
		dh = -0.55 * PI * cos(PI * t) / 0.62;
	} else {
		float t = (x - 0.62) / 0.38;
		h = sin(PI * t);
		dh = PI * cos(PI * t) / 0.38;
	}
	float tid = hash12(vec2(col_id, row));
	float tid2 = hash12(vec2(col_id + 17.1, row - 3.7));
	vec3 tile = tint * (0.84 + 0.28 * tid);
	tile = mix(tile, tint * vec3(0.66, 0.58, 0.55), step(0.86, tid2) * 0.8);
	tile = mix(tile, tint * vec3(1.12, 1.04, 0.92), step(tid2, 0.07) * 0.7);
	// Far off, the tiles' differences blend to the roof's mean colour (single tiles sparkled as noise at a distance).
	tile = mix(tile, tint * 0.97, fade * 0.85);
	tile *= 0.88 + 0.18 * vnoise(q * 0.4 + 3.0);
	tile *= 0.95 + 0.1 * vnoise(q * 16.0) * (1.0 - fade);
	// Light: the pan lies in shade, the roll's crest catches it; the course above shades this tile's top (the lap), and the
	// tile's own lower edge throws a thin shadow on the course below.
	float relief = 0.86 + 0.14 * h;
	float lap = 1.0 - smoothstep(0.0, 0.1, 1.0 - y);
	float edge = 1.0 - smoothstep(0.0, 0.05, y);
	float pat = mix(relief * (1.0 - 0.32 * lap) * (1.0 - 0.38 * edge), 0.88, fade);
	vec3 col = tile * pat;
	// Lichen spots and moss in the pans, most on the lower courses.
	float lichen = smoothstep(0.78, 0.92, vnoise(q * 2.1 + 5.0)) * smoothstep(0.55, 0.8, vnoise(q * 11.0 + 2.0));
	col = mix(col, pow(vec3(0.66, 0.62, 0.46), vec3(2.2)), lichen * 0.25);
	float moss = smoothstep(0.6, 0.85, vnoise(q * 0.8 + 9.0)) * step(x, 0.62) * (1.0 - fade);
	col = mix(col, pow(vec3(0.24, 0.29, 0.13), vec3(2.2)), moss * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.78;
	SPECULAR = 0.22;
	vec3 n = normalize(vec3(-dh * 0.09 * (1.0 - fade), -0.5 * edge * (1.0 - fade) - 0.12 * (1.0 - fade), 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
