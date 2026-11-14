shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://camera_xray.gdshaderinc"

// The Miyoshino GP's garden and stream boulders (MiyoshinoPropKit.garden_rock, key "boulder"): the granite of
// granite.gdshaderinc, greyer, under cushions of moss on the tops and a damp, mossy foot. Vertex colour: r the occlusion
// baked by the builder (dark where the stone meets the ground and in its hollows), g the height over the ground (life
// metres / 1.5), b a seed.

#include "res://granite.gdshaderinc"

uniform vec3 moss_a : source_color = vec3(0.20, 0.30, 0.09);
uniform vec3 moss_b : source_color = vec3(0.36, 0.44, 0.15);
uniform vec3 damp : source_color = vec3(0.20, 0.21, 0.18);
uniform float moss_amount = 0.65;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	if (xray_hidden(VERTEX, VIEW_MATRIX, CAMERA_POSITION_WORLD, PROJECTION_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(20.0, 160.0, dist);
	vec3 n = normalize(w_nrm);
	float rough;
	float h;
	vec3 col = granite_albedo(w_pos * 1.6 + COLOR.b * 50.0, n, detail, rough, h);
	// Greyer than the kopjes' pink granite.
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(lum) * vec3(0.96, 1.0, 0.98), 0.55) * 0.82;
	float occ = COLOR.r;
	float foot = 1.0 - smoothstep(0.0, 0.18, COLOR.g);
	// Damp and dark where it stands in the ground or the stream.
	col = mix(col, damp, foot * 0.55);
	// Moss: cushions on what faces up, broken into patches, and a ragged band round the foot.
	float up = smoothstep(0.25, 0.85, n.y);
	float patches = smoothstep(0.38, 0.55, gr_fbm(w_pos * 2.2 + COLOR.b * 17.0));
	float m = clamp((up * patches + foot * 0.7 * smoothstep(0.3, 0.6, gr_fbm(w_pos * 5.0 + 3.0))) * moss_amount * 1.4, 0.0, 1.0);
	float tuft = gr_noise(w_pos * 38.0) * detail;
	vec3 moss = mix(moss_a, moss_b, smoothstep(0.3, 0.8, gr_fbm(w_pos * 7.0 + 9.0))) * (0.85 + 0.3 * tuft);
	col = mix(col, moss, m);
	col *= mix(0.5, 1.0, occ);
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.97, m);
	SPECULAR = mix(0.35, 0.15, m);
	AO = mix(0.4, 1.0, occ);
	AO_LIGHT_AFFECT = 0.3;
	NORMAL = gr_bump(NORMAL, VERTEX, h * (1.0 - m) + m * (0.012 + tuft * 0.006), mix(0.35, 1.0, detail));
}
