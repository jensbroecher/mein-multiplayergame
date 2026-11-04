extends Node
# Freight Line's level crossings: watches each one in real time (the trains run on the wall clock) and prints when
# its recorded freight pass-by (RailCrossing.PASSBY_CLIPS) starts and stops, where in the clip, and when the
# crossing's warning (lights, bell) comes on and off, to check the swell lines up with the train. Headless:
#   Godot --headless --path . res://scratch/passby_probe.tscn [-- seconds=150 level=res://levels/FreightLevel.tscn]
# The node's name holds "regenerate" so Level.gd skips its race setup.


func _ready() -> void:
	var level_path := "res://levels/FreightLevel.tscn"
	var seconds := 150.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("level="):
			level_path = a.substr(6)
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	var crossings: Array = []
	for c in level.find_children("RailCrossing*", "Node3D", true, false):
		crossings.append(c)
	var state := {}
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().physics_frame
		var t: float = (Time.get_ticks_msec() - t0) / 1000.0
		for c in crossings:
			var pb: AudioStreamPlayer3D = c.get("_passby")
			var warn: bool = c.get("warning")
			var playing: bool = pb != null and pb.playing
			var prev: Array = state.get(c.name, [false, false])
			if warn != prev[0]:
				print("%6.1fs %s warning %s" % [t, c.name, "ON" if warn else "off"])
			if playing != prev[1]:
				if playing:
					print("%6.1fs %s PASSBY %s from %.1fs (%s)" % [t, c.name, pb.stream.resource_path.get_file(), pb.get_playback_position(), c.get("_passby_key")])
				else:
					print("%6.1fs %s passby stopped" % [t, c.name])
			state[c.name] = [warn, playing]
	get_tree().quit()
