@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING CONCRETE RAMP COLLISION ---")
	var scene: PackedScene = load("res://ConcreteRamp.tscn")
	var ramp: Node3D = scene.instantiate()
	root.add_child(ramp)
	
	# Wait 2 frames for CSG baking
	for i in range(3):
		await process_frame
		
	var combiner: CSGCombiner3D = ramp.get_node("CSGCombiner3D")
	print("Combiner use_collision: ", combiner.use_collision)
	
	# Find StaticBody3D created by CSG
	var sb: StaticBody3D = null
	for c in combiner.get_children():
		if c is StaticBody3D:
			sb = c
			break
	if not sb:
		# In Godot 4, CSGCombiner creates internal collision child or mesh
		print("StaticBody3D child count in combiner: ", combiner.get_child_count())
		for c in combiner.get_children():
			print(" - child: ", c.name, " (", c.get_class(), ")")
	else:
		print("Found StaticBody3D: ", sb.name)
		for c in sb.get_children():
			if c is CollisionShape3D:
				var shape: Shape3D = c.shape
				print("  Collision shape: ", shape.get_class())
				if shape is ConcavePolygonShape3D:
					var faces := (shape as ConcavePolygonShape3D).get_faces()
					print("  Concave face count: ", faces.size() / 3)
	
	# Raycast test: shoot downward rays along centerline X from -12 to 8
	print("\n--- SURFACE HEIGHT CONTINUITY TEST ---")
	var space := ramp.get_world_3d().direct_space_state
	var hits := 0
	var prev_y := -999.0
	for x_step in range(-120, 81, 10):
		var x := x_step / 10.0
		var from := Vector3(x, 15.0, 0.0)
		var to := Vector3(x, -5.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		var result := space.intersect_ray(query)
		if result:
			hits += 1
			var hit_pos: Vector3 = result.position
			var hit_norm: Vector3 = result.normal
			var dy := (hit_pos.y - prev_y) if prev_y > -900 else 0.0
			print("X = %5.1f -> Hit Y = %5.2f (norm: %s, dy: %5.2f)" % [x, hit_pos.y, hit_norm, dy])
			prev_y = hit_pos.y
		else:
			print("X = %5.1f -> MISS!" % [x])
	# Lateral raycasts across Z at X = 0.0
	print("\n--- LATERAL PROFILE COLLISION TEST (at X = 0.0) ---")
	for z_step in range(-50, 51, 5):
		var z := z_step / 10.0
		var from := Vector3(0.0, 15.0, z)
		var to := Vector3(0.0, -5.0, z)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		var result := space.intersect_ray(query)
		if result:
			print("Z = %5.2f -> Hit Y = %5.2f (norm: %s)" % [z, result.position.y, result.normal])
		else:
			print("Z = %5.2f -> MISS (outside ramp footprint)" % [z])
	quit(0)
