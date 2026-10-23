extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 800)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	
	var lvl_scene := load("res://levels/LakesideLevel.tscn") as PackedScene
	var lvl := lvl_scene.instantiate()
	add_child(lvl)
	
	var cam := Camera3D.new()
	cam.fov = 48.0
	add_child(cam)
	cam.make_current()
	
	# Position on the large bridge deck looking at the turbine hill ridge
	cam.position = Vector3(-430.0, 24.5, -450.0)
	cam.look_at(Vector3(-470.0, 45.0, -740.0), Vector3.UP)
	
	for i in 25:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img := vp.get_texture().get_image()
	img.save_png("res://scratch/shots_turbine/fixed_bridge_apex.png")
	print("SAVED: res://scratch/shots_turbine/fixed_bridge_apex.png")
	get_tree().quit()
