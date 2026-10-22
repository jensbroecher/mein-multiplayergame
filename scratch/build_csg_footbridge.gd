extends Node

func _ready() -> void:
	print("--- BUILDING REFINED CSG CONCRETE FOOTBRIDGE ---")
	
	var mat: Material = load("res://ConcreteFootbridge_material.tres")
	
	var root := Node3D.new()
	root.name = "ConcreteFootbridge"
	
	var combiner := CSGCombiner3D.new()
	combiner.name = "CSGCombiner3D"
	combiner.use_collision = true
	root.add_child(combiner)
	combiner.owner = root
	
	# Polygons:
	# 1. Deck profile in XY (spans X in [-25.8, +25.8], deck surface at Y=8.25 in center, 0.0 at landings)
	var deck_poly := PackedVector2Array([
		Vector2(-25.8, -1.2),
		Vector2(-25.8, 0.0),
		Vector2(-23.5, 0.0),
		Vector2(-10.6, 8.25),
		Vector2(10.6, 8.25),
		Vector2(23.5, 0.0),
		Vector2(25.8, 0.0),
		Vector2(25.8, -1.2),
		Vector2(17.8, -1.2),
		Vector2(17.8, 0.0),
		Vector2(10.6, 4.96),
		Vector2(-10.6, 4.96),
		Vector2(-17.8, 0.0),
		Vector2(-17.8, -1.2),
	])
	
	# 2. Parapet profile in XY (parapet wall top at Y=10.60 in center, 0.73 at ends)
	var parapet_poly := PackedVector2Array([
		Vector2(-25.8, -1.2),
		Vector2(-25.8, 0.73),
		Vector2(-10.6, 10.60),
		Vector2(10.6, 10.60),
		Vector2(25.8, 0.73),
		Vector2(25.8, -1.2),
		Vector2(17.8, -1.2),
		Vector2(17.8, 0.0),
		Vector2(10.6, 4.96),
		Vector2(-10.6, 4.96),
		Vector2(-17.8, 0.0),
		Vector2(-17.8, -1.2),
	])

	# 3. Parapet Coping / Cornice profile (slight overhang rim along the top of the outer parapet)
	var coping_poly := PackedVector2Array([
		Vector2(-25.8, 0.40),
		Vector2(-25.8, 0.75),
		Vector2(-10.6, 10.62),
		Vector2(10.6, 10.62),
		Vector2(25.8, 0.75),
		Vector2(25.8, 0.40),
		Vector2(10.6, 10.25),
		Vector2(-10.6, 10.25),
	])
	
	# Walkway Deck: extruded along Z across [-3.55, 3.55] (depth 7.1, starts at Z=3.55)
	var deck := CSGPolygon3D.new()
	deck.name = "WalkwayDeck"
	deck.use_collision = true
	deck.mode = CSGPolygon3D.MODE_DEPTH
	deck.depth = 7.1
	deck.position = Vector3(0, 0, 3.55)
	deck.polygon = deck_poly
	deck.material = mat
	combiner.add_child(deck)
	deck.owner = root
	
	# Left Parapet: extruded along Z across [-4.80, -3.55] (depth 1.25, starts at Z=-3.55)
	var left_parapet := CSGPolygon3D.new()
	left_parapet.name = "LeftParapet"
	left_parapet.use_collision = true
	left_parapet.mode = CSGPolygon3D.MODE_DEPTH
	left_parapet.depth = 1.25
	left_parapet.position = Vector3(0, 0, -3.55)
	left_parapet.polygon = parapet_poly
	left_parapet.material = mat
	combiner.add_child(left_parapet)
	left_parapet.owner = root
	
	# Right Parapet: extruded along Z across [3.55, 4.80] (depth 1.25, starts at Z=4.80)
	var right_parapet := CSGPolygon3D.new()
	right_parapet.name = "RightParapet"
	right_parapet.use_collision = true
	right_parapet.mode = CSGPolygon3D.MODE_DEPTH
	right_parapet.depth = 1.25
	right_parapet.position = Vector3(0, 0, 4.80)
	right_parapet.polygon = parapet_poly
	right_parapet.material = mat
	combiner.add_child(right_parapet)
	right_parapet.owner = root

	# Left Coping (outer parapet top rim overhang)
	var left_coping := CSGPolygon3D.new()
	left_coping.name = "LeftCoping"
	left_coping.use_collision = true
	left_coping.mode = CSGPolygon3D.MODE_DEPTH
	left_coping.depth = 0.15
	left_coping.position = Vector3(0, 0, -4.80)
	left_coping.polygon = coping_poly
	left_coping.material = mat
	combiner.add_child(left_coping)
	left_coping.owner = root

	# Right Coping (outer parapet top rim overhang)
	var right_coping := CSGPolygon3D.new()
	right_coping.name = "RightCoping"
	right_coping.use_collision = true
	right_coping.mode = CSGPolygon3D.MODE_DEPTH
	right_coping.depth = 0.15
	right_coping.position = Vector3(0, 0, 4.95)
	right_coping.polygon = coping_poly
	right_coping.material = mat
	combiner.add_child(right_coping)
	right_coping.owner = root

	# Center Span Girder Band (subtle horizontal fascia along the central span under-soffit)
	# Spans X in [-10.8, 10.8], Y in [4.86, 5.25], projecting out slightly on sides
	for side_sign in [-1.0, 1.0]:
		var girder := CSGBox3D.new()
		girder.name = "GirderBand_%s" % ("Left" if side_sign < 0 else "Right")
		girder.use_collision = true
		girder.size = Vector3(21.6, 0.45, 0.12)
		girder.position = Vector3(0, 5.15, side_sign * 4.84)
		girder.material = mat
		combiner.add_child(girder)
		girder.owner = root

	var packed_scene := PackedScene.new()
	var err := packed_scene.pack(root)
	if err != OK:
		print("Error packing scene: ", err)
		get_tree().quit(1)
		return
		
	err = ResourceSaver.save(packed_scene, "res://ConcreteFootbridge.tscn")
	if err != OK:
		print("Error saving res://ConcreteFootbridge.tscn: ", err)
		get_tree().quit(1)
		return
		
	print("Successfully generated refined res://ConcreteFootbridge.tscn!")
	get_tree().quit(0)
