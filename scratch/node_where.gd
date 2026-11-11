extends SceneTree

# Prints where a level's nodes are: every node whose name holds one of the words, its global position and, for
# meshes and MultiMeshes, the middle and size of its world bounds (to aim a camera). Headless:
#   Godot --headless --path . -s res://scratch/node_where.gd -- <level> word [word ...] [max=40]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: PackedScene = load(args[0])
	var words: Array = []
	var cap := 40
	for a in args.slice(1):
		if a.begins_with("max="):
			cap = int(a.substr(4))
		else:
			words.append(a.to_lower())
	var root := level.instantiate()
	get_root().add_child(root)
	var n := 0
	var stack: Array = [root]
	while not stack.is_empty() and n < cap:
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		var nm := String(node.name).to_lower()
		var hit := false
		for w in words:
			if w in nm:
				hit = true
		if not hit or not node is Node3D:
			continue
		n += 1
		var line := "%s  at %s" % [root.get_path_to(node), (node as Node3D).global_position.snapped(Vector3.ONE * 0.1)]
		if node is VisualInstance3D:
			var ab: AABB = (node as Node3D).global_transform * (node as VisualInstance3D).get_aabb()
			line += "  bounds middle %s size %s" % [ab.get_center().snapped(Vector3.ONE * 0.1), ab.size.snapped(Vector3.ONE * 0.1)]
		if node is Path3D and (node as Path3D).curve:
			var cv: Curve3D = (node as Path3D).curve
			var pts := []
			for i in range(0, cv.point_count, maxi(1, cv.point_count / 8)):
				pts.append((node as Node3D).global_transform * cv.get_point_position(i))
			line += "  points %s" % [pts]
		print(line)
	quit()
