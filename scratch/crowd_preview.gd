extends SceneTree

# Look-dev for Nyota Stadium's crowd: builds the spectators in memory (no regeneration needed) and renders them.
# Run windowed:
#   Godot --path . --resolution 1400x900 -s res://scratch/crowd_preview.gd -- <out_dir> [rows=3] [seed=1]
#       [cards=1] [skin=<g>] [fov=40] [sun=<pitch>,<yaw>] name:x,y,z:tx,ty,tz ...
# A row per variant, a column per pose 0..15 (2.6m apart, x = 0 .. 39), facing +z; the camera looks along -z.
# Seated poses (0-6) are on seat blocks. `cards=1` puts the far level of detail (the card) in a row behind,
# `skin=<g>` forces the skin draw (0 .. 1) for every spectator.
const CrowdKit = preload("res://CrowdKit.gd")

const SPACING := 2.6


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var rows := 3
	var seed_v := 1
	var cards := false
	var skin := -1.0
	var fov := 40.0
	var sun_rot := Vector3(-48.0, 38.0, 0.0)
	var shots := []
	for a in args.slice(1):
		if a.begins_with("rows="):
			rows = int(a.substr(5))
		elif a.begins_with("seed="):
			seed_v = int(a.substr(5))
		elif a == "cards=1":
			cards = true
		elif a.begins_with("skin="):
			skin = float(a.substr(5))
		elif a.begins_with("fov="):
			fov = float(a.substr(4))
		elif a.begins_with("sun="):
			var f := a.substr(4).split(",")
			sun_rot = Vector3(float(f[0]), float(f[1]), 0.0)
		else:
			shots.append(a)
	_setup_world(sun_rot)
	var t0 := Time.get_ticks_msec()
	var mesh: ArrayMesh = CrowdKit.new().build()
	print("spectator: %d triangles, built in %.0fms" % [(mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, Time.get_ticks_msec() - t0])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://stadium_person.gdshader")
	mat.set_shader_parameter("lod_mode", 1)
	mat.set_shader_parameter("lod_fade_begin", 500.0)
	mat.set_shader_parameter("lod_fade_end", 600.0)
	mat.set_shader_parameter("lod_jitter", 0.0)
	mesh.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var transforms: Array = []
	var customs: Array = []
	for r in range(rows):
		for p in range(16):
			var g := skin if skin >= 0.0 else rng.randf()
			var y := 0.84 if p < 7 else 0.0
			transforms.append(Transform3D(Basis(), Vector3(float(p) * SPACING, y, -float(r) * 3.4)))
			customs.append(Color(rng.randf(), g, (float(p) + 0.5) / 16.0, rng.randf()))
	_multimesh(mesh, transforms, customs)
	# Seat blocks under the seated poses.
	var seat := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.84, 1.0)
	seat.mesh = bm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.10, 0.45, 0.22)
	bm.material = smat
	for r in range(rows):
		for p in range(7):
			var s := seat.duplicate()
			s.position = Vector3(float(p) * SPACING, 0.42, -float(r) * 3.4 - 0.0)
			root.add_child(s)
	if cards:
		# The far level of detail, in the generator's five card shapes (regenerate_nyota_stadium.gd's CROWD_CARDS).
		var shapes := [[1.1, 2.75, 0.9, 0.0, 0.475], [2.1, 3.15, 0.9, 0.0, 0.675], [1.1, 3.5, 1.65, 0.0, 1.75], [2.1, 3.9, 1.65, 0.0, 1.95], [3.0, 4.9, 1.65, -0.5, 2.45]]
		for cls in range(shapes.size()):
			var sh: Array = shapes[cls]
			var card := QuadMesh.new()
			card.size = Vector2(float(sh[0]), float(sh[1]))
			card.center_offset = Vector3(float(sh[3]), float(sh[4]), 0.0)
			var cm := ShaderMaterial.new()
			cm.shader = load("res://stadium_crowd.gdshader")
			cm.set_shader_parameter("lod_mode", 2)
			cm.set_shader_parameter("lod_fade_begin", -100.0)
			cm.set_shader_parameter("lod_fade_end", -50.0)
			cm.set_shader_parameter("lod_jitter", 0.0)
			cm.set_shader_parameter("card_w", float(sh[0]))
			cm.set_shader_parameter("card_h", float(sh[1]))
			cm.set_shader_parameter("card_below", float(sh[2]))
			cm.set_shader_parameter("card_x", float(sh[3]))
			card.material = cm
			var ct: Array = []
			var cc: Array = []
			for p in range(16):
				var pc := 1 if p == 5 else (3 if (p == 9 or p == 14) else (4 if p == 12 else (2 if p >= 7 else 0)))
				if pc != cls:
					continue
				var seated := p < 7
				# Seated cards stand forward of the seat, as in the level.
				ct.append(Transform3D(Basis(), Vector3(float(p) * SPACING, 0.84 if seated else 0.0, 3.4 + (0.6 if seated else 0.0))))
				var rr := RandomNumberGenerator.new()
				rr.seed = seed_v * 100 + p
				cc.append(Color(rr.randf(), skin if skin >= 0.0 else rr.randf(), (float(p) + 0.5) / 16.0, rr.randf()))
			if not ct.is_empty():
				_multimesh(card, ct, cc)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
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


func _multimesh(mesh: Mesh, transforms: Array, customs: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_custom_data(i, customs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)


func _setup_world(sun_rot: Vector3) -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.62, 0.60, 0.56)
	gmat.roughness = 0.95
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
	sun.directional_shadow_max_distance = 80.0
	root.add_child(sun)
