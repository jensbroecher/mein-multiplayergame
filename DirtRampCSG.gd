@tool
class_name DirtRampCSG
extends Node3D
## A dirt hump jump for Canyon Chasm, built in CSG from its exports as internal children (never saved), so a
## level stores only the transform. It replaced the Hunyuan FBX ramps (models/ramps/a0c68129...): the
## same hump, about 33m long, 13m wide and 8.9m high, a long shallow approach rising to a steep crest and
## a shorter way down the far side.
##
## The origin is the middle of the base on the ground; the run is along z, the width along x. The body
## is the side profile (`PROFILE`, z and height) extruded across the width, intersected with the cross
## section (`SECTION`, x and height) extruded along the run, so the crest's ends round off. Both reach
## `SINK` under the origin to bed into the ground. The CSG makes its own trimesh collider.

## Side profile: [z, height over the ground], measured off the FBX at the centre line.
const PROFILE := [
	[-16.8, 1.0], [-13.0, 1.4], [-9.0, 2.4], [-6.0, 3.5], [-4.0, 5.0], [-2.0, 7.9], [-0.8, 8.65],
	[0.0, 8.85], [0.8, 8.65], [2.0, 7.1], [3.0, 5.8], [4.0, 4.8], [6.0, 3.4], [8.0, 2.3], [10.0, 2.0],
	[13.0, 1.55], [16.6, 1.0],
]
## Cross section: [x, height], as wide as the road's dirt at the foot, the crest's ends sloping away.
const SECTION := [
	[-6.6, 0.0], [-6.6, 1.6], [-6.2, 4.5], [-5.4, 8.0], [-4.4, 10.0], [4.4, 10.0], [5.4, 8.0], [6.2, 4.5],
	[6.6, 1.6], [6.6, 0.0],
]
const SINK := 2.0
const LENGTH := 34.0
const WIDTH := 13.2

static var _material: StandardMaterial3D

func _ready() -> void:
	_build()

func _build() -> void:
	for c in get_children(true):
		if c.get_meta(&"dirt_ramp_part", false):
			remove_child(c)
			c.free()
	var root := CSGCombiner3D.new()
	root.set_meta(&"dirt_ramp_part", true)
	root.use_collision = true
	add_child(root, false, Node.INTERNAL_MODE_FRONT)

	# Side profile, extruded across x. Turned 90 degrees about y: its x runs along -z, its extrusion along -x.
	var side := CSGPolygon3D.new()
	var pts := PackedVector2Array()
	pts.append(Vector2(-PROFILE[0][0], -SINK))
	for p in PROFILE:
		pts.append(Vector2(-p[0], p[1]))
	pts.append(Vector2(-PROFILE[PROFILE.size() - 1][0], -SINK))
	side.polygon = pts
	side.depth = WIDTH + 2.0
	side.rotation_degrees.y = 90.0
	side.position.x = WIDTH * 0.5 + 1.0
	side.material = _dirt()
	root.add_child(side)

	# Cross section, extruded along z, keeping what is inside it.
	var section := CSGPolygon3D.new()
	var cs := PackedVector2Array()
	cs.append(Vector2(SECTION[0][0], -SINK))
	for p in SECTION:
		cs.append(Vector2(p[0], p[1]))
	cs.append(Vector2(SECTION[SECTION.size() - 1][0], -SINK))
	section.polygon = cs
	section.depth = LENGTH + 2.0
	section.position.z = LENGTH * 0.5 + 1.0
	section.operation = CSGShape3D.OPERATION_INTERSECTION
	section.material = _dirt()
	root.add_child(section)

static func _dirt() -> StandardMaterial3D:
	if _material:
		return _material
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.52, 0.36, 0.25), Color(0.70, 0.51, 0.37)])
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = ramp
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	m.roughness = 1.0
	m.metallic_specular = 0.2
	_material = m
	return m
