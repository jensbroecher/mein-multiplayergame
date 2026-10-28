extends SceneTree
## Finds exact X/Y positions of doors, windows, lanterns, and vigas on LargeHouse and House.

func _initialize() -> void:
	_check_large_house_features()
	_check_house_features()
	quit()


func _load_verts(path: String, scl: float) -> PackedVector3Array:
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


func _check_large_house_features() -> void:
	var verts := _load_verts("res://models/desert/2f1728e226824507fc3188405c2c7935.fbx", 45.0)
	print("=== LargeHouse Front Features ===")
	# 1. Step at Z > 16.5, Y < 1.0
	var smin := Vector3(999, 999, 999)
	var smax := Vector3(-999, -999, -999)
	for v in verts:
		if v.z > 16.55 and v.y < 1.0:
			smin = smin.min(v)
			smax = smax.max(v)
	print("  Front step (Z>16.55, Y<1): min=%s max=%s" % [smin, smax])

	# 2. Lanterns protruding on front gable wall (Z > 16.55, Y in [2.5..6.0])
	print("  Front gable protrusions (Z > 16.55, Y in [2.5..6.0]):")
	for xi in range(-15, 0, 1):
		var x0 := float(xi)
		var ymin := 999.0
		var ymax := -999.0
		var zmax := -999.0
		var cnt := 0
		for v in verts:
			if v.z > 16.55 and v.y >= 2.5 and v.y <= 6.0 and v.x >= x0 and v.x < x0 + 1.0:
				ymin = minf(ymin, v.y)
				ymax = maxf(ymax, v.y)
				zmax = maxf(zmax, v.z)
				cnt += 1
		if cnt > 10:
			print("    X [%.0f..%.0f]: Y [%.2f..%.2f] maxZ=%.2f (n=%d)" % [x0, x0 + 1.0, ymin, ymax, zmax, cnt])

	# 3. Arched door recess on front gable (Z in [15.5..16.3], Y in [0.5..6.5], X in [-11..-5])
	var dmin := Vector3(999, 999, 999)
	var dmax := Vector3(-999, -999, -999)
	for v in verts:
		if v.z >= 15.6 and v.z <= 16.25 and v.y >= 0.5 and v.y <= 6.5 and v.x >= -10.5 and v.x <= -5.5:
			dmin = dmin.min(v)
			dmax = dmax.max(v)
	print("  Arched door recess: min=%s max=%s" % [dmin, dmax])

	# 4. Porch back wall openings (Z in [7.1..7.85], X in [-1..17], Y in [0.5..6.0])
	print("  Porch wall recesses (Z in [7.1..7.85], Y in [0.5..6.0]):")
	for xi in range(-1, 17, 1):
		var x0 := float(xi)
		var ymin := 999.0
		var ymax := -999.0
		var cnt := 0
		for v in verts:
			if v.z >= 7.1 and v.z <= 7.85 and v.y >= 0.5 and v.y <= 6.0 and v.x >= x0 and v.x < x0 + 1.0:
				ymin = minf(ymin, v.y)
				ymax = maxf(ymax, v.y)
				cnt += 1
		if cnt > 20:
			print("    X [%.0f..%.0f]: Y [%.2f..%.2f] (n=%d)" % [x0, x0 + 1.0, ymin, ymax, cnt])


func _check_house_features() -> void:
	var verts := _load_verts("res://models/desert/49ac41a0567226438249fc402b0d629c.fbx", 35.0)
	print("\n=== House (Adobe) Features ===")
	# 1. Vigas protruding on +Z (Z > 11.4)
	print("  +Z protrusions (vigas/step, Z > 11.4):")
	for yi in range(0, 22, 1):
		var y0 := float(yi)
		var xs: Array[float] = []
		for v in verts:
			if v.z > 11.4 and v.y >= y0 and v.y < y0 + 1.0:
				xs.append(snappedf(v.x, 0.5))
		xs.sort()
		var u: Array[float] = []
		for x in xs:
			if u.is_empty() or absf(u.back() - x) >= 0.5:
				u.append(x)
		if not u.is_empty():
			print("    Y [%.0f..%.0f]: X clusters=%s" % [y0, y0 + 1.0, str(u)])

	# 2. Vigas protruding on -Z (Z < -9.5)
	print("  -Z protrusions (vigas, Z < -9.5):")
	for yi in range(0, 22, 1):
		var y0 := float(yi)
		var xs: Array[float] = []
		for v in verts:
			if v.z < -9.5 and v.y >= y0 and v.y < y0 + 1.0:
				xs.append(snappedf(v.x, 0.5))
		xs.sort()
		var u: Array[float] = []
		for x in xs:
			if u.is_empty() or absf(u.back() - x) >= 0.5:
				u.append(x)
		if not u.is_empty():
			print("    Y [%.0f..%.0f]: X clusters=%s" % [y0, y0 + 1.0, str(u)])

	# 3. Pergola posts (X > 4.0, Y in [1.5..5.5], Z > 0.5)
	print("  Pergola posts (X > 4.0, Y in [1.5..5.5], Z > 0.5):")
	for xi in range(4, 17, 1):
		var x0 := float(xi)
		var zmin := 999.0
		var zmax := -999.0
		var cnt := 0
		for v in verts:
			if v.x >= x0 and v.x < x0 + 1.0 and v.y >= 1.5 and v.y <= 5.5 and v.z > 0.5:
				zmin = minf(zmin, v.z)
				zmax = maxf(zmax, v.z)
				cnt += 1
		if cnt > 0:
			print("    X [%.0f..%.0f]: Z [%.2f..%.2f] (n=%d)" % [x0, x0 + 1.0, zmin, zmax, cnt])
