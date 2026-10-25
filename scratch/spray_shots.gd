extends Node

# What the wheels throw up in a live spectator race: waits, then shoots carts while they raise dust
# or fling grit (or smoke on asphalt), from behind and to the side. Windowed:
#   Godot --path . --resolution 1600x900 res://scratch/spray_shots.tscn -- <out_dir> [level=res://...]
#       [wait=25] [shots=4] [gap=3]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var level_path := "res://levels/MaraCrossingLevel.tscn"
	var wait := 25.0
	var shots := 4
	var gap := 3.0
	for a in args:
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("wait="):
			wait = float(a.substr(5))
		elif a.begins_with("shots="):
			shots = int(a.substr(6))
		elif a.begins_with("gap="):
			gap = float(a.substr(4))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		await get_tree().process_frame
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 3000.0
	add_child(cam)
	cam.make_current()
	var taken := 0
	var tries := 0
	while taken < shots and tries < 4000:
		tries += 1
		await get_tree().process_frame
		var best: Node3D = null
		for c in get_tree().get_nodes_in_group("player_carts"):
			if c._is_dust_active or c._is_skid_active:
				best = c
				break
		if best == null:
			continue
		# Follow it for a moment so the spray has built up behind it.
		for f in 24:
			var v: Node3D = best.visuals
			var fwd: Vector3 = -v.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var side: Vector3 = fwd.cross(Vector3.UP)
			cam.global_position = v.global_position - fwd * 7.5 + side * 3.0 + Vector3.UP * 2.4
			cam.look_at(v.global_position - fwd * 1.5, Vector3.UP)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/spray_%d.png" % [out_dir, taken]
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path, " surface ", best.Surfaces.NAMES[best.surface], " skid ", best._skid_amount)
		taken += 1
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < int(gap * 1000.0):
			await get_tree().process_frame
	get_tree().quit()
