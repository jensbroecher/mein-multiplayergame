extends Node3D
## Rotates windmill blades (default: part_4 + part_15) around a pivot at the
## combined mesh center so the hub stays put instead of orbiting the FBX origin.

@export var blade_part_names: PackedStringArray = ["part_4", "part_15"]
## Degrees per second around the spin axis (positive = one direction).
@export var spin_degrees_per_second: float = 40.0
## If non-zero, used as local spin axis. If zero, inferred from blade AABB (thinnest axis).
@export var spin_axis_local: Vector3 = Vector3.ZERO
@export var auto_setup_on_ready: bool = true

var _pivot: Node3D = null
var _axis: Vector3 = Vector3.FORWARD


func _ready() -> void:
	if auto_setup_on_ready:
		setup_blade_pivot()


func _process(delta: float) -> void:
	if _pivot == null or spin_degrees_per_second == 0.0:
		return
	_pivot.rotate(_axis, deg_to_rad(spin_degrees_per_second) * delta)


## Call again if you change which parts spin.
func setup_blade_pivot() -> void:
	if _pivot != null and is_instance_valid(_pivot):
		# Already set up
		return

	var blades: Array[Node3D] = []
	for n in blade_part_names:
		var node := _find_desc_named(self, str(n))
		if node is Node3D:
			blades.append(node as Node3D)
		else:
			push_warning("[Windmill] blade part not found: %s" % n)

	if blades.is_empty():
		push_warning("[Windmill] no blade parts found under %s" % name)
		return

	var center_global := _combined_mesh_center_global(blades)
	if not center_global.is_finite():
		push_warning("[Windmill] invalid blade center")
		return

	_pivot = Node3D.new()
	_pivot.name = "BladePivot"
	add_child(_pivot)
	# Pivot at geometric hub in world space, then reparent blades under it.
	_pivot.global_position = center_global
	# Keep pivot rotation aligned with windmill so local axis is stable.
	_pivot.global_basis = global_basis.orthonormalized()

	for blade in blades:
		var gt := blade.global_transform
		var parent := blade.get_parent()
		if parent:
			parent.remove_child(blade)
		_pivot.add_child(blade)
		blade.global_transform = gt

	_axis = _resolve_spin_axis(blades)
	print("[Windmill] pivot at ", center_global, " axis ", _axis, " parts ", blade_part_names)


func _resolve_spin_axis(blades: Array[Node3D]) -> Vector3:
	if spin_axis_local.length_squared() > 0.0001:
		return spin_axis_local.normalized()

	# Thinnest AABB axis in pivot/windmill local space ≈ shaft through the hub.
	var aabb := _combined_aabb_local_to(self, blades)
	var s := aabb.size
	if s.x <= s.y and s.x <= s.z:
		return Vector3.RIGHT
	if s.y <= s.x and s.y <= s.z:
		return Vector3.UP
	return Vector3.FORWARD


func _find_desc_named(root: Node, want: String) -> Node:
	if root.name == want:
		return root
	for c in root.get_children():
		var f := _find_desc_named(c, want)
		if f:
			return f
	return null


func _combined_mesh_center_global(blades: Array[Node3D]) -> Vector3:
	var merged: AABB
	var has := false
	for blade in blades:
		var a := _global_mesh_aabb(blade)
		if not has:
			merged = a
			has = true
		else:
			merged = merged.merge(a)
	if not has:
		return global_position
	return merged.get_center()


func _combined_aabb_local_to(space: Node3D, blades: Array[Node3D]) -> AABB:
	var inv := space.global_transform.affine_inverse()
	var merged: AABB
	var has := false
	for blade in blades:
		var g := _global_mesh_aabb(blade)
		for i in range(8):
			var corner_local: Vector3 = inv * g.get_endpoint(i)
			if not has:
				merged = AABB(corner_local, Vector3.ZERO)
				has = true
			else:
				merged = merged.expand(corner_local)
	return merged


func _global_mesh_aabb(node: Node3D) -> AABB:
	var mi := node as MeshInstance3D
	if mi == null or mi.mesh == null:
		# Fallback: node origin only
		return AABB(node.global_position, Vector3.ZERO)
	var local_aabb: AABB = mi.mesh.get_aabb()
	var xf: Transform3D = mi.global_transform
	var merged := AABB(xf * local_aabb.get_endpoint(0), Vector3.ZERO)
	for i in range(1, 8):
		merged = merged.expand(xf * local_aabb.get_endpoint(i))
	return merged
