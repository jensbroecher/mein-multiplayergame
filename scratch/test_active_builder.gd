@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING REWRITTEN WindTurbineBuilder ---")
	var tower: Mesh = WindTurbineBuilder.build_tower_mesh()
	var nacelle: Mesh = WindTurbineBuilder.build_nacelle_mesh()
	var rotor: Mesh = WindTurbineBuilder.build_rotor_mesh()
	
	for pair in [["Tower", tower], ["Nacelle", nacelle], ["Rotor", rotor]]:
		var name_str: String = pair[0]
		var m: Mesh = pair[1]
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(m, 0)
		var bad := 0
		var zero_fn := 0
		for f in range(mdt.get_face_count()):
			var fn := mdt.get_face_normal(f)
			if fn.length_squared() < 0.001:
				zero_fn += 1
			var vn := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
					   mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
					   mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
			vn = vn.normalized()
			if fn.dot(vn) < 0.2:
				bad += 1
		print(name_str, " faces: ", mdt.get_face_count(), " - bad faces: ", bad, " - zero face normals: ", zero_fn)
	quit()
