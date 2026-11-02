extends SceneTree

func _init() -> void:
	var level_scene: PackedScene = load("res://levels/FreightLevel.tscn")
	var root: Node = level_scene.instantiate()
	
	# Add to SceneTree root so physics and inside-tree checks succeed
	get_root().add_child(root)
	
	var dc_script = load("res://DressingColliders.gd")
	var dc = Node.new()
	dc.set_script(dc_script)
	root.add_child(dc)
	dc.build(root)
	
	print("\n=== VERIFYING BUFFER STOPS ===")
	var buffer_stops = root.find_children("BufferStop*", "", true, false)
	print("Found BufferStops: ", buffer_stops.size())
	for bs in buffer_stops:
		var bodies = bs.find_children("*Body*", "StaticBody3D", true, false)
		print("  ", bs.name, " pos: ", bs.global_position, " bodies: ", bodies.size())
		for b in bodies:
			var shapes = b.find_children("*", "CollisionShape3D", true, false)
			print("    body: ", b.name, " shapes: ", shapes.size())
			for s in shapes:
				print("      shape: ", s.shape.get_class())
	
	print("\n=== VERIFYING RAIL CROSSING GATE POSTS ===")
	var crossings = root.find_children("RailCrossing*", "", true, false)
	print("Found Crossings: ", crossings.size())
	for c in crossings:
		c._ready()
		var masts = c.find_children("Mast*", "Node3D", false, false)
		print("  ", c.name, " masts: ", masts.size())
		for m in masts:
			var col = m.find_children("*", "CollisionShape3D", true, false)
			print("    ", m.name, " collision shapes: ", col.size())
			for s in col:
				print("      shape: ", s.shape.get_class(), " pos: ", s.position)

	print("\n=== VERIFYING TELEGRAPH POLES ===")
	var poles = root.find_child("TelegraphPoles", true, false)
	if poles:
		var pole_solid_count := 0
		for owned in dc._owned:
			if owned[0] == poles:
				for o in owned[1]:
					if o != null:
						pole_solid_count += 1
		print("TelegraphPoles total instances: ", poles.multimesh.instance_count, " solid colliders: ", pole_solid_count)

	print("\n=== VERIFYING SAGEBRUSH ===")
	var sage_mmi_count := 0
	var sage_inst_count := 0
	var sage_wobble_count := 0
	for mm in root.find_children("Sagebrush*", "MultiMeshInstance3D", true, false):
		sage_mmi_count += 1
		sage_inst_count += mm.multimesh.instance_count
	
	print("Sagebrush MultiMeshes: ", sage_mmi_count, " total instances: ", sage_inst_count)
	print("Total DressingColliders shapes made: ", dc.shapes_made)
	print("Total wobbling plants: ", dc._wobble.size())
	
	quit()

