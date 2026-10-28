extends SceneTree
## -s windowed: -- <dir>  renders Canyon Chasm's two CSG-baked houses (LargeHouse.tscn and AdobeHouse.tscn)
## from multiple angles for visual inspection.

const HOUSES := [
	["csg_large_house", "res://LargeHouse.tscn"],
	["csg_adobe_house", "res://AdobeHouse.tscn"],
]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "."

	var w := Node3D.new()
	root.add_child(w)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.76, 0.90)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.76, 0.75, 0.78)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	w.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.shadow_enabled = true
	w.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_energy = 0.35
	w.add_child(fill)

	var cam := Camera3D.new()
	cam.fov = 50.0
	w.add_child(cam)
	cam.current = true

	for h in HOUSES:
		var label: String = h[0]
		var path: String = h[1]
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		w.add_child(inst)
		for i in 4:
			await process_frame

		var box := AABB()
		var first := true
		for mi in inst.find_children("*", "VisualInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("%s aabb=%s" % [label, box])

		var c := box.get_center() + Vector3(0, 1.25, 0) # compensate for -2.5m SINK
		var r := box.size.length()
		var views := [
			["front_z", Vector3(0.0, 0.25, 1.0)],
			["back_negz", Vector3(0.0, 0.25, -1.0)],
			["three_q1", Vector3(0.75, 0.42, 0.75)],
			["three_q2", Vector3(-0.75, 0.42, -0.75)],
		]
		for v in views:
			cam.position = c + (v[1] as Vector3).normalized() * r * 0.76
			cam.look_at(c)
			for i in 30:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, label, v[0]])

		inst.queue_free()
		for i in 3:
			await process_frame

	quit()
