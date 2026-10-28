extends SceneTree

func _initialize():
	var ps = load("res://models/desert2/d4250e86adc7a52ecf39a804e207694e.fbx")
	var node = ps.instantiate()
	var mi: MeshInstance3D = node.find_child("node_0", true, false)
	var m: Mesh = mi.mesh
	var arr = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	
	# Scale factor to world meters = 100 * 40 = 4000
	var scale_factor = 4000.0
	var slices = 20
	var slice_max_r = []
	var slice_min_r = []
	var slice_count = []
	for s in range(slices):
		slice_max_r.append(0.0)
		slice_min_r.append(9999.0)
		slice_count.append(0)
	
	var max_y = 0.0
	for v in verts:
		var y = v.y * scale_factor
		if y > max_y:
			max_y = y
		var r = Vector2(v.x, v.z).length() * scale_factor
		var s = clampi(int((y / 34.0) * slices), 0, slices - 1)
		slice_max_r[s] = maxf(slice_max_r[s], r)
		slice_min_r[s] = minf(slice_min_r[s], r)
		slice_count[s] += 1
		
	print("Max Y: ", max_y)
	for s in range(slices):
		var y = (float(s) + 0.5) / float(slices) * 34.0
		print("Y=%.1fm: min_r=%.2fm, max_r=%.2fm (count=%d)" % [y, slice_min_r[s], slice_max_r[s], slice_count[s]])
		
	quit()
