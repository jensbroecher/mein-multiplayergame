@tool
extends SceneTree

# Helpers for testing
static func add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		n0: Vector3, n1: Vector3, col: Color) -> void:
	# Outward winding in Godot right-handed space (p0 -> p2 -> p1 and p0 -> p3 -> p2)
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

static func add_disc(st: SurfaceTool, center: Vector3, radius: float, normal: Vector3, segs: int, col: Color) -> void:
	st.set_color(col)
	st.set_normal(normal)
	var right: Vector3 = Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.9 else Vector3.UP.cross(normal).normalized()
	var up: Vector3 = normal.cross(right).normalized()
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0: Vector3 = center + (right * cos(a0) + up * sin(a0)) * radius
		var p1: Vector3 = center + (right * cos(a1) + up * sin(a1)) * radius
		# CCW looking against normal
		st.set_color(col)
		st.set_normal(normal)
		st.add_vertex(center)
		st.add_vertex(p0)
		st.add_vertex(p1)

func audit_mesh(mesh: Mesh, name_str: String) -> int:
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
		vert_n = vert_n.normalized()
		if geom_n.dot(vert_n) < 0.2:
			bad += 1
			if bad <= 3:
				print("   ", name_str, " bad face ", f, ": geom=", geom_n, " vert=", vert_n, " dot=", geom_n.dot(vert_n))
	print(name_str, " total bad faces: ", bad, " / ", mdt.get_face_count())
	return bad

func _init() -> void:
	print("--- TESTING DISC AND TOWER WINDINGS ---")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_disc(st, Vector3(0, 40, 0), 1.15, Vector3.UP, 24, Color.WHITE)
	var m := st.commit()
	audit_mesh(m, "Disc UP")
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_disc(st, Vector3(0, 0, 0), 1.4, Vector3.BACK, 24, Color.WHITE)
	m = st.commit()
	audit_mesh(m, "Disc BACK")
	quit()
