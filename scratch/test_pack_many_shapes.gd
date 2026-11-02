extends SceneTree

func _init() -> void:
	var root_node = Node3D.new()
	var body = StaticBody3D.new()
	body.name = "BouldersBody"
	root_node.add_child(body)
	body.owner = root_node
	
	var box = BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	
	for i in 150:
		var cs = CollisionShape3D.new()
		cs.name = "Boulder_%d" % i
		cs.shape = box
		cs.position = Vector3(i * 3.0, 0, 0)
		body.add_child(cs)
		cs.owner = root_node
		
	var ps = PackedScene.new()
	var t0 = Time.get_ticks_msec()
	ps.pack(root_node)
	var t1 = Time.get_ticks_msec()
	print("Packing 150 CollisionShape3Ds took %d ms" % [t1 - t0])
	
	var inst = ps.instantiate()
	var inst_body = inst.get_node("BouldersBody")
	print("Instantiated child count: %d" % inst_body.get_child_count())
	print("Instantiated shape owners: %d" % inst_body.get_shape_owners().size())
	quit()

