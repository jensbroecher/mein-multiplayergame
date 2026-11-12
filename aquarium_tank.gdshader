shader_type spatial;
render_mode cull_back, unshaded;

// Tianqiao's aquarium (regenerate_tianqiao.gd): the tanks round the tunnel, seen from inside it. The tanks' walls,
// floor (sand, rocks) and roof carry this: their vertex colour is the surface, and everything is seen through water,
// so it fades into a blue-green by how far it is from the camera past the tunnel's glass (`clear`), darker with depth
// under the surface (`surface_y`); caustics ripple over the floor and rocks, light shafts fall from the surface.

uniform float surface_y = 40.0;
uniform float clear = 6.0;
uniform float murk = 0.05;
uniform vec3 deep : source_color = vec3(0.01, 0.08, 0.16);
uniform vec3 shallow : source_color = vec3(0.03, 0.22, 0.34);
uniform float energy = 1.2;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float caustic(vec2 p) {
	float t = TIME * 0.6;
	float a = vnoise(p * 0.7 + vec2(t, t * 0.7));
	float b = vnoise(p * 0.9 - vec2(t * 0.8, -t * 0.5) + 3.1);
	return pow(1.0 - abs(a - b), 8.0);
}

void fragment() {
	vec3 surf = pow(COLOR.rgb, vec3(2.2));
	float depth = clamp((surface_y - w_pos.y) / 30.0, 0.0, 1.0);
	vec3 water = mix(shallow, deep, depth);
	float up = clamp(w_nrm.y, 0.0, 1.0);
	surf *= 0.55 + caustic(w_pos.xz) * 1.6 * up * (1.0 - depth * 0.7);
	float d = max(length(w_pos - CAMERA_POSITION_WORLD) - clear, 0.0);
	float f = 1.0 - exp(-d * murk);
	vec3 c = mix(surf, water, f);
	// Light shafts: brighter columns of water, swaying.
	float shaft = smoothstep(0.62, 0.95, vnoise(vec2(w_pos.x * 0.08 + sin(TIME * 0.2) * 0.5, w_pos.z * 0.08)));
	c += shallow * shaft * f * 0.5 * (1.0 - depth);
	ALBEDO = c * energy;
}
