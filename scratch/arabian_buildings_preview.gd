extends SceneTree
## Renders ArabianKit's forts, watchtowers and houses in memory on a flat sand plain in desert light, grown by the
## stages' PROP_SCALE (1.6) as ArabianDresser.building does, in a second or two. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/arabian_buildings_preview.gd -- <dir> [set=fort|tower|houses|mosque|villa]
##       [style=0|1] [seed=7] name:x,y,z:tx,ty,tz[:fov] ...
## style picks the variant the stage uses (0 Jebel Sahar's, 1 Wadi al-Ghaf's). The fort's gate faces -z.

const ArabianKit = preload("res://ArabianKit.gd")
const PS := 1.6


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/arabian_preview"
	DirAccess.make_dir_recursive_absolute(dir)
	var which := "fort"
	var style := 0
	var seed_v := 7
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		elif a.begins_with("style="):
			style = int(a.substr(6))
		elif a.begins_with("seed="):
			seed_v = int(a.substr(5))
		else:
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]), float(parts[3]) if parts.size() > 3 else 45.0])
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.32, 0.50, 0.78)
	sky.sky_horizon_color = Color(0.86, 0.78, 0.66)
	sky.ground_horizon_color = Color(0.80, 0.64, 0.46)
	sky.ground_bottom_color = Color(0.55, 0.42, 0.30)
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(-120.0), 0.0)
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.9, 0.74)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.86, 0.64, 0.42)
	gm.roughness = 0.95
	ground.material_override = gm
	root.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var build := func(xf: Transform3D, fn: Callable) -> void:
		var pk := ArabianKit.new_kit(PS)
		pk.set_frame(Transform3D(xf.basis.scaled(Vector3.ONE * PS), xf.origin))
		var kit := {}
		fn.call(pk, kit)
		var mi := MeshInstance3D.new()
		mi.mesh = ArabianKit.commit(pk, kit)
		root.add_child(mi)
	match which:
		"fort":
			build.call(Transform3D(), func(pk, kit) -> void:
				ArabianKit.fort(pk, kit, rng, 32.0 if style == 0 else 30.0, 8.0 if style == 0 else 7.5, style))
			if shots.is_empty():
				shots = [["fort_gate", Vector3(-30, 16, -95), Vector3(0, 10, 0), 45.0], ["fort_corner", Vector3(70, 24, -60), Vector3(0, 8, 0), 45.0],
						["fort_above", Vector3(40, 70, 60), Vector3(0, 0, 0), 50.0], ["fort_close", Vector3(-12, 5, -50), Vector3(0, 9, -26), 50.0]]
		"tower":
			for i in range(3):
				build.call(Transform3D(Basis(), Vector3((float(i) - 1.0) * 22.0, 0, 0)), func(pk, kit) -> void:
					ArabianKit.watchtower(pk, kit, 10.0 + i * 2.0, 2.8, style))
			if shots.is_empty():
				shots = [["towers", Vector3(0, 10, -60), Vector3(0, 9, 0), 45.0], ["tower_close", Vector3(-6, 4, -16), Vector3(0, 9, 0), 55.0]]
		"villa":
			build.call(Transform3D(), func(pk, kit) -> void:
				ArabianKit.villa(pk, kit, rng))
			if shots.is_empty():
				shots = [["villa", Vector3(8, 14, -120), Vector3(0, 9, 0), 45.0], ["villa_low", Vector3(-34, 3.5, -78), Vector3(4, 11, 6), 50.0],
						["villa_above", Vector3(60, 70, -70), Vector3(0, 4, 0), 50.0]]
		"mosque":
			build.call(Transform3D(), func(pk, kit) -> void:
				ArabianKit.mosque(pk, kit, rng, 10.0, 8.0, style))
			if shots.is_empty():
				shots = [["mosque", Vector3(14, 8, -34), Vector3(0, 6, 0), 45.0], ["mosque_back", Vector3(-20, 10, 30), Vector3(0, 6, 0), 45.0]]
		_:
			for i in range(6):
				var x: float = (float(i % 3) - 1.0) * 26.0
				var z: float = (float(i / 3) - 0.5) * 34.0
				build.call(Transform3D(Basis(), Vector3(x, 0, z)), func(pk, kit) -> void:
					if style == 1:
						ArabianKit.house_najdi(pk, kit, rng, rng.randf_range(9.0, 12.0), rng.randf_range(8.0, 10.0), 1 + i % 2)
					else:
						ArabianKit.house(pk, kit, rng, rng.randf_range(9.0, 12.0), rng.randf_range(8.0, 10.0), 1 + i % 2, "mud"))
			if shots.is_empty():
				shots = [["houses", Vector3(-10, 22, -90), Vector3(0, 4, 0), 45.0], ["houses_close", Vector3(-30, 5, -45), Vector3(-26, 5, -17), 55.0]]
	var cam := Camera3D.new()
	cam.far = 3000.0
	root.add_child(cam)
	cam.current = true
	for i in range(40):
		await process_frame
	for s in shots:
		cam.fov = s[3]
		cam.look_at_from_position(s[1], s[2])
		for i in range(4):
			await process_frame
		var img := get_root().get_texture().get_image()
		var path: String = dir.path_join("%s_%d.png" % [s[0], style])
		img.save_png(path)
		print("SHOT ", path)
	quit()
