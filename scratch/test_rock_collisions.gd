extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var Level = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(Level)

	for i in 20:
		await get_tree().physics_frame

	var space = Level.get_world_3d().direct_space_state
	var desert = Level.get_node("Desert")

	var tested := 0
	var hit_count := 0
	var missed_boulders := []

	for ch in desert.get_children():
		if not (ch is MultiMeshInstance3D) or not ch.name.contains("Boulder"):
			continue
		var mmi: MultiMeshInstance3D = ch
		var mm = mmi.multimesh
		var buf = mm.buffer
		var stride = 12
		var info_h = mm.mesh.get_aabb().size.y
		for i in range(mm.instance_count):
			var o = i * stride
			var pos = Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			var sy = Vector3(buf[o + 1], buf[o + 5], buf[o + 9]).length()
			var h = info_h * sy

			# Raycast downward through the rock from top to bottom
			var from = pos + Vector3(0, h * 0.8 + 0.5, 0)
			var to = pos + Vector3(0, -0.5, 0)
			var q = PhysicsRayQueryParameters3D.create(from, to)
			q.collision_mask = 1
			var hit = space.intersect_ray(q)
			tested += 1
			if hit and hit.collider and "Rock" in hit.collider.name:
				hit_count += 1
			else:
				var col_name = hit.collider.name if hit and hit.collider else "null"
				missed_boulders.append({"name": mmi.name, "h": h, "pos": pos, "hit": col_name})

	print("Tested %d boulders: %d hit rock collider, %d missed" % [tested, hit_count, missed_boulders.size()])
	if missed_boulders.size() > 0:
		print("Sample missed boulders (first 10):")
		for m in missed_boulders.slice(0, 10):
			print("  ", m)
	get_tree().quit()
