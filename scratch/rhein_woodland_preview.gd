extends SceneTree

# Look-dev for Rheinufer's trees (WoodlandBuilder.gd's pollard, poplar and plane, with an oak and a lime beside them for
# comparison) on a flat meadow: near meshes in a row at z = 0 (two shapes each), far stand-ins behind at z = 40. A 2.2m RC
# car box and a 2.9m person stand-in at the front for scale. Run windowed:
#   Godot --path . --resolution 1400x850 -s res://scratch/rhein_woodland_preview.gd -- <out_dir> [scale=1.0] name:x,y,z:tx,ty,tz[:fov] ...
# Prints each mesh's triangles. Trees are built at life size; `scale` grows them (the stage uses 1.0-1.35 like Kronburg's).
const Woodland = preload("res://WoodlandBuilder.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var sc := 1.0
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("scale="):
			sc = float(a.substr(6))
		else:
			shots.append(a)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = load("res://materials/grass.png")
	gmat.uv1_scale = Vector3(80, 80, 1)
	gmat.albedo_color = Color(0.75, 0.75, 0.75)
	gmat.roughness = 1.0
	pm.material = gmat
	root.add_child(gm)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.50, 0.82)
	sm.sky_horizon_color = Color(0.74, 0.80, 0.88)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	# A low early-evening sun from the west-south-west, as on the stage.
	sun.rotation_degrees = Vector3(-28.0, 250.0, 0.0)
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	root.add_child(sun)
	var w = Woodland.new()
	w.save_res = func(res: Resource, _n: String) -> Resource: return res
	var t0 := Time.get_ticks_msec()
	var leaf: ShaderMaterial = w.leaf_material(0, 0.12, 20.0)
	var rleaf: ShaderMaterial = w.rhein_leaf_material(0, 0.12, 20.0)
	var x := -60.0
	var stats := ""
	for kind in ["pollard", "poplar", "plane", "oak", "lime"]:
		var bark: ShaderMaterial = w.bark_material(kind, 0)
		var lm: ShaderMaterial = rleaf if Woodland.uses_rhein_atlas(kind) else leaf
		for v in range(2):
			for lod in range(2):
				var mesh: ArrayMesh = w.tree_mesh(kind, v, lod, bark, lm)
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.position = Vector3(x, 0, 40.0 * lod)
				mi.scale = Vector3.ONE * sc
				root.add_child(mi)
				var tris := 0
				for s in range(mesh.get_surface_count()):
					tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				stats += "%s%d%s: %d tris, aabb %s\n" % [kind, v, "far" if lod == 1 else "", tris, mesh.get_aabb().size]
			x += 13.0 if kind == "pollard" else (10.0 if kind == "poplar" else 18.0)
	print(stats)
	print("built in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# Scale figures at the front.
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.7, 2.2)
	car.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.1, 0.08)
	bm.material = cm
	car.position = Vector3(-56, 0.35, 8)
	root.add_child(car)
	var man := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 2.9
	man.mesh = cap
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.15, 0.3, 0.85)
	cap.material = mm
	man.position = Vector3(-52, 1.45, 8)
	root.add_child(man)
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 2000.0
	root.add_child(cam)
	cam.make_current()
	for i in 45:
		await process_frame
	for a in shots:
		var parts := (a as String).split(":")
		if parts.size() < 3:
			continue
		var p := parts[1].split_floats(",")
		var t := parts[2].split_floats(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 60.0
		cam.global_position = Vector3(p[0], p[1], p[2])
		cam.look_at(Vector3(t[0], t[1], t[2]), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()
