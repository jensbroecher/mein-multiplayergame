shader_type spatial;
render_mode cull_back, fog_disabled, diffuse_lambert, specular_disabled;

// The volcano on Mara Crossing's skyline. It stands several kilometres out, past where the depth
// fog would wash it to a flat sheet, so it opts out of fog and fades into the horizon haze here:
// strongly at the foot, less toward the snowcap, the way a big mountain looks through dusty air.
// Vertex colour carries the rock/snow colour; COLOR.a is the snow weight.

uniform vec4 haze_color : source_color = vec4(0.90, 0.76, 0.58, 1.0);
uniform float haze_base = 0.62;
uniform float haze_top = 0.22;
uniform float peak_height = 1200.0;

varying float h01;

void vertex() {
	h01 = clamp(VERTEX.y / peak_height, 0.0, 1.0);
}

void fragment() {
	// The generator's palette is sRGB.
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float haze = mix(haze_base, haze_top, smoothstep(0.0, 0.9, h01));
	ALBEDO = mix(c, haze_color.rgb, haze);
	ROUGHNESS = 1.0;
	// Haze is lit air: keep the far side from going black in shadow.
	EMISSION = haze_color.rgb * haze * 0.35;
}
