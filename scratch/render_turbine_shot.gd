extends Node

const WindTurbineBuilder = preload("res://WindTurbineBuilder.gd")

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 800)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	
	# Create environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.70, 0.82, 0.93) # Lakeside sky blue
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.90, 0.95)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 45, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	
	# Sloped ground to test foundation embedment
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.35, 0.55, 0.28) # Meadow green
	ground.mesh = plane
	ground.material_override = gmat
	ground.rotation_degrees.z = 8.0 # 8-degree slope!
	add_child(ground)
	
	# Build turbine
	var turbine := WindTurbineBuilder.build_turbine(0.0, 30.0, 0.0)
	add_child(turbine)
	
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	
	var shots := [
		{
			"file": "res://scratch/shots_turbine/fixed_cone_closeup.png",
			"pos": Vector3(2.5, 40.8, 8.5),
			"target": Vector3(0.0, 40.0, 3.0),
			"fov": 32.0
		},
		{
			"file": "res://scratch/shots_turbine/fixed_cone_front.png",
			"pos": Vector3(0.0, 40.0, 7.5),
			"target": Vector3(0.0, 40.0, 2.5),
			"fov": 35.0
		},
		{
			"file": "res://scratch/shots_turbine/fixed_socket_closeup.png",
			"pos": Vector3(4.8, 3.2, 5.5),
			"target": Vector3(0.0, 0.9, 0.0),
			"fov": 42.0
		},
		{
			"file": "res://scratch/shots_turbine/fixed_full_preview.png",
			"pos": Vector3(0, 30, 75),
			"target": Vector3(0, 28, 0),
			"fov": 50.0
		}
	]
	
	DirAccess.make_dir_absolute("res://scratch/shots_turbine")
	
	for s in shots:
		cam.fov = s["fov"]
		cam.position = s["pos"]
		cam.look_at(s["target"], Vector3.UP)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(s["file"])
		print("SAVED: ", s["file"])
		
	get_tree().quit()
