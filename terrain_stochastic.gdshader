shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float uv_scale = 40.0;
uniform vec2 uv_scale_v2 = vec2(1.0, 1.0);
uniform float smoothness : hint_range(0.0, 1.0) = 1.0;
uniform bool use_world_uv = false;

uniform bool use_normal_map = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

uniform bool enable_edge_fade = false;
uniform float edge_fade_start = 550.0;
uniform float edge_fade_end = 960.0;
uniform vec4 edge_fade_color : source_color = vec4(0.65, 0.75, 0.85, 1.0);

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Robust integer hash that never suffers from float trigonometry precision loss
vec2 hash2(vec2 p) {
	uvec2 u = uvec2(ivec2(floor(p)));
	u = u * 1664525u + 1013904223u;
	u.x += u.y * 1664525u;
	u.y += u.x * 1664525u;
	u = u ^ (u >> 16u);
	u.x += u.y * 1664525u;
	u.y += u.x * 1664525u;
	u = u ^ (u >> 16u);
	return vec2(u) * (1.0 / 4294967295.0);
}

// Convert grid vertex (in skewed grid coordinates) back to UV space
vec2 grid_to_uv(vec2 v) {
	vec2 v_grid = vec2(v.x + v.y * 0.5, v.y * 0.8660254);
	return v_grid * 0.28867513;
}

// Rotate UV relative to grid vertex so large world coordinates don't blow up
void rotated_grad(vec2 vertex_id, vec2 uv, vec2 ddx_uv, vec2 ddy_uv, out vec2 tuv, out vec2 tdx, out vec2 tdy) {
	vec2 r = hash2(vertex_id);
	float a = r.x * 6.2831853;
	float c = cos(a);
	float s = sin(a);
	vec2 v_uv = grid_to_uv(vertex_id);
	vec2 local_uv = uv - v_uv;
	tuv = vec2(c * local_uv.x - s * local_uv.y, s * local_uv.x + c * local_uv.y) + r;
	tdx = vec2(c * ddx_uv.x - s * ddx_uv.y, s * ddx_uv.x + c * ddx_uv.y) * 1.08;
	tdy = vec2(c * ddy_uv.x - s * ddy_uv.y, s * ddy_uv.x + c * ddy_uv.y) * 1.08;
}

void triangle_grid(vec2 uv, out vec2 v1, out vec2 v2, out vec2 v3, out vec3 w) {
	uv *= 3.4641016;
	vec2 skewed = vec2(uv.x - uv.y * 0.57735027, uv.y * 1.15470054);
	vec2 base_id = floor(skewed);
	vec2 f = fract(skewed);
	float z = 1.0 - f.x - f.y;
	if (z > 0.0) {
		w = vec3(z, f.y, f.x);
		v1 = base_id;
		v2 = base_id + vec2(0.0, 1.0);
		v3 = base_id + vec2(1.0, 0.0);
	} else {
		w = vec3(-z, 1.0 - f.y, 1.0 - f.x);
		v1 = base_id + vec2(1.0, 1.0);
		v2 = base_id + vec2(1.0, 0.0);
		v3 = base_id + vec2(0.0, 1.0);
	}
	w = smoothstep(vec3(0.0), vec3(1.0), w);
	w /= max(w.x + w.y + w.z, 1e-5);
}

vec3 stochastic_sample(sampler2D tex, vec2 uv, vec2 ddx_uv, vec2 ddy_uv) {
	vec2 v1;
	vec2 v2;
	vec2 v3;
	vec3 w;
	triangle_grid(uv, v1, v2, v3, w);
	w /= max(w.x + w.y + w.z, 1e-5);

	vec2 tuv;
	vec2 tdx;
	vec2 tdy;
	rotated_grad(v1, uv, ddx_uv, ddy_uv, tuv, tdx, tdy);
	vec3 c1 = textureGrad(tex, tuv, tdx, tdy).rgb;
	rotated_grad(v2, uv, ddx_uv, ddy_uv, tuv, tdx, tdy);
	vec3 c2 = textureGrad(tex, tuv, tdx, tdy).rgb;
	rotated_grad(v3, uv, ddx_uv, ddy_uv, tuv, tdx, tdy);
	vec3 c3 = textureGrad(tex, tuv, tdx, tdy).rgb;
	return c1 * w.x + c2 * w.y + c3 * w.z;
}

