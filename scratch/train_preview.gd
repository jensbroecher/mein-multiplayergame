extends SceneTree

# Look-dev for Freight Line's rolling stock: puts a Train on a straight track in memory and renders it
# from named cameras. Run windowed:
#   Godot --path . --resolution 1400x900 -s res://scratch/train_preview.gd -- <out_dir> [head=120]
#       [consist=loco,box,flat,...] [fov=40] [sun=<pitch>,<yaw>] name:x,y,z:tx,ty,tz ...
# The track runs along +z from the origin; `head` is how far along it the locomotive's front is.
const Train = preload("res://Train.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var head := 150.0
	var consist := PackedStringArray(["loco", "box", "box:1", "flat", "flat_load", "gap:16", "tank", "tank:1", "box:2", "caboose"])
	var fov := 40.0
	var sun_rot := Vector3(-55.0, 38.0, 0.0)
	var shots := []
	for a in args.slice(1):
		if a.begins_with("head="):
			head = float(a.substr(5))
		elif a.begins_with("consist="):
			consist = PackedStringArray(a.substr(8).split(","))
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("sun="):
			var f := a.substr(4).split(",")
			sun_rot = Vector3(float(f[0]), float(f[1]), 0.0)
		else:
			shots.append(a)
	_setup_world(sun_rot)
	var curve := Curve3D.new()
	curve.add_point(Vector3(0, 0, 0))
	curve.add_point(Vector3(0, 0, 400))
	var train := Train.new()
	train.path = curve
	train.consist = consist
	train.speed = 20.0
	train.period = 100.0
	train.clock_override = head / 20.0
	train.kills = false
	root.add_child(train)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = 800.0
	root.add_child(cam)
	cam.make_current()
	for i in 40:
		await process_frame
	var tris := 0
	for car in train.cars:
		if car.node:
			var m: ArrayMesh = car.node.mesh
			for s in m.get_surface_count():
				tris += (m.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("train: %d cars, %.0fm, %d triangles" % [train.cars.size(), train.train_length, tris])
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
	pm.size = Vector2(600, 600)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.62, 0.50, 0.38)
	gmat.roughness = 0.95
	pm.material = gmat
	root.add_child(gm)
	# Ballast and two rails, so the wheels have something to stand on.
	var bm := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(5.0, 0.3, 600)
	bm.mesh = bx
	bm.position = Vector3(0, -0.15, 200)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.42, 0.40, 0.38)
	bx.material = bmat
	root.add_child(bm)
	for sx in [-0.7175, 0.7175]:
		var rm := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.12, 0.16, 600)
		rm.mesh = rb
		rm.position = Vector3(sx * 1.5 / 1.0, -0.08, 200)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.25, 0.22, 0.2)
		rmat.metallic = 0.6
		rb.material = rmat
		root.add_child(rm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.52, 0.86)
	sm.sky_horizon_color = Color(0.78, 0.84, 0.90)
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
	sun.directional_shadow_max_distance = 200.0
	root.add_child(sun)
