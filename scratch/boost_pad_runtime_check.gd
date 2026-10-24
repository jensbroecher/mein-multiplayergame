extends Node

# Loads a level as a spectator race and, once BoostPad.gd has turned its pads to face the lap
# (_face_lap), lists each pad's angle from the lap's direction under it (the nearest of TrackPath,
# the alternative paths and other lap paths). Every pad should be under a few degrees. Headless:
#   Godot --headless --path . res://scratch/boost_pad_runtime_check.tscn -- res://levels/X.tscn

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(args[0]).instantiate()
	add_child(level)
	for i in 30:
		await get_tree().process_frame
	var paths: Array = [level.track_path]
	paths.append_array(level.alternative_paths)
	for c in level.get_children():
		if c is Path3D and not paths.has(c) and "Path" in str(c.name):
			paths.append(c)
	var worst := 0.0
	for pad in get_tree().get_nodes_in_group("boost_pads"):
		var p: Vector3 = pad.global_position
		var best := INF
		var tan := Vector3.ZERO
		for path in paths:
			if path == null or path.curve == null:
				continue
			var off: float = path.curve.get_closest_offset(path.to_local(p))
			var d: float = path.to_global(path.curve.sample_baked(off)).distance_to(p)
			if d < best:
				best = d
				var a: Vector3 = path.to_global(path.curve.sample_baked(maxf(off - 2.0, 0.0)))
				var b: Vector3 = path.to_global(path.curve.sample_baked(minf(off + 2.0, path.curve.get_baked_length())))
				tan = Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var fwd: Vector3 = -pad.global_transform.basis.z
		fwd.y = 0.0
		var ang := rad_to_deg(fwd.normalized().angle_to(tan))
		worst = maxf(worst, ang)
		print("PAD %-22s %5.1f deg" % [pad.name, ang])
	print("WORST %.1f deg in %s" % [worst, args[0].get_file()])
	get_tree().quit()
