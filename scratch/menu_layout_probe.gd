extends Node

# Prints the main menu's tile sizes against the screen through a start-up like the real one (the menu built while
# hidden behind the title card, then shown) and a walk through its pages: any tile reaching past the window, or
# tiles that change size between visits to one page, is a layout bug.
# `start=<w>x<h>` opens the window at that size first and resizes it to `size` while the menu is hidden (the
# game going fullscreen at start-up).
#   Godot --path . res://scratch/menu_layout_probe.tscn [-- size=1728x1080] [start=1152x720] [hidden=60]

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1728, 1080)
	var hidden := 60
	var final_size := win.size
	for a in OS.get_cmdline_user_args():
		if a.begins_with("size="):
			var wh := a.substr(5).split("x")
			final_size = Vector2i(int(wh[0]), int(wh[1]))
			win.size = final_size
		elif a.begins_with("start="):
			var wh2 := a.substr(6).split("x")
			win.size = Vector2i(int(wh2[0]), int(wh2[1]))
		elif a.begins_with("hidden="):
			hidden = int(a.substr(7))
	var menu = load("res://MainMenu.tscn").instantiate()
	menu.visible = false
	add_child(menu)
	for i in hidden:
		await get_tree().process_frame
		if i == hidden / 2:
			win.size = final_size
	menu.visible = true
	for i in 20:
		await get_tree().process_frame
	_report(menu, "main (first)")
	for screen in ["sp_modes", "main", "coop_config", "cup_select", "main"]:
		menu.show_sub_menu(screen)
		for i in 20:
			await get_tree().process_frame
		_report(menu, screen)
	get_tree().quit()


func _report(menu: Control, label: String) -> void:
	var view := get_viewport().get_visible_rect()
	var scroll: Control = menu.get_node("Root/VBox/TileScroll")
	var line := "%-14s scroll %s at %s;" % [label, scroll.size.round(), scroll.global_position.round()]
	var worst := 0.0
	for btn in menu.find_children("*", "Button", true, false):
		var b := btn as Button
		if not b.is_visible_in_tree() or b.get_child_count() == 0 or not (b.get_child(0) is Control) or b.get_child(0).get_child_count() == 0:
			continue
		var r := b.get_global_rect()
		worst = maxf(worst, r.end.y - view.end.y)
		line += " %dx%d" % [r.size.x, r.size.y]
	print(line, "  past the bottom by %.0f" % worst if worst > 0.0 else "")
