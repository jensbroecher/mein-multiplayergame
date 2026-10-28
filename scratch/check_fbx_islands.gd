extends SceneTree

func _initialize():
	var ps = load("res://models/desert2/d4250e86adc7a52ecf39a804e207694e.fbx")
	var node = ps.instantiate()
	var mi: MeshInstance3D = node.find_child("node_0", true, false)
	var m: Mesh = mi.mesh
	print("Surfaces: ", m.get_surface_count())
	var arr = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	print("Verts: ", verts.size(), " Indices: ", indices.size(), " Tris: ", indices.size() / 3)
	
	# Check if there are disconnected mesh components (islands)
	var adj = {}
	for i in range(0, indices.size(), 3):
		var a = indices[i]
		var b = indices[i+1]
		var c = indices[i+2]
		for pair in [[a, b], [b, c], [c, a]]:
			var u = pair[0]
			var v = pair[1]
			if not adj.has(u): adj[u] = []
			if not adj.has(v): adj[v] = []
			adj[u].append(v)
			adj[v].append(u)
			
	var visited = {}
	var islands = 0
	var island_sizes = []
	for vi in range(verts.size()):
		if visited.has(vi):
			continue
		islands += 1
		var q = [vi]
		visited[vi] = true
		var count = 0
		while q.size() > 0:
			var curr = q.pop_back()
			count += 1
			if adj.has(curr):
				for nbr in adj[curr]:
					if not visited.has(nbr):
						visited[nbr] = true
						q.append(nbr)
		island_sizes.append(count)
		
	print("Found %d connected islands. Top 10 sizes:" % islands)
	island_sizes.sort()
	island_sizes.reverse()
	for i in range(min(10, island_sizes.size())):
		print("  Island %d: %d verts" % [i, island_sizes[i]])
		
	quit()
