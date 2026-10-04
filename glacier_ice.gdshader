shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Glacier ice for Northlight Caverns: the cavern shell, the seracs, the ice arches and the
// frozen lake.
//
// cull_disabled is a requirement, not a shortcut. The cavern shell is a single swept arch
// whose faces all have to be seen from inside the passage, and the ice arches are open
// rings; authoring every face's winding so both sides come out correct is the kind of
// thing that silently produces one invisible side. Normals are authored inward for the
// shell and from the solid's own centre elsewhere, so lighting is right either way.

uniform sampler2D ice_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 ice_color : source_color = vec4(0.44, 0.68, 0.86, 1.0);
uniform vec4 deep_color : source_color = vec4(0.10, 0.30, 0.52, 1.0);
uniform vec4 frosted_color : source_color = vec4(0.86, 0.93, 1.00, 1.0);
uniform vec4 vein_color : source_color = vec4(0.32, 0.92, 0.78, 1.0);
uniform vec4 aurora_tint : source_color = vec4(0.20, 0.62, 0.52, 1.0);

uniform float ice_scale : hint_range(0.005, 2.0) = 0.10;
uniform float normal_strength : hint_range(0.0, 4.0) = 0.10;
uniform float vein_density : hint_range(0.0, 2.0) = 0.55;
uniform float vein_glow : hint_range(0.0, 8.0) = 1.5;
uniform float frost_line : hint_range(-80.0, 400.0) = 40.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.42;
uniform float horizon_color_mix : hint_range(0.0, 1.0) = 0.35;

varying vec3 w_pos;
varying vec3 w_nrm;

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.11 + 7.3;
		a *= 0.5;
	}
	return v;
}

float ridge(vec2 p) {
	return 1.0 - abs(vnoise(p) * 2.0 - 1.0);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 w, float s) {
	vec3 bw = pow(abs(w), vec3(6.0));
	bw /= max(bw.x + bw.y + bw.z, 0.0001);
	vec4 cx = texture(tex, p.zy * s);
	vec4 cy = texture(tex, p.xz * s);
	vec4 cz = texture(tex, p.xy * s);
	return cx * bw.x + cy * bw.y + cz * bw.z;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 view = normalize(CAMERA_POSITION_WORLD - w_pos);
	float fres = pow(1.0 - clamp(dot(n, view), 0.0, 1.0), 3.0);

	// Distance fade: a tiling ice pattern that has lost its texels still reads as a repeat
	// across a 200m cavern wall, so the fine octaves are dropped with range and only a
	// noise-tinted flat colour is left.
	float detail = 1.0 - smoothstep(60.0, 420.0, length(w_pos - CAMERA_POSITION_WORLD));

	// Internal strata: ice is laid down in layers, and the banding is what sells it as
	// glacier rather than as blue plastic.
	float strata = fbm(vec2(w_pos.y * 0.26, (w_pos.x + w_pos.z) * 0.012));
	strata = mix(0.5, strata, 0.75);
	float band = 0.5 + 0.5 * sin(w_pos.y * 0.42 + strata * 6.0);

	// Fracture planes: two ridged noise fields at different scales and rotations. The
	// second one is what stops the first from reading as a single repeating vein pattern.
	float f1 = pow(ridge(w_pos.xz * ice_scale * 3.1 + vec2(0.0, w_pos.y * 0.05)), 6.0);
	float f2 = pow(ridge(w_pos.xy * ice_scale * 1.7 + 21.0), 8.0);
	float fracture = clamp(f1 + f2 * 0.8, 0.0, 1.0) * detail;

	// Frost settles on upward faces and anything shallow enough to hold it.
	float up_mask = smoothstep(0.15, 0.75, n.y);
	float altitude = 1.0 - smoothstep(frost_line - 30.0, frost_line + 60.0, w_pos.y);
	float frost = clamp(up_mask * (0.35 + altitude * 0.55) + (fbm(w_pos.xz * 0.05) - 0.5) * 0.5, 0.0, 1.0);
	frost = smoothstep(0.25, 0.85, frost);

	vec3 ice = mix(deep_color.rgb, ice_color.rgb, strata * 0.7 + band * 0.35);
	ice = mix(ice, ice * vec3(0.72, 0.88, 1.06), fres * 0.7);
	// Rock and silt suspended in the ice, otherwise it reads as glass.
	vec3 silt = triplanar(rock_albedo, w_pos, n, ice_scale * 0.35).rgb;
	ice = mix(ice, ice * 0.55 + silt * 0.22, 0.35);

	vec3 albedo = mix(ice, frosted_color.rgb, frost * 0.85);
	albedo = mix(albedo, albedo * 0.55, fracture * 0.6);

	ALBEDO = albedo;
	ROUGHNESS = clamp(mix(roughness, 0.72, frost) + fracture * 0.12, 0.03, 1.0);
	METALLIC = 0.0;
	SPECULAR = mix(0.36, 0.22, frost);

	NORMAL_MAP = triplanar(ice_normal, w_pos, n, ice_scale * 0.55).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (0.35 + 0.65 * detail) * clamp(1.0 - fwidth(w_pos.x) * 0.02 - fwidth(w_pos.z) * 0.02, 0.1, 1.0);

	// The veins glow: air trapped in the fracture planes scatters what little light the
	// cavern has, and that is the cavern's only real light source. A slow pulse keeps the
	// walls alive without reading as an effect.
	float pulse = 0.75 + 0.25 * sin(TIME * 0.6 + w_pos.z * 0.05 + w_pos.x * 0.03);
	EMISSION = vein_color.rgb * vein_glow * pulse * fracture * vein_density;
	// A faint standing glow on the ice itself, so the cavern never goes fully black.
	EMISSION += aurora_tint.rgb * 0.20 * (0.5 + 0.5 * band);
}