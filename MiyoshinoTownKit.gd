extends "res://MiyoshinoKit.gd"
## The Miyoshino GP's buildings (the stage generators call these): the temple town's wooden townhouses (machiya), its
## temple (the great gate the race drives through, the main hall, the pagoda, the bell tower, the walls and their gates),
## the tea house of the mountain viewpoint, the festival's food stalls, a small Shinto hall, a farmhouse and the
## pilgrims' lodge of the mountain trail.
##
## Built at life size through MiyoshinoKit's materials and grown by the generators' PROP_SCALE (1.6): `new_kit(scale)`,
## set the frame, call a builder, `MiyoshinoTownKit.commit(pk, kit)` (it adds the tangents "hiwada" needs to the base's).
##
## Frames. Houses: the street front in the plane z = 0 facing +z, x from 0 to w along the street, the back at z = -d,
## y = 0 the ground at the front; footings run down to FOOT (-3) so a house on a slope never floats. Monuments are centred
## on the origin (the main hall and the Shinto hall: x centred, the front at z = 0).
##
## The builders (life size):
##   machiya(pk, kit, w, d, floors, variant, rng, labels)  variants 0 dwelling, 1 shop, 2 sake brewery, 3 ryokan, 4 sweet
##                                    shop, 5 kura; machiya_extent(variant): how far it reaches past z = 0; machiya_default
##   great_gate(pk, kit, labels)      the Niomon, centred, the road along z; nothing in |x| < 4.3 under y = 6.6
##   main_hall(pk, kit, labels)       the hondo: podium front z = 0, x centred, back -18.6; steps to +3.2, the burner +6..+8
##   pagoda(pk, kit, tiers := 3)      centred, 6.4m square body on a podium
##   temple_wall(pk, kit, a, b, h := 2.3, detail := true), wall_gate(pk, kit, w := 3.2, labels := [])
##   chaya(pk, kit, labels)           front z = 0, x 0..9, 5.5 deep
##   yatai(pk, kit, variant, rng, labels)  front z = 0, x 0..2.7, 1.8 deep
##   bell_tower(pk, kit), shrine_hall(pk, kit, labels), kominka(pk, kit, w, d, rng), mountain_hut(pk, kit, labels)
##   sakura_crest(pk, kit, key, c, out, r, col), chochin(pk, kit, c, r, h, col, ...)
##
## The roofs are one helper, `jroof(pk, kit, spec)` over a `roof_spec(kind, c, hx, hz, rise, key, col)`: gabled
## (R_KIRIZUMA), hipped (R_YOSEMUNE), hip-and-gable (R_IRIMOYA), pyramidal (R_HOGYO) and a lean-to (R_PENT), each slope a
## curved grid (the profile sags, `sori`; the eave line turns up to the corners, `lift`) with its underside, the eave's
## edge with round end tiles on the tile ribs, bargeboards and a pendant on the verges, a ridge of stacked tiles with
## onigawara, corner ridges, and rafters under the eaves. `roof_y(spec, p)` is the roof's top over a point.
##
## No writing: the project has no CJK font. Shop names go into `labels` in romaji capitals ([text, position, outward
## normal, cap height, colour, board width], life size in the building's frame); the cup's emblem, a five-petal cherry
## blossom, is geometry (`sakura_crest`) on the noren, lanterns and gables. Lit paper (lanterns, shoji) is "washi".
## Faces never share a plane: trim stands TP proud, panes 2cm, parts are cut to each other.

const MBase = preload("res://MiyoshinoKit.gd")

const R_KIRIZUMA := 0
const R_YOSEMUNE := 1
const R_IRIMOYA := 2
const R_HOGYO := 3
const R_PENT := 4

const DARK := Color(0.055, 0.05, 0.05)            # what lies behind a lattice
const WOODS := [Color(0.23, 0.16, 0.12), Color(0.30, 0.20, 0.14), Color(0.34, 0.17, 0.12), Color(0.17, 0.13, 0.11), Color(0.38, 0.27, 0.19)]
const PLASTERS := [Color(0.95, 0.94, 0.90), Color(0.86, 0.78, 0.62), Color(0.90, 0.88, 0.82), Color(0.80, 0.68, 0.50), Color(0.72, 0.70, 0.66)]
const RENJI_GREEN := Color(0.16, 0.36, 0.27)
const FELT_RED := Color(0.80, 0.10, 0.08)
const WHITE_END := Color(0.93, 0.90, 0.80)       # the painted ends of temple rafters
const SHOP_NAMES := ["MIYAGE", "SOBA", "KUZU", "UDON", "WASHI", "TOFU", "HASHI"]
const SWEET_NAMES := ["CHAYA", "DANGO", "MOCHI", "KANMI"]
const INN_NAMES := ["RYOKAN HANAMINE", "RYOKAN SAKURAYA", "YADO YOSHINO", "RYOKAN KINPU"]


## MiyoshinoKit.commit, with tangents on "hiwada" too (hut_thatch reads a normal map).
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	if kit.has("hiwada"):
		var s: SurfaceTool = kit["hiwada"]
		s.index()
		s.generate_tangents()
	return MBase.commit(pk, kit)


# ======================================================================================
#  Helpers in a wall's frame
# ======================================================================================

## A wall's frame: x along the wall (u), y up (v), z out of it; `o` the wall's foot at u = 0.
static func _wf(o: Vector3, out: Vector3) -> Transform3D:
	var u: Vector3 = Vector3.UP.cross(out).normalized()
	return Transform3D(Basis(u, Vector3.UP, out), o)


## A flat face [u0, u1] x [v0, v1] at depth d, facing out of the wall, UVs (u, v) in metres.
static func _face(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, d: float, col: Color) -> void:
	if u1 - u0 < 1e-4 or v1 - v0 < 1e-4:
		return
	var n: Vector3 = wf.basis.z.normalized()
	pk.quad(kit, key, [wf * Vector3(u0, v0, d), wf * Vector3(u1, v0, d), wf * Vector3(u1, v1, d), wf * Vector3(u0, v1, d)], n, col,
			[Vector2(u0, v0) * uvk, Vector2(u1, v0) * uvk, Vector2(u1, v1) * uvk, Vector2(u0, v1) * uvk])


## A rectangle [u0, u1] x [v0, v1] standing from d0 to d1 off a wall: its front and its four edges (and its back).
## Squared timber's grain runs along the longer side.
static func _rect(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, d0: float, d1: float,
		col: Color, back := false) -> void:
	if u1 - u0 < 1e-4 or v1 - v0 < 1e-4:
		return
	var n: Vector3 = wf.basis.z.normalized()
	var nu: Vector3 = wf.basis.x.normalized()
	var p: Array = [wf * Vector3(u0, v0, d1), wf * Vector3(u1, v0, d1), wf * Vector3(u1, v1, d1), wf * Vector3(u0, v1, d1)]
	var b: Array = [wf * Vector3(u0, v0, d0), wf * Vector3(u1, v0, d0), wf * Vector3(u1, v1, d0), wf * Vector3(u0, v1, d0)]
	var lying: bool = (key == "hinoki" or key == "timber") and (u1 - u0) > (v1 - v0)
	var uv: Array = [Vector2(u0, v0) * uvk, Vector2(u1, v0) * uvk, Vector2(u1, v1) * uvk, Vector2(u0, v1) * uvk]
	if lying:
		uv = [Vector2(v0, u0) * uvk, Vector2(v0, u1) * uvk, Vector2(v1, u1) * uvk, Vector2(v1, u0) * uvk]
	pk.quad(kit, key, p, n, col, uv)
	if back:
		pk.quad(kit, key, [b[1], b[0], b[3], b[2]], -n, col, [uv[1], uv[0], uv[3], uv[2]])
	var dd: float = (d1 - d0) * uvk
	var side: Color = col.darkened(0.12)
	# Edges: u along the edge for a lying timber (its grain), else v.
	var lu: float = (u1 - u0) * uvk
	var lv: float = (v1 - v0) * uvk
	pk.quad(kit, key, [b[0], b[1], p[1], p[0]], Vector3.DOWN, side, [Vector2(0, 0), Vector2(0, lu), Vector2(dd, lu), Vector2(dd, 0)])
	pk.quad(kit, key, [b[3], p[3], p[2], b[2]], Vector3.UP, side, [Vector2(0, 0), Vector2(dd, 0), Vector2(dd, lu), Vector2(0, lu)])
	pk.quad(kit, key, [b[0], p[0], p[3], b[3]], -nu, side, [Vector2(0, 0), Vector2(dd, 0), Vector2(dd, lv), Vector2(0, lv)])
	pk.quad(kit, key, [b[1], b[2], p[2], p[1]], nu, side, [Vector2(0, 0), Vector2(0, lv), Vector2(dd, lv), Vector2(dd, 0)])


## An outline in a frame's x-y plane extruded along its z from d0 to d1: the face at d1 (and at d0 with `back`) and the rim.
static func _prism(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, ol: PackedVector2Array, d0: float, d1: float, col: Color,
		back := false, rim := true) -> void:
	var n := ol.size()
	if n < 3:
		return
	var area: float = PropKit._signed_area(ol)
	if absf(area) < 1e-7:
		return
	var ccw := area > 0.0
	var tris := Geometry2D.triangulate_polygon(ol)
	var nf: Vector3 = wf.basis.z.normalized()
	for i in range(0, tris.size(), 3):
		var a: Vector2 = ol[tris[i]]
		var b: Vector2 = ol[tris[i + 1]]
		var c: Vector2 = ol[tris[i + 2]]
		pk.tri(kit, key, wf * Vector3(a.x, a.y, d1), wf * Vector3(b.x, b.y, d1), wf * Vector3(c.x, c.y, d1), nf, nf, nf, col, nf, a * uvk, b * uvk, c * uvk)
		if back:
			pk.tri(kit, key, wf * Vector3(a.x, a.y, d0), wf * Vector3(b.x, b.y, d0), wf * Vector3(c.x, c.y, d0), -nf, -nf, -nf, col, -nf, a * uvk, b * uvk, c * uvk)
	if not rim:
		return
	var run := 0.0
	var dd: float = d1 - d0
	for i in range(n):
		var p: Vector2 = ol[i]
		var q: Vector2 = ol[(i + 1) % n]
		var e: Vector2 = q - p
		var el: float = e.length()
		if el < 1e-6:
			continue
		var o2: Vector2 = (Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)) / el
		var o3: Vector3 = (wf.basis * Vector3(o2.x, o2.y, 0.0)).normalized()
		pk.quad(kit, key, [wf * Vector3(p.x, p.y, d0), wf * Vector3(q.x, q.y, d0), wf * Vector3(q.x, q.y, d1), wf * Vector3(p.x, p.y, d1)], o3, col.darkened(0.1),
				[Vector2(0.0, run) * uvk, Vector2(0.0, run + el) * uvk, Vector2(dd, run + el) * uvk, Vector2(dd, run) * uvk])
		run += el


## `n` upright bars `bw` wide spread evenly over [u0, u1], from v0 to v1, standing d0..d1 off the wall: fronts and sides.
static func _bars(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, u1: float, v0: float, v1: float, n: int, bw: float,
		d0: float, d1: float, col: Color) -> void:
	if n <= 0 or v1 - v0 < 1e-4:
		return
	var nf: Vector3 = wf.basis.z.normalized()
	var nu: Vector3 = wf.basis.x.normalized()
	var side: Color = col.darkened(0.18)
	for i in range(n):
		var cu: float = lerpf(u0, u1, (float(i) + 0.5) / float(n))
		var a: float = cu - bw * 0.5
		var b: float = cu + bw * 0.5
		pk.quad(kit, key, [wf * Vector3(a, v0, d1), wf * Vector3(b, v0, d1), wf * Vector3(b, v1, d1), wf * Vector3(a, v1, d1)], nf, col,
				[Vector2(a, v0) * uvk, Vector2(b, v0) * uvk, Vector2(b, v1) * uvk, Vector2(a, v1) * uvk])
		pk.quad(kit, key, [wf * Vector3(a, v0, d0), wf * Vector3(a, v0, d1), wf * Vector3(a, v1, d1), wf * Vector3(a, v1, d0)], -nu, side,
				[Vector2(d0, v0) * uvk, Vector2(d1, v0) * uvk, Vector2(d1, v1) * uvk, Vector2(d0, v1) * uvk])
		pk.quad(kit, key, [wf * Vector3(b, v0, d1), wf * Vector3(b, v0, d0), wf * Vector3(b, v1, d0), wf * Vector3(b, v1, d1)], nu, side,
				[Vector2(d1, v0) * uvk, Vector2(d0, v0) * uvk, Vector2(d0, v1) * uvk, Vector2(d1, v1) * uvk])


## `n` level bars `bh` tall spread evenly over [v0, v1], from u0 to u1, standing d0..d1 off the wall: fronts, tops, undersides.
static func _hbars(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, u1: float, v0: float, v1: float, n: int, bh: float,
		d0: float, d1: float, col: Color) -> void:
	if n <= 0 or u1 - u0 < 1e-4:
		return
	var nf: Vector3 = wf.basis.z.normalized()
	var side: Color = col.darkened(0.18)
	for i in range(n):
		var cv: float = lerpf(v0, v1, (float(i) + 0.5) / float(n))
		var a: float = cv - bh * 0.5
		var b: float = cv + bh * 0.5
		pk.quad(kit, key, [wf * Vector3(u0, a, d1), wf * Vector3(u1, a, d1), wf * Vector3(u1, b, d1), wf * Vector3(u0, b, d1)], nf, col,
				[Vector2(a, u0) * uvk, Vector2(a, u1) * uvk, Vector2(b, u1) * uvk, Vector2(b, u0) * uvk])
		pk.quad(kit, key, [wf * Vector3(u0, b, d0), wf * Vector3(u0, b, d1), wf * Vector3(u1, b, d1), wf * Vector3(u1, b, d0)], Vector3.UP, side,
				[Vector2(d0, u0) * uvk, Vector2(d1, u0) * uvk, Vector2(d1, u1) * uvk, Vector2(d0, u1) * uvk])
		pk.quad(kit, key, [wf * Vector3(u0, a, d1), wf * Vector3(u0, a, d0), wf * Vector3(u1, a, d0), wf * Vector3(u1, a, d1)], Vector3.DOWN, side,
				[Vector2(d1, u0) * uvk, Vector2(d0, u0) * uvk, Vector2(d0, u1) * uvk, Vector2(d1, u1) * uvk])


## A wall face [u0, u1] x [v0, v1] at depth 0 with rectangular openings left out (`ops`: [u0, v0, u1, v1] each, apart).
static func _holed(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, ops: Array, col: Color) -> void:
	var us: Array = [u0, u1]
	for o in ops:
		us.append(clampf(float(o[0]), u0, u1))
		us.append(clampf(float(o[2]), u0, u1))
	us.sort()
	for i in range(us.size() - 1):
		var a: float = us[i]
		var b: float = us[i + 1]
		if b - a < 1e-4:
			continue
		var mid: float = (a + b) * 0.5
		var cuts: Array = []
		for o in ops:
			if mid > float(o[0]) and mid < float(o[2]):
				cuts.append([float(o[1]), float(o[3])])
		cuts.sort_custom(func(p, q): return p[0] < q[0])
		var y := v0
		for c in cuts:
			if float(c[0]) > y:
				_face(pk, kit, key, wf, a, y, b, minf(float(c[0]), v1), 0.0, col)
			y = maxf(y, float(c[1]))
		if v1 > y:
			_face(pk, kit, key, wf, a, y, b, v1, 0.0, col)


## An opening's inside: its back `depth` behind the wall's face and the four reveals.
static func _recess(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, depth: float, key_back: String, col_back: Color,
		key_side: String, col_side: Color) -> void:
	_face(pk, kit, key_back, wf, u0, v0, u1, v1, -depth, col_back)
	var nu: Vector3 = wf.basis.x.normalized()
	var c: Color = col_side.darkened(0.25)
	pk.quad(kit, key_side, [wf * Vector3(u0, v0, -depth), wf * Vector3(u0, v0, 0), wf * Vector3(u0, v1, 0), wf * Vector3(u0, v1, -depth)], nu, c)
	pk.quad(kit, key_side, [wf * Vector3(u1, v0, 0), wf * Vector3(u1, v0, -depth), wf * Vector3(u1, v1, -depth), wf * Vector3(u1, v1, 0)], -nu, c)
	pk.quad(kit, key_side, [wf * Vector3(u0, v0, -depth), wf * Vector3(u1, v0, -depth), wf * Vector3(u1, v0, 0), wf * Vector3(u0, v0, 0)], Vector3.UP, c)
	pk.quad(kit, key_side, [wf * Vector3(u0, v1, 0), wf * Vector3(u1, v1, 0), wf * Vector3(u1, v1, -depth), wf * Vector3(u0, v1, -depth)], Vector3.DOWN, c)


## An axis-aligned block between two corners with masonry UVs: its sides as walls (u along, v up) and its top.
static func _mblock(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color, top := true, bottom := false) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	wall(pk, kit, key, Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z), lo.y, hi.y, col, Vector3(0, 0, 1), lo.x)
	wall(pk, kit, key, Vector3(hi.x, 0, lo.z), Vector3(lo.x, 0, lo.z), lo.y, hi.y, col, Vector3(0, 0, -1), -hi.x)
	wall(pk, kit, key, Vector3(hi.x, 0, hi.z), Vector3(hi.x, 0, lo.z), lo.y, hi.y, col, Vector3(1, 0, 0), -hi.z)
	wall(pk, kit, key, Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), lo.y, hi.y, col, Vector3(-1, 0, 0), lo.z)
	if top:
		pk.quad(kit, key, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], Vector3.UP, col,
				[Vector2(lo.x, lo.z) * uvk, Vector2(hi.x, lo.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(lo.x, hi.z) * uvk])
	if bottom:
		pk.quad(kit, key, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)], Vector3.DOWN, col.darkened(0.3),
				[Vector2(lo.x, lo.z) * uvk, Vector2(lo.x, hi.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(hi.x, lo.z) * uvk])


## A square post `s` across standing at (x, z) from y0 to y1: four sides, the grain up it (and its top with `cap`).
static func _post(pk: PropKit, kit: Dictionary, key: String, x: float, z: float, y0: float, y1: float, s: float, col: Color, cap := false) -> void:
	var h: float = s * 0.5
	var c: Array = [Vector3(x - h, 0, z + h), Vector3(x + h, 0, z + h), Vector3(x + h, 0, z - h), Vector3(x - h, 0, z - h)]
	var outs: Array = [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]
	for i in range(4):
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		pk.quad(kit, key, [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)], outs[i], col,
				[Vector2(float(i) * s, y0) * uvk, Vector2(float(i + 1) * s, y0) * uvk, Vector2(float(i + 1) * s, y1) * uvk, Vector2(float(i) * s, y1) * uvk])
	if cap:
		pk.quad(kit, key, [Vector3(x - h, y1, z - h), Vector3(x + h, y1, z - h), Vector3(x + h, y1, z + h), Vector3(x - h, y1, z + h)], Vector3.UP, col.darkened(0.1))


## A box whose long axis runs a to b, `w` across (along `side`) and `t` thick, UVs in metres: beams, rails.
static func _beam(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, t: float, col: Color, side := Vector3.ZERO) -> void:
	pk.beam(kit, key, a, b, w, t, col, side, uvk)


## A round column from y0 to y1 at c (its x and z), radius r0 at the foot and r1 at the head, UVs in metres.
static func _round(pk: PropKit, kit: Dictionary, key: String, c: Vector3, y0: float, y1: float, r0: float, r1: float, segs: int, col: Color, caps := false) -> void:
	pk.tube(kit, key, Vector3(c.x, y0, c.z), Vector3(c.x, y1, c.z), r0, r1, segs, col, caps, uvk)


## A small diamond (octahedron) at c: fruit, knobs, beads.
static func _blob(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: Vector3, col: Color) -> void:
	var ax := [Vector3(r.x, 0, 0), Vector3(0, r.y, 0), Vector3(0, 0, r.z)]
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var a: Vector3 = c + ax[0] * sx
				var b: Vector3 = c + ax[1] * sy
				var d: Vector3 = c + ax[2] * sz
				var n := Vector3(sx / r.x, sy / r.y, sz / r.z).normalized()
				pk.tri(kit, key, a, b, d, n, n, n, col, n)


## A ball: a lathe of `rings` bands.
static func _ball(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, col: Color, segs := 8, rings := 5, squash := 1.0) -> void:
	var prof: Array = []
	for i in range(rings + 1):
		var a: float = -PI * 0.5 + PI * float(i) / float(rings)
		prof.append(Vector2(maxf(cos(a) * r, 0.001), sin(a) * r * squash))
	pk.lathe(kit, key, c, prof, segs, col)


# ======================================================================================
#  The emblem, lanterns, cloth
# ======================================================================================

## The cup's emblem: a five-petal cherry blossom, each petal notched at its tip, flat, facing `out` at `c` (stand it TP
## off what carries it), `r` to the petals' tips; `heart` (with alpha) a small centre in another colour.
static func sakura_crest(pk: PropKit, kit: Dictionary, key: String, c: Vector3, out: Vector3, r: float, col: Color, heart := Color(0, 0, 0, 0)) -> void:
	var o: Vector3 = out.normalized()
	var ux: Vector3 = Vector3.UP.cross(o)
	if ux.length_squared() < 1e-6:
		ux = Vector3.RIGHT
	ux = ux.normalized()
	var uy: Vector3 = o.cross(ux).normalized()
	var petal: Array = [Vector2(0.0, 0.13), Vector2(0.17, 0.34), Vector2(0.29, 0.62), Vector2(0.24, 0.86), Vector2(0.10, 1.0), Vector2(0.0, 0.84),
			Vector2(-0.10, 1.0), Vector2(-0.24, 0.86), Vector2(-0.29, 0.62), Vector2(-0.17, 0.34)]
	var fan: Array = [[0, 1, 9], [1, 2, 8], [1, 8, 9], [2, 7, 8], [2, 5, 7], [2, 3, 5], [3, 4, 5], [5, 6, 7]]
	for k in range(5):
		var a: float = TAU * float(k) / 5.0
		var ca: float = cos(a)
		var sa: float = sin(a)
		var pts: Array = []
		for p in petal:
			var q: Vector2 = Vector2(p.x * ca + p.y * sa, -p.x * sa + p.y * ca) * r
			pts.append(c + ux * q.x + uy * q.y)
		for f in fan:
			pk.tri(kit, key, pts[f[0]], pts[f[1]], pts[f[2]], o, o, o, col, o)
	if heart.a > 0.0:
		var hc: Vector3 = c + o * 0.004
		for k in range(5):
			var a0: float = TAU * (float(k) + 0.5) / 5.0
			var a1: float = TAU * (float(k) + 1.5) / 5.0
			pk.tri(kit, key, hc, hc + (ux * sin(a0) + uy * cos(a0)) * r * 0.16, hc + (ux * sin(a1) + uy * cos(a1)) * r * 0.16, o, o, o, heart, o)


## A paper lantern (chochin) centred at `c`: a bellied paper body ("washi": it glows at dusk) between black lacquer rims,
## `r` its belly, `h` its body's height; with `crest` (alpha) the blossom on its front (`face`), `cord` its hanging cord's
## length above the top rim.
static func chochin(pk: PropKit, kit: Dictionary, c: Vector3, r: float, h: float, col: Color, segs := 8, crest := Color(0, 0, 0, 0), face := Vector3(0, 0, 1),
		cord := 0.0) -> void:
	var prof: Array = [Vector2(r * 0.58, -h * 0.5), Vector2(r * 0.88, -h * 0.3), Vector2(r, 0.0), Vector2(r * 0.88, h * 0.3), Vector2(r * 0.58, h * 0.5)]
	pk.lathe(kit, "washi", c, prof, segs, col)
	var rh: float = maxf(h * 0.07, 0.025)
	for sy in [-1.0, 1.0]:
		var y0: float = sy * h * 0.5 - (rh if sy < 0.0 else 0.008)
		var y1: float = sy * h * 0.5 + (0.008 if sy < 0.0 else rh)
		pk.lathe(kit, "urushi", c, [Vector2(0.001, y0), Vector2(r * 0.63, y0), Vector2(r * 0.63, y1), Vector2(0.001, y1)], segs, BLACK_LAC)
	if cord > 0.0:
		pk.tube(kit, "rope", c + Vector3(0, h * 0.5, 0), c + Vector3(0, h * 0.5 + rh + cord, 0), r * 0.05 + 0.006, r * 0.05 + 0.006, 4, BLACK_LAC, false)
	if crest.a > 0.0:
		var f: Vector3 = face.normalized()
		sakura_crest(pk, kit, "urushi", c + f * (r + 0.012), f, r * 0.42, crest)


## A noren: a rod along the wall at height `v_top` and `n` cloth panels hanging `drop` from it, a hand apart, the
## blossom on the middle ones. `d` is how far off the wall's face it hangs.
static func _noren(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, u1: float, v_top: float, drop: float, n: int, col: Color, crest: Color, d := 0.14) -> void:
	var nf: Vector3 = wf.basis.z.normalized()
	pk.tube(kit, "hinoki", wf * Vector3(u0 - 0.08, v_top, d), wf * Vector3(u1 + 0.08, v_top, d), 0.02, 0.02, 5, BAMBOO_DRY, true)
	var pw: float = (u1 - u0) / float(n)
	for i in range(n):
		var a: float = u0 + pw * float(i) + 0.015
		var b: float = u0 + pw * float(i + 1) - 0.015
		# Each panel swings a little out at its foot, by its own amount: no two lie in one plane.
		var sway: float = 0.02 + 0.025 * float((i * 7 + 3) % 4)
		pk.quad(kit, "cloth", [wf * Vector3(a, v_top - drop, d + sway), wf * Vector3(b, v_top - drop, d + sway), wf * Vector3(b, v_top, d), wf * Vector3(a, v_top, d)],
				nf, col.darkened(0.04 * float(i % 2)))
		if crest.a > 0.0 and ((n % 2 == 1 and i == n / 2) or (n % 2 == 0 and (i == n / 2 - 1 or i == n / 2)) or n <= 2):
			var cr: float = minf(pw * 0.36, drop * 0.3)
			var cy: float = v_top - drop * 0.5
			sakura_crest(pk, kit, "cloth", wf * Vector3((a + b) * 0.5, cy, d + sway * 0.5 + TP), nf, cr, crest)


## A bench (shogi) with a red felt cloth over it: `c` the middle of its top's front edge on the ground, facing `out`.
static func _felt_bench(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, length := 1.8, depth := 0.5, felt := true) -> void:
	var wf := _wf(c, out)
	var h := 0.42
	var wood := Color(0.34, 0.24, 0.16)
	# The top and four legs with a stretcher each end.
	_slab(pk, kit, "hinoki", wf, -length * 0.5, length * 0.5, -depth, 0.0, h - 0.05, h, wood)
	for su in [-1.0, 1.0]:
		for sd in [-0.07, -depth + 0.07]:
			var p: Vector3 = wf * Vector3(su * (length * 0.5 - 0.1), 0, sd)
			_post(pk, kit, "hinoki", p.x, p.z, c.y, c.y + h - 0.05, 0.06, wood)
	if felt:
		var e := 0.03
		var red := FELT_RED
		var top: Array = [wf * Vector3(-length * 0.5 - e, h + 0.012, e), wf * Vector3(length * 0.5 + e, h + 0.012, e), wf * Vector3(length * 0.5 + e, h + 0.012, -depth - e),
				wf * Vector3(-length * 0.5 - e, h + 0.012, -depth - e)]
		pk.quad(kit, "cloth", top, Vector3.UP, red)
		# It hangs down the front and the back.
		var nf: Vector3 = wf.basis.z.normalized()
		pk.quad(kit, "cloth", [wf * Vector3(-length * 0.5 - e, h - 0.2, e + 0.012), wf * Vector3(length * 0.5 + e, h - 0.2, e + 0.012), top[1], top[0]], nf, red.darkened(0.08))
		pk.quad(kit, "cloth", [top[3], top[2], wf * Vector3(length * 0.5 + e, h - 0.2, -depth - e - 0.012), wf * Vector3(-length * 0.5 - e, h - 0.2, -depth - e - 0.012)], -nf,
				red.darkened(0.08))


