// car_body.gdshader
//
// One shader for a whole procedural car (CarBuilder.gd). The vertex's material id (UV2.x) picks
// paint, rubber, rim, chrome, aluminium, plastic, anodised or lamp; the vertex colour is the base
// shade (sRGB) for the unpainted ones. Everything the player chooses is a per-instance uniform
// (CarPaint.apply), so every car of a model shares this one material: the colours, the pattern
// (drawn here in the car's own frame, metres, front at -Z, from the model's layout uniforms) and
// the finish. On the body, the detail map (MudrunnerBuilder.build_detail_map) lays glass, black
// seals, panel gaps and chrome trim over the paint.
//
// PlayerCart's flashes (respawn blink, shock, teleport) also go through instance uniforms here
// (fx_glow, fx_tint) instead of a material per car; to fade a car out it swaps in the transparent
// twin, car_body_fade.gdshader. The code is in car_body.gdshaderinc, shared by both.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://car_body.gdshaderinc"
