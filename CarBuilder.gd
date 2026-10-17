# CarBuilder.gd
#
# Geometry toolkit for the procedural RC cars (regenerate_cars.gd builds them, one *Builder.gd per
# car). A car is built in the cart frame: metres, X right, Y up, front at -Z, the ground at y = 0.
# Everything goes into one indexed mesh drawn by car_body.gdshader; each vertex carries its
# material id in UV2.x (the M_* constants), so a whole car body is a single draw call and the
# player's paint job is per-instance shader parameters, not separate materials.
#
# Smooth surfaces (grids, lathes, tubes, rounded boxes) share vertices and get normals from their
# own parameterisation. Winding: Godot front faces are clockwise, the face normal of (a, b, c) is
# (c - a) x (b - a); tri() flips any triangle whose face disagrees with its vertex normals, so a
# surface comes out right as long as its normals point outward when it's built. To turn a surface
# around afterwards use flip() (or orient_*()), which rewinds the triangles too: negating only the
# normals leaves the faces pointing inward, culled, and the surface vanishes.
extends RefCounted

# Material ids (UV2.x). car_body.gdshader switches on these.
const M_BODY := 0       # paint, plus the body's detail map (glass, seals, panel gaps, trim)
const M_PAINT := 1      # paint without the detail map (fenders, mirror shells)
const M_RUBBER := 2
const M_RIM := 3        # wheel rims and spokes: the player's rim colour
const M_CHROME := 4
const M_ALLOY := 5      # brushed aluminium: bumpers, nerf bars, skid plates, dampers
const M_DARK := 6       # black plastic, chassis, wheel wells (vertex colour is the shade)
const M_ANODISED := 7   # springs and diff covers: the player's accent colour
const M_HEADLAMP := 8
const M_TAILLAMP := 9   # lamp lens in its vertex colour (red tail, amber marker)

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()


func vertex(p: Vector3, n: Vector3, mat: int, col: Color, uv := Vector2.ZERO) -> int:
	_v.append(p)
	_n.append(n.normalized() if n.length_squared() > 1e-20 else Vector3.UP)
	_uv.append(uv)
	_uv2.append(Vector2(mat, 0.0))
	_c.append(col)
	return _v.size() - 1


## A triangle whose front face agrees with its vertex normals. Degenerate triangles are dropped.
func tri(a: int, b: int, c: int) -> void:
	var f: Vector3 = (_v[c] - _v[a]).cross(_v[b] - _v[a])
	if f.length_squared() < 1e-18:
		return
	if f.dot(_n[a] + _n[b] + _n[c]) < 0.0:
		var t := b
		b = c
		c = t
	_i.append(a)
	_i.append(b)
	_i.append(c)


## Quad a-b-c-d (in order around it), split along its shorter diagonal.
func quad(a: int, b: int, c: int, d: int) -> void:
	if _v[a].distance_squared_to(_v[c]) <= _v[b].distance_squared_to(_v[d]):
		tri(a, b, c)
		tri(a, c, d)
	else:
		tri(a, b, d)
		tri(b, c, d)


