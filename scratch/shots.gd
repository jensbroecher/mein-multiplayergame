extends Node

# Screenshots of a level from given camera poses, with the game's autoloads and shadow settings.
# Run windowed:
#   Godot --path . res://scratch/shots.tscn -- res://levels/X.tscn <out_dir> name:x,y,z:tx,ty,tz ...

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := args[0]
	var out_dir := args[1]
	AudioServer.set_bus_mute(0, true)
	MusicManager.window_mode = 0
	MusicManager.resolution_index = 0
	for i in 5:
		await get_tree().process_frame
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var vp := get_viewport()
	vp.scaling_3d_scale = 1.0
	vp.msaa_3d = Viewport.MSAA_4X
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	MusicManager.set_shadow_quality(3, false)
	# debug: red=<node name> paints that mesh flat red, double-sided.
	for a in args:
		if a.begins_with("red="):
			for n in level.find_children(a.substr(4), "MeshInstance3D", true, false):
				var m := StandardMaterial3D.new()
				m.albedo_color = Color.RED
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				n.material_override = m
	# Hide the race HUD so the shots show only the world.
	for n in level.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	cam.make_current()
	for a in args.slice(2):
		if a.begins_with("red="):
			continue
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	get_tree().quit()
