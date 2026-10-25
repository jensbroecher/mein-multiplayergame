extends Node

# Checks a level's AI shortcuts (the Path3D children of AlternativePaths) and races bots that always
# take them. Headless:
#   Godot --headless --path . res://scratch/shortcut_probe.tscn -- res://levels/X.tscn [seconds=180] [speed=2]
#       [static=1] [chance=1.0] [trace=<shortcut name>]
# trace= logs every 0.2s, for carts on that shortcut: the distance along it, how far off its line
# (+ right), the speed and the AI's lane offset.
# Static part, per shortcut: its length, how its ends meet the lap (distance, height, heading), and
# every stretch where the line has no drivable ground under it (water, a drop, off the road), floats
# or is buried, or runs into something solid at a cart's height.
# Race part (skipped with static=1): every bot takes every shortcut it reaches; logs when it takes one,
# where along it it falls, drowns, gets stuck or leaves the line, and where it rejoins the lap.

const ROAD_WORDS := ["road", "track", "ramp", "bridge", "deck", "jump", "curb", "loop", "kicker"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var seconds := 180.0
	var speed := 2.0
	var static_only := false
	var chance := 1.0
	var trace := ""
	for a in args:
		if a.begins_with("seconds="): seconds = float(a.substr(8))
		elif a.begins_with("speed="): speed = float(a.substr(6))
		elif a.begins_with("static="): static_only = a.substr(7) == "1"
		elif a.begins_with("chance="): chance = float(a.substr(7))
		elif a.begins_with("trace="): trace = a.substr(6)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 20:
		await get_tree().physics_frame
	var track: Path3D = level.track_path
	var water_y := -INF
	var ws := level.find_child("Water_Surface", true, false) as Node3D
	if ws:
		water_y = ws.global_position.y
	print("=== %s: %d shortcuts, lap %.0fm, water %s ===" % [level_path.get_file(), level.alternative_paths.size(),
			track.curve.get_baked_length(), "%.1f" % water_y if water_y > -INF else "none found"])
	for alt in level.alternative_paths:
		_check(level, track, alt, water_y)
	if static_only:
		get_tree().quit()
		return
	await _race(level, track, seconds, speed, chance, trace)
	get_tree().quit()


func _is_road(n: Node) -> bool:
	var cur := n
	while cur:
		var s := String(cur.name).to_lower()
		for w in ROAD_WORDS:
			if s.contains(w):
				return true
		if cur.has_meta(&"surface"):
			return str(cur.get_meta(&"surface")) in ["asphalt"]
		cur = cur.get_parent()
	return false


func _check(level: Node3D, track: Path3D, alt: Path3D, water_y: float) -> void:
	var c: Curve3D = alt.curve
	var length := c.get_baked_length()
	var a: Vector3 = alt.to_global(c.sample_baked(0.0))
	var b: Vector3 = alt.to_global(c.sample_baked(length))
	var lap := track.curve
	var oa := lap.get_closest_offset(track.to_local(a))
	var ob := lap.get_closest_offset(track.to_local(b))
	var pa: Vector3 = track.to_global(lap.sample_baked(oa))
	var pb: Vector3 = track.to_global(lap.sample_baked(ob))
	var dir_a: Vector3 = (alt.to_global(c.sample_baked(4.0)) - a).normalized()
	var lap_a: Vector3 = (track.to_global(lap.sample_baked(oa + 4.0)) - pa).normalized()
	var dir_b: Vector3 = (b - alt.to_global(c.sample_baked(length - 4.0))).normalized()
	var lap_b: Vector3 = (track.to_global(lap.sample_baked(ob + 4.0)) - pb).normalized()
	var skipped := fposmod(ob - oa, lap.get_baked_length())
	print("\n%s: %.0fm (skips %.0fm of lap, %.0fm -> %.0fm)" % [alt.name, length, skipped, oa, ob])
	print("  start %.1fm off the lap (dy %.1f), heading %.2f with it; end %.1fm off (dy %.1f), heading %.2f" % [
		Vector2(a.x - pa.x, a.z - pa.z).length(), a.y - pa.y, dir_a.dot(lap_a),
		Vector2(b.x - pb.x, b.z - pb.z).length(), b.y - pb.y, dir_b.dot(lap_b)])
	var space := level.get_world_3d().direct_space_state
	var carts: Array = []
	for k in get_tree().get_nodes_in_group("player_carts"):
		carts.append((k as CollisionObject3D).get_rid())
	var issue := ""
	var issue_from := 0.0
	var lo := INF
	var hi := -INF
	var s := 0.0
	var probe := SphereShape3D.new()
	probe.radius = 0.8
	while s <= length:
		var p: Vector3 = alt.to_global(c.sample_baked(s))
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p + Vector3.DOWN * 40.0)
		q.exclude = carts
		var hit := space.intersect_ray(q)
		var what := ""
		var amount := 0.0
		if hit.is_empty():
			what = "no ground"
		else:
			var col: Node = hit["collider"]
			var gy: float = (hit["position"] as Vector3).y
			if water_y > -INF and gy < water_y - 0.5 and absf(p.y - water_y) < 6.0:
				what = "water, bed under the surface by"
				amount = water_y - gy
			elif p.y - gy > 2.5:
				what = "floats over %s by" % col.name
				amount = p.y - gy
			elif gy - p.y > 2.5:
				what = "buried in %s by" % col.name
				amount = gy - p.y
			else:
				var sq := PhysicsShapeQueryParameters3D.new()
				sq.shape = probe
				sq.transform = Transform3D(Basis(), Vector3(p.x, gy + 1.1, p.z))
				var ex: Array = carts.duplicate()
				ex.append(hit["rid"])
				sq.exclude = ex
				var blocks := PackedStringArray()
				for h in space.intersect_shape(sq, 6):
					var bn: Node = h["collider"]
					if bn is CollisionObject3D and ((bn as CollisionObject3D).collision_layer & 1) == 0:
						continue
					if _is_road(bn) or String(bn.name).contains("Gate") or String(bn.name).contains("Checkpoint"):
						continue
					if not blocks.has(String(bn.name)):
						blocks.append(String(bn.name))
				if not blocks.is_empty():
					what = "runs into " + ", ".join(blocks)
				elif not _is_road(col):
					what = "off-road on %s" % col.name
		if what != issue:
			_report(issue, issue_from, s, lo, hi)
			issue = what
			issue_from = s
			lo = INF
			hi = -INF
		lo = minf(lo, amount)
		hi = maxf(hi, amount)
		s += 2.0
	_report(issue, issue_from, length, lo, hi)


