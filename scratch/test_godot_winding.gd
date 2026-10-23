@tool
extends SceneTree

# Standard CCW winding for Godot
static func add_quad_ccw(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		n0: Vector3, n1: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(n0)
	st.add_vertex(p0)
	st.set_normal(n1)
	st.add_vertex(p1)
	st.set_normal(n1)
	st.add_vertex(p2)

	st.set_color(col)
	st.set_normal(n0)
	st.add_vertex(p0)
	st.set_normal(n1)
	st.add_vertex(p2)
	st.set_normal(n0)
	st.add_vertex(p3)

func _init() -> void:
	# Cylinder of radius 2.0, height 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 16
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)
		# p0, p1 at bottom; p2, p3 at top
		var p0 := Vector3(c0 * 2.0, 0, s0 * 2.0)
		var p1 := Vector3(c1 * 2.0, 0, s1 * 2.0)
		var p2 := Vector3(c1 * 2.0, 1.0, s1 * 2.0)
		var p3 := Vector3(c0 * 2.0, 1.0, s0 * 2.0)
		var n0 := Vector3(c0, 0, s0)
		var n1 := Vector3(c1, 0, s1)
		add_quad_ccw(st, p0, p1, p2, p3, n0, n1, Color.WHITE)
		
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	var bad := 0
	for f in range(mdt.get_face_count()):
		var fn := mdt.get_face_normal(f)
		var c := (mdt.get_vertex(mdt.get_face_vertex(f, 0)) +
				  mdt.get_vertex(mdt.get_face_vertex(f, 1)) +
				  mdt.get_vertex(mdt.get_face_vertex(f, 2))) / 3.0
		var expected_outward := Vector3(c.x, 0, c.z).normalized()
		if fn.dot(expected_outward) < 0.5:
			bad += 1
	print("CCW Cylinder bad faces (mdt_fn dot outward): ", bad, " / ", mdt.get_face_count())
	quit()
