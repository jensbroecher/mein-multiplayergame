shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Nyota Stadium's street level: one flat sheet painted with the city around the stadium. Inside
// the precinct (the stadium, its plazas and the lap's streets, which are their own mesh) it is
// square paving; outside, a grid of tarmac streets with kerbs and pavements round the blocks.
// The grid has to match the generator's (STREET_X0, BLOCK_X, ...), which places the buildings.

uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec2 grid_origin = vec2(320.0, 190.0);
uniform vec2 block = vec2(110.0, 95.0);
uniform float street_half = 9.0;
uniform float pavement = 4.5;
// The precinct, as min.xy, max.xy (x, z).
uniform vec4 precinct = vec4(-230.0, -190.0, 320.0, 190.0);
uniform vec4 paving_color : source_color = vec4(0.68, 0.65, 0.60, 1.0);
uniform vec4 pavement_color : source_color = vec4(0.62, 0.60, 0.57, 1.0);
uniform vec4 asphalt_color : source_color = vec4(0.34, 0.34, 0.35, 1.0);
uniform vec4 lot_color : source_color = vec4(0.52, 0.45, 0.38, 1.0);
uniform vec4 far_color : source_color = vec4(0.55, 0.52, 0.48, 1.0);

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 xz = w_pos.xz;
	float cam_d = length(w_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(80.0, 500.0, cam_d);
	vec3 conc = texture(concrete_tex, xz * 0.09).rgb;
	float grime = vnoise(xz * 0.03) * 0.5 + vnoise(xz * 0.11) * 0.25;
	bool in_precinct = xz.x > precinct.x && xz.x < precinct.z && xz.y > precinct.y && xz.y < precinct.w;
	vec3 col;
	float rough = 0.9;
	if (in_precinct) {
		// Plaza: big square slabs with dark joints, each a slightly different shade.
		vec2 cell = floor(xz / 2.5);
		vec2 f = fract(xz / 2.5);
		float joint = 1.0 - smoothstep(0.0, 0.035, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		col = paving_color.rgb * (0.9 + hash21(cell) * 0.16) * (0.85 + conc * 0.3);
		col *= 1.0 - joint * 0.25 * detail;
		col *= 0.92 + grime * 0.14;
	} else {
		// Distance across the nearest street in each direction.
		vec2 rel = xz - grid_origin;
		float dx = abs(rel.x - round(rel.x / block.x) * block.x);
		float dz = abs(rel.y - round(rel.y / block.y) * block.y);
		float d = min(dx, dz);
		if (d < street_half) {
			vec3 asph = texture(asphalt_tex, xz * 0.12).rgb;
			col = asphalt_color.rgb * (0.8 + asph * 0.5) * (0.92 + grime * 0.12);
			// Centre line along each street, dashed.
			bool along_z = dx < dz;
			float lat = along_z ? dx : dz;
			float run = along_z ? xz.y : xz.x;
			float dash = step(0.5, fract(run / 8.0)) * smoothstep(0.18, 0.1, lat);
			// Not across the junctions.
			float junction = step(max(dx, dz), street_half + pavement);
			col = mix(col, vec3(0.85, 0.82, 0.70), dash * (1.0 - junction) * 0.8 * detail);
			rough = 0.85;
		} else if (d < street_half + pavement) {
			// Pavement with a kerb line.
			float kerb = smoothstep(0.35, 0.0, d - street_half);
			col = pavement_color.rgb * (0.85 + conc * 0.3) * (0.92 + grime * 0.1);
			col = mix(col, vec3(0.75, 0.74, 0.70), kerb);
		} else {
			// Inside the blocks, between the buildings: yards, red earth and patches of grass.
			float g = smoothstep(0.55, 0.75, vnoise(xz * 0.05));
			col = mix(lot_color.rgb, vec3(0.32, 0.38, 0.18), g * 0.6) * (0.85 + conc * 0.25);
		}
	}
	float far = smoothstep(600.0, 1600.0, cam_d);
	col = mix(col, far_color.rgb, far);
	ALBEDO = col;
	ROUGHNESS = rough;
}
