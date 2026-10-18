extends Node
# Renders the GP podium with made-up standings and saves screenshots at given times.
#   Godot --path . res://scratch/podium_shots.tscn -- <out_dir> [times=1,3,6,9] [cars=0,6,7,2,3,5] [size=<w>x<h>]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 900)
	var times: Array = [1.0, 3.0, 6.0, 9.0]
	var cars: Array = [0, 6, 7, 2, 3, 5]
	for a in args.slice(1):
		if a.begins_with("times="):
			times = Array(a.substr(6).split(",")).map(func(x): return float(x))
		elif a.begins_with("cars="):
			cars = Array(a.substr(5).split(",")).map(func(x): return int(x))
		elif a.begins_with("size="):
			var wh := a.substr(5).split("x")
			win.size = Vector2i(int(wh[0]), int(wh[1]))
	var names := ["SoloRacer", "Viper", "Shadow", "Apex", "Blaze", "Nova"]
	var pts := [34, 30, 26, 18, 14, 9]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ranking: Array = []
	for i in cars.size():
		ranking.append({"name": names[i], "points": pts[i], "car_index": cars[i],
				"paint": preload("res://CarPaint.gd").random(rng, ""), "is_bot": i > 0})
	NetworkManager.players = {1: {"name": "SoloRacer", "car_index": 0}}
	var podium: Control = load("res://Podium.tscn").instantiate()
	podium.setup("Matumaini GP", ranking)
	add_child(podium)
	for i in 45:
		await get_tree().process_frame
	podium.start()
	var t0 := Time.get_ticks_msec()
	var n := 0
	for t in times:
		while (Time.get_ticks_msec() - t0) / 1000.0 < t:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/podium_%02d.png" % [args[0], n])
		print("SHOT ", n, " at ", t)
		n += 1
	get_tree().quit()
