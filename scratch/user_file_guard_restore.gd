extends SceneTree
## Puts back the player's files a killed test left aside (scratch/user_file_guard.gd), every tag's or the named ones'.
##   Godot --headless --path . -s res://scratch/user_file_guard_restore.gd [-- tag ...]

const Guard = preload("res://scratch/user_file_guard.gd")


func _init() -> void:
	var tags: Array = Array(OS.get_cmdline_user_args())
	if tags.is_empty():
		tags = Array(Guard.pending())
	if tags.is_empty():
		print("nothing waiting in ", ProjectSettings.globalize_path(Guard.ROOT))
	for t in tags:
		print("%s: %d files put back" % [t, Guard.restore(str(t))])
	quit()
