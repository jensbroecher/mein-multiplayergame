// The water in an overshot wheel's buckets (Yoshino Rapids' sawmill, regenerate_yoshino_rapids.gd _build_wheel_water).
// The mesh is a child of the turning wheel: one small quad a bucket, its vertices only carrying where they belong:
//   UV.x  the bucket's angle about the axle in the wheel's own frame (0 at its top, toward +z: the way the top turns)
//   UV.y  -0.5 or 0.5: which end of the water's surface across the bucket
//   UV2.x the vertex's place along the axle (life metres), UV2.y unused
// Each frame the vertex shader finds where its bucket is now (from MODEL_MATRIX, so it follows the wheel's turn) and lays
// the water's surface in it level, filled by how far round the loaded side the bucket has come: filling under the flume's
// lip at the top, full down the loaded side, spilling as it tips past the axle's height and empty from near the bottom;
// the rising side's buckets are dry. The surface is clipped to the bucket's own outline (its two boards, the sole, the
// mouth: the kit's water_wheel), so it never shows through the wood. The shrouds hide the rest: it shows in the mouths.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, world_vertex_coords, specular_schlick_ggx;

uniform float rim_r = 2.37;        // just inside the rim boards' outer edge (life metres)
uniform float elbow_r = 2.19;      // where each bucket's board bends back
uniform float sole_r = 2.01;       // just outside the sole (the buckets' floor)
uniform float back = 0.24;         // the elbow's bend back against the turn (radians: WHEEL_BUCKET_BACK)
uniform float pitch = 0.3927;      // the angle between buckets (TAU / WHEEL_BUCKETS)
uniform float board = 0.025;       // kept off each board (radians)
uniform float fill = 0.85;         // a loaded bucket's water, as a share of what it holds up to its lip
uniform vec3 water_color : source_color = vec3(0.22, 0.42, 0.40);
uniform vec3 foam_color : source_color = vec3(0.86, 0.93, 0.93);
uniform float opacity = 0.88;

varying float v_fill;
varying float v_churn;
varying vec3 w_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A point of the wheel's plane (radius, angle about the axle in the wheel's own frame) in the world's vertical plane
// through the axle: x along `dn` (the way the top runs), y up, both in life metres from the axle.
vec2 to_plane(float r, float a, mat3 rot, vec3 dn) {
	vec3 w = rot * vec3(0.0, cos(a), sin(a)) * r;
	return vec2(dot(w, dn), w.y);
}

void vertex() {
	vec3 ax = MODEL_MATRIX[0].xyz;
	float sc = length(ax);
	ax /= sc;
	mat3 rot = mat3(MODEL_MATRIX[0].xyz / sc, MODEL_MATRIX[1].xyz / sc, MODEL_MATRIX[2].xyz / sc);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 dn = normalize(cross(ax, up));
	// The bucket: its floor board (from the sole at a0 out to the elbow, then back to the rim), the board above it
	// (a pitch earlier), the sole between and the mouth at the rim. Kept a little inside the wood.
	float a0 = UV.x - board;
	float a1 = UV.x - pitch + board;
	vec2 poly[6];
	poly[0] = to_plane(sole_r, a0, rot, dn);
	poly[1] = to_plane(elbow_r, a0, rot, dn);
	poly[2] = to_plane(rim_r, a0 - back, rot, dn);
	poly[3] = to_plane(rim_r, a1 - back, rot, dn);
	poly[4] = to_plane(elbow_r, a1, rot, dn);
	poly[5] = to_plane(sole_r, a1, rot, dn);
	float lo = 1e9;
	for (int k = 0; k < 6; k++) {
		lo = min(lo, poly[k].y);
	}
	// It holds water up to the lower end of its mouth: as it tips past the axle's height that falls, and it pours.
	float lip = min(poly[2].y, poly[3].y);
	vec2 mid = to_plane((rim_r + sole_r) * 0.5, UV.x - pitch * 0.5, rot, dn);
	float th = atan(mid.x, mid.y);
	float loaded = smoothstep(0.02, 0.38, th) * step(th, 3.0);
	float depth = max(lip - lo, 0.0) * fill * loaded;
	float level = lo + depth;
	// Where that level crosses the bucket's outline: the water's surface from wall to wall.
	float h0 = 1e9;
	float h1 = -1e9;
	for (int k = 0; k < 6; k++) {
		vec2 p = poly[k];
		vec2 q = poly[(k + 1) % 6];
		if ((p.y - level) * (q.y - level) <= 0.0 && abs(q.y - p.y) > 1e-5) {
			float h = mix(p.x, q.x, (level - p.y) / (q.y - p.y));
			h0 = min(h0, h);
			h1 = max(h1, h);
		}
	}
	if (depth < 0.01 || h0 > h1) {
		h0 = mid.x;
		h1 = mid.x;
		depth = 0.0;
	}
	float h = UV.y < 0.0 ? h0 : h1;
	VERTEX = MODEL_MATRIX[3].xyz + (dn * h + up * level) * sc + ax * UV2.x * sc;
	NORMAL = up;
	v_fill = clamp(depth / 0.12, 0.0, 1.0);
	// Churned white where the flume's water is landing in it, and as it pours out.
	v_churn = (1.0 - smoothstep(0.25, 0.6, th)) + smoothstep(1.6, 2.2, th) * 0.6;
	w_pos = VERTEX;
}

void fragment() {
	if (v_fill < 0.02) {
		discard;
	}
	float t = TIME;
	float rip = sin(w_pos.x * 23.0 + t * 7.0) * sin(w_pos.z * 19.0 - t * 6.0);
	float sparkle = hash(floor(w_pos.xz * 40.0) + floor(t * 9.0));
	float foam = clamp(v_churn * (0.55 + 0.45 * sparkle) + 0.15 * rip, 0.0, 1.0);
	ALBEDO = mix(water_color, foam_color, foam * 0.85);
	ROUGHNESS = mix(0.06, 0.5, foam);
	SPECULAR = 0.6;
	NORMAL = normalize(NORMAL + vec3(0.12 * rip, 0.0, 0.08 * rip));
	ALPHA = opacity * smoothstep(0.02, 0.18, v_fill) * mix(0.85, 1.0, foam);
}
