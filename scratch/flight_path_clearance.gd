extends SceneTree
## Checks the loops a level's AirTaxis node flies against everything drawn in the level: every route is sampled every
## `step` metres and, at each sample, short segments are cast `side` metres out each way across and `up`/`down` metres
## up and down against the triangles of every mesh (and every MultiMesh instance) whose bounds come near. Prints each
## route's hits (where, what), or CLEAR.
##   Godot --headless --path . -s res://scratch/flight_path_clearance.gd -- <level.tscn> [step=4] [side=8] [up=5] [down=6]

var _tm_cache := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := "res://levels/TianqiaoLevel.tscn"
	var step := 4.0
	var side := 8.0
	var up := 5.0
	var down := 6.0
	for a in args:
		if a.begins_with("res://"):
			level_path = a
		elif a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("side="):
			side = float(a.substr(5))
		elif a.begins_with("up="):
			up = float(a.substr(3))
		elif a.begins_with("down="):
			down = float(a.substr(5))
	var level: Node = (load(level_path) as PackedScene).instantiate()
	var taxis: Node = level.get_node_or_null("AirTaxis")
	if taxis == null:
		print("no AirTaxis node")
		quit()
		return
	# Everything drawn, as [global AABB, TriangleMesh, global transform, name].
	var items: Array = []
	_collect(level, Transform3D.IDENTITY, items, taxis)
	print("%d meshes and instances" % items.size())
	var routes: Array = taxis.get("routes")
	var dirs: Array = [Vector3(side, 0, 0), Vector3(-side, 0, 0), Vector3(0, 0, side), Vector3(0, 0, -side), Vector3(0, up, 0), Vector3(0, -down, 0)]
	var reach := maxf(side, maxf(up, down))
	for ri in range(routes.size()):
		var pts: PackedVector3Array = (routes[ri] as Dictionary)["points"]
		var c: Curve3D = load("res://AirTaxis.gd")._loop_curve(pts)
		var length: float = c.get_baked_length()
		var hits := {}
		var lowest := INF
		var s := 0.0
		while s < length:
			var p: Vector3 = c.sample_baked(s, true)
			for it in items:
				var bb: AABB = it[0]
				if not bb.grow(reach).has_point(p):
					continue
				var tm: TriangleMesh = it[1]
				var inv: Transform3D = (it[2] as Transform3D).affine_inverse()
				for d in dirs:
					var r: Dictionary = tm.intersect_segment(inv * p, inv * (p + (d as Vector3)))
					if not r.is_empty():
						var nm: String = it[3]
						var hp: Vector3 = (it[2] as Transform3D) * (r["position"] as Vector3)
						lowest = minf(lowest, hp.distance_to(p))
						if not hits.has(nm):
							hits[nm] = []
						if (hits[nm] as Array).size() < 4:
							(hits[nm] as Array).append("s %.0f at (%.0f, %.0f, %.0f) %.1fm" % [s, p.x, p.y, p.z, hp.distance_to(p)])
						break
			s += step
		if hits.is_empty():
			print("route %d (%.0fm): CLEAR" % [ri, length])
		else:
			print("route %d (%.0fm): %d things within reach, nearest %.1fm" % [ri, length, hits.size(), lowest])
			for nm in hits:
				print("   %s: %s" % [nm, ", ".join(hits[nm])])
	level.free()
	quit()


func _collect(n: Node, xf: Transform3D, items: Array, skip: Node) -> void:
	if n == skip:
		return
	var g: Transform3D = xf
	if n is Node3D:
		g = xf * (n as Node3D).transform
		if not (n as Node3D).visible:
			return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		var tm := _tm(m)
		if tm:
			items.append([g * m.get_aabb(), tm, g, String(n.get_path()) if n.is_inside_tree() else String(n.name)])
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		var tm2 := _tm(mm.mesh) if mm.mesh else null
		if tm2:
			var buf: PackedFloat32Array = mm.buffer
			var stride: int = 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			for i in range(mm.instance_count):
				var o: int = i * stride
				if o + 12 > buf.size():
					break
				var t := Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
					Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
				var gi: Transform3D = g * t
				items.append([gi * mm.mesh.get_aabb(), tm2, gi, String(n.name) + "#%d" % i])
	for ch in n.get_children():
		_collect(ch, g, items, skip)


func _tm(m: Mesh) -> TriangleMesh:
	if _tm_cache.has(m):
		return _tm_cache[m]
	var tm: TriangleMesh = m.generate_triangle_mesh()
	_tm_cache[m] = tm
	return tm
