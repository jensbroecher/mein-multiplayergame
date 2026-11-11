extends SceneTree

# Photographs scratch/human_lineup.tscn (windowed):
#   Godot --path . --resolution 1600x900 -s res://scratch/human_lineup_shots.gd -- <dir> [time=<s>] [nocar=1]
#       name:x,y,z:tx,ty,tz[:fov] ...
# `time=` lets the clock run that long first (the spectators' bursts take seconds); nocar=1 parks the car.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var wait := 1.0
	var scene: Node3D = (load("res://scratch/human_lineup.tscn") as PackedScene).instantiate()
	for a in args.slice(1):
		if a == "nocar=1":
			scene.set("car_drives", false)
	root.add_child(scene)
	for a in args.slice(1):
		if a.begins_with("time="):
			wait = float(a.substr(5))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		await process_frame
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	for a in args.slice(1):
		if not ":" in a:
			continue
		var parts := (a as String).split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 60.0
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, parts[0]])
		print("SHOT ", parts[0])
	quit()