## A smooth surface through rows of points, pts[i][j]. Normals are (d/dj) x (d/di) of the grid,
## negated with `flip`. `closed_j` joins each row's last point back to its first. A row that has
## collapsed to a point (a pole) takes the average normal of the row next to it.
## `uvs`, if given, is an Array of PackedVector2Array matching pts.
func grid(pts: Array, mat: int, col: Color, flip := false, closed_j := false, uvs: Array = []) -> void:
	var ni: int = pts.size()
	var nj: int = (pts[0] as PackedVector3Array).size()
	var ns := []
	for i in ni:
		var row: PackedVector3Array = pts[i]
		var prev: PackedVector3Array = pts[maxi(i - 1, 0)]
		var next: PackedVector3Array = pts[mini(i + 1, ni - 1)]
		var nrow := PackedVector3Array()
		for j in nj:
			var j0: int = (j - 1 + nj) % nj if closed_j else maxi(j - 1, 0)
			var j1: int = (j + 1) % nj if closed_j else mini(j + 1, nj - 1)
			var n: Vector3 = (row[j1] - row[j0]).cross(next[j] - prev[j])
			nrow.append(-n if flip else n)
		ns.append(nrow)
	# Poles: a collapsed row has no span along j, so it borrows its neighbour's mean normal.
	for i in ni:
		var nrow: PackedVector3Array = ns[i]
		var degenerate := true
		for j in nj:
			if nrow[j].length_squared() > 1e-16:
				degenerate = false
				break
		if not degenerate or ni < 2:
			continue
		var other: PackedVector3Array = ns[1 if i == 0 else i - 1]
		var avg := Vector3.ZERO
		for j in nj:
			avg += other[j].normalized()
		for j in nj:
			nrow[j] = avg
		ns[i] = nrow
	var base: int = _v.size()
	for i in ni:
		var row: PackedVector3Array = pts[i]
		var nrow: PackedVector3Array = ns[i]
		for j in nj:
			var uv := Vector2(float(i) / maxf(ni - 1, 1), float(j) / maxf(nj - 1, 1))
			if not uvs.is_empty():
				uv = (uvs[i] as PackedVector2Array)[j]
			vertex(row[j], nrow[j], mat, col, uv)
	var jn: int = nj if closed_j else nj - 1
	for i in ni - 1:
		for j in jn:
			var j2: int = (j + 1) % nj
			quad(base + i * nj + j, base + i * nj + j2, base + (i + 1) * nj + j2, base + (i + 1) * nj + j)


## A surface of revolution about `axis` (unit) through `centre`. Profile points are
## Vector2(offset along the axis, radius). A partial sweep from a0 to a1 is left open.
## The profile is smooth-shaded along its length; split it into several lathe() calls for creases.
func lathe(centre: Vector3, axis: Vector3, profile: PackedVector2Array, segs: int, mat: int, col: Color,
		flip := false, a0 := 0.0, a1 := TAU) -> void:
	var e1: Vector3 = _perp(axis)
	var e2: Vector3 = axis.cross(e1).normalized()
	var full: bool = is_equal_approx(a1 - a0, TAU)
	var n: int = segs if full else segs + 1
	var rows := []
	for k in profile.size():
		var row := PackedVector3Array()
		for s in n:
			var a: float = a0 + (a1 - a0) * float(s) / segs
			row.append(centre + axis * profile[k].x + (e1 * cos(a) + e2 * sin(a)) * profile[k].y)
		rows.append(row)
	grid(rows, mat, col, flip, full)


## A flat disc (or ring, with r_in > 0) facing `normal`.
func disc(centre: Vector3, normal: Vector3, r_out: float, r_in: float, segs: int, mat: int, col: Color) -> void:
	var e1: Vector3 = _perp(normal)
	var e2: Vector3 = normal.cross(e1).normalized()
	var c: int = vertex(centre, normal, mat, col) if r_in <= 0.0 else -1
	var outer := []
	var inner := []
	for s in segs:
		var a: float = TAU * s / segs
		var d: Vector3 = e1 * cos(a) + e2 * sin(a)
		outer.append(vertex(centre + d * r_out, normal, mat, col))
		if r_in > 0.0:
			inner.append(vertex(centre + d * r_in, normal, mat, col))
	for s in segs:
		var s2: int = (s + 1) % segs
		if r_in > 0.0:
			quad(outer[s], outer[s2], inner[s2], inner[s])
		else:
			tri(c, outer[s], outer[s2])


## A round tube along a polyline, with optional per-point radii and flat end caps.
func tube(path: PackedVector3Array, radius: float, segs: int, mat: int, col: Color, cap_a := true, cap_b := true,
		radii := PackedFloat32Array()) -> void:
	var frames: Array = _frames(path)
	var rows := []
	for k in path.size():
		var r: float = radii[k] if radii.size() == path.size() else radius
		var e1: Vector3 = frames[k][0]
		var e2: Vector3 = frames[k][1]
		var row := PackedVector3Array()
		for s in segs:
			var a: float = TAU * s / segs
			row.append(path[k] + (e1 * cos(a) + e2 * sin(a)) * r)
		rows.append(row)
	# Normals must point away from the path; the grid's sign depends on the frames' handedness.
	var base: int = _v.size()
	var ibase: int = _i.size()
	grid(rows, mat, col, false, true)
	if _n[base].dot(rows[0][0] - path[0]) < 0.0:
		flip(base, ibase)
	if cap_a:
		var ra: float = radii[0] if radii.size() == path.size() else radius
		disc(path[0], (path[0] - path[1]).normalized(), ra, 0.0, segs, mat, col)
	if cap_b:
		var last: int = path.size() - 1
		var rb: float = radii[last] if radii.size() == path.size() else radius
		disc(path[last], (path[last] - path[last - 1]).normalized(), rb, 0.0, segs, mat, col)


