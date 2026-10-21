extends SceneTree

# Renders a camera view of a level's sky to a PNG.
# Usage: Godot --path . --resolution 960x540 -s res://scratch/render_sky_shot.gd [-- [level=res://levels/LakesideLevel.tscn] [out=sky.png] [pitch=30]]

func _init():
	var level_path := "res://levels/LakesideLevel.tscn"
	var out_path := "res://scratch/sky_shot.png"
	var pitch := 30.0

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("level="):
			level_path = arg.substr(6)
		elif arg.begins_with("out="):
			out_path = arg.substr(4)
		elif arg.begins_with("pitch="):
			pitch = float(arg.substr(6))

	var root = SubViewport.new()
	root.size = Vector2i(960, 540)
	root.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(root)

	var scene = load(level_path).instantiate()
	root.add_child(scene)

	var cam = Camera3D.new()
	cam.position = Vector3(0, 10, 0)
	cam.rotation_degrees = Vector3(pitch, 0, 0)
	cam.fov = 70.0
	cam.far = 4000.0
	root.add_child(cam)
	cam.make_current()

	for i in range(10):
		await process_frame

	var img = root.get_texture().get_image()
	img.save_png(out_path)
	print("Saved %s" % out_path)
	quit()
