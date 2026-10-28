shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// tornado_vortex.gdshader: multi-shell volumetric desert twister / vortex shader.
// Uses three nested shells (COLOR.r: 0.0 = dense inner core, 0.5 = mid vortex wall,
// 1.0 = outer billowing dust mantle) with seamless 3D FBM turbulence, roping helical
// dust bands, directional sunlight + storm-anvil self-shadowing, an opaque heart so
// background sky never bleeds through, and noise-feathered gaseous silhouettes.

uniform vec4 base_dust_color : source_color = vec4(0.62, 0.35, 0.20, 0.98);
uniform vec4 mid_dust_color : source_color = vec4(0.76, 0.48, 0.29, 0.94);
uniform vec4 top_dust_color : source_color = vec4(0.72, 0.54, 0.39, 0.90);

uniform float wind_spiral_speed = 1.45;
uniform float wind_rise_speed = 2.3;
uniform float spiral_strands = 5.0;
uniform float flute_displacement = 1.35;
uniform float sway_speed = 2.0;
uniform float sway_amount = 0.30;
uniform float fresnel_power = 1.4;
uniform float overall_alpha = 0.92;

varying float v_norm_height;
varying vec3 v_rel_pos;
varying vec3 v_world_normal;
varying float v_flute;
varying float v_shell;

// Fast 3D hash and value noise for seamless volumetric dust billows
float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			mix(hash31(i + vec3(0.0, 0.0, 0.0)), hash31(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), f.x),
			f.y
		),
		mix(
			mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), f.x),
			f.y
		),
		f.z
	);
}

float fbm3(vec3 p) {
	float v = 0.533 * noise3(p);
	p = p * 2.07 + vec3(17.3, 9.1, 13.7);
	v += 0.267 * noise3(p);
	p = p * 2.11 + vec3(5.9, 23.4, 11.2);
	v += 0.200 * noise3(p);
	return v;
}

