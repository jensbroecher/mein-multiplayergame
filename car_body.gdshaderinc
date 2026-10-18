// car_body.gdshaderinc: the body of car_body.gdshader (opaque, what every procedural car draws
// with) and car_body_fade.gdshader (its transparent twin, swapped in by PlayerCart only while a car
// fades out: the Mobile renderer ignores GeometryInstance3D.transparency, and a shader that writes
// ALPHA is always drawn as transparent, so the fade can't be one shader). See car_body.gdshader.

#define M_BODY 0
#define M_PAINT 1
#define M_RUBBER 2
#define M_RIM 3
#define M_CHROME 4
#define M_ALLOY 5
#define M_DARK 6
#define M_ANODISED 7
#define M_HEADLAMP 8
#define M_TAILLAMP 9

// Patterns and finishes: keep in step with CarPaint.PATTERNS / FINISHES.
#define PAT_SOLID 0
#define PAT_STRIPES 1
#define PAT_TWO_TONE 2
#define PAT_SIDE_STRIPE 3
#define PAT_FLAMES 4
#define PAT_CHECKER 5
#define PAT_CAMO 6
#define PAT_RACER 7
#define PAT_FADE 8
#define PAT_SPLINTER 9
#define PAT_TIGER 10
#define PAT_RALLY 11
#define PAT_STREAKS 12
#define PAT_CLAW 13

#define FIN_GLOSS 0
#define FIN_METALLIC 1
#define FIN_MATTE 2
#define FIN_PEARL 3
#define FIN_CHROME 4

uniform sampler2D detail_map : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;

// The model's layout in the cart frame (the builder's PAINT_LAYOUT, set by regenerate_cars.gd).
uniform float nose_z = -0.82;
uniform float tail_z = 0.95;
uniform float belt_y = 0.665;
uniform float side_x = 0.38;
uniform vec2 door_roundel = vec2(0.0, 0.49);   // z, y of the door roundels
uniform float roundel_r = 0.105;
uniform float hood_z = -0.50;                   // z of the bonnet roundel
uniform float hood_r = 0.095;
uniform float stripe_w = 0.07;
uniform float stripe_gap = 0.028;

instance uniform vec4 paint_primary : source_color = vec4(0.25, 0.55, 0.48, 1.0);
instance uniform vec4 paint_secondary : source_color = vec4(0.94, 0.94, 0.91, 1.0);
instance uniform vec4 paint_accent : source_color = vec4(0.82, 0.12, 0.07, 1.0);
instance uniform vec4 paint_rim : source_color = vec4(0.76, 0.77, 0.79, 1.0);
instance uniform int paint_pattern = 0;
instance uniform int paint_finish = 0;
instance uniform int paint_number = 53;
instance uniform vec4 fx_glow = vec4(0.0);      // rgb colour, a energy
instance uniform vec4 fx_tint = vec4(0.0);      // rgb colour, a amount
#ifdef CAR_FADE
instance uniform float fx_alpha = 1.0;
#endif

varying vec3 v_pos;
varying vec3 v_nrm;
varying flat int v_mat;

const int SEGMENTS[10] = int[](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	v_mat = int(UV2.x + 0.5);
}

// Coverage of a signed distance (negative inside), anti-aliased over one pixel.
float cover(float d) {
	float w = max(fwidth(d), 1e-5);
	return clamp(0.5 - d / w, 0.0, 1.0);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return 0.55 * vnoise(p) + 0.30 * vnoise(p * 2.1 + 7.3) + 0.15 * vnoise(p * 4.3 + 1.9);
}

float sd_capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

