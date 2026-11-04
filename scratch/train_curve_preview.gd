extends SceneTree
## Renders a train held on a tight curve (Train.gd on a path: 80m straight, a quarter circle of radius `r`, 80m
## straight), to see that the bogies stand on the rails and the bodies swing between them. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/train_curve_preview.gd -- <dir> [r=60] [head=190]
##       [consist=ploco,coach,coach,~ploco] name:x,y,z:tx,ty,tz ...
## The curve turns left from +z... it starts at the origin heading -z and bends toward -x round (-r, 0, -80).

const FreightKit = preload("res://FreightKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/train_curve"
	DirAccess.make_dir_recursive_absolute(dir)
	var r := 60.0
	var head := 190.0
	var consist := PackedStringArray(["ploco", "coach", "coach", "~ploco"])
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("r="): r = float(a.substr(2))
		elif a.begins_with("head="): head = float(a.substr(5))
		elif a.begins_with("consist="): consist = PackedStringArray(a.substr(8).split(","))
		else: shots.append(a)
	var root3 := Node3D.new()
	root.add_child(root3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.7, 0.85)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.6
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.5, 0.42)
	ground.material_override = gm
	ground.position.y = -0.6
	root3.add_child(ground)
	# The path: rail tops at y 0.
	var pts: Array = []
	for k in range(0, 81, 2):
		pts.append(Vector3(0, 0, -float(k)))
	for k in range(1, 48):
		var a: float = PI * 0.5 * float(k) / 47.0
		pts.append(Vector3(-r + r * cos(a), 0, -80.0 - r * sin(a)))
	for k in range(1, 41):
		pts.append(Vector3(-r - float(k) * 2.0, 0, -80.0 - r))
	var track := MeshInstance3D.new()
	var bed: Array = []
	for p in pts:
		bed.append(true)
	track.mesh = FreightKit.track_piece(pts, bed, 3)
	root3.add_child(track)
	var curve := Curve3D.new()
	for p in pts:
		curve.add_point(p)
	var train := Node3D.new()
	train.set_script(load("res://Train.gd"))
	train.set("path", curve)
	train.set("consist", consist)
	train.set("speed", 10.0)
	train.set("period", 1000.0)
	train.set("sounds", false)
	train.set("kills", false)
	train.set("clock_override", head / 10.0)
	root3.add_child(train)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.current = true
	for i in 40:
		await process_frame
	for sh in shots:
		var p: PackedStringArray = String(sh).split(":")
		var a2 := p[1].split(",")
		var b2 := p[2].split(",")
		cam.position = Vector3(float(a2[0]), float(a2[1]), float(a2[2]))
		cam.look_at(Vector3(float(b2[0]), float(b2[1]), float(b2[2])), Vector3.UP if absf(cam.position.y - float(b2[1])) < 50.0 else Vector3(0, 0, -1))
		cam.fov = float(p[3]) if p.size() > 3 else 50.0
		for i in 8:
			await process_frame
		root.get_texture().get_image().save_png(dir.path_join(p[0] + ".png"))
		print("SHOT ", p[0])
	quit(0)
