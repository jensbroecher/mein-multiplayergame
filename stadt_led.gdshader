// A dot-matrix display (StadtKit.gd, key "led"): the trams' and buses' destination displays, the station's train
// indicators and the tram stop's departure board. Lit and unshaded: dark glass with lines of amber (the vertex colour)
// characters, 5 x 7 dots each, in words of made-up letters (no font: a hash picks each dot), from the panel's top left.
// UV is in game metres (u along the panel from its left edge, v down from its top edge); `dot_pitch` is the dots' pitch in game
// metres. Under a dot a pixel the characters fade to a dim even glow, so a far display doesn't sparkle.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float dot_pitch = 0.035;
uniform float energy = 2.0;
uniform float line_gap = 2.0;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 led = pow(COLOR.rgb, vec3(2.2));
	vec2 q = UV / dot_pitch;
	vec2 cellid = floor(q);
	vec2 f = fract(q) - 0.5;
	float aa = length(fwidth(q));
	// Characters 6 dots wide (5 and a gap) on lines 7 + line_gap dots tall, a margin of one dot.
	float lx = cellid.x - 1.0;
	float ly = cellid.y - 1.0;
	float ch = floor(lx / 6.0);
	float cx = lx - ch * 6.0;
	float lh = 7.0 + line_gap;
	float line_ = floor(ly / lh);
	float cy = ly - line_ * lh;
	float in_char = step(0.0, lx) * step(0.0, ly) * step(cx, 4.0) * step(cy, 6.0);
	// Words: a run of characters, a space now and then; each line shorter or longer.
	float word = step(0.16, hash12(vec2(ch * 1.7, line_ * 3.1 + 11.0)));
	float len = 6.0 + floor(hash12(vec2(line_, 4.4)) * 18.0);
	word *= step(ch, len);
	float lit = step(0.46, hash12(vec2(ch * 7.0 + cx, line_ * 13.0 + cy * 2.3))) * in_char * word;
	float spot = 1.0 - smoothstep(0.28, 0.42, length(f));
	float on = mix(lit * spot, 0.18, smoothstep(0.35, 0.9, aa));
	vec3 bg = vec3(0.012, 0.012, 0.014);
	ALBEDO = bg + led * energy * on + led * 0.04 * spot * in_char;
}
