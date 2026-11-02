extends SceneTree

func _init() -> void:
	var root_node = Node3D.new()
	var body = StaticBody3D.new()
	body.name = "BouldersBody"
	root_node.add_child(body)
	body.owner = root_node
	
	var hull = ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array([
		Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1),
		Vector3(0, 2, 0)
	])
	
	var cs = CollisionShape3D.new()
	cs.name = "Boulder_0"
	cs.shape = hull
	cs.position = Vector3(10, 0, 10)
	body.add_child(cs)
	cs.owner = root_node
		
	var ps = PackedScene.new()
	ps.pack(root_node)
	
	var inst = ps.instantiate()
	var inst_body = inst.get_node("BouldersBody")
	var inst_cs = inst_body.get_node("Boulder_0") as CollisionShape3D
	var inst_hull = inst_cs.shape as ConvexPolygonShape3D
	print("Instantiated hull points count: ", inst_hull.points.size())
	print("Instantiated hull pt 0: ", inst_hull.points[0])
	quit()

