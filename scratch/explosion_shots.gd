extends Node

# Blows up carts on the start grid with forced damage (PlayerCart.damage_override) and shoots each
# as it comes apart, from a camera that follows it. Prints how long explode() took. Run windowed:
#   Godot --path . --resolution 1376x768 res://scratch/explosion_shots.tscn -- <out_dir>
#       [level=res://levels/LakesideLevel.tscn] [cars=0,1,2,3,4,5] [dmg=name:wheels:parts:dis ...]
#       [times=0.15,0.5,1.1,2.2] [random] [nofire]
# nofire tears the car and flies the pieces for 0.6s without the blast, fire or tumble, then shoots
# the car and its pieces from the front and the side (what's left of it).
# dmg= entries are used in turn, one per cart: wheels is a comma list of FL,FR,RL,RR or - for none;
# dis is 1 to disintegrate. With `random` each cart rolls its own damage (CarDebris.roll()).

const DEFAULT_DAMAGE := [
	"stripped:FL:8:0",
	"wheels:FL,FR,RR:2:0",
	"shatter:RL,RR,FL:0:1",
	"bare:-:6:0",
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var level_path := "res://levels/LakesideLevel.tscn"
	var cars: PackedStringArray = ["0", "1", "2", "3", "4", "5"]
	var damages: Array = []
	var times: PackedFloat32Array = [0.15, 0.5, 1.1, 2.2]
	var random := false
	var nofire := false
	for a in args:
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("cars="):
			cars = a.substr(5).split(",")
		elif a.begins_with("dmg="):
			damages.append(a.substr(4))
		elif a.begins_with("times="):
			times = PackedFloat32Array()
			for t in a.substr(6).split(","):
				times.append(float(t))
		elif a == "random":
			random = true
		elif a == "nofire":
			nofire = true
	if damages.is_empty():
		damages = DEFAULT_DAMAGE
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	for i in mini(cars.size(), 6):
		NetworkManager.players[100 + i]["car_index"] = int(cars[i])
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	# On the grid, held until GO: wait for the debris plans (a worker thread builds them).
	await get_tree().create_timer(1.5).timeout
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()

	for i in mini(cars.size(), 6):
		var cart: Node3D = level.find_child(str(100 + i), true, false)
		if cart == null:
			continue
		var label := "random"
		if not random:
			var spec: PackedStringArray = str(damages[i % damages.size()]).split(":")
			label = spec[0]
			var wheels: Array = [] if spec[1] == "-" else Array(spec[1].split(","))
			cart.damage_override = {"wheels": wheels, "parts": int(spec[2]), "disintegrate": spec[3] == "1"}
		var plan: Dictionary = cart.CarDebris.get_plan(cart._debris_key)
		if nofire:
			cart._tear_car(cart.damage_override)
			for k in 36:
				cart._update_debris(1.0 / 60.0)
			var xf: Transform3D = cart._debris_body.global_transform
			var c: Vector3 = xf.origin + Vector3(0, 0.5, 0)
			var views := {"front": Vector3(-3.0, 1.8, 4.2), "side": Vector3(5.2, 1.6, 0.8)}
			for v in views:
				cam.global_position = c + xf.basis.orthonormalized() * views[v]
				cam.look_at(c + Vector3(0, 0.5, 0), Vector3.UP)
				for k in 8:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/car%d_%s_%s.png" % [out_dir, cart.car_index, label, v])
			print("SHOT nofire car %d %s (%d pieces)" % [cart.car_index, label, cart._debris.size()])
			cart._clear_debris()
			continue
		var t0 := Time.get_ticks_usec()
		cart.explode(0)
		var took := (Time.get_ticks_usec() - t0) / 1000.0
		print("EXPLODE cart %d car %d %s plan=%s took %.1f ms, %d pieces flying" % [100 + i, cart.car_index, label,
				"ready (%d parts, %d own, %d shards)" % [plan["parts"].size(), plan["own"].size(), plan["shards"].size()] if not plan.is_empty() else "MISSING",
				took, cart._debris.size()])
		var start := Time.get_ticks_msec()
		var base: Vector3 = cart.global_position
		for t in times:
			while (Time.get_ticks_msec() - start) / 1000.0 < t:
				await get_tree().process_frame
			var centre: Vector3 = cart.global_position
			var back: Vector3 = -cart.visuals.global_transform.basis.z
			cam.global_position = base + Vector3(back.x * -7.0 - 3.0, 4.0, back.z * -7.0 + 5.0)
			cam.look_at(centre + Vector3(0, 0.6, 0), Vector3.UP)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/car%d_%s_t%03d.png" % [out_dir, cart.car_index, label, int(t * 100.0)])
		print("SHOT car %d %s" % [cart.car_index, label])
		# Let it finish and respawn before the next one, and check the car comes back whole.
		while cart.is_exploding or cart.is_teleporting:
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		print("RESTORED cart %d: body visible=%s, debris=%d, mesh verts=%d" % [100 + i, cart._debris_body.visible, cart._debris.size(),
				(cart._debris_body.mesh as ArrayMesh).surface_get_arrays(0)[0].size()])
	get_tree().quit()
