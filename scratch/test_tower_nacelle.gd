@tool
extends SceneTree

func _init() -> void:
	for name_str in ["tower", "nacelle"]:
		var mesh: Mesh = load("res://generated/lakeside_turbine_" + name_str + ".res")
		var mdt = MeshDataTool.new()
		mdt.create_from_surface(mesh, 0)
		print("=== ", name_str, " faces: ", mdt.get_face_count(), " verts: ", mdt.get_vertex_count())
		var bad_faces = 0
		for i in range(mdt.get_face_count()):
			var fn = mdt.get_face_normal(i)
			if fn.length_squared() < 0.001 or is_nan(fn.x):
				bad_faces += 1
		print("Bad faces: ", bad_faces)
		
		# Sample some face normals and their centers
		for i in [0, 5, 20, 50, 100]:
			if i < mdt.get_face_count():
				var fn = mdt.get_face_normal(i)
				var v0 = mdt.get_vertex(mdt.get_face_vertex(i, 0))
				var v1 = mdt.get_vertex(mdt.get_face_vertex(i, 1))
				var v2 = mdt.get_vertex(mdt.get_face_vertex(i, 2))
				var c = (v0 + v1 + v2) / 3.0
				print("Face ", i, " center: ", c, " normal: ", fn)
	quit()
