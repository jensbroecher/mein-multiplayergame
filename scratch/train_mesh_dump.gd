extends SceneTree
# Saves TrainKit car meshes (no bogies) as .res files, for scratch/zfight_scan.gd. Headless:
#   Godot --headless --path . -s res://scratch/train_mesh_dump.gd -- <dir> [kinds=ploco:0,coach:0,obs:0]

func _init() -> void:
	var TrainKit = load("res://TrainKit.gd")
	var dir := ""
	var kinds := ["ploco:0", "coach:0", "obs:0"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("kinds="):
			kinds = Array(a.substr(6).split(","))
		else:
			dir = a
	for k in kinds:
		var parts: PackedStringArray = String(k).split(":")
		var m: ArrayMesh = TrainKit.build(parts[0], int(parts[1]), false)
		var path := "%s/%s_%s.res" % [dir, parts[0], parts[1]]
		ResourceSaver.save(m, path)
		print("SAVED ", path)
	quit()
