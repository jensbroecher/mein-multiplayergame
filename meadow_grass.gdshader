shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The Lakeside Course's meadow grass (MeadowGrass.gd, regenerate_lakeside.gd's _build_meadow): tufts of
// real blades, each a curved, tapering strip with rounded normals, swaying in gusts that roll across the
// meadow from the wind turbines' side, like the trees' crowns.
//
// The tufts aren't placed one by one. Every cell of a tier draws the same MultiMesh, a cell's worth of
// tufts at y = 0, and the shader stands each tuft on the ground and decides whether it grows there:
//   height_map - the terrain's vertex heights (RG8, 16 bits), read on the terrain's own triangles,
//                each 2m cell split from (x + 1, z) to (x, z + 1) as TerrainGenerator indexes it
//   grass_map  - R how much grass grows (0 under props, trunks, rocks, the road and the water), G how
//                tall it is (mown verges and pads are short); drawn by the generator at 0.5m
// A tuft is moved, turned and sized from a hash of where it stands, so the cells don't repeat.
//
// Vertex data (MeadowGrass.gd): COLOR.r how far up the blade, COLOR.g a random per blade, COLOR.b
// the part (0 blade, 0.5 flower stalk, 1 flower head), COLOR.a the flower's slot. UV.x runs across the blade.
//
// Each tier fades its tufts out by shrinking them between fade_begin and fade_end (times range_scale,
// MeadowDetail.gd's detail level), and the tiers that carry on grow wider as the others thin out.

uniform sampler2D height_map : filter_nearest, repeat_disable;
// x0, z0, step, vertices per side
uniform vec4 height_grid = vec4(-1000.0, -1000.0, 2.0, 1001.0);
uniform vec2 height_range = vec2(-40.0, 60.0);
uniform sampler2D grass_map : filter_linear, repeat_disable;
// x0, z0, metres across
uniform vec3 grass_grid = vec3(-1000.0, -1000.0, 2000.0);

uniform float fade_begin = 45.0;
uniform float fade_end = 60.0;
uniform float range_scale = 1.0;
// Wider with distance as the nearer tiers fade: (begin, end, factor) twice.
uniform vec3 widen_a = vec3(40.0, 62.0, 1.0);
uniform vec3 widen_b = vec3(130.0, 152.0, 1.0);
// Metres a tuft is moved from its place in the cell, so the cells don't repeat.
uniform float jitter = 0.9;
uniform float tuft_height = 1.15;
uniform float flower_share = 0.22;

uniform vec2 wind_dir = vec2(0.28, -0.96);
uniform float wind_strength = 0.2;
uniform float gust_speed = 5.5;
uniform float gust_size = 34.0;

uniform vec4 root_color : source_color = vec4(0.13, 0.27, 0.05, 1.0);
uniform vec4 mid_color : source_color = vec4(0.30, 0.54, 0.11, 1.0);
uniform vec4 tip_color : source_color = vec4(0.56, 0.73, 0.24, 1.0);
uniform vec4 dry_color : source_color = vec4(0.72, 0.70, 0.36, 1.0);
uniform vec4 lush_color : source_color = vec4(0.24, 0.52, 0.10, 1.0);
uniform vec4 flower_a : source_color = vec4(0.98, 0.84, 0.12, 1.0);
uniform vec4 flower_b : source_color = vec4(0.97, 0.96, 0.92, 1.0);
uniform vec4 flower_c : source_color = vec4(0.72, 0.34, 0.66, 1.0);
uniform vec4 flower_d : source_color = vec4(0.36, 0.50, 0.92, 1.0);

// Carts push the grass aside (Level.gd feeds their positions).
uniform vec3 player_positions[8];
uniform int player_count = 0;

varying vec3 v_color;
varying float v_ao;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float height_at(ivec2 i) {
	vec2 t = texelFetch(height_map, i, 0).rg;
	float n = round(t.r * 255.0) * 256.0 + round(t.g * 255.0);
	return height_range.x + n / 65535.0 * (height_range.y - height_range.x);
}

