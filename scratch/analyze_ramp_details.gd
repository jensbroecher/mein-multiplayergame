@tool
extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://models/ramps/1f92b579825d1652d7ab8d760b289672.fbx")
	var inst: Node = scene.instantiate()
	var mi := inst.get_child(0) as MeshInstance3D
	var arr_mesh: ArrayMesh = mi.mesh
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(arr_mesh, 0)
	
	# Scale factor to world units in LakesideLevel:
	# node_0 scale is 100, ramp scale is 20 -> total factor is 2000.0
	var scale_factor := 2000.0
	
	print("Total vertices: ", mdt.get_vertex_count())
	print("Total faces: ", mdt.get_face_count())
	
	# Sample cross sections at X = -12, -8, -4, 0, 4, 8
	var test_xs := [-12.0, -10.0, -6.0, -2.0, 2.0, 6.0, 8.0]
	for tx in test_xs:
		var verts_near: Array[Vector3] = []
		for i in range(mdt.get_vertex_count()):
			var v := mdt.get_vertex(i) * scale_factor
			if abs(v.x - tx) < 0.3:
				verts_near.append(v)
		print("\n--- Cross section near X = ", tx, " (count: ", verts_near.size(), ") ---")
		var min_y := 999.0
		var max_y := -999.0
		var min_z := 999.0
		var max_z := -999.0
		for v in verts_near:
			min_y = minf(min_y, v.y)
			max_y = maxf(max_y, v.y)
			min_z = minf(min_z, v.z)
			max_z = maxf(max_z, v.z)
		print("  Y range: [%4.2f, %4.2f] (height %4.2f)" % [min_y, max_y, max_y - min_y])
		print("  Z range: [%4.2f, %4.2f] (width %4.2f)" % [min_z, max_z, max_z - min_z])
		# Let's inspect Z vs Y for points with upward or near-upward normals
		var surface_pts: Array = []
		for i in range(mdt.get_vertex_count()):
			var v := mdt.get_vertex(i) * scale_factor
			var n := mdt.get_vertex_normal(i)
			if abs(v.x - tx) < 0.3 and n.y > 0.1:
				surface_pts.append(v)
		surface_pts.sort_custom(func(a, b): return a.z < b.z)
		print("  Upward surface Z vs Y samples:")
		var last_z := -999.0
		for p in surface_pts:
			if abs(p.z - last_z) > 0.5:
				print("    Z=%5.2f -> Y=%5.2f" % [p.z, p.y])
				last_z = p.z

	# Check bottom surface: is Y near 0 everywhere on the bottom?
	var bottom_min_y := 999.0
	var bottom_max_y := -999.0
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i) * scale_factor
		var n := mdt.get_vertex_normal(i)
		if n.y < -0.5:
			bottom_min_y = minf(bottom_min_y, v.y)
			bottom_max_y = maxf(bottom_max_y, v.y)
	print("\nBottom surface normals (pointing down): Y in [%4.2f, %4.2f]" % [bottom_min_y, bottom_max_y])

	# Check back surface: at max X (around +8.4)
	var back_verts: Array[Vector3] = []
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i) * scale_factor
		if v.x > 8.0:
			back_verts.append(v)
	print("Back face vertices (X > 8.0): count=", back_verts.size())
	
	quit(0)