## A slab in a wall frame: u0..u1 along, depth z0..z1 (out of the wall), y0..y1: all six faces.
static func _slab(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, u1: float, z0: float, z1: float, y0: float, y1: float, col: Color) -> void:
	var c: Vector3 = wf * Vector3((u0 + u1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	pk.box(kit, key, Transform3D(wf.basis, c), Vector3(absf(u1 - u0), absf(y1 - y0), absf(z1 - z0)), col, uvk)


## A big red paper parasol (nodate-gasa) standing at `p`: a pole, a shallow cone of paper in sixteen gores, a knob.
static func _parasol(pk: PropKit, kit: Dictionary, p: Vector3, height := 2.5, r := 1.35, col := PAPER_RED) -> void:
	pk.tube(kit, "urushi", p, p + Vector3(0, height + 0.06, 0), 0.028, 0.024, 6, BLACK_LAC, false)
	pk.lathe(kit, "ishi", p, [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.17, 0.14), Vector2(0.001, 0.14)], 8, GRANITE.darkened(0.2))
	var apex: Vector3 = p + Vector3(0, height, 0)
	var n := 16
	for i in range(n):
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var e0: Vector3 = p + Vector3(cos(a0) * r, height - r * 0.3, sin(a0) * r)
		var e1: Vector3 = p + Vector3(cos(a1) * r, height - r * 0.3, sin(a1) * r)
		var nn: Vector3 = Vector3(cos((a0 + a1) * 0.5) * 0.3, 1.0, sin((a0 + a1) * 0.5) * 0.3).normalized()
		pk.tri(kit, "cloth", apex, e0, e1, nn, nn, nn, col.darkened(0.1 * float(i % 2)), nn)
		# A rib under every other seam.
		if i % 2 == 0:
			pk.beam(kit, "hinoki", apex + Vector3(0, -0.035, 0), e0 + Vector3(0, -0.03, 0), 0.02, 0.02, BAMBOO_DRY.darkened(0.3))
	pk.lathe(kit, "urushi", apex, [Vector2(0.001, -0.02), Vector2(0.07, -0.02), Vector2(0.05, 0.07), Vector2(0.001, 0.1)], 6, BLACK_LAC)


# ======================================================================================
#  The roof
# ======================================================================================

## A roof's description. `c`: the middle of the roof in plan at the height of its eave's edge (for R_PENT: the middle of
## the wall line, at the eave's height); `hx`, `hz`: the half extents out to the eaves' and verges' edges, the ridge
## along x (R_PENT: `hz` is how far it reaches out from the wall, toward +z); `rise`: the ridge over the eave. Turn it
## with "yaw". Change any field before `jroof`:
##   sori (how much the slope sags: 0 straight), lift (how far the eave rises to a corner), thick (the edge's thickness),
##   run (a hip's reach in x: hz gives 45 degrees in plan), tb (R_IRIMOYA: the share of the height where the gable starts),
##   gable_in (how far the gable wall stands in from the verge), gable_key/gable_col, t_max (R_HOGYO: cut the slopes off
##   there, where the next storey rises through),
##   wall_hx, wall_zf, wall_zb (where the walls stand, from the middle: the rafters start there), raft (their spacing; 0
##   none), raft_key/raft_col/raft_end/raft_w/raft_d, ridge (false: none), ridge_h, ridge_key/ridge_col, oni (the ridge's
##   end ornaments), discs (round end tiles), n and m (the grid along and up a slope), under_key/under_col,
##   hafu_key/hafu_col (the bargeboards), crest (alpha: a blossom on the gables' pendants).
static func roof_spec(kind: int, c: Vector3, hx: float, hz: float, rise: float, key := "kawara", col := KAWARA) -> Dictionary:
	return {"kind": kind, "c": c, "hx": hx, "hz": hz, "rise": rise, "key": key, "col": col, "yaw": 0.0,
			"sori": 0.35, "lift": 0.1, "thick": 0.13, "run": hz, "tb": 0.5, "gable_in": 0.5, "gable_key": "shikkui", "gable_col": SHIKKUI, "t_max": 1.0,
			"wall_hx": hx - 0.8, "wall_zf": hz - 0.8, "wall_zb": hz - 0.8,
			"raft": 0.0, "raft_key": "hinoki", "raft_col": CEDAR_DARK, "raft_end": Color(0, 0, 0, 0), "raft_w": 0.07, "raft_d": 0.1,
			"ridge": true, "ridge_h": 0.26, "ridge_key": "kawara", "ridge_col": KAWARA_OLD, "oni": true, "discs": key == "kawara",
			"n": 8, "m": 4, "under_key": "sugi", "under_col": CEDAR_DARK, "hafu_key": "hinoki", "hafu_col": CEDAR_DARK, "crest": Color(0, 0, 0, 0)}


## A lean-to roof's spec: along x from x0 to x1 on a wall at z = z_wall facing +z, its top edge at y_top on the wall,
## reaching `depth` out and falling `drop`.
static func pent_spec(x0: float, x1: float, z_wall: float, y_top: float, depth: float, drop: float, key := "kawara", col := KAWARA) -> Dictionary:
	var s := roof_spec(R_PENT, Vector3((x0 + x1) * 0.5, y_top - drop, z_wall), (x1 - x0) * 0.5, depth, drop, key, col)
	s.wall_zf = 0.0
	s.wall_zb = 0.0
	s.lift = 0.05
	s.sori = 0.25
	s.m = 2
	s.ridge = false
	return s


static func _rf_f(t: float, k: float) -> float:
	return (1.0 - k) * t + k * t * t


static func _rf_tcap(s: Dictionary) -> float:
	match int(s.kind):
		R_YOSEMUNE, R_HOGYO:
			return 1.0
		R_IRIMOYA:
			return float(s.tb)
	return 0.0


## The height (over the eave's edge) of a front or back slope at x, `q` from the ridge line (R_PENT: from the eave's far
## side: q = hz at the eave... see _rf_q).
static func _rf_front(s: Dictionary, x: float, q: float) -> float:
	var t: float = 1.0 - q / float(s.hz)
	var tc: float = clampf(t, 0.0, 1.0)
	var w: float = float(s.hx) - minf(tc, _rf_tcap(s)) * float(s.run)
	var u: float = clampf(absf(x) / maxf(w, 0.05), 0.0, 1.2)
	var e: float = 1.0 - tc
	return float(s.rise) * _rf_f(t, float(s.sori)) + float(s.lift) * u * u * u * e * e


## The height of an end slope (a hipped roof's) at `q` from the middle along x, z across.
static func _rf_end(s: Dictionary, q: float, z: float) -> float:
	var t: float = (float(s.hx) - q) / float(s.run)
	var tc: float = clampf(t, 0.0, 1.0)
	var wz: float = float(s.hz) * (1.0 - tc)
	var u: float = clampf(absf(z) / maxf(wz, 0.05), 0.0, 1.2)
	var e: float = 1.0 - tc
	return float(s.rise) * _rf_f(t, float(s.sori)) + float(s.lift) * u * u * u * e * e


## The roof's top over a point of its own plan (x along the ridge, z across; over the eave's edge height).
static func _rf_top(s: Dictionary, x: float, z: float) -> float:
	var kind: int = s.kind
	if kind == R_PENT:
		return _rf_front(s, x, clampf(z, 0.0, float(s.hz)))
	var f: float = _rf_front(s, x, absf(z))
	if kind == R_YOSEMUNE or kind == R_HOGYO:
		return minf(f, _rf_end(s, absf(x), z))
	if kind == R_IRIMOYA and (float(s.hx) - absf(x)) / float(s.run) < float(s.tb):
		return minf(f, _rf_end(s, absf(x), z))
	return f


static func _rf_xf(s: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(s.yaw)), s.c)


## The roof's top surface (y, in the frame the spec's `c` is in) over the point p.
static func roof_y(s: Dictionary, p: Vector3) -> float:
	var l: Vector3 = _rf_xf(s).affine_inverse() * p
	return (s.c as Vector3).y + _rf_top(s, l.x, l.z)


## Its underside there: what a post or a wall under it reaches up to.
static func roof_under_y(s: Dictionary, p: Vector3) -> float:
	return roof_y(s, p) - float(s.thick)


static func _gq(pk: PropKit, kit: Dictionary, key: String, a: Array, b: Array, c: Array, d: Array, col: Color) -> void:
	var out: Vector3 = (a[1] as Vector3) + (b[1] as Vector3) + (c[1] as Vector3) + (d[1] as Vector3)
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var pd: Vector3 = d[0]
	if (pb - pa).cross(pc - pa).length_squared() > 1e-9:
		pk.tri(kit, key, pa, pb, pc, a[1], b[1], c[1], col, out, a[2], b[2], c[2])
	if (pc - pa).cross(pd - pa).length_squared() > 1e-9:
		pk.tri(kit, key, pa, pc, pd, a[1], c[1], d[1], col, out, a[2], c[2], d[2])


## One slope: `rows` of [local position, local normal, uv in metres] from the eave up; the top, the underside `thick`
## below it and the eave's edge (row 0) between them.
static func _rf_slope(pk: PropKit, kit: Dictionary, s: Dictionary, xf: Transform3D, rows: Array, out_l: Vector3) -> void:
	var thick: float = s.thick
	var top: Array = []
	var und: Array = []
	for row in rows:
		var tr: Array = []
		var ur: Array = []
		for v in row:
			var p: Vector3 = v[0]
			var n: Vector3 = xf.basis * (v[1] as Vector3)
			tr.append([xf * p, n, (v[2] as Vector2) * uvk])
			ur.append([xf * (p - Vector3(0, thick, 0)), -n, Vector2(p.x, p.z) * uvk])
		top.append(tr)
		und.append(ur)
	var key: String = s.key
	var col: Color = s.col
	for j in range(top.size() - 1):
		var n: int = mini((top[j] as Array).size(), (top[j + 1] as Array).size())
		for i in range(n - 1):
			_gq(pk, kit, key, top[j][i], top[j][i + 1], top[j + 1][i + 1], top[j + 1][i], col)
			_gq(pk, kit, s.under_key, und[j][i], und[j][i + 1], und[j + 1][i + 1], und[j + 1][i], s.under_col)
	# The eave's edge.
	var o: Vector3 = (xf.basis * out_l).normalized()
	var r0: Array = top[0]
	var u0: Array = und[0]
	var ec: Color = col.darkened(0.16)
	for i in range(r0.size() - 1):
		var ua: float = ((rows[0][i][2]) as Vector2).x * uvk
		var ub: float = ((rows[0][i + 1][2]) as Vector2).x * uvk
		pk.quad(kit, key, [u0[i][0], u0[i + 1][0], r0[i + 1][0], r0[i][0]], o, ec, [Vector2(ua, 0), Vector2(ub, 0), Vector2(ub, thick * uvk), Vector2(ua, thick * uvk)])


## A round end tile (a hexagon standing 2cm off the eave's edge) at the local point p, facing out_l.
static func _rf_disc(pk: PropKit, kit: Dictionary, s: Dictionary, xf: Transform3D, p: Vector3, out_l: Vector3, r: float) -> void:
	var o: Vector3 = (xf.basis * out_l).normalized()
	var ux: Vector3 = Vector3.UP.cross(o).normalized()
	var c: Vector3 = xf * p + o * 0.02
	var pts: Array = []
	var uvs: Array = []
	for k in range(6):
		var a: float = TAU * float(k) / 6.0
		pts.append(c + (ux * cos(a) + Vector3.UP * sin(a)) * r)
		uvs.append(Vector2(0.21 + cos(a) * 0.05, 0.3 + sin(a) * 0.05))
	var col: Color = (s.col as Color).lightened(0.1)
	for f in [[0, 1, 2], [0, 2, 3], [0, 3, 5], [3, 4, 5]]:
		pk.tri(kit, s.key, pts[f[0]], pts[f[1]], pts[f[2]], o, o, o, col, o, uvs[f[0]], uvs[f[1]], uvs[f[2]])


