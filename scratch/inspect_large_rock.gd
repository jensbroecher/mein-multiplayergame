extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var Level = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(Level)

	for i in 20:
		await get_tree().physics_frame

	var dc = Level.get_node("DressingColliders")
	var target_pos = Vector3(139.9259, 2.272735, 297.6652)
	print("Inspecting near target: ", target_pos)

	for o in dc._owned:
		var mmi: MultiMeshInstance3D = o[0]
		if not is_instance_valid(mmi) or not mmi.name.contains("Boulder"):
			continue
		var owned: Array = o[1]
		var buf = mmi.multimesh.buffer
		for i in range(mmi.multimesh.instance_count):
			var pos = Vector3(buf[i * 12 + 3], buf[i * 12 + 7], buf[i * 12 + 11])
			if pos.distance_to(target_pos) < 1.0:
				print("Found boulder instance: %s idx=%d pos=%s" % [mmi.name, i, pos])
				var entry = owned[i]
				print("Owned entry: ", entry)
				if entry != null:
					var body: StaticBody3D = entry[0]
					var owner_id: int = entry[1]
					var disabled = body.is_shape_owner_disabled(owner_id)
					var shape_count = body.shape_owner_get_shape_count(owner_id)
					var shape = body.shape_owner_get_shape(owner_id, 0)
					var xf = body.shape_owner_get_transform(owner_id)
					print("Body: %s disabled=%s shape_count=%d shape=%s xf=%s" % [body.name, disabled, shape_count, shape, xf])
					if shape is ConvexPolygonShape3D:
						var pts: PackedVector3Array = shape.points
						var min_pt := Vector3(INF, INF, INF)
						var max_pt := Vector3(-INF, -INF, -INF)
						for pt in pts:
							min_pt = min_pt.min(pt)
							max_pt = max_pt.max(pt)
						print("Shape points count=%d min=%s max=%s" % [pts.size(), min_pt, max_pt])
	get_tree().quit()

