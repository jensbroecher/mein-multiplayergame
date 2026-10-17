shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Weathered timber for the Msitu Falls ranger post (RangerPostBuilder.gd). UV is in world metres
// and the vertex colour is the tint: the colour of the wood, or the paint for `style` 3.
//   0  upright boards with battens over the joints (walls)
//   1  weatherboards laid along u (floors, ceilings, shutters, louvred vents)
//   2  squared timber with the grain along v (posts, beams, rails, logs)
//   3  painted boards: trim, doors and shutters, the paint worn through at the edges
// The mesh carries tangents only because the other hut shaders need them; this one doesn't.

uniform int style = 0;
uniform float weathering : hint_range(0.0, 1.0) = 0.6;

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

void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	vec2 q = UV;
	float across = (style == 1) ? q.y : q.x;
	float along = (style == 1) ? q.x : q.y;
	// Board width in world metres.
	float pw = (style == 1) ? 0.26 : ((style == 3) ? 0.22 : 0.5);
	if (style == 2) {
		pw = 1000.0;
	}
	float id = floor(across / pw);
	float f = fract(across / pw);
	float r1 = hash12(vec2(id, 1.7));
	float r2 = hash12(vec2(id, 9.1));
	float d_joint = min(f, 1.0 - f) * pw;

	// Grain: fine streaks along the board, a broader variation, and now and then a knot.
	float grain = vnoise(vec2(across * 34.0 + r1 * 50.0, along * 1.5)) * 0.55
			+ vnoise(vec2(across * 9.0 + r2 * 30.0, along * 0.45)) * 0.45;
	float knot = smoothstep(0.86, 0.95, vnoise(vec2(across * 3.0 + r1 * 20.0, along * 0.9 + r2 * 40.0)));
	float tone = 0.74 + 0.4 * r1 + (grain - 0.5) * 0.5 - knot * 0.25;
	vec3 col = tint * tone;
	float rough = 0.88;

	if (style == 0) {
		// Battens over the joints, with a shadow line either side that makes the boards sit back.
		float bw = 0.075;
		float batten = 1.0 - smoothstep(bw * 0.5, bw * 0.5 + 0.012, d_joint);
		float shadow = smoothstep(bw * 0.5, bw * 0.5 + 0.012, d_joint) * (1.0 - smoothstep(bw * 0.5 + 0.012, bw * 0.5 + 0.07, d_joint));
		col *= 1.0 + 0.10 * batten;
		col *= 1.0 - 0.45 * shadow;
		// Faint joints between the boards under the battens' reach, so a wall isn't a flat sheet.
		float inner = abs(f - 0.5) * pw;
		col *= 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.012, inner)) * (1.0 - batten);
	} else if (style == 1) {
		// Each board's lower edge is in shadow under the one above.
		col *= mix(0.5, 1.0, smoothstep(0.0, 0.2, f)) * mix(1.0, 1.08, smoothstep(0.85, 1.0, f));
	} else if (style == 3) {
		// Paint: even, with the boards just showing, then chipped and worn at the board edges.
		float n = vnoise(q * vec2(17.0, 2.4) + 7.0) * 0.6 + vnoise(q * 3.1 + 2.0) * 0.4;
		float edge = 1.0 - smoothstep(0.0, 0.05, d_joint);
		float wear = smoothstep(0.7, 0.9, n + edge * 0.2) * weathering * 0.7;
		vec3 bare = pow(vec3(0.46, 0.42, 0.37), vec3(2.2)) * (0.8 + grain * 0.4);
		col = mix(tint * (0.9 + 0.12 * r1), bare, wear * 0.7);
		col *= 1.0 - 0.28 * (1.0 - smoothstep(0.0, 0.01, d_joint));
		rough = mix(0.6, 0.9, wear);
	}

	// Weather: grey silvering, and dark streaks where rain has run down from the eaves.
	float silver = vnoise(q * vec2(0.9, 0.45) + 11.0);
	float streak = smoothstep(0.55, 0.85, vnoise(vec2(q.x * 2.3, q.y * 0.14 + 3.0)));
	float w = (style == 3) ? weathering * 0.4 : weathering;
	col = mix(col, col * vec3(0.62, 0.62, 0.64) + vec3(0.02), silver * w * 0.6);
	col *= 1.0 - streak * w * 0.35;

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
}
