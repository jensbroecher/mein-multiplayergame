extends SceneTree

# Look-dev for the procedural cars: builds one in memory (no regeneration needed), paints it, and
# renders it on a grey yard from named cameras in the cart frame (metres, front at -Z).
# Run windowed:
#   Godot --path . --resolution 1400x900 -s res://scratch/car_preview.gd -- <out_dir> [car=Mudrunner]
#       [orig=res://models/cars/Viper.tscn] [scene=res://generated/cars/Mudrunner.tscn]
#       [paint=<pattern>,<finish>,<primary>,<secondary>,<accent>,<rim>,<number>] [fov=40] [yaw=0]
#       [sun=<pitch>,<yaw>] name:x,y,z:tx,ty,tz[:ux,uy,uz] ...
# orig renders an imported model instead, placed the way PlayerCart places it (x2, half turn);
# scene loads a saved car. Colours in paint= are hex (e.g. 2,1,cc2211,f0f0e8,ffcc00,c0c0c0,53).
const RegenCars = preload("res://regenerate_cars.gd")
const CarPaint = preload("res://CarPaint.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var car_name := "Mudrunner"
	var orig := ""
	var scene_path := ""
	var paint_arg := ""
	var fov := 40.0
	var yaw := 0.0
	var sun_rot := Vector3(-48.0, 38.0, 0.0)
	var shots := []
	for a in args.slice(1):
		if a.begins_with("car="):
			car_name = a.substr(4)
		elif a.begins_with("orig="):
			orig = a.substr(5)
		elif a.begins_with("scene="):
			scene_path = a.substr(6)
		elif a.begins_with("paint="):
			paint_arg = a.substr(6)
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("yaw="):
			yaw = deg_to_rad(float(a.substr(4)))
		elif a.begins_with("sun="):
			var f := a.substr(4).split(",")
			sun_rot = Vector3(float(f[0]), float(f[1]), 0.0)
		else:
			shots.append(a)
	_setup_world(sun_rot)
	var car: Node3D
	if not orig.is_empty():
		car = (load(orig) as PackedScene).instantiate()
	elif not scene_path.is_empty():
		car = (load(scene_path) as PackedScene).instantiate()
	else:
		var entry: Dictionary = {}
		for c in RegenCars.CARS:
			if c["name"] == car_name:
				entry = c
		var t0 := Time.get_ticks_msec()
		var parts: Dictionary = RegenCars.build_car(entry["builder"])
		print("built %s: %d triangles in %.1fs" % [car_name, parts["triangles"], (Time.get_ticks_msec() - t0) / 1000.0])
		car = RegenCars.assemble(car_name, parts)
	root.add_child(car)
	# PlayerCart's placement of a car model: x2, half turn (the procedural ones undo it inside).
	car.transform = Transform3D(Basis(Vector3.UP, PI + yaw) * 2.0, Vector3.ZERO)
	if CarPaint.is_paintable(car):
		var paint: Dictionary = CarPaint.factory(car_name)
		if not paint_arg.is_empty():
			var f := paint_arg.split(",")
			paint["pattern"] = int(f[0])
			paint["finish"] = int(f[1])
			paint["primary"] = Color.html(f[2])
			paint["secondary"] = Color.html(f[3])
			paint["accent"] = Color.html(f[4])
			paint["rim"] = Color.html(f[5])
			paint["number"] = int(f[6])
		CarPaint.apply(car, paint)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.02
	root.add_child(cam)
	cam.make_current()
	# New shaders compile in the background and draw nothing until ready: give them time.
	for i in 40:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		var up := Vector3.UP
		if parts.size() > 3:
			var u := parts[3].split(",")
			up = Vector3(float(u[0]), float(u[1]), float(u[2]))
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), up)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


func _setup_world(sun_rot: Vector3) -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.40, 0.40, 0.38)
	gmat.roughness = 0.95
	pm.material = gmat
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.50, 0.80)
	sm.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sm.ground_bottom_color = Color(0.25, 0.24, 0.22)
	sm.ground_horizon_color = Color(0.55, 0.56, 0.55)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	root.add_child(sun)
