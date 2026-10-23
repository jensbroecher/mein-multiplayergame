@tool
extends SceneTree

func _init() -> void:
	print("--- RENDERING CLOSEUPS ---")
	var root := Node3D.new()
	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.4, 0.5, 0.6)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment = env_res
	root.add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 45, 0)
	sun.light_energy = 1.0
	root.add_child(sun)
	
	var turbine = WindTurbineBuilder.build_turbine(0, 0, 0)
	root.add_child(turbine)
	
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	var cam := Camera3D.new()
	vp.add_child(cam)
	root.add_child(vp)
	
	# We will save several shots
	var shots = [
		{"name": "cone_front", "pos": Vector3(0, 40, 7.0), "target": Vector3(0, 40, 2.5)},
		{"name": "cone_three_quarter", "pos": Vector3(4, 42, 6.0), "target": Vector3(0, 40, 3.5)},
		{"name": "cone_side", "pos": Vector3(6, 40, 2.5), "target": Vector3(0, 40, 2.5)},
		{"name": "socket_base", "pos": Vector3(4, 2.0, 4.0), "target": Vector3(0, 0.5, 0)},
		{"name": "socket_top_skirt", "pos": Vector3(3, 39.5, 2.0), "target": Vector3(0, 40, 0)},
	]
	
	DirAccess.make_dir_absolute("res://scratch/closeups")
	
	for shot in shots:
		cam.position = shot["pos"]
		cam.look_at(shot["target"], Vector3.UP)
		
		# Force render
		for f in range(3):
			RenderingServer.viewport_set_update_mode(vp.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
			RenderingServer.force_draw(true)
			await process_frame
			
		var img := vp.get_texture().get_image()
		var path: String = "res://scratch/closeups/" + shot["name"] + ".png"
		img.save_png(path)
		print("Saved: ", path)
		
	print("Done rendering closeups!")
	quit()
