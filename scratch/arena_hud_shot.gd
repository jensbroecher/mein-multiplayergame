extends Node
## Plays an arena match as a single player (the human's car standing still, five bots) in a window and saves the screen,
## HUD and all, at the given seconds after the green light:
##   Godot --path . res://scratch/arena_hud_shot.tscn -- <football|ctf> <dir> [teams=1] [at=8,30] [speed=1] [drive=1]
## drive=1 lets a bot drive the human's car (arena_target as a bot's), so the camera follows the play.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var kind: String = args[0]
	var dir: String = args[1]
	var teams := false
	var times: Array = [8.0, 30.0]
	var speed := 1.0
	var drive := false
	for a in args:
		if a == "teams=1":
			teams = true
		elif a.begins_with("at="):
			times = []
			for t in a.substr(3).split(","):
				times.append(float(t))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
		elif a == "drive=1":
			drive = true
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	NetworkManager.arena = {"kind": kind, "teams": teams}
	NetworkManager.start_single_player("Jabro")
	var level: Node = load(NetworkManager.arena_level()).instantiate()
	add_child(level)
	while level.race_state != 1:
		await get_tree().process_frame
	var me: Node = level.get_node("Players/1")
	while not bool(me.get("can_move")):
		await get_tree().process_frame
	Engine.time_scale = speed
	if drive:
		me.set("is_ai", true)
	var t0 := Time.get_ticks_msec()
	var game: Node = level.get_node("ArenaGame")
	for t in times:
		while (Time.get_ticks_msec() - t0) * 0.001 * speed < float(t):
			if drive and game.has_method("_football_bot"):
				pass
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s_%02d.png" % [dir, kind, int(t)]
		img.save_png(path)
		print("SHOT ", path)
	get_tree().quit()
