@tool
extends SceneTree

func _init() -> void:
	var mesh: Mesh = load("res://generated/lakeside_turbine_tower.res")
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	print("Checking top ring faces (48 to 95):")
	for i in range(48, 96):
		var fn = mdt.get_face_normal(i)
		var v0 = mdt.get_vertex(mdt.get_face_vertex(i, 0))
		var v1 = mdt.get_vertex(mdt.get_face_vertex(i, 1))
		var v2 = mdt.get_vertex(mdt.get_face_vertex(i, 2))
		if fn.y > 0:
			print("Face ", i, " normal: ", fn)
		else:
			print("Face ", i, " INVERTED! normal: ", fn, " verts: ", v0, v1, v2)
	quit()
