extends SceneTree

func _init() -> void:
	print("cmdline user args: ", OS.get_cmdline_user_args())
	print("rebake in args? ", "rebake" in OS.get_cmdline_user_args())
	quit(0)
