extends Node

# Checks that the main menu's tiles move in the real start-up (Main.tscn, the player's own settings): grabs each
# live tile's picture (MenuTileStage.gd) and each picture tile's on-screen rect twice, half a second apart, and
# prints how much of it changed. A tile that prints 0% stands still. `screen=` opens another menu page first.
#   Godot --path . res://scratch/menu_motion_check.tscn [-- detail=<0..4>] [screen=stage_select]

var _screen := ""


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("detail="):
			MusicManager.grass_quality_index = int(a.substr(7))
		elif a.begins_with("screen="):
			_screen = a.substr(7)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var main = load("res://Main.tscn").instantiate()
	add_child(main)
	if _screen != "":
		main.get_node("MainMenu").show_sub_menu(_screen)
	print("detail level ", MusicManager.grass_quality_index)
	for i in 90:
		await get_tree().process_frame
	var a := await _grab(main)
	await get_tree().create_timer(0.5).timeout
	var b := await _grab(main)
	for key in a.keys():
		print("%-14s %5.1f%% of pixels changed" % [key, _changed(a[key], b[key]) * 100.0])
	get_tree().quit()


func _grab(main: Node) -> Dictionary:
	await RenderingServer.frame_post_draw
	var screen := get_viewport().get_texture().get_image()
	var scale := get_viewport().get_final_transform().get_scale()
	var out := {}
	for btn in _tiles(main.get_node("MainMenu")):
		var title := ""
		for lbl in btn.find_children("*", "Label", true, false):
			title = (lbl as Label).text
			break
		var r: Rect2 = (btn as Control).get_global_rect()
		var px := Rect2i(Vector2i(r.position * scale), Vector2i(r.size * scale * Vector2(1.0, 0.5)))
		out[title] = screen.get_region(px)
	return out


func _tiles(n: Node) -> Array:
	var out: Array = []
	if n is Button and n.get_child_count() > 0 and n.get_child(0).get_child_count() > 0 and n.get_child(0).get_child(0) is TextureRect:
		out.append(n)
	for c in n.get_children():
		out.append_array(_tiles(c))
	return out


func _changed(a: Image, b: Image) -> float:
	var n := 0
	var diff := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			n += 1
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.03:
				diff += 1
	return float(diff) / maxf(float(n), 1.0)
