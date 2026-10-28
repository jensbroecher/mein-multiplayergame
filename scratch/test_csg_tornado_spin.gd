extends SceneTree

func _initialize():
	print("--- TESTING CSG POLYGON SPIN BAKE ---")
	var root := CSGCombiner3D.new()
	var poly := CSGPolygon3D.new()
	poly.mode = CSGPolygon3D.MODE_SPIN
	poly.spin_degrees = 360.0
	poly.spin_sides = 32
	poly.smooth_faces = true

	# Test profile
	var pts := PackedVector2Array()
	pts.append(Vector2(0.9, 0.0))
	pts.append(Vector2(6.0, 15.0))
	pts.append(Vector2(20.0, 34.0))
	pts.append(Vector2(19.4, 34.0))
	pts.append(Vector2(5.5, 15.0))
	pts.append(Vector2(0.7, 0.0))
	poly.polygon = pts
	root.add_child(poly)

	var w := Node3D.new()
	root_node = w
	self.root.add_child(w)
	w.add_child(root)

	for i in 2:
		await process_frame

	var mesh: ArrayMesh = root.bake_static_mesh()
	if mesh:
		print("Bake SUCCESS! Surfaces: ", mesh.get_surface_count())
		for s in mesh.get_surface_count():
			var arr = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			print("Surface ", s, " verts=", verts.size(), " uvs=", uvs.size(), " normals=", normals.size(), " aabb=", mesh.get_aabb())
			if uvs.size() > 0:
				print("UV sample 0..3: ", uvs[0], ", ", uvs[1], ", ", uvs[2])
	else:
		push_error("Bake returned null!")

	quit()

var root_node: Node3D
