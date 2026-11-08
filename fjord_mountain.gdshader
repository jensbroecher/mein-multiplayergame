shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The fjord's walls round Frostpeak Creek and Svartfjell at its head (regenerate_frostpeak_dressing.gd,
// _build_backdrop): one ring of ground from under the island's rim out to the far plane, seen from 0.5 to
// 4km. Winter: snow down to the water on anything gentle enough to hold it, dark rock on the steep faces
// with snow in the couloirs running down them, dark snowy forest on the lower slopes up to a ragged tree
// line, a wet dark band and a rim of ice along the water's edge, the bed dark under the water. The
// generator bakes into the vertex colour's g how black the rock is (1 on Svartfjell, which grows no forest).
// Every pattern is noise in world space (3D where it runs on steep faces: couloirs stretched down the
// height), never coordinates turned with the normal, which swirled like marble; snow on ledges across the
// faces read as brush strokes. The coarse mesh's normals change slowly, so the snow's edge has fine noise of
// its own or it smears into soft blobs. Fine terms fade by the size of a pixel in metres.

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 snow_color : source_color = vec4(0.84, 0.87, 0.93, 1.0);
uniform vec4 snow_shade_color : source_color = vec4(0.72, 0.78, 0.89, 1.0);
uniform vec4 rock_color : source_color = vec4(0.15, 0.15, 0.16, 1.0);
uniform vec4 black_rock_color : source_color = vec4(0.05, 0.05, 0.055, 1.0);
uniform vec4 forest_color : source_color = vec4(0.07, 0.10, 0.09, 1.0);
uniform vec4 ice_color : source_color = vec4(0.70, 0.80, 0.88, 1.0);
uniform float water_y = -1.2;
// n.y under which a face sheds its snow.
uniform float snow_slope : hint_range(0.0, 1.0) = 0.66;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 masks;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
}

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

vec3 triplanar(sampler2D tex, vec3 p, vec3 w, float s) {
	vec3 bw = pow(abs(w), vec3(6.0));
	bw /= max(bw.x + bw.y + bw.z, 0.0001);
	return texture(tex, p.zy * s).rgb * bw.x + texture(tex, p.xz * s).rgb * bw.y + texture(tex, p.xy * s).rgb * bw.z;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float px_m = length(fwidth(w_pos));
	float fine = 1.0 - smoothstep(5.0, 16.0, px_m);
	float black = masks.g;

	// --- Snow against the slope: broken at two scales, with a crisp edge -------------------------
	float big = vnoise3(w_pos * 0.006);
	float mid = vnoise3(w_pos * 0.021 + 3.7);
	float small = vnoise3(w_pos * 0.09 + 1.3);
	// The coarse mesh's normals change slowly across a face, so the snow's edge needs its own fine break-up
	// or it smears into soft blobs.
	float tiny = vnoise3(w_pos * 0.31 + 7.9);
	float breakup = (big - 0.5) * 0.18 + (mid - 0.5) * 0.16 + (small - 0.5) * 0.2 * fine
			+ (tiny - 0.5) * 0.1 * (1.0 - smoothstep(1.0, 4.0, px_m));
	float snow = smoothstep(snow_slope - 0.03, snow_slope + 0.03, n.y + breakup);
	// Couloirs: gullies of snow down the steep faces, long up and down, narrow across.
	float steep = 1.0 - smoothstep(snow_slope - 0.1, snow_slope + 0.05, n.y);
	float gully = vnoise3(w_pos * vec3(0.016, 0.0025, 0.016)) * 0.6 + vnoise3(w_pos * vec3(0.05, 0.008, 0.05) + 9.1) * 0.25
			+ small * 0.15;
	float couloir = smoothstep(0.67, 0.72, gully) * steep * step(0.12, n.y) * mix(1.0, 0.6, black);
	snow = max(snow, couloir);

	// --- Rock ------------------------------------------------------------------------------
	vec3 tex = triplanar(rock_albedo, w_pos, n, 0.012);
	float lum = dot(tex, vec3(0.3, 0.55, 0.15));
	vec3 rock = mix(rock_color.rgb, black_rock_color.rgb, black) * (0.7 + mid * 0.45 + big * 0.25);
	rock *= mix(1.0, lum * 2.4, 0.4 * fine);
	// Buttresses and gullies: bands of lighter and darker rock running down the faces, and the faces broken
	// into slabs.
	rock *= 0.78 + 0.44 * vnoise3(w_pos * vec3(0.03, 0.006, 0.03) + 2.2) * (0.6 + 0.4 * small);
	rock *= mix(1.0, 0.8 + tiny * 0.4, 1.0 - smoothstep(1.0, 4.0, px_m));
	// Paler streaks of frost on the bare walls.
	rock = mix(rock, snow_shade_color.rgb * 0.5, smoothstep(0.55, 0.85, vnoise3(w_pos * vec3(0.03, 0.006, 0.03))) * 0.25 * (1.0 - black));

	// --- Snow colour: faces turned from the sky read bluer ---------------------------------
	vec3 snow_col = mix(snow_shade_color.rgb, snow_color.rgb, smoothstep(0.35, 0.95, n.y)) * (0.94 + big * 0.1);

	// --- Forest: dark crowns, snow between and on them --------------------------------------
	// Up to a ragged tree line (worked out here: from the vertex colour it ran along the rings in a straight
	// band), on slopes a forest can stand on, not on Svartfjell, not at the water's edge.
	float above = w_pos.y - water_y;
	float tree_line = 300.0 + (big - 0.5) * 240.0 + (mid - 0.5) * 90.0 + (small - 0.5) * 30.0 * fine;
	float forest = smoothstep(0.66, 0.74, n.y + (mid - 0.5) * 0.1) * (1.0 - black) * smoothstep(4.0, 16.0, above)
			* (1.0 - smoothstep(tree_line - 25.0, tree_line + 10.0, w_pos.y));
	forest *= smoothstep(0.3, 0.45, vnoise3(w_pos * 0.011 + 5.0) * 0.7 + small * 0.3);
	float crowns = mix(0.5, vnoise3(w_pos * 0.32), fine);
	vec3 forest_col = mix(forest_color.rgb, snow_col * 0.85, 0.28 + 0.36 * smoothstep(0.45, 0.85, crowns));

	vec3 albedo = mix(rock, snow_col, snow);
	albedo = mix(albedo, forest_col, forest);
	float rough = mix(0.9, 0.7, snow * (1.0 - forest));

	// --- The water's edge: wet dark rock, then a rim of ice; the bed dark under the water ----
	float wet = (1.0 - smoothstep(0.5, 4.0 + big * 3.0, above)) * smoothstep(-0.6, 0.0, above);
	albedo = mix(albedo, rock * 0.6, wet * 0.85);
	float ice = (1.0 - smoothstep(0.1, 0.9 + big, above)) * smoothstep(-0.9, -0.3, above);
	albedo = mix(albedo, ice_color.rgb, ice * 0.8);
	albedo = mix(albedo, vec3(0.07, 0.08, 0.08), 1.0 - smoothstep(-1.6, -0.8, above));
	rough = mix(rough, 0.3, max(wet * 0.5, ice));

	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = mix(0.15, 0.3, snow);
}
