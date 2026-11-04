extends Node
# Loads a level with trains (Train.gd) and prints, every few seconds, each train's recorded sound loops: which of
# the pair plays, where in the clip and how loud (the crossfade shows as both playing). Headless:
#   Godot --headless --path . res://scratch/train_loop_probe.tscn [-- level=res://levels/FreightLevel.tscn seconds=26]
# The node's name holds "regenerate" so Level.gd skips its race setup.


func _ready() -> void:
	var level_path := "res://levels/FreightLevel.tscn"
	var seconds := 26.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	var t := 0.0
	var next := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if t < next:
			continue
		next += 4.0
		for tr in level.find_children("*", "Node3D", true, false):
			if not tr.has_method("is_moving") or tr.get("_loops") == null:
				continue
			var parts: Array = []
			for lp in tr.get("_loops"):
				var ps: Array = []
				for p in lp["players"]:
					var ap := p as AudioStreamPlayer3D
					ps.append("%s@%.1fs %.0fdB" % ["on" if ap.playing else "--", ap.get_playback_position(), ap.volume_db] if ap.playing else "--")
				parts.append(("engine " if lp["engine"] else "wheels ") + String((lp["players"][0] as AudioStreamPlayer3D).stream.resource_path.get_file()) + " [" + ", ".join(ps) + "]")
			print("T %.0fs %s: %s" % [t, tr.name, " | ".join(parts)])
	get_tree().quit()
