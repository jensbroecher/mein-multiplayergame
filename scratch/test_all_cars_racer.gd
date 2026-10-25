extends SceneTree

const RegenCars = preload("res://regenerate_cars.gd")
const CarPaint = preload("res://CarPaint.gd")

func _init() -> void:
	var cars := [
		"Mudrunner", "Phantom", "Strikeforce", "Centurion", "Shadow",
		"Interceptor", "Viper", "Apex", "Mirage", "Inferno",
		"Nocturne", "Vortex", "Zephyr"
	]
	
	DirAccess.make_dir_absolute("scratch/output/all_cars_racer")
	
	# Setup camera and light
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	root.add_child(sun)
	
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.02
	cam.position = Vector3(0, 1.4, -2.4)
	cam.look_at(Vector3(0, 0.5, -0.6), Vector3.UP)
	root.add_child(cam)
	cam.make_current()
	
	for car_name in cars:
		var entry: Dictionary = {}
		for c in RegenCars.CARS:
			if c["name"] == car_name:
				entry = c
				break
		if entry.is_empty():
			continue
		
		var parts: Dictionary = RegenCars.build_car(entry["builder"])
		var car: Node3D = RegenCars.assemble(car_name, parts)
		root.add_child(car)
		car.transform = Transform3D(Basis(Vector3.UP, PI) * 2.0, Vector3.ZERO)
		
		# Pattern 7 (Racer)
		var paint: Dictionary = CarPaint.factory(car_name)
		paint["pattern"] = 7
		paint["number"] = 53
		CarPaint.apply(car, paint)
		
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		
		var img: Image = root.get_texture().get_image()
		img.save_png("scratch/output/all_cars_racer/%s_racer.png" % car_name)
		print("Saved %s" % car_name)
		
		car.queue_free()
		for i in 2:
			await process_frame
	
	quit()
