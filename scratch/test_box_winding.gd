@tool
extends SceneTree

const DIR_FRONT := Vector3(0, 0, 1)
const DIR_BACK := Vector3(0, 0, -1)

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p3)

func _init() -> void:
	var h := Vector3(1, 1, 1)
	var c := [
		Vector3(-h.x, -h.y, -h.z), # 0
		Vector3( h.x, -h.y, -h.z), # 1
		Vector3( h.x,  h.y, -h.z), # 2
		Vector3(-h.x,  h.y, -h.z), # 3
		Vector3(-h.x, -h.y,  h.z), # 4
		Vector3( h.x, -h.y,  h.z), # 5
		Vector3( h.x,  h.y,  h.z), # 6
		Vector3(-h.x,  h.y,  h.z), # 7
	]
	var faces := [
		# [p0, p1, p2, p3, expected_normal]
		[0, 1, 2, 3, DIR_BACK],
		[5, 4, 7, 6, DIR_FRONT],
		[4, 0, 3, 7, Vector3.LEFT],
		[1, 5, 6, 2, Vector3.RIGHT],
		[3, 2, 6, 7, Vector3.UP],
		[4, 5, 1, 0, Vector3.DOWN],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		_add_quad(st, c[f[0]], c[f[1]], c[f[2]], c[f[3]], f[4])
	var m := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(m, 0)
	var bad := 0
	for f_idx in range(faces.size()):
		var fn0 := mdt.get_face_normal(f_idx * 2)
		var fn1 := mdt.get_face_normal(f_idx * 2 + 1)
		var exp_n: Vector3 = faces[f_idx][4]
		if fn0.dot(exp_n) < 0.9 or fn1.dot(exp_n) < 0.9:
			bad += 1
			print("Face ", f_idx, " bad: exp=", exp_n, " got fn0=", fn0, " fn1=", fn1)
	print("Box bad faces: ", bad, " / ", faces.size())
	quit()