## A tube with an elliptical section (radii r1 along frame e1, r2 along e2), e.g. an oval bumper bar.
## `up` picks e2's direction where possible.
func oval_tube(path: PackedVector3Array, r1: float, r2: float, up: Vector3, segs: int, mat: int, col: Color,
		round_ends := true) -> void:
	var rows := []
	var t: Vector3 = (path[path.size() - 1] - path[0]).normalized()
	var e2: Vector3 = (up - t * up.dot(t)).normalized()
	var e1: Vector3 = e2.cross(t).normalized()
	var n_end: int = 5 if round_ends else 0
	# Rounded ends: shrink the section over the last r1 of each end, like a capsule.
	var cap_len: float = minf(r1, r2)
	var pts := []
	var scales := []
	for k in range(n_end, 0, -1):
		var a: float = PI * 0.5 * k / (n_end + 0.0)
		pts.append(path[0] - t * cap_len * sin(a))
		scales.append(cos(a))
	for k in path.size():
		pts.append(path[k])
		scales.append(1.0)
	for k in range(1, n_end + 1):
		var a: float = PI * 0.5 * k / (n_end + 0.0)
		pts.append(path[path.size() - 1] + t * cap_len * sin(a))
		scales.append(cos(a))
	for k in pts.size():
		var row := PackedVector3Array()
		for s in segs:
			var a: float = TAU * s / segs
			row.append(pts[k] + (e1 * cos(a) * r1 + e2 * sin(a) * r2) * scales[k])
		rows.append(row)
	var base: int = _v.size()
	var ibase: int = _i.size()
	grid(rows, mat, col, false, true)
	if _n[base + segs * 2].dot(rows[2][0] - pts[2]) < 0.0:
		flip(base, ibase)


## A coil spring: a helix of wire radius `wire` around the segment a -> b.
func spring(a: Vector3, b: Vector3, coil_r: float, wire: float, turns: float, mat: int, col: Color) -> void:
	var axis: Vector3 = (b - a).normalized()
	var e1: Vector3 = _perp(axis)
	var e2: Vector3 = axis.cross(e1).normalized()
	var path := PackedVector3Array()
	var steps: int = int(turns * 10.0)
	for k in steps + 1:
		var t: float = float(k) / steps
		var ang: float = TAU * turns * t
		path.append(a.lerp(b, t) + (e1 * cos(ang) + e2 * sin(ang)) * coil_r)
	tube(path, wire, 5, mat, col, false, false)


## A rounded box: `xf` places it (its basis must be orthonormal), `h` is the half-size along the
## basis axes and `r` the edge radius. Edges and corners are quarter-rounds of `k` steps; the flat
## middle of each face is one quad, so it costs little whatever its size. Normals are exact.
func rbox(xf: Transform3D, h: Vector3, r: float, k: int, mat: int, col: Color) -> void:
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.999)
	var inner: Vector3 = h - Vector3(r, r, r)
	# Grid values along each axis: a quarter-round at each end, nothing in the flat middle.
	var vals := []
	for ax in 3:
		var v := PackedFloat32Array()
		for s in range(k, -1, -1):
			v.append(-inner[ax] - r * sin(PI * 0.5 * s / k))
		for s in range(0, k + 1):
			v.append(inner[ax] + r * sin(PI * 0.5 * s / k))
		vals.append(v)
	for face in 6:
		var axis: int = face / 2
		var sgn: float = 1.0 if face % 2 == 0 else -1.0
		var ua: int = (axis + 1) % 3
		var va: int = (axis + 2) % 3
		var uvals: PackedFloat32Array = vals[ua]
		var vvals: PackedFloat32Array = vals[va]
		var base: int = _v.size()
		for a in uvals.size():
			for b in vvals.size():
				var q := Vector3.ZERO
				q[axis] = sgn * h[axis]
				q[ua] = uvals[a]
				q[va] = vvals[b]
				var c := Vector3(clampf(q.x, -inner.x, inner.x), clampf(q.y, -inner.y, inner.y), clampf(q.z, -inner.z, inner.z))
				var n: Vector3 = (q - c).normalized()
				vertex(xf * (c + n * r), xf.basis * n, mat, col)
		var nv: int = vvals.size()
		for a in uvals.size() - 1:
			for b in nv - 1:
				quad(base + a * nv + b, base + a * nv + b + 1, base + (a + 1) * nv + b + 1, base + (a + 1) * nv + b)


