extends Node

# Screenshots main-menu screens.
#   Godot --path . res://scratch/menu_shot.tscn -- <out_dir> <screen> [<screen>...] [scroll=<px>]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var menu = load("res://MainMenu.tscn").instantiate()
	add_child(menu)
	var scroll_px := 0
	for a in args:
		if a.begins_with("scroll="):
			scroll_px = int(a.substr(7))
	for screen in args.slice(1):
		if screen.begins_with("scroll="):
			continue
		menu.show_sub_menu(screen)
		for i in 20:
			await get_tree().process_frame
		var sc: ScrollContainer = menu.get_node("Root/VBox/TileScroll")
		sc.scroll_vertical = scroll_px
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/menu_%s.png" % [args[0], screen])
		print("SHOT ", screen)
	get_tree().quit()
