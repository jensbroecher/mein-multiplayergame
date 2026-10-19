extends Node
# Starts a spectator race with the given cars and lists each one's engine loop (length, loop
# settings, gain) and, once GO has happened and they drive, the volume and pitch they play at.
#   Godot --headless --path . res://scratch/engine_sound_test.tscn -- cars=0,1,2,3,4,5
func _ready() -> void:
	var cars: PackedStringArray = ["0", "1", "2", "3", "4", "5"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cars="):
			cars = a.substr(5).split(",")
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	for i in cars.size():
		NetworkManager.players[100 + i]["car_index"] = int(cars[i])
	var level: Node = load("res://levels/Level.tscn").instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	await get_tree().create_timer(14.0).timeout
	for i in cars.size():
		var c: Node = level.find_child(str(100 + i), true, false)
		var st := c.engine_sound.stream as AudioStreamWAV
		print("%-12s loop %5.2fs  mode=%d end=%d/%d frames  gain %+5.1f dB  playing=%s vol=%+5.1f pitch=%.2f speed=%.0f" % [
			c.CAR_PRESETS[c.car_index]["name"], st.get_length(), st.loop_mode, st.loop_end,
			st.data.size() / (4 if st.stereo else 2), c._engine_gain_db, c.engine_sound.playing,
			c.engine_sound.volume_db, c.engine_sound.pitch_scale, c.linear_velocity.length()])
	get_tree().quit()