## A flat-shaded convex polygon (points in order), facing `normal`.
func poly(pts: PackedVector3Array, normal: Vector3, mat: int, col: Color) -> void:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var ci: int = vertex(c, normal, mat, col)
	var ids := []
	for p in pts:
		ids.append(vertex(p, normal, mat, col))
	for k in ids.size():
		tri(ci, ids[k], ids[(k + 1) % ids.size()])


## Mirrors everything added since `from_vertex` across x = 0 (for symmetric parts built on one side).
func mirror_x(from_vertex: int, from_index: int) -> void:
	var off: int = _v.size() - from_vertex
	var nv: int = _v.size()
	for k in range(from_vertex, nv):
		var p: Vector3 = _v[k]
		var n: Vector3 = _n[k]
		_v.append(Vector3(-p.x, p.y, p.z))
		_n.append(Vector3(-n.x, n.y, n.z))
		_uv.append(_uv[k])
		_uv2.append(_uv2[k])
		_c.append(_c[k])
	var ni: int = _i.size()
	for k in range(from_index, ni, 3):
		# Mirroring flips handedness: swap two corners to keep the faces outward.
		_i.append(_i[k] + off)
		_i.append(_i[k + 2] + off)
		_i.append(_i[k + 1] + off)


## Moves everything added since `from_vertex` by `xf`, whose basis is a rotation (uniformly
## scaled at most): a part built round the origin, put in place.
func transform_from(from_vertex: int, xf: Transform3D) -> void:
	for k in range(from_vertex, _v.size()):
		_v[k] = xf * _v[k]
		_n[k] = (xf.basis * _n[k]).normalized()


## Mirrors everything built so far across x = 0, in place (a left wheel from a right one).
func mirror_in_place() -> void:
	for k in _v.size():
		var p: Vector3 = _v[k]
		var n: Vector3 = _n[k]
		_v[k] = Vector3(-p.x, p.y, p.z)
		_n[k] = Vector3(-n.x, n.y, n.z)
	for k in range(0, _i.size(), 3):
		var t: int = _i[k + 1]
		_i[k + 1] = _i[k + 2]
		_i[k + 2] = t


## Turns everything added since (v_from, i_from) inside out: normals negated, triangles rewound.
## Orientation fixes must go through here; flipping only the normals would leave the triangles
## wound for the old ones, facing inward and culled.
func flip(v_from: int, i_from: int) -> void:
	for k in range(v_from, _v.size()):
		_n[k] = -_n[k]
	for k in range(i_from, _i.size(), 3):
		var t: int = _i[k + 1]
		_i[k + 1] = _i[k + 2]
		_i[k + 2] = t


## Flips what was added since (v_from, i_from) if its normals mostly point toward `centre`
## (a lathe or patch whose parameterisation came out inward).
func orient_away_from(v_from: int, i_from: int, centre: Vector3) -> void:
	var s := 0.0
	for k in range(v_from, _v.size()):
		s += _n[k].dot(_v[k] - centre)
	if s < 0.0:
		flip(v_from, i_from)


## Flips what was added since (v_from, i_from) if its normals mostly point against `dir`.
func orient_toward(v_from: int, i_from: int, dir: Vector3) -> void:
	var s := Vector3.ZERO
	for k in range(v_from, _v.size()):
		s += _n[k]
	if s.dot(dir) < 0.0:
		flip(v_from, i_from)


func vertex_count() -> int:
	return _v.size()


func index_count() -> int:
	return _i.size()


