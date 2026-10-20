extends SceneTree

# Look-dev for the street light: builds it in memory and renders it from named cameras. Run windowed:
#   Godot --path . --resolution 1400x900 -s res://scratch/streetlamp_preview.gd -- <out_dir> [scale=1.35]
#       [fov=40] [sun=<pitch>,<yaw>] name:x,y,z:tx,ty,tz ...
# The pole stands at the origin, the arm reaches along +x. `scale=1` is life size (8.9m pole).
const StreetLampKit = preload("res://StreetLampKit.gd")
const PropKit = preload("res://PropKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var sc := 1.35
	var fov := 40.0
	var sun_rot := Vector3(-48.0, 38.0, 0.0)
	var shots := []
	for a in args.slice(1):
		if a.begins_with("scale="):
			sc = float(a.substr(6))
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("sun="):
			var f := a.substr(4).split(",")
			sun_rot = Vector3(float(f[0]), float(f[1]), 0.0)
		else:
			shots.append(a)
	_setup_world(sun_rot)
	var kit := PropKit.new()
	var mats := {}
	kit.material_for = func(key: String) -> Material:
		if not mats.has(key):
			mats[key] = StreetLampKit.make_material(key)
		return mats[key]
	kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * sc), Vector3.ZERO))
	var t0 := Time.get_ticks_msec()
	var mesh: ArrayMesh = StreetLampKit.new(kit).build()
	var tris := 0
	for s in range(mesh.get_surface_count()):
		tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("street light: %d triangles, %d surfaces, %.2fs" % [tris, mesh.get_surface_count(), (Time.get_ticks_msec() - t0) / 1000.0])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.02
	cam.far = 400.0
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
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


func _setup_world(sun_rot: Vector3) -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.74, 0.71, 0.66)
	gmat.roughness = 0.9
	pm.material = gmat
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.52, 0.86)
	sm.sky_horizon_color = Color(0.74, 0.82, 0.90)
	sm.ground_bottom_color = Color(0.45, 0.42, 0.38)
	sm.ground_horizon_color = Color(0.70, 0.70, 0.68)
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
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)
