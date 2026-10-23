@tool
extends SceneTree

func _init() -> void:
	var mesh = WindTurbineBuilder.build_rotor_mesh()
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	print("Vertex count: ", mdt.get_vertex_count())
	print("Face count: ", mdt.get_face_count())
	
	var nan_count = 0
	var zero_count = 0
	for i in range(mdt.get_vertex_count()):
		var n = mdt.get_vertex_normal(i)
		if is_nan(n.x) or is_nan(n.y) or is_nan(n.z):
			nan_count += 1
		elif n.length_squared() < 0.001:
			zero_count += 1
	print("NaN normals: ", nan_count, " Zero normals: ", zero_count)
	
	# Check the faces near the tip (z > 2.0)
	for i in range(mdt.get_face_count()):
		var v0 = mdt.get_vertex(mdt.get_face_vertex(i, 0))
		var v1 = mdt.get_vertex(mdt.get_face_vertex(i, 1))
		var v2 = mdt.get_vertex(mdt.get_face_vertex(i, 2))
		var fn = mdt.get_face_normal(i)
		if v0.z > 2.0 or v1.z > 2.0 or v2.z > 2.0:
			if is_nan(fn.x) or fn.length_squared() < 0.001:
				print("Bad face normal at face ", i, ": ", fn, " verts: ", v0, v1, v2)

	quit()
