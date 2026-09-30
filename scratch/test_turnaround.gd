extends SceneTree

func _init():
	var scene = load("res://levels/GlacierHighwayLevel.tscn")
	var level = scene.instantiate()
	root.add_child(level)
	var curve: Curve3D = level.get_node("TrackPath").curve
	var total_len = curve.get_baked_length()

	print("Total track length: %.2f" % total_len)

	# Check the turnaround loop at the end (from off=1650 to end) against start (off=0 to 200)
	print("Comparing south section against itself:")
	for s1 in range(1650, int(total_len), 5):
		var p1 = curve.sample_baked(float(s1))
		for s2 in range(0, 250, 5):
			var p2 = curve.sample_baked(float(s2))
			var h_dist = Vector2(p1.x - p2.x, p1.z - p2.z).length()
			var v_dist = absf(p1.y - p2.y)
			# Road width is 16m. Sum of half-widths is 16m!
			# If h_dist < 16.5m, the roads or barriers overlap!
			if h_dist < 18.0:
				print("  CLOSE: s1=%.1f (%s) near s2=%.1f (%s): h_dist=%.2f, v_dist=%.2f" % [s1, p1, s2, p2, h_dist, v_dist])

	# Also check turnaround loop (around Z=320..350) self-closeness
	print("\nChecking turnaround loop self-closeness:")
	for s1 in range(1700, int(total_len), 5):
		var p1 = curve.sample_baked(float(s1))
		for s2 in range(s1 + 30, int(total_len), 5):
			var p2 = curve.sample_baked(float(s2))
			var h_dist = Vector2(p1.x - p2.x, p1.z - p2.z).length()
			if h_dist < 18.0:
				print("  LOOP CLOSE: s1=%.1f (%s) near s2=%.1f (%s): h_dist=%.2f" % [s1, p1, s2, p2, h_dist])

	quit(0)
