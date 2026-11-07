extends SceneTree
# Lists every HazardGate.gd of a level (Quer durch Kronburg's hazards) with its hazard's period, when in the cycle the
# hazard covers the road there, and how much of the cycle a bot arriving at the gate would find it open (HazardGate's
# own test: clear from `lead` + 1s before its arrival to `trail` + 1s after). A gate open 0% of the time holds the bots
# for good, as the wrecking ball's did. Headless, no race (the level's own script is taken off, so nothing spawns):
#   Godot --headless --path . -s res://scratch/hazard_gate_probe.gd -- [level=res://levels/StadtrallyeLevel.tscn]

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "res://levels/StadtrallyeLevel.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			path = a.substr(6)
	var lvl: Node = (load(path) as PackedScene).instantiate()
	lvl.set_script(null)
	root.add_child(lvl)
	await process_frame
	await process_frame
	var n := 0
	for g in lvl.find_children("*", "Node3D", true, false):
		var sc: Script = g.get_script()
		if sc == null or not sc.resource_path.ends_with("HazardGate.gd"):
			continue
		n += 1
		var hz: Node = g.get_node_or_null(g.get("hazard"))
		if hz == null:
			print("%s: no hazard at %s" % [g.name, g.get("hazard")])
			continue
		var period: float = float(hz.get("period"))
		var iv: Array = hz.cover_intervals(g)
		var lead: float = float(g.get("lead")) + 1.0
		var trail: float = float(g.get("trail")) + 1.0
		var open := 0
		var steps := 0
		var run := 0.0
		var best := 0.0
		var t := 0.0
		# Twice round, so a run of open arrivals across the cycle's end counts whole.
		while t < period * 2.0:
			var closed := false
			for i in iv:
				for k in [-1.0, 0.0, 1.0, 2.0, 3.0]:
					var s0: float = float(i[0]) + k * period
					var s1: float = float(i[1]) + k * period
					if s1 >= t - lead and s0 <= t + trail:
						closed = true
			if t < period:
				steps += 1
				if not closed:
					open += 1
			run = 0.0 if closed else run + 0.05
			best = maxf(best, minf(run, period))
			t += 0.05
		var ivs := PackedStringArray()
		for i in iv:
			ivs.append("%.1f-%.1f" % [float(i[0]), float(i[1])])
		print("%-26s %-22s period %5.1fs  covers %-28s open %3.0f%%  longest open run %.1fs  at %s" % [g.name, hz.name, period,
				", ".join(ivs), 100.0 * float(open) / float(maxi(steps, 1)), best, str((g as Node3D).global_position.round())])
	print("%d gates" % n)
	quit()
