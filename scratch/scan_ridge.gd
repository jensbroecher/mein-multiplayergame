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

	print("Ridge fine scan:")
	var best_points = []
	for x in range(-560, -400, 10):
		var best_z = -750
		var max_h = -999.0
		for z in range(-780, -710, 5):
			var h = get_h.call(float(x), float(z))
			if h > max_h:
				max_h = h
				best_z = z
		print("x=%4d: ridge peak at z=%d, height=%.2fm" % [x, best_z, max_h])
	quit()
