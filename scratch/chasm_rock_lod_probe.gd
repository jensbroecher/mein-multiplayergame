extends SceneTree
# -s windowed: lists each baked Canyon Chasm rock's triangles per LOD (generated/canyon_chasm_rock_*.res),
# and an imported FBX's triangles for comparison (-- fbx=<path>).
func _initialize():
	await process_frame
	var dir := DirAccess.open("res://generated")
	for f in dir.get_files():
		if f.begins_with("canyon_chasm_rock_") and f.ends_with(".res"):
			var m: ArrayMesh = load("res://generated/" + f)
			var s := RenderingServer.mesh_get_surface(m.get_rid(), 0)
			var lods := []
			for l in s.get("lods", []):
				lods.append(l.index_data.size() / (6 if s.index_count > 65535 or s.vertex_count > 65535 else 3) / 2)
			print("%-40s %6d tris  LODs %s" % [f, m.surface_get_array_index_len(0) / 3, lods])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("fbx="):
			var sc = load(a.substr(4)).instantiate()
			var n := 0
			for mi in sc.find_children("*", "MeshInstance3D", true, false):
				n += mi.mesh.get_faces().size() / 3
			print("fbx %s: %d tris" % [a.substr(4), n])
	quit()
