extends SceneTree
# -s windowed: -- <dir>  renders the Canyon Chasm dirt ramp (DirtRampCSG) on flat ground
func _initialize():
	var dir = OS.get_cmdline_user_args()[0]
	var root3 = Node3D.new(); root.add_child(root3)
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6,0.75,0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7,0.7,0.75)
	root3.add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45,-40,0); root3.add_child(sun)
	var floor = MeshInstance3D.new(); var pm = PlaneMesh.new(); pm.size = Vector2(200,200); floor.mesh = pm
	var fm = StandardMaterial3D.new(); fm.albedo_color = Color(0.7,0.5,0.4); floor.material_override = fm
	root3.add_child(floor)
	var r = load("res://DirtRampCSG.gd").new(); root3.add_child(r)
	var cam = Camera3D.new(); root3.add_child(cam); cam.current = true
	var views = {"side":[Vector3(45,6,0),Vector3(0,4,0)],"front":[Vector3(10,9,-40),Vector3(0,4,0)],"three":[Vector3(28,12,-30),Vector3(0,4,0)]}
	for i in 30: await process_frame
	for k in views:
		cam.position = views[k][0]; cam.look_at(views[k][1])
		for i in 5: await process_frame
		root.get_texture().get_image().save_png("%s/dirt_ramp_%s.png" % [dir,k])
	quit()
