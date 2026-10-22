@tool
extends SceneTree

func _init() -> void:
	var lvl_scene: PackedScene = load("res://levels/LakesideLevel.tscn")
	var lvl: Node = lvl_scene.instantiate()
	var ramp = lvl.get_node_or_null("Ramps/ConcreteRamp")
	if not ramp:
		print("Ramp not found!")
		quit(1)
		return
	
	var r_pos: Vector3 = ramp.global_position
	print("ConcreteRamp global pos: ", r_pos)
	print("ConcreteRamp global rot (deg): ", ramp.global_rotation_degrees)
	print("ConcreteRamp global scale: ", ramp.scale)
	
	# Check TrackPath
	var track_path: Path3D = lvl.get_node_or_null("TrackPath")
	if track_path and track_path.curve:
		var c := track_path.curve
		var closest_offset := c.get_closest_offset(r_pos)
		var closest_pt := c.sample_baked(closest_offset)
		print("Nearest TrackPath point at offset: ", closest_offset, " pos: ", closest_pt, " dist: ", r_pos.distance_to(closest_pt))
	
	# Check AlternativePaths
	var alt_paths = lvl.get_node_or_null("AlternativePaths")
	if alt_paths:
		for p in alt_paths.get_children():
			if p is Path3D and p.curve:
				var c: Curve3D = p.curve
				var off := c.get_closest_offset(r_pos)
				var pt := c.sample_baked(off)
				print("AlternativePath '", p.name, "' closest dist: ", r_pos.distance_to(pt), " at off: ", off, " / ", c.get_baked_length())

	# Check children of Ramps
	var ramps_node = lvl.get_node_or_null("Ramps")
	if ramps_node:
		for ch in ramps_node.get_children():
			print("Ramps child: ", ch.name, " type: ", ch.get_class(), " pos: ", ch.position)
			
	quit(0)
