shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// SheepFlock.gd's animals and shepherd, drawn from MultiMeshes: one mesh per kind at life size (front toward -z, feet on
// y = 0), each instance posed by its custom data, so a flock is one draw and nothing is skinned.
//   UV.x    the part: 0 body (still), 1 head and neck (a sheep lowers it to graze), 2..5 the legs (front left, front right,
//           rear left, rear right; the shepherd's legs are 2 and 3, his swinging arm 4), 6 the tail
//   UV.y    the region: 0 fleece (curls and fuzz drawn here), 1 face and legs (black or cream by the instance's variant),
//           2 dark (hooves, eyes, nose), 3 the vertex colour as it is (the dog, the shepherd)
//   UV2     the part's pivot (y, z): legs swing, heads nod and tails wag about the x axis (a dog's tail about y) there
//   COLOR   rgb a tint (sRGB): the fleece's dirt toward the belly, the dog's and shepherd's colours
//   INSTANCE_CUSTOM  r the gait's phase (cycles), g its amplitude 0..1, b the head lowered 0..1 (a dog: lying 0..1),
//           a the variant (0 a white-faced sheep, 1 black-headed)

uniform int kind = 0;
// Each part's phase in the gait (cycles) and swing at full stride (radians); set per kind by SheepFlock.gd.
uniform float part_phase[8];
uniform float part_amp[8];
uniform float head_down = 1.45;
uniform vec4 fleece : source_color = vec4(0.86, 0.84, 0.78, 1.0);
uniform vec4 face_black : source_color = vec4(0.075, 0.068, 0.062, 1.0);
uniform vec4 face_cream : source_color = vec4(0.84, 0.79, 0.70, 1.0);

varying vec3 obj;
varying flat float region;
varying flat float variant;
varying flat float seed;

float h13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x), mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x), mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

vec3 bump(vec3 n_view, vec3 pos_view, float h, float strength) {
	vec3 dpdx = dFdx(pos_view);
	vec3 dpdy = dFdy(pos_view);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n_view);
	vec3 r2 = cross(n_view, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n_view - strength * grad);
}

void rot_x(inout vec3 v, inout vec3 n, vec2 piv, float a) {
	float c = cos(a);
	float s = sin(a);
	vec2 p = v.yz - piv;
	v.yz = piv + vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	n.yz = vec2(c * n.y - s * n.z, s * n.y + c * n.z);
}

void vertex() {
	int part = int(UV.x + 0.5);
	vec4 ic = INSTANCE_CUSTOM;
	float ph = ic.r;
	float gait = ic.g;
	region = UV.y;
	variant = ic.a;
	seed = fract(float(INSTANCE_ID) * 0.61803398 + 0.17);
	obj = VERTEX;
	vec2 piv = UV2;
	if (part >= 2 && part <= 5) {
		float a = sin((ph + part_phase[part]) * TAU) * part_amp[part] * gait;
		if (kind == 1) {
			// A dog lying down: its legs folded forward under it.
			a = mix(a, part <= 3 ? 1.35 : 1.15, ic.b);
		}
		rot_x(VERTEX, NORMAL, piv, a);
	} else if (part == 1 && kind == 0) {
		rot_x(VERTEX, NORMAL, piv, -ic.b * head_down);
	} else if (part == 6) {
		if (kind == 1) {
			// The dog's tail wags about y, less when it lies.
			float w = sin(TIME * 7.0 + seed * 20.0) * 0.45 * (1.0 - 0.7 * ic.b) + 0.2;
			float c = cos(w);
			float s = sin(w);
			vec2 p = VERTEX.xz - vec2(0.0, piv.y);
			VERTEX.xz = vec2(0.0, piv.y) + vec2(c * p.x - s * p.y, s * p.x + c * p.y);
			NORMAL.xz = vec2(c * NORMAL.x - s * NORMAL.z, s * NORMAL.x + c * NORMAL.z);
		} else {
			rot_x(VERTEX, NORMAL, piv, sin(ph * TAU * 2.0) * 0.18 * gait + sin(TIME * 2.3 + seed * 9.0) * 0.08);
		}
	}
	// A little bob with every step, legs left where they stand.
	if (part < 2 || part > 5) {
		VERTEX.y += abs(sin(ph * TAU)) * 0.018 * gait;
	}
}

void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	vec3 col;
	float rough = 0.92;
	float fw = length(fwidth(obj));
	if (region < 0.5) {
		// Fleece: dense curls (two octaves of noise in the model's own space), fading to their average far off.
		float fade = smoothstep(0.004, 0.03, fw);
		float n = vnoise3(obj * 22.0) * 0.6 + vnoise3(obj * 51.0) * 0.4;
		float lumps = vnoise3(obj * 7.0);
		float h = mix(n, 0.5, fade);
		col = pow(fleece.rgb, vec3(2.2)) * tint * (0.78 + 0.34 * h) * (0.9 + 0.16 * lumps) * mix(0.9, 1.06, seed);
		col *= mix(vec3(1.0), vec3(1.02, 0.98, 0.9), seed);
		NORMAL = bump(NORMAL, VERTEX, h * 0.012, 1.0 - fade);
		RIM = 0.45;
		RIM_TINT = 0.7;
		rough = 1.0;
	} else if (region < 1.5) {
		vec3 face = variant > 0.5 ? pow(face_black.rgb, vec3(2.2)) : pow(face_cream.rgb, vec3(2.2));
		col = face * (0.9 + 0.2 * vnoise3(obj * 40.0));
		rough = 0.75;
	} else if (region < 2.5) {
		col = vec3(0.025, 0.022, 0.02);
		rough = 0.45;
	} else {
		col = tint;
		rough = 0.85;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
}
