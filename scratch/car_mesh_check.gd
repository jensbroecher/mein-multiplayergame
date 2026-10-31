extends SceneTree

# Builds procedural cars in memory (the body, the wheels and a canopy's glass) and checks their meshes
# for data that breaks the render: NaN or infinite positions and normals, zero normals, material ids
# outside car_body.gdshader's M_* range, and colours outside 0..1. Prints the vertex and triangle
# counts and each car's bounds.
# Run headless:
#   Godot --headless --path . -s res://scratch/car_mesh_check.gd -- [Fulmine Inferno ...]
const RegenCars = preload("res://regenerate_cars.gd")


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	for c in RegenCars.CARS:
		if not only.is_empty() and not only.has(c["name"]):
			continue
		var design = c["builder"].new()
		var parts := {}
		for key in ["body", "wheel_r", "rear_wheel_r", "glass"]:
			if key == "rear_wheel_r" and not design.has_method("build_rear_wheel"):
				continue
			if key == "glass" and not design.has_method("build_glass"):
				continue
			var b = RegenCars.CB.new()
			if key == "body":
				design.build_body(b)
			elif key == "wheel_r":
				design.build_wheel(b, 1.0)
			elif key == "glass":
				design.build_glass(b)
			else:
				design.build_rear_wheel(b, 1.0)
			parts[key] = b
		for key in parts:
			_check(c["name"] + "/" + key, parts[key])
	quit()


func _check(label: String, b) -> void:
	var bad_v := 0
	var bad_n := 0
	var zero_n := 0
	var bad_mat := 0
	var bad_col := 0
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for k in b._v.size():
		var p: Vector3 = b._v[k]
		var n: Vector3 = b._n[k]
		if not p.is_finite():
			bad_v += 1
		else:
			lo = lo.min(p)
			hi = hi.max(p)
		if not n.is_finite():
			bad_n += 1
		elif n.length_squared() < 0.5:
			zero_n += 1
		var m: float = b._uv2[k].x
		if m < 0.0 or m > 9.0 or not is_finite(m):
			bad_mat += 1
		var col: Color = b._c[k]
		if not (is_finite(col.r) and is_finite(col.g) and is_finite(col.b) and is_finite(col.a)) or col.r < 0.0 \
				or col.g < 0.0 or col.b < 0.0 or col.r > 1.0 or col.g > 1.0 or col.b > 1.0:
			bad_col += 1
	var bad_uv := 0
	for k in b._uv.size():
		if not b._uv[k].is_finite():
			bad_uv += 1
	print("%s: %d vertices, %d triangles, bounds %s..%s" % [label, b._v.size(), b.triangle_count(), lo, hi])
	if bad_v + bad_n + zero_n + bad_mat + bad_col + bad_uv > 0:
		print("  BAD: positions %d, normals %d (zero %d), uv %d, material ids %d, colours %d"
				% [bad_v, bad_n, zero_n, bad_uv, bad_mat, bad_col])
