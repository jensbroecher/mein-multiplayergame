extends SceneTree

# Lists every imported model in the given folders: triangles, size and the textures its materials use.
#   Godot --headless --path . -s res://scratch/asset_survey.gd -- res://models/plants res://models/desert ...

func _init() -> void:
	var dirs := OS.get_cmdline_user_args()
	for dir in dirs:
		var files := DirAccess.get_files_at(dir)
		for f in files:
			if not (f.ends_with(".fbx") or f.ends_with(".glb")):
				continue
			var path: String = dir.path_join(f)
			var ps: PackedScene = load(path)
			if ps == null:
				print("FAIL ", path)
				continue
			var root: Node = ps.instantiate()
			var tris := 0
			var aabb := AABB()
			var first := true
			var texs := {}
			for mi in root.find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = mi.mesh
				if m == null:
					continue
				var xf: Transform3D = _xform_to(mi, root)
				var box: AABB = xf * m.get_aabb()
				aabb = box if first else aabb.merge(box)
				first = false
				for s in m.get_surface_count():
					var arr := m.surface_get_arrays(s)
					var idx = arr[Mesh.ARRAY_INDEX]
					tris += (idx.size() if idx else arr[Mesh.ARRAY_VERTEX].size()) / 3
					var mat: Material = mi.get_surface_override_material(s)
					if mat == null:
						mat = m.surface_get_material(s)
					if mat is BaseMaterial3D:
						for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "emission_texture", "ao_texture"]:
							var t: Texture2D = mat.get(prop)
							if t:
								texs[t.resource_path.get_file() + "(" + prop.replace("_texture", "") + " " + str(t.get_width()) + ")"] = true
			print("%s tris=%d size=%s texs=%s" % [path.get_file(), tris, str(aabb.size.snapped(Vector3.ONE * 0.01)), ", ".join(texs.keys())])
			root.free()
	quit()


func _xform_to(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur := n
	while cur and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
