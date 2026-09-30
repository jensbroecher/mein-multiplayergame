extends SceneTree

func _init():
	var scene = load("res://levels/GlacierHighwayLevel.tscn")
	var level = scene.instantiate()
	root.add_child(level)

	var roads = {
		"Main": level.get_node("TrackPath").curve,
		"Alt1": level.get_node("AlternativePaths/AlternativePath_ViaductExpress").curve,
		"Alt2": level.get_node("AlternativePaths/AlternativePath_GorgeCut").curve,
		"Alt3": level.get_node("AlternativePaths/AlternativePath_RidgeBypass").curve
	}

	print("=== ALL CROSSINGS AND PROXIMITIES WITH HEIGHT DIFFERENCE ===")
	for name1 in roads:
		var c1: Curve3D = roads[name1]
		var len1 = c1.get_baked_length()
		for name2 in roads:
			var c2: Curve3D = roads[name2]
			var len2 = c2.get_baked_length()
			
			for s1 in range(0, int(len1), 2):
				var p1 = c1.sample_baked(float(s1))
				var s2_start = s1 + 80 if name1 == name2 else 0
				for s2 in range(s2_start, int(len2), 2):
					if name1 == name2 and (float(s1) + (len2 - float(s2)) < 80.0):
						continue
					var p2 = c2.sample_baked(float(s2))
					var h_dist = Vector2(p1.x - p2.x, p1.z - p2.z).length()
					var v_diff = p1.y - p2.y
					# If horizontal distance is small and p1 is above p2
					if h_dist < 14.0 and v_diff > 1.5:
						print("  %s s1=%d (%.1f, %.1f, %.1f) is ABOVE %s s2=%d (%.1f, %.1f, %.1f) | h_dist=%.1f, v_diff=%.1f" % [
							name1, s1, p1.x, p1.y, p1.z, name2, s2, p2.x, p2.y, p2.z, h_dist, v_diff
						])

	quit(0)
