shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Glacier ice for Northlight Caverns: the cavern shell, the seracs, the ice arches and the
// frozen lake.
//
// cull_disabled is a requirement, not a shortcut. The cavern shell is a single swept arch
// whose faces all have to be seen from inside the passage, and the ice arches are open rings;
// authoring every face's winding so both sides come out correct is the kind of thing that
// silently produces one invisible side. Normals are authored inward for the shell and from the
// solid's own centre elsewhere, so lighting is right either way.
//
// An earlier revision of this read as slime rather than ice, and the causes are worth recording
// because each is individually a plausible-looking choice:
//   - the veins were emerald and glowed, so the whole surface carried a green cast;
//   - a constant teal emission was added "so the cavern never goes black", which turned every
//     face into a self-lit green one regardless of the light hitting it;
//   - fracture planes were DARKENED, as if they were dirt;
//   - dark rock was mixed in as "silt suspended in the ice", which is exactly the muddy organic
//     read we were trying to avoid.
// Ice is none of those. Its colour is almost entirely depth - a thin edge is nearly white and
// only thick, shadowed ice goes blue - and what is suspended in it is white air, not dark rock.

uniform sampler2D ice_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 ice_color : source_color = vec4(0.74, 0.87, 0.96, 1.0);
uniform vec4 deep_color : source_color = vec4(0.16, 0.36, 0.58, 1.0);
uniform vec4 frosted_color : source_color = vec4(0.92, 0.96, 1.00, 1.0);
uniform vec4 bubble_color : source_color = vec4(0.88, 0.95, 1.00, 1.0);
// Internal fractures scatter light rather than absorb it, so they read as bright threads in the
// ice. Anything saturated here is what turns a glacier into an aquarium.
uniform vec4 vein_color : source_color = vec4(0.70, 0.90, 1.00, 1.0);
uniform vec4 aurora_tint : source_color = vec4(0.30, 0.48, 0.72, 1.0);

