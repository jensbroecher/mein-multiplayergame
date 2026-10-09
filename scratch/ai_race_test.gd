extends Node

# Races 6 AI carts around a level headless and reports lap times, respawns (with where they
# happened) and how far each cart got.
#   Godot --headless --path . res://scratch/ai_race_test.tscn -- res://levels/X.tscn [seconds=300] [speed=4] [weather=0..1]

var seconds := 300.0
var speed := 4.0
var weather := -1.0

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
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	if weather >= 0.0 and level.get_node_or_null("NorthlightWeather"):
		level.get_node("NorthlightWeather").force_intensity = weather
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
		for c in carts:
			if not is_instance_valid(c):
				continue
			var tele: bool = c.is_teleporting
			if tele and not was_tele[c]:
				var p: Vector3 = last_pos.get(c, c.global_position)
				var off: float = track.curve.get_closest_offset(track.to_local(p))
				respawns[c].append("%.0fm(%s y%.0f)" % [off, "drown" if c.is_drowned else "fall", p.y])
				print("RESPAWN %s from %.0fm; last moments:" % [c.name, off])
				var tr0: Array = trail.get(c, [])
				for k in range(maxi(0, tr0.size() - 90), tr0.size(), 10):
					print("    ", tr0[k])
			was_tele[c] = tele
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
	for c in carts:
		var st: Dictionary = level.player_stats.get(c.name.to_int(), {})
		print("CART %s car=%d laps=%d finished=%s respawns=%d %s" % [c.name, c.car_index, st.get("laps", 0), st.get("finished", false), respawns[c].size(), respawns[c]])
	get_tree().quit()
