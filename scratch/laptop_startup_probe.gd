extends Node

# The real start-up (Main.tscn as the running scene, so the title card plays), watched from a node on the root:
# once the main menu shows, logs every frame the Options tile's laptop page viewport (its size, its 2D canvas
# scale) and how much of its lower right is drawn. Any frame whose numbers differ from the rest is the
# first-view flicker (the page drawn into a corner of the laptop's screen). Since the page is drawn on the screen in
# 3D, not in a SubViewport, it prints "no page": it stays for the record.
#   Godot --path . res://scratch/laptop_startup_probe.tscn [-- frames=120] [key=2.5]

var frames := 120
var key_at := 2.5
var watching := false


func _ready() -> void:
	if watching:
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			frames = int(a.substr(7))
		elif a.begins_with("key="):
			key_at = float(a.substr(4))
	var helper: Node = (get_script() as GDScript).new()
	helper.watching = true
	helper.frames = frames
	helper.key_at = key_at
	get_tree().root.add_child.call_deferred(helper)
	helper.call_deferred("_watch")
	get_tree().change_scene_to_file.call_deferred("res://Main.tscn")


func _watch() -> void:
	# Skip the title card with a key, as a player would.
	await get_tree().create_timer(key_at).timeout
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	var menu: Control = null
	while menu == null or not menu.is_visible_in_tree():
		await get_tree().process_frame
		var main := get_tree().current_scene
		if main:
			menu = main.get_node_or_null("MainMenu")
	print("menu visible")
	for i in frames:
		await RenderingServer.frame_post_draw
		var pages := menu.find_children("LaptopPage", "SubViewport", true, false)
		if pages.is_empty():
			print("%3d no page" % i)
			continue
		var vp := pages[0] as SubViewport
		var img := vp.get_texture().get_image()
		var n := 0
		var drawn := 0
		for y in range(img.get_height() / 2, img.get_height(), 2):
			for x in range(img.get_width() / 2, img.get_width(), 2):
				n += 1
				var c := img.get_pixel(x, y)
				if c.r + c.g + c.b < 0.75:
					drawn += 1
		print("%3d size %s tex %dx%d canvas %s final %s lower right %d%%" % [i, vp.size, img.get_width(), img.get_height(),
			vp.canvas_transform.get_scale(), vp.get_final_transform().get_scale(), roundi(100.0 * drawn / maxf(n, 1))])
	get_tree().quit()
