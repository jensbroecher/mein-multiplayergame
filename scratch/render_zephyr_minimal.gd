extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var vp := get_viewport()
	vp.scaling_3d_scale = 1.0
	vp.msaa_3d = Viewport.MSAA_4X

	var out_dir := "scratch/shots_zephyr"
	if not DirAccess.dir_exists_absolute("res://" + out_dir):
		DirAccess.make_dir_recursive_absolute("res://" + out_dir)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.88, 0.89, 0.90)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.79, 0.81)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-40, -45, 0)
	key_light.light_energy = 1.8
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-25, 135, 0)
	fill_light.light_energy = 0.8
	add_child(fill_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-15, 30, 0)
	rim_light.light_energy = 0.6
	add_child(rim_light)

	var ground := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(30, 30)
	ground.mesh = plane_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.82, 0.83, 0.85)
	ground_mat.roughness = 0.35
	ground.material_override = ground_mat
	add_child(ground)

	var car_scene: PackedScene = load("res://generated/cars/Zephyr.tscn")
	var car: Node3D = car_scene.instantiate()
	car.rotation.y = PI
	car.scale = Vector3(2.0, 2.0, 2.0)
	add_child(car)

	var CarPaint = load("res://CarPaint.gd")
	CarPaint.apply(car, CarPaint.factory("Zephyr"))

	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.make_current()

	# Let the engine render a couple of frames, then capture immediately.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var poses := {
		"side": [Vector3(4.8, 0.70, 0.0), Vector3(0.0, 0.45, 0.0)],
		"front_3q": [Vector3(3.2, 1.45, -3.2), Vector3(0.0, 0.45, 0.0)],
		"rear_3q": [Vector3(3.4, 1.55, 3.2), Vector3(0.0, 0.45, 0.0)],
	}
	for shot_name in poses.keys():
		var p: Vector3 = poses[shot_name][0]
		var t: Vector3 = poses[shot_name][1]
		cam.position = p
		cam.look_at(t, Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = vp.get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, shot_name])
		print("SAVED: ", shot_name)

	get_tree().quit(0)
