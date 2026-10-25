extends SceneTree

# Contact sheet of the imported models in a folder: each one alone on a grey floor, framed to its own
# size, with its index and name in the corner, tiled 6 across into one image. Run windowed:
#   Godot --path . --resolution 1200x900 -s res://scratch/asset_sheet.gd -- <out.png> res://models/plants [res://models/desert ...]
#       [only=<file name prefix>] [cell=300]

const COLS := 6
var CELL := 300

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var paths: Array[String] = []
	var only := ""
	for a in args.slice(1):
		if a.begins_with("only="):
			only = a.substr(5)
		elif a.begins_with("cell="):
			CELL = int(a.substr(5))
	for dir in args.slice(1):
		if dir.contains("="):
			continue
		for f in DirAccess.get_files_at(dir):
			if (f.ends_with(".fbx") or f.ends_with(".glb")) and f.begins_with(only):
				paths.append(dir.path_join(f))
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	vp.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(50, 50)
	floor_mi.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.42, 0.40, 0.38)
	pm.material = fmat
	vp.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 35.0
	vp.add_child(cam)
	cam.make_current()
	await process_frame
	var cols: int = mini(COLS, paths.size())
	var sheet := Image.create(CELL * cols, CELL * int(ceil(paths.size() / float(cols))), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	var i := 0
	for path in paths:
		var ps: PackedScene = load(path)
		if ps == null:
			i += 1
			continue
		var model: Node3D = ps.instantiate()
		vp.add_child(model)
		var aabb := AABB()
		var first := true
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mi.global_transform * mi.mesh.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		var s: float = 2.0 / maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		model.scale = Vector3.ONE * s
		model.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
		var lbl := Label3D.new()
		lbl.text = "%d %s" % [i, path.get_file().substr(0, 8)]
		lbl.pixel_size = 0.0035
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = Color(1, 1, 0.6)
		lbl.outline_size = 8
		lbl.position = Vector3(-0.9, 2.15, 0.0)
		vp.add_child(lbl)
		cam.position = Vector3(2.6, 2.0, 3.6)
		cam.look_at(Vector3(0, 0.75, 0), Vector3.UP)
		for f in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i((i % cols) * CELL, (i / cols) * CELL))
		print("%d %s" % [i, path])
		model.queue_free()
		lbl.queue_free()
		i += 1
	sheet.save_png(out)
	print("SHEET ", out)
	quit()
