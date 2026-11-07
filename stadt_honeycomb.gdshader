// The 1960s department store's facade (StadtKit.gd, key "honeycomb"): a lattice of white glazed ceramic tiles laid in a
// honeycomb, every hexagon a shallow cup with a raised rim, grey joints between them. UV is in game metres (life x 1.6,
// StadtKit.uvk), u along the wall, v up; the vertex colour tints the glaze. The cups' walls tilt the normal toward the
// cell's middle (the mesh needs tangents: StadtKit.commit makes them), the cup's floor is shaded a little (no ambient
// occlusion otherwise), now and then a tile is a shade warmer, and the rain has left faint streaks down the wall.
// Filtered: under a few pixels a cell the pattern fades to its mean and the normal to the wall's, so a far facade
// doesn't shimmer.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// A hexagon's width across its flats, in game metres (0.6m life).
uniform float cell = 0.96;
uniform vec3 joint_color : source_color = vec3(0.50, 0.50, 0.48);
// How far the cups' walls tilt the normal.
uniform float cup_tilt = 0.75;
uniform float streaks = 0.18;

varying vec3 wpos;

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV / cell;
	// Hexagons 1 across their flats, centres on a (1, sqrt 3) lattice and its offset copy.
	vec2 s = vec2(1.0, 1.7320508);
	vec2 h = s * 0.5;
	vec2 a = mod(p, s) - h;
	vec2 b = mod(p - h, s) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = floor((p - g) * 2.0 + 0.5);
	// 0 at the cell's edge, 1 at its middle.
	float d = max(abs(g.x), dot(abs(g), vec2(0.5, 0.8660254)));
	float e = clamp(1.0 - d * 2.0, 0.0, 1.0);
	float aa = length(fwidth(p));
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float warm = step(0.86, hash12(id + vec2(3.1, 7.7)));
	vec3 glaze = tint * mix(vec3(0.93, 0.93, 0.91), vec3(0.95, 0.91, 0.82), warm) * (0.97 + 0.05 * hash12(id));
	vec3 jc = pow(joint_color, vec3(2.2));
	float jw = 0.05;
	float joint = 1.0 - smoothstep(jw - aa, jw + aa, e);
	// The cup: the rim from the joint to 0.3, its wall to 0.72, its floor to the middle.
	float wall = smoothstep(0.26, 0.34, e) * (1.0 - smoothstep(0.66, 0.76, e));
	float floor_ = smoothstep(0.7, 0.78, e);
	vec3 col = glaze;
	col *= 1.0 - 0.16 * floor_ - 0.08 * wall;
	col = mix(col, jc, joint);
	// Its normal: the wall leans toward the middle (a concave cup), the rim's outer edge rolls off into the joint.
	vec2 rad = length(g) > 1e-4 ? normalize(g) : vec2(0.0);
	float roll = smoothstep(0.2, 0.06, e) * (1.0 - joint);
	vec2 tilt = -rad * cup_tilt * wall + rad * 0.6 * roll;
	// Far off, the mean colour and a flat wall.
	float fade = smoothstep(0.12, 0.45, aa);
	vec3 mean = mix(glaze * 0.9, jc, 0.12);
	col = mix(col, mean, fade);
	tilt *= 1.0 - fade;
	// Rain streaks and grime, from the world position.
	float hcoord = wpos.x + wpos.z;
	float st = vnoise(vec2(hcoord * 1.3, wpos.y * 0.05)) * 0.65 + vnoise(vec2(hcoord * 0.21, wpos.y * 0.03 + 5.0)) * 0.35;
	col *= 1.0 - streaks * smoothstep(0.5, 0.95, st);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.22, 0.32, floor_), 0.9, joint * (1.0 - fade));
	SPECULAR = 0.55;
	NORMAL_MAP = normalize(vec3(tilt, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
