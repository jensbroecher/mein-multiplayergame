extends SceneTree

func _init() -> void:
	var tex = load("res://images/logo_transparent.png") as Texture2D
	if tex:
		print("Loaded logo_transparent.png successfully: size=", tex.get_size())
	else:
		push_error("Failed to load logo_transparent.png")
	quit(0 if tex else 1)

