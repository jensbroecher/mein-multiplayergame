shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// An item box's glass cube (ItemBox.gd builds the mesh): every face has UV 0..1 and its index in COLOR.r.
// Drawn premultiplied: ALBEDO is the light the glass gives off, ALPHA how much it dims what is behind it,
// so the edges glow without the cube turning milky. Back faces show through, dimmer, which gives the
// hologram its far edges. Each face carries a bright edge with brackets at the corners, faint circuit
// traces with pulses running through them, and a scan band rising through the box.
// `build` (0 -> 1) cuts the cube off under a glowing line sweeping up it as the box appears; `pop`
// (0 -> 1) flashes it and fades it out as it bursts.

instance uniform float phase = 0.0;
instance uniform float pop = 0.0;
instance uniform float build = 1.0;
uniform vec3 glass_colour : source_color = vec3(0.04, 0.55, 1.0);
uniform vec3 edge_colour : source_color = vec3(0.3, 0.88, 1.0);
uniform float fill = 0.05;
uniform float gain = 1.0;          // 1 / the level's exposure (ItemBox.gd)
uniform float half_size = 0.75;
uniform float fade_begin = 200.0;
uniform float fade_end = 330.0;

varying vec3 obj;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Traces in a 5 x 5 grid: a cell carries a trace across, one along, an L-turn or nothing, and some a
// pad. `pulse` is a light that runs through now and then, cell by cell.
float circuit(vec2 uv, float seed, out float pulse) {
	vec2 g = uv * 5.0;
	vec2 c = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(c + seed * 31.7);
	float aa = fwidth(g.x) * 0.75;
	float w = 0.045;
	float across = 1.0 - smoothstep(w - aa, w + aa, abs(f.y));
	float along = 1.0 - smoothstep(w - aa, w + aa, abs(f.x));
	float line = 0.0;
	if (h < 0.26) {
		line = across;
	} else if (h < 0.5) {
		line = along;
	} else if (h < 0.66) {
		line = max(across * step(f.x, w), along * step(-w, f.y));
	} else if (h < 0.8) {
		line = max(across * step(-w, f.x), along * step(f.y, w));
	}
	float rd = length(f);
	float pad = (1.0 - smoothstep(0.12 - aa, 0.12 + aa, rd)) * (smoothstep(0.06 - aa, 0.06 + aa, rd) * 0.6 + 0.4);
	pad *= step(0.55, fract(h * 7.31)) * step(h, 0.8);
	pulse = smoothstep(0.86, 1.0, fract(TIME * 0.3 + h * 0.35 + (c.x + c.y) * 0.07 + phase));
	return max(line, pad);
}

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float cut = mix(-half_size - 0.04, half_size + 0.04, build);
	if (obj.y > cut) {
		discard;
	}
	vec2 uv = UV;
	vec2 e = min(uv, 1.0 - uv);
	float d = min(e.x, e.y);
	float fw = fwidth(d);
	// The edge: a bright core line where two faces meet, a glow falling off inward.
	float edge = 1.0 - smoothstep(0.012, 0.012 + fw * 1.5, d);
	float halo = exp(-d * 24.0) * 0.55 + exp(-d * 7.0) * 0.1;
	// Brackets: the line thickens over the last fifth of each edge into a corner.
	float near_corner = 1.0 - smoothstep(0.17, 0.2, max(e.x, e.y));
	float bracket = (1.0 - smoothstep(0.032, 0.032 + fw * 1.5, d)) * near_corner;
	// A fine line inset round the face.
	float inset = 1.0 - smoothstep(0.003, 0.003 + fw * 1.5, abs(d - 0.075));
	float pulse;
	float trace = circuit(uv, COLOR.r, pulse);
	// Fine detail fades out once a cell is only a few pixels across, before it shimmers.
	float detail = 1.0 - smoothstep(0.1, 0.25, fwidth(uv.x * 5.0));
	float scan = smoothstep(0.9, 1.0, fract(obj.y * 7.0 - TIME * 0.5)) * 0.15;
	float band_y = mix(-half_size - 0.3, half_size + 0.3, fract(TIME * 0.22 + phase));
	float band = exp(-pow((obj.y - band_y) * 7.0, 2.0));
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	vec3 light = mix(edge_colour, vec3(1.0), 0.35) * (edge * 2.0 + bracket * 1.4) + edge_colour * halo * 0.8
			+ glass_colour * (trace * (0.16 + pulse * 1.1) * detail + inset * 0.25 * detail + scan * detail
					+ band * 0.35 + fres * 0.5 + fill);
	float alpha = 0.1 + fres * 0.18 + (edge + bracket) * 0.4;
	float face = FRONT_FACING ? 1.0 : 0.45;
	// The line the cube is built up to as it appears.
	float rising = 1.0 - step(0.999, build);
	light += edge_colour * exp(-(cut - obj.y) * 28.0) * 3.0 * rising;
	// Taken: a flash the instant it bursts, dying away as the glass fades out.
	float flash = step(0.001, pop) * 4.0 * exp(-pop * 9.0);
	float fade = (1.0 - pop) * (1.0 - pop) * (1.0 - smoothstep(fade_begin, fade_end, length(VERTEX)));
	ALBEDO = (light * fade + mix(edge_colour, vec3(1.0), 0.5) * flash * (0.15 + edge + bracket)) * face * gain;
	ALPHA = clamp(alpha * face * fade, 0.0, 1.0);
}
