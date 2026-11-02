extends SceneTree
# Prints the bounds of each seashell mesh the Bloombay generator saved (generated/bloombay_dunes_seashell_*.res)
# and how much of each one's normals face up: to see how a shell lies. -s, headless.
func _init() -> void:
	for i in 2:
		var m: Mesh = load("res://generated/bloombay_dunes_seashell_%d.res" % i)
		var a := m.surface_get_arrays(0)
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var up := 0.0
		for v in n:
			up += v.y
		print("shell %d aabb=%s mean normal y=%.2f mat=%s" % [i, m.get_aabb(), up / n.size(), m.surface_get_material(0)])
	quit()
