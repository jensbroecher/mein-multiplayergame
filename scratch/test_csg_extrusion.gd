extends Node

func _ready() -> void:
	var comb := CSGCombiner3D.new()
	var csg := CSGPolygon3D.new()
	csg.mode = CSGPolygon3D.MODE_DEPTH
	csg.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(2, 0),
		Vector2(2, 1),
		Vector2(0, 1)
	])
	csg.depth = 5.0
	comb.add_child(csg)
	add_child(comb)

	await get_tree().process_frame
	await get_tree().process_frame
	
	var meshes: Array = comb.get_meshes()
	print("Meshes count: ", meshes.size())
	if meshes.size() >= 2:
		var m: Mesh = meshes[1]
		var aabb: AABB = m.get_aabb()
		print("Mesh AABB: ", aabb)
		print("AABB min: ", aabb.position, " max: ", aabb.end)
	get_tree().quit(0)
