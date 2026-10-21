extends SceneTree

func _initialize() -> void:
	var race_ui = load("res://RaceUI.tscn").instantiate()
	root.add_child(race_ui)
	
	var ec = race_ui.get_node("EndCountdown")
	ec.visible = true
	var hbox = ec.get_node("HBoxContainer")
	var unit = hbox.get_node_or_null("LabelUnit")
	if unit:
		unit.queue_free()
	
	var count = hbox.get_node("LabelCount")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.custom_minimum_size = Vector2(80, 0)
	
	await process_frame
	await process_frame
	
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("res://scratch/countdown_no_s.png")
		print("Successfully saved countdown_no_s.png!")
	else:
		print("Image was null")
	
	quit()
