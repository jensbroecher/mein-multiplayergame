@tool
extends SceneTree

func _init() -> void:
	# Let's inspect a single blade face geometry
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Build one blade and call st.generate_normals()
	var script = load("res://scratch/test_complete_builder.gd")
	script._build_blade_fixed(st, 0.0) # Blade pointing along +X (angle 0)
	st.generate_normals()
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	print("Single blade faces: ", mdt.get_face_count())
	var bad = 0
	for f in range(mdt.get_face_count()):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var geom_n := (v1 - v0).cross(v2 - v0).normalized()
		var vert_n := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
					  mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
					  mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
		vert_n = vert_n.normalized()
		if geom_n.dot(vert_n) < 0.5:
			bad += 1
			if bad <= 3:
				print("Blade face ", f, " mismatch: geom=", geom_n, " vert=", vert_n, " dot=", geom_n.dot(vert_n))
	print("Single blade bad faces after generate_normals: ", bad, " / ", mdt.get_face_count())
	quit()
