extends SceneTree

func _init():
	var scene = load("res://levels/GlacierHighwayLevel.tscn")
	var level = scene.instantiate()
	root.add_child(level)
	var curve: Curve3D = level.get_node("TrackPath").curve
	var total_len = curve.get_baked_length()

	print("Sampling points from s = total_len - 150m to start + 50m:")
	for s in range(int(total_len) - 150, int(total_len), 5):
		var p = curve.sample_baked(float(s))
		var p_next = curve.sample_baked(minf(total_len, float(s + 1)))
		var fwd = (p_next - p).normalized()
		var right = Vector3(-fwd.z, 0, fwd.x).normalized()
		var left_edge = p - right * 8.0
		var right_edge = p + right * 8.0
		print("  s=%4d: center=(%5.1f, %5.1f) | L_edge=(%5.1f, %5.1f) | R_edge=(%5.1f, %5.1f)" % [
			s, p.x, p.z, left_edge.x, left_edge.z, right_edge.x, right_edge.z
		])

	print("\nStart of track (s = 0 to 60):")
	for s in range(0, 60, 5):
		var p = curve.sample_baked(float(s))
		var p_next = curve.sample_baked(float(s + 1))
		var fwd = (p_next - p).normalized()
		var right = Vector3(-fwd.z, 0, fwd.x).normalized()
		var left_edge = p - right * 8.0
		var right_edge = p + right * 8.0
		print("  s=%4d: center=(%5.1f, %5.1f) | L_edge=(%5.1f, %5.1f) | R_edge=(%5.1f, %5.1f)" % [
			s, p.x, p.z, left_edge.x, left_edge.z, right_edge.x, right_edge.z
		])

	quit(0)
