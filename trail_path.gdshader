// The Lakeside Meadows' paths (regenerate_lakeside.gd, _build_trails): a ribbon laid a few centimetres over the
// ground. UV.x runs across it (0 and 1 its edges), UV.y metres along it; COLOR.r picks the kind: 0 a footpath (worn
// earth in two wheel-less ruts with grass along its crown), 1 the bike path (compacted pale gravel, a darker line
// worn down the middle of each lane). The edges are ragged: grass creeps in by noise (discarded, so the meadow's own
// ground shows through) and the path fades into the grass's colour toward them. The vertices are pulled toward the
// eye along their own rays (as the skid marks are): the same pixels, but it wins the depth test against the ground it
// lies on at any distance, without standing off it.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 earth : source_color = vec3(0.47, 0.37, 0.26);
uniform vec3 gravel : source_color = vec3(0.74, 0.69, 0.58);
uniform vec3 grass_edge : source_color = vec3(0.33, 0.45, 0.16);
uniform float fade_far = 380.0;

varying vec3 w_pos;
varying float v_kind;

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

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_kind = COLOR.r;
	vec3 view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(view);
	view *= max(d - (0.03 + d * 0.0015), 0.0) / max(d, 1e-4);
	POSITION = PROJECTION_MATRIX * vec4(view, 1.0);
}

void fragment() {
	float x = UV.x;
	float along = UV.y;
	float bike = step(0.5, v_kind);
	vec2 p = w_pos.xz;
	// Ragged edges: how far in the grass reaches varies along each edge.
	float edge_n = vnoise(vec2(along * 0.45, x < 0.5 ? 3.0 : 9.0)) * 0.6 + vnoise(vec2(along * 1.7, x < 0.5 ? 17.0 : 23.0)) * 0.4;
	float reach = mix(0.03, 0.16, edge_n) * mix(1.0, 0.55, bike);
	float e = min(x, 1.0 - x);
	if (e < reach) {
		discard;
	}
	float in_edge = smoothstep(reach, reach + 0.12, e);
	vec3 tex = texture(dirt_tex, p * 0.22).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	float patch = vnoise(p * 0.08) * 0.6 + vnoise(p * 0.31) * 0.4;
	vec3 col;
	if (bike > 0.5) {
		// Pale compacted gravel, a darker line worn down each lane, odd dark pebbles.
		col = gravel * (0.78 + lum * 0.55) * mix(0.92, 1.06, patch);
		float lane = 1.0 - smoothstep(0.0, 0.07, abs(abs(x - 0.5) - 0.24));
		col *= 1.0 - lane * 0.12;
		col *= 1.0 - step(0.93, hash12(floor(p * 9.0))) * 0.35;
	} else {
		// Worn earth: two ruts, grass along the crown between them.
		col = earth * (0.7 + lum * 0.7) * mix(0.88, 1.1, patch);
		float crown = 1.0 - smoothstep(0.05, 0.13, abs(x - 0.5));
		float tuft = smoothstep(0.35, 0.75, vnoise(p * 1.3) * 0.7 + vnoise(p * 4.0) * 0.3);
		col = mix(col, grass_edge * (0.8 + lum * 0.5), crown * tuft * 0.85);
	}
	// Into the grass's colour toward the edges.
	col = mix(grass_edge * (0.75 + lum * 0.4), col, in_edge);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.85, bike);
	NORMAL_MAP = texture(dirt_normal, p * 0.22).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	float d = length(VERTEX);
	if (d > fade_far) {
		discard;
	}
}
