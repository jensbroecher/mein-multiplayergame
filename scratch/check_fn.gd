@tool
extends SceneTree

func _init() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var script = load("res://scratch/test_complete_builder.gd")
	script._build_blade_fixed(st, 0.0)
	st.generate_normals()
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	for f in range(5):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var geom_n := (v1 - v0).cross(v2 - v0).normalized()
		var mdt_fn := mdt.get_face_normal(f)
		var vn0 := mdt.get_vertex_normal(mdt.get_face_vertex(f, 0))
		print("Face ", f, ":")
		print("  geom_n: ", geom_n)
		print("  mdt_fn: ", mdt_fn)
		print("  vn0:    ", vn0)
	quit()
