extends SceneTree
## Checks PolyTriangulate.gd: the triangles of a polygon with holes must cover exactly its area, every one
## counter-clockwise. Run headless:  Godot --headless --path . -s res://scratch/poly_triangulate_test.gd

const PolyTriangulate = preload("res://PolyTriangulate.gd")


func _initialize() -> void:
	var failures := 0
	failures += _check("square", _rect(0, 0, 10, 10), [])
	failures += _check("square with a square hole", _rect(0, 0, 10, 10), [_hole(_rect(3, 3, 7, 7))])
	failures += _check("two holes", _rect(0, 0, 20, 10), [_hole(_rect(2, 2, 8, 8)), _hole(_rect(12, 2, 18, 8))])
	# An L, a C, and a star: concave outlines.
	failures += _check("L", PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 3), Vector2(3, 3), Vector2(3, 10), Vector2(0, 10)]), [])
	failures += _check("C with a hole in its back", PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 3), Vector2(3, 3), Vector2(3, 7), Vector2(10, 7), Vector2(10, 10), Vector2(0, 10)]),
		[_hole(_rect(0.5, 3.5, 2.5, 6.5))])
	failures += _check("star", _star(12, 10.0, 4.0), [])
	failures += _check("star with a round hole", _star(12, 10.0, 6.0), [_hole(_circle(Vector2.ZERO, 2.5, 24))])
	failures += _check("hole touching the bridge line of another", _rect(0, 0, 30, 10),
		[_hole(_rect(2, 4, 6, 6)), _hole(_rect(10, 4, 14, 6)), _hole(_rect(18, 4, 22, 6)), _hole(_rect(26, 4, 28, 6))])
	# Random blobs with random holes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for t in 12:
		var outline := _star(rng.randi_range(8, 40), 10.0, rng.randf_range(6.0, 9.5))
		var holes := []
		for k in rng.randi_range(0, 3):
			holes.append(_hole(_circle(Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)) + Vector2(k * 0.0, 0), rng.randf_range(0.5, 1.2), 10)))
		# Keep the holes apart.
		if holes.size() > 1:
			holes = [holes[0]]
		failures += _check("blob %d (%d outline points)" % [t, outline.size()], outline, holes)
	print("FAILED %d" % failures if failures > 0 else "all passed")
	quit(1 if failures > 0 else 0)


func _check(label: String, outline: PackedVector2Array, holes: Array) -> int:
	var tris := PolyTriangulate.triangulate(outline, holes)
	var all_pts := outline.duplicate()
	for hole in holes:
		all_pts.append_array(hole)
	var expected := _area(outline)
	for hole in holes:
		expected += _area(hole)   # a hole's signed area is negative
	var covered := 0.0
	var flipped := 0
	for t in tris.size() / 3:
		var a := all_pts[tris[t * 3]]
		var b := all_pts[tris[t * 3 + 1]]
		var c := all_pts[tris[t * 3 + 2]]
		var ar := (b - a).cross(c - a) * 0.5
		covered += ar
		if ar < -1e-9:
			flipped += 1
	var ok := absf(covered - expected) < 1e-6 * maxf(expected, 1.0) and flipped == 0
	print("%s %s: %d triangles, area %.4f of %.4f, %d flipped" % ["ok  " if ok else "FAIL", label, tris.size() / 3, covered, expected, flipped])
	return 0 if ok else 1


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5


func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## A hole runs the other way round.
func _hole(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.reverse()
	return out


func _star(points: int, r_out: float, r_in: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := TAU * float(i) / float(points * 2)
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out
