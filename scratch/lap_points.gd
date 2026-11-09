extends SceneTree

# Prints where a level's TrackPath runs, every `every` metres along it (to aim a camera or a tile's focus).
#   Godot --headless --path . -s res://scratch/lap_points.gd -- <level.tscn> [every=250]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var every := 250.0
	for a in args:
		if a.begins_with("every="):
			every = float(a.substr(6))
	var level: Node3D = load(args[0]).instantiate()
	var tp := level.find_child("TrackPath", true, false) as Path3D
	var len := tp.curve.get_baked_length()
	print("length %.0f" % len)
	var s := 0.0
	while s <= len:
		var p: Vector3 = tp.transform * tp.curve.sample_baked(s)
		print("  s %5.0f  (%.0f, %.0f, %.0f)" % [s, p.x, p.y, p.z])
		s += every
	level.free()
	quit()
