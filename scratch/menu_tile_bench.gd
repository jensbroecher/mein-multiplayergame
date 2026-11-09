extends Node

# Frame times of the main menu's screens with their live 3D tiles (MenuTileStage.gd), vsync off.
#   Godot --path . res://scratch/menu_tile_bench.tscn -- [screens=main,sp_modes] [frames=300]

func _ready() -> void:
	var screens := ["main", "sp_modes", "coop_config"]
	var frames := 300
	for a in OS.get_cmdline_user_args():
		if a.begins_with("screens="):
			screens = a.substr(8).split(",")
		elif a.begins_with("dbg="):
			var kv := a.substr(4).split(":")
			var st = preload("res://MenuTileStage.gd")
			st.dbg[kv[0]] = str_to_var(kv[1])
		elif a.begins_with("frames="):
			frames = int(a.substr(7))
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var menu = load("res://MainMenu.tscn").instantiate()
	add_child(menu)
	for screen in screens:
		menu.show_sub_menu(screen)
		for i in 90:
			await get_tree().process_frame
		var vps: Array = []
		for st in _stages(menu):
			for vp in st._vps:
				RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
				vps.append([st.kind, vp])
		for i in 30:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		var worst := 0.0
		var last := t0
		for i in frames:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - last) / 1000.0)
			last = now
		var mean := (Time.get_ticks_usec() - t0) / 1000.0 / frames
		print("BENCH %s: %.2f ms mean (%.0f fps), worst %.1f ms, GPU %.2f ms" % [screen, mean, 1000.0 / mean, worst,
			RenderingServer.get_frame_setup_time_cpu()])
		for e in vps:
			var vp: SubViewport = e[1]
			print("  %s %dx%d: GPU %.2f ms, CPU %.2f ms" % [e[0], vp.size.x, vp.size.y,
				RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()),
				RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())])
	get_tree().quit()


func _stages(n: Node) -> Array:
	var out: Array = []
	if n.get_script() == preload("res://MenuTileStage.gd"):
		out.append(n)
	for c in n.get_children():
		out.append_array(_stages(c))
	return out
