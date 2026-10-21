extends SceneTree

func _initialize() -> void:
	var race_ui = load("res://RaceUI.tscn").instantiate()
	root.add_child(race_ui)
	
	var ec = race_ui.get_node("EndCountdown")
	ec.visible = true
	var hbox = ec.get_node("HBoxContainer")
	var ending = hbox.get_node("LabelEnding")
	var count = hbox.get_node("LabelCount")
	var unit = hbox.get_node_or_null("LabelUnit")
	if unit:
		unit.queue_free()
	
	await process_frame
	await process_frame
	
	print("--- Without LabelUnit (current count.align = ", count.horizontal_alignment, ") ---")
	print("ec.size: ", ec.size, " hbox.size: ", hbox.size)
	print("ending.pos: ", ending.position, " ending.size: ", ending.size)
	print("count.pos: ", count.position, " count.size: ", count.size)
	
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await process_frame
	print("--- With count.align = CENTER ---")
	print("count.pos: ", count.position, " count.size: ", count.size)
	
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	await process_frame
	print("--- With count.align = LEFT ---")
	print("count.pos: ", count.position, " count.size: ", count.size)
	
	quit()
