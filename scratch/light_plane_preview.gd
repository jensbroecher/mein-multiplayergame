extends SceneTree
## Renders LightPlane.gd's aeroplane standing still at the origin (scale 1.6, nose toward -z) from named cameras. Windowed:
##   Godot --path . --resolution 1400x900 -s res://scratch/light_plane_preview.gd -- <dir> name:x,y,z:tx,ty,tz[:fov] ...

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.72, 0.88)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.64, 0.68)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	root.add_child(sun)
	var plane := Node3D.new()
	plane.set_script(load("res://LightPlane.gd"))
	plane.set("radii", Vector2(500, 400))
	root.add_child(plane)
	# Its _ready runs on the first frame (and turns its flight on): freeze it after that.
	await process_frame
	plane.set_process(false)
	plane.global_transform = Transform3D()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	for f in 30:
		await process_frame
	for sh in args.slice(1):
		var p: PackedStringArray = String(sh).split(":")
		var a: PackedStringArray = p[1].split(",")
		var b: PackedStringArray = p[2].split(",")
		cam.fov = float(p[3]) if p.size() > 3 else 40.0
		cam.look_at_from_position(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3(float(b[0]), float(b[1]), float(b[2])))
		for f in 4:
			await process_frame
		get_root().get_texture().get_image().save_png(dir.path_join(p[0] + ".png"))
		print("SHOT ", p[0])
	quit()
