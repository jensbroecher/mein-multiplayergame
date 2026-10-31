shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// A light beam in the haze over Club Kilele (Mtaa Nights): a cone from a moving head or a laser,
// additive. UV.y runs 0 at the head to 1 at the far end; the beam is brightest along its axis (where
// the cone's faces look at the camera) and fades out along its length, near the camera (so a beam swinging
// through the view never fills the screen) and with fog-like distance. ClubLights.gd turns the heads
// and sets each one's `tint` (an instance uniform, so every beam shares this material).

instance uniform vec3 tint = vec3(1.0, 0.3, 0.8);
instance uniform float strength = 1.0;
uniform float energy = 0.35;
uniform float near_fade = 7.0;

void fragment() {
	// Faces seen square-on lie across the middle of the beam; its silhouette fades out softly.
	float core = pow(abs(dot(normalize(NORMAL), VIEW)), 1.5);
	float along = 1.0 - smoothstep(0.0, 1.0, UV.y);
	along *= smoothstep(0.0, 0.04, UV.y);
	float d = length(VERTEX);
	float near = smoothstep(near_fade * 0.4, near_fade, d);
	float haze = 0.75 + 0.25 * sin(UV.y * 14.0 + TIME * 0.7);
	ALBEDO = tint * energy * strength * core * along * near * haze;
}
