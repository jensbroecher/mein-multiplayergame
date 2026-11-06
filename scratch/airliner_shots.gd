extends SceneTree
## Photographs a level's airliners where they are at a held clock (Airliners' clock_override, and the suspended trains'
## and searchlights' if the level has them), after waiting long enough for their shaders to compile (lap_shots shoots
## too soon on a heavy level: new shaders draw nothing until they are ready). Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/airliner_shots.gd -- <level> <dir> clock=<s>
##       name:x,y,z:tx,ty,tz[:fov] ...  (a target of "plane0".."planeN" aims at that flight)
## Prints where every flight is.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node = (load(args[0]) as PackedScene).instantiate()
	var dir: String = args[1]
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	get_root().add_child(level)
	var clk := -1.0
	var shots: Array = []
	for a in args.slice(2):
		if a.begins_with("clock="):
			clk = float(a.substr(6))
		else:
			shots.append(a)
	for n in level.find_children("*", "Node3D", true, false):
		if "clock_override" in n and clk >= 0.0:
			n.set("clock_override", clk)
	for c in level.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.far = 4000.0
	get_root().add_child(cam)
	cam.make_current()
	for i in range(240):
		await process_frame
	var air: Node3D = level.find_child("Airliners", true, false)
	var planes: Array = []
	if air:
		for c in air.get_children():
			if c is Node3D and (c as Node3D).visible:
				planes.append(c)
				print("%s at %s" % [c.name, (c as Node3D).global_position])
	for spec in shots:
		var parts := String(spec).split(":")
		var p := parts[1].split_floats(",")
		var target: Vector3
		if parts[2].begins_with("plane"):
			var idx := int(parts[2].substr(5))
			target = (planes[mini(idx, planes.size() - 1)] as Node3D).global_position if not planes.is_empty() else Vector3.ZERO
		else:
			var t := parts[2].split_floats(",")
			target = Vector3(t[0], t[1], t[2])
		cam.fov = float(parts[3]) if parts.size() > 3 else 50.0
		cam.look_at_from_position(Vector3(p[0], p[1], p[2]), target)
		for i in range(8):
			await process_frame
		var img := get_root().get_texture().get_image()
		var out: String = dir.path_join("%s.png" % parts[0])
		img.save_png(out)
		print("SHOT ", out)
	quit()
