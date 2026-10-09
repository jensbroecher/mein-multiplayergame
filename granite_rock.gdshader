shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Granite boulders of Mara Crossing's kopjes (see granite.gdshaderinc for the look).
// The generator bakes occlusion into vertex colour r: dark in the cracks between stacked blocks
// and where a rock meets the ground. Vertex colour g is the height above the ground (0 at the
// foot, 1 from 1.5m up), where red dust from the plain stains the rock.

#include "res://granite.gdshaderinc"

uniform vec4 dust_color : source_color = vec4(0.62, 0.40, 0.26, 1.0);

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(30.0, 220.0, dist);
	vec3 n = normalize(w_nrm);
	float rough;
	float h;
	vec3 col = granite_albedo(w_pos, n, detail, rough, h);
	float occ = COLOR.r;
	float foot = 1.0 - COLOR.g;
	col = mix(col, dust_color.rgb * (0.8 + gr_noise(w_pos * 1.3) * 0.4), foot * foot * 0.7);
	col *= mix(0.42, 1.0, occ);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	AO = mix(0.35, 1.0, occ);
	AO_LIGHT_AFFECT = 0.35;
	NORMAL = gr_bump(NORMAL, VERTEX, h, mix(0.35, 1.0, detail));
}
