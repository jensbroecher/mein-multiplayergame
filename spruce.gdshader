shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Snowy spruce for Frostfall Gorge. The generator builds each tree as drooping star-shaped branch
// whorls and bakes into the vertex colour:
//   rgb - needle (or bark) colour, already darkened toward the shaded core of the tree
//   a   - how much snow that surface can hold: 1 on the upper side of a branch, 0 underneath
// and UV in metres: x out along the branch from the trunk, y around the whorl. The generated needle
// texture (twigs along x, needles angled toward the twig tip) is laid on with those, so every tree
// shows needles at the same real-world size.
// Normals are rounded outward from the trunk rather than faceted, so the crown shades like a
// mass of needles instead of like a stack of cones. Everything else - needle grain, snow clumps,
// per-tree tint and a little sway - is done here so one mesh can stand in for the whole forest.

uniform vec4 snow_color : source_color = vec4(0.86, 0.90, 0.97, 1.0);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.5;
uniform float sway : hint_range(0.0, 0.3) = 0.06;
uniform sampler2D needle_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D needle_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres per texture repeat.
uniform float needle_tile = 1.1;
uniform float needle_normal_depth : hint_range(0.0, 3.0) = 1.1;

varying vec3 local_pos;
varying vec3 w_nrm;
varying float tree_seed;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local_pos = VERTEX;
	vec3 origin = MODEL_MATRIX[3].xyz;
	tree_seed = hash31(floor(origin * 0.37) + 0.5);
	// Sway grows with height and with distance from the trunk: tips move, the trunk does not.
	float bend = pow(max(VERTEX.y, 0.0) / 11.0, 2.0) + length(VERTEX.xz) * 0.04;
	float phase = TIME * (0.9 + tree_seed * 0.4) + tree_seed * 6.28;
	VERTEX.xz += vec2(sin(phase), cos(phase * 0.83)) * sway * bend;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// Per-tree tint: some trees bluer, some more olive, some darker.
	base *= mix(vec3(0.86, 0.96, 1.04), vec3(1.10, 1.04, 0.86), tree_seed) * (0.85 + tree_seed * 0.3);

	// Needle grain: fine streaks running out along the branches, plus clumping.
	float radial = length(local_pos.xz);
	float ang = atan(local_pos.z, local_pos.x);
	float grain = vnoise3(vec3(ang * 9.0, radial * 2.6, local_pos.y * 3.0));
	float clumps = vnoise3(local_pos * 1.7 + tree_seed * 13.0);
	// Bark is the only brown in the mesh (red above green); it gets no needles.
	float is_bark = step(COLOR.g, COLOR.r);
	vec2 nuv = UV / needle_tile;
	float needle_l = texture(needle_albedo, nuv).r;
	vec3 needles = base * mix(1.0, 0.45 + needle_l * 1.25, 1.0 - is_bark) * (0.80 + grain * 0.30) * (0.85 + clumps * 0.30);

	// Snow lies on the upper sides of branches, in clumps, thicker toward the tips' upper faces.
	float up = smoothstep(0.45, 0.92, normalize(w_nrm).y);
	float clump_snow = vnoise3(local_pos * vec3(2.4, 3.2, 2.4) + 3.1);
	float snow = COLOR.a * up * smoothstep(0.62 - snow_amount * 0.55, 0.85 - snow_amount * 0.35, clump_snow * 0.6 + up * 0.5);
	snow = clamp(snow, 0.0, 1.0);

	vec3 col = mix(needles, snow_color.rgb * (0.88 + grain * 0.12), snow);
	ALBEDO = col;
	ROUGHNESS = mix(0.88, 0.72, snow);
	SPECULAR = mix(0.18, 0.32, snow);
	// Light coming through the outer needles.
	BACKLIGHT = vec3(0.10, 0.16, 0.08) * (1.0 - snow) * (1.0 - is_bark);
	// Needle relief, fading under snow and on the bark.
	NORMAL_MAP = texture(needle_normal, nuv).rgb;
	NORMAL_MAP_DEPTH = needle_normal_depth * (1.0 - snow * 0.8) * (1.0 - is_bark);
}
