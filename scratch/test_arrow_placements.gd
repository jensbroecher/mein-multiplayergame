extends SceneTree
# Renders driver views and overview for candidate placements

func _initialize():
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	for i in 5: await process_frame
	await physics_frame
	
	var arrow: Node3D = lvl.get_node("ArrowSign")
	var rock: Node3D = lvl.get_node("Rock5")
	var track_path: Path3D = lvl.get_node("TrackPath")
	var curve := track_path.curve
	var space_state: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	
	var candidates := [
		["orig", 173.57, 57.05, 178.4, 13.69], # Original position
		["ledge_center", 170.0, 53.0, 178.4, -1.0],
		["ledge_front_right", 171.0, 54.0, 178.4, -1.0],
		["ledge_wide", 169.0, 54.0, 178.4, -1.0],
		["mid_shelf", 168.0, 52.0, 178.4, -1.0],
		["upper_tier", 163.5, 50.0, 178.4, -1.0],
	]
	
	var exclude_rids: Array[RID] = []
	for body in arrow.find_children("*", "CollisionObject3D", true, false):
		exclude_rids.append(body.get_rid())
	for body in lvl.find_children("Col_*ArrowSign*", "CollisionObject3D", true, false):
		exclude_rids.append(body.get_rid())
		
	var cam := Camera3D.new()
	lvl.add_child(cam)
	cam.current = true
	
	var pt_approach := curve.sample_baked(975.0) + Vector3(0, 2.0, 0)
	var pt_mid := curve.sample_baked(1005.0) + Vector3(0, 2.0, 0)
	var pt_overview := Vector3(188.0, 28.0, 35.0)
	
	for cand in candidates:
		var cname: String = cand[0]
		var px: float = cand[1]
		var pz: float = cand[2]
		var ry: float = cand[3]
		var fixed_y: float = cand[4]
		
		var surface_y: float = fixed_y
		if surface_y < 0:
			var query := PhysicsRayQueryParameters3D.create(Vector3(px, 35, pz), Vector3(px, 0, pz))
			query.exclude = exclude_rids
			var hit: Dictionary = space_state.intersect_ray(query)
			surface_y = hit.position.y if hit else 15.0
			
		var basis := Basis(Vector3.UP, deg_to_rad(ry))
		var offset_from_post := basis * Vector3(-0.73, 0, 0)
		var sign_pos := Vector3(px, surface_y, pz) - offset_from_post
		arrow.transform = Transform3D(basis, sign_pos)
		
		# View 1: approach (offset 975)
		cam.position = pt_approach
		cam.look_at(arrow.global_position + Vector3(0, 3.0, 0))
		for i in 8: await process_frame
		root.get_texture().get_image().save_png("/Users/jensbrocher/.gemini/antigravity-ide/brain/474e7d2d-135a-474d-a929-70b6ece5cc46/scratch/arrow_rock/v2_%s_approach.png" % cname)
		
		# View 2: mid (offset 1005)
		cam.position = pt_mid
		cam.look_at(arrow.global_position + Vector3(0, 2.5, 0))
		for i in 8: await process_frame
		root.get_texture().get_image().save_png("/Users/jensbrocher/.gemini/antigravity-ide/brain/474e7d2d-135a-474d-a929-70b6ece5cc46/scratch/arrow_rock/v2_%s_mid.png" % cname)
		
		# View 3: overview
		cam.position = pt_overview
		cam.look_at(arrow.global_position + Vector3(0, 1.0, 0))
		for i in 8: await process_frame
		root.get_texture().get_image().save_png("/Users/jensbrocher/.gemini/antigravity-ide/brain/474e7d2d-135a-474d-a929-70b6ece5cc46/scratch/arrow_rock/v2_%s_overview.png" % cname)

	print("All views rendered!")
	quit(0)
