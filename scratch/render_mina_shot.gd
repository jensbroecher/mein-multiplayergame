extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 800)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X

	var lvl_scene := load("res://levels/MinaLevel.tscn") as PackedScene
	var lvl := lvl_scene.instantiate()
	add_child(lvl)

	var cam := Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.make_current()

	# Elevated camera behind the StartLine looking down the plateau across the array and balloons
	cam.position = Vector3(-435.0, 58.5, -1190.0)
	cam.look_at(Vector3(-260.0, 50.0, -980.0), Vector3.UP)

	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png("res://scratch/mina_del_viento_shot.png")
	img.save_jpg("res://images/menu/tile_mina_del_viento.jpg", 0.9)
	print("SAVED: scratch/mina_del_viento_shot.png and images/menu/tile_mina_del_viento.jpg")
	get_tree().quit()

