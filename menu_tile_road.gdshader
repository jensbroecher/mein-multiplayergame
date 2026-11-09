// The menu tiles' road (MenuTileStage.gd): a straight asphalt road along z with edge lines, a dashed centre
// line and red-and-white kerbs, mown grass beyond, all in world metres. `scroll` (metres) slides the pattern
// toward -z, so cars standing still on it drive along +z. Set from the script, never TIME, so a still shot holds.
shader_type spatial;
render_mode cull_disabled;

uniform float scroll = 0.0;
uniform float road_half = 8.0;
uniform float kerb_w = 1.0;
uniform vec3 asphalt : source_color = vec3(0.16, 0.165, 0.18);
uniform vec3 grass_a : source_color = vec3(0.17, 0.31, 0.10);
uniform vec3 grass_b : source_color = vec3(0.21, 0.36, 0.12);
uniform vec3 kerb_red : source_color = vec3(0.78, 0.08, 0.06);
// 0 a plain road, 1 a start line across it at z = start_z (VS race), 2 a chequered grid box.
uniform float start_z = 1e6;

varying vec3 w_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Box-filtered coverage of [a, b] at x, the filter `w` wide: lines fade to their share instead of shimmering.
float band(float x, float a, float b, float w) {
	w = max(w, 1e-4);
	return clamp((min(x + w * 0.5, b) - max(x - w * 0.5, a)) / w, 0.0, 1.0);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(w_pos.x, w_pos.z + scroll);
	vec2 fw = fwidth(p);
	float ax = abs(p.x);
	float rough = 0.85;
	vec3 col;
	if (ax < road_half + kerb_w + 0.4) {
		float n = vnoise(p * 3.1) * 0.5 + vnoise(p * 0.37) * 0.5;
		col = asphalt * (0.86 + 0.28 * n);
		// A darker rubbered line either side of the middle.
		col *= 1.0 - 0.18 * exp(-pow((ax - road_half * 0.45) / (road_half * 0.18), 2.0));
		float white = band(ax, road_half - 0.55, road_half - 0.3, fw.x);
		float dash = band(fract(p.y / 9.0), 0.0, 0.45, fw.y / 9.0);
		white = max(white, band(ax, 0.0, 0.13, fw.x) * dash);
		if (abs(w_pos.z - start_z) < 6.0) {
			// The grid's chequered start line across the road.
			float cz = w_pos.z - start_z;
			if (abs(cz) < 0.9 && ax < road_half - 0.3) {
				float ch = mod(floor(p.x / 0.6) + floor(cz / 0.6), 2.0);
				col = mix(vec3(0.03), vec3(0.92), ch);
				white = 0.0;
			}
		}
		col = mix(col, vec3(0.88), white * 0.9);
		rough = 0.78;
		if (ax > road_half) {
			// Kerb: red and white blocks with a dark seam, a touch of camber shading.
			float k = step(0.5, fract(p.y / 3.0));
			col = mix(kerb_red, vec3(0.9), k);
			col *= 0.82 + 0.18 * smoothstep(road_half + kerb_w, road_half, ax);
			col = mix(col, vec3(0.08), band(fract(p.y / 1.5), 0.0, 0.04, fw.y / 1.5) * 0.6);
			rough = 0.6;
		}
	} else {
		// Mown grass: bands across the road's direction, tufts, a worn verge by the kerb.
		float stripe = band(fract(p.y / 14.0), 0.0, 0.5, fw.y / 14.0);
		col = mix(grass_a, grass_b, stripe);
		float n = vnoise(p * 1.7) * 0.6 + vnoise(p * 8.0) * 0.4;
		col *= 0.8 + 0.35 * n;
		col = mix(col, vec3(0.38, 0.33, 0.24), smoothstep(road_half + kerb_w + 1.6, road_half + kerb_w + 0.4, ax) * 0.45);
		rough = 0.95;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
