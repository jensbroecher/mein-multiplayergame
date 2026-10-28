extends SceneTree
# Finds the exact surface of Rock5 around the arrow sign, excluding the arrow sign itself.
# Tests candidate positions for placing the arrow sign cleanly and solidly on the rock.

func _initialize():
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	for i in 5: await process_frame
	await physics_frame
	
	var arrow: Node3D = lvl.get_node("ArrowSign")
	var rock: Node3D = lvl.get_node("Rock5")
	var space_state: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	
	# Hide arrow sign colliders for raycasting
	var exclude_rids: Array[RID] = []
	for body in arrow.find_children("*", "CollisionObject3D", true, false):
		exclude_rids.append(body.get_rid())
	for body in lvl.find_children("Col_*ArrowSign*", "CollisionObject3D", true, false):
		exclude_rids.append(body.get_rid())
		
	print("--- Rock5 Surface Probe (excluding ArrowSign) ---")
	# Check where the rock surface actually is
	for z in range(48, 64, 2):
		var line := "Z=%2d: " % z
		for x in range(162, 176, 2):
			var ray_start := Vector3(x, 30, z)
			var ray_end := Vector3(x, 0, z)
			var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			query.exclude = exclude_rids
			var hit: Dictionary = space_state.intersect_ray(query)
			if hit:
				line += "X%d:y=%.2f(%s) " % [x, hit.position.y, hit.collider.name.substr(0, 4)]
			else:
				line += "X%d:miss " % x
		print(line)
		
	# Let's inspect rock mesh vertices or bounds in local space
	var rock_mi: MeshInstance3D = rock.find_children("*", "MeshInstance3D", true, false)[0]
	print("Rock5 global transform: ", rock.global_transform)
	print("Rock5 local AABB: ", rock_mi.mesh.get_aabb())

	quit(0)
