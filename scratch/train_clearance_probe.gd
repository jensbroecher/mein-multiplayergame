extends Node
# Steps every Train in a level through its timetable together (Train._place at a shared clock reading; parked ones at
# their clock_override) and measures the gap between each pair of cars of different trains in plan: centreline to
# centreline less both half widths (cars as capsules). Prints the closest each pair of trains comes, when and where,
# and every overlap. Headless:
#   Godot --headless --path . res://scratch/train_clearance_probe.tscn -- [level=res://levels/FreightLevel.tscn]
#       [from=0] [span=1500] [step=0.25] [warn=3.0]
# `warn` lists every moment two trains come closer than that many metres.
# The node's name holds "regenerate" so Level.gd skips its race setup.


func _ready() -> void:
	var level_path := "res://levels/FreightLevel.tscn"
	var from := 0.0
	var span := 1500.0
	var step := 0.25
	var warn := 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("from="):
			from = float(a.substr(5))
		elif a.begins_with("span="):
			span = float(a.substr(5))
		elif a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("warn="):
			warn = float(a.substr(5))
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var trains: Array = []
	for n in level.find_children("*", "Node3D", true, false):
		if n.has_method("head_at") and n.get("cars") != null:
			n.set_physics_process(false)
			trains.append(n)
	print("trains: %s" % ", ".join(trains.map(func(t): return String(t.name))))
	var best := {}
	var overlaps := 0
	var warned := 0
	var t := from
	while t < from + span:
		var segs: Array = []
		for ti in trains.size():
			var tr: Node3D = trains[ti]
			var ov: float = tr.get("clock_override")
			tr.call("_place", ov if ov >= 0.0 else t)
			var gx: Transform3D = tr.global_transform
			for car in tr.get("cars"):
				if not car.present or car.node == null:
					continue
				var xf: Transform3D = gx * car.xf
				var fwd: Vector3 = xf.basis.z.normalized()
				var c := Vector2(xf.origin.x, xf.origin.z)
				var f: Vector2 = Vector2(fwd.x, fwd.z).normalized() * (float(car.length) * 0.5 - float(car.half_width))
				segs.append([ti, c - f, c + f, car.half_width, car.kind, c])
		for i in segs.size():
			for j in range(i + 1, segs.size()):
				var A: Array = segs[i]
				var B: Array = segs[j]
				if A[0] == B[0]:
					continue
				if (A[5] as Vector2).distance_to(B[5]) > 45.0:
					continue
				var d: float = _seg_dist(A[1], A[2], B[1], B[2]) - float(A[3]) - float(B[3])
				var key := "%s / %s" % [trains[A[0]].name, trains[B[0]].name]
				if not best.has(key) or d < float(best[key][0]):
					best[key] = [d, t, A[5], A[4], B[4]]
				if d < 0.0:
					overlaps += 1
				if d < warn and warned < 40:
					warned += 1
					var p: Vector2 = A[5]
					print("CLOSE %.2fs %s: %.2fm (%s vs %s) at (%.0f, %.0f)" % [t, key, d, A[4], B[4], p.x, p.y])
		t += step
	for key in best:
		var b: Array = best[key]
		print("PAIR %-48s closest %.2fm at %.2fs near (%.0f, %.0f) (%s vs %s)" % [key, b[0], b[1], (b[2] as Vector2).x, (b[2] as Vector2).y, b[3], b[4]])
	print("OVERLAPS %d samples" % overlaps)
	get_tree().quit()


static func _seg_dist(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> float:
	var a := Geometry2D.get_closest_points_between_segments(p1, q1, p2, q2)
	return (a[0] as Vector2).distance_to(a[1])
