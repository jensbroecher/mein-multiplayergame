extends SceneTree
## Renders RowboatCSG.gd's boat (built, updated, baked as the Lakeside generator does) on a flat lake in
## a second or two. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/rowboat_preview.gd -- <dir> [csg=1] name:x,y,z:tx,ty,tz ...
## Life size (bow toward -z, waterline y = 0). `csg=1` shows the live CSG tree instead of the baked mesh.

const RowboatCSG = preload("res://RowboatCSG.gd")
const CampKit = preload("res://CampKit.gd")

var _mats := {}


func _material(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"timber", "lapboards", "battens", "painted":
			var wm := ShaderMaterial.new()
			wm.shader = load("res://hut_wood.gdshader")
			wm.set_shader_parameter("style", {"timber": 2, "lapboards": 1, "battens": 0, "painted": 3}[key])
			wm.set_shader_parameter("weathering", 0.55)
			m = wm
		"iron":
			m = CampKit.make_material("steel")
		_:
			m = CampKit.make_material(key)
	_mats[key] = m
	return m


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/rowboat"
	DirAccess.make_dir_recursive_absolute(dir)
	var live := "csg=1" in args
	var shots: Array = []
	for a in args.slice(1):
		var parts := String(a).split(":")
		if parts.size() >= 3:
			var p := parts[1].split_floats(",")
			var t := parts[2].split_floats(",")
			shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])])
	if shots.is_empty():
		shots = [["side", Vector3(5.5, 1.6, 1.0), Vector3(0, 0.2, 0)], ["bow", Vector3(-3.0, 2.2, -5.0), Vector3(0, 0.2, 0)],
				["above", Vector3(1.5, 5.0, 3.0), Vector3(0, 0.1, 0.2)], ["stern", Vector3(2.5, 1.8, 5.0), Vector3(0, 0.3, 0)]]

	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-140.0), 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.16, 0.30, 0.42, 0.75)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.1
	water.material_override = wm
	root.add_child(water)

	var csg := RowboatCSG.build()
	root.add_child(csg)
	for i in range(3):
		await process_frame
	if not live:
		var t0 := Time.get_ticks_msec()
		var mesh := RowboatCSG.bake(csg, _material)
		var tris := 0
		for si in range(mesh.get_surface_count()):
			tris += (mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		print("baked: %d surfaces, %d triangles, AABB %s (%d ms)" % [mesh.get_surface_count(), tris, mesh.get_aabb(), Time.get_ticks_msec() - t0])
		csg.queue_free()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		root.add_child(mi)

	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	for i in range(40):
		await process_frame
	for s in shots:
		cam.look_at_from_position(s[1], s[2])
		for i in range(4):
			await process_frame
		var img := get_root().get_texture().get_image()
		var path: String = dir.path_join("%s.png" % s[0])
		img.save_png(path)
		print("SHOT ", path)
	quit()
