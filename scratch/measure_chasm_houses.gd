extends SceneTree
## Headless measurement probe for the two houses in CanyonChasmLevel.tscn:
## 1) Prints their world transforms, nearest track points, and ground heights at their footprints in CanyonChasmLevel.
## 2) Slices the FBX vertex clouds (at their level scales: 45 for LargeHouse, 35 for House) to report exact part dimensions.

func _initialize() -> void:
	var lvl_ps: PackedScene = load("res://levels/CanyonChasmLevel.tscn")
	var lvl: Node3D = lvl_ps.instantiate()
	root.add_child(lvl)
	for i in 5:
		await process_frame
	await physics_frame

	var path: Path3D = lvl.get_node("TrackPath")
	var curve := path.curve
	var space := lvl.get_world_3d().direct_space_state

	for node_name in ["LargeHouse", "House"]:
		var n: Node3D = lvl.get_node_or_null(node_name)
		if n == null:
			continue
		var pos := n.global_position
		var basis := n.global_transform.basis
		var scl := basis.get_scale()
		var rot_deg := basis.orthonormalized().get_euler() * (180.0 / PI)
		var closest_off := curve.get_closest_offset(path.to_local(pos))
		var closest_pt := path.to_global(curve.sample_baked(closest_off))
		var dir_to_road := (closest_pt - pos)
		var local_dir_to_road := basis.orthonormalized().inverse() * dir_to_road.normalized()
		print("=== %s in CanyonChasmLevel ===" % node_name)
		print("  global_pos = %s  scale = %s  rot_deg = %s" % [pos, scl, rot_deg])
		print("  closest road pt = %s (dist = %.2fm, local dir to road = %s)" % [
			closest_pt, dir_to_road.length(), local_dir_to_road
		])
		# Raycast terrain/rock height around the footprint (excluding the house's own collider)
		var ex: Array[RID] = []
		for body in lvl.find_children("Col_*" + node_name + "*", "StaticBody3D", true, false):
			ex.append(body.get_rid())
		var min_ground_y := 9999.0
		var max_ground_y := -9999.0
		for dx in [-14.0, -7.0, 0.0, 7.0, 14.0]:
			for dz in [-14.0, -7.0, 0.0, 7.0, 14.0]:
				var wp := pos + basis.orthonormalized() * Vector3(dx, 0.0, dz)
				var q := PhysicsRayQueryParameters3D.create(wp + Vector3(0, 50, 0), wp + Vector3(0, -50, 0))
				q.exclude = ex
				var hit := space.intersect_ray(q)
				if not hit.is_empty():
					var hy: float = hit["position"].y
					min_ground_y = minf(min_ground_y, hy)
					max_ground_y = maxf(max_ground_y, hy)
		print("  ground y under footprint: min=%.2f max=%.2f (house origin y=%.2f, sink needed=%.2f)" % [
			min_ground_y, max_ground_y, pos.y, pos.y - min_ground_y
		])

	# Detailed slice analysis of the two FBX meshes in their scaled local metre frame
	_analyze_fbx("LargeHouse", "res://models/desert/2f1728e226824507fc3188405c2c7935.fbx", 45.0)
	_analyze_fbx("House", "res://models/desert/49ac41a0567226438249fc402b0d629c.fbx", 35.0)

	quit()


func _analyze_fbx(label: String, path: String, level_scale: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = mi.mesh
	var xform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * level_scale), Vector3.ZERO) * mi.transform
	var arr := mesh.surface_get_arrays(0)
	var raw_verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var verts := PackedVector3Array()
	verts.resize(raw_verts.size())
	var bmin := Vector3(9999, 9999, 9999)
	var bmax := Vector3(-9999, -9999, -9999)
	for i in raw_verts.size():
		var v := xform * raw_verts[i]
		verts[i] = v
		bmin = bmin.min(v)
		bmax = bmax.max(v)
	print("\n=== %s Mesh Analysis (scale %.1f, %d verts) ===" % [label, level_scale, verts.size()])
	print("  bounds: X [%.2f .. %.2f] (w=%.2f), Y [%.2f .. %.2f] (h=%.2f), Z [%.2f .. %.2f] (d=%.2f)" % [
		bmin.x, bmax.x, bmax.x - bmin.x,
		bmin.y, bmax.y, bmax.y - bmin.y,
		bmin.z, bmax.z, bmax.z - bmin.z
	])
	# Print Y-slices every 1.0m
	var y_step := 1.0
	var y := 0.0
	while y < bmax.y:
		var sx_min := 9999.0
		var sx_max := -9999.0
		var sz_min := 9999.0
		var sz_max := -9999.0
		var cnt := 0
		for v in verts:
			if v.y >= y and v.y < y + y_step:
				sx_min = minf(sx_min, v.x)
				sx_max = maxf(sx_max, v.x)
				sz_min = minf(sz_min, v.z)
				sz_max = maxf(sz_max, v.z)
				cnt += 1
		if cnt > 0:
			print("  Y [%.1f..%.1f]: X [%.2f..%.2f] (%.2fm)  Z [%.2f..%.2f] (%.2fm)  n=%d" % [
				y, y + y_step, sx_min, sx_max, sx_max - sx_min, sz_min, sz_max, sz_max - sz_min, cnt
			])
		y += y_step

	# Also print X-slices (left-to-right sections) to see wings/gables/towers
	print("  --- X sections ---")
	var x_step := 2.5
	var x := bmin.x
	while x < bmax.x:
		var sy_max := -9999.0
		var sz_min := 9999.0
		var sz_max := -9999.0
		var cnt := 0
		for v in verts:
			if v.x >= x and v.x < x + x_step:
				sy_max = maxf(sy_max, v.y)
				sz_min = minf(sz_min, v.z)
				sz_max = maxf(sz_max, v.z)
				cnt += 1
		if cnt > 0:
			print("  X [%.1f..%.1f]: maxY=%.2f  Z [%.2f..%.2f] (%.2fm)  n=%d" % [
				x, x + x_step, sy_max, sz_min, sz_max, sz_max - sz_min, cnt
			])
		x += x_step
	inst.free()

