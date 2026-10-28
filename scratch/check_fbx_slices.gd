extends SceneTree

func _initialize():
	var ps = load("res://models/desert2/d4250e86adc7a52ecf39a804e207694e.fbx")
	var node = ps.instantiate()
	var mi: MeshInstance3D = node.find_child("node_0", true, false)
	var m: Mesh = mi.mesh
	var arr = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var scale_factor = 4000.0
	
	var slices = 15
	var slice_centers = []
	var slice_counts = []
	for s in range(slices):
		slice_centers.append(Vector2.ZERO)
		slice_counts.append(0)
		
	for v in verts:
		var y = v.y * scale_factor
		var s = clampi(int((y / 34.0) * slices), 0, slices - 1)
		slice_centers[s] += Vector2(v.x, v.z) * scale_factor
		slice_counts[s] += 1
		
	for s in range(slices):
		if slice_counts[s] > 0:
			slice_centers[s] /= float(slice_counts[s])
			
	for s in range(slices):
		var y = (float(s) + 0.5) / float(slices) * 34.0
		var c: Vector2 = slice_centers[s]
		var max_dist = 0.0
		var min_dist = 999.0
		for v in verts:
			var vy = v.y * scale_factor
			var vs = clampi(int((vy / 34.0) * slices), 0, slices - 1)
			if vs == s:
				var d = (Vector2(v.x, v.z) * scale_factor - c).length()
				max_dist = maxf(max_dist, d)
				min_dist = minf(min_dist, d)
		print("Slice %2d (Y=%4.1fm): center=(%5.2f, %5.2f) radius=[%4.2fm .. %4.2fm] (count=%d)" % [
			s, y, c.x, c.y, min_dist, max_dist, slice_counts[s]
		])
		
	quit()
