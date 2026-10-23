@tool
extends SceneTree

func _init() -> void:
	for name_str in ["tower", "nacelle", "rotor"]:
		var mesh: Mesh = load("res://generated/lakeside_turbine_" + name_str + ".res")
		var mdt = MeshDataTool.new()
		mdt.create_from_surface(mesh, 0)
		print("=========================================")
		print("AUDITING: ", name_str, " (Faces: ", mdt.get_face_count(), ")")
		
		var inverted_count = 0
		for i in range(mdt.get_face_count()):
			var v0 = mdt.get_vertex(mdt.get_face_vertex(i, 0))
			var v1 = mdt.get_vertex(mdt.get_face_vertex(i, 1))
			var v2 = mdt.get_vertex(mdt.get_face_vertex(i, 2))
			var center = (v0 + v1 + v2) / 3.0
			var geom_n = (v1 - v0).cross(v2 - v0).normalized()
			var vert_n = (mdt.get_vertex_normal(mdt.get_face_vertex(i, 0)) +
						  mdt.get_vertex_normal(mdt.get_face_vertex(i, 1)) +
						  mdt.get_vertex_normal(mdt.get_face_vertex(i, 2))) / 3.0
			vert_n = vert_n.normalized()
			
			var dot = geom_n.dot(vert_n)
			if dot < 0.1:
				inverted_count += 1
				if inverted_count <= 8:
					print("  Face ", i, " mismatch! geom_n=", geom_n, " vert_n=", vert_n, " dot=", dot, " center=", center)
		print("Total mismatched/inverted faces in ", name_str, ": ", inverted_count, " / ", mdt.get_face_count())
	quit()
