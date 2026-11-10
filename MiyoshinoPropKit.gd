extends "res://MiyoshinoKit.gd"
## The Miyoshino GP's props (the four stages' generators): shrine things, lanterns, roadside furniture and hanami gear, on
## MiyoshinoKit's materials and palette. Life size in metres (the generators grow it by 1.6): y up, the ground at y = 0,
## fronts toward +z; whatever stands on the ground runs 0.6m into it, so nothing floats on a slope. `new_kit(scale)`, set
## the frame, call builders, `commit(pk, kit)`.
##
## No writing: the project has no CJK font. The cup's emblem is `sakura_crest` (five notched petals, flat geometry 1.5cm
## proud), and what must be read goes into a builder's `labels` as YardKit's [text, position, outward normal, cap height,
## colour, board width] (life size, the prop's frame), romaji capitals.
##
## What glows: "washi" (paper lanterns, fire-boxes, andon: lit at dusk when MiyoshinoKit.night is set before the first
## new_kit, plain paper by day) and "neon" (the vending machine's window). Sculpted stone (lanterns, statues, cairns) is
## "matte" in the granite colours: "ishi" draws coursed ashlar from UVs in metres, right for plinths, steps and platforms
## and wrong on a carved figure.
##
## The builders (centred on the origin unless they take points):
##   sakura_crest(pk, kit, key, c, out, r, col)        the emblem on the plane through c facing out
##   torii(pk, kit, style, w, h)                       road along z, pillars' axes w apart, h clear under the tie beam;
##                                                     0 vermilion myojin with a tablet, 1 granite, 2 cedar with a rope
##   shimenawa(pk, kit, a, b, thick, shide, sag, drop) a straw rope between two points; rope_ring(pk, kit, r, y, shide)
##   stone_lantern(pk, kit, style, h)                  0 kasuga (h tall), 1 yukimi on three legs (0.55 h tall)
##   chochin(pk, kit, c, r, col, crest), chochin_string(pk, kit, a, b, n, sag, cols), bonbori(pk, kit, h, col)
##   wood_lantern_post(pk, kit, h), utility_pole(pk, kit, h, variant), pole_wires(pk, kit, a, b, sag, n)
##   guardrail(pk, kit, a, b), curve_mirror(pk, kit, twin), road_sign(pk, kit, kind, labels, text), nobori(pk, kit, col, h, crest)
##   jizo_row(pk, kit, n, rng), komainu(pk, kit, mirror), stone_marker(pk, kit, h, text, labels), cairn(pk, kit, rng, h),
##   hokora(pk, kit)
##   koran, chain_fence, rope_fence, bamboo_fence (pk, kit, a, b, h): between two ground points, following the slope
##   hanami_set(pk, kit, variant, rng), red_bench(pk, kit, parasol), sake_barrels(pk, kit, cols, rows),
##   vending_machine(pk, kit, variant)
##   arched_bridge(pk, kit, span, width, rise), summit_shrine(pk, kit, labels, text), ema_rack(pk, kit, w), chozuya(pk, kit),
##   stone_steps(pk, kit, w, n, rise, run), kei_truck(pk, kit, col)
##
## Faces never share a plane: trim, paint and emblems stand 1.5-2.5cm proud of what carries them, parts that meet run
## into each other. Thin sheets (banners, shide papers, bibs, the parasol) are "cloth", one face seen from both sides.
## Godot's front faces wind clockwise: PropKit.tri winds every triangle for the `out` it is given, and `_loft` works out
## which way is out for a whole skin.

const OFF_WHITE := Color(0.93, 0.93, 0.90)
const RAIL_WHITE := Color(0.90, 0.91, 0.90)
const MIRROR_ORANGE := Color(0.95, 0.42, 0.06)
const SIGN_YELLOW := Color(0.98, 0.80, 0.08)
const SIGN_RED := Color(0.80, 0.10, 0.10)
const SIGN_BLUE := Color(0.10, 0.25, 0.62)
const SIGN_BROWN := Color(0.40, 0.25, 0.15)
const INK := Color(0.06, 0.06, 0.06)
const POLE_GREY := Color(0.60, 0.60, 0.58)
const GALV := Color(0.62, 0.64, 0.64)
const IRON := Color(0.13, 0.13, 0.14)
const TARP_BLUE := Color(0.12, 0.36, 0.78)
const FELT_RED := Color(0.78, 0.10, 0.10)
const BIB_RED := Color(0.82, 0.10, 0.08)
const SHIDE_WHITE := Color(0.97, 0.97, 0.94)
const STONE_A := Color(0.56, 0.58, 0.53)
const STONE_B := Color(0.47, 0.52, 0.44)

## A torii's lean (its pillars stand wider at the foot) per metre of height.
const TORII_LEAN := 0.028
## Where a utility pole's wires leave it, under its top: the high-voltage arm's three and the lower arm's two.
const POLE_WIRE_HIGH := 0.15
const POLE_WIRE_LOW := 1.55
const POLE_WIRE_GAP := 0.65


# ======================================================================================
#  Helpers
# ======================================================================================

## A plane's frame through `c`: z out of it, x to the right seen from in front, y up it (away from the viewer for a
## face that looks up).
static func _pl(c: Vector3, out: Vector3) -> Transform3D:
	var z := out.normalized()
	var up := Vector3.UP if absf(z.y) < 0.9 else Vector3.FORWARD
	var x := up.cross(z).normalized()
	return Transform3D(Basis(x, z.cross(x), z), c)


## Moves the kit's frame by `t` (in the frame's own axes) and returns the old one, to put back with set_frame.
static func _push(pk: PropKit, t: Transform3D) -> Transform3D:
	var old: Transform3D = pk.xf
	pk.set_frame(old * t)
	return old


## A flat polygon in a plane's frame, `d` out of it.
static func _flat(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, pts: PackedVector2Array, d: float, col: Color) -> void:
	var n: Vector3 = wf.basis.z
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in range(0, idx.size(), 3):
		var a: Vector2 = pts[idx[i]]
		var b: Vector2 = pts[idx[i + 1]]
		var c: Vector2 = pts[idx[i + 2]]
		pk.tri(kit, key, wf * Vector3(a.x, a.y, d), wf * Vector3(b.x, b.y, d), wf * Vector3(c.x, c.y, d), n, n, n, col, n)


static func _rect(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, d: float, col: Color) -> void:
	var n: Vector3 = wf.basis.z
	pk.quad(kit, key, [wf * Vector3(u0, v0, d), wf * Vector3(u1, v0, d), wf * Vector3(u1, v1, d), wf * Vector3(u0, v1, d)], n, col)


## A box in a plane's frame, from depth d0 to d1.
static func _slab(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, d0: float, d1: float, col: Color) -> void:
	pk.box(kit, key, wf * Transform3D(Basis(), Vector3((u0 + u1) * 0.5, (v0 + v1) * 0.5, (d0 + d1) * 0.5)), Vector3(absf(u1 - u0), absf(v1 - v0), absf(d1 - d0)), col)


## A band `w` wide along a polyline in a plane's frame, its corners mitred (no piece overlaps the next).
static func _stroke(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, pts: Array, w: float, d: float, col: Color, closed := false) -> void:
	var n: int = pts.size()
	var l: Array = []
	var r: Array = []
	for i in range(n):
		var p: Vector2 = pts[i]
		var has_prev: bool = closed or i > 0
		var has_next: bool = closed or i < n - 1
		var d0: Vector2 = (p - (pts[(i - 1 + n) % n] as Vector2)).normalized() if has_prev else Vector2.ZERO
		var d1: Vector2 = ((pts[(i + 1) % n] as Vector2) - p).normalized() if has_next else Vector2.ZERO
		if not has_prev:
			d0 = d1
		if not has_next:
			d1 = d0
		var n0 := Vector2(-d0.y, d0.x)
		var n1 := Vector2(-d1.y, d1.x)
		var m: Vector2 = (n0 + n1).normalized()
		var k: float = (w * 0.5) / maxf(m.dot(n0), 0.4)
		l.append(p + m * k)
		r.append(p - m * k)
	var nz: Vector3 = wf.basis.z
	for i in range(n if closed else n - 1):
		var j: int = (i + 1) % n
		var r0: Vector2 = r[i]
		var r1: Vector2 = r[j]
		var l0: Vector2 = l[i]
		var l1: Vector2 = l[j]
		pk.quad(kit, key, [wf * Vector3(r0.x, r0.y, d), wf * Vector3(r1.x, r1.y, d), wf * Vector3(l1.x, l1.y, d), wf * Vector3(l0.x, l0.y, d)], nz, col)


## A ring (or a sector of one) in a plane's frame.
static func _annulus(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, c: Vector2, r0: float, r1: float, segs: int, d: float, col: Color,
		a0 := 0.0, a1 := TAU) -> void:
	var nz: Vector3 = wf.basis.z
	for i in range(segs):
		var t0: float = lerpf(a0, a1, float(i) / float(segs))
		var t1: float = lerpf(a0, a1, float(i + 1) / float(segs))
		var e0 := Vector2(cos(t0), sin(t0))
		var e1 := Vector2(cos(t1), sin(t1))
		var p: Array = [c + e0 * r0, c + e1 * r0, c + e1 * r1, c + e0 * r1]
		var q: Array = []
		for v: Vector2 in p:
			q.append(wf * Vector3(v.x, v.y, d))
		if r0 < 1e-5:
			pk.tri(kit, key, q[0], q[2], q[3], nz, nz, nz, col, nz)
		else:
			pk.quad(kit, key, q, nz, col)


static func _disc(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, c: Vector2, r: float, segs: int, d: float, col: Color) -> void:
	_annulus(pk, kit, key, wf, c, 0.0, r, segs, d, col)


## A small octahedron at c: knobs, curls, fruit, blossoms.
static func _octa(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: Vector3, col: Color, basis := Basis()) -> void:
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var a: Vector3 = c + basis * Vector3(r.x * sx, 0, 0)
				var b: Vector3 = c + basis * Vector3(0, r.y * sy, 0)
				var d: Vector3 = c + basis * Vector3(0, 0, r.z * sz)
				var n: Vector3 = (basis * Vector3(sx / r.x, sy / r.y, sz / r.z)).normalized()
				pk.tri(kit, key, a, b, d, n, n, n, col, n)


## A surface of revolution about the vertical through c: PropKit.lathe without its empty triangles at the axis and with
## a start angle (a six-sided lantern needs a face, not a corner, toward the front). `prof` walks the outside from the
## bottom up in (radius, height).
static func _turn(pk: PropKit, kit: Dictionary, key: String, c: Vector3, prof: Array, segs: int, col: Color, flat := false, a0 := 0.0, basis := Basis()) -> void:
	for k in range(prof.size() - 1):
		var p0: Vector2 = prof[k]
		var p1: Vector2 = prof[k + 1]
		var d := p1 - p0
		if d.length_squared() < 1e-12:
			continue
		var n2 := Vector2(d.y, -d.x).normalized()
		for j in range(segs):
			var t0: float = a0 + TAU * float(j) / float(segs)
			var t1: float = a0 + TAU * float(j + 1) / float(segs)
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var um := (u0 + u1).normalized()
			var out: Vector3 = basis * (um * n2.x + Vector3.UP * n2.y)
			var n0: Vector3 = out if flat else basis * (u0 * n2.x + Vector3.UP * n2.y)
			var n1: Vector3 = out if flat else basis * (u1 * n2.x + Vector3.UP * n2.y)
			var q00: Vector3 = c + basis * (u0 * p0.x + Vector3.UP * p0.y)
			var q01: Vector3 = c + basis * (u1 * p0.x + Vector3.UP * p0.y)
			var q10: Vector3 = c + basis * (u0 * p1.x + Vector3.UP * p1.y)
			var q11: Vector3 = c + basis * (u1 * p1.x + Vector3.UP * p1.y)
			if p0.x > 1e-4:
				pk.tri(kit, key, q00, q01, q11, n0, n1, n1, col, out)
			if p1.x > 1e-4:
				pk.tri(kit, key, q00, q11, q10, n0, n1, n0, col, out)


## An ellipsoid of radii `r` at c, turned by `basis`, with true normals however flat it is.
static func _ell(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: Vector3, segs: int, rings: int, col: Color, basis := Basis()) -> void:
	for i in range(rings):
		var t0: float = PI * float(i) / float(rings)
		var t1: float = PI * float(i + 1) / float(rings)
		for j in range(segs):
			var a0: float = TAU * float(j) / float(segs)
			var a1: float = TAU * float(j + 1) / float(segs)
			var s00 := Vector3(sin(t0) * cos(a0), -cos(t0), sin(t0) * sin(a0))
			var s01 := Vector3(sin(t0) * cos(a1), -cos(t0), sin(t0) * sin(a1))
			var s10 := Vector3(sin(t1) * cos(a0), -cos(t1), sin(t1) * sin(a0))
			var s11 := Vector3(sin(t1) * cos(a1), -cos(t1), sin(t1) * sin(a1))
			var out: Vector3 = (basis * ((s00 + s01 + s10 + s11) / r)).normalized()
			if i > 0:
				pk.tri(kit, key, c + basis * (s00 * r), c + basis * (s01 * r), c + basis * (s11 * r), basis * (s00 / r), basis * (s01 / r), basis * (s11 / r), col, out)
			if i < rings - 1:
				pk.tri(kit, key, c + basis * (s00 * r), c + basis * (s11 * r), c + basis * (s10 * r), basis * (s00 / r), basis * (s11 / r), basis * (s10 / r), col, out)


## A skin through `secs` (loops of the same number of points, each walking the same way round), flat shaded. Which side is
## out is worked out for the whole skin (the faces' area vectors against their places round its middle), or taken from
## `hint` for an open sheet. `uvm` 1: UVs in metres, u along the skin and v round it; 2: the other way (timber, whose
## grain runs along v). `closed` false: each loop is an open profile (a skin of revolution, a sheet).
static func _loft(pk: PropKit, kit: Dictionary, key: String, secs: Array, col: Color, cap0 := true, cap1 := true, uvm := 0, closed := true,
		hint := Vector3.ZERO) -> void:
	var ns: int = secs.size()
	var m: int = (secs[0] as Array).size()
	var edges: int = m if closed else m - 1
	var cen: Array = []
	var mid := Vector3.ZERO
	for s: Array in secs:
		var c := Vector3.ZERO
		for p: Vector3 in s:
			c += p
		c /= float(m)
		cen.append(c)
		mid += c / float(ns)
	var sgn := 0.0
	for i in range(ns - 1):
		for j in range(edges):
			var a: Vector3 = secs[i][j]
			var b: Vector3 = secs[i][(j + 1) % m]
			var e: Vector3 = secs[i + 1][j]
			var f: Vector3 = secs[i + 1][(j + 1) % m]
			var nq: Vector3 = (f - a).cross(b - a) + (e - a).cross(f - a)
			sgn += nq.dot(hint) if hint != Vector3.ZERO else nq.dot((a + b + e + f) * 0.25 - mid)
	var flip: float = -1.0 if sgn < 0.0 else 1.0
	var ul: Array = [0.0]
	for i in range(1, ns):
		ul.append(float(ul[i - 1]) + ((cen[i] as Vector3) - (cen[i - 1] as Vector3)).length())
	var vl: Array = [0.0]
	for j in range(1, m + 1):
		vl.append(float(vl[j - 1]) + ((secs[0][j % m] as Vector3) - (secs[0][j - 1] as Vector3)).length())
	for i in range(ns - 1):
		for j in range(edges):
			var a: Vector3 = secs[i][j]
			var b: Vector3 = secs[i][(j + 1) % m]
			var e: Vector3 = secs[i + 1][j]
			var f: Vector3 = secs[i + 1][(j + 1) % m]
			var nq: Vector3 = (f - a).cross(b - a) + (e - a).cross(f - a)
			if nq.length_squared() < 1e-14:
				continue
			var n: Vector3 = nq.normalized() * flip
			var ua := Vector2.ZERO
			var ub := Vector2.ZERO
			var ue := Vector2.ZERO
			var uf := Vector2.ZERO
			if uvm == 1:
				ua = Vector2(float(ul[i]), float(vl[j])) * uvk
				ub = Vector2(float(ul[i]), float(vl[j + 1])) * uvk
				ue = Vector2(float(ul[i + 1]), float(vl[j])) * uvk
				uf = Vector2(float(ul[i + 1]), float(vl[j + 1])) * uvk
			elif uvm == 2:
				ua = Vector2(float(vl[j]), float(ul[i])) * uvk
				ub = Vector2(float(vl[j + 1]), float(ul[i])) * uvk
				ue = Vector2(float(vl[j]), float(ul[i + 1])) * uvk
				uf = Vector2(float(vl[j + 1]), float(ul[i + 1])) * uvk
			if (b - a).cross(f - a).length_squared() > 1e-14:
				pk.tri(kit, key, a, b, f, n, n, n, col, n, ua, ub, uf)
			if (f - a).cross(e - a).length_squared() > 1e-14:
				pk.tri(kit, key, a, f, e, n, n, n, col, n, ua, uf, ue)
	if closed and cap0:
		_cap(pk, kit, key, secs[0], (cen[0] as Vector3) - (cen[1] as Vector3), col, uvm > 0)
	if closed and cap1:
		_cap(pk, kit, key, secs[ns - 1], (cen[ns - 1] as Vector3) - (cen[ns - 2] as Vector3), col, uvm > 0)


## A loop's flat end facing `dir` (the loop may be concave).
static func _cap(pk: PropKit, kit: Dictionary, key: String, loop: Array, dir: Vector3, col: Color, uv := false) -> void:
	var m: int = loop.size()
	var n := Vector3.ZERO
	for j in range(m):
		var p: Vector3 = loop[j]
		var q: Vector3 = loop[(j + 1) % m]
		n += Vector3((p.y - q.y) * (p.z + q.z), (p.z - q.z) * (p.x + q.x), (p.x - q.x) * (p.y + q.y))
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if n.dot(dir) < 0.0:
		n = -n
	var first: Vector3 = loop[0]
	var inv: Transform3D = _pl(first, n).affine_inverse()
	var pts := PackedVector2Array()
	for p: Vector3 in loop:
		var lp: Vector3 = inv * p
		pts.append(Vector2(lp.x, lp.y))
	var idx := Geometry2D.triangulate_polygon(pts)
	var k: float = uvk if uv else 0.0
	for i in range(0, idx.size(), 3):
		pk.tri(kit, key, loop[idx[i]], loop[idx[i + 1]], loop[idx[i + 2]], n, n, n, col, n, pts[idx[i]] * k, pts[idx[i + 1]] * k, pts[idx[i + 2]] * k)


## A squared bar from a to b, `w` wide along `side` and `t` thick, UVs in metres with the grain along it (timber), or
## u along it for stone (`grain` false).
static func _bar(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, t: float, col: Color, side := Vector3.ZERO, grain := true) -> void:
	var z: Vector3 = b - a
	if z.length_squared() < 1e-10:
		return
	z = z.normalized()
	var x: Vector3 = side
	if x.length_squared() < 1e-8 or absf(x.normalized().dot(z)) > 0.99:
		x = Vector3.UP.cross(z)
		if x.length_squared() < 1e-6:
			x = Vector3.RIGHT
	x = (x - z * x.dot(z)).normalized()
	var y: Vector3 = z.cross(x)
	var s0: Array = []
	var s1: Array = []
	for q: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var o: Vector3 = x * (w * 0.5 * q.x) + y * (t * 0.5 * q.y)
		s0.append(a + o)
		s1.append(b + o)
	_loft(pk, kit, key, [s0, s1], col, true, true, 2 if grain else 1)


## A squared post standing at p from y0 to y1.
static func _post(pk: PropKit, kit: Dictionary, key: String, p: Vector3, y0: float, y1: float, w: float, col: Color, d := -1.0) -> void:
	_bar(pk, kit, key, p + Vector3(0, y0, 0), p + Vector3(0, y1, 0), w, w if d < 0.0 else d, col, Vector3.RIGHT)


