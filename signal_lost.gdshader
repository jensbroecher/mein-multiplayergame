shader_type canvas_item;

// The race camera's feed breaking up and cutting out (SignalLostOverlay.gd): drawn over the 3D view, under the HUD.
// `glitch` (0..1) tears the picture into shifted bands, shuffles blocks of it, splits its colours and lays scanlines and
// grain over it; `cut` (0..1) takes the picture away for dim digital static. Everything steps at `rate` patterns a
// second, as a broken digital feed does, never per frame, and the static stays dark: no bright flashing (motion comfort).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float cut : hint_range(0.0, 1.0) = 0.0;
uniform float rate = 12.0;
uniform float seed = 0.0;

float h11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float t = floor(TIME * rate) + seed * 17.0;
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// Tear bands: rows of a random height each step, some of them shifted sideways.
	float rows = mix(10.0, 46.0, h11(t * 1.31));
	float band = floor(uv.y * rows);
	float on = step(1.0 - glitch * 0.55, h21(vec2(band * 1.7, t + 3.0)));
	float shift = (h21(vec2(band, t)) - 0.5) * 0.14 * glitch * on;
	uv.x = fract(uv.x + shift);
	// Macroblocks: square blocks of the picture taken from somewhere else, and a few frozen grey ones.
	vec2 bsize = px * mix(18.0, 40.0, h11(t + 7.0));
	vec2 block = floor(uv / bsize);
	float bk = h21(block + vec2(t * 3.1, t * 1.7));
	float moved = step(bk, glitch * 0.16);
	vec2 src = (floor(vec2(h21(block + t + 1.0), h21(block + t + 2.0)) / bsize) + fract(uv / bsize)) * bsize;
	uv = mix(uv, src, moved);
	// Colour split along the tear.
	float split = px.x * (3.0 + 14.0 * abs(shift) / max(px.x, 1e-5) * 0.02) * glitch * 3.0;
	vec3 col;
	col.r = textureLod(screen_tex, uv + vec2(split, 0.0), 0.0).r;
	col.g = textureLod(screen_tex, uv, 0.0).g;
	col.b = textureLod(screen_tex, uv - vec2(split, 0.0), 0.0).b;
	// Blocks that lost their data: flat colour from the block's own corner, posterised.
	float dead = step(bk, glitch * 0.05) * (1.0 - moved);
	vec3 flat_col = textureLod(screen_tex, (block + 0.5) * bsize, 4.0).rgb;
	col = mix(col, floor(flat_col * 5.0) / 5.0, dead);
	// Posterise a little, scanlines and grain.
	col = mix(col, floor(col * 12.0) / 12.0, glitch * 0.6);
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	col *= 1.0 - 0.14 * glitch * scan;
	float grain = h21(floor(FRAGCOORD.xy / 2.0) + t * 13.0);
	col = mix(col, vec3(grain), glitch * 0.1);
	// The cut: dark static in coarse grains, rolling bands, a faint blue-grey cast.
	float g2 = h21(floor(FRAGCOORD.xy / 3.0) + vec2(t * 7.0, t * 3.0));
	float roll = 0.75 + 0.25 * step(0.5, fract(SCREEN_UV.y * 3.0 - TIME * 0.35));
	vec3 st = vec3(0.03, 0.04, 0.06) + vec3(g2 * 0.22 * roll);
	col = mix(col, st, cut);
	COLOR = vec4(col, 1.0);
}
