extends SceneTree
## Renders and inspects the two houses in CanyonChasmLevel.tscn (LargeHouse and House)
## from multiple angles and in-level views.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "."

	var houses := [
		["large_house", "res://models/desert/2f1728e226824507fc3188405c2c7935.fbx", 45.0],
		["house", "res://models/desert/49ac41a0567226438249fc402b0d629c.fbx", 35.0],
	]

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

	for h in houses:
		var label: String = h[0]
		var path: String = h[1]
		var scl: float = h[2]
		if not ResourceLoader.exists(path):
			print("Missing: ", path)
			continue
		var ps: PackedScene = load(path)
		var inst: Node3D = ps.instantiate()
		inst.scale = Vector3.ONE * scl
		w.add_child(inst)
		for i in 4:
			await process_frame

		var box := AABB()
		var first := true
		var total_tris := 0
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
			if mi.mesh:
				total_tris += mi.mesh.get_faces().size() / 3
				print("%s mesh node=%s xform=%s local_aabb=%s world_aabb=%s tris=%d surfaces=%d" % [
					label, mi.name, mi.transform, mi.get_aabb(), b, total_tris, mi.mesh.get_surface_count()
				])
		print("%s total world AABB (at scale %.1f): pos=%s size=%s end=%s center=%s tris=%d" % [
			label, scl, box.position, box.size, box.end, box.get_center(), total_tris
		])

		var c := box.get_center()
		var r := box.size.length()
		var views := [
			["front_z", Vector3(0.0, 0.25, 1.0)],
			["back_negz", Vector3(0.0, 0.25, -1.0)],
			["right_x", Vector3(1.0, 0.25, 0.0)],
			["left_negx", Vector3(-1.0, 0.25, 0.0)],
			["three_q1", Vector3(0.75, 0.42, 0.75)],
			["three_q2", Vector3(-0.75, 0.42, -0.75)],
		]
		for v in views:
			cam.position = c + (v[1] as Vector3).normalized() * r * 0.78
			cam.look_at(c)
			for i in 20:
				await process_frame
			var img := root.get_texture().get_image()
			img.save_png("%s/%s_%s.png" % [out_dir, label, v[0]])

		inst.queue_free()
		for i in 3:
			await process_frame

	quit()