## Points along a line from a to b hanging `sag` in the middle: n pieces.
static func _sag(a: Vector3, b: Vector3, sag: float, n: int) -> Array:
	var out: Array = []
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		out.append(a.lerp(b, t) - Vector3.UP * (sag * 4.0 * t * (1.0 - t)))
	return out


## Thin tubes through `pts`: cords, wires, chains.
static func _strand(pk: PropKit, kit: Dictionary, key: String, pts: Array, r: float, segs: int, col: Color) -> void:
	for i in range(pts.size() - 1):
		pk.tube(kit, key, pts[i], pts[i + 1], r, r, segs, col, false)


# ======================================================================================
#  The emblem
# ======================================================================================

## The cup's crest: a five-petal cherry blossom, each petal notched at its tip, flat on the plane through `c` facing
## `out`, 1.5cm proud of it, `r` to the petals' tips. 30 triangles.
static func sakura_crest(pk: PropKit, kit: Dictionary, key: String, c: Vector3, out: Vector3, r: float, col: Color) -> void:
	var wf := _pl(c + out.normalized() * 0.015, out)
	var n: Vector3 = wf.basis.z
	var shape: Array = [Vector2(0, 0), Vector2(-0.30, 0.52), Vector2(-0.27, 0.84), Vector2(-0.12, 1.0), Vector2(0, 0.83), Vector2(0.12, 1.0),
			Vector2(0.27, 0.84), Vector2(0.30, 0.52)]
	for k in range(5):
		var a: float = TAU * float(k) / 5.0
		var ax := Vector2(-sin(a), cos(a))
		var px := Vector2(cos(a), sin(a))
		var p: Array = []
		for q: Vector2 in shape:
			var v: Vector2 = (px * q.x + ax * q.y) * r
			p.append(wf * Vector3(v.x, v.y, 0.0))
		# A fan from the notch, which sees the whole petal.
		for t: Vector2i in [Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 0), Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3)]:
			pk.tri(kit, key, p[4], p[t.x], p[t.y], n, n, n, col, n)


# ======================================================================================
#  Torii and sacred ropes
# ======================================================================================

## A torii across a road running along z: the pillars' axes `w` apart where the tie beam (nuki) meets them, `h` clear
## under it. Proportions grow with w (the pillars are 9% of it across), so w 11, h 7.5 is a grand gate over a road.
##   0  a vermilion myojin torii: pillars on black collars, the nuki with its wedges, a curved top beam with upturned
##      ends under a black cap, a framed tablet with the gold crest on both faces
##   1  weathered granite, plainer and flatter
##   2  unpainted cedar with a shimenawa and its shide papers across the front
## The pillars lean (TORII_LEAN): their feet stand wider than w. Nothing is inside |x| < w/2 - pillar radius - 0.05
## below y = h; `torii_pillar_radius(w)` gives the radius. Height over all about h + 7 radii.
static func torii(pk: PropKit, kit: Dictionary, style := 0, w := 4.6, h := 4.4) -> void:
	var st: int = clampi(style, 0, 2)
	var key: String = ["urushi", "ishi", "hinoki"][st]
	var col: Color = [VERMILION, GRANITE, CEDAR][st]
	var uvs: float = 0.0 if st == 0 else uvk
	var uvm: int = [0, 1, 2][st]
	var pr: float = torii_pillar_radius(w)
	var hw: float = w * 0.5
	var nh: float = pr * 1.5
	var nt: float = pr * 0.8
	var gap: float = pr * 2.6
	var sh: float = pr * 1.25
	var kh: float = pr * 1.05
	var ys: float = h + nh + gap
	var sori: float = pr * float([1.7, 1.0, 0.8][st])
	var lk: float = hw + pr * 5.2
	var dy := func(x: float) -> float: return sori * pow(absf(x) / lk, 2.4)
	var top_y: float = ys + float(dy.call(hw)) + sh * 0.6
	var base_r: float = minf(pr * 1.45, pr + TORII_LEAN * h + 0.03)
	for sx: float in [-1.0, 1.0]:
		var foot := Vector3(sx * (hw + TORII_LEAN * (h + 0.6)), -0.6, 0)
		var head := Vector3(sx * (hw - TORII_LEAN * (top_y - h)), top_y, 0)
		pk.tube(kit, key, foot, head, pr, pr * 0.92, 12, col, false, uvs)
		# The stone it stands on, a low rounded drum.
		var at0 := Vector3(sx * (hw + TORII_LEAN * h), 0, 0)
		_turn(pk, kit, "matte", at0, [Vector2(base_r, -0.6), Vector2(base_r, 0.05), Vector2(base_r * 0.9, 0.14), Vector2(pr * 0.9, 0.17)], 10, STONE_B)
		if st == 0:
			# The black collar round the foot.
			var c0 := Vector3(sx * (hw + TORII_LEAN * (h - 0.1)), 0.1, 0)
			var c1 := Vector3(sx * (hw + TORII_LEAN * (h - 0.1 - pr * 2.2)), 0.1 + pr * 2.2, 0)
			pk.tube(kit, "urushi", c0, c1, pr * 1.06, pr * 1.06, 12, BLACK_LAC, true)
		# The wedges through the pillar over the nuki, either side of it.
		for sd: float in [-1.0, 1.0]:
			var wx: float = sx * hw + sd * pr * 1.2
			pk.block(kit, key, Vector3(wx - pr * 0.22, h + nh - 0.01, -(nt * 0.5 + pr * 0.22)), Vector3(wx + pr * 0.22, h + nh + pr * 0.3, nt * 0.5 + pr * 0.22),
					col.darkened(0.3), uvs)
	# The nuki: through the pillars, and out past them on the timber gates.
	var nx: float = hw + pr * (1.7 if st == 1 else 2.3)
	_bar(pk, kit, key, Vector3(-nx, h + nh * 0.5, 0), Vector3(nx, h + nh * 0.5, 0), nt, nh, col, Vector3.BACK, st != 1)
	# The strut between the nuki and the beams above, and the tablet on it.
	pk.block(kit, key, Vector3(-pr * 0.42, h + nh - 0.01, -nt * 0.42), Vector3(pr * 0.42, ys + 0.02, nt * 0.42), col, uvs)
	if st == 0:
		var gw: float = pr * 2.5
		var gh: float = gap * 0.78
		var fw: float = gw * 0.09
		for sz: float in [-1.0, 1.0]:
			var wf := _pl(Vector3(0, h + nh + gap * 0.5, sz * nt * 0.42), Vector3(0, 0, sz))
			_slab(pk, kit, "urushi", wf, -gw * 0.5, -gh * 0.5, gw * 0.5, gh * 0.5, 0.0, 0.05, INDIGO.darkened(0.45))
			_slab(pk, kit, "gold", wf, -gw * 0.5 - fw * 0.5, gh * 0.5 - fw * 0.5, gw * 0.5 + fw * 0.5, gh * 0.5 + fw * 0.5, 0.01, 0.05 + TP, GOLD)
			_slab(pk, kit, "gold", wf, -gw * 0.5 - fw * 0.5, -gh * 0.5 - fw * 0.5, gw * 0.5 + fw * 0.5, -gh * 0.5 + fw * 0.5, 0.01, 0.05 + TP, GOLD)
			for su: float in [-1.0, 1.0]:
				_slab(pk, kit, "gold", wf, su * gw * 0.5 - fw * 0.5, -gh * 0.5 + fw * 0.5, su * gw * 0.5 + fw * 0.5, gh * 0.5 - fw * 0.5, 0.01, 0.05 + TP, GOLD)
			sakura_crest(pk, kit, "gold", wf * Vector3(0, 0, 0.05), wf.basis.z, minf(gw, gh) * 0.36, GOLD)
	# The shimaki, the kasagi on it and (on the lacquered gate) the black cap: one curve, turning up to the ends.
	_curved_beam(pk, kit, key, col, lk, lk - pr * 0.6, ys, sh, pr * 0.95, 0.0, sh * 0.3, dy, uvm)
	_curved_beam(pk, kit, key, col, lk, lk, ys + sh, kh, pr * 1.2, 0.0 if st == 0 else pr * 0.3, kh * 0.45, dy, uvm)
	if st == 0:
		_curved_beam(pk, kit, "urushi", BLACK_LAC, lk, lk + pr * 0.3, ys + sh + kh, pr * 0.22, pr * 1.42, pr * 0.3, pr * 0.2, dy, 0)
	if st == 2:
		var th: float = pr * 0.5
		var ry: float = h + nh + gap * 0.72
		var zf: float = pr + th * 0.5 + 0.02
		var sg: float = gap * 0.25
		var drop: float = minf(pr * 1.6, ry - sg - th * 0.5 - h - 0.05)
		shimenawa(pk, kit, Vector3(-hw - pr * 0.7, ry, zf), Vector3(hw + pr * 0.7, ry, zf), th, 4, sg, drop)


static func torii_pillar_radius(w: float) -> float:
	return clampf(w * 0.045, 0.14, 0.62)


## One of a torii's top beams: a section `zh` either side of the middle and `depth` deep (with a ridge `ridge` over it),
## its underside at y0 + dy(x), from -half to half with the stations between at the same x for every beam (`lk`), so one
## beam lies on the next; the ends are cut on a slant, the top `slant` longer.
static func _curved_beam(pk: PropKit, kit: Dictionary, key: String, col: Color, lk: float, half: float, y0: float, depth: float, zh: float, ridge: float,
		slant: float, dy: Callable, uvm: int) -> void:
	var n := 10
	var secs: Array = []
	for i in range(n + 1):
		var x: float = lk * (-1.0 + 2.0 * float(i) / float(n))
		var xo := 0.0
		if i == 0:
			x = -half
			xo = -slant
		elif i == n:
			x = half
			xo = slant
		var yb: float = y0 + float(dy.call(x))
		var s: Array = [Vector3(x, yb, zh), Vector3(x + xo, yb + depth, zh)]
		if ridge > 0.0:
			s.append(Vector3(x + xo, yb + depth + ridge, 0))
		s.append(Vector3(x + xo, yb + depth, -zh))
		s.append(Vector3(x, yb, -zh))
		secs.append(s)
	_loft(pk, kit, key, secs, col, true, true, uvm)


## A shide: the white zigzag paper hanging from a sacred rope, one sheet of cloth facing `out`, `drop` long.
static func _shide(pk: PropKit, kit: Dictionary, top: Vector3, along: Vector3, out: Vector3, drop: float, wd: float) -> void:
	var al := Vector3(along.x, 0, along.z).normalized()
	var stem: float = drop * 0.14
	var ph: float = (drop - stem) / 3.0
	pk.quad(kit, "cloth", [top - al * wd * 0.16, top + al * wd * 0.16, top + al * wd * 0.16 - Vector3(0, stem, 0), top - al * wd * 0.16 - Vector3(0, stem, 0)], out, SHIDE_WHITE)
	for k in range(3):
		var off: float = wd * (0.22 if k % 2 == 0 else -0.22)
		var y0: float = stem + ph * float(k)
		var c: Vector3 = top + al * off
		pk.quad(kit, "cloth", [c - al * wd * 0.5 - Vector3(0, y0, 0), c + al * wd * 0.5 - Vector3(0, y0, 0), c + al * wd * 0.5 - Vector3(0, y0 + ph, 0),
				c - al * wd * 0.5 - Vector3(0, y0 + ph, 0)], out, SHIDE_WHITE)


## A straw tassel hanging from `top`.
static func _tassel(pk: PropKit, kit: Dictionary, top: Vector3, length: float, r: float) -> void:
	_turn(pk, kit, "rope", top, [Vector2(0.0, -length * 1.08), Vector2(r, -length), Vector2(r * 0.4, 0.0)], 5, STRAW.darkened(0.1))


