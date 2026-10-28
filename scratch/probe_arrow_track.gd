extends SceneTree
# Finds where the track is near Rock5 and ArrowSign, the driver's view approaching the turn,
# and samples the top surface of Rock5 around the arrow sign.

func _initialize():
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	for i in 5: await process_frame
	await physics_frame
	
	var arrow: Node3D = lvl.get_node("ArrowSign")
	var rock: Node3D = lvl.get_node("Rock5")
	var track_path: Path3D = lvl.get_node_or_null("TrackPath")
	
	print("TrackPath found: ", track_path != null)
	if track_path:
		var curve := track_path.curve
		print("Curve point count: ", curve.point_count)
		# Find closest point on curve to ArrowSign
		var closest_offset := curve.get_closest_offset(arrow.global_position)
		var closest_pt := curve.sample_baked(closest_offset)
		print("Closest track point to ArrowSign: ", closest_pt, " at offset: ", closest_offset)
		
		# Sample track before the sign (approaching)
		var approach_offset = wrapf(closest_offset - 40.0, 0, curve.get_baked_length())
		var approach_pt := curve.sample_baked(approach_offset)
		var approach_forward := (curve.sample_baked(approach_offset + 1.0) - approach_pt).normalized()
		print("Approach point (-40m): ", approach_pt, " forward: ", approach_forward)
		
		# Camera from driver's approach
		var cam := Camera3D.new()
		lvl.add_child(cam)
		cam.current = true
		cam.position = approach_pt + Vector3(0, 2.0, 0)
		cam.look_at(arrow.global_position + Vector3(0, 3, 0))
		for i in 15: await process_frame
		root.get_texture().get_image().save_png("/Users/jensbrocher/.gemini/antigravity-ide/brain/474e7d2d-135a-474d-a929-70b6ece5cc46/scratch/arrow_rock/driver_view_current.png")
		print("Saved driver_view_current.png")

	# Let's sample a grid of heights on Rock5 around (160..175, 45..65)
	var space_state: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	print("\n--- Rock5 Top Surface Grid (X from 165 to 175, Z from 50 to 62) ---")
	for z in range(50, 63, 2):
		var line := "Z=%2d: " % z
		for x in range(165, 176, 2):
			var ray_start := Vector3(x, 30, z)
			var ray_end := Vector3(x, 0, z)
			var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			var hit: Dictionary = space_state.intersect_ray(query)
			if hit:
				line += "X%d:y=%.1f " % [x, hit.position.y]
			else:
				line += "X%d:miss  " % x
		print(line)
		
	quit(0)
