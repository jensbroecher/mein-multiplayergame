extends SceneTree

# Look-dev for Frostfall Gorge's spruces on a snowy meadow, without generating the level. Builds the
# generator's own _spruce_mesh (near variants 0 and 1 in front, far stand-ins behind). Run windowed:
#   Godot --path . --resolution 1400x800 -s res://scratch/gorge_tree_preview.gd -- <out_dir> name:x,y,z:tx,ty,tz ...
const Gen = preload("res://regenerate_frostfall_gorge.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.80, 0.84, 0.90)
	gmat.roughness = 0.9
	pm.material = gmat
	gm.mesh = pm
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.84)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.74)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34.0, -142.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	root.add_child(sun)
	var g = Gen.new()
	var t0 := Time.get_ticks_msec()
	var stats := ""
	var x := -12.0
	for lod in range(2):
		for v in range(2):
			var mesh: ArrayMesh = g._spruce_mesh(v, lod)
			mesh = g._spruce_lod(mesh, 0)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.position = Vector3(x, 0, -30.0 * lod)
			root.add_child(mi)
			var tris := 0
			for sf in range(mesh.get_surface_count()):
				var arr: Array = mesh.surface_get_arrays(sf)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			stats += "v%d lod%d: %d tris  " % [v, lod, tris]
			x += 12.0
	print(stats)
	print("built in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 2000.0
	root.add_child(cam)
	cam.make_current()
	for i in 60:
		await process_frame
	for a in args.slice(1):
		var parts := a.split(":")
		if parts.size() < 3:
			continue
		var p := parts[1].split(",")
		var tg := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(tg[0]), float(tg[1]), float(tg[2])), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()
