extends SceneTree

func _initialize():
	var packed: PackedScene = load("res://levels/CanyonChasmLevel.tscn")
	var level = packed.instantiate()
	root.add_child(level)
	for i in 3:
		await process_frame
	
	var tornado = level.get_node_or_null("Tornado")
	if tornado:
		print("Tornado global_position: ", tornado.global_position)
		print("Tornado scale: ", tornado.scale)
	
	var track = level.get_node_or_null("TrackPath")
	if track and tornado:
		var curve: Curve3D = track.curve
		if curve:
			var nearest_offset = curve.get_closest_offset(tornado.global_position)
			var nearest_pt = curve.sample_baked(nearest_offset)
			print("Nearest track point: ", nearest_pt, " offset: ", nearest_offset, " distance: ", tornado.global_position.distance_to(nearest_pt))
	
	# Take a screenshot from track looking at Tornado
	var cam = Camera3D.new()
	level.add_child(cam)
	cam.current = true
	if tornado:
		cam.position = tornado.global_position + Vector3(45, 12, 45)
		cam.look_at(tornado.global_position + Vector3(0, 10, 0))
		for i in 45:
			await process_frame
		root.get_texture().get_image().save_png("/Users/jensbrocher/.gemini/antigravity-ide/brain/fafee246-b7a8-4be6-99b6-20f826dde6c7/tornado_in_level_improved.png")
	
	quit()
