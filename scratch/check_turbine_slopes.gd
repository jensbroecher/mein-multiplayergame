extends SceneTree

const GRID_RES := 1000
const GRID_START := -1000.0
const GRID_STEP := 2.0

func _init() -> void:
	var mesh: ArrayMesh = load("res://generated/terrain_visual.res")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var heights := PackedFloat32Array()
	heights.resize(verts.size())
	for i in range(verts.size()):
		heights[i] = verts[i].y
		
	var stride := GRID_RES + 1
	var get_h = func(x: float, z: float) -> float:
		var gx = clampi(int((x - GRID_START) / GRID_STEP), 0, GRID_RES)
		var gz = clampi(int((z - GRID_START) / GRID_STEP), 0, GRID_RES)
		return heights[gz * stride + gx]

	var points = [
		{"name": "Turbine 1 (West)", "pos": Vector2(-515.0, -735.0)},
		{"name": "Turbine 2 (Center Summit)", "pos": Vector2(-470.0, -750.0)},
		{"name": "Turbine 3 (East)", "pos": Vector2(-425.0, -725.0)},
	]

	for p in points:
		var h = get_h.call(p.pos.x, p.pos.y)
		# Check local slope over 4m radius (foundation size)
		var h_n = get_h.call(p.pos.x, p.pos.y - 4.0)
		var h_s = get_h.call(p.pos.x, p.pos.y + 4.0)
		var h_e = get_h.call(p.pos.x + 4.0, p.pos.y)
		var h_w = get_h.call(p.pos.x - 4.0, p.pos.y)
		var max_diff = maxf(maxf(absf(h_n - h), absf(h_s - h)), maxf(absf(h_e - h), absf(h_w - h)))
		print("%s at (%.1f, %.1f): center height = %.2fm, max 4m edge height diff = %.2fm" % [p.name, p.pos.x, p.pos.y, h, max_diff])

	quit()
