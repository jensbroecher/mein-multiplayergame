@tool
extends SceneTree

func _init() -> void:
	print("--- BUILDING CSG CONCRETE RAMP ---")
	
	var mat: Material = load("res://weathered_concrete.tres")
	
	# Root node
	var ramp_root := Node3D.new()
	ramp_root.name = "ConcreteRamp"
	ramp_root.add_to_group("collision_trimesh")
	
	var combiner := CSGCombiner3D.new()
	combiner.name = "CSGCombiner3D"
	combiner.use_collision = true
	ramp_root.add_child(combiner)
	combiner.owner = ramp_root
	
	# Curve points along deck
	var eval_xs: Array[float] = [
		-12.370, -11.768, -11.166, -10.564, -9.962, -9.360, -8.758, -8.156,
		-7.554, -6.951, -6.349, -5.747, -5.145, -4.543, -3.941, -3.339,
		-2.737, -2.135, -1.533, -0.931, -0.329, 0.273, 0.875, 1.477,
		2.079, 2.681, 3.284, 3.886, 4.488, 5.090, 5.692, 6.294,
		6.896, 7.498, 8.100
	]
	var eval_ys: Array[float] = [
		0.000, 0.368, 0.556, 0.746, 0.938, 1.133, 1.331, 1.532,
		1.735, 1.942, 2.151, 2.364, 2.579, 2.798, 3.020, 3.245,
		3.474, 3.706, 3.942, 4.181, 4.424, 4.671, 4.921, 5.176,
		5.434, 5.696, 5.963, 6.233, 6.508, 6.787, 7.070, 7.358,
		7.650, 7.947, 8.120
	]
	
	# 1. Deck polygon (width 7.0, from Z = +3.5 to Z = -3.5)
	var deck_poly_pts := PackedVector2Array()
	for i in range(eval_xs.size()):
		deck_poly_pts.append(Vector2(eval_xs[i], eval_ys[i]))
	deck_poly_pts.append(Vector2(8.10, 0.0))
	deck_poly_pts.append(Vector2(8.10, -0.6))
	deck_poly_pts.append(Vector2(-12.10, -0.6))
	deck_poly_pts.append(Vector2(-12.37, 0.0))
	
	var deck_csg := CSGPolygon3D.new()
	deck_csg.name = "RampDeck"
	deck_csg.mode = CSGPolygon3D.MODE_DEPTH
	deck_csg.depth = 7.0
	deck_csg.polygon = deck_poly_pts
	deck_csg.position = Vector3(0, 0, 3.5) # extrudes along -Z from +3.5 to -3.5
	deck_csg.material = mat
	deck_csg.use_collision = true
	combiner.add_child(deck_csg)
	deck_csg.owner = ramp_root
	
	# 2. Side walls & parapet curbs
	var wall_poly_pts := PackedVector2Array()
	for i in range(eval_xs.size()):
		var x := eval_xs[i]
		var y := eval_ys[i]
		var curb_h := 0.38 * clampf((x - (-12.37)) / 1.5, 0.0, 1.0)
		wall_poly_pts.append(Vector2(x, y + curb_h))
	wall_poly_pts.append(Vector2(8.10, 0.0))
	wall_poly_pts.append(Vector2(8.10, -0.6))
	wall_poly_pts.append(Vector2(-12.10, -0.6))
	wall_poly_pts.append(Vector2(-12.37, 0.0))
	
	# Left wall: from Z = -3.5 to Z = -4.3 (depth = 0.8 at position Z = -3.5)
	var left_wall := CSGPolygon3D.new()
	left_wall.name = "LeftWall"
	left_wall.mode = CSGPolygon3D.MODE_DEPTH
	left_wall.depth = 0.8
	left_wall.polygon = wall_poly_pts
	left_wall.position = Vector3(0, 0, -3.5) # extrudes to -4.3
	left_wall.material = mat
	left_wall.use_collision = true
	combiner.add_child(left_wall)
	left_wall.owner = ramp_root
	
	# Right wall: from Z = +4.3 to Z = +3.5 (depth = 0.8 at position Z = +4.3)
	var right_wall := CSGPolygon3D.new()
	right_wall.name = "RightWall"
	right_wall.mode = CSGPolygon3D.MODE_DEPTH
	right_wall.depth = 0.8
	right_wall.polygon = wall_poly_pts
	right_wall.position = Vector3(0, 0, 4.3) # extrudes to +3.5
	right_wall.material = mat
	right_wall.use_collision = true
	combiner.add_child(right_wall)
	right_wall.owner = ramp_root

	# 3. Cantilevered Cornice / Outer overhang ledges with chamfered underside
	var cornice_poly := PackedVector2Array()
	# Top edge
	for i in range(eval_xs.size()):
		var x := eval_xs[i]
		var y := eval_ys[i]
		var curb_h := 0.38 * clampf((x - (-12.37)) / 1.5, 0.0, 1.0)
		cornice_poly.append(Vector2(x, y + curb_h))
	# Outer vertical edge drop
	cornice_poly.append(Vector2(8.10, eval_ys[-1] + 0.38 - 0.20))
	# Angled corbel return
	for i in range(eval_xs.size() - 1, -1, -1):
		var x := eval_xs[i]
		var y := eval_ys[i]
		var curb_h := 0.38 * clampf((x - (-12.37)) / 1.5, 0.0, 1.0)
		var under_y := y + curb_h - 0.35
		cornice_poly.append(Vector2(x, maxf(under_y, -0.6)))
		
	var left_cornice := CSGPolygon3D.new()
	left_cornice.name = "LeftCornice"
	left_cornice.mode = CSGPolygon3D.MODE_DEPTH
	left_cornice.depth = 0.25
	left_cornice.polygon = cornice_poly
	left_cornice.position = Vector3(0, 0, -4.3) # extrudes to -4.55
	left_cornice.material = mat
	left_cornice.use_collision = true
	combiner.add_child(left_cornice)
	left_cornice.owner = ramp_root

	var right_cornice := CSGPolygon3D.new()
	right_cornice.name = "RightCornice"
	right_cornice.mode = CSGPolygon3D.MODE_DEPTH
	right_cornice.depth = 0.25
	right_cornice.polygon = cornice_poly
	right_cornice.position = Vector3(0, 0, 4.55) # extrudes to +4.3
	right_cornice.material = mat
	right_cornice.use_collision = true
	combiner.add_child(right_cornice)
	right_cornice.owner = ramp_root

	# 4. Base Footing Plinth (flares out at ground level Y in [-0.6, 0.45])
	var plinth_poly := PackedVector2Array([
		Vector2(-12.10, 0.45),
		Vector2(8.10, 0.45),
		Vector2(8.10, -0.6),
		Vector2(-12.10, -0.6)
	])
	var left_plinth := CSGPolygon3D.new()
	left_plinth.name = "LeftPlinth"
	left_plinth.mode = CSGPolygon3D.MODE_DEPTH
	left_plinth.depth = 0.25
	left_plinth.polygon = plinth_poly
	left_plinth.position = Vector3(0, 0, -4.3) # extrudes to -4.55
	left_plinth.material = mat
	left_plinth.use_collision = true
	combiner.add_child(left_plinth)
	left_plinth.owner = ramp_root

	var right_plinth := CSGPolygon3D.new()
	right_plinth.name = "RightPlinth"
	right_plinth.mode = CSGPolygon3D.MODE_DEPTH
	right_plinth.depth = 0.25
	right_plinth.polygon = plinth_poly
	right_plinth.position = Vector3(0, 0, 4.55) # extrudes to +4.3
	right_plinth.material = mat
	right_plinth.use_collision = true
	combiner.add_child(right_plinth)
	right_plinth.owner = ramp_root

	# 5. Rear cornice and rear plinth at X = 8.10
	var rear_cornice := CSGBox3D.new()
	rear_cornice.name = "RearCornice"
	rear_cornice.size = Vector3(0.40, 0.40, 9.10)
	rear_cornice.position = Vector3(8.10 + 0.20, 8.50 - 0.20, 0.0)
	rear_cornice.material = mat
	rear_cornice.use_collision = true
	combiner.add_child(rear_cornice)
	rear_cornice.owner = ramp_root

	var rear_plinth := CSGBox3D.new()
	rear_plinth.name = "RearPlinth"
	rear_plinth.size = Vector3(0.40, 1.05, 9.10)
	rear_plinth.position = Vector3(8.10 + 0.20, -0.075, 0.0)
	rear_plinth.material = mat
	rear_plinth.use_collision = true
	combiner.add_child(rear_plinth)
	rear_plinth.owner = ramp_root

	# Save PackedScene
	var packed := PackedScene.new()
	var err := packed.pack(ramp_root)
	if err != OK:
		print("Error packing scene: ", err)
		quit(1)
		return
		
	ResourceSaver.save(packed, "res://ConcreteRamp.tscn")
	print("Saved res://ConcreteRamp.tscn successfully!")

	# Now let's render screenshots to test visual quality!
	var cam := Camera3D.new()
	cam.position = Vector3(-18, 8, 12)
	root.add_child(ramp_root)
	root.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(-2, 4, 0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	root.add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.18, 0.22, 0.26)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = environment
	root.add_child(env)

	for i in range(12):
		await process_frame

	var img := root.get_texture().get_image()
	if img:
		img.save_png("res://scratch/csg_ramp_render_front.png")
		print("Saved res://scratch/csg_ramp_render_front.png")

	# Second angle: side view
	cam.position = Vector3(18, 14, 20)
	cam.look_at_from_position(cam.position, Vector3(0, 4, 0))
	for i in range(5):
		await process_frame
	img = root.get_texture().get_image()
	if img:
		img.save_png("res://scratch/csg_ramp_render_side.png")
		print("Saved res://scratch/csg_ramp_render_side.png")

	quit(0)
