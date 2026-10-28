extends SceneTree
## Renders LargeHouse and House inside CanyonChasmLevel.tscn from the road and from 3/4 overview angles.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "."
	var suffix := ("_" + args[1]) if args.size() > 1 else ""

	var lvl: Node3D = (load("res://levels/CanyonChasmLevel.tscn") as PackedScene).instantiate()
	root.add_child(lvl)
	for i in 10:
		await process_frame

	var cam := Camera3D.new()
	cam.fov = 60.0
	lvl.add_child(cam)
	cam.current = true

	var lh: Node3D = lvl.get_node_or_null("LargeHouse")
	var h: Node3D = lvl.get_node_or_null("House")

	var shots := []
	if lh:
		var p := lh.global_position
		shots.append(["level_large_house_road" + suffix, Vector3(92.0, 24.5, -178.0), p + Vector3(0, 6.0, 0)])
		shots.append(["level_large_house_3q" + suffix, p + Vector3(32.0, 18.0, 34.0), p + Vector3(0, 6.0, 0)])
	if h:
		var p := h.global_position
		shots.append(["level_house_road" + suffix, Vector3(41.0, 42.5, -118.0), p + Vector3(0, 10.0, 0)])
		shots.append(["level_house_3q" + suffix, p + Vector3(26.0, 18.0, 28.0), p + Vector3(0, 10.0, 0)])

	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		for i in 25:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, s[0]])
		print("Saved %s/%s.png" % [out_dir, s[0]])

	quit()
