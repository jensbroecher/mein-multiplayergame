shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Club Kilele's LED dancefloor (Mtaa Nights): square glass tiles over LEDs in a dark glossy frame.
// The patterns run on the clock at `bpm`: a colour wave rolling across, rings out from the middle and
// a slow checker, crossfading every eight bars, each beat a soft swell (never a flash). Tiles under a
// cart light up white and fade behind it: ClubLights.gd feeds the carts' positions in every frame.
// UV is metres across the floor from its corner; `size` the floor's size in metres.

uniform vec2 size = vec2(60.0, 36.0);
uniform float tile = 1.5;
uniform float bpm = 124.0;
uniform float energy = 2.2;
uniform vec3 colour_a : source_color = vec3(1.0, 0.10, 0.55);
uniform vec3 colour_b : source_color = vec3(0.10, 0.55, 1.0);
uniform vec3 colour_c : source_color = vec3(0.65, 0.15, 1.0);
uniform vec3 colour_d : source_color = vec3(1.0, 0.55, 0.05);
uniform int cart_count = 0;
uniform vec3 cart_pos[8];
uniform float clock = 0.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 palette(float t) {
	t = fract(t) * 4.0;
	if (t < 1.0) return mix(colour_a, colour_b, t);
	if (t < 2.0) return mix(colour_b, colour_c, t - 1.0);
	if (t < 3.0) return mix(colour_c, colour_d, t - 2.0);
	return mix(colour_d, colour_a, t - 3.0);
}

void fragment() {
	vec2 cell = floor(UV / tile);
	vec2 f = fract(UV / tile);
	vec2 c = (cell + 0.5) * tile;
	float beat_t = clock * bpm / 60.0;
	float beat = fract(beat_t);
	float bar = floor(beat_t / 4.0);
	// Each beat swells and settles (an attack over a tenth of the beat), never blinking out.
	float pulse = 0.55 + 0.45 * exp(-beat * 3.5);
	vec2 mid = size * 0.5;
	// Three patterns, crossfading every eight bars.
	float wave = sin((c.x * 0.18 + c.y * 0.07) - beat_t * 0.9) * 0.5 + 0.5;
	float ring = sin(length(c - mid) * 0.35 - beat_t * 1.6) * 0.5 + 0.5;
	float chk = mod(cell.x + cell.y + floor(beat_t / 2.0), 2.0);
	float phase = mod(floor(bar / 8.0), 3.0);
	float blend = smoothstep(0.75, 1.0, fract(bar / 8.0));
	float pa = phase < 0.5 ? wave : (phase < 1.5 ? ring : chk);
	float pb = phase < 0.5 ? ring : (phase < 1.5 ? chk : wave);
	float lvl = mix(pa, pb, blend);
	vec3 col = palette(lvl * 0.5 + bar * 0.0625 + hash21(cell) * 0.08) * (0.25 + 0.75 * lvl) * pulse;
	// Under a cart: white, fading out over a few metres.
	float glow = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= cart_count) break;
		float d = length(w_pos.xz - cart_pos[i].xz);
		glow = max(glow, 1.0 - smoothstep(0.8, 4.5, d));
	}
	col = mix(col, vec3(1.0, 0.95, 0.9) * 1.6, glow);
	// The tile's glass and the dark frame between tiles.
	float inset = 0.06;
	float tile_mask = step(inset, f.x) * step(f.x, 1.0 - inset) * step(inset, f.y) * step(f.y, 1.0 - inset);
	// Brighter in the middle of a tile, like a diffuser over an LED panel.
	float diffuse = 1.0 - 0.35 * length(f - 0.5);
	ALBEDO = mix(vec3(0.02), col * 0.05, tile_mask);
	ROUGHNESS = mix(0.25, 0.08, tile_mask);
	METALLIC = 0.0;
	SPECULAR = 0.7;
	EMISSION = col * energy * diffuse * tile_mask;
}
