@tool
extends SceneTree

func _init() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_radial: int = 16
	var z_top: float = 2.0
	var z_apex: float = 2.5
	var r_top: float = 0.5
	var apex := Vector3(0, 0, z_apex)
	
	for i in range(n_radial):
		var a0: float = TAU * float(i) / float(n_radial)
		var a1: float = TAU * float(i + 1) / float(n_radial)
		var p0 := Vector3(cos(a0) * r_top, sin(a0) * r_top, z_top)
		var p1 := Vector3(cos(a1) * r_top, sin(a1) * r_top, z_top)
		
		# Test: apex -> p0 -> p1 vs apex -> p1 -> p0
		st.add_vertex(apex)
		st.add_vertex(p0)
		st.add_vertex(p1)
		
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	var bad := 0
	for f in range(mdt.get_face_count()):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var geom_n := (v1 - v0).cross(v2 - v0).normalized()
		var center := (v0 + v1 + v2) / 3.0
		var rad_dir := Vector3(center.x, center.y, 0.5).normalized()
		if geom_n.dot(rad_dir) < 0.5:
			bad += 1
	print("Tip (apex -> p0 -> p1) bad faces: ", bad, " / ", mdt.get_face_count())
	quit()
