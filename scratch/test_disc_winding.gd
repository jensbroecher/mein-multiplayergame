@tool
extends SceneTree

static func add_disc(st: SurfaceTool, center: Vector3, radius: float, normal: Vector3, segs: int) -> void:
	var right: Vector3 = Vector3.RIGHT if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var up: Vector3 = normal.cross(right).normalized()
	right = up.cross(normal).normalized()
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0: Vector3 = center + (right * cos(a0) + up * sin(a0)) * radius
		var p1: Vector3 = center + (right * cos(a1) + up * sin(a1)) * radius
		st.set_normal(normal)
		st.add_vertex(center)
		st.add_vertex(p1)
		st.add_vertex(p0)

func _init() -> void:
	for n in [Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		add_disc(st, Vector3.ZERO, 1.0, n, 16)
		var m := st.commit()
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(m, 0)
		var fn := mdt.get_face_normal(0)
		print("Requested normal: ", n, " -> got MeshDataTool face normal: ", fn, " dot=", n.dot(fn))
	quit()
