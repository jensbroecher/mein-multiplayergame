shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Shipping containers (PortKit.container, Harbor Pier): UV is in metres on every face (u across it, v up it, or
// along and across on the roof), UV2.x says which face: 0 a side wall, 1 the door end, 2 the closed end, 3 the roof.
// The vertex colour is the paint (sRGB); its alpha a seed per container (wear, rust, whether it carries a line's
// lettering). The walls' trapezoid corrugation, the doors' panels and the lettering are drawn here; the corner
// posts, rails, locking bars and castings are geometry. Needs tangents (PortKit commits them).

uniform float pitch = 0.278;

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

// Height of a trapezoid corrugation across x (0..1 per pitch) and its slope.
vec2 trapezoid(float x) {
	float f = fract(x);
	// Flat crest 0..0.35, slope 0.35..0.5, flat trough 0.5..0.85, slope back 0.85..1.
	if (f < 0.35) return vec2(1.0, 0.0);
	if (f < 0.5) return vec2(1.0 - (f - 0.35) / 0.15, -1.0 / 0.15);
	if (f < 0.85) return vec2(0.0, 0.0);
	return vec2((f - 0.85) / 0.15, 1.0 / 0.15);
}

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	float seed = COLOR.a;
	float face = UV2.x;
	vec2 uv = UV;
	float fw = max(fwidth(uv.x), fwidth(uv.y));
	float detail = 1.0 - smoothstep(0.03, 0.12, fw);
	vec3 col = paint;
	float slope = 0.0;
	float depth = 0.045;

	if (face < 0.5 || (face > 1.5 && face < 2.5)) {
		vec2 tz = trapezoid(uv.x / pitch);
		slope = tz.y * depth / pitch;
		col *= 0.93 + 0.1 * tz.x;
	} else if (face > 0.5 && face < 1.5) {
		// The doors: two leaves, each with three pressed panels; a seam down the middle.
		float w = 2.44;
		float x = uv.x;
		float leaf_x = fract(x / (w * 0.5));
		float panel = fract(uv.y / 0.86);
		float press = smoothstep(0.08, 0.14, leaf_x) * (1.0 - smoothstep(0.86, 0.92, leaf_x)) * smoothstep(0.08, 0.14, panel) * (1.0 - smoothstep(0.86, 0.92, panel));
		col *= 0.9 + 0.12 * press;
		float seam = 1.0 - smoothstep(0.0, 0.02, abs(x - w * 0.5));
		col *= 1.0 - 0.6 * seam * detail;
		// The safety-approval plate and the container's number, in black, high on the right leaf.
		vec2 plate = vec2(x - w * 0.72, uv.y - 2.05);
		float plate_m = step(abs(plate.x), 0.32) * step(abs(plate.y), 0.12);
		float digits = step(0.5, vnoise(vec2(floor(plate.x * 22.0), seed * 50.0)) + 0.15) * step(abs(plate.y), 0.05);
		col = mix(col, vec3(0.03), plate_m * digits * detail);
	} else {
		// Roof: shallow dents across the length, dust and puddle stains.
		col *= 0.85 + 0.15 * vnoise(uv * 1.3 + seed * 20.0);
		col = mix(col, col * vec3(0.7, 0.62, 0.55), smoothstep(0.55, 0.85, vnoise(uv * 0.6 + seed * 9.0)) * 0.6);
	}

	// A line's lettering along the side walls of about half the boxes: a pale band of letter-blocks.
	if (face < 0.5 && hash12(vec2(seed * 91.0, 3.0)) > 0.45) {
		float lx = uv.x - 1.0;
		float ly = uv.y - 1.55;
		float word_len = 3.2 + 2.2 * hash12(vec2(seed * 17.0, 1.0));
		float in_word = step(0.0, lx) * step(lx, word_len) * step(abs(ly), 0.26);
		float letter = floor(lx / 0.42);
		float gap = step(0.08, fract(lx / 0.42));
		float shape = step(0.25, vnoise(vec2(letter * 3.7 + seed * 11.0, floor((ly + 0.26) / 0.13))));
		vec3 ink = hash12(vec2(seed * 7.0, 5.0)) > 0.5 ? vec3(0.92, 0.92, 0.88) : vec3(0.05, 0.05, 0.06);
		col = mix(col, ink, in_word * gap * shape * detail * 0.92);
	}

	// Weather: rust streaks from the top rail and round dents, grime toward the bottom, faded paint.
	float n = vnoise(vec2(uv.x * 3.0, uv.y * 0.35) + seed * 37.0);
	float streak = smoothstep(0.62, 0.9, vnoise(vec2(uv.x * 7.0 + seed * 13.0, 0.5))) * smoothstep(0.4, 2.6, uv.y) * (0.35 + 0.65 * n);
	float rustiness = 0.25 + 0.75 * hash12(vec2(seed * 29.0, 7.0));
	vec3 rust = vec3(0.30, 0.12, 0.05);
	col = mix(col, rust, streak * rustiness * 0.55);
	float patch = smoothstep(0.7, 0.92, vnoise(uv * 2.1 + seed * 53.0)) * rustiness;
	col = mix(col, rust * 0.8, patch * 0.6);
	float grime = 1.0 - smoothstep(0.0, 0.9, uv.y);
	if (face < 2.5) {
		col = mix(col, col * vec3(0.55, 0.5, 0.45), grime * 0.4);
	}
	col = mix(col, col * 1.15 + vec3(0.03), 0.3 * vnoise(uv * 0.5 + seed * 3.0));

	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.85, patch + streak * 0.5);
	METALLIC = mix(0.25, 0.05, patch);
	SPECULAR = 0.45;
	if (slope != 0.0 && detail > 0.0) {
		vec3 nm = normalize(vec3(-slope * detail, 0.0, 1.0));
		NORMAL_MAP = nm * 0.5 + 0.5;
	}
}
