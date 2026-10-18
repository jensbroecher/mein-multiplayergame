shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The start/finish gantry's LED screen (CheckpointGate.gd). It runs a ticker, waves a chequered flag
// (the last lap), or shows the start lights: three lamps that light red one by one through the
// countdown and all turn green at the start. The picture is sampled once per LED, so close up it
// reads as a dot matrix. Where an LED shrinks to a pixel or two the dots fade into their average,
// or the grid would shimmer into moire at a distance.

// LEDs across and down the screen.
uniform vec2 led_count = vec2(104.0, 35.0);
// 0 = the ticker (or the flag), 1 = start lights. CheckpointGate tweens between them.
uniform float board : hint_range(0.0, 1.0) = 0.0;
// 0 = the ticker, 1 = the chequered flag.
uniform float flag_mix : hint_range(0.0, 1.0) = 0.0;
// The ticker's text strip, ticker_ss texels to an LED, ticker_len LEDs long (it loops), scrolled
// ticker_scroll LEDs to the left, across ticker_rows rows in the middle of the screen.
uniform sampler2D ticker_tex : source_color, filter_linear, repeat_disable;
uniform float ticker_ss = 2.0;
uniform float ticker_rows = 18.0;
uniform float ticker_len = 0.0;
uniform float ticker_scroll = 0.0;
uniform float ticker_energy = 1.8;
// How far each lamp is lit red (countdown), and all three green (start).
uniform vec3 lamps_red = vec3(0.0);
uniform float lamps_green : hint_range(0.0, 1.0) = 0.0;
// Kept low on purpose: brighter, the tonemapper (ACES on most levels) bleaches the red to coral
// and the green to mint.
uniform float flag_energy = 2.0;
uniform float lamp_energy = 1.6;

const vec3 RED = vec3(1.0, 0.0, 0.0);
const vec3 GREEN = vec3(0.0, 1.0, 0.12);
// Lamp radius and spacing, in screen heights.
const float LAMP_R = 0.34;
const float LAMP_GAP = 0.96;
// LED radius as a share of the LED pitch, and the share of the screen the LEDs cover.
const float DOT_R = 0.4;
const float DOT_COVER = 0.503;

// p: screen heights from the centre, y up.
vec3 flag(vec2 p) {
	float t = TIME * 2.4;
	float ph = p.x * 2.6 - t;
	// The cloth billows: the rows ride the wave, and folds turned away from us go darker.
	vec2 q = vec2(p.x, p.y + sin(ph) * 0.06 + sin(p.x * 5.1 - t * 1.3 + p.y * 2.0) * 0.015);
	vec2 k = floor(q / 0.2);
	float white = mod(k.x + k.y, 2.0);
	float shade = 0.62 + 0.38 * (0.5 + 0.5 * cos(ph));
	return mix(vec3(0.012), vec3(1.0), white) * shade * flag_energy;
}

vec3 lights(vec2 p) {
	vec3 col = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float d = length(p - vec2((float(i) - 1.0) * LAMP_GAP, 0.0));
		float red = i == 0 ? lamps_red.x : (i == 1 ? lamps_red.y : lamps_red.z);
		vec3 lit = (RED * red * (1.0 - lamps_green) + GREEN * lamps_green) * lamp_energy;
		// A lens, brightest in the middle, inside a grey rim, with a faint halo round it when lit.
		float lens = 1.0 - smoothstep(LAMP_R - 0.025, LAMP_R, d);
		float hot = mix(0.8, 1.0, 1.0 - smoothstep(0.0, LAMP_R, d));
		float rim = smoothstep(LAMP_R + 0.01, LAMP_R + 0.035, d) * (1.0 - smoothstep(LAMP_R + 0.065, LAMP_R + 0.09, d));
		float halo = (1.0 - lens) * exp(-max(d - LAMP_R, 0.0) * 16.0) * 0.12;
		col += lens * (vec3(0.05, 0.012, 0.01) + lit * hot) + rim * vec3(0.1) + halo * lit;
	}
	return col;
}

// led: LEDs from the screen's top left corner.
vec3 ticker(vec2 led) {
	vec3 col = vec3(0.0);
	float row0 = (led_count.y - ticker_rows) * 0.5;
	float v = (led.y - row0) / ticker_rows;
	if (ticker_len > 0.0 && v >= 0.0 && v <= 1.0) {
		float x = mod(led.x + ticker_scroll, ticker_len);
		col = texture(ticker_tex, vec2(x * ticker_ss / float(textureSize(ticker_tex, 0).x), v)).rgb;
	}
	// Rules above and below the text, dashed, running with it.
	float dash = step(0.5, fract((led.x + ticker_scroll) / 6.0));
	float rule = step(abs(led.y - (row0 - 3.0)), 0.5) + step(abs(led.y - (row0 + ticker_rows + 3.0)), 0.5);
	col += vec3(1.0, 0.24, 0.18) * 0.45 * dash * rule;
	return col * ticker_energy;
}

vec3 picture(vec2 uv) {
	vec2 p = (uv - 0.5) * vec2(led_count.x / led_count.y, -1.0);
	vec3 col = mix(ticker(uv * led_count), flag(p), flag_mix);
	return mix(col, lights(p), board);
}

void fragment() {
	vec2 g = UV * led_count;
	vec2 cell = floor(g);
	// LEDs per pixel. At 0.4 an LED is 2.5 pixels wide and drawn as a dot; by 0.8 the dots are gone.
	float px = max(fwidth(g.x), fwidth(g.y));
	float detail = clamp(2.0 - px * 2.5, 0.0, 1.0);
	vec3 pic = picture(UV);
	float mask = DOT_COVER;
	if (detail > 0.0) {
		pic = mix(pic, picture((cell + 0.5) / led_count), detail);
		float r = length(g - cell - 0.5);
		float dots = 1.0 - smoothstep(DOT_R - 0.06 - px, DOT_R + px, r);
		mask = mix(DOT_COVER, dots, detail);
	}
	ALBEDO = vec3(0.012);
	// Matte, like a louvred LED face: a glossy one mirrors the sky and greys the black out.
	ROUGHNESS = 0.6;
	SPECULAR = 0.25;
	EMISSION = pic * mask;
}