// A seven-segment digit in a cell of half-size (w, h) round the origin, segments of radius r.
float sd_digit(vec2 p, int d, float w, float h, float r) {
	int bits = SEGMENTS[clamp(d, 0, 9)];
	vec2 tl = vec2(-w, h);
	vec2 tr = vec2(w, h);
	vec2 ml = vec2(-w, 0.0);
	vec2 mr = vec2(w, 0.0);
	vec2 bl = vec2(-w, -h);
	vec2 br = vec2(w, -h);
	float s = 1e3;
	if ((bits & 1) != 0) s = min(s, sd_capsule(p, tl, tr, r));
	if ((bits & 2) != 0) s = min(s, sd_capsule(p, tr, mr, r));
	if ((bits & 4) != 0) s = min(s, sd_capsule(p, mr, br, r));
	if ((bits & 8) != 0) s = min(s, sd_capsule(p, bl, br, r));
	if ((bits & 16) != 0) s = min(s, sd_capsule(p, ml, bl, r));
	if ((bits & 32) != 0) s = min(s, sd_capsule(p, tl, ml, r));
	if ((bits & 64) != 0) s = min(s, sd_capsule(p, ml, mr, r));
	return s;
}

// The racing number (1 or 2 digits) centred in a roundel of radius rr; q in metres, y up.
float sd_number(vec2 q, float rr) {
	int num = clamp(paint_number, 0, 99);
	float h = rr * 0.40;
	float w = h * 0.46;
	float r = h * 0.13;
	if (num < 10) {
		return sd_digit(q, num, w, h, r);
	}
	float gap = w * 1.75;
	return min(sd_digit(q + vec2(gap, 0.0), num / 10, w, h, r), sd_digit(q - vec2(gap, 0.0), num % 10, w, h, r));
}

// A racing roundel: white disc in an accent ring, black number, whatever the paint, so it reads.
vec3 roundel(vec3 col, vec2 q, float rr) {
	float d = length(q) - rr;
	col = mix(col, paint_accent.rgb, cover(d - 0.006));
	col = mix(col, vec3(0.80, 0.80, 0.77), cover(d + 0.007));
	col = mix(col, vec3(0.012), cover(sd_number(q, rr)));
	return col;
}

// Twin stripes nose to tail over the top, each edged with an accent pinstripe.
vec3 stripes(vec3 col, vec3 p, vec3 n) {
	if (n.y < -0.4) {
		return col;
	}
	float c = stripe_gap + stripe_w * 0.5;
	float d = abs(abs(p.x) - c) - stripe_w * 0.5;
	col = mix(col, paint_accent.rgb, cover(d - 0.007));
	col = mix(col, paint_primary.rgb, cover(d - 0.004));
	col = mix(col, paint_secondary.rgb, cover(d));
	return col;
}

// Hot-rod flames licking back from the nose along the sides and over the bonnet.
vec3 flames(vec3 col, vec3 p, vec3 n) {
	if (n.y < -0.4) {
		return col;
	}
	float s = p.z - nose_z;                                       // metres back from the nose
	// Across the flames: up the side, then on over the top toward the centre line.
	float over = smoothstep(0.35, 0.8, n.y);
	float c = mix(p.y, belt_y + (side_x - abs(p.x)), over);
	float period = 0.085;
	float k = floor(c / period);
	float len = 0.42 + 0.42 * hash13(vec3(k, 3.1, 7.7));
	float q = fract(c / period) - 0.5 + 0.16 * sin(s * 11.0 + k * 1.7) * smoothstep(0.0, 0.25, s);
	float t = clamp(s / len, 0.0, 1.0);
	float half_w = 0.5 * (1.0 - pow(t, 1.4));
	float d = (abs(q) - half_w) * period;                         // metres, negative inside a tongue
	d = max(d, s - len);
	d = min(d, s - 0.10);                                         // solid fire at the very front
	vec3 fire = mix(paint_accent.rgb, paint_secondary.rgb, smoothstep(0.1, 0.85, t));
	col = mix(col, paint_secondary.rgb * 0.35, cover(d - 0.005));
	col = mix(col, fire, cover(d));
	return col;
}

// Splinter camo: hard-edged shards in the three paint colours, from a 3D Voronoi sheared and
// stretched along the car, so the cells' straight borders run back and slant like broken glass.
vec3 pattern_colour(vec3 cell) {
	float h = hash13(cell + vec3(5.3, 1.7, 8.9));
	return h < 0.45 ? paint_primary.rgb : (h < 0.8 ? paint_secondary.rgb : paint_accent.rgb);
}

