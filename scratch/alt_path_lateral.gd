extends SceneTree

# Prints each AlternativePaths child's lateral offset from the lap (TrackPath) and its height over the lap's nearest
# point, every `step` metres from its start: how a shortcut leaves and joins the lap. Headless:
#   Godot --headless --path . -s res://scratch/alt_path_lateral.gd -- <level.tscn> [step=4] [max=80] [only=<name part>]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node3D = load(args[0]).instantiate()
	var step := 4.0
	var max_s := 80.0
	var only := ""
	for a in args.slice(1):
		if a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("max="):
			max_s = float(a.substr(4))
		elif a.begins_with("only="):
			only = a.substr(5)
	var lap: Curve3D = (level.get_node("TrackPath") as Path3D).curve
	for path in level.get_node("AlternativePaths").get_children():
		if not path is Path3D or (only != "" and not only in str(path.name)):
			continue
		var c: Curve3D = (path as Path3D).curve
		var L := c.get_baked_length()
		print("%s (%.0fm)" % [path.name, L])
		for part in [[0.0, 1.0], [L, -1.0]]:
			var s := 0.0
			while s <= max_s:
				var at: float = part[0] + part[1] * s
				var p: Vector3 = c.sample_baked(clampf(at, 0.0, L))
				var off := lap.get_closest_offset(p)
				var q := lap.sample_baked(off)
				var f := (lap.sample_baked(off + 1.0) - q).normalized()
				var right := Vector3(-f.z, 0, f.x).normalized()
				print("  s %6.1f  lap %6.0f  lat %6.2f  dy %5.2f  at (%.1f, %.1f, %.1f)" % [at, off, (p - q).dot(right), p.y - q.y, p.x, p.y, p.z])
				s += step
	level.free()
	quit()
