extends MultiMeshInstance3D
## The rubber carts lay on paved road, for the whole level: one MultiMesh of quads, a ring of
## MAX_SEGMENTS reused oldest first. Each wheel's mark is a strip whose quads share their corners
## with the quad before, so it follows a bend without gaps or dark overlaps, and it lies on the
## ground the wheel's ray hit (LIFT above it), not on a flat particle that floats over a crest.
## skid_marks.gdshader builds each quad from the corners in its instance transform and fades it
## out over FADE_TIME.
##
## PlayerCart calls lay() for every wheel that skids, each frame, and lift() when it stops. The first
## cart that skids adds the node to the level (PlayerCart._skid_marks), so it goes with the level.

const SHADER := preload("res://skid_marks.gdshader")
const MAX_SEGMENTS := 8192
## Seconds a mark lasts (it fades over the last 45% of them).
const FADE_TIME := 45.0
## A new quad once the wheel has moved this far; a jump past MAX_STEP starts a new strip.
const MIN_STEP := 0.3
const MAX_STEP := 3.0
## Height of the mark over the hit point (the shader also pulls it toward the camera).
const LIFT := 0.015

var _material: ShaderMaterial
var _next := 0
var _used := 0
var _t0 := 0
## wheel key -> {"p", "l", "r", "s", "k"}: the strip's last edge, distance along it and strength.
var _trails := {}


func _init() -> void:
	_t0 = Time.get_ticks_msec()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("fade_time", FADE_TIME)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	mm.instance_count = MAX_SEGMENTS
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# The instance "transforms" are corners, not placements: culling can't use them.
	custom_aabb = AABB(Vector3(-6000, -2000, -6000), Vector3(12000, 4000, 12000))


## A one-quad stand-in in the marks' shader for FxWarmup, so the first skid doesn't compile it.
static func warmup_node() -> MultiMeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	mm.mesh = quad
	mm.instance_count = 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


func _process(_delta: float) -> void:
	_material.set_shader_parameter("now", _now())


func _now() -> float:
	return (Time.get_ticks_msec() - _t0) * 0.001


## One wheel's contact this frame: `pos` on the ground with normal `n`, moving along `fwd`, a mark
## `width` wide at `strength` (0..1). Marks start faded in from nothing.
func lay(key: int, pos: Vector3, n: Vector3, fwd: Vector3, width: float, strength: float) -> void:
	var right := fwd.cross(n)
	if right.length_squared() < 1e-6:
		return
	right = right.normalized() * (width * 0.5)
	var p := pos + n * LIFT
	var t: Dictionary = _trails.get(key, {})
	if t.is_empty() or p.distance_to(t["p"]) > MAX_STEP:
		_trails[key] = {"p": p, "l": p - right, "r": p + right, "s": 0.0, "k": 0.0}
		return
	var step: float = p.distance_to(t["p"])
	if step < MIN_STEP:
		return
	var l := p - right
	var r := p + right
	var s: float = float(t["s"]) + step
	var i := _next
	multimesh.set_instance_transform(i, Transform3D(Basis(t["l"], t["r"], l), r))
	multimesh.set_instance_color(i, Color(t["k"], strength, 0.0, 1.0))
	multimesh.set_instance_custom_data(i, Color(_now(), t["s"], s, 0.0))
	_next = (_next + 1) % MAX_SEGMENTS
	_used = mini(_used + 1, MAX_SEGMENTS)
	if multimesh.visible_instance_count < _used:
		multimesh.visible_instance_count = _used
	t["p"] = p
	t["l"] = l
	t["r"] = r
	t["s"] = s
	t["k"] = strength


## The wheel stopped skidding: its next mark starts a new strip.
func lift(key: int) -> void:
	_trails.erase(key)


func _quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	# The positions are never used (the shader takes the corners from the instance); the UV says
	# which corner a vertex is.
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(-0.5, 0, 1), Vector3(0.5, 0, 1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 2, 1, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
