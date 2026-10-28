extends SceneTree

func _initialize():
	for path in ["res://sounds/winter_wind_loop.mp3", "res://sounds/blizzard/blizzard_1.wav"]:
		var stream = load(path)
		if stream:
			print(path, " length=", stream.get_length())
	quit()
