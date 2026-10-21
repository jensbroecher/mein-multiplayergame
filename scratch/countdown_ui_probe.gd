extends SceneTree

func _initialize() -> void:
	var race_ui = load("res://RaceUI.tscn").instantiate()
	root.add_child(race_ui)
	await process_frame
	await process_frame
	
	var ec = race_ui.get_node("EndCountdown")
	var hbox = ec.get_node("HBoxContainer")
	var ending = hbox.get_node("LabelEnding")
	var count = hbox.get_node("LabelCount")
	var unit = hbox.get_node_or_null("LabelUnit")
	
	print("EndCountdown size: ", ec.size)
	print("HBoxContainer size: ", hbox.size)
	print("LabelEnding size: ", ending.size, " text: ", ending.text)
	print("LabelCount size: ", count.size, " min_size: ", count.custom_minimum_size, " align: ", count.horizontal_alignment)
	if unit:
		print("LabelUnit size: ", unit.size, " text: ", unit.text)
	
	quit()