## A shimenawa: a twisted straw rope from a to b, thickest in the middle, with `shide` zigzag papers and straw tassels
## between them. It hangs `sag` in the middle (7% of its length if not given) and the papers `drop` below it.
static func shimenawa(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, thick := 0.11, shide := 4, sag := -1.0, drop := -1.0) -> void:
	var ln: float = (b - a).length()
	if ln < 0.01:
		return
	var sg: float = ln * 0.07 if sag < 0.0 else sag
	var dr: float = clampf(thick * 3.0, 0.2, 0.6) if drop < 0.0 else drop
	var n := 10
	var pts: Array = _sag(a, b, sg, n)
	var across: Vector3 = (b - a).cross(Vector3.UP)
	across = Vector3.BACK if across.length_squared() < 1e-8 else across.normalized()
	var secs: Array = []
	for i in range(n + 1):
		var p: Vector3 = pts[i]
		var tg: Vector3 = ((pts[mini(i + 1, n)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var up: Vector3 = across.cross(tg).normalized()
		var rad: float = _rope_r(thick, float(i) / float(n))
		var s: Array = []
		for k in range(6):
			var ang: float = TAU * float(k) / 6.0 + float(i) * 0.7
			s.append(p + (across * cos(ang) + up * sin(ang)) * (rad * (1.0 if k % 2 == 0 else 0.62)))
		secs.append(s)
	_loft(pk, kit, "rope", secs, STRAW, true, true)
	var along: Vector3 = (b - a).normalized()
	for k in range(maxi(shide, 0)):
		var t: float = (float(k) + 0.5) / float(shide)
		var p: Vector3 = a.lerp(b, t) - Vector3.UP * (sg * 4.0 * t * (1.0 - t) + _rope_r(thick, t) * 0.5)
		_shide(pk, kit, p, along, across, dr, clampf(thick * 1.1, 0.07, 0.4))
	for k in range(1, maxi(shide, 0)):
		var t: float = float(k) / float(shide)
		var p: Vector3 = a.lerp(b, t) - Vector3.UP * (sg * 4.0 * t * (1.0 - t) + _rope_r(thick, t) * 0.5)
		_tassel(pk, kit, p, dr * 0.8, thick * 0.42)


static func _rope_r(thick: float, t: float) -> float:
	return thick * 0.5 * (0.62 + 0.38 * sin(PI * t))


## A shimenawa round a sacred tree: a ring of twisted rope `thick` thick hugging a trunk of radius `r` about the origin's
## vertical at height `y`, `shide` papers and tassels hanging from it.
static func rope_ring(pk: PropKit, kit: Dictionary, r: float, y: float, shide := 6, thick := 0.09) -> void:
	var rr: float = r + thick * 0.42
	var n := 15
	var secs: Array = []
	for i in range(n + 1):
		var th: float = TAU * float(i) / float(n)
		var rad := Vector3(cos(th), 0, sin(th))
		var s: Array = []
		for k in range(6):
			var ang: float = TAU * float(k) / 6.0 + float(i) * TAU / 9.0
			s.append(rad * rr + Vector3(0, y, 0) + (rad * cos(ang) + Vector3.UP * sin(ang)) * (thick * 0.5 * (1.0 if k % 2 == 0 else 0.62)))
		secs.append(s)
	_loft(pk, kit, "rope", secs, STRAW, false, false)
	for k in range(maxi(shide, 0)):
		for half in range(2):
			var th: float = TAU * (float(k) + 0.5 * float(half)) / float(shide)
			var rad := Vector3(cos(th), 0, sin(th))
			var p: Vector3 = rad * (rr + thick * 0.3) + Vector3(0, y - thick * 0.3, 0)
			if half == 0:
				_shide(pk, kit, p, Vector3(-rad.z, 0, rad.x), rad, thick * 3.2, thick * 1.2)
			else:
				_tassel(pk, kit, p, thick * 2.4, thick * 0.4)


# ======================================================================================
#  Lanterns
# ======================================================================================

## A stone lantern (ishidoro), centred, mossy granite, its fire-box windows "washi".
##   0  the kasuga type, `h` tall: a six-sided base, a round shaft with its ring, a platform, the fire-box between six
##      corner posts, a curved six-sided roof with upturned corners, a jewel; 1.04 x h/2.1 across the roof's corners
##   1  a yukimi (snow-viewing) lantern, squat on three legs under a broad roof: 0.55 h tall, 1.3 x h/2.1 across
static func stone_lantern(pk: PropKit, kit: Dictionary, style := 0, h := 2.1) -> void:
	var s: float = h / 2.1
	var old := _push(pk, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO))
	var dn: float = -0.6 / s
	var c1: Color = STONE_B
	var c2: Color = STONE_A
	if style == 1:
		for k in range(3):
			var ang: float = PI * 0.5 + TAU * float(k) / 3.0
			var d := Vector3(cos(ang), 0, sin(ang))
			var tv := Vector3(-d.z, 0, d.x)
			var path: Array = [d * 0.42 + Vector3(0, dn, 0), d * 0.42, d * 0.37 + Vector3(0, 0.24, 0), d * 0.27 + Vector3(0, 0.43, 0), d * 0.19 + Vector3(0, 0.5, 0)]
			var secs: Array = []
			for i in range(path.size()):
				var p: Vector3 = path[i]
				var dir: Vector3 = ((path[mini(i + 1, path.size() - 1)] as Vector3) - (path[maxi(i - 1, 0)] as Vector3)).normalized()
				var nr: Vector3 = tv.cross(dir).normalized()
				var hw: float = lerpf(0.065, 0.05, float(i) / 4.0)
				secs.append([p + tv * hw + nr * hw, p - tv * hw + nr * hw, p - tv * hw - nr * hw, p + tv * hw - nr * hw])
			_loft(pk, kit, "matte", secs, c1.darkened(0.1), false, true)
		_turn(pk, kit, "matte", Vector3.ZERO, [Vector2(0.0, 0.46), Vector2(0.17, 0.46), Vector2(0.33, 0.51), Vector2(0.34, 0.58), Vector2(0.0, 0.58)], 6, c2, true)
		_fire_box(pk, kit, 0.575, 0.835, 0.2, c2)
		_lantern_roof(pk, kit, 0.83, 0.66, 0.17, 0.035, 0.04, 0.07, c1)
		_turn(pk, kit, "matte", Vector3.ZERO, [Vector2(0.075, 1.02), Vector2(0.095, 1.07), Vector2(0.06, 1.1), Vector2(0.0, 1.155)], 6, c2)
		pk.set_frame(old)
		return
	_turn(pk, kit, "matte", Vector3.ZERO, [Vector2(0.37, dn), Vector2(0.37, 0.07), Vector2(0.32, 0.13), Vector2(0.32, 0.19), Vector2(0.17, 0.29), Vector2(0.11, 0.29)],
			6, c1.darkened(0.12), true)
	_turn(pk, kit, "matte", Vector3.ZERO, [Vector2(0.125, 0.27), Vector2(0.118, 0.66), Vector2(0.152, 0.69), Vector2(0.152, 0.75), Vector2(0.118, 0.78),
			Vector2(0.115, 1.12)], 8, c2)
	_turn(pk, kit, "matte", Vector3.ZERO, [Vector2(0.115, 1.1), Vector2(0.29, 1.21), Vector2(0.315, 1.24), Vector2(0.315, 1.3), Vector2(0.0, 1.3)], 6, c1, true)
	_fire_box(pk, kit, 1.295, 1.67, 0.2, c2)
	_lantern_roof(pk, kit, 1.665, 0.52, 0.22, 0.11, 0.045, 0.085, c1)
	_turn(pk, kit, "matte", Vector3.ZERO, [Vector2(0.095, 1.91), Vector2(0.095, 1.95), Vector2(0.06, 1.97), Vector2(0.1, 2.02), Vector2(0.08, 2.06), Vector2(0.0, 2.1)],
			6, c2)
	pk.set_frame(old)


## A lantern's fire-box: a six-sided paper body between six stone corner posts.
static func _fire_box(pk: PropKit, kit: Dictionary, y0: float, y1: float, r: float, col: Color) -> void:
	_turn(pk, kit, "washi", Vector3.ZERO, [Vector2(r, y0), Vector2(r, y1)], 6, PAPER_WARM, true)
	for k in range(6):
		var ang: float = TAU * float(k) / 6.0
		var d := Vector3(cos(ang), 0, sin(ang))
		pk.beam(kit, "matte", d * (r + 0.022) + Vector3(0, y0, 0), d * (r + 0.022) + Vector3(0, y1, 0), 0.055, 0.055, col, d)


## A stone lantern's roof: six curved slopes between ridges that turn up at the corners, with its rim and underside.
## `yu` the underside, `re` the corners' reach, `rise` from the eave to the top, `up` the corners' lift, `rt` the top's
## radius.
static func _lantern_roof(pk: PropKit, kit: Dictionary, yu: float, re: float, rise: float, up: float, rim: float, rt: float, col: Color) -> void:
	var secs: Array = []
	var cm: float = cos(PI / 6.0)
	var yt: float = yu + rim + rise
	for i in range(13):
		var ang: float = TAU * float(i % 12) / 12.0
		var d := Vector3(cos(ang), 0, sin(ang))
		var corner: bool = i % 2 == 0
		var k: float = 1.0 if corner else cm
		var lift: float = up if corner else 0.0
		var rr: float = re if corner else re * cm * 0.93
		secs.append([Vector3(0, yt + 0.01, 0), d * (rt * k) + Vector3(0, yt, 0), d * (re * 0.42 * k) + Vector3(0, yu + rim + rise * 0.4, 0),
				d * (re * 0.74 * k) + Vector3(0, yu + rim + rise * 0.11 + lift * 0.25, 0), d * rr + Vector3(0, yu + rim + lift, 0),
				d * rr + Vector3(0, yu + lift * 0.7, 0), Vector3(0, yu - 0.004, 0)])
	_loft(pk, kit, "matte", secs, col, false, false, 0, false)


## A paper lantern (chochin) hanging with its middle at `c`: a ribbed paper body `r` across its half ("washi"), black
## rings top and bottom, a tassel, a loop to hang it by; the crest on its front and back. 2.9 r tall with its rings.
static func chochin(pk: PropKit, kit: Dictionary, c: Vector3, r := 0.24, col := PAPER_RED, crest := true) -> void:
	_chochin(pk, kit, c, r, col, crest, 10)


static func _chochin(pk: PropKit, kit: Dictionary, c: Vector3, r: float, col: Color, crest: bool, segs: int) -> void:
	var ry: float = r * 1.22
	var t0: float = asin(0.46)
	var strips := 6
	for i in range(strips):
		var a0: float = lerpf(t0, PI - t0, float(i) / float(strips))
		var a1: float = lerpf(t0, PI - t0, float(i + 1) / float(strips))
		_turn(pk, kit, "washi", c, [Vector2(r * sin(a0), -ry * cos(a0)), Vector2(r * sin(a1), -ry * cos(a1))], segs, col if i % 2 == 0 else col.darkened(0.1))
	var yr: float = ry * cos(t0)
	var rr: float = r * 0.5
	_turn(pk, kit, "matte", c, [Vector2(0.0, -yr - r * 0.2), Vector2(rr, -yr - r * 0.2), Vector2(rr, -yr + r * 0.06)], segs, INK)
	_turn(pk, kit, "matte", c, [Vector2(rr, yr - r * 0.06), Vector2(rr, yr + r * 0.2), Vector2(0.0, yr + r * 0.2)], segs, INK)
	_turn(pk, kit, "rope", c + Vector3(0, -yr - r * 0.18, 0), [Vector2(0.0, -r * 0.62), Vector2(r * 0.12, -r * 0.56), Vector2(r * 0.035, 0.0)], 4, col.darkened(0.15))
	pk.tube(kit, "matte", c + Vector3(0, yr + r * 0.18, 0), c + Vector3(0, yr + r * 0.45, 0), r * 0.035, r * 0.035, 3, INK, false)
	if crest:
		var cc: Color = OFF_WHITE if col.get_luminance() < 0.55 else PAPER_RED.darkened(0.1)
		for sz: float in [-1.0, 1.0]:
			sakura_crest(pk, kit, "washi", c + Vector3(0, 0, sz * r), Vector3(0, 0, sz), r * 0.42, cc)


## A festival string: a cord from a to b hanging `sag` in the middle with `n` paper lanterns under it, in the colours of
## `cols` in turn (red and white if none). The lanterns are 0.2 across their half and hang 0.6 under the cord: the
## caller keeps the cord that far and more over the cars.
static func chochin_string(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, n: int, sag := 0.5, cols := []) -> void:
	var cnt: int = maxi(n, 1)
	var pts: Array = _sag(a, b, sag, cnt * 2)
	_strand(pk, kit, "matte", pts, 0.014, 3, INK)
	var palette: Array = cols if cols.size() > 0 else [PAPER_RED, PAPER]
	for i in range(cnt):
		var p: Vector3 = pts[i * 2 + 1]
		_chochin(pk, kit, p - Vector3(0, 0.35, 0), 0.2, palette[i % palette.size()], false, 6)


## The cherry-viewing lamp (bonbori), centred, `h` tall: a paper box widening upward in a black frame under a little
## roof, on a slim black post; the crest on its front and back. 0.5 across its roof.
static func bonbori(pk: PropKit, kit: Dictionary, h := 2.3, col := PAPER_PINK) -> void:
	var yb: float = h - 0.62
	var q := sqrt(2.0)
	_post(pk, kit, "urushi", Vector3.ZERO, -0.6, yb + 0.01, 0.06, BLACK_LAC)
	var c := Vector3(0, yb, 0)
	# A flared seat under the box.
	_turn(pk, kit, "urushi", c, [Vector2(0.0, -0.1), Vector2(0.05 * q, -0.1), Vector2(0.15 * q, -0.012), Vector2(0.15 * q, 0.012), Vector2(0.0, 0.012)], 4, BLACK_LAC, true, PI * 0.25)
	_turn(pk, kit, "washi", c, [Vector2(0.13 * q, 0.01), Vector2(0.18 * q, 0.43)], 4, col, true, PI * 0.25)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pk.beam(kit, "urushi", c + Vector3(sx * 0.134, 0.01, sz * 0.134), c + Vector3(sx * 0.186, 0.43, sz * 0.186), 0.022, 0.022, BLACK_LAC)
	_turn(pk, kit, "urushi", c, [Vector2(0.0, 0.425), Vector2(0.235 * q, 0.43), Vector2(0.235 * q, 0.455), Vector2(0.08 * q, 0.57), Vector2(0.0, 0.61)], 4, BLACK_LAC, true, PI * 0.25)
	var cc: Color = Color(0.86, 0.22, 0.38) if col.get_luminance() > 0.5 else OFF_WHITE
	for sz: float in [-1.0, 1.0]:
		sakura_crest(pk, kit, "washi", c + Vector3(0, 0.22, sz * 0.155), Vector3(0, -0.05, sz * 0.42).normalized(), 0.095, cc)


## A street andon, centred, `h` tall: a square timber post with a pointed cap, an arm out toward +z on a brace, and on it
## a paper lantern box in a timber frame under a little hipped roof (its middle 0.42 before the post).
static func wood_lantern_post(pk: PropKit, kit: Dictionary, h := 2.6) -> void:
	var wood: Color = CEDAR
	var q := sqrt(2.0)
	_post(pk, kit, "hinoki", Vector3.ZERO, -0.6, h - 0.06, 0.13, wood)
	_turn(pk, kit, "matte", Vector3(0, h - 0.07, 0), [Vector2(0.0, 0.0), Vector2(0.085 * q, 0.0), Vector2(0.085 * q, 0.025), Vector2(0.0, 0.1)], 4, CEDAR_DARK, true, PI * 0.25)
	var ya: float = h - 0.72
	_bar(pk, kit, "hinoki", Vector3(0, ya, 0.03), Vector3(0, ya, 0.6), 0.07, 0.07, wood, Vector3.RIGHT)
	_bar(pk, kit, "hinoki", Vector3(0, ya - 0.34, 0.05), Vector3(0, ya - 0.03, 0.4), 0.05, 0.05, wood.darkened(0.1), Vector3.RIGHT)
	var c := Vector3(0, ya + 0.03, 0.42)
	pk.block(kit, "matte", c + Vector3(-0.17, 0.0, -0.17), c + Vector3(0.17, 0.03, 0.17), CEDAR_DARK)
	_turn(pk, kit, "washi", c, [Vector2(0.135 * q, 0.025), Vector2(0.135 * q, 0.455)], 4, PAPER_WARM, true, PI * 0.25)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pk.beam(kit, "matte", c + Vector3(sx * 0.143, 0.02, sz * 0.143), c + Vector3(sx * 0.143, 0.46, sz * 0.143), 0.03, 0.03, CEDAR_DARK, Vector3.RIGHT)
		# A bar across each pane.
		pk.beam(kit, "matte", c + Vector3(sx * 0.147, 0.24, -0.13), c + Vector3(sx * 0.147, 0.24, 0.13), 0.014, 0.02, CEDAR_DARK, Vector3.UP)
		pk.beam(kit, "matte", c + Vector3(-0.13, 0.24, sx * 0.147), c + Vector3(0.13, 0.24, sx * 0.147), 0.014, 0.02, CEDAR_DARK, Vector3.UP)
	_turn(pk, kit, "matte", c, [Vector2(0.0, 0.45), Vector2(0.25 * q, 0.455), Vector2(0.25 * q, 0.48), Vector2(0.06 * q, 0.6), Vector2(0.0, 0.62)], 4, CEDAR_DARK, true, PI * 0.25)


## The concrete pole of every Japanese street, centred, `h` tall, its arms across x (the wires run along z): step
## bolts, a yellow guard band, a steel arm with three insulators near the top and a shorter one with two below it.
##   1  with a grey transformer can hung behind it (-z)
##   2  with a street lamp on an arm out toward +z (its lens "washi")
## The wires leave it POLE_WIRE_HIGH under its top (three, POLE_WIRE_GAP apart, 0.16 before the axis) and POLE_WIRE_LOW
## under it (two): `pole_wires` strings them.
static func utility_pole(pk: PropKit, kit: Dictionary, h := 9.5, variant := 0) -> void:
	var r0 := 0.17
	var r1 := 0.115
	pk.tube(kit, "matte", Vector3(0, -0.6, 0), Vector3(0, h, 0), r0, r1, 10, POLE_GREY, true)
	pk.tube(kit, "paint", Vector3(0, 0.9, 0), Vector3(0, 1.7, 0), r0 + 0.006, r0 - 0.004, 10, SIGN_YELLOW, false)
	for k in range(2):
		pk.tube(kit, "paint", Vector3(0, 1.08 + 0.36 * float(k), 0), Vector3(0, 1.2 + 0.36 * float(k), 0), r0 + 0.02, r0 + 0.02, 10, INK, false)
	pk.block(kit, "paint", Vector3(-0.07, 2.0, r0 - 0.03), Vector3(0.07, 2.22, r0 + 0.008), OFF_WHITE)
	# Step bolts, alternating sides, from above reach to the lower arm.
	var y := 2.6
	var side := 1.0
	while y < h - 2.1:
		var rr: float = lerpf(r0, r1, (y + 0.6) / (h + 0.6))
		pk.tube(kit, "metal", Vector3(side * (rr - 0.02), y, 0), Vector3(side * (rr + 0.16), y, 0), 0.012, 0.012, 3, GALV, false)
		y += 0.55
		side = -side
	for arm in range(2):
		var ya: float = h - (0.4 if arm == 0 else 1.8)
		var half: float = 0.78 if arm == 0 else 0.46
		var rr: float = lerpf(r0, r1, (ya + 0.6) / (h + 0.6))
		pk.block(kit, "metal", Vector3(-half, ya - 0.045, rr - 0.01), Vector3(half, ya + 0.045, rr + 0.08), GALV.darkened(0.2))
		pk.beam(kit, "metal", Vector3(-half * 0.6, ya, rr + 0.03), Vector3(0, ya - 0.5, rr + 0.03), 0.04, 0.012, GALV.darkened(0.2), Vector3.BACK)
		pk.beam(kit, "metal", Vector3(half * 0.6, ya, rr + 0.03), Vector3(0, ya - 0.5, rr + 0.03), 0.04, 0.012, GALV.darkened(0.2), Vector3.BACK)
		var xs: Array = [-POLE_WIRE_GAP, 0.0, POLE_WIRE_GAP] if arm == 0 else [-POLE_WIRE_GAP * 0.5, POLE_WIRE_GAP * 0.5]
		for x: float in xs:
			_turn(pk, kit, "gloss", Vector3(x, ya + 0.04, rr + 0.035), [Vector2(0.03, 0.0), Vector2(0.06, 0.05), Vector2(0.035, 0.1), Vector2(0.055, 0.16), Vector2(0.0, 0.21)],
					5, OFF_WHITE)
	if variant == 1:
		var yc: float = h - 3.6
		var zc := -0.46
		pk.block(kit, "metal", Vector3(-0.05, yc + 0.5, zc + 0.1), Vector3(0.05, yc + 0.58, 0.0), GALV.darkened(0.2))
		pk.block(kit, "metal", Vector3(-0.05, yc + 0.1, zc + 0.1), Vector3(0.05, yc + 0.18, 0.0), GALV.darkened(0.2))
		_turn(pk, kit, "paint", Vector3(0, yc, zc), [Vector2(0.0, -0.02), Vector2(0.25, 0.0), Vector2(0.27, 0.04), Vector2(0.27, 0.7), Vector2(0.24, 0.76), Vector2(0.0, 0.78)],
				10, Color(0.56, 0.58, 0.58))
		for sx: float in [-1.0, 1.0]:
			_turn(pk, kit, "gloss", Vector3(sx * 0.12, yc + 0.76, zc), [Vector2(0.03, 0.0), Vector2(0.05, 0.05), Vector2(0.03, 0.1), Vector2(0.0, 0.2)], 5, OFF_WHITE)
			pk.tube(kit, "matte", Vector3(sx * 0.12, yc + 0.95, zc), Vector3(sx * POLE_WIRE_GAP * 0.5, h - 1.72, 0.1), 0.012, 0.012, 3, IRON, false)
	elif variant == 2:
		var yl: float = h * 0.6
		_strand(pk, kit, "metal", [Vector3(0, yl, 0.1), Vector3(0, yl + 0.4, 0.75), Vector3(0, yl + 0.44, 1.3)], 0.03, 5, GALV)
		pk.block(kit, "metal", Vector3(-0.11, yl + 0.36, 1.2), Vector3(0.11, yl + 0.47, 1.78), GALV.darkened(0.12))
		pk.quad(kit, "washi", [Vector3(-0.085, yl + 0.345, 1.26), Vector3(0.085, yl + 0.345, 1.26), Vector3(0.085, yl + 0.345, 1.74), Vector3(-0.085, yl + 0.345, 1.74)],
				Vector3.DOWN, Color(1.0, 0.95, 0.82))


## `n` sagging wires between two pole tops, POLE_WIRE_GAP apart across the line, each a few straight pieces. `a` and
## `b` are the middle wire's ends: a pole's place plus (0, h - POLE_WIRE_HIGH, 0.16) for its upper three.
static func pole_wires(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, sag := 0.6, n := 3) -> void:
	var across: Vector3 = (b - a).cross(Vector3.UP)
	across = Vector3.RIGHT if across.length_squared() < 1e-8 else across.normalized()
	for i in range(n):
		var off: Vector3 = across * ((float(i) - float(n - 1) * 0.5) * POLE_WIRE_GAP)
		_strand(pk, kit, "matte", _sag(a + off, b + off, sag * (1.0 + 0.07 * float(i)), 5), 0.016, 3, IRON)


# ======================================================================================
#  The roadside
# ======================================================================================

## The white Japanese guardrail between two ground points: round posts every 4m (upright, 0.6 into the ground), a
## W-beam on both of their sides (it reads the same from either), following the slope, a rounded end piece at each end.
## Beam's middle 0.6 over the ground, 0.23 across.
static func guardrail(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3) -> void:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var ln: float = flat.length()
	if ln < 0.05:
		return
	var along: Vector3 = flat / ln
	var side := Vector3(-along.z, 0, along.x)
	var spans: int = maxi(1, int(round(ln / 4.0)))
	for i in range(spans + 1):
		var p: Vector3 = a.lerp(b, float(i) / float(spans))
		pk.tube(kit, "paint", p + Vector3(0, -0.6, 0), p + Vector3(0, 0.74, 0), 0.057, 0.057, 6, RAIL_WHITE, true)
	# The beam's section: two crowns and a valley on each face.
	var prof: Array = [Vector2(0.07, -0.175), Vector2(0.115, -0.1), Vector2(0.078, 0.0), Vector2(0.115, 0.1), Vector2(0.07, 0.175)]
	var s0: Array = []
	var s1: Array = []
	for q: Vector2 in prof:
		s0.append(a + side * q.x + Vector3(0, 0.6 + q.y, 0))
		s1.append(b + side * q.x + Vector3(0, 0.6 + q.y, 0))
	for k in range(prof.size() - 1, -1, -1):
		var q: Vector2 = prof[k]
		s0.append(a - side * q.x + Vector3(0, 0.6 + q.y, 0))
		s1.append(b - side * q.x + Vector3(0, 0.6 + q.y, 0))
	_loft(pk, kit, "paint", [s0, s1], RAIL_WHITE, false, false)
	# The rounded ends.
	for e in range(2):
		var p: Vector3 = (a if e == 0 else b) + Vector3(0, 0.6, 0)
		var dir: Vector3 = -along if e == 0 else along
		var secs: Array = []
		for k in range(6):
			var ang: float = -PI * 0.5 + PI * float(k) / 5.0
			var d: Vector3 = side * sin(ang) + dir * cos(ang)
			secs.append([p + d * 0.115 + Vector3(0, -0.175, 0), p + d * 0.115 + Vector3(0, 0.175, 0), p + Vector3(0, 0.176, 0), p + Vector3(0, -0.176, 0)])
		_loft(pk, kit, "paint", secs, RAIL_WHITE, false, false, 0, true, Vector3.ZERO)


## The orange roadside mirror, centred, facing +z: a convex mirror 0.8 across in an orange shell under its hood, on an
## orange post 3.1 tall with a white name plate; `twin` two of them, turned apart. The mirror's middle 2.55 up.
static func curve_mirror(pk: PropKit, kit: Dictionary, twin := false) -> void:
	pk.tube(kit, "paint", Vector3(0, -0.6, 0), Vector3(0, 3.1, 0), 0.045, 0.045, 8, MIRROR_ORANGE, true)
	pk.block(kit, "paint", Vector3(-0.16, 1.82, 0.04), Vector3(0.16, 1.98, 0.06), OFF_WHITE)
	var yaws: Array = [-0.42, 0.42] if twin else [0.0]
	for yaw: float in yaws:
		var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.12)
		var off: float = 0.0 if not twin else signf(yaw) * 0.48
		var c := Vector3(off, 2.55, 0.1)
		if twin:
			pk.beam(kit, "paint", Vector3(0, 2.55, 0.0), c, 0.05, 0.05, MIRROR_ORANGE)
		var old := _push(pk, Transform3D(rot * Basis(Vector3.RIGHT, PI * 0.5), c))
		# In this frame the axis (y) is the mirror's out: the shell behind, the convex glass before it.
		_turn(pk, kit, "paint", Vector3.ZERO, [Vector2(0.0, -0.1), Vector2(0.3, -0.07), Vector2(0.43, 0.0), Vector2(0.43, 0.05), Vector2(0.4, 0.05)], 12, MIRROR_ORANGE)
		_turn(pk, kit, "pane", Vector3.ZERO, [Vector2(0.4, 0.045), Vector2(0.24, 0.085), Vector2(0.0, 0.1)], 12, Color(0.70, 0.80, 0.88))
		# The hood over its upper half: one sheet, orange outside, seen from under as well.
		for k in range(6):
			var a0: float = PI + PI * float(k) / 6.0
			var a1: float = PI + PI * float(k + 1) / 6.0
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var e0: float = 0.05 + 0.2 * sin(PI * float(k) / 6.0)
			var e1: float = 0.05 + 0.2 * sin(PI * float(k + 1) / 6.0)
			pk.quad(kit, "cloth", [d0 * 0.445, d1 * 0.445, d1 * 0.445 + Vector3(0, e1, 0), d0 * 0.445 + Vector3(0, e0, 0)], (d0 + d1).normalized(), MIRROR_ORANGE)
		pk.set_frame(old)


## A road sign on a grey post, centred, facing +z, its middle 2.3 up:
##   "curve_l", "curve_r", "winding", "falling_rocks", "slippery"   a yellow diamond 0.6 a side, its symbol drawn in black
##   "speed40"   a white disc in a red ring ("40" in blue goes into `labels`)
##   "stop"      the red inverted triangle with its white edge ("STOP" into `labels`)
##   "tourist"   a brown board 1.5 wide with the white crest and `text` (into `labels`)
static func road_sign(pk: PropKit, kit: Dictionary, kind: String, labels := [], text := "") -> void:
	var yc := 2.3
	pk.tube(kit, "metal", Vector3(0, -0.6, 0), Vector3(0, yc + 0.5, 0), 0.036, 0.036, 8, GALV, true)
	var wf := _pl(Vector3(0, yc, 0.04), Vector3.BACK)
	var back: Color = GALV.darkened(0.1)
	match kind:
		"speed40":
			pk.tube(kit, "metal", Vector3(0, yc, 0.04), Vector3(0, yc, 0.06), 0.36, 0.36, 14, back, true)
			_disc(pk, kit, "paint", wf, Vector2.ZERO, 0.345, 14, 0.035, OFF_WHITE)
			_annulus(pk, kit, "paint", wf, Vector2.ZERO, 0.265, 0.345, 14, 0.05, SIGN_RED)
			labels.append(["40", Vector3(0, yc, 0.095), Vector3.BACK, 0.25, SIGN_BLUE, 0.42])
		"stop":
			var tri: Array = [Vector2(-0.45, 0.26), Vector2(0.45, 0.26), Vector2(0, -0.52)]
			_plate(pk, kit, wf, tri, back)
			_flat(pk, kit, "paint", wf, PackedVector2Array([Vector2(-0.42, 0.245), Vector2(0.42, 0.245), Vector2(0, -0.485)]), 0.035, SIGN_RED)
			_stroke(pk, kit, "paint", wf, [Vector2(-0.365, 0.215), Vector2(0.365, 0.215), Vector2(0, -0.42)], 0.03, 0.05, OFF_WHITE, true)
			labels.append(["STOP", Vector3(0, yc + 0.06, 0.095), Vector3.BACK, 0.12, OFF_WHITE, 0.46])
		"tourist":
			_slab(pk, kit, "paint", wf, -0.75, -0.21, 0.75, 0.21, 0.0, 0.03, SIGN_BROWN)
			_stroke(pk, kit, "paint", wf, [Vector2(-0.71, -0.17), Vector2(0.71, -0.17), Vector2(0.71, 0.17), Vector2(-0.71, 0.17)], 0.018, 0.045, OFF_WHITE, true)
			sakura_crest(pk, kit, "paint", wf * Vector3(-0.52, 0, 0.03), Vector3.BACK, 0.12, OFF_WHITE)
			if text != "":
				labels.append([text, Vector3(0.14, yc, 0.11), Vector3.BACK, 0.15, OFF_WHITE, 1.0])
		_:
			var rr := 0.6 / sqrt(2.0)
			_plate(pk, kit, wf, [Vector2(0, -rr), Vector2(rr, 0), Vector2(0, rr), Vector2(-rr, 0)], back)
			var ri: float = rr - 0.015
			_flat(pk, kit, "paint", wf, PackedVector2Array([Vector2(0, -ri), Vector2(ri, 0), Vector2(0, ri), Vector2(-ri, 0)]), 0.035, SIGN_YELLOW)
			var rb: float = rr - 0.05
			_stroke(pk, kit, "paint", wf, [Vector2(0, -rb), Vector2(rb, 0), Vector2(0, rb), Vector2(-rb, 0)], 0.02, 0.05, INK, true)
			_sign_symbol(pk, kit, wf, kind, rr, 0.05)


## A sign's plate: a thin prism of the outline `ol`, from the frame's plane to 2cm before it.
static func _plate(pk: PropKit, kit: Dictionary, wf: Transform3D, ol: Array, col: Color) -> void:
	var s0: Array = []
	var s1: Array = []
	for p: Vector2 in ol:
		s0.append(wf * Vector3(p.x, p.y, 0.0))
		s1.append(wf * Vector3(p.x, p.y, 0.02))
	_loft(pk, kit, "metal", [s0, s1], col)


## A warning sign's black symbol, in units of the diamond's half diagonal `rr`.
static func _sign_symbol(pk: PropKit, kit: Dictionary, wf: Transform3D, kind: String, rr: float, d: float) -> void:
	var line: Array = []
	var mirror := 1.0
	match kind:
		"curve_l", "curve_r":
			line = [Vector2(-0.14, -0.5), Vector2(-0.14, -0.05), Vector2(0.0, 0.2), Vector2(0.24, 0.3)]
			mirror = -1.0 if kind == "curve_l" else 1.0
		"winding":
			line = [Vector2(0.12, -0.52), Vector2(0.12, -0.3), Vector2(-0.14, -0.1), Vector2(-0.14, 0.04), Vector2(0.1, 0.22), Vector2(0.1, 0.3)]
		"falling_rocks":
			_flat(pk, kit, "paint", wf, _scaled([Vector2(-0.46, -0.36), Vector2(-0.04, -0.36), Vector2(-0.26, 0.08), Vector2(-0.2, 0.44), Vector2(-0.46, 0.44)], rr, 1.0), d, INK)
			_stroke(pk, kit, "paint", wf, _scaled_arr([Vector2(0.0, -0.385), Vector2(0.5, -0.385)], rr, 1.0), 0.05 * rr, d, INK)
			for q: Vector3 in [Vector3(0.0, 0.3, 0.07), Vector3(0.17, 0.08, 0.09), Vector3(0.06, -0.1, 0.06), Vector3(0.32, -0.2, 0.1), Vector3(0.24, -0.3, 0.05)]:
				_disc(pk, kit, "paint", wf, Vector2(q.x, q.y) * rr, q.z * rr, 5, d, INK)
		"slippery":
			_flat(pk, kit, "paint", wf, _scaled([Vector2(-0.2, 0.08), Vector2(0.2, 0.08), Vector2(0.2, 0.3), Vector2(0.1, 0.46), Vector2(-0.1, 0.46), Vector2(-0.2, 0.3)], rr, 1.0), d, INK)
			for sx: float in [-1.0, 1.0]:
				_rect(pk, kit, "paint", wf, (sx * 0.14 - 0.045) * rr, -0.01 * rr, (sx * 0.14 + 0.045) * rr, 0.06 * rr, d, INK)
				_stroke(pk, kit, "paint", wf, _scaled_arr([Vector2(sx * 0.14, -0.07), Vector2(sx * 0.14 - 0.1, -0.2), Vector2(sx * 0.14 + 0.05, -0.32), Vector2(sx * 0.14 - 0.07, -0.47)], rr, 1.0),
						0.05 * rr, d, INK)
	if line.size() > 1:
		var pts: Array = _scaled_arr(line, rr, mirror)
		_stroke(pk, kit, "paint", wf, pts, 0.13 * rr, d, INK)
		var tip: Vector2 = pts[pts.size() - 1]
		var dir: Vector2 = (tip - (pts[pts.size() - 2] as Vector2)).normalized()
		var nr := Vector2(-dir.y, dir.x)
		_flat(pk, kit, "paint", wf, PackedVector2Array([tip + nr * 0.17 * rr, tip + dir * 0.27 * rr, tip - nr * 0.17 * rr]), d, INK)


static func _scaled_arr(pts: Array, k: float, mirror: float) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(Vector2(p.x * mirror, p.y) * k)
	return out


static func _scaled(pts: Array, k: float, mirror: float) -> PackedVector2Array:
	return PackedVector2Array(_scaled_arr(pts, k, mirror))


## A nobori, centred on its pole: the tall narrow banner of shops and shrines, `h` tall, on a bamboo pole with a
## crosspiece; the cloth (0.6 x 0.7 h, in the x-y plane beside the pole, toward +x) one sheet in `col` between two white
## stripes, the crest on both of its faces.
static func nobori(pk: PropKit, kit: Dictionary, col: Color, h := 4.4, crest := true) -> void:
	pk.tube(kit, "matte", Vector3(0, -0.6, 0), Vector3(0, h, 0), 0.024, 0.017, 6, BAMBOO_DRY, true)
	var x0 := 0.035
	var x1 := 0.64
	var yt: float = h - 0.1
	var yb: float = h - 0.1 - h * 0.7
	pk.tube(kit, "matte", Vector3(-0.03, yt + 0.015, 0), Vector3(x1 + 0.02, yt + 0.015, 0), 0.012, 0.012, 4, BAMBOO_DRY, true)
	# The sheet in bands from the top: white, the colour, white, the colour (its foot swung out a little).
	var ys: Array = [yt, yt - 0.14, lerpf(yt, yb, 0.52), lerpf(yt, yb, 0.52) - 0.1, lerpf(yt, yb, 0.8), yb]
	var zs: Array = [0.0, 0.0, 0.0, 0.0, 0.03, 0.1]
	var cs: Array = [OFF_WHITE, col, OFF_WHITE, col, col.darkened(0.06)]
	for k in range(5):
		pk.quad(kit, "cloth", [Vector3(x0, ys[k + 1], zs[k + 1]), Vector3(x1, ys[k + 1], zs[k + 1]), Vector3(x1, ys[k], zs[k]), Vector3(x0, ys[k], zs[k])], Vector3.BACK, cs[k])
	# The loops that hold it to the pole and the crosspiece.
	for k in range(5):
		var y: float = lerpf(yt - 0.1, yb + 0.25, float(k) / 4.0)
		pk.block(kit, "matte", Vector3(-0.03, y - 0.02, -0.03), Vector3(x0 + 0.02, y + 0.02, 0.03), OFF_WHITE)
	if crest:
		var cy: float = lerpf(yt - 0.14, lerpf(yt, yb, 0.52), 0.5)
		var cc: Color = OFF_WHITE if col.get_luminance() < 0.6 else VERMILION
		for sz: float in [-1.0, 1.0]:
			sakura_crest(pk, kit, "cloth", Vector3((x0 + x1) * 0.5, cy, 0.0), Vector3(0, 0, sz), 0.2, cc)


# ======================================================================================
#  Wayside stones and little shrines
# ======================================================================================

## `n` small stone jizo (rounded monk figures 0.6-0.9 tall, hands together) in a row along x on a low stone plinth,
## facing +z: each in a red bib, some in a red knitted cap, coins and flowers before a few. 0.46 a figure, 0.64 deep.
static func jizo_row(pk: PropKit, kit: Dictionary, n: int, rng: RandomNumberGenerator) -> void:
	var sp := 0.46
	var half: float = float(n) * sp * 0.5 + 0.1
	pk.block(kit, "ishi", Vector3(-half - 0.07, -0.6, -0.32), Vector3(half + 0.07, 0.1, 0.32), STONE_B.darkened(0.1), uvk)
	pk.block(kit, "ishi", Vector3(-half, 0.09, -0.25), Vector3(half, 0.22, 0.25), STONE_A, uvk)
	for i in range(n):
		var x: float = (float(i) - float(n - 1) * 0.5) * sp
		var k: float = rng.randf_range(0.6, 0.9) / 0.8
		var col: Color = STONE_A.lerp(STONE_B, rng.randf()).darkened(rng.randf() * 0.12)
		var c := Vector3(x + rng.randf_range(-0.02, 0.02), 0.21, -0.03)
		_turn(pk, kit, "matte", c, [Vector2(0.15 * k, 0.0), Vector2(0.155 * k, 0.1 * k), Vector2(0.13 * k, 0.38 * k), Vector2(0.105 * k, 0.5 * k), Vector2(0.055 * k, 0.56 * k)], 7, col)
		var hc: Vector3 = c + Vector3(0, 0.635 * k, 0)
		_ell(pk, kit, "matte", hc, Vector3(0.095, 0.1, 0.095) * k, 7, 4, col.lightened(0.04))
		_octa(pk, kit, "matte", c + Vector3(0, 0.39 * k, 0.125 * k), Vector3(0.035, 0.055, 0.03) * k, col.lightened(0.03))
		# The bib: one sheet round the chest.
		for j in range(4):
			var a0: float = PI * 0.5 - 1.15 + 2.3 * float(j) / 4.0
			var a1: float = PI * 0.5 - 1.15 + 2.3 * float(j + 1) / 4.0
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var lo: float = 0.31 if (j == 1 or j == 2) else 0.36
			pk.quad(kit, "cloth", [c + d0 * (0.155 * k + 0.012) + Vector3(0, lo * k, 0), c + d1 * (0.155 * k + 0.012) + Vector3(0, lo * k, 0),
					c + d1 * (0.125 * k + 0.012) + Vector3(0, 0.5 * k, 0), c + d0 * (0.125 * k + 0.012) + Vector3(0, 0.5 * k, 0)], (d0 + d1).normalized(), BIB_RED)
		if rng.randf() < 0.45:
			_turn(pk, kit, "rope", hc, [Vector2(0.112 * k, -0.005 * k), Vector2(0.108 * k, 0.045 * k), Vector2(0.07 * k, 0.095 * k), Vector2(0.0, 0.118 * k)], 7, BIB_RED.darkened(0.08))
		if rng.randf() < 0.5:
			_disc(pk, kit, "gold", _pl(Vector3(x + 0.1, 0.22, 0.19), Vector3.UP), Vector2.ZERO, 0.022, 5, 0.012, GOLD)
		if rng.randf() < 0.4:
			var f := Vector3(x - 0.12, 0.215, 0.18)
			_turn(pk, kit, "gloss", f, [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.036, 0.1)], 5, OFF_WHITE)
			_octa(pk, kit, "leaf", f + Vector3(0.01, 0.15, 0), Vector3(0.035, 0.035, 0.035), PAPER_PINK)
			_octa(pk, kit, "leaf", f + Vector3(-0.02, 0.19, 0.01), Vector3(0.03, 0.03, 0.03), Color(0.98, 0.84, 0.3))


