extends SceneTree
## Renders Marina Nights' new set pieces in memory at night in a second or two, without building the level. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/marina_landmark_preview.gd -- <dir> [set=fanous|car]
##       name:x,y,z:tx,ty,tz[:fov] ...
## fanous: MarinaKit.fanous_tower at the origin (world metres). car: two of MarinaKit.hanging_car (life size) hung cab
## to cab outward under a stand-in rail at y 0.

const MarinaKit = preload("res://MarinaKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/marina_landmark"
	DirAccess.make_dir_recursive_absolute(dir)
	var which := "fanous"
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = a.substr(4)
		else:
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]), float(parts[3]) if parts.size() > 3 else 40.0])
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.01, 0.02, 0.06)
	sky.sky_horizon_color = Color(0.16, 0.12, 0.18)
	sky.ground_horizon_color = Color(0.08, 0.07, 0.09)
	sky.ground_bottom_color = Color(0.02, 0.02, 0.03)
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.18, 0.30)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.12
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-140.0), 0.0)
	sun.light_energy = 0.25
	sun.light_color = Color(0.62, 0.70, 0.95)
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.03, 0.06, 0.09)
	gm.roughness = 0.2
	ground.material_override = gm
	root.add_child(ground)
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	if which == "car":
		ground.position.y = -12.0
		var l: float = MarinaKit.CAR_LEN
		pk.set_frame(Transform3D(Basis(), Vector3(0, 0, -l * 0.5 - 0.15)))
		MarinaKit.hanging_car(pk, kit, true)
		pk.set_frame(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, l * 0.5 + 0.15)))
		MarinaKit.hanging_car(pk, kit, true)
		pk.reset_frame()
		pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(0, 0.9, 0)), Vector3(1.4, 1.6, 40.0), Color(0.3, 0.32, 0.35))
		if shots.is_empty():
			shots = [["car_side", Vector3(16, -2, 6), Vector3(0, -2.5, 0), 45.0], ["car_front", Vector3(-6, -3, -26), Vector3(0, -2.5, -8), 45.0],
					["car_below", Vector3(7, -9, -10), Vector3(0, -2.5, 0), 50.0]]
	else:
		var top: float = MarinaKit.fanous_tower(pk, kit)
		print("Fanous: beacon at %.0fm" % top)
		if shots.is_empty():
			shots = [["fanous_far", Vector3(0, 60, -900), Vector3(0, 150, 0), 40.0], ["fanous_mid", Vector3(-180, 20, -260), Vector3(0, 130, 0), 50.0],
					["fanous_base", Vector3(-60, 8, -130), Vector3(0, 60, 0), 55.0]]
	var mesh := MarinaKit.commit(pk, kit)
	var tris := 0
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var idx = arr[Mesh.ARRAY_INDEX]
		tris += ((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	print("%s: %d surfaces, %d triangles, AABB %s" % [which, mesh.get_surface_count(), tris, mesh.get_aabb()])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if which == "car":
		mi.scale = Vector3.ONE
	root.add_child(mi)
	var cam := Camera3D.new()
	cam.far = 4000.0
	root.add_child(cam)
	cam.current = true
	for i in range(45):
		await process_frame
	for s in shots:
		cam.fov = s[3]
		cam.look_at_from_position(s[1], s[2])
		for i in range(4):
			await process_frame
		var img := get_root().get_texture().get_image()
		var path: String = dir.path_join("%s.png" % s[0])
		img.save_png(path)
		print("SHOT ", path)
	quit()
