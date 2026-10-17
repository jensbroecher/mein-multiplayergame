extends Node

# Screenshots main-menu screens, and the car selection with its paint shop (car:<index>[:<pattern>],
# shown without saving anything to the player's settings).
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
	var cars: Control = null
	for screen in args.slice(1):
		if screen.begins_with("scroll="):
			continue
		if screen.begins_with("car:"):
			var f := screen.split(":")
			if cars == null:
				menu.hide()
				cars = load("res://CarSelection.tscn").instantiate()
				add_child(cars)
			cars.current_car_index = int(f[1])
			cars.update_car_selection()
			if f.size() > 2 and not cars.current_paint.is_empty():
				cars.current_paint["pattern"] = int(f[2])
				cars._paint_changed(false)
			for i in 40:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [args[0], screen.replace(":", "_")])
			print("SHOT ", screen)
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
