extends SceneTree
# -s headless: loads Canyon Chasm and lists each ChasmRock (ChasmRock.gd): its kind, the bake it loaded (or
# BUILT if it had to build its mesh), the collider's triangles, its world bounds and the surface
# Surfaces.gd reads off it.
func _initialize():
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	for i in 5: await process_frame
	await physics_frame
	var n := 0
	for r in lvl.get_children():
		if not (r.get_script() and r.get_script().resource_path.ends_with("ChasmRock.gd")):
			continue
		n += 1
		for body in r.get_children(true):
			if body is StaticBody3D:
				var mi: MeshInstance3D = body.find_children("*", "MeshInstance3D", true, false)[0]
				var cs: CollisionShape3D = body.find_children("*", "CollisionShape3D", true, false)[0]
				var faces: int = cs.shape.get_faces().size() / 3 if cs.shape else 0
				var baked: bool = mi.mesh.resource_path == r.bake_path()
				print("%-12s kind=%d %s collider=%d tris surface=%s bounds=%s" % [r.name, r.kind,
					"baked" if baked else "BUILT", faces, r.get_meta(&"surface", "?"), mi.global_transform * mi.mesh.get_aabb()])
	print("rocks: ", n)
	quit()
