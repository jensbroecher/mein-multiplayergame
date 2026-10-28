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
		# New CasitaHouse & warm desert sky on graded hill pad
		["casita_house_closeup", Vector3(-196.0, 17.5, 54.0), Vector3(-226.5, 17.5, 65.0)],
		["casita_house_side1", Vector3(-206.0, 26.0, 44.0), Vector3(-226.5, 16.5, 65.0)],
		["casita_house_side2", Vector3(-206.0, 26.0, 86.0), Vector3(-226.5, 16.5, 65.0)],
		# Chasm water and 3D sandstone cliffs from multiple angles
		["chasm_water_north", Vector3(135.0, 22.0, -56.0), Vector3(162.0, -1.0, -108.0)],
		["chasm_water_south", Vector3(165.0, 20.0, -105.0), Vector3(138.0, 2.0, -55.0)],
		["chasm_water_east", Vector3(172.0, 18.0, -82.0), Vector3(124.0, 2.0, -82.0)],
		["chasm_water_west", Vector3(128.0, 18.0, -82.0), Vector3(176.0, 2.0, -82.0)],
		# Rebuilt CSG Windmill (platform, ladder & blades clearance)
		["windmill_platform", Vector3(-83.0, 36.5, -135.0), Vector3(-92.5, 31.5, -127.0)],
		["windmill_front", Vector3(-72.0, 28.0, -140.0), Vector3(-92.0, 31.0, -127.0)],
		# Rebuilt CSG Barriers at crossing jump & ramp side walls
		["barriers_jump", Vector3(52.0, 43.8, -116.0), Vector3(36.0, 41.5, -100.0)],
		["ramp_side_view", Vector3(58.0, 31.0, -96.0), Vector3(38.0, 33.0, -106.0)],
	]

	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		for i in 20:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, s[0]])
		print("Saved %s/%s.png" % [out_dir, s[0]])

	quit()
