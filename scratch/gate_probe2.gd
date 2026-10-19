extends SceneTree
func _initialize() -> void:
	var level: Node3D = load("res://levels/MountainLevel.tscn").instantiate()
	root.add_child(level)
	level.race_state = level.RaceState.RACING
	await level.wait_for_collisions()
	for i in 30:
		await physics_frame
	var g: Node3D = level.get_node("Checkpoints/Halfway4")
	var space := level.get_world_3d().direct_space_state
	for x in [-6.85, 0.0, 6.85, 12.0, 20.0]:
		for z in [-4.0, 0.0, 4.0]:
			var q := PhysicsRayQueryParameters3D.create(g.to_global(Vector3(x, 30, z)), g.to_global(Vector3(x, -5, z)))
			q.hit_back_faces = true
			var out := ""
			var ex: Array[RID] = []
			for b in g.find_children("*", "StaticBody3D", true, false):
				ex.append(b.get_rid())
			for n in 6:
				q.exclude = ex
				var h := space.intersect_ray(q)
				if h.is_empty(): break
				out += " [%s y=%.2f n=%.2f]" % [h["collider"].get_parent().name, g.to_local(h["position"]).y, (g.global_basis.inverse() * h["normal"]).y]
				ex.append(h["rid"])
			print("PROBE x=", x, " z=", z, out)
	quit()
