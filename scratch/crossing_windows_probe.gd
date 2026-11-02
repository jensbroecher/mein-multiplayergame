extends SceneTree

# Lists, for each of Freight Line's level crossings, every train it listens to and that train's passes over it (seconds
# into the train's cycle, from the timetable Train.gd gives the crossing), so a train that comes back the way it went
# (the local into the station) shows its two passes. With `at=<s0>,<s1>` it also holds every train's clock at each
# second from s0 to s1 and prints what a bot would hear from each crossing (`is_closed_for` 0 to 5s ahead, X closed)
# and which trains are on it. Headless:
#   Godot --headless --path . -s res://scratch/crossing_windows_probe.gd [-- at=40,60]

func _initialize() -> void:
	var at := Vector2(-1, -1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("at="):
			var p := a.substr(3).split(",")
			at = Vector2(float(p[0]), float(p[1]))
	var level: Node3D = load("res://levels/FreightLevel.tscn").instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	var crossings: Array = level.find_children("RailCrossing*", "", false, false)
	for c in crossings:
		print("%s at train_s %.0fm (warn %.1fs ahead, hold %.1fs):" % [c.name, c.train_s, c.warn_lead, c.hold])
		for t in c._trains:
			var wins: Array = t.pass_windows(c.train_s, c.pad)
			var parts := PackedStringArray()
			for w in wins:
				parts.append("%.1f-%.1fs" % [w[0], w[1]])
			print("  %s (every %.0fs): %s" % [t.name, t.period, ", ".join(parts)])
	if at.x < 0.0:
		quit()
		return
	var trains: Array = level.find_children("*Train", "", false, false)
	var clock: float = at.x
	while clock <= at.y:
		for t in trains:
			t.clock_override = clock
		await physics_frame
		var line := "t=%5.1f" % clock
		for c in crossings:
			var marks := ""
			for eta in range(6):
				marks += "X" if c.is_closed_for(float(eta)) else "."
			var on := PackedStringArray()
			for t in c._trains:
				for w in t.pass_windows(c.train_s, c.pad):
					var tt: float = t.cycle_time()
					if tt >= float(w[0]) and tt <= float(w[1]):
						on.append(String(t.name).replace("MainLine", "").replace("BranchLine", "B").replace("Train", ""))
			line += "  %s %s %-12s" % [c.name.replace("RailCrossing", "#"), marks, ",".join(on)]
		print(line)
		clock += 1.0
	quit()
