extends Node

# Cars in a real race: starts a spectator race (6 AI carts) with the given cars, lets it run, then
# shoots each listed cart from a chase camera (like the player's), from its side and from ahead.
# The bots get random paint jobs (they only show on procedural cars). Run windowed:
#   Godot --path . --resolution 1376x768 res://scratch/car_live_shot.tscn -- <out_dir>
#       [level=res://levels/Level.tscn] [cars=5,5,5,0,1,2] [wait=20] [carts=100,101]
#       [fx=shock,respawn,teleport,fade]
# fx= puts PlayerCart's flashes on the shot carts, one each in order, to check them on a car.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var wait := 20.0
	var level_path := "res://levels/Level.tscn"
	var cars: PackedStringArray = []
	var shoot: PackedStringArray = ["100", "101"]
	var fx: PackedStringArray = []
	for a in args:
		if a.begins_with("wait="):
			wait = float(a.substr(5))
		elif a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("cars="):
			cars = a.substr(5).split(",")
		elif a.begins_with("carts="):
			shoot = a.substr(6).split(",")
		elif a.begins_with("fx="):
			fx = a.substr(3).split(",")
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	for i in mini(cars.size(), 6):
		NetworkManager.players[100 + i]["car_index"] = int(cars[i])
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		await get_tree().process_frame
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 4000.0
	add_child(cam)
	cam.make_current()
	# Freeze the race so each cart holds still for its shots.
	get_tree().paused = true
	for k in shoot.size():
		var id: String = shoot[k]
		var cart: Node3D = level.find_child(id, true, false)
		if cart == null:
			print("no cart ", id)
			continue
		if k < fx.size():
			match fx[k]:
				"shock":
					cart._set_visuals_shock_effect(true, true)
				"respawn":
					cart._set_visuals_respawn_effect(true, true)
				"teleport":
					cart._set_teleport_glow(0.6)
					cart._set_visuals_alpha(0.5)
				"fade":
					cart._set_visuals_alpha(0.35)
		var vis: Node3D = cart.get_node("Visuals")
		var b: Basis = vis.global_transform.basis.orthonormalized()
		var c: Vector3 = vis.global_position
		var views := {
			"chase": [c - b.z * -4.5 + Vector3.UP * 2.0, c + b.z * -4.0],
			"side": [c + b.x * 3.6 + Vector3.UP * 0.9 + b.z * -0.6, c],
			"front": [c + b.z * -4.2 + b.x * 1.6 + Vector3.UP * 1.2, c],
		}
		for v in views:
			cam.global_position = views[v][0]
			cam.look_at(views[v][1] + Vector3.UP * 0.3, Vector3.UP)
			for i in 12:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, id, v])
			print("SHOT %s_%s car=%d" % [id, v, cart.car_index])
	get_tree().quit()
