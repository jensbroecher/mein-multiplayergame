extends SceneTree

func _init() -> void:
	var level_scene: PackedScene = load("res://levels/FreightLevel.tscn")
	var root: Node = level_scene.instantiate()
	var dc_script = load("res://DressingColliders.gd")
	var dc = Node.new()
	dc.set_script(dc_script)
	root.add_child(dc)
	dc.build(root)
	
	var poles = root.find_child("TelegraphPoles", true, false)
	print("Poles node: ", poles)
	if poles:
		var info = dc._mesh_shape(poles.multimesh.mesh)
		print("Poles mesh shape info: ", info)
		print("Poles soft: ", dc._soft(poles))
	
	# Check if any pole position collides or has a shape owner
	print("Shapes made: ", dc.shapes_made)
	for owned_entry in dc._owned:
		if owned_entry[0] == poles:
			print("Found poles in dc._owned! Count: ", owned_entry[1].size())
			var null_count := 0
			var solid_count := 0
			for o in owned_entry[1]:
				if o == null:
					null_count += 1
				else:
					solid_count += 1
			print("Poles solid: ", solid_count, " null: ", null_count)
			break

	quit()

