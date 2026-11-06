extends SceneTree
## For every TerrainGenerator bridge pillar ("BridgeSupport_*") in a level: where it stands, its top, and the natural
## ground under it (TerrainGenerator.natural_height: the ground before the road is graded in, so a lake bed under a
## real bridge): a pillar whose top is within a few metres of it holds nothing up (it was stood there because the road
## was 5m over sea level: on a dune). Headless:
##   Godot --headless --path . -s res://scratch/bridge_support_check.gd -- res://levels/X.tscn

func _init() -> void:
	var root: Node3D = (load(OS.get_cmdline_user_args()[0]) as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	var tg: Node = root.get_node("TerrainGenerator")
	var buried := 0
	var standing := 0
	for n in root.find_children("BridgeSupport_*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var size: Vector3 = (mi.mesh as BoxMesh).size
		var top: float = mi.global_position.y + size.y * 0.5
		var ground: float = tg.natural_height(mi.global_position.x, mi.global_position.z)
		var gap: float = top - ground
		if gap < 4.0:
			buried += 1
		else:
			standing += 1
		print("%s at (%.0f, %.0f) top %.1f natural ground %.1f: %s" % [mi.name, mi.global_position.x, mi.global_position.z, top, ground,
				"BURIED" if gap < 4.0 else "%.0fm over the ground" % gap])
	print("%d standing over the ground, %d buried" % [standing, buried])
	quit()
