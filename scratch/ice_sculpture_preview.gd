extends SceneTree

# Look-dev for Northlight Caverns' ice sculptures (IceSculptureKit.gd, ice_sculpture.gdshader): meshes every design (or
# `only=`) in a row along x, 6m apart from x 0, on a dark snowfield under a night sky with a coloured light at each
# foot, and renders them from named cameras. Windowed:
#   Godot --path . --resolution 1600x900 -s res://scratch/ice_sculpture_preview.gd -- <out_dir> [only=owl,swan]
#     [voxel=0.075] name:x,y,z:tx,ty,tz[:fov] ...
const Kit = preload("res://IceSculptureKit.gd")
const ORDER := ["owl", "reindeer", "whale", "swan", "bear", "snowflake", "spiral", "wave", "fox"]
const GLOWS := [Color(0.55, 0.85, 1.0), Color(0.75, 0.55, 1.0), Color(0.3, 1.0, 0.75), Color(1.0, 0.55, 0.85),
		Color(0.5, 0.75, 1.0), Color(0.65, 1.0, 0.95), Color(1.0, 0.8, 0.45), Color(0.4, 0.8, 1.0), Color(0.9, 0.6, 1.0)]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var only: Array = ORDER
	var voxel := 0.075
	var cams: Array = []
	for a in args.slice(1):
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
		elif a.begins_with("voxel="):
			voxel = float(a.substr(6))
		else:
			cams.append(a)
	_setup_world()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ice_sculpture.gdshader")
	var x := 0.0
	for d in only:
		var t0 := Time.get_ticks_msec()
		var m: ArrayMesh = Kit.mesh(d, voxel)
		var tris: int = (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		print("%s: %d triangles in %.1fs" % [d, tris, (Time.get_ticks_msec() - t0) / 1000.0])
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = Vector3(x, 0, 0)
		root.add_child(mi)
		mi.set_instance_shader_parameter("glow", GLOWS[ORDER.find(d)])
		var l := OmniLight3D.new()
		l.light_color = GLOWS[ORDER.find(d)]
		l.light_energy = 1.5
		l.omni_range = 7.0
		l.position = Vector3(x, 0.4, 1.2)
		root.add_child(l)
		x += 6.0
	var cam := Camera3D.new()
	cam.far = 2000.0
	root.add_child(cam)
	cam.make_current()
	for i in 40:
		await process_frame
	for a in cams:
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var tg := parts[2].split(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 50.0
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(tg[0]), float(tg[1]), float(tg[2])), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()


func _setup_world() -> void:
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.55, 0.62, 0.75)
	gmat.roughness = 0.85
	pm.material = gmat
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.04, 0.12)
	sm.sky_horizon_color = Color(0.12, 0.35, 0.4)
	sm.ground_bottom_color = Color(0.02, 0.03, 0.06)
	sm.ground_horizon_color = Color(0.1, 0.2, 0.25)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	moon.light_energy = 0.35
	moon.light_color = Color(0.7, 0.8, 1.0)
	root.add_child(moon)
