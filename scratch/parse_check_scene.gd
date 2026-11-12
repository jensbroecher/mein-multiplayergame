extends Node
## Parse-checks scripts that use the autoloads (NetworkManager, MusicManager...), which `-s res://scratch/parse_check.gd`
## can't load: Godot --headless --path . res://scratch/parse_check_scene.tscn -- res://a.gd ...
func _ready() -> void:
	for p in OS.get_cmdline_user_args():
		var s: Script = load(p)
		print("PARSE ", p, " ", "ok" if s != null and s.can_instantiate() else "FAILED")
	get_tree().quit()
