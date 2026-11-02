extends Node

# Puts one AI cart on any level's route at racing speed and logs how it drives on from there: its place along the
# TrackPath, height, speed, what it touches, and the AI's state (obstacle and stuck timers, the offset it tracks),
# every 0.2s of physics time. The other carts are moved out of the way. Headless:
#   Godot --headless --path . res://scratch/route_ai_probe.tscn -- [level=res://levels/MinaLevel.tscn] [start=3380]
#       [speed=30] [seconds=8]

func _ready() -> void:
	var level_path := "res://levels/MinaLevel.tscn"
	var start := 3380.0
	var v0 := 30.0
	var seconds := 8.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("start="): start = float(a.substr(6))
		elif a.begins_with("speed="): v0 = float(a.substr(6))
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().physics_frame
	for i in 200:
		await get_tree().physics_frame
	var curve: Curve3D = level.track_path.curve
	var cart: RigidBody3D = get_tree().get_nodes_in_group("player_carts")[0]
	for c in get_tree().get_nodes_in_group("player_carts"):
		if c != cart:
			c.global_position += Vector3(0, 0, 3000)
	var p := curve.sample_baked(start) + Vector3.UP * 1.2
	var fwd := (curve.sample_baked(start + 2.0) - curve.sample_baked(start - 2.0)).normalized()
	var xf := Transform3D(Basis.looking_at(Vector3(fwd.x, 0, fwd.z), Vector3.UP), p)
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	cart.global_transform = xf
	cart.visuals.global_transform.basis = xf.basis
	cart.linear_velocity = fwd * v0
	cart.contact_monitor = true
	cart.max_contacts_reported = 8
	var t := 0.0
	var next := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t >= next:
			next += 0.2
			var gp: Vector3 = cart.global_position
			print("t=%4.1f off=%6.0f pos=(%6.1f, %6.2f, %6.1f) v=%5.1f obst_rev=%.2f obst_stuck=%.2f ai_off=%.0f input=%s" % [t,
					curve.get_closest_offset(gp), gp.x, gp.y, gp.z, cart.linear_velocity.length(), cart.get("_ai_obstacle_reverse_timer"),
					cart.get("_ai_obstacle_stuck_timer"), float(cart.get("current_offset") if cart.get("current_offset") != null else -1.0),
					str(cart.get("_last_ai_input"))])
			for b in cart.get_colliding_bodies():
				print("    touching ", b.get_path())
	get_tree().quit()
