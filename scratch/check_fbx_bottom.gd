extends SceneTree

func _initialize():
	var ps = load("res://models/desert2/d4250e86adc7a52ecf39a804e207694e.fbx")
	var node = ps.instantiate()
	var mi: MeshInstance3D = node.find_child("node_0", true, false)
	var m: Mesh = mi.mesh
	var arr = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var scale_factor = 4000.0
	
	# Sort verts by Y
	var list = []
	for v in verts:
		list.append(v * scale_factor)
	list.sort_custom(func(a, b): return a.y < b.y)
	
	print("Lowest 20 vertices:")
	for i in range(20):
		print("Y=%.3f, X=%.3f, Z=%.3f, R=%.3f" % [list[i].y, list[i].x, list[i].z, Vector2(list[i].x, list[i].z).length()])
		
	quit()
