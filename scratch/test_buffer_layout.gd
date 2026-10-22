extends SceneTree

func _init() -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 1
	var t = Transform3D(Basis(), Vector3(10.0, 20.0, 30.0))
	mm.set_instance_transform(0, t)
	print("Buffer for origin (10, 20, 30): ", mm.buffer)
	quit(0)
