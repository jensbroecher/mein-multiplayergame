extends Node

const KickBall := preload("res://KickBall.gd")

# Drives a real cart into a KickBall (KickBall.gd) and logs the kick: the cart's speed before and after,
# the ball's speed off the car, how high and how far it flew, where it ended up after `watch` seconds.
# The ball is the index-th of the level's own (group kick_balls), or with spawn= a new one put on the
# lap `s` metres along. Spectator race, headless is fine:
#   Godot --headless --path . res://scratch/kick_ball_test.tscn -- [level=res://levels/NyotaStadiumLevel.tscn]
#       [index=0 | spawn=football|beach s=300] [speed=30] [aside=0] [watch=4] [trace=1]
# aside: how far off the ball's centre the cart's line passes (m, + to the right), for glancing hits.


func _ready() -> void:
	var level_path := "res://levels/NyotaStadiumLevel.tscn"
	var index := 0
	var spawn := ""
	var s_at := 300.0
	var speed := 30.0
	var aside := 0.0
	var watch := 4.0
	var trace := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("index="): index = int(a.substr(6))
		elif a.begins_with("spawn="): spawn = a.substr(6)
		elif a.begins_with("s="): s_at = float(a.substr(2))
		elif a.begins_with("speed="): speed = float(a.substr(6))
		elif a.begins_with("aside="): aside = float(a.substr(6))
		elif a.begins_with("watch="): watch = float(a.substr(6))
		elif a == "trace=1": trace = true
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 10:
		await get_tree().physics_frame
	var path := level.get_node("TrackPath") as Path3D
	var ball: RigidBody3D
	if spawn != "":
		ball = RigidBody3D.new()
		ball.set_script(load("res://KickBall.gd"))
		ball.set("style", 1 if spawn == "beach" else 0)
		var p: Vector3 = path.to_global(path.curve.sample_baked(s_at))
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 5, 0), p - Vector3(0, 10, 0))
		var hit := level.get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			p = hit.position
		ball.position = p + Vector3(0, float(KickBall.STYLES[ball.style]["radius"]) + 0.05, 0)
		level.add_child(ball)
	else:
		var balls := get_tree().get_nodes_in_group("kick_balls")
		if index >= balls.size():
			print("the level has %d balls" % balls.size())
			get_tree().quit()
			return
		ball = balls[index]
	for i in 30:
		await get_tree().physics_frame
	var at := ball.global_position
	print("BALL %s style %d at %s, r %.2f, sleeping %s" % [ball.name, ball.style, at, KickBall.STYLES[ball.style]["radius"], ball.sleeping])
	var off := path.curve.get_closest_offset(path.to_local(at))
	var fwd: Vector3 = path.to_global(path.curve.sample_baked(off + 2.0)) - path.to_global(path.curve.sample_baked(off - 2.0))
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var cart: RigidBody3D = get_tree().get_nodes_in_group("player_carts")[0]
	var wait := 0.0
	while not cart.can_move and wait < 30.0:
		await get_tree().physics_frame
		wait += get_physics_process_delta_time()
	var from := at - fwd * 30.0 - right * aside
	from.y = at.y - float(KickBall.STYLES[ball.style]["radius"]) + 0.85
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.looking_at(fwd, Vector3.UP), from))
	# Let it settle on the ground, then hold it at speed on the line.
	for i in 30:
		cart.linear_velocity = Vector3(0.0, cart.linear_velocity.y, 0.0)
		await get_tree().physics_frame
	var t := 0.0
	var before := 0.0
	var hit_t := -1.0
	var after := 0.0
	var ball_v := 0.0
	var top := at.y
	var cart_top := 0.0
	var prev_cv := speed
	while t < watch + 1.2:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if trace and absf(t - hit_t) < 0.3 or trace and hit_t < 0.0 and cart.global_position.distance_to(ball.global_position) < 4.0:
			var lb := cart.global_transform.basis.inverse() * (ball.global_position - cart.global_position)
			print("  t=%4.2f ball local %s v %s | cart y %.2f vy %.2f" % [t, lb, ball.linear_velocity, cart.global_position.y, cart.linear_velocity.y])
		if hit_t < 0.0:
			if ball.linear_velocity.length() > 2.0:
				hit_t = t
				after = Vector2(cart.linear_velocity.x, cart.linear_velocity.z).length()
				ball_v = ball.linear_velocity.length()
				var lat := (cart.global_position - at).dot(right)
				print("t=%4.2f KICK: cart %.1f -> %.1f m/s (%.0f%% lost), %.2fm to the side, ball off at %.1f m/s, up %.1f m/s" % [
					t, before, after, (1.0 - after / maxf(before, 0.01)) * 100.0, lat, ball_v, ball.linear_velocity.y])
			else:
				# Held at speed on its line (its own steering undone) until the ball moves.
				var lat := (cart.global_position - at).dot(right)
				cart.linear_velocity = Vector3(fwd.x * speed, cart.linear_velocity.y, fwd.z * speed) - right * (lat + aside) * 4.0
				before = speed
		else:
			top = maxf(top, ball.global_position.y)
			cart_top = maxf(cart_top, cart.linear_velocity.y)
			if t - hit_t > watch:
				break
	if hit_t < 0.0:
		print("RESULT: no kick; ball at %s, cart at %s" % [ball.global_position, cart.global_position])
	else:
		print("RESULT: hit at %.1f m/s, cart kept %.1f m/s, ball off at %.1f m/s, rose %.2fm, %.1fm away after %.1fs (at %s, %.1f m/s); cart's upward speed peaked %.2f m/s" % [
			before, Vector2(cart.linear_velocity.x, cart.linear_velocity.z).length(), ball_v, top - at.y,
			Vector2(ball.global_position.x - at.x, ball.global_position.z - at.z).length(), watch, ball.global_position, ball.linear_velocity.length(), cart_top])
	get_tree().quit()
