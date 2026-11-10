extends SceneTree

# Look-dev for the Miyoshino GP's trees (MiyoshinoTrees.gd), after woodland_preview.gd. Run windowed:
#   Godot --path . --resolution 1400x850 -s res://scratch/miyoshino_trees_preview.gd -- <out_dir> [far=1] [grove=1]
#       [only=sakura,sugi] [atlas=1] [cache=<file>] [sun=<pitch>,<yaw>] name:x,y,z:tx,ty,tz[:fov] ...
# Row (default): every kind and variant at scale 1 along x (the order and x of each is printed), near meshes at z = 0,
# with far=1 the stand-ins at z = 40; a 2.9m person and a 2.2m RC car beside each. grove=1: about 120 cherries on a
# gentle slope (rising toward -z) with 200 sugi behind and above them, near and far meshes crossfading as in a level.
# atlas=1 saves the leaf atlas as <out_dir>/atlas.png. cache=<file> keeps the atlas between runs (delete it after
# changing the atlas's drawing). Prints each mesh's triangles and size.
const Trees = preload("res://MiyoshinoTrees.gd")

const VARIANTS := {"sakura": 3, "yamazakura": 2, "shidare": 2, "sugi": 2, "momiji": 2, "take": 2, "matsu": 2, "tsutsuji": 2}
const SLOPE := 0.2


func _tris(mesh: ArrayMesh) -> int:
	var tris := 0
	for s in range(mesh.get_surface_count()):
		tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return tris