## A guardian lion-dog (komainu) sitting on a tall three-tier plinth, centred, facing +z; about 1.95 tall, the plinth
## 0.84 x 1.2. The plain one has its mouth open (a), the `mirror` one closed (un) and its head turned the other way:
## they stand as a pair either side of a path, heads turned a little toward it.
static func komainu(pk: PropKit, kit: Dictionary, mirror := false) -> void:
	pk.block(kit, "ishi", Vector3(-0.42, -0.6, -0.6), Vector3(0.42, 0.14, 0.6), STONE_B.darkened(0.1), uvk)
	pk.block(kit, "ishi", Vector3(-0.34, 0.13, -0.5), Vector3(0.34, 0.8, 0.5), STONE_A, uvk)
	pk.block(kit, "ishi", Vector3(-0.4, 0.79, -0.56), Vector3(0.4, 0.95, 0.56), STONE_B, uvk)
	var py := 0.94
	var col: Color = STONE_A.lerp(STONE_B, 0.4)
	var mx: float = -1.0 if mirror else 1.0
	_ell(pk, kit, "matte", Vector3(0, py + 0.2, -0.17), Vector3(0.23, 0.22, 0.27), 8, 4, col)
	_ell(pk, kit, "matte", Vector3(0, py + 0.42, 0.05), Vector3(0.19, 0.31, 0.2), 8, 4, col, Basis(Vector3.RIGHT, 0.3))
	for sx: float in [-1.0, 1.0]:
		pk.tube(kit, "matte", Vector3(sx * 0.12, py + 0.45, 0.2), Vector3(sx * 0.13, py + 0.03, 0.3), 0.075, 0.062, 6, col, false)
		_ell(pk, kit, "matte", Vector3(sx * 0.13, py + 0.045, 0.34), Vector3(0.078, 0.05, 0.1), 6, 2, col.lightened(0.03))
		_ell(pk, kit, "matte", Vector3(sx * 0.21, py + 0.05, 0.08), Vector3(0.07, 0.055, 0.15), 6, 2, col)
	# The head, turned toward the path, with its muzzle, brows, ears and the mane's curls.
	var hb := Basis(Vector3.UP, 0.32 * mx)
	var hc := Vector3(0, py + 0.77, 0.19)
	_ell(pk, kit, "matte", hc, Vector3(0.19, 0.18, 0.2), 8, 4, col.lightened(0.03), hb)
	_ell(pk, kit, "matte", hc + hb * Vector3(0, -0.02, 0.18), Vector3(0.125, 0.085, 0.11), 6, 3, col.lightened(0.05), hb)
	_octa(pk, kit, "matte", hc + hb * Vector3(0, 0.02, 0.29), Vector3(0.04, 0.03, 0.03), col.darkened(0.45), hb)
	if not mirror:
		pk.box(kit, "matte", Transform3D(hb, hc + hb * Vector3(0, -0.098, 0.19)), Vector3(0.15, 0.03, 0.15), Color(0.16, 0.08, 0.07))
		_ell(pk, kit, "matte", hc + hb * Vector3(0, -0.14, 0.17), Vector3(0.1, 0.04, 0.1), 6, 2, col, hb)
	for sx: float in [-1.0, 1.0]:
		_ell(pk, kit, "matte", hc + hb * Vector3(sx * 0.085, 0.075, 0.15), Vector3(0.065, 0.035, 0.05), 5, 2, col.darkened(0.1), hb)
		_octa(pk, kit, "matte", hc + hb * Vector3(sx * 0.07, 0.035, 0.185), Vector3(0.022, 0.022, 0.015), INK, hb)
		_octa(pk, kit, "matte", hc + hb * Vector3(sx * 0.17, 0.08, -0.02), Vector3(0.05, 0.085, 0.045), col.darkened(0.08), hb * Basis(Vector3.BACK, -sx * 0.5))
	for k in range(7):
		var ang: float = PI * 1.5 + (float(k) - 3.0) * 0.44
		_ell(pk, kit, "matte", hc + hb * Vector3(cos(ang) * 0.17, -0.05 + 0.04 * float(k % 2), sin(ang) * 0.17), Vector3(0.09, 0.1, 0.09), 5, 3, col.darkened(0.05 + 0.06 * float(k % 2)), hb)
	for k in range(5):
		var ang: float = PI * 1.5 + (float(k) - 2.0) * 0.6
		_ell(pk, kit, "matte", Vector3(cos(ang) * 0.19, py + 0.55, 0.1 + sin(ang) * 0.18), Vector3(0.09, 0.09, 0.09), 5, 3, col.darkened(0.1))
	# The tail: a flame standing behind, with two curls.
	_ell(pk, kit, "matte", Vector3(0, py + 0.52, -0.42), Vector3(0.07, 0.25, 0.11), 6, 3, col.darkened(0.05), Basis(Vector3.RIGHT, -0.25))
	for sx: float in [-1.0, 1.0]:
		_octa(pk, kit, "matte", Vector3(sx * 0.09, py + 0.36, -0.42), Vector3(0.07, 0.1, 0.07), col.darkened(0.1))


