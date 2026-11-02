extends SceneTree

func _init() -> void:
	var level = load("res://levels/FreightLevel.tscn").instantiate()
	var desert = level.get_node("Desert")
	var at_nodes := []
	var boulders := []
	for ch in desert.get_children():
		if ch is MultiMeshInstance3D:
			var res_path = ch.multimesh.mesh.resource_path if ch.multimesh and ch.multimesh.mesh else ""
			if str(ch.name).begins_with("@"):
				at_nodes.append({"name": ch.name, "mesh": res_path, "instances": ch.multimesh.instance_count})
			if "rock" in res_path:
				boulders.append({"name": ch.name, "mesh": res_path, "instances": ch.multimesh.instance_count, "hull": ch.get_meta("hull_collider", false)})
	print("Desert total children: %d" % desert.get_child_count())
	print("@ nodes count: %d" % at_nodes.size())
	print("Sample @ nodes: %s" % str(at_nodes.slice(0, 5)))
	print("Boulders count: %d" % boulders.size())
	var no_hull = boulders.filter(func(b): return not b["hull"])
	print("Boulders without hull meta: %d" % no_hull.size())
	quit()

