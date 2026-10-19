extends SceneTree
# Prints each checkpoint gate's truss height after it has settled, and what shortened it. -- <level.tscn>
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node3D = load(args[0]).instantiate()
	root.add_child(level)
	level.race_state = level.RaceState.RACING
	await level.wait_for_collisions()
	for i in 30:
		await physics_frame
	var space := level.get_world_3d().direct_space_state
	for g in level.get_node("Checkpoints").get_children():
		print("GATE ", g.name, " truss_top=", g._truss_top)
		if g._truss_top < 7.9:
			for dy in [[4.0,-2.0],[12.0,-12.0]]:
				var q2 := PhysicsRayQueryParameters3D.create(g.to_global(Vector3(0.03, dy[0], 0.02)), g.to_global(Vector3(0.03, dy[1], 0.02)))
				var ex2: Array[RID] = []
				for b in g.find_children("*", "StaticBody3D", true, false):
					ex2.append(b.get_rid())
				q2.exclude = ex2
				var h2 := space.intersect_ray(q2)
				if not h2.is_empty():
					print("  down ", dy, " hit ", h2["collider"].get_path(), " y ", g.to_local(h2["position"]).y)
			for x in [-6.85, 0.0, 6.85]:
				var q := PhysicsRayQueryParameters3D.create(g.to_global(Vector3(x, 3, 0)), g.to_global(Vector3(x, 9, 0)))
				q.hit_back_faces = false
				var ex: Array[RID] = []
				for b in g.find_children("*", "StaticBody3D", true, false):
					ex.append(b.get_rid())
				q.exclude = ex
				var h := space.intersect_ray(q)
				if not h.is_empty():
					print("  x=", x, " hit ", h["collider"].get_path(), " at height ", g.to_local(h["position"]).y)
	quit()
