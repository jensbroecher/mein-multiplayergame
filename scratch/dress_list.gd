extends SceneTree

# Lists where a generated level's MultiMesh dressing stands: for each model whose cells match a name
# fragment, the instances nearest the lap (TrackPath) with their distance to it, s along it and scale.
# Reads the saved scene's state, so no level script runs. Headless:
#   Godot --headless --path . -s res://scratch/dress_list.gd -- [level=res://levels/CanyonLevel.tscn]
#       [match=Near_saguaro] [count=8] [max=60]

func _init() -> void:
	var level := "res://levels/CanyonLevel.tscn"
	var frag := "Near_"
	var count := 8
	var max_d := 60.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level = a.substr(6)
		elif a.begins_with("match="):
			frag = a.substr(6)
		elif a.begins_with("count="):
			count = int(a.substr(6))
		elif a.begins_with("max="):
			max_d = float(a.substr(4))
	var state: SceneState = (load(level) as PackedScene).get_state()
	var curve: Curve3D = null
	var per_model := {}
	for i in state.get_node_count():
		var nm := String(state.get_node_name(i))
		for p in state.get_node_property_count(i):
			var pn := state.get_node_property_name(i, p)
			if nm == "TrackPath" and pn == &"curve":
				curve = state.get_node_property_value(i, p)
			elif pn == &"multimesh" and nm.contains(frag):
				var mm: MultiMesh = state.get_node_property_value(i, p)
				# Cell names are <Kind>Near_<model>_<x>_<z>.
				var parts := nm.split("_")
				var model := "_".join(parts.slice(1, parts.size() - 2))
				var list: Array = per_model.get(model, [])
				var buf: PackedFloat32Array = mm.buffer
				for k in mm.instance_count:
					var o := k * 12
					var basis_x := Vector3(buf[o], buf[o + 4], buf[o + 8])
					list.append([Vector3(buf[o + 3], buf[o + 7], buf[o + 11]), basis_x.length()])
				per_model[model] = list
	if curve == null:
		print("no TrackPath")
		quit()
		return
	for model in per_model:
		var rows: Array = []
		for e in per_model[model]:
			var pos: Vector3 = e[0]
			var on: Vector3 = curve.get_closest_point(pos)
			var d := Vector2(pos.x - on.x, pos.z - on.z).length()
			if d <= max_d:
				rows.append([d, pos, curve.get_closest_offset(pos), e[1]])
		rows.sort_custom(func(a, b): return a[0] < b[0])
		print("%s: %d instances, %d within %.0fm" % [model, (per_model[model] as Array).size(), rows.size(), max_d])
		for r in rows.slice(0, count):
			var p: Vector3 = r[1]
			print("   %5.1fm off, s=%6.0f  at (%.1f, %.1f, %.1f) scale %.2f" % [r[0], r[2], p.x, p.y, p.z, r[3]])
	quit()
