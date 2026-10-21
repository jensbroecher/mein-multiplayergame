extends SceneTree

func _initialize() -> void:
	var script = load("res://PlayerCart.gd")
	if script != null:
		print("PlayerCart.gd parsed and loaded successfully without error!")
	else:
		printerr("Failed to load PlayerCart.gd!")
	quit()
