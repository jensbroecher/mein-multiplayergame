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

	# 1. Studio Environment (Soft studio lighting matching high-end car look-dev)
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

	# 2. Key and Fill Lights
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-40, -45, 0)
	key_light.light_energy = 1.8
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-25, 135, 0)
	fill_light.light_energy = 0.8
	fill_light.shadow_enabled = false
	add_child(fill_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-15, 30, 0)
	rim_light.light_energy = 0.6
	rim_light.shadow_enabled = false
	add_child(rim_light)

	# 3. Ground plane
	var ground := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(30, 30)
	ground.mesh = plane_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.82, 0.83, 0.85)
	ground_mat.roughness = 0.35
	ground.material_override = ground_mat
	add_child(ground)

	# 4. Instantiate Zephyr (with game rotation and scale)
	var car_scene: PackedScene = load("res://generated/cars/Zephyr.tscn")
	var car: Node3D = car_scene.instantiate()
	car.rotation.y = PI
	car.scale = Vector3(2.0, 2.0, 2.0)
	add_child(car)

	var CarPaint = load("res://CarPaint.gd")
	CarPaint.apply(car, CarPaint.factory("Zephyr"))

	# 5. Camera
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.make_current()

	for i in 12:
		await get_tree().process_frame

	# Poses centered on the car (which spans roughly x: -1.5..1.5, y: 0..1.3, z: -1.8..1.8)
	var poses := {
		"user_issue1_fender": [Vector3(-5.0, 1.25, -2.6), Vector3(-0.4, 0.45, 0.4)],
		"user_issue2_window": [Vector3(-4.4, 1.60, 3.6), Vector3(0.0, 0.42, 0.0)],
		"concept_match":      [Vector3(-3.4, 2.0, -3.2), Vector3(0.0, 0.38, 0.0)],
		"front_3q":           [Vector3(3.2, 1.45, -3.2), Vector3(0.0, 0.45, 0.0)],
		"side":               [Vector3(-4.8, 0.70, 0.0), Vector3(0.0, 0.45, 0.0)],
		"wheel_close":        [Vector3(-2.8, 0.65, 1.3), Vector3(-1.26, 0.54, 1.3)],
		"rear_spoiler":       [Vector3(0.0, 1.60, -3.8), Vector3(0.0, 0.60, -1.0)],
		"top":                [Vector3(0.0, 5.5, 0.01),  Vector3(0.0, 0.0, 0.0)],
	}

	for shot_name in ["user_issue1_fender", "user_issue2_window", "concept_match", "front_3q", "side", "wheel_close", "rear_spoiler", "top"]:
		var p: Vector3 = poses[shot_name][0]
		var t: Vector3 = poses[shot_name][1]
		cam.position = p
		cam.look_at(t, Vector3.UP if shot_name != "top" else Vector3.FORWARD)

		for i in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var img: Image = vp.get_texture().get_image()
		var file_path := "%s/%s.png" % [out_dir, shot_name]
		img.save_png(file_path)
		print("SAVED SHOT: ", file_path)

	get_tree().quit(0)
