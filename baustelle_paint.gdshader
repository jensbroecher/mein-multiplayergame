// Weathered machine and plant paint for the building site (BaustelleKit.gd, key "bpaint"): the tower crane, the
// excavator, the road roller, the dumper, the mixer truck, the Leitbaken. Several of these turn or drive (the crane's
// top slews, the excavator's upper slews, the roller runs back and forth, the Leitbaken are knocked about), so every
// pattern is laid in the mesh's own frame (VERTEX before the model matrix), never from the world position, and rides
// along with the part. The vertex colour is the paint (sRGB); its alpha picks what is drawn:
//   a >= 0.75         weathered paint: dirt in low-frequency patches, small chips through to dark primer, dust
//                     settled on faces looking up, a little gloss left where it is clean.
//   0.375 <= a < 0.75 yellow-and-black hazard stripes, diagonal in the mesh's frame (period `hazard_period` mesh
//                     units), the vertex colour tinting the yellow.
//   a < 0.375         red-and-white warning stripes from UV (life metres, u + v: diagonal on a board's face), the
//                     vertex colour the red; retroreflective film, a little glossier (Leitbaken, barrier boards).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float hazard_period = 0.55;
// A pair of red-and-white stripes, in life metres along u + v.
uniform float warn_period = 0.32;
uniform vec3 dust_color : source_color = vec3(0.58, 0.54, 0.47);
uniform float dirt = 0.28;
uniform float chips = 0.2;

varying vec3 opos;
varying vec3 onrm;

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

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	float mode = COLOR.a;
	vec3 n = normalize(onrm);
	// The plane the pattern lies on: the vertical plane the face looks across, or the ground plane on flat faces.
	float h = mix(opos.x, opos.z, smoothstep(-0.2, 0.2, abs(n.x) - abs(n.z)));
	vec2 q = vec2(h, opos.y);
	float flat_face = step(0.72, abs(n.y));
	q = mix(q, opos.xz, flat_face);
	float fw = length(fwidth(opos));
	float fine = 1.0 - smoothstep(0.02, 0.25, fw);
	vec3 col;
	float rough;
	float metal = 0.1;
	if (mode < 0.375) {
		float d = (UV.x + UV.y) / warn_period;
		float dw = fwidth(d);
		float s = smoothstep(0.5 - dw, 0.5 + dw, abs(fract(d) - 0.5) * 2.0);
		s = mix(s, 0.5, smoothstep(0.3, 0.8, dw));
		col = mix(vec3(0.86, 0.86, 0.84), paint, s);
		col *= 0.9 + 0.1 * vnoise(q * 3.0);
		rough = 0.32;
		metal = 0.0;
	} else if (mode < 0.75) {
		float d = (opos.x + opos.y + opos.z) / hazard_period;
		float dw = fwidth(d);
		float s = smoothstep(0.5 - dw, 0.5 + dw, abs(fract(d) - 0.5) * 2.0);
		s = mix(s, 0.5, smoothstep(0.3, 0.8, dw));
		col = mix(vec3(0.025, 0.025, 0.028), paint, s);
		float wear = vnoise(q * 3.0);
		col = mix(col, vec3(0.16, 0.14, 0.12), smoothstep(0.75, 0.92, wear) * 0.6);
		rough = 0.5 + 0.3 * wear;
	} else {
		// Dirt in broad patches, darker and greyer; streaks down the vertical faces.
		float pz = vnoise(q * 0.45 + 3.1) * 0.6 + vnoise(q * 1.7 + 7.3) * 0.4;
		float streak = mix(vnoise(vec2(q.x * 3.5, q.y * 0.25) + 1.7), 0.5, flat_face);
		float dirty = smoothstep(0.45, 0.85, pz) * dirt + smoothstep(0.62, 0.9, streak) * dirt * 0.6 * (1.0 - flat_face);
		vec3 grey = vec3(dot(paint, vec3(0.3, 0.55, 0.15)));
		col = mix(paint, mix(paint, grey, 0.5) * 0.62, clamp(dirty, 0.0, 0.8));
		// Chips through to dark primer, only where they are bigger than a pixel.
		float c = vnoise(q * 11.0 + 5.3) * 0.7 + vnoise(q * 31.0) * 0.3;
		float chip = smoothstep(0.83, 0.88, c) * chips * fine;
		col = mix(col, vec3(0.06, 0.055, 0.05), chip);
		// Dust settled on faces looking up.
		float up_face = smoothstep(0.5, 0.9, n.y);
		float dn = vnoise(q * 2.3 + 11.0);
		col = mix(col, pow(dust_color, vec3(2.2)), up_face * (0.15 + 0.25 * dn));
		col *= 0.94 + 0.08 * vnoise(q * 6.0) * fine + 0.03;
		rough = mix(0.42, 0.78, clamp(dirty + up_face * 0.4 + chip, 0.0, 1.0));
		metal = mix(0.12, 0.25, chip);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
}
