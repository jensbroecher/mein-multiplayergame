extends Node

func _ready() -> void:
	print("--- TESTING LAKESIDE LEVEL LOAD WITH CSG RAMP & CSG FOOTBRIDGE ---")
	var lvl_scene := load("res://levels/LakesideLevel.tscn") as PackedScene
	if not lvl_scene:
		printerr("FAILED: Could not load LakesideLevel.tscn")
		get_tree().quit(1)
		return
		
	var lvl: Node = lvl_scene.instantiate()
	if not lvl:
		printerr("FAILED: Could not instantiate LakesideLevel.tscn")
		get_tree().quit(1)
		return
		
	add_child(lvl)
	
	# Test ConcreteRamp
	var ramp := lvl.get_node_or_null("Ramps/ConcreteRamp")
	if not ramp:
		printerr("FAILED: Ramps/ConcreteRamp not found!")
		get_tree().quit(1)
		return
		
	print("ConcreteRamp found: ", ramp.get_class())
	print("ConcreteRamp scale: ", ramp.scale)
	var ramp_comb := ramp.get_node_or_null("CSGCombiner3D") as CSGCombiner3D
	if not ramp_comb or not ramp_comb.use_collision:
		printerr("FAILED: ConcreteRamp CSGCombiner3D missing or use_collision is false!")
		get_tree().quit(1)
		return

	# Test ConcreteFootbridge
	var bridge := lvl.get_node_or_null("LevelDesign/ConcreteFootbridge")
	if not bridge:
		printerr("FAILED: LevelDesign/ConcreteFootbridge not found!")
		get_tree().quit(1)
		return
		
	print("ConcreteFootbridge found: ", bridge.get_class())
	print("ConcreteFootbridge position: ", bridge.global_position)
	print("ConcreteFootbridge scale: ", bridge.scale)
	print("ConcreteFootbridge rotation (deg): ", bridge.global_rotation_degrees)
	
	if (bridge.scale - Vector3.ONE).length() > 0.01:
		printerr("FAILED: ConcreteFootbridge scale is not normalized 1.0! Scale: ", bridge.scale)
		get_tree().quit(1)
		return
		
	var bridge_comb := bridge.get_node_or_null("CSGCombiner3D") as CSGCombiner3D
	if not bridge_comb or not bridge_comb.use_collision:
		printerr("FAILED: ConcreteFootbridge CSGCombiner3D missing or use_collision is false!")
		get_tree().quit(1)
		return
		
	print("ConcreteFootbridge CSGCombiner3D children:")
	for c in bridge_comb.get_children():
		print("  - ", c.name, " (", c.get_class(), ")")
		
	print("SUCCESS: LakesideLevel loaded cleanly with both CSG ConcreteRamp and CSG ConcreteFootbridge!")
	get_tree().quit(0)
