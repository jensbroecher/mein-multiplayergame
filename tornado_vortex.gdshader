shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// tornado_vortex.gdshader: desert twister / vortex shader.
// Blends rich canyon terracotta at the base into warm sunlit sand aloft,
// with sculpted helical vertex fluting, sharp swirling dust ribbons,
// fresnel edge glow, and serpentine trunk sway.

uniform vec4 base_dust_color : source_color = vec4(0.78, 0.40, 0.22, 0.94);
uniform vec4 mid_dust_color : source_color = vec4(0.88, 0.58, 0.34, 0.86);
uniform vec4 top_dust_color : source_color = vec4(0.80, 0.72, 0.65, 0.75);

uniform float wind_spiral_speed = 1.4;
uniform float wind_rise_speed = 2.4;
uniform float spiral_strands = 5.0;
uniform float flute_displacement = 1.6;
uniform float sway_speed = 2.0;
uniform float sway_amount = 0.32;
uniform float fresnel_power = 1.4;
uniform float overall_alpha = 0.82;

varying float v_norm_height;
varying vec3 v_local_pos;
varying float v_flute;

void vertex() {
	// Mesh Y ranges from 0.0 at ground touchdown to ~35.5m at anvil crown
	v_norm_height = clamp(VERTEX.y / 35.5, 0.0, 1.0);
	
	// Dynamic serpentine trunk sway: tip stays grounded, upper funnel weaves
	float sway = pow(v_norm_height, 1.35) * (sway_amount * 3.6);
	float phase = TIME * sway_speed + v_norm_height * 3.4;
	VERTEX.x += sin(phase) * sway;
	VERTEX.z += cos(phase * 0.82 + 1.15) * sway;
	
	// 3D Helical spiral fluting: physically carves twisting ridges into the silhouette
	vec2 xz = VERTEX.xz;
	float len = length(xz);
	if (len > 0.1) {
		vec2 dir = xz / len;
		float angle = atan(xz.y, xz.x);
		float flute_phase = angle * spiral_strands - v_norm_height * 15.0 + TIME * wind_rise_speed * 4.5;
		float wave1 = sin(flute_phase);
		float wave2 = cos(angle * 3.0 + v_norm_height * 8.0 - TIME * wind_spiral_speed * 3.0);
		v_flute = wave1 * 0.75 + wave2 * 0.25;
		
		// Flute expands with height: tight at ground, broad in funnel.
		// radial_fade prevents star-pinching at the exact apex pole (len < 2.5m).
		float radial_fade = smoothstep(1.5, 5.0, len);
		float scale = flute_displacement * (0.35 + 1.65 * pow(v_norm_height, 1.25)) * radial_fade;
		VERTEX.x += dir.x * v_flute * scale;
		VERTEX.z += dir.y * v_flute * scale;
	} else {
		v_flute = 0.0;
	}
	
	// Subtle breathing pulsation
	float breath = sin(TIME * 2.8 + v_norm_height * 4.5) * 0.015 * v_norm_height;
	VERTEX.x += VERTEX.x * breath;
	VERTEX.z += VERTEX.z * breath;
	
	v_local_pos = VERTEX;
}

void fragment() {
	// Cylindrical angle for spiral ribbons
	float angle = atan(v_local_pos.z, v_local_pos.x);
	float spiral_p1 = angle * spiral_strands + v_norm_height * 18.0 - TIME * wind_rise_speed * 5.5;
	float spiral_p2 = angle * (spiral_strands * 1.6) - v_norm_height * 12.0 - TIME * wind_spiral_speed * 4.0;
	
	// Distinct, roping dust strands using power curves
	float strand1 = pow(clamp(0.5 + 0.5 * sin(spiral_p1), 0.0, 1.0), 1.8);
	float strand2 = pow(clamp(0.5 + 0.5 * cos(spiral_p2), 0.0, 1.0), 2.2);
	float bands = clamp(strand1 * 0.75 + strand2 * 0.45, 0.0, 1.0);
	
	// Animated micro-noise for turbulent sand grit
	vec2 uv_anim = UV;
	uv_anim.y -= TIME * wind_rise_speed * 0.28;
	uv_anim.x += TIME * wind_spiral_speed * 0.38;
	float noise = sin(uv_anim.x * 32.0 + uv_anim.y * 18.0) * cos(uv_anim.x * 16.0 - uv_anim.y * 24.0);
	
	// Warm desert color gradient along column: terracotta red -> warm amber -> sunlit dust
	vec3 dust_col = mix(base_dust_color.rgb, mid_dust_color.rgb, smoothstep(0.01, 0.40, v_norm_height));
	dust_col = mix(dust_col, top_dust_color.rgb, smoothstep(0.40, 0.95, v_norm_height));
	
	// Strong ribbon contrast: bright sunlit highlights on ridges, rich terracotta in valleys
	vec3 ribbon_highlight = dust_col * 1.35 + vec3(0.12, 0.08, 0.03);
	vec3 ribbon_shadow = dust_col * 0.62;
	dust_col = mix(ribbon_shadow, ribbon_highlight, bands);
	dust_col += vec3(0.06, 0.04, 0.02) * noise;
	
	// Sunlit Fresnel rim glow (gives edge luminosity)
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	dust_col += vec3(0.22, 0.16, 0.08) * fresnel;
	
	// Volumetric alpha: dense in dust ribbons, semi-transparent in troughs
	float density = clamp(0.42 + 0.50 * bands + 0.16 * noise, 0.0, 1.0);
	float height_alpha = mix(base_dust_color.a, top_dust_color.a, v_norm_height);
	float alpha = overall_alpha * density * height_alpha;
	alpha = mix(alpha * 0.72, alpha * 1.25, fresnel);
	// Soften touchdown tip so it blends cleanly into the ground contact dust
	alpha *= smoothstep(0.005, 0.05, v_norm_height);
	
	ALBEDO = dust_col;
	ALPHA = clamp(alpha, 0.0, 0.96);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