## A pilgrim way-stone, centred, `h` tall: a rough granite pillar 0.3 x 0.24 with a dressed face toward +z. `text` goes
## into `labels` letter by letter down the face (as such stones are cut), or across it if longer than ten letters.
static func stone_marker(pk: PropKit, kit: Dictionary, h := 1.5, text := "", labels := []) -> void:
	var secs: Array = []
	var rows: Array = [[-0.6, 0.165, 0.135, 0.0, 0.0], [h * 0.45, 0.15, 0.125, 0.008, -0.006], [h - 0.1, 0.135, 0.11, -0.006, 0.004], [h, 0.07, 0.06, 0.012, 0.0]]
	for r: Array in rows:
		var y: float = r[0]
		var hx: float = r[1]
		var hz: float = r[2]
		var ox: float = r[3]
		var oz: float = r[4]
		secs.append([Vector3(ox + hx, y, oz + hz), Vector3(ox - hx, y, oz + hz), Vector3(ox - hx * 0.94, y, oz - hz), Vector3(ox + hx * 0.9, y, oz - hz * 0.92)])
	_loft(pk, kit, "matte", secs, STONE_A, false, true)
	var wf := _pl(Vector3(0, h * 0.52, 0.128), Vector3.BACK)
	_rect(pk, kit, "matte", wf, -0.1, -h * 0.34, 0.1, h * 0.34, 0.012, STONE_A.lightened(0.12))
	if text != "":
		var ink := Color(0.14, 0.13, 0.12)
		if text.length() <= 10:
			var cap: float = minf(0.1, h * 0.62 / float(text.length()) * 0.72)
			var step: float = cap / 0.72
			for i in range(text.length()):
				labels.append([text.substr(i, 1), Vector3(0, h * 0.52 + step * (float(text.length() - 1) * 0.5 - float(i)), 0.128 + 0.03), Vector3.BACK, cap, ink, 0.16])
		else:
			labels.append([text, Vector3(0, h * 0.6, 0.158), Vector3.BACK, 0.06, ink, 0.18])


## A cairn, centred, about `h` tall: flat stones stacked by passing pilgrims, each smaller than the one under it.
static func cairn(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, h := 1.0) -> void:
	var n: int = 5 + rng.randi() % 3
	var y := -0.1
	var c := Vector3.ZERO
	for i in range(n):
		var f: float = float(i) / float(n - 1)
		var r: float = h * lerpf(0.36, 0.09, pow(f, 0.8)) * rng.randf_range(0.9, 1.1)
		var t: float = (h + 0.1 - y) / float(n - i) * (1.0 if i == n - 1 else rng.randf_range(0.85, 1.15))
		var col: Color = STONE_A.lerp(STONE_B, rng.randf()).darkened(rng.randf() * 0.2)
		var rot := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06)) * Basis.from_scale(Vector3(1.0, 1.0, rng.randf_range(0.72, 0.95)))
		_turn(pk, kit, "matte", c + Vector3(0, y, 0), [Vector2(0.0, 0.0), Vector2(r * 0.78, 0.01), Vector2(r, t * 0.45), Vector2(r * 0.8, t * 1.0), Vector2(0.0, t * 1.04)], 5, col, true, 0.0, rot)
		y += t
		c += Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1)) * r


## A wayside shrine (hokora), centred, its front toward +z: a little gabled timber house on a stone base, 1.3 high,
## 0.9 x 0.8 on the ground; tiny doors with gilt knobs, a canopy roof with a ridge log, forked finials and two billets
## across the ridge, a rope with its papers under the eave, an offering cup, a flask and a coin on the step.
static func hokora(pk: PropKit, kit: Dictionary) -> void:
	pk.block(kit, "ishi", Vector3(-0.45, -0.6, -0.4), Vector3(0.45, 0.4, 0.4), STONE_B, uvk)
	pk.block(kit, "ishi", Vector3(-0.38, 0.39, -0.3), Vector3(0.38, 0.5, 0.36), STONE_A, uvk)
	var wood: Color = CEDAR
	# The floor on its sills, the cell, its doors.
	pk.block(kit, "sugi", Vector3(-0.33, 0.49, -0.26), Vector3(0.33, 0.54, 0.3), wood.darkened(0.15), uvk)
	pk.block(kit, "sugi", Vector3(-0.26, 0.53, -0.22), Vector3(0.26, 0.98, 0.16), wood, uvk)
	for sx: float in [-1.0, 1.0]:
		pk.block(kit, "sugi", Vector3(sx * 0.105 - 0.095, 0.57, 0.16 - 0.01), Vector3(sx * 0.105 + 0.095, 0.9, 0.16 + TP), wood.darkened(0.25), uvk)
		_octa(pk, kit, "gold", Vector3(sx * 0.03, 0.74, 0.16 + TP + 0.012), Vector3(0.014, 0.014, 0.014), GOLD)
		_post(pk, kit, "hinoki", Vector3(sx * 0.3, 0, 0.27), 0.53, 0.96, 0.045, wood.darkened(0.1))
	# The roof: the back slope short, the front one long over the step; each a board with its own underside.
	var ry := 1.2
	var rz := -0.06
	var dark: Color = CEDAR_DARK
	var eave_b := Vector3(0, 0.99, -0.36)
	var eave_f := Vector3(0, 0.9, 0.5)
	for e: Vector3 in [eave_b, eave_f]:
		var ridge := Vector3(0, ry, rz)
		var mid: Vector3 = (ridge + e) * 0.5
		var run: Vector3 = (e - ridge)
		var zb: Vector3 = run.normalized()
		var yb: Vector3 = zb.cross(Vector3.RIGHT).normalized()
		if yb.y < 0.0:
			yb = -yb
		pk.box(kit, "sugi", Transform3D(Basis(Vector3.RIGHT, yb, Vector3.RIGHT.cross(yb)), mid), Vector3(0.92, 0.04, run.length()), dark, uvk)
	pk.tube(kit, "matte", Vector3(-0.5, ry + 0.03, rz), Vector3(0.5, ry + 0.03, rz), 0.04, 0.04, 6, dark.darkened(0.2), true)
	for sx: float in [-1.0, 1.0]:
		pk.tube(kit, "matte", Vector3(sx * 0.2, ry + 0.085, rz - 0.1), Vector3(sx * 0.2, ry + 0.085, rz + 0.1), 0.032, 0.032, 6, wood, true)
		for sz: float in [-1.0, 1.0]:
			pk.beam(kit, "matte", Vector3(sx * 0.475, ry - 0.12, rz - sz * 0.1), Vector3(sx * 0.475, ry + 0.24, rz + sz * 0.16), 0.022, 0.035, dark, Vector3.RIGHT)
	# The gable ends.
	for sx: float in [-1.0, 1.0]:
		pk.tri(kit, "matte", Vector3(sx * 0.262, 0.98, -0.22), Vector3(sx * 0.262, 0.98, 0.16), Vector3(sx * 0.262, ry - 0.03, rz), Vector3(sx, 0, 0), Vector3(sx, 0, 0), Vector3(sx, 0, 0),
				wood.darkened(0.2), Vector3(sx, 0, 0))
	shimenawa(pk, kit, Vector3(-0.3, 0.95, 0.31), Vector3(0.3, 0.95, 0.31), 0.035, 2, 0.03, 0.12)
	_turn(pk, kit, "gloss", Vector3(-0.12, 0.5, 0.31), [Vector2(0.0, 0.0), Vector2(0.025, 0.0), Vector2(0.04, 0.05)], 6, OFF_WHITE)
	_turn(pk, kit, "gloss", Vector3(0.1, 0.5, 0.3), [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.034, 0.06), Vector2(0.012, 0.09), Vector2(0.016, 0.12)], 6, OFF_WHITE)
	_disc(pk, kit, "gold", _pl(Vector3(0.0, 0.5, 0.32), Vector3.UP), Vector2.ZERO, 0.02, 5, 0.012, GOLD)


# ======================================================================================
#  Railings and fences (between two ground points, following the slope)
# ======================================================================================

## The onion-shaped cap (giboshi) of a railing's main post, standing on p; 0.3 s tall.
static func _giboshi(pk: PropKit, kit: Dictionary, p: Vector3, s := 1.0) -> void:
	_turn(pk, kit, "gold", p, [Vector2(0.0, -0.01), Vector2(0.07 * s, 0.0), Vector2(0.075 * s, 0.03 * s), Vector2(0.045 * s, 0.065 * s), Vector2(0.085 * s, 0.15 * s),
			Vector2(0.06 * s, 0.225 * s), Vector2(0.0, 0.3 * s)], 6, BRONZE.lerp(GOLD, 0.35))


## A lacquer railing (koran) for bridges and verandas from a to b, `h` to its round top rail: three rails, a strut every
## 2m, and at the ends and every third a taller main post under a giboshi (0.44 over the rail). Posts run 0.25 under the
## line a-b (into a deck or the ground).
static func koran(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 1.1, col := VERMILION) -> void:
	var ln: float = (b - a).length()
	if ln < 0.05:
		return
	var along: Vector3 = (b - a) / ln
	var spans: int = maxi(1, int(round(ln / 2.0)))
	for i in range(spans + 1):
		var p: Vector3 = a.lerp(b, float(i) / float(spans))
		if i == 0 or i == spans or i % 3 == 0:
			pk.block(kit, "urushi", p + Vector3(-0.06, -0.25, -0.06), p + Vector3(0.06, h + 0.14, 0.06), col)
			_giboshi(pk, kit, p + Vector3(0, h + 0.14, 0))
		else:
			pk.block(kit, "urushi", p + Vector3(-0.03, -0.25, -0.03), p + Vector3(0.03, h, 0.03), col)
	pk.tube(kit, "urushi", a - along * 0.16 + Vector3(0, h, 0), b + along * 0.16 + Vector3(0, h, 0), 0.045, 0.045, 6, col, true)
	pk.beam(kit, "urushi", a + Vector3(0, h * 0.58, 0), b + Vector3(0, h * 0.58, 0), 0.05, 0.06, col)
	pk.beam(kit, "urushi", a + Vector3(0, 0.12, 0), b + Vector3(0, 0.12, 0), 0.09, 0.07, col.darkened(0.08))


## A dry-stone retaining wall (ishigaki) along a terrace's edge from a to b (its top edge, the terrace's level): its face
## toward `out` (level), battered back `batter` per metre, dropping `drop` to the ground and running on 1m under it; a
## granite coping along the top, flush with the terrace. Segments of a curve meet at their ends.
static func ishigaki(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, out: Vector3, drop: float, batter := 0.22) -> void:
	var o: Vector3 = Vector3(out.x, 0.0, out.z).normalized()
	var l: float = (b - a).length()
	if l < 0.05:
		return
	var h: float = drop + 1.0
	var down := Vector3(0, -h, 0) + o * (h * batter)
	var top_a: Vector3 = a + Vector3(0, -0.28, 0)
	var top_b: Vector3 = b + Vector3(0, -0.28, 0)
	var n: Vector3 = (o + Vector3(0, batter, 0)).normalized()
	pk.quad(kit, "ishi", [top_a + down, top_b + down, top_b, top_a], n, GRANITE.darkened(0.12),
			[Vector2(0.0, 0.0), Vector2(l, 0.0) * uvk, Vector2(l, h) * uvk, Vector2(0.0, h) * uvk])
	# Moss and weather streaks low on the wall: a second, darker band over its foot.
	var band: float = minf(0.9, h * 0.5)
	var lift := Vector3(0, band, 0) + o * (-band * batter)
	pk.quad(kit, "ishi", [top_a + down + o * 0.01, top_b + down + o * 0.01, top_b + down + lift + o * 0.01, top_a + down + lift + o * 0.01], n,
			GRANITE_MOSSY.darkened(0.2), [Vector2(0.0, 0.0), Vector2(l, 0.0) * uvk, Vector2(l, band) * uvk, Vector2(0.0, band) * uvk])
	# The coping: a course of long granite blocks, 0.6 deep, its top the terrace's level, standing 4cm out.
	var c0a: Vector3 = a + o * 0.04
	var c0b: Vector3 = b + o * 0.04
	var c1a: Vector3 = a - o * 0.6
	var c1b: Vector3 = b - o * 0.6
	pk.quad(kit, "ishi", [c1a, c1b, c0b, c0a], Vector3.UP, GRANITE.lightened(0.05), [Vector2(0.0, 0.0), Vector2(l, 0.0) * uvk, Vector2(l, 0.64) * uvk, Vector2(0.0, 0.64) * uvk])
	pk.quad(kit, "ishi", [c0a + Vector3(0, -0.3, 0), c0b + Vector3(0, -0.3, 0), c0b, c0a], o, GRANITE, [Vector2(0.0, 0.0), Vector2(l, 0.0) * uvk, Vector2(l, 0.3) * uvk, Vector2(0.0, 0.3) * uvk])
	pk.quad(kit, "ishi", [c0a + Vector3(0, -0.3, 0), c0b + Vector3(0, -0.3, 0), top_b + o * 0.0, top_a], Vector3.DOWN, GRANITE.darkened(0.3))


## A pilgrim trail's chain fence from a to b: iron posts every 3m with a knob, two chains hanging between them.
static func chain_fence(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 1.0) -> void:
	var ln: float = (b - a).length()
	var spans: int = maxi(1, int(round(ln / 3.0)))
	for i in range(spans + 1):
		var p: Vector3 = a.lerp(b, float(i) / float(spans))
		pk.tube(kit, "metal", p + Vector3(0, -0.6, 0), p + Vector3(0, h, 0), 0.035, 0.03, 6, IRON, false)
		_octa(pk, kit, "metal", p + Vector3(0, h + 0.02, 0), Vector3(0.05, 0.05, 0.05), IRON)
		if i < spans:
			var q: Vector3 = a.lerp(b, float(i + 1) / float(spans))
			for y: float in [h - 0.1, h * 0.52]:
				_strand(pk, kit, "metal", _sag(p + Vector3(0, y, 0), q + Vector3(0, y, 0), 0.13, 4), 0.016, 3, IRON.lightened(0.06))


## A rope fence from a to b: rough cedar stakes every 2.5m, two straw ropes hanging between them.
static func rope_fence(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 0.9) -> void:
	var ln: float = (b - a).length()
	var spans: int = maxi(1, int(round(ln / 2.5)))
	for i in range(spans + 1):
		var p: Vector3 = a.lerp(b, float(i) / float(spans))
		var lean := Vector3(sin(float(i) * 2.3) * 0.04, 0, cos(float(i) * 1.7) * 0.04)
		pk.tube(kit, "hinoki", p + Vector3(0, -0.6, 0), p + lean + Vector3(0, h + 0.08 * sin(float(i) * 3.1), 0), 0.055, 0.042, 5, CEDAR.darkened(0.1 + 0.1 * absf(sin(float(i)))), true, uvk)
		if i < spans:
			var q: Vector3 = a.lerp(b, float(i + 1) / float(spans))
			for y: float in [h - 0.12, h * 0.48]:
				_strand(pk, kit, "rope", _sag(p + Vector3(0, y, 0), q + Vector3(0, y, 0), 0.09, 3), 0.018, 4, STRAW)


## A yotsume-gaki from a to b, `h` tall: bamboo posts every 1.8m, three bamboo rails, upright canes every 0.36m set
## alternately before and behind the rails, tied to the top rail with black twine.
static func bamboo_fence(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 1.3) -> void:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var ln: float = flat.length()
	if ln < 0.05:
		return
	var side: Vector3 = Vector3(-flat.z, 0, flat.x) / ln
	var spans: int = maxi(1, int(round(ln / 1.8)))
	for i in range(spans + 1):
		var p: Vector3 = a.lerp(b, float(i) / float(spans))
		pk.tube(kit, "matte", p + Vector3(0, -0.6, 0), p + Vector3(0, h + 0.08, 0), 0.045, 0.042, 6, BAMBOO_DRY.darkened(0.25), true)
	for fy: float in [0.2, 0.55, 0.88]:
		pk.tube(kit, "matte", a + Vector3(0, h * fy, 0), b + Vector3(0, h * fy, 0), 0.022, 0.022, 5, BAMBOO_DRY, true)
	var canes: int = maxi(1, int(round(ln / 0.36)))
	for i in range(canes):
		var p: Vector3 = a.lerp(b, (float(i) + 0.5) / float(canes))
		var sd: float = 1.0 if i % 2 == 0 else -1.0
		var top: float = h * (1.0 + 0.04 * sin(float(i) * 1.9))
		var col: Color = BAMBOO_DRY.lerp(BAMBOO, 0.25 + 0.25 * sin(float(i) * 2.7))
		pk.tube(kit, "matte", p + side * (sd * 0.04) + Vector3(0, -0.12, 0), p + side * (sd * 0.04) + Vector3(0, top, 0), 0.017, 0.017, 4, col, false)
		_octa(pk, kit, "matte", p + side * (sd * 0.035) + Vector3(0, h * 0.88, 0), Vector3(0.03, 0.03, 0.03), INK)


# ======================================================================================
#  Hanami
# ======================================================================================

## A bottle standing on p: sake (tall, brown or green) or a can.
static func _bottle(pk: PropKit, kit: Dictionary, p: Vector3, col: Color, s := 1.0) -> void:
	_turn(pk, kit, "gloss", p, [Vector2(0.0, 0.0), Vector2(0.05 * s, 0.0), Vector2(0.05 * s, 0.2 * s), Vector2(0.018 * s, 0.29 * s), Vector2(0.018 * s, 0.36 * s), Vector2(0.0, 0.36 * s)], 6, col)


static func _can(pk: PropKit, kit: Dictionary, p: Vector3, col: Color) -> void:
	_turn(pk, kit, "metal", p, [Vector2(0.0, 0.0), Vector2(0.033, 0.0), Vector2(0.033, 0.12), Vector2(0.0, 0.12)], 5, col)


## A cushion (zabuton) lying on p, turned by yaw.
static func _cushion(pk: PropKit, kit: Dictionary, p: Vector3, yaw: float, col: Color) -> void:
	pk.box(kit, "rope", Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.035, 0)), Vector3(0.5, 0.07, 0.5), col, 0.0, true)


