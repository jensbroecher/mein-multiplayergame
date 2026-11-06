extends SceneTree
func _init():
	var MM = load("res://MusicManager.gd")
	for p in ["res://levels/DesertWadiLevel.tscn", "res://levels/MountainLevel.tscn", "res://levels/RamlatHamraLevel.tscn", "res://levels/MarinaNightsLevel.tscn", "res://levels/MaraCrossingLevel.tscn"]:
		print(p, " -> ", MM._stage_track_key(p.to_lower()))
	var s = load("res://music/al-raihana/Racing_the_Mirage.mp3")
	print("stream: ", s, " length ", s.get_length() if s else -1)
	quit()
