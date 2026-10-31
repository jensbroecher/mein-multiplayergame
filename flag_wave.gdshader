shader_type spatial;
render_mode cull_disabled;

// A flag waving in the wind (regenerate_bloombay_dunes.gd, _flag). The mesh is in world space, the flag
// a vertical plane facing along NORMAL and streaming along cross(up, NORMAL). UV.x runs from the hoist
// (0) to the fly (1), UV.y from the top down. UV2.x is this flag's phase, UV2.y its length in metres.
// Waves run out from the pole and grow toward the fly, with a quicker flutter on top, and the normal is
// tilted with them so the folds catch the light. In a MultiMesh (Bloombay's flags on spring bases,
// SpringProps.gd) every instance shares one mesh, so INSTANCE_CUSTOM.x adds each flag's own phase.
// Reading TIME here is fine: it's sky shaders that must not, because there it rebuilds the radiance
// map every frame.

#include "res://flag_wave.gdshaderinc"

uniform float roughness_value = 0.85;

void fragment() {
	// Vertex colours are sRGB.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = roughness_value;
}
