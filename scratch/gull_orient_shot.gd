extends SceneTree
## Renders a model's rest pose from above and the side, without animation, to tell which way it faces:
## -s, windowed, -- <res path> <dir>. Camera up is -z in the top view (+x right).
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var m: Node3D = (load(args[0]) as PackedScene).instantiate()
	DirAccess.make_dir_recursive_absolute(args[1])
	for n in ["Camera", "Light"]:
		var d := m.find_child(n, true, false)
		if d: d.free()
	root.add_child(m)
	for ap in m.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.3, 0.45, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.8)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var cam := Camera3D.new(); root.add_child(cam)
	for f in 20: await process_frame
	cam.global_position = Vector3(0, 30, 0.1); cam.look_at(Vector3.ZERO, Vector3(0, 0, -1))
	for f in 6: await process_frame
	root.get_texture().get_image().save_png(args[1] + "/top.png")
	cam.global_position = Vector3(0, 0, 30); cam.look_at(Vector3.ZERO, Vector3.UP)
	for f in 6: await process_frame
	root.get_texture().get_image().save_png(args[1] + "/front.png")
	cam.global_position = Vector3(30, 0, 0); cam.look_at(Vector3.ZERO, Vector3.UP)
	for f in 6: await process_frame
	root.get_texture().get_image().save_png(args[1] + "/side.png")
	print("OK")
	quit()
