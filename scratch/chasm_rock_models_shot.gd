extends SceneTree
# -s windowed: -- <dir>  renders Canyon Chasm's imported rock models (at their level scale) one per shot,
# with their size, for comparing their procedural replacements. Prints each one's AABB in metres.
const MODELS := {
	"rock_462b": ["res://models/desert/462b0835dae4689feaf62903546389ee.fbx", 30.0],
	"rock_0c79": ["res://models/desert/0c797c60dd8eef1acae70d532301f210.fbx", 25.0],
	"arch_8fc3": ["res://models/desert/8fc36b06f12d9b9e49c5877a89ef126c.fbx", 31.0],
	"rock_5de4": ["res://models/desert/5de45969eb67cee87dc8ebbdd862dc99.fbx", 20.0],
}
func _initialize():
	var dir = OS.get_cmdline_user_args()[0]
	var w = Node3D.new(); root.add_child(w)
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	w.add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -40, 0); w.add_child(sun)
	var cam = Camera3D.new(); w.add_child(cam); cam.current = true
	for k in MODELS:
		var m = load(MODELS[k][0]).instantiate()
		m.scale = Vector3.ONE * MODELS[k][1]
		w.add_child(m)
		await process_frame
		var box := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print(k, " aabb=", box)
		var c = box.get_center()
		var r = box.size.length()
		for v in [["a", Vector3(1, 0.5, 1)], ["b", Vector3(-1, 0.35, 0.2)]]:
			cam.position = c + v[1].normalized() * r * 1.1
			cam.look_at(c)
			for i in 40: await process_frame
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [dir, k, v[0]])
		m.queue_free()
	quit()
