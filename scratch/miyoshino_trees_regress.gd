extends SceneTree

# Regression check for WoodlandBuilder.gd: builds the existing kinds (variant 0, lod 0 and 1) and prints a hash of
# every surface's vertices, normals, colours, UVs and indices. Run before and after an edit: the lines must match.
#   Godot --headless --path . -s res://scratch/miyoshino_trees_regress.gd
const Woodland = preload("res://WoodlandBuilder.gd")

func _init() -> void:
	var w = Woodland.new()
	w.save_res = func(res: Resource, _n: String) -> Resource: return res
	var mat := StandardMaterial3D.new()
	var all := ""
	for kind in ["oak", "lime", "birch", "willow", "plane", "poplar", "pollard", "spruce", "pine", "fir", "larch", "alder", "cottonwood", "ghaf", "samr"]:
		for lod in range(2):
			var mesh: ArrayMesh = w.tree_mesh(kind, 0, lod, mat, mat)
			var h := 0
			var verts := 0
			for s in range(mesh.get_surface_count()):
				var arr: Array = mesh.surface_get_arrays(s)
				for ch in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_INDEX]:
					if arr[ch] != null:
						h = hash([h, var_to_bytes(arr[ch])])
				verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var line := "%s lod%d verts=%d hash=%d" % [kind, lod, verts, h]
			print(line)
			all += line + "\n"
	for v in range(2):
		for mesh in [w.shrub_mesh(v, mat, mat), w.alpine_shrub_mesh(v, mat, mat)]:
			var h2 := 0
			for s in range(mesh.get_surface_count()):
				var arr2: Array = mesh.surface_get_arrays(s)
				for ch in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
					if arr2[ch] != null:
						h2 = hash([h2, var_to_bytes(arr2[ch])])
			var line2 := "shrub v%d hash=%d" % [v, h2]
			print(line2)
			all += line2 + "\n"
	for tex in [w.atlas(), w.rhein_atlas()]:
		var line3 := "atlas hash=%d" % hash((tex as Texture2D).get_image().get_data())
		print(line3)
		all += line3 + "\n"
	print("ALL ", hash(all))
	quit()
