extends SceneTree
# -s headless: loads Canyon Chasm and reports its LargeHouse (LargeHouse.tscn, baked LargeHouseCSG.gd)
# and House (AdobeHouse.tscn, baked AdobeHouseCSG.gd): their meshes, world bounds, and the trimesh
# colliders Level.gd's collision builder gave them (both nodes are in the collision_trimesh group).
func _initialize():
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	for i in 5: await process_frame
	await physics_frame
	for node_name in ["LargeHouse", "House"]:
		var n: Node3D = lvl.get_node(node_name)
		var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
		print("%s: mesh=%s local_aabb=%s world_bounds=%s" % [
			node_name, mi.mesh.resource_path, mi.mesh.get_aabb(), mi.global_transform * mi.mesh.get_aabb()
		])
		var found := 0
		for body in lvl.find_children("Col_*_" + node_name + "_*", "StaticBody3D", true, false):
			for cs in body.find_children("*", "CollisionShape3D", true, false):
				found += 1
				print("  collider %s: %s, %d faces" % [body.name, cs.shape.get_class(),
					cs.shape.get_faces().size() / 3 if cs.shape is ConcavePolygonShape3D else -1])
		print("  colliders: ", found)
	quit()

