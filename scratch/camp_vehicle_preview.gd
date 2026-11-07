extends SceneTree
## Renders CampKit's vehicles side by side in memory (life size, noses toward -z, 4m apart along x), to compare kinds
## and variants (the camp's motorhome with its awning out against the Autobahn's motorhome_road). Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/camp_vehicle_preview.gd -- <dir>
##       [kinds=motorhome:0,motorhome_road:0,van:0,suv:0] name:x,y,z:tx,ty,tz ...

const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://camp_vehicles"
	DirAccess.make_dir_recursive_absolute(dir)
	var kinds: Array = ["motorhome:0", "motorhome_road:0", "van:0", "suv:0"]
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("kinds="):
			kinds = a.substr(6).split(",")
		elif a.contains(":"):
			shots.append(a)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.72, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor_mi.mesh = pm
	root.add_child(floor_mi)
	var pk := PropKit.new()
	var mats := {}
	pk.material_for = func(key: String) -> Material:
		if not mats.has(key):
			mats[key] = CampKit.make_material(key)
		return mats[key]
	var camp := CampKit.new(pk)
	for i in kinds.size():
		var parts: PackedStringArray = String(kinds[i]).split(":")
		var kit := {}
		pk.set_frame(Transform3D(Basis(), Vector3(float(i) * 4.0, 0, 0)))
		camp.vehicle(kit, parts[0], Color(0.94, 0.94, 0.92), int(parts[1]) if parts.size() > 1 else 0)
		var mi := MeshInstance3D.new()
		mi.mesh = pk.commit(kit)
		root.add_child(mi)
	if shots.is_empty():
		shots = ["side:6,2.5,9:6,1.4,0", "camp:6,2.5,-9:6,1.4,0"]
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	for f in 40:
		await process_frame
	for sh in shots:
		var p: PackedStringArray = String(sh).split(":")
		var a: PackedStringArray = p[1].split(",")
		var b: PackedStringArray = p[2].split(",")
		cam.look_at_from_position(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3(float(b[0]), float(b[1]), float(b[2])))
		for f in 4:
			await process_frame
		get_root().get_texture().get_image().save_png(dir.path_join(p[0] + ".png"))
		print("SHOT ", p[0])
	quit()
