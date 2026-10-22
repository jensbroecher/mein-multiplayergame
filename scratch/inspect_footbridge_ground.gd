extends Node

func _ready() -> void:
	var lvl_scene := load("res://levels/LakesideLevel.tscn") as PackedScene
	var lvl: Node = lvl_scene.instantiate()
	add_child(lvl)

	var bridge: Node3D = lvl.get_node_or_null("LevelDesign/ConcreteFootbridge")
	print("Bridge global transform: ", bridge.global_transform)
	print("Bridge origin: ", bridge.global_position)
	
	# Let's test raycasts from above at bridge center, and at both ends
	# In local space:
	# Center: (0, 10, 0)
	# Leg 1: (-15, 5, 0)
	# Leg 2: (+15, 5, 0)
	var space_state := bridge.get_world_3d().direct_space_state
	for lx in [-17.0, -12.0, -7.0, 0.0, 7.0, 12.0, 17.0]:
		for lz in [-5.0, 0.0, 5.0]:
			var wp: Vector3 = bridge.global_transform * Vector3(lx, 15.0, lz)
			var query := PhysicsRayQueryParameters3D.create(wp + Vector3(0, 10, 0), wp - Vector3(0, 30, 0))
			var res := space_state.intersect_ray(query)
			if res:
				print("Local X=%.1f, Z=%.1f -> Ground Y=%.2f (collider: %s)" % [lx, lz, (res.position as Vector3).y, res.collider.name])
			else:
				print("Local X=%.1f, Z=%.1f -> No hit" % [lx, lz])

	get_tree().quit(0)
