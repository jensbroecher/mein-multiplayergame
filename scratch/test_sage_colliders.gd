extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var Level = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(Level)

	for i in 15:
		await get_tree().physics_frame

	var dc = Level.get_node_or_null("DressingColliders")
	print("DressingColliders node: ", dc)

	var space = Level.get_world_3d().direct_space_state
	var desert = Level.get_node("Desert")

	var sage_tested := 0
	var sage_hit := 0

	for ch in desert.get_children():
		if ch is MultiMeshInstance3D and ch.name.begins_with("RockMound_Sage"):
			var mmi: MultiMeshInstance3D = ch
			var mm = mmi.multimesh
			var buf = mm.buffer
			var stride = 12
			for i in range(mini(5, mm.instance_count)):
				var o = i * stride
				var pos = Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
				# Cast a horizontal ray towards the mound from 2.5m away
				var from = pos + Vector3(2.5, 0.35, 0)
				var to = pos + Vector3(0, 0.35, 0)
				var q = PhysicsRayQueryParameters3D.create(from, to)
				q.collision_mask = 1
				var hit = space.intersect_ray(q)
				sage_tested += 1
				if hit and hit.collider and ("Rock" in hit.collider.name or "Solid" in hit.collider.name):
					sage_hit += 1
				else:
					var cname = hit.collider.name if hit and hit.collider else "null"
					print("Sage mound at %s hit: %s" % [pos, cname])

	print("Tested %d sage mounds: %d hit rock collider!" % [sage_tested, sage_hit])
	get_tree().quit(0 if sage_hit == sage_tested else 1)

