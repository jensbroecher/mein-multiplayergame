extends Node

# The menus' music through Main (MusicManager.play_menu_music), headless: it starts with Main on the main theme, keeps
# playing through car select, crossfades to the headquarters' own and back, fades out once a race's level loads, and
# the race's music starts at GO. Prints PASS or FAIL lines.
#   Godot --headless --path . res://scratch/menu_music_test.tscn [-- level=Lakeside]

var main: Node
var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _track() -> String:
	var ap: AudioStreamPlayer = MusicManager.active_player
	return ap.stream.resource_path if ap and ap.stream and ap.playing else "(none)"


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	main = load("res://Main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	_check(_track() == MusicManager.MENU_MAIN_THEME, "the main theme plays from the start (%s)" % _track())
	main.car_selection.show()
	await _frames(10)
	main.car_selection.hide()
	_check(MusicManager.is_menu_music_playing(), "still the menus' music after car select")
	main.main_menu.garage_pressed.emit()
	for i in 400:
		await get_tree().process_frame
		if main.garage != null and main.garage._started:
			break
	await _frames(5)
	_check(_track().begins_with("res://music/headquarters/"), "the headquarters plays its own (%s)" % _track())
	main.garage.finished.emit()
	await get_tree().create_timer(3.0).timeout
	_check(MusicManager.is_menu_music_playing(), "back to the menus' music (%s)" % _track())
	main.main_menu.hide()
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_GP
	NetworkManager.current_gp_name = "Bloombay GP"
	NetworkManager.current_gp_stage = 0
	NetworkManager.start_single_player("Tester")
	main.start_game(true)
	var level: Node = null
	var t0 := Time.get_ticks_msec()
	var faded_at := -1.0
	var race_track := ""
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if level == null:
			level = get_tree().get_first_node_in_group("level")
			continue
		if faded_at < 0.0 and not MusicManager.active_player.playing and not MusicManager.inactive_player.playing:
			faded_at = (Time.get_ticks_msec() - t0) / 1000.0
		if MusicManager.active_player.playing and not MusicManager.is_menu_music_playing():
			race_track = _track()
			break
	_check(faded_at > 0.0, "the menus' music faded out as the level loaded (silent at %.1fs)" % faded_at)
	_check(race_track != "" and not race_track.begins_with(MusicManager.MENU_MUSIC_FOLDER), "the race's music at GO (%s)" % race_track)
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()
