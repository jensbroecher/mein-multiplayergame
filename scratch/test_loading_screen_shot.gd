extends Node

# Captures a screenshot of LoadingScreen to inspect its visuals.
# Run with: & "D:\Godot\Godot_v4.8-beta1_win64_console.exe" --path . --resolution 1920x1080 res://scratch/test_loading_screen_shot.tscn

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var loading_scene: PackedScene = load("res://LoadingScreen.tscn")
	var loading: CanvasLayer = loading_scene.instantiate()
	add_child(loading)
	await get_tree().process_frame

	loading.show_loading("Loading race")
	loading.set_progress(0.45)

	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("scratch/loading_screen_shot.png")
	print("Saved scratch/loading_screen_shot.png")
	get_tree().quit(0)
