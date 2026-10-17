extends SceneTree

# Look-dev for the Msitu Falls ranger post (RangerPostBuilder.gd) on flat ground, so a change to
# the buildings or their shaders shows in seconds, without generating the level. The camera
# positions are in the level's coordinates (the post is round (-121, -34), its ground at y = 3.95).
# Run windowed:
#   Godot --path . --resolution 1400x800 -s res://scratch/ranger_post_preview.gd -- <out_dir> name:x,y,z:tx,ty,tz ...
const Builder = preload("res://RangerPostBuilder.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var pad_y := 3.95
	# Ground: a flat yard of red earth.
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.46, 0.27, 0.17)
	gmat.roughness = 1.0
	pm.material = gmat
	gm.position = Vector3(-121, pad_y, -34)
	root.add_child(gm)
	# Sky and sun like the level's.
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	sm.set_shader_parameter("sky_top", Color(0.16, 0.40, 0.78))
	sm.set_shader_parameter("sky_horizon", Color(0.74, 0.84, 0.84))
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.86, 0.94, 0.86)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 62.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 240.0
	root.add_child(sun)
	# The post.
	var b = Builder.new()
	b.build_all(Vector2(-121.0, -34.0), pad_y, func(x: float, z: float) -> float: return pad_y)
	var mesh: ArrayMesh = b.commit(Builder.make_materials())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	for l in b.labels:
		var lab := Label3D.new()
		lab.text = l["text"]
		lab.font_size = l["font_size"]
		lab.pixel_size = l["pixel_size"]
		lab.outline_size = 4
		lab.modulate = l["color"]
		lab.outline_modulate = Color(0.05, 0.1, 0.06)
		lab.transform = l["xf"]
		root.add_child(lab)
	print("surfaces ", mesh.get_surface_count(), " colliders ", b.colliders.size(), " footprints ", b.footprints.size())
	var tris := 0
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	print("triangles ", tris)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 2000.0
	root.add_child(cam)
	cam.make_current()
	await process_frame
	for a in args.slice(1):
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()
