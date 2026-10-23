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
		# Test apex, p1, p0
		st.add_vertex(apex)
		st.add_vertex(p1)
		st.add_vertex(p0)
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	var fn := mdt.get_face_normal(0)
	var c := (mdt.get_vertex(mdt.get_face_vertex(0, 0)) +
			  mdt.get_vertex(mdt.get_face_vertex(0, 1)) +
			  mdt.get_vertex(mdt.get_face_vertex(0, 2))) / 3.0
	print("Apex tip face 0 center: ", c, " fn: ", fn)
	quit()
