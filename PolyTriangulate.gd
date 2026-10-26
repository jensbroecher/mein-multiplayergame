extends RefCounted
## Triangulates a polygon with holes by ear clipping, the holes first joined to the outline by bridges
## (a doubled edge from the hole's leftmost point to a vertex of the outline it can see). Godot's own
## Geometry2D.triangulate_polygon takes no holes, and the logo's B, P, G and R have them.
##
## The outline must run counter-clockwise and every hole clockwise, in one plane (x right, y up). Triangles
## come back counter-clockwise as indices into the outline's points followed by each hole's, in order.

const EPS := 1e-12


static func triangulate(outline: PackedVector2Array, holes: Array = []) -> PackedInt32Array:
	var pts := outline.duplicate()
	var ring: Array[int] = []
	for i in outline.size():
		ring.append(i)
	var pending: Array = []
	var hole_polys: Array = []
	for hole in holes:
		var start := pts.size()
		var idx: Array[int] = []
		for i in hole.size():
			pts.append(hole[i])
			idx.append(start + i)
		pending.append(idx)
	# The hole furthest to the left first: its bridge can't be crossed by the ones still to come.
	pending.sort_custom(func(a, b): return _min_x(pts, a) < _min_x(pts, b))
	for idx in pending:
		var poly := PackedVector2Array()
		for i in idx:
			poly.append(pts[i])
		hole_polys.append(poly)
	for k in pending.size():
		ring = _bridge(pts, ring, pending, hole_polys, k)
	return _clip_ears(pts, ring)


static func _min_x(pts: PackedVector2Array, idx: Array) -> float:
	var m := INF
	for i in idx:
		m = minf(m, pts[i].x)
	return m


## `ring` with hole `k` spliced in: ... v, h, (round the hole), h, v ... for the nearest ring vertex v
## that h can see.
static func _bridge(pts: PackedVector2Array, ring: Array[int], holes: Array, hole_polys: Array, k: int) -> Array[int]:
	var hole: Array = holes[k]
	var hi := 0
	for j in hole.size():
		if pts[hole[j]].x < pts[hole[hi]].x:
			hi = j
	var h := pts[hole[hi]]
	var order: Array = []
	for r in ring.size():
		order.append(r)
	order.sort_custom(func(a, b): return pts[ring[a]].distance_squared_to(h) < pts[ring[b]].distance_squared_to(h))
	var ring_poly := PackedVector2Array()
	for i in ring:
		ring_poly.append(pts[i])
	for r in order:
		var v := pts[ring[r]]
		if not _sees(pts, ring, ring_poly, holes, hole_polys, h, v):
			continue
		var merged: Array[int] = []
		for i in range(r + 1):
			merged.append(ring[i])
		for j in hole.size():
			merged.append(hole[(hi + j) % hole.size()])
		merged.append(hole[hi])
		merged.append(ring[r])
		for i in range(r + 1, ring.size()):
			merged.append(ring[i])
		return merged
	push_error("PolyTriangulate: a hole at %s can see no vertex of the outline, and is left out" % h)
	return ring


## Does the segment h-v run inside the polygon, clear of every edge and every hole?
static func _sees(pts: PackedVector2Array, ring: Array[int], ring_poly: PackedVector2Array, holes: Array,
		hole_polys: Array, h: Vector2, v: Vector2) -> bool:
	var mid := (h + v) * 0.5
	if not Geometry2D.is_point_in_polygon(mid, ring_poly):
		return false
	for poly in hole_polys:
		if Geometry2D.is_point_in_polygon(mid, poly):
			return false
	var n := ring.size()
	for i in n:
		var a := pts[ring[i]]
		var b := pts[ring[(i + 1) % n]]
		if _crosses(h, v, a, b):
			return false
	for idx in holes:
		var m: int = idx.size()
		for i in m:
			if _crosses(h, v, pts[idx[i]], pts[idx[(i + 1) % m]]):
				return false
	return true


## Do the segments p-q and a-b cross properly? Touching at an end (the bridge's own ends) doesn't count.
static func _crosses(p: Vector2, q: Vector2, a: Vector2, b: Vector2) -> bool:
	if p == a or p == b or q == a or q == b:
		return false
	var d1 := (q - p).cross(a - p)
	var d2 := (q - p).cross(b - p)
	var d3 := (b - a).cross(p - a)
	var d4 := (b - a).cross(q - a)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


static func _clip_ears(pts: PackedVector2Array, ring: Array[int]) -> PackedInt32Array:
	var n := ring.size()
	var prev := PackedInt32Array()
	var nxt := PackedInt32Array()
	prev.resize(n)
	nxt.resize(n)
	for i in n:
		prev[i] = (i - 1 + n) % n
		nxt[i] = (i + 1) % n
	var out := PackedInt32Array()
	var left := n
	var cur := 0
	var stuck := 0
	var warned := false
	while left > 3:
		var a := prev[cur]
		var c := nxt[cur]
		var pa := pts[ring[a]]
		var pb := pts[ring[cur]]
		var pc := pts[ring[c]]
		var area := (pb - pa).cross(pc - pb)
		var clip := false
		var emit := true
		if absf(area) < EPS:
			# Collinear or doubled: the corner adds nothing.
			clip = true
			emit = false
		elif area > 0.0 and _ear_is_empty(pts, ring, nxt, a, c, pa, pb, pc):
			clip = true
		if not clip and stuck > left:
			# No ear anywhere (a polygon that touches itself): cut the sharpest convex corner anyway.
			var best := cur
			var best_area := -INF
			var p := nxt[cur]
			for step in left:
				var q := pts[ring[prev[p]]]
				var r := pts[ring[p]]
				var s := pts[ring[nxt[p]]]
				var ar := (r - q).cross(s - r)
				if ar > best_area:
					best_area = ar
					best = p
				p = nxt[p]
			cur = best
			a = prev[cur]
			c = nxt[cur]
			clip = true
			if not warned:
				push_warning("PolyTriangulate: no ear found with %d corners left" % left)
				warned = true
		if clip:
			if emit:
				out.append(ring[a])
				out.append(ring[cur])
				out.append(ring[c])
			nxt[a] = c
			prev[c] = a
			left -= 1
			cur = c
			stuck = 0
		else:
			cur = c
			stuck += 1
	if left == 3:
		var a2 := prev[cur]
		var c2 := nxt[cur]
		if (pts[ring[cur]] - pts[ring[a2]]).cross(pts[ring[c2]] - pts[ring[cur]]) > EPS:
			out.append(ring[a2])
			out.append(ring[cur])
			out.append(ring[c2])
	return out


## No other corner of the remaining polygon in the triangle a-b-c (the copies of its own corners that a
## bridge leaves don't count).
static func _ear_is_empty(pts: PackedVector2Array, ring: Array[int], nxt: PackedInt32Array, a: int, c: int,
		pa: Vector2, pb: Vector2, pc: Vector2) -> bool:
	var x0 := minf(pa.x, minf(pb.x, pc.x))
	var x1 := maxf(pa.x, maxf(pb.x, pc.x))
	var y0 := minf(pa.y, minf(pb.y, pc.y))
	var y1 := maxf(pa.y, maxf(pb.y, pc.y))
	var p := nxt[c]
	while p != a:
		var q := pts[ring[p]]
		p = nxt[p]
		if q.x < x0 or q.x > x1 or q.y < y0 or q.y > y1:
			continue
		if q == pa or q == pb or q == pc:
			continue
		if (pb - pa).cross(q - pa) >= 0.0 and (pc - pb).cross(q - pb) >= 0.0 and (pa - pc).cross(q - pc) >= 0.0:
			return false
	return true
