// showroom_sky.gdshader: the car select screen's studio, as a sky that only lights and reflects
// (the showroom renders over a clear background). Soft boxes overhead, at the sides and behind the
// camera put long highlights on gloss, metallic and chrome paint. No TIME: the radiance map is
// built once.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.16, 0.18, 0.23);
uniform vec3 horizon_color : source_color = vec3(0.09, 0.10, 0.13);
uniform vec3 ground_color : source_color = vec3(0.02, 0.022, 0.028);
uniform vec3 box_color : source_color = vec3(1.0, 0.97, 0.92);
uniform float box_energy = 2.6;

// A soft-edged box on the sky: `centre` and `size` in (azimuth, elevation) radians.
float soft_box(vec2 ae, vec2 centre, vec2 size, float soft) {
	vec2 d = abs(ae - centre) - size;
	return 1.0 - smoothstep(0.0, soft, max(d.x, d.y));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float az = atan(d.x, d.z);    // 0 toward +Z, where the camera stands
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.9, el));
	col = mix(col, ground_color, smoothstep(0.0, -0.35, el));
	float boxes = 0.0;
	// A long strip overhead, across the car.
	boxes += smoothstep(1.05, 1.18, el) * (1.0 - smoothstep(0.22, 0.30, abs(d.x)));
	// Behind the camera, high: the front's highlight.
	boxes += soft_box(vec2(az, el), vec2(0.0, 0.42), vec2(0.55, 0.16), 0.08);
	// Tall strips either side.
	boxes += soft_box(vec2(abs(az), el), vec2(1.57, 0.30), vec2(0.10, 0.30), 0.06) * 0.8;
	// A rim box behind the car.
	boxes += soft_box(vec2(abs(az), el), vec2(3.14159, 0.35), vec2(0.45, 0.10), 0.08) * 0.6;
	COLOR = col + box_color * box_energy * clamp(boxes, 0.0, 1.0);
}
