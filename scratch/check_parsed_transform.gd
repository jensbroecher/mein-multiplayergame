extends Node

func _ready() -> void:
	var scene := load("res://levels/LakesideLevel.tscn") as PackedScene
	var inst := scene.instantiate()
	var bridge := inst.get_node("LevelDesign/ConcreteFootbridge") as Node3D
	var t: Transform3D = bridge.transform
	print("--- PARSED FROM LakesideLevel.tscn ---")
	print("t.basis.x = ", t.basis.x, " (len = ", t.basis.x.length(), ")")
	print("t.basis.y = ", t.basis.y, " (len = ", t.basis.y.length(), ")")
	print("t.basis.z = ", t.basis.z, " (len = ", t.basis.z.length(), ")")
	print("t.basis.get_scale() = ", t.basis.get_scale())
	print("t.basis.get_rotation_quaternion() = ", t.basis.get_rotation_quaternion())
	print("t.origin = ", t.origin)
	
	for c in bridge.get_children():
		print("Child: ", c.name, " transform: ", c.transform)
		if c is MeshInstance3D:
			print("Mesh AABB: ", c.mesh.get_aabb())

	get_tree().quit(0)
