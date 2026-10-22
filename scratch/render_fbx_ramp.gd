@tool
extends SceneTree

func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var scene: PackedScene = load("res://models/ramps/1f92b579825d1652d7ab8d760b289672.fbx")
	var ramp: Node3D = scene.instantiate()
	ramp.scale = Vector3(20, 20, 20)
	vp.add_child(ramp)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.25, 0.3)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment = environment
	vp.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	vp.add_child(light)

	var cam := Camera3D.new()
	cam.position = Vector3(15, 12, 18)
	cam.look_at(Vector3(0, 4, 0))
	vp.add_child(cam)

	# Wait a couple frames for rendering
	for i in range(5):
		await process_frame

	var img: Image = vp.get_texture().get_image()
	img.save_png("res://scratch/fbx_ramp.png")
	print("Saved screenshot to scratch/fbx_ramp.png")
	quit(0)
