shader_type spatial;
render_mode cull_back;

// Northlight Caverns' ice sculptures (IceSculptureKit.gd), lit from their plinths at night.
// Clear carved ice: pale, glossy, catching the sky; the light of its uplight (`glow`, per instance) inside it, strongest
// at the silhouette (where light runs through the most ice) and at its foot (nearest the lamp); the carver's chisel
// marks as shallow scoops bumped into the surface (from the model-space position, so they ride with the sculpture),
// fading out once they are smaller than a pixel. Opaque: a transparent pass would sort against the aurora sky and
// the cavern's glass.

instance uniform vec3 glow : source_color = vec3(0.45, 0.85, 1.0);
uniform vec3 ice : source_color = vec3(0.60, 0.78, 0.90);
uniform float glow_energy = 1.5;
uniform float chisel_scale = 2.2;
uniform float chisel_depth = 0.18;

varying vec3 m_pos;

void vertex() {
	m_pos = VERTEX;
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// The nearest scoop's centre distance (Worley F1): the chisel's cuts.
float scoops(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = hash33(i + g);
				d = min(d, length(g + o - f));
			}
		}
	}
	return d;
}

void fragment() {
	float px = length(fwidth(m_pos));
	float fade = 1.0 - smoothstep(0.03, 0.12, px);
	// Bump without tangents (the mesh has none): perturb the normal by the scoops' screen-space slope.
	float h = scoops(m_pos * chisel_scale);
	vec3 ds = dFdx(VERTEX);
	vec3 dt = dFdy(VERTEX);
	vec3 r1 = cross(dt, NORMAL);
	vec3 r2 = cross(NORMAL, ds);
	float det = dot(ds, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * chisel_depth * fade);

	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.5);
	ALBEDO = ice * (0.4 + 0.1 * h);
	ROUGHNESS = 0.05 + 0.1 * h;
	SPECULAR = 0.75;
	float foot = 1.0 - smoothstep(0.3, 3.5, m_pos.y);
	EMISSION = glow * glow_energy * (0.05 + 0.75 * rim + 0.3 * foot) + vec3(0.55, 0.8, 1.0) * rim * 0.15;
}
