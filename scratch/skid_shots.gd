extends Node

# Skid marks in a live spectator race: lets the AI race for a while, then looks at the marks they
# laid (SkidMarks.gd) from a few cameras near them, and from straight above one. Windowed:
#   Godot --path . --resolution 1600x900 res://scratch/skid_shots.tscn -- <out_dir> [level=res://...]
#       [wait=40] [shots=4]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var level_path := "res://levels/LakesideLevel.tscn"
	var wait := 40.0
	var shots := 4
	for a in args:
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("wait="):
			wait = float(a.substr(5))
		elif a.begins_with("shots="):
			shots = int(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	Engine.time_scale = 2.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0 / 2.0):
		await get_tree().process_frame
	# Freeze the race so the marks being shot aren't driven over or overwritten (their age runs on).
	Engine.time_scale = 0.0
	var marks: MultiMeshInstance3D = level.get_node_or_null("SkidMarks")
	if marks == null or marks._used == 0:
		print("NO MARKS")
		get_tree().quit()
		return
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 3000.0
	add_child(cam)
	cam.make_current()
	var used: int = marks._used
	print("segments ", used)
	for k in shots:
		# The latest marks, which haven't faded yet.
		var i: int = posmod(marks._next - 1 - k * maxi(1, mini(used, 600) / shots), marks.MAX_SEGMENTS)
		var xf: Transform3D = marks.multimesh.get_instance_transform(i)
		var c: Vector3 = (xf.basis.x + xf.basis.y + xf.basis.z + xf.origin) * 0.25
		var along: Vector3 = (xf.basis.z - xf.basis.x).normalized()
		var side: Vector3 = along.cross(Vector3.UP).normalized()
		for view in [["low", c - along * 7.0 + side * 2.5 + Vector3.UP * 2.2], ["top", c + Vector3.UP * 9.0 + along * 0.01]]:
			cam.global_position = view[1]
			cam.look_at(c, Vector3.UP)
			for f in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/skid_%d_%s.png" % [out_dir, k, view[0]]
			get_viewport().get_texture().get_image().save_png(path)
			print("SHOT ", path, " at ", c)
	get_tree().quit()
