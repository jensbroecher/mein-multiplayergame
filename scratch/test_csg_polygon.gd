@tool
extends SceneTree

func _init() -> void:
	var poly := CSGPolygon3D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(10, 0),
		Vector2(10, 5),
		Vector2(0, 5)
	])
	poly.mode = CSGPolygon3D.MODE_DEPTH
	poly.depth = 6.0
	var combiner := CSGCombiner3D.new()
	combiner.add_child(poly)
	root.add_child(combiner)
	
	for i in range(2):
		await process_frame
		
	var aabb: AABB = combiner.get_meshes()[1].get_aabb() if combiner.get_meshes().size() > 1 else AABB()
	print("Extruded depth = 6.0:")
	print("Combiner meshes count: ", combiner.get_meshes().size())
	if combiner.get_meshes().size() > 1:
		print("Mesh AABB: pos=", aabb.position, " size=", aabb.size)
	quit(0)
