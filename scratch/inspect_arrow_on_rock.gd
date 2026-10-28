extends SceneTree
# -s windowed: renders Canyon Chasm's Rock5 and ArrowSign from multiple viewpoints
# and prints detailed geometric information about the sign's post, the rock surface,
# and how the sign meets the rock.
# Outputs screenshots to the specified directory.

func _initialize():
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "/tmp"
	
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	for i in 5: await process_frame
	await physics_frame
	
	var arrow: Node3D = lvl.get_node_or_null("ArrowSign")
	var rock: Node3D = lvl.get_node_or_null("Rock5")
	
	if not arrow or not rock:
		print("ERROR: ArrowSign or Rock5 not found!")
		quit(1)
		return
		
	print("=== ARROW SIGN ===")
	print("Global Transform: ", arrow.global_transform)
	print("Global Origin: ", arrow.global_position)
	
	# Find arrow mesh
	var arrow_mi: MeshInstance3D = arrow.find_children("*", "MeshInstance3D", true, false)[0]
	var arrow_aabb: AABB = arrow_mi.mesh.get_aabb()
	print("Arrow Mesh Local AABB: ", arrow_aabb)
	print("Arrow Mesh World AABB: ", arrow_mi.global_transform * arrow_aabb)
	
	print("=== ROCK5 ===")
	print("Rock Global Transform: ", rock.global_transform)
	print("Rock Global Origin: ", rock.global_position)
	var rock_mi: MeshInstance3D
	for child in rock.find_children("*", "MeshInstance3D", true, false):
		rock_mi = child
		break
	if rock_mi:
		var rock_aabb: AABB = rock_mi.mesh.get_aabb()
		print("Rock Mesh Local AABB: ", rock_aabb)
		print("Rock Mesh World AABB: ", rock_mi.global_transform * rock_aabb)
		
	# Post bottom in world coords:
	# In ArrowSignCSG: post is at x = -0.73, bottom is at y = -POST_SINK = -0.5
	var post_bottom_local := Vector3(-0.73, -0.5, 0.0)
	var post_bottom_world := arrow.global_transform * post_bottom_local
	print("Post Bottom World: ", post_bottom_world)

	# Raycast down from above the post to see where the rock surface or ground is!
	var space_state: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	var ray_start := post_bottom_world + Vector3(0, 10, 0)
	var ray_end := post_bottom_world - Vector3(0, 20, 0)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit:
		print("Ray hit object: ", hit.collider.name, " at position: ", hit.position, " normal: ", hit.normal)
		var diff = post_bottom_world.y - hit.position.y
		print("Post bottom relative to hit surface: ", diff, " (positive means floating, negative means submerged)")
	else:
		print("Ray hit nothing!")

	# Now setup camera to take pictures
	var cam := Camera3D.new()
	lvl.add_child(cam)
	cam.current = true
	
	var focus_point := arrow.global_position + Vector3(0, 3, 0)
	var views := [
		["front", Vector3(1, 0.2, 1).normalized() * 18.0],
		["side", Vector3(-1, 0.3, 0.5).normalized() * 16.0],
		["close_base", Vector3(0.5, 0.1, 1).normalized() * 8.0],
		["high", Vector3(0.2, 0.9, 0.5).normalized() * 25.0],
	]
	
	for v in views:
		cam.position = focus_point + v[1]
		cam.look_at(focus_point)
		for i in 15: await process_frame
		var img := root.get_texture().get_image()
		var p := "%s/arrow_rock_%s.png" % [out_dir, v[0]]
		img.save_png(p)
		print("Saved ", p)
		
	quit(0)
