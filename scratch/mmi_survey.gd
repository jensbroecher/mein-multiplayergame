extends SceneTree

# Lists every MultiMeshInstance3D a level's saved scene holds, grouped by name (trailing numbers and
# cell coordinates stripped): how many nodes, instances, and the mesh's height. Reads the scene state,
# so no level script runs. Headless:
#   Godot --headless --path . -s res://scratch/mmi_survey.gd -- res://levels/A.tscn [res://levels/B.tscn ...]

func _init() -> void:
	for level in OS.get_cmdline_user_args():
		var state: SceneState = (load(level) as PackedScene).get_state()
		var groups := {}
		for i in state.get_node_count():
			var nm := String(state.get_node_name(i))
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) != &"multimesh":
					continue
				var mm: MultiMesh = state.get_node_property_value(i, p)
				if mm == null:
					continue
				var key := nm
				var re := RegEx.new()
				re.compile("(_-?\\d+)+$")
				key = re.sub(key, "")
				var g: Array = groups.get(key, [0, 0, 0.0, String(state.get_node_path(i, true))])
				g[0] += 1
				g[1] += mm.instance_count
				if mm.mesh:
					g[2] = mm.mesh.get_aabb().size.y
				groups[key] = g
		print("== ", level.get_file(), ": ", groups.size(), " groups")
		var keys := groups.keys()
		keys.sort()
		for k in keys:
			var g: Array = groups[k]
			print("   %-34s nodes %4d  instances %6d  mesh h %.2f   %s" % [k, g[0], g[1], g[2], String(g[3]).get_base_dir()])
	quit()
