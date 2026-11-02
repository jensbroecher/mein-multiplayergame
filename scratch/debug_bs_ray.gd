extends SceneTree

func _init() -> void:
	var level_scene = load("res://levels/FreightLevel.tscn")
	var level = level_scene.instantiate()
	get_root().add_child(level)
	
	var bs0 = level.find_child("BufferStop_0", true, false)
	var body: StaticBody3D = bs0.find_child("BufferStop_Body", true, false)
	print("Body: ", body)
	print("Collision layer: ", body.collision_layer, " mask: ", body.collision_mask)
	var col_shape: CollisionShape3D = body.get_child(0)
	print("Shape: ", col_shape.shape)
	var mesh_shape = col_shape.shape as ConcavePolygonShape3D
	var faces = mesh_shape.get_faces()
	print("Faces count: ", faces.size())
	print("First triangle: ", faces[0], faces[1], faces[2])
	
	var space = body.get_world_3d().direct_space_state
	# Cast rays from all 6 directions through bs0.global_position + Vector3(0, 1.5, 0)
	var center = bs0.global_position + Vector3(0, 1.5, 0)
	for d in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN]:
		var p1 = center + d * 5.0
		var p2 = center - d * 5.0
		var ray = PhysicsRayQueryParameters3D.create(p1, p2)
		var res = space.intersect_ray(ray)
		if not res.is_empty():
			print("HIT from direction ", d, " at ", res.position, " normal: ", res.normal, " collider: ", res.collider.name)
		else:
			print("Miss from direction ", d)
	quit()

