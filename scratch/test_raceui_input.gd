extends Node

func _ready():
	call_deferred("_run")

func _run():
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Start single player time trial on LakesideCourse
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	NetworkManager.time_trial_stage = "res://levels/LakesideLevel.tscn"
	await main.start_game(true)
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Race started. Level nodes: ", main._find_level_nodes().size())
	print("Pause menu visible initially: ", main.pause_menu.visible)
	
	# Send Backspace through the viewport input pipeline!
	var ev = InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.keycode = KEY_BACKSPACE
	ev.physical_keycode = KEY_BACKSPACE
	
	print("Pushing Backspace input to Viewport...")
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Pause menu visible after Backspace: ", main.pause_menu.visible)
	
	get_tree().quit()
