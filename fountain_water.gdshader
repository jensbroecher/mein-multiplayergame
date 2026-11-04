// Fountain water (Estación Seca's plaza, regenerate_freight_line.gd _build_fountain_water).
// mode 0: a pool's surface (a disc, UV round its top cap): rings running out from where the water falls in, a little
// noise chop over them, a clear blue-green with a bright rim of light. mode 1: a falling sheet (an open cone or
// cylinder, UV.y down it): streaks racing down, thinning and breaking up toward the bottom, white where it hits.
// All from TIME: a few meshes, no particles.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform int mode = 0;
uniform vec4 deep : source_color = vec4(0.10, 0.30, 0.34, 1.0);
uniform vec4 shallow : source_color = vec4(0.36, 0.62, 0.62, 1.0);
// Pool: the radius (model units) where the water lands, and how fast its rings run out.
uniform float fall_r = 1.0;
uniform float ring_speed = 0.9;
uniform float fall_speed = 3.2;
varying vec3 v_pos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	if (mode == 0) {
		vec2 p = v_pos.xz;
		float r = length(p);
		// Rings out from the falling sheet's foot, both ways, fading with distance from it.
		float d = abs(r - fall_r);
		float ring = sin(d * 14.0 - TIME * ring_speed * 9.0) * exp(-d * 1.4);
		float chop = vn(p * 3.0 + vec2(TIME * 0.4, -TIME * 0.3)) - 0.5;
		float hgt = ring * 0.6 + chop * 0.4;
		// A normal from the height's slope (derivatives across the pixel).
		vec3 n_world = normalize(vec3(-dFdx(hgt) * 6.0, 1.0, -dFdy(hgt) * 6.0));
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(n_world, 0.0)).xyz, 0.6));
		vec3 col = mix(deep.rgb, shallow.rgb, 0.45 + 0.35 * hgt);
		// Foam where the water lands.
		float foam = smoothstep(0.35, 0.0, d) * (0.5 + 0.5 * vn(p * 9.0 + TIME * 2.0));
		col = mix(col, vec3(0.92, 0.95, 0.95), foam * 0.8);
		ALBEDO = col;
		ROUGHNESS = 0.06;
		METALLIC = 0.0;
		SPECULAR = 0.8;
		ALPHA = 0.9;
	} else {
		// UV.x round, UV.y down the sheet.
		float u = UV.x * 48.0;
		float v = UV.y;
		float streak = vn(vec2(u, v * 3.0 - TIME * fall_speed)) * 0.7 + vn(vec2(u * 2.3, v * 7.0 - TIME * fall_speed * 1.4)) * 0.3;
		// Thins and breaks up toward the bottom.
		float cover = smoothstep(0.25 + 0.5 * v, 0.7 + 0.2 * v, streak);
		if (cover < 0.05) {
			discard;
		}
		vec3 col = mix(shallow.rgb, vec3(0.92, 0.96, 0.97), 0.35 + 0.5 * streak + 0.4 * smoothstep(0.8, 1.0, v));
		ALBEDO = col;
		ROUGHNESS = 0.1;
		SPECULAR = 0.7;
		ALPHA = cover * 0.8;
	}
}
