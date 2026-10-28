extends SceneTree
## Windowed probe: renders CasitaHouse, rebuilt Windmill, rebuilt Barriers, ChasmPitWater/cliffs, sky, and desert flora.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "scratch/shots_inspect"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var lvl: Node3D = (load("res://levels/CanyonChasmLevel.tscn") as PackedScene).instantiate()
	root.add_child(lvl)
	for i in 12:
		await process_frame

	var cam := Camera3D.new()
	cam.fov = 60.0
	lvl.add_child(cam)
	cam.current = true

	var shots := [
		# New CasitaHouse & warm desert sky
		["casita_house_closeup", Vector3(-196.0, 22.0, 54.0), Vector3(-227.5, 22.5, 65.0)],
		["casita_house_road", Vector3(-196.0, 17.5, 22.0), Vector3(-218.0, 21.0, 80.0)],
		# Chasm water and 3D sandstone cliffs from multiple angles
		["chasm_water_north", Vector3(135.0, 22.0, -56.0), Vector3(162.0, -1.0, -108.0)],
		["chasm_water_south", Vector3(165.0, 20.0, -105.0), Vector3(138.0, 2.0, -55.0)],
		["chasm_water_east", Vector3(172.0, 18.0, -82.0), Vector3(124.0, 2.0, -82.0)],
		["chasm_water_west", Vector3(128.0, 18.0, -82.0), Vector3(176.0, 2.0, -82.0)],
		# Rebuilt CSG Windmill
		["windmill_3q1", Vector3(-68.0, 29.0, -105.0), Vector3(-92.0, 31.0, -127.0)],
		["windmill_front", Vector3(-72.0, 28.0, -140.0), Vector3(-92.0, 31.0, -127.0)],
		# Rebuilt CSG Barriers at crossing jump
		["barriers_jump", Vector3(56.0, 44.0, -120.0), Vector3(36.0, 41.5, -101.0)],
		# Track overview shots showing sky, houses & scattered desert flora/rocks
		["track_start", Vector3(0.0, 12.0, 185.0), Vector3(0.0, 10.0, 60.0)],
		["track_houses_vista", Vector3(45.0, 28.0, -185.0), Vector3(88.0, 26.0, -225.0)],
	]

	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		for i in 20:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, s[0]])
		print("Saved %s/%s.png" % [out_dir, s[0]])

	quit()
