extends SceneTree
## Extrudes a word (Arabic by default: الريحانة, Al-Raihana) through Godot's TextMesh in each font given, one row per
## font, in gold, on a dark plain at dusk, and photographs them, to choose a font for a monument. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/arabic_text_preview.gd -- <dir> font=<ttf> [font=...]
##       [text=...] [size=64] [depth=0.35] name:x,y,z:tx,ty,tz[:fov] ...
## Fonts are read from any path (FontFile.load_dynamic_font). Prints each mesh's triangles and size.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/arabic_text"
	DirAccess.make_dir_recursive_absolute(dir)
	var fonts: Array = []
	var text := "الريحانة"
	var size := 64
	var depth := 0.35
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("font="):
			fonts.append(a.substr(5))
		elif a.begins_with("text="):
			text = a.substr(5)
		elif a.begins_with("size="):
			size = int(a.substr(5))
		elif a.begins_with("depth="):
			depth = float(a.substr(6))
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
	sky.sky_top_color = Color(0.20, 0.30, 0.55)
	sky.sky_horizon_color = Color(0.95, 0.70, 0.50)
	sky.ground_horizon_color = Color(0.40, 0.32, 0.28)
	sky.ground_bottom_color = Color(0.10, 0.09, 0.09)
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-25.0), deg_to_rad(-150.0), 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.30, 0.27, 0.25)
	ground.material_override = gm
	root.add_child(ground)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.76, 0.33)
	gold.metallic = 1.0
	gold.roughness = 0.28
	var row := 0
	for path in fonts:
		var ff := FontFile.new()
		var err := ff.load_dynamic_font(String(path))
		if err != OK:
			print("FONT FAILED ", path, " ", err)
			continue
		var tm := TextMesh.new()
		tm.text = text
		tm.font = ff
		tm.font_size = size
		tm.pixel_size = 0.05
		tm.depth = depth
		tm.curve_step = 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = gold
		mi.position = Vector3(0, 2.5 + row * 6.0, 0)
		root.add_child(mi)
		var arr := tm.get_mesh_arrays()
		var tris: int = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		print("ROW %d %s: %d triangles, AABB %s" % [row, String(path).get_file(), tris, tm.get_aabb()])
		row += 1
	if shots.is_empty():
		var h: float = 2.5 + row * 3.0
		shots = [["rows", Vector3(0, h, 34.0 + row * 4.0), Vector3(0, h, 0), 45.0], ["rows_angle", Vector3(-24, h + 4.0, 26.0 + row * 3.0), Vector3(0, h, 0), 45.0]]
	var cam := Camera3D.new()
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
		var out: String = dir.path_join("%s.png" % s[0])
		img.save_png(out)
		print("SHOT ", out)
	quit()
