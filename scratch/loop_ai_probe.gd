extends Node

# Puts one AI cart on the lap before the Lakeside loop at racing speed and logs how it gets through:
# its place along the lap, height, speed, whether it's on the loop, every 0.2s of physics time, in the
# loop's own frame too (x across, z along its ground lanes). Headless:
#   Godot --headless --path . res://scratch/loop_ai_probe.tscn -- [start=2540] [speed=32] [seconds=10]

func _ready() -> void:
	var start := 2540.0
	var v0 := 32.0
	var seconds := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("start="): start = float(a.substr(6))
		elif a.begins_with("speed="): v0 = float(a.substr(6))
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load("res://levels/LakesideLevel.tscn").instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().physics_frame
	for i in 400:
		await get_tree().physics_frame
	var loop: Node3D = level.get_node("Ramps/LoopCSG")
	var curve: Curve3D = level.track_path.curve
	var cart: RigidBody3D = get_tree().get_nodes_in_group("player_carts")[0]
	# Everyone else out of the way.
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
			var l := loop.global_transform.affine_inverse() * cart.global_position
			print("t=%4.1f off=%6.0f y=%6.2f v=%5.1f loop=%s local=(%5.1f, %5.1f, %5.1f) tele=%s" % [t, curve.get_closest_offset(cart.global_position),
					cart.global_position.y, cart.linear_velocity.length(), cart.is_on_loop, l.x, l.y, l.z, cart.is_teleporting])
			for b in cart.get_colliding_bodies():
				print("    touching ", b.get_path())
	get_tree().quit()
