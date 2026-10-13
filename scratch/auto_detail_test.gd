extends Node

# Watches Auto vegetation detail (MusicManager) settle during a real spectator race: 6 AI carts,
# the spectator camera, the player's other graphics settings. Prints the level of detail, FPS and
# the main viewport's GPU time every few seconds, and every step Auto takes. The setting is pinned
# to Auto in memory only (nothing is saved). Run windowed:
#   Godot --path . res://scratch/auto_detail_test.tscn -- <level.tscn> [seconds=90] [start=0..4]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var seconds := 90.0
	var start := -1
	for a in args:
		if a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("start="):
			start = int(a.substr(6))
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	MusicManager.set_grass_setting(0, false)
	var level: Node = load(level_path).instantiate()
	add_child(level)
	if start >= 0:
		await get_tree().process_frame
		MusicManager.set_grass_quality(start, false)
	var rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var t0 := Time.get_ticks_msec()
	var next := 5.0
	var last_q := -1
	var gpu_sum := 0.0
	var frames := 0
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await get_tree().process_frame
		gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		frames += 1
		var t: float = (Time.get_ticks_msec() - t0) / 1000.0
		if MusicManager.grass_quality_index != last_q:
			last_q = MusicManager.grass_quality_index
			print("t=%5.1fs  detail -> %s" % [t, MusicManager.GRASS_QUALITY_NAMES[last_q]])
		if t >= next:
			next += 5.0
			print("t=%5.1fs  detail=%s  fps=%d  gpu=%.1fms" % [t, MusicManager.GRASS_QUALITY_NAMES[MusicManager.grass_quality_index],
					Engine.get_frames_per_second(), gpu_sum / float(maxi(frames, 1))])
			gpu_sum = 0.0
			frames = 0
	get_tree().quit()
