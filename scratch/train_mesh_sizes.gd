extends SceneTree
# Prints the triangle count of each TrainKit car kind and variant (the body mesh, bogies apart). Headless:
#   Godot --headless --path . -s res://scratch/train_mesh_sizes.gd -- [kinds=loco:0,loco:1,loco:2,box:0,ploco:0]

func _init() -> void:
	var TrainKit = load("res://TrainKit.gd")
	var kinds := ["loco:0", "loco:1", "loco:2", "ploco:0", "coach:0", "box:0", "hopper:0", "tank:0", "flat:0", "caboose:0"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("kinds="):
			kinds = Array(a.substr(6).split(","))
	for k in kinds:
		var parts: PackedStringArray = String(k).split(":")
		var t0 := Time.get_ticks_usec()
		var m: ArrayMesh = TrainKit.build(parts[0], int(parts[1]), false)
		var tris := 0
		for si in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		print("%-10s %6d triangles, built in %.1f ms" % [k, tris, (Time.get_ticks_usec() - t0) / 1000.0])
	quit()
