extends SceneTree

func _init() -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 1
	var buf = PackedFloat32Array([-0.7693115, 0.014730599, -0.8868238, -832.72205, 0.01354963, 1.1591176, 0.00799688, 7.970955, 0.8868457, -0.0049311784, -0.76941454, 98.826645])
	mm.buffer = buf
	var t = mm.get_instance_transform(0)
	print("Decoded transform: ", t)
	print("Origin: ", t.origin)
	quit(0)
