@tool
extends SceneTree

func _init() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)

	var scene: PackedScene = load("res://models/ramps/1f92b579825d1652d7ab8d760b289672.fbx")
	var ramp: Node3D = scene.instantiate()
	ramp.scale = Vector3(20, 20, 20)
	root_node.add_child(ramp)
	
	var cam := Camera3D.new()
	cam.position = Vector3(-18, 8, 12)
	root_node.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(-2, 4, 0))
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	root_node.add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.18, 0.22, 0.26)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = environment
	root_node.add_child(env)

	for i in range(10):
		await process_frame

	var img := root.get_texture().get_image()
	if img:
		img.save_png("res://scratch/fbx_ramp_render.png")
		print("Saved res://scratch/fbx_ramp_render.png")
	else:
		print("Image is null!")
	quit(0)
