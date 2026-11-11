extends SceneTree
## The kill feed's "(YOU)": only the human driving on this peer gets it. In a single race every cart, the bots too, holds
## the one RaceUI as its race_ui, and a bot listed before the human ("Ninja" here) was called "(YOU)" when it bombed
## another bot. Headless: Godot --headless --path . -s res://scratch/test_you_highlight.gd

class MockCart extends Node3D:
	var race_ui = null
	var injected_race_ui = null
	var player_name: String = "Jens"
	var is_local_player: bool = true
	var is_ai: bool = false
	var device_id: int = -1


func _labels(race_ui) -> String:
	var card = race_ui.killfeed_container.get_child(race_ui.killfeed_container.get_child_count() - 1)
	var hbox = card.get_child(0)
	var out: Array = []
	for n in hbox.get_children():
		if n is Label:
			out.append(n.text)
	return " | ".join(out)


func _initialize() -> void:
	var race_ui = load("res://RaceUI.tscn").instantiate()
	root.add_child(race_ui)

	# Bots first in the group, as they were in the race: same RaceUI, local to the server, AI.
	for b in [["1001", "Ninja"], ["1002", "Viper"]]:
		var bot = MockCart.new()
		bot.name = b[0]
		bot.player_name = b[1]
		bot.is_ai = true
		bot.is_local_player = false
		bot.race_ui = race_ui
		bot.add_to_group("player_carts")
		root.add_child(bot)
	var me = MockCart.new()
	me.name = "1"
	me.race_ui = race_ui
	me.add_to_group("player_carts")
	root.add_child(me)

	await process_frame
	await process_frame

	var ok := true
	race_ui.show_explosion_notice("Ninja", "Viper", 1001, 1002, "BOMB")
	var t1 := _labels(race_ui)
	print("bot on bot: ", t1)
	if t1.contains("(YOU)"):
		ok = false
	race_ui.show_explosion_notice("Jens", "Ninja", 1, 1001, "MISSILE")
	var t2 := _labels(race_ui)
	print("me on bot:  ", t2)
	if not t2.contains("Jens (YOU)") or t2.contains("Ninja (YOU)"):
		ok = false
	race_ui.show_explosion_notice("Viper", "Jens", 1002, 1, "BOMB")
	var t3 := _labels(race_ui)
	print("bot on me:  ", t3)
	if not t3.contains("Jens (YOU)") or t3.contains("Viper (YOU)"):
		ok = false
	print("YOU highlight test %s" % ("PASSED" if ok else "FAILED"))
	quit(0 if ok else 1)
