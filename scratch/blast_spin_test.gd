extends Node

# A blast that doesn't lift a car (apply_blast_impulse with no upward push, as at a shockwave's edge or against a
# wall) must not leave its tumble waiting for the car's next jump: the user was thrown about off a ramp many seconds
# after a shockwave that hadn't thrown them. Spectator race, headless:
#   Godot --headless --path . res://scratch/blast_spin_test.tscn -- [level=res://levels/TianqiaoLevel.tscn] [wait=3]
# Prints the car's tumble right after the blast and after `wait` seconds on the ground: PASS when it has gone.
# `lift=1` throws the car as a shockwave's middle does (up as well): PASS when it still tumbles in that flight.

func _ready() -> void:
	var level_path := "res://levels/TianqiaoLevel.tscn"
	var wait := 3.0
	var lift := false
	for a in OS.get_cmdline_user_args():
		if a == "lift=1": lift = true
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("wait="): wait = float(a.substr(5))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	var carts: Array = get_tree().get_nodes_in_group("player_carts")
	var cart: RigidBody3D = carts[0]
	var t := 0.0
	while not cart.can_move and t < 30.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for i in 30:
		await get_tree().physics_frame
	# A push along the road and no lift: the car stays on the ground (or, lift=1, the shockwave's throw).
	var fwd: Vector3 = -cart.visuals.global_transform.basis.z
	if lift:
		cart.apply_blast_impulse((fwd * 54.0 + Vector3.UP * 27.0) * cart.BASE_MASS)
		var max_air_spin := 0.0
		var tt := 0.0
		while tt < 2.0:
			await get_tree().physics_frame
			tt += get_physics_process_delta_time()
			if not cart.is_on_ground:
				max_air_spin = maxf(max_air_spin, cart.air_angular_velocity.length())
		print("SPIN in the flight up to %.2f rad/s" % max_air_spin)
		print("PASS" if max_air_spin > 1.0 else "FAIL")
		get_tree().quit()
		return
	cart.apply_blast_impulse(fwd * 4.0 * cart.mass)
	await get_tree().physics_frame
	var spin0: Vector3 = cart.air_angular_velocity
	var airborne := 0.0
	t = 0.0
	while t < wait:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not cart.is_on_ground:
			airborne += get_physics_process_delta_time()
	var spin1: Vector3 = cart.air_angular_velocity
	print("SPIN after the blast %.2f rad/s, after %.1fs %.2f rad/s (%.2fs of it off the ground)" % [spin0.length(), wait, spin1.length(), airborne])
	print("PASS" if spin0.length() > 1.0 and spin1.length() < 0.01 else "FAIL")
	get_tree().quit()
