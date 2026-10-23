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
	var segs: int = 24
	var r_out: float = 3.6
	var r_in: float = 2.4
	var y: float = 0.8
	
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)
		
		# Outer at a0, a1; inner at a1, a0
		var p0 := Vector3(c0 * r_out, y, s0 * r_out)
		var p1 := Vector3(c1 * r_out, y, s1 * r_out)
		var p2 := Vector3(c1 * r_in, y, s1 * r_in)
		var p3 := Vector3(c0 * r_in, y, s0 * r_in)
		add_quad(st, p0, p1, p2, p3, Vector3.UP, Vector3.UP, Color.WHITE)
		
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	var bad := 0
	for f in range(mdt.get_face_count()):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var geom_n := (v1 - v0).cross(v2 - v0).normalized()
		if geom_n.dot(Vector3.UP) < 0.9:
			bad += 1
	print("Horizontal ring bad faces: ", bad, " / ", mdt.get_face_count())
	quit()
