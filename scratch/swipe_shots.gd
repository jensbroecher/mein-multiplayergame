extends Node
# Shoots the screen swipe (ScreenTransition) over the main menu at set points of the cover and the
# reveal. Windowed:  Godot --path . --resolution 1376x768 res://scratch/swipe_shots.tscn -- <out_dir>
func _ready() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	AudioServer.set_bus_mute(0, true)
	var main: Node = load("res://Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	for i in 90:
		await get_tree().process_frame
	var swipe: CanvasLayer = main.screen_transition
	swipe.visible = true
	var steps := {
		"1_cover25": [0.25, 0.0, 0.0], "2_cover55": [0.55, 0.0, 0.0], "3_cover85": [0.85, 0.0, 0.0],
		"4_covered": [1.0, 0.0, 0.0], "5_reveal30": [1.0, 0.3, 0.0], "6_reveal60": [1.0, 0.6, 0.15], "7_reveal85": [1.0, 0.85, 0.6],
	}
	for k in steps:
		var v: Array = steps[k]
		swipe._set_state(v[0], v[1], v[2])
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, k])
		print("SHOT ", k)
	get_tree().quit()
