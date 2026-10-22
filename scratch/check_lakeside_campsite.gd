extends SceneTree

const GRID_RES := 1000
const GRID_START := -1000.0
const GRID_STEP := 2.0

func _init() -> void:
	print("--- Checking Lakeside Campsite & Terrain Heights ---")
	var mesh: ArrayMesh = load("res://generated/terrain_visual.res")
	if not mesh:
		print("FAILED to load terrain_visual.res")
		quit(1)
		return
	
	var arrays = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	print("Vertex count in terrain_visual.res: ", verts.size())
	
	var heights := PackedFloat32Array()
	heights.resize(verts.size())
	for i in range(verts.size()):
		heights[i] = verts[i].y

	var sample_ground = func(x: float, z: float) -> float:
		var gx: float = (x - GRID_START) / GRID_STEP
		var gz: float = (z - GRID_START) / GRID_STEP
		var x0: int = clampi(floori(gx), 0, GRID_RES - 1)
		var z0: int = clampi(floori(gz), 0, GRID_RES - 1)
		var fx: float = gx - float(x0)
		var fz: float = gz - float(z0)
		var stride := GRID_RES + 1
		var h00: float = heights[z0 * stride + x0]
		var h10: float = heights[z0 * stride + x0 + 1]
		var h01: float = heights[(z0 + 1) * stride + x0]
		var h11: float = heights[(z0 + 1) * stride + x0 + 1]
		if fx + fz <= 1.0:
			return h00 + fx * (h10 - h00) + fz * (h01 - h00)
		return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)

	var check_pts = [
		{"name": "Box 367", "x": 66.85, "z": 55.72, "prop_y": 10.94},
		{"name": "Box 368", "x": 67.72, "z": 65.39, "prop_y": 10.50},
		{"name": "Box 369", "x": 69.12, "z": 74.38, "prop_y": 10.94},
		{"name": "Box 370", "x": 69.22, "z": 81.02, "prop_y": 9.98},
		{"name": "Box 371", "x": 52.74, "z": 54.01, "prop_y": 10.76},
		{"name": "Box 372", "x": 57.87, "z": 27.08, "prop_y": 15.95},
		{"name": "Box 373", "x": 60.60, "z": 38.78, "prop_y": 16.39},
		{"name": "Terrace Center", "x": 62.0, "z": 68.0, "prop_y": 8.3},
		{"name": "Upper Center", "x": 59.0, "z": 33.0, "prop_y": 13.75},
	]

	for pt in check_pts:
		var gy: float = sample_ground.call(pt.x, pt.z)
		var diff = gy - pt.prop_y
		print("%s at (%.2f, %.2f): terrain Y = %.2f, prop Y = %.2f, diff = %.2f m (%s)" % [
			pt.name, pt.x, pt.z, gy, pt.prop_y, diff,
			"BURIED BY %.2f m" % diff if diff > 0.5 else ("FLOATING BY %.2f m" % -diff if diff < -0.5 else "MATCHES")
		])

	quit(0)
