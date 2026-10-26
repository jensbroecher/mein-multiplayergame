shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

// Bloombay Dunes surf.
//
// The generator bakes a shore field (shore_tex, one texel per terrain vertex):
//   R  ground height under the water (the visual terrain)
//   G  travel time in seconds for a wave from here to the waterline (eikonal solve with the shallow
//      water speed sqrt(g*depth)), so crests bend round the bay and close up as the water shoals
//   B  surf weight: 1 on the ocean side, 0 inland (dune ponds stay flat)
//   A  the shallowest depth seaward of here along the row (a wave that broke on the sandbar leaves
//      foam behind it in the trough)
// West of the field the travel time grows at the deep water speed; elsewhere edge texels repeat.
//
// Waves are numbered by phase: theta = (TIME + travel_time) / period, so every crest reaches the
// waterline at a whole number. Within a wave u = fract(theta) runs from its shoreward foot (0) up the
// front face to the crest (front_w) and down the long back (1). A wave steepens as the water shoals,
// breaks where it gets taller than ~0.78 of the depth, runs in as a foaming bore, and its swash runs
// up the sand, drains back and leaves the sand wet.

uniform sampler2D shore_tex : filter_linear, repeat_disable;
uniform vec2 shore_origin = vec2(-330.0, -475.0);
uniform float shore_step = 2.2619;
uniform vec2 shore_size = vec2(149.0, 421.0);

uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform float period = 7.5;
uniform float c_deep = 8.0;
uniform float swell_height = 1.15;      // crest to trough in deep water
uniform float oblique = 0.0024;         // phase per metre along the beach: the breakers peel north
uniform float breaker_ratio = 0.78;     // height/depth at which a wave breaks
uniform float runup = 0.42;             // swash height above sea level for an average wave

uniform vec3 deep_color : source_color = vec3(0.02, 0.16, 0.30);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.62, 0.62);
uniform vec3 absorption = vec3(0.42, 0.12, 0.085);
uniform vec3 foam_color : source_color = vec3(0.96, 0.97, 0.96);
uniform vec3 crest_glow : source_color = vec3(0.18, 0.75, 0.66);
uniform vec3 wet_sand_tint = vec3(0.66, 0.58, 0.48);

varying vec3 v_world;

