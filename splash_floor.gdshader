shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// splash_floor.gdshader: the title card's floor, dark polished stone. The cars and the logo stand again
// below it, mirrored (SplashScreen.gd), and the floor is see-through where it hides one: how much shows
// falls off with how far below the floor the reflected thing is (read from the depth texture), the way a
// reflection fades away from its contact. The sky's glow shows in it by Fresnel, a pool of orange light
// lies under the logo, and a ring of light spreads from the logo when its last letter lands.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 base_color : source_color = vec3(0.010, 0.016, 0.040);
uniform float rough : hint_range(0.0, 1.0) = 0.3;
uniform float mirror_strength : hint_range(0.0, 1.0) = 0.8;
// Metres below the floor over which a reflection fades to a third.
uniform float mirror_fade = 5.0;
uniform vec3 pool_color : source_color = vec3(1.0, 0.45, 0.12);
uniform vec3 pool_centre = vec3(0.0, 0.0, -4.0);
uniform vec2 pool_size = vec2(9.0, 4.0);
uniform float pool = 0.30;
// A ring of light, `ring_radius` metres from the pool's centre (under 0: none), and how bright.
uniform float ring_radius = -1.0;
uniform float ring_alpha = 0.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	v.xyz /= v.w;
	float behind = max(-v.z + VERTEX.z, 0.0);
	float mirror = mirror_strength * exp(-behind / mirror_fade);

	vec2 q = (world.xz - pool_centre.xz) / pool_size;
	float glow = pool * exp(-dot(q, q));
	float d = length(world.xz - pool_centre.xz);
	float ring = ring_alpha * exp(-pow((d - ring_radius) / 0.5, 2.0)) * step(0.0, ring_radius);

	ALBEDO = base_color;
	METALLIC = 0.0;
	ROUGHNESS = rough;
	SPECULAR = 0.55;
	EMISSION = pool_color * glow + vec3(1.0, 0.75, 0.45) * ring * 1.0;
	ALPHA = 1.0 - mirror;
}
