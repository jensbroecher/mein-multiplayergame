// The Lakeside loop's platform (regenerate_lakeside.gd, _build_loop_apron): a concrete slab the road runs into and the
// loop stands on, flush with the road at both ends, flared out under both lanes. UV.x is metres right of the lap's line,
// UV.y metres along the platform; UV2.x the platform's half width there. Drawn here: cast concrete in bays (expansion
// joints every `bay` metres along and down the middle), a white line along its edge, yellow and black hazard stripes
// along the flared sides beyond the road's width, and white chevrons leading into the entry lane. The vertices are
// pulled a little toward the eye along their rays (as the skid marks and the paths are) so where its ends meet the road's
// last centimetres it wins the depth test instead of fighting it.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D concrete_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 concrete_tint : source_color = vec3(0.78, 0.77, 0.74);
uniform float bay = 5.0;
uniform float road_half = 8.0;
uniform float edge_line = 0.25;
uniform float stripe_band = 1.4;
// The entry lane: its middle across (metres right of the line) and where it starts along the platform.
uniform float entry_lat = -5.25;
uniform float entry_v = 5.0;
uniform float lane_half = 4.0;

varying vec3 w_pos;
varying float v_half;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_half = UV2.x;
	vec3 view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(view);
	view *= max(d - (0.02 + d * 0.0008), 0.0) / max(d, 1e-4);
	POSITION = PROJECTION_MATRIX * vec4(view, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float x = UV.x;
	float v = UV.y;
	vec2 p = w_pos.xz;
	vec3 tex = texture(concrete_tex, p * 0.25).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	// Each bay cast a shade apart.
	vec2 cell = floor(vec2(x / (v_half + 1e-3) * 1.0 + 1.0, v / bay));
	vec3 col = concrete_tint * (0.72 + lum * 0.5) * mix(0.94, 1.05, hash12(cell + 7.0));
	// Joints: across every `bay` metres and down the middle, a dark line that fades to its average far off.
	float fwv = max(fwidth(v), 1e-4);
	float fwx = max(fwidth(x), 1e-4);
	float jv = 1.0 - smoothstep(0.0, 0.03 + fwv, abs(fract(v / bay + 0.5) - 0.5) * bay);
	float jx = 1.0 - smoothstep(0.0, 0.03 + fwx, abs(x));
	float joint = max(jv, jx) * clamp(0.06 / (fwv + 0.02), 0.0, 1.0);
	col *= 1.0 - joint * 0.45;
	// From the edge in: the white line, then (where wider than the road) the hazard stripes.
	float edge = v_half - abs(x);
	float aa = max(fwx, 0.01);
	float line_w = 1.0 - smoothstep(edge_line - aa, edge_line + aa, edge);
	float wide = smoothstep(road_half + 0.3, road_half + 1.2, v_half);
	float in_band = (1.0 - smoothstep(edge_line + stripe_band - aa, edge_line + stripe_band + aa, edge)) * (1.0 - line_w) * wide;
	float diag = fract((v + abs(x)) / 1.2);
	float yellow = step(0.5, diag);
	vec3 stripes = mix(vec3(0.05, 0.05, 0.05), vec3(0.95, 0.72, 0.08), yellow);
	col = mix(col, stripes * (0.85 + lum * 0.25), in_band);
	col = mix(col, vec3(0.92, 0.92, 0.9) * (0.85 + lum * 0.2), line_w);
	// Chevrons into the entry lane: two white arrows pointing along the platform, on the lane's line before it starts.
	float lx = (x - entry_lat) / lane_half;
	if (abs(lx) < 0.9 && v > 0.6 && v < entry_v - 0.6) {
		for (int k = 0; k < 2; k++) {
			float tip = entry_v - 1.0 - float(k) * 2.4;
			float arm = (tip - v) - abs(lx) * 1.4;
			float c = (1.0 - smoothstep(0.42, 0.42 + fwv * 2.0, abs(arm - 0.25))) * step(-0.2, arm) * step(abs(lx), 0.85);
			col = mix(col, vec3(0.93, 0.93, 0.92) * (0.85 + lum * 0.2), c * 0.92);
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.82;
	NORMAL_MAP = texture(concrete_normal, p * 0.25).rgb;
	NORMAL_MAP_DEPTH = 0.5;
}
