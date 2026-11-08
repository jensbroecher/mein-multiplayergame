extends SceneTree
## Lists every MeshInstance3D (and MultiMeshInstance3D) of a level whose world bounds contain a point, to find
## what draws something seen in a shot (headless):
##   Godot --headless --path . -s res://scratch/meshes_at.gd -- <level.tscn> x,y,z [x,y,z ...]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node3D = (load(args[0]) as PackedScene).instantiate()
	root.add_child(level)
	await process_frame
	for a in args.slice(1):
		var c := a.split(",")
		var p := Vector3(float(c[0]), float(c[1]), float(c[2]))
		print("at %s:" % str(p))
		for n in level.find_children("*", "GeometryInstance3D", true, false):
			var gi := n as VisualInstance3D
			if gi == null:
				continue
			var box: AABB = gi.global_transform * gi.get_aabb()
			if box.grow(0.5).has_point(p):
				print("  %s (%s) box %s .. %s" % [level.get_path_to(gi), gi.get_class(), str(box.position), str(box.end)])
	level.queue_free()
	quit()
