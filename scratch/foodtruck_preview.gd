extends SceneTree

# Look-dev for the food trucks: builds them in memory and renders them on a paved yard. Run windowed:
#   Godot --path . --resolution 1400x900 -s res://scratch/foodtruck_preview.gd -- <out_dir> [truck=0] [all=1] [scale=1]
#       [fov=40] name:x,y,z:tx,ty,tz ...
# Life size by default, nose toward -z, the serving hatch on +x. `all=1` parks the three trucks 8m apart.
const FoodTruckKit = preload("res://FoodTruckKit.gd")
const PropKit = preload("res://PropKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var truck := 0
	var all := false
	var sc := 1.0
	var fov := 40.0
	var shots := []
	for a in args.slice(1):
		if a.begins_with("truck="):
			truck = int(a.substr(6))
		elif a == "all=1":
			all = true
		elif a.begins_with("scale="):
			sc = float(a.substr(6))
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		else:
			shots.append(a)
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
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)
	var kit := PropKit.new()
	var mats := {}
	kit.material_for = func(key: String) -> Material:
		if not mats.has(key):
			mats[key] = FoodTruckKit.make_material(key)
		return mats[key]
	kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * sc), Vector3.ZERO))
	var ids: Array = range(FoodTruckKit.TRUCKS.size()) if all else [truck]
	var n := 0
	for id in ids:
		var t0 := Time.get_ticks_msec()
		var mesh: ArrayMesh = FoodTruckKit.new(kit).build_truck(FoodTruckKit.TRUCKS[id])
		var tris := 0
		for s in range(mesh.get_surface_count()):
			tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		print("%s: %d triangles, %.2fs" % [FoodTruckKit.TRUCKS[id]["name"], tris, (Time.get_ticks_msec() - t0) / 1000.0])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3((float(n) - float(ids.size() - 1) * 0.5) * 8.0 * sc, 0.0, 0.0) if all else Vector3.ZERO
		root.add_child(mi)
		n += 1
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
