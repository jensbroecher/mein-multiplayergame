shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Pinecrest Ridge's asphalt, which gives out toward the forest trail (TerrainGenerator.road_gaps)
// instead of narrowing to a clean point: over the gap's taper and `lead` metres before it the
// surface cracks, dirt washes over it and pieces break away (discarded, showing the trail's ground
// a few centimetres below), most at the edges. Leaving a gap, the tyres carry dirt onto the road
// along their two lines.
// The road mesh's UV is (0..road_width across, metres along the lap), the same offsets road_gaps
// takes. Away from the gaps it is the plain asphalt the level had (StandardMaterial: texture tiled
// every 1 / uv_scale metres, tint, roughness).

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 0.2;
uniform vec3 tint : source_color = vec3(0.92);
uniform float roughness = 0.75;
// Matches the terrain's trail dirt (terrain_grass_varied.gdshader).
uniform vec3 dirt_tint : source_color = vec3(0.80, 0.70, 0.58);
uniform float dirt_tile = 6.0;

uniform vec2 gaps[4];
uniform int gap_count = 0;
uniform float taper = 14.0;
uniform float lead = 10.0;
uniform float road_width = 15.0;
// How far the tyres carry the dirt out of a gap, and their lines' lateral offsets from the middle.
uniform float carry = 26.0;
uniform float rut_offset = 1.8;

varying vec3 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.03 + 7.1) * 0.3 + vnoise(p * 4.1 + 2.3) * 0.2;
}

// Distance to the nearest crack of a cell pattern (cells about `size` metres).
float cracks(vec2 p, float size) {
	vec2 q = p / size;
	vec2 i = floor(q);
	vec2 f = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 19.7));
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return (d2 - d1) * size;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 asphalt = texture(asphalt_tex, UV * uv_scale).rgb * tint;
	float s = UV.y;
	// How far the asphalt has given out (0 sound, 1 at the gap), and the dirt carried out of a gap.
	float wear = 0.0;
	float carried = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= gap_count) {
			break;
		}
		vec2 g = gaps[i];
		float d = max(g.x - s, s - g.y);
		wear = max(wear, 1.0 - clamp(d / (taper + lead), 0.0, 1.0));
		if (s > g.y) {
			carried = max(carried, exp(-(s - g.y) / carry));
		}
	}
	if (wear <= 0.0 && carried < 0.02) {
		ALBEDO = asphalt;
		ROUGHNESS = roughness;
	} else {
		// 0 at either edge of what is left of the road, 1 down its middle.
		float mid = 1.0 - abs(UV.x / road_width * 2.0 - 1.0);
		float n = fbm(world_pos.xz * 0.55) * 0.75 + fbm(world_pos.xz * 2.7 + 11.0) * 0.25;
		// The noise sits round 0.5: from a few holes a third of the way in to most of it gone at the gap.
		float eaten = 0.06 + 0.64 * wear + (1.0 - mid) * 0.3 * wear;
		float v = n - (1.0 - eaten);
		if (v > 0.0) {
			discard;
		}
		vec3 dirt = texture(dirt_tex, world_pos.xz / dirt_tile).rgb * dirt_tint;
		// Dirt drifted over the asphalt round the broken edges, and a film of it all over near the gap.
		float film = smoothstep(-0.22, 0.0, v) + wear * 0.45 * smoothstep(0.35, 0.75, fbm(world_pos.xz * 0.9 + 4.0));
		// Along the tyres' two lines out of the gap.
		float lat = UV.x - road_width * 0.5;
		float line = max(1.0 - smoothstep(0.25, 0.9, abs(abs(lat) - rut_offset)), 0.0);
		film = max(film, carried * line * (0.55 + 0.45 * vnoise(world_pos.xz * 3.0)));
		film = clamp(film, 0.0, 1.0);
		float crack = 1.0 - smoothstep(0.0, 0.035 + 0.04 * wear, cracks(world_pos.xz, 1.6));
		vec3 col = asphalt * (1.0 - crack * smoothstep(0.05, 0.4, wear) * 0.55);
		col = mix(col, dirt, film);
		ALBEDO = col;
		ROUGHNESS = mix(roughness, 0.95, film);
		vec3 dn = texture(dirt_normal, world_pos.xz / dirt_tile).rgb;
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), dn, film);
		NORMAL_MAP_DEPTH = 1.0;
	}
}
