extends Node

# Drives a cart into one of a level's knockable marker poles (KnockablePoles.gd) and logs what the
# pole's rigid body does: how far and how high it flies, how far it tips, and the cart's speed before
# and after. Also lists anything else solid at the pole's foot (DressingColliders.gd must leave the
# poles to their own bodies). Spectator race, headless is fine:
#   Godot --headless --path . res://scratch/pole_launch_test.tscn -- [level=res://levels/MsituFallsLevel.tscn]
#       [index=40] [speed=22]

const KNOCKABLE_POLES := "res://KnockablePoles.gd"


func _ready() -> void:
	var level_path := "res://levels/MsituFallsLevel.tscn"
	var index := 40
	var speed := 22.0
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
	var poles: Node = null
	for n in level.find_children("*", "MultiMeshInstance3D", true, false):
		var scr: Script = n.get_script()
		if scr and scr.resource_path == KNOCKABLE_POLES:
			poles = n
			break
	if poles == null:
		print("no KnockablePoles on ", level_path)
		get_tree().quit()
		return
	index = clampi(index, 0, poles._bodies.size() - 1)
	var body: RigidBody3D = poles._bodies[index]
	var start: Vector3 = body.global_position
	print("POLES %s: %d poles; pole %d at %s" % [poles.name, poles._bodies.size(), index, start])
	# Anything solid at its foot besides its own body?
	var q := PhysicsShapeQueryParameters3D.new()
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	q.shape = probe
	q.collision_mask = 0xFFFFFFFF
	q.transform = Transform3D(Basis(), start + Vector3.UP * 0.4)
	var others := PackedStringArray()
	for h in level.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c: Node = h["collider"]
		if c != body:
			others.append(String(c.name))
	print("OTHER COLLIDERS at its foot: ", others if not others.is_empty() else PackedStringArray(["none"]))
	# Drive a cart at it from across the road.
	var path := level.get_node_or_null("TrackPath") as Path3D
	var dir := Vector3.RIGHT
	if path:
		var near: Vector3 = path.to_global(path.curve.get_closest_point(path.to_local(start)))
		dir = Vector3(start.x - near.x, 0.0, start.z - near.z).normalized()
	var carts: Array = get_tree().get_nodes_in_group("player_carts")
	var cart: RigidBody3D = carts[0]
	# Frozen on the grid until the green light.
	var wait := 0.0
	while not cart.can_move and wait < 30.0:
		await get_tree().physics_frame
		wait += get_physics_process_delta_time()
	var from := start - dir * 16.0
	from.y = start.y + 1.0
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis.looking_at(dir, Vector3.UP), from))
	var t := 0.0
	var hit_speed := -1.0
	var max_dist := 0.0
	var max_rise := 0.0
	var max_tilt := 0.0
	var pushing := true
	var peak_v := 0.0
	var closest := INF
	while t < 3.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var to_pole: Vector3 = body.global_position - cart.global_position
		to_pole.y = 0.0
		if pushing:
			var v := cart.linear_velocity
			cart.linear_velocity = Vector3(dir.x * speed, v.y, dir.z * speed)
			if to_pole.length() < 2.2:
				pushing = false
				hit_speed = cart.linear_velocity.length()
		closest = minf(closest, to_pole.length())
		peak_v = maxf(peak_v, body.linear_velocity.length())
		var off: Vector3 = body.global_position - start
		max_dist = maxf(max_dist, Vector2(off.x, off.z).length())
		max_rise = maxf(max_rise, off.y)
		max_tilt = maxf(max_tilt, rad_to_deg(body.global_transform.basis.y.angle_to(Vector3.UP)))
		if fmod(t + 10.0, 0.25) < get_physics_process_delta_time():
			print("t=%4.2f  pole moved %5.2fm  up %5.2fm  tilt %5.1f deg  frozen %s  cart %4.1f m/s at %s, %.1fm off" % [
				t, Vector2(off.x, off.z).length(), off.y, rad_to_deg(body.global_transform.basis.y.angle_to(Vector3.UP)),
				body.freeze, cart.linear_velocity.length(), cart.global_position, to_pole.length()])
	print("RESULT: hit at %.1f m/s (closest %.1fm); pole flew %.1fm out, %.2fm up at up to %.1f m/s, tipped %.0f deg; cart left at %.1f m/s" % [
		hit_speed, closest, max_dist, max_rise, peak_v, max_tilt, cart.linear_velocity.length()])
	get_tree().quit()