uniform float ice_scale : hint_range(0.005, 2.0) = 0.10;
uniform float normal_strength : hint_range(0.0, 4.0) = 0.28;
uniform float vein_density : hint_range(0.0, 2.0) = 0.30;
uniform float vein_glow : hint_range(0.0, 8.0) = 0.35;
uniform float frost_line : hint_range(-80.0, 400.0) = 40.0;
uniform float bubble_density : hint_range(0.0, 2.0) = 0.55;
uniform float roughness : hint_range(0.0, 1.0) = 0.16;
uniform float frost_roughness : hint_range(0.0, 1.0) = 0.72;
uniform float depth_power : hint_range(0.0, 4.0) = 1.0;
// Annual layers: thin, slightly wavy bands of bluer ice across every face that isn't frosted over.
// They are what tells a block of glacier ice from a lump of glass. Off by default.
uniform float strata_strength : hint_range(0.0, 1.0) = 0.0;
uniform float strata_spacing : hint_range(0.2, 8.0) = 1.6;

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
	float fres = pow(1.0 - clamp(dot(n, view), 0.0, 1.0), 4.0);

	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(70.0, 460.0, dist);

	// --- Thickness, which is where ice gets its colour ------------------------------------
	// A thin edge or an exposed face is almost white; only mass in shadow carries the blue.
	// Keying the colour to facing and cavity rather than to a fixed tint is the whole difference
	// between "ice" and "blue plastic".
	float cavity = 1.0 - smoothstep(0.0, 1.0, n.y * 0.5 + 0.5);
	float strata = fbm(vec2(w_pos.y * 0.22, (w_pos.x + w_pos.z) * 0.011));
	float band = 0.5 + 0.5 * sin(w_pos.y * 0.34 + strata * 5.0);
	float thickness = clamp(cavity * 0.75 + strata * 0.25 + band * 0.15, 0.0, 1.0);
	thickness = pow(thickness, depth_power);

	// --- Internal structure ---------------------------------------------------------------
	// Fractures scatter, so they lighten. Dark ridged lines are what read as grime.
	float f1 = pow(ridge(w_pos.xz * ice_scale * 3.1 + vec2(0.0, w_pos.y * 0.05)), 7.0);
	float f2 = pow(ridge(w_pos.xy * ice_scale * 1.7 + 21.0), 9.0);
	float fracture = clamp(f1 + f2 * 0.8, 0.0, 1.0) * detail;

	// --- Air bubbles ---------------------------------------------------------------------
	// What is actually suspended in glacier ice is air, and it is white. Sparse, irregular, and
	// gathered in bands where the ice froze fastest.
	float band_gate = smoothstep(0.35, 0.75, fbm(vec2(w_pos.y * 0.09, (w_pos.x + w_pos.z) * 0.02)));
	float bubbles = smoothstep(0.62, 0.80, fbm(w_pos.xz * ice_scale * 9.0 + w_pos.y * 0.31)) * band_gate;
	bubbles *= bubble_density * detail;

	// --- Frost ----------------------------------------------------------------------------
	// Rime collects on anything that faces up or catches the wind. The matte white against the
	// glassy blue is the contrast that makes ice legible at a distance.
	float up_mask = smoothstep(0.10, 0.70, n.y);
	float altitude = 1.0 - smoothstep(frost_line - 30.0, frost_line + 60.0, w_pos.y);
	float frost = clamp(up_mask * (0.30 + altitude * 0.60) + (fbm(w_pos.xz * 0.06) - 0.5) * 0.55, 0.0, 1.0);
	frost = smoothstep(0.28, 0.82, frost);

	// --- Albedo ---------------------------------------------------------------------------
	vec3 ice = mix(ice_color.rgb, deep_color.rgb, thickness * 0.85);
	// Grazing angles show more of whatever is behind the surface, so the rim goes deeper and
	// brighter at once rather than picking up a hue.
	ice = mix(ice, deep_color.rgb * 1.15, fres * 0.35);
	ice = mix(ice, bubble_color.rgb, bubbles * 0.55);
	ice = mix(ice, vein_color.rgb, fracture * 0.40);

	if (strata_strength > 0.0) {
		float wave = (fbm(w_pos.xz * 0.045) - 0.5) * 3.0 + (fbm(w_pos.xz * 0.21 + 3.0) - 0.5) * 0.6;
		float phase = fract((w_pos.y + wave) / strata_spacing);
		float layer = smoothstep(0.80, 0.90, phase) * (1.0 - smoothstep(0.92, 1.0, phase));
		float faint = smoothstep(0.35, 0.42, phase) * (1.0 - smoothstep(0.44, 0.50, phase)) * 0.45;
		ice = mix(ice, deep_color.rgb * 0.85, (layer + faint) * strata_strength * detail);
	}

	vec3 albedo = mix(ice, frosted_color.rgb, frost * 0.9);

	ALBEDO = albedo;
	ROUGHNESS = clamp(mix(roughness, frost_roughness, frost) + bubbles * 0.10, 0.02, 1.0);
	METALLIC = 0.0;
	// Ice is glassy: a strong, tight highlight is most of what says "ice" rather than "stone".
	SPECULAR = mix(0.62, 0.16, frost);

	NORMAL_MAP = triplanar(ice_normal, w_pos, n, ice_scale * 0.55).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (0.35 + 0.65 * detail) * clamp(1.0 - fwidth(w_pos.x) * 0.02 - fwidth(w_pos.z) * 0.02, 0.1, 1.0);

	// --- Emission -------------------------------------------------------------------------
	// Barely there. The cavern's light comes from its lamps; this only stops the deepest
	// crevices going to pure black, and it is cool and very weak so it cannot tint the ice.
	float pulse = 0.80 + 0.20 * sin(TIME * 0.5 + w_pos.z * 0.05 + w_pos.x * 0.03);
	EMISSION = vein_color.rgb * vein_glow * pulse * fracture * vein_density;
	EMISSION += aurora_tint.rgb * 0.045 * thickness;
}