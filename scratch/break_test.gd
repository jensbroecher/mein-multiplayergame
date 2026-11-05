extends Node

# Drives a real cart into a corner's chevron sign (BreakableSigns.gd) or a fern (DressingColliders' brush, torn into its
# fronds by FernShreds.gd) and logs what happens: the sign knocked off (its flight, how far and high, where it lies,
# and the cart's speed before and after), or the fern torn (its fronds flying, then gone). A spectator race; headless
# for the log, windowed with a <dir> to save frames from a camera beside the target:
#   Godot --path . --resolution 1280x720 res://scratch/break_test.tscn -- [<dir>] [kind=sign|fern]
#       [level=res://levels/MsituFallsLevel.tscn] [index=0] [speed=22] [frames=16] [gap=0.12]
# index: the sign's number, or for ferns the index-th nearest the lap.

func _ready() -> void:
	var dir_out := ""
	var kind := "sign"
	var level_path := "res://levels/MsituFallsLevel.tscn"
	var index := 0
	var speed := 22.0
	var frames := 16
	var gap := 0.12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("kind="): kind = a.substr(5)
		elif a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("index="): index = int(a.substr(6))
		elif a.begins_with("speed="): speed = float(a.substr(6))
		elif a.begins_with("frames="): frames = int(a.substr(7))
		elif a.begins_with("gap="): gap = float(a.substr(4))
		elif not a.contains("="): dir_out = a
	if dir_out != "":
		DirAccess.make_dir_recursive_absolute(dir_out)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 10:
		await get_tree().physics_frame
	var path := level.get_node_or_null("TrackPath") as Path3D
	var target := Vector3.ZERO
	var signs: Node = level.get_node_or_null("BreakableSigns")
	var dc: Node = level.get_node_or_null("DressingColliders")
	var entry: Array = []
	if kind == "sign":
		if signs == null or signs._signs.is_empty():
			print("no breakable signs on ", level_path)
			get_tree().quit()
			return
		index = clampi(index, 0, signs._signs.size() - 1)
		target = signs._signs[index][2]
		print("SIGNS: %d; sign %d at %s, radius %.2f" % [signs._signs.size(), index, str(target), float(signs._signs[index][3])])
	else:
		var brush: Array = []
		for e in dc._wobble:
			if e[8]:
				brush.append(e)
		if brush.is_empty() or path == null:
			print("no ferns on ", level_path)
			get_tree().quit()
			return
		brush.sort_custom(func(a, b) -> bool:
			return _lap_dist(path, a[3]) < _lap_dist(path, b[3]))
		entry = brush[clampi(index, 0, brush.size() - 1)]
		target = entry[3]
		print("FERNS: %d brush; fern %d at %s, %.1fm from the lap, radius %.2f" % [brush.size(), index, str(target), _lap_dist(path, target), float(entry[4])])
	var dir := Vector3.RIGHT
	if path:
		var near: Vector3 = path.to_global(path.curve.get_closest_point(path.to_local(target)))
		dir = Vector3(target.x - near.x, 0.0, target.z - near.z).normalized()
		if dir.length_squared() < 0.5:
			dir = Vector3.RIGHT
	var cart: RigidBody3D = get_tree().get_nodes_in_group("player_carts")[0]
	var wait := 0.0
	while not cart.can_move and wait < 30.0:
		await get_tree().physics_frame
		wait += get_physics_process_delta_time()
	var from := target - dir * 18.0
	from.y = target.y + 1.5
	var hit := level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 10.0, from + Vector3.DOWN * 30.0))
	if not hit.is_empty():
		from.y = float(hit["position"].y) + 1.0
	PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.looking_at(dir, Vector3.UP), from))
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	cam.global_position = target + side * 11.0 - dir * 4.0 + Vector3.UP * 3.5
	cam.look_at(target + dir * 3.0 + Vector3.UP * 0.8, Vector3.UP)
	if dir_out != "":
		cam.make_current()
	var t := 0.0
	var pushing := true
	var hit_speed := -1.0
	var max_rise := 0.0
	var next_shot := 0.0
	var shots := 0
	var shot_from := -1.0
	var sign_start: Vector3 = target
	while t < 5.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var to_t: Vector3 = target - cart.global_position
		to_t.y = 0.0
		if pushing:
			var v := cart.linear_velocity
			cart.linear_velocity = Vector3(dir.x * speed, v.y, dir.z * speed)
			if to_t.length() < 4.5 and shot_from < 0.0:
				shot_from = t - gap * 2.0
		if pushing and to_t.dot(dir) < -1.0:
			pushing = false
		if hit_speed < 0.0 and to_t.length() < 3.5:
			hit_speed = cart.linear_velocity.length()
		var line := "t=%4.2f cart %4.1f m/s %.1fm off" % [t, cart.linear_velocity.length(), to_t.length()]
		if kind == "sign":
			var s: Array = signs._signs[index]
			var node: Node3D = s[0]
			var off: Vector3 = node.global_position - sign_start
			max_rise = maxf(max_rise, off.y)
			line += " | sign state %d moved %.1fm up %.2fm" % [int(s[5]), Vector2(off.x, off.z).length(), off.y]
		else:
			var shreds: Node = dc.get_node_or_null("FernShreds")
			line += " | fern torn %s, fronds flying %d" % [entry[9], shreds._flying.size() if shreds else 0]
		if fmod(t + 10.0, 0.25) < get_physics_process_delta_time():
			print(line)
		if dir_out != "" and shot_from >= 0.0 and t >= shot_from + next_shot and shots < frames:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir_out.path_join("%s_%02d.png" % [kind, shots]))
			shots += 1
			next_shot += gap
	if kind == "sign":
		var s2: Array = signs._signs[index]
		var off2: Vector3 = (s2[0] as Node3D).global_position - sign_start
		print("RESULT: hit at %.1f m/s; sign state %d, flew %.1fm out, %.1fm up, lies at %s; cart left at %.1f m/s" % [hit_speed, int(s2[5]),
			Vector2(off2.x, off2.z).length(), max_rise, str((s2[0] as Node3D).global_position), cart.linear_velocity.length()])
	else:
		var sh: Node = dc.get_node_or_null("FernShreds")
		print("RESULT: hit at %.1f m/s; fern torn %s, ferns shredded %d; cart left at %.1f m/s" % [hit_speed, entry[9],
			int(sh.shredded) if sh else 0, cart.linear_velocity.length()])
	get_tree().quit()


static func _lap_dist(path: Path3D, p: Vector3) -> float:
	var q: Vector3 = path.to_global(path.curve.get_closest_point(path.to_local(p)))
	return Vector2(q.x - p.x, q.z - p.z).length()
