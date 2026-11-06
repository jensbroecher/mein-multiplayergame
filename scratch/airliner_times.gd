extends SceneTree
## When a level's airliners are where, to aim shots at them (lap_shots' clock= holds every flight at a clock reading):
## for each route of its Airliners node, every 10s of a flight within 4.2km of the lap's middle, the clock reading (the
## flight number `k` that day: every * k + phase + its time) and where it is. Headless:
##   Godot --headless --path . -s res://scratch/airliner_times.gd -- res://levels/X.tscn [k=100]

const Airliners = preload("res://Airliners.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var lp: String = args[0]
	var k := 100
	for a in args.slice(1):
		if a.begins_with("k="):
			k = int(a.substr(2))
	var root: Node = (load(lp) as PackedScene).instantiate()
	var air := root.find_child("Airliners", true, false)
	var path: Path3D = root.get_node("TrackPath")
	var o := Vector2.ZERO
	var n := 0
	var s := 0.0
	while s < path.curve.get_baked_length():
		var p := path.curve.sample_baked(s)
		o += Vector2(p.x, p.z)
		n += 1
		s += 10.0
	o /= float(n)
	print("lap middle ", o)
	var routes: Array = air.get("routes")
	for ri in range(routes.size()):
		var rt: Dictionary = Airliners.build_route(routes[ri])
		var t: PackedFloat32Array = rt.t
		var pos: PackedVector3Array = rt.pos
		var every: float = rt.every
		print("route %d %s every %.0fs phase %.1fs, %.0fs long" % [ri, rt.kind, every, float(rt.phase), float(rt.total)])
		var u := 0.0
		while u < float(rt.total):
			var i: int = clampi(t.bsearch(u, true) - 1, 0, t.size() - 2)
			var q: Vector3 = pos[i]
			var dd: float = Vector2(q.x, q.z).distance_to(o)
			if dd < 4200.0:
				print("  %4.0fs  clock=%.0f  at (%6.0f, %5.0f, %6.0f)  %5.0fm from the lap's middle" % [u, every * float(k) + float(rt.phase) + u, q.x, q.y, q.z, dd])
			u += 10.0
	root.free()
	quit()
