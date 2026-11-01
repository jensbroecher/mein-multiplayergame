extends SceneTree
## Options: model=<res path> anim=<name> copies=N centre=x,y,z. Renders a BirdFlock from above-behind and beside: -s, windowed, -- <dir> [yaw=0] [scale=6]
func _init() -> void:
	var dir := "user://bird_shots"
	var yaw := 0.0
	var sc := 6.0
	var model := ""
	var anim := ""
	var tex := ""
	var copies := 1
	var centre := Vector3(0, 0, 0.44)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("yaw="): yaw = float(a.substr(4))
		elif a.begins_with("scale="): sc = float(a.substr(6))
		elif a.begins_with("model="): model = a.substr(6)
		elif a.begins_with("texture="): tex = a.substr(8)
		elif a.begins_with("anim="): anim = a.substr(5)
		elif a.begins_with("copies="): copies = int(a.substr(7))
		elif a.begins_with("centre="): centre = Vector3(float(a.split("=")[1].split(",")[0]), float(a.split("=")[1].split(",")[1]), float(a.split("=")[1].split(",")[2]))
		else: dir = a
	DirAccess.make_dir_recursive_absolute(dir)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.62, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); root.add_child(sun)
	var flock: Node3D = load("res://BirdFlock.gd").new()
	if model != "":
		flock.model = load(model)
		flock.drop_nodes = PackedStringArray(["Camera", "Light"])
	if tex != "": flock.albedo_texture = load(tex)
	flock.animation_name = anim; flock.copies = copies; flock.model_centre = centre
	flock.radius = 40.0; flock.bird_scale = sc; flock.model_yaw_deg = yaw
	root.add_child(flock)
	var cam := Camera3D.new(); root.add_child(cam)
	cam.far = 500
	for f in 20: await process_frame
	var views := {
		"top": [Vector3(0, 110, 0.1), Vector3.ZERO],
		"side": [Vector3(0, 8, 90), Vector3(0, 0, 40)],
	}
	for k in views:
		for i in 3:
			var fp: Node3D = flock.get_node("FlockPivot") if flock.has_node("FlockPivot") else flock.get_child(0, true)
			var target: Vector3 = fp.global_position
			if k == "top":
				cam.global_position = target + Vector3(0, 30, 0.1)
			else:
				cam.global_position = target + Vector3(25, 6, 25)
			cam.look_at(target, Vector3.UP if k == "side" else Vector3(0, 0, -1))
			print("HEADING ", k, i, " pivot -z = ", -fp.global_basis.z)
			for f in 12 + i * 5: await process_frame
			root.get_texture().get_image().save_png("%s/%s_%d.png" % [dir, k, i])
	print("SHOTS ", ProjectSettings.globalize_path(dir))
	quit()
