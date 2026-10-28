extends SceneTree

func _initialize():
	var ps = load("res://models/desert2/d4250e86adc7a52ecf39a804e207694e.fbx")
	var node = ps.instantiate()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m = mi.mesh
		var aabb = m.get_aabb()
		print("mi name=", mi.name, " aabb=", aabb)
		var arr = m.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var min_v = Vector3.ONE * 999999
		var max_v = Vector3.ONE * -999999
		for v in verts:
			min_v = min_v.min(v)
			max_v = max_v.max(v)
		print("verts min=", min_v, " max=", max_v)
		print("mi transform: ", mi.transform)
	quit()
