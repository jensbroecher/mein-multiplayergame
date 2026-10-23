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
		
	var path_scene = load("res://levels/LakesideLevel.tscn")
	# Just find highest points in the region around the bridge
	# Bridge region: X in [-800, 100], Z in [-800, -100]
	print("=== Searching for hills near the large bridge ===")
	var stride := GRID_RES + 1
	var peaks: Array = []
	for gx in range(50, 950, 5):
		for gz in range(50, 950, 5):
			var x = GRID_START + gx * GRID_STEP
			var z = GRID_START + gz * GRID_STEP
			if x >= -850 and x <= 150 and z >= -850 and z <= 50:
				var h = heights[gz * stride + gx]
				# Check if it's high
				if h > 20.0:
					peaks.append({"x": x, "z": z, "h": h})
	
	# Sort by height descending
	peaks.sort_custom(func(a, b): return a["h"] > b["h"])
	print("Top 15 high spots around bridge area:")
	var reported: Array = []
	for p in peaks:
		var too_close = false
		for r in reported:
			if Vector2(p.x - r.x, p.z - r.z).length() < 60.0:
				too_close = true
				break
		if not too_close:
			reported.append(p)
			print("  Peak at (x=%.1f, z=%.1f): height = %.2fm" % [p.x, p.z, p.h])
		if reported.size() >= 15:
			break
	quit()
