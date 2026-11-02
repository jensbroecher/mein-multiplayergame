extends SceneTree
# Renders low-poly models side on, each fitted to the frame, with a red ball at the model's +z end and a
# blue one at +x: to read which way a boat's bow points and how a prop lies.
# Godot --path . --resolution 1200x700 -s res://scratch/lowpoly_preview.gd -- <dir> "res://models/X.glb" ...
# (windowed). Each model is shot from +x (side) and from above-front.
var _dir := ""
var _paths: Array = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0]
	_paths = args.slice(1)
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _run() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	for k in _paths.size():
		var s: Node3D = (load(_paths[k]) as PackedScene).instantiate()
		root.add_child(s)
		var box := AABB()
		var first := true
		for m in s.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var b: AABB = s.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var r := box.size.length() * 0.5
		var c := box.get_center()
		for end in [[Vector3(0, 0, box.end.z), Color.RED], [Vector3(box.end.x, 0, 0), Color.BLUE]]:
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = r * 0.04
			sm.height = r * 0.08
			ball.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = end[1]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ball.material_override = mat
			ball.position = Vector3(end[0].x, c.y, end[0].z) if end[0].x == 0.0 else Vector3(end[0].x, c.y, c.z)
			s.add_child(ball)
		var views := {"side": c + Vector3(r * 2.2, r * 0.3, 0), "top": c + Vector3(r * 0.8, r * 1.8, r * 1.0)}
		for v in views:
			cam.position = views[v]
			cam.look_at(c, Vector3.UP if v == "side" else Vector3.UP)
			cam.fov = 40.0
			for i in 40:
				await process_frame
			var img := root.get_texture().get_image()
			var out := _dir.path_join("%d_%s.png" % [k, v])
			img.save_png(out)
			print("SHOT ", out, " ", _paths[k], " box=", box)
		s.queue_free()
		await process_frame
	quit()
