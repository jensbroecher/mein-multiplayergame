extends SceneTree
## Parse-checks scripts without running them (headless): Godot --headless --path . -s res://scratch/parse_check.gd -- res://a.gd ...
## A generator scene whose script fails to parse sits idle instead of quitting, so check a new or changed one first.
func _init() -> void:
	for p in OS.get_cmdline_user_args():
		var s: Script = load(p)
		print("PARSE ", p, " ", "ok" if s != null and s.can_instantiate() else "FAILED")
	quit()
