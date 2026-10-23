@tool
extends SceneTree

func _init() -> void:
	for name_str in ["tower", "nacelle", "rotor"]:
		var mesh: Mesh = load("res://generated/lakeside_turbine_" + name_str + ".res")
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(mesh, 0)
		print("=== MISMATCHES IN ", name_str, " ===")
		for f in range(mdt.get_face_count()):
			var fn := mdt.get_face_normal(f)
			var vn := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
					   mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
					   mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
			vn = vn.normalized()
			if fn.dot(vn) < 0.2:
				var c := (mdt.get_vertex(mdt.get_face_vertex(f, 0)) +
						  mdt.get_vertex(mdt.get_face_vertex(f, 1)) +
						  mdt.get_vertex(mdt.get_face_vertex(f, 2))) / 3.0
				print("  Face ", f, " fn=", fn, " vn=", vn, " center=", c)
	quit()
