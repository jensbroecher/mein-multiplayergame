shader_type spatial;
render_mode cull_back;

#include "res://granite.gdshaderinc"

// Flag Hill's ground (regenerate_arena_ctf.gd: the heightfield and the country past it, one material). Vertex colour:
// r how open the ground is (1 meadow .. 0 under the woods), g bare rock (outcrops, the ranges' heads), b packed dirt
// (the tracks between the bases and round them), a sand (the trench's floor, the bowl). Everything else is worked out
// here in world metres, so the heightfield and the far rings match:
//   - the meadow in lush and dry patches (two sizes of noise), its texture at two scales;
//   - under the woods the forest floor (dark, litter), and past `canopy_from` the canopy itself, mottled: from far
//     off a wood is seen from above, and the 3D trees stop;
//   - the tracks with ragged edges, worn pale grass along them, damp patches and stones;
//   - rock on every steep face (the edge broken by noise): the boulders' grey granite (granite.gdshaderinc), bedded
//     by height, moss and grass on its ledges. The pebble-rubble texture it had drew every cliff dark brown.
// No pattern here is finer than its texture's mipmaps resolve, so nothing shimmers far off.

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 grass_lush : source_color = vec3(0.21, 0.40, 0.11);
uniform vec3 grass_dry : source_color = vec3(0.44, 0.50, 0.20);
uniform vec3 forest_floor : source_color = vec3(0.30, 0.30, 0.17);
uniform vec3 canopy : source_color = vec3(0.105, 0.20, 0.085);
uniform float canopy_from = 380.0;
uniform float canopy_to = 560.0;
uniform vec3 rock_tint : source_color = vec3(0.86, 0.85, 0.83);
uniform vec3 moss : source_color = vec3(0.24, 0.33, 0.13);
uniform vec3 dirt_color : source_color = vec3(0.50, 0.40, 0.29);
uniform vec3 sand_tint : source_color = vec3(0.92, 0.84, 0.66);

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 w = COLOR;
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float n_big = vnoise(w_pos.xz / 47.0);
	float n_mid = vnoise(w_pos.xz / 11.0 + 7.3);
	float n_fine = vnoise(w_pos.xz / 2.4 + 3.1);

	// The meadow.
	vec3 gt = texture(grass_tex, w_pos.xz / 4.5).rgb;
	vec3 gt2 = texture(grass_tex, w_pos.xz / 29.0).rgb;
	float patchy = smoothstep(0.3, 0.72, n_big * 0.62 + n_mid * 0.38);
	vec3 g = mix(grass_lush, grass_dry, patchy * 0.75) * (0.6 + 0.95 * gt.g) * (0.88 + 0.3 * gt2.g);

	// Under the trees, and the canopy from far off.
	float woods = 1.0 - w.r;
	vec3 litter = forest_floor * (0.7 + 0.7 * texture(dirt_tex, w_pos.xz / 5.0).g) * (0.85 + 0.3 * n_mid);
	g = mix(g, litter, woods * 0.8);
	float far = smoothstep(canopy_from, canopy_to, dist);
	float crowns = 0.72 + 0.5 * vnoise(w_pos.xz / 8.0) * vnoise(w_pos.xz / 21.0 + 4.0) + 0.14 * n_big;
	g = mix(g, canopy * crowns, far * smoothstep(0.25, 0.6, woods));

	// The tracks: a ragged edge, the grass worn pale beside them.
	float dw = w.b > 0.01 ? smoothstep(0.3, 0.62, w.b + (n_fine - 0.5) * 0.5 + (n_mid - 0.5) * 0.2) : 0.0;
	float worn = w.b > 0.01 ? smoothstep(0.04, 0.3, w.b + (n_fine - 0.5) * 0.25) : 0.0;
	// Packed earth: the texture only for its grain (its own colour is a saturated red-brown that tiled), at two
	// scales, over a tan that wanders; damp patches, paler dust down the middle of what is driven most.
	float grain = dot(texture(dirt_tex, w_pos.xz / 5.0).rgb, vec3(0.333)) * 0.6 + dot(texture(dirt_tex, w_pos.xz / 17.0).rgb, vec3(0.333)) * 0.4;
	vec3 d = dirt_color * (0.5 + 1.5 * grain) * (0.84 + 0.3 * n_mid) * mix(vec3(1.0), vec3(1.1, 1.02, 0.9), n_big);
	d *= 1.0 - 0.24 * smoothstep(0.55, 0.8, vnoise(w_pos.xz / 5.3 + 11.0));
	d = mix(d, d * 1.22 + 0.03, smoothstep(0.6, 0.85, w.b) * 0.6);
	vec3 col = mix(g, mix(g, grass_dry * (0.6 + 1.0 * gt.g), 0.7), worn * (1.0 - woods));
	col = mix(col, d, dw);
	vec3 s = sand_tint * (0.62 + 0.75 * grain) * (0.9 + 0.2 * n_mid);
	col = mix(col, s, w.a);

	// Rock: every steep face and the outcrops, in beds, mossy where it lies flatter.
	float g_rough;
	float g_h;
	vec3 r = granite_albedo(w_pos, normalize(w_nrm), 1.0 - smoothstep(30.0, 220.0, dist), g_rough, g_h) * rock_tint;
	float bed = vnoise(vec2(w_pos.y * 0.55 + n_mid * 2.2, 3.0)) * 0.6 + vnoise(vec2(w_pos.y * 1.7 + n_big * 3.0, 9.0)) * 0.4;
	r *= 0.8 + 0.4 * bed;
	float steep = 1.0 - smoothstep(0.66, 0.86, w_nrm.y + (n_fine - 0.5) * 0.14 + (n_mid - 0.5) * 0.08);
	float crop = smoothstep(0.3, 0.62, w.g + (n_fine - 0.5) * 0.4 + (n_mid - 0.5) * 0.3);
	float rock = max(steep, crop * (0.35 + 0.65 * (1.0 - smoothstep(0.86, 0.99, w_nrm.y))));
	rock = max(rock, smoothstep(0.75, 1.0, w.g));
	float ledge = smoothstep(0.7, 0.92, w_nrm.y) * smoothstep(0.35, 0.7, n_mid * 0.6 + n_fine * 0.4);
	r = mix(r, moss * (0.7 + 0.8 * gt.g), ledge * 0.75 * (1.0 - smoothstep(0.75, 1.0, w.g)));
	col = mix(col, r, rock * (1.0 - w.a));

	ALBEDO = col;
	ROUGHNESS = mix(0.94, g_rough, rock * (1.0 - w.a));
	SPECULAR = 0.22;
}
