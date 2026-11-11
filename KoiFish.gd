extends MultiMeshInstance3D
## Koi in Yoshino Rapids' garden (regenerate_yoshino_rapids.gd, _build_koi): one MultiMesh of fish (koi.gdshader swishes
## their tails), each on a swim of its own on the wall clock, so LAN peers see the same. A swim is a row of `swims`:
##   kind 0, a circle in the pool: a = its centre (y the fish's depth), b.x its radius, b.y the speed (m/s); clockwise
##        when the speed is negative
##   kind 1, a beat in the stream: a = the upstream end, b = the downstream end (the fish holds station between them,
##        drifting back and pushing up again, nose upstream), speed how fast it beats
## and `sizes` the fish's scales. Still on a headless server and in the generator.

@export var kinds := PackedInt32Array()
@export var a_pts := PackedVector3Array()
@export var b_pts := PackedVector3Array()
@export var speeds := PackedFloat32Array()
@export var phases := PackedFloat32Array()
@export var sizes := PackedFloat32Array()
## Where the fish are (the instances are in world space, the node at the origin): they swim only while a camera is
## within `visibility_range_end` of it.
@export var centre := Vector3.ZERO

var _active := true


func _ready() -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or _in_generator():
		_active = false
		set_process(false)


func _in_generator() -> bool:
	for child in get_tree().root.get_children():
		if "regenerate" in str(child.name).to_lower():
			return true
	return false


## The fish's place and heading at time t (seconds).
func pose_at(i: int, t: float) -> Transform3D:
	var a: Vector3 = a_pts[i]
	var b: Vector3 = b_pts[i]
	var sp: float = speeds[i]
	var ph: float = phases[i]
	var pos: Vector3
	var fwd: Vector3
	if kinds[i] == 0:
		var r: float = b.x
		var ang: float = ph + t * sp / maxf(r, 0.1)
		var wob: float = r * (1.0 + 0.12 * sin(t * 0.37 + ph * 3.0))
		pos = a + Vector3(cos(ang) * wob, 0.04 * sin(t * 0.8 + ph), sin(ang) * wob)
		fwd = Vector3(-sin(ang), 0.0, cos(ang)) * signf(sp)
	else:
		var u: float = 0.5 + 0.5 * sin(t * sp + ph)
		var along: Vector3 = (a - b)
		along.y = 0.0
		fwd = along.normalized()
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		pos = b.lerp(a, u) + side * 0.25 * sin(t * 0.51 + ph * 2.0)
		# A little yaw as it works against the current.
		fwd = (fwd + side * 0.15 * sin(t * 1.3 + ph)).normalized()
	var x: Vector3 = Vector3.UP.cross(fwd).normalized()
	return Transform3D(Basis(x, Vector3.UP, fwd).scaled(Vector3.ONE * sizes[i]), pos)


func _process(_delta: float) -> void:
	if not _active or multimesh == null or not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam and visibility_range_end > 0.0 and cam.global_position.distance_to(centre) > visibility_range_end + 40.0:
		return
	var t: float = fposmod(Time.get_unix_time_from_system(), 86400.0)
	for i in range(mini(multimesh.instance_count, kinds.size())):
		multimesh.set_instance_transform(i, pose_at(i, t))
