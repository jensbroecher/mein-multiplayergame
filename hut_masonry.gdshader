shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Stone, plaster and brick for the Msitu Falls ranger post (RangerPostBuilder.gd). UV is in world
// metres; the vertex colour is the tint (the plaster's colour, the brick's red).
//   0  rubble stone: irregular blocks with mortar between, mossy at the foot
//   1  lime-washed plaster: mottled, hairline cracks, splashed with mud toward the ground (v = 0)
//   2  brick in running bond, sooted toward the top of a chimney

uniform int style = 0;

// Colours below are written as sRGB and linearised here.
vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash12(p), hash12(p + 17.31));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Voronoi: x the distance to the nearest cell border, y the cell's id (0..1).
vec2 voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash22(n + g) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + hash22(n + g) - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec2(md, hash12(n + mg));
}

void fragment() {
	vec2 q = UV;
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	vec3 col = tint;
	float rough = 0.9;

	if (style == 0) {
		// Flat-ish stones, wider than they are tall, about a third of a metre.
		vec2 vc = voronoi(vec2(q.x / 0.62, q.y / 0.40));
		float mortar = 1.0 - smoothstep(0.02, 0.09, vc.x);
		float tone = 0.62 + 0.55 * vc.y + 0.2 * (vnoise(q * 9.0) - 0.5);
		vec3 stone = mix(srgb(vec3(0.52, 0.47, 0.40)), srgb(vec3(0.40, 0.38, 0.36)), fract(vc.y * 7.0));
		col = stone * tone * mix(vec3(1.0), tint, 0.5);
		// Round the stones' faces: darker toward their edges.
		col *= 0.78 + 0.22 * smoothstep(0.02, 0.2, vc.x);
		col = mix(col, srgb(vec3(0.30, 0.28, 0.25)), mortar * 0.85);
		// Moss and mud near the foot.
		float foot = 1.0 - smoothstep(0.1, 0.9, q.y);
		float moss = smoothstep(0.45, 0.7, vnoise(q * 3.0 + 4.0)) * foot;
		col = mix(col, srgb(vec3(0.28, 0.40, 0.20)), moss * 0.6);
		rough = 0.95;
	} else if (style == 1) {
		float mottle = vnoise(q * 2.2 + 3.0) * 0.55 + vnoise(q * 7.5) * 0.3 + vnoise(q * 21.0) * 0.15;
		col = tint * (0.7 + 0.35 * mottle);
		// Hairline cracks.
		vec2 vc = voronoi(q * 1.6 + 5.0);
		float crack = 1.0 - smoothstep(0.0, 0.018, vc.x);
		col *= 1.0 - crack * 0.12;
		// Mud splashed up from the ground, and a few patches where the wash has gone.
		float splash = (1.0 - smoothstep(0.0, 0.55 + 0.4 * vnoise(vec2(q.x * 2.0, 1.0)), q.y));
		col = mix(col, srgb(vec3(0.45, 0.33, 0.22)), splash * 0.7);
		float bare = smoothstep(0.72, 0.84, vnoise(q * 1.3 + 21.0));
		col = mix(col, srgb(vec3(0.50, 0.34, 0.24)), bare * 0.45);
		// Rain streaks down from the roof.
		col *= 1.0 - 0.18 * smoothstep(0.55, 0.85, vnoise(vec2(q.x * 3.0, q.y * 0.2)));
		rough = 0.95;
	} else {
		// Running bond: courses of 7cm, bricks of 22cm, in world metres at 1.6x.
		float bh = 0.12;
		float bwid = 0.37;
		float row = floor(q.y / bh);
		float bx = q.x / bwid + 0.5 * mod(row, 2.0);
		float fx = fract(bx);
		float fy = fract(q.y / bh);
		float id = hash12(vec2(floor(bx), row));
		float mortar = 1.0 - smoothstep(0.0, 0.07, min(min(fx, 1.0 - fx) * bwid, min(fy, 1.0 - fy) * bh));
		vec3 brick = tint * (0.7 + 0.5 * id) * (0.9 + 0.2 * vnoise(q * 25.0));
		col = mix(brick, srgb(vec3(0.62, 0.59, 0.53)), mortar * 0.8);
		// Soot toward the top, where the smoke comes out.
		col *= 1.0 - 0.45 * smoothstep(0.55, 1.0, vnoise(vec2(q.x * 2.0, 3.0)) * 0.4 + 0.6 * smoothstep(0.0, 6.0, q.y) );
		rough = 0.9;
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
}
