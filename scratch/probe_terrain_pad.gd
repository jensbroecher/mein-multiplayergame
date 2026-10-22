extends SceneTree

func _init() -> void:
	var tg_script = load("res://TerrainGenerator.gd")
	var tg = Node3D.new()
	tg.set_script(tg_script)
	
	# The pads from LakesideLevel.tscn:
	var pads = PackedFloat32Array([
		-19.860287, 66.60782, 35, 11, 1.7671446, 2.5, 12,
		41.90017, -42.37507, 23, 6.5, 0.3947933, 1.8, 7,
		62, 68, 17, 13, -1.45, 8.3, 11,
		59, 33, 9, 8, -1.3, 13.75, 11
	])
	tg.flat_pads = pads
	
	print("--- Testing TerrainGenerator._apply_flat_pads ---")
	var pts = [
		{"name": "Box 368", "x": 67.72, "z": 65.39},
		{"name": "Box 369", "x": 69.12, "z": 74.38},
		{"name": "Terrace Center", "x": 62.0, "z": 68.0},
		{"name": "Upper Center", "x": 59.0, "z": 33.0},
	]
	
	for pt in pts:
		var raw_h = 15.0 # suppose natural hill was 15.0
		var padded_h = tg._apply_flat_pads(pt.x, pt.z, raw_h)
		print("%s at (%.2f, %.2f): initial %.2f -> padded %.2f" % [pt.name, pt.x, pt.z, raw_h, padded_h])
	
	tg.free()
	quit(0)
