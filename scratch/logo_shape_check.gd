extends SceneTree
## Checks the logo's traced shapes (generated/logo/logo_shapes.json) before they are extruded: per loop its
## vertex count, area, shortest edge and any place it crosses itself, then whether the tier triangulates to
## exactly its area. Run headless:  Godot --headless --path . -s res://scratch/logo_shape_check.gd

const LogoBuilder = preload("res://LogoBuilder.gd")
const PolyTriangulate = preload("res://PolyTriangulate.gd")


func _initialize() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://generated/logo/logo_shapes.json"))
	var lb := LogoBuilder.new()
	lb.size_px = Vector2(data["size"][0], data["size"][1])
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in data["rim"]:
		var flat: Array = s["outer"]["p"]
		for i in flat.size() / 2:
			lo = Vector2(minf(lo.x, flat[i * 2]), minf(lo.y, flat[i * 2 + 1]))
			hi = Vector2(maxf(hi.x, flat[i * 2]), maxf(hi.y, flat[i * 2 + 1]))
	lb.centre_px = (lo + hi) * 0.5
	var bad := 0
	bad += _check_tier("rim", lb, data["rim"])
	bad += _check_tier("body", lb, data["body"])
	for f in data["faces"]:
		bad += _check_tier("face at %s" % [f["centre"]], lb, [f])
	print("problems: %d" % bad)
	quit(1 if bad > 0 else 0)


func _check_tier(label: String, lb: RefCounted, shapes: Array) -> int:
	var bad := 0
	for s in shapes:
		var shape: Dictionary = lb._prep_shape(s)
		var loops: Array = [shape["outer"]]
		loops.append_array(shape["holes"])
		var expected := 0.0
		for L in loops:
			var p: PackedVector2Array = L["p"]
			var crossings := _self_crossings(p)
			var shortest := INF
			for i in p.size():
				shortest = minf(shortest, p[i].distance_to(p[(i + 1) % p.size()]))
			var area := _area(p)
			expected += area
			print("%s: loop of %d points, area %.0f, shortest edge %.2f, %d self-crossings" % [label, p.size(), area, shortest, crossings])
			bad += 1 if crossings > 0 else 0
		var outline: PackedVector2Array = shape["outer"]["p"]
		var holes: Array = []
		for hole in shape["holes"]:
			holes.append(hole["p"])
		var tris := PolyTriangulate.triangulate(outline, holes)
		var all_pts := outline.duplicate()
		for hole in holes:
			all_pts.append_array(hole)
		var covered := 0.0
		var flipped := 0
		for t in tris.size() / 3:
			var ar: float = (all_pts[tris[t * 3 + 1]] - all_pts[tris[t * 3]]).cross(all_pts[tris[t * 3 + 2]] - all_pts[tris[t * 3]]) * 0.5
			covered += ar
			if ar < -1e-9:
				flipped += 1
		var ok := absf(covered - expected) < 1e-4 * absf(expected) and flipped == 0
		print("  triangulated: %d triangles cover %.0f of %.0f, %d flipped: %s" % [tris.size() / 3, covered, expected, flipped, "ok" if ok else "FAIL"])
		bad += 0 if ok else 1
		# And the top: the loops pushed in by the bevel the way LogoBuilder does it.
		for L in loops:
			lb._loop_geometry(L)
			L["cap"] = lb._no_caps(L)
			L["rings"] = lb._rings(L, LogoBuilder.FACE_BEVEL)
			var ring: PackedVector2Array = L["rings"][LogoBuilder.BEVEL_STEPS]
			var c := _self_crossings(ring)
			if c > 0:
				print("  pushed in by %.0f the loop of %d points crosses itself %d times" % [LogoBuilder.FACE_BEVEL.x, ring.size(), c])
	return bad


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5


## How many pairs of edges of the closed polygon cross properly.
func _self_crossings(p: PackedVector2Array) -> int:
	var n := p.size()
	var count := 0
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			var c := p[j]
			var d := p[(j + 1) % n]
			var d1 := (b - a).cross(c - a)
			var d2 := (b - a).cross(d - a)
			var d3 := (d - c).cross(a - c)
			var d4 := (d - c).cross(b - c)
			if d1 * d2 < 0.0 and d3 * d4 < 0.0:
				count += 1
	return count
