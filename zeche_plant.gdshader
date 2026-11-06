// The Zeche Kronprinz brownfield plants (ZechenKit.gd: buddleia_mesh, goldenrod_mesh; key "zplant"), drawn as MultiMeshes.
// Two-sided; the vertex colour (sRGB) is the colour, its alpha picks what a face is (constant over a face):
//   1.0   solid: stems and single leaves; their undersides paler and silvery (buddleia's felted leaves).
//   0.75  a leaf card: UV.y from the card's foot (0) to its top (1), fract(UV.x) across it, floor(UV.x) the card's id. The
//         shader draws a fan of five lanceolate leaves from the foot's middle (a midrib, a paler edge) and discards the rest.
//   0.5   a plume card (goldenrod's panicle): a tapering plume of small florets on arching sprays, airy (discarded between
//         them) near, filling in to its outline far off.
//   0.0   a flower spike (buddleia's panicle): UV.x round it, UV.y along it; a crowd of florets, each a pale ring with a
//         dark heart and an orange eye.
// Patterns fade to their mean once their detail is under a pixel; cut-outs widen a little so a far card keeps its body.
// The plant sways from its foot up (the model's y, life metres) with gusts phased by where the instance stands.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Sway at the top of a 2m plant, in model metres.
uniform float sway = 0.05;
uniform vec2 wind_dir = vec2(0.8, 0.6);
// Florets round a spike and along it.
uniform vec2 florets = vec2(7.0, 15.0);
uniform vec3 eye_color : source_color = vec3(0.98, 0.62, 0.12);

varying float mode;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float ph = dot(o.xz, vec2(0.11, 0.17));
	float g = sin(TIME * 1.1 + ph) * 0.55 + sin(TIME * 2.3 + ph * 1.9) * 0.3 + sin(TIME * 4.7 + ph * 3.1 + VERTEX.x * 3.0) * 0.15;
	VERTEX.xz += normalize(wind_dir) * g * sway * h * h * 0.25;
	mode = COLOR.a;
}

// A fan of five leaves in a card: returns coverage (0/1 with a soft edge) and, in `rib`, how near the midrib (1) a pixel is.
float leaf_fan(vec2 uv, float id, float aa, out float rib, out float tone) {
	vec2 o = vec2(0.5, 0.02);
	float cov = 0.0;
	rib = 0.0;
	tone = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float hv = hash12(vec2(id * 7.31 + fi, fi * 3.7 + 1.3));
		float ang = (fi - 2.0) * 0.45 + (hv - 0.5) * 0.3;
		vec2 dir = vec2(sin(ang), cos(ang));
		vec2 p = uv - o;
		float s = dot(p, dir);
		float t = dot(p, vec2(dir.y, -dir.x));
		float L = 0.92 - abs(fi - 2.0) * 0.14 + hv * 0.06;
		float x = s / L;
		float w = 0.085 * pow(max(sin(3.14159 * clamp(x, 0.0, 1.0)), 0.0), 0.85) * (1.2 - 0.5 * x);
		float inside = step(0.0, x) * step(x, 1.0) * (1.0 - smoothstep(w - aa * 0.3, w + aa * 0.8, abs(t)));
		if (inside > cov) {
			cov = inside;
			rib = 1.0 - clamp(abs(t) / max(w, 1e-3), 0.0, 1.0);
			tone = hv;
		}
	}
	return cov;
}

// Goldenrod's plume: a central axis with eight sprays leaving it up its length, each rising a little and arching out and
// down, shorter toward the top, a band of florets along its upper side (dots near, a solid band far off).
float plume(vec2 uv, float id, float aa, out float tone) {
	float u = uv.x - 0.5;
	float v = uv.y;
	float au = abs(u);
	float cov = (1.0 - smoothstep(0.008, 0.018 + aa, au)) * step(v, 0.97);
	tone = 0.5;
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float hv = hash12(vec2(id * 3.1 + fi, fi * 1.7 + 7.7));
		float vi = 0.06 + fi * 0.112 + hv * 0.03;
		float reach = 0.47 * (1.0 - vi * 0.8) * (0.8 + 0.3 * hv);
		float x = au / max(reach, 0.02);
		float y = vi + reach * (0.5 * x - 0.85 * x * x);
		float dy = v - y;
		float th = 0.03 + 0.03 * (1.0 - x) + aa;
		float on = step(au, reach) * smoothstep(-0.006 - aa, 0.0, dy) * (1.0 - smoothstep(th - aa, th + aa, dy));
		float cellf = fract(au * 46.0 + hv * 3.0) - 0.5;
		float dots = 1.0 - smoothstep(0.3, 0.45, abs(cellf));
		dots = mix(dots, 1.0, smoothstep(0.008, 0.025, aa));
		float c = on * dots;
		if (c > cov) {
			cov = c;
			tone = hv;
		}
	}
	return cov;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec2 fwu = fwidth(UV);
	float aa = max(fwu.x, fwu.y);
	vec3 col = base;
	float rough = 0.85;
	float back = 0.4;
	if (mode > 0.9) {
		if (!FRONT_FACING) {
			col = mix(col, col * vec3(1.35, 1.38, 1.25) + vec3(0.02), 0.5);
		}
	} else if (mode > 0.6) {
		float id = floor(UV.x);
		float rib;
		float tone;
		float c = leaf_fan(vec2(fract(UV.x), UV.y), id, aa, rib, tone);
		if (c < 0.5) {
			discard;
		}
		col = base * (0.85 + 0.3 * tone);
		col = mix(col, col * 1.25 + vec3(0.01), smoothstep(0.82, 0.97, rib) * (1.0 - smoothstep(0.02, 0.08, aa)));
		col *= 0.88 + 0.12 * (1.0 - rib);
		if (!FRONT_FACING) {
			col = mix(col, col * vec3(1.35, 1.38, 1.25) + vec3(0.02), 0.5);
		}
	} else if (mode > 0.35) {
		float id = floor(UV.x);
		float tone;
		float c = plume(vec2(fract(UV.x), UV.y), id, aa, tone);
		if (c < 0.5) {
			discard;
		}
		col = base * (0.82 + 0.35 * tone);
		rough = 0.9;
		back = 0.3;
	} else {
		vec2 q = UV * florets;
		vec2 f = fract(q) - 0.5;
		vec2 fid = floor(q);
		float hv = hash12(fid + vec2(3.1, 7.7));
		vec2 jf = f - (vec2(hash12(fid + 1.3), hash12(fid + 9.1)) - 0.5) * 0.25;
		float d = length(jf);
		vec2 fwq = fwidth(q);
		float qa = max(fwq.x, fwq.y);
		float fade = smoothstep(0.35, 0.9, qa);
		float petal = 1.0 - smoothstep(0.30 - qa * 0.5, 0.42 + qa * 0.5, d);
		float eye = 1.0 - smoothstep(0.05, 0.13 + qa * 0.5, d);
		vec3 fl = base * mix(0.5, 1.12 + 0.2 * hv, petal);
		fl = mix(fl, pow(eye_color, vec3(2.2)), eye * 0.8);
		col = mix(fl, base * 0.9, fade);
		rough = 0.9;
		back = 0.25;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	BACKLIGHT = col * back;
}
