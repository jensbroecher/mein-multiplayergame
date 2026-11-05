extends Node

# Starts a single-player GP race (the human, id 1, against the bots) with the anti-aliasing applied the way the
# game does it (MusicManager.set_anti_aliasing on the root viewport) and logs, every half second from the level's
# load, the race's phase and the frame's mean brightness and contrast (the 5th and 95th percentile of luma), saving
# a frame at each log when a directory is given. For the 4x MSAA washout (fine at 2x and FXAA). Windowed:
#   Godot --path . --resolution 1600x900 res://scratch/msaa_brightness_probe.tscn -- [<dir>] [level=...] [aa=2]
#       [seconds=16] [every=0.5] [noread]
# detail: the Detail Level setting held (0 Auto, 1 Off ... 5 Ultra); default the player's.
# noread (without a dir) logs only the phase and frame rate, without reading the image back.
# aa: 0 off, 1 2x, 2 4x, 3 8x, 4 FXAA (MusicManager's indices).

func _ready() -> void:
	var dir := ""
	var level_path := "res://levels/LakesideLevel.tscn"
	var aa := 2
	var seconds := 16.0
	var every := 0.5
	var no_read := false
	var detail := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("aa="): aa = int(a.substr(3))
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
		elif a.begins_with("every="): every = float(a.substr(6))
		elif a == "noread": no_read = true
		elif a.begins_with("detail="): detail = int(a.substr(7))
		elif not a.contains("="): dir = a
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	MusicManager.set_anti_aliasing(aa, false)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.start_single_player("Tester")
	var level: Node = load(level_path).instantiate()
	add_child(level)
	MusicManager.refresh_level_graphics()
	if detail >= 0:
		MusicManager.set_grass_setting(detail, false)
	var t0 := Time.get_ticks_msec()
	var next := 0.0
	var k := 0
	while true:
		await RenderingServer.frame_post_draw
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if t > seconds:
			break
		if t < next:
			continue
		next += every
		var img: Image = get_viewport().get_texture().get_image() if dir != "" or not no_read else null
		var stats := _luma(img) if img else Vector3.ZERO
		var cart: Node = level.players_container.get_node_or_null("1")
		var phase := "lobby"
		if level.race_state == level.RaceState.RACING:
			phase = "racing"
			if cart and cart.get("is_intro_active"):
				phase = "intro"
			elif cart and not cart.get("can_move"):
				phase = "countdown"
		var cam: Camera3D = get_viewport().get_camera_3d()
		print("t=%5.2f %-9s mean %.3f  p5 %.3f  p95 %.3f  fps %d  size %s  cam %s  msaa %d" % [t, phase, stats.x, stats.y, stats.z,
			Engine.get_frames_per_second(), str(get_viewport().get_visible_rect().size), str(cam.get_path()) if cam else "-",
			get_viewport().msaa_3d])
		if dir != "":
			img.save_png(dir.path_join("f%03d_%s.png" % [k, phase]))
		k += 1
	get_tree().quit()


## Mean luma, 5th and 95th percentile, over a grid of samples.
func _luma(img: Image) -> Vector3:
	var vals := PackedFloat32Array()
	var w := img.get_width()
	var h := img.get_height()
	var sum := 0.0
	for y in range(0, h, 30):
		for x in range(0, w, 30):
			var c := img.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			vals.append(l)
			sum += l
	vals.sort()
	return Vector3(sum / vals.size(), vals[int(vals.size() * 0.05)], vals[int(vals.size() * 0.95)])
