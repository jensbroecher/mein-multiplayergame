@tool
extends SceneTree

func _init() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 16
	var apex := Vector3(0, 0, 2.6)
	var z_base := 2.0
	var r_base := 0.6
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * r_base, sin(a0) * r_base, z_base)
		var p1 := Vector3(cos(a1) * r_base, sin(a1) * r_base, z_base)
		var n0 := Vector3(cos(a0), sin(a0), 0.5).normalized()
		var n1 := Vector3(cos(a1), sin(a1), 0.5).normalized()
		
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(apex)
		st.set_normal(n1)
		st.add_vertex(p1)
		st.set_normal(n0)
		st.add_vertex(p0)
		
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	var bad := 0
	for f in range(mdt.get_face_count()):
		var fn := mdt.get_face_normal(f)
		var vn := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
				   mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
				   mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
		vn = vn.normalized()
		if fn.dot(vn) < 0.5:
			bad += 1
	print("Spinner apex fan bad faces: ", bad, " / ", mdt.get_face_count())
	quit()