## A cherry-blossom picnic, centred, on the ground: a sheet with what a party leaves on it (the people are the
## generator's). 3.6 x 2.7 (variant 2: 3.6 x 1.8), nothing over 0.45.
##   0  a blue tarp: stacked lacquer boxes, open boxes of food, sake bottles, cans, cups, cushions, a paper bag, shoes
##      lined up at its edge
##   1  the same with a low folding table and a charcoal grill
##   2  a red felt carpet with a tea set on a lacquer tray, sweets, two cushions
static func hanami_set(pk: PropKit, kit: Dictionary, variant: int, rng: RandomNumberGenerator) -> void:
	var hx := 1.8
	var hz: float = 0.9 if variant == 2 else 1.35
	var sheet: Color = FELT_RED if variant == 2 else TARP_BLUE
	# The sheet: one face, a little rumpled, never under 2cm.
	var gx := 4
	var gz := 3
	var hgt: Array = []
	for j in range(gz + 1):
		for i in range(gx + 1):
			hgt.append(0.02 + rng.randf() * (0.03 if (i == 0 or j == 0 or i == gx or j == gz) else 0.008))
	for j in range(gz):
		for i in range(gx):
			var q: Array = []
			for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				q.append(Vector3(lerpf(-hx, hx, float(c.x) / float(gx)), hgt[c.y * (gx + 1) + c.x], lerpf(-hz, hz, float(c.y) / float(gz))))
			pk.quad(kit, "cloth", q, Vector3.UP, sheet if (i + j) % 2 == 0 else sheet.darkened(0.04))
	var y0 := 0.03
	if variant == 2:
		# The tray, the pot with its side handle and spout, cups of green tea, a plate of three-coloured dango.
		pk.block(kit, "urushi", Vector3(-0.3, y0, -0.2), Vector3(0.3, y0 + 0.03, 0.2), BLACK_LAC)
		var tp := Vector3(-0.12, y0 + 0.03, 0.0)
		_turn(pk, kit, "matte", tp, [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.085, 0.05), Vector2(0.07, 0.1), Vector2(0.03, 0.115), Vector2(0.0, 0.14)], 7, Color(0.36, 0.2, 0.14))
		pk.tube(kit, "matte", tp + Vector3(0.07, 0.06, 0), tp + Vector3(0.15, 0.1, 0), 0.016, 0.01, 4, Color(0.36, 0.2, 0.14), false)
		pk.tube(kit, "matte", tp + Vector3(0, 0.06, 0.07), tp + Vector3(0, 0.08, 0.2), 0.014, 0.016, 4, Color(0.36, 0.2, 0.14), true)
		for k in range(4):
			var cp := Vector3(0.08 + 0.1 * float(k % 2), y0 + 0.03, -0.1 + 0.2 * float(k / 2))
			_turn(pk, kit, "gloss", cp, [Vector2(0.0, 0.0), Vector2(0.025, 0.0), Vector2(0.036, 0.055), Vector2(0.0, 0.045)], 6, OFF_WHITE)
			_disc(pk, kit, "gloss", _pl(cp + Vector3(0, 0.044, 0), Vector3.UP), Vector2.ZERO, 0.03, 6, 0.0, Color(0.45, 0.6, 0.2))
		var pp := Vector3(0.75, y0, 0.25)
		_turn(pk, kit, "gloss", pp, [Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.15, 0.02), Vector2(0.0, 0.012)], 8, OFF_WHITE)
		for k in range(3):
			for j in range(3):
				_octa(pk, kit, "leaf", pp + Vector3(-0.07 + 0.07 * float(k), 0.045, -0.045 + 0.045 * float(j)), Vector3(0.022, 0.022, 0.022), [PAPER_PINK, OFF_WHITE, Color(0.55, 0.7, 0.35)][j])
		_cushion(pk, kit, Vector3(-1.0, y0, 0.1), 0.15, NOREN[0])
		_cushion(pk, kit, Vector3(1.25, y0, -0.25), -0.2, NOREN[4])
		_bottle(pk, kit, Vector3(-0.55, y0, -0.45), Color(0.2, 0.34, 0.18), 0.9)
		return
	# Stacked lacquer boxes (jubako) with a gold line, and two open ones with food.
	var jp := Vector3(rng.randf_range(-0.5, -0.1), y0, rng.randf_range(-0.3, 0.1))
	for k in range(3):
		pk.block(kit, "urushi", jp + Vector3(-0.11, 0.075 * float(k), -0.11), jp + Vector3(0.11, 0.075 * float(k) + 0.068, 0.11), BLACK_LAC if k < 2 else VERMILION)
	sakura_crest(pk, kit, "gold", jp + Vector3(0, 0.218, 0), Vector3.UP, 0.07, GOLD)
	var food: Array = [Color(0.95, 0.8, 0.25), Color(0.95, 0.94, 0.9), Color(0.85, 0.35, 0.3), Color(0.4, 0.6, 0.25)]
	for k in range(2):
		var op: Vector3 = jp + Vector3(0.32 + 0.27 * float(k), 0, rng.randf_range(-0.1, 0.1))
		pk.block(kit, "urushi", op + Vector3(-0.11, 0, -0.11), op + Vector3(0.11, 0.06, 0.11), BLACK_LAC)
		pk.quad(kit, "urushi", [op + Vector3(-0.095, 0.072, -0.095), op + Vector3(0.095, 0.072, -0.095), op + Vector3(0.095, 0.072, 0.095), op + Vector3(-0.095, 0.072, 0.095)], Vector3.UP, VERMILION)
		for f in range(4):
			var fp: Vector3 = op + Vector3(-0.045 + 0.09 * float(f % 2), 0.074, -0.045 + 0.09 * float(f / 2))
			pk.box(kit, "rope", Transform3D(Basis(), fp + Vector3(0, 0.012, 0)), Vector3(0.07, 0.024, 0.07), food[(f + k) % 4], 0.0, true)
	# Bottles, cans and cups.
	var sp := Vector3(rng.randf_range(0.5, 0.9), y0, rng.randf_range(-0.8, -0.5))
	_bottle(pk, kit, sp, Color(0.3, 0.17, 0.08))
	_bottle(pk, kit, sp + Vector3(0.14, 0, 0.06), Color(0.2, 0.34, 0.18))
	for k in range(4):
		_can(pk, kit, Vector3(rng.randf_range(-0.9, 0.9), y0, rng.randf_range(-0.9, 0.9)), [Color(0.85, 0.82, 0.7), Color(0.75, 0.12, 0.1), Color(0.2, 0.4, 0.7), Color(0.9, 0.7, 0.15)][k])
	for k in range(4):
		var cp := Vector3(jp.x + 0.1 * float(k), y0, jp.z + 0.3 + 0.04 * float(k % 2))
		_turn(pk, kit, "gloss", cp, [Vector2(0.0, 0.0), Vector2(0.022, 0.0), Vector2(0.032, 0.07), Vector2(0.0, 0.06)], 5, OFF_WHITE)
	for k in range(4 if variant == 0 else 3):
		_cushion(pk, kit, Vector3([-1.3, 1.3, -1.25, 1.2][k] + rng.randf_range(-0.1, 0.1), y0, [-0.7, -0.75, 0.6, 0.55][k]), rng.randf_range(-0.4, 0.4), NOREN[(k * 2 + 1) % NOREN.size()])
	# A paper bag, leaning.
	pk.box(kit, "rope", Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.12), Vector3(-0.3, y0 + 0.16, 0.95)), Vector3(0.26, 0.33, 0.12), PAPER.darkened(0.12), 0.0, true)
	# Shoes in pairs at the near edge, on the ground.
	for k in range(3):
		var sx0: float = -0.9 + 0.75 * float(k) + rng.randf_range(-0.1, 0.1)
		var shoe: Color = [Color(0.12, 0.12, 0.13), OFF_WHITE, Color(0.45, 0.25, 0.15)][k]
		for e in range(2):
			pk.box(kit, "rope", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)), Vector3(sx0 + 0.13 * float(e), 0.035, hz + 0.2)), Vector3(0.095, 0.09, 0.26), shoe, 0.0, true)
	if variant == 1:
		# The folding table and the grill (shichirin) beside the sheet's far edge.
		var tc := Vector3(0.2, y0, 0.45)
		pk.block(kit, "timber", tc + Vector3(-0.45, 0.28, -0.3), tc + Vector3(0.45, 0.31, 0.3), HINOKI, uvk)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				pk.block(kit, "metal", tc + Vector3(sx * 0.4 - 0.012, -0.01, sz * 0.25 - 0.012), tc + Vector3(sx * 0.4 + 0.012, 0.285, sz * 0.25 + 0.012), GALV)
		_can(pk, kit, tc + Vector3(-0.2, 0.31, 0.05), Color(0.9, 0.7, 0.15))
		_bottle(pk, kit, tc + Vector3(0.2, 0.31, -0.1), Color(0.3, 0.17, 0.08), 0.8)
		var gc := Vector3(1.25, y0, 0.2)
		_turn(pk, kit, "matte", gc, [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.16, 0.2), Vector2(0.17, 0.24), Vector2(0.14, 0.24), Vector2(0.13, 0.19), Vector2(0.0, 0.19)], 8, Color(0.8, 0.74, 0.62))
		_disc(pk, kit, "neon", _pl(gc + Vector3(0, 0.2, 0), Vector3.UP), Vector2.ZERO, 0.1, 6, 0.0, Color(0.95, 0.35, 0.08))
		for k in range(4):
			pk.beam(kit, "metal", gc + Vector3(-0.15, 0.25, -0.09 + 0.06 * float(k)), gc + Vector3(0.15, 0.25, -0.09 + 0.06 * float(k)), 0.01, 0.01, IRON)


## The red-felt bench of tea houses (en-dai), centred, its long side along x: 1.8 x 0.62, 0.43 high, the felt hanging
## over both long sides; `parasol` stands a big red paper umbrella (nodate-gasa, 2.5 across, to 2.75) on a bamboo pole
## behind it.
static func red_bench(pk: PropKit, kit: Dictionary, parasol := true) -> void:
	var wood: Color = CEDAR.darkened(0.15)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_post(pk, kit, "hinoki", Vector3(sx * 0.78, 0, sz * 0.24), -0.3, 0.37, 0.06, wood)
		_bar(pk, kit, "hinoki", Vector3(sx * 0.78, 0.16, -0.24), Vector3(sx * 0.78, 0.16, 0.24), 0.045, 0.045, wood, Vector3.RIGHT)
	pk.block(kit, "hinoki", Vector3(-0.9, 0.36, -0.3), Vector3(0.9, 0.41, 0.3), wood, uvk)
	# The felt: its top a slab over the boards, its skirts one sheet each.
	pk.block(kit, "rope", Vector3(-0.92, 0.405, -0.315), Vector3(0.92, 0.435, 0.315), FELT_RED)
	for sz: float in [-1.0, 1.0]:
		pk.quad(kit, "cloth", [Vector3(-0.92, 0.24, sz * 0.33), Vector3(0.92, 0.24, sz * 0.33), Vector3(0.92, 0.43, sz * 0.316), Vector3(-0.92, 0.43, sz * 0.316)], Vector3(0, 0, sz), FELT_RED.darkened(0.08))
	if parasol:
		var base := Vector3(0.55, 0, -0.5)
		pk.tube(kit, "matte", base + Vector3(0, -0.6, 0), base + Vector3(0, 2.72, 0), 0.028, 0.024, 6, BAMBOO_DRY.darkened(0.15), true)
		var tip := Basis(Vector3.RIGHT, 0.1)
		var top: Vector3 = base + Vector3(0, 2.66, 0)
		var n := 16
		for k in range(n):
			var a0: float = TAU * float(k) / float(n)
			var a1: float = TAU * float(k + 1) / float(n)
			var e0: Vector3 = top + tip * Vector3(cos(a0) * 1.25, -0.42, sin(a0) * 1.25)
			var e1: Vector3 = top + tip * Vector3(cos(a1) * 1.25, -0.42, sin(a1) * 1.25)
			var nr: Vector3 = (e1 - top).cross(e0 - top).normalized()
			if nr.y < 0.0:
				nr = -nr
			pk.tri(kit, "cloth", top, e0, e1, nr, nr, nr, PAPER_RED if k % 2 == 0 else PAPER_RED.darkened(0.1), nr)
			if k % 2 == 0:
				pk.tube(kit, "matte", top + Vector3(0, -0.5, 0), top + tip * Vector3(cos(a0) * 1.2, -0.44, sin(a0) * 1.2), 0.01, 0.01, 3, BAMBOO_DRY, false)
		_turn(pk, kit, "matte", top, [Vector2(0.06, -0.03), Vector2(0.05, 0.03), Vector2(0.0, 0.08)], 6, INK)


## A display of straw-wrapped sake barrels (komodaru), centred, facing +z: `cols` x `rows` barrels lying on a timber
## rack, their round faces painted (a coloured field, a white disc, the crest), a rope round each. 0.62 a barrel across,
## 0.25 + 0.64 a row high, 0.6 deep.
static func sake_barrels(pk: PropKit, kit: Dictionary, cols := 4, rows := 3) -> void:
	var r := 0.28
	var pitch := 0.62
	var row_h := 0.64
	var half: float = float(cols) * pitch * 0.5
	var wood: Color = HINOKI.darkened(0.2)
	var top: float = 0.25 + float(rows) * row_h
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_post(pk, kit, "hinoki", Vector3(sx * (half + 0.07), 0, sz * 0.24), -0.6, top + 0.05, 0.09, wood)
	var fields: Array = [VERMILION, INDIGO, Color(0.1, 0.35, 0.22), BLACK_LAC, Color(0.75, 0.55, 0.1)]
	for j in range(rows):
		var yb: float = 0.25 + float(j) * row_h
		for sz: float in [-1.0, 1.0]:
			_bar(pk, kit, "hinoki", Vector3(-half - 0.14, yb - 0.035, sz * 0.2), Vector3(half + 0.14, yb - 0.035, sz * 0.2), 0.07, 0.07, wood, Vector3.BACK)
		for i in range(cols):
			var c := Vector3(-half + pitch * (float(i) + 0.5), yb + r - 0.012, 0)
			pk.tube(kit, "rope", c + Vector3(0, 0, -0.29), c + Vector3(0, 0, 0.29), r, r, 8, STRAW.darkened(0.06 * float((i + j) % 2)), true)
			pk.tube(kit, "rope", c + Vector3(0, 0, 0.02), c + Vector3(0, 0, 0.08), r + 0.012, r + 0.012, 8, STRAW.darkened(0.3), false)
			var wf := _pl(c + Vector3(0, 0, 0.29), Vector3.BACK)
			var fc: Color = fields[(i * 2 + j * 3) % fields.size()]
			_disc(pk, kit, "paint", wf, Vector2.ZERO, 0.25, 8, 0.015, fc)
			_disc(pk, kit, "paint", wf, Vector2.ZERO, 0.185, 8, 0.03, OFF_WHITE)
			sakura_crest(pk, kit, "paint", wf * Vector3(0, 0, 0.03), Vector3.BACK, 0.14, fc if fc != BLACK_LAC else VERMILION)
	# A board over the top row.
	pk.block(kit, "sugi", Vector3(-half - 0.2, top + 0.04, -0.36), Vector3(half + 0.2, top + 0.08, 0.36), CEDAR_DARK, uvk)


## A drinks machine, centred, its front toward +z: 0.95 wide, 0.75 deep, 1.85 high on a kick plinth. Its body white (0),
## red (1) or blue (2); a lit window ("neon") with three rows of bottles and cans, a price strip with a button under each,
## a coin panel, the pick-up flap, the crest on its brow.
static func vending_machine(pk: PropKit, kit: Dictionary, variant := 0) -> void:
	var body: Color = [OFF_WHITE, Color(0.78, 0.1, 0.1), Color(0.1, 0.3, 0.68)][clampi(variant, 0, 2)]
	pk.block(kit, "matte", Vector3(-0.45, -0.6, -0.35), Vector3(0.45, 0.09, 0.35), Color(0.18, 0.18, 0.19))
	pk.block(kit, "gloss", Vector3(-0.475, 0.08, -0.375), Vector3(0.475, 1.85, 0.375), body)
	var wf := _pl(Vector3(0, 0, 0.375), Vector3.BACK)
	# The window, lit, and what stands in it.
	_rect(pk, kit, "neon", wf, -0.4, 0.92, 0.26, 1.7, TP, Color(0.92, 0.95, 1.0))
	var drinks: Array = [Color(0.85, 0.15, 0.12), Color(0.15, 0.5, 0.25), Color(0.95, 0.75, 0.1), Color(0.2, 0.35, 0.75), Color(0.9, 0.9, 0.88), Color(0.5, 0.25, 0.1),
			Color(0.95, 0.5, 0.15)]
	for j in range(3):
		var y: float = 0.98 + 0.25 * float(j)
		_rect(pk, kit, "paint", wf, -0.4, y - 0.045, 0.26, y - 0.01, TP + 0.03, Color(0.86, 0.86, 0.84))
		for i in range(6):
			var u: float = -0.345 + 0.11 * float(i)
			var tall: float = 0.17 if (i + j) % 3 != 0 else 0.12
			pk.box(kit, "neon", wf * Transform3D(Basis(), Vector3(u, y + tall * 0.5, TP + 0.02)), Vector3(0.062, tall, 0.04), drinks[(i * 3 + j * 2) % drinks.size()], 0.0, true)
			_rect(pk, kit, "neon", wf, u - 0.02, y - 0.038, u + 0.02, y - 0.018, TP + 0.045, Color(0.2, 0.55, 0.95) if (i + j) % 4 != 0 else Color(0.95, 0.25, 0.2))
	# The coin panel, the brow with the crest, the flap.
	_slab(pk, kit, "metal", wf, 0.29, 0.95, 0.44, 1.6, 0.0, TP, GALV)
	_rect(pk, kit, "matte", wf, 0.335, 1.38, 0.395, 1.5, TP + 0.015, INK)
	_rect(pk, kit, "matte", wf, 0.33, 1.2, 0.4, 1.23, TP + 0.015, INK)
	_slab(pk, kit, "metal", wf, 0.32, 1.02, 0.41, 1.1, TP, TP + 0.03, GALV.darkened(0.3))
	_rect(pk, kit, "paint", wf, -0.44, 1.73, 0.44, 1.82, TP, body.darkened(0.25) if variant == 0 else OFF_WHITE)
	sakura_crest(pk, kit, "paint", wf * Vector3(-0.33, 1.775, TP), Vector3.BACK, 0.04, VERMILION if variant == 0 else body)
	_slab(pk, kit, "matte", wf, -0.36, 0.3, 0.36, 0.52, 0.0, TP, Color(0.12, 0.12, 0.13))
	_rect(pk, kit, "gloss", wf, -0.33, 0.33, 0.33, 0.49, TP + 0.015, Color(0.3, 0.32, 0.35))
	_rect(pk, kit, "paint", wf, -0.44, 0.6, 0.44, 0.84, TP, body.darkened(0.12))


# ======================================================================================
#  Bridge, summit shrine, shrine yard, steps, the farm truck
# ======================================================================================

## A vermilion drum bridge (taiko-bashi) for walkers, centred, its deck along x from -span/2 to span/2 (both ends on the
## ground, y 0), `rise` high in the middle, `width` across (z): an arched plank deck on two lacquered girders, railings
## with giboshi on the end and middle posts (1.0 to the rail), two bents of timber piles and stone abutments down to FOOT.
static func arched_bridge(pk: PropKit, kit: Dictionary, span := 12.0, width := 3.0, rise := 1.8) -> void:
	var n := 12
	var hw: float = width * 0.5
	var xs: Array = []
	var ys: Array = []
	for i in range(n + 1):
		var x: float = span * (float(i) / float(n) - 0.5)
		xs.append(x)
		ys.append(rise * (1.0 - pow(2.0 * x / span, 2.0)))
	var deck: Array = []
	var g0: Array = []
	var g1: Array = []
	for i in range(n + 1):
		var x: float = xs[i]
		var y: float = ys[i]
		deck.append([Vector3(x, y, hw), Vector3(x, y, -hw), Vector3(x, y - 0.16, -hw), Vector3(x, y - 0.16, hw)])
		var zg: float = hw - 0.2
		g0.append([Vector3(x, y - 0.15, zg + 0.09), Vector3(x, y - 0.15, zg - 0.09), Vector3(x, y - 0.5, zg - 0.09), Vector3(x, y - 0.5, zg + 0.09)])
		g1.append([Vector3(x, y - 0.15, -zg + 0.09), Vector3(x, y - 0.15, -zg - 0.09), Vector3(x, y - 0.5, -zg - 0.09), Vector3(x, y - 0.5, -zg + 0.09)])
	_loft(pk, kit, "hinoki", deck, HINOKI.darkened(0.25), true, true, 1)
	_loft(pk, kit, "urushi", g0, VERMILION.darkened(0.1))
	_loft(pk, kit, "urushi", g1, VERMILION.darkened(0.1))
	for sz: float in [-1.0, 1.0]:
		var zr: float = sz * (hw - 0.09)
		for i in range(0, n + 1, 2):
			var p := Vector3(xs[i], ys[i], zr)
			if i == 0 or i == n or i == n / 2:
				pk.block(kit, "urushi", p + Vector3(-0.065, -0.2, -0.065), p + Vector3(0.065, 1.14, 0.065), VERMILION)
				_giboshi(pk, kit, p + Vector3(0, 1.14, 0))
			else:
				pk.block(kit, "urushi", p + Vector3(-0.04, -0.2, -0.04), p + Vector3(0.04, 1.0, 0.04), VERMILION)
			if i < n:
				var q := Vector3(xs[i + 2], ys[i + 2], zr)
				pk.tube(kit, "urushi", p + Vector3(0, 1.0, 0), q + Vector3(0, 1.0, 0), 0.045, 0.045, 6, VERMILION, false)
				pk.beam(kit, "urushi", p + Vector3(0, 0.6, 0), q + Vector3(0, 0.6, 0), 0.05, 0.06, VERMILION)
				pk.beam(kit, "urushi", p + Vector3(0, 0.16, 0), q + Vector3(0, 0.16, 0), 0.11, 0.07, VERMILION.darkened(0.08))
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * span * 0.21
		var y: float = rise * (1.0 - pow(2.0 * x / span, 2.0))
		for sz: float in [-1.0, 1.0]:
			pk.tube(kit, "hinoki", Vector3(x, FOOT, sz * (hw - 0.3)), Vector3(x, y - 0.4, sz * (hw - 0.3)), 0.14, 0.13, 8, CEDAR_DARK, false, uvk)
		_bar(pk, kit, "hinoki", Vector3(x, y - 0.6, -hw - 0.1), Vector3(x, y - 0.6, hw + 0.1), 0.18, 0.2, CEDAR_DARK, Vector3.RIGHT)
		_bar(pk, kit, "hinoki", Vector3(x, y * 0.4 - 0.5, -hw + 0.1), Vector3(x, y * 0.4 - 0.5, hw - 0.1), 0.08, 0.14, CEDAR_DARK, Vector3.RIGHT)
		pk.block(kit, "ishi", Vector3(sx * span * 0.5 - 0.65, FOOT, -hw - 0.2), Vector3(sx * span * 0.5 + 0.65, -0.17, hw + 0.2), STONE_B, uvk)


