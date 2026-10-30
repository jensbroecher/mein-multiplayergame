extends SceneTree

## Pinecrest Ridge road audit, headless, from the saved level (no physics):
##   Godot --headless --path . -s res://scratch/pinecrest_road_probe.gd -- [level=res://levels/PinecrestRidgeLevel.tscn]
##       [step=2] [lats=-7,-4,0,4,7]
## Prints, along the lap:
##   BURIED  stretches where the visual ground stands over the asphalt (at any of `lats`),
##   TIGHT   corners whose radius is under the curbs' half width (the ribbon folds on its inside),
##   NEAR    where another leg of the lap passes within 30m in plan (and how far above or below),
## and every dressing MultiMesh instance standing within the curbs (ON ROAD; not the meadow's grass).

const ROAD_Y := 0.06
const CURB_HALF := 8.5


func _init() -> void:
	var level_path := "res://levels/PinecrestRidgeLevel.tscn"
	var step := 2.0
	var lats := PackedFloat32Array([-7.0, -4.0, 0.0, 4.0, 7.0])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("lats="):
			lats = PackedFloat32Array(Array(a.substr(5).split(",")).map(func(x): return float(x)))
	var level: Node3D = (load(level_path) as PackedScene).instantiate()
	var path: Path3D = level.get_node("TrackPath")
	# Closed as TerrainGenerator lays the road: the TrackPath stops short of the start line.
	var open: Curve3D = path.curve
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	for i in range(open.point_count):
		curve.add_point(open.get_point_position(i), open.get_point_in(i), open.get_point_out(i))
	curve.add_point(open.get_point_position(0), open.get_point_in(0), open.get_point_out(0))
	var length := curve.get_baked_length()
	var tg: Node = level.get_node("TerrainGenerator")
	var res: int = tg.get("terrain_resolution")
	var size: Vector2 = tg.get("terrain_size")
	var tv: MeshInstance3D = tg.get_node("Terrain_Visual")
	var verts: PackedVector3Array = tv.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var stride := res + 1
	var start := -size.x * 0.5
	var cell := size.x / float(res)
	var ground := func(x: float, z: float) -> float:
		var gx := (x - start) / cell
		var gz := (z - start) / cell
		var x0 := clampi(floori(gx), 0, res - 1)
		var z0 := clampi(floori(gz), 0, res - 1)
		var fx := gx - x0
		var fz := gz - z0
		var h00 := verts[z0 * stride + x0].y
		var h10 := verts[z0 * stride + x0 + 1].y
		var h01 := verts[(z0 + 1) * stride + x0].y
		var h11 := verts[(z0 + 1) * stride + x0 + 1].y
		if fx + fz <= 1.0:
			return h00 + fx * (h10 - h00) + fz * (h01 - h00)
		return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)
	print("lap %.0fm, terrain %dx%d, %.2fm cells" % [length, res, res, cell])

	var samples := PackedVector3Array()
	var s := 0.0
	while s < length:
		samples.append(curve.sample_baked(s))
		s += 1.0

	# Buried: the ground over the asphalt.
	var run_start := -1.0
	var run_max := 0.0
	var run_lat := 0.0
	s = 0.0
	while s <= length:
		var p := curve.sample_baked(fposmod(s, length))
		var f := curve.sample_baked(fposmod(s + 0.6, length)) - curve.sample_baked(fposmod(s - 0.6, length))
		f.y = 0.0
		f = f.normalized()
		var r := Vector3(-f.z, 0.0, f.x)
		var worst := -INF
		var worst_lat := 0.0
		for lat in lats:
			var q := p + r * lat
			var over: float = ground.call(q.x, q.z) - (p.y + ROAD_Y)
			if over > worst:
				worst = over
				worst_lat = lat
		if worst > 0.02:
			if run_start < 0.0:
				run_start = s
				run_max = 0.0
			if worst > run_max:
				run_max = worst
				run_lat = worst_lat
		elif run_start >= 0.0:
			print("BURIED s %.0f-%.0f (%.0fm): ground up to %.2fm over the road at lat %+.0f, at (%.0f, %.0f, %.0f)" % [
					run_start, s, s - run_start, run_max, run_lat, p.x, p.y, p.z])
			run_start = -1.0
		s += step

	# Tight corners: radius from the heading change over +-3m.
	var tight_start := -1.0
	var tight_min := INF
	s = 0.0
	while s <= length:
		var a := curve.sample_baked(fposmod(s - 3.0, length))
		var b := curve.sample_baked(fposmod(s, length))
		var c := curve.sample_baked(fposmod(s + 3.0, length))
		var v1 := Vector2(b.x - a.x, b.z - a.z)
		var v2 := Vector2(c.x - b.x, c.z - b.z)
		var ang := absf(v1.angle_to(v2))
		var radius := 3.0 / maxf(ang, 1e-4)
		if radius < CURB_HALF + 2.0:
			if tight_start < 0.0:
				tight_start = s
				tight_min = INF
			tight_min = minf(tight_min, radius)
		elif tight_start >= 0.0:
			var m := curve.sample_baked(fposmod((tight_start + s) * 0.5, length))
			print("TIGHT s %.0f-%.0f: radius down to %.1fm at (%.0f, %.0f, %.0f)" % [tight_start, s, tight_min, m.x, m.y, m.z])
			tight_start = -1.0
		s += 0.5

	# Other legs close by in plan.
	var near_start := -1
	var near_info := ""
	for i in range(0, samples.size(), 4):
		var p := samples[i]
		var best := INF
		var best_dy := 0.0
		var best_j := -1
		for j in range(samples.size()):
			var ds := absi(i - j)
			ds = mini(ds, samples.size() - ds)
			if ds < 60:
				continue
			var d := Vector2(p.x - samples[j].x, p.z - samples[j].z).length()
			if d < best:
				best = d
				best_dy = samples[j].y - p.y
				best_j = j
		if best < 30.0:
			if near_start < 0:
				near_start = i
			near_info = "nearest %.1fm to s %d (%+.1fm)" % [best, best_j, best_dy]
		elif near_start >= 0:
			print("NEAR s %d-%d: %s" % [near_start, i, near_info])
			near_start = -1

	# Dressing standing on the road.
	var on_road := 0
	var dressing := level.get_node_or_null("PinecrestDressing")
	if dressing:
		for mmi in dressing.find_children("*", "MultiMeshInstance3D", true, false):
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			# The meadow's cells share one MultiMesh of tufts at y = 0 that its shader stands on the ground
			# (or hides) by the grass map: their instances aren't where the grass grows.
			if mm == null or str(mmi.get_parent().name) == "Meadow":
				continue
			var buf := mm.buffer
			var stride_b := 12
			if mm.use_colors:
				stride_b += 4
			if mm.use_custom_data:
				stride_b += 4
			var xf: Transform3D = (mmi as Node3D).transform
			var node := mmi as Node3D
			while node.get_parent() is Node3D:
				node = node.get_parent()
				xf = node.transform * xf
			for k in range(mm.instance_count):
				var o := xf * Vector3(buf[k * stride_b + 3], buf[k * stride_b + 7], buf[k * stride_b + 11])
				var cp := curve.get_closest_point(o)
				var d := Vector2(o.x - cp.x, o.z - cp.z).length()
				if d < CURB_HALF and absf(o.y - cp.y) < 3.0:
					on_road += 1
					if on_road <= 40:
						print("ON ROAD %s #%d at (%.1f, %.1f, %.1f), %.1fm off the centreline at s %.0f" % [
								mmi.name, k, o.x, o.y, o.z, d, curve.get_closest_offset(o)])
	print("%d dressing instances on the road" % on_road)
	level.free()
	quit(0)
