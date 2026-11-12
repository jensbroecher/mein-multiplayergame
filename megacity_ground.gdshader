shader_type spatial;
render_mode cull_back, diffuse_burley;

// Tianqiao's street level (the terrain's own material, set by regenerate_tianqiao.gd): a grid of streets in world
// space (`grid_origin`, each cell `block` metres with a `street`-wide street along its low x and low z edges), lane
// markings, pavements round the blocks with a street light's pool every 28m, the ground under the buildings, and the
// park's lawns inside `park` (x0, z0, x1, z1). At night: the light pools are the ground's only light besides the city.

uniform vec2 grid_origin = vec2(0.0);
uniform vec2 block = vec2(120.0, 100.0);
uniform float street = 22.0;
uniform float pavement = 5.0;
uniform vec4 park = vec4(0.0);
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float lamp_energy = 1.4;
// Shuangjiang: ground under `shore_y` is a river's shore (gravel and mud, wetter toward the water, no streets), and with
// `slope_grass` steep ground is grass and rock. The defaults leave the other stages as they were.
uniform float shore_y = -1000.0;
uniform float slope_grass = 0.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = w_pos.xz - grid_origin;
	vec2 q = mod(p, block);
	float st_x = step(q.y, street);
	float st_z = step(q.x, street);
	float on_street = max(st_x, st_z);
	float pave = 0.0;
	if (on_street < 0.5) {
		vec2 in_block = q - vec2(street);
		vec2 size = block - vec2(street);
		float d_edge = min(min(in_block.x, in_block.y), min(size.x - in_block.x, size.y - in_block.y));
		pave = step(d_edge, pavement);
	}
	vec3 asphalt = texture(asphalt_tex, w_pos.xz / 6.0).rgb * 0.35;
	vec3 tiles = texture(concrete_tex, w_pos.xz / 3.0).rgb * 0.55;
	vec3 lot = texture(concrete_tex, w_pos.xz / 9.0).rgb * 0.28;
	vec3 col = mix(lot, tiles, pave);
	col = mix(col, asphalt, on_street);
	// Lane lines: a dashed white centre line and stop lines' worth of zebra at the crossings.
	float cx = abs(q.y - street * 0.5);
	float cz = abs(q.x - street * 0.5);
	float dash_x = step(cx, 0.15) * step(0.5, fract(p.x / 9.0)) * st_x * (1.0 - st_z);
	float dash_z = step(cz, 0.15) * step(0.5, fract(p.y / 9.0)) * st_z * (1.0 - st_x);
	float zebra = st_x * st_z * step(0.5, fract((q.x + q.y) / 1.6)) * step(street * 0.15, min(q.x, q.y));
	col = mix(col, vec3(0.75), clamp(dash_x + dash_z, 0.0, 1.0) * 0.8);
	col = mix(col, vec3(0.6), zebra * 0.5);
	// The park's lawns and paths.
	float in_park = step(park.x, w_pos.x) * step(w_pos.x, park.z) * step(park.y, w_pos.z) * step(w_pos.z, park.w);
	vec3 grass = texture(grass_tex, w_pos.xz / 4.0).rgb * 0.5;
	col = mix(col, grass, in_park);
	// The shore and the slopes.
	float shore = 1.0 - smoothstep(shore_y - 0.6, shore_y, w_pos.y);
	vec3 gravel = texture(concrete_tex, w_pos.xz / 2.5).rgb * vec3(0.5, 0.46, 0.4);
	vec3 mud = texture(asphalt_tex, w_pos.xz / 4.0).rgb * vec3(0.32, 0.28, 0.22);
	vec3 shore_col = mix(mud, gravel, smoothstep(0.6, 2.2, w_pos.y));
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float steep = slope_grass * (1.0 - smoothstep(0.72, 0.86, wn.y)) * smoothstep(shore_y, shore_y + 1.0, w_pos.y);
	vec3 bank = mix(grass * 0.85, texture(concrete_tex, w_pos.xz / 5.0).rgb * vec3(0.42, 0.4, 0.36), smoothstep(0.55, 0.4, wn.y));
	col = mix(col, shore_col, shore);
	col = mix(col, bank, steep);
	in_park = max(in_park, max(shore, steep));
	// Street lights: warm pools along the pavements' street edge every 28m.
	vec2 lp = vec2(mod(p.x, 28.0) - 14.0, mod(p.y, 28.0) - 14.0);
	float near_edge = (1.0 - on_street) * (1.0 - in_park);
	float pool = exp(-dot(lp, lp) / 60.0) * pave;
	vec3 emi = vec3(1.0, 0.78, 0.5) * pool * lamp_energy * 0.25 + vec3(1.0, 0.8, 0.55) * on_street * 0.015;
	ALBEDO = col;
	EMISSION = (emi * near_edge + emi * on_street) * (1.0 - max(shore, steep));
	ROUGHNESS = mix(mix(0.85, 0.55, on_street), mix(0.95, 0.6, 1.0 - smoothstep(0.3, 1.2, w_pos.y)), max(shore, steep));
}
