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

static func _sample_airfoil(r: float, u: float, v: float, chord: float, thick: float, twist: float,
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
	
	var v_rad := Vector3.UP
	var v_tan := Vector3.LEFT
	var v_norm := Vector3.FORWARD
	
	# Reverse loop order: CCW in (local_x, local_y) plane!
	# Start at trailing edge (1.0), go along upper surface to leading edge (0.0), then along lower to trailing
	var x_pts := [1.0, 0.75, 0.40, 0.15, 0.0, 0.15, 0.40, 0.75]
	var y_pts := [0.0, 0.28, 0.50, 0.38, 0.0, -0.10, -0.18, -0.15]
	var n_pts := x_pts.size()
	
	var r0: float = 5.0
	var r1: float = 6.0
	var ch: float = 1.2
	var th: float = 0.3
	var tw: float = 0.1
	
	for p in range(n_pts):
		var p_next := (p + 1) % n_pts
		var pt0_a := _sample_airfoil(r0, x_pts[p], y_pts[p], ch, th, tw, v_rad, v_tan, v_norm)
		var pt0_b := _sample_airfoil(r0, x_pts[p_next], y_pts[p_next], ch, th, tw, v_rad, v_tan, v_norm)
		var pt1_a := _sample_airfoil(r1, x_pts[p], y_pts[p], ch, th, tw, v_rad, v_tan, v_norm)
		var pt1_b := _sample_airfoil(r1, x_pts[p_next], y_pts[p_next], ch, th, tw, v_rad, v_tan, v_norm)
		
		var n_a := (pt0_a - (v_rad * r0)).normalized()
		var n_b := (pt0_b - (v_rad * r0)).normalized()
		
		# Test larger R first: pt1_a, pt1_b, pt0_b, pt0_a
		add_quad(st, pt1_a, pt1_b, pt0_b, pt0_a, n_a, n_b, Color.WHITE)
		
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
		var outward := (center - (v_rad * ((r0 + r1) * 0.5))).normalized()
		if geom_n.dot(outward) < 0.2:
			bad += 1
	print("Blade quad Option B bad faces: ", bad, " / ", mdt.get_face_count())
	quit()
