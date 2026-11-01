shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Ridgecrest's window-box geraniums (RidgecrestKit.flower_box). Every leaf, floret and bud is one quad whose
// shape is drawn here from its UV (0..1 across); UV2.x says what it is, UV2.y how far it sways (0 at the box,
// 1 at the tip of a stem hanging down the wall), COLOR is its colour (sRGB):
//   0 a zonal leaf: round with a scalloped rim and a notch where its stalk joins (toward UV.y 0), a dark
//     horseshoe band, pale palmate veins; paler and plain underneath.
//   1 an ivy leaf: five pointed lobes, glossy.
//   2 a floret: five rounded petals (the upper two smaller, with the darker veins), a pale eye.
//   3 a bud: a teardrop, green sepals over the petals' colour at its tip (toward UV.y 0).
//   4 a stalk, or the far stand-in's flat colour: the whole quad.
// A shape too small on screen to draw (under about six pixels) is a plain disc, and the veins and bands fade
// out before that, so a box seen from across the street doesn't sparkle. lod_mode 1 (the plants) dithers out
// and 2 (the far stand-in) in between lod_fade_begin and lod_fade_end, by each fragment's own distance.

#include "res://tree_lod.gdshaderinc"

uniform float sway = 0.02;
uniform float speed = 1.3;

const float TAU_ = 6.2831853;
const float HALF_PI = 1.5707963;

void vertex() {
	if (UV2.y > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float g = sin(TIME * speed + wp.x * 0.9 + wp.z * 0.7) + 0.4 * sin(TIME * speed * 2.7 + wp.x * 2.3 - wp.z * 1.9);
		VERTEX.xz += vec2(g, g * 0.6) * sway * UV2.y;
	}
}

// An angle wrapped into -PI..PI.
float wrap_pi(float a) {
	return mod(a + 3.14159265, TAU_) - 3.14159265;
}

// How far (in the quad's -1..1 units) a point at radius r and angle a lies from the nearest of `count` lines
// radiating from the middle, the first along `a0`.
float ray_distance(float a, float r, float a0, float count) {
	float x = wrap_pi(a - a0) / (TAU_ / count);
	return abs(fract(x + 0.5) - 0.5) * (TAU_ / count) * r;
}

void fragment() {
	if (lod_hidden(length(VERTEX), FRAGCOORD.xy, PROJECTION_MATRIX)) {
		discard;
	}
	vec2 p = UV * 2.0 - 1.0;
	float kind = UV2.x;
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	// One pixel in the quad's own units (it is 2 across).
	float px = length(fwidth(p));
	float r = length(p);
	float a = atan(p.y, p.x);
	float detail = 1.0 - smoothstep(0.12, 0.3, px);
	float rough = 0.75;
	float spec = 0.3;
	float back = 0.3;
	if (kind < 3.5 && px > 0.45) {
		// Too small to draw: a disc as big as the shape on average.
		if (r > 0.72) {
			discard;
		}
	} else if (kind < 0.5) {
		// The zonal leaf. Its stalk joins at the middle; the notch opens toward -y.
		float da = abs(wrap_pi(a + HALF_PI));
		float rim = 0.93 + 0.05 * cos(a * 11.0);
		if (r > rim + px * 0.5 || (da < 0.17 && r > 0.13)) {
			discard;
		}
		float zone = smoothstep(0.36, 0.44, r) * (1.0 - smoothstep(0.6, 0.7, r)) * smoothstep(0.5, 1.1, da);
		float vein = (1.0 - smoothstep(0.012, 0.012 + px, ray_distance(a, r, -HALF_PI, 9.0)))
				* smoothstep(0.06, 0.18, r) * (1.0 - smoothstep(0.75, 0.9, r));
		if (FRONT_FACING) {
			col = mix(col, col * vec3(0.42, 0.32, 0.21), zone * 0.8 * detail);
			col = mix(col, col * 1.35 + vec3(0.01, 0.02, 0.0), vein * 0.55 * detail);
		} else {
			// Felted and pale underneath, the veins standing out.
			col = col * 1.25 + vec3(0.03, 0.04, 0.02);
			col = mix(col, col * 1.2, vein * 0.6 * detail);
		}
		col *= mix(1.0, 1.12, smoothstep(rim - 0.15, rim, r));
		rough = 0.8;
		spec = 0.25;
	} else if (kind < 1.5) {
		// The ivy leaf: five pointed lobes, the top one along +y, a notch toward -y.
		float lobe = pow(max(cos(2.5 * (a - HALF_PI)), 0.0), 1.6);
		float rim = 0.6 + 0.38 * lobe;
		if (r > rim + px * 0.5 || (abs(wrap_pi(a + HALF_PI)) < 0.12 && r > 0.18)) {
			discard;
		}
		float vein = (1.0 - smoothstep(0.015, 0.015 + px, ray_distance(a, r, HALF_PI, 5.0)))
				* smoothstep(0.05, 0.15, r) * (1.0 - smoothstep(0.7, 0.9, r));
		col = mix(col, col * 1.4, vein * 0.5 * detail);
		col *= mix(0.85, 1.05, smoothstep(0.0, 0.7, r));
		rough = 0.35;
		spec = 0.5;
		back = 0.2;
	} else if (kind < 2.5) {
		// The floret: petals centred at 54, 126 (the upper pair), 198, 270 and 342 degrees.
		float sector = TAU_ / 5.0;
		float t = mod(a - 2.1991149 + sector * 0.5, TAU_);
		float k = floor(t / sector);
		float s = (t - (k + 0.5) * sector) / (sector * 0.5);
		bool upper = k < 0.5 || k > 3.5;
		float rim = (upper ? 0.82 : 1.0) * (0.98 - 0.4 * s * s);
		if (r > rim + px * 0.5) {
			discard;
		}
		float vein = (1.0 - smoothstep(0.01, 0.01 + px, abs(s) * r * sector * 0.5))
				* smoothstep(0.15, 0.3, r) * (1.0 - smoothstep(0.5, 0.75, r));
		col *= mix(0.72, 1.0, smoothstep(0.12, 0.55, r));
		col = mix(col, col * 0.55, vein * detail * (upper ? 0.8 : 0.35));
		col = mix(col, vec3(0.92, 0.86, 0.70), (1.0 - smoothstep(0.13, 0.2, r)) * 0.85);
		rough = 0.55;
		back = 0.5;
	} else if (kind < 3.5) {
		// The bud, hanging: its tip (the petals showing) toward -y.
		vec2 q = vec2(p.x / 0.5, (p.y - 0.1) / 0.9);
		if (dot(q, q) > 1.0 + px) {
			discard;
		}
		col = mix(vec3(0.20, 0.36, 0.12), col, 1.0 - smoothstep(-0.65, -0.2, p.y));
		rough = 0.7;
	} else {
		rough = 0.8;
		back = 0.2;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	BACKLIGHT = col * back;
}
