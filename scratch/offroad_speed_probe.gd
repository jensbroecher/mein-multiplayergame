extends Node

# How fast a car goes off the road. Drives the human's cart (a single-player GP, the car picked with
# car=) with the player's own input actions, flat out, `aside` metres to the right of the lap line from
# `from` metres along it (negative: left), and logs every half second its speed (m/s and as the HUD
# shows it, x1.8), whether it counts as off-road, the off-road speed penalty, the surface and any boost.
# The result line gives the top HUD speed reached while it had been off-road for a second or more.
#   Godot --headless --path . res://scratch/offroad_speed_probe.tscn -- [level=res://levels/MaraCrossingLevel.tscn]
#       [car=16] [aside=30] [from=150] [seconds=40]
# A run in which the cart respawns (water, a drop) stops there.

var level: Node
var cart: RigidBody3D
var curve: Curve3D
var length := 1.0


func _ready() -> void:
	var level_path := "res://levels/MaraCrossingLevel.tscn"
	var car := 16
	var aside := 30.0
	var from := 150.0
	var seconds := 40.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("car="): car = int(a.substr(4))
		elif a.begins_with("aside="): aside = float(a.substr(6))
		elif a.begins_with("from="): from = float(a.substr(5))
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
	print("car %d %s: max_speed %.1f m/s (HUD %.0f), offroad %.1f; aside %.0f m from %.0f m" % [cart.car_index,
			preset["name"], preset["max_speed"], preset["max_speed"] * 1.8, preset["offroad"], aside, from])
	var t := 0.0
	var next_log := 0.0
	var off_time := 0.0
	var top_off := 0.0
	var top_road := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if cart.get("is_teleporting"):
			print("respawned at %.1fs: stopping" % t)
			break
		var pos: Vector3 = cart.global_position
		var off := curve.get_closest_offset(level.track_path.to_local(pos))
		var travelled := fmod(off - from + length * 1.5, length) - length * 0.5
		# Along the line to `from`, then out to `aside` over 25m and on beside it.
		var lateral: float = aside * clampf((travelled + 25.0) / 25.0, 0.0, 1.0)
		var speed: float = cart.linear_velocity.length()
		var tp := _target(off + 12.0 + speed * 0.5, lateral)
		var fwd: Vector3 = -cart.get_node("Visuals").global_transform.basis.z
		fwd.y = 0.0
		var to := tp - pos
		to.y = 0.0
		var steer := clampf(atan2(fwd.cross(to).y, fwd.dot(to)) * 1.6, -1.0, 1.0)
		_press("p1_steer_left", maxf(steer, 0.0))
		_press("p1_steer_right", maxf(-steer, 0.0))
		_press("p1_throttle", 1.0)
		var offroad: bool = cart.is_offroad
		off_time = off_time + 1.0 / 60.0 if offroad else 0.0
		if offroad and off_time > 1.0:
			top_off = maxf(top_off, speed)
		elif not offroad:
			top_road = maxf(top_road, speed)
		if t >= next_log:
			next_log = t + 0.5
			print("t=%5.1f speed %5.1f m/s HUD %3.0f  offroad %s penalty %.2f surface %d boost %s/%s lateral %.0f" % [t, speed,
					speed * 1.8, "Y" if offroad else "n", cart.offroad_penalty, cart.surface, str(cart.is_boosting),
					str(cart.get("is_pad_boosting")), lateral])
	print("RESULT car %d: top HUD speed off-road %.0f (on road %.0f)" % [cart.car_index, top_off * 1.8, top_road * 1.8])
	get_tree().quit()


func _press(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## The point `off` metres along the lap, `lateral` to the right of the line.
func _target(off: float, lateral: float) -> Vector3:
	var o := fmod(off + length * 4.0, length)
	var p := curve.sample_baked(o)
	var along := (curve.sample_baked(fmod(o + 2.0, length)) - p).normalized()
	return level.track_path.to_global(p + along.cross(Vector3.UP).normalized() * lateral)
