extends Node

# The Options tile's laptop screen, frame by frame: its mean brightness in the tile's own picture, with the mouse
# still and then moving over the tile (real InputEventMouseMotion through the window). A screen that drops to
# dark or jumps between frames flickers.
# `dir=` also saves the laptop's corner of the tile's picture for each frame (laptop_<still|moving>_<n>.png).
#   Godot --path . res://scratch/laptop_flicker_probe.tscn [-- frames=90] [dir=<out dir>]

var frames := 90
var dir := ""
var _tag := "still"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			frames = int(a.substr(7))
		elif a.begins_with("dir="):
			dir = a.substr(4)
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var menu = load("res://MainMenu.tscn").instantiate()
	add_child(menu)
	for i in 60:
		await get_tree().process_frame
	var stage: Node = null
	for n in menu.find_children("*", "TextureRect", true, false):
		if n.get_script() == preload("res://MenuTileStage.gd") and n.kind == "options":
			stage = n
	var tile := stage.get_parent().get_parent() as Control
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
