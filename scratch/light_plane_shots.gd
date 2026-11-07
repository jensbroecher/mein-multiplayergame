extends SceneTree
## Photographs a level's LightPlane (node "Rundflug") where the wall clock has it: from beside it (`near`), from a little
## behind and above (`chase`) and from the ground on the lap's nearest point looking up (`ground`), and prints where it
## is and how high over the lap. The level's own scripts that need the game's autoloads fail to compile here; its meshes
## still draw. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/light_plane_shots.gd -- <level.tscn> <dir> [wait=1.0]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var dir: String = args[1]
	var wait := 1.0
	for a in args.slice(2):
		if a.begins_with("wait="):
			wait = float(a.substr(5))
	DirAccess.make_dir_recursive_absolute(dir)
	var level: Node3D = (load(level_path) as PackedScene).instantiate()
	get_root().add_child(level)
	var cam := Camera3D.new()
	cam.far = 4000.0
	get_root().add_child(cam)
	cam.current = true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		await process_frame
	var plane: Node3D = level.get_node_or_null("Rundflug")
	if plane == null:
		print("no Rundflug in ", level_path)
		quit(1)
		return
	var path: Path3D = level.get_node_or_null("TrackPath")
	var shots := ["near", "chase", "ground"]
	for sh in shots:
		for f in 3:
			await process_frame
		var xf: Transform3D = plane.global_transform
		var fwd: Vector3 = -xf.basis.z.normalized()
		var p: Vector3 = xf.origin
		match sh:
			"near":
				cam.fov = 40.0
				cam.look_at_from_position(p + xf.basis.x.normalized() * 30.0 + fwd * 10.0 + Vector3(0, 4, 0), p)
			"chase":
				cam.fov = 50.0
				cam.look_at_from_position(p - fwd * 45.0 + Vector3(0, 12, 0), p + fwd * 30.0)
			"ground":
				var g: Vector3 = p
				if path:
					var off: float = path.curve.get_closest_offset(path.to_local(p))
					g = path.to_global(path.curve.sample_baked(off)) + Vector3(0, 2.0, 0)
				cam.fov = 55.0
				cam.look_at_from_position(g, p)
				print("plane at %s, %.0fm over the lap's nearest point %s, %.0fm away in plan" % [p, p.y - g.y, g, Vector2(p.x - g.x, p.z - g.z).length()])
		for f in 3:
			await process_frame
		get_root().get_texture().get_image().save_png(dir.path_join(sh + ".png"))
		print("SHOT ", sh)
	quit()
