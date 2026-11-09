extends SceneTree

# What a ray query costs on a real level, the way PlayerCart casts them against the cheaper ways GDScript allows.
# The AI's feelers (11 a bot a tick in _get_ai_input: two drop probes, nine forward rays) along the lap:
#   A  as the game does: PhysicsRayQueryParameters3D.create() per ray, a new [rid] exclude array, a mask
#   B  one query object reused, its exclude and mask set once, only from/to changed
#   C  B without reading the result Dictionary (what the engine call itself costs)
#   D  A's GDScript only, no intersect_ray (the allocations alone)
# Rounds alternate the order. Headless:
#   Godot --headless --path . -s res://scratch/ray_query_bench.gd -- [level=res://levels/LakesideLevel.tscn]
#     [spots=400] [rounds=6]

func _init() -> void:
	var level_path := "res://levels/LakesideLevel.tscn"
	var spot_count := 400
	var rounds := 6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("spots="): spot_count = int(a.substr(6))
		elif a.begins_with("rounds="): rounds = int(a.substr(7))
	var level: Node3D = load(level_path).instantiate()
	root.add_child(level)
	for i in 90:
		await physics_frame
	var path := level.get_node_or_null("TrackPath") as Path3D
	if path == null:
		push_error("no TrackPath")
		quit(1)
		return
	var curve := path.curve
	var length := curve.get_baked_length()
	var space := level.get_world_3d().direct_space_state
	# A cart's frame at evenly spaced spots on the lap, on the ground under the line.
	var frames: Array = []
	for k in spot_count:
		var off := length * (float(k) + 0.5) / float(spot_count)
		var p := path.global_transform * curve.sample_baked(off)
		var p2 := path.global_transform * curve.sample_baked(fmod(off + 2.0, length))
		var fwd := p2 - p
		fwd.y = 0.0
		if fwd.length() < 0.01:
			continue
		fwd = fwd.normalized()
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 5.0, p + Vector3.DOWN * 10.0)
		var hit := space.intersect_ray(q)
		if hit:
			p = hit.position + Vector3.UP * 0.75
		frames.append([p, fwd, fwd.cross(Vector3.UP).normalized()])
	var rays := _feelers(frames)
	print("level %s: %d spots, %d rays a pass (11 a spot)" % [level_path.get_file(), frames.size(), rays.size()])
	var dummy_rid := RID()
	var totals := {"A": 0.0, "B": 0.0, "C": 0.0, "D": 0.0}
	var hits := 0
	for r in rounds:
		var order := ["A", "B", "C", "D"] if r % 2 == 0 else ["D", "C", "B", "A"]
		for v in order:
			await physics_frame
			var t0 := Time.get_ticks_usec()
			match v:
				"A": hits = _run_a(space, rays, dummy_rid)
				"B": _run_b(space, rays, dummy_rid)
				"C": _run_c(space, rays, dummy_rid)
				"D": _run_d(rays, dummy_rid)
			totals[v] += float(Time.get_ticks_usec() - t0)
	var n := float(rays.size() * rounds)
	print("rays that hit something: %d of %d" % [hits, rays.size()])
	for v in ["A", "B", "C", "D"]:
		print("%s  %.2f us a ray   %.3f ms a tick for 6 bots x 11 rays" % [v, totals[v] / n, totals[v] / n * 66.0 / 1000.0])
	quit()

func _feelers(frames: Array) -> Array:
	var out: Array = []
	for f in frames:
		var centre: Vector3 = f[0]  # the cart's sphere, 0.75m over the ground
		var fwd: Vector3 = f[1]
		var right: Vector3 = f[2]
		var my_pos := centre + Vector3.UP * 0.32
		var low_pos := centre + Vector3.UP * 0.16
		var bumper := centre + Vector3.UP * 0.25 + fwd * 0.5
		var lp := my_pos + fwd * 4.0 - right * 2.2
		var rp := my_pos + fwd * 4.0 + right * 2.2
		out.append([lp + Vector3.UP * 0.5, lp + Vector3.DOWN * 4.0, 1])
		out.append([rp + Vector3.UP * 0.5, rp + Vector3.DOWN * 4.0, 1])
		out.append([my_pos, my_pos + fwd * 20.0, 5])
		out.append([low_pos, low_pos + fwd * 12.0, 5])
		out.append([bumper, bumper + fwd * 2.5, 5])
		for s in [0.75, -0.75]:
			out.append([my_pos + right * s, my_pos + right * s + fwd * 14.0, 5])
		for s in [1.35, -1.35]:
			out.append([my_pos + right * s, my_pos + right * s + fwd * 10.0, 5])
		for s in [1.15, -1.15]:
			out.append([my_pos + right * s, my_pos + right * s + fwd * 4.0, 5])
	return out

# As PlayerCart does it.
func _run_a(space: PhysicsDirectSpaceState3D, rays: Array, rid: RID) -> int:
	var hits := 0
	for ray in rays:
		var query = PhysicsRayQueryParameters3D.create(ray[0], ray[1])
		query.exclude = [rid]
		query.collision_mask = ray[2]
		var result = space.intersect_ray(query)
		if result and result.normal.y > -2.0:
			hits += 1
	return hits

func _run_b(space: PhysicsDirectSpaceState3D, rays: Array, rid: RID) -> int:
	var hits := 0
	var query := PhysicsRayQueryParameters3D.new()
	query.exclude = [rid]
	for ray in rays:
		query.from = ray[0]
		query.to = ray[1]
		query.collision_mask = ray[2]
		var result := space.intersect_ray(query)
		if result and result.normal.y > -2.0:
			hits += 1
	return hits

func _run_c(space: PhysicsDirectSpaceState3D, rays: Array, rid: RID) -> void:
	var query := PhysicsRayQueryParameters3D.new()
	query.exclude = [rid]
	for ray in rays:
		query.from = ray[0]
		query.to = ray[1]
		query.collision_mask = ray[2]
		space.intersect_ray(query)

func _run_d(rays: Array, rid: RID) -> int:
	var n := 0
	for ray in rays:
		var query = PhysicsRayQueryParameters3D.create(ray[0], ray[1])
		query.exclude = [rid]
		query.collision_mask = ray[2]
		n += query.collision_mask
	return n
