extends SceneTree

func _initialize():
	var dir := "/Users/jensbrocher/.gemini/antigravity-ide/brain/fafee246-b7a8-4be6-99b6-20f826dde6c7"
	var packed: PackedScene = load("res://levels/CanyonChasmLevel.tscn")
	var level: Node3D = packed.instantiate()
	root.add_child(level)

	for i in 10:
		await process_frame

	var tornado := level.get_node_or_null("Tornado")
	if tornado == null:
		print("Tornado not found!")
		quit()
		return

	print("Tornado at: ", tornado.global_position, " scale: ", tornado.scale)

	# Place camera on the track looking at the tornado, matching the classic shot angle
	var cam := Camera3D.new()
	cam.fov = 68.0
	level.add_child(cam)
	cam.current = true

	# Nearest track point was around (-194.5, 15.4, -16.8), tornado is at (-190.1, 16.0, -14.2)
	# Position camera along the approach road looking towards tornado
	cam.position = Vector3(-160.0, 20.5, 32.0)
	cam.look_at(tornado.global_position + Vector3(0, 12.0, 0))

	for i in 35:
		await process_frame

	var img := root.get_texture().get_image()
	if img:
		img.save_png("%s/tornado_in_canyon_chasm.png" % dir)
		print("Saved tornado_in_canyon_chasm.png")
	else:
		print("Image null")

	quit()
