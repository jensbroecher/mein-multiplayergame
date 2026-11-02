extends SceneTree

func _init() -> void:
	var FreightKit = load("res://FreightKit.gd")
	var DressingColliders = load("res://DressingColliders.gd").new()
	var mat = StandardMaterial3D.new()
	for v in 4:
		var ml: Mesh = FreightKit.boulder(4300 + v, Vector3(1.4, 0.62, 1.15), mat)
		var mt: Mesh = FreightKit.boulder(4320 + v, Vector3(1.0, 0.95, 0.88), mat)
		var il = DressingColliders._mesh_shape(ml)
		var it = DressingColliders._mesh_shape(mt)
		print("rock_l%d: aabb=%s info=%s" % [v, ml.get_aabb(), il])
		print("rock_t%d: aabb=%s info=%s" % [v, mt.get_aabb(), it])
	quit()

