extends Node
## Photographs the race screens over a level: the HUD (place, lap, speed, a message), the end panel (a race's table,
## a Grand Prix's, an arena match's) and the pause menu, to judge HudStyle.gd's look side by side.
## Windowed:
##   Godot --path . --resolution 1600x900 res://scratch/race_screens_shot.tscn -- <dir> [level=res://levels/X.tscn]
##        [cam=x,y,z:tx,ty,tz] [size=1600x900]

var out_dir := ""
var level_path := "res://levels/TestTrackLevel.tscn"
var cam_spot: Array = []
var win_size := Vector2i(1600, 900)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("cam="):
			var pt := a.substr(4).split(":")
			var p := pt[0].split(",")
			var t := pt[1].split(",")
			cam_spot = [Vector3(float(p[0]), float(p[1]), float(p[2])), Vector3(float(t[0]), float(t[1]), float(t[2]))]
		elif a.begins_with("size="):
			var wh := a.substr(5).split("x")
			win_size = Vector2i(int(wh[0]), int(wh[1]))
		elif not a.begins_with("--"): out_dir = a
	if out_dir == "":
		push_error("give an output dir")
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	AudioServer.set_bus_mute(0, true)
	get_window().size = win_size
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	var cam := Camera3D.new()
	cam.far = 4000.0
	add_child(cam)
	if cam_spot.is_empty():
		var path: Path3D = level.get_node_or_null("TrackPath")
		var xf := path.global_transform * path.curve.sample_baked_with_rotation(40.0, true)
		var fwd := -xf.basis.z
		fwd.y = 0.0
		cam_spot = [xf.origin - fwd.normalized() * 14.0 + Vector3.UP * 9.0, xf.origin + fwd.normalized() * 20.0]
	cam.global_position = cam_spot[0]
	cam.look_at(cam_spot[1], Vector3.UP)
	for i in 30:
		await get_tree().process_frame
	cam.make_current()
	var ui = level.get_node("RaceUI")
	# The spectator's own overlay sits over the place: hide it, the shots are of the racer's HUD.
	for n in level.find_children("*", "Label", true, false):
		if (n as Label).text.begins_with("SPECTATING") or (n as Label).text.contains("Auto-Switch"):
			n.hide()
	for i in 60:
		await get_tree().process_frame
	cam.make_current()
	ui.show_hud()
	ui.update_hud(2, 8, 2, 3)
	ui.update_speed(147.0)
	ui.update_items("BOOST", "SHIELD")
	ui.show_message("FINAL LAP")
	await _shot("hud_2nd")
	ui.update_hud(1, 8, 3, 3)
	ui.update_speed(88.0)
	ui.update_end_timer(23)
	await _shot("hud_1st_countdown")
	ui.update_hud(11, 12, 1, 1, 0.42)
	ui.update_speed(7.0)
	ui.show_message("")
	await _shot("hud_11th")

	var names := ["Mudrunner", "Viper", "Basilisk", "Crimson", "Sandpiper", "Titan", "Ninja", "Jukebox"]
	var rows: Array = []
	for i in names.size():
		rows.append({"pos": i + 1, "name": names[i], "time_ms": 182345 + i * 2410 + i * i * 300,
				"laps_ms": [61000 + i * 700, 60500 + i * 900 - (1800 if i == 3 else 0), 60845 + i * 800],
				"is_bot": i != 2, "round_points": maxi(0, 10 - i), "total_points": 30 - i * 3})
	# The third row is the local player's (its row is tinted gold).
	if not NetworkManager.players.has(1):
		NetworkManager.players[1] = {}
	NetworkManager.players[1]["name"] = "Basilisk"
	ui.display_race_results(rows)
	await _shot("end_race")

	var pause: Control = load("res://PauseMenu.tscn").instantiate()
	ui.end_panel.hide()
	ui._end_dim.hide()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	layer.add_child(pause)
	pause.show_pause_menu()
	await _shot("pause")
	pause.hide()

	var arena: Array = []
	for i in 6:
		arena.append({"pos": i + 1, "name": names[i], "team_name": "RED" if i % 2 == 0 else "BLUE",
				"team_color": Color(1, 0.3, 0.3) if i % 2 == 0 else Color(0.3, 0.6, 1), "stat": 5 - i, "score": 50 - i * 8,
				"is_bot": i != 0, "arena": true, "headline": "RED WINS 9 : 6" if i == 0 else "", "stat_name": "GOALS"})
	ui.display_race_results(arena)
	await _shot("end_arena")
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)
