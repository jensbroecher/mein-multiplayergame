@tool
extends SceneTree

static func add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		n0: Vector3, n1: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(n0)
	st.add_vertex(p0)
	st.set_normal(n1)
	st.add_vertex(p2)
	st.set_normal(n1)
	st.add_vertex(p1)

	st.set_color(col)
	st.set_normal(n0)
	st.add_vertex(p0)
	st.set_normal(n0)
	st.add_vertex(p3)
	st.set_normal(n1)
	st.add_vertex(p2)

func _init() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_radial: int = 16
	var z0: float = 0.0
	var z1: float = 1.0 # z0 < z1
	var r0: float = 1.4
	var r1: float = 1.0
	
	for i in range(n_radial):
		var a0: float = TAU * float(i) / float(n_radial)
		var a1: float = TAU * float(i + 1) / float(n_radial)
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)
		
		# Put larger Z first (z1 first, then z0)
		var p0 := Vector3(c0 * r1, s0 * r1, z1)
		var p1 := Vector3(c1 * r1, s1 * r1, z1)
		var p2 := Vector3(c1 * r0, s1 * r0, z0)
		var p3 := Vector3(c0 * r0, s0 * r0, z0)
		var n0 := Vector3(c0, s0, 0.45).normalized()
		var n1 := Vector3(c1, s1, 0.45).normalized()
		add_quad(st, p0, p1, p2, p3, n0, n1, Color.WHITE)
		
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
		var rad_dir := Vector3(center.x, center.y, 0.45).normalized()
		if geom_n.dot(rad_dir) < 0.5:
			bad += 1
	print("Spinner quad test (larger Z first) bad faces: ", bad, " / ", mdt.get_face_count())
	quit()
