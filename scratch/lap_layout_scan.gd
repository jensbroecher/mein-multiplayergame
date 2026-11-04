extends SceneTree
# Lists a level's straights (stretches of its TrackPath turning under 2 degrees over every 20m, `min` metres or
# longer) and where along the lap its gates, boost pads, ramps, rail crossings and jump lips stand, to plan
# placements. Headless:  Godot --headless --path . -s res://scratch/lap_layout_scan.gd -- [level=...] [min=120]

func _init() -> void:
	var level_path := "res://levels/FreightLevel.tscn"
	var min_len := 120.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("min="):
			min_len = float(a.substr(4))
	var level: Node3D = load(level_path).instantiate()
	var path: Path3D = level.get_node("TrackPath")
	var c: Curve3D = path.curve
	var L: float = c.get_baked_length()
	print("lap %.0fm" % L)
	var step := 5.0
	var run0 := -1.0
	var s := 0.0
	var prev_dir := Vector2.ZERO
	while s <= L + step:
		var a3: Vector3 = c.sample_baked(fposmod(s, L))
		var b3: Vector3 = c.sample_baked(fposmod(s + 20.0, L))
		var d := Vector2(b3.x - a3.x, b3.z - a3.z).normalized()
		var straight := prev_dir != Vector2.ZERO and absf(prev_dir.angle_to(d)) < deg_to_rad(2.0) * step / 20.0 * 4.0
		if straight and run0 < 0.0:
			run0 = s
		elif not straight and run0 >= 0.0:
			if s - run0 >= min_len:
				print("STRAIGHT %.0f-%.0f (%.0fm)" % [run0, s, s - run0])
			run0 = -1.0
		prev_dir = d
		s += step
	var items: Array = []
	for n in level.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("Checkpoint_") or nm == "FinishLine" or nm.begins_with("Boost") or nm.begins_with("RailCrossing") \
				or n.is_in_group("ramps") or (n.get_script() != null and String(n.get_script().resource_path).ends_with("WoodenRamp.gd")):
			var p: Vector3 = (n as Node3D).position
			var parent := n.get_parent() as Node3D
			if parent != null and parent != level:
				p = parent.transform * p
			items.append([c.get_closest_offset(path.to_local(p)), nm])
	for lip in path.get_meta(&"jump_lips", []):
		items.append([c.get_closest_offset(lip["lip"]), "lip " + String(lip["name"])])
	items.sort_custom(func(x, y): return x[0] < y[0])
	for it in items:
		print("AT %6.0f  %s" % [it[0], it[1]])
	level.free()
	quit()
