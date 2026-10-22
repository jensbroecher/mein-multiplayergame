extends SceneTree

const GRID_RES := 1000
const GRID_START := -1000.0
const GRID_STEP := 2.0

func _init() -> void:
	var mesh: ArrayMesh = load("res://generated/terrain_visual.res")
	var arrays = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
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

	var px = -832.72205
	var py = 7.970955
	var pz = 98.826645
	var gy = sample_ground.call(px, pz)
	print("Tree 1: pos=(%.2f, %.2f, %.2f), terrain_y=%.2f, diff=%.2f" % [px, py, pz, gy, gy - py])
	quit(0)
