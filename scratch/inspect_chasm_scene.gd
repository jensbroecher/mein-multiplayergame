extends SceneTree
## Headless probe of CanyonChasmLevel.tscn: inspects Windmill local parts (in metres),
## Barrier local mesh vertices/axes, and candidate CasitaHouse sites along TrackPath.

func _initialize() -> void:
	var lvl: Node3D = (load("res://levels/CanyonChasmLevel.tscn") as PackedScene).instantiate()
	root.add_child(lvl)
	for i in 4:
		await process_frame
	await physics_frame

	var wm: Node3D = lvl.get_node_or_null("Windmill")
	if wm:
		# Unscaled basis at Windmill origin
		var wm_unscaled := Transform3D(wm.global_transform.basis.orthonormalized(), wm.global_position)
		var inv_u := wm_unscaled.affine_inverse()
		print("=== WINDMILL IN METRES (unscaled frame at wm.global_position) ===")
		for mi in wm.find_children("*", "MeshInstance3D", true, false):
			var lb: AABB = mi.get_aabb()
			var b_m := AABB()
			for c in 8:
				var wp: Vector3 = mi.global_transform * lb.get_endpoint(c)
				var lp: Vector3 = inv_u * wp
				b_m = AABB(lp, Vector3.ZERO) if c == 0 else b_m.expand(lp)
			print("  %-10s center=%s size=%s min=%s max=%s" % [mi.name, b_m.get_center(), b_m.size, b_m.position, b_m.end])

	print("\n=== BARRIER DETAILS ===")
	for bname in ["Barrier", "Barrier2"]:
		var b: Node3D = lvl.get_node_or_null(bname)
		if b:
			var bu := Transform3D(b.global_transform.basis.orthonormalized(), b.global_position)
			var inv_b := bu.affine_inverse()
			for mi in b.find_children("*", "MeshInstance3D", true, false):
				var lb: AABB = mi.get_aabb()
				var bm := AABB()
				for c in 8:
					var wp: Vector3 = mi.global_transform * lb.get_endpoint(c)
					var lp: Vector3 = inv_b * wp
					bm = AABB(lp, Vector3.ZERO) if c == 0 else bm.expand(lp)
				print("  %s: mi.xform=%s unscaled_local_aabb=%s center=%s size=%s" % [
					bname, mi.transform, bm, bm.get_center(), bm.size
				])

	print("\n=== CANDIDATE CASITA HOUSE SITES ===")
	var space := lvl.get_world_3d().direct_space_state
	var curve: Curve3D = (lvl.get_node("TrackPath") as Path3D).curve
	var candidates := [
		["WestStraight_Out", Vector3(-232.0, 0.0, 65.0), 90.0],
		["WestCurve_North", Vector3(-165.0, 0.0, -95.0), 135.0],
		["StartStraight_Left", Vector3(-36.0, 0.0, 85.0), 90.0],
		["StartStraight_Right", Vector3(36.0, 0.0, 5.0), -90.0],
		["EastStraight_Out", Vector3(246.0, 0.0, -20.0), -110.0],
		["SouthWest_Corner", Vector3(-155.0, 0.0, 232.0), 140.0],
	]
	for cand in candidates:
		var p: Vector3 = cand[1]
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 120.0, p.z), Vector3(p.x, -50.0, p.z))
		var hit := space.intersect_ray(q)
		var gy: float = hit["position"].y if not hit.is_empty() else -999.0
		# Check 4 corners of a 22x20m footprint
		var min_y := gy
		var max_y := gy
		for dx in [-10.0, 10.0]:
			for dz in [-9.0, 9.0]:
				var h2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x + dx, 120.0, p.z + dz), Vector3(p.x + dx, -50.0, p.z + dz)))
				if not h2.is_empty():
					min_y = minf(min_y, h2["position"].y)
					max_y = maxf(max_y, h2["position"].y)
		var cp := curve.get_closest_point(Vector3(p.x, gy, p.z))
		var rdist := Vector2(p.x, p.z).distance_to(Vector2(cp.x, cp.z))
		print("  %-20s pos=(%.1f, %.2f, %.1f) footprint_y=[%.2f..%.2f] road_dist=%.1fm road_y=%.1f" % [
			cand[0], p.x, gy, p.z, min_y, max_y, rdist, cp.y
		])

	quit()
