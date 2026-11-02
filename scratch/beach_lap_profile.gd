extends SceneTree
# Prints, every `step` metres of z along Bloombay's west beach, the waterline's x and where the lap's
# racing line crosses that z (the nearest points within 40m of the waterline): for placing things on the
# sand between the two. -s, headless, -- [z0=-400] [z1=400] [step=25]
func _init() -> void:
	var z0 := -400.0
	var z1 := 400.0
	var step := 25.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("z0="): z0 = float(a.substr(3))
		if a.begins_with("z1="): z1 = float(a.substr(3))
		if a.begins_with("step="): step = float(a.substr(5))
	var lvl: Node = (load("res://levels/BloombayDunesLevel.tscn") as PackedScene).instantiate()
	var path := lvl.find_child("TrackPath", true, false) as Path3D
	var curve := path.curve
	var tg := load("res://TerrainGenerator.gd")
	var pts := curve.get_baked_points()
	var z := z0
	while z <= z1:
		var shore: float = tg.bloombay_shore_x(z)
		var xs := []
		for i in pts.size() - 1:
			var p: Vector3 = path.transform * pts[i]
			var q: Vector3 = path.transform * pts[i + 1]
			if (p.z - z) * (q.z - z) <= 0.0 and absf(q.z - p.z) > 0.0001:
				var x := lerpf(p.x, q.x, (z - p.z) / (q.z - p.z))
				if x < shore + 60.0:
					xs.append(snappedf(x, 0.1))
		print("z %6.0f  waterline x %6.1f  lap x %s" % [z, shore, xs])
		z += step
	lvl.free()
	quit()
