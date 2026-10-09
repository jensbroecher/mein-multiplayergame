// Weathered granite for Mara Crossing's kopjes. Shared by the boulders (granite_rock.gdshader) and
// the exposed rock of the ground (savanna_ground.gdshader), so the two meet without a seam.
//
// Everything is procedural and in world space: pale grey granite with a pink cast and a fine
// grain of dark mica, soft patches of tone a few metres across, rust staining on the flanks,
// dark streaks where rain runs off down the steep faces, and orange and grey-green lichen on
// the tops. The palette is written in sRGB and converted with gr_lin().

float gr_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float gr_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(gr_hash(i), gr_hash(i + vec3(1, 0, 0)), f.x),
			mix(gr_hash(i + vec3(0, 1, 0)), gr_hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(gr_hash(i + vec3(0, 0, 1)), gr_hash(i + vec3(1, 0, 1)), f.x),
			mix(gr_hash(i + vec3(0, 1, 1)), gr_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Three octaves, roughly 0..0.9.
float gr_fbm(vec3 p) {
	float v = 0.5 * gr_noise(p);
	p = p * 2.07 + vec3(1.7, 9.2, 3.1);
	v += 0.25 * gr_noise(p);
	p = p * 2.03 + vec3(4.3, 0.7, 6.9);
	v += 0.125 * gr_noise(p);
	return v;
}

vec3 gr_lin(vec3 srgb) {
	return pow(srgb, vec3(2.2));
}

// Albedo at world position `wp` with world normal `wn`. `detail` (1 near, 0 far) fades the grain
// so it cannot shimmer in the distance. Also returns the roughness and a bump height in metres
// for gr_bump().
vec3 granite_albedo(vec3 wp, vec3 wn, float detail, out float rough, out float height) {
	float tone = gr_fbm(wp * 0.05);
	float mottle = gr_fbm(wp * 0.23 + 7.3);
	vec3 col = mix(gr_lin(vec3(0.40, 0.39, 0.37)), gr_lin(vec3(0.64, 0.62, 0.58)), smoothstep(0.15, 0.75, tone));
	// Pinker where the feldspar is richer.
	col = mix(col, col * vec3(1.10, 0.96, 0.90), smoothstep(0.4, 0.65, gr_fbm(wp * 0.017 + 21.0)));
	col *= 0.84 + mottle * 0.34;
	// Grain: black mica and white quartz specks, averaged out with distance.
	float g1 = gr_noise(wp * 15.0);
	float g2 = gr_noise(wp * 29.0 + 5.0);
	float grain = smoothstep(0.62, 0.9, g1) * -0.24 + smoothstep(0.6, 0.9, g2) * 0.1;
	col *= 1.0 + grain * detail;
	// Rust: iron staining in soft patches, on the flanks more than the tops.
	float flank = 1.0 - smoothstep(0.55, 0.95, wn.y);
	float rust = smoothstep(0.5, 0.75, gr_fbm(wp * 0.08 + 13.0)) * (0.35 + 0.65 * flank);
	col = mix(col, col * vec3(1.20, 0.90, 0.70), rust * 0.4);
	// Dark streaks where rain runs off: long down the faces, narrow across them, and only on
	// some faces (everywhere, they rib a round boulder like a pumpkin).
	float steep = 1.0 - smoothstep(0.2, 0.7, wn.y);
	float streak = smoothstep(0.45, 0.8, gr_fbm(vec3(wp.x * 0.8, wp.y * 0.05, wp.z * 0.8) + 3.0));
	streak *= smoothstep(0.42, 0.62, gr_fbm(wp * 0.04 + 61.0));
	col *= 1.0 - streak * steep * 0.4;
	// Lichen on the tops: orange crusts and pale grey-green rosettes, in sharp-edged blotches.
	float up = smoothstep(0.3, 0.85, wn.y);
	float l_or = smoothstep(0.6, 0.66, gr_fbm(wp * 0.7 + 41.0));
	float l_gr = smoothstep(0.58, 0.64, gr_fbm(wp * 0.45 + 77.0));
	col = mix(col, gr_lin(vec3(0.78, 0.56, 0.28)) * (0.8 + mottle * 0.4), l_or * up * 0.6);
	col = mix(col, gr_lin(vec3(0.68, 0.68, 0.60)) * (0.85 + mottle * 0.3), l_gr * (0.2 + 0.8 * up) * 0.35);
	rough = 0.74 + l_gr * 0.14 + l_or * 0.1 - streak * steep * 0.08;
	height = gr_fbm(wp * 0.7) * 0.22 + (g1 * 0.012 + l_or * 0.01) * detail;
	return col;
}

// Bumps a view-space normal by the screen-space slope of `h` (metres), Mikkelsen's surface
// gradient method: no tangents needed, so it works on any mesh and on the ground alike.
vec3 gr_bump(vec3 n_view, vec3 pos_view, float h, float strength) {
	vec3 dpdx = dFdx(pos_view);
	vec3 dpdy = dFdy(pos_view);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n_view);
	vec3 r2 = cross(n_view, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n_view - strength * grad);
}
