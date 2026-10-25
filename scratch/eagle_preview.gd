extends Node

# Renders the canyon's eagle (Eagle.gd on its FBX) standing still in an empty sky, its wings posed
# through a beat: frames at phases 0, 0.1 .. 0.9 (the downstroke takes 0.0-0.4), the glide and the
# stoop. Windowed: Godot --path . --resolution 1200x800 res://scratch/eagle_preview.tscn -- <dir> [yaw=0] [pitch=10]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var yaw := 0.0
	var pitch := 12.0
	for a in args.slice(1):
		if a.begins_with("yaw="):
			yaw = float(a.substr(4))
		elif a.begins_with("pitch="):
			pitch = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -50, 0)
	add_child(sun)
	var eagle: Node3D = (load("res://models/animals/20260717033727_7db23447.fbx") as PackedScene).instantiate()
	eagle.set_script(load("res://Eagle.gd"))
	eagle.name = "Eagle"
	eagle.transform = Transform3D(Basis().scaled(Vector3.ONE * 10.0), Vector3.ZERO)
	add_child(eagle)
	eagle.set_physics_process(false)
	eagle.global_transform = Transform3D(Basis().scaled(Vector3.ONE * 10.0), Vector3.ZERO)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40.0
	# Frame the bird by its meshes' bounds (the FBX's units are not metres).
	var box := AABB()
	var first := true
	for mi in eagle.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	print("EAGLE bounds ", box)
	print("WINGS side ", eagle.get("_wing_side"), " rest ", eagle.get("_wing_rest"), " pivots ", (eagle.get("_wing_pivots") as Array).map(func(p): return p.position))
	var dir := Vector3(sin(deg_to_rad(yaw)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw))).normalized()
	cam.position = box.get_center() + dir * box.size.length() * 1.9
	cam.look_at(box.get_center(), Vector3.UP)
	cam.make_current()
	get_window().size = Vector2i(1200, 800)
	for i in 40:
		await get_tree().process_frame
	var poses: Array = []
	for k in range(10):
		var ph: float = float(k) / 10.0
		poses.append(["beat_%02d" % k, eagle.stroke_angle(ph), eagle.stroke_twist(ph)])
	poses.append(["glide", eagle.glide_dihedral_deg, 0.0])
	poses.append(["stoop", eagle.stoop_deg, 0.0])
	for p in poses:
		eagle.set_wing_pose(p[1], p[2])
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, p[0]])
		print("SHOT ", p[0])
	get_tree().quit()
