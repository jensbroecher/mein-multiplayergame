extends Node

# The Options tile's laptop screen, frame by frame: its mean brightness in the tile's own picture, with the mouse
# still and then moving over the tile (real InputEventMouseMotion through the window). A screen that drops to
# dark or jumps between frames flickers.
# `dir=` also saves the laptop's corner of the tile's picture for each frame (laptop_<still|moving>_<n>.png).
# (Since the page is drawn on the screen in 3D, not in a SubViewport, `first=1` finds no page: it stays for the
# record.) `first=1` instead watches the laptop page's own texture from the menu's first frame (the menu built, as at
# start-up) and prints, frame by frame, how much of it is drawn: the page drawn into a quarter of the screen on
# alternate frames (size_2d_override, since replaced) showed as 25%. `fullscreen=1` goes fullscreen at once, as the
# game does.
#   Godot --path . res://scratch/laptop_flicker_probe.tscn [-- frames=90] [dir=<out dir>] [first=1]

var frames := 90
var dir := ""
var _tag := "still"
var _first := false
var _fullscreen := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			frames = int(a.substr(7))
		elif a.begins_with("dir="):
			dir = a.substr(4)
		elif a == "first=1":
			_first = true
		elif a == "fullscreen=1":
			_fullscreen = true
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	if _fullscreen:
		win.mode = Window.MODE_FULLSCREEN
	var menu = load("res://MainMenu.tscn").instantiate()
	add_child(menu)
	if _first:
		# As at start-up: built hidden behind the title card for a moment, then shown.
		menu.visible = false
		for i in 20:
			await get_tree().process_frame
		menu.visible = true
		await _watch_page(menu)
		get_tree().quit()
		return
	for i in 60:
		await get_tree().process_frame
	var stage: Node = null
	for n in menu.find_children("*", "TextureRect", true, false):
		if n.get_script() == preload("res://MenuTileStage.gd") and n.kind == "options":
			stage = n
	var tile := stage.get_parent() as Control
	while tile != null and not (tile is BaseButton):
		tile = tile.get_parent() as Control
	var screen := stage.find_children("LaptopScreen", "MeshInstance3D", true, false)[0] as MeshInstance3D
	print("mouse still, away:")
	await _record(stage, screen, func(_i: int) -> void: pass)
	var centre := tile.get_global_rect().get_center()
	print("mouse moving over the tile:")
	_tag = "moving"
	await _record(stage, screen, func(i: int) -> void:
		var ev := InputEventMouseMotion.new()
		ev.position = centre + Vector2(sin(i * 0.3) * 120.0, cos(i * 0.21) * 30.0)
		ev.global_position = ev.position
		ev.relative = Vector2(4, 1)
		get_viewport().push_input(ev))
	get_tree().quit()


func _record(stage: Node, screen: MeshInstance3D, each: Callable) -> void:
	var line := ""
	var lo := 9.0
	var hi := 0.0
	for i in frames:
		each.call(i)
		await RenderingServer.frame_post_draw
		var vp: SubViewport = stage._vps[0]
		var cam: Camera3D = stage._cams[0]
		var p := cam.unproject_position(screen.global_position)
		var img := vp.get_texture().get_image()
		var r := Rect2i(Vector2i(p) - Vector2i(6, 4), Vector2i(12, 8)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var sum := 0.0
		var n := 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := img.get_pixel(x, y)
				sum += c.r + c.g + c.b
				n += 1
		var v := sum / maxf(n, 1)
		if dir != "":
			var crop := img.get_region(Rect2i(Vector2i(p) - Vector2i(90, 60), Vector2i(180, 120)).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
			crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
			crop.save_png("%s/laptop_%s_%02d.png" % [dir, _tag, i])
		lo = minf(lo, v)
		hi = maxf(hi, v)
		line += "%.2f " % v
	print(line)
	print("  min %.2f max %.2f" % [lo, hi])


func _watch_page(menu: Node) -> void:
	var line := ""
	var worst := 1.0
	for i in frames:
		await RenderingServer.frame_post_draw
		var pages := menu.find_children("LaptopPage", "SubViewport", true, false)
		if pages.is_empty():
			line += "- "
			continue
		var img := (pages[0] as SubViewport).get_texture().get_image()
		# The page's bottom-right quarter is its dark panel and graph; drawn into a quarter, the page leaves it the
		# viewport's grey clear colour.
		var n := 0
		var drawn := 0
		for y in range(img.get_height() / 2, img.get_height(), 2):
			for x in range(img.get_width() / 2, img.get_width(), 2):
				n += 1
				var c := img.get_pixel(x, y)
				if c.r + c.g + c.b < 0.75:
					drawn += 1
		var share := float(drawn) / maxf(float(n), 1.0)
		worst = minf(worst, share)
		line += "%d%% " % roundi(share * 100.0)
	print("laptop page's lower right drawn, frame by frame: ", line)
	print("  least %d%%" % roundi(worst * 100.0))
