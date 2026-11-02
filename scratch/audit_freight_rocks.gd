extends SceneTree

func _init() -> void:
	var level = load("res://levels/FreightLevel.tscn").instantiate()
	root.add_child(level)
	var DCClass = load("res://DressingColliders.gd")
	var dc = DCClass.new()
	level.add_child(dc)
	dc.build(level)

	var total_rock_instances := 0
	var solid_rock_instances := 0
	var skipped_rock_instances := 0
	var skipped_examples := []

	for o in dc._owned:
		var mmi: MultiMeshInstance3D = o[0]
		if not is_instance_valid(mmi) or not mmi.name.contains("Boulder"):
			continue
		var owned: Array = o[1]
		var info = dc._mesh_shape(mmi.multimesh.mesh)
		var buf = mmi.multimesh.buffer
		var stride = 12
		for i in range(mmi.multimesh.instance_count):
			total_rock_instances += 1
			var local = DCClass._buffer_transform(buf, i * stride)
			var sc = local.basis.get_scale()
			var height = float(info["h"]) * sc.y
			if owned[i] != null:
				solid_rock_instances += 1
			else:
				skipped_rock_instances += 1
				if skipped_examples.size() < 10:
					skipped_examples.append({
						"name": mmi.name,
						"index": i,
						"h": height,
						"pos": local.origin,
						"min_h": mmi.get_meta(&"min_collider_height", 0.5)
					})
	print("AUDIT RESULTS:")
	print("Total rock instances: %d" % total_rock_instances)
	print("Solid rock instances: %d" % solid_rock_instances)
	print("Skipped rock instances: %d" % skipped_rock_instances)
	print("Skipped examples: %s" % str(skipped_examples))
	quit()
