extends SceneTree

# Look-dev for the Test Track's buildings (ProvingGroundKit.gd): builds the pit building, the control tower (with the
# 3D logo on its turntable), the workshop and the office on a flat field in memory and renders them from named cameras,
# without generating the level. Run windowed:
#   Godot --path . --resolution 1400x850 -s res://scratch/proving_ground_preview.gd -- <out_dir> [set=pit,tower,workshop,office]
#       name:x,y,z:tx,ty,tz[:fov] ...
# At PROP_SCALE 1.6, fronts toward +z: the pit building at (0, 0, 0), the tower at (-90, 0, 0), the workshop at (90, 0, 0),
# the office at (180, 0, 0).
const PGK = preload("res://ProvingGroundKit.gd")
const SCALE := 1.6
const SPOTS := {"pit": Vector3(0, 0, 0), "tower": Vector3(-90, 0, 0), "workshop": Vector3(90, 0, 0), "office": Vector3(180, 0, 0)}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var which := ["pit", "tower", "workshop", "office"]
	var shots := []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = Array(a.substr(4).split(","))
		else:
			shots.append(a)
	_setup_world()
	var tris := 0
	for w in which:
		var pk = PGK.new_kit(SCALE)
		var kit := {}
		var labels: Array = []
		match w:
			"pit": PGK.pit_building(pk, kit, labels)
			"tower": PGK.control_tower(pk, kit, labels)
			"workshop": PGK.workshop(pk, kit, labels)
			"office": PGK.office(pk, kit, labels)
		var mesh: ArrayMesh = PGK.commit(pk, kit)
		var t := 0
		for si in mesh.get_surface_count():
			t += (mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		print("  %s: %d surfaces, %d triangles" % [w, mesh.get_surface_count(), t])
		tris += t
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = SPOTS[w]
		root.add_child(mi)
		for l in labels:
			_label(l, SPOTS[w])
		if w == "tower":
			var spin := Node3D.new()
			spin.position = SPOTS[w] + Vector3(0, PGK.TOWER_LOGO_Y, -0.5) * SCALE
			root.add_child(spin)
			for k in 2:
				var logo: Node3D = (load("res://generated/logo/RcVibeLogo.tscn") as PackedScene).instantiate()
				logo.scale = Vector3.ONE * 2.4
				logo.rotation.y = PI * float(k)
				logo.position = Vector3(0, 1.708 * 2.4, 0)
				spin.add_child(logo)
			spin.rotation.y = 0.35
	print("triangles ", tris)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 3000.0
	root.add_child(cam)
	cam.make_current()
	for i in 40:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 55.0
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


func _label(l: Array, origin: Vector3) -> void:
	var lab := Label3D.new()
	lab.text = l[0]
	lab.font = load("res://fonts/NotoSansSC-Yunhai.otf")
	lab.font_size = 64
	lab.pixel_size = float(l[3]) * SCALE / 44.8
	lab.modulate = l[4]
	lab.outline_size = 0
	lab.double_sided = false
	var n: Vector3 = l[2]
	lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), origin + (l[1] as Vector3) * SCALE)
	root.add_child(lab)


func _setup_world() -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.36, 0.46, 0.26)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(0, -0.02, 0)
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.50, 0.85)
	sm.sky_horizon_color = Color(0.80, 0.84, 0.88)
	sm.ground_bottom_color = Color(0.45, 0.42, 0.38)
	sm.ground_horizon_color = Color(0.72, 0.70, 0.66)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, 20.0, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	root.add_child(sun)
