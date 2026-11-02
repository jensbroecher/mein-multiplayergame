extends SceneTree

func _init() -> void:
	var root_node = Node3D.new()
	var body = StaticBody3D.new()
	body.name = "TestBody"
	root_node.add_child(body)
	
	# 1. Via create_shape_owner
	var oid = body.create_shape_owner(body)
	var shape1 = BoxShape3D.new()
	body.shape_owner_add_shape(oid, shape1)
	
	# 2. Via CollisionShape3D child node
	var cs = CollisionShape3D.new()
	cs.name = "ChildShape"
	cs.shape = BoxShape3D.new()
	body.add_child(cs)
	
	body.owner = root_node
	cs.owner = root_node
	
	var ps = PackedScene.new()
	ps.pack(root_node)
	var inst = ps.instantiate()
	var inst_body = inst.get_node("TestBody")
	print("Packed body child count: ", inst_body.get_child_count())
	print("Packed body shape owners count: ", inst_body.get_shape_owners().size())
	print("Child shape node: ", inst_body.get_node_or_null("ChildShape"))
	quit()

