// Per-tree near/far crossfade for MultiMesh trees (Mara Crossing's acacias).
// lod_mode: 0 = always drawn, 1 = the detailed tree (dithers out between lod_fade_begin and
// lod_fade_end), 2 = the far stand-in (dithers in over the same band). The two use the same
// dither, so together they always cover exactly one tree.

uniform int lod_mode = 0;
uniform float lod_fade_begin = 270.0;
uniform float lod_fade_end = 330.0;
// Each tree's band is shifted by up to this much, so the swap isn't a sharp ring.
uniform float lod_jitter = 15.0;

float lod_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// A number per tree from its origin (MODEL_MATRIX[3].xyz in vertex(), which includes the
// MultiMesh instance's transform).
float lod_seed(vec3 origin) {
	return lod_hash(floor(origin * 0.37) + 0.5);
}

// The distance the crossfade uses: camera to the tree's origin, shifted per tree.
float lod_distance(vec3 origin, vec3 camera) {
	return distance(origin, camera) + (lod_seed(origin) - 0.5) * 2.0 * lod_jitter;
}

// True where this fragment belongs to the other level of detail. Never in the sun's shadow pass
// (orthographic, its "camera" is the light), so shadows don't flicker.
bool lod_hidden(float dist, vec2 frag, mat4 projection) {
	if (lod_mode == 0 || projection[3][3] > 0.5) {
		return false;
	}
	float t = clamp((dist - lod_fade_begin) / max(lod_fade_end - lod_fade_begin, 0.001), 0.0, 1.0);
	// Interleaved gradient noise: a fine, even screen-space dither.
	float d = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
	return (lod_mode == 1 && t > d) || (lod_mode == 2 && t <= d);
}
