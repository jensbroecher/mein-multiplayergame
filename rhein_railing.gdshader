// Railings drawn on one quad (RheinBridgeKit.gd, keys "railing" and "barrail"): UV is in game metres, u along the railing,
// v up from its foot. Everything that isn't iron is discarded, so the quad is two-sided and costs two triangles a bay.
//   style 0: the old Rhine bridge's cast-iron railing (1912): a top rail and a bottom rail, a middle rail at 62%, square
//            balusters every 0.2m below it, a frieze of rings with a quatrefoil cross between the middle and the top rail.
//   style 1: the motorway bridge's steel railing: a handrail tube, a bottom rail and plain vertical bars every 0.13m.
// The vertex colour is the paint. Lines never get thinner than about a pixel (fwidth), so far off a railing reads as a
// darker band with gaps instead of breaking up into dots.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform int style = 0;
uniform float height = 1.76;

float bar(float x, float w, float fw) {
	return step(abs(x), max(w * 0.5, fw * 0.75));
}

void fragment() {
	vec2 q = UV;
	vec2 fwv = fwidth(q);
	float fw = max(fwv.x, fwv.y);
	float H = height;
	float solid = 0.0;
	if (style == 0) {
		float top = H - 0.1;
		float mid = H * 0.62;
		solid = max(solid, step(top, q.y));
		solid = max(solid, step(q.y, 0.09));
		solid = max(solid, bar(q.y - mid, 0.05, fw));
		// Balusters below the middle rail.
		float bx = (fract(q.x / 0.2) - 0.5) * 0.2;
		solid = max(solid, bar(bx, 0.03, fw) * step(q.y, mid));
		// The frieze: rings between the middle rail and the top rail, a cross in each.
		float band = top - mid;
		float rr = band * 0.42;
		float pitch = band * 0.95;
		vec2 c = vec2((fract(q.x / pitch) - 0.5) * pitch, q.y - (mid + top) * 0.5);
		float d = length(c);
		float inband = step(mid, q.y) * step(q.y, top);
		solid = max(solid, bar(d - rr, 0.026, fw) * inband);
		solid = max(solid, bar(d - rr * 0.38, 0.02, fw) * inband);
		// The quatrefoil's spokes and the ties between the rings.
		float sp = min(abs(c.x + c.y), abs(c.x - c.y)) * 0.7071;
		solid = max(solid, bar(sp, 0.018, fw) * step(d, rr) * inband);
		solid = max(solid, bar(c.y, 0.022, fw) * step(rr, d) * inband);
		// Spear points on every other baluster, under the middle rail.
		float spear = step(abs(bx), 0.035 - (q.y - (mid - 0.11)) * 0.32) * step(mid - 0.11, q.y) * step(q.y, mid);
		solid = max(solid, spear * step(0.5, fract(q.x / 0.4)));
	} else {
		solid = max(solid, step(H - 0.07, q.y));
		solid = max(solid, bar(q.y - 0.12, 0.06, fw));
		solid = max(solid, bar(q.y - (H - 0.3), 0.04, fw));
		float bx = (fract(q.x / 0.13) - 0.5) * 0.13;
		solid = max(solid, bar(bx, 0.025, fw) * step(0.09, q.y));
	}
	if (solid < 0.5) {
		discard;
	}
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = paint * (0.92 + 0.08 * sin(q.x * 3.1 + q.y * 7.0));
	ROUGHNESS = style == 0 ? 0.62 : 0.42;
	METALLIC = style == 0 ? 0.15 : 0.55;
}
