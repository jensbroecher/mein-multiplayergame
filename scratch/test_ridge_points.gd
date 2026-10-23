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

	var test_points = [
		Vector2(-500, -735),
		Vector2(-470, -750),
		Vector2(-435, -720),
		Vector2(-370, -710),
		Vector2(-320, -705),
		Vector2(-270, -710),
	]
	for p in test_points:
		var h = get_h.call(p.x, p.y)
		var h_n = get_h.call(p.x, p.y - 4.0)
		var h_s = get_h.call(p.x, p.y + 4.0)
		var h_e = get_h.call(p.x + 4.0, p.y)
		var h_w = get_h.call(p.x - 4.0, p.y)
		var max_diff = maxf(maxf(absf(h_n - h), absf(h_s - h)), maxf(absf(h_e - h), absf(h_w - h)))
		print("Pt (%.1f, %.1f): h=%.2fm, max 4m diff=%.2fm" % [p.x, p.y, h, max_diff])
	quit()
