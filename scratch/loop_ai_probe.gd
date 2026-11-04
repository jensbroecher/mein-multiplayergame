extends Node

# Puts one AI cart on the lap before the Lakeside loop at racing speed and logs how it gets through:
# its place along the lap, height, speed, whether it's on the loop, every 0.2s of physics time, in the
# loop's own frame too (x across, z along its ground lanes). Headless:
#   Godot --headless --path . res://scratch/loop_ai_probe.tscn -- [start=2540] [speed=32] [seconds=10]
# At the end, how well the car followed the loop while on it: the angle between its model's up and the loop surface
# under it (a ray down the model's up), frames its ground ray missed, and how many bump/landing sounds played.

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
	var angles: Array[float] = []
	var misses := 0
	var loop_frames := 0
	var sounds := 0
	var was_playing := false
	var space := cart.get_world_3d().direct_space_state
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var bonk: AudioStreamPlayer3D = cart.get("sfx_landing_bonk")
		var playing: bool = bonk != null and bonk.playing
		if cart.is_on_loop:
			loop_frames += 1
			if playing and not was_playing:
				sounds += 1
			if not cart.ground_ray.is_colliding():
				misses += 1
			var up: Vector3 = cart.visuals.global_transform.basis.y
			var q := PhysicsRayQueryParameters3D.create(cart.global_position + up * 0.5, cart.global_position - up * 4.0)
			q.exclude = [cart.get_rid()]
			var hit := space.intersect_ray(q)
			# Only where the loop's surface is under it (just past the exit lane is_on_loop holds on 0.28s over the road).
			if hit and cart._is_loop_surface(hit.collider):
				angles.append(rad_to_deg(up.angle_to(hit.normal)))
				if angles[angles.size() - 1] > 20.0:
					var lp := loop.global_transform.affine_inverse() * cart.global_position
					print("  OFF %.1f deg at t=%.2f local=(%.1f, %.1f, %.1f)" % [angles[angles.size() - 1], t, lp.x, lp.y, lp.z])
		was_playing = playing
		if t >= next:
			next += 0.2
			var l := loop.global_transform.affine_inverse() * cart.global_position
			print("t=%4.1f off=%6.0f y=%6.2f v=%5.1f loop=%s local=(%5.1f, %5.1f, %5.1f) tele=%s" % [t, curve.get_closest_offset(cart.global_position),
					cart.global_position.y, cart.linear_velocity.length(), cart.is_on_loop, l.x, l.y, l.z, cart.is_teleporting])
			for b in cart.get_colliding_bodies():
				print("    touching ", b.get_path())
	var worst := 0.0
	var sum := 0.0
	for a in angles:
		worst = maxf(worst, a)
		sum += a
	print("LOOP %d frames on it: model up vs the surface %.1f deg on average, worst %.1f; ground ray missed %d frames; %d bump/landing sounds" % [
			loop_frames, sum / maxf(angles.size(), 1.0), worst, misses, sounds])
	get_tree().quit()
