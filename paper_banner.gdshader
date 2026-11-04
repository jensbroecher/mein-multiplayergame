// The paper run-through banner (PaperBanner.gd): its sheet and the scraps torn out of it.
// UV is the place on the whole sheet (u across, v down from the top), so a scrap keeps its piece of the
// artwork. UV2 is the place inside the cell (0..1 each way) and COLOR says which of the cell's edges are
// torn (r left, g right, b top, a bottom): a torn edge shows the white paper fibres under the print.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D art : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// The sheet's size in metres, for the paper's grain and the flutter.
uniform vec2 sheet_size = vec2(17.0, 6.6);
uniform float flutter_amp = 0.07;
// 1 on the hanging sheet (pinned at its top and sides), 0 on a scrap.
instance uniform float flutter = 1.0;
// A scrap curls: its corners bend out of its plane by this much per square metre from its middle.
instance uniform float curl = 0.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	if (flutter > 0.0) {
		// Pinned along the top bar and both posts; the free bottom edge moves most.
		float pin = sin(PI * clamp(UV.x, 0.0, 1.0)) * smoothstep(0.0, 0.8, UV.y);
		float w = sin(TIME * 2.3 + UV.x * 9.0) + 0.6 * sin(TIME * 3.7 - UV.y * 7.0 + UV.x * 4.0);
		VERTEX.z += flutter * flutter_amp * pin * w;
	}
	VERTEX.z += curl * dot(VERTEX.xy, VERTEX.xy);
}

void fragment() {
	vec2 uv = UV;
	// Printed on both sides, each reading the right way round.
	if (!FRONT_FACING) {
		uv.x = 1.0 - uv.x;
	}
	vec3 col = texture(art, uv).rgb;
	vec2 m = UV * sheet_size;
	float grain = vnoise(m * 38.0) * 0.6 + vnoise(m * 9.0) * 0.4;
	col *= 0.92 + 0.08 * grain;
	// Torn edges: a ragged band of bare paper.
	float e = 1.0;
	if (COLOR.r > 0.5) { e = min(e, UV2.x); }
	if (COLOR.g > 0.5) { e = min(e, 1.0 - UV2.x); }
	if (COLOR.b > 0.5) { e = min(e, UV2.y); }
	if (COLOR.a > 0.5) { e = min(e, 1.0 - UV2.y); }
	float band = 0.05 + 0.09 * vnoise(m * 26.0);
	if (e < band) {
		col = vec3(0.90, 0.89, 0.84) * (0.92 + 0.08 * grain);
	}
	ALBEDO = col;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
	// Thin paper: the sun shows through it.
	BACKLIGHT = col * 0.35;
}
