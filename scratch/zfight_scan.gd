extends SceneTree

# Finds z-fighting in saved meshes: triangles lying in the same plane (within `tol` metres) that
# overlap by more than a sliver. For double-sided surfaces, faces back to back count too.
#   Godot --headless --path . -s res://scratch/zfight_scan.gd -- res://generated/x.res ... [tol=0.002]
# Prints each clash once per pair of colours/surfaces, with where it is.

var tol := 0.002


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tol="):
			tol = float(a.substr(4))
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("tol="):
			_scan(a)
	quit()


func _scan(path: String) -> void:
	var mesh: ArrayMesh = load(path)
	var tris: Array = []   # [a, b, c, n, d, surface, colour, double]
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols = arr[Mesh.ARRAY_COLOR]
		var idx = arr[Mesh.ARRAY_INDEX]
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		var double := mat != null and mat.cull_mode == BaseMaterial3D.CULL_DISABLED
		var count: int = idx.size() if idx != null and idx.size() > 0 else v.size()
		for t in range(0, count, 3):
			var i0: int = idx[t] if idx != null and idx.size() > 0 else t
			var i1: int = idx[t + 1] if idx != null and idx.size() > 0 else t + 1
			var i2: int = idx[t + 2] if idx != null and idx.size() > 0 else t + 2
			var a := v[i0]
			var b := v[i1]
			var c := v[i2]
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-10:
				continue
			n = n.normalized()
			var col: Color = cols[i0] if cols != null and cols.size() > 0 else Color.WHITE
			tris.append([a, b, c, n, n.dot(a), s, col, double])
	# Bucket by plane; a triangle goes in its own bucket and, if double-sided, the flipped one.
	var buckets := {}
	for i in tris.size():
		var t: Array = tris[i]
		for sign in ([1.0, -1.0] if t[7] else [1.0]):
			var n: Vector3 = t[3] * sign
			var key := Vector4i(roundi(n.x * 100), roundi(n.y * 100), roundi(n.z * 100), roundi(t[4] * sign / tol))
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(i)
	var seen := {}
	var clashes := 0
	for key in buckets:
		var list: Array = buckets[key]
		# Neighbouring distance bins can hold the same plane: merge in the next one up.
		var k2 := Vector4i(key.x, key.y, key.z, key.w + 1)
		if buckets.has(k2):
			list = list + buckets[k2]
		if list.size() < 2 or list.size() > 4000:
			continue
		for x in list.size():
			for y in range(x + 1, list.size()):
				var p: Array = tris[list[x]]
				var q: Array = tris[list[y]]
				if list[x] == list[y]:
					continue
				# Same plane facing the same way within tol, or back to back on a double-sided surface.
				var same: bool = (p[3] as Vector3).dot(q[3]) > 0.999
				var back: bool = (p[3] as Vector3).dot(q[3]) < -0.999 and (p[7] or q[7])
				if not same and not back:
					continue
				if absf((p[3] as Vector3).dot((q[0] as Vector3) - (p[0] as Vector3))) > tol:
					continue
				if not _overlap(p, q):
					continue
				var tag := "%d/%s - %d/%s" % [p[5], (p[6] as Color).to_html(false), q[5], (q[6] as Color).to_html(false)]
				if seen.has(tag):
					continue
				seen[tag] = true
				clashes += 1
				var at := ((p[0] as Vector3) + (p[1] as Vector3) + (p[2] as Vector3)) / 3.0
				print("  %s at %s %s" % [tag, at.snappedf(0.01), "back-to-back" if back else ""])
	print("%s: %d triangles, %d clashing colour pairs" % [path.get_file(), tris.size(), clashes])


## Do two coplanar triangles share area (not just an edge)? Shrunk 2% toward their centroids, then
## a separating-axis test in the plane.
func _overlap(p: Array, q: Array) -> bool:
	var n: Vector3 = p[3]
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := n.cross(u)
	var pa := _shrink([p[0], p[1], p[2]], u, w)
	var qa := _shrink([q[0], q[1], q[2]], u, w)
	for poly in [pa, qa]:
		for e in 3:
			var e0: Vector2 = poly[e]
			var e1: Vector2 = poly[(e + 1) % 3]
			var axis := Vector2(e1.y - e0.y, e0.x - e1.x)
			var a_min := INF
			var a_max := -INF
			var b_min := INF
			var b_max := -INF
			for pt in pa:
				a_min = minf(a_min, axis.dot(pt))
				a_max = maxf(a_max, axis.dot(pt))
			for pt in qa:
				b_min = minf(b_min, axis.dot(pt))
				b_max = maxf(b_max, axis.dot(pt))
			if a_max <= b_min or b_max <= a_min:
				return false
	return true


func _shrink(pts: Array, u: Vector3, w: Vector3) -> Array:
	var c: Vector3 = (pts[0] + pts[1] + pts[2]) / 3.0
	var out := []
	for p in pts:
		var s: Vector3 = c + ((p as Vector3) - c) * 0.98
		out.append(Vector2(s.dot(u), s.dot(w)))
	return out
