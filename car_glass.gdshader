// car_glass.gdshader: a procedural car's see-through canopy (its builder's build_glass(), the "Glass"
// mesh beside the body). car_body.gdshaderinc's CAR_GLASS path: tinted, glossy, premultiplied. It
// carries the car's instance uniforms, so CarPaint.apply and PlayerCart's flashes treat it like the
// body; a fade swaps in car_body_fade.gdshader, which draws the glass by its material id (dark trim).
shader_type spatial;
render_mode blend_premul_alpha, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#define CAR_GLASS
#include "res://car_body.gdshaderinc"
