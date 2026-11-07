// Wire grids and the privacy banner of the building site (BaustelleKit.gd). One quad, two-sided; UV in life metres (u along,
// v up or across). What lies between the wires is discarded. Once the wires are thinner than a pixel their coverage is kept
// as a dither on the screen (an opaque pipeline, nothing to sort), so a far fence reads as a faint veil instead of
// shimmering (as zeche_fence.gdshader does). The vertex colour tints the wire or the fabric (sRGB).
//   mode 0 ("bmesh"): a Bauzaun panel's welded mesh, galvanised, `cell` apart (along u, up v), wires `wire` thick.
//   mode 1 ("bnet"): the green privacy mesh on a fence panel: a dense weave of flat tapes with small holes between them,
//     a darker selvedge along its edges, eyelets every half metre.
//   mode 2 ("brebar"): a reinforcing mat (Baustahlmatte): ribbed bars, rusty, a square grid of `cell`.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform int mode = 0;
uniform vec2 cell = vec2(0.1, 0.25);
uniform float wire = 0.0045;
// The quad's size in life metres (the banner's selvedge needs its edges); 0: none.
uniform vec2 extent = vec2(0.0, 0.0);

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

// Coverage of a grid of wires `w` thick on cells `c`, faded to its mean once a wire is under a pixel.
float grid(vec2 uv, vec2 c, float w) {
	vec2 f = fract(uv / c);
	vec2 d = min(f, 1.0 - f) * c;
	vec2 fw = fwidth(uv);
	float aa = max(fw.x, fw.y);
	float hx = 1.0 - smoothstep(w * 0.5 - aa * 0.5, w * 0.5 + aa * 0.5, d.x);
	float hy = 1.0 - smoothstep(w * 0.5 - aa * 0.5, w * 0.5 + aa * 0.5, d.y);
	float cov = max(hx, hy);
	float mean = clamp(w / c.x + w / c.y - w * w / (c.x * c.y), 0.0, 1.0) * 1.4;
	return mix(cov, mean, smoothstep(w * 0.6, w * 2.5, aa));
}

void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float cov;
	vec3 col;
	float rough;
	float metal;
	if (mode == 1) {
		// Flat tapes about 3mm wide with pin holes between them: about 85% covered.
		vec2 f = fract(UV / 0.004);
		float hole = step(0.7, f.x) * step(0.7, f.y);
		float aa = length(fwidth(UV)) / 0.004;
		cov = mix(1.0 - hole, 0.86, smoothstep(0.2, 0.8, aa));
		col = tint * (0.85 + 0.15 * vnoise(UV * vec2(0.7, 3.0)));
		// Creases where it pulls between its ties.
		col *= 0.9 + 0.12 * sin(UV.y * 7.0 + vnoise(UV * 1.3) * 3.0);
		if (extent.x > 0.0) {
			vec2 e = min(UV, extent - UV);
			float sel = 1.0 - step(0.035, min(e.x, e.y));
			col = mix(col, tint * 0.45, sel);
			cov = mix(cov, 1.0, sel);
			// Eyelets along the top and bottom selvedge.
			vec2 ey = vec2(fract(UV.x / 0.5) - 0.5, min(e.y, 0.02) - 0.018);
			float eye = 1.0 - smoothstep(0.012, 0.016, length(vec2(ey.x * 0.5, ey.y)));
			col = mix(col, vec3(0.55, 0.55, 0.55), eye * step(e.y, 0.035));
		}
		rough = 0.85;
		metal = 0.0;
	} else if (mode == 2) {
		cov = grid(UV, cell, wire);
		float rn = vnoise(UV * vec2(2.2, 1.6)) * 0.6 + vnoise(UV * 13.0) * 0.4;
		col = mix(tint, vec3(0.30, 0.13, 0.06), smoothstep(0.25, 0.75, rn) * 0.7);
		// Ribs: a fine ripple along the bars.
		col *= 0.88 + 0.12 * sin((UV.x + UV.y) * 380.0);
		rough = 0.9;
		metal = 0.15;
	} else {
		cov = grid(UV, cell, wire);
		float g = vnoise(UV * vec2(1.1, 0.8)) * 0.6 + vnoise(UV * 9.0) * 0.4;
		col = tint * (0.8 + 0.3 * g);
		// White rust and dirt toward the foot.
		col = mix(col, tint * 0.55, (1.0 - smoothstep(0.0, 0.6, UV.y)) * 0.5);
		rough = mix(0.35, 0.7, g);
		metal = 0.65;
	}
	if (cov < dither * 0.98 + 0.01) {
		discard;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
}
