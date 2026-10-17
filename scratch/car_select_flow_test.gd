extends Node
# Drives Main.tscn's menu flow round the car select screen and prints what is visible at each step:
# open it, change car, back to the menu; change car from a lobby room and back; split-screen
# player 2 backing out to player 1.  Godot --headless --path . res://scratch/car_select_flow_test.tscn
func _ready() -> void:
	var main: Node = load("res://Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var cs: Control = main.get_node("CarSelection")
	var menu: Control = main.get_node("MainMenu")
	print("start: car_select visible=", cs.visible, " menu visible=", menu.visible)
	menu.hide()
	main._on_menu_start_pressed()
	await get_tree().process_frame
	print("opened: car_select visible=", cs.visible, " title=", cs._title.text, " car=", cs.current_car_index)
	cs._change_car(1)
	cs._change_car(1)
	await get_tree().process_frame
	print("after 2 next: car=", cs.current_car_index, " name=", cs._name_label.text)
	cs._select_car(6)
	print("picked 6: name=", cs._name_label.text, " paintable=", cs._is_paintable())
	# Cycling saves to the player's settings: put their paint job back afterwards.
	var saved: Dictionary = cs.current_paint.duplicate()
	cs._cycle("pattern", 1)
	print("pattern now ", cs.current_paint.get("pattern"))
	cs.current_paint = saved
	cs._paint_changed()
	cs._on_back_pressed()
	await get_tree().process_frame
	print("back: car_select visible=", cs.visible, " menu visible=", menu.visible)
	# Lobby path: change car from the room, then back to the room.
	var lobby: Control = main.get_node("Lobby")
	lobby.is_in_room = true
	main._on_lobby_change_car_requested()
	await get_tree().process_frame
	print("from lobby: car_select visible=", cs.visible, " lobby visible=", lobby.visible)
	cs._on_back_pressed()
	await get_tree().process_frame
	print("back to lobby: car_select visible=", cs.visible, " lobby visible=", lobby.visible, " in_room=", lobby.is_in_room)
	lobby.is_in_room = false
	lobby.hide()
	# Split-screen: player 2 backs out to player 1.
	main._coop_selecting_p2 = true
	cs.show_for_player(2)
	await get_tree().process_frame
	print("p2: title=", cs._title.text, " sub=", cs._subtitle.text, " slot=", cs.player_slot)
	cs._on_back_pressed()
	await get_tree().process_frame
	print("p2 back: title=", cs._title.text, " slot=", cs.player_slot, " visible=", cs.visible, " selecting_p2=", main._coop_selecting_p2)
	get_tree().quit(0)
