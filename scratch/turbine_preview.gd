extends SceneTree

# Look-dev for the wind turbine (WindTurbineBuilder.gd, WindTurbine.gd): builds one on a meadow and renders
# it from named cameras. Run windowed:
#   Godot --path . --resolution 1376x768 -s res://scratch/turbine_preview.gd -- <out_dir> [spin=40] [angle=30]
#       [fov=50] [sun=<pitch>,<yaw>] name:x,y,z:tx,ty,tz[:frames[:gap]] ...
# The tower stands at the origin, the rotor faces +z (upwind) with its hub about (0, 40, 2.2). A shot with
# frames > 1 saves name_00.png, name_01.png, ... `gap` seconds apart (default 0.1), to watch it turn.
const WindTurbineBuilder = preload("res://WindTurbineBuilder.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var spin := 40.0
	var angle := 30.0
	var fov := 50.0
	var sun_rot := Vector3(-40.0, -35.0, 0.0)
	var shots := []
	for a in args.slice(1):
		if a.begins_with("spin="):
			spin = float(a.substr(5))
		elif a.begins_with("angle="):
			angle = float(a.substr(6))
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("sun="):
			var f := a.substr(4).split(",")
			sun_rot = Vector3(float(f[0]), float(f[1]), 0.0)
		else:
			shots.append(a)
	_setup_world(sun_rot)
	root.add_child(WindTurbineBuilder.build_turbine(spin, angle, 0.0))
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = 2000.0
	root.add_child(cam)
	cam.make_current()
	for i in 40:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		var frames := int(parts[3]) if parts.size() > 3 else 1
		var gap := float(parts[4]) if parts.size() > 4 else 0.1
		for f in frames:
			if f > 0:
				await create_timer(gap).timeout
			else:
				for i in 6:
					await process_frame
			await RenderingServer.frame_post_draw
			var file := parts[0] if frames == 1 else "%s_%02d" % [parts[0], f]
			root.get_texture().get_image().save_png("%s/%s.png" % [out, file])
			print("SHOT ", file)
	quit()


func _setup_world(sun_rot: Vector3) -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.3, 0.5, 0.2)
	gmat.roughness = 0.95
	pm.material = gmat
	gm.mesh = pm
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.3, 0.52, 0.86)
	sm.sky_horizon_color = Color(0.74, 0.82, 0.9)
	sm.ground_bottom_color = Color(0.3, 0.35, 0.25)
	sm.ground_horizon_color = Color(0.7, 0.75, 0.7)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.06
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	root.add_child(sun)
