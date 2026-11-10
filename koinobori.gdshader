// Koinobori, the carp streamers of Children's Day (MiyoshinoPropKit.koinobori_pole, koinobori_line): an open cloth tube
// per carp, its mouth on a hoop, swimming downwind. Everything about a carp is in its vertices:
//   UV.x   0 at the mouth .. 1 at the tail's tip; UV.y 0 on its back, 0.5 under its belly, going round
//   COLOR  rgb the carp's colour; a the design: 0 a carp, 1 the five-coloured streamer (fukinagashi) over them
//   CUSTOM0 xy the horizontal sway axis (across the wind), z the carp's phase, w its length (metres)
// The vertex stage ripples it: the body swings across the wind and dips, more toward the tail, the waves running back
// from the mouth; the cloth breathes. The fragment stage paints scales, the eyes, the head band, the belly and the
// tail's stripes, and cuts the tail's fork. Seen from inside (the open mouth) it is darker, as cloth is.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float flap_speed = 2.6;
uniform float sway = 0.09;
uniform float dip = 0.045;
uniform vec3 gold : source_color = vec3(0.95, 0.76, 0.28);
uniform vec3 white : source_color = vec3(0.96, 0.95, 0.92);

varying float v_u;
varying float v_v;
varying vec4 v_col;
varying float v_len;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_u = UV.x;
	v_v = UV.y;
	v_col = COLOR;
	float len = max(CUSTOM0.w, 0.5);
	v_len = len;
	float ph = CUSTOM0.z;
	float t = TIME * flap_speed + ph;
	float u = UV.x;
	vec3 side = normalize(vec3(CUSTOM0.x, 0.0, CUSTOM0.y) + vec3(1e-4, 0.0, 0.0));
	float swing = sin(t - u * 5.0) + 0.35 * sin(t * 1.9 + ph * 0.7 - u * 9.0);
	float lift = sin(t * 0.7 + ph * 1.3 - u * 4.0);
	VERTEX += side * swing * sway * len * pow(u, 1.4);
	VERTEX.y += lift * dip * len * pow(u, 1.6);
	// The cloth breathes: the tube swells and slackens in waves running back along it.
	VERTEX += NORMAL * (0.035 * len * u * sin(t * 2.3 - u * 11.0));
}

void fragment() {
	float u = v_u;
	float v = v_v;
	vec3 base = v_col.rgb;
	vec3 col = base;
	float fw = max(fwidth(u), 1e-4);
	if (v_col.a > 0.5) {
		// The five-coloured streamer: blue, white, red, yellow, green in bands round it, ending in loose ribbons.
		float band = floor(fract(v) * 5.0);
		vec3 cs[5] = vec3[5](vec3(0.10, 0.25, 0.70), white, vec3(0.85, 0.10, 0.08), vec3(0.98, 0.80, 0.10), vec3(0.08, 0.55, 0.28));
		col = cs[int(band)];
		// A ring of gold and a crest at the mouth.
		col = mix(col, gold, step(u, 0.06));
		// The last third splits into ribbons: cut between the bands.
		float fb = fract(fract(v) * 5.0);
		if (u > 0.68 && (fb < 0.12 || fb > 0.88)) {
			discard;
		}
		if (u > 0.94 + 0.05 * hash12(vec2(band, 3.0))) {
			discard;
		}
	} else {
		// A carp: the head band, the eyes on its sides, scales down the body, a pale belly, the striped tail.
		float dark = step(dot(base, vec3(0.33)), 0.12);
		vec3 trim = mix(white, gold, dark);
		// The tail's fork: the tube is flattened there; cut a V from the tip.
		float side_v = abs(fract(v + 0.25) - 0.5) * 2.0;   // 0 on the back and belly (the tail's edges), 1 at the sides
		if (u > 0.9 && side_v > 1.0 - (u - 0.9) * 6.0) {
			discard;
		}
		// Scales: rows of arcs across the body.
		float su = u * 15.0;
		float sv = v * 12.0 + 0.5 * floor(su);
		vec2 cell = vec2(fract(su), fract(sv));
		float arc = length(vec2((cell.x - 1.0) * 1.15, cell.y - 0.5));
		float scale_line = 1.0 - smoothstep(0.04, 0.09 + fw * 8.0, abs(arc - 0.62));
		float body = step(0.13, u) * step(u, 0.86);
		col = mix(col, trim, scale_line * body * 0.85);
		// Scale shading: each scale a touch darker toward its edge.
		col *= mix(1.0, 0.82 + 0.18 * smoothstep(0.62, 0.2, arc), body);
		// The belly: paler (gold under a black carp, white under the others).
		float belly = 1.0 - smoothstep(0.12, 0.24, abs(v - 0.5));
		col = mix(col, trim * 0.95, belly * body * 0.6);
		// The head band: white with a colour edge; the gold-white hoop at the mouth.
		float head = step(u, 0.13) * step(0.03, u);
		col = mix(col, mix(white, trim, 0.25), head);
		col = mix(col, base, head * (1.0 - smoothstep(0.0, 0.015 + fw, abs(u - 0.115))));
		col = mix(col, gold, step(u, 0.03));
		// The eyes: on each side (v 0.25 and 0.75) just behind the mouth: a gold ring, white, a black pupil.
		// Round the tube is about 0.9 of the carp's length (its radius is 0.14 of it), so v is scaled by that.
		for (int k = 0; k < 2; k++) {
			float ev = k == 0 ? 0.25 : 0.75;
			vec2 e = vec2((u - 0.085) * v_len, (v - ev) * v_len * 0.9);
			float er = max(v_len * 0.062, 0.01);
			float r = length(e) / er;
			col = mix(col, gold, 1.0 - smoothstep(0.96, 1.04, r));
			col = mix(col, white, 1.0 - smoothstep(0.74, 0.8, r));
			col = mix(col, vec3(0.02), 1.0 - smoothstep(0.46, 0.52, r));
			col = mix(col, white, 1.0 - smoothstep(0.1, 0.16, length(e / er - vec2(-0.16, 0.2))));
		}
		// Fins: small painted ones under the body.
		float fin = (1.0 - smoothstep(0.0, 0.03, abs(u - 0.35))) + (1.0 - smoothstep(0.0, 0.025, abs(u - 0.62)));
		col = mix(col, trim, clamp(fin, 0.0, 1.0) * (1.0 - smoothstep(0.05, 0.1, abs(abs(v - 0.5) - 0.17))) * 0.8);
		// The tail: stripes of trim and colour.
		float tail = step(0.86, u);
		col = mix(col, trim, tail * step(0.5, fract(u * 30.0)) * 0.7);
	}
	// Inside the tube the cloth is shaded and the colour shows through.
	if (!FRONT_FACING) {
		col *= 0.45;
	}
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	// Thin cloth lets the light through.
	BACKLIGHT = pow(col, vec3(2.2)) * 0.35;
}
