shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Round timber for the Miyoshino GP (MiyoshinoRiverKit._log, key "log"): the bark of a felled cedar, peeled cedar (the
// rafts' logs, posts) and the sawn ends, all in the shader from the log's own coordinates, so a log reads as wood however
// close the camera comes. Vertex data:
//   COLOR.a  what this is: under 0.2 bark, 0.2..0.5 peeled wood, over 0.5 a cut end
//   COLOR.r  the log's radius there (life metres / 0.5)
//   COLOR.g  a seed (0..1) for the log
//   COLOR.b  how much darker this log is (weathering, shade)
//   UV       on the sides: x the angle round the log (0..1), y metres along it; on an end: the place on the face,
//            -1..1 across it (1 the outside of the wood)
// Fine patterns fade to their average by the pixel's size, or they shimmer on distant stacks.

#include "res://granite.gdshaderinc"

uniform vec3 bark_red : source_color = vec3(0.36, 0.22, 0.15);
uniform vec3 bark_grey : source_color = vec3(0.40, 0.35, 0.31);
uniform vec3 bark_deep : source_color = vec3(0.09, 0.06, 0.05);
uniform vec3 peeled_light : source_color = vec3(0.86, 0.74, 0.55);
uniform vec3 peeled_dark : source_color = vec3(0.70, 0.55, 0.38);
uniform vec3 inner_bark : source_color = vec3(0.52, 0.27, 0.16);
uniform vec3 sapwood : source_color = vec3(0.90, 0.79, 0.60);
uniform vec3 heartwood : source_color = vec3(0.66, 0.40, 0.30);
uniform vec3 weathered : source_color = vec3(0.56, 0.52, 0.47);

varying float v_part;
varying float v_rad;
varying float v_seed;
varying float v_shade;

void vertex() {
	v_part = COLOR.a;
	v_rad = COLOR.r * 0.5;
	v_seed = COLOR.g;
	v_shade = COLOR.b;
}

float h1(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec3 col;
	float h = 0.0;
	float rough = 0.85;
	float fw;
	if (v_part > 0.5) {
		// --- A cut end: growth rings round a pith a little off the middle, sapwood to heartwood, radial checks, saw
		// marks, the bark's rim (on a barked log) and the end greyed by the weather on old cuts.
		vec2 p = UV;
		fw = length(fwidth(p)) * v_rad;
		vec2 pith = vec2(h1(v_seed * 7.1) - 0.5, h1(v_seed * 3.7) - 0.5) * 0.22;
		vec2 q = p - pith * (1.0 - length(p));
		float r = length(q);
		float ang = atan(q.y, q.x);
		float wob = gr_noise(vec3(cos(ang) * 2.5, sin(ang) * 2.5, v_seed * 40.0)) * 0.06;
		float rr = (r + wob) * v_rad;
		// Rings about 5mm apart (life), late wood darker, shown only while a ring spans several pixels (or they crawl).
		float ring_n = rr / 0.005;
		float ring = smoothstep(0.55, 0.95, fract(ring_n)) * (1.0 - smoothstep(0.0006, 0.0014, fw));
		// Further off, a soft hint of them: a few broad bands of tone.
		float bands = 0.5 + 0.5 * sin(rr / 0.03 + gr_noise(vec3(cos(ang), sin(ang), v_seed * 9.0)) * 2.0);
		float heart = 1.0 - smoothstep(0.52, 0.62, r + wob * 0.6);
		col = mix(sapwood, heartwood, heart);
		col *= 1.0 - ring * mix(0.10, 0.20, heart) - bands * 0.06;
		// Coarser bands every few years and the tone across the face.
		col *= 0.92 + 0.12 * gr_noise(vec3(rr * 60.0, v_seed * 13.0, 0.0));
		// Saw marks: faint straight lines across the face.
		float saw = sin((p.x * 0.8 + p.y * 0.6) * v_rad * 520.0 + gr_noise(vec3(p * 3.0, v_seed)) * 4.0);
		col *= 1.0 - 0.05 * saw * (1.0 - smoothstep(0.0008, 0.002, fw));
		// Checks: one or two drying cracks opening from the rim inward, widest at the rim, wandering a little.
		float checks = 0.0;
		for (int k = 0; k < 2; k++) {
			if (k == 1 && h1(v_seed * 23.0) < 0.5) {
				break;
			}
			float ca = h1(v_seed * 11.0 + float(k) * 3.1) * 6.2832 + (gr_noise(vec3(r * 6.0, v_seed * 30.0 + float(k), 0.0)) - 0.5) * 0.25;
			float start = 0.35 + 0.4 * h1(v_seed * 5.0 + float(k));
			float da = abs(mod(ang - ca + 3.1416, 6.2832) - 3.1416) * r;
			float w = 0.018 * smoothstep(start, 1.0, r);
			checks = max(checks, (1.0 - smoothstep(w * 0.4, w, da)) * step(start, r));
		}
		col = mix(col, bark_deep * 0.8, checks * 0.85);
		// The pith.
		col = mix(col, heartwood * 0.55, 1.0 - smoothstep(0.015, 0.035, r));
		// Weathered grey on older cuts, more toward the rim.
		float age = h1(v_seed * 17.0);
		col = mix(col, weathered, age * 0.55 * (0.5 + 0.5 * smoothstep(0.3, 1.0, r)));
		// The rim: bark on a barked log (COLOR.a near 1), a thin darker cambium line on a peeled one.
		float barked = step(0.9, v_part);
		float rim = smoothstep(0.88, 0.92, r) * barked;
		col = mix(col, mix(bark_red, bark_deep, 0.5), rim);
		col = mix(col, inner_bark, (1.0 - barked) * smoothstep(0.95, 0.99, r) * 0.7);
		h = (1.0 - ring) * 0.0008 - checks * 0.004 - rim * 0.004;
		rough = 0.9;
	} else {
		float ang = UV.x * 6.2832;
		float v = UV.y;
		float rad = max(v_rad, 0.02);
		vec3 c3 = vec3(cos(ang) * rad, sin(ang) * rad, v);
		fw = length(fwidth(vec2(UV.x * 6.2832 * rad, v)));
		float det = 1.0 - smoothstep(0.004, 0.03, fw);
		if (v_part < 0.2) {
			// --- Cedar bark: fibrous strips a few centimetres wide running down the log, split by dark furrows and broken
			// across now and then, a grey weathered skin over the red-brown, strips lifting at their edges. Matte.
			float s_ar = UV.x * 6.2832 * rad;
			vec3 sc = vec3(cos(ang), sin(ang), 0.0);
			float n1 = gr_noise(vec3(sc.xy * rad * 30.0, v * 2.4 + v_seed * 31.0));
			float n2 = gr_noise(vec3(sc.xy * rad * 30.0 * 2.1 + 7.0, v * 5.0 + v_seed * 17.0));
			float ridge = 1.0 - abs(2.0 * (n1 * 0.7 + n2 * 0.3) - 1.0);
			float furrow = 1.0 - smoothstep(0.08, 0.42, ridge);
			float across = smoothstep(0.62, 0.8, gr_noise(vec3(sc.xy * rad * 9.0, v * 7.0 + v_seed * 3.0)));
			float fibre = gr_noise(vec3(sc.xy * rad * 140.0, v * 9.0 + v_seed * 7.0));
			float grey = smoothstep(0.3, 0.7, gr_fbm(vec3(sc.xy * rad * 3.0, v * 0.5 + v_seed * 11.0)));
			col = mix(bark_red, bark_grey, (0.35 + 0.5 * grey) * smoothstep(0.2, 0.7, ridge));
			col *= 0.8 + 0.35 * fibre * det + 0.12 * (1.0 - det);
			col = mix(col, bark_deep, max(furrow, across * 0.6) * mix(0.55, 0.85, det));
			float loose = smoothstep(0.74, 0.82, gr_noise(vec3(sc.xy * rad * 12.0, v * 0.8 + v_seed * 5.0))) * ridge;
			col = mix(col, bark_grey * 1.3, loose * 0.45);
			h = (ridge - 1.0) * 0.014 - across * 0.004 + fibre * 0.0025 * det + loose * 0.004;
			rough = 0.97;
		} else {
			// --- Peeled cedar: pale wood worked smooth with a draw-knife (flats round the log in slightly different
			// tones), the grain running along it, scraps of the inner bark left in streaks, knots where branches were,
			// greyed by the river's weather on the top.
			float flats = gr_noise(vec3(floor(UV.x * 16.0 + 0.5 * gr_noise(vec3(v * 0.6, v_seed * 9.0, 0.0))) * 3.7, v * 0.25, v_seed * 13.0));
			col = mix(peeled_dark, peeled_light, 0.45 + 0.4 * flats);
			float grain = gr_noise(vec3(c3.x * 120.0, c3.y * 120.0, v * 1.5 + v_seed * 3.0));
			col *= 0.9 + 0.16 * grain * det + 0.08 * (1.0 - det);
			float streak = smoothstep(0.66, 0.74, gr_fbm(vec3(c3.x * 10.0, c3.y * 10.0, v * 0.5 + v_seed * 19.0)));
			col = mix(col, inner_bark, streak * 0.85);
			// Knots: dark ovals, stretched along the log, in a whorl now and then.
			vec2 kc = vec2(UV.x * 5.0, v / 0.9 + v_seed * 7.0);
			vec2 kid = floor(kc);
			vec2 kf = fract(kc) - 0.5 - (vec2(h1(kid.x * 3.0 + kid.y * 17.0), h1(kid.x * 7.0 + kid.y * 5.0)) - 0.5) * 0.5;
			float knot_on = step(0.62, h1(kid.x * 13.0 + kid.y * 29.0 + v_seed));
			float kd = length(kf * vec2(1.0, 2.2));
			float knot = (1.0 - smoothstep(0.07, 0.11, kd)) * knot_on;
			float knot_ring = (1.0 - smoothstep(0.11, 0.17, kd)) * knot_on;
			col = mix(col, peeled_dark * 0.75, knot_ring * 0.4);
			col = mix(col, bark_deep * 1.6, knot * 0.85);
			float top = smoothstep(0.0, 0.8, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
			col = mix(col, weathered, top * 0.35 * smoothstep(0.3, 0.7, gr_fbm(vec3(c3.xy * 3.0, v * 0.3 + v_seed))));
			h = grain * 0.0006 * det + flats * 0.001 - knot * 0.002 - streak * 0.0008;
			rough = 0.78;
		}
	}
	col *= 1.0 - v_shade * 0.6;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = v_part < 0.2 ? 0.12 : 0.25;
	NORMAL = gr_bump(NORMAL, VERTEX, h, 1.0);
}
