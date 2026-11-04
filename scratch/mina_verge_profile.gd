extends SceneTree
## Prints the ground beside Mina del Viento's road (from regenerate_mina.gd's own heights, built headless in ~10s)
## against the road's height, at the distances given: one line per s, the ground at each lateral (right of travel +).
##   Godot --headless --path . -s res://scratch/mina_verge_profile.gd -- 1205 1560 ... [lats=-20,-16,...]

func _init() -> void:
	var lats: Array = [-22.0, -18.0, -15.0, -12.0, -10.0, -8.5, 0.0, 8.5, 10.0, 12.0, 15.0, 18.0, 22.0]
	var ss: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lats="):
			lats = Array(a.substr(5).split(",")).map(func(v): return float(v))
		else:
			ss.append(float(a))
	var gen = load("res://regenerate_mina.gd").new()
	gen._init_noise()
	gen._solve_route()
	gen._build_profile()
	gen._add_samples()
	gen._plan_pads()
	gen._plan_signs()
	gen._plan_bumps()
	gen._build_heights()
	print("lat:   " + " ".join(lats.map(func(l): return "%6.1f" % l)))
	for s in ss:
		var row: Array = []
		for l in lats:
			var p: Vector3 = gen._spot(s, l, 0.0)["pos"]
			row.append("%6.1f" % (gen._ground_at(p.x, p.z) - gen._road_y(s)))
		print("s=%4.0f " % s + " ".join(row))
	gen.free()
	quit(0)
