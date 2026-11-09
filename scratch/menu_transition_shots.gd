extends Node

# Frames through a main menu page change (the last page fading out, the new tiles cascading in), saved as one
# contact sheet, `every` frames apart from the moment the page changes.
#   Godot --path . res://scratch/menu_transition_shots.tscn -- <dir> [from=main] [to=sp_modes] [every=4] [count=12]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0]
	var from := "main"
	var to := "sp_modes"
	var every := 4
	var count := 12
	for a in args:
		if a.begins_with("from="):
			from = a.substr(5)
		elif a.begins_with("to="):
			to = a.substr(3)
		elif a.begins_with("every="):
			every = int(a.substr(6))
		elif a.begins_with("count="):
			count = int(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var menu = load("res://MainMenu.tscn").instantiate()
	add_child(menu)
	menu.show_sub_menu(from)
	for i in 90:
		await get_tree().process_frame
	menu.show_sub_menu(to)
	var shots: Array[Image] = []
	for i in count:
		for f in every:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 4, img.get_height() / 4)
		shots.append(img)
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var cols := 4
	var sheet := Image.create(w * cols, h * int(ceil(count / float(cols))), false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png("%s/transition_%s_%s.png" % [dir, from, to])
	print("SHEET ", dir)
	get_tree().quit()
