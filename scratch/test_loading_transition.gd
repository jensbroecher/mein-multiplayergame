extends Node

# Validates that:
# 1. LoadingScreen displays the RC Vibe GP logo (TextureRect).
# 2. Main._show_loading() does not return until the ScreenTransition has fully ended (not busy, not visible).
# Run headless: & "D:\Godot\Godot_v4.8-beta1_win64_console.exe" --headless --path . res://scratch/test_loading_transition.tscn

func _ready() -> void:
	var main: Node = load("res://Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var loading_screen = main.loading_screen
	var screen_transition = main.screen_transition

	assert(loading_screen != null, "LoadingScreen must exist on Main")
	assert(screen_transition != null, "ScreenTransition must exist on Main")

	# Check logo presence on LoadingScreen
	var logo_rect = loading_screen.find_child("Logo", true, false) as TextureRect
	assert(logo_rect != null, "LoadingScreen must have a 'Logo' TextureRect")
	assert(logo_rect.texture != null, "Logo TextureRect must have a valid texture assigned")
	print("ok  LoadingScreen has logo TextureRect with texture: %s (%s)" % [logo_rect.texture.resource_path, logo_rect.texture.get_size()])

	# Test _show_loading transition completion
	print("Testing _show_loading transition completion...")
	await main._show_loading("Testing transition")

	# After _show_loading finishes, the transition must be fully done:
	assert(not screen_transition.busy, "ScreenTransition must NOT be busy after _show_loading")
	assert(not screen_transition.visible, "ScreenTransition must NOT be visible after _show_loading")
	assert(loading_screen.visible, "LoadingScreen must be visible after _show_loading")
	print("ok  ScreenTransition is completely ended (busy=false, visible=false) before loading begins")

	# Test _hide_loading
	await main._hide_loading()
	assert(not loading_screen.visible, "LoadingScreen must be hidden after _hide_loading")
	print("ok  LoadingScreen is hidden after _hide_loading")

	print("ALL LOADING & TRANSITION CHECKS PASSED")
	get_tree().quit(0)

