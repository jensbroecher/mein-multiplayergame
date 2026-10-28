extends SceneTree

const DEFAULT := "res://Tornado.tscn"

func _initialize():
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "."
	var src: String = args[1] if args.size() > 1 else DEFAULT
	var w = Node3D.new()
	root.add_child(w)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	w.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -40, 0)
	w.add_child(sun)
	var cam = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	var m: Node3D = load(src).instantiate()
	m.scale = Vector3.ONE
	w.add_child(m)
	for i in 3:
		await process_frame
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "VisualInstance3D", true, false) + ([m] if m is VisualInstance3D else []):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	print("aabb=", box)
	var c = box.get_center()
	var r = box.size.length()
	for v in [["front", Vector3(0.15, 0.2, 1)], ["side", Vector3(1, 0.3, 0.1)], ["three", Vector3(0.8, 0.5, 0.7)]]:
		cam.position = c + v[1].normalized() * r * 0.52
		cam.look_at(c)
		for i in 15:
			await process_frame
		root.get_texture().get_image().save_png("%s/tornado_%s.png" % [dir, v[0]])
	quit()
