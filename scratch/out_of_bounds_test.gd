extends Node

# Out-of-bounds respawns (PlayerCart._update_out_of_bounds, SignalLostOverlay): runs a single-player GP on a level and
# puts the human's cart, in turn, (1) on the ground just past the reach (the feed should break up, no respawn), (2)
# well past it (respawn behind the cut), (3) far off the map in the air (nothing below: respawn), (4) under the ground
# at the start (respawn), then (5) drives it along the lap for a while (nothing may fire). Prints PASS/FAIL per case.
#   Godot --headless --path . res://scratch/out_of_bounds_test.tscn -- [level=res://levels/LakesideLevel.tscn] [drive=20]

var level: Node
var cart: RigidBody3D
var fails := 0


func _ready() -> void:
	var level_path := "res://levels/LakesideLevel.tscn"
	var drive := 20.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("drive="): drive = float(a.substr(6))
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.start_single_player("Tester")
	level = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	cart = level.players_container.get_node("1")
	while not cart.can_move:
		await get_tree().physics_frame
	for i in 30:
		await get_tree().physics_frame
	var reach: float = float(level.get_meta(&"oob_reach", cart.OOB_REACH))
	var start: Vector3 = cart.global_position
	print("level %s, reach %.0f m" % [level_path.get_file(), reach])
	# (1) and (2): ground beside the lap at reach + 20 and reach + 80, on the side where there is ground.
	var p1: Vector3 = _ground_off_lap(reach + 20.0)
	if p1.is_finite():
		await _case("just past the reach", p1, false, 3.0)
	else:
		print("SKIP just past the reach: no ground found")
	var p2: Vector3 = _ground_off_lap(reach + 80.0)
	if p2.is_finite():
		await _case("well past the reach", p2, true, 4.0)
	else:
		print("SKIP well past the reach: no ground found")
	await _case("off the map in the air", Vector3(start.x + 9000.0, start.y + 40.0, start.z + 9000.0), true, 3.0)
	await _case("under the ground", start + Vector3(0, -25.0, 0), true, 3.0)
	# (5) driving the lap: follow the line flat out.
	await _settle()
	var t := 0.0
	var fired := false
	var curve: Curve3D = level.track_path.curve
	while t < drive:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if cart.get("_signal_lost_active") or cart.get("is_teleporting"):
			fired = true
			break
		var off := curve.get_closest_offset(level.track_path.to_local(cart.global_position))
		var tp: Vector3 = level.track_path.to_global(curve.sample_baked(fmod(off + 14.0, curve.get_baked_length())))
		var fwd: Vector3 = -cart.get_node("Visuals").global_transform.basis.z
		var to := tp - cart.global_position
		var steer := clampf(atan2(Vector3(fwd.x, 0, fwd.z).cross(Vector3(to.x, 0, to.z)).y, Vector3(fwd.x, 0, fwd.z).dot(Vector3(to.x, 0, to.z))) * 1.6, -1.0, 1.0)
		_press("p1_steer_left", maxf(steer, 0.0))
		_press("p1_steer_right", maxf(-steer, 0.0))
		_press("p1_throttle", 0.7)
	_press("p1_throttle", 0.0)
	_result("driving the lap %.0fs" % drive, not fired, "fired at %s" % str(cart.global_position) if fired else "")
	print("DONE %d failed" % fails)
	get_tree().quit()


func _case(label: String, p: Vector3, expect_respawn: bool, wait: float) -> void:
	await _settle()
	cart.freeze = false
	cart.global_position = p
	cart.linear_velocity = Vector3.ZERO
	cart.angular_velocity = Vector3.ZERO
	var t := 0.0
	var respawned := false
	var max_weak := 0.0
	var saw_cut := false
	while t < wait:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var ui = cart.race_ui
		var o = ui.get("_signal_overlay") if ui else null
		if o != null:
			max_weak = maxf(max_weak, float(o.get("_weak")))
			if o.call("is_cutting"):
				saw_cut = true
		if cart.get("is_teleporting") or cart.get("_signal_lost_active"):
			respawned = true
	var detail := "weak %.2f, cut %s, respawn %s" % [max_weak, saw_cut, respawned]
	var ok: bool = respawned == expect_respawn and (saw_cut or not expect_respawn)
	if not expect_respawn:
		ok = ok and max_weak > 0.1
	_result(label, ok, detail)


func _settle() -> void:
	# Wait for any respawn and cut to finish.
	var t := 0.0
	while t < 6.0 and (cart.get("is_teleporting") or cart.get("_signal_lost_active")):
		await get_tree().physics_frame
		t += 1.0 / 60.0
	for i in 150:
		await get_tree().physics_frame


func _result(label: String, ok: bool, detail: String) -> void:
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", label, detail])


## A point on dry ground `dist` (to +40m) from the nearest lap path: walking out from the lap's middle on 36 bearings.
func _ground_off_lap(dist: float) -> Vector3:
	var curve: Curve3D = level.track_path.curve
	var mid := Vector3.ZERO
	var m := 40
	for i in m:
		mid += level.track_path.to_global(curve.sample_baked(curve.get_baked_length() * float(i) / float(m)))
	mid /= float(m)
	var space := cart.get_world_3d().direct_space_state
	var keep: Vector3 = cart.global_position
	var found := Vector3.INF
	for k in 36:
		var dir := Vector3(cos(TAU * k / 36.0), 0, sin(TAU * k / 36.0))
		var r := 50.0
		while r < 3000.0 and not found.is_finite():
			var q: Vector3 = mid + dir * r
			r += 10.0
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3(0, 800, 0), q - Vector3(0, 800, 0)))
			if hit.is_empty() or (hit.normal as Vector3).y < 0.6:
				continue
			var p: Vector3 = (hit.position as Vector3) + Vector3(0, 1.0, 0)
			cart.global_position = p
			var d: float = p.distance_to(cart.call("_nearest_lap_point"))
			if d > dist + 90.0:
				break
			if d > dist and not cart.call("_deep_water_at", p) and not cart.call("_water_under", p):
				found = p
		if found.is_finite():
			break
	cart.global_position = keep
	return found


func _press(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
