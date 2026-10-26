extends SceneTree
## Prints a stretch of a level's lap: heading, turn radius, the road's height and the ground beside it,
## and which checkpoints, boost pads and item spots lie along it. Headless:
##   Godot --headless --path . -s res://scratch/lakeside_bend_probe.gd -- [level=res://levels/LakesideLevel.tscn] [s0=380] [s1=780] [step=10]

func _init() -> void:
	var args := {"level": "res://levels/LakesideLevel.tscn", "s0": "380", "s1": "780", "step": "10"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var level: Node3D = (load(args["level"]) as PackedScene).instantiate()
	var curve: Curve3D = (level.get_node("TrackPath") as Path3D).curve
	var length := curve.get_baked_length()
	var tg := level.get_node_or_null("TerrainGenerator")
	var road_y: float = float(tg.get("road_y_offset")) if tg else 0.0
	var space_mesh: ArrayMesh = load("res://generated/terrain_visual.res")
	var verts: PackedVector3Array = space_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ground := func(x: float, z: float) -> float:
		var gx: float = (x + 1000.0) / 2.0
		var gz: float = (z + 1000.0) / 2.0
		var x0 := clampi(floori(gx), 0, 999)
		var z0 := clampi(floori(gz), 0, 999)
		var fx := gx - x0
		var fz := gz - z0
		var st := 1001
		var h00 := verts[z0 * st + x0].y
		var h10 := verts[z0 * st + x0 + 1].y
		var h01 := verts[(z0 + 1) * st + x0].y
		var h11 := verts[(z0 + 1) * st + x0 + 1].y
		if fx + fz <= 1.0:
			return h00 + fx * (h10 - h00) + fz * (h01 - h00)
		return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)
	var s0 := float(args["s0"])
	var s1 := float(args["s1"])
	var step := float(args["step"])
	print("lap %.0fm, road_y %.2f" % [length, road_y])
	print("   s      x       z     head  R(+right)   road_y  ground  g-12   g+12   g-20   g+20")
	var s := s0
	while s <= s1:
		var p := curve.sample_baked(fposmod(s, length))
		var a := curve.sample_baked(fposmod(s - 4.0, length))
		var b := curve.sample_baked(fposmod(s + 4.0, length))
		var f0 := curve.sample_baked(fposmod(s - 8.0, length)) - a
		var f1 := b - p
		var h0 := atan2(f0.x, -f0.z)
		var h1 := atan2(f1.x, -f1.z)
		var dh := wrapf(h1 - h0, -PI, PI)
		var radius := 8.0 / dh if absf(dh) > 1e-4 else INF
		var fwd := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var right := Vector3(-fwd.z, 0, fwd.x)
		var row := "%6.0f %7.1f %7.1f %6.1f %9.0f %8.2f" % [s, p.x, p.z, rad_to_deg(atan2(fwd.x, -fwd.z)), radius, p.y + road_y]
		row += " %7.2f" % ground.call(p.x, p.z)
		for lat in [-12.0, 12.0, -20.0, 20.0]:
			var q: Vector3 = p + right * lat
			row += " %6.1f" % ground.call(q.x, q.z)
		print(row)
		s += step
	for group in ["Checkpoints", "BoostPads", "ItemBoxes", "ItemBoxSpawns"]:
		var holder := level.get_node_or_null(group)
		if holder == null:
			continue
		for c in holder.get_children():
			if c is Node3D:
				var off := curve.get_closest_offset((c as Node3D).position)
				if off >= s0 - 30.0 and off <= s1 + 30.0:
					print("%s/%s at s %.0f %s" % [group, c.name, off, (c as Node3D).position])
	level.free()
	quit()
