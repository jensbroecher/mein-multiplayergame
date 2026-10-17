// car_body_fade.gdshader: car_body.gdshader drawn transparent, for a car fading out (PlayerCart
// swaps it in as the meshes' material_override while their alpha is below 1; fx_alpha is the
// alpha). The per-instance paint carries over, being the instance's, not the material's.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

#define CAR_FADE
#include "res://car_body.gdshaderinc"
