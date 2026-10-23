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

	print("Heights along northern ridge near bridge apex (s ~ 1300..1500, track at z ~ -630..-650):")
	for x in range(-550, -250, 50):
		var line := "x=%4d: " % x
		for z in range(-800, -640, 20):
			line += "z%d=%.1f " % [z, get_h.call(float(x), float(z))]
		print(line)

	print("\nHeights on the hill west of the bridge (s ~ 1700..2000, track at x ~ -700..-540, z ~ -480..-240):")
	for x in range(-900, -650, 50):
		var line := "x=%4d: " % x
		for z in range(-500, -150, 50):
			line += "z%d=%.1f " % [z, get_h.call(float(x), float(z))]
		print(line)

	print("\nHeights inside the bridge curve (towards the center of the lake?):")
	for x in range(-500, -200, 50):
		var line := "x=%4d: " % x
		for z in range(-550, -350, 50):
			line += "z%d=%.1f " % [z, get_h.call(float(x), float(z))]
		print(line)

	quit()