float ground_at(vec2 p) {
	vec2 g = (p - height_grid.xy) / height_grid.z;
	vec2 c = clamp(floor(g), vec2(0.0), vec2(height_grid.w - 2.0));
	vec2 f = clamp(g - c, vec2(0.0), vec2(1.0));
	ivec2 i = ivec2(c);
	float h00 = height_at(i);
	float h10 = height_at(i + ivec2(1, 0));
	float h01 = height_at(i + ivec2(0, 1));
	float h11 = height_at(i + ivec2(1, 1));
	if (f.x + f.y <= 1.0) {
		return h00 + f.x * (h10 - h00) + f.y * (h01 - h00);
	}
	return h11 + (1.0 - f.x) * (h01 - h11) + (1.0 - f.y) * (h10 - h11);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec4 rnd = hash42(origin.xz * 1.37 + 17.0);
	vec2 pos = origin.xz + (rnd.xy - 0.5) * jitter;
	float d = distance(pos, CAMERA_POSITION_WORLD.xz);
	float fe = fade_end * range_scale;
	float fb = fade_begin * range_scale;
	vec2 gm = textureLod(grass_map, (pos - grass_grid.xy) / grass_grid.z, 0.0).rg;
	// A tuft grows where its random is under the grass amount; near the threshold it is smaller.
	float grow = smoothstep(0.0, 0.12, gm.r - rnd.z * 0.98) * (1.0 - smoothstep(fb, fe, d));
	v_ao = 1.0;
	v_color = vec3(0.0);
	if (grow <= 0.002 || d > fe) {
		VERTEX = vec3(0.0);
	} else {
		vec4 rnd2 = hash42(pos * 0.71 - 3.0);
		bool flower = COLOR.b > 0.25;
		// Flowers grow in drifts: a share of the tufts in the patches the noise picks.
		float drift = smoothstep(0.42, 0.72, vnoise(pos * 0.021 + 40.0));
		if (flower && rnd2.x > flower_share * drift + 0.03) {
			VERTEX = vec3(0.0);
		} else {
			float ground = ground_at(pos);
			float wide = mix(1.0, widen_a.z, smoothstep(widen_a.x * range_scale, widen_a.y * range_scale, d))
					* mix(1.0, widen_b.z, smoothstep(widen_b.x * range_scale, widen_b.y * range_scale, d));
			float tall = tuft_height * mix(0.72, 1.22, rnd.w) * max(gm.g, 0.08) * mix(0.35, 1.0, grow);
			float ang = rnd2.y * TAU;
			mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
			vec3 v = VERTEX;
			v.xz = rot * (v.xz * wide * mix(0.85, 1.2, rnd2.z));
			v.y *= tall;
			vec3 n = NORMAL;
			n.xz = rot * n.xz;
			// Wind: gusts roll across the meadow along wind_dir; each blade flutters on its own.
			vec2 wd = normalize(wind_dir);
			vec2 gp = (pos - wd * TIME * gust_speed) / gust_size;
			float gust = vnoise(gp) * 0.65 + vnoise(gp * 2.7 + 9.3) * 0.35;
			gust = gust * gust;
			float h = COLOR.r;
			float flutter = sin(TIME * (3.2 + COLOR.g * 2.0) + COLOR.g * 40.0 + pos.x * 0.9 + pos.y * 0.7);
			float sway = wind_strength * (0.25 + 1.6 * gust) + flutter * 0.05 * (0.4 + gust);
			float bend = h * h * sway * tall;
			v.xz += wd * bend + vec2(-wd.y, wd.x) * flutter * 0.025 * h * tall;
			v.y -= bend * bend * 0.6 / max(tall, 0.1);
			// Carts push it flat round them.
			vec3 world = vec3(pos.x + v.x, ground + v.y, pos.y + v.z);
			if (player_count > 0 && h > 0.05) {
				vec2 push = vec2(0.0);
				float down = 0.0;
				for (int i = 0; i < player_count; i++) {
					vec3 diff = world - player_positions[i];
					float dd = dot(diff.xz, diff.xz);
					if (dd < 6.25 && abs(diff.y) < 2.5) {
						float dist = sqrt(max(dd, 0.0001));
						float p = 1.0 - dist / 2.5;
						p = p * p * h;
						push += diff.xz / dist * p * 1.4;
						down += p * 0.6;
					}
				}
				world.xz += push;
				world.y -= down * tall;
			}
			VERTEX = world - origin;
			// Mostly up, like the ground under it, so the meadow shades as one mass and blades seen
			// from behind aren't black; the blade's own normal gives each one a little modelling.
			NORMAL = normalize(mix(n, vec3(0.0, 1.0, 0.0), 0.72));
			// Colour per tuft: lush or dry patches across the meadow, and a little per blade.
			float patch = vnoise(pos * 0.012 + 3.0) * 0.7 + vnoise(pos * 0.05) * 0.3;
			vec3 tip = mix(tip_color.rgb, dry_color.rgb, smoothstep(0.55, 0.85, patch) * 0.8);
			vec3 mid = mix(mid_color.rgb, lush_color.rgb, smoothstep(0.45, 0.15, patch));
			vec3 c = h < 0.45 ? mix(root_color.rgb, mid, h / 0.45) : mix(mid, tip, (h - 0.45) / 0.55);
			c *= mix(0.82, 1.12, COLOR.g) * mix(0.9, 1.08, rnd2.w);
			if (flower) {
				float pick = vnoise(pos * 0.017 - 11.0) * 3.999;
				vec3 fc = pick < 1.0 ? flower_a.rgb : (pick < 2.0 ? flower_b.rgb : (pick < 3.0 ? flower_c.rgb : flower_d.rgb));
				// Petals, a golden eye, or the stalk.
				c = COLOR.b > 0.75 ? (COLOR.a > 0.5 ? fc : vec3(0.62, 0.42, 0.05)) : mix(root_color.rgb, mid_color.rgb, h);
			}
			v_color = c;
			// Dark down in the tuft, as the blades shade each other.
			v_ao = mix(0.45, 1.0, smoothstep(0.0, 0.6, h));
		}
	}
}

void fragment() {
	ALBEDO = v_color;
	// Matt: the near-upright normals would otherwise mirror the blue sky.
	ROUGHNESS = 0.82;
	SPECULAR = 0.18;
	BACKLIGHT = v_color * 0.55;
	AO = v_ao;
	AO_LIGHT_AFFECT = 0.5;
}
