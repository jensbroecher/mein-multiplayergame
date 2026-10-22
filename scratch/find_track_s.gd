@tool
extends SceneTree

func _init() -> void:
	# Parse LakesideLevel.tscn as text to extract TrackPath points and jump info
	var f := FileAccess.open("res://levels/LakesideLevel.tscn", FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	
	# Find TrackPath curve points
	var tp_idx := txt.find('[node name="TrackPath"')
	if tp_idx != -1:
		print("Found TrackPath in LakesideLevel.tscn")
	
	# Find ConcreteRamp transform
	var cr_idx := txt.find('[node name="ConcreteRamp"')
	if cr_idx != -1:
		var end_l := txt.find("\n\n", cr_idx)
		print("ConcreteRamp definition:\n", txt.substr(cr_idx, end_l - cr_idx))

	quit(0)
