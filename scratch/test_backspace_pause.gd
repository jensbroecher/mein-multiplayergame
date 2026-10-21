extends Node

func _ready():
	call_deferred("_run_test")

func _run_test():
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Simulate pressing Backspace
	var ev = InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.keycode = KEY_BACKSPACE
	ev.physical_keycode = KEY_BACKSPACE
	
	print("Testing before race started:")
	print("  Level nodes count: ", main._find_level_nodes().size())
	main._input(ev)
	print("  Pause menu visible: ", main.pause_menu.visible)
	
	# Now simulate a level loaded
	print("Simulating level loaded...")
	var dummy_level = Node3D.new()
	dummy_level.name = "Level"
	dummy_level.add_to_group("level")
	main.add_child(dummy_level)
	await get_tree().process_frame
	
	print("Testing with Level node in tree:")
	print("  Level nodes count: ", main._find_level_nodes().size())
	main._input(ev)
	print("  Pause menu visible after Backspace: ", main.pause_menu.visible)
	
	main._input(ev)
	print("  Pause menu visible after 2nd Backspace: ", main.pause_menu.visible)
	
	get_tree().quit()
