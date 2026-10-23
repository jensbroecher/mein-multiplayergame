@tool
extends SceneTree

const WindTurbineBuilder = preload("res://WindTurbineBuilder.gd")

func _init() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Test with pt0_a, pt0_b, pt1_b, pt1_a
	var r_stations := [0.8, 1.8, 3.2, 5.5, 8.5, 12.0, 15.5, 18.0, 19.5, 21.0]
	var chords := [1.10, 1.35, 1.55, 1.50, 1.30, 1.08, 0.80, 0.58, 0.42, 0.22]
	var thicks := [0.95, 0.70, 0.42, 0.33, 0.25, 0.18, 0.13, 0.08, 0.06, 0.04]
	var twists := [16.0, 14.0, 10.0, 7.0, 4.5, 2.5, 1.2, 0.5, 0.0, -0.5]

	var v_rad := Vector3.RIGHT
	var v_tan := Vector3.UP
	var v_norm := Vector3.FORWARD

	var x_pts := [0.0, 0.15, 0.40, 0.75, 1.0, 0.75, 0.40, 0.15]
	var y_pts := [0.0, 0.38, 0.50, 0.28, 0.0, -0.15, -0.18, -0.10]
	var n_pts := x_pts.size()

	for s in range(r_stations.size() - 1):
		var r0: float = r_stations[s]
		var r1: float = r_stations[s + 1]
		var ch0: float = chords[s]
		var ch1: float = chords[s + 1]
		var th0: float = thicks[s]
		var th1: float = thicks[s + 1]
		var tw0: float = deg_to_rad(twists[s])
		var tw1: float = deg_to_rad(twists[s + 1])

		for p in range(n_pts):
			var p_next: int = (p + 1) % n_pts
			var pt0_a := WindTurbineBuilder._sample_airfoil(r0, x_pts[p], y_pts[p], ch0, th0, tw0, v_rad, v_tan, v_norm)
			var pt0_b := WindTurbineBuilder._sample_airfoil(r0, x_pts[p_next], y_pts[p_next], ch0, th0, tw0, v_rad, v_tan, v_norm)
			var pt1_a := WindTurbineBuilder._sample_airfoil(r1, x_pts[p], y_pts[p], ch1, th1, tw1, v_rad, v_tan, v_norm)
			var pt1_b := WindTurbineBuilder._sample_airfoil(r1, x_pts[p_next], y_pts[p_next], ch1, th1, tw1, v_rad, v_tan, v_norm)

			WindTurbineBuilder._add_quad(st, pt0_a, pt0_b, pt1_b, pt1_a, Vector3.UP, Vector3.UP, Color.WHITE)

	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	print("Total blade faces: ", mdt.get_face_count())
	var bad := 0
	for f in range(mdt.get_face_count()):
		var fn := mdt.get_face_normal(f)
		var v0 := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var c := (v0 + v1 + v2) / 3.0
		var center_line := Vector3(c.x, 0, 0.35 - c.x * 0.03)
		var outward := (c - center_line).normalized()
		var dot := fn.dot(outward)
		if dot < 0.0:
			bad += 1
	print("With pt0_a, pt0_b, pt1_b, pt1_a - total inward faces: ", bad, " / ", mdt.get_face_count())
	quit()
