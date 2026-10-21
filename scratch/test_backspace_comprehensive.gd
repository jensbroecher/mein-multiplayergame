extends Node

func _ready():
	call_deferred("_run_tests")

func _run_tests():
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	main.name = "Main"
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Simulate a race level loaded
	var dummy_level = Node3D.new()
	dummy_level.name = "Level"
	dummy_level.add_to_group("level")
	main.add_child(dummy_level)
	await get_tree().process_frame
	
	print("--- TEST 1: KEY_BACKSPACE with keycode ---")
	var ev1 = InputEventKey.new()
	ev1.pressed = true
	ev1.keycode = KEY_BACKSPACE
	main._input(ev1)
	assert(main.pause_menu.visible == true, "Pause menu should be visible after KEY_BACKSPACE")
	print("PASS: Pause menu opened with Backspace (keycode)")
	main._input(ev1)
	assert(main.pause_menu.visible == false, "Pause menu should hide after 2nd KEY_BACKSPACE")
	print("PASS: Pause menu closed with Backspace (keycode)")

	print("--- TEST 2: KEY_BACKSPACE with only physical_keycode ---")
	var ev2 = InputEventKey.new()
	ev2.pressed = true
	ev2.physical_keycode = KEY_BACKSPACE
	main._input(ev2)
	assert(main.pause_menu.visible == true, "Pause menu should be visible with physical_keycode")
	print("PASS: Pause menu opened with Backspace (physical_keycode)")
	main.pause_menu.hide()

	print("--- TEST 3: KEY_BACKSPACE with only key_label ---")
	var ev3 = InputEventKey.new()
	ev3.pressed = true
	ev3.key_label = KEY_BACKSPACE
	main._input(ev3)
	assert(main.pause_menu.visible == true, "Pause menu should be visible with key_label")
	print("PASS: Pause menu opened with Backspace (key_label)")
	main.pause_menu.hide()

	print("--- TEST 4: KEY_BACK (Android Back) ---")
	var ev4 = InputEventKey.new()
	ev4.pressed = true
	ev4.keycode = KEY_BACK
	main._input(ev4)
	assert(main.pause_menu.visible == true, "Pause menu should be visible with KEY_BACK")
	print("PASS: Pause menu opened with KEY_BACK")
	main.pause_menu.hide()

	print("--- TEST 5: NOTIFICATION_WM_GO_BACK_REQUEST ---")
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(main.pause_menu.visible == true, "Pause menu should be visible after NOTIFICATION_WM_GO_BACK_REQUEST")
	print("PASS: Pause menu opened with NOTIFICATION_WM_GO_BACK_REQUEST")
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(main.pause_menu.visible == false, "Pause menu should close after 2nd NOTIFICATION_WM_GO_BACK_REQUEST")
	print("PASS: Pause menu closed with NOTIFICATION_WM_GO_BACK_REQUEST")

	print("--- TEST 6: RaceUI forwarding Backspace ---")
	var race_ui_scene = load("res://RaceUI.tscn")
	var race_ui = race_ui_scene.instantiate()
	var minimap = race_ui.get_node_or_null("HUDPanel/MinimapContainer")
	if minimap:
		minimap.queue_free()
	dummy_level.add_child(race_ui)
	await get_tree().process_frame
	
	race_ui._input(ev1)
	assert(main.pause_menu.visible == true, "Pause menu should be visible after RaceUI forwarded Backspace")
	print("PASS: RaceUI forwarded Backspace to main._input")
	main.pause_menu.hide()

	print("--- TEST 7: LineEdit focus protection ---")
	var line_edit = LineEdit.new()
	main.add_child(line_edit)
	await get_tree().process_frame
	line_edit.grab_focus()
	await get_tree().process_frame
	assert(main.get_viewport().gui_get_focus_owner() == line_edit, "LineEdit should have focus")
	main._input(ev1)
	assert(main.pause_menu.visible == false, "Pause menu must NOT open when LineEdit is focused")
	print("PASS: Backspace ignored when typing in LineEdit")
	line_edit.release_focus()

	print("ALL TESTS PASSED!")
	get_tree().quit()