vec3 splinter(vec3 p) {
	vec3 q = vec3(p.x * 7.0, (p.y + p.z * 0.55) * 7.0, p.z * 3.2);
	vec3 i = floor(q);
	vec3 f = fract(q);
	float f1 = 8.0;
	float f2 = 8.0;
	vec3 c1 = i;
	vec3 c2 = i;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash13(i + g), hash13(i + g + 17.1), hash13(i + g + 31.7));
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < f1) {
					f2 = f1;
					c2 = c1;
					f1 = d;
					c1 = i + g;
				} else if (d < f2) {
					f2 = d;
					c2 = i + g;
				}
			}
		}
	}
	// Half way between the two nearest sites is the border: blend across it over a pixel.
	return mix(pattern_colour(c2), pattern_colour(c1), cover(sqrt(f1) - sqrt(f2)));
}

// Tiger stripes: bands across the top that sweep back and taper to points down the flanks.
vec3 tiger(vec3 col, vec3 p, vec3 n) {
	if (n.y < -0.4) {
		return col;
	}
	// Distance down from the top's centre line, roughly over the body.
	float c = abs(p.x) + max(belt_y + 0.2 - p.y, 0.0);
	float period = 0.13;
	float u = p.z / period + c * 3.2;
	float k = floor(u);
	float len = 0.34 + 0.30 * hash13(vec3(k, 1.3, 9.1));
	float t = clamp(c / len, 0.0, 1.0);
	float half_w = 0.30 * (1.0 - t * t) + 0.02;
	float q = fract(u) - 0.5 + 0.10 * sin(c * 23.0 + k * 2.3);
	float d = (abs(q) - half_w) * period;
	d = max(d, c - len);
	col = mix(col, paint_accent.rgb, cover(d - 0.004));
	col = mix(col, paint_secondary.rgb, cover(d));
	return col;
}

// Rally: a swoosh rising along each side from the front wheel to the rear quarter, edged with an
// accent pinstripe, and a door plate with the racing number.
vec3 rally(vec3 col, vec3 p, vec3 n) {
	if (abs(n.x) < 0.3) {
		return col;
	}
	float s = clamp((p.z - nose_z) / (tail_z - nose_z), 0.0, 1.0);
	float yc = belt_y - 0.22 + 0.17 * smoothstep(0.05, 0.95, s);
	float hw = mix(0.010, 0.070, smoothstep(0.0, 0.85, s));
	float d = abs(p.y - yc) - hw;
	col = mix(col, paint_accent.rgb, cover(abs(d - 0.016) - 0.006));
	col = mix(col, paint_secondary.rgb, cover(d));
	if (abs(n.x) > 0.55) {
		vec2 q = vec2(-sign(p.x) * (p.z - door_roundel.x), p.y - door_roundel.y);
		vec2 e = abs(q) - vec2(roundel_r * 1.2, roundel_r * 0.75);
		float plate = length(max(e, 0.0)) + min(max(e.x, e.y), 0.0) - 0.008;
		col = mix(col, paint_accent.rgb, cover(plate - 0.006));
		col = mix(col, vec3(0.80, 0.80, 0.77), cover(plate));
		col = mix(col, vec3(0.012), cover(sd_number(q, roundel_r)));
	}
	return col;
}

// Streaks: a panel in the secondary colour along each side (the doors), its ends broken into
// horizontal brush strokes of random length that taper to points.
vec3 streaks(vec3 col, vec3 p, vec3 n) {
	if (abs(n.x) < 0.35 || p.y > belt_y + 0.015) {
		return col;
	}
	float mid = mix(nose_z, tail_z, 0.47);
	float half_len = (tail_z - nose_z) * 0.17;
	float band = 0.026;
	float k = floor(p.y / band);
	float f = fract(p.y / band) * 2.0 - 1.0;
	float ahead = p.z < mid ? 1.0 : 0.0;
	float reach = half_len * (0.8 + 0.7 * hash13(vec3(k, 2.1 + ahead * 5.0, 5.3)));
	float d = abs(p.z - mid) - reach + 0.12 * f * f;
	return mix(col, paint_secondary.rgb, cover(d));
}

