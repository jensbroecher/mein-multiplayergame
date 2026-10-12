shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Nyota Stadium's sponsor boards and signs. ads_tex is an atlas of ATLAS_COLS x ATLAS_ROWS
// adverts that StadiumAds.gd draws when the level loads. Each panel's UV spans 0..1 over its face;
// COLOR.r carries which advert (index / 64), COLOR.g whether it is an LED board that cycles
// through the adverts (1) or a printed sign that keeps its own (0).

uniform sampler2D ads_tex : source_color, filter_linear_mipmap_anisotropic;
const float ATLAS_COLS = 2.0;
const float ATLAS_ROWS = 8.0;
const float AD_COUNT = 16.0;
uniform float cycle_seconds = 9.0;
uniform float led_energy = 0.55;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

vec3 ad_at(float idx, vec2 uv) {
	idx = mod(idx, AD_COUNT);
	vec2 cell = vec2(mod(idx, ATLAS_COLS), floor(idx / ATLAS_COLS));
	vec2 a = (cell + vec2(clamp(uv.x, 0.004, 0.996), clamp(1.0 - uv.y, 0.01, 0.99))) / vec2(ATLAS_COLS, ATLAS_ROWS);
	return texture(ads_tex, a).rgb;
}

void fragment() {
	float idx = floor(vcol.r * 64.0 + 0.5);
	bool led = vcol.g > 0.5;
	vec3 col;
	if (led) {
		// Every board flips to the next advert together, with a wipe across each panel.
		float t = TIME / cycle_seconds;
		float k = floor(t);
		float f = fract(t);
		float wipe = smoothstep(0.0, 0.08, f) ;
		float edge = step(UV.x, wipe);
		vec3 a = ad_at(idx + k - 1.0, UV);
		vec3 b = ad_at(idx + k, UV);
		col = mix(a, b, edge);
		// LED pixel grid, visible close up.
		vec2 px = fract(UV * vec2(384.0, 48.0));
		float grid = smoothstep(0.0, 0.25, px.x) * smoothstep(0.0, 0.25, px.y);
		col *= mix(1.0, 0.75 + 0.25 * grid, 1.0 - smoothstep(10.0, 40.0, length(VERTEX)));
		ALBEDO = col * 0.35;
		EMISSION = col * led_energy;
		ROUGHNESS = 0.35;
	} else {
		col = ad_at(idx, UV);
		ALBEDO = col;
		ROUGHNESS = 0.7;
	}
}
