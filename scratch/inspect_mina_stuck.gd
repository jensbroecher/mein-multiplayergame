extends SceneTree
## Prints where Mina del Viento's route is at the distances given (its world position, the road's height there and the
## yaw facing along it), from regenerate_mina.gd's own plan, without building the level: for aiming shots and probes at
## a place a cart got stuck.
##   Godot --headless --path . -s res://scratch/inspect_mina_stuck.gd -- 3436 3804 ...

func _init() -> void:
	var gen = load("res://regenerate_mina.gd").new()
	gen._init_noise()
	gen._solve_route()
	gen._build_profile()
	for a in OS.get_cmdline_user_args():
		var s := float(a)
		var sp: Dictionary = gen._spot(s, 0.0, 0.0)
		print("s=%.0fm pos=%s yaw=%.1f" % [s, sp["pos"], sp["yaw"]])
	gen.free()
	quit(0)
