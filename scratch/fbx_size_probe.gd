extends SceneTree

# Prints the size of imported models (the merged AABB of their meshes) and, given a scale, how big
# that is in a level. Headless:
#   Godot --headless --path . -s res://scratch/fbx_size_probe.gd -- <model.fbx>[:scale] ...

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var parts := a.split(":")
		var path := parts[0] if parts.size() < 3 else parts[0] + ":" + parts[1]
		var sc := float(parts[parts.size() - 1]) if parts.size() > 1 and parts[parts.size() - 1].is_valid_float() else 1.0
		if path.begins_with("res") and not path.contains("://"):
			path = a
		var node: Node3D = (load(path) as PackedScene).instantiate()
		var box := AABB()
		var first := true
		var tris := 0
		for m in node.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var xf := _to_root(mi, node)
			var b: AABB = xf * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
			for si in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_index_len(si) / 3
		print("%s: size %s (x%.2f -> %s), %d triangles" % [path.get_file(), box.size, sc, box.size * sc, tris])
		node.free()
	quit()


func _to_root(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D()
	var cur: Node = n
	while cur and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
