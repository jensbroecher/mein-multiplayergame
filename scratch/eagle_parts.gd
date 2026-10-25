extends SceneTree
func _init() -> void:
	var e: Node3D = (load("res://models/animals/20260717033727_7db23447.fbx") as PackedScene).instantiate()
	root.add_child(e)
	for mi in e.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var ab: AABB = m.global_transform * m.mesh.get_aabb()
		print("%s parent=%s tris=%d aabb=%s" % [m.name, m.get_parent().name, m.mesh.get_faces().size() / 3, ab])
	quit()
