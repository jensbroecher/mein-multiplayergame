extends SceneTree
## Prints Mina del Viento's ground (regenerate_mina.gd's own heights, built headless) along a line: every `step` metres
## from x0,z0 to x1,z1 (more points chain on), with the distance to the route.
##   Godot --headless --path . -s res://scratch/mina_line_profile.gd -- x0,z0 x1,z1 [...] [step=100]

func _init() -> void:
	var pts: Array = []
	var step := 100.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("step="):
			step = float(a.substr(5))
		else:
			var xz := a.split(",")
			pts.append(Vector2(float(xz[0]), float(xz[1])))
	var gen = load("res://regenerate_mina.gd").new()
	gen._init_noise()
	gen._solve_route()
	gen._build_profile()
	gen._add_samples()
	gen._plan_pads()
	gen._plan_signs()
	gen._plan_bumps()
	gen._build_heights()
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		for k in range(n + (1 if i == pts.size() - 2 else 0)):
			var p: Vector2 = a.lerp(b, float(k) / n)
			print("(%7.0f, %7.0f) ground %7.1f  route %6.0fm" % [p.x, p.y, gen._ground_at(p.x, p.y), gen._route_dist(p)])
	gen.free()
	quit(0)
