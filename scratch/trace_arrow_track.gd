extends SceneTree
func _initialize():
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	var track_path: Path3D = lvl.get_node("TrackPath")
	var curve = track_path.curve
	var off_base = 1015.0
	for d in range(-40, 80, 10):
		var off = off_base + d
		var pt = curve.sample_baked(off)
		var fwd = (curve.sample_baked(off + 1.0) - pt).normalized()
		print("off=%6.1f pt=(%6.1f, %5.1f, %6.1f) fwd=(%5.2f, %5.2f, %5.2f)" % [off, pt.x, pt.y, pt.z, fwd.x, fwd.y, fwd.z])
	quit(0)
