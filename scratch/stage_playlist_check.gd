extends Node
# Prints the playlist MusicManager picks for each stage (MusicManager.load_playlist_for_level). Headless:
#   Godot --headless --path . res://scratch/stage_playlist_check.tscn [-- res://levels/X.tscn ...]


func _ready() -> void:
	var levels: Array = OS.get_cmdline_user_args()
	if levels.is_empty():
		levels = ["res://levels/MinaLevel.tscn", "res://levels/CanyonLevel.tscn", "res://levels/FreightLevel.tscn",
			"res://levels/NyotaStadiumLevel.tscn", "res://levels/BloombayDunesLevel.tscn"]
	for l in levels:
		MusicManager.load_playlist_for_level(l)
		var names: Array = MusicManager.playlist.map(func(p: String) -> String: return p.get_file())
		print("PLAYLIST %s: %s" % [String(l).get_file(), ", ".join(names)])
	get_tree().quit()
