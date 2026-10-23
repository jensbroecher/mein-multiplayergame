@tool
extends SceneTree

func _init() -> void:
	var mesh: Mesh = load("res://generated/lakeside_turbine_tower.res")
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	for i in [50, 51]:
		var fn = mdt.get_face_normal(i)
		var v0 = mdt.get_vertex(mdt.get_face_vertex(i, 0))
		var v1 = mdt.get_vertex(mdt.get_face_vertex(i, 1))
		var v2 = mdt.get_vertex(mdt.get_face_vertex(i, 2))
		print("Face ", i, " normal: ", fn)
		print("   v0: ", v0)
		print("   v1: ", v1)
		print("   v2: ", v2)
		var calculated_fn = (v1 - v0).cross(v2 - v0).normalized()
		print("   calc fn: ", calculated_fn)
	quit()
