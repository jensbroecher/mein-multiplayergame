shader_type spatial;
render_mode cull_disabled;

// The RC Vibe GP flag (regenerate_canyon.gd, _build_logo_flag): flag_wave's wave with the flag's artwork
// from a texture (the logo on navy between orange bands, drawn by the generator), UV.x from the hoist to
// the fly and UV.y from the top down. It is printed through, so the back shows it too: the back face
// mirrors u, and the logo reads the right way round from either side.

#include "res://flag_wave.gdshaderinc"

uniform sampler2D flag_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float roughness_value = 0.8;

void fragment() {
	vec2 uv = UV;
	if (!FRONT_FACING) {
		uv.x = 1.0 - uv.x;
	}
	ALBEDO = texture(flag_tex, uv).rgb;
	ROUGHNESS = roughness_value;
}
