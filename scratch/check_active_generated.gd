@tool
extends SceneTree

func _init() -> void:
	for name_str in ["tower", "nacelle", "rotor"]:
		var mesh: Mesh = load("res://generated/lakeside_turbine_" + name_str + ".res")
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(mesh, 0)
		print("=========================================")
		print("ACTIVE MESH: ", name_str, " (Faces: ", mdt.get_face_count(), ")")
		
		# Check face normals vs vertex normals
		var bad := 0
		for f in range(mdt.get_face_count()):
			var fn := mdt.get_face_normal(f)
			var vn := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
					   mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
					   mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
			vn = vn.normalized()
			if fn.dot(vn) < 0.2:
				bad += 1
		print("Face normal vs vertex normal mismatches: ", bad, " / ", mdt.get_face_count())
	quit()
