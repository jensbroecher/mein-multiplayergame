extends SceneTree
func _init():
	var gen = load("res://regenerate_glacier_highway.gd").new()
	root.add_child(gen)
