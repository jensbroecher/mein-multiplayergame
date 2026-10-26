// See-through for the raised race cameras (High Chase, Top Down): trees, palms, cacti and rocks
// between the camera and the player's cart are thinned by a screen-space dither inside a tube
// round the line from the camera to the cart, so the cart shows through them.
// PlayerCart sets the globals every frame (`_update_xray_globals`): slot a for player 1, b for
// player 2 in split screen. xyz the camera / the cart, the camera's w the strength (0 = off), the
// cart's w the tube's radius in metres. A slot only applies to the view whose camera it names, so
// each split-screen viewport opens its own player's tube, and no shadow pass cuts holes in shadows.

global uniform vec4 xray_cam_a;
global uniform vec4 xray_car_a;
global uniform vec4 xray_cam_b;
global uniform vec4 xray_car_b;

// Share of the fragments removed at the tube's centre: the rest still shows, so it reads as
// semi-transparent rather than gone.
const float XRAY_MAX_CUT = 0.72;

float xray_slot(vec3 vertex_view, mat4 view_matrix, vec3 cam_world, vec4 cam, vec4 car) {
	// The camera that renders is the physics-interpolated one, a little behind where PlayerCart put
	// it at speed, so the match is loose (split-screen players' cameras are never this close) and the
	// tube starts at the view's own camera (vertex_view's origin).
	if (cam.w <= 0.0 || distance(cam_world, cam.xyz) > 4.0) {
		return 0.0;
	}
	vec3 car_v = (view_matrix * vec4(car.xyz, 1.0)).xyz;
	float len = length(car_v);
	if (len < 1.0) {
		return 0.0;
	}
	vec3 dir = car_v / len;
	float along = dot(vertex_view, dir);
	float perp = length(vertex_view - dir * along);
	// Only in front of the cart (the margin keeps the road it stands on), opening toward the camera.
	float before = smoothstep(0.0, 2.5, len - 1.5 - along);
	float radius = car.w * mix(1.0, 1.35, clamp(1.0 - along / len, 0.0, 1.0));
	return cam.w * before * (1.0 - smoothstep(radius * 0.6, radius, perp));
}

// True where this fragment is dithered away. In fragment(): xray_hidden(VERTEX, VIEW_MATRIX,
// CAMERA_POSITION_WORLD, PROJECTION_MATRIX, FRAGCOORD.xy).
bool xray_hidden(vec3 vertex_view, mat4 view_matrix, vec3 cam_world, mat4 projection, vec2 frag) {
	// The sun's shadow pass is orthographic.
	if (projection[3][3] > 0.5) {
		return false;
	}
	float cut = max(xray_slot(vertex_view, view_matrix, cam_world, xray_cam_a, xray_car_a),
			xray_slot(vertex_view, view_matrix, cam_world, xray_cam_b, xray_car_b));
	if (cut <= 0.0) {
		return false;
	}
	// Interleaved gradient noise, as tree_lod.gdshaderinc's crossfade.
	float d = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
	return cut * XRAY_MAX_CUT > d;
}
