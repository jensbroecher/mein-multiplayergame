extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var Level = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(Level)

	for i in 5:
		await get_tree().physics_frame

	var desert = Level.get_node_or_null("Desert")
	if desert == null:
		print("ERROR: Desert not found!")
		get_tree().quit(1)
		return

	var bb: StaticBody3D = desert.get_node_or_null("BouldersBody")
	if bb == null:
		print("ERROR: BouldersBody not found!")
		get_tree().quit(1)
		return

	print("BouldersBody found! Child count (shapes): %d" % bb.get_child_count())
	print("BouldersBody collision_layer: %d" % bb.collision_layer)

	var space = Level.get_world_3d().direct_space_state
	var hits := 0
	var total_tested := 0

	for i in range(mini(20, bb.get_child_count())):
		var cs = bb.get_child(i) as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		total_tested += 1
		var pos = cs.global_position
		# Raycast horizontally towards pos from 4m away
		var from = pos + Vector3(4.0, 0.5, 0.0)
		var to = pos + Vector3(0.0, 0.5, 0.0)
		var q = PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1
		var hit = space.intersect_ray(q)
		if hit and hit.collider == bb:
			hits += 1
		else:
			var cname = hit.collider.name if hit and hit.collider else "null"
			print("Missed boulder %d at %s: hit=%s" % [i, pos, cname])

	print("Tested %d boulders horizontally: %d hit BouldersBody" % [total_tested, hits])
	get_tree().quit(0 if hits == total_tested else 1)

