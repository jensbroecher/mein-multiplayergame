extends SceneTree

func _init() -> void:
	var level_scene: PackedScene = load("res://levels/FreightLevel.tscn")
	var root: Node = level_scene.instantiate()
	
	print("--- INSPECTING BUFFERS & TRACK STOPS ---")
	var buffers: Array = root.find_children("BufferStop*", "", true, false)
	print("Found buffer stops: ", buffers.size())
	for b in buffers:
		print("  Buffer: ", b.name, " class: ", b.get_class(), " path: ", root.get_path_to(b), " parent: ", b.get_parent().name)
		var children: Array = b.get_children()
		print("    children: ", children.size())
		for ch in children:
			print("      ch: ", ch.name, " class: ", ch.get_class())

	print("--- INSPECTING RAIL CROSSINGS ---")
	var crossings: Array = root.find_children("RailCrossing*", "", true, false)
	print("Found crossings: ", crossings.size())
	for c in crossings:
		print("  Crossing: ", c.name, " path: ", root.get_path_to(c))
		# If it runs _ready, it creates internal children Mast0, Mast1
		c._ready()
		var internal_children = c.get_children(true)
		print("    Crossing children (inc internal): ", internal_children.size())
		for ch in internal_children:
			print("      ch: ", ch.name, " class: ", ch.get_class(), " pos: ", ch.position)
			for gch in ch.get_children(true):
				print("        subch: ", gch.name, " class: ", gch.get_class())

	print("--- INSPECTING TELEGRAPH POLES ---")
	var poles: Array = root.find_children("*pole*", "", true, false)
	for p in poles:
		print("  Pole node: ", p.name, " class: ", p.get_class(), " path: ", root.get_path_to(p))
		if p is MultiMeshInstance3D:
			print("    instance_count: ", p.multimesh.instance_count)
			print("    mesh: ", p.multimesh.mesh)
			print("    aabb: ", p.multimesh.mesh.get_aabb())

	print("--- INSPECTING OTHER MASTS / SIGNS ---")
	var masts: Array = root.find_children("*mast*", "", true, false)
	for m in masts:
		print("  Mast node: ", m.name, " class: ", m.get_class(), " path: ", root.get_path_to(m))

	var signs: Array = root.find_children("*Sign*", "", true, false)
	for s in signs:
		print("  Sign node: ", s.name, " class: ", s.get_class(), " path: ", root.get_path_to(s))

	quit()