float hash11(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

vec4 shore_at(vec2 p) {
	// East of the field (the dunes and their ponds) is calm water with no beach under it.
	if (p.x > shore_origin.x + (shore_size.x - 1.0) * shore_step) {
		return vec4(-50.0, 0.0, 0.0, 50.0);
	}
	vec2 uv = ((p - shore_origin) / shore_step + 0.5) / shore_size;
	vec4 s = textureLod(shore_tex, uv, 0.0);
	s.g += max(shore_origin.x - p.x, 0.0) / c_deep;
	return s;
}

// Height of wave number n (relative to the mean swell): sets of bigger waves, and each wave a little
// bigger or smaller along the beach.
float wave_scale(float n, float z) {
	float sets = 0.80 + 0.30 * sin(n * 0.83) + 0.18 * (hash11(n) - 0.5);
	float along = 0.78 + 0.22 * sin(z * 0.019 + n * 1.7) + 0.12 * sin(z * 0.053 - n * 0.9);
	return sets * along;
}

float profile(float u, float front_w) {
	if (u < front_w) {
		float x = u / front_w;
		return x * x * (3.0 - 2.0 * x);
	}
	float y = (u - front_w) / (1.0 - front_w);
	return pow(1.0 - y, 2.4);
}

struct Surf {
	float height;   // water surface y
	float foam;     // 0..1 foam cover
	float crest;    // 0..1 how near the crest (for the light through the lip)
	float lean;     // metres the crest is thrown shoreward
	float tau;
	float ground;
	float weight;
};

// The open-sea chop: a few short waves crossing the swell, faded out in the surf.
float chop(vec2 p, float t) {
	float h = 0.0;
	h += 0.070 * sin(dot(p, vec2(0.231, 0.094)) - t * 1.42);
	h += 0.050 * sin(dot(p, vec2(0.118, -0.262)) - t * 1.63 + 1.3);
	h += 0.035 * sin(dot(p, vec2(-0.170, 0.390)) - t * 2.05 + 4.1);
	h += 0.022 * sin(dot(p, vec2(0.520, 0.210)) - t * 2.40 + 2.2);
	return h;
}

Surf surf_at(vec2 p, float t) {
	Surf s;
	vec4 f = shore_at(p);
	float g = f.r;
	float w = f.b;
	float depth = max(-g, 0.0);
	s.ground = g;
	s.weight = w;
	s.tau = f.g;

	float theta = (t + f.g) / period + p.y * oblique;
	float n = floor(theta);
	float u = theta - n;

	// Green's law shoaling, then capped by the depth once broken.
	float shoal = clamp(pow(5.0 / max(depth, 0.35), 0.25), 0.9, 1.6);
	float h_mean = swell_height * shoal;
	float h_wave = h_mean * wave_scale(n, p.y);
	float ratio = h_wave / max(depth, 0.02);
	float broken = smoothstep(breaker_ratio * 0.92, breaker_ratio * 1.12, ratio);
	float steep = smoothstep(breaker_ratio * 0.45, breaker_ratio, ratio);
	float h_cap = mix(breaker_ratio, 0.55, broken) * depth + 0.03;
	float h = min(h_wave, h_cap);
	float h_ref = min(h_mean, h_cap);

	float front_w = mix(mix(0.45, 0.14, steep), 0.05, broken);
	float pr = profile(u, front_w);
	// Constant trough within each spot, so wave-to-wave height changes never step the surface.
	s.height = (h * pr - 0.30 * h_ref) * w;
	s.height += chop(p, t) * mix(0.25, 1.0, smoothstep(0.6, 4.0, depth)) * (0.3 + 0.7 * w);

	float at_crest = exp(-pow((u - front_w) / 0.05, 2.0));
	s.crest = at_crest * (1.0 - broken) * steep;
	s.lean = s.crest * h * 0.55 * w;

	// Foam: the white bore and the water churned up behind it, the lip of a wave about to break,
	// and the lace left in the trough behind the sandbar.
	float behind = u >= front_w ? 0.25 + 0.75 * exp(-(u - front_w) * 14.0) : smoothstep(front_w * 0.35, front_w, u);
	behind *= u >= front_w ? exp(-(u - front_w) * 3.0) : 1.0;
	float bore = broken * behind * smoothstep(0.02, 0.12, h);
	float lip = s.crest * 0.55;
	float lace = smoothstep(1.35, 0.95, f.a / max(h_mean, 0.05)) * 0.22 * smoothstep(0.0, 0.25, depth);
	s.foam = clamp(max(max(bore, lip), lace), 0.0, 1.0) * w;
	return s;
}

// Swash at a beach point: the edge of the sheet of water a wave throws up the sand, as a height above
// sea level. It runs up fast, drains back slower and sinks under the next bore.
float swash_edge(float z, float t, out float since_peak, out float reach) {
	float theta = t / period + z * oblique - 0.05;
	float n = floor(theta);
	float x = theta - n;
	reach = runup * wave_scale(n, z) * (0.92 + 0.08 * sin(z * 0.31 + n * 2.3));
	since_peak = (x - 0.26) / 0.62;
	if (x < 0.26) {
		float a = 1.0 - x / 0.26;
		return reach * (1.0 - a * a);
	}
	float b = clamp(since_peak, 0.0, 1.0);
	return mix(reach, -0.12, pow(b, 1.5));
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz;
	float t = TIME;

	Surf s0 = surf_at(p, t);
	float e = 0.6;
	Surf sx = surf_at(p + vec2(e, 0.0), t);
	Surf sz = surf_at(p + vec2(0.0, e), t);

	float y = s0.height;
	// Over the beach the sheet lies on the sand (the fragment cuts its edge); far up the beach it hides
	// under the sand.
	if (s0.ground > -0.6 && s0.weight > 0.0) {
		float since_peak;
		float reach;
		float edge = swash_edge(p.y, t, since_peak, reach);
		float film = s0.ground + 0.035 + clamp((edge - s0.ground) * 0.3, 0.0, 0.08);
		y = max(y, film);
		if (s0.ground > runup * 1.8) {
			y = s0.ground - 1.0;
		}
	}

	// Crest thrown forward, toward lower travel time (the shore).
	vec2 grad = vec2(sx.tau - s0.tau, sz.tau - s0.tau);
	vec2 shoreward = length(grad) > 1e-5 ? -normalize(grad) : vec2(1.0, 0.0);
	world.xz += shoreward * s0.lean;
	world.y = y;

	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	vec3 nrm = normalize(vec3(s0.height - sx.height, e, s0.height - sz.height));
	if (s0.ground > -0.3) {
		nrm = normalize(mix(nrm, vec3(0.0, 1.0, 0.0), smoothstep(-0.3, 0.1, s0.ground)));
	}
	NORMAL = (MODEL_NORMAL_MATRIX * nrm);
	v_world = world;
}

float scene_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 p = v_world.xz;
	float t = TIME;
	Surf s = surf_at(p, t);
	float g = s.ground;
	float view_dist = length(v_world - CAMERA_POSITION_WORLD);

	// Swash and wet sand.
	float since_peak;
	float reach;
	float edge = swash_edge(p.y, t, since_peak, reach);
	float lace_n = texture(foam_tex, p * 0.21).r;
	edge += (lace_n - 0.5) * 0.035;
	float sea_covers = smoothstep(g + 0.005, g + 0.04, s.height);
	float swash_covers = smoothstep(0.0, 0.012, edge - g) * step(-0.6, g);
	float covered = max(sea_covers, swash_covers);
	float wet = 0.0;
	if (covered < 0.999) {
		// Sand the backwash just left is soaked and dries over the rest of the cycle; the band up to
		// the usual run-up stays damp.
		float fresh = smoothstep(reach + 0.02, reach - 0.02, g + (lace_n - 0.5) * 0.04)
				* (1.0 - clamp(since_peak, 0.0, 1.0)) * step(0.0, since_peak);
		float damp = (1.0 - smoothstep(0.0, runup * 0.85, g + (lace_n - 0.5) * 0.06)) * 0.5;
		wet = max(fresh, damp) * step(-0.6, g) * s.weight;
		if (wet < 0.01 && covered < 0.01) {
			discard;
		}
	}

	// Ripples on the swell.
	float ripple_fade = 1.0 - smoothstep(60.0, 260.0, view_dist);
	vec2 r_uv1 = p * 0.085 + vec2(t * 0.020, t * 0.012);
	vec2 r_uv2 = p * 0.140 + vec2(-t * 0.016, t * 0.022);
	vec3 r1 = texture(ripple_tex, r_uv1).xyz * 2.0 - 1.0;
	vec3 r2 = texture(ripple_tex, r_uv2).xyz * 2.0 - 1.0;
	vec3 ripple = vec3(r1.x + r2.x, 0.0, r1.y + r2.y) * 0.22 * ripple_fade;
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz + ripple);
	if (!FRONT_FACING) {
		n_world = -n_world;
	}

	// What lies under the surface, bent a little by the waves, and how much water the light crosses.
	float surf_depth = -VERTEX.z;
	// Clamped inside the frame: past its edge the screen copy holds whatever was drawn there before.
	vec2 px = 1.5 / VIEWPORT_SIZE;
	vec2 refr_uv = clamp(SCREEN_UV + n_world.xz * 0.025 * clamp(surf_depth * 0.02, 0.0, 1.0), px, 1.0 - px);
	float behind = scene_depth(refr_uv, INV_PROJECTION_MATRIX);
	if (behind < surf_depth) {
		refr_uv = clamp(SCREEN_UV, px, 1.0 - px);
		behind = scene_depth(refr_uv, INV_PROJECTION_MATRIX);
	}
	// Still in front of the surface: a pixel along the silhouette of something standing before the
	// water (a pier rail, a palm), where the depth texture and the water's pixels don't line up. Not a
	// contact: take the depth of the sea there, or it drew a white outline of foam round them.
	bool occluded = behind < surf_depth - 0.05;
	float path = occluded ? max(-g, 0.0) * 2.0 : max(behind - surf_depth, 0.0);
	vec3 below = textureLod(screen_tex, refr_uv, 0.0).rgb;
	vec3 transmit = exp(-absorption * path);
	float body_t = 1.0 - exp(-path * 0.22);
	vec3 body = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, body_t));

	vec3 v = normalize(CAMERA_POSITION_WORLD - v_world);
	float fresnel = 0.02 + 0.98 * pow(1.0 - clamp(dot(n_world, v), 0.0, 1.0), 5.0);

	// Foam: a bubbly cellular pattern thresholded by the foam amount, so thin foam reads as lace.
	float pat = texture(foam_tex, p * 0.16 + vec2(0.0, t * 0.01)).r * 0.55 + texture(foam_tex, vec2(p.x * 0.37 + p.y * 0.11, p.y * 0.37 - p.x * 0.11) - vec2(t * 0.015, 0.0)).r * 0.45;
	// Foam gathers in patches and streaks rather than an even sheet.
	float patches = texture(foam_tex, p * vec2(0.035, 0.018)).r;
	pat *= mix(0.7, 1.15, patches);
	// Far off the pattern would alias, so it flattens toward an even grey there.
	pat = mix(pat, 0.55, 0.7 * (1.0 - ripple_fade));
	float foam = smoothstep(1.0 - s.foam, 1.0 - s.foam + 0.22, pat) * covered;
	// Foam round anything standing in the water (piles, rocks, wrecks, carts).
	float contact = occluded ? 0.0 : (1.0 - smoothstep(0.0, 0.35, path)) * step(0.0, -g) * smoothstep(0.1, 0.6, -g);
	foam = max(foam, contact * smoothstep(0.35, 0.65, pat) * 0.8);
	// The frothy line at the swash edge.
	float edge_line = (1.0 - smoothstep(0.0, 0.05, edge - g)) * swash_covers * step(0.0, g) * (1.0 - smoothstep(0.6, 1.0, since_peak));
	foam = max(foam, edge_line * smoothstep(0.25, 0.6, lace_n) * 0.9);

	// Light from the sand below comes through as emission (it is already lit); the water's own colour
	// is albedo so it takes the sun and shadows. Reflection comes from the specular.
	vec3 water_light = below * transmit * (1.0 - fresnel);
	vec3 water_albedo = body * (1.0 - transmit.g) * (1.0 - fresnel);
	float glow = s.crest * 0.6;

	vec3 sand_wet = below * mix(vec3(1.0), wet_sand_tint, wet);

	ALBEDO = mix(water_albedo, foam_color, foam) * covered;
	EMISSION = mix(water_light + crest_glow * glow * 0.35, vec3(0.0), foam) * covered + sand_wet * (1.0 - covered);
	ROUGHNESS = mix(mix(0.14, 0.04, ripple_fade), 0.8, foam) * covered + mix(0.9, 0.45, wet) * (1.0 - covered);
	SPECULAR = mix(0.5, 0.2, foam) * covered + 0.12 * wet * (1.0 - covered);
	METALLIC = 0.0;
	NORMAL = (VIEW_MATRIX * vec4(n_world, 0.0)).xyz;
	if (covered < 0.5) {
		NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	}
	ALPHA = max(covered, smoothstep(0.0, 0.08, wet));
}
