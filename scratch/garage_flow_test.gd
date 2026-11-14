extends Node

const Guard = preload("res://scratch/user_file_guard.gd")

# The garage's flow through Main, headless: the menu's GARAGE tile opens it, a car is taken out of the
# line-up there (and the last one can't be), Esc leaves it, and the car select screen then offers only the
# line-up; a Grand Prix podium records a trophy, and a GP TEST from a later stage doesn't. Prints PASS or
# FAIL lines and puts settings.cfg's line-up and trophies.cfg back as they were.
#   Godot --headless --path . res://scratch/garage_flow_test.tscn

var main: Node
var fails := 0


func _ready() -> void:
	# The player's settings and trophies, copied aside on disk (scratch/user_file_guard.gd): a run killed half way loses
	# nothing.
	Guard.protect("garage_flow_test", ["user://settings.cfg", "user://trophies.cfg"])
	var CC = load("res://CarCollection.gd")
	var T = load("res://Trophies.gd")
	main = load("res://Main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	# Every car in the line-up to start with.
	for i in CC.CAR_PRESETS.size():
		CC.set_in_lineup(i, true)
	main.main_menu.garage_pressed.emit()
	for i in 400:
		await get_tree().process_frame
		if main.garage != null and main.garage._started:
			break
	_check(main.garage != null and main.garage._started, "garage opened and started")
	var g = main.garage
	_check(g._bays.size() == CC.CAR_PRESETS.size(), "a bay per car (%d)" % g._bays.size())
	var ap: AudioStreamPlayer = MusicManager.active_player
	var track: String = ap.stream.resource_path if ap and ap.stream else ""
	_check(ap != null and ap.playing and track.begins_with("res://music/headquarters/"), "its own music plays (%s)" % track)
	var fulmine := -1
	for i in g._bays.size():
		if str(CC.CAR_PRESETS[g._bays[i]["index"]].name) == "Fulmine":
			fulmine = i
	g._toggle_lineup(fulmine)
	_check(not CC.in_lineup(CC.index_of("Fulmine")), "Fulmine left out of the line-up")
	# Leave only one car, then try to take it out.
	for i in CC.CAR_PRESETS.size():
		CC.set_in_lineup(i, i == 0)
	_check(not CC.set_in_lineup(0, false) and CC.lineup() == [0], "the last car stays in the line-up")
	for i in CC.CAR_PRESETS.size():
		CC.set_in_lineup(i, str(CC.CAR_PRESETS[i].name) != "Fulmine")
	# Esc leaves.
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(3)
	print("after Esc: leaving=%s garage=%s busy=%s" % [str(g._leaving) if is_instance_valid(g) else "freed", str(main.garage), str(main.screen_transition.busy)])
	await get_tree().create_timer(3.0).timeout
	_check(main.garage == null and main.main_menu.visible, "Esc went back to the menu")
	_check(MusicManager.is_menu_music_playing(), "back to the menu's music on leaving (%s)" % MusicManager.active_player.stream.resource_path)
	# The car select screen offers the line-up only.
	main.car_selection.show()
	await _frames(5)
	var cs = main.car_selection
	var names: Array = []
	for p in cs._pills:
		names.append(p.text)
	_check(cs._pills.size() == CC.CAR_PRESETS.size() - 1 and not names.has("FULMINE"), "car select offers %d cars, no Fulmine" % cs._pills.size())
	var seen := {}
	for k in cs._lineup.size() + 2:
		cs._change_car(1)
		seen[cs.current_car_index] = true
	_check(not seen.has(CC.index_of("Fulmine")) and seen.size() == cs._lineup.size(), "stepping through cars skips Fulmine")
	cs.hide()
	# Trophies.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://trophies.cfg"))
	var place: int = T.record_gp("Bloombay GP", [{"name": "Bot1", "is_bot": true}, {"name": "Me", "car_index": 10, "is_bot": false}], ["Me"])
	var rec: Dictionary = T.cup("Bloombay GP")
	_check(place == 1 and rec["silver"] == 1 and rec["best"] == 1 and rec["car"] == "Nocturne", "a 2nd place recorded as silver with the Nocturne")
	place = T.record_gp("Bloombay GP", [{"name": "Me", "car_index": 16, "is_bot": false}], ["Me"])
	rec = T.cup("Bloombay GP")
	_check(rec["gold"] == 1 and rec["silver"] == 1 and rec["best"] == 0 and rec["car"] == "Fulmine", "a win raises the best to gold")
	place = T.record_gp("Svartfjell GP", [{"name": "A"}, {"name": "B"}, {"name": "C"}, {"name": "Me", "is_bot": false}], ["Me"])
	_check(place == -1 and T.cup("Svartfjell GP")["best"] == -1, "4th place earns nothing")
	# The menu's GP TEST from stage 2 clears eligibility; a cup from the menu sets it.
	main.main_menu._on_gp_test_stage_selected("Bloombay GP", 2)
	await _frames(2)
	_check(not NetworkManager.gp_trophy_eligible, "GP TEST from a later stage earns no trophy")
	# Put things back.
	Guard.restore("garage_flow_test")
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
