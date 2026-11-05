extends SceneTree

# Lists the box shapes of a level's bodies whose name matches near a point (centre, size, the box's long axis in plan,
# its ends), to see where a run of guardrail ends and whether a gap is left. Headless:
#   Godot --headless --path . -s res://scratch/rail_boxes_near.gd -- <level.tscn> x,z [radius=10] [match=Guardrail]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node = load(args[0]).instantiate()
	var c := args[1].split(",")
	var at := Vector2(float(c[0]), float(c[1]))
	var radius := 10.0
	var pattern := "Guardrail"
	for a in args.slice(2):
		if a.begins_with("radius="):
			radius = float(a.substr(7))
		elif a.begins_with("match="):
			pattern = a.substr(6)
	var stack: Array = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is CollisionShape3D) or not (n.shape is BoxShape3D):
			continue
		if not str(level.get_path_to(n)).contains(pattern):
			continue
		var xf: Transform3D = _global(n)
		var p := Vector2(xf.origin.x, xf.origin.z)
		if p.distance_to(at) > radius:
			continue
		var size: Vector3 = (n.shape as BoxShape3D).size
		var z := xf.basis.z.normalized()
		var e0 := xf.origin - z * size.z * 0.5
		var e1 := xf.origin + z * size.z * 0.5
		print("%s  size %s  ends (%.2f, %.2f) - (%.2f, %.2f)  y %.2f" % [level.get_path_to(n), size, e0.x, e0.z, e1.x, e1.z, xf.origin.y])
	level.free()
	quit()


func _global(n: Node) -> Transform3D:
	var xf := Transform3D()
	var cur: Node = n
	while cur:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
