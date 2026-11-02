extends SceneTree
# Prints a model's node tree with each mesh's bounds in the model's own frame, its triangles and its
# materials, and the whole model's bounds: for setting up the low-poly props (boats, raft, seashells).
# Godot --headless --path . -s res://scratch/lowpoly_model_probe.gd -- "res://models/lowpoly/X.glb" ...
func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var s: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(s)
		print("== ", path)
		var total := AABB()
		var first := true
		for m in s.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var box: AABB = _to_root(s, mi) * mi.get_aabb()
			var tris := 0
			var mats := []
			for i in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(i)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				var mat := mi.get_active_material(i)
				var desc := "null"
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					desc = "%s col=%s tex=%s" % [sm.resource_name, sm.albedo_color, sm.albedo_texture.resource_path if sm.albedo_texture else "-"]
				elif mat != null:
					desc = mat.get_class()
				mats.append(desc)
			print("  ", s.get_path_to(mi), " tris=", tris, " box=", box, " mats=", mats)
			total = box if first else total.merge(box)
			first = false
		print("  TOTAL ", total, " size=", total.size)
		s.queue_free()
	quit()


func _to_root(r: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != r and c != null:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
