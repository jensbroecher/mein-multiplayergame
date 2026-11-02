extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 800)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	
	var lvl_scene := load("res://levels/FreightLevel.tscn") as PackedScene
	var lvl := lvl_scene.instantiate()
	add_child(lvl)
	
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	
	# Framed shot of the bush right in front of the station
	cam.position = Vector3(-180.0, 5.2, 44.0)
	cam.look_at(Vector3(-180.0, 4.4, 52.0), Vector3.UP)
	
	for i in 25:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img := vp.get_texture().get_image()
	img.save_png("res://scratch/freight_depot_close_sage.png")
	print("SAVED: scratch/freight_depot_close_sage.png")
	get_tree().quit()
