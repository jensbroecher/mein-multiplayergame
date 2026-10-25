extends SceneTree

# Lists the LOD chain Godot's mesh simplifier makes for a model (ImporterMesh.generate_lods): the
# triangle count of each level, to pick how far to reduce a model before using it. Headless:
#   Godot --headless --path . -s res://scratch/lod_probe.gd -- res://models/plants/X.fbx ...

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var root: Node = (load(path) as PackedScene).instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var t0 := Time.get_ticks_msec()
			var im := ImporterMesh.from_mesh(mi.mesh)
			im.generate_lods(25.0, 60.0, [])
			var line := "%s: base %d tris" % [path.get_file(), im.get_surface_arrays(0)[Mesh.ARRAY_INDEX].size() / 3]
			for k in im.get_surface_lod_count(0):
				line += ", lod%d %d (%.3f)" % [k, im.get_surface_lod_indices(0, k).size() / 3, im.get_surface_lod_size(0, k)]
			print(line, "  [%d ms]" % (Time.get_ticks_msec() - t0))
		root.free()
	quit()
