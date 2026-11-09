shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// A football goal's net (GoalNet.gd): white cords in a square mesh, drawn by discarding between them. UV is the cords'
// place in metres across the face, UV2.x how far the point may move (0 where the net is tied to the frame).
// The pokes are where something presses the net: poke_pos.xyz the point (the node's frame), .w the bulge's radius;
// poke_vec.xyz the bulge (its direction times how far). The vertices move by the sum of gaussians round them.
// The cords shrink under a pixel at a distance: there their coverage is kept by a stable screen-space dither instead
// of the line test, so the net fades to a light veil rather than shimmering.

uniform vec4 poke_pos[4];
uniform vec4 poke_vec[4];
uniform vec4 cord_color : source_color = vec4(0.93, 0.93, 0.91, 1.0);
// The mesh's cell (m) and a cord's width (m), at the game's scale.
uniform float cell = 0.19;
uniform float cord = 0.022;

void vertex() {
	float w = UV2.x;
	vec3 d = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec3 q = VERTEX - poke_pos[i].xyz;
		float r = poke_pos[i].w;
		d += poke_vec[i].xyz * exp(-dot(q, q) / (r * r));
	}
	// A little sag under its own weight, more in the middle of a face.
	d.y -= 0.05 * w;
	VERTEX += d * w;
}

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 g = UV / cell;
	vec2 fw = max(fwidth(g), vec2(1e-4));
	vec2 f = abs(fract(g) - 0.5);
	// Box-filtered coverage of the two sets of cords.
	// At least about a pixel wide, so a cord never breaks into dashes as it thins.
	vec2 hw = max(vec2(0.5 * cord / cell), fw * 0.45);
	vec2 cov2 = clamp((f - (0.5 - hw)) / fw + 0.5, 0.0, 1.0);
	float cov = max(cov2.x, cov2.y);
	// Far off, the average share of cords instead (about 2 * hw), dithered.
	float far = smoothstep(0.42, 0.75, max(fw.x, fw.y));
	float mean = 2.0 * (cord / cell) * 1.4;
	cov = mix(cov, mean, far);
	if (cov < 0.5 * (1.0 - far) + ign(FRAGCOORD.xy) * far) {
		discard;
	}
	ALBEDO = cord_color.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
