// The glass tube's glazing (regenerate_marina_nights.gd, _build_tube): one sheet over the vault, seen from inside and
// out (both faces, the normal turned toward the eye). Clear face on, mirror-like at a grazing angle: a made-up
// reflection of the night (the sky's blue overhead, the city's warm glow along the horizon) in EMISSION, scaled by a
// Fresnel term, as the city's windows do (city_building.gdshader). Thin dark mullions every `pane_w` round the vault
// (UV.x metres round it) and transoms every `pane_h` along it (UV.y). Drawn after the sea (render_priority), and no
// depth write, so what is behind it shows. Vertices are not moved: the glass stands clear of everything.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.30, 0.55, 0.62);
uniform float base_alpha = 0.13;
uniform float edge_alpha = 0.72;
uniform vec3 sky_top : source_color = vec3(0.03, 0.05, 0.12);
uniform vec3 sky_glow : source_color = vec3(0.55, 0.38, 0.32);
uniform float refl = 1.25;
uniform float pane_w = 2.2;
uniform float pane_h = 3.0;

float stripe(float d, float w, float aa) {
	aa = max(aa, 1e-4);
	float cov = clamp((w * 0.5 - abs(d)) / aa + 0.5, 0.0, 1.0);
	return mix(cov, clamp(w / (aa * 2.0), 0.0, 1.0), smoothstep(w * 0.6, w * 1.6, aa));
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	// Whichever face this is, the normal faces the eye.
	if (dot(n, v) < 0.0) {
		n = -n;
	}
	float ndv = clamp(abs(dot(n, v)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 4.0);
	// The reflected ray in world space, and a sky for it: dark blue overhead, warm city glow at the horizon.
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-v, n), 0.0)).xyz;
	float up = clamp(r.y, -1.0, 1.0);
	vec3 sky = mix(sky_glow, sky_top, smoothstep(0.0, 0.45, up));
	sky = mix(sky, sky_glow * 0.35, smoothstep(0.0, -0.3, up));
	// Mullions round the vault and transoms along it.
	float fu = max(fwidth(UV.x), 1e-4);
	float fv = max(fwidth(UV.y), 1e-4);
	float mull = stripe((fract(UV.x / pane_w + 0.5) - 0.5) * pane_w, 0.07, fu);
	float tran = stripe((fract(UV.y / pane_h + 0.5) - 0.5) * pane_h, 0.06, fv);
	float frame = max(mull, tran);
	ALBEDO = mix(tint * 0.22, vec3(0.05, 0.05, 0.06), frame);
	ROUGHNESS = mix(0.04, 0.4, frame);
	METALLIC = 0.0;
	SPECULAR = 0.8;
	EMISSION = sky * refl * mix(0.08, 1.0, fres) * (1.0 - frame);
	ALPHA = clamp(mix(base_alpha, edge_alpha, fres) + frame * 0.75, 0.0, 1.0);
	NORMAL = n;
}
