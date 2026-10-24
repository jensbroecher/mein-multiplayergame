shader_type spatial;

// A boost pad's face (BoostPad.gd builds the mesh). On the top (COLOR.r = 1), UV.x runs across the pad
// and UV.y from its back edge (0) to its front (1), the way carts cross it. Chevrons pointing forward
// stream across it, brightest at their leading edge, inside a glowing border. The bevelled rim
// (COLOR.r = 0) is dark trim with a lit groove. `flash` (per pad) lights everything up when a cart
// takes the boost.

instance uniform float flash = 0.0;
uniform vec3 base_colour : source_color = vec3(0.07, 0.08, 0.11);
uniform vec3 glow_colour : source_color = vec3(1.0, 0.62, 0.12);
uniform vec3 trail_colour : source_color = vec3(1.0, 0.25, 0.08);
uniform float chevrons = 3.0;     // on the pad at once
uniform float speed = 1.6;        // chevrons passing per second
uniform float sweep = 0.55;       // how far back the chevrons' arms reach, in pad lengths
uniform float aspect = 1.5376;    // the top's length over its width (BoostPad.gd: 5.72 / 3.72)

void fragment() {
	float top = COLOR.r;
	vec2 uv = UV;
	float x = abs(uv.x - 0.5) * 2.0;
	// Chevron coordinate: constant along a ">" pointing toward the pad's front.
	float c = uv.y + x * sweep / 2.0;
	float ph = fract(c * chevrons - TIME * speed);
	float w = fwidth(c * chevrons) * 1.5;
	// A band whose leading edge is sharp and whose tail fades out behind it.
	float band = smoothstep(0.62 - w, 0.62 + w, ph) * (1.0 - smoothstep(0.92 - w, 0.92 + w, ph));
	float tail = smoothstep(0.25, 0.62, ph) * (1.0 - step(0.62, ph)) * 0.35;
	float lane = (1.0 - smoothstep(0.74 - w, 0.74 + w, x)) * smoothstep(0.05, 0.09, uv.y) * (1.0 - smoothstep(0.91, 0.95, uv.y));
	float lit = band * mix(0.55, 1.0, (ph - 0.62) / 0.3);
	// The border: a lit rectangular frame round the lane, the same width all round, its corners square.
	// (Separate side and end lines overshot each other at the corners.) In half-widths of the top.
	vec2 q = vec2(x, abs(uv.y - 0.5) * 2.0 * aspect);
	float d = max(q.x - 0.88, q.y - (aspect - 0.06));
	float bw = fwidth(d) * 1.2;
	float border = smoothstep(-0.06 - bw, -0.06 + bw, d) * (1.0 - smoothstep(-bw, bw, d));
	vec3 glow = (glow_colour * lit + trail_colour * tail) * lane + glow_colour * border * 0.6;
	vec3 col = mix(base_colour, vec3(0.03, 0.035, 0.05), 1.0 - top);
	// The rim's groove: a thin lit line halfway down the bevel.
	float groove = (1.0 - top) * (1.0 - smoothstep(0.0, 0.12, abs(COLOR.g - 0.5)));
	glow += glow_colour * groove * 0.5;
	ALBEDO = col + glow * 0.35;
	EMISSION = glow * (1.6 + flash * 3.0) + glow_colour * flash * 0.4 * top;
	ROUGHNESS = mix(0.35, 0.55, top);
	METALLIC = mix(0.6, 0.2, top);
}
