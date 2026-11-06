extends SceneTree
func _init():
	var args := OS.get_cmdline_user_args()
	var level: Node = (load(args[0]) as PackedScene).instantiate()
	var c: Curve3D = (level.get_node("TrackPath") as Path3D).curve
	var L := c.get_baked_length()
	var s := 0.0
	while s < L:
		var p := c.sample_baked(s)
		print("s=%5d  x=%7.1f y=%6.1f z=%7.1f" % [s, p.x, p.y, p.z])
		s += float(args[1]) if args.size() > 1 else 100.0
	for n in ["FinishLine"]:
		var f = level.get_node_or_null(n)
		if f: print(n, " ", f.position)
	for cp in level.get_node("Checkpoints").get_children():
		print(cp.name, " ", cp.position)
	quit()
