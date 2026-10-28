extends SceneTree
# -s headless: loads Canyon Chasm and reports its ArrowSign (ArrowSign.tscn, the baked ArrowSignCSG.gd mesh):
# its mesh, world bounds, and the collider Level.gd's collision builder gave it (the node is in the
# collision_trimesh group).
func _initialize():
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	for i in 5: await process_frame
	await physics_frame
	var sign: Node3D = lvl.get_node("ArrowSign")
	var mi: MeshInstance3D = sign.find_children("*", "MeshInstance3D", true, false)[0]
	print("mesh=%s bounds=%s" % [mi.mesh.resource_path, mi.global_transform * mi.mesh.get_aabb()])
	var found := 0
	for body in lvl.find_children("Col_*ArrowSign*", "StaticBody3D", true, false):
		for cs in body.find_children("*", "CollisionShape3D", true, false):
			found += 1
			print("collider %s: %s, %d faces" % [body.name, cs.shape.get_class(),
				cs.shape.get_faces().size() / 3 if cs.shape is ConcavePolygonShape3D else -1])
	print("colliders: ", found)
	quit()