void vertex() {
	v_shell = COLOR.r;
	// Mesh Y ranges from 0.0 at ground touchdown to ~35.5m at anvil crown
	v_norm_height = clamp(VERTEX.y / 35.5, 0.0, 1.0);

	// 3D Helical spiral fluting around the un-swayed axis first so shells stay concentric
	vec2 xz = VERTEX.xz;
	float len = length(xz);
	if (len > 0.08) {
		vec2 dir = xz / len;
		float angle = atan(xz.y, xz.x);
		float shell_phase = v_shell * 2.2;
		float shell_speed = 1.0 + (1.0 - v_shell) * 0.25;
		float flute_phase = angle * spiral_strands - v_norm_height * 14.5 + TIME * wind_rise_speed * 4.2 * shell_speed + shell_phase;
		float wave1 = sin(flute_phase);
		float wave2 = cos(angle * 3.0 + v_norm_height * 8.5 - TIME * wind_spiral_speed * 3.1 - shell_phase);
		v_flute = wave1 * 0.72 + wave2 * 0.28;

		// Inner core flutes modestly so it never pokes through outer shells
		float shell_flute = mix(0.42, 1.0, v_shell);
		float radial_fade = smoothstep(0.6, 3.8, len) * (1.0 - smoothstep(0.84, 0.98, v_norm_height));
		float scale = flute_displacement * shell_flute * (0.30 + 1.35 * pow(v_norm_height, 1.2)) * radial_fade;
		xz += dir * v_flute * scale;
	} else {
		v_flute = 0.0;
	}

	// Subtle breathing pulsation
	float breath = sin(TIME * 2.6 + v_norm_height * 4.2 + v_shell * 1.5) * 0.02 * v_norm_height;
	xz *= (1.0 + breath);

	// Store position relative to vortex centerline before serpentine sway
	v_rel_pos = vec3(xz.x, VERTEX.y, xz.y);

	// Coherent serpentine trunk sway: applied identically to all shells so core stays inside mantle
	float sway = pow(v_norm_height, 1.35) * (sway_amount * 3.5);
	float phase = TIME * sway_speed + v_norm_height * 3.3;
	vec2 sway_xz = vec2(sin(phase), cos(phase * 0.82 + 1.15)) * sway;

	VERTEX.xz = xz + sway_xz;
	v_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// Seamless cylindrical coordinates around the vortex axis
	float angle = atan(v_rel_pos.z, v_rel_pos.x);
	float shell_rate = 1.0 + (1.0 - v_shell) * 0.30;
	float twist_ang = angle + v_norm_height * 9.5 - TIME * wind_spiral_speed * 2.1 * shell_rate + v_shell * 3.7;

	// 3D helical coordinates for seamless FBM turbulence (periodic in angle)
	vec3 p_turb = vec3(
		cos(twist_ang) * 2.4 + sin(v_norm_height * 6.0) * 0.5,
		sin(twist_ang) * 2.4 + cos(v_norm_height * 6.0) * 0.5,
		v_norm_height * 8.5 - TIME * wind_rise_speed * 1.85 + v_shell * 4.3
	);
	float turb = fbm3(p_turb);
	float grit_noise = fbm3(p_turb * 3.1 + vec3(11.4, -TIME * wind_spiral_speed * 2.5, 7.8));

	// Domain-warped helical dust ribbons
	float warped_angle = angle + (turb - 0.5) * 1.25;
	float spiral_p1 = warped_angle * spiral_strands + v_norm_height * 16.5 - TIME * wind_rise_speed * 5.0 * shell_rate + v_shell * 2.3;
	float spiral_p2 = warped_angle * (spiral_strands * 1.6) - v_norm_height * 11.5 - TIME * wind_spiral_speed * 3.8 + v_shell * 4.1;
	float spiral_p3 = warped_angle * 3.0 + v_norm_height * 7.0 - TIME * wind_rise_speed * 3.2;

	float strand1 = pow(clamp(0.5 + 0.5 * sin(spiral_p1), 0.0, 1.0), 1.45);
	float strand2 = pow(clamp(0.5 + 0.5 * cos(spiral_p2), 0.0, 1.0), 1.85);
	float strand3 = 0.5 + 0.5 * sin(spiral_p3);
	float bands = clamp(strand1 * 0.55 + strand2 * 0.35 + strand3 * 0.22 + (turb - 0.5) * 0.35, 0.0, 1.0);

	// Warm canyon dirt -> ochre sienna -> dusty storm-sand gradient along column
	vec3 dust_col = mix(base_dust_color.rgb, mid_dust_color.rgb, smoothstep(0.02, 0.45, v_norm_height));
	dust_col = mix(dust_col, top_dust_color.rgb, smoothstep(0.45, 0.92, v_norm_height));

	// Directional sun shading + storm cloud shelf self-shadowing
	vec3 sun_dir = normalize(vec3(0.58, 0.64, 0.50));
	float sun_wrap = clamp(dot(v_world_normal, sun_dir) * 0.5 + 0.5, 0.0, 1.0);
	// Undersides of the flaring funnel & upper anvil shelves are shadowed like heavy storm clouds
	float under_shade = mix(0.52, 1.04, smoothstep(-0.65, 0.45, v_world_normal.y));
	// Ground kick-up darkening at the very foot
	float base_soil = mix(0.74, 1.0, smoothstep(0.0, 0.16, v_norm_height));

	// Ribbon & billow sculpting: deep canyon umber in troughs, warm sunlit ochre on crests
	float relief = clamp(bands * 0.65 + (v_flute * 0.5 + 0.5) * 0.35, 0.0, 1.0);
	vec3 shadow_col = dust_col * 0.46;
	vec3 lit_col = dust_col * 1.24 + vec3(0.10, 0.06, 0.02);
	dust_col = mix(shadow_col, lit_col, relief);

	// Apply directional sun wrap, under-shelf shadow, fine sand grit, and deeper core tone
	float sun_factor = mix(0.68, 1.18, smoothstep(0.15, 0.90, sun_wrap));
	float core_tone = mix(0.84, 1.0, v_shell);
	dust_col *= sun_factor * under_shade * base_soil * core_tone;
	dust_col += (grit_noise - 0.5) * vec3(0.11, 0.07, 0.04);

	// Volumetric opacity: SOLID in the center (ndotv -> 1), soft & billowing at grazing edges (ndotv -> 0)
	float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float alpha = 0.0;

	if (v_shell < 0.25) {
		// Inner Core: dense, opaque heart with a broad soft edge so its boundary never shows inside the mantle
		float core_edge = pow(smoothstep(0.08, 0.65, ndotv + (turb - 0.5) * 0.28), 1.15);
		float core_density = clamp(0.96 + 0.06 * bands, 0.0, 1.0);
		alpha = core_density * core_edge;
	} else if (v_shell < 0.75) {
		// Middle Vortex Wall: thick swirling helical bands bridging core and mantle seamlessly
		float mid_edge = smoothstep(0.08, 0.56, ndotv + (turb - 0.5) * 0.34);
		float mid_density = clamp(0.76 + 0.28 * bands + 0.18 * (grit_noise - 0.45), 0.0, 1.0);
		alpha = overall_alpha * mid_density * mid_edge * (1.0 - smoothstep(0.86, 0.99, v_norm_height) * 0.35);
	} else {
		// Outer Dust Mantle: sculpted roping ribbons and billowing cloud edges
		float outer_edge = smoothstep(0.10, 0.64, ndotv + (turb - 0.5) * 0.44);
		float outer_density = clamp(0.52 + 0.50 * bands + 0.24 * (turb - 0.42), 0.0, 1.0);
		alpha = overall_alpha * outer_density * outer_edge * (1.0 - smoothstep(0.84, 0.98, v_norm_height) * 0.55);
	}

	// Blend foot raggedly into the ground dust plume and soften apex cap
	alpha *= smoothstep(0.012, 0.095, v_norm_height + (turb - 0.5) * 0.04);
	alpha *= 1.0 - smoothstep(0.92, 1.0, v_norm_height) * 0.55;

	ALBEDO = clamp(dust_col, vec3(0.0), vec3(1.0));
	ALPHA = clamp(alpha, 0.0, 0.98);
}