## A rafter under the roof from a (by the wall) to b (the eave), local points on its top line: two sides, its underside
## and its outer end.
static func _rf_rafter(pk: PropKit, kit: Dictionary, s: Dictionary, xf: Transform3D, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 0.1:
		return
	d /= l
	var side: Vector3 = d.cross(Vector3.UP).normalized()
	var dn: Vector3 = d.cross(side).normalized()
	if dn.y > 0.0:
		dn = -dn
	var w: float = float(s.raft_w) * 0.5
	var dp: float = s.raft_d
	var key: String = s.raft_key
	var col: Color = s.raft_col
	var a0: Vector3 = xf * (a - side * w)
	var a1: Vector3 = xf * (a + side * w)
	var b0: Vector3 = xf * (b - side * w)
	var b1: Vector3 = xf * (b + side * w)
	var lo: Vector3 = xf.basis * (dn * dp)
	var ws: Vector3 = xf.basis * side
	var uv: Array = [Vector2(0, 0), Vector2(0, l) * uvk, Vector2(dp, l) * uvk, Vector2(dp, 0) * uvk]
	pk.quad(kit, key, [a0, b0, b0 + lo, a0 + lo], -ws, col, uv)
	pk.quad(kit, key, [a1, b1, b1 + lo, a1 + lo], ws, col, uv)
	pk.quad(kit, key, [a0 + lo, b0 + lo, b1 + lo, a1 + lo], xf.basis * dn, col.darkened(0.15), uv)
	var endc: Color = s.raft_end
	pk.quad(kit, key, [b0, b1, b1 + lo, b0 + lo], xf.basis * d, endc if endc.a > 0.0 else col.lightened(0.08))


## A quad of local points through the roof's transform.
static func _rf_quad(pk: PropKit, kit: Dictionary, key: String, xf: Transform3D, p: Array, n: Vector3, col: Color, uv: Array = []) -> void:
	pk.quad(kit, key, [xf * (p[0] as Vector3), xf * (p[1] as Vector3), xf * (p[2] as Vector3), xf * (p[3] as Vector3)], (xf.basis * n).normalized(), col, uv)


## The ridge's end ornament (onigawara): a horned plaque at the local point p (the ridge's foot), facing `dir` (local).
static func _onigawara(pk: PropKit, kit: Dictionary, key: String, xf: Transform3D, p: Vector3, dir: Vector3, size: float, col: Color) -> void:
	var o: Vector3 = (xf.basis * dir).normalized()
	var wf := Transform3D(Basis(Vector3.UP.cross(o).normalized(), Vector3.UP, o), xf * p)
	var ol := PackedVector2Array()
	for q in [Vector2(-0.46, 0.0), Vector2(0.46, 0.0), Vector2(0.6, 0.42), Vector2(0.44, 0.86), Vector2(0.2, 0.96), Vector2(0.0, 1.28), Vector2(-0.2, 0.96),
			Vector2(-0.44, 0.86), Vector2(-0.6, 0.42)]:
		ol.append(q * size)
	_prism(pk, kit, key, wf, ol, -0.07 * size - 0.02, 0.09 * size, col, true)
	# The boss on its face and the horn (toribusuma) over it.
	var bc: Vector3 = wf * Vector3(0, 0.5 * size, 0.09 * size)
	pk.lathe(kit, key, bc, [Vector2(0.2 * size, 0.0), Vector2(0.12 * size, 0.07 * size), Vector2(0.001, 0.09 * size)], 6, col.lightened(0.12), false,
			Basis(Vector3.UP.cross(o).normalized(), o, -Vector3.UP))
	pk.tube(kit, key, wf * Vector3(0, 1.0 * size, -0.05 * size), wf * Vector3(0, 1.3 * size, 0.42 * size), 0.1 * size, 0.07 * size, 5, col, true)


## The gable wall under a gabled roof's end: at local x = sx * (the verge - `inset`), from local z0 to z1, from `y0` (a
## height in the spec's frame) up to the roof's underside. For R_KIRIZUMA ends; jroof makes R_IRIMOYA's own.
static func roof_gable(pk: PropKit, kit: Dictionary, s: Dictionary, sx: float, z0: float, z1: float, y0: float, key: String, col: Color, inset := 0.2) -> void:
	var xf := _rf_xf(s)
	_rf_gable_at(pk, kit, s, xf, sx * (float(s.hx) - inset), z0, z1, y0 - (s.c as Vector3).y, key, col, sx)


static func _rf_gable_at(pk: PropKit, kit: Dictionary, s: Dictionary, xf: Transform3D, lx: float, z0: float, z1: float, y0: float, key: String, col: Color, sx: float) -> void:
	var k: int = 8
	var n := Vector3(sx, 0, 0)
	var thick: float = s.thick
	for i in range(k):
		var za: float = lerpf(z0, z1, float(i) / float(k))
		var zb: float = lerpf(z0, z1, float(i + 1) / float(k))
		var ya: float = maxf(_rf_front(s, lx, absf(za)) - thick * 0.6, y0)
		var yb: float = maxf(_rf_front(s, lx, absf(zb)) - thick * 0.6, y0)
		if ya - y0 < 1e-4 and yb - y0 < 1e-4:
			continue
		pk.quad(kit, key, [xf * Vector3(lx, y0, za), xf * Vector3(lx, y0, zb), xf * Vector3(lx, yb, zb), xf * Vector3(lx, ya, za)], (xf.basis * n).normalized(), col,
				[Vector2(za, y0) * uvk, Vector2(zb, y0) * uvk, Vector2(zb, yb) * uvk, Vector2(za, ya) * uvk])


## Builds the roof a spec describes.
static func jroof(pk: PropKit, kit: Dictionary, s: Dictionary) -> void:
	var xf := _rf_xf(s)
	var kind: int = s.kind
	var hx: float = s.hx
	var hz: float = s.hz
	var run: float = s.run
	var rise: float = s.rise
	var thick: float = s.thick
	var tb: float = s.tb
	var tcap: float = _rf_tcap(s)
	var n: int = s.n
	var m: int = s.m
	var key: String = s.key
	var col: Color = s.col
	var hip: bool = kind == R_YOSEMUNE or kind == R_HOGYO or kind == R_IRIMOYA
	var e := 0.02
	# The rows' heights up a slope.
	var ts: Array = []
	if kind == R_IRIMOYA:
		var ml: int = maxi(2, int(round(float(m) * tb)))
		var mu: int = maxi(2, m - ml)
		for j in range(ml):
			ts.append(tb * float(j) / float(ml))
		for j in range(mu + 1):
			ts.append(lerpf(tb, 1.0, float(j) / float(mu)))
	else:
		var tmax: float = s.t_max if kind == R_HOGYO else 1.0
		for j in range(m + 1):
			ts.append(tmax * float(j) / float(m))
	var signs: Array = [1.0] if kind == R_PENT else [1.0, -1.0]
	var pitch: float = 0.42 / uvk
	# Front and back slopes.
	for sz in signs:
		var rows: Array = []
		var vlen := 0.0
		var prev := Vector3.ZERO
		for j in range(ts.size()):
			var t: float = ts[j]
			var q: float = hz * (1.0 - t)
			var w: float = hx - minf(t, tcap) * run
			var mid := Vector3(0, _rf_front(s, 0.0, q), q)
			if j > 0:
				vlen += (mid - prev).length()
			prev = mid
			var row: Array = []
			for i in range(n + 1):
				var x: float = (-1.0 + 2.0 * float(i) / float(n)) * w
				var y: float = _rf_front(s, x, q)
				var dhx: float = (_rf_front(s, x + e, q) - _rf_front(s, x - e, q)) / (2.0 * e)
				var dhq: float = (_rf_front(s, x, q + e) - y) / e
				row.append([Vector3(x, y, sz * q), Vector3(-dhx, 1.0, -sz * dhq).normalized(), Vector2(x + hx, vlen)])
			rows.append(row)
		_rf_slope(pk, kit, s, xf, rows, Vector3(0, 0, sz))
		if bool(s.discs):
			var k0: int = int(ceil((-hx + pitch * 0.5) / pitch - 0.5 + hx / pitch))
			var x := (float(k0) + 0.5) * pitch - hx
			while x < hx - pitch * 0.45:
				if x > -hx + pitch * 0.45:
					_rf_disc(pk, kit, s, xf, Vector3(x, _rf_front(s, x, hz) - pitch * 0.33, sz * hz), Vector3(0, 0, sz), pitch * 0.4)
				x += pitch
		# The rafters under this eave.
		if float(s.raft) > 0.0:
			var step: float = s.raft
			var xmax: float = hx - (0.3 if hip else 0.14)
			var cnt: int = maxi(int(floor(2.0 * xmax / step)), 1)
			var wall_q: float = float(s.wall_zf) if sz > 0.0 else float(s.wall_zb)
			for k in range(cnt + 1):
				var x2: float = -xmax + 2.0 * xmax * float(k) / float(cnt)
				var q0: float = wall_q - 0.03
				if hip and absf(x2) > float(s.wall_hx):
					q0 = maxf(q0, hz * (1.0 - (hx - absf(x2)) / run) + 0.14)
				var q1: float = hz - 0.035
				if q1 - q0 < 0.18:
					continue
				_rf_rafter(pk, kit, s, xf, Vector3(x2, _rf_front(s, x2, q0) - thick + 0.012, sz * q0), Vector3(x2, _rf_front(s, x2, q1) - thick + 0.012, sz * q1))
	# The end slopes of a hipped roof.
	if hip:
		var t_end: float = 1.0
		if kind == R_IRIMOYA:
			t_end = minf(1.0, tb + float(s.gable_in) / run + 0.03)
		elif kind == R_HOGYO:
			t_end = s.t_max
		var me: int = maxi(2, int(round(float(m) * t_end)))
		for sx in [1.0, -1.0]:
			var rows: Array = []
			var vlen := 0.0
			var prev := Vector3.ZERO
			for j in range(me + 1):
				var t: float = t_end * float(j) / float(me)
				var q: float = hx - t * run
				var wz: float = hz * (1.0 - t)
				var mid := Vector3(q, _rf_end(s, q, 0.0), 0)
				if j > 0:
					vlen += (mid - prev).length()
				prev = mid
				var row: Array = []
				var ne: int = maxi(2, int(round(float(n) * hz / hx))) if kind != R_HOGYO else n
				for i in range(ne + 1):
					var z: float = (-1.0 + 2.0 * float(i) / float(ne)) * wz
					var y: float = _rf_end(s, q, z)
					var dhz: float = (_rf_end(s, q, z + e) - _rf_end(s, q, z - e)) / (2.0 * e)
					var dhq: float = (_rf_end(s, q + e, z) - y) / e
					row.append([Vector3(sx * q, y, z), Vector3(-sx * dhq, 1.0, -dhz).normalized(), Vector2(z + hz, vlen)])
				rows.append(row)
			_rf_slope(pk, kit, s, xf, rows, Vector3(sx, 0, 0))
			if bool(s.discs):
				var z := (float(int(ceil(hz / pitch - 0.5 - hz / pitch))) + 0.5) * pitch - hz
				z = fposmod(z + hz, pitch) - hz + pitch * 0.5
				while z < hz - pitch * 0.45:
					if z > -hz + pitch * 0.45:
						_rf_disc(pk, kit, s, xf, Vector3(sx * hx, _rf_end(s, hx, z) - pitch * 0.33, z), Vector3(sx, 0, 0), pitch * 0.4)
					z += pitch
			if float(s.raft) > 0.0:
				var step: float = s.raft
				var zmax: float = hz - 0.3
				var cnt: int = maxi(int(floor(2.0 * zmax / step)), 1)
				for k in range(cnt + 1):
					var z2: float = -zmax + 2.0 * zmax * float(k) / float(cnt)
					var wall_z: float = float(s.wall_zf) if z2 > 0.0 else float(s.wall_zb)
					var q0: float = float(s.wall_hx) - 0.03
					if absf(z2) > wall_z:
						q0 = maxf(q0, hx - (hz - absf(z2)) * run / hz + 0.14)
					var q1: float = hx - 0.035
					if q1 - q0 < 0.18:
						continue
					_rf_rafter(pk, kit, s, xf, Vector3(sx * q0, _rf_end(s, q0, z2) - thick + 0.012, z2), Vector3(sx * q1, _rf_end(s, q1, z2) - thick + 0.012, z2))
	# The verges: bargeboards (hafu) along the gables' edges, a pendant (gegyo) under each apex; a lean-to's ends closed.
	var xv: float = hx if kind != R_IRIMOYA else hx - tb * run
	var hafu: Color = s.hafu_col
	var hk: String = s.hafu_key
	if kind == R_KIRIZUMA or kind == R_IRIMOYA:
		var hh: float = thick + 0.16
		var t0: float = 0.0 if kind == R_KIRIZUMA else tb
		var mv: int = maxi(3, m)
		for sx in [1.0, -1.0]:
			for sz in [1.0, -1.0]:
				var run_l := 0.0
				for j in range(mv):
					var ta: float = lerpf(t0, 1.0, float(j) / float(mv))
					var tc: float = lerpf(t0, 1.0, float(j + 1) / float(mv))
					var qa: float = hz * (1.0 - ta) + (0.015 if j == 0 and kind == R_KIRIZUMA else 0.0)
					var qc: float = hz * (1.0 - tc)
					var ya: float = _rf_front(s, xv, qa)
					var yc: float = _rf_front(s, xv, qc)
					var seg: float = Vector2(qa - qc, yc - ya).length()
					var xo: float = sx * (xv + 0.035)
					var xi: float = sx * (xv - 0.075)
					var uv: Array = [Vector2(run_l, 0) * uvk, Vector2(run_l + seg, 0) * uvk, Vector2(run_l + seg, hh) * uvk, Vector2(run_l, hh) * uvk]
					# Outer face, underside, inner face (below the roof's underside), and the strip closing its top.
					_rf_quad(pk, kit, hk, xf, [Vector3(xo, ya - hh, sz * qa), Vector3(xo, yc - hh, sz * qc), Vector3(xo, yc + 0.03, sz * qc), Vector3(xo, ya + 0.03, sz * qa)],
							Vector3(sx, 0, 0), hafu, uv)
					_rf_quad(pk, kit, hk, xf, [Vector3(xo, ya - hh, sz * qa), Vector3(xo, yc - hh, sz * qc), Vector3(xi, yc - hh, sz * qc), Vector3(xi, ya - hh, sz * qa)],
							Vector3(0, -1, 0), hafu.darkened(0.2))
					_rf_quad(pk, kit, hk, xf, [Vector3(xi, ya - hh, sz * qa), Vector3(xi, yc - hh, sz * qc), Vector3(xi, yc - thick, sz * qc), Vector3(xi, ya - thick, sz * qa)],
							Vector3(-sx, 0, 0), hafu.darkened(0.2))
					_rf_quad(pk, kit, hk, xf, [Vector3(xo, ya + 0.03, sz * qa), Vector3(xo, yc + 0.03, sz * qc), Vector3(sx * xv, yc + 0.03, sz * qc), Vector3(sx * xv, ya + 0.03, sz * qa)],
							Vector3(0, 1, 0), hafu)
					run_l += seg
				# The board's foot, cut square at the eave.
				if kind == R_KIRIZUMA:
					var y0: float = _rf_front(s, xv, hz)
					var zc: float = sz * (hz + 0.015)
					_rf_quad(pk, kit, hk, xf, [Vector3(sx * (xv + 0.035), y0 - hh, zc), Vector3(sx * (xv - 0.075), y0 - hh, zc), Vector3(sx * (xv - 0.075), y0 + 0.03, zc),
							Vector3(sx * (xv + 0.035), y0 + 0.03, zc)], Vector3(0, 0, sz), hafu.darkened(0.1))
			# The pendant.
			var gs: float = clampf(rise * 0.16, 0.22, 0.75)
			var o: Vector3 = (xf.basis * Vector3(sx, 0, 0)).normalized()
			var gf := Transform3D(Basis(Vector3.UP.cross(o).normalized(), Vector3.UP, o), xf * Vector3(sx * (xv + 0.035), rise - hh + 0.06, 0.0))
			var ol := PackedVector2Array()
			for q in [Vector2(-0.42, 0.0), Vector2(0.42, 0.0), Vector2(0.56, -0.4), Vector2(0.3, -0.82), Vector2(0.0, -1.1), Vector2(-0.3, -0.82), Vector2(-0.56, -0.4)]:
				ol.append(q * gs)
			_prism(pk, kit, hk, gf, ol, 0.0, 0.05, hafu.lightened(0.05))
			var cr: Color = s.crest
			if cr.a > 0.0:
				sakura_crest(pk, kit, "gold", gf * Vector3(0, -0.45 * gs, 0.05 + TP), o, gs * 0.36, cr)
	elif kind == R_PENT:
		for sx in [1.0, -1.0]:
			for j in range(ts.size() - 1):
				var qa: float = hz * (1.0 - float(ts[j]))
				var qc: float = hz * (1.0 - float(ts[j + 1]))
				var ya: float = _rf_front(s, hx, qa)
				var yc: float = _rf_front(s, hx, qc)
				_rf_quad(pk, kit, key, xf, [Vector3(sx * hx, ya - thick, qa), Vector3(sx * hx, yc - thick, qc), Vector3(sx * hx, yc, qc), Vector3(sx * hx, ya, qa)],
						Vector3(sx, 0, 0), col.darkened(0.16))
	# An irimoya's gable walls, standing in from the verge on the end slopes.
	if kind == R_IRIMOYA:
		var gin: float = s.gable_in
		var t_e: float = tb + gin / run
		var xw: float = xv - gin
		var zg: float = hz * (1.0 - t_e)
		var y0: float = rise * _rf_f(t_e, float(s.sori)) - 0.04
		for sx in [1.0, -1.0]:
			_rf_gable_at(pk, kit, s, xf, sx * xw, -zg, zg, y0, s.gable_key, s.gable_col, sx)
			# A tie beam along its foot and a king post, TP proud.
			var o: Vector3 = (xf.basis * Vector3(sx, 0, 0)).normalized()
			var gf := Transform3D(Basis(Vector3.UP.cross(o).normalized(), Vector3.UP, o), xf * Vector3(sx * xw, 0.0, 0.0))
			var bh: float = clampf(rise * 0.05, 0.12, 0.3)
			_rect(pk, kit, hk, gf, -zg, y0, zg, y0 + bh, 0.0, 0.06, hafu)
			_rect(pk, kit, hk, gf, -bh * 0.5, y0 + bh, bh * 0.5, rise - thick - 0.02, 0.0, 0.05, hafu)
	# The ridge: stacked tiles under a round cap, an onigawara at each end.
	var rk: String = s.ridge_key
	var rc: Color = s.ridge_col
	var rh: float = s.ridge_h
	var rw: float = rh * 0.9
	if bool(s.ridge) and kind != R_HOGYO and kind != R_PENT:
		var rr: float = hx - 0.02
		if kind == R_YOSEMUNE:
			rr = hx - run
		elif kind == R_IRIMOYA:
			rr = xv - 0.02
		var y0: float = rise - 0.06
		var y1: float = rise + rh
		for sz in [1.0, -1.0]:
			# The courses lie level: the tile ribs run along v here (u up the ridge, four to its height).
			_rf_quad(pk, kit, rk, xf, [Vector3(-rr, y0, sz * rw * 0.5), Vector3(rr, y0, sz * rw * 0.5), Vector3(rr, y1, sz * rw * 0.5), Vector3(-rr, y1, sz * rw * 0.5)],
					Vector3(0, 0, sz), rc, [Vector2(0.0, 0.0), Vector2(0.0, 2.0 * rr * uvk), Vector2(1.5, 2.0 * rr * uvk), Vector2(1.5, 0.0)])
		for sx in [1.0, -1.0]:
			_rf_quad(pk, kit, rk, xf, [Vector3(sx * rr, y0, -rw * 0.5), Vector3(sx * rr, y0, rw * 0.5), Vector3(sx * rr, y1, rw * 0.5), Vector3(sx * rr, y1, -rw * 0.5)],
					Vector3(sx, 0, 0), rc.darkened(0.1))
		pk.tube(kit, rk, xf * Vector3(-rr - 0.03, y1 - 0.01, 0), xf * Vector3(rr + 0.03, y1 - 0.01, 0), rw * 0.62, rw * 0.62, 6, rc.lightened(0.06), true, uvk)
		if bool(s.oni):
			for sx in [1.0, -1.0]:
				_onigawara(pk, kit, rk, xf, Vector3(sx * (rr + 0.03), y0 - 0.02, 0), Vector3(sx, 0, 0), rh * 1.9, rc.darkened(0.08))
	# Corner ridges down the hips, each ending in an upturned tip.
	if hip and bool(s.ridge):
		var t_hip: float = tcap if kind != R_HOGYO else float(s.t_max)
		var mh: int = maxi(3, int(round(float(m) * t_hip)) + 1)
		for sx in [1.0, -1.0]:
			for sz in [1.0, -1.0]:
				var prev := Vector3.ZERO
				for j in range(mh + 1):
					var t: float = t_hip * float(j) / float(mh)
					var w: float = hx - t * run
					var q: float = hz * (1.0 - t)
					var p := Vector3(sx * w, _rf_front(s, w, q) + rh * 0.3, sz * q)
					if j == 0:
						var tip := p + Vector3(sx * run, 0, sz * hz).normalized() * (rh * 0.9) + Vector3(0, rh * 0.5, 0)
						pk.beam(kit, rk, xf * tip, xf * p, rh * 0.8, rh * 0.8, rc.darkened(0.06), Vector3.ZERO, uvk)
					else:
						pk.beam(kit, rk, xf * prev, xf * p, rh * 0.7, rh * 0.6, rc, Vector3.ZERO, uvk)
					prev = p
	# An irimoya's descending ridges, in from each verge.
	if kind == R_IRIMOYA and bool(s.ridge):
		var mv: int = maxi(3, m - 1)
		for sx in [1.0, -1.0]:
			for sz in [1.0, -1.0]:
				var prev := Vector3.ZERO
				for j in range(mv + 1):
					var t: float = lerpf(1.0, tb - 0.04, float(j) / float(mv))
					var q: float = hz * (1.0 - t)
					var x: float = sx * (xv - 0.3 - rh * 0.4)
					var p := Vector3(x, _rf_front(s, x, q) + rh * 0.28, sz * q)
					if j > 0:
						pk.beam(kit, rk, xf * prev, xf * p, rh * 0.7, rh * 0.6, rc, Vector3.ZERO, uvk)
					prev = p


# ======================================================================================
#  The townhouse (machiya)
# ======================================================================================

## A good width, depth and number of storeys for each variant.
static func machiya_default(variant: int) -> Vector3:
	match posmod(variant, 6):
		0:
			return Vector3(6.0, 9.5, 2)
		1:
			return Vector3(6.4, 9.0, 2)
		2:
			return Vector3(8.0, 10.5, 2)
		3:
			return Vector3(9.0, 10.0, 2)
		4:
			return Vector3(6.0, 8.0, 1)
	return Vector3(5.2, 7.0, 2)


## How far a variant reaches out past z = 0 toward the street (its eaves, pent roof, bamboo skirt, what stands before it).
static func machiya_extent(variant: int) -> float:
	match posmod(variant, 6):
		1:
			return 1.5
		2:
			return 1.6
		4:
			return 3.1
		5:
			return 1.25
	return 1.3


## A machiya: the wooden townhouse of the temple town's street. Front z = 0 facing +z, x 0..w, back -d; `floors` 1 or 2.
## Variants: 0 dwelling, 1 shop, 2 sake brewery, 3 ryokan, 4 sweet shop, 5 kura (a plastered storehouse, its gable to the
## street). The roof's verges reach 0.2 past x = 0 and x = w.
static func machiya(pk: PropKit, kit: Dictionary, w: float, d: float, floors: int, variant: int, rng: RandomNumberGenerator, labels: Array) -> void:
	var v: int = posmod(variant, 6)
	if v == 5:
		_kura(pk, kit, w, d, rng, labels)
		return
	var two: bool = floors >= 2 or v == 3
	var wood: Color = (WOODS[rng.randi() % WOODS.size()] as Color).lightened(rng.randf() * 0.08)
	var pi: int = rng.randi() % PLASTERS.size()
	if v == 2:
		pi = 0
	var plaster: Color = PLASTERS[pi]
	var pkey: String = "tsuchi" if (pi == 1 or pi == 3) else "shikkui"
	var roofc: Color = KAWARA.lerp(KAWARA_OLD, rng.randf()).darkened(rng.randf() * 0.12)
	var g: float = 2.5 + rng.randf() * 0.25
	var up: float = 0.0
	if two:
		up = 2.3 if v == 3 else 1.4 + rng.randf() * 0.4
	var over_f: float = 0.78 if two else 1.0
	var over_b := 0.5
	var pitch: float = 0.44 + rng.randf() * 0.08
	var hz: float = (d + over_f + over_b) * 0.5
	var cz: float = (over_f - d - over_b) * 0.5
	var rise: float = hz * pitch
	var wall_top: float = (g + 0.3 + up) if two else g + 0.28
	var s := roof_spec(R_KIRIZUMA, Vector3(w * 0.5, 0.0, cz), w * 0.5 + 0.2, hz, rise, "kawara", roofc)
	s.lift = 0.06 + rng.randf() * 0.05
	s.sori = 0.22 + rng.randf() * 0.12
	s.n = 6
	s.m = 3
	s.wall_hx = w * 0.5
	s.wall_zf = hz - over_f
	s.wall_zb = hz - over_b
	s.raft = 0.42
	s.raft_col = wood.darkened(0.1)
	s.under_col = wood.darkened(0.25)
	s.hafu_col = wood.darkened(0.15)
	s.ridge_h = 0.22 + rng.randf() * 0.08
	s.ridge_col = roofc.darkened(0.1)
	# The eave's height: the underside over the front wall meets the wall's top.
	s.c = Vector3(w * 0.5, wall_top - _rf_front(s, 0.0, hz - over_f) + float(s.thick), cz)
	jroof(pk, kit, s)
	var y_back: float = roof_under_y(s, Vector3(w * 0.5, 0, -d))
	# The footing, the side walls and the back.
	var sill := 0.14
	_mblock(pk, kit, "ishi", Vector3(-0.05, FOOT, -d - 0.05), Vector3(w + 0.05, sill, 0.05), GRANITE.darkened(0.12 + rng.randf() * 0.1))
	var board_h: float = [1.1, 1.9, y_back - 0.3][rng.randi() % 3]
	var boards: Color = wood.darkened(0.2 + rng.randf() * 0.2)
	for side in [[0.0, Vector3(-1, 0, 0), -1.0], [w, Vector3(1, 0, 0), 1.0]]:
		var sxw: float = side[0]
		var o: Vector3 = side[1]
		var a := Vector3(sxw, 0, -d) if o.x < 0.0 else Vector3(sxw, 0, 0)
		var b := Vector3(sxw, 0, 0) if o.x < 0.0 else Vector3(sxw, 0, -d)
		wall(pk, kit, "battens", a, b, sill, board_h, boards, o)
		wall(pk, kit, pkey, a, b, board_h, y_back, plaster, o)
		roof_gable(pk, kit, s, float(side[2]), -(hz - over_b), hz - over_f, y_back, pkey, plaster, 0.2)
		var sf := _wf(a, o)
		_rect(pk, kit, "hinoki", sf, 0.0, board_h - 0.06, d, board_h + 0.06, 0.0, TP, wood)
		_rect(pk, kit, "hinoki", sf, 0.0, y_back - 0.07, d, y_back + 0.07, 0.0, TP, wood)
		for pu in [0.0, d * 0.5 - 0.07, d - 0.14]:
			_rect(pk, kit, "hinoki", sf, pu, sill, pu + 0.14, board_h - 0.06, 0.0, TP, wood)
			_rect(pk, kit, "hinoki", sf, pu, board_h + 0.06, pu + 0.14, y_back - 0.07, 0.0, TP, wood)
	var bf := _wf(Vector3(w, 0, -d), Vector3(0, 0, -1))
	wall(pk, kit, "battens", Vector3(w, 0, -d), Vector3(0, 0, -d), sill, 1.9, boards, Vector3(0, 0, -1))
	wall(pk, kit, pkey, Vector3(w, 0, -d), Vector3(0, 0, -d), 1.9, y_back, plaster, Vector3(0, 0, -1))
	_rect(pk, kit, "hinoki", bf, 0.0, 1.84, w, 1.96, 0.0, TP, wood)
	_rect(pk, kit, "hinoki", bf, w * 0.2, sill, w * 0.2 + 0.9, 1.84, 0.0, TP, wood.lightened(0.06))
	if y_back > 3.4:
		_rect(pk, kit, "pane", bf, w * 0.6, 2.5, w * 0.6 + 0.9, 3.2, 0.0, 0.02, DARK)
		_bars(pk, kit, "hinoki", bf, w * 0.6, w * 0.6 + 0.9, 2.5, 3.2, 5, 0.05, 0.02, 0.06, wood)
	# The front.
	var ff := _wf(Vector3(0, 0, 0), Vector3(0, 0, 1))
	var st := {"wood": wood, "plaster": plaster, "pkey": pkey, "g": g, "sill": sill, "roofc": roofc, "v": v, "two": two}
	var door: Vector2 = _machiya_ground(pk, kit, ff, w, st, rng, labels)
	# The lintel beam over the ground storey and the corner posts.
	_rect(pk, kit, "hinoki", ff, 0.0, g, w, g + 0.2, 0.0, 0.07, wood)
	_rect(pk, kit, "hinoki", ff, 0.0, sill, 0.14, g, 0.0, 0.06, wood)
	_rect(pk, kit, "hinoki", ff, w - 0.14, sill, w, g, 0.0, 0.06, wood)
	var lamp_z := 0.55
	var lamp_y: float = g - 0.05
	if two:
		# The pent roof over the ground storey, on arms out of the posts and a beam along its eave.
		var hy: float = g + 0.52
		var hd: float = 1.02 + rng.randf() * 0.12
		var hs := pent_spec(-0.16, w + 0.16, 0.0, hy, hd, 0.36, "kawara", roofc)
		hs.n = 6
		hs.raft = 0.42
		hs.raft_col = wood.darkened(0.1)
		hs.under_col = wood.darkened(0.25)
		jroof(pk, kit, hs)
		# The flashing course where it meets the wall.
		_rect(pk, kit, "kawara", ff, -0.13, hy - 0.02, w + 0.13, hy + 0.1, 0.0, 0.09, roofc.darkened(0.12))
		var by: float = roof_under_y(hs, Vector3(w * 0.5, 0, hd - 0.2)) - float(hs.raft_d)
		_beam(pk, kit, "hinoki", Vector3(-0.1, by - 0.06, hd - 0.2), Vector3(w + 0.1, by - 0.06, hd - 0.2), 0.1, 0.12, wood, Vector3(0, 0, 1))
		var arms: Array = [0.07, w - 0.07, door.x - 0.07, door.y + 0.07]
		for ax in arms:
			_beam(pk, kit, "hinoki", Vector3(float(ax), by - 0.19, 0.0), Vector3(float(ax), by - 0.19, hd - 0.12), 0.09, 0.13, wood, Vector3(1, 0, 0))
		lamp_y = by - 0.12
		lamp_z = hd - 0.2
		_machiya_upper(pk, kit, ff, w, st, hy + 0.1, wall_top, rng, labels)
	else:
		_face(pk, kit, pkey, ff, 0.0, g + 0.2, w, wall_top, 0.0, plaster)
	# A paper lantern by the door on about half of them (always at the inn).
	if rng.randf() < 0.5 or v == 3:
		var lx: float = door.x - 0.32 if door.x > 0.9 else door.y + 0.32
		if v == 3:
			# Clear of the inn's long name board.
			lx = (door.x + door.y) * 0.5 - 2.25 if (door.x + door.y) * 0.5 > 2.7 else (door.x + door.y) * 0.5 + 2.25
		var lc: Color = [PAPER, PAPER_WARM, PAPER_RED, PAPER][rng.randi() % 4]
		var lh := 0.62
		chochin(pk, kit, Vector3(lx, lamp_y - 0.16 - lh * 0.5, lamp_z), 0.2, lh, lc, 8, VERMILION if lc != PAPER_RED else BLACK_LAC, Vector3(0, 0, 1), 0.12)


## The ground storey's front by variant. Returns the door's (u0, u1).
static func _machiya_ground(pk: PropKit, kit: Dictionary, ff: Transform3D, w: float, st: Dictionary, rng: RandomNumberGenerator, labels: Array) -> Vector2:
	var v: int = st.v
	var wood: Color = st.wood
	var g: float = st.g
	var sill: float = st.sill
	var a := 0.14
	var b: float = w - 0.14
	var flip: bool = rng.randf() < 0.5
	var dw: float = clampf([1.35, 1.5, 2.0, 2.1, 1.3][v], 1.0, (b - a) * 0.6)
	var du: float
	var bays: Array = []     # [u0, u1, kind]
	match v:
		0, 2, 3:
			var left: float = (b - a - dw) * ([0.42, 0.5, 0.5, 0.5][mini(v, 3)] + (rng.randf() - 0.5) * (0.2 if v == 0 else 0.0))
			du = a + left
			bays = [[a, du, "koshi"], [du, du + dw, "door"], [du + dw, b, "degoshi" if v == 0 and rng.randf() < 0.6 else "koshi"]]
		1:
			du = a + 0.0
			bays = [[a, a + dw, "door"], [a + dw, b, "shop"]]
		_:
			du = a
			bays = [[a, a + dw, "door"], [a + dw, b, "open"]]
	if flip:
		var fb: Array = []
		for bay in bays:
			fb.append([a + b - float(bay[1]), a + b - float(bay[0]), bay[2]])
		bays = fb
		du = a + b - du - dw
	var noren_col: Color = NOREN[rng.randi() % NOREN.size()]
	if v == 2:
		noren_col = INDIGO
	var crest_col: Color = PAPER if noren_col != NOREN[2] else INDIGO
	for bay in bays:
		var u0: float = bay[0]
		var u1: float = bay[1]
		# A post between bays.
		if u0 > a + 0.01:
			_rect(pk, kit, "hinoki", ff, u0 - 0.06, sill, u0 + 0.06, g, 0.0, 0.055, wood)
		var i0: float = u0 + (0.06 if u0 > a + 0.01 else 0.0)
		var i1: float = u1 - (0.06 if u1 < b - 0.01 else 0.0)
		match String(bay[2]):
			"koshi":
				_bay_koshi(pk, kit, ff, i0, i1, sill, g, st, rng, 0.0)
				_foot_dressing(pk, kit, ff, i0, i1, st, rng)
			"degoshi":
				_bay_koshi(pk, kit, ff, i0, i1, sill, g, st, rng, 0.24)
			"door":
				_bay_door(pk, kit, ff, i0, i1, sill, g, st, rng, noren_col if v != 0 else Color(0, 0, 0, 0), crest_col)
			"shop":
				_bay_shop(pk, kit, ff, i0, i1, sill, g, st, rng)
			"open":
				_bay_open(pk, kit, ff, i0, i1, sill, g, st, rng, noren_col, crest_col)
	var door := Vector2(du, du + dw)
	# What stands before the house.
	match v:
		2:
			# Straw-wrapped barrels by the door and the cedar ball over it.
			var bx: float = door.y + 0.55 if door.y + 1.4 < w else door.x - 0.55
			_komodaru(pk, kit, Vector3(bx, sill - 0.14, 0.42), 0.3, true)
			_komodaru(pk, kit, Vector3(bx + (0.64 if bx + 1.0 < w else -0.64), sill - 0.14, 0.42), 0.3, false)
			_komodaru(pk, kit, Vector3(bx + (0.32 if bx + 1.0 < w else -0.32), sill - 0.14 + 0.62, 0.42), 0.3, true)
			var sy: float = g + 0.05
			pk.tube(kit, "rope", Vector3((door.x + door.y) * 0.5, sy - 0.18, 0.62), Vector3((door.x + door.y) * 0.5, sy + 0.12, 0.62), 0.012, 0.012, 4, STRAW.darkened(0.3), false)
			_ball(pk, kit, "leaf", Vector3((door.x + door.y) * 0.5, sy - 0.45, 0.62), 0.3, Color(0.36, 0.33, 0.18).lerp(Color(0.24, 0.36, 0.16), rng.randf()), 8, 5)
			var su: float = (a + door.x) * 0.5 if door.x - a > b - door.y else (door.y + b) * 0.5
			_sign_board(pk, kit, ff, su, g - 0.42, 1.5, "SAKE", labels, wood, 0.34)
		3:
			_sign_board(pk, kit, ff, (door.x + door.y) * 0.5, g - 0.4, minf(dw + 1.6, 3.6), INN_NAMES[rng.randi() % INN_NAMES.size()], labels, wood, 0.3)
		1:
			_sign_board(pk, kit, ff, w * 0.5, g - 0.36, 1.7, SHOP_NAMES[rng.randi() % SHOP_NAMES.size()], labels, wood, 0.3)
			# A hanging board with the blossom, out from a post.
			var hx: float = 0.2 if door.x > w * 0.5 else w - 0.2
			_beam(pk, kit, "hinoki", Vector3(hx, g - 0.25, 0.0), Vector3(hx, g - 0.25, 0.75), 0.06, 0.06, wood, Vector3(1, 0, 0))
			var hb := _wf(Vector3(hx + 0.02, g - 1.25, 0.72), Vector3(1, 0, 0))
			_rect(pk, kit, "hinoki", hb, 0.0, 0.0, 0.42, 0.95, -0.04, 0.0, HINOKI.darkened(0.1), true)
			sakura_crest(pk, kit, "urushi", Vector3(hx + 0.02 + TP, g - 0.72, 0.51), Vector3(1, 0, 0), 0.16, VERMILION_OLD)
			sakura_crest(pk, kit, "urushi", Vector3(hx - 0.02 - TP, g - 0.72, 0.51), Vector3(-1, 0, 0), 0.16, VERMILION_OLD)
		4:
			_sign_board(pk, kit, ff, w * 0.5, g + 0.34 if not bool(st.two) else g - 0.36, 1.6, SWEET_NAMES[rng.randi() % SWEET_NAMES.size()], labels, wood, 0.3)
			# A bench under a red parasol before the open front.
			var ox: float = (float(bays[1][0]) + float(bays[1][1])) * 0.5 if not flip else (float(bays[0][0]) + float(bays[0][1])) * 0.5
			_felt_bench(pk, kit, Vector3(ox - 0.3, 0, 1.9), Vector3(0, 0, 1), 1.9, 0.55)
			_parasol(pk, kit, Vector3(ox + 1.0, 0, 2.0), 2.45, 1.05)
	return door


## A lattice bay (koshi): a boarded skirt, fine upright bars over a dark room, a plastered band above. With `proj` the
## lattice stands out as a box (degoshi).
static func _bay_koshi(pk: PropKit, kit: Dictionary, ff: Transform3D, u0: float, u1: float, v0: float, v1: float, st: Dictionary, rng: RandomNumberGenerator, proj: float) -> void:
	var wood: Color = st.wood
	var skirt: float = v0 + 0.42 + rng.randf() * 0.2
	var head: float = v1 - 0.28
	var wf: Transform3D = ff
	if proj > 0.0:
		# The box: its cheeks, its little roof board and its floor, on two brackets.
		wf = ff.translated_local(Vector3(0, 0, proj))
		_face(pk, kit, "pane", ff, u0, v0, u1, skirt + 0.1, 0.0, wood.darkened(0.5))
		for su in [[u0, -1.0], [u1, 1.0]]:
			var sf := _wf(ff * Vector3(float(su[0]), 0, proj if float(su[1]) > 0.0 else 0.0), Vector3(float(su[1]), 0, 0))
			_face(pk, kit, "hinoki", sf, 0.0, skirt + 0.1, proj, head + 0.05, 0.0, wood.darkened(0.1))
		_slab(pk, kit, "hinoki", ff, u0 - 0.03, u1 + 0.03, 0.0, proj + 0.05, head + 0.05, head + 0.1, wood)
		_slab(pk, kit, "hinoki", ff, u0 - 0.02, u1 + 0.02, 0.0, proj + 0.03, skirt + 0.04, skirt + 0.1, wood)
		for bu in [u0 + 0.12, u1 - 0.12]:
			_slab(pk, kit, "hinoki", ff, bu - 0.04, bu + 0.04, 0.0, proj - 0.02, skirt - 0.12, skirt + 0.04, wood.darkened(0.1))
		skirt += 0.1
	else:
		# The skirt: boards, TP proud, under a sill rail.
		_rect(pk, kit, "sugi", ff, u0, v0, u1, skirt - 0.07, 0.0, TP, wood.darkened(0.12))
	_rect(pk, kit, "hinoki", wf, u0, skirt - 0.07, u1, skirt, 0.0, 0.085, wood)
	_face(pk, kit, "pane", wf, u0, skirt, u1, head, 0.0, DARK)
	var n: int = maxi(3, int(round((u1 - u0) / (0.085 + rng.randf() * 0.04))))
	_bars(pk, kit, "hinoki", wf, u0, u1, skirt, head, n, minf(0.045, (u1 - u0) / float(n) * 0.52), 0.03, 0.07, wood)
	_hbars(pk, kit, "hinoki", wf, u0, u1, lerpf(skirt, head, 0.12), lerpf(skirt, head, 0.88), 2, 0.04, 0.0, 0.03, wood.darkened(0.1))
	_rect(pk, kit, "hinoki", wf, u0, head, u1, head + 0.06, 0.0, 0.085, wood)
	if proj <= 0.0:
		_face(pk, kit, st.pkey, ff, u0, head + 0.06, u1, v1, 0.0, st.plaster)
	else:
		_face(pk, kit, st.pkey, ff, u0, head + 0.1, u1, v1, 0.0, st.plaster)


## The curved bamboo skirt (inuyarai) before a lattice bay, or a row of kerb stones.
static func _foot_dressing(pk: PropKit, kit: Dictionary, ff: Transform3D, u0: float, u1: float, st: Dictionary, rng: RandomNumberGenerator) -> void:
	if u1 - u0 < 0.8:
		return
	if rng.randf() < 0.62:
		var reach := 0.42
		var top := 0.62
		var n: int = maxi(4, int(round((u1 - u0 - 0.1) / 0.11)))
		var arc: Array = []
		for k in range(4):
			var t: float = float(k) / 3.0
			# From the ground out in the street up to the wall: a quarter of an oval.
			arc.append(Vector2(reach * cos(t * PI * 0.5) + 0.03, top * sin(t * PI * 0.5) + 0.02))
		for i in range(n):
			var a: float = lerpf(u0 + 0.05, u1 - 0.05, float(i) / float(n))
			var b: float = lerpf(u0 + 0.05, u1 - 0.05, float(i + 1) / float(n)) - 0.012
			var col: Color = BAMBOO_DRY.darkened(0.3 + 0.12 * float(i % 2) + rng.randf() * 0.05)
			for k in range(3):
				var p: Vector2 = arc[k]
				var q: Vector2 = arc[k + 1]
				var nn: Vector3 = (ff.basis * Vector3(0, q.x - p.x, -(q.y - p.y))).normalized()
				if nn.z < 0.0:
					nn = -nn
				pk.quad(kit, "leaf", [ff * Vector3(a, p.y, p.x), ff * Vector3(b, p.y, p.x), ff * Vector3(b, q.y, q.x), ff * Vector3(a, q.y, q.x)], nn, col)
		# Two split canes binding it.
		for k in [1, 2]:
			var p2: Vector2 = arc[k]
			pk.tube(kit, "hinoki", ff * Vector3(u0 + 0.03, p2.y, p2.x + 0.02), ff * Vector3(u1 - 0.03, p2.y, p2.x + 0.02), 0.016, 0.016, 4, BAMBOO_DRY.darkened(0.3), true)
	else:
		var n2: int = maxi(2, int((u1 - u0) / 0.8))
		for i in range(n2):
			var a2: float = lerpf(u0, u1, float(i) / float(n2)) + 0.03
			var b2: float = lerpf(u0, u1, float(i + 1) / float(n2)) - 0.03
			_mblock(pk, kit, "ishi", ff * Vector3(a2, FOOT, 0.06), ff * Vector3(b2, 0.17 + 0.03 * float(i % 2), 0.3), GRANITE.darkened(0.05 + 0.1 * rng.randf()))


## The door bay: two sliding lattice doors (one a hand behind the other) under a transom, a stone step, and a noren
## (if `noren` has alpha).
static func _bay_door(pk: PropKit, kit: Dictionary, ff: Transform3D, u0: float, u1: float, v0: float, v1: float, st: Dictionary, rng: RandomNumberGenerator,
		noren: Color, crest: Color) -> void:
	var wood: Color = st.wood
	var head: float = minf(v0 + 1.95, v1 - 0.3)
	var mid: float = (u0 + u1) * 0.5
	_face(pk, kit, "pane", ff, u0, v0, u1, head, -0.12, DARK)
	var lit: bool = rng.randf() < 0.45 or int(st.v) == 3
	# The leaves: a frame, a boarded foot, a lattice over paper or the dark.
	for leaf in [[u0, mid + 0.03, 0.0], [mid - 0.03, u1, -0.05]]:
		var a: float = leaf[0]
		var b: float = leaf[1]
		var dz: float = leaf[2]
		var lf: Transform3D = ff.translated_local(Vector3(0, 0, dz))
		var fw := 0.06
		_rect(pk, kit, "hinoki", lf, a, v0, a + fw, head, -0.03, 0.03, wood.lightened(0.05))
		_rect(pk, kit, "hinoki", lf, b - fw, v0, b, head, -0.03, 0.03, wood.lightened(0.05))
		_rect(pk, kit, "hinoki", lf, a + fw, v0, b - fw, v0 + 0.1, -0.03, 0.025, wood.lightened(0.05))
		_rect(pk, kit, "hinoki", lf, a + fw, head - 0.08, b - fw, head, -0.03, 0.025, wood.lightened(0.05))
		_rect(pk, kit, "sugi", lf, a + fw, v0 + 0.1, b - fw, v0 + 0.62, -0.03, 0.01, wood.lightened(0.02))
		_rect(pk, kit, "hinoki", lf, a + fw, v0 + 0.62, b - fw, v0 + 0.68, -0.03, 0.025, wood.lightened(0.05))
		if lit:
			_face(pk, kit, "washi", lf, a + fw, v0 + 0.68, b - fw, head - 0.08, -0.012, PAPER_WARM.lerp(PAPER, 0.4))
		var nb: int = maxi(3, int(round((b - a - 2.0 * fw) / 0.11)))
		_bars(pk, kit, "hinoki", lf, a + fw, b - fw, v0 + 0.68, head - 0.08, nb, 0.022, -0.01, 0.018, wood.lightened(0.05))
		_hbars(pk, kit, "hinoki", lf, a + fw, b - fw, v0 + 0.72, head - 0.12, 3, 0.02, -0.01, 0.012, wood.lightened(0.05))
	# The head rail and the transom over it: a lattice (ranma) or plaster.
	_rect(pk, kit, "hinoki", ff, u0, head, u1, head + 0.1, 0.0, 0.07, wood)
	if v1 - head > 0.5 and rng.randf() < 0.6:
		_face(pk, kit, "pane", ff, u0, head + 0.1, u1, v1, 0.0, DARK)
		_bars(pk, kit, "hinoki", ff, u0, u1, head + 0.1, v1, maxi(4, int((u1 - u0) / 0.13)), 0.03, 0.0, 0.04, wood)
	else:
		_face(pk, kit, st.pkey, ff, u0, head + 0.1, u1, v1, 0.0, st.plaster)
	# The step.
	_mblock(pk, kit, "ishi", ff * Vector3(u0 + 0.05, FOOT, 0.06), ff * Vector3(u1 - 0.05, v0 - 0.02, 0.42), GRANITE.lightened(0.04))
	if noren.a > 0.0:
		var n: int = maxi(2, int(round((u1 - u0) / 0.5)))
		_noren(pk, kit, ff, u0 + 0.04, u1 - 0.04, head + 0.02, 0.5 + rng.randf() * 0.4 if int(st.v) != 4 else 0.38, n, noren, crest, 0.13)


## A shop's open bay: the dark shop behind, a sloping display of goods on a stand before it.
static func _bay_shop(pk: PropKit, kit: Dictionary, ff: Transform3D, u0: float, u1: float, v0: float, v1: float, st: Dictionary, rng: RandomNumberGenerator) -> void:
	var wood: Color = st.wood
	var head: float = v1 - 0.34
	_recess(pk, kit, ff, u0, v0, u1, head, 0.8, "pane", DARK, "hinoki", wood)
	_rect(pk, kit, "hinoki", ff, u0, head, u1, head + 0.08, 0.0, 0.07, wood)
	_face(pk, kit, st.pkey, ff, u0, head + 0.08, u1, v1, 0.0, st.plaster)
	# Shelves on the back wall with wares.
	var cols: Array = [VERMILION_OLD, INDIGO, HINOKI, PAPER, Color(0.30, 0.42, 0.24), PAPER_PINK, GOLD.darkened(0.2)]
	for k in range(2):
		var sy: float = v0 + 0.95 + 0.5 * float(k)
		_slab(pk, kit, "hinoki", ff, u0 + 0.1, u1 - 0.1, -0.78, -0.56, sy, sy + 0.035, wood.lightened(0.15))
		var x := u0 + 0.22
		while x < u1 - 0.25:
			var bw: float = 0.12 + rng.randf() * 0.12
			var bh: float = 0.12 + rng.randf() * 0.2
			_slab(pk, kit, "urushi", ff, x, x + bw, -0.74, -0.6, sy + 0.035, sy + 0.035 + bh, cols[rng.randi() % cols.size()])
			x += bw + 0.05 + rng.randf() * 0.12
	# The display: a stand sloping to the street, trays of goods on it.
	var z0 := 0.02
	var z1 := 0.72
	var ya: float = v0 + 0.72
	var yb: float = v0 + 0.42
	var a: float = u0 + 0.08
	var b: float = u1 - 0.08
	var nn := Vector3(0, z1 - z0, ya - yb).normalized()
	pk.quad(kit, "hinoki", [ff * Vector3(a, yb, z1), ff * Vector3(b, yb, z1), ff * Vector3(b, ya, z0), ff * Vector3(a, ya, z0)], ff.basis * nn, HINOKI.darkened(0.25),
			[Vector2(a, 0) * uvk, Vector2(b, 0) * uvk, Vector2(b, 0.8) * uvk, Vector2(a, 0.8) * uvk])
	_rect(pk, kit, "sugi", ff.translated_local(Vector3(0, 0, z1)), a + 0.012, v0 - 0.14, b - 0.012, yb, -0.02, 0.0, wood.lightened(0.04))
	for su in [[a, -1.0], [b, 1.0]]:
		var sf := _wf(ff * Vector3(float(su[0]), 0, z1 if float(su[1]) > 0.0 else z0), Vector3(float(su[1]), 0, 0))
		var ol := PackedVector2Array([Vector2(0, v0 - 0.14), Vector2(z1 - z0, v0 - 0.14), Vector2(z1 - z0, yb if float(su[1]) > 0.0 else ya), Vector2(0, ya if float(su[1]) > 0.0 else yb)])
		_prism(pk, kit, "sugi", sf, ol, -0.02, 0.0, wood.lightened(0.04), false, false)
	var nt: int = maxi(2, int((b - a) / 0.55))
	var up: Vector3 = ff.basis * nn
	var along: Vector3 = (ff.basis * Vector3(0, ya - yb, -(z1 - z0))).normalized()   # up the slope
	for i in range(nt):
		for r in range(2):
			var cu: float = lerpf(a, b, (float(i) + 0.5) / float(nt))
			var t: float = 0.28 + 0.44 * float(r)
			var c: Vector3 = ff * Vector3(cu, lerpf(yb, ya, t), lerpf(z1, z0, t))
			var tw: float = (b - a) / float(nt) * 0.4
			var tray: Color = [BLACK_LAC, wood.lightened(0.2), VERMILION_OLD][rng.randi() % 3]
			pk.box(kit, "urushi", Transform3D(Basis(ff.basis.x, up, -along), c + up * 0.02), Vector3(tw * 2.0, 0.035, 0.26), tray)
			var gc: Color = cols[rng.randi() % cols.size()]
			for q in range(3):
				_blob(pk, kit, "urushi", c + up * 0.065 + ff.basis.x * (tw * 0.6 * float(q - 1)), Vector3(tw * 0.26, 0.045, 0.08), gc.lightened(0.1 * float(q % 2)))


## The sweet shop's open bay: a raised matted floor behind a low noren, a counter with a tray of dango.
static func _bay_open(pk: PropKit, kit: Dictionary, ff: Transform3D, u0: float, u1: float, v0: float, v1: float, st: Dictionary, rng: RandomNumberGenerator,
		noren: Color, crest: Color) -> void:
	var wood: Color = st.wood
	var head: float = v1 - 0.3
	_recess(pk, kit, ff, u0, v0, u1, head, 1.3, "pane", DARK.lightened(0.04), "hinoki", wood)
	_rect(pk, kit, "hinoki", ff, u0, head, u1, head + 0.08, 0.0, 0.07, wood)
	_face(pk, kit, st.pkey, ff, u0, head + 0.08, u1, v1, 0.0, st.plaster)
	# The floor inside, with a tatami-coloured top and a boarded front.
	_slab(pk, kit, "hinoki", ff, u0, u1, -1.28, -0.04, v0, v0 + 0.4, wood.lightened(0.1))
	pk.quad(kit, "rope", [ff * Vector3(u0, v0 + 0.405, -1.28), ff * Vector3(u1, v0 + 0.405, -1.28), ff * Vector3(u1, v0 + 0.405, -0.1), ff * Vector3(u0, v0 + 0.405, -0.1)], Vector3.UP,
			STRAW.lerp(BAMBOO, 0.3))
	# A paper screen across the back, lit.
	_face(pk, kit, "washi", ff, u0 + 0.15, v0 + 0.5, u1 - 0.15, head - 0.2, -1.27, PAPER_WARM.lerp(PAPER, 0.5))
	_bars(pk, kit, "hinoki", ff.translated_local(Vector3(0, 0, -1.27)), u0 + 0.15, u1 - 0.15, v0 + 0.5, head - 0.2, maxi(3, int((u1 - u0) / 0.45)), 0.03, 0.0, 0.025, wood)
	_hbars(pk, kit, "hinoki", ff.translated_local(Vector3(0, 0, -1.27)), u0 + 0.15, u1 - 0.15, v0 + 0.5, head - 0.2, 3, 0.03, 0.0, 0.02, wood)
	# The counter at the front with a stand of dango and a tea urn.
	var cu: float = lerpf(u0, u1, 0.3)
	_slab(pk, kit, "hinoki", ff, u0 + 0.1, u0 + (u1 - u0) * 0.55, 0.0, 0.34, v0 + 0.62, v0 + 0.68, HINOKI.darkened(0.2))
	_slab(pk, kit, "sugi", ff, u0 + 0.14, u0 + (u1 - u0) * 0.55 - 0.04, 0.02, 0.3, v0 - 0.14, v0 + 0.62, wood.lightened(0.05))
	for k in range(4):
		var p: Vector3 = ff * Vector3(cu - 0.3 + 0.2 * float(k), v0 + 0.68, 0.17)
		pk.tube(kit, "hinoki", p, p + Vector3(0, 0.26, 0), 0.008, 0.008, 3, BAMBOO_DRY, false)
		for q in range(3):
			_blob(pk, kit, "urushi", p + Vector3(0, 0.1 + 0.065 * float(q), 0), Vector3(0.035, 0.032, 0.035), [PAPER_PINK, PAPER, Color(0.55, 0.70, 0.36)][q])
	pk.lathe(kit, "urushi", ff * Vector3(u0 + (u1 - u0) * 0.47, v0 + 0.68, 0.17), [Vector2(0.001, 0.0), Vector2(0.09, 0.0), Vector2(0.12, 0.1), Vector2(0.1, 0.22), Vector2(0.04, 0.26), Vector2(0.001, 0.27)],
			7, Color(0.10, 0.10, 0.11))
	if noren.a > 0.0:
		_noren(pk, kit, ff, u0 + 0.04, u1 - 0.04, head - 0.02, 0.4, maxi(3, int(round((u1 - u0) / 0.6))), noren, crest, 0.13)


## The low upper storey: plaster with insect-cage windows (mushiko mado), or the inn's balcony before lit shoji.
static func _machiya_upper(pk: PropKit, kit: Dictionary, ff: Transform3D, w: float, st: Dictionary, y0: float, y1: float, rng: RandomNumberGenerator, _labels: Array) -> void:
	var wood: Color = st.wood
	var plaster: Color = st.plaster
	var pkey: String = st.pkey
	var v: int = st.v
	# Corner posts and the plate under the eaves.
	_rect(pk, kit, "hinoki", ff, 0.0, y0, 0.14, y1 - 0.12, 0.0, 0.05, wood)
	_rect(pk, kit, "hinoki", ff, w - 0.14, y0, w, y1 - 0.12, 0.0, 0.05, wood)
	_rect(pk, kit, "hinoki", ff, 0.0, y1 - 0.12, w, y1, 0.0, 0.07, wood)
	var a := 0.14
	var b: float = w - 0.14
	var top: float = y1 - 0.12
	if v == 3:
		# The inn: shoji screens the width of the house behind a railed balcony.
		var floor_y: float = y0 + 0.14
		var sh0: float = floor_y + 0.1
		var sh1: float = top - 0.28
		_face(pk, kit, pkey, ff, a, y0, b, sh0, 0.0, plaster)
		_face(pk, kit, pkey, ff, a, sh1 + 0.07, b, top, 0.0, plaster)
		_rect(pk, kit, "hinoki", ff, a, sh1, b, sh1 + 0.07, 0.0, 0.05, wood)
		var np: int = maxi(3, int(round((b - a) / 0.95)))
		for i in range(np):
			var pa: float = lerpf(a, b, float(i) / float(np))
			var pb: float = lerpf(a, b, float(i + 1) / float(np))
			var lit: bool = rng.randf() < 0.75
			_face(pk, kit, "washi" if lit else "pane", ff, pa, sh0, pb, sh1, -0.02, PAPER_WARM.lerp(PAPER, rng.randf() * 0.5) if lit else PAPER.darkened(0.25))
			_rect(pk, kit, "hinoki", ff, pa - 0.025, sh0, pa + 0.025, sh1, -0.02, 0.03, wood.lightened(0.08))
			_bars(pk, kit, "hinoki", ff, pa + 0.025, pb - 0.025, sh0, sh1, 3, 0.018, -0.02, 0.008, wood.lightened(0.1))
			_hbars(pk, kit, "hinoki", ff, pa + 0.025, pb - 0.025, sh0, sh1, 5, 0.018, -0.02, 0.004, wood.lightened(0.1))
		# The balcony: a floor on brackets, posts, three rails.
		var bz := 0.5
		_slab(pk, kit, "hinoki", ff, a - 0.05, b + 0.05, 0.0, bz, floor_y - 0.07, floor_y, wood.lightened(0.05))
		var nposts: int = maxi(3, int(round((b - a) / 1.3)))
		for i in range(nposts + 1):
			var px: float = lerpf(a, b, float(i) / float(nposts))
			var pp: Vector3 = ff * Vector3(px, 0, bz - 0.05)
			_post(pk, kit, "hinoki", pp.x, pp.z, floor_y, floor_y + 0.78, 0.07, wood, true)
			_slab(pk, kit, "hinoki", ff, px - 0.035, px + 0.035, 0.0, bz - 0.1, floor_y - 0.2, floor_y - 0.07, wood.darkened(0.1))
		for ry in [0.2, 0.47, 0.72]:
			_beam(pk, kit, "hinoki", ff * Vector3(a - 0.1, floor_y + ry, bz - 0.05), ff * Vector3(b + 0.1, floor_y + ry, bz - 0.05), 0.05, 0.05, wood.lightened(0.04), Vector3(0, 0, 1))
		return
	# One or two mushiko windows: an oblong opening with rounded plaster bars, a hand deep.
	var nwin: int = 1 if w < 6.6 or rng.randf() < 0.35 else 2
	var ww: float = clampf((b - a) / float(nwin) * (0.5 + rng.randf() * 0.14), 0.9, 2.4)
	var wh: float = clampf((top - y0) * 0.42, 0.4, 0.7)
	var wy: float = y0 + (top - y0) * 0.5 - wh * 0.5 + 0.05
	var ops: Array = []
	for i in range(nwin):
		var c: float = lerpf(a, b, (float(i) + 0.5) / float(nwin))
		ops.append([c - ww * 0.5, wy, c + ww * 0.5, wy + wh])
	_holed(pk, kit, pkey, ff, a, y0, b, top, ops, plaster)
	for o in ops:
		_recess(pk, kit, ff, o[0], o[1], o[2], o[3], 0.14, "pane", DARK, pkey, plaster)
		var nb: int = maxi(5, int(round((float(o[2]) - float(o[0])) / 0.17)))
		_bars(pk, kit, pkey, ff, float(o[0]) + 0.03, float(o[2]) - 0.03, o[1], o[3], nb, 0.075, -0.1, -0.02, plaster.darkened(0.04))
	# A middle post on the wider fronts.
	if nwin == 2:
		_rect(pk, kit, "hinoki", ff, w * 0.5 - 0.06, y0, w * 0.5 + 0.06, top, 0.0, 0.045, wood)


## A signboard on the front: a framed board at (u, v) (its middle), `bw` wide, the name on it.
static func _sign_board(pk: PropKit, kit: Dictionary, ff: Transform3D, u: float, v: float, bw: float, text: String, labels: Array, wood: Color, cap: float) -> void:
	var bh: float = cap * 1.9
	var light: bool = (text.length() % 2) == 0
	var board: Color = HINOKI.darkened(0.12) if light else wood.darkened(0.35)
	_rect(pk, kit, "hinoki", ff, u - bw * 0.5, v - bh * 0.5, u + bw * 0.5, v + bh * 0.5, 0.075, 0.12, board)
	_rect(pk, kit, "hinoki", ff, u - bw * 0.5 - 0.05, v + bh * 0.5, u + bw * 0.5 + 0.05, v + bh * 0.5 + 0.06, 0.07, 0.15, wood.darkened(0.2))
	_rect(pk, kit, "hinoki", ff, u - bw * 0.5 - 0.05, v - bh * 0.5 - 0.05, u + bw * 0.5 + 0.05, v - bh * 0.5, 0.07, 0.14, wood.darkened(0.2))
	var p: Vector3 = ff * Vector3(u, v, 0.15)
	labels.append([text, p, ff.basis.z.normalized(), cap, BLACK_LAC if light else GOLD, bw - 0.2])


## A straw-wrapped sake barrel (komodaru) standing at `p`: a bellied drum bound with rope, a white face with the blossom.
static func _komodaru(pk: PropKit, kit: Dictionary, p: Vector3, r: float, crest: bool) -> void:
	var h: float = r * 2.0
	pk.lathe(kit, "rope", p, [Vector2(0.001, 0.0), Vector2(r * 0.86, 0.0), Vector2(r, h * 0.25), Vector2(r, h * 0.75), Vector2(r * 0.86, h), Vector2(0.001, h)], 10, STRAW)
	for y in [0.2, 0.8]:
		pk.tube(kit, "rope", p + Vector3(0, h * y - 0.02, 0), p + Vector3(0, h * y + 0.02, 0), r * 1.03, r * 1.03, 10, STRAW.darkened(0.3), false)
	var f := _wf(p + Vector3(0, 0, r * 0.985), Vector3(0, 0, 1))
	_face(pk, kit, "urushi", f, -r * 0.5, h * 0.3, r * 0.5, h * 0.72, 0.0, PAPER)
	if crest:
		sakura_crest(pk, kit, "urushi", f * Vector3(0, h * 0.51, TP), Vector3(0, 0, 1), r * 0.3, VERMILION)
	else:
		_face(pk, kit, "urushi", f, -r * 0.3, h * 0.42, r * 0.3, h * 0.6, TP, INDIGO)


## The kura: a plastered fireproof storehouse, its gable to the street. Thick white walls on a namako skirt (black tiles
## in a white diamond grid), a stepped doorway under its own little tiled roof, a shuttered window in the gable.
static func _kura(pk: PropKit, kit: Dictionary, w: float, d: float, rng: RandomNumberGenerator, labels: Array) -> void:
	var white: Color = SHIKKUI.darkened(rng.randf() * 0.06)
	var roofc: Color = KAWARA.lerp(KAWARA_OLD, rng.randf())
	var eave: float = 4.6 + rng.randf() * 0.5
	var skirt: float = 1.25 + rng.randf() * 0.4
	var over := 0.42
	var hz: float = w * 0.5 + over
	var rise: float = hz * 0.62
	# Ridge along z: the spec's x runs back from the street.
	var s := roof_spec(R_KIRIZUMA, Vector3(w * 0.5, eave, -d * 0.5), d * 0.5 + 0.3, hz, rise, "kawara", roofc)
	s.yaw = PI * 0.5
	s.lift = 0.05
	s.sori = 0.2
	s.thick = 0.18
	s.n = 5
	s.m = 3
	s.under_key = "shikkui"
	s.under_col = white.darkened(0.12)
	s.hafu_key = "shikkui"
	s.hafu_col = white
	s.crest = Color(0, 0, 0, 0)
	s.ridge_h = 0.3
	s.ridge_col = roofc.darkened(0.1)
	var wall_top: float = eave + _rf_front(s, 0.0, hz - over) - float(s.thick)
	jroof(pk, kit, s)
	_mblock(pk, kit, "ishi", Vector3(-0.08, FOOT, -d - 0.08), Vector3(w + 0.08, 0.3, 0.08), GRANITE.darkened(0.15))
	# The walls, the gables (front and back) and the thick band (hachimaki) under the eaves.
	wall(pk, kit, "shikkui", Vector3(0, 0, -d), Vector3(0, 0, 0), 0.3, wall_top, white, Vector3(-1, 0, 0))
	wall(pk, kit, "shikkui", Vector3(w, 0, 0), Vector3(w, 0, -d), 0.3, wall_top, white, Vector3(1, 0, 0))
	wall(pk, kit, "shikkui", Vector3(0, 0, 0), Vector3(w, 0, 0), 0.3, wall_top, white, Vector3(0, 0, 1))
	wall(pk, kit, "shikkui", Vector3(w, 0, -d), Vector3(0, 0, -d), 0.3, wall_top, white, Vector3(0, 0, -1))
	roof_gable(pk, kit, s, -1.0, -w * 0.5, w * 0.5, wall_top, "shikkui", white, 0.3)
	roof_gable(pk, kit, s, 1.0, -w * 0.5, w * 0.5, wall_top, "shikkui", white, 0.3)
	for side in [[Vector3(0, 0, -d), Vector3(-1, 0, 0)], [Vector3(w, 0, 0), Vector3(1, 0, 0)]]:
		var sf := _wf(side[0], side[1])
		_rect(pk, kit, "shikkui", sf, -0.06, wall_top - 0.34, d + 0.06, wall_top - 0.02, 0.0, 0.07, white.darkened(0.03))
		_namako(pk, kit, sf, 0.0, 0.3, d, skirt, rng)
	var ff := _wf(Vector3(0, 0, 0), Vector3(0, 0, 1))
	var dw: float = minf(1.5, w * 0.34)
	var du: float = w * 0.5 - dw * 0.5
	var dh := 2.25
	_namako(pk, kit, ff, 0.0, 0.3, du - 0.36, skirt, rng)
	_namako(pk, kit, ff, du + dw + 0.36, 0.3, w, skirt, rng)
	# The doorway: three steps of plaster round a dark opening with a lattice door, the heavy leaves swung open.
	for k in range(3):
		var e: float = 0.3 - 0.1 * float(k)
		var dpt: float = 0.05 + 0.05 * float(k)
		_rect(pk, kit, "shikkui", ff, du - e - 0.02, 0.3, du - e + 0.1, 0.3 + dh + e, 0.0, dpt, white.darkened(0.02 * float(k)))
		_rect(pk, kit, "shikkui", ff, du + dw + e - 0.1, 0.3, du + dw + e + 0.02, 0.3 + dh + e, 0.0, dpt, white.darkened(0.02 * float(k)))
		_rect(pk, kit, "shikkui", ff, du - e + 0.1, 0.3 + dh + e - 0.12, du + dw + e - 0.1, 0.3 + dh + e, 0.0, dpt, white.darkened(0.02 * float(k)))
	_face(pk, kit, "pane", ff, du, 0.3, du + dw, 0.3 + dh, 0.02, DARK)
	var wood: Color = WOODS[rng.randi() % WOODS.size()]
	_bars(pk, kit, "hinoki", ff, du, du + dw, 0.3, 0.3 + dh, 7, 0.07, 0.02, 0.06, wood)
	_hbars(pk, kit, "hinoki", ff, du, du + dw, 0.4, 0.3 + dh, 4, 0.07, 0.02, 0.05, wood)
	for su in [-1.0, 1.0]:
		# An open leaf: a thick slab standing out from the jamb, its stepped edge to the street.
		var hx: float = du - 0.34 if su < 0.0 else du + dw + 0.34
		var lf := _wf(Vector3(hx, 0, 0.16), Vector3(su, 0, 0))
		var z0: float = 0.0 if su > 0.0 else -0.78
		_rect(pk, kit, "shikkui", lf, z0, 0.32, z0 + 0.78, 0.3 + dh, -0.14, 0.0, white.darkened(0.05), true)
		_rect(pk, kit, "shikkui", lf, z0 + 0.08, 0.4, z0 + 0.7, 0.3 + dh - 0.08, 0.0, 0.05, white.darkened(0.08))
		_rect(pk, kit, "urushi", lf, z0 + 0.3, 1.2, z0 + 0.48, 1.38, 0.05, 0.08, BLACK_LAC)
	_mblock(pk, kit, "ishi", Vector3(du - 0.4, FOOT, 0.08), Vector3(du + dw + 0.4, 0.2, 0.75), GRANITE)
	# Its little roof on two brackets.
	var hs := pent_spec(du - 0.75, du + dw + 0.75, 0.0, 0.3 + dh + 0.95, 0.95, 0.4, "kawara", roofc)
	hs.n = 4
	hs.under_key = "shikkui"
	hs.under_col = white.darkened(0.15)
	jroof(pk, kit, hs)
	_rect(pk, kit, "kawara", ff, du - 0.72, 0.3 + dh + 0.92, du + dw + 0.72, 0.3 + dh + 1.03, 0.0, 0.09, roofc.darkened(0.12))
	for bu in [du - 0.55, du + dw + 0.55]:
		var by: float = roof_under_y(hs, Vector3(bu, 0, 0.5))
		var bfr := _wf(Vector3(bu - 0.05, 0, 0), Vector3(1, 0, 0))
		_prism(pk, kit, "shikkui", bfr, PackedVector2Array([Vector2(0, by - 0.55), Vector2(-0.12, by - 0.5), Vector2(-0.8, by - 0.06), Vector2(-0.8, by + 0.02), Vector2(0, by + 0.25)]), 0.0, 0.1,
				white.darkened(0.04), true)
	# The gable's window: a small barred opening between stepped shutters, and the blossom under the ridge.
	var wy: float = minf(wall_top + rise * 0.1, eave + 0.2)
	var wc: float = w * 0.5
	_rect(pk, kit, "shikkui", ff, wc - 0.62, wy - 0.12, wc + 0.62, wy + 0.95, 0.0, 0.06, white.darkened(0.03))
	_rect(pk, kit, "pane", ff, wc - 0.38, wy, wc + 0.38, wy + 0.8, 0.06, 0.075, DARK)
	_bars(pk, kit, "urushi", ff, wc - 0.38, wc + 0.38, wy, wy + 0.8, 4, 0.035, 0.075, 0.1, BLACK_LAC)
	for su in [-1.0, 1.0]:
		var sx0: float = wc + su * 0.62 - (0.42 if su < 0.0 else 0.0)
		_rect(pk, kit, "shikkui", ff, sx0, wy - 0.06, sx0 + 0.42, wy + 0.86, 0.06, 0.16, white)
		_rect(pk, kit, "shikkui", ff, sx0 + 0.07, wy + 0.02, sx0 + 0.35, wy + 0.78, 0.16, 0.2, white.darkened(0.06))
	sakura_crest(pk, kit, "urushi", Vector3(wc, minf(wy + 1.5, eave + rise - 0.75), TP), Vector3(0, 0, 1), 0.3, KAWARA_OLD.darkened(0.2))
	if rng.randf() < 0.5:
		labels.append(["KURA", Vector3(wc, 0.3 + dh + 0.52, 0.2), Vector3(0, 0, 1), 0.2, BLACK_LAC, 1.2])
		_rect(pk, kit, "hinoki", ff, wc - 0.6, 0.3 + dh + 0.36, wc + 0.6, 0.3 + dh + 0.68, 0.16, 0.19, HINOKI.darkened(0.1))


## A namako wall: black tiles standing 3cm proud, white rounded joints in a diamond grid over them.
static func _namako(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, _rng: RandomNumberGenerator) -> void:
	if u1 - u0 < 0.3:
		return
	_rect(pk, kit, "urushi", wf, u0, v0, u1, v1, 0.0, 0.03, Color(0.10, 0.10, 0.11))
	var area := PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
	var step := 0.46
	var nf: Vector3 = wf.basis.z.normalized()
	var k := -int((v1 - v0) / step) - 2
	var kmax: int = int((u1 - u0) / step) + 2
	while k <= kmax:
		for dir in [1.0, -1.0]:
			var bx: float = u0 + float(k) * step if dir > 0.0 else u1 - float(k) * step
			var t := Vector2(dir, 1.0).normalized()
			var nn := Vector2(-t.y, t.x) * 0.03
			var p0 := Vector2(bx, v0) - t * 0.5
			var p1 := Vector2(bx, v0) + t * ((v1 - v0) * 1.5 + 1.0)
			var band := PackedVector2Array([p0 - nn, p1 - nn, p1 + nn, p0 + nn])
			for piece in Geometry2D.intersect_polygons(band, area):
				var pl: PackedVector2Array = piece
				if pl.size() < 3:
					continue
				var tris := Geometry2D.triangulate_polygon(pl)
				# The two directions' joints at their own depths: they cross without sharing a plane.
				var dz: float = 0.045 if dir > 0.0 else 0.057
				for i in range(0, tris.size(), 3):
					pk.tri(kit, "shikkui", wf * Vector3(pl[tris[i]].x, pl[tris[i]].y, dz), wf * Vector3(pl[tris[i + 1]].x, pl[tris[i + 1]].y, dz),
							wf * Vector3(pl[tris[i + 2]].x, pl[tris[i + 2]].y, dz), nf, nf, nf, SHIKKUI, nf, pl[tris[i]] * uvk, pl[tris[i + 1]] * uvk, pl[tris[i + 2]] * uvk)
		k += 1
	_rect(pk, kit, "shikkui", wf, u0, v1, u1, v1 + 0.09, 0.0, 0.07, SHIKKUI.darkened(0.03))

# ======================================================================================
#  Temple carpentry: columns, bracket clusters, railings, framed walls
# ======================================================================================

## A round column at (x, z) from y0 to y1 on a stone base `base_r` across; with `weather` its foot is bare, grey timber
## (the paint goes from the ground up).
static func _column(pk: PropKit, kit: Dictionary, x: float, z: float, y0: float, y1: float, r: float, col: Color, key := "urushi", segs := 10, base_r := 0.0,
		weather := 0.0) -> void:
	var c := Vector3(x, 0, z)
	var ys: float = y0
	if base_r > 0.0:
		pk.lathe(kit, "ishi", Vector3(x, y0, z), [Vector2(base_r, -0.3), Vector2(base_r, 0.08), Vector2(base_r * 0.86, 0.18), Vector2(0.001, 0.18)], segs, GRANITE.darkened(0.08))
		ys = y0 + 0.16
	if weather > 0.0:
		_round(pk, kit, "hinoki", c, ys, y0 + weather + 0.03, r * 1.004, r * 1.004, segs, Color(0.46, 0.38, 0.31))
		_round(pk, kit, key, c, y0 + weather, y1, r, r * 0.94, segs, col)
	else:
		_round(pk, kit, key, c, ys, y1, r, r * 0.94, segs, col)


## A bracket cluster (tokyo, simplified) on a column's head at `p`, reaching toward `out`: the bearing block, an arm along
## the wall with its blocks, and with two tiers an arm out to a second, outer arm that carries the eave purlin. Its top
## is 1.04 * sc over p (0.66 * sc with one tier); the purlin's line is 0.8 * sc out.
static func _bracket(pk: PropKit, kit: Dictionary, key: String, p: Vector3, out: Vector3, sc: float, col: Color, tiers := 2) -> void:
	var o: Vector3 = out.normalized()
	var side: Vector3 = Vector3.UP.cross(o).normalized()
	var b := Basis(side, Vector3.UP, o)
	var dk: Color = col.darkened(0.12)
	pk.box(kit, key, Transform3D(b, p + Vector3(0, 0.14 * sc, 0)), Vector3(0.5, 0.28, 0.5) * sc, dk, uvk)
	pk.box(kit, key, Transform3D(b, p + Vector3(0, 0.38 * sc, 0)), Vector3(1.5, 0.2, 0.2) * sc, col, uvk)
	if tiers < 2:
		for k in [-1.0, 0.0, 1.0]:
			pk.box(kit, key, Transform3D(b, p + Vector3(0, 0.57 * sc, 0) + side * (0.6 * sc * k)), Vector3(0.28, 0.18, 0.28) * sc, dk, uvk)
		return
	pk.box(kit, key, Transform3D(b, p + Vector3(0, 0.385 * sc, 0) + o * (0.36 * sc)), Vector3(0.19, 0.2, 1.1) * sc, col, uvk)
	pk.box(kit, key, Transform3D(b, p + Vector3(0, 0.57 * sc, 0) + o * (0.8 * sc)), Vector3(0.3, 0.18, 0.3) * sc, dk, uvk)
	pk.box(kit, key, Transform3D(b, p + Vector3(0, 0.76 * sc, 0) + o * (0.8 * sc)), Vector3(1.5, 0.2, 0.2) * sc, col, uvk)
	for k in [-1.0, 0.0, 1.0]:
		pk.box(kit, key, Transform3D(b, p + Vector3(0, 0.95 * sc, 0) + o * (0.8 * sc) + side * (0.6 * sc * k)), Vector3(0.28, 0.18, 0.28) * sc, dk, uvk)


## Bracket clusters on every column of a rectangle of columns (xs by zs, the perimeter only) at height y, the purlin
## they carry (a ring 0.8 * sc out, under y + 1.04 * sc) and the plastered frieze between them on the column line.
static func _bracket_ring(pk: PropKit, kit: Dictionary, key: String, xs: Array, zs: Array, y: float, sc: float, col: Color, frieze := SHIKKUI, lite := false) -> void:
	var x0: float = xs[0]
	var x1: float = xs[xs.size() - 1]
	var z0: float = zs[0]
	var z1: float = zs[zs.size() - 1]
	for x in xs:
		for z in zs:
			var ox: float = (-1.0 if x == x0 else 0.0) + (1.0 if x == x1 else 0.0)
			var oz: float = (-1.0 if z == z0 else 0.0) + (1.0 if z == z1 else 0.0)
			if ox == 0.0 and oz == 0.0:
				continue
			_bracket(pk, kit, key, Vector3(x, y, z), Vector3(ox, 0, oz), sc, col, 1 if lite and (ox == 0.0 or oz == 0.0) else 2)
	var off: float = 0.8 * sc
	var top: float = y + 1.04 * sc
	var pw: float = 0.24 * sc
	for sz in [z0 - off, z1 + off]:
		_beam(pk, kit, key, Vector3(x0 - off - pw, top - pw * 0.5, sz), Vector3(x1 + off + pw, top - pw * 0.5, sz), pw, pw, col, Vector3(0, 0, 1))
	for sx in [x0 - off, x1 + off]:
		_beam(pk, kit, key, Vector3(sx, top - pw * 0.5, z0 - off + pw * 0.5), Vector3(sx, top - pw * 0.5, z1 + off - pw * 0.5), pw, pw, col, Vector3(1, 0, 0))
	if frieze.a > 0.0:
		wall(pk, kit, "shikkui", Vector3(x0, 0, z1), Vector3(x1, 0, z1), y, top, frieze, Vector3(0, 0, 1))
		wall(pk, kit, "shikkui", Vector3(x1, 0, z0), Vector3(x0, 0, z0), y, top, frieze, Vector3(0, 0, -1))
		wall(pk, kit, "shikkui", Vector3(x1, 0, z1), Vector3(x1, 0, z0), y, top, frieze, Vector3(1, 0, 0))
		wall(pk, kit, "shikkui", Vector3(x0, 0, z0), Vector3(x0, 0, z1), y, top, frieze, Vector3(-1, 0, 0))


## A temple railing (koran) from a to b (level): posts, a foot rail, a middle rail and a round top rail that runs on
## past both ends.
static func _koran(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, h: float, col: Color, over := 0.2) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 0.2:
		return
	var dir: Vector3 = d / l
	var n: int = maxi(int(ceil(l / 1.6)), 1)
	for i in range(n + 1):
		var p: Vector3 = a + d * (float(i) / float(n))
		_post(pk, kit, key, p.x, p.z, a.y, a.y + h - 0.03, 0.09, col)
	var side: Vector3 = Vector3.UP.cross(dir).normalized()
	_beam(pk, kit, key, a + Vector3(0, 0.1, 0), b + Vector3(0, 0.1, 0), 0.07, 0.09, col, side)
	_beam(pk, kit, key, a + Vector3(0, h * 0.56, 0), b + Vector3(0, h * 0.56, 0), 0.05, 0.07, col, side)
	pk.tube(kit, key, a + Vector3(0, h, 0) - dir * over, b + Vector3(0, h, 0) + dir * over, 0.05, 0.05, 6, col, true)


## A barred temple window (renji mado) in a wall frame: a dark opening, green bars, a timber frame.
static func _renji(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, key: String, col: Color) -> void:
	_face(pk, kit, "pane", wf, u0, v0, u1, v1, 0.02, DARK)
	_bars(pk, kit, "urushi", wf, u0, u1, v0, v1, maxi(4, int(round((u1 - u0) / 0.2))), 0.07, 0.02, 0.07, RENJI_GREEN)
	var fw := 0.1
	_rect(pk, kit, key, wf, u0 - fw, v0 - fw, u1 + fw, v0, 0.0, 0.1, col)
	_rect(pk, kit, key, wf, u0 - fw, v1, u1 + fw, v1 + fw, 0.0, 0.1, col)
	_rect(pk, kit, key, wf, u0 - fw, v0, u0, v1, 0.0, 0.09, col)
	_rect(pk, kit, key, wf, u1, v0, u1 + fw, v1, 0.0, 0.09, col)


## One bay of a framed temple wall, between its columns and from sill to head: "plaster", "renji" (a barred window in
## plaster), "door" (latticed leaves), "lattice" (bars over the dark), "boards" or "open".
static func _bay(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, kind: String, key: String, col: Color, plaster: Color) -> void:
	match kind:
		"open":
			return
		"plaster":
			_face(pk, kit, "shikkui", wf, u0, v0, u1, v1, 0.0, plaster)
		"boards":
			_face(pk, kit, "sugi", wf, u0, v0, u1, v1, 0.0, CEDAR.darkened(0.2))
		"renji":
			_face(pk, kit, "shikkui", wf, u0, v0, u1, v1, 0.0, plaster)
			var mu: float = (u1 - u0) * 0.2
			_renji(pk, kit, wf, u0 + mu, lerpf(v0, v1, 0.38), u1 - mu, lerpf(v0, v1, 0.82), key, col)
		"lattice":
			_face(pk, kit, "pane", wf, u0, v0, u1, v1, 0.0, DARK)
			_bars(pk, kit, key, wf, u0, u1, v0, v1, maxi(3, int(round((u1 - u0) / 0.28))), 0.09, 0.0, 0.08, col)
			_hbars(pk, kit, key, wf, u0, u1, v0, v1, 3, 0.1, 0.0, 0.05, col.darkened(0.1))
		"door":
			var dk: Color = Color(0.20, 0.14, 0.10)
			_face(pk, kit, "sugi", wf, u0, v0, u1, v1, 0.0, dk)
			var mid: float = lerpf(v0, v1, 0.36)
			var c: float = (u0 + u1) * 0.5
			for leaf in [[u0, c - 0.02], [c + 0.02, u1]]:
				var a: float = leaf[0]
				var b: float = leaf[1]
				_rect(pk, kit, "hinoki", wf, a + 0.03, v0 + 0.05, b - 0.03, mid, 0.0, 0.03, dk.lightened(0.07))
				_face(pk, kit, "pane", wf, a + 0.08, mid + 0.08, b - 0.08, v1 - 0.08, 0.012, DARK)
				_bars(pk, kit, "hinoki", wf, a + 0.08, b - 0.08, mid + 0.08, v1 - 0.08, maxi(3, int((b - a) / 0.3)), 0.045, 0.012, 0.04, dk.lightened(0.1))
				_hbars(pk, kit, "hinoki", wf, a + 0.08, b - 0.08, mid + 0.08, v1 - 0.08, maxi(3, int((v1 - mid) / 0.3)), 0.045, 0.012, 0.03, dk.lightened(0.1))
				_rect(pk, kit, "gold", wf, (a + b) * 0.5 - 0.09, v0 + 0.02, (a + b) * 0.5 + 0.09, v0 + 0.14, 0.03, 0.045, GOLD)
				_rect(pk, kit, "gold", wf, (a + b) * 0.5 - 0.09, mid - 0.12, (a + b) * 0.5 + 0.09, mid - 0.02, 0.03, 0.045, GOLD)


## A framed temple storey: columns on the perimeter of xs by zs from y0 to y1, a sill and a head beam between them,
## and each bay filled as `bays` says ("front" +z, "back", "left" -x, "right": a list of kinds per bay, left to right
## seen from outside; the last repeats). `o`: key, col (the timber), r (the columns), plaster, base_r, weather, beam.
static func _temple_storey(pk: PropKit, kit: Dictionary, xs: Array, zs: Array, y0: float, y1: float, o: Dictionary, bays: Dictionary) -> void:
	var key: String = o.get("key", "urushi")
	var col: Color = o.get("col", VERMILION)
	var r: float = o.get("r", 0.3)
	var plaster: Color = o.get("plaster", SHIKKUI)
	var bh: float = o.get("beam", r * 0.9)
	var x0: float = xs[0]
	var x1: float = xs[xs.size() - 1]
	var z0: float = zs[0]
	var z1: float = zs[zs.size() - 1]
	for x in xs:
		for z in zs:
			if x != x0 and x != x1 and z != z0 and z != z1:
				continue
			_column(pk, kit, x, z, y0, y1, r, col, key, int(o.get("segs", 10)), float(o.get("base_r", 0.0)), float(o.get("weather", 0.0)))
	var faces: Array = [["front", Vector3(x0, 0, z1), Vector3(0, 0, 1), xs, x0, 1.0], ["back", Vector3(x1, 0, z0), Vector3(0, 0, -1), xs, x1, -1.0],
			["right", Vector3(x1, 0, z1), Vector3(1, 0, 0), zs, z1, -1.0], ["left", Vector3(x0, 0, z0), Vector3(-1, 0, 0), zs, z0, 1.0]]
	for f in faces:
		var wf := _wf(f[1], f[2])
		var list: Array = bays.get(f[0], ["plaster"])
		var grid: Array = f[3]
		var us: Array = []
		for g in grid:
			us.append((float(g) - float(f[4])) * float(f[5]))
		us.sort()
		var span: float = us[us.size() - 1]
		# The sill and the head, between the outermost columns and proud of the infill.
		_rect(pk, kit, key, wf, r * 0.5, y0, span - r * 0.5, y0 + bh, -bh * 0.4, bh * 0.4, col)
		_rect(pk, kit, key, wf, r * 0.5, y1 - bh, span - r * 0.5, y1, -bh * 0.4, bh * 0.4, col)
		for i in range(us.size() - 1):
			var kind: String = list[mini(i, list.size() - 1)]
			_bay(pk, kit, wf, float(us[i]) + r * 0.8, y0 + bh, float(us[i + 1]) - r * 0.8, y1 - bh, kind, key, col, plaster)


# ======================================================================================
#  The great gate (Niomon)
# ======================================================================================

const GATE_CX := [5.0, 7.6]        # the columns' x (both signs): the passage between the inner ones
const GATE_CZ := 2.6               # the columns' z (both signs, and 0)
const GATE_LOW := 9.35             # the lower storey's column heads
const GATE_CLEAR_X := 4.3          # nothing nearer the road's middle than this ...
const GATE_CLEAR_Y := 6.6          # ... under this height


## The gate's size: x across the road, y, z along it (out to the roof's corner tips; the columns stand in 15.2 x 5.2,
## the plinths' steps reach z +-3.95, the balcony x +-8.8, z +-3.8).
static func great_gate_size() -> Vector3:
	return Vector3(19.7, 17.9, 9.9)


## The temple's great gate (Niomon): a two-storey romon the race drives through, centred on the origin, the road along z.
## Twelve round columns on stone bases carry a balcony on bracket clusters and an upper storey under a great tiled
## hip-and-gable roof; the guardians stand behind lattices in the front side bays; a huge red paper lantern hangs in the
## passage. Nothing at all stands in |x| < 4.3 under y = 6.6 (the lantern's foot is at 6.7).
static func great_gate(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var red: Color = VERMILION.lerp(VERMILION_OLD, 0.8)
	var cz: float = GATE_CZ
	var xi: float = GATE_CX[0]
	var xo: float = GATE_CX[1]
	var ply := 0.3
	# Stone plinths under the side bays only: the road runs through on the ground.
	for sx in [-1.0, 1.0]:
		_mblock(pk, kit, "ishi", Vector3(sx * 4.36, FOOT, -cz - 0.95), Vector3(sx * (xo + 0.95), ply, cz + 0.95), GRANITE)
		_mblock(pk, kit, "ishi", Vector3(sx * 4.6, FOOT, cz + 0.95), Vector3(sx * (xo + 0.6), ply * 0.5, cz + 1.35), GRANITE.darkened(0.06))
		_mblock(pk, kit, "ishi", Vector3(sx * 4.6, FOOT, -cz - 1.35), Vector3(sx * (xo + 0.6), ply * 0.5, -cz - 0.95), GRANITE.darkened(0.06))
	# The columns.
	for sx in [-1.0, 1.0]:
		for x in GATE_CX:
			for z in [-cz, 0.0, cz]:
				_column(pk, kit, sx * float(x), z, ply, GATE_LOW, 0.5, red, "urushi", 12, 0.64, 1.5)
	# Tie beams. Round the heads and at 6.9 across everything (clear of the passage's 6.6); lower ones in the side bays.
	var bw := 0.3
	var bh := 0.42
	for y in [GATE_LOW - bh * 0.5, 6.95]:
		for z in [-cz, 0.0, cz]:
			_beam(pk, kit, "urushi", Vector3(-xo, y, z), Vector3(xo, y, z), bw, bh, red, Vector3(0, 0, 1))
		for sx in [-1.0, 1.0]:
			for x in GATE_CX:
				_beam(pk, kit, "urushi", Vector3(sx * float(x), y - 0.01, -cz), Vector3(sx * float(x), y - 0.01, cz), bw - 0.02, bh - 0.02, red, Vector3(1, 0, 0))
	for y in [3.6, ply + 0.45]:
		for sx in [-1.0, 1.0]:
			for z in [-cz, 0.0, cz]:
				_beam(pk, kit, "urushi", Vector3(sx * xi, y, z), Vector3(sx * xo, y, z), bw - 0.04, bh - 0.06, red, Vector3(0, 0, 1))
			for x in GATE_CX:
				_beam(pk, kit, "urushi", Vector3(sx * float(x), y - 0.01, -cz), Vector3(sx * float(x), y - 0.01, cz), bw - 0.06, bh - 0.08, red, Vector3(1, 0, 0))
	# The side bays' walls: plaster outside and at the back, lattices round the guardians in the front halves.
	for sx in [-1.0, 1.0]:
		var of := _wf(Vector3(sx * xo, 0, cz if sx > 0.0 else -cz), Vector3(sx, 0, 0))
		_face(pk, kit, "sugi", of, 0.5, ply, 2.0 * cz - 0.5, ply + 0.45, 0.0, CEDAR.darkened(0.25))
		_face(pk, kit, "shikkui", of, 0.5, ply + 0.45, 2.0 * cz - 0.5, GATE_LOW - bh, 0.0, SHIKKUI)
		# Front and back faces between the columns.
		for sz in [-1.0, 1.0]:
			var a: float = xi if sx * sz > 0.0 else xo
			var ff := _wf(Vector3(sx * a, 0, sz * cz), Vector3(0, 0, sz))
			var u0 := 0.5
			var u1: float = xo - xi - 0.5
			_face(pk, kit, "shikkui", ff, u0, 7.15, u1, GATE_LOW - bh, 0.0, SHIKKUI)
			if sz > 0.0:
				_face(pk, kit, "sugi", ff, u0, ply, u1, 1.1, 0.0, CEDAR.darkened(0.25))
				_rect(pk, kit, "urushi", ff, u0, 1.1, u1, 1.24, -0.06, 0.1, red)
				_bars(pk, kit, "urushi", ff, u0, u1, 1.24, 6.74, 6, 0.09, -0.02, 0.07, red.darkened(0.12))
				_hbars(pk, kit, "urushi", ff, u0, u1, 1.6, 3.2, 1, 0.1, -0.06, 0.0, red.darkened(0.15))
				_hbars(pk, kit, "urushi", ff, u0, u1, 4.2, 6.4, 2, 0.1, -0.06, 0.0, red.darkened(0.15))
			else:
				_face(pk, kit, "sugi", ff, u0, ply, u1, ply + 0.45, 0.0, CEDAR.darkened(0.25))
				_face(pk, kit, "shikkui", ff, u0, ply + 0.45, u1, 6.74, 0.0, SHIKKUI)
		# The passage side: a lattice by the guardian, plaster behind; the partition between the two halves.
		var pf := _wf(Vector3(sx * xi, 0, cz if sx < 0.0 else -cz), Vector3(-sx, 0, 0))
		var fa: float = 0.5 if sx < 0.0 else cz + 0.3
		var fb: float = cz - 0.3 if sx < 0.0 else 2.0 * cz - 0.5
		var ba: float = cz + 0.3 if sx < 0.0 else 0.5
		var bb: float = 2.0 * cz - 0.5 if sx < 0.0 else cz - 0.3
		_face(pk, kit, "sugi", pf, fa, ply, fb, 1.1, 0.0, CEDAR.darkened(0.25))
		_rect(pk, kit, "urushi", pf, fa, 1.1, fb, 1.24, -0.06, 0.1, red)
		_bars(pk, kit, "urushi", pf, fa, fb, 1.24, 6.74, 7, 0.09, -0.02, 0.07, red.darkened(0.12))
		_hbars(pk, kit, "urushi", pf, fa, fb, 1.6, 3.2, 1, 0.1, -0.06, 0.0, red.darkened(0.15))
		_hbars(pk, kit, "urushi", pf, fa, fb, 4.2, 6.4, 2, 0.1, -0.06, 0.0, red.darkened(0.15))
		_face(pk, kit, "sugi", pf, ba, ply, bb, ply + 0.45, 0.0, CEDAR.darkened(0.25))
		_face(pk, kit, "shikkui", pf, ba, ply + 0.45, bb, 6.74, 0.0, SHIKKUI)
		_face(pk, kit, "shikkui", pf, 0.5, 7.15, 2.0 * cz - 0.5, GATE_LOW - bh, 0.0, SHIKKUI)
		# The cell: dark inside (its back, its outer side, its ceiling), and the guardian.
		var cf := _wf(Vector3(sx * xi if sx > 0.0 else sx * xo, 0, 0.16), Vector3(0, 0, 1))
		_face(pk, kit, "pane", cf, 0.3, ply, xo - xi - 0.3, 6.74, 0.0, DARK.lightened(0.03))
		var sf := _wf(Vector3(sx * (xo - 0.16), 0, cz if sx < 0.0 else 0.0), Vector3(-sx, 0, 0))
		_face(pk, kit, "pane", sf, 0.0, ply, cz, 6.74, 0.0, DARK.lightened(0.03))
		_nio(pk, kit, Vector3(sx * (xi + xo) * 0.5, ply, cz * 0.5 - 0.1), sx, 4.9)
	# The passage's ceiling (the upper floor's boards).
	pk.quad(kit, "sugi", [Vector3(-xo, GATE_LOW - 0.02, -cz), Vector3(-xo, GATE_LOW - 0.02, cz), Vector3(xo, GATE_LOW - 0.02, cz), Vector3(xo, GATE_LOW - 0.02, -cz)], Vector3.DOWN,
			CEDAR.darkened(0.3), [Vector2(-xo, -cz) * uvk, Vector2(-xo, cz) * uvk, Vector2(xo, cz) * uvk, Vector2(xo, -cz) * uvk])
	# The great lantern, high in the passage: its foot rim at 6.7.
	chochin(pk, kit, Vector3(0, 7.84, 0), 1.0, 2.0, PAPER_RED, 14, BLACK_LAC, Vector3(0, 0, 1), 0.2)
	sakura_crest(pk, kit, "urushi", Vector3(0, 7.84, -1.012), Vector3(0, 0, -1), 0.42, BLACK_LAC)
	pk.tube(kit, "urushi", Vector3(0, 8.3, 0), Vector3(0, 8.42, 0), 0.9, 0.9, 14, BLACK_LAC, false)
	pk.tube(kit, "urushi", Vector3(0, 7.26, 0), Vector3(0, 7.38, 0), 0.9, 0.9, 14, BLACK_LAC, false)
	# The balcony on its brackets.
	var xs: Array = [-xo, -xi, xi, xo]
	var zs: Array = [-cz, 0.0, cz]
	var bsc := 0.82
	_bracket_ring(pk, kit, "urushi", xs, zs, GATE_LOW, bsc, red)
	var fy: float = GATE_LOW + 1.04 * bsc
	var bx: float = xo + 1.2
	var bz: float = cz + 1.2
	_slab(pk, kit, "sugi", Transform3D.IDENTITY, -bx, bx, -bz, bz, fy, fy + 0.16, CEDAR.darkened(0.1))
	for e in [[Vector3(-bx + 0.12, fy + 0.16, bz - 0.12), Vector3(bx - 0.12, fy + 0.16, bz - 0.12)], [Vector3(-bx + 0.12, fy + 0.16, -bz + 0.12), Vector3(bx - 0.12, fy + 0.16, -bz + 0.12)],
			[Vector3(bx - 0.12, fy + 0.16, -bz + 0.12), Vector3(bx - 0.12, fy + 0.16, bz - 0.12)], [Vector3(-bx + 0.12, fy + 0.16, -bz + 0.12), Vector3(-bx + 0.12, fy + 0.16, bz - 0.12)]]:
		_koran(pk, kit, "urushi", e[0], e[1], 1.0, red, 0.3)
	# The upper storey.
	var uy0: float = fy + 0.16
	var uy1: float = uy0 + 2.7
	var uxs: Array = [-7.1, -2.5, 2.5, 7.1]
	var uzs: Array = [-2.2, 2.2]
	_temple_storey(pk, kit, uxs, uzs, uy0, uy1, {"key": "urushi", "col": red, "r": 0.3, "beam": 0.26},
			{"front": ["renji", "door", "renji"], "back": ["renji", "door", "renji"], "left": ["renji"], "right": ["renji"]})
	var usc := 0.8
	_bracket_ring(pk, kit, "urushi", uxs, uzs, uy1, usc, red)
	var ptop: float = uy1 + 1.04 * usc
	# The roof.
	var s := roof_spec(R_IRIMOYA, Vector3.ZERO, 7.1 + 2.3, 2.2 + 2.3, 3.7, "kawara", KAWARA.lerp(KAWARA_OLD, 0.5))
	s.sori = 0.45
	s.lift = 0.55
	s.thick = 0.2
	s.tb = 0.42
	s.gable_in = 0.6
	s.n = 14
	s.m = 6
	s.wall_hx = 7.1
	s.wall_zf = 2.2
	s.wall_zb = 2.2
	s.raft = 0.37
	s.raft_key = "urushi"
	s.raft_col = red
	s.raft_end = WHITE_END
	s.raft_w = 0.1
	s.raft_d = 0.13
	s.under_col = CEDAR.darkened(0.2)
	s.hafu_key = "urushi"
	s.hafu_col = red
	s.ridge_h = 0.42
	s.crest = GOLD
	var pq: float = 2.2 + 0.8 * usc
	s.c = Vector3(0, ptop + float(s.thick) - _rf_front(s, 0.0, pq) + 0.005, 0)
	jroof(pk, kit, s)
	# A name board over the passage on the balcony's front.
	_rect(pk, kit, "hinoki", _wf(Vector3(0, 0, bz), Vector3(0, 0, 1)), -1.5, fy + 0.3, 1.5, fy + 1.2, 0.0, 0.08, CEDAR_DARK.darkened(0.2))
	sakura_crest(pk, kit, "gold", Vector3(0, fy + 0.75, bz + 0.08 + TP), Vector3(0, 0, 1), 0.36, GOLD)
	if labels != null and false:
		labels.append(["", Vector3.ZERO, Vector3(0, 0, 1), 0.3, GOLD, 2.6])


## A guardian (Nio) suggested behind its lattice: a muscular red figure `h` tall standing at `p`, one fist raised.
## `sx`: which side of the gate (it turns a little toward the passage).
static func _nio(pk: PropKit, kit: Dictionary, p: Vector3, sx: float, h: float) -> void:
	var skin := Color(0.56, 0.20, 0.13)
	var cloth := Color(0.20, 0.30, 0.24)
	var k: float = h / 4.9
	var seg := 7
	for lx in [-0.42, 0.42]:
		pk.tube(kit, "urushi", p + Vector3(lx * k * 1.15, 0, 0), p + Vector3(lx * k, 1.5 * k, 0), 0.22 * k, 0.3 * k, seg, skin, false)
	pk.lathe(kit, "urushi", p + Vector3(0, 1.3 * k, 0), [Vector2(0.95 * k, 0.0), Vector2(0.8 * k, 0.5 * k), Vector2(0.56 * k, 1.05 * k), Vector2(0.001, 1.1 * k)], seg, cloth)
	pk.lathe(kit, "urushi", p + Vector3(0, 2.3 * k, 0), [Vector2(0.5 * k, 0.0), Vector2(0.66 * k, 0.5 * k), Vector2(0.8 * k, 1.05 * k), Vector2(0.62 * k, 1.4 * k), Vector2(0.2 * k, 1.55 * k), Vector2(0.001, 1.56 * k)],
			seg, skin)
	_ball(pk, kit, "urushi", p + Vector3(0, 4.25 * k, 0.05), 0.42 * k, skin.lightened(0.05), seg, 4)
	_ball(pk, kit, "urushi", p + Vector3(0, 4.72 * k, 0), 0.16 * k, BLACK_LAC, 5, 3)
	# The raised arm (toward the passage) and the lowered one.
	var sh: Vector3 = p + Vector3(-sx * 0.72 * k, 3.6 * k, 0)
	var el: Vector3 = sh + Vector3(-sx * 0.5 * k, 0.25 * k, 0.25 * k)
	var fi: Vector3 = el + Vector3(sx * 0.1 * k, 0.85 * k, 0.15 * k)
	pk.tube(kit, "urushi", sh, el, 0.24 * k, 0.2 * k, 6, skin, false)
	pk.tube(kit, "urushi", el, fi, 0.2 * k, 0.16 * k, 6, skin, false)
	_ball(pk, kit, "urushi", fi, 0.22 * k, skin, 6, 3)
	var sh2: Vector3 = p + Vector3(sx * 0.72 * k, 3.6 * k, 0)
	var el2: Vector3 = sh2 + Vector3(sx * 0.38 * k, -0.8 * k, 0.1 * k)
	var fi2: Vector3 = el2 + Vector3(-sx * 0.2 * k, -0.6 * k, 0.4 * k)
	pk.tube(kit, "urushi", sh2, el2, 0.24 * k, 0.2 * k, 6, skin, false)
	pk.tube(kit, "urushi", el2, fi2, 0.2 * k, 0.16 * k, 6, skin, false)
	_ball(pk, kit, "urushi", fi2, 0.22 * k, skin, 6, 3)
	# The scarf flying in an arc over the head.
	var prev := Vector3.ZERO
	for i in range(8):
		var a: float = PI * float(i) / 7.0
		var q: Vector3 = p + Vector3(cos(a) * 1.15 * k, 3.5 * k + sin(a) * 1.5 * k, -0.25 * k)
		if i > 0:
			pk.beam(kit, "urushi", prev, q, 0.26 * k, 0.04 * k, Color(0.72, 0.62, 0.36), Vector3(0, 0, 1))
		prev = q


# ======================================================================================
#  The main hall (hondo)
# ======================================================================================

## The temple's main hall: its stone podium's front at z = 0 facing +z, x centred (+-12.4), the back at -18.6; a broad
## flight of steps before it (to z = +3.1) under a step canopy on two posts (to +4.3), a great incense burner at z = +7.
## Unpainted timber, white plaster and a sweeping hip-and-gable roof of cypress bark under a tiled ridge; 15.5m high.
static func main_hall(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var wood := Color(0.40, 0.29, 0.21)
	var py := 1.4
	var zc := -9.3
	# The podium and the veranda's deck on it.
	_mblock(pk, kit, "ishi", Vector3(-12.4, FOOT, -18.6), Vector3(12.4, py, 0.0), GRANITE)
	_mblock(pk, kit, "ishi", Vector3(-12.55, FOOT, -18.75), Vector3(12.55, 0.25, 0.15), GRANITE.darkened(0.08))
	var fy: float = py + 0.12
	_slab(pk, kit, "sugi", Transform3D.IDENTITY, -12.15, 12.15, -18.35, -0.25, py - 0.01, fy, wood.lightened(0.12))
	# The steps: seven stone treads between two cheek walls.
	var sw := 4.0
	for i in range(1, 8):
		_mblock(pk, kit, "ishi", Vector3(-sw, FOOT, 0.02 + 0.4 * float(i - 1)), Vector3(sw, py - 0.175 * float(i), 0.02 + 0.4 * float(i)), GRANITE.lightened(0.03 * float(i % 2)))
	for sx in [-1.0, 1.0]:
		var cf := _wf(Vector3(sx * sw if sx > 0.0 else sx * (sw + 0.5), 0, 0.0), Vector3(1, 0, 0))
		_prism(pk, kit, "ishi", cf, PackedVector2Array([Vector2(-3.2, FOOT), Vector2(-0.02, FOOT), Vector2(-0.02, py + 0.3), Vector2(-0.5, py + 0.3), Vector2(-3.2, 0.42)]), 0.0, 0.5,
				GRANITE.darkened(0.05), true)
	# The body: six by five columns, the three middle bays of the front doors.
	var xs: Array = [-9.2, -5.52, -1.84, 1.84, 5.52, 9.2]
	var zs: Array = [-15.7, -12.5, -9.3, -6.1, -2.9]
	var y1 := 6.5
	_temple_storey(pk, kit, xs, zs, fy, y1, {"key": "hinoki", "col": wood, "r": 0.36, "beam": 0.34, "base_r": 0.5},
			{"front": ["renji", "door", "door", "door", "renji"], "back": ["plaster"], "left": ["plaster", "renji", "renji", "door"], "right": ["door", "renji", "renji", "plaster"]})
	# A rail (nageshi) round the body over the doors' heads.
	for f in [[Vector3(-9.2, 0, -2.9), Vector3(0, 0, 1), 18.4], [Vector3(9.2, 0, -15.7), Vector3(0, 0, -1), 18.4], [Vector3(9.2, 0, -2.9), Vector3(1, 0, 0), 12.8],
			[Vector3(-9.2, 0, -15.7), Vector3(-1, 0, 0), 12.8]]:
		_rect(pk, kit, "hinoki", _wf(f[0], f[1]), 0.2, 4.95, float(f[2]) - 0.2, 5.2, 0.0, 0.2, wood.darkened(0.06))
	var bsc := 0.9
	_bracket_ring(pk, kit, "hinoki", xs, zs, y1, bsc, wood)
	var ptop: float = y1 + 1.04 * bsc
	# The veranda's railing, open at the steps.
	var ry: float = fy
	_koran(pk, kit, "hinoki", Vector3(-12.0, ry, -0.4), Vector3(-sw - 0.6, ry, -0.4), 0.95, wood)
	_koran(pk, kit, "hinoki", Vector3(sw + 0.6, ry, -0.4), Vector3(12.0, ry, -0.4), 0.95, wood)
	_koran(pk, kit, "hinoki", Vector3(-12.0, ry, -18.2), Vector3(12.0, ry, -18.2), 0.95, wood)
	_koran(pk, kit, "hinoki", Vector3(-12.0, ry, -18.2), Vector3(-12.0, ry, -0.4), 0.95, wood)
	_koran(pk, kit, "hinoki", Vector3(12.0, ry, -18.2), Vector3(12.0, ry, -0.4), 0.95, wood)
	# The roof.
	var s := roof_spec(R_IRIMOYA, Vector3(0, 0, zc), 12.5, 9.7, 7.0, "hiwada", HIWADA.lightened(0.25))
	s.sori = 0.5
	s.lift = 0.75
	s.thick = 0.4
	s.tb = 0.5
	s.gable_in = 0.9
	s.n = 16
	s.m = 7
	s.wall_hx = 9.2
	s.wall_zf = 6.4
	s.wall_zb = 6.4
	s.raft = 0.5
	s.raft_col = wood.darkened(0.1)
	s.raft_end = WHITE_END
	s.raft_w = 0.11
	s.raft_d = 0.15
	s.under_col = wood.darkened(0.3)
	s.hafu_col = wood.darkened(0.15)
	s.ridge_h = 0.6
	s.ridge_col = KAWARA_OLD
	s.crest = GOLD
	s.c = Vector3(0, ptop + 0.4 - _rf_front(s, 0.0, 6.4 + 0.8 * bsc) + 0.005, zc)
	jroof(pk, kit, s)
	# The step canopy (kohai): a lean-to of bark from under the front eave out over the steps, on two posts.
	var kd := 5.5
	var kz := -1.2
	var ks := pent_spec(-5.7, 5.7, kz, 0.0, kd, 1.75, "hiwada", HIWADA.lightened(0.25))
	ks.thick = 0.3
	ks.lift = 0.3
	ks.sori = 0.35
	ks.n = 8
	ks.m = 3
	ks.raft = 0.5
	ks.raft_col = wood.darkened(0.1)
	ks.raft_end = WHITE_END
	ks.raft_w = 0.1
	ks.raft_d = 0.13
	ks.under_col = wood.darkened(0.3)
	# Its top tucks under the main eave's edge.
	var edge_z: float = zc + 9.7
	var want: float = roof_under_y(s, Vector3(0, 0, edge_z)) - 0.05
	ks.c = Vector3(0, want - _rf_front(ks, 0.0, edge_z - kz), kz)
	jroof(pk, kit, ks)
	var pz := 3.6
	for sx in [-1.0, 1.0]:
		var px: float = sx * 4.75
		var top: float = roof_under_y(ks, Vector3(px, 0, pz)) - 0.13
		_mblock(pk, kit, "ishi", Vector3(px - 0.4, FOOT, pz - 0.4), Vector3(px + 0.4, 0.3, pz + 0.4), GRANITE.darkened(0.05))
		_post(pk, kit, "hinoki", px, pz, 0.3, top - 0.4, 0.36, wood)
		# The beam back to the hall's column.
		var hy: float = roof_under_y(ks, Vector3(px, 0, -2.5)) - 0.4
		_beam(pk, kit, "hinoki", Vector3(px, top - 0.62, pz), Vector3(px, minf(hy, y1 - 0.2), -2.9), 0.22, 0.3, wood, Vector3(1, 0, 0))
		_bracket(pk, kit, "hinoki", Vector3(px, top - 0.4 - 0.0, pz), Vector3(0, 0, 1), 0.5, wood, 1)
	var bt: float = roof_under_y(ks, Vector3(4.75, 0, pz)) - 0.13
	_beam(pk, kit, "hinoki", Vector3(-5.3, bt - 0.62, pz), Vector3(5.3, bt - 0.62, pz), 0.26, 0.42, wood, Vector3(0, 0, 1))
	_beam(pk, kit, "hinoki", Vector3(-5.5, bt - 0.07, pz), Vector3(5.5, bt - 0.07, pz), 0.2, 0.14, wood.darkened(0.08), Vector3(0, 0, 1))
	# A rope of bells' cloth and the crest over the doors.
	sakura_crest(pk, kit, "gold", Vector3(0, 5.75, -2.9 + 0.36), Vector3(0, 0, 1), 0.42, GOLD)
	# The incense burner before the steps: a bronze cauldron on a stone drum under its own little roof.
	_incense_burner(pk, kit, Vector3(0, 0, 7.0))
	if labels != null and false:
		labels.append(["", Vector3.ZERO, Vector3(0, 0, 1), 0.3, GOLD, 2.0])


## A great incense burner (jokoro) at p: 2m across, 3.3m to its roof's knob.
static func _incense_burner(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	pk.lathe(kit, "ishi", p, [Vector2(1.25, FOOT), Vector2(1.25, 0.22), Vector2(1.05, 0.22), Vector2(1.05, 0.5), Vector2(0.001, 0.5)], 8, GRANITE, true)
	var br := BRONZE
	for k in range(3):
		var a: float = TAU * float(k) / 3.0 + 0.5
		pk.tube(kit, "urushi", p + Vector3(cos(a) * 0.55, 0.5, sin(a) * 0.55), p + Vector3(cos(a) * 0.62, 0.95, sin(a) * 0.62), 0.09, 0.14, 6, br.darkened(0.1), false)
	pk.lathe(kit, "urushi", p + Vector3(0, 0.9, 0), [Vector2(0.001, 0.0), Vector2(0.55, 0.02), Vector2(0.9, 0.3), Vector2(0.98, 0.62), Vector2(0.9, 0.7), Vector2(0.8, 0.62), Vector2(0.001, 0.6)], 12, br)
	pk.lathe(kit, "rope", p + Vector3(0, 1.515, 0), [Vector2(0.001, 0.0), Vector2(0.8, 0.0)], 12, Color(0.62, 0.60, 0.56))
	for k in range(4):
		var a2: float = TAU * (float(k) + 0.5) / 4.0
		var c: Vector3 = p + Vector3(cos(a2) * 0.86, 0, sin(a2) * 0.86)
		pk.tube(kit, "urushi", Vector3(c.x, 1.55, c.z), Vector3(c.x, 2.62, c.z), 0.045, 0.045, 5, br.darkened(0.15), false)
	var s := roof_spec(R_HOGYO, p + Vector3(0, 2.62, 0), 1.25, 1.25, 0.55, "urushi", br)
	s.lift = 0.14
	s.sori = 0.5
	s.thick = 0.06
	s.n = 4
	s.m = 2
	s.discs = false
	s.ridge = false
	s.under_key = "urushi"
	s.under_col = br.darkened(0.3)
	jroof(pk, kit, s)
	pk.lathe(kit, "gold", p + Vector3(0, 3.12, 0), [Vector2(0.001, 0.0), Vector2(0.1, 0.02), Vector2(0.14, 0.14), Vector2(0.05, 0.26), Vector2(0.001, 0.36)], 6, GOLD)
	for k in range(5):
		var q: Vector3 = p + Vector3(-0.3 + 0.15 * float(k), 1.52, 0.1 * float(k % 2))
		pk.tube(kit, "urushi", q, q + Vector3(0, 0.3, 0), 0.012, 0.012, 3, Color(0.35, 0.5, 0.3), false)


# ======================================================================================
#  The pagoda
# ======================================================================================

## A pagoda of `tiers` storeys (3 or 5), centred: a 6.4m square body on a stone podium (9.2m square, steps toward +z),
## every storey with its balcony's railing and its own tiled roof, the roofs shrinking a little upward; vermilion
## timbers, white infill, a bronze sorin with its nine rings. With three tiers 23m to the jewel, its eaves 11.6m across.
static func pagoda(pk: PropKit, kit: Dictionary, tiers := 3) -> void:
	var red: Color = VERMILION.lerp(VERMILION_OLD, 0.7)
	var roofc: Color = KAWARA.lerp(KAWARA_OLD, 0.4)
	var py := 0.9
	_mblock(pk, kit, "ishi", Vector3(-4.6, FOOT, -4.6), Vector3(4.6, py, 4.6), GRANITE)
	for i in range(1, 5):
		_mblock(pk, kit, "ishi", Vector3(-1.4, FOOT, 4.6 + 0.34 * float(i - 1)), Vector3(1.4, py - 0.18 * float(i), 4.6 + 0.34 * float(i)), GRANITE.lightened(0.03 * float(i % 2)))
	var y0: float = py
	var n: int = maxi(tiers, 1)
	var shrink: float = 0.09 if n <= 3 else 0.075
	for i in range(n):
		var b: float = 3.2 * (1.0 - shrink * float(i))
		var hs: float = 3.3 if i == 0 else 2.15
		var y1: float = y0 + hs
		var xs: Array = [-b, -b / 3.0, b / 3.0, b]
		if i > 0:
			# The balcony round this storey, over the roof below.
			var bb: float = b + 0.75
			_slab(pk, kit, "sugi", Transform3D.IDENTITY, -bb, bb, -bb, bb, y0 - 0.14, y0, CEDAR.darkened(0.1))
			var e: float = bb - 0.1
			_koran(pk, kit, "urushi", Vector3(-e, y0, e), Vector3(e, y0, e), 0.72, red, 0.18)
			_koran(pk, kit, "urushi", Vector3(-e, y0, -e), Vector3(e, y0, -e), 0.72, red, 0.18)
			_koran(pk, kit, "urushi", Vector3(e, y0, -e), Vector3(e, y0, e), 0.72, red, 0.18)
			_koran(pk, kit, "urushi", Vector3(-e, y0, -e), Vector3(-e, y0, e), 0.72, red, 0.18)
		var kinds: Array = ["renji", "door", "renji"] if i == 0 else ["plaster", "door", "plaster"]
		_temple_storey(pk, kit, xs, xs, y0, y1, {"key": "urushi", "col": red, "r": 0.17, "beam": 0.2, "segs": 8, "base_r": 0.26 if i == 0 else 0.0},
				{"front": kinds, "back": kinds, "left": kinds if i == 0 else ["plaster", "lattice", "plaster"], "right": kinds if i == 0 else ["plaster", "lattice", "plaster"]})
		var sc := 0.52
		_bracket_ring(pk, kit, "urushi", xs, xs, y1, sc, red, SHIKKUI, true)
		var ptop: float = y1 + 1.04 * sc
		var ov: float = 2.6 - 0.16 * float(i)
		var hx: float = b + ov
		var s := roof_spec(R_HOGYO, Vector3.ZERO, hx, hx, hx * 0.56, "kawara", roofc)
		s.sori = 0.42
		s.lift = 0.42
		s.thick = 0.16
		s.n = 8
		s.m = 3
		s.wall_hx = b
		s.wall_zf = b
		s.wall_zb = b
		s.raft = 0.8
		s.raft_key = "urushi"
		s.raft_col = red
		s.raft_end = WHITE_END
		s.raft_w = 0.09
		s.raft_d = 0.1
		s.under_col = CEDAR.darkened(0.2)
		s.ridge_h = 0.2
		var last: bool = i == n - 1
		var bn: float = 3.2 * (1.0 - shrink * float(i + 1))
		if not last:
			s.t_max = 1.0 - (bn - 0.25) / hx
		s.c = Vector3(0, ptop + 0.16 - _rf_front(s, 0.0, b + 0.8 * sc) + 0.005, 0)
		jroof(pk, kit, s)
		if last:
			_sorin(pk, kit, Vector3(0, (s.c as Vector3).y + float(s.rise) - 0.25, 0), 1.0 if n <= 3 else 0.9)
		else:
			y0 = (s.c as Vector3).y + _rf_front(s, 0.0, bn + 0.75) + 0.2


## The finial (sorin) of a pagoda standing on `p`: the dew basin, the inverted bowl, nine rings on the mast, the water
## flame and the jewel, in bronze and gilt. 6.4m at scale 1.
static func _sorin(pk: PropKit, kit: Dictionary, p: Vector3, sc: float) -> void:
	var br := BRONZE
	_slab(pk, kit, "urushi", Transform3D(Basis(), p), -0.55 * sc, 0.55 * sc, -0.55 * sc, 0.55 * sc, 0.0, 0.42 * sc, br.darkened(0.1))
	pk.lathe(kit, "urushi", p + Vector3(0, 0.42 * sc, 0), [Vector2(0.5 * sc, 0.0), Vector2(0.44 * sc, 0.22 * sc), Vector2(0.22 * sc, 0.4 * sc), Vector2(0.12 * sc, 0.46 * sc)], 8, br)
	var prof: Array = [Vector2(0.09 * sc, 0.0)]
	var y := 0.2 * sc
	for k in range(9):
		var rr: float = (0.5 - 0.022 * float(k)) * sc
		prof.append(Vector2(0.09 * sc, y))
		prof.append(Vector2(rr, y + 0.08 * sc))
		prof.append(Vector2(rr, y + 0.14 * sc))
		y += 0.3 * sc
	prof.append(Vector2(0.09 * sc, y))
	prof.append(Vector2(0.07 * sc, y + 1.5 * sc))
	prof.append(Vector2(0.001, y + 1.5 * sc))
	var base: Vector3 = p + Vector3(0, 0.86 * sc, 0)
	pk.lathe(kit, "urushi", base, prof, 8, br)
	# The water flame: two crossed gilt blades.
	var fy: float = y + 0.25 * sc
	for a in [0.0, PI * 0.5]:
		var wf := Transform3D(Basis(Vector3.UP, a), base + Vector3(0, fy, 0))
		var ol := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.34 * sc, 0.18 * sc), Vector2(0.42 * sc, 0.55 * sc), Vector2(0.2 * sc, 0.75 * sc), Vector2(0.0, 1.1 * sc),
				Vector2(-0.2 * sc, 0.75 * sc), Vector2(-0.42 * sc, 0.55 * sc), Vector2(-0.34 * sc, 0.18 * sc)])
		_prism(pk, kit, "gold", wf, ol, -0.012, 0.012, GOLD, true, false)
	_ball(pk, kit, "gold", base + Vector3(0, y + 1.62 * sc, 0), 0.16 * sc, GOLD, 6, 4, 1.2)

# ======================================================================================
#  The temple's wall and its gate
# ======================================================================================

## A temple wall (tsuijibei) from a to b, standing on the ground heights a.y and b.y and sloping with them: a stone base
## course, a plastered face with five white lines, a little tiled roof. `h`: the face's top over the ground; the ridge is
## 0.55 higher, the eaves reach 0.72 either side of the middle. `detail` false leaves the round end tiles out (a long
## wall far from the road).
static func temple_wall(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 2.3, detail := true) -> void:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var l: float = flat.length()
	if l < 0.05:
		return
	var dir: Vector3 = flat / l
	var nrm: Vector3 = dir.cross(Vector3.UP).normalized()      # the wall's one face; the other is -nrm
	# A sheared frame: x along the wall (rising with the ground), y up, z across.
	var fr := Transform3D(Basis(Vector3(dir.x, (b.y - a.y) / l, dir.z), Vector3.UP, nrm), a)
	var face: Color = Color(0.90, 0.85, 0.72)
	var roofc: Color = KAWARA.lerp(KAWARA_OLD, 0.5)
	var base_h := 0.45
	var hw := 0.34
	var bw := 0.42
	var secs: Array = [["ishi", FOOT, base_h, bw, GRANITE.darkened(0.05)], ["shikkui", base_h, h, hw, face], ["hinoki", h, h + 0.1, hw + 0.06, CEDAR_DARK]]
	for sc in secs:
		var key: String = sc[0]
		var y0: float = sc[1]
		var y1: float = sc[2]
		var w: float = sc[3]
		var col: Color = sc[4]
		for sz in [1.0, -1.0]:
			pk.quad(kit, key, [fr * Vector3(0, y0, sz * w), fr * Vector3(l, y0, sz * w), fr * Vector3(l, y1, sz * w), fr * Vector3(0, y1, sz * w)], nrm * sz, col,
					[Vector2(0, y0) * uvk, Vector2(l, y0) * uvk, Vector2(l, y1) * uvk, Vector2(0, y1) * uvk])
		for e in [[0.0, -1.0], [l, 1.0]]:
			var u: float = e[0]
			pk.quad(kit, key, [fr * Vector3(u, y0, -w), fr * Vector3(u, y0, w), fr * Vector3(u, y1, w), fr * Vector3(u, y1, -w)], dir * float(e[1]), col,
					[Vector2(-w, y0) * uvk, Vector2(w, y0) * uvk, Vector2(w, y1) * uvk, Vector2(-w, y1) * uvk])
		if key == "ishi":
			for sz in [1.0, -1.0]:
				pk.quad(kit, key, [fr * Vector3(0, y1, sz * hw), fr * Vector3(l, y1, sz * hw), fr * Vector3(l, y1, sz * w), fr * Vector3(0, y1, sz * w)], Vector3.UP, col)
	# The five lines, TP proud.
	for k in range(5):
		var ly: float = lerpf(base_h, h, (float(k) + 0.6) / 5.2)
		for sz in [1.0, -1.0]:
			var z0: float = sz * hw
			var z1: float = sz * (hw + TP)
			pk.quad(kit, "shikkui", [fr * Vector3(0.02, ly, z1), fr * Vector3(l - 0.02, ly, z1), fr * Vector3(l - 0.02, ly + 0.055, z1), fr * Vector3(0.02, ly + 0.055, z1)], nrm * sz, SHIKKUI)
			pk.quad(kit, "shikkui", [fr * Vector3(0.02, ly + 0.055, z0), fr * Vector3(l - 0.02, ly + 0.055, z0), fr * Vector3(l - 0.02, ly + 0.055, z1), fr * Vector3(0.02, ly + 0.055, z1)], Vector3.UP,
					SHIKKUI.darkened(0.05))
			pk.quad(kit, "shikkui", [fr * Vector3(0.02, ly, z0), fr * Vector3(l - 0.02, ly, z0), fr * Vector3(l - 0.02, ly, z1), fr * Vector3(0.02, ly, z1)], Vector3.DOWN, SHIKKUI.darkened(0.2))
	# The roof: two slopes, their undersides, the eaves' edges, the gable ends, a round ridge.
	var ry: float = h + 0.55
	var ey: float = h + 0.1
	var ew := 0.72
	var th := 0.09
	var sl: float = Vector2(ew, ry - ey).length()
	for sz in [1.0, -1.0]:
		var n: Vector3 = (nrm * sz * (ry - ey) + Vector3.UP * ew).normalized()
		var p: Array = [fr * Vector3(-0.08, ey, sz * ew), fr * Vector3(l + 0.08, ey, sz * ew), fr * Vector3(l + 0.08, ry, 0), fr * Vector3(-0.08, ry, 0)]
		pk.quad(kit, "kawara", p, n, roofc, [Vector2(0, 0), Vector2(l + 0.16, 0) * uvk, Vector2(l + 0.16, sl) * uvk, Vector2(0, sl) * uvk])
		var dn := Vector3(0, -th, 0)
		pk.quad(kit, "sugi", [p[0] + dn, p[1] + dn, fr * Vector3(l + 0.08, h + 0.1, sz * (hw + 0.06)), fr * Vector3(-0.08, h + 0.1, sz * (hw + 0.06))], -n, CEDAR_DARK.darkened(0.2))
		pk.quad(kit, "kawara", [p[0] + dn, p[1] + dn, p[1], p[0]], nrm * sz, roofc.darkened(0.16), [Vector2(0, 0), Vector2(l + 0.16, 0) * uvk, Vector2(l + 0.16, th) * uvk, Vector2(0, th) * uvk])
		if detail:
			var pitch: float = 0.42 / uvk
			var x := pitch * 0.5 - 0.08
			var ux: Vector3 = (fr.basis.x).normalized()
			while x < l + 0.08 - pitch * 0.3:
				var c: Vector3 = fr * Vector3(x, ey - pitch * 0.3, sz * (ew + 0.02))
				var pts: Array = []
				for q in range(6):
					var ang: float = TAU * float(q) / 6.0
					pts.append(c + (ux * cos(ang) + Vector3.UP * sin(ang)) * pitch * 0.4)
				for f in [[0, 1, 2], [0, 2, 3], [0, 3, 5], [3, 4, 5]]:
					pk.tri(kit, "kawara", pts[f[0]], pts[f[1]], pts[f[2]], nrm * sz, nrm * sz, nrm * sz, roofc.lightened(0.1), nrm * sz, Vector2(0.21, 0.3), Vector2(0.24, 0.3), Vector2(0.21, 0.33))
				x += pitch
	for e in [[-0.08, -1.0], [l + 0.08, 1.0]]:
		var u2: float = e[0]
		var o: Vector3 = dir * float(e[1])
		pk.tri(kit, "shikkui", fr * Vector3(u2, ey - th, -ew), fr * Vector3(u2, ey - th, ew), fr * Vector3(u2, ry, 0), o, o, o, face.darkened(0.1), o)
	pk.tube(kit, "kawara", fr * Vector3(-0.1, ry + 0.02, 0), fr * Vector3(l + 0.1, ry + 0.02, 0), 0.1, 0.1, 6, roofc.darkened(0.08), true, uvk)


## A roofed timber gate in a temple wall, centred on the origin, the passage along z, `w` wide and 2.85 high inside.
## Two posts carry a lintel and a little tiled roof (its eaves 1.5m before and behind, the verges 1m past the posts);
## two stay posts stand behind (z = -1.15); the plank leaves stand open along the passage's sides. 4.6m to the ridge.
static func wall_gate(pk: PropKit, kit: Dictionary, w := 3.2, labels: Array = []) -> void:
	var wood: Color = CEDAR_DARK.lightened(0.06)
	var px: float = w * 0.5 + 0.16
	var s := roof_spec(R_KIRIZUMA, Vector3(0, 3.42, -0.3), px + 1.0, 1.55, 0.85, "kawara", KAWARA.lerp(KAWARA_OLD, 0.4))
	s.lift = 0.1
	s.sori = 0.3
	s.n = 6
	s.m = 3
	s.wall_hx = px
	s.wall_zf = 0.2
	s.wall_zb = 0.2
	s.raft = 0.36
	s.raft_col = wood
	s.hafu_col = wood
	s.under_col = wood.darkened(0.2)
	s.crest = GOLD
	jroof(pk, kit, s)
	for sx in [-1.0, 1.0]:
		_mblock(pk, kit, "ishi", Vector3(sx * px - 0.26, FOOT, -0.26), Vector3(sx * px + 0.26, 0.16, 0.26), GRANITE)
		_post(pk, kit, "hinoki", sx * px, 0.0, 0.16, roof_under_y(s, Vector3(sx * px, 0, 0)) - 0.08, 0.32, wood)
		_mblock(pk, kit, "ishi", Vector3(sx * px - 0.18, FOOT, -1.33), Vector3(sx * px + 0.18, 0.12, -0.97), GRANITE)
		_post(pk, kit, "hinoki", sx * px, -1.15, 0.12, roof_under_y(s, Vector3(sx * px, 0, -1.15)) - 0.08, 0.2, wood)
		_beam(pk, kit, "hinoki", Vector3(sx * px, 2.2, -0.1), Vector3(sx * px, 2.2, -1.2), 0.1, 0.16, wood, Vector3(1, 0, 0))
		_beam(pk, kit, "hinoki", Vector3(sx * px, 3.25, 0.75), Vector3(sx * px, 3.25, -1.45), 0.14, 0.2, wood, Vector3(1, 0, 0))
		# An open leaf along the passage's side: planks, three ledges, iron studs.
		var lf := _wf(Vector3(sx * (w * 0.5 - 0.09), 0, -0.2 if sx < 0.0 else -0.2 - w * 0.48), Vector3(-sx, 0, 0))
		_rect(pk, kit, "sugi", lf, 0.0, 0.12, w * 0.48, 2.8, -0.06, 0.0, wood.lightened(0.08), true)
		for ly in [0.45, 1.45, 2.45]:
			_rect(pk, kit, "hinoki", lf, 0.0, ly, w * 0.48, ly + 0.12, 0.0, 0.035, wood.darkened(0.15))
			for k in range(4):
				_rect(pk, kit, "urushi", lf, 0.18 + 0.38 * float(k), ly + 0.03, 0.24 + 0.38 * float(k), ly + 0.09, 0.035, 0.05, BLACK_LAC)
	# The lintel and the purlins the rafters lie on.
	_beam(pk, kit, "hinoki", Vector3(-px - 0.55, 3.02, 0), Vector3(px + 0.55, 3.02, 0), 0.26, 0.3, wood, Vector3(0, 0, 1))
	_beam(pk, kit, "hinoki", Vector3(-px - 0.2, 3.02, -1.15), Vector3(px + 0.2, 3.02, -1.15), 0.14, 0.18, wood, Vector3(0, 0, 1))
	sakura_crest(pk, kit, "gold", Vector3(0, 3.02, 0.13 + TP), Vector3(0, 0, 1), 0.12, GOLD)
	if labels != null and false:
		labels.append(["", Vector3.ZERO, Vector3(0, 0, 1), 0.2, GOLD, 1.0])


# ======================================================================================
#  The tea house, the festival stalls
# ======================================================================================

## A stack of split firewood against a wall: log ends in rows over a dark body, in a wall frame.
static func _woodpile(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, u1: float, v0: float, v1: float, depth: float, rng: RandomNumberGenerator) -> void:
	_rect(pk, kit, "sugi", wf, u0, v0, u1, v1, 0.0, depth, Color(0.16, 0.11, 0.08))
	var nf: Vector3 = wf.basis.z.normalized()
	var r := 0.085
	var row := 0
	var y := v0 + r
	while y < v1 - r * 0.6:
		var x: float = u0 + r + (r if row % 2 == 1 else 0.0)
		while x < u1 - r * 0.6:
			var rr: float = r * (0.8 + rng.randf() * 0.3)
			var c: Vector3 = wf * Vector3(x, y, depth + 0.012 + rng.randf() * 0.03)
			var a0: float = rng.randf() * TAU
			var col: Color = HINOKI.darkened(0.1 + rng.randf() * 0.3)
			var pts: Array = []
			for k in range(5):
				var ang: float = a0 + TAU * float(k) / 5.0
				pts.append(c + (wf.basis.x * cos(ang) + Vector3.UP * sin(ang)) * rr)
			for f in [[0, 1, 2], [0, 2, 3], [0, 3, 4]]:
				pk.tri(kit, "hinoki", pts[f[0]], pts[f[1]], pts[f[2]], nf, nf, nf, col, nf)
			x += r * 2.05
		y += r * 1.8
		row += 1


## An iron kettle on a clay hearth at p.
static func _hearth(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	pk.lathe(kit, "tsuchi", p, [Vector2(0.42, 0.0), Vector2(0.44, 0.45), Vector2(0.36, 0.6), Vector2(0.24, 0.62), Vector2(0.001, 0.56)], 8, TSUCHI.darkened(0.2))
	pk.lathe(kit, "urushi", p + Vector3(0, 0.58, 0), [Vector2(0.001, 0.0), Vector2(0.2, 0.02), Vector2(0.27, 0.16), Vector2(0.22, 0.3), Vector2(0.1, 0.34), Vector2(0.001, 0.36)], 8, Color(0.09, 0.09, 0.10))
	pk.tube(kit, "urushi", p + Vector3(0.2, 0.8, 0), p + Vector3(0.38, 0.9, 0), 0.03, 0.02, 4, Color(0.09, 0.09, 0.10), false)


## The tea house of the mountain viewpoint: front z = 0 facing +z, x 0..9, 5.5 deep, open to the front under a hipped
## roof of bark (its eaves 1.15 out all round): benches with red felt, a red parasol (to z = +2.6), a noren along the
## front beam, a kettle on its hearth, a matted floor at the back. 5.4m high.
static func chaya(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var wood := Color(0.33, 0.23, 0.16)
	var w := 9.0
	var d := 5.5
	var by := 2.45
	_mblock(pk, kit, "ishi", Vector3(-0.1, FOOT, -d - 0.1), Vector3(w + 0.1, 0.12, 0.1), GRANITE.darkened(0.1))
	var s := roof_spec(R_YOSEMUNE, Vector3(w * 0.5, 0, -d * 0.5), w * 0.5 + 1.15, d * 0.5 + 1.15, 2.5, "hiwada", HIWADA.lightened(0.3))
	s.thick = 0.3
	s.lift = 0.22
	s.sori = 0.4
	s.n = 10
	s.m = 4
	s.wall_hx = w * 0.5
	s.wall_zf = d * 0.5
	s.wall_zb = d * 0.5
	s.raft = 0.5
	s.raft_col = wood
	s.under_col = wood.darkened(0.3)
	s.ridge_key = "hiwada"
	s.ridge_col = HIWADA.lightened(0.15)
	s.ridge_h = 0.3
	s.oni = false
	s.c = Vector3(w * 0.5, by + 0.3 - _rf_front(s, 0.0, d * 0.5) + 0.005, -d * 0.5)
	jroof(pk, kit, s)
	# Posts and the beams on them.
	for x in [0.09, 3.0, 6.0, w - 0.09]:
		for z in [-0.09, -d + 0.09]:
			_post(pk, kit, "hinoki", x, z, 0.12, by - 0.2, 0.18, wood)
	for z in [-0.09, -d + 0.09]:
		_beam(pk, kit, "hinoki", Vector3(0, by - 0.1, z), Vector3(w, by - 0.1, z), 0.2, 0.22, wood, Vector3(0, 0, 1))
	for x in [0.09, w - 0.09]:
		_beam(pk, kit, "hinoki", Vector3(x, by - 0.11, -0.2), Vector3(x, by - 0.11, -d + 0.2), 0.2, 0.2, wood, Vector3(1, 0, 0))
		_post(pk, kit, "hinoki", x, -d * 0.5, 0.12, by - 0.21, 0.16, wood)
	# The back wall and the left end: earth over a boarded skirt; the right end half open over a low wall.
	var bf := _wf(Vector3(w, 0, -d + 0.09), Vector3(0, 0, -1))
	_rect(pk, kit, "tsuchi", bf, 0.18, 0.9, w - 0.18, by - 0.21, -0.06, 0.0, TSUCHI, true)
	_rect(pk, kit, "sugi", bf, 0.18, 0.12, w - 0.18, 0.9, -0.065, 0.02, wood.darkened(0.15), true)
	var lf := _wf(Vector3(0.09, 0, -d), Vector3(-1, 0, 0))
	_rect(pk, kit, "tsuchi", lf, 0.18, 0.9, d - 0.18, by - 0.21, -0.06, 0.0, TSUCHI, true)
	_rect(pk, kit, "sugi", lf, 0.18, 0.12, d - 0.18, 0.9, -0.065, 0.02, wood.darkened(0.15), true)
	var rf := _wf(Vector3(w - 0.09, 0, 0), Vector3(1, 0, 0))
	_rect(pk, kit, "sugi", rf, 0.18, 0.12, d - 0.18, 0.9, -0.065, 0.02, wood.darkened(0.15), true)
	_rect(pk, kit, "tsuchi", rf, d * 0.5 + 0.08, 0.9, d - 0.18, by - 0.21, -0.06, 0.0, TSUCHI, true)
	# The matted floor along the back, a lit paper screen behind it.
	_slab(pk, kit, "hinoki", Transform3D.IDENTITY, 0.2, 6.0, -d + 0.2, -d + 2.4, 0.12, 0.5, wood.lightened(0.08))
	pk.quad(kit, "rope", [Vector3(0.2, 0.506, -d + 0.2), Vector3(6.0, 0.506, -d + 0.2), Vector3(6.0, 0.506, -d + 2.36), Vector3(0.2, 0.506, -d + 2.36)], Vector3.UP, STRAW.lerp(BAMBOO, 0.3))
	var sf := _wf(Vector3(0, 0, -d + 0.2), Vector3(0, 0, 1))
	_face(pk, kit, "washi", sf, 0.6, 0.65, 5.6, 2.0, 0.0, PAPER_WARM.lerp(PAPER, 0.5))
	_bars(pk, kit, "hinoki", sf, 0.6, 5.6, 0.65, 2.0, 9, 0.035, 0.0, 0.03, wood)
	_hbars(pk, kit, "hinoki", sf, 0.6, 5.6, 0.65, 2.0, 4, 0.03, 0.0, 0.022, wood)
	# The hearth, benches inside and out, the parasol.
	_hearth(pk, kit, Vector3(7.5, 0.12, -d + 1.5))
	_slab(pk, kit, "hinoki", Transform3D.IDENTITY, 6.6, 8.5, -d + 0.3, -d + 0.75, 0.12, 0.8, wood.lightened(0.05))
	_felt_bench(pk, kit, Vector3(2.0, 0.12, -1.3), Vector3(0, 0, 1), 2.2, 0.6)
	_felt_bench(pk, kit, Vector3(5.2, 0.12, -1.6), Vector3(0, 0, 1), 2.0, 0.6)
	_felt_bench(pk, kit, Vector3(2.4, 0, 1.6), Vector3(0, 0, 1), 2.0, 0.55)
	_felt_bench(pk, kit, Vector3(6.6, 0, 2.3), Vector3(-0.0, 0, 1), 1.8, 0.55)
	_parasol(pk, kit, Vector3(4.6, 0, 1.55), 2.5, 1.2)
	# The noren along the front beam, the name board over the middle bay, a lantern on the corner post.
	var ff := _wf(Vector3(0, 0, 0), Vector3(0, 0, 1))
	_noren(pk, kit, ff, 0.3, 2.85, by - 0.24, 0.42, 5, INDIGO, PAPER, 0.06)
	_noren(pk, kit, ff, 6.15, w - 0.3, by - 0.24, 0.42, 5, INDIGO, PAPER, 0.06)
	_sign_board(pk, kit, ff, 4.5, by - 0.55, 2.0, "CHAYA", labels, wood, 0.3)
	chochin(pk, kit, Vector3(w + 0.35, by - 0.75, 0.3), 0.2, 0.6, PAPER_RED, 8, BLACK_LAC, Vector3(0, 0, 1), 0.12)
	_beam(pk, kit, "hinoki", Vector3(w - 0.09, by - 0.32, 0.3), Vector3(w + 0.5, by - 0.32, 0.3), 0.05, 0.05, wood, Vector3(0, 0, 1))


const YATAI_NAMES := ["TAKOYAKI", "RINGO AME", "KINGYO", "OMEN"]
const YATAI_STRIPES := [[Color(0.86, 0.12, 0.10), Color(0.96, 0.95, 0.90)], [Color(0.96, 0.95, 0.90), Color(0.92, 0.42, 0.55)], [Color(0.16, 0.36, 0.66), Color(0.96, 0.95, 0.90)],
		[Color(0.95, 0.76, 0.20), Color(0.86, 0.12, 0.10)]]


## A festival food stall: front z = 0 facing +z, x 0..2.7, 1.8 deep, 2.6 high: a timber frame under a striped cloth
## roof with a valance, a counter with its goods (0 takoyaki, 1 candied apples and bananas, 2 goldfish scooping,
## 3 masks), a row of small paper lanterns along the front (to z = +0.25).
static func yatai(pk: PropKit, kit: Dictionary, variant: int, rng: RandomNumberGenerator, labels: Array) -> void:
	var v: int = posmod(variant, 4)
	var w := 2.7
	var d := 1.8
	var hf := 2.35
	var hb := 2.05
	var wood: Color = HINOKI.darkened(0.2 + rng.randf() * 0.2)
	var st: Array = YATAI_STRIPES[(v + (rng.randi() % 2) * 2) % 4] if rng.randf() < 0.5 else YATAI_STRIPES[v]
	for x in [0.04, w - 0.04]:
		_post(pk, kit, "hinoki", x, -0.04, 0.0, hf, 0.07, wood)
		_post(pk, kit, "hinoki", x, -d + 0.04, 0.0, hb, 0.07, wood)
		_beam(pk, kit, "hinoki", Vector3(x, hf - 0.03, -0.04), Vector3(x, hb - 0.03, -d + 0.04), 0.05, 0.06, wood, Vector3(1, 0, 0))
		_beam(pk, kit, "hinoki", Vector3(x, 0.5, -0.04), Vector3(x, 0.5, -d + 0.04), 0.04, 0.05, wood, Vector3(1, 0, 0))
	_beam(pk, kit, "hinoki", Vector3(0, hf - 0.03, -0.04), Vector3(w, hf - 0.03, -0.04), 0.05, 0.06, wood, Vector3(0, 0, 1))
	_beam(pk, kit, "hinoki", Vector3(0, hb - 0.03, -d + 0.04), Vector3(w, hb - 0.03, -d + 0.04), 0.05, 0.06, wood, Vector3(0, 0, 1))
	# The cloth: stripes from the front's edge (a hand before the frame) back over the stall, a valance hanging in front
	# and down both sides, and a back sheet.
	var n := 9
	var nn := Vector3(0, d + 0.3, hf - hb).normalized()
	for i in range(n):
		var a: float = -0.12 + (w + 0.24) * float(i) / float(n)
		var b: float = -0.12 + (w + 0.24) * float(i + 1) / float(n)
		var col: Color = st[i % 2]
		pk.quad(kit, "cloth", [Vector3(a, hf + 0.03, 0.2), Vector3(b, hf + 0.03, 0.2), Vector3(b, hb + 0.0, -d - 0.08), Vector3(a, hb + 0.0, -d - 0.08)], nn, col)
		pk.quad(kit, "cloth", [Vector3(a, hf - 0.32, 0.215), Vector3(b, hf - 0.32, 0.215), Vector3(b, hf + 0.03, 0.2), Vector3(a, hf + 0.03, 0.2)], Vector3(0, 0, 1), col.darkened(0.06))
	for sx in [[-0.12, -1.0], [w + 0.12, 1.0]]:
		for i in range(4):
			var za: float = lerpf(0.2, -d - 0.08, float(i) / 4.0)
			var zb: float = lerpf(0.2, -d - 0.08, float(i + 1) / 4.0)
			var ya: float = lerpf(hf + 0.03, hb, float(i) / 4.0)
			var yb: float = lerpf(hf + 0.03, hb, float(i + 1) / 4.0)
			pk.quad(kit, "cloth", [Vector3(float(sx[0]), ya - 0.33, za), Vector3(float(sx[0]), yb - 0.33, zb), Vector3(float(sx[0]), yb, zb), Vector3(float(sx[0]), ya, za)],
					Vector3(float(sx[1]), 0, 0), (st[i % 2] as Color).darkened(0.06))
	pk.quad(kit, "cloth", [Vector3(0.0, 0.2, -d + 0.0), Vector3(w, 0.2, -d + 0.0), Vector3(w, hb - 0.06, -d + 0.0), Vector3(0.0, hb - 0.06, -d + 0.0)], Vector3(0, 0, -1), (st[1] as Color).darkened(0.1))
	# The name on a board across the valance and the lanterns under it.
	var ff := _wf(Vector3(0, 0, 0.215), Vector3(0, 0, 1))
	_rect(pk, kit, "hinoki", ff, 0.45, hf - 0.27, w - 0.45, hf - 0.03, 0.01, 0.035, PAPER)
	labels.append([YATAI_NAMES[v], Vector3(w * 0.5, hf - 0.15, 0.26), Vector3(0, 0, 1), 0.15, VERMILION if v != 2 else INDIGO, w - 1.1])
	for i in range(5):
		var lx: float = 0.3 + (w - 0.6) * float(i) / 4.0
		chochin(pk, kit, Vector3(lx, hf - 0.56, 0.1), 0.085, 0.2, PAPER_RED if i % 2 == 0 else PAPER, 6, Color(0, 0, 0, 0), Vector3(0, 0, 1), 0.05)
	pk.tube(kit, "rope", Vector3(0.04, hf - 0.39, 0.1), Vector3(w - 0.04, hf - 0.39, 0.1), 0.008, 0.008, 3, BLACK_LAC, false)
	for x in [0.04, w - 0.04]:
		_beam(pk, kit, "hinoki", Vector3(x, hf - 0.39, -0.04), Vector3(x, hf - 0.39, 0.12), 0.03, 0.03, wood, Vector3(1, 0, 0))
	# The counter: a top on a clothed front.
	var ch := 0.86
	if v != 2:
		_slab(pk, kit, "hinoki", Transform3D.IDENTITY, 0.08, w - 0.08, -0.72, -0.02, ch - 0.04, ch, wood.lightened(0.12))
		pk.quad(kit, "cloth", [Vector3(0.08, 0.06, -0.03), Vector3(w - 0.08, 0.06, -0.03), Vector3(w - 0.08, ch - 0.04, -0.03), Vector3(0.08, ch - 0.04, -0.03)], Vector3(0, 0, 1), st[0])
		sakura_crest(pk, kit, "cloth", Vector3(w * 0.5, 0.46, -0.03 + TP), Vector3(0, 0, 1), 0.2, st[1])
	match v:
		0:
			# The griddle with its rows of dumplings, a stack of boat trays, sauce pots.
			_slab(pk, kit, "urushi", Transform3D.IDENTITY, 0.3, 1.5, -0.62, -0.14, ch, ch + 0.06, Color(0.08, 0.08, 0.09))
			for i in range(7):
				for j in range(3):
					_blob(pk, kit, "urushi", Vector3(0.42 + 0.16 * float(i), ch + 0.075, -0.52 + 0.14 * float(j)), Vector3(0.05, 0.035, 0.05), Color(0.62, 0.42, 0.2).darkened(rng.randf() * 0.25))
			for k in range(4):
				_slab(pk, kit, "hinoki", Transform3D.IDENTITY, 1.75, 2.1, -0.5, -0.3, ch + 0.03 * float(k), ch + 0.03 * float(k) + 0.022, HINOKI.lightened(0.1))
			for k in range(2):
				pk.lathe(kit, "urushi", Vector3(2.3, ch, -0.25 - 0.25 * float(k)), [Vector2(0.001, 0.0), Vector2(0.07, 0.0), Vector2(0.08, 0.14), Vector2(0.001, 0.14)], 6, [Color(0.3, 0.14, 0.08), PAPER][k])
		1:
			# Candied apples on sticks in a rack, a row of chocolate bananas.
			_slab(pk, kit, "hinoki", Transform3D.IDENTITY, 0.25, 1.45, -0.6, -0.2, ch, ch + 0.1, HINOKI)
			for i in range(6):
				for j in range(2):
					var p := Vector3(0.36 + 0.2 * float(i), ch + 0.1, -0.5 + 0.2 * float(j))
					pk.tube(kit, "hinoki", p, p + Vector3(0, 0.3, 0), 0.008, 0.008, 3, BAMBOO_DRY, false)
					_blob(pk, kit, "pane", p + Vector3(0, 0.3, 0), Vector3(0.065, 0.065, 0.065), Color(0.82, 0.06, 0.08))
			for i in range(6):
				var q := Vector3(1.7 + 0.14 * float(i), ch, -0.4)
				pk.tube(kit, "hinoki", q, q + Vector3(0, 0.16, 0.0), 0.007, 0.007, 3, BAMBOO_DRY, false)
				pk.tube(kit, "urushi", q + Vector3(0, 0.14, 0), q + Vector3(0.02, 0.36, 0.03), 0.03, 0.022, 5, [Color(0.3, 0.16, 0.08), PAPER_PINK, Color(0.95, 0.85, 0.3)][i % 3], true)
			_slab(pk, kit, "hinoki", Transform3D.IDENTITY, 1.62, 2.5, -0.47, -0.33, ch, ch + 0.04, HINOKI)
		2:
			# A wide shallow tub of water with goldfish on the ground, paper scoops and bowls on its rim, a low stool.
			_slab(pk, kit, "urushi", Transform3D.IDENTITY, 0.25, w - 0.25, -1.15, -0.1, 0.0, 0.34, Color(0.20, 0.42, 0.70))
			pk.quad(kit, "pane", [Vector3(0.31, 0.345, -1.09), Vector3(w - 0.31, 0.345, -1.09), Vector3(w - 0.31, 0.345, -0.16), Vector3(0.31, 0.345, -0.16)], Vector3.UP, Color(0.30, 0.62, 0.80))
			for k in range(14):
				var fp := Vector3(0.45 + rng.randf() * (w - 0.9), 0.352, -1.0 + rng.randf() * 0.75)
				var fa: float = rng.randf() * TAU
				var fd := Vector3(cos(fa), 0, sin(fa))
				var fc: Color = [Color(0.95, 0.36, 0.08), Color(0.92, 0.2, 0.1), Color(0.95, 0.92, 0.88), Color(0.1, 0.1, 0.1)][rng.randi() % 4 if rng.randf() < 0.4 else 0]
				pk.tri(kit, "urushi", fp + fd * 0.05, fp - fd * 0.03 + Vector3(-fd.z, 0, fd.x) * 0.02, fp - fd * 0.03 - Vector3(-fd.z, 0, fd.x) * 0.02, Vector3.UP, Vector3.UP, Vector3.UP, fc, Vector3.UP)
				pk.tri(kit, "urushi", fp - fd * 0.03, fp - fd * 0.07 + Vector3(-fd.z, 0, fd.x) * 0.025, fp - fd * 0.07 - Vector3(-fd.z, 0, fd.x) * 0.025, Vector3.UP, Vector3.UP, Vector3.UP, fc, Vector3.UP)
			for k in range(4):
				pk.lathe(kit, "urushi", Vector3(0.5 + 0.55 * float(k), 0.34, -0.13), [Vector2(0.001, 0.0), Vector2(0.05, 0.0), Vector2(0.08, 0.05), Vector2(0.001, 0.045)], 6, [PAPER, Color(0.3, 0.6, 0.8)][k % 2])
			_slab(pk, kit, "hinoki", Transform3D.IDENTITY, w * 0.5 - 0.2, w * 0.5 + 0.2, -1.65, -1.3, 0.0, 0.3, wood)
		3:
			# Masks on a lattice rack leaning back behind the counter: fox and plain faces, in rows.
			var rf := Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(0, ch + 0.02, -0.55))
			var rw := _wf(Vector3.ZERO, Vector3(0, 0, 1))
			rw = rf * rw
			_bars(pk, kit, "hinoki", rw, 0.2, w - 0.2, 0.0, 1.2, 9, 0.025, -0.02, 0.0, wood)
			_hbars(pk, kit, "hinoki", rw, 0.2, w - 0.2, 0.0, 1.2, 4, 0.025, -0.02, 0.006, wood)
			for j in range(3):
				for i in range(5):
					var mc: Vector3 = rw * Vector3(0.45 + (w - 0.9) * float(i) / 4.0, 0.2 + 0.4 * float(j), 0.05)
					var fox: bool = (i + j) % 2 == 0
					var mcol: Color = PAPER if fox else [Color(0.86, 0.2, 0.14), Color(0.95, 0.8, 0.7), Color(0.3, 0.5, 0.8)][(i + j * 2) % 3]
					_ball(pk, kit, "urushi", mc, 0.13, mcol, 6, 3, 1.25)
					if fox:
						for se in [-1.0, 1.0]:
							var e0: Vector3 = mc + rw.basis * Vector3(se * 0.07, 0.12, 0.02)
							var o: Vector3 = rw.basis.z
							pk.tri(kit, "urushi", e0 + rw.basis * Vector3(-0.045, 0, 0), e0 + rw.basis * Vector3(0.045, 0, 0), e0 + rw.basis * Vector3(se * 0.02, 0.12, 0), o, o, o, VERMILION, o)
			_slab(pk, kit, "hinoki", Transform3D.IDENTITY, 0.3, 1.0, -0.4, -0.12, ch, ch + 0.12, VERMILION_OLD)


# ======================================================================================
#  The bell tower, the Shinto hall, the farmhouse, the pilgrims' lodge
# ======================================================================================

## The temple's bell tower (shoro), centred: a stone podium 5.4m square (steps toward +z), four posts leaning in under a
## tiled hip-and-gable roof (7.6 x 7m at its eaves), the bronze bell and its striking beam on ropes. 8.2m high.
static func bell_tower(pk: PropKit, kit: Dictionary) -> void:
	var wood := Color(0.38, 0.27, 0.19)
	var py := 1.0
	_mblock(pk, kit, "ishi", Vector3(-2.7, FOOT, -2.7), Vector3(2.7, py, 2.7), GRANITE)
	for i in range(1, 5):
		_mblock(pk, kit, "ishi", Vector3(-1.0, FOOT, 2.7 + 0.32 * float(i - 1)), Vector3(1.0, py - 0.2 * float(i), 2.7 + 0.32 * float(i)), GRANITE.lightened(0.03 * float(i % 2)))
	var top := 5.0
	var f0 := 2.05
	var f1 := 1.62
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pk.lathe(kit, "ishi", Vector3(sx * f0, py, sz * f0), [Vector2(0.34, -0.2), Vector2(0.34, 0.08), Vector2(0.26, 0.14), Vector2(0.001, 0.14)], 8, GRANITE.darkened(0.1))
			_beam(pk, kit, "hinoki", Vector3(sx * f0, py + 0.1, sz * f0), Vector3(sx * f1, top, sz * f1), 0.34, 0.34, wood, Vector3(1, 0, 0))
	# Ties between the posts at two heights (they stand on the posts' slope) and the plates on their heads.
	for y in [py + 1.2, top - 0.9, top + 0.02]:
		var k: float = lerpf(f0, f1, (y - py - 0.1) / (top - py - 0.1))
		var e: float = k + (0.5 if y > top else 0.35)
		for sg in [-1.0, 1.0]:
			_beam(pk, kit, "hinoki", Vector3(-e, y, sg * k), Vector3(e, y, sg * k), 0.2, 0.26, wood, Vector3(0, 0, 1))
			_beam(pk, kit, "hinoki", Vector3(sg * k, y - 0.01, -e), Vector3(sg * k, y - 0.01, e), 0.2, 0.26, wood.darkened(0.05), Vector3(1, 0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bracket(pk, kit, "hinoki", Vector3(sx * f1, top + 0.15, sz * f1), Vector3(sx, 0, sz), 0.5, wood, 2)
	var ptop: float = top + 0.15 + 0.52
	var s := roof_spec(R_IRIMOYA, Vector3.ZERO, 3.8, 3.5, 2.3, "kawara", KAWARA.lerp(KAWARA_OLD, 0.5))
	s.sori = 0.45
	s.lift = 0.38
	s.thick = 0.16
	s.tb = 0.45
	s.gable_in = 0.4
	s.n = 8
	s.m = 5
	s.wall_hx = f1
	s.wall_zf = f1
	s.wall_zb = f1
	s.raft = 0.42
	s.raft_col = wood
	s.raft_end = WHITE_END
	s.under_col = wood.darkened(0.3)
	s.hafu_col = wood
	s.ridge_h = 0.3
	s.c = Vector3(0, ptop + 0.16 - _rf_front(s, 0.0, f1 + 0.4) + 0.005, 0)
	jroof(pk, kit, s)
	# The beam the bell hangs from, the bell, the striker on its two ropes.
	_beam(pk, kit, "hinoki", Vector3(-f1 - 0.3, top + 0.3, 0), Vector3(f1 + 0.3, top + 0.3, 0), 0.3, 0.34, wood, Vector3(0, 0, 1))
	var bt: float = top - 0.15
	pk.tube(kit, "urushi", Vector3(0, bt, 0), Vector3(0, top + 0.2, 0), 0.07, 0.07, 6, BRONZE.darkened(0.2), false)
	pk.lathe(kit, "urushi", Vector3(0, bt - 2.0, 0), [Vector2(0.001, 0.02), Vector2(0.74, 0.0), Vector2(0.8, 0.1), Vector2(0.72, 0.3), Vector2(0.7, 1.3), Vector2(0.6, 1.7), Vector2(0.34, 1.95), Vector2(0.001, 2.0)], 12, BRONZE)
	for y in [0.42, 1.25]:
		pk.tube(kit, "urushi", Vector3(0, bt - 2.0 + y, 0), Vector3(0, bt - 2.0 + y + 0.07, 0), 0.735, 0.735, 12, BRONZE.lightened(0.12), false)
	var sy: float = bt - 1.55
	pk.tube(kit, "hinoki", Vector3(0.95, sy, 0), Vector3(2.9, sy, 0), 0.11, 0.11, 7, HINOKI.darkened(0.25), true, uvk)
	for rx in [1.3, 2.5]:
		pk.tube(kit, "rope", Vector3(rx, sy, 0), Vector3(rx * 0.72, top - 0.9, 0), 0.018, 0.018, 4, STRAW.darkened(0.2), false)
	pk.tube(kit, "rope", Vector3(2.85, sy, 0), Vector3(2.85, sy - 1.2, 0), 0.018, 0.018, 4, STRAW.darkened(0.2), false)


## A small Shinto hall (haiden): front z = 0 facing +z, x centred (+-3.5), 6 deep, on a stone base with steps (to +1.5)
## under a canopy on two posts (to z = +2.6): a gabled roof of bark, a straw rope with white zigzag papers across the
## canopy, an offering box at the steps' head. 7.2m high.
static func shrine_hall(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var wood := Color(0.50, 0.38, 0.26)
	var py := 0.75
	_mblock(pk, kit, "ishi", Vector3(-4.1, FOOT, -6.5), Vector3(4.1, py, 0.0), GRANITE)
	for i in range(1, 4):
		_mblock(pk, kit, "ishi", Vector3(-1.9, FOOT, 0.02 + 0.36 * float(i - 1)), Vector3(1.9, py - 0.19 * float(i), 0.02 + 0.36 * float(i)), GRANITE.lightened(0.03 * float(i % 2)))
	var xs: Array = [-3.5, -1.3, 1.3, 3.5]
	var zs: Array = [-6.0, -3.25, -0.5]
	var y1 := 3.9
	_temple_storey(pk, kit, xs, zs, py, y1, {"key": "hinoki", "col": wood, "r": 0.16, "beam": 0.2, "segs": 8},
			{"front": ["lattice", "door", "lattice"], "back": ["boards"], "left": ["boards", "lattice"], "right": ["lattice", "boards"]})
	var s := roof_spec(R_KIRIZUMA, Vector3(0, 0, -3.25), 4.5, 4.1, 2.9, "hiwada", HIWADA.lightened(0.3))
	s.sori = 0.45
	s.lift = 0.3
	s.thick = 0.28
	s.n = 8
	s.m = 5
	s.wall_hx = 3.5
	s.wall_zf = 2.75
	s.wall_zb = 2.75
	s.raft = 0.42
	s.raft_col = wood
	s.under_col = wood.darkened(0.3)
	s.hafu_col = wood.darkened(0.1)
	s.ridge_h = 0.34
	s.ridge_key = "hinoki"
	s.ridge_col = wood.darkened(0.2)
	s.oni = false
	s.crest = GOLD
	s.c = Vector3(0, y1 + 0.28 - _rf_front(s, 0.0, 2.75) + 0.005, -3.25)
	jroof(pk, kit, s)
	roof_gable(pk, kit, s, 1.0, -2.75, 2.75, y1, "sugi", wood.darkened(0.1), 1.0)
	roof_gable(pk, kit, s, -1.0, -2.75, 2.75, y1, "sugi", wood.darkened(0.1), 1.0)
	# Crossed finials (chigi) and billets (katsuogi) on the ridge.
	var ry: float = (s.c as Vector3).y + 2.9 + 0.34
	for sx in [-1.0, 1.0]:
		for sg in [-1.0, 1.0]:
			_beam(pk, kit, "hinoki", Vector3(sx * 4.3, ry - 0.5, -3.25 - sg * 0.5), Vector3(sx * 4.3, ry + 1.0, -3.25 + sg * 1.0), 0.09, 0.2, wood.darkened(0.15), Vector3(1, 0, 0))
	for k in range(3):
		pk.tube(kit, "hinoki", Vector3(-2.6 + 2.6 * float(k), ry + 0.12, -3.25 - 0.55), Vector3(-2.6 + 2.6 * float(k), ry + 0.12, -3.25 + 0.55), 0.14, 0.14, 7, wood.darkened(0.1), true, uvk)
	# The canopy over the steps.
	var ks := pent_spec(-2.6, 2.6, -0.3, 0.0, 2.9, 0.95, "hiwada", HIWADA.lightened(0.3))
	ks.thick = 0.22
	ks.lift = 0.2
	ks.sori = 0.5
	ks.n = 6
	ks.m = 3
	ks.raft = 0.42
	ks.raft_col = wood
	ks.under_col = wood.darkened(0.3)
	var edge_z: float = -3.25 + 4.1
	ks.c = Vector3(0, roof_under_y(s, Vector3(0, 0, edge_z)) - 0.04 - _rf_front(ks, 0.0, edge_z + 0.3), -0.3)
	jroof(pk, kit, ks)
	var pz := 2.0
	var bt: float = roof_under_y(ks, Vector3(2.1, 0, pz)) - 0.1
	for sx in [-1.0, 1.0]:
		_mblock(pk, kit, "ishi", Vector3(sx * 2.1 - 0.22, FOOT, pz - 0.22), Vector3(sx * 2.1 + 0.22, 0.2, pz + 0.22), GRANITE.darkened(0.05))
		_post(pk, kit, "hinoki", sx * 2.1, pz, 0.2, bt - 0.3, 0.22, wood)
		_beam(pk, kit, "hinoki", Vector3(sx * 2.1, bt - 0.42, pz), Vector3(sx * 2.1, y1 - 0.25, -0.5), 0.14, 0.2, wood, Vector3(1, 0, 0))
	_beam(pk, kit, "hinoki", Vector3(-2.5, bt - 0.15, pz), Vector3(2.5, bt - 0.15, pz), 0.2, 0.3, wood, Vector3(0, 0, 1))
	# The shimenawa: a thick straw rope sagging between the posts, tassels and white zigzag papers hanging from it.
	var prev := Vector3.ZERO
	for i in range(9):
		var t: float = float(i) / 8.0
		var p := Vector3(lerpf(-2.0, 2.0, t), bt - 0.55 - 0.3 * sin(t * PI), pz + 0.14)
		if i > 0:
			pk.tube(kit, "rope", prev, p, 0.07 + 0.035 * sin((t - 0.06) * PI), 0.07 + 0.035 * sin(t * PI), 6, STRAW, i == 1 or i == 8)
		prev = p
	for k in range(4):
		var t2: float = (float(k) + 0.5) / 4.0
		var q := Vector3(lerpf(-2.0, 2.0, t2), bt - 0.66 - 0.3 * sin(t2 * PI), pz + 0.16)
		var zx := 0.0
		for j in range(3):
			var x0: float = q.x - 0.06 + zx
			pk.quad(kit, "cloth", [Vector3(x0, q.y - 0.16 * float(j + 1), q.z + 0.01 * float(j)), Vector3(x0 + 0.12, q.y - 0.16 * float(j + 1), q.z + 0.01 * float(j)),
					Vector3(x0 + 0.12, q.y - 0.16 * float(j), q.z + 0.01 * float(j)), Vector3(x0, q.y - 0.16 * float(j), q.z + 0.01 * float(j))], Vector3(0, 0, 1), PAPER)
			zx += 0.07 if j % 2 == 0 else -0.07
	for k in range(3):
		var t3: float = float(k + 1) / 4.0
		var q3 := Vector3(lerpf(-2.0, 2.0, t3), bt - 0.62 - 0.3 * sin(t3 * PI), pz + 0.14)
		pk.tube(kit, "rope", q3, q3 + Vector3(0, -0.4, 0), 0.03, 0.06, 5, STRAW.darkened(0.1), true)
	# The offering box at the head of the steps: slats over a boarded chest.
	_slab(pk, kit, "sugi", Transform3D.IDENTITY, -0.75, 0.75, -0.42, -0.04, py, py + 0.55, wood.darkened(0.2))
	for k in range(7):
		_slab(pk, kit, "hinoki", Transform3D.IDENTITY, -0.7 + 0.2 * float(k), -0.62 + 0.2 * float(k), -0.4, -0.06, py + 0.55, py + 0.6, wood.darkened(0.05))
	if labels != null and false:
		labels.append(["", Vector3.ZERO, Vector3(0, 0, 1), 0.2, GOLD, 1.0])


## The summit's hall (the Yamabushi Trail's precinct): a vermilion hall of worship on a granite podium, front z = 0
## facing +z, x centred (+-9.4), the back at -14.6; six steps before it (to z +2.4) under a step canopy whose front is a
## curved gable board (karahafu) with a gold crest, on two posts at z +3.0. A veranda all round behind a vermilion
## railing, the body three bays by two of vermilion columns with white plaster and lattice under bracket clusters, a
## hip-and-gable roof of dark tiles with gold crests, red lanterns hanging along the front, a bell and its rope over the
## offering box. About 13m high.
const SUMMIT_HALL_ROOF := Color(0.19, 0.20, 0.22)

static func summit_hall(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var red: Color = VERMILION.lerp(VERMILION_OLD, 0.3)
	var roofc: Color = SUMMIT_HALL_ROOF
	var py := 1.2
	_mblock(pk, kit, "ishi", Vector3(-9.4, FOOT, -14.6), Vector3(9.4, py, 0.0), GRANITE)
	_mblock(pk, kit, "ishi", Vector3(-9.55, FOOT, -14.75), Vector3(9.55, 0.25, 0.15), GRANITE.darkened(0.08))
	var fy: float = py + 0.12
	_slab(pk, kit, "sugi", Transform3D.IDENTITY, -9.15, 9.15, -14.35, -0.25, py - 0.01, fy, Color(0.52, 0.40, 0.28))
	# The steps: six granite treads between two cheek walls.
	var sw := 2.6
	for i in range(1, 7):
		_mblock(pk, kit, "ishi", Vector3(-sw, FOOT, 0.02 + 0.4 * float(i - 1)), Vector3(sw, py - 0.2 * float(i), 0.02 + 0.4 * float(i)), GRANITE.lightened(0.03 * float(i % 2)))
	for sx in [-1.0, 1.0]:
		var cf := _wf(Vector3(sx * sw if sx > 0.0 else sx * (sw + 0.45), 0, 0.0), Vector3(1, 0, 0))
		_prism(pk, kit, "ishi", cf, PackedVector2Array([Vector2(-2.5, FOOT), Vector2(-0.02, FOOT), Vector2(-0.02, py + 0.25), Vector2(-0.45, py + 0.25), Vector2(-2.5, 0.35)]), 0.0, 0.45,
				GRANITE.darkened(0.05), true)
	# The body: four by three vermilion columns.
	var xs: Array = [-6.3, -2.1, 2.1, 6.3]
	var zs: Array = [-11.6, -7.3, -3.0]
	var y1 := 5.4
	_temple_storey(pk, kit, xs, zs, fy, y1, {"key": "urushi", "col": red, "r": 0.3, "beam": 0.3, "base_r": 0.42},
			{"front": ["renji", "door", "renji"], "back": ["plaster", "plaster", "plaster"], "left": ["plaster", "renji"], "right": ["renji", "plaster"]})
	for f in [[Vector3(-6.3, 0, -3.0), Vector3(0, 0, 1), 12.6], [Vector3(6.3, 0, -11.6), Vector3(0, 0, -1), 12.6], [Vector3(6.3, 0, -3.0), Vector3(1, 0, 0), 8.6],
			[Vector3(-6.3, 0, -11.6), Vector3(-1, 0, 0), 8.6]]:
		_rect(pk, kit, "urushi", _wf(f[0], f[1]), 0.2, 4.0, float(f[2]) - 0.2, 4.22, 0.0, 0.2, red.darkened(0.06))
	var bsc := 0.8
	_bracket_ring(pk, kit, "urushi", xs, zs, y1, bsc, red)
	var ptop: float = y1 + 1.04 * bsc
	# The veranda's railing all round, open at the steps.
	_koran(pk, kit, "urushi", Vector3(-9.0, fy, -0.42), Vector3(-sw - 0.55, fy, -0.42), 0.9, red)
	_koran(pk, kit, "urushi", Vector3(sw + 0.55, fy, -0.42), Vector3(9.0, fy, -0.42), 0.9, red)
	_koran(pk, kit, "urushi", Vector3(-9.0, fy, -14.2), Vector3(9.0, fy, -14.2), 0.9, red)
	_koran(pk, kit, "urushi", Vector3(-9.0, fy, -14.2), Vector3(-9.0, fy, -0.42), 0.9, red)
	_koran(pk, kit, "urushi", Vector3(9.0, fy, -14.2), Vector3(9.0, fy, -0.42), 0.9, red)
	# The roof: hip-and-gable, dark tiles, the gables on the sides.
	var zc := -7.3
	var s := roof_spec(R_IRIMOYA, Vector3(0, 0, zc), 10.4, 8.0, 5.8, "kawara", roofc)
	s.sori = 0.55
	s.lift = 0.85
	s.thick = 0.36
	s.tb = 0.5
	s.gable_in = 0.8
	s.n = 14
	s.m = 6
	s.wall_hx = 6.3
	s.wall_zf = 4.3
	s.wall_zb = 4.3
	s.raft = 0.45
	s.raft_col = red.darkened(0.1)
	s.raft_end = GOLD
	s.raft_w = 0.1
	s.raft_d = 0.14
	s.under_col = red.darkened(0.35)
	s.hafu_col = roofc.lightened(0.1)
	s.ridge_h = 0.55
	s.ridge_col = roofc.darkened(0.1)
	s.crest = GOLD
	s.c = Vector3(0, ptop + 0.4 - _rf_front(s, 0.0, 4.3 + 0.8 * bsc) + 0.005, zc)
	jroof(pk, kit, s)
	# The step canopy (kohai): dark tiles from under the front eave out over the steps, on two posts.
	var kz := -1.0
	var kd := 4.4
	var ks := pent_spec(-4.3, 4.3, kz, 0.0, kd, 1.45, "kawara", roofc)
	ks.thick = 0.28
	ks.lift = 0.3
	ks.sori = 0.35
	ks.n = 8
	ks.m = 3
	ks.raft = 0.45
	ks.raft_col = red.darkened(0.1)
	ks.raft_end = GOLD
	ks.raft_w = 0.09
	ks.raft_d = 0.12
	ks.under_col = red.darkened(0.35)
	var edge_z: float = zc + 8.0
	var want: float = roof_under_y(s, Vector3(0, 0, edge_z)) - 0.05
	ks.c = Vector3(0, want - _rf_front(ks, 0.0, edge_z - kz), kz)
	jroof(pk, kit, ks)
	var pz := 3.0
	var bt: float = roof_under_y(ks, Vector3(3.5, 0, pz)) - 0.12
	for sx in [-1.0, 1.0]:
		var px: float = sx * 3.5
		_mblock(pk, kit, "ishi", Vector3(px - 0.38, FOOT, pz - 0.38), Vector3(px + 0.38, 0.3, pz + 0.38), GRANITE.darkened(0.05))
		_column(pk, kit, px, pz, 0.3, bt - 0.36, 0.25, red, "urushi", 10, 0.34)
		var hy: float = roof_under_y(ks, Vector3(px, 0, -2.6)) - 0.35
		_beam(pk, kit, "urushi", Vector3(px, bt - 0.58, pz), Vector3(px, minf(hy, y1 - 0.2), -3.0), 0.2, 0.28, red, Vector3(1, 0, 0))
		_bracket(pk, kit, "urushi", Vector3(px, bt - 0.36, pz), Vector3(0, 0, 1), 0.45, red, 1)
	_beam(pk, kit, "urushi", Vector3(-4.0, bt - 0.58, pz), Vector3(4.0, bt - 0.58, pz), 0.24, 0.38, red, Vector3(0, 0, 1))
	_beam(pk, kit, "urushi", Vector3(-4.2, bt - 0.08, pz), Vector3(4.2, bt - 0.08, pz), 0.18, 0.14, red.darkened(0.08), Vector3(0, 0, 1))
	# The karahafu: a curved gable board across the canopy's front, bowed up in the middle and swept down at its ends,
	# black lacquer edged in gold, a gold crest at its crown.
	var zf: float = kz + kd
	var hump := 1.15
	var half := 4.5
	var segs := 18
	var prev_lo := Vector3.ZERO
	var prev_hi := Vector3.ZERO
	for i in range(segs + 1):
		var t: float = lerpf(-1.0, 1.0, float(i) / float(segs))
		var x: float = t * half
		var ey: float = roof_y(ks, Vector3(clampf(x, -4.2, 4.2), 0, zf - 0.15))
		var bow: float = hump * pow(1.0 - t * t, 1.6)
		var lo := Vector3(x, ey - 0.2 + bow * 0.85, zf + 0.06)
		var hi := Vector3(x, ey + 0.3 + bow, zf + 0.06)
		if i > 0:
			var n: Vector3 = Vector3(0, 0, 1)
			pk.quad(kit, "urushi", [prev_lo, lo, hi, prev_hi], n, Color(0.07, 0.06, 0.06))
			pk.quad(kit, "urushi", [prev_lo + Vector3(0, 0, -0.14), lo + Vector3(0, 0, -0.14), hi + Vector3(0, 0, -0.14), prev_hi + Vector3(0, 0, -0.14)], -n, Color(0.07, 0.06, 0.06))
			pk.quad(kit, "urushi", [prev_hi, hi, hi + Vector3(0, 0, -0.14), prev_hi + Vector3(0, 0, -0.14)], Vector3.UP, roofc)
			pk.tube(kit, "gold", prev_hi + Vector3(0, -0.04, 0.03), hi + Vector3(0, -0.04, 0.03), 0.035, 0.035, 4, GOLD, false)
			pk.tube(kit, "gold", prev_lo + Vector3(0, 0.04, 0.03), lo + Vector3(0, 0.04, 0.03), 0.03, 0.03, 4, GOLD, false)
		prev_lo = lo
		prev_hi = hi
	var crown_y: float = roof_y(ks, Vector3(0, 0, zf - 0.15)) + hump * 0.85 - 0.2
	sakura_crest(pk, kit, "gold", Vector3(0, crown_y - 0.32, zf + 0.12), Vector3(0, 0, 1), 0.34, GOLD)
	# Gold crests on the side gables and over the doors.
	sakura_crest(pk, kit, "gold", Vector3(0, 4.7, -3.0 + 0.36), Vector3(0, 0, 1), 0.4, GOLD)
	# Red lanterns hanging along the front under the main eave and from the canopy's beam.
	for lx in [-7.6, -4.2, 4.2, 7.6]:
		var top_y: float = roof_under_y(s, Vector3(lx, 0, -1.2)) - 0.05
		var cy: float = minf(top_y - 1.25, 4.3)
		pk.tube(kit, "rope", Vector3(lx, top_y, -1.2), Vector3(lx, cy + 0.42, -1.2), 0.012, 0.012, 3, Color(0.1, 0.08, 0.06), false)
		chochin(pk, kit, Vector3(lx, cy, -1.2), 0.34, 0.85, PAPER_RED, 10, Color(0.08, 0.06, 0.05), Vector3(0, 0, 1))
	for lx2 in [-2.2, 2.2]:
		chochin(pk, kit, Vector3(lx2, bt - 1.15, pz), 0.3, 0.76, PAPER_RED, 10, Color(0.08, 0.06, 0.05), Vector3(0, 0, 1))
		pk.tube(kit, "rope", Vector3(lx2, bt - 0.58 - 0.19, pz), Vector3(lx2, bt - 0.77, pz), 0.012, 0.012, 3, Color(0.1, 0.08, 0.06), false)
	# The shimenawa across the canopy, the bell and its rope, the offering box at the head of the steps.
	var prev := Vector3.ZERO
	for i in range(11):
		var t2: float = float(i) / 10.0
		var p := Vector3(lerpf(-3.2, 3.2, t2), bt - 0.86 - 0.32 * sin(t2 * PI), pz + 0.16)
		if i > 0:
			pk.tube(kit, "rope", prev, p, 0.08 + 0.04 * sin((t2 - 0.05) * PI), 0.08 + 0.04 * sin(t2 * PI), 6, STRAW, i == 1 or i == 10)
		prev = p
	for k in range(5):
		var t3: float = (float(k) + 0.5) / 5.0
		var q := Vector3(lerpf(-3.2, 3.2, t3), bt - 0.98 - 0.32 * sin(t3 * PI), pz + 0.2)
		var zx := 0.0
		for j in range(3):
			var x0: float = q.x - 0.06 + zx
			pk.quad(kit, "cloth", [Vector3(x0, q.y - 0.16 * float(j + 1), q.z + 0.01 * float(j)), Vector3(x0 + 0.12, q.y - 0.16 * float(j + 1), q.z + 0.01 * float(j)),
					Vector3(x0 + 0.12, q.y - 0.16 * float(j), q.z + 0.01 * float(j)), Vector3(x0, q.y - 0.16 * float(j), q.z + 0.01 * float(j))], Vector3(0, 0, 1), PAPER)
			zx += 0.07 if j % 2 == 0 else -0.07
	var bell_top := Vector3(0, bt - 0.8, 1.6)
	pk.lathe(kit, "gold", bell_top + Vector3(0, -0.55, 0), [Vector2(0.001, 0.0), Vector2(0.2, 0.05), Vector2(0.27, 0.22), Vector2(0.2, 0.4), Vector2(0.001, 0.45)], 10, GOLD.darkened(0.1))
	for k in range(3):
		var a: float = float(k) * 0.07 - 0.07
		pk.tube(kit, "cloth", bell_top + Vector3(a, -0.6, 0), bell_top + Vector3(a, -2.45, 0.05), 0.035, 0.035, 5, [PAPER_RED, PAPER, PAPER_RED][k], true)
	_slab(pk, kit, "sugi", Transform3D.IDENTITY, -0.9, 0.9, -0.9, -0.42, fy, fy + 0.6, Color(0.30, 0.20, 0.13))
	for k in range(8):
		_slab(pk, kit, "hinoki", Transform3D.IDENTITY, -0.86 + 0.22 * float(k), -0.76 + 0.22 * float(k), -0.88, -0.44, fy + 0.6, fy + 0.65, Color(0.36, 0.25, 0.16))
	if labels != null and false:
		labels.append(["", Vector3.ZERO, Vector3(0, 0, 1), 0.3, GOLD, 2.0])


## A farmhouse (kominka): front z = 0 facing +z, x 0..w, back -d (about 12 x 7.5): earthen walls in a dark timber
## frame under a thick hipped roof of thatch (1.1 out all round), a veranda (engawa) along the front before paper
## screens, a woodpile under the eaves at the right end.
static func kominka(pk: PropKit, kit: Dictionary, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var wood: Color = (WOODS[rng.randi() % WOODS.size()] as Color).lightened(0.04)
	var earth: Color = TSUCHI.darkened(rng.randf() * 0.15)
	var wy: float = 2.5 + rng.randf() * 0.2
	_mblock(pk, kit, "ishi", Vector3(-0.08, FOOT, -d - 0.08), Vector3(w + 0.08, 0.2, 0.08), GRANITE_MOSSY)
	var s := roof_spec(R_YOSEMUNE, Vector3(w * 0.5, 0, -d * 0.5), w * 0.5 + 1.1, d * 0.5 + 1.1, (d * 0.5 + 1.1) * (0.95 + rng.randf() * 0.15), "hiwada", STRAW.lerp(HIWADA, 0.45))
	s.thick = 0.5
	s.lift = 0.0
	s.sori = 0.12
	s.n = 10
	s.m = 4
	s.wall_hx = w * 0.5
	s.wall_zf = d * 0.5
	s.wall_zb = d * 0.5
	s.raft = 0.6
	s.raft_col = wood
	s.under_col = STRAW.darkened(0.55)
	s.under_key = "hiwada"
	s.ridge_key = "hiwada"
	s.ridge_col = STRAW.lerp(HIWADA, 0.7)
	s.ridge_h = 0.4
	s.oni = false
	s.c = Vector3(w * 0.5, wy + 0.5 - _rf_front(s, 0.0, d * 0.5) + 0.005, -d * 0.5)
	jroof(pk, kit, s)
	# Bamboo poles holding the ridge's thatch down.
	var ry: float = (s.c as Vector3).y + float(s.rise) + 0.42
	var rr: float = w * 0.5 + 1.1 - (d * 0.5 + 1.1)
	for k in range(5):
		var x: float = w * 0.5 + rr * (float(k) / 2.0 - 1.0) * 0.9
		pk.tube(kit, "hinoki", Vector3(x, ry - 0.45, -d * 0.5 - 0.5), Vector3(x, ry + 0.02, -d * 0.5), 0.035, 0.035, 4, BAMBOO_DRY, false)
		pk.tube(kit, "hinoki", Vector3(x, ry - 0.45, -d * 0.5 + 0.5), Vector3(x, ry + 0.02, -d * 0.5), 0.035, 0.035, 4, BAMBOO_DRY, false)
	# The walls: earth in a frame, boards below on the ends and the back.
	var faces: Array = [[Vector3(0, 0, 0), Vector3(0, 0, 1), w], [Vector3(w, 0, -d), Vector3(0, 0, -1), w], [Vector3(w, 0, 0), Vector3(1, 0, 0), d], [Vector3(0, 0, -d), Vector3(-1, 0, 0), d]]
	for fi in range(4):
		var f: Array = faces[fi]
		var wf := _wf(f[0], f[1])
		var l: float = f[2]
		_face(pk, kit, "tsuchi", wf, 0.0, 0.2, l, wy, 0.0, earth)
		if fi > 0:
			_rect(pk, kit, "battens", wf, 0.16, 0.2, l - 0.16, 1.05, 0.0, TP, wood.darkened(0.2))
		var np: int = maxi(2, int(round(l / 1.9)))
		for i in range(np + 1):
			var u: float = clampf(l * float(i) / float(np) - 0.08, 0.0, l - 0.16)
			_rect(pk, kit, "hinoki", wf, u, 0.2, u + 0.16, wy - 0.18, 0.0, 0.04, wood)
		_rect(pk, kit, "hinoki", wf, 0.0, wy - 0.18, l, wy, 0.0, 0.055, wood)
		if fi > 0:
			_rect(pk, kit, "hinoki", wf, 0.16, 1.05, l - 0.16, 1.17, 0.0, 0.05, wood)
			var wu: float = l * 0.5 + 0.2
			_rect(pk, kit, "pane", wf, wu, 1.4, wu + 1.0, 2.05, 0.0, 0.02, DARK)
			_bars(pk, kit, "hinoki", wf, wu, wu + 1.0, 1.4, 2.05, 6, 0.045, 0.02, 0.06, wood)
	# The front: paper screens along the left two thirds behind the veranda, the earth-floored entrance on the right.
	var ff := _wf(Vector3(0, 0, 0), Vector3(0, 0, 1))
	var ex: float = w * 0.66
	var np2: int = maxi(3, int(round((ex - 0.3) / 0.95)))
	for i in range(np2):
		var a: float = lerpf(0.24, ex - 0.08, float(i) / float(np2))
		var b: float = lerpf(0.24, ex - 0.08, float(i + 1) / float(np2))
		_face(pk, kit, "washi", ff, a, 0.62, b, wy - 0.4, 0.02, PAPER.lerp(PAPER_WARM, rng.randf() * 0.5))
		_rect(pk, kit, "hinoki", ff, a, 0.62, a + 0.05, wy - 0.4, 0.02, 0.05, wood.lightened(0.06))
		_bars(pk, kit, "hinoki", ff, a + 0.05, b, 0.62, wy - 0.4, 3, 0.018, 0.02, 0.035, wood.lightened(0.08))
		_hbars(pk, kit, "hinoki", ff, a + 0.05, b, 0.62, wy - 0.4, 5, 0.018, 0.02, 0.03, wood.lightened(0.08))
	_rect(pk, kit, "hinoki", ff, 0.16, wy - 0.4, ex, wy - 0.3, 0.0, 0.07, wood)
	_slab(pk, kit, "sugi", ff, 0.1, ex, 0.0, 0.95, 0.5, 0.58, wood.lightened(0.12))
	for i in range(np2 + 1):
		var px: float = lerpf(0.2, ex - 0.1, float(i) / float(np2))
		_post(pk, kit, "hinoki", px, 0.85, FOOT, 0.5, 0.1, wood)
	for px2 in [0.2, ex * 0.5, ex - 0.1]:
		_post(pk, kit, "hinoki", px2, 0.88, 0.58, roof_under_y(s, Vector3(px2, 0, 0.88)) - 0.02, 0.11, wood)
	_mblock(pk, kit, "ishi", Vector3(ex * 0.3, FOOT, 0.98), Vector3(ex * 0.3 + 0.9, 0.24, 1.4), GRANITE_MOSSY.lightened(0.1))
	# The entrance: a wide plank door slid half open.
	_rect(pk, kit, "pane", ff, ex + 0.35, 0.2, ex + 1.3, 2.05, 0.0, 0.015, DARK)
	_rect(pk, kit, "sugi", ff, ex + 1.1, 0.2, ex + 2.2, 2.05, 0.0, 0.05, wood.lightened(0.1))
	_rect(pk, kit, "hinoki", ff, ex + 0.25, 2.05, minf(ex + 2.3, w - 0.16), 2.17, 0.0, 0.06, wood)
	if w - (ex + 2.4) > 1.0:
		_woodpile(pk, kit, ff, ex + 2.4, w - 0.2, 0.2, 1.25, 0.4, rng)
	else:
		_woodpile(pk, kit, _wf(Vector3(w, 0, -0.4), Vector3(1, 0, 0)), 0.0, minf(3.0, d - 1.0), 0.0, 1.2, 0.4, rng)


## The pilgrims' lodge of the mountain trail: front z = 0 facing +z, x 0..9, 6 deep: weathered boards on a stone footing
## under a low shingle roof weighted with stones, a stacked woodpile and a bench under the front eave (to z = +1.0),
## a stove pipe. 4.6m high.
static func mountain_hut(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var wood := Color(0.36, 0.30, 0.25)
	var w := 9.0
	var d := 6.0
	var wy := 2.45
	_mblock(pk, kit, "ishi", Vector3(-0.12, FOOT, -d - 0.12), Vector3(w + 0.12, 0.45, 0.12), GRANITE_MOSSY)
	var s := roof_spec(R_KIRIZUMA, Vector3(w * 0.5, 0, -d * 0.5 + 0.15), w * 0.5 + 0.6, d * 0.5 + 1.0, 1.35, "sugi", Color(0.42, 0.37, 0.32))
	s.thick = 0.1
	s.lift = 0.0
	s.sori = 0.0
	s.n = 4
	s.m = 4
	s.wall_hx = w * 0.5
	s.wall_zf = d * 0.5 - 0.15
	s.wall_zb = d * 0.5 + 0.15
	s.raft = 0.6
	s.raft_col = wood.darkened(0.2)
	s.under_col = wood.darkened(0.35)
	s.hafu_col = wood.darkened(0.2)
	s.ridge_key = "hinoki"
	s.ridge_col = wood.darkened(0.25)
	s.ridge_h = 0.16
	s.oni = false
	s.c = Vector3(w * 0.5, wy + 0.1 - _rf_front(s, 0.0, d * 0.5 - 0.15) + 0.005, -d * 0.5 + 0.15)
	jroof(pk, kit, s)
	var yb: float = roof_under_y(s, Vector3(w * 0.5, 0, -d))
	# Poles along the slopes with stones on them.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for sz in [1.0, -1.0]:
		for t in [0.3, 0.62, 0.9]:
			var z: float = -d * 0.5 + 0.15 + sz * (d * 0.5 + 1.0) * t
			var y: float = roof_y(s, Vector3(w * 0.5, 0, z))
			pk.tube(kit, "hinoki", Vector3(-0.5, y + 0.05, z), Vector3(w + 0.5, y + 0.05, z), 0.045, 0.045, 5, wood.darkened(0.1), true, uvk)
			var x := 0.3 + rng.randf() * 0.6
			while x < w - 0.2:
				_ball(pk, kit, "ishi", Vector3(x, y + 0.14, z + sz * 0.13), 0.14 + rng.randf() * 0.07, GRANITE.darkened(rng.randf() * 0.25), 5, 3, 0.7)
				x += 0.9 + rng.randf() * 0.9
	# The walls: boards, corner posts, the gables boarded too.
	var faces: Array = [[Vector3(0, 0, 0), Vector3(0, 0, 1), w, wy], [Vector3(w, 0, -d), Vector3(0, 0, -1), w, yb], [Vector3(w, 0, 0), Vector3(1, 0, 0), d, yb], [Vector3(0, 0, -d), Vector3(-1, 0, 0), d, yb]]
	for f in faces:
		var wf := _wf(f[0], f[1])
		_face(pk, kit, "sugi", wf, 0.0, 0.45, float(f[2]), float(f[3]), 0.0, wood)
		_rect(pk, kit, "hinoki", wf, 0.0, 0.45, 0.16, float(f[3]), 0.0, 0.035, wood.darkened(0.2))
		_rect(pk, kit, "hinoki", wf, float(f[2]) - 0.16, 0.45, float(f[2]), float(f[3]), 0.0, 0.035, wood.darkened(0.2))
	roof_gable(pk, kit, s, 1.0, -(d * 0.5 + 0.15), d * 0.5 - 0.15, yb, "sugi", wood.darkened(0.06), 0.6)
	roof_gable(pk, kit, s, -1.0, -(d * 0.5 + 0.15), d * 0.5 - 0.15, yb, "sugi", wood.darkened(0.06), 0.6)
	# The front: a plank door up two stone steps, two shuttered windows, the woodpile, a bench, the name.
	var ff := _wf(Vector3(0, 0, 0), Vector3(0, 0, 1))
	_rect(pk, kit, "sugi", ff, 3.9, 0.45, 4.9, 2.2, 0.0, 0.04, wood.darkened(0.25))
	for ly in [0.75, 1.9]:
		_rect(pk, kit, "hinoki", ff, 3.9, ly, 4.9, ly + 0.1, 0.04, 0.065, wood.darkened(0.4))
	_rect(pk, kit, "hinoki", ff, 3.78, 2.2, 5.02, 2.32, 0.0, 0.07, wood.darkened(0.3))
	_mblock(pk, kit, "ishi", Vector3(3.7, FOOT, 0.12), Vector3(5.1, 0.42, 0.5), GRANITE_MOSSY.lightened(0.08))
	_mblock(pk, kit, "ishi", Vector3(3.6, FOOT, 0.5), Vector3(5.2, 0.2, 0.9), GRANITE_MOSSY.lightened(0.04))
	for wu in [1.6, 6.3]:
		_rect(pk, kit, "pane", ff, wu, 1.3, wu + 0.9, 2.0, 0.0, 0.02, DARK)
		_rect(pk, kit, "hinoki", ff, wu - 0.08, 1.2, wu + 0.98, 1.3, 0.0, 0.06, wood.darkened(0.3))
		_rect(pk, kit, "hinoki", ff, wu + 0.42, 1.3, wu + 0.48, 2.0, 0.02, 0.05, wood.darkened(0.3))
		_rect(pk, kit, "sugi", ff, wu - 0.5, 1.3, wu - 0.02, 2.0, 0.0, 0.035, wood.darkened(0.2))
	_woodpile(pk, kit, ff, 6.2, 8.8, 0.45, 1.15, 0.4, rng)
	_woodpile(pk, kit, ff, 0.2, 1.3, 0.45, 1.0, 0.4, rng)
	_slab(pk, kit, "hinoki", ff, 1.6, 3.5, 0.5, 0.9, 0.42, 0.48, wood.lightened(0.1))
	for bu in [1.75, 3.35]:
		_mblock(pk, kit, "ishi", Vector3(bu - 0.12, FOOT, 0.55), Vector3(bu + 0.12, 0.42, 0.85), GRANITE_MOSSY)
	_sign_board(pk, kit, ff, 2.05, 2.24, 1.5, "YAMAGOYA", labels, wood, 0.15)
	# The stove pipe through the back slope.
	var pz: float = -d + 1.2
	var pyy: float = roof_y(s, Vector3(7.6, 0, pz))
	pk.tube(kit, "urushi", Vector3(7.6, pyy - 0.2, pz), Vector3(7.6, pyy + 1.0, pz), 0.08, 0.08, 6, Color(0.14, 0.13, 0.13), false)
	pk.lathe(kit, "urushi", Vector3(7.6, pyy + 1.0, pz), [Vector2(0.16, 0.0), Vector2(0.001, 0.14)], 6, Color(0.14, 0.13, 0.13))
	pk.lathe(kit, "urushi", Vector3(7.6, pyy + 0.995, pz), [Vector2(0.001, 0.0), Vector2(0.16, 0.0)], 6, Color(0.1, 0.1, 0.1))