func _box(size: Vector3, at: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	bm.material = m
	mi.mesh = bm
	mi.position = at
	root.add_child(mi)


func _scale_figures(at: Vector3) -> void:
	_box(Vector3(0.7, 2.2, 0.45), at + Vector3(0.0, 1.1, 0.0), Color(0.25, 0.35, 0.6))
	_box(Vector3(0.5, 0.7, 0.5), at + Vector3(0.0, 2.55, 0.0), Color(0.8, 0.62, 0.5))
	_box(Vector3(1.1, 0.5, 2.2), at + Vector3(1.6, 0.45, 0.0), Color(0.8, 0.15, 0.1))


func _ground_y(z: float) -> float:
	return maxf(-z, 0.0) * SLOPE


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var opt := {}
	for a in args.slice(1):
		if a.contains("=") and not a.contains(":"):
			opt[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var grove: bool = opt.has("grove")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.26, 0.48, 0.84)
	sm.sky_horizon_color = Color(0.72, 0.82, 0.92)
	sm.ground_bottom_color = Color(0.25, 0.3, 0.22)
	sm.ground_horizon_color = Color(0.6, 0.68, 0.7)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	if grove:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color(0.72, 0.80, 0.90)
		env.fog_depth_begin = 150.0
		env.fog_depth_end = 3500.0
		env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	var sp: PackedStringArray = String(opt.get("sun", "-42,35")).split(",")
	sun.rotation_degrees = Vector3(float(sp[0]), float(sp[1]), 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0 if grove else 200.0
	root.add_child(sun)
	# The ground: level for z > 0, rising toward -z in the grove.
	var gst := SurfaceTool.new()
	gst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zs: Array = [600.0, 0.0, -700.0] if grove else [600.0, -600.0]
	for i in range(zs.size() - 1):
		var z0: float = zs[i]
		var z1: float = zs[i + 1]
		var quad: Array = [Vector3(-700, _ground_y(z0) if grove else 0.0, z0), Vector3(700, _ground_y(z0) if grove else 0.0, z0),
				Vector3(700, _ground_y(z1) if grove else 0.0, z1), Vector3(-700, _ground_y(z1) if grove else 0.0, z1)]
		for idx in [0, 2, 1, 0, 3, 2]:
			var v: Vector3 = quad[idx]
			gst.set_normal(Vector3.UP)
			gst.set_uv(Vector2(v.x, v.z) / 10.0)
			gst.add_vertex(v)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = load("res://materials/grass.png")
	gmat.albedo_color = Color(0.7, 0.75, 0.65)
	gmat.roughness = 1.0
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gm := MeshInstance3D.new()
	gm.mesh = gst.commit()
	gm.material_override = gmat
	root.add_child(gm)

	var w = Trees.new()
	w.save_res = func(res: Resource, _n: String) -> Resource: return res
	var t0 := Time.get_ticks_msec()
	var cache: String = opt.get("cache", "")
	if cache != "" and FileAccess.file_exists(cache):
		var bytes := FileAccess.get_file_as_bytes(cache)
		w._miyo_atlas = ImageTexture.create_from_image(Image.create_from_data(Trees.MW, Trees.MW, true, Image.FORMAT_RGBA8, bytes))
	else:
		var img: Image = w.miyo_atlas_image()
		w._miyo_atlas = ImageTexture.create_from_image(img)
		if cache != "":
			var fa := FileAccess.open(cache, FileAccess.WRITE)
			fa.store_buffer(img.get_data())
			fa.close()
		print("atlas drawn in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if opt.has("atlas"):
		var ai: Image = (w._miyo_atlas as Texture2D).get_image()
		ai.clear_mipmaps()
		ai.save_png("%s/atlas.png" % out)
		# The same over mid grey, alpha tested: what the cards show.
		var flat := Image.create(1024, 1024, false, Image.FORMAT_RGB8)
		for y in range(1024):
			for x in range(1024):
				var c: Color = ai.get_pixel(x * 2, y * 2)
				flat.set_pixel(x, y, c if c.a >= 0.5 else Color(0.35, 0.5, 0.75))
		flat.save_png("%s/atlas_cut.png" % out)
		print("ATLAS saved")
	t0 = Time.get_ticks_msec()
	var only: PackedStringArray = String(opt.get("only", "")).split(",", false)
	var mode_near: int = 1 if grove else 0
	var mode_far: int = 2 if grove else 0
	var leaf_near: ShaderMaterial = w.miyo_leaf_material(mode_near, 0.12, 18.0)
	var leaf_far: ShaderMaterial = w.miyo_leaf_material(mode_far, 0.12, 18.0)
	var meshes := {}
	var x := 0.0
	for kind in Trees.MIYO_KINDS:
		if not only.is_empty() and not only.has(kind):
			continue
		var bn: ShaderMaterial = w.bark_material(w.miyo_bark_key(kind), mode_near)
		var bf: ShaderMaterial = w.bark_material(w.miyo_bark_key(kind), mode_far)
		for v in range(int(VARIANTS[kind])):
			var near: ArrayMesh = w.miyo_mesh(kind, v, 0, bn, leaf_near)
			var far: ArrayMesh = w.miyo_mesh(kind, v, 1, bf, leaf_far)
			meshes["%s%d" % [kind, v]] = [near, far]
			var bb: AABB = near.get_aabb()
			var fb: AABB = far.get_aabb()
			var half: float = maxf(bb.size.x, bb.size.z) * 0.5 + 1.5
			x += half
			print("%s v%d  x=%.0f  near %d tris, far %d tris;  height %.1f (far %.1f), across %.1f x %.1f (far %.1f x %.1f)" % [kind, v, x, _tris(near), _tris(far),
					bb.end.y, fb.end.y, bb.size.x, bb.size.z, fb.size.x, fb.size.z])
			if not grove:
				var mi := MeshInstance3D.new()
				mi.mesh = near
				mi.position = Vector3(x, 0.0, 0.0)
				root.add_child(mi)
				_scale_figures(Vector3(x - 1.0, 0.0, half + 1.0))
				if opt.has("far"):
					var mf := MeshInstance3D.new()
					mf.mesh = far
					mf.position = Vector3(x, 0.0, 40.0)
					root.add_child(mf)
			x += half
	print("built in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if grove:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var lists := {}
		var add := func(key: String, px: float, pz: float, sc: float) -> void:
			if not meshes.has(key):
				return
			if not lists.has(key):
				lists[key] = []
			lists[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.08), sc)), Vector3(px, _ground_y(pz) - 0.2, pz)))
		for i in range(120):
			var r: float = rng.randf()
			var key := "sakura%d" % (i % 3)
			if r < 0.2:
				key = "yamazakura%d" % (i % 2)
			elif r < 0.27:
				key = "shidare%d" % (i % 2)
			add.call(key, rng.randf_range(-150.0, 150.0), rng.randf_range(-150.0, -14.0), rng.randf_range(1.0, 1.3))
		for i in range(200):
			add.call("sugi%d" % (1 if rng.randf() < 0.25 else 0), rng.randf_range(-190.0, 190.0), rng.randf_range(-290.0, -150.0), rng.randf_range(0.9, 1.25))
		for i in range(14):
			add.call("momiji%d" % (i % 2), rng.randf_range(-60.0, 60.0), rng.randf_range(-12.0, -4.0), 1.1)
			add.call("take%d" % (i % 2), rng.randf_range(-190.0, -150.0), rng.randf_range(-140.0, -20.0), 1.1)
		for key in lists.keys():
			for lod in range(2):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = meshes[key][lod]
				mm.instance_count = (lists[key] as Array).size()
				for i in range(mm.instance_count):
					mm.set_instance_transform(i, lists[key][i])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				if lod == 1:
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mmi)
		_scale_figures(Vector3(0.0, 0.0, 6.0))
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 4000.0
	root.add_child(cam)
	cam.make_current()
	for i in 50:
		await process_frame
	for a in args.slice(1):
		var parts := a.split(":")
		if parts.size() < 3:
			continue
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 60.0
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()