func _report(issue: String, s0: float, s1: float, lo: float, hi: float) -> void:
	if issue == "":
		return
	if issue.ends_with(" by"):
		print("  %5.0f-%5.0fm  %s %.1f-%.1fm" % [s0, s1, issue, lo, hi])
	else:
		print("  %5.0f-%5.0fm  %s" % [s0, s1, issue])


func _race(level: Node3D, track: Path3D, seconds: float, speed: float, chance: float, trace: String) -> void:
	var carts: Array = get_tree().get_nodes_in_group("player_carts")
	for c in carts:
		c.ai_shortcut_chance = chance
	Engine.time_scale = speed
	print("\n=== race: %d bots, shortcut chance %.2f, %.0fs at x%.0f ===" % [carts.size(), chance, seconds, speed])
	var route := {}
	var route_best := {}
	var tele := {}
	var stuck := {}
	var t := 0.0
	var taken := {}
	var trouble := {}
	# Where each cart was over the last second (position, route, offset along it, drowning), for respawns.
	var hist := {}
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		for c in carts:
			if not is_instance_valid(c):
				continue
			var on: String = str(c.active_path.name) if c.on_alternative_path and c.active_path else ""
			var was: String = route.get(c, "")
			if on != was:
				if was != "":
					var alt: Path3D = level.get_node("AlternativePaths/" + was)
					var off: float = alt.curve.get_closest_offset(alt.to_local(c.global_position))
					var full: float = alt.curve.get_baked_length()
					var lp: float = track.curve.get_closest_offset(track.to_local(c.global_position))
					var how := "rejoined the lap at %.0fm" % lp if full - off < 12.0 else "LEFT IT at %.0f of %.0fm" % [off, full]
					print("t=%5.1f %s %s: %s, %s" % [t, c.name, was, how, c.global_position])
				if on != "":
					taken[on] = int(taken.get(on, 0)) + 1
					print("t=%5.1f %s takes %s" % [t, c.name, on])
				route[c] = on
			if trace != "" and on == trace and fmod(t + 100.0, 0.2) < get_physics_process_delta_time():
				var ap: Path3D = c.active_path
				var lo: Vector3 = ap.to_local(c.global_position)
				var off: float = ap.curve.get_closest_offset(lo)
				var cp: Vector3 = ap.curve.sample_baked(off)
				var tg: Vector3 = (ap.curve.sample_baked(off + 1.0) - cp).normalized()
				var rt := Vector3(-tg.z, 0.0, tg.x)
				print("TRACE t=%5.1f %s at %5.1fm  off line %+5.2fm  %4.1f m/s  lane %+5.2f  turn %.2f in %.0fm%s" % [t, c.name, off, (lo - cp).dot(rt),
					c.linear_velocity.length(), c.ai_lane_offset, c._ai_upcoming_turn_angle, c._ai_upcoming_turn_dist, " BOOST" if (c.is_boosting or c.is_pad_boosting) else ""])
			var tl: bool = c.is_teleporting
			var h: Array = hist.get(c, [])
			if not tl:
				var ro := -1.0
				if on != "":
					ro = c.active_path.curve.get_closest_offset(c.active_path.to_local(c.global_position))
				h.append([c.global_position, on, ro, c.is_underwater])
				if h.size() > 30:
					h.pop_front()
				hist[c] = h
			if tl and not tele.get(c, false):
				var where := ""
				var before: Array = h[0] if not h.is_empty() else [c.global_position, on, -1.0, false]
				if String(before[1]) != "":
					where = " on %s at %.0fm" % [before[1], float(before[2])]
					trouble[String(before[1])] = int(trouble.get(String(before[1]), 0)) + 1
				where += ", 0.5s before at %s%s" % [before[0], " under water" if before[3] else ""]
				var lp2: float = track.curve.get_closest_offset(track.to_local(c.global_position))
				print("t=%5.1f %s RESPAWN (%s)%s, lap %.0fm, %s" % [t, c.name, "drowned" if c.is_drowned else ("blown up" if c.is_exploding else "fell/stuck"),
						where, lp2, c.global_position])
			tele[c] = tl
			# Stuck: under 2 m/s for 3s while racing on a shortcut.
			if on != "" and c.can_move and c.linear_velocity.length() < 2.0:
				stuck[c] = float(stuck.get(c, 0.0)) + get_physics_process_delta_time()
				if absf(float(stuck[c]) - 3.0) < get_physics_process_delta_time() * 0.6:
					var alt3: Path3D = c.active_path
					print("t=%5.1f %s STUCK on %s at %.0fm, %s" % [t, c.name, on, alt3.curve.get_closest_offset(alt3.to_local(c.global_position)), c.global_position])
					trouble[on] = int(trouble.get(on, 0)) + 1
			else:
				stuck[c] = 0.0
	print("\nSUMMARY")
	for alt in level.alternative_paths:
		print("  %s: taken %d times, %d respawns/stalls on it" % [alt.name, int(taken.get(String(alt.name), 0)), int(trouble.get(String(alt.name), 0))])
