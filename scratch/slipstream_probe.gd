extends Node

# The slipstream (PlayerCart._update_slipstream) in a real race. Drives the human's cart (a single-player
# GP with bots, the car picked with car=) flat out along the lap line with the player's own input
# actions, and logs every half second its speed against its cap (max_speed x offroad_penalty), its draft
# and the gap to the nearest cart ahead in its lane. The result lines give, for the human, the share of
# time it drafted and its best speed over the cap in and out of a draft, and for every cart (bots too)
# the share of time each spent drafting.
#   Godot --headless --path . res://scratch/slipstream_probe.tscn -- [level=res://levels/LakesideLevel.tscn]
#       [car=5] [seconds=60]
# A run in which the human respawns stops there.

var level: Node
var cart: RigidBody3D
var curve: Curve3D
var length := 1.0


func _ready() -> void:
	var level_path := "res://levels/LakesideLevel.tscn"
	var car := 5
	var seconds := 60.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("car="): car = int(a.substr(4))
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.local_car_index = car
	NetworkManager.start_single_player("Tester")
	level = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	cart = level.players_container.get_node("1")
	while not cart.can_move:
		await get_tree().physics_frame
	curve = level.track_path.curve
	length = curve.get_baked_length()
	var preset: Dictionary = cart.CAR_PRESETS[cart.car_index]
	print("car %d %s: max_speed %.1f m/s" % [cart.car_index, preset["name"], preset["max_speed"]])
	var t := 0.0
	var next_log := 0.0
	var drafting := 0.0
	var best_in := 0.0
	var best_out := 0.0
	var share := {}
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if cart.get("is_teleporting"):
			print("respawned at %.1fs: stopping" % t)
			break
		var pos: Vector3 = cart.global_position
		var off := curve.get_closest_offset(level.track_path.to_local(pos))
		var speed: float = Vector3(cart.linear_velocity.x, 0.0, cart.linear_velocity.z).length()
		var tp: Vector3 = level.track_path.to_global(curve.sample_baked(fmod(off + 12.0 + speed * 0.5, length)))
		var fwd: Vector3 = -cart.get_node("Visuals").global_transform.basis.z
		fwd.y = 0.0
		var to: Vector3 = tp - pos
		to.y = 0.0
		var steer := clampf(atan2(fwd.cross(to).y, fwd.dot(to)) * 1.6, -1.0, 1.0)
		_press("p1_steer_left", maxf(steer, 0.0))
		_press("p1_steer_right", maxf(-steer, 0.0))
		_press("p1_throttle", 1.0)
		var draft: float = cart.get("_draft")
		var cap: float = cart.max_speed * cart.offroad_penalty
		var boosted: bool = cart.is_boosting or cart.get("is_pad_boosting")
		if not boosted and cart.is_on_ground:
			if draft > 0.5:
				best_in = maxf(best_in, speed / cap)
			elif draft < 0.02:
				best_out = maxf(best_out, speed / cap)
		if draft > 0.2:
			drafting += 1.0 / 60.0
		for c in get_tree().get_nodes_in_group("player_carts"):
			var k := str(c.name) + " " + str(c.CAR_PRESETS[c.car_index]["name"])
			share[k] = float(share.get(k, 0.0)) + (1.0 / 60.0 if float(c.get("_draft")) > 0.2 else 0.0)
		if t >= next_log:
			next_log = t + 0.5
			print("t=%5.1f speed %5.1f cap %5.1f (x%.3f) draft %.2f target %.2f gap %s boost %s" % [t, speed, cap,
					speed / cap, draft, cart.get("_draft_target"), _gap_ahead(), str(boosted)])
	print("RESULT human drafted %.0f%% of %.0fs; best speed/cap in a draft %.3f, out of one %.3f" % [
			100.0 * drafting / t, t, best_in, best_out])
	for k in share:
		print("RESULT cart %s drafted %.0f%%" % [k, 100.0 * float(share[k]) / t])
	get_tree().quit()


## The nearest cart ahead within 4m of the human's heading line, in metres along it ("-" for none).
func _gap_ahead() -> String:
	var v: Vector3 = cart.linear_velocity
	v.y = 0.0
	if v.length() < 1.0:
		return "-"
	var dir := v.normalized()
	var best := INF
	for c in get_tree().get_nodes_in_group("player_carts"):
		if c == cart:
			continue
		var to: Vector3 = c.global_position - cart.global_position
		var along := to.x * dir.x + to.z * dir.z
		var side := absf(to.x * dir.z - to.z * dir.x)
		if along > 0.0 and side < 4.0 and along < best:
			best = along
	return "-" if best == INF else "%.1f" % best


func _press(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