## A mountain-top shrine, centred, its front toward +z, about 5 x 5: a stone-banked platform (0.5 high, down to FOOT)
## with a step, a weathered timber shrine under a roof weighted with stones, a little cedar torii before it, two
## cairns of offering stones, and a summit post whose `text` goes into `labels` letter by letter.
static func summit_shrine(pk: PropKit, kit: Dictionary, labels: Array, text := "") -> void:
	pk.block(kit, "ishi", Vector3(-2.5, FOOT, -2.5), Vector3(2.5, 0.2, 2.5), STONE_B.darkened(0.1), uvk)
	pk.block(kit, "ishi", Vector3(-2.2, 0.19, -2.2), Vector3(2.2, 0.5, 2.2), STONE_A, uvk)
	pk.block(kit, "ishi", Vector3(-0.7, 0.19, 2.2), Vector3(0.7, 0.35, 2.48), STONE_A.lightened(0.05), uvk)
	var old := _push(pk, Transform3D(Basis.from_scale(Vector3.ONE * 1.5), Vector3(0, 0.5, -0.9)))
	hokora(pk, kit)
	for q: Vector3 in [Vector3(-0.3, 1.07, 0.2), Vector3(0.05, 1.03, 0.3), Vector3(0.32, 1.1, 0.14), Vector3(-0.1, 1.14, -0.2), Vector3(0.25, 1.12, -0.22), Vector3(-0.36, 1.16, -0.16)]:
		_ell(pk, kit, "matte", q, Vector3(0.07, 0.04, 0.06), 5, 2, STONE_A.darkened(0.1))
	pk.set_frame(old)
	old = _push(pk, Transform3D(Basis(), Vector3(0, 0.5, 1.35)))
	torii(pk, kit, 2, 1.5, 1.75)
	pk.set_frame(old)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for sx: float in [-1.0, 1.0]:
		old = _push(pk, Transform3D(Basis(), Vector3(sx * 1.55, 0.5, 0.2)))
		cairn(pk, kit, rng, 0.55)
		pk.set_frame(old)
	var pp := Vector3(1.75, 0.5, 1.75)
	_post(pk, kit, "hinoki", pp, -0.5, 1.9, 0.13, HINOKI.darkened(0.2))
	pk.block(kit, "paint", pp + Vector3(-0.055, 0.7, 0.065), pp + Vector3(0.055, 1.8, 0.065 + TP), OFF_WHITE)
	if text != "":
		var cap: float = minf(0.09, 1.0 / float(text.length()) * 0.72)
		var step: float = cap / 0.72
		for i in range(text.length()):
			labels.append([text.substr(i, 1), pp + Vector3(0, 1.25 + step * (float(text.length() - 1) * 0.5 - float(i)), 0.065 + TP + 0.03), Vector3.BACK, cap, INK, 0.1])


## A rack of votive tablets (ema), centred, `w` between its posts, 2.3 high: three rails hung on both sides with rows of
## small wooden tablets, under a little board roof.
static func ema_rack(pk: PropKit, kit: Dictionary, w := 2.4) -> void:
	var wood: Color = HINOKI.darkened(0.25)
	for sx: float in [-1.0, 1.0]:
		_post(pk, kit, "hinoki", Vector3(sx * w * 0.5, 0, 0), -0.6, 2.02, 0.1, wood)
	_bar(pk, kit, "hinoki", Vector3(-w * 0.5 - 0.2, 1.95, 0), Vector3(w * 0.5 + 0.2, 1.95, 0), 0.08, 0.1, wood, Vector3.BACK)
	for sz: float in [-1.0, 1.0]:
		pk.box(kit, "sugi", Transform3D(Basis(Vector3.RIGHT, sz * 0.45), Vector3(0, 2.13, sz * 0.2)), Vector3(w + 0.7, 0.035, 0.5), CEDAR_DARK, uvk)
	pk.tube(kit, "matte", Vector3(-w * 0.5 - 0.37, 2.24, 0), Vector3(w * 0.5 + 0.37, 2.24, 0), 0.035, 0.035, 5, CEDAR_DARK.darkened(0.2), true)
	var cnt: int = maxi(1, int((w - 0.2) / 0.17))
	for j in range(3):
		var y: float = 1.0 + 0.3 * float(j)
		_bar(pk, kit, "hinoki", Vector3(-w * 0.5, y, 0), Vector3(w * 0.5, y, 0), 0.045, 0.045, wood, Vector3.BACK)
		for sz: float in [-1.0, 1.0]:
			for i in range(cnt):
				var x: float = (float(i) - float(cnt - 1) * 0.5) * 0.17 + 0.02 * sin(float(i * 7 + j * 3) * 1.3)
				var tilt: float = 0.14 * sin(float(i * 5 + j * 11) * 2.1 + sz)
				var wf := _pl(Vector3(x, y - 0.03, sz * (0.045 + 0.016 * float(i % 2))), Vector3(0, -0.12, sz)) * Transform3D(Basis(Vector3.BACK, tilt), Vector3.ZERO)
				var tone: float = 0.1 * absf(sin(float(i * 3 + j) * 1.7 + sz))
				_flat(pk, kit, "cloth", wf, PackedVector2Array([Vector2(-0.07, -0.13), Vector2(0.07, -0.13), Vector2(0.07, -0.035), Vector2(0, 0.0), Vector2(-0.07, -0.035)]), 0.0,
						HINOKI.darkened(tone))


## The water-basin pavilion (chozuya), centred, its long side along x: four posts (2.4 x 1.8), a tiled gable roof
## (3.5 x 3.2, ridge 3.05), a stone basin 1.6 x 0.8 with water, ladles on a bamboo rack and a bamboo spout.
static func chozuya(pk: PropKit, kit: Dictionary) -> void:
	var wood: Color = HINOKI.darkened(0.3)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_post(pk, kit, "hinoki", Vector3(sx * 1.2, 0, sz * 0.9), -0.6, 2.3, 0.16, wood)
			pk.block(kit, "ishi", Vector3(sx * 1.2 - 0.16, -0.6, sz * 0.9 - 0.16), Vector3(sx * 1.2 + 0.16, 0.1, sz * 0.9 + 0.16), STONE_A, uvk)
		_bar(pk, kit, "hinoki", Vector3(sx * 1.2, 2.22, -1.25), Vector3(sx * 1.2, 2.22, 1.25), 0.12, 0.16, wood, Vector3.RIGHT)
		_bar(pk, kit, "hinoki", Vector3(-1.5, 2.36, sx * 0.9), Vector3(1.5, 2.36, sx * 0.9), 0.12, 0.14, wood, Vector3.BACK)
		# The gable: a board under the roof's end.
		pk.tri(kit, "matte", Vector3(sx * 1.3, 2.43, -1.15), Vector3(sx * 1.3, 2.43, 1.15), Vector3(sx * 1.3, 2.98, 0), Vector3(sx, 0, 0), Vector3(sx, 0, 0), Vector3(sx, 0, 0),
				SHIKKUI.darkened(0.08), Vector3(sx, 0, 0))
		pk.tri(kit, "matte", Vector3(sx * 1.3, 2.43, -1.15), Vector3(sx * 1.3, 2.43, 1.15), Vector3(sx * 1.3, 2.98, 0), Vector3(-sx, 0, 0), Vector3(-sx, 0, 0), Vector3(-sx, 0, 0),
				wood.darkened(0.3), Vector3(-sx, 0, 0))
	for sz: float in [-1.0, 1.0]:
		roof(pk, kit, "kawara", Vector3(-1.75, 2.3, sz * 1.6), Vector3(1.75, 2.3, sz * 1.6), Vector3(1.75, 3.02, 0), Vector3(-1.75, 3.02, 0), KAWARA, Vector3(0, 0.9, sz * 0.42).normalized())
	pk.tube(kit, "matte", Vector3(-1.85, 3.05, 0), Vector3(1.85, 3.05, 0), 0.1, 0.1, 6, KAWARA_OLD.darkened(0.1), true)
	# The basin: a block with a raised rim round the water.
	pk.block(kit, "ishi", Vector3(-0.8, -0.6, -0.4), Vector3(0.8, 0.55, 0.4), STONE_B, uvk)
	for sx: float in [-1.0, 1.0]:
		pk.block(kit, "matte", Vector3(sx * 0.72 - 0.1, 0.54, -0.42), Vector3(sx * 0.72 + 0.1, 0.66, 0.42), STONE_A)
		pk.block(kit, "matte", Vector3(-0.62, 0.54, sx * 0.33 - 0.09), Vector3(0.62, 0.655, sx * 0.33 + 0.09), STONE_A.darkened(0.04))
		pk.tube(kit, "matte", Vector3(-0.85, 0.7, sx * 0.13), Vector3(0.85, 0.7, sx * 0.13), 0.02, 0.02, 5, BAMBOO_DRY, true)
	pk.quad(kit, "pane", [Vector3(-0.64, 0.62, -0.26), Vector3(0.64, 0.62, -0.26), Vector3(0.64, 0.62, 0.26), Vector3(-0.64, 0.62, 0.26)], Vector3.UP, Color(0.25, 0.42, 0.42))
	for k in range(3):
		var x: float = -0.4 + 0.4 * float(k)
		pk.tube(kit, "matte", Vector3(x, 0.735, -0.32), Vector3(x, 0.735, 0.22), 0.012, 0.012, 4, BAMBOO_DRY.lightened(0.1), false)
		_turn(pk, kit, "matte", Vector3(x, 0.7, 0.26), [Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.045, 0.07), Vector2(0.0, 0.055)], 6, HINOKI)
	pk.tube(kit, "matte", Vector3(0, -0.3, -0.62), Vector3(0, 1.0, -0.62), 0.035, 0.035, 6, BAMBOO.darkened(0.1), true)
	pk.tube(kit, "matte", Vector3(0, 0.93, -0.68), Vector3(0, 0.86, -0.2), 0.025, 0.025, 6, BAMBOO, true)


## A straight flight of `n` mossy granite steps `w` wide climbing toward -z from the origin (the first riser at z 0,
## each tread `run` deep and `rise` higher), with a kerb stone 0.24 wide down either side; every block runs 0.6 under
## the flight's slope. For footpaths beside the road.
static func stone_steps(pk: PropKit, kit: Dictionary, w: float, n: int, rise := 0.17, run := 0.34) -> void:
	var hw: float = w * 0.5
	for k in range(n):
		var top: float = rise * float(k + 1)
		var tone: float = 0.5 + 0.5 * sin(float(k) * 2.3)
		pk.box(kit, "ishi", Transform3D(Basis(), Vector3(0, top - (rise + 0.6) * 0.5, -run * (float(k) + 0.5) - 0.01)), Vector3(w, rise + 0.6, run + 0.02),
				STONE_A.lerp(STONE_B, tone), uvk, true, Vector2(float(k) * 0.37, 0.0))
	var top_z: float = -run * float(n)
	var top_y: float = rise * float(n)
	for sx: float in [-1.0, 1.0]:
		var x0: float = sx * (hw + 0.005)
		var x1: float = sx * (hw + 0.245)
		_loft(pk, kit, "ishi", [[Vector3(x0, 0.13, 0.12), Vector3(x1, 0.13, 0.12), Vector3(x1, -0.6, 0.12), Vector3(x0, -0.6, 0.12)],
				[Vector3(x0, top_y + 0.13, top_z), Vector3(x1, top_y + 0.13, top_z), Vector3(x1, top_y - 0.6, top_z), Vector3(x0, top_y - 0.6, top_z)]], STONE_B, true, true, 1)


## A shrine's grand stairway (ishidan) of `n` granite treads `w` wide climbing toward -z from the origin (the first
## riser at z 0), each a solid block down to FOOT, so it stands on a slope or out from a terrace's wall whatever the
## ground under it does; cheek walls either side whose coping runs with the nosings 0.4 over them, a landing slab at
## the top (`landing` deep). Its head is at z = -run * n - landing, y = rise * n.
static func grand_stairs(pk: PropKit, kit: Dictionary, w: float, n: int, rise := 0.17, run := 0.34, landing := 1.2) -> void:
	var hw: float = w * 0.5
	for k in range(n):
		var top: float = rise * float(k + 1)
		var tone: float = 0.5 + 0.5 * sin(float(k) * 2.3)
		var z0: float = -run * float(k)
		var z1: float = -run * float(k + 1) - (landing if k == n - 1 else 0.0)
		pk.box(kit, "ishi", Transform3D(Basis(), Vector3(0, (top + FOOT) * 0.5, (z0 + z1) * 0.5 - 0.01)), Vector3(w, top - FOOT, z0 - z1 + 0.02),
				STONE_A.lerp(STONE_B, tone), uvk, true, Vector2(float(k) * 0.37, 0.0))
	var top_z: float = -run * float(n)
	var top_y: float = rise * float(n)
	var end_z: float = top_z - landing
	var cw := 0.45
	for sx: float in [-1.0, 1.0]:
		var x0: float = sx * (hw + 0.005)
		var x1: float = sx * (hw + cw)
		# The cheek wall: a sloping coping over a solid wall down to FOOT, level along the landing.
		# The outline in (z, y).
		var ol := PackedVector2Array([Vector2(0.25, FOOT), Vector2(end_z, FOOT), Vector2(end_z, top_y + 0.4), Vector2(top_z, top_y + 0.4), Vector2(0.25, 0.42)])
		var ccw: bool = PropKit._signed_area(ol) > 0.0
		for i in range(ol.size()):
			var a2: Vector2 = ol[i]
			var b2: Vector2 = ol[(i + 1) % ol.size()]
			var e: Vector2 = b2 - a2
			var o2: Vector2 = (Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)).normalized()
			pk.quad(kit, "ishi", [Vector3(x0, a2.y, a2.x), Vector3(x0, b2.y, b2.x), Vector3(x1, b2.y, b2.x), Vector3(x1, a2.y, a2.x)],
					Vector3(0, o2.y, o2.x), STONE_B.darkened(0.05),
					[Vector2(0.0, 0.0), Vector2(e.length(), 0.0) * uvk, Vector2(e.length(), cw) * uvk, Vector2(0.0, cw) * uvk])
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(ol)
		for i in range(0, tris.size(), 3):
			for xx in [x0, x1]:
				var nrm := Vector3(sx if xx == x1 else -sx, 0, 0)
				var pa: Vector2 = ol[tris[i]]
				var pb: Vector2 = ol[tris[i + 1]]
				var pc: Vector2 = ol[tris[i + 2]]
				pk.tri(kit, "ishi", Vector3(xx, pa.y, pa.x), Vector3(xx, pb.y, pb.x), Vector3(xx, pc.y, pc.x), nrm, nrm, nrm, STONE_B.darkened(0.08), nrm,
						Vector2(pa.x, pa.y) * uvk, Vector2(pb.x, pb.y) * uvk, Vector2(pc.x, pc.y) * uvk)


