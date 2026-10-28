extends SceneTree

func _initialize():
	print("--- TESTING HELICAL RIBBON IN CSG ---")
	var root := CSGCombiner3D.new()

	# Create a Path3D with a helical spiral curve
	var path_node := Path3D.new()
	var curve := Curve3D.new()
	var turns := 2.5
	var height := 32.0
	var steps := 40
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := t * TAU * turns
		var r := 1.2 + pow(t, 1.6) * 18.5
		var y := t * height
		var pos := Vector3(cos(angle) * r, y, sin(angle) * r)
		curve.add_point(pos)
	path_node.curve = curve
	root.add_child(path_node)

	var poly := CSGPolygon3D.new()
	poly.mode = CSGPolygon3D.MODE_PATH
	poly.path_node = poly.get_path_to(path_node)
	poly.path_interval = 0.5
	poly.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH
	poly.smooth_faces = true
	var pts := PackedVector2Array()
	pts.append(Vector2(-0.8, -0.05))
	pts.append(Vector2(0.8, -0.05))
	pts.append(Vector2(0.8, 0.05))
	pts.append(Vector2(-0.8, 0.05))
	poly.polygon = pts
	root.add_child(poly)

	var w := Node3D.new()
	self.root.add_child(w)
	w.add_child(root)

	for i in 2:
		await process_frame

	var mesh: ArrayMesh = root.bake_static_mesh()
	if mesh:
		print("Helical ribbon bake SUCCESS! verts=", mesh.surface_get_array_len(0))
	else:
		print("Path bake returned null (might need relative path resolution)")

	quit()
