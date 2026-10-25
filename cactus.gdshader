shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The Canyon Course's cacti (CactusKit.gd, which documents the vertex data): the ribs shaded round
// between their ridges and dark in their valleys, felt areoles along the ridges with spines from each,
// a corky foot on old saguaros, glochid dots on prickly pear pads, the cholla's coat of pale spines
// glowing against the light, leaves and furrows on woody stems. Each plant's colour differs a little
// (from its position). Spines finer than a pixel turn into the sheen they give the ridges from afar.

uniform float rib_round = 0.6;
uniform vec4 dust : source_color = vec4(0.70, 0.54, 0.42, 1.0);

varying vec3 base_col;
varying vec4 info;
varying float plant_rand;
varying float plant_rand2;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Per species: x areole spacing, y areole radius, z spine length (metres), w how much of the surface
// the spines cover seen from afar.
vec4 spine_geo(float sp) {
	if (sp < 0.5) return vec4(0.045, 0.006, 0.035, 0.1);
	if (sp < 1.5) return vec4(0.05, 0.006, 0.03, 0.22);
	if (sp < 2.5) return vec4(0.07, 0.012, 0.1, 0.62);
	if (sp < 3.5) return vec4(0.06, 0.008, 0.012, 0.12);
	if (sp < 4.5) return vec4(0.034, 0.006, 0.04, 0.8);
	if (sp < 5.5) return vec4(0.03, 0.005, 0.026, 0.55);
	return vec4(0.05, 0.004, 0.006, 0.0);
}

vec3 spine_color(float sp) {
	if (sp < 0.5) return vec3(0.40, 0.36, 0.32);
	if (sp < 1.5) return vec3(0.12, 0.11, 0.10);
	if (sp < 2.5) return vec3(0.66, 0.24, 0.10);
	if (sp < 3.5) return vec3(0.62, 0.50, 0.22);
	if (sp < 4.5) return vec3(0.80, 0.74, 0.50);
	if (sp < 5.5) return vec3(0.78, 0.74, 0.66);
	return vec3(0.3);
}

void vertex() {
	base_col = pow(COLOR.rgb, vec3(2.2));
	info = CUSTOM0;
	vec3 org = MODEL_MATRIX[3].xyz;
	plant_rand = h21(org.xz * 0.37);
	plant_rand2 = h21(org.xz * 0.71 + 17.3);
	// Ocotillo whips sway in the wind, the more toward their tips.
	if (info.x > 5.5 && info.y > 1.5) {
		float tip = info.z * info.z;
		VERTEX.x += sin(TIME * 1.3 + org.x * 0.2 + VERTEX.y * 0.4) * tip * 0.1;
		VERTEX.z += cos(TIME * 1.1 + org.z * 0.2 + VERTEX.y * 0.3) * tip * 0.07;
	}
}

void fragment() {
	float sp = floor(info.x + 0.5);
	float part = floor(info.y + 0.5);
	vec3 col = base_col;
	float rough = 0.5;
	float spec = 0.4;
	vec3 emit = vec3(0.0);
	float aa = max(fwidth(UV.y), 0.0004);
	if (part < 0.5) {
		// Each plant a little different: greener or greyer, some yellowed by drought.
		col *= mix(0.86, 1.12, plant_rand);
		col = mix(col, col * vec3(1.1, 1.02, 0.72), plant_rand2 * plant_rand2 * 0.7);
		vec4 g = spine_geo(sp);
		vec3 scol = spine_color(sp);
		float d;
		float ridge;
		float seq;
		if (sp > 2.5 && sp < 3.5) {
			// A pad: areoles in offset rows over both faces, the rim flushed red in some plants.
			vec2 q = UV / g.x;
			q.x += 0.5 * mod(floor(q.y), 2.0);
			vec2 cell = fract(q) - 0.5;
			d = length(cell) * g.x;
			ridge = 1.0;
			seq = h21(floor(q));
			col = mix(col, col * vec3(1.25, 0.72, 0.95), smoothstep(0.8, 1.0, info.w) * plant_rand2 * 0.8);
			col *= 0.94 + 0.12 * vnoise(UV * 18.0);
		} else {
			// Ribs: round between the ridges, dark down in the valleys.
			float f = fract(UV.x);
			float c = cos(f * TAU);
			NORMAL_MAP = vec3(0.5 + 0.5 * rib_round * sin(f * TAU), 0.5, 1.0);
			col *= mix(0.62, 1.06, smoothstep(-1.0, 1.0, c));
			ridge = smoothstep(0.2, 1.0, c);
			float around_m = (UV.x - floor(UV.x + 0.5)) * info.w;
			float k = floor(UV.y / g.x + 0.5);
			float al = UV.y - k * g.x;
			d = length(vec2(around_m, al));
			seq = h21(vec2(floor(UV.x + 0.5), k));
			// Faint growth bands across the stem, and scuffs.
			col *= 0.95 + 0.08 * vnoise(vec2(UV.x * 0.5, UV.y * 1.7));
		}
		// The areole, and a few spines radiating from it.
		float areole = 1.0 - smoothstep(g.y - aa, g.y + aa, d);
		float spines = (1.0 - smoothstep(g.y, g.z, d)) * step(g.y * 0.7, d) * smoothstep(0.5, 0.95, seq * 0.4 + 0.6 * vnoise(vec2(d * 400.0, seq * 50.0)));
		// Up close the spines one by one; from afar the sheen they give the ridges.
		float near_w = 1.0 - smoothstep(g.y * 0.4, g.y * 1.6, aa);
		float sheen = g.w * ridge;
		col = mix(col, scol, mix(sheen, clamp(areole * 0.9 + spines * 0.8, 0.0, 1.0), near_w));
		if (sp < 0.5) {
			// An old saguaro's foot turns corky grey-brown.
			float cork = smoothstep(0.075, 0.02, info.z + (vnoise(UV * vec2(3.0, 4.0)) - 0.5) * 0.03);
			col = mix(col, vec3(0.20, 0.16, 0.13) * (0.8 + 0.4 * vnoise(UV * 12.0)), cork);
		}
		if (sp > 3.5 && sp < 4.5) {
			// The cholla's spines catch the light round its edges.
			float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
			emit += scol * rim * 0.22;
		}
		rough = 0.48;
		spec = 0.42;
	} else if (part < 1.5) {
		// Flowers and fruit.
		col *= 0.9 + 0.2 * plant_rand;
		rough = 0.7;
		spec = 0.3;
	} else {
		// Wood: furrowed bark; an ocotillo in leaf carries small leaves all along its whips.
		col *= 0.8 + 0.3 * vnoise(vec2(UV.x * 3.0, UV.y * 6.0));
		col *= 0.85 + 0.15 * smoothstep(0.2, 0.8, fract(UV.x * 2.0 + vnoise(UV * vec2(1.0, 0.5)) * 0.6));
		if (sp > 5.5) {
			float leafy = smoothstep(0.35, 0.65, plant_rand);
			float leaves = smoothstep(0.55, 0.75, vnoise(vec2(UV.x * 6.0, UV.y * 22.0))) * leafy;
			col = mix(col, vec3(0.10, 0.17, 0.05), leaves * 0.85);
		}
		rough = 0.85;
		spec = 0.25;
	}
	// Dust splashed up round the foot.
	col = mix(col, dust.rgb, (1.0 - smoothstep(0.0, 0.1, info.z)) * 0.35);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
}
