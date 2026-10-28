extends SceneTree
func _initialize():
	var sc = load("res://models/ramps/a0c68129ab868a396612d59572399b8f.fbx").instantiate()
	var meshes = []
	_collect(sc, meshes)
	for mi in meshes:
		var m: Mesh = mi.mesh
		var lo = m.get_aabb()
		print(mi.name, " aabb=", lo, " xf=", mi.transform)
		var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		# long axis profile: slice along each axis
		for i in range(11):
			var z = lo.position.z + lo.size.z * i / 10.0
			var top = -1e9; var bot = 1e9; var xmin=1e9; var xmax=-1e9
			for p in v:
				if abs(p.z - z) < lo.size.z*0.03:
					top = max(top,p.y); bot=min(bot,p.y); xmin=min(xmin,p.x); xmax=max(xmax,p.x)
			print("  z=%.5f top=%.5f bot=%.5f x[%.5f,%.5f]" % [z,top,bot,xmin,xmax])
	quit()
func _collect(n, out):
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): _collect(c, out)