vec3 stochastic_sample_normal(sampler2D tex, vec2 uv, vec2 ddx_uv, vec2 ddy_uv) {
	vec2 v1;
	vec2 v2;
	vec2 v3;
	vec3 w;
	triangle_grid(uv, v1, v2, v3, w);
	w /= max(w.x + w.y + w.z, 1e-5);

	vec2 tuv;
	vec2 tdx;
	vec2 tdy;
	vec2 r;
	float a;
	float c;
	float s;
	vec3 n = vec3(0.0);

	rotated_grad(v1, uv, ddx_uv, ddy_uv, tuv, tdx, tdy);
	r = hash2(v1);
	a = r.x * 6.2831853;
	c = cos(a);
	s = sin(a);
	vec3 n1 = textureGrad(tex, tuv, tdx, tdy).rgb * 2.0 - 1.0;
	n += vec3(c * n1.x - s * n1.y, s * n1.x + c * n1.y, n1.z) * w.x;

	rotated_grad(v2, uv, ddx_uv, ddy_uv, tuv, tdx, tdy);
	r = hash2(v2);
	a = r.x * 6.2831853;
	c = cos(a);
	s = sin(a);
	vec3 n2 = textureGrad(tex, tuv, tdx, tdy).rgb * 2.0 - 1.0;
	n += vec3(c * n2.x - s * n2.y, s * n2.x + c * n2.y, n2.z) * w.y;

	rotated_grad(v3, uv, ddx_uv, ddy_uv, tuv, tdx, tdy);
	r = hash2(v3);
	a = r.x * 6.2831853;
	c = cos(a);
	s = sin(a);
	vec3 n3 = textureGrad(tex, tuv, tdx, tdy).rgb * 2.0 - 1.0;
	n += vec3(c * n3.x - s * n3.y, s * n3.x + c * n3.y, n3.z) * w.z;

	return normalize(n) * 0.5 + 0.5;
}

void fragment() {
	vec3 geom_nrm = normalize(world_nrm);
	vec3 n_abs = abs(geom_nrm);
	vec3 n_weight = pow(n_abs, vec3(4.0));
	n_weight /= max(n_weight.x + n_weight.y + n_weight.z, 0.0001);

	vec2 scale_v = (uv_scale * 0.1) * uv_scale_v2;

	vec3 color;
	if (use_world_uv) {
		vec2 uv_bx = vec2(world_pos.z, -world_pos.y) * scale_v;
		vec2 uv_by = world_pos.xz * scale_v;
		vec2 uv_bz = vec2(-world_pos.x, -world_pos.y) * scale_v;
		vec3 col_x = stochastic_sample(albedo_texture, uv_bx, dFdx(uv_bx), dFdy(uv_bx));
		vec3 col_y = stochastic_sample(albedo_texture, uv_by, dFdx(uv_by), dFdy(uv_by));
		vec3 col_z = stochastic_sample(albedo_texture, uv_bz, dFdx(uv_bz), dFdy(uv_bz));
		color = (col_x * n_weight.x + col_y * n_weight.y + col_z * n_weight.z) * albedo.rgb;
	} else {
		vec2 uv = UV * scale_v;
		color = stochastic_sample(albedo_texture, uv, dFdx(uv), dFdy(uv)) * albedo.rgb;
	}

	float rough = smoothness;
	if (enable_edge_fade) {
		float d_xz = length(world_pos.xz);
		float fade_t = clamp((d_xz - edge_fade_start) / max(edge_fade_end - edge_fade_start, 0.001), 0.0, 1.0);
		fade_t = fade_t * fade_t * (3.0 - 2.0 * fade_t);
		color = mix(color, edge_fade_color.rgb, fade_t);
		rough = mix(smoothness, 0.98, fade_t);
	}

	ALBEDO = color;
	ROUGHNESS = rough;
	SPECULAR = 0.05;
	METALLIC = 0.0;

	if (use_normal_map) {
		if (use_world_uv) {
			vec2 uv_bx = vec2(world_pos.z, -world_pos.y) * scale_v;
			vec2 uv_by = world_pos.xz * scale_v;
			vec2 uv_bz = vec2(-world_pos.x, -world_pos.y) * scale_v;
			vec3 n_x = stochastic_sample_normal(normal_texture, uv_bx, dFdx(uv_bx), dFdy(uv_bx));
			vec3 n_y = stochastic_sample_normal(normal_texture, uv_by, dFdx(uv_by), dFdy(uv_by));
			vec3 n_z = stochastic_sample_normal(normal_texture, uv_bz, dFdx(uv_bz), dFdy(uv_bz));
			NORMAL_MAP = n_x * n_weight.x + n_y * n_weight.y + n_z * n_weight.z;
		} else {
			vec2 uv = UV * scale_v;
			NORMAL_MAP = stochastic_sample_normal(normal_texture, uv, dFdx(uv), dFdy(uv));
		}
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