// Claw: the tops (bonnet, roof, rails) in the secondary colour, and three claw slashes across each
// door in the accent, raked back, curved a little and tapering to points at both ends.
vec3 claw(vec3 col, vec3 p, vec3 n) {
	col = mix(col, paint_secondary.rgb, smoothstep(0.45, 0.65, n.y));
	if (abs(n.x) < 0.4) {
		return col;
	}
	// Along the car toward the tail and up, from the door's centre: the same rake on both sides.
	vec2 q = vec2(p.z - door_roundel.x, p.y - door_roundel.y);
	float len = roundel_r * 3.2;
	float hw = roundel_r * 0.17;
	vec2 u = normalize(vec2(0.42, 1.0));
	vec2 v = vec2(u.y, -u.x);
	float d = 1e3;
	for (int k = 0; k < 3; k++) {
		vec2 r = q - vec2(float(k - 1) * roundel_r * 0.85, 0.0);
		float t = dot(r, u) / (len * 0.5);
		float s = dot(r, v) - roundel_r * 0.30 * (1.0 - t * t);
		float taper = max(1.0 - t * t, 0.0);
		d = min(d, max(abs(s) - hw * taper, abs(t) * len * 0.5 - len * 0.5));
	}
	return mix(col, paint_accent.rgb, cover(d));
}

