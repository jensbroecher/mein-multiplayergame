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

	print("Area scan from x=-600 to -300, z=-850 to -650:")
	for z in range(-820, -680, 20):
		var line = "z=%4d: " % z
		for x in range(-550, -350, 40):
			line += "x%d=%.1f " % [x, get_h.call(float(x), float(z))]
		print(line)

	quit()
