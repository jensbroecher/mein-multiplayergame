extends Node

# Drives a real cart through brush (ferns: DressingColliders.gd's driven-through plants) and logs, per
# fern it enters, its speed just before and after (the drag), how far each one leans, and the speed
# it leaves with. The brush picked is the index-th one within 20m of the lap, so the run is on level
# ground. Spectator race, headless is fine:
#   Godot --headless --path . res://scratch/brush_drive_test.tscn -- [level=res://levels/MsituFallsLevel.tscn]
#       [index=0] [speed=20]


func _ready() -> void:
	var level_path := "res://levels/MsituFallsLevel.tscn"
	var index := 0
	var speed := 20.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("index="): index = int(a.substr(6))
		elif a.begins_with("speed="): speed = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 10:
		await get_tree().physics_frame
	var dc = level.get_node("DressingColliders")
	var path := level.get_node("TrackPath") as Path3D
	var pick: Array = []
	var k := 0
	for e in dc._wobble:
		if not e[8]:
			continue
		var foot: Vector3 = e[3]
		var near: Vector3 = path.to_global(path.curve.get_closest_point(path.to_local(foot)))
		if near.distance_to(foot) < 20.0:
			if k == index:
				pick = e
				break
			k += 1
	if pick.is_empty():
		print("no brush near the lap")
		get_tree().quit()
		return
	var foot: Vector3 = pick[3]
	var near: Vector3 = path.to_global(path.curve.get_closest_point(path.to_local(foot)))
	var dir := Vector3(foot.x - near.x, 0.0, foot.z - near.z).normalized()
	print("BRUSH %s #%d at %s, radius %.2f, %.1fm off the lap" % [(pick[0][0] as Node).name, pick[1], foot, pick[4], near.distance_to(foot)])
	var cart: RigidBody3D = get_tree().get_nodes_in_group("player_carts")[0]
	var wait := 0.0
	while not cart.can_move and wait < 30.0:
		await get_tree().physics_frame
		wait += get_physics_process_delta_time()
	var from := foot - dir * 12.0
	from.y = foot.y + 1.0
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.looking_at(dir, Vector3.UP), from))
	var cid := cart.get_instance_id()
	var t := 0.0
	var pushing := true
	var prev_speed := speed
	var entered := 0
	var max_lean := 0.0
	while t < 1.6:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var to: Vector3 = foot - cart.global_position
		to.y = 0.0
		# Pushed straight at it until just short of its leaves, then on its own.
		if pushing:
			cart.linear_velocity = Vector3(dir.x * speed, cart.linear_velocity.y, dir.z * speed)
			if to.length() < float(pick[4]) + 1.6:
				pushing = false
		var inside: Dictionary = dc._brush_in.get(cid, {})
		var v := cart.linear_velocity.length()
		if inside.size() > entered:
			print("t=%4.2f  in %d fern(s): %.2f -> %.2f m/s" % [t, inside.size(), prev_speed, v])
		entered = inside.size()
		max_lean = maxf(max_lean, absf(rad_to_deg(float(pick[6]))))
		prev_speed = v
	print("RESULT: hit at %.1f m/s, left at %.1f m/s; the fern leaned up to %.0f deg; cart at %s" % [
		speed, cart.linear_velocity.length(), max_lean, cart.global_position])
	get_tree().quit()
