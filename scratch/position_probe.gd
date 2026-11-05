extends Node

# Starts a single-player GP race (the human, id 1, against the bots) and carries the human along the lap line ahead of
# everyone, a few metres a frame (frozen, as missed_checkpoint_test does), printing every 2s each racer's laps, next
# gate, the ranking's score and the position it gives (Level._update_positions). The human should lead. Headless:
#   Godot --headless --path . res://scratch/position_probe.tscn -- [level=res://levels/MtaaNightsLevel.tscn] [seconds=40]
#       [step=0.6] (metres a physics frame: 0.6 is 36 m/s)

func _ready() -> void:
	var level_path := "res://levels/MtaaNightsLevel.tscn"
	var seconds := 40.0
	var step := 0.6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
		elif a.begins_with("step="): step = float(a.substr(5))
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.start_single_player("Tester")
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	var cart: RigidBody3D = level.players_container.get_node("1")
	while not cart.can_move:
		await get_tree().physics_frame
	cart.freeze = true
	var path: Path3D = level.track_path
	var curve: Curve3D = path.curve
	var length := curve.get_baked_length()
	var off := curve.get_closest_offset(path.to_local(cart.global_position))
	print("track %.0fm, gates at %s, human starts at %.0f" % [length, str(level.cp_offsets), off])
	var t := 0.0
	var next_log := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		off = fmod(off + step, length)
		var p: Vector3 = path.to_global(curve.sample_baked(off))
		var q: Vector3 = path.to_global(curve.sample_baked(fmod(off + 2.0, length)))
		var xf := Transform3D(Basis.looking_at((q - p).normalized(), Vector3.UP), p + Vector3.UP * 0.9)
		PhysicsServer3D.body_set_state(cart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		cart.global_transform = xf
		if t >= next_log:
			next_log += 2.0
			var line := "t=%4.1f human@%.0f |" % [t, off]
			var ids: Array = level.player_stats.keys()
			ids.sort()
			for id in ids:
				var st: Dictionary = level.player_stats[id]
				line += " %s: L%d g%d pos%d" % [str(id), int(st["laps"]), int(st["next_checkpoint_idx"]), int(st.get("pos", 0))]
			print(line)
	get_tree().quit()
