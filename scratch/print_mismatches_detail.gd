@tool
extends SceneTree

func _init() -> void:
	for pair in [["Tower", WindTurbineBuilder.build_tower_mesh()],
				 ["Nacelle", WindTurbineBuilder.build_nacelle_mesh()],
				 ["Rotor", WindTurbineBuilder.build_rotor_mesh()]]:
		var name_str: String = pair[0]
		var m: Mesh = pair[1]
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(m, 0)
		print("=== ", name_str, " ===")
		for f in range(mdt.get_face_count()):
			var fn := mdt.get_face_normal(f)
			var vn := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
					   mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
					   mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
			vn = vn.normalized()
			if fn.dot(vn) < 0.1:
				var c := (mdt.get_vertex(mdt.get_face_vertex(f, 0)) +
						  mdt.get_vertex(mdt.get_face_vertex(f, 1)) +
						  mdt.get_vertex(mdt.get_face_vertex(f, 2))) / 3.0
				print("  Face ", f, " fn=", fn, " vn=", vn, " dot=", fn.dot(vn), " center=", c)
	quit()