## The little white farm pickup (kei truck), centred, its nose toward -z: 3.4 long, 1.48 wide, 1.75 high; a cab-over
## cab, a flat bed with drop sides behind a guard frame, small wheels, a yellow plate.
static func kei_truck(pk: PropKit, kit: Dictionary, col := Color(0.93, 0.93, 0.90)) -> void:
	# Built along x (the nose at +x) and turned: x -> -z, z -> x.
	var old := _push(pk, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	var hw := 0.74
	var dark := Color(0.12, 0.12, 0.13)
	var glass := Color(0.1, 0.13, 0.16)
	pk.block(kit, "matte", Vector3(-1.6, 0.3, -0.55), Vector3(1.55, 0.6, 0.55), dark)
	pk.extrude(kit, "gloss", PackedVector2Array([Vector2(0.55, 0.42), Vector2(1.68, 0.42), Vector2(1.7, 0.95), Vector2(1.6, 1.08), Vector2(1.36, 1.72), Vector2(0.58, 1.75), Vector2(0.55, 1.7)]),
			-hw, hw, 0.04, col)
	# Windscreen, side and rear windows, lamps, bumper, plate.
	var wn := Vector3(0.67, 0.24, 0).normalized()
	var w0 := Vector3(1.585, 1.12, 0) + wn * 0.02
	var w1 := Vector3(1.385, 1.66, 0) + wn * 0.02
	pk.quad(kit, "pane", [w0 + Vector3(0, 0, -0.64), w0 + Vector3(0, 0, 0.64), w1 + Vector3(0, 0, 0.64), w1 + Vector3(0, 0, -0.64)], wn, glass)
	for sz: float in [-1.0, 1.0]:
		pk.quad(kit, "pane", [Vector3(0.72, 1.12, sz * (hw + 0.02)), Vector3(1.46, 1.12, sz * (hw + 0.02)), Vector3(1.3, 1.62, sz * (hw + 0.02)), Vector3(0.72, 1.62, sz * (hw + 0.02))],
				Vector3(0, 0, sz), glass)
		pk.block(kit, "matte", Vector3(1.0, 0.86, sz * (hw + 0.02) - 0.01), Vector3(1.12, 0.9, sz * (hw + 0.02) + 0.02), dark)
		pk.quad(kit, "gloss", [Vector3(1.72, 0.74, sz * 0.52 - 0.11), Vector3(1.72, 0.74, sz * 0.52 + 0.11), Vector3(1.72, 0.9, sz * 0.52 + 0.11), Vector3(1.72, 0.9, sz * 0.52 - 0.11)],
				Vector3.RIGHT, Color(0.95, 0.95, 0.85))
		pk.block(kit, "matte", Vector3(1.36, 1.3, sz * (hw + 0.03)), Vector3(1.44, 1.5, sz * (hw + 0.16)), dark)
		for wx: float in [1.15, -1.05]:
			var c := Vector3(wx, 0.27, sz * (hw - 0.09))
			pk.tube(kit, "matte", c - Vector3(0, 0, 0.08), c + Vector3(0, 0, 0.08), 0.27, 0.27, 10, Color(0.07, 0.07, 0.08), true)
			_disc(pk, kit, "metal", _pl(c + Vector3(0, 0, sz * 0.08), Vector3(0, 0, sz)), Vector2.ZERO, 0.15, 8, 0.012, GALV)
	pk.quad(kit, "pane", [Vector3(0.53, 1.2, -0.5), Vector3(0.53, 1.2, 0.5), Vector3(0.53, 1.6, 0.5), Vector3(0.53, 1.6, -0.5)], Vector3.LEFT, glass)
	pk.block(kit, "matte", Vector3(1.66, 0.4, -hw + 0.02), Vector3(1.76, 0.56, hw - 0.02), dark)
	pk.quad(kit, "paint", [Vector3(1.775, 0.42, -0.17), Vector3(1.775, 0.42, 0.17), Vector3(1.775, 0.54, 0.17), Vector3(1.775, 0.54, -0.17)], Vector3.RIGHT, SIGN_YELLOW)
	# The bed: a floor, three drop sides, the guard frame behind the cab.
	pk.block(kit, "gloss", Vector3(-1.7, 0.6, -hw), Vector3(0.5, 0.68, hw), col.darkened(0.06))
	for sz: float in [-1.0, 1.0]:
		pk.block(kit, "gloss", Vector3(-1.7, 0.67, sz * hw - 0.02), Vector3(0.5, 0.96, sz * hw + 0.02), col)
		pk.block(kit, "matte", Vector3(-1.705, 0.8, sz * hw - 0.028), Vector3(0.505, 0.83, sz * hw + 0.028), col.darkened(0.25))
		pk.block(kit, "metal", Vector3(0.44, 0.67, sz * (hw - 0.06) - 0.02), Vector3(0.48, 1.7, sz * (hw - 0.06) + 0.02), dark)
		pk.quad(kit, "gloss", [Vector3(-1.725, 0.72, sz * 0.55 - 0.08), Vector3(-1.725, 0.72, sz * 0.55 + 0.08), Vector3(-1.725, 0.86, sz * 0.55 + 0.08), Vector3(-1.725, 0.86, sz * 0.55 - 0.08)],
				Vector3.LEFT, Color(0.75, 0.1, 0.08))
	pk.block(kit, "gloss", Vector3(-1.71, 0.67, -hw + 0.02), Vector3(-1.67, 0.96, hw - 0.02), col)
	pk.block(kit, "metal", Vector3(0.44, 1.66, -hw + 0.06), Vector3(0.48, 1.7, hw - 0.06), dark)
	pk.set_frame(old)


## A tall-box kei car (a "kei wagon", the little upright city car), centred, its nose toward -z: 3.4 long, 1.48 wide,
## 1.75 high; a short sloping nose, a tall glasshouse with near-upright pillars, a flat roof, sliding rear doors' rails,
## small wheels. `two_tone`: a white roof over the colour.
static func kei_car(pk: PropKit, kit: Dictionary, col := Color(0.82, 0.86, 0.90), two_tone := false) -> void:
	var old := _push(pk, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	var hw := 0.74
	var dark := Color(0.12, 0.12, 0.13)
	var glass := Color(0.09, 0.12, 0.15)
	var roof_col: Color = Color(0.94, 0.94, 0.92) if two_tone else col
	# The body below the windows: a short nose, upright flanks, a square tail; the roof over the glasshouse.
	pk.extrude(kit, "gloss", PackedVector2Array([Vector2(-1.7, 0.32), Vector2(1.6, 0.32), Vector2(1.7, 0.5), Vector2(1.7, 0.82), Vector2(1.28, 1.0), Vector2(-1.68, 1.0), Vector2(-1.7, 0.8)]),
			-hw, hw, 0.04, col)
	pk.extrude(kit, "gloss", PackedVector2Array([Vector2(-1.66, 1.62), Vector2(0.9, 1.62), Vector2(0.96, 1.75), Vector2(-1.62, 1.75)]), -hw + 0.04, hw - 0.04, 0.03, roof_col)
	pk.block(kit, "matte", Vector3(-1.72, 0.22, -hw + 0.06), Vector3(1.72, 0.36, hw - 0.06), dark)
	# Pillars, with the glass between them standing in a little.
	for sz: float in [-1.0, 1.0]:
		var zz: float = sz * (hw - 0.05)
		for px in [-1.62, -0.36, 0.42]:
			pk.block(kit, "gloss", Vector3(px - 0.04, 1.0, zz - 0.04), Vector3(px + 0.04, 1.63, zz + 0.04), roof_col if two_tone else col)
		pk.quad(kit, "pane", [Vector3(-1.58, 1.04, sz * (hw - 0.03)), Vector3(1.2, 1.04, sz * (hw - 0.03)), Vector3(0.9, 1.6, sz * (hw - 0.03)), Vector3(-1.58, 1.6, sz * (hw - 0.03))],
				Vector3(0, 0, sz), glass)
		# The sliding door's rail, the mirror, the handles.
		pk.block(kit, "matte", Vector3(-1.4, 0.98, sz * hw - 0.01), Vector3(-0.4, 1.0, sz * hw + 0.015), dark)
		pk.block(kit, "matte", Vector3(1.0, 1.02, sz * (hw + 0.02)), Vector3(1.1, 1.14, sz * (hw + 0.12)), dark)
		for hx in [-0.5, 0.35]:
			pk.block(kit, "matte", Vector3(hx, 0.86, sz * hw), Vector3(hx + 0.14, 0.89, sz * (hw + 0.015)), dark)
		# Wheels.
		for wx: float in [1.12, -1.15]:
			var c := Vector3(wx, 0.28, sz * (hw - 0.1))
			pk.tube(kit, "matte", c - Vector3(0, 0, 0.09), c + Vector3(0, 0, 0.09), 0.28, 0.28, 10, Color(0.07, 0.07, 0.08), true)
			_disc(pk, kit, "metal", _pl(c + Vector3(0, 0, sz * 0.09), Vector3(0, 0, sz)), Vector2.ZERO, 0.17, 8, 0.012, GALV)
		# Lamps: the headlamps round the nose's corners, tall tail lamps.
		pk.quad(kit, "gloss", [Vector3(1.55, 0.82, sz * 0.5 - 0.15), Vector3(1.55, 0.82, sz * 0.5 + 0.15), Vector3(1.3, 0.97, sz * 0.5 + 0.15), Vector3(1.3, 0.97, sz * 0.5 - 0.15)],
				Vector3(0.6, 1.0, 0).normalized(), Color(0.95, 0.95, 0.88))
		pk.quad(kit, "gloss", [Vector3(-1.705, 0.62, sz * 0.62 - 0.07), Vector3(-1.705, 0.62, sz * 0.62 + 0.07), Vector3(-1.705, 1.2, sz * 0.62 + 0.07), Vector3(-1.705, 1.2, sz * 0.62 - 0.07)],
				Vector3.LEFT, Color(0.80, 0.10, 0.08))
	# The windscreen, steep, and the rear window.
	var wn := Vector3(0.88, 0.48, 0).normalized()
	pk.quad(kit, "pane", [Vector3(1.26, 1.02, -0.66) + wn * 0.02, Vector3(1.26, 1.02, 0.66) + wn * 0.02, Vector3(0.94, 1.6, 0.66) + wn * 0.02, Vector3(0.94, 1.6, -0.66) + wn * 0.02], wn, glass)
	pk.quad(kit, "pane", [Vector3(-1.71, 1.06, -0.6), Vector3(-1.71, 1.06, 0.6), Vector3(-1.71, 1.56, 0.6), Vector3(-1.71, 1.56, -0.6)], Vector3.LEFT, glass)
	# Grille, plates, bumpers.
	pk.block(kit, "matte", Vector3(1.68, 0.4, -0.45), Vector3(1.73, 0.6, 0.45), dark)
	pk.quad(kit, "paint", [Vector3(1.745, 0.42, -0.17), Vector3(1.745, 0.42, 0.17), Vector3(1.745, 0.54, 0.17), Vector3(1.745, 0.54, -0.17)], Vector3.RIGHT, SIGN_YELLOW)
	pk.quad(kit, "paint", [Vector3(-1.725, 0.42, -0.17), Vector3(-1.725, 0.42, 0.17), Vector3(-1.725, 0.54, 0.17), Vector3(-1.725, 0.54, -0.17)], Vector3.LEFT, SIGN_YELLOW)
	pk.set_frame(old)


# ======================================================================================
#  Koinobori: the carp streamers of Children's Day
# ======================================================================================

## The carps' colours: the black father (magoi), the red mother (higoi), then the children (blue, green, orange, pink).
const KOI_BLACK := Color(0.07, 0.07, 0.08)
const KOI_RED := Color(0.86, 0.12, 0.08)
const KOI_KIDS := [Color(0.12, 0.32, 0.82), Color(0.10, 0.58, 0.30), Color(0.96, 0.52, 0.10), Color(0.95, 0.45, 0.62)]


## The "koi" surface: its SurfaceTool carries CUSTOM0 (the sway axis, the phase, the length) for koinobori.gdshader.
static func _koi_st(kit: Dictionary) -> SurfaceTool:
	if not kit.has("koi"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		kit["koi"] = st
	return kit["koi"]


## One carp (or, `streamer`, the five-coloured fukinagashi) as an open tube in the kit's frame: its mouth's middle at
## `mouth`, its body trailing along `wind` (level, local), `length` long, `r` at its widest, sagging a little toward the
## tail. 18 rings of 12. The hoop at its mouth is a thin ring of metal.
static func koinobori_carp(pk: PropKit, kit: Dictionary, mouth: Vector3, wind: Vector3, length: float, r: float, col: Color,
		phase: float, streamer := false) -> void:
	var st := _koi_st(kit)
	var ax: Vector3 = Vector3(wind.x, 0.0, wind.z).normalized()
	var side: Vector3 = Vector3.UP.cross(ax).normalized()
	var rings := 18
	var segs := 12
	# Its sway axis and length as the shader sees them (world, after the frame).
	var w_side: Vector3 = pk.xf.basis * side
	w_side.y = 0.0
	w_side = w_side.normalized()
	var scale: float = (pk.xf.basis * ax).length()
	var custom := Color(w_side.x, w_side.z, phase, length * scale)
	var pts: Array = []
	var nrm: Array = []
	var uvs: Array = []
	for i in range(rings + 1):
		var u: float = float(i) / float(rings)
		var rad: float
		var ry: float
		var rz: float
		if streamer:
			rad = r * (1.0 - 0.25 * u)
			ry = rad
			rz = rad
		else:
			# Full in the body, narrowing behind it, the tail flattened upright into a fan.
			rad = r * (0.86 + 0.18 * sin(minf(u / 0.55, 1.0) * PI * 0.5)) * (1.0 - 0.5 * smoothstep(0.5, 0.88, u))
			var flat: float = smoothstep(0.78, 1.0, u)
			ry = rad * (1.0 + 0.9 * flat)
			rz = rad * (1.0 - 0.8 * flat)
		var c: Vector3 = mouth + ax * (u * length) - Vector3.UP * (0.06 * length * u * u)
		for k in range(segs + 1):
			var v: float = float(k) / float(segs)
			var a: float = v * TAU
			# v 0 on the back (up), 0.5 under the belly.
			var off: Vector3 = Vector3.UP * cos(a) * ry + side * sin(a) * rz
			pts.append(c + off)
			nrm.append((Vector3.UP * cos(a) / maxf(ry, 0.01) + side * sin(a) / maxf(rz, 0.01)).normalized())
			uvs.append(Vector2(u, v))
	var col_a := Color(col.r, col.g, col.b, 1.0 if streamer else 0.0)
	var nb: Basis = pk.xf.basis.inverse().transposed()
	for i in range(rings):
		for k in range(segs):
			var i0: int = i * (segs + 1) + k
			var i1: int = i0 + 1
			var i2: int = i0 + segs + 1
			var i3: int = i2 + 1
			for tri in [[i0, i2, i1], [i1, i2, i3]]:
				var wa: Vector3 = pk.xf * (pts[tri[0]] as Vector3)
				var wb: Vector3 = pk.xf * (pts[tri[1]] as Vector3)
				var wc: Vector3 = pk.xf * (pts[tri[2]] as Vector3)
				var out: Vector3 = (nb * ((nrm[tri[0]] as Vector3) + (nrm[tri[1]] as Vector3) + (nrm[tri[2]] as Vector3))).normalized()
				var order: Array = tri
				# Front face outward: (c - a) x (b - a) along the outward normal.
				if (wc - wa).cross(wb - wa).dot(out) < 0.0:
					order = [tri[0], tri[2], tri[1]]
				for j in order:
					st.set_color(col_a)
					st.set_normal((nb * (nrm[j] as Vector3)).normalized())
					st.set_uv(uvs[j])
					st.set_custom(0, custom)
					st.add_vertex(pk.xf * (pts[j] as Vector3))
	# The hoop round its mouth.
	var hoop: Array = []
	for k in range(segs + 1):
		var a2: float = float(k) / float(segs) * TAU
		hoop.append(mouth + Vector3.UP * cos(a2) * r * 0.86 + side * sin(a2) * r * 0.86)
	_strand(pk, kit, "metal", hoop, 0.012, 4, GOLD.darkened(0.2))


## A koinobori pole (life size, its foot at the origin): a tall pole `h` high with a gilt ball and an arrow wheel
## (yaguruma) on top, the five-coloured streamer under it, then the black carp, the red carp and `kids` children, all
## streaming along `wind` (level, local) off a short arm, the halyard down the pole, three guy ropes to stakes, a stone
## foot. The carps' sizes go down the pole; their phases come from `rng`.
static func koinobori_pole(pk: PropKit, kit: Dictionary, h := 9.0, kids := 2, wind := Vector3(1, 0, 0), rng: RandomNumberGenerator = null) -> void:
	var r0: float = rng.randf() * TAU if rng else 0.0
	var ax: Vector3 = Vector3(wind.x, 0.0, wind.z).normalized()
	var side: Vector3 = Vector3.UP.cross(ax).normalized()
	# The pole: a stone foot, a tapering painted pole, a gilt ball.
	pk.block(kit, "ishi", Vector3(-0.45, -0.6, -0.45), Vector3(0.45, 0.25, 0.45), GRANITE)
	pk.tube(kit, "painted", Vector3(0, 0.2, 0), Vector3(0, h, 0), 0.09, 0.05, 8, Color(0.92, 0.92, 0.88))
	pk.lathe(kit, "gold", Vector3(0, h, 0), [Vector2(0.0, 0.0), Vector2(0.12, 0.08), Vector2(0.14, 0.2), Vector2(0.1, 0.32), Vector2(0.0, 0.36)], 10, GOLD)
	# The arrow wheel: eight arrows round a hub, in two crossed wheels, just under the ball.
	var hub := Vector3(0, h - 0.25, 0)
	for wheel in range(2):
		var plane_a: Vector3 = ax if wheel == 0 else side
		for k in range(8):
			var a: float = float(k) / 8.0 * TAU + r0
			var d: Vector3 = (Vector3.UP * cos(a) + plane_a * sin(a))
			pk.tube(kit, "painted", hub + d * 0.06, hub + d * 0.55, 0.012, 0.012, 4, Color(0.95, 0.95, 0.92))
			pk.tube(kit, "urushi", hub + d * 0.42, hub + d * 0.6, 0.035, 0.0, 4, VERMILION if k % 2 == 0 else Color(0.15, 0.3, 0.75))
	pk.lathe(kit, "gold", hub - Vector3(0, 0.05, 0), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.1), Vector2(0.0, 0.1)], 8, GOLD)
	# The streamer and the carps, each off a short arm of the pole.
	var y: float = h - 0.85
	var fams: Array = [[true, 4.0, 0.36, Color(1, 1, 1)], [false, 3.8, 0.52, KOI_BLACK], [false, 3.2, 0.45, KOI_RED]]
	for k in range(kids):
		fams.append([false, 2.6 - 0.35 * float(k), 0.37 - 0.04 * float(k), KOI_KIDS[k % KOI_KIDS.size()]])
	var ph := 0.0
	for f in fams:
		var rr: float = f[2]
		var mouth: Vector3 = Vector3(0, y - rr, 0) + ax * (0.22 + rr * 0.86)
		pk.tube(kit, "metal", Vector3(0, y, 0), Vector3(0, y, 0) + ax * 0.24, 0.015, 0.015, 4, GOLD.darkened(0.3))
		koinobori_carp(pk, kit, mouth, ax, f[1], rr, f[3], ph + (rng.randf() * 0.6 if rng else 0.0), f[0])
		ph += 0.9
		y -= rr * 2.0 + 0.55
	# The halyard down the pole, guy ropes to three stakes.
	pk.tube(kit, "rope", Vector3(0.1, 0.9, 0), Vector3(0.07, h - 0.6, 0), 0.008, 0.008, 3, STRAW.darkened(0.2))
	for k in range(3):
		var a2: float = float(k) / 3.0 * TAU + 0.5
		var stake := Vector3(cos(a2) * h * 0.42, 0.0, sin(a2) * h * 0.42)
		pk.tube(kit, "rope", Vector3(0, h * 0.62, 0), stake + Vector3(0, 0.25, 0), 0.01, 0.01, 3, STRAW.darkened(0.25))
		pk.tube(kit, "timber", stake + Vector3(0, -0.5, 0), stake + Vector3(0, 0.35, 0), 0.04, 0.035, 5, CEDAR)


## A line of koinobori on a rope between two masts, as hung across a river: masts at `a` and `b` (their feet, life
## size, local), the rope from their tops sagging `sag`, `n` carps hanging off it by short cords, streaming along `wind`.
static func koinobori_line(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, n: int, wind := Vector3(1, 0, 0), sag := 1.4,
		rng: RandomNumberGenerator = null, mast_h := 10.0) -> void:
	var ax: Vector3 = Vector3(wind.x, 0.0, wind.z).normalized()
	var top_a: Vector3 = a + Vector3(0, mast_h, 0)
	var top_b: Vector3 = b + Vector3(0, mast_h, 0)
	for m in [a, b]:
		pk.block(kit, "ishi", m + Vector3(-0.4, -0.6, -0.4), m + Vector3(0.4, 0.2, 0.4), GRANITE)
		pk.tube(kit, "timber", m + Vector3(0, -0.6, 0), m + Vector3(0, mast_h + 0.3, 0), 0.13, 0.09, 8, CEDAR)
		# A guy rope back from each mast, away from the line.
		var away: Vector3 = (m - (b if m == a else a))
		away.y = 0.0
		away = away.normalized()
		pk.tube(kit, "rope", m + Vector3(0, mast_h * 0.9, 0), m + away * mast_h * 0.5 + Vector3(0, 0.2, 0), 0.012, 0.012, 3, STRAW.darkened(0.25))
		pk.tube(kit, "timber", m + away * mast_h * 0.5 + Vector3(0, -0.5, 0), m + away * mast_h * 0.5 + Vector3(0, 0.35, 0), 0.05, 0.04, 5, CEDAR)
	var rope: Array = _sag(top_a, top_b, sag, 24)
	_strand(pk, kit, "rope", rope, 0.016, 4, STRAW.darkened(0.2))
	var cols: Array = [KOI_BLACK, KOI_RED] + KOI_KIDS
	for i in range(n):
		var t: float = (float(i) + 0.5) / float(n)
		var p: Vector3 = top_a.lerp(top_b, t) - Vector3.UP * (sag * 4.0 * t * (1.0 - t))
		var length: float = 3.2 + (rng.randf_range(-0.4, 0.5) if rng else 0.0)
		var rr: float = length * 0.14
		var mouth: Vector3 = p - Vector3(0, 0.25 + rr, 0) + ax * rr * 0.86
		pk.tube(kit, "rope", p, mouth + Vector3(0, rr * 0.86, 0) - ax * rr * 0.86, 0.008, 0.008, 3, STRAW.darkened(0.2))
		var col: Color = cols[(i + (rng.randi_range(0, 5) if rng else 0)) % cols.size()]
		koinobori_carp(pk, kit, mouth, ax, length, rr, col, (rng.randf() * TAU) if rng else float(i) * 0.7)
