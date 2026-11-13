extends Node
## Checks the menu tiles' slideshows (MenuTileDrift.slides): prints the menu's slide lists for the Yunhai GP's courses
## and cup, then runs one tile for 12 seconds, printing each picture it shows and the slideshow's state every second.
## Run it windowed (headless, a texture's threaded load never finishes and the tile falls back to waiting for it):
##   godot --path . --fixed-fps 60 res://scratch/tile_slides_test.tscn -- [tile_yunhai_gp.jpg]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var file: String = args[0] if args.size() > 0 else "tile_shuangjiang.jpg"
	var mm: Script = load("res://MainMenu.gd")
	var menu: Object = mm.new()
	for f in ["tile_tianqiao.jpg", "tile_panlong.jpg", "tile_wangjiang.jpg", "tile_shuangjiang.jpg", "tile_yunhai_gp.jpg", "tile_lakeside.jpg"]:
		print(f, ": ", menu.call("_tile_slides", f))
	var drift: Script = load("res://MenuTileDrift.gd")
	var t: TextureRect = drift.new()
	t.slides = menu.call("_tile_slides", file)
	t.texture = load(t.slides[0])
	t.size = Vector2(400, 240)
	add_child(t)
	var last := ""
	for i in range(12 * 60):
		await get_tree().process_frame
		var cur: String = t.texture.resource_path if t.texture else ""
		if i % 60 == 0:
			var pend: String = t.get("_pending")
			print("  t=%.0f slide_t=%.2f pending=%s status=%d fade=%.2f" % [i / 60.0, t.get("_slide_t"), pend, ResourceLoader.load_threaded_get_status(pend) if pend != "" else -1, t.get("_fade_t")])
		if cur != last:
			print("%.1fs %s" % [i / 60.0, cur])
			last = cur
	menu.free()
	get_tree().quit()
