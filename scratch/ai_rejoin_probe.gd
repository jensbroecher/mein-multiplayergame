extends Node
## Puts one AI cart off the course at each given spot during a spectator race and watches it find its way back
## (headless):
##   Godot --headless --path . res://scratch/ai_rejoin_probe.tscn -- <level> x,z[,yaw] ... [auto=N] [rails=N] [seconds=25] [speed=1] [trace=1]
## yaw in degrees (0 faces -z); without it the cart faces away from the road (the worst case: it has to turn round).
## Per spot it prints when the cart was back on the road (within the road's half width plus 2m of the lap, on the
## ground, at the road's height), or respawned (or drowned: pick dry spots), or neither when time ran out; how long it crawled (under 3 m/s with the
## throttle on: grinding a wall or stuck) and how far it drove. `trace=1` logs it every half second. The other carts
## race on (they are moved out of its way at the start of each spot).

var seconds := 25.0
var speed := 1.0
var trace := false
var spots: Array = []
var auto_n := 0
var rails_n := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	for a in args.slice(1):
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
		elif a == "trace=1":
			trace = true
		elif a.begins_with("auto="):
			auto_n = int(a.substr(5))
		elif a.begins_with("rails="):
			rails_n = int(a.substr(6))
		elif a.contains(","):
			var v := a.split(",")
			spots.append([float(v[0]), float(v[1]), float(v[2]) if v.size() > 2 else NAN])
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	Engine.time_scale = speed
	var track: Path3D = level.track_path
	var half: float = 7.5
	var tg := level.get_node_or_null("TerrainGenerator")
	if tg and tg.get("road_width") != null:
		half = float(tg.get("road_width")) * 0.5
	# Wait out the countdown.
	var t := 0.0
	while t < 7.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var carts: Array = get_tree().get_nodes_in_group("player_carts")
	if carts.is_empty():
		print("no carts")
		get_tree().quit()
		return
	var cart: RigidBody3D = carts[0]
	var space := cart.get_world_3d().direct_space_state
	# rails=N: N spots 3.5m outside guardrails (collision boxes under any body named *Guardrail*), on the far side from
	# the road, facing the rail (the worst case: the way to the road is through it), on dry ground.
	if rails_n > 0:
		var boxes: Array = []
		for b in level.find_children("*", "StaticBody3D", true, false):
			if not String(b.name).to_lower().contains("guardrail"):
				continue
			for cs in b.get_children():
				if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D:
					boxes.append((cs as CollisionShape3D).global_transform)
		var water_y0: float = float(cart.water_surface_y)
		var stride: int = maxi(1, boxes.size() / maxi(rails_n, 1))
		var bi := 0
		while bi < boxes.size() and spots.size() < rails_n:
			var bx: Transform3D = boxes[bi]
			bi += stride
			var c: Vector3 = bx.origin
			var lp: Vector3 = track.to_global(track.curve.get_closest_point(track.to_local(c)))
			var away := Vector3(c.x - lp.x, 0.0, c.z - lp.z).normalized()
			var at := c + away * 3.5
			var hq := PhysicsRayQueryParameters3D.create(Vector3(at.x, c.y + 6.0, at.z), Vector3(at.x, c.y - 30.0, at.z))
			var h := space.intersect_ray(hq)
			if h.is_empty() or (h.position as Vector3).y < water_y0 + 0.3 or (h.normal as Vector3).y < 0.75:
				continue
			# Facing the rail (toward the road).
			spots.append([at.x, at.z, rad_to_deg(atan2(away.x, away.z))])
		print("rails: %d guardrail boxes, %d spots" % [boxes.size(), spots.size()])
	# auto=N: N spots along the lap, 20-30m out to alternating sides, on dry ground under 6m below the road (where a
	# cart that ran wide ends up), facing away from the road.
	if auto_n > 0:
		var length: float = track.curve.get_baked_length()
		var water_y: float = float(cart.water_surface_y)
		var k := 0
		var tries := 0
		while spots.size() < auto_n and tries < auto_n * 12:
			var off: float = fposmod(length * (float(tries) + 0.5) / float(auto_n * 3), length)
			tries += 1
			var p: Vector3 = track.to_global(track.curve.sample_baked(off))
			var ahead: Vector3 = track.to_global(track.curve.sample_baked(fposmod(off + 2.0, length)))
			var f := Vector3(ahead.x - p.x, 0.0, ahead.z - p.z).normalized()
			var right := Vector3(-f.z, 0.0, f.x)
			var side := 1.0 if k % 2 == 0 else -1.0
			var lat := 20.0 + 10.0 * fposmod(float(tries) * 0.37, 1.0)
			var at := p + right * side * lat
			var hq := PhysicsRayQueryParameters3D.create(Vector3(at.x, 400.0, at.z), Vector3(at.x, -400.0, at.z))
			var h := space.intersect_ray(hq)
			if h.is_empty():
				continue
			var g: Vector3 = h.position
			if g.y < water_y + 0.3 or p.y - g.y > 6.0 or g.y - p.y > 3.0 or (h.normal as Vector3).y < 0.8:
				continue
			var cp2: Vector3 = track.to_global(track.curve.get_closest_point(track.to_local(g)))
			if Vector2(g.x - cp2.x, g.z - cp2.z).length() < 16.0:
				continue
			spots.append([g.x, g.z, NAN])
			k += 1
	var results: Array = []
	for sp in spots:
		# Let a respawn from the last spot finish first.
		var wait := 0.0
		while (cart.is_teleporting or cart.is_exploding or not cart.can_move) and wait < 8.0:
			await get_tree().physics_frame
			wait += get_physics_process_delta_time()
		var x: float = sp[0]
		var z: float = sp[1]
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 400.0, z), Vector3(x, -400.0, z))
		var hit := space.intersect_ray(q)
		var y: float = (hit.position as Vector3).y + 1.2 if hit else 2.0
		var cp: Vector3 = track.to_global(track.curve.get_closest_point(track.to_local(Vector3(x, y, z))))
		var yaw: float = sp[2]
		if is_nan(yaw):
			# Facing away from the road.
			var away := Vector3(x - cp.x, 0.0, z - cp.z).normalized()
			yaw = atan2(-away.x, -away.z)
		else:
			yaw = deg_to_rad(yaw)
		# Others out of the way, then the cart onto the spot, still.
		for o in carts:
			if o != cart and (o as Node3D).global_position.distance_to(Vector3(x, y, z)) < 60.0:
				(o as RigidBody3D).global_position += Vector3(0.0, 0.0, 200.0)
		cart.global_position = Vector3(x, y, z)
		cart.linear_velocity = Vector3.ZERO
		cart.angular_velocity = Vector3.ZERO
		cart.visuals.global_basis = Basis(Vector3.UP, yaw)
		cart.set("_ai_last_ontrack_offset", track.curve.get_closest_offset(track.to_local(cp)))
		for i in 3:
			await get_tree().physics_frame
		var start := cart.global_position
		var last := start
		var driven := 0.0
		var crawl := 0.0
		var outcome := "timeout"
		var at := seconds
		var since := 0.0
		var next_log := 0.0
		var was_tele := false
		while since < seconds:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			since += dt
			var p := cart.global_position
			if cart.is_teleporting and not was_tele:
				outcome = "drowned and respawned" if cart.is_drowned else "respawned"
				at = since
				break
			was_tele = cart.is_teleporting
			driven += Vector2(p.x - last.x, p.z - last.z).length()
			last = p
			var v: float = cart.linear_velocity.length()
			if v < 3.0:
				crawl += dt
			var near: Vector3 = track.to_global(track.curve.get_closest_point(track.to_local(p)))
			var d := Vector2(p.x - near.x, p.z - near.z).length()
			if d < half + 2.0 and absf(p.y - near.y) < 2.5 and cart.is_on_ground:
				outcome = "back on the road"
				at = since
				break
			if trace and since >= next_log:
				next_log += 0.5
				print("    t=%4.1f at (%.0f, %.1f, %.0f) %.1f m/s, %.1fm off the lap, offroad=%s goal=%s" % [since, p.x, p.y, p.z, v, d,
						cart.is_offroad, cart.get("_ai_recover_goal")])
		var line := "SPOT (%.0f, %.0f): %s after %.1fs, crawled %.1fs, drove %.0fm" % [x, z, outcome, at, crawl, driven]
		print(line)
		results.append(line)
	print("---")
	for r in results:
		print(r)
	var RP = load("res://RejoinPlanner.gd")
	print("planner: %.1f ms in all, the busiest step %.2f ms" % [float(RP.total_usec) / 1000.0, float(RP.busiest_usec) / 1000.0])
	get_tree().quit()