func triangle_count() -> int:
	return _i.size() / 3


func commit(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_INDEX] = _i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	return mesh


# --------------------------------------------------------------------------------------------
#  Helpers
# --------------------------------------------------------------------------------------------

static func _perp(axis: Vector3) -> Vector3:
	var ref: Vector3 = Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	return axis.cross(ref).normalized()


## Parallel-transport frames along a polyline: [e1, e2] per point, both perpendicular to it.
static func _frames(path: PackedVector3Array) -> Array:
	var out := []
	var n: int = path.size()
	var t0: Vector3 = (path[1] - path[0]).normalized()
	var e1: Vector3 = _perp(t0)
	for k in n:
		var t: Vector3
		if k == 0:
			t = t0
		elif k == n - 1:
			t = (path[k] - path[k - 1]).normalized()
		else:
			t = (path[k + 1] - path[k - 1]).normalized()
		e1 = (e1 - t * e1.dot(t)).normalized()
		var e2: Vector3 = t.cross(e1).normalized()
		out.append([e1, e2])
	return out


## Resamples a polyline to `count` points spaced evenly by arc length plus `bend` metres per
## radian of turning, so curved stretches get more points than straight ones.
static func resample(pts: PackedVector2Array, count: int, bend: float) -> PackedVector2Array:
	var acc := PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		var w: float = pts[k].distance_to(pts[k - 1])
		if k > 1:
			var d0: Vector2 = pts[k - 1] - pts[k - 2]
			var d1: Vector2 = pts[k] - pts[k - 1]
			if d0.length_squared() > 1e-14 and d1.length_squared() > 1e-14:
				w += bend * absf(d0.angle_to(d1))
		acc.append(acc[k - 1] + w)
	var total: float = acc[acc.size() - 1]
	var out := PackedVector2Array()
	var seg := 1
	for s in count:
		var target: float = total * s / (count - 1)
		while seg < acc.size() - 1 and acc[seg] < target:
			seg += 1
		var a0: float = acc[seg - 1]
		var a1: float = acc[seg]
		var t: float = 0.0 if a1 - a0 < 1e-12 else clampf((target - a0) / (a1 - a0), 0.0, 1.0)
		out.append(pts[seg - 1].lerp(pts[seg], t))
	return out


## A smooth 1D curve through (x, y) knots: monotone cubic Hermite (Fritsch-Carlson), so it never
## overshoots between knots and levels off at local peaks (a roofline stays flat on top).
class Profile:
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var ms := PackedFloat32Array()

	func _init(knots: Array) -> void:
		for k in knots:
			xs.append(k[0])
			ys.append(k[1])
		var n: int = xs.size()
		var d := PackedFloat32Array()
		for k in n - 1:
			d.append((ys[k + 1] - ys[k]) / (xs[k + 1] - xs[k]))
		ms.resize(n)
		ms[0] = d[0]
		ms[n - 1] = d[n - 2]
		for k in range(1, n - 1):
			ms[k] = 0.0 if d[k - 1] * d[k] <= 0.0 else (d[k - 1] + d[k]) * 0.5
		for k in n - 1:
			if absf(d[k]) < 1e-12:
				ms[k] = 0.0
				ms[k + 1] = 0.0
				continue
			var a: float = ms[k] / d[k]
			var b: float = ms[k + 1] / d[k]
			var s: float = a * a + b * b
			if s > 9.0:
				var t: float = 3.0 / sqrt(s)
				ms[k] = t * a * d[k]
				ms[k + 1] = t * b * d[k]

	func at(x: float) -> float:
		var n: int = xs.size()
		if x <= xs[0]:
			return ys[0]
		if x >= xs[n - 1]:
			return ys[n - 1]
		var k := 0
		while k < n - 2 and x > xs[k + 1]:
			k += 1
		var h: float = xs[k + 1] - xs[k]
		var t: float = (x - xs[k]) / h
		var t2: float = t * t
		var t3: float = t2 * t
		return (2.0 * t3 - 3.0 * t2 + 1.0) * ys[k] + (t3 - 2.0 * t2 + t) * h * ms[k] \
				+ (-2.0 * t3 + 3.0 * t2) * ys[k + 1] + (t3 - t2) * h * ms[k + 1]
