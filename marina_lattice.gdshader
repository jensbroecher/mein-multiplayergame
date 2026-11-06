// Mashrabiya lattice (regenerate_marina_nights.gd: the covered arcade's vaults and screens, Burj al-Fanous's lantern):
// a geometric screen of eight-pointed stars, each in a ring with a boss in its middle, tied by struts to a grid of bars,
// the holes cut out (discard) so the night sky or the lit hall shows through. UV is in metres across the surface,
// `cell` the pattern's period. The bars are gilded stone, backlit warm at night: they glow at the holes' edges, as
// light spilling through a screen does (`glow`, over a `glow_base` all over). COLOR tints it. Drawn from both sides.
// Far off the holes close up (a cell under `min_px` pixels), so the lattice reads as a lit surface instead of moire.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float cell = 2.4;
uniform float bar = 0.13;
uniform float star = 0.33;
uniform vec3 stone : source_color = vec3(0.86, 0.66, 0.38);
uniform vec3 glow_col : source_color = vec3(1.0, 0.68, 0.32);
uniform float glow = 1.6;
uniform float glow_base = 0.12;
// Fade the holes out between these screen sizes of a cell (pixels).
uniform float min_px = 6.0;

varying vec3 v_col;

// The signed distance (cell units) to an eight-pointed star of half size s at the origin.
float sd_star8(vec2 p, float s) {
	vec2 q = abs(p);
	float a = max(q.x, q.y) - s;
	vec2 r = vec2(p.x - p.y, p.x + p.y) * 0.70710678;
	vec2 rq = abs(r);
	float b = max(rq.x, rq.y) - s;
	return min(a, b);
}

void vertex() {
	v_col = COLOR.rgb;
}

void fragment() {
	vec2 uv = UV / cell;
	vec2 p = fract(uv) - 0.5;
	float fw = max(length(fwidth(uv)), 1e-4);
	// The solid: a ring round each star, a bar along each cell edge, and the four struts that tie the star's points to
	// the edges.
	float d_star = sd_star8(p, star);
	float ring = abs(d_star) - bar * 0.5;
	float grid = (0.5 - max(abs(p.x), abs(p.y))) - bar * 0.5;
	float strut = min(min(abs(p.x), abs(p.y)), min(abs(p.x - p.y), abs(p.x + p.y)) * 0.70710678) - bar * 0.35;
	strut = max(strut, -d_star);
	// A boss in each star's middle.
	float boss = length(p) - star * 0.3;
	float solid_d = min(min(min(ring, grid), strut), boss);
	// Far off (a cell under min_px pixels) the holes close up into a lit surface.
	float px = 1.0 / fw;
	float open = smoothstep(min_px * 0.5, min_px, px);
	float hole = clamp(solid_d / fw + 0.5, 0.0, 1.0) * open;
	if (hole > 0.5) {
		discard;
	}
	// Light spills round the holes' edges; the stone's middle stays darker.
	float edge = 1.0 - smoothstep(0.0, bar * 0.9, -solid_d);
	vec3 base = stone * v_col;
	ALBEDO = base;
	ROUGHNESS = 0.55;
	METALLIC = 0.15;
	EMISSION = glow_col * glow * (glow_base + edge * 0.85 + (1.0 - open) * 0.35) * v_col;
}
