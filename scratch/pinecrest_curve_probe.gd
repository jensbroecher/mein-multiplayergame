extends SceneTree

## Pinecrest Ridge's lap as the generator builds it (no level, no terrain), headless:
##   Godot --headless --path . -s res://scratch/pinecrest_curve_probe.gd -- [min=12] [s0=] [s1=] [step=2]
## Lists each control point's kink in plan (the angle between its two handles; a kink is a corner in
## the road ribbon) and every stretch whose radius is under `min`, then, with s0/s1, the radius and
## height along that stretch.

func _init() -> void:
	var min_r := 12.0
	var s0 := -1.0
	var s1 := -1.0
	var step := 2.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("min="):
			min_r = float(a.substr(4))
		elif a.begins_with("s0="):
			s0 = float(a.substr(3))
		elif a.begins_with("s1="):
			s1 = float(a.substr(3))
		elif a.begins_with("step="):
			step = float(a.substr(5))
	var gen: Node = load("res://regenerate_pinecrest_ridge.gd").new()
	var path := Path3D.new()
	gen.call("_setup_track_curve", path)
	var open: Curve3D = path.curve
	# Closed the way TerrainGenerator lays the road (the first point again at the end).
	var c := Curve3D.new()
	c.bake_interval = 0.25
	for i in range(open.point_count):
		c.add_point(open.get_point_position(i), open.get_point_in(i), open.get_point_out(i))
	c.add_point(open.get_point_position(0), open.get_point_in(0), open.get_point_out(0))
	var length := c.get_baked_length()
	print("lap %.1fm (open %.1fm), %d points" % [length, open.get_baked_length(), open.point_count])
	for i in range(open.point_count):
		var pin := open.get_point_in(i)
		var pout := open.get_point_out(i)
		var a := Vector2(-pin.x, -pin.z)
		var b := Vector2(pout.x, pout.z)
		var kink := rad_to_deg(absf(a.angle_to(b))) if a.length() > 0.01 and b.length() > 0.01 else 0.0
		var p := open.get_point_position(i)
		print("pt %2d (%6.1f, %5.1f, %6.1f) s %6.1f  kink %5.1f deg%s" % [i, p.x, p.y, p.z,
				c.get_closest_offset(p), kink, "  <--" if kink > 3.0 else ""])
	var radius_at := func(s: float) -> float:
		var pa := c.sample_baked(fposmod(s - 3.0, length))
		var pb := c.sample_baked(fposmod(s, length))
		var pc := c.sample_baked(fposmod(s + 3.0, length))
		var v1 := Vector2(pb.x - pa.x, pb.z - pa.z)
		var v2 := Vector2(pc.x - pb.x, pc.z - pb.z)
		return 3.0 / maxf(absf(v1.angle_to(v2)), 1e-4)
	var t0 := -1.0
	var rmin := INF
	var s := 0.0
	while s <= length:
		var r: float = radius_at.call(s)
		if r < min_r:
			if t0 < 0.0:
				t0 = s
				rmin = INF
			rmin = minf(rmin, r)
		elif t0 >= 0.0:
			var m := c.sample_baked((t0 + s) * 0.5)
			print("TIGHT s %.0f-%.0f radius down to %.1fm at (%.0f, %.0f, %.0f)" % [t0, s, rmin, m.x, m.y, m.z])
			t0 = -1.0
		s += 0.5
	if s0 >= 0.0:
		s = s0
		while s <= s1:
			var p := c.sample_baked(fposmod(s, length))
			print("  s %6.1f (%6.1f, %5.1f, %6.1f) r %6.1f" % [s, p.x, p.y, p.z, radius_at.call(s)])
			s += step
	gen.free()
	quit(0)
