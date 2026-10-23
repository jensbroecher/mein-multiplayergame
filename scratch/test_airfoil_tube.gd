@tool
extends SceneTree

static func add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color) -> void:
	# CCW: p0 -> p1 -> p2 and p0 -> p2 -> p3
	st.set_color(col)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)

	st.set_color(col)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p3)

static func _sample(r: float, u: float, v: float, chord: float, thick: float, twist: float,
		v_rad: Vector3, v_tan: Vector3, v_norm: Vector3) -> Vector3:
	var local_x := (u - 0.3) * chord
	var local_y := v * thick
	var rot_x := local_x * cos(twist) - local_y * sin(twist)
	var rot_y := local_x * sin(twist) + local_y * cos(twist)
	var precone_z := 0.35 - r * 0.03
	return (v_rad * r) + (v_tan * rot_x) + (v_norm * (rot_y + precone_z))

func _init() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var v_rad := Vector3.RIGHT
	var v_tan := Vector3.UP
	var v_norm := Vector3(0, 0, 1)
	
	# CCW loop
	var x_pts := [1.0, 0.75, 0.40, 0.15, 0.0, 0.15, 0.40, 0.75]
	var y_pts := [0.0, 0.28, 0.50, 0.38, 0.0, -0.10, -0.18, -0.15]
	var n_pts := x_pts.size()
	
	var r0: float = 5.0
	var r1: float = 6.0
	var ch0: float = 1.2
	var ch1: float = 1.1
	var th0: float = 0.3
	var th1: float = 0.25
	var tw0: float = 0.1
	var tw1: float = 0.08
	
	for p in range(n_pts):
		var p_next: int = (p + 1) % n_pts
		var p00 := _sample(r0, x_pts[p], y_pts[p], ch0, th0, tw0, v_rad, v_tan, v_norm)
		var p01 := _sample(r0, x_pts[p_next], y_pts[p_next], ch0, th0, tw0, v_rad, v_tan, v_norm)
		var p11 := _sample(r1, x_pts[p_next], y_pts[p_next], ch1, th1, tw1, v_rad, v_tan, v_norm)
		var p10 := _sample(r1, x_pts[p], y_pts[p], ch1, th1, tw1, v_rad, v_tan, v_norm)
		
		# Test: (p00, p01, p11, p10) vs (p00, p10, p11, p01)
		add_quad(st, p00, p10, p11, p01, Color.WHITE)
		
	st.generate_normals()
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	var bad := 0
	for f in range(mdt.get_face_count()):
		var fn := mdt.get_face_normal(f)
		var c := (mdt.get_vertex(mdt.get_face_vertex(f, 0)) +
				  mdt.get_vertex(mdt.get_face_vertex(f, 1)) +
				  mdt.get_vertex(mdt.get_face_vertex(f, 2))) / 3.0
		var axis_pt := v_rad * c.x + v_norm * (0.35 - c.x * 0.03)
		var rad_vec := (c - axis_pt).normalized()
		var dot := fn.dot(rad_vec)
		if dot < 0.2:
			bad += 1
			print("Face ", f, " inward! fn=", fn, " rad_vec=", rad_vec, " dot=", dot)
	print("Airfoil tube bad faces: ", bad, " / ", mdt.get_face_count())
	quit()
