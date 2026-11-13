// A drone light show (DroneShow.gd): every drone is one instance of a quad in a MultiMesh, and everything it does is
// worked out here from INSTANCE_ID and the show's clock, so the CPU only sets `show_time` each frame.
// pos_tex: one column per drone, one row per formation: xyz in the show's frame (metres, +z toward the audience), w its
// motion (< 0 still; 0..1 the dragon's body wave along it; 2 breathing; 4 lanterns swaying; 6 turning about z).
// col_tex: the same layout, the drone's colour. Each formation holds `hold` seconds, then the drones fly to the next over
// `trans`, each setting off a little after the last (by its id's hash), lifting toward the audience on the way.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D pos_tex : filter_nearest, repeat_disable;
uniform sampler2D col_tex : source_color, filter_nearest, repeat_disable;
uniform int formations = 5;
uniform float hold = 14.0;
uniform float trans = 8.0;
uniform float show_time = 0.0;
uniform float energy = 3.0;
// A drone's light: its size in metres, and never smaller than this share of its distance (so it stays a point far off).
uniform float size = 1.4;
uniform float min_angle = 0.0026;

varying vec3 v_col;
varying float v_fade;

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

vec3 animate(vec4 p, float t) {
	vec3 q = p.xyz;
	float w = p.w;
	if (w >= 0.0 && w <= 1.0) {
		// The dragon: a wave running down its body from head to tail, the head swinging with it.
		q.y += sin(w * 9.0 - t * 1.4) * 7.0 * (0.35 + 0.65 * w);
		q.z += cos(w * 7.0 - t * 1.1) * 4.0;
	} else if (w >= 2.0 && w < 3.0) {
		q *= 1.0 + 0.04 * sin(t * 0.9);
	} else if (w >= 4.0 && w < 5.0) {
		// Lanterns sway from their strings (the string's top at y 60).
		float arm = max(60.0 - q.y, 0.0);
		q.x += sin(t * 0.8 + p.x * 0.02) * arm * 0.05;
	} else if (w >= 6.0 && w < 7.0) {
		float a = t * 0.22;
		q.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * q.xy;
	}
	return q;
}

void vertex() {
	int id = INSTANCE_ID;
	float seg = hold + trans;
	float cyc = seg * float(formations);
	float t = mod(show_time, cyc);
	int k = int(floor(t / seg));
	float local = t - float(k) * seg;
	int k2 = (k + 1) % formations;
	float h = hash11(float(id) * 0.731 + 3.1);
	float lag = h * trans * 0.3;
	float m = clamp((local - hold - lag) / (trans * 0.7), 0.0, 1.0);
	m = m * m * (3.0 - 2.0 * m);
	vec4 a = texelFetch(pos_tex, ivec2(id, k), 0);
	vec4 b = texelFetch(pos_tex, ivec2(id, k2), 0);
	vec3 pa = animate(a, show_time);
	vec3 pb = animate(b, show_time);
	vec3 p = mix(pa, pb, m);
	// On the way between shapes: out toward the audience and up a little, each on its own arc.
	float arc = sin(m * PI);
	p += vec3(0.0, 6.0 + 10.0 * h, 14.0 + 18.0 * hash11(float(id) * 1.37)) * arc;
	vec3 ca = texelFetch(col_tex, ivec2(id, k), 0).rgb;
	vec3 cb = texelFetch(col_tex, ivec2(id, k2), 0).rgb;
	v_col = mix(ca, cb, m) * mix(1.0, 0.55, arc);
	// A twinkle on some drones.
	v_col *= 0.85 + 0.15 * sin(show_time * (2.0 + 3.0 * h) + h * 40.0);
	vec4 view = VIEW_MATRIX * (MODEL_MATRIX * vec4(p, 1.0));
	float d = max(-view.z, 1.0);
	float s = max(size, d * min_angle);
	// Far ones whose size is held up by the angle are dimmed to the same total light.
	v_fade = clamp(size / s, 0.25, 1.0);
	view.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float core = exp(-r * r * 9.0);
	float halo = exp(-r * r * 2.2) * 0.35;
	float a = (core + halo) * v_fade;
	if (a < 0.004) {
		discard;
	}
	ALBEDO = v_col * energy * a;
}
