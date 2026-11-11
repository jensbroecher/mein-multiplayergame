extends SceneTree

# How many triangles a level's meshes put in view along its route: at every `step` metres of the TrackPath, the sum over
# MeshInstance3Ds (and MultiMeshes) whose visibility range holds the camera's distance to their bounds' middle (no
# frustum: a camera can look any way). Headless:
#   Godot --headless --path . -s res://scratch/visible_tris_probe.gd -- <level> [step=200] [under=Stadt]
# `under` counts only meshes below a node of that name (default: all). Prints each point and the mean and the worst.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var step := 200.0
	var under := ""
	for a in args.slice(1):
		if a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("under="):
			under = a.substr(6)
	var root: Node = (load(args[0]) as PackedScene).instantiate()
	var items: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is GeometryInstance3D):
			continue
		if not under.is_empty():
			var ok := false
			var p: Node = n
			while p != null:
				if String(p.name) == under:
					ok = true
					break
				p = p.get_parent()
			if not ok:
				continue
		var tris := 0
		var mesh: Mesh = null
		var count := 1
		if n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			mesh = (n as MultiMeshInstance3D).multimesh.mesh
			count = (n as MultiMeshInstance3D).multimesh.instance_count
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var arr: Array = mesh.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var g := n as GeometryInstance3D
		var ab: AABB = g.global_transform * g.get_aabb() if g.is_inside_tree() else _xf(g) * g.get_aabb()
		items.append([ab.get_center(), g.visibility_range_begin, g.visibility_range_end, tris * count])
	var tp: Path3D = root.get_node("TrackPath")
	var c: Curve3D = tp.curve
	var length := c.get_baked_length()
	var s := 0.0
	var total := 0.0
	var worst := 0
	var n_pts := 0
	while s < length:
		var cam: Vector3 = c.sample_baked(s) + Vector3(0, 3, 0)
		var sum := 0
		for it in items:
			var d: float = (it[0] as Vector3).distance_to(cam)
			if d >= float(it[1]) and (float(it[2]) <= 0.0 or d <= float(it[2])):
				sum += int(it[3])
		print("s %5.0f  %8d triangles" % [s, sum])
		total += sum
		worst = maxi(worst, sum)
		n_pts += 1
		s += step
	print("MEAN %d  WORST %d  (%d points)" % [int(total / maxf(n_pts, 1)), worst, n_pts])
	quit()


func _xf(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
