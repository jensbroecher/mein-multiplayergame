extends SceneTree
## Measures detailed sub-parts of LargeHouse (scale 45) and House (scale 35) by sampling
## cross-sections in X, Y, Z.

func _initialize() -> void:
	_probe_large_house()
	_probe_adobe_house()
	quit()


func _load_scaled_verts(path: String, scl: float) -> PackedVector3Array:
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var xform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scl), Vector3.ZERO) * mi.transform
	var raw: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var out := PackedVector3Array()
	out.resize(raw.size())
	for i in raw.size():
		out[i] = xform * raw[i]
	inst.free()
	return out


func _probe_large_house() -> void:
	var path := "res://models/desert/2f1728e226824507fc3188405c2c7935.fbx"
	if not ResourceLoader.exists(path):
		return
	var verts := _load_scaled_verts(path, 45.0)
	print("=== Detailed Probe: LargeHouse (scale 45) ===")
	# 1. At mid-wall height Y in [2.0..4.5], check Z min/max for every 2m X bin
	print("-- Wall plan at Y in [2.0..4.5] --")
	for xi in range(-19, 19, 2):
		var x0 := float(xi)
		var x1 := x0 + 2.0
		var zmin := 999.0
		var zmax := -999.0
		var cnt := 0
		for v in verts:
			if v.y >= 2.0 and v.y <= 4.5 and v.x >= x0 and v.x < x1:
				zmin = minf(zmin, v.z)
				zmax = maxf(zmax, v.z)
				cnt += 1
		if cnt > 0:
			print("  X [%.1f..%.1f]: Z [%.2f .. %.2f] (n=%d)" % [x0, x1, zmin, zmax, cnt])

	# 2. Check the recessed porch on +Z (X > -2, Z > 5): where is the inner porch back wall and columns/roof?
	print("-- Porch & Front (+Z) Z-distribution at Y in [1.5..3.5] --")
	for xi in range(-18, 19, 3):
		var x0 := float(xi)
		var x1 := x0 + 3.0
		var zs: Array[float] = []
		for v in verts:
			if v.y >= 1.5 and v.y <= 3.5 and v.x >= x0 and v.x < x1 and v.z > 0.0:
				zs.append(snappedf(v.z, 0.5))
		zs.sort()
		var unique_z: Array[float] = []
		for z in zs:
			if unique_z.is_empty() or absf(unique_z.back() - z) >= 0.5:
				unique_z.append(z)
		print("  X [%.1f..%.1f] (+Z clusters): %s" % [x0, x1, str(unique_z)])

	# 3. Roof profile along Z (at X around +5.0 where main roof runs, and X around -8.0 where front gable is)
	print("-- Main Roof Profile (X in [4.0..8.0]) max Y per Z bin --")
	for zi in range(-20, 18, 2):
		var z0 := float(zi)
		var z1 := z0 + 2.0
		var ymax := -999.0
		for v in verts:
			if v.x >= 4.0 and v.x <= 8.0 and v.z >= z0 and v.z < z1:
				ymax = maxf(ymax, v.y)
		if ymax > 0.0:
			print("  Z [%.1f..%.1f]: maxY=%.2f" % [z0, z1, ymax])

	print("-- Left Gable Profile (Z in [8.0..16.5]) max Y per X bin --")
	for xi in range(-18, 2, 2):
		var x0 := float(xi)
		var x1 := x0 + 2.0
		var ymax := -999.0
		for v in verts:
			if v.z >= 8.0 and v.z <= 16.5 and v.x >= x0 and v.x < x1:
				ymax = maxf(ymax, v.y)
		if ymax > 0.0:
			print("  X [%.1f..%.1f]: maxY=%.2f" % [x0, x1, ymax])

	# 4. Chimney bounds (Y > 11.5)
	var cmin := Vector3(999, 999, 999)
	var cmax := Vector3(-999, -999, -999)
	for v in verts:
		if v.y > 12.4:
			cmin = cmin.min(v)
			cmax = cmax.max(v)
	print("-- Chimney (Y > 12.4): min=%s max=%s --" % [cmin, cmax])


func _probe_adobe_house() -> void:
	var path := "res://models/desert/49ac41a0567226438249fc402b0d629c.fbx"
	if not ResourceLoader.exists(path):
		return
	var verts := _load_scaled_verts(path, 35.0)
	print("\n=== Detailed Probe: House (scale 35) ===")
	print("-- Wall plan at Y in [2.5..5.5] (1st floor) --")
	for xi in range(-15, 18, 2):
		var x0 := float(xi)
		var x1 := x0 + 2.0
		var zmin := 999.0
		var zmax := -999.0
		var cnt := 0
		for v in verts:
			if v.y >= 2.5 and v.y <= 5.5 and v.x >= x0 and v.x < x1:
				zmin = minf(zmin, v.z)
				zmax = maxf(zmax, v.z)
				cnt += 1
		if cnt > 0:
			print("  X [%.1f..%.1f]: Z [%.2f .. %.2f] (n=%d)" % [x0, x1, zmin, zmax, cnt])

	print("-- Wall plan at Y in [14.0..17.0] (2nd floor tower) --")
	for xi in range(-15, 6, 2):
		var x0 := float(xi)
		var x1 := x0 + 2.0
		var zmin := 999.0
		var zmax := -999.0
		var cnt := 0
		for v in verts:
			if v.y >= 14.0 and v.y <= 17.0 and v.x >= x0 and v.x < x1:
				zmin = minf(zmin, v.z)
				zmax = maxf(zmax, v.z)
				cnt += 1
		if cnt > 0:
			print("  X [%.1f..%.1f]: Z [%.2f .. %.2f] (n=%d)" % [x0, x1, zmin, zmax, cnt])

	print("-- Pergola / Awning on right wing (X in [4.0..17.0], Z > 4.0) --")
	for yi in range(0, 12, 1):
		var y0 := float(yi)
		var y1 := y0 + 1.0
		var xmin := 999.0
		var xmax := -999.0
		var zmin := 999.0
		var zmax := -999.0
		var cnt := 0
		for v in verts:
			if v.x >= 4.0 and v.z >= 4.5 and v.y >= y0 and v.y < y1:
				xmin = minf(xmin, v.x)
				xmax = maxf(xmax, v.x)
				zmin = minf(zmin, v.z)
				zmax = maxf(zmax, v.z)
				cnt += 1
		if cnt > 0:
			print("  Y [%.0f..%.0f]: X [%.2f..%.2f] Z [%.2f..%.2f] (n=%d)" % [y0, y1, xmin, xmax, zmin, zmax, cnt])

