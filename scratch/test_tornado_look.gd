extends SceneTree

func _initialize():
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/Users/jensbrocher/.gemini/antigravity/brain/c17bffc8-1e40-4f64-87dd-dba36506980b"
	var w := Node3D.new()
	root.add_child(w)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.52, 0.62)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.68, 0.68, 0.72)
	w.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -45, 0)
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.light_energy = 1.3
	w.add_child(sun)

	# Ground plane to check touchdown contact and dust
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(200, 200)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.32, 0.18, 0.12) # Canyon dirt
	ground_mesh.material = gmat
	var ground_inst := MeshInstance3D.new()
	ground_inst.mesh = ground_mesh
	w.add_child(ground_inst)

	var cam := Camera3D.new()
	w.add_child(cam)
	cam.current = true

	var m: Node3D = load("res://Tornado.tscn").instantiate()
	m.scale = Vector3.ONE
	w.add_child(m)

	for i in 8:
		await process_frame

	# Shot 1: Racer ground-level view (Y=2.5m, looking up at the 35m vortex)
	cam.position = Vector3(32, 3.5, 32)
	cam.look_at(Vector3(0, 14, 0))
	for i in 25:
		await process_frame
	var img1 := root.get_texture().get_image()
	if img1:
		img1.save_png("%s/tornado_ground_view.png" % dir)
		print("Saved tornado_ground_view.png")

	# Shot 2: Full profile view (Y=16m, distance 55m)
	cam.position = Vector3(45, 16.0, 35)
	cam.look_at(Vector3(0, 17, 0))
	for i in 15:
		await process_frame
	var img2 := root.get_texture().get_image()
	if img2:
		img2.save_png("%s/tornado_full_profile.png" % dir)
		print("Saved tornado_full_profile.png")

	quit()
