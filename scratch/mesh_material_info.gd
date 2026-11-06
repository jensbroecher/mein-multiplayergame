extends SceneTree
func _init():
	var files := DirAccess.get_files_at("res://generated")
	var n := 0
	for f in files:
		if f.begins_with("marina_nights_city_") and f.ends_with(".res") and n < 2:
			var m: ArrayMesh = load("res://generated/" + f)
			n += 1
			print(f, " surfaces ", m.get_surface_count())
			for i in m.get_surface_count():
				var mat = m.surface_get_material(i)
				print("  ", i, " ", mat, " ", mat.resource_path if mat else "", " ", (mat as ShaderMaterial).shader.resource_path if mat is ShaderMaterial else "", " lit=", mat.get_shader_parameter("lit_share") if mat is ShaderMaterial else "")
				var a: Array = m.surface_get_arrays(i)
				print("  uv=", a[Mesh.ARRAY_TEX_UV] != null, " uv2=", a[Mesh.ARRAY_TEX_UV2] != null, " col=", a[Mesh.ARRAY_COLOR] != null)
	quit()
