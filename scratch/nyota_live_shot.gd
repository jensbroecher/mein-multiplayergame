extends Node

# Nyota Stadium in a real race: starts a spectator race (6 AI carts), lets it run, then takes shots
# through the main viewport from fixed cameras (the big screen and the sponsor boards only show
# what they should in a real game, not in an offscreen render). Run windowed:
#   Godot --path . --resolution 1376x768 res://scratch/nyota_live_shot.tscn -- <out_dir> [wait=25] [level=res://...]
#       name:x,y,z:tx,ty,tz ...

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var wait := 25.0
	for a in args:
		if a.begins_with("wait="):
			wait = float(a.substr(5))
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level_path := "res://levels/NyotaStadiumLevel.tscn"
	for a in args:
		if a.begins_with("level="):
			level_path = a.substr(6)
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		await get_tree().process_frame
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	if "jumbo_always" in args:
		for j in get_tree().root.find_children("Jumbotron", "", true, false):
			var vp: SubViewport = j.get_node("BroadcastViewport")
			j.set_process(false)
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 4000.0
	add_child(cam)
	for a in args.slice(1):
		if not ":" in a:
			continue
		var parts := a.split(":")
		var p := parts[1].split(",")
		var tg := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(tg[0]), float(tg[1]), float(tg[2])), Vector3.UP)
		cam.make_current()
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	get_tree().quit()
