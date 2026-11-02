shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Railway ballast for Freight Line (FreightKit.track_piece, turnout): crushed stone, drawn from the desert
// pavement's pebbles (dark_canyon_rock.png) washed out to grey and laid in world space from above, so beds
// that meet or overlap match. UV.x and UV.y are the metres across the bed from the centre of each track it
// carries (99 where there is no second track): between the rails the stone is stained dark with oil and
// rust, a rusty line runs under each rail, and the shoulders are dusty with the plain's sand. The vertex
// colour's grey scales the stone (0.5 leaves it as it is). The meshes carry no tangents, so the stones'
// normal map is applied in world space.

uniform sampler2D stones_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stones_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres of track one tile of the stones covers (the stones come out about 7cm across).
uniform float tile_m = 1.7;
uniform float gauge_half = 1.076;
uniform vec4 oil : source_color = vec4(0.30, 0.27, 0.25, 1.0);
uniform vec4 rust : source_color = vec4(0.46, 0.30, 0.20, 1.0);
uniform vec4 dust : source_color = vec4(0.80, 0.68, 0.52, 1.0);

varying vec3 w_pos;
varying vec3 w_nrm;

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
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 q = w_pos.xz / tile_m;
	vec3 s = texture(stones_tex, q).rgb;
	// A second, coarser read breaks up the tiling.
	vec3 s2 = texture(stones_tex, q * 0.29 + vec2(0.37, 0.71)).rgb;
	float lum = dot(s, vec3(0.3, 0.59, 0.11));
	// Crushed basalt and granite: grey, with a little of the pavement's warmth left in it.
	vec3 stone = mix(vec3(lum), s, 0.28) * 3.1;
	stone *= 0.82 + 0.45 * dot(s2, vec3(0.333));
	float patchy = vnoise(w_pos.xz * 0.35) * 0.6 + vnoise(w_pos.xz * 1.7) * 0.4;
	stone *= 0.9 + 0.2 * patchy;
	stone *= COLOR.rgb * 2.0;

	// Distance from the nearest rail line of either track, and whether that is between its rails.
	float lat = min(abs(UV.x), abs(UV.y));
	float between = 1.0 - smoothstep(gauge_half - 0.3, gauge_half + 0.05, lat);
	float under_rail = exp(-pow((lat - gauge_half) / 0.2, 2.0));
	float n1 = vnoise(w_pos.xz * 0.9 + 3.0) * 0.6 + vnoise(w_pos.xz * 4.3) * 0.4;
	vec3 col = mix(stone, stone * oil.rgb * 2.2, between * (0.45 + 0.4 * n1));
	col = mix(col, stone * rust.rgb * 1.9, under_rail * (0.35 + 0.3 * n1));
	// The shoulders: sand blown up onto them from the plain, thickest at the foot.
	float shoulder = smoothstep(2.4, 4.2, lat) * step(lat, 50.0);
	col = mix(col, dust.rgb * (0.8 + 0.3 * patchy), shoulder * (0.35 + 0.35 * vnoise(w_pos.xz * 0.6 + 9.0)));

	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.35;
	// The stones' relief, tipped onto the face in world space (the texture is laid from above).
	vec3 tn = texture(stones_normal, q).rgb * 2.0 - 1.0;
	vec3 n = normalize(w_nrm);
	vec3 bumped = normalize(n + vec3(tn.x, 0.0, -tn.y) * 0.8);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
}
