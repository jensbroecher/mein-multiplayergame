extends SceneTree

# Probe to verify CarSelection rendering
func _init() -> void:
	var root_vp := root
	root_vp.size = Vector2i(1400, 900)
	var cs_scene := load("res://CarSelection.tscn") as PackedScene
	var cs := cs_scene.instantiate()
	root_vp.add_child(cs)
	
	# Select Mudrunner (index 5)
	cs.current_car_index = 5
	cs.update_car_selection()
	
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var img := root_vp.get_texture().get_image()
	DirAccess.make_dir_absolute("scratch/output")
	img.save_png("scratch/output/car_selection_test.png")
	print("Saved scratch/output/car_selection_test.png")
	quit()
