extends Node

func _ready() -> void:
	var lvl_scene := load("res://levels/LakesideLevel.tscn") as PackedScene
	var lvl: Node = lvl_scene.instantiate()
	add_child(lvl)

	var bridge: Node3D = lvl.get_node_or_null("LevelDesign/ConcreteFootbridge")
	if not bridge:
		print("Footbridge not found!")
		get_tree().quit(1)
		return

	print("Bridge pos: ", bridge.global_position)
	print("Bridge rot: ", bridge.global_rotation_degrees)
	print("Bridge scale: ", bridge.scale)

	# Place camera looking at footbridge
	var cam := Camera3D.new()
	# Bridge is at (67.78, 2.82, -410.95)
	# Place camera on road / track looking towards the bridge
	cam.position = bridge.global_position + Vector3(25.0, 8.0, 30.0)
	add_child(cam)
	cam.look_at_from_position(cam.position, bridge.global_position + Vector3(0.0, 5.0, 0.0))

	for i in range(15):
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://scratch/lakeside_fbx_footbridge.png")
		print("Saved res://scratch/lakeside_fbx_footbridge.png")
		
	get_tree().quit(0)
