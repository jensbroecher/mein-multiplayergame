extends SceneTree
## Lists a level's single meshes wider than DressingColliders' 400m limit (it gives them no collider). Headless:
##   Godot --headless --path . -s res://scratch/wide_prop_meshes.gd -- res://levels/X.tscn [limit=400]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var limit := 400.0
	for a in args:
		if a.begins_with("limit="):
			limit = float(a.substr(6))
	var root: Node = (load(args[0]) as PackedScene).instantiate()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := Transform3D()
		var p: Node = mi
		while p != null and p != root:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var box: AABB = t * mi.mesh.get_aabb()
		if box.size.x > limit or box.size.z > limit:
			print("%s  %.0f x %.0f" % [root.get_path_to(mi), box.size.x, box.size.z])
	root.free()
	quit()
