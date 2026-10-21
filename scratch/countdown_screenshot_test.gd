extends SceneTree

func _initialize() -> void:
	var race_ui = load("res://RaceUI.tscn").instantiate()
	root.add_child(race_ui)
	
	var ec = race_ui.get_node("EndCountdown")
	ec.visible = true
	var hbox = ec.get_node("HBoxContainer")
	var count = hbox.get_node("LabelCount")
	var unit = hbox.get_node_or_null("LabelUnit")
	
	# Let's test with unit removed
	if unit:
		unit.queue_free()
	
	await process_frame
	await process_frame
	
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("res://scratch/countdown_current.png")
	print("Saved countdown_current.png, ec size: ", ec.size, " count pos: ", count.position, " count size: ", count.size)
	
	quit()
