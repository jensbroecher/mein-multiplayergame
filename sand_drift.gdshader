shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_disabled;

// Sand blowing across the road where it has drifted over it (Jebel Sahar, regenerate_mountain_dressing.gd,
// SandFx): streamers of sand running along the wind, long and thin, wavering and breaking up as they go, on a
// strip lying over the road and its verges. Layer 0 lies on the surface (thin, sharp streamers), layer 1 a little
// above it (broad, faint, slower: the haze of sand lifted off the ground). COLOR.a fades the strip at its ends and
// sides. Vertices are pulled toward the eye (as the skid marks) so the layer on the road wins the depth test.
// Reading TIME is fine here (not a sky shader).

uniform vec2 wind_dir = vec2(0.78, 0.62);
uniform int layer = 0;
uniform float strength = 0.85;
uniform float speed = 7.5;
uniform vec4 sand_color : source_color = vec4(0.93, 0.72, 0.50, 1.0);

varying vec3 w_pos;
varying float fade;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fade = COLOR.a;
	vec3 to_cam = CAMERA_POSITION_WORLD - w_pos;
	float dist = length(to_cam);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(to_cam / max(dist, 0.001) * min(0.08 + dist * 0.002, 0.6), 0.0)).xyz;
}

void fragment() {
	vec2 w = normalize(wind_dir);
	vec2 across = vec2(-w.y, w.x);
	float u = dot(w_pos.xz, w);
	float v = dot(w_pos.xz, across);
	float big = float(layer);
	float t = TIME * speed * (1.0 - 0.45 * big);
	// Long along the wind, narrow across it; they waver sideways as they run.
	float wave = (vnoise(vec2(u * 0.05 - t * 0.03, v * 0.05)) - 0.5) * 6.0;
	vec2 q = vec2((u - t) * mix(0.12, 0.05, big), (v + wave) * mix(1.4, 0.35, big));
	float n = vnoise(q) * 0.65 + vnoise(q * vec2(2.3, 2.7) + 9.1) * 0.35;
	// Gusts: whole bands of streamers come and go.
	float gust = smoothstep(0.25, 0.75, vnoise(vec2((u - t * 1.4) * 0.012, v * 0.02) + 3.3));
	float streak = smoothstep(mix(0.5, 0.42, big), mix(0.72, 0.78, big), n) * (0.45 + 0.55 * gust);
	// Fine grains flickering within the streamers (fading out with distance).
	float fw = length(fwidth(w_pos));
	float grain = mix(1.0, 0.6 + 0.8 * hash12(floor(w_pos.xz * 18.0) + floor(t * 6.0)), (1.0 - big) * (1.0 - smoothstep(0.02, 0.15, fw)));
	float a = streak * grain * fade * strength;
	// Not right under the lens: a streamer filling the view reads as a smear.
	a *= smoothstep(1.5, 5.0, length(CAMERA_POSITION_WORLD - w_pos));
	ALBEDO = sand_color.rgb * (0.92 + 0.12 * n);
	ALPHA = clamp(a, 0.0, 0.9);
	ROUGHNESS = 1.0;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}
