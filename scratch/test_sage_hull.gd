extends SceneTree

func _init() -> void:
	var FreightKit = load("res://FreightKit.gd")
	var DressingColliders = load("res://DressingColliders.gd").new()
	var mesh = FreightKit.sage(100)
	print("Sage mesh AABB: ", mesh.get_aabb())
	var info = DressingColliders._mesh_shape(mesh)
	print("Sage mesh info: ", info)
	var hull = DressingColliders._hull_for(mesh, Vector3.ONE)
	print("Sage hull shape points count: ", (hull as ConvexPolygonShape3D).points.size())
	quit()