vec3 paint_albedo(vec3 p, vec3 n) {
	vec3 col = paint_primary.rgb;
	if (paint_pattern == PAT_STRIPES) {
		col = stripes(col, p, n);
	} else if (paint_pattern == PAT_TWO_TONE) {
		float d = belt_y - 0.012 - p.y;
		col = mix(col, paint_secondary.rgb, cover(d));
		col = mix(col, paint_accent.rgb, cover(abs(d + 0.006) - 0.0035));
	} else if (paint_pattern == PAT_SIDE_STRIPE) {
		if (abs(n.x) > 0.3) {
			float mid = belt_y - 0.075;
			float d = abs(p.y - mid) - 0.03;
			col = mix(col, paint_accent.rgb, cover(abs(d - 0.012) - 0.0035));
			col = mix(col, paint_secondary.rgb, cover(d));
		}
	} else if (paint_pattern == PAT_FLAMES) {
		col = flames(col, p, n);
	} else if (paint_pattern == PAT_CHECKER) {
		// A chequered band, four squares wide, down the middle from nose to tail.
		float sq = 0.045;
		float band = abs(p.x) - sq * 2.0;
		if (n.y > -0.4) {
			vec2 cell = floor(vec2(p.x, p.z) / sq);
			float odd = mod(cell.x + cell.y, 2.0);
			vec3 chk = mix(paint_secondary.rgb, paint_accent.rgb, odd);
			col = mix(col, paint_primary.rgb * 0.25, cover(band - 0.006));
			col = mix(col, chk, cover(band));
		}
	} else if (paint_pattern == PAT_CAMO) {
		float a = fbm(p * 6.5);
		float b = fbm(p * 6.5 + vec3(13.7, 3.1, 27.9));
		col = mix(col, paint_secondary.rgb, cover((0.53 - a) * 0.2));
		col = mix(col, paint_accent.rgb, cover((0.58 - b) * 0.2));
	} else if (paint_pattern == PAT_RACER) {
		col = stripes(col, p, n);
		if (abs(n.x) > 0.55) {
			vec2 q = vec2(-sign(p.x) * (p.z - door_roundel.x), p.y - door_roundel.y);
			col = roundel(col, q, roundel_r);
		}
		if (n.y > 0.5 && p.z < hood_z + hood_r * 2.0) {
			vec2 q = vec2(p.x, hood_z - p.z);
			col = roundel(col, q, hood_r);
		}
	} else if (paint_pattern == PAT_FADE) {
		float t = smoothstep(nose_z + 0.25, tail_z - 0.25, p.z + 0.05 * (vnoise(p * 9.0) - 0.5));
		col = mix(paint_primary.rgb, paint_secondary.rgb, t);
	} else if (paint_pattern == PAT_SPLINTER) {
		col = splinter(p);
	} else if (paint_pattern == PAT_TIGER) {
		col = tiger(col, p, n);
	} else if (paint_pattern == PAT_RALLY) {
		col = rally(col, p, n);
	} else if (paint_pattern == PAT_STREAKS) {
		col = streaks(col, p, n);
	} else if (paint_pattern == PAT_CLAW) {
		col = claw(col, p, n);
	}
	return col;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 alb = base;
	float rough = 0.6;
	float metal = 0.0;
	float spec = 0.5;
	float cc = 0.0;
	float ccr = 0.1;
	vec3 emit = vec3(0.0);
	if (v_mat <= M_PAINT) {
		vec3 n_obj = normalize(v_nrm);
		alb = paint_albedo(v_pos, n_obj);
		if (paint_finish == FIN_GLOSS) {
			rough = 0.2;
			cc = 1.0;
			ccr = 0.04;
		} else if (paint_finish == FIN_METALLIC) {
			// Flakes: a little per-sparkle roughness, faded out before they could shimmer.
			float flake = hash13(floor(v_pos * 900.0));
			float near = 1.0 - smoothstep(0.0004, 0.0012, length(fwidth(v_pos)));
			rough = 0.32 + (flake - 0.5) * 0.18 * near;
			metal = 0.7;
			cc = 0.8;
			ccr = 0.05;
		} else if (paint_finish == FIN_MATTE) {
			rough = 0.72;
			spec = 0.35;
		} else if (paint_finish == FIN_PEARL) {
			float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
			alb = mix(alb, paint_accent.rgb, fres * 0.65);
			rough = 0.22;
			metal = 0.35;
			cc = 1.0;
			ccr = 0.04;
		} else if (paint_finish == FIN_CHROME) {
			alb = mix(vec3(0.95), alb, 0.65);
			rough = 0.06;
			metal = 1.0;
		}
		if (v_mat == M_BODY) {
			vec4 d = texture(detail_map, UV);
			alb *= 1.0 - 0.8 * d.g;
			cc *= 1.0 - d.g;
			alb = mix(alb, vec3(0.012), d.a);
			rough = mix(rough, 0.55, d.a);
			metal = mix(metal, 0.0, d.a);
			cc = mix(cc, 0.0, d.a);
			alb = mix(alb, vec3(0.86), d.b);
			metal = mix(metal, 1.0, d.b);
			rough = mix(rough, 0.08, d.b);
			alb = mix(alb, vec3(0.010, 0.013, 0.016), d.r);
			rough = mix(rough, 0.03, d.r);
			metal = mix(metal, 0.0, d.r);
			spec = mix(spec, 0.9, d.r);
			cc = mix(cc, 0.0, d.r);
		}
	} else if (v_mat == M_RUBBER) {
		rough = 0.86;
		spec = 0.3;
	} else if (v_mat == M_RIM) {
		alb = paint_rim.rgb * base;
		metal = 0.45;
		rough = 0.38;
	} else if (v_mat == M_CHROME) {
		metal = 1.0;
		rough = 0.07;
	} else if (v_mat == M_ALLOY) {
		metal = 0.8;
		rough = 0.36;
	} else if (v_mat == M_DARK) {
		rough = 0.62;
	} else if (v_mat == M_ANODISED) {
		alb = paint_accent.rgb * base;
		metal = 0.6;
		rough = 0.3;
	} else if (v_mat == M_HEADLAMP) {
		// Clear lens over a reflector: faint rings round the lens's centre (its UV is the offset from
		// there in metres, CarDesign.lens), a little glow.
		float rr = length(UV);
		alb = vec3(0.70, 0.72, 0.74) * (0.85 + 0.15 * sin(rr * 260.0));
		rough = 0.08;
		spec = 0.8;
		emit = vec3(0.05, 0.05, 0.045);
	} else if (v_mat == M_TAILLAMP) {
		// Lamp lens in its vertex colour (red tail, amber marker), glowing a little.
		alb = base * 0.6;
		rough = 0.1;
		spec = 0.7;
		emit = base * 0.3;
	}
	alb = mix(alb, fx_tint.rgb, fx_tint.a);
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	CLEARCOAT = cc;
	CLEARCOAT_ROUGHNESS = ccr;
	EMISSION = emit + fx_glow.rgb * fx_glow.a;
#ifdef CAR_FADE
	ALPHA = fx_alpha;
#endif
}
