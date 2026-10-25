extends Node

# Drops a cart into deep water from a height (as off the long bridge) and saves frames of what
# follows: WaterFx's big splash and foam, the flooded engine, the bubbles while it sinks, the respawn.
# Prints the cart's flood state as it goes. Windowed:
#   Godot --path . --resolution 1376x768 res://scratch/deep_water_test.tscn -- <out_dir>
#       [level=res://levels/LakesideLevel.tscn] [at=x,z] [height=25] [cam=dx,dy,dz] [times=0.1,0.3,...]
#       [follow=1] [vel=x,y,z] [pre=0.3,0.6]
# follow=1 shoots through the cart's own follower camera (the cart made the local player's), with
# shots `pre` seconds into the fall as well; vel= throws it in moving (as off a bridge).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var level_path := "res://levels/LakesideLevel.tscn"
	var at := Vector2(-450.0, -470.0)
	var height := 25.0
	var cam_off := Vector3(8.0, 4.0, 8.0)
	var times := [0.05, 0.25, 0.5, 0.9, 1.4, 2.2, 3.0, 4.2]
	var follow := false
	var vel := Vector3.ZERO
	var pre: Array = []
	for a in args.slice(1):
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("at="):
			var p := a.substr(3).split(",")
			at = Vector2(float(p[0]), float(p[1]))
		elif a.begins_with("height="):
			height = float(a.substr(7))
		elif a.begins_with("cam="):
			var c := a.substr(4).split(",")
			cam_off = Vector3(float(c[0]), float(c[1]), float(c[2]))
		elif a.begins_with("times="):
			times = Array(a.substr(6).split(",")).map(func(v): return float(v))
		elif a.begins_with("follow="):
			follow = a.substr(7) == "1"
		elif a.begins_with("vel="):
			var v := a.substr(4).split(",")
			vel = Vector3(float(v[0]), float(v[1]), float(v[2]))
		elif a.begins_with("pre="):
			pre = Array(a.substr(4).split(",")).map(func(v): return float(v))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var carts: Array = []
	while carts.is_empty():
		await get_tree().physics_frame
		carts = get_tree().get_nodes_in_group("player_carts")
	for i in 300:
		await get_tree().physics_frame
	var cart: RigidBody3D = carts[0]
	var surface: float = cart.water_surface_y
	var spot := Vector3(at.x, surface + height, at.y)
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	add_child(cam)
	cam.global_position = Vector3(at.x, surface, at.y) + cam_off
	cam.look_at(Vector3(at.x, surface + 1.5, at.y), Vector3.UP)
	cam.make_current()
	if follow:
		while not cart.can_move:
			await get_tree().physics_frame
		cart.is_local_player = true
		cart.is_isometric = false
		# As PlayerCart sets up a local player's camera.
		cart.camera_pivot.top_level = true
		cart.camera.make_current()
	cart.freeze = false
	var xf := Transform3D(Basis(), spot)
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, vel)
	cart.global_transform = xf
	cart.linear_velocity = vel
	print("DROP from %s, surface %.2f" % [spot, surface])
	# Wait for the splash, then shoot at each time after it.
	var t := 0.0
	var pk := 0
	while not cart.is_underwater and t < 6.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if pk < pre.size() and t >= float(pre[pk]):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/fall_%02d.png" % [out_dir, pk])
			var wy: float = cart._get_water_surface_y_at(cart.visuals.global_position)
			print("FALL SHOT %d t=%.2f cart_y=%.2f vy=%.1f on_ground=%s water_y=%.1f ground_above=%s splash_at=%s cam=%s" % [pk, t,
				cart.global_position.y, cart.linear_velocity.y, cart.is_on_ground, wy,
				cart._ground_above_water(cart.visuals.global_position, wy, cart._camera_excludes), cart._splash_cam_at,
				get_viewport().get_camera_3d().global_position])
			pk += 1
	print("UNDER at %.2fs, flooded=%s engine_playing=%s" % [t, cart._engine_flooded, cart.engine_sound.playing])
	# Physics time: the shots stall frames, and physics catches up only 4 steps a frame.
	var pt := 0.0
	for k in range(times.size()):
		while pt < float(times[k]):
			await get_tree().physics_frame
			pt += get_physics_process_delta_time()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/deep_%02d.png" % [out_dir, k])
		print("  cam=%s" % get_viewport().get_camera_3d().global_position)
		print("SHOT %d t=%.2f water_timer=%.2f flooded=%s drowned=%s engine_playing=%s vol=%.1f cart_y=%.2f bubbles=%d splashes=%d" % [k, float(times[k]), cart.water_timer,
				cart._engine_flooded, cart.is_drowned, cart.engine_sound.playing, cart.engine_sound.volume_db, cart.global_position.y,
				get_tree().root.find_children("SinkingBubbles", "", true, false).size(), get_tree().root.find_children("BigSplash", "", true, false).size()])
	get_tree().quit()
