// A lamp's light (LampGlow.gd): unshaded, the vertex colour (sRGB) times `energy`, over 1 so the glow blooms it. For the
// night and dusk stages: CampKit's and MatatuKit's "lamp" (a StandardMaterial3D with emission MULTIPLY and no emission
// texture, whose default is black) gives off no light at all, and a StandardMaterial3D can't glow in its vertex colour.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float energy = 2.4;

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * energy;
}
