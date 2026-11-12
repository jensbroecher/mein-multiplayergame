shader_type spatial;
render_mode cull_disabled, unshaded;

// Tianqiao's aquarium fish (regenerate_tianqiao.gd): one MultiMesh a kind, each instance a fish swimming round its own
// loop in the shader. The instance transform places the loop's middle (its basis turns the loop); INSTANCE_CUSTOM is
// (radius along x, radius along z, speed in loops a minute, phase). The fish's mesh is built nose toward +z, its tail
// toward -z, and its tail half swings side to side. Fogged like the tanks (aquarium_tank.gdshader).

uniform float surface_y = 40.0;
uniform float clear = 6.0;
uniform float murk = 0.05;
uniform vec3 deep : source_color = vec3(0.01, 0.08, 0.16);
uniform vec3 shallow : source_color = vec3(0.03, 0.22, 0.34);
uniform float energy = 1.5;
uniform float wiggle = 0.12;
uniform float wiggle_rate = 7.0;

varying vec3 w_pos;
varying vec3 tint;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float a = TIME * cd.z * 6.28318 / 60.0 + cd.w * 6.28318;
	vec3 at = vec3(cos(a) * cd.x, sin(a * 2.0 + cd.w * 3.0) * 0.6, sin(a) * cd.y);
	vec3 fwd = normalize(vec3(-sin(a) * cd.x, 1.2 * cos(a * 2.0 + cd.w * 3.0) * 0.6, cos(a) * cd.y));
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 up = cross(fwd, side);
	vec3 v = VERTEX;
	float tailw = smoothstep(0.1, -1.0, v.z);
	v.x += sin(TIME * wiggle_rate + cd.w * 20.0 + v.z * 3.0) * wiggle * tailw * (1.0 + abs(v.z));
	vec3 local = at + side * v.x + up * v.y + fwd * v.z;
	VERTEX = local;
	w_pos = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 surf = pow(tint, vec3(2.2)) * (FRONT_FACING ? 1.0 : 0.75);
	float depth = clamp((surface_y - w_pos.y) / 30.0, 0.0, 1.0);
	vec3 water = mix(shallow, deep, depth);
	float d = max(length(w_pos - CAMERA_POSITION_WORLD) - clear, 0.0);
	float f = 1.0 - exp(-d * murk);
	ALBEDO = mix(surf, water, f) * energy;
}
