extends Node
# Races Meteors (or any car with a preset "engine_top_loop") in a spectator race and logs cart 100's engine: its
# speed against max_speed, whether the top-speed loop is on, the stream's loop start and the playback position. At the
# end: how long it was at top speed (the bot is made the local player: only that cart plays its engine), and whether its playback stayed in the clip's last stretch once there (after it
# had run on to the clip's end) and went back over the whole clip below it. Headless:
#   Godot --headless --path . res://scratch/engine_top_loop_test.tscn -- [cars=19,19,19,19,19,19] [seconds=60]
#       [level=res://levels/LakesideLevel.tscn]
func _ready() -> void:
	var cars: PackedStringArray = ["19", "19", "19", "19", "19", "19"]
	var seconds := 60.0
	var level_path := "res://levels/LakesideLevel.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cars="):
			cars = a.substr(5).split(",")
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("level="):
			level_path = a.substr(6)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	for i in cars.size():
		NetworkManager.players[100 + i]["car_index"] = int(cars[i])
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	var c: Node = null
	var t := 0.0
	var top_time := 0.0
	var in_tail := 0
	var out_tail := 0
	var below_full := 0
	var settled_at := -1.0
	var last_pos := 0.0
	var last_top := false
	var next_log := 0.0
	var frame_t := 0.0
	var wraps_top := 0
	var wraps_top_bad := 0
	while frame_t < seconds:
		await get_tree().process_frame
		frame_t += get_process_delta_time()
		if c != null and c.engine_sound.stream is AudioStreamWAV:
			var st2 := c.engine_sound.stream as AudioStreamWAV
			var p2: float = c.engine_sound.get_playback_position()
			var tf: float = float(c._engine_top_begin) / st2.mix_rate
			if c._engine_at_top != last_top:
				print("  %.2fs top %s at pos %.3f (speed %.2f)" % [frame_t, c._engine_at_top, p2,
						c.linear_velocity.length() / c.max_speed])
				last_top = c._engine_at_top
			if p2 < last_pos - 0.3:
				var to_tail: bool = p2 >= tf - 0.05
				print("  %.2fs wrap %.3f -> %.3f (top %s)%s" % [frame_t, last_pos, p2, c._engine_at_top,
						"" if to_tail == c._engine_at_top else "  <-- unexpected"])
				if c._engine_at_top:
					wraps_top += 1
					if not to_tail:
						wraps_top_bad += 1
			last_pos = p2
		if frame_t < next_log:
			continue
		next_log += 0.25
		t += 0.25
		if c == null:
			c = level.find_child("100", true, false)
			if c != null:
				# The engine sound only runs for the local player's cart: make this bot it (and keep its camera off it,
				# as PlayerCart's own set-up does).
				c.is_local_player = true
				c.camera_pivot.top_level = true
			continue
		var st := c.engine_sound.stream as AudioStreamWAV
		if st == null:
			continue
		var pos: float = c.engine_sound.get_playback_position()
		var tail_from: float = float(c._engine_top_begin) / st.mix_rate
		var ratio: float = c.linear_velocity.length() / c.max_speed
		if c._engine_at_top:
			top_time += 0.25
			if settled_at < 0.0 and pos >= tail_from:
				settled_at = t
			if settled_at >= 0.0:
				if pos >= tail_from - 0.02:
					in_tail += 1
				else:
					out_tail += 1
		else:
			settled_at = -1.0
			if pos < tail_from:
				below_full += 1
		if int(t * 4.0) % 4 == 0:
			print("t %5.1f  speed %.2f  top %s  loop_begin %6d  pos %.3f / %.3f (tail from %.3f)  playing %s" % [t, ratio,
					c._engine_at_top, st.loop_begin, pos, st.get_length(), tail_from, c.engine_sound.playing])
	print("AT TOP %.1fs; once settled in the tail: %d samples in it, %d outside; below top, %d samples before the tail" % [
			top_time, in_tail, out_tail, below_full])
	print("wraps at top speed: %d, %d of them back to the clip's start" % [wraps_top, wraps_top_bad])
	print("RESULT: %s" % ("PASS" if wraps_top > 0 and wraps_top_bad == 0 else "FAIL"))
	get_tree().quit()
