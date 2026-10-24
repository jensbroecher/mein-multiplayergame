shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// An item box's glass as a sphere (ItemBox.gd, SHELL = SPHERE; the cube is item_box_glass.gdshader): a
// holographic globe. UV is longitude (x, 0..1 round) and latitude (y, 0 at the bottom). Drawn
// premultiplied like the cube: ALBEDO is the light it gives off, ALPHA how much it dims what's behind
// it. A bright rim where the globe turns away from the eye, faint latitude and longitude lines, the
// cube's circuit traces with pulses running through them, and a scan band rising through it. Back faces
// show through, dimmer. `build` (0 -> 1) cuts it off under a glowing line sweeping up it as the box
// appears; `pop` (0 -> 1) flashes it and fades it out as it bursts.

instance uniform float phase = 0.0;
instance uniform float pop = 0.0;
instance uniform float build = 1.0;
uniform vec3 glass_colour : source_color = vec3(0.04, 0.55, 1.0);
uniform vec3 edge_colour : source_color = vec3(0.3, 0.88, 1.0);
uniform float fill = 0.05;
uniform float gain = 1.0;          // 1 / the level's exposure (ItemBox.gd)
uniform float radius = 0.92;
uniform float fade_begin = 200.0;
uniform float fade_end = 330.0;

varying vec3 obj;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The cube's traces (item_box_glass.gdshader): a 5 x 5 grid per unit of `uv`.
float circuit(vec2 uv, out float pulse) {
	vec2 g = uv * 5.0;
	vec2 c = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(c);
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
	pulse = smoothstep(0.86, 1.0, fract(TIME * 0.3 + h * 0.35 + (c.x + c.y) * 0.07 + phase));
	return line;
}

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float cut = mix(-radius - 0.04, radius + 0.04, build);
	if (obj.y > cut) {
		discard;
	}
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - facing, 2.5);
	// The rim: a bright core line round the silhouette, a glow falling off inward.
	float rim = smoothstep(0.55, 0.95, fres);
	// Latitude and longitude lines: 8 bands up, 16 round.
	vec2 g = vec2(UV.x * 16.0, UV.y * 8.0);
	vec2 gd = abs(fract(g) - 0.5);
	vec2 gw = fwidth(g) * 1.2;
	float grid = max(smoothstep(0.5 - gw.x * 1.5, 0.5, gd.x), smoothstep(0.5 - gw.y * 1.5, 0.5, gd.y));
	// The equator a little brighter.
	float equator = 1.0 - smoothstep(0.0, fwidth(UV.y) * 2.0, abs(UV.y - 0.5));
	float pulse;
	float trace = circuit(UV * vec2(2.4, 1.2), pulse);
	// Fine detail fades out once a cell is only a few pixels across, before it shimmers.
	float detail = 1.0 - smoothstep(0.1, 0.25, fwidth(UV.x * 12.0));
	float scan = smoothstep(0.9, 1.0, fract(obj.y * 7.0 - TIME * 0.5)) * 0.15;
	float band_y = mix(-radius - 0.3, radius + 0.3, fract(TIME * 0.22 + phase));
	float band = exp(-pow((obj.y - band_y) * 7.0, 2.0));
	vec3 light = mix(edge_colour, vec3(1.0), 0.35) * rim * 1.6 + edge_colour * fres * 0.6
			+ edge_colour * (grid * 0.3 + equator * 0.5) * detail
			+ glass_colour * (trace * (0.14 + pulse * 1.1) * detail + scan * detail + band * 0.35 + fill);
	float alpha = 0.08 + fres * 0.3 + rim * 0.3 + grid * 0.06 * detail;
	float face = FRONT_FACING ? 1.0 : 0.45;
	// The line it's built up to as it appears.
	float rising = 1.0 - step(0.999, build);
	light += edge_colour * exp(-(cut - obj.y) * 28.0) * 3.0 * rising;
	// Taken: a flash the instant it bursts, dying away as the glass fades out.
	float flash = step(0.001, pop) * 4.0 * exp(-pop * 9.0);
	float fade = (1.0 - pop) * (1.0 - pop) * (1.0 - smoothstep(fade_begin, fade_end, length(VERTEX)));
	ALBEDO = (light * fade + mix(edge_colour, vec3(1.0), 0.5) * flash * (0.15 + rim)) * face * gain;
	ALPHA = clamp(alpha * face * fade, 0.0, 1.0);
}
