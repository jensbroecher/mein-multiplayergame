extends Node
## Plays a few seconds of an arena match as a single player, headless, and prints the end panel's title once the
## match is over (it must say "Match Finished!", not the races' "Race Finished!"), and the menus' names for the
## football arena (MainMenu's tiles, the lobby's modes: "Hex Bowl").
##   Godot --headless --path . res://scratch/arena_end_title_check.tscn -- [football|ctf] [seconds=4]

func _ready() -> void:
	var kind := "football"
	var seconds := 4.0
	for a in OS.get_cmdline_user_args():
		if a == "football" or a == "ctf":
			kind = a
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	NetworkManager.arena = {"kind": kind, "teams": false}
	NetworkManager.start_single_player("Jabro")
	var level: Node = load(NetworkManager.arena_level()).instantiate()
	add_child(level)
	level.get_node("ArenaGame").match_seconds = seconds
	while level.race_state != 2:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	var bad := 0
	for ui in level._all_race_uis():
		var title := ui.get_node_or_null("EndPanel/VBoxContainer/LabelFinished") as Label
		var text := title.text if title else "(no title)"
		print("end title: \"%s\" (panel shown: %s)" % [text, str(ui.get_node("EndPanel").visible)])
		if text != "Match Finished!":
			bad += 1
	var lobby_src := FileAccess.get_file_as_string("res://Lobby.gd")
	var menu_src := FileAccess.get_file_as_string("res://MainMenu.gd")
	for pair in [["lobby", lobby_src, "Arena: Hex Bowl (Teams)"], ["menu", menu_src, "HEX BOWL  •  TEAMS"]]:
		var has: bool = (pair[1] as String).contains(pair[2])
		print("%s names it \"%s\": %s" % [pair[0], pair[2], str(has)])
		if not has:
			bad += 1
	print("PASS" if bad == 0 else "FAIL (%d)" % bad)
	get_tree().quit()
