extends SceneTree

func _init() -> void:
	var level_scene: PackedScene = load("res://levels/LakesideLevel.tscn")
	var level = level_scene.instantiate()
	var tg = level.get_node("TerrainGenerator")
	print("tg.flat_pads size: ", tg.flat_pads.size())
	for i in range(0, tg.flat_pads.size(), 7):
		print("Pad %d: x=%.2f, z=%.2f, hw=%.2f, hl=%.2f, yaw=%.2f, h=%.2f, blend=%.2f" % [
			i / 7, tg.flat_pads[i], tg.flat_pads[i+1], tg.flat_pads[i+2], tg.flat_pads[i+3],
			tg.flat_pads[i+4], tg.flat_pads[i+5], tg.flat_pads[i+6]
		])
	
	# Test pad application at Terrace Center (62, 68) and Upper Center (59, 33)
	var h1 = tg._apply_flat_pads(62.0, 68.0, 20.0)
	var h2 = tg._apply_flat_pads(59.0, 33.0, 20.0)
	print("Test _apply_flat_pads with initial 20.0:")
	print("  at (62, 68): result = ", h1)
	print("  at (59, 33): result = ", h2)
	
	level.free()
	quit(0)
