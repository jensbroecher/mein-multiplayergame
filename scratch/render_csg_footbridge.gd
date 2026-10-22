extends Node

func _ready() -> void:
	print("--- RENDERING CSG FOOTBRIDGE ---")
	
	var scene: PackedScene = load("res://ConcreteFootbridge.tscn")
	var bridge: Node3D = scene.instantiate()
	add_child(bridge)
	
	var cam := Camera3D.new()
	cam.position = Vector3(25, 18, 30)
	add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 5, 0))
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.18, 0.22, 0.26)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = environment
	add_child(env)

	for i in range(12):
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://scratch/csg_footbridge_3d.png")
		print("Saved res://scratch/csg_footbridge_3d.png")

	# Front / side angle
	cam.position = Vector3(0, 12, 35)
	cam.look_at_from_position(cam.position, Vector3(0, 5, 0))
	for i in range(5):
		await get_tree().process_frame
	img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://scratch/csg_footbridge_side.png")
		print("Saved res://scratch/csg_footbridge_side.png")

	get_tree().quit(0)
