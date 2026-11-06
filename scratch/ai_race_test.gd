extends Node

# Races 6 AI carts around a level headless and reports lap times, respawns (with where they
# happened) and how far each cart got, and each cart's laps in game seconds (FLYING LAPS: the mean of the laps after the
# first). cars= picks each bot's car (CAR_PRESETS indices).
#   Godot --headless --path . res://scratch/ai_race_test.tscn -- res://levels/X.tscn [seconds=300] [speed=4]
#       [weather=0..1] [cars=5,5,0,1,2,3] [noitems=1] [hide=<node name>]
# nodrift=1 sets every bot's ai_drift_chance to 0 (to tell what drifting does to a race).
# noitems=1 frees every item box (to tell what an item box does to a lap from what the course does).
# It prints each jump lip's crossing speeds (TrackPath's "jump_lips"), and REJOIN-ON-ROAD when a bot goes into
# off-course recovery while it is over the road (that once made every bot brake on the kickers).

var seconds := 300.0
var speed := 4.0
var weather := -1.0
var cars: PackedStringArray = []
var no_items := false
var no_drift := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	for a in args:
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
		elif a.begins_with("weather="):
			weather = float(a.substr(8))
		elif a.begins_with("cars="):
			cars = a.substr(5).split(",")
		elif a == "noitems=1":
			no_items = true
		elif a == "nodrift=1":
			no_drift = true
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	for i in mini(cars.size(), 6):
		NetworkManager.players[100 + i]["car_index"] = int(cars[i])
	var level: Node = load(level_path).instantiate()
	add_child(level)
	for wname in ["NorthlightWeather", "JungleRain", "HaboobWeather"]:
		if weather >= 0.0 and level.get_node_or_null(wname):
			level.get_node(wname).force_intensity = weather
	if no_items:
		for i in 10:
			await get_tree().physics_frame
		for n in level.find_children("*ItemBox*", "Node3D", true, false):
			if n.get_parent() == level or n.get_parent().name == "ItemBoxes":
				n.queue_free()
	Engine.time_scale = speed
	var track: Path3D = level.track_path
	var length: float = track.curve.get_baked_length()
	var carts: Array = []
	var was_tele := {}
	var last_pos := {}
	var respawns := {}
	var best_prog := {}
	var trail := {}
	var under := {}
	var on_route := {}
	# Each cart's speed as it crosses each jump lip (TrackPath's "jump_lips"): a bot that brakes on a kicker shows here.
	var lips: Array = track.get_meta(&"jump_lips", [])
	var lip_speeds := {}
	var lip_last := {}
	var rejoin_warned := {}
	# Drifts: how many each cart began and how long it held them.
	var drifts := {}
	var fin_at := {}
	var fin_rest := {}
	# Each cart's laps in game time (the physics delta summed), from the green light (race_state RACING).
	var lap_marks := {}
	var go_t := -1.0
	var drift_time := {}
	var was_drift := {}
	var drift_start := {}
	var t := 0.0
	var next_report := 20.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if carts.is_empty():
			carts = get_tree().get_nodes_in_group("player_carts")
			for c in carts:
				was_tele[c] = false
				respawns[c] = []
				best_prog[c] = 0.0
				if no_drift:
					c.set("ai_drift_chance", 0.0)
		if go_t < 0.0 and level.get("race_state") == level.RaceState.RACING:
			go_t = t
		for c in carts:
			if not is_instance_valid(c):
				continue
			if go_t >= 0.0:
				var lp: int = int(level.player_stats.get(c.name.to_int(), {}).get("laps", 0))
				if not lap_marks.has(c):
					lap_marks[c] = [go_t]
				while (lap_marks[c] as Array).size() - 1 < lp:
					(lap_marks[c] as Array).append(t)
			# Where each cart is when it finishes, and where it comes to rest after.
			if c.is_finished_race and not fin_at.has(c):
				fin_at[c] = c.global_position
				var fl: Node3D = level.get_node_or_null("FinishLine")
				if fl == null:
					fl = level.get_node_or_null("StartLine")
				var to_line: float = -1.0
				if fl:
					to_line = Vector2(c.global_position.x - fl.global_position.x, c.global_position.z - fl.global_position.z).length()
				print("FINISHED %s at %s, %.1f m/s, %.0fm from the finish gate" % [c.name, c.global_position, c.linear_velocity.length(), to_line])
			elif fin_at.has(c) and not fin_rest.has(c) and c.linear_velocity.length() < 0.5:
				fin_rest[c] = c.global_position
				print("AT REST %s at %s, %.1fm on from where it finished" % [c.name, c.global_position, c.global_position.distance_to(fin_at[c])])
			var route: String = str(c.active_path.name) if c.on_alternative_path and c.active_path else ""
			if route != str(on_route.get(c, "")):
				if route != "":
					print("ROUTE %s takes %s" % [c.name, route])
				on_route[c] = route
			var tele: bool = c.is_teleporting
			if tele and not was_tele[c]:
				var p: Vector3 = last_pos.get(c, c.global_position)
				var off: float = track.curve.get_closest_offset(track.to_local(p))
				respawns[c].append("%.0fm(%s y%.0f)" % [off, "drown" if c.is_drowned else ("boom" if c.is_exploding else "fall"), p.y])
				print("RESPAWN %s from %.0fm%s; last moments:" % [c.name, off, " (blown up)" if c.is_exploding else ""])
				var tr0: Array = trail.get(c, [])
				for k in range(maxi(0, tr0.size() - 90), tr0.size(), 10):
					print("    ", tr0[k])
			was_tele[c] = tele
			var dr: bool = c.get("drift_mode") == true
			if dr and not was_drift.get(c, false):
				drifts[c] = int(drifts.get(c, 0)) + 1
				drift_start[c] = t
			if dr:
				drift_time[c] = float(drift_time.get(c, 0.0)) + get_physics_process_delta_time()
				# A drift held over 4s is stuck on (a bot circling in it): say where, every 2s it lasts.
				var held: float = t - float(drift_start.get(c, t))
				if held > 4.0 and fmod(held, 2.0) < get_physics_process_delta_time() * 1.01:
					print("LONG DRIFT %s %.0fs at %s %.1f m/s, charge %.2f, offset %.0fm" % [c.name, held, c.global_position.snapped(Vector3.ONE * 0.1),
						c.linear_velocity.length(), float(c.get("_drift_charge_time")), track.curve.get_closest_offset(track.to_local(c.global_position))])
			was_drift[c] = dr
			if not tele:
				for li in range(lips.size()):
					# A lip is a dictionary with its place, or (Canyon) just its distance along the lap.
					var lip: Vector3 = lips[li]["lip"] if lips[li] is Dictionary else track.to_global(track.curve.sample_baked(float(lips[li])))
					var key := "%s/%d" % [c.name, li]
					if Vector2(lip.x - c.global_position.x, lip.z - c.global_position.z).length() < 4.0 and t - float(lip_last.get(key, -99.0)) > 4.0:
						lip_last[key] = t
						if not lip_speeds.has(li):
							lip_speeds[li] = []
						lip_speeds[li].append(c.linear_velocity.length())
			# A bot in off-course recovery while over the road (within 9m of the lap in plan, near its height): the
			# recovery taking a bot on a jump for lost made it brake on the lip and drive off the road.
			if not tele and c.get("_ai_recover_goal") != Vector3.ZERO and c.get("_ai_recover_goal") != null:
				var lp2: Vector3 = track.to_global(track.curve.get_closest_point(track.to_local(c.global_position)))
				if Vector2(lp2.x - c.global_position.x, lp2.z - c.global_position.z).length() < 9.0 and not rejoin_warned.has(c):
					rejoin_warned[c] = true
					print("REJOIN-ON-ROAD %s at %.0fm (%.1fm over the lap)" % [c.name, track.curve.get_closest_offset(track.to_local(c.global_position)),
							c.global_position.y - lp2.y])
			if not tele:
				# First moment a cart drops well below anything drivable: where, how fast, on what.
				if c.global_position.y < -4.0 and last_pos.get(c, Vector3.ZERO).y >= -4.0:
					var lp: Vector3 = last_pos.get(c, c.global_position)
					print("FALL %s at %s (was %s) vel %s off %.0fm" % [c.name, c.global_position, lp, c.linear_velocity,
							track.curve.get_closest_offset(track.to_local(lp))])
					for e in trail.get(c, []):
						print("    ", e)
				last_pos[c] = c.global_position
				var tr: Array = trail.get(c, [])
				var gc = c.ground_ray.get_collider() if c.ground_ray.is_colliding() else null
				tr.append("%s v%s ground=%s grip=%.2f" % [c.global_position, c.linear_velocity, gc.name if gc else "-", c.surface_grip])
				if tr.size() > 90:
					tr.pop_front()
				trail[c] = tr
				# First moment a cart is underneath a road deck: where it got in.
				if gc and str(gc.name) == "Icefield" and not under.has(c):
					var q := PhysicsRayQueryParameters3D.create(c.global_position + Vector3.UP * 5.0, c.global_position)
					q.exclude = [c.get_rid()]
					var hit := (c as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
					if hit and str(hit.collider.name).contains("Road"):
						under[c] = true
						print("UNDER %s at %s below %s (%.2f)" % [c.name, c.global_position, hit.collider.name, hit.position.y])
						for e in tr:
							print("    ", e)
		if t >= next_report:
			next_report += 20.0
			var line := "t=%3.0fs" % t
			for c in carts:
				var st: Dictionary = level.player_stats.get(c.name.to_int(), {})
				var off: float = track.curve.get_closest_offset(track.to_local(c.global_position))
				line += "  %s:L%d/%.0fm %.0fkmh" % [c.name, st.get("laps", 0), off, c.linear_velocity.length() * 3.6]
			print(line)
	for li in range(lips.size()):
		var sp: Array = lip_speeds.get(li, [])
		if sp.is_empty():
			print("LIP %s: no cart crossed it" % (lips[li]["name"] if lips[li] is Dictionary else "at %.0fm" % float(lips[li])))
			continue
		var lo := 999.0
		var sum := 0.0
		for v in sp:
			lo = minf(lo, v)
			sum += v
		print("LIP %s: %d crossings, %.1f m/s on average, slowest %.1f" % [lips[li]["name"] if lips[li] is Dictionary else "at %.0fm" % float(lips[li]), sp.size(), sum / sp.size(), lo])
	var all_laps: Array = []
	for c in carts:
		var st: Dictionary = level.player_stats.get(c.name.to_int(), {})
		var lt: Array = []
		var marks: Array = lap_marks.get(c, [])
		for i in range(1, marks.size()):
			lt.append("%.1f" % (float(marks[i]) - float(marks[i - 1])))
			if i > 1:
				all_laps.append(float(marks[i]) - float(marks[i - 1]))
		print("CART %s car=%d laps=%d finished=%s respawns=%d %s drifts=%d (%.1fs) laps_s=[%s]" % [c.name, c.car_index, st.get("laps", 0), st.get("finished", false),
				respawns[c].size(), respawns[c], int(drifts.get(c, 0)), float(drift_time.get(c, 0.0)), ", ".join(lt)])
	# The flying laps (each cart's second and third: the first starts from the grid), in game seconds.
	if not all_laps.is_empty():
		all_laps.sort()
		var sum := 0.0
		for v in all_laps:
			sum += v
		print("FLYING LAPS %d: mean %.1fs, median %.1fs, best %.1fs" % [all_laps.size(), sum / all_laps.size(), all_laps[all_laps.size() / 2], all_laps[0]])
	get_tree().quit()
