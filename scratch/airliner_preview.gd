extends SceneTree
## Renders AirlinerKit's airliners in memory in a second or two, without a level. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/airliner_preview.gd -- <dir> [frame=twin|quad]
##       [livery=raihana] [gear=1] [night=1] [all=1] name:x,y,z:tx,ty,tz[:fov] ...
## Life size, the nose toward -z, the right wing +x, standing on its wheels on a grey apron. gear=0 folds the gear up
## (and lifts it off the apron); all=1 shoots a row of every livery from the side. Prints each mesh's triangles.

const AirlinerKit = preload("res://AirlinerKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/airliner"
	DirAccess.make_dir_recursive_absolute(dir)
	var frame := "twin"
	var livery := "raihana"
	var gear := 1.0
	var night := false
	var all := false
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("frame="):
			frame = a.substr(6)
		elif a.begins_with("livery="):
			livery = a.substr(7)
		elif a.begins_with("gear="):
			gear = float(a.substr(5))
		elif a == "night=1":
			night = true
		elif a == "all=1":
			all = true
		else:
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]), float(parts[3]) if parts.size() > 3 else 40.0])
	if shots.is_empty():
		shots = [["side", Vector3(95, 2, 0), Vector3(0, 1, 0), 40.0], ["front", Vector3(-48, 10, -70), Vector3(0, 1, 0), 40.0],
				["rear", Vector3(52, 16, 74), Vector3(0, 3, 4), 40.0], ["below", Vector3(30, -40, -30), Vector3(0, -2, 0), 45.0],
				["nose", Vector3(-14, 4, -46), Vector3(0, 0.5, -26), 35.0], ["tail", Vector3(24, 10, 40), Vector3(0, 6, 27), 35.0]]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	if night:
		sky.sky_top_color = Color(0.01, 0.02, 0.06)
		sky.sky_horizon_color = Color(0.2, 0.14, 0.18)
		sky.ground_horizon_color = Color(0.1, 0.08, 0.1)
		sky.ground_bottom_color = Color(0.02, 0.02, 0.03)
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if night else Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.16, 0.18, 0.30)
	env.ambient_light_energy = 0.35 if night else 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = night
	env.glow_intensity = 0.75
	env.glow_bloom = 0.12
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-130.0), 0.0)
	sun.light_energy = 0.22 if night else 1.25
	sun.light_color = Color(0.62, 0.70, 0.95) if night else Color(1, 0.96, 0.9)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.31, 0.30) if not night else Color(0.05, 0.05, 0.06)
	gm.roughness = 0.9
	ground.material_override = gm
	var c: Vector3 = AirlinerKit.contact(frame)
	ground.position.y = c.y - (0.0 if gear > 0.5 else 4.0)
	root.add_child(ground)
	for m in AirlinerKit.all_materials():
		(m as ShaderMaterial).set_shader_parameter("night", 1.0 if night else 0.0)
	var liveries: Array = AirlinerKit.LIVERIES.keys() if all else [livery]
	for li in range(liveries.size()):
		var lv: String = liveries[li]
		var node := Node3D.new()
		node.position = Vector3(0, 0, -95.0 * li) if all else Vector3.ZERO
		root.add_child(node)
		_build(node, frame, lv, gear, li == 0)
	if all:
		shots = [["fleet_side", Vector3(260, 3, -95.0 * (liveries.size() - 1) * 0.5), Vector3(0, 2, -95.0 * (liveries.size() - 1) * 0.5), 62.0],
				["fleet_tails", Vector3(70, 14, 60), Vector3(0, 8, -95.0 * (liveries.size() - 1) * 0.5), 40.0]]
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


func _build(node: Node3D, frame: String, livery: String, gear: float, report: bool) -> void:
	var mat := AirlinerKit.livery_material(livery)
	var params := AirlinerKit.instance_params(frame)
	var body := MeshInstance3D.new()
	body.mesh = AirlinerKit.airframe(frame)
	body.material_override = mat
	node.add_child(body)
	for k in params.keys():
		body.set_instance_shader_parameter(k, params[k])
	if report:
		print("%s airframe: %d triangles, AABB %s" % [frame, _tris(body.mesh), body.mesh.get_aabb()])
	for g in AirlinerKit.gear(frame):
		var mi := MeshInstance3D.new()
		mi.mesh = g[1]
		mi.material_override = mat
		var axis: Vector3 = g[3]
		mi.transform = Transform3D(Basis(axis, float(g[4]) * (1.0 - gear)), g[2])
		mi.visible = gear > 0.02
		node.add_child(mi)
		if report:
			print("  %s: %d triangles" % [g[0], _tris(mi.mesh)])
	var lights := MeshInstance3D.new()
	lights.mesh = AirlinerKit.lights_mesh(frame)
	lights.material_override = AirlinerKit.light_material()
	lights.extra_cull_margin = 80.0
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(lights)


func _tris(mesh: Mesh) -> int:
	var n := 0
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var idx = arr[Mesh.ARRAY_INDEX]
		n += ((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n
