@tool
extends SceneTree

static func _add_quad_fixed(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
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
	var plinth_r: float = 3.4
	var plinth_h: float = 0.7
	var segs: int = 24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)
		
		var p0 := Vector3(c0 * plinth_r, 0, s0 * plinth_r)
		var p1 := Vector3(c1 * plinth_r, 0, s1 * plinth_r)
		var p2 := Vector3(c1 * plinth_r, plinth_h, s1 * plinth_r)
		var p3 := Vector3(c0 * plinth_r, plinth_h, s0 * plinth_r)
		var n0 := Vector3(c0, 0, s0)
		var n1 := Vector3(c1, 0, s1)
		_add_quad_fixed(st, p0, p1, p2, p3, n0, n1, Color.WHITE)
		
	var mesh := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	var bad := 0
	for f in range(mdt.get_face_count()):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var geom_n := (v1 - v0).cross(v2 - v0).normalized()
		var vert_n := (mdt.get_vertex_normal(mdt.get_face_vertex(f, 0)) +
					  mdt.get_vertex_normal(mdt.get_face_vertex(f, 1)) +
					  mdt.get_vertex_normal(mdt.get_face_vertex(f, 2))) / 3.0
		if geom_n.dot(vert_n) < 0.5:
			bad += 1
	print("Cylinder test bad faces: ", bad, " / ", mdt.get_face_count())
	quit()
