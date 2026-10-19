extends SceneTree

# Look-dev for the Lakeside Course's trees (WoodlandBuilder.gd) on a flat meadow, so a change to the
# trees shows in seconds without generating the level. A row of every kind and shape, near meshes in
# front (z = 0), far stand-ins behind (z = 40). Run windowed:
#   Godot --path . --resolution 1400x800 -s res://scratch/woodland_preview.gd -- <out_dir> [far=1] name:x,y,z:tx,ty,tz ...
const Woodland = preload("res://WoodlandBuilder.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = load("res://materials/grass.png")
	gmat.uv1_scale = Vector3(60, 60, 1)
	gmat.albedo_color = Color(0.75, 0.75, 0.75)
	gmat.roughness = 1.0
	pm.material = gmat
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.50, 0.82)
	sm.sky_horizon_color = Color(0.70, 0.80, 0.90)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	root.add_child(sun)
	var w = Woodland.new()
	w.save_res = func(res: Resource, _n: String) -> Resource: return res
	var t0 := Time.get_ticks_msec()
	var bark := {}
	for kind in ["oak", "lime", "birch", "spruce", "hazel"]:
		bark[kind] = [w.bark_material(kind, 0), w.bark_material(kind, 0)]
	var leaf: ShaderMaterial = w.leaf_material(0, 0.12, 20.0)
	var x := -60.0
	var stats := ""
	for kind in ["oak", "lime", "birch", "spruce", "hazel"]:
		for v in range(2):
			for lod in range(2):
				var mesh: ArrayMesh
				if kind == "spruce":
					mesh = w.spruce_mesh(v, lod, bark[kind][0], leaf)
				elif kind == "hazel":
					if lod == 1:
						continue
					mesh = w.shrub_mesh(v, bark[kind][0], leaf)
				else:
					mesh = w.broadleaf_mesh(kind, v, lod, bark[kind][0], leaf)
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.position = Vector3(x, 0, 40.0 * lod)
				root.add_child(mi)
				var tris := 0
				for s in range(mesh.get_surface_count()):
					tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				stats += "%s%d%s: %d tris  " % [kind, v, "far" if lod == 1 else "", tris]
			x += 13.0
	print(stats)
	print("built in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 2000.0
	root.add_child(cam)
	cam.make_current()
	for i in 45:
		await process_frame
	for a in args.slice(1):
		var parts := a.split(":")
		if parts.size() < 3:
			continue
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
