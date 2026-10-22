extends Node

func _ready() -> void:
	var lvl_scene := load("res://levels/LakesideLevel.tscn") as PackedScene
	var lvl: Node = lvl_scene.instantiate()
	add_child(lvl)

	var ramp: Node3D = lvl.get_node_or_null("Ramps/ConcreteRamp")
	if not ramp:
		print("Ramp not found!")
		get_tree().quit(1)
		return

	# Place camera near ramp
	var cam := Camera3D.new()
	# Ramp is at (167.59, 6.92, -80.38)
	# Ramp forward is (+16.4, 0, +11.4) normalized = (0.82, 0, 0.57)
	# Toe is at (157.42, 6.92, -87.42)
	# Lip is at (174.25, 15.04, -75.77)
	# Place camera in front of the toe looking up towards the lip
	cam.position = Vector3(150.0, 11.0, -96.0)
	add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(168.0, 10.0, -80.0))

	# Wait a few frames for rendering
	for i in range(15):
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://scratch/lakeside_csg_ramp.png")
		print("Saved res://scratch/lakeside_csg_ramp.png")
		
	get_tree().quit(0)
