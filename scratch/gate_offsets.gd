extends SceneTree
## Where each checkpoint of a level stands along its lap (the closest offset on the TrackPath), and the order the level
## lists them in (read from the .tscn, so it works without the game's autoloads).
##   Godot --headless --path . -s res://scratch/gate_offsets.gd -- res://levels/X.tscn ...
func _init() -> void:
	for lp in OS.get_cmdline_user_args():
		var text := FileAccess.get_file_as_string(lp)
		var i := text.find("checkpoints = [")
		var order := text.substr(i, text.find("]", i) - i + 1) if i >= 0 else "?"
		var root := (load(lp) as PackedScene).instantiate()
		var path: Path3D = root.get_node("TrackPath")
		var c := path.curve
		print(lp.get_file(), "  lap %.0fm" % c.get_baked_length())
		print("  ", order)
		for cp in root.get_node("Checkpoints").get_children():
			var p: Vector3 = (cp as Node3D).position
			print("  %-14s s %7.1f at (%.0f, %.0f)" % [cp.name, c.get_closest_offset(p), p.x, p.z])
		var fl: Node3D = root.get_node("FinishLine")
		print("  %-14s s %7.1f" % ["FinishLine", c.get_closest_offset(fl.position)])
		root.free()
	quit()
