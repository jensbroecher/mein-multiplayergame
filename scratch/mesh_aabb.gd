extends SceneTree

# Prints the world AABB of named MeshInstance3Ds in a saved level (reads the scene state; no level
# script runs). Headless:
#   Godot --headless --path . -s res://scratch/mesh_aabb.gd -- <level.tscn> <name> [<name> ...]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var state: SceneState = (load(args[0]) as PackedScene).get_state()
	for i in state.get_node_count():
		var nm := String(state.get_node_name(i))
		if not args.slice(1).has(nm):
			continue
		var xf := Transform3D()
		var mesh: Mesh = null
		for p in state.get_node_property_count(i):
			var pn := state.get_node_property_name(i, p)
			if pn == &"mesh":
				mesh = state.get_node_property_value(i, p)
			elif pn == &"transform":
				xf = state.get_node_property_value(i, p)
		if mesh:
			print("%s (%s): %s" % [nm, state.get_node_path(i), xf * mesh.get_aabb()])
	quit()
