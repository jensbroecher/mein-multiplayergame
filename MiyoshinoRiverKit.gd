extends "res://MiyoshinoKit.gd"
## The Miyoshino GP's river and forestry kit: the Yoshino river's log rafts (ikada), the cedar forestry's log stacks,
## sawmill and boats (Part A, life size, grown by the generators' PROP_SCALE), and the structures the cars drive over
## (Part B, in GAME metres: make the kit with `new_kit(1.0)`): a timber trestle road bridge and a vermilion steel arch
## bridge, a suspension bridge (tsuribashi), a plank road bolted to a cliff (kakehashi) and a log-built timber slide (shura).
##
## Materials are MiyoshinoKit's: "hinoki" (hut_wood style 2, the grain along v) carries every squared timber and every round
## log's side (bark or peeled, by its tint), "sugi" plank decks and boarded walls, "wood" (plain vertex colour) the logs' cut
## faces with their rings, "urushi" the vermilion railings and steelwork, "ishi" stone, "concrete", "steel"/"metal" iron,
## "rope", "washi" paper lanterns, "kawara"/"hiwada" roofs, "pane" water in the flume, "leaf" straw.
##
## Part A (life size; y up, the ground or the waterline at y = 0):
##   log_raft(pk, kit, logs := 10, length := 7.5, rng := null)   one raft section, centred, logs along z, floating: the
##       waterline y 0, the logs' tops y 0.24-0.26, lashing poles and rope to 0.41; raft_width(logs) wide (0.36 a log)
##   raft_cargo(pk, kit, variant, rng)   standing on y 0.30 (RAFT_DECK), centred: 0 a thatched shelter and a brazier,
##       1 short logs and a coil of rope, 2 a sweep oar on its forked stand at the stern (-z), a hat and coat on a post
##   log_stack(pk, kit, base := 6, length := 6.0, rng := null)   a pyramid on two bearers between four stakes, logs along z
##   log_pile(pk, kit, n := 9, length := 4.0, rng := null)       a loose jumble, mostly along z
##   plank_stack(pk, kit, w := 1.2, h := 1.4, length := 4.0)     stickered boards along z under a weighted tin sheet
##   sawmill(pk, kit, labels, with_water := true)   front z = 0 facing +z, x 0..16, 9 deep (sawmill_size()); its wheel is
##       a mesh of its own, water_wheel(pk, kit, r := 2.4, w := 1.1) (centred on its axle, the axle along x), at
##       sawmill_wheel_at(); its flume's trough is sawmill_flume() (a stage can carry it on: flume() below)
##   mooring_post(pk, kit, h := 1.5), mooring_rope(pk, kit, a, b, sag := 0.35)   a post on a bank, a line to a raft
##   river_boat(pk, kit, variant := 0)   7 x 1.3m, bow toward +z, waterline y 0: 0 empty with its pole, 1 a fisherman's
##       (baskets, a hat on a post), 2 a roofed pleasure boat with paper lanterns
##   yana(pk, kit, w := 9.0)             a bamboo fish weir: the slatted platform rising toward +z, a watch hut on stilts
##   kinma_sled(pk, kit)                 a timber sledge of logs on a corduroy track, its nose toward +z
##
## Part B (game metres, kit scale 1). A bridge runs from z = 0 to z = -span (travel toward -z; t = -z is the distance
## along), x across, `hw` the driven deck's half width; `deck_y.call(t)` is the deck surface's height and
## `ground_y.call(x, t)` the ground or river bed (asked from t = -16 to span + 16). The generator lays the driven surface
## (its ribbon and collider): these build everything under and beside it. The corridor is kept clear: nothing inside
## |x| < hw from 2cm under the deck surface to 12m above it (check_corridor counts the triangles that are).
##   road_bridge(pk, kit, span, hw, deck_y, ground_y, style := 0)   0 a timber trestle, 1 a vermilion steel deck arch;
##       vermilion railings with giboshi at x = +-(hw + 0.25), stone abutments and wing walls
##   suspension_bridge(pk, kit, span, hw, deck_y, ground_y)         portal towers 14m over the deck, cables, hangers
##   ledge_walk(pk, kit, pts, rights, hw, side, ground_y)           along world points (the kit's frame the identity);
##       `ground_y.call(x, z)` the rock's height at a world point; `side` +1: the drop is on the right
##   timber_chute(pk, kit, pts, rights, hw, ground_y)               log walls either side, bents under the deck
##   flume(pk, kit, pts, ground_y, iw, wh, bay)   a raised trough on trestles along world points (the floor's top)
##   culvert_head(pk, kit, w, h, ow, oh, depth)   a stone headwall with a dark barrel, +z out of it
##   sluice(pk, kit, iw, wh)                      a mill pond's gate over a flume's mouth, +z downstream
##   check_corridor(kit or mesh, span, hw, deck_y) and check_path_corridor(kit or mesh, pts, rights, hw) -> int
##
## Faces never share a plane (parts stand proud of or are cut to each other), posts and struts reach the ground or the
## rock they bear on. Godot's front faces wind clockwise: PropKit winds every triangle for the `out` it is given.

const BARK := Color(0.50, 0.33, 0.23)
const BARK_DARK := Color(0.36, 0.23, 0.16)
const PEELED := Color(0.72, 0.58, 0.40)
const SAPWOOD := Color(0.90, 0.79, 0.58)
const SAPWOOD_RING := Color(0.80, 0.66, 0.45)
const HEARTWOOD := Color(0.74, 0.50, 0.37)
const PITH := Color(0.45, 0.25, 0.17)
const SAWN := Color(0.86, 0.72, 0.50)
const AGED := Color(0.52, 0.41, 0.30)
const AGED_DARK := Color(0.38, 0.29, 0.21)
const IRON := Color(0.10, 0.10, 0.11)
const RUST := Color(0.36, 0.21, 0.14)
const CABLE := Color(0.17, 0.18, 0.19)
const ROPE := Color(0.66, 0.55, 0.36)
const VINE := Color(0.42, 0.33, 0.21)
const CONCRETE_COL := Color(0.72, 0.71, 0.68)
const WATER_COL := Color(0.42, 0.60, 0.62)
const THATCH_TINT := Color(1.0, 0.96, 0.90)

const RAFT_PITCH := 0.36
## The top of the collision box the generators give a raft: cargo stands on it.
const RAFT_DECK := 0.30


# ======================================================================================
#  Helpers
# ======================================================================================

static func _rng(rng: RandomNumberGenerator, seed_v: int) -> RandomNumberGenerator:
	if rng != null:
		return rng
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


## A UV offset from a place, so no two timbers show the same grain.
static func _uo(p: Vector3) -> Vector2:
	return Vector2(fposmod(p.x * 1.37 + p.z * 2.11 + p.y * 0.53, 31.0), fposmod(p.y * 0.73 + p.x * 0.41 + p.z * 0.29, 17.0))


## A four-sided member from a to b, `w` across `side` and `t` across the other way, UVs in metres with v along it (hut_wood's
## grain runs along the timber on every face); `caps` closes its ends (8 triangles without, 12 with).
static func _bar(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, t: float, col: Color, side := Vector3.ZERO, caps := true) -> void:
	var ax := b - a
	var l := ax.length()
	if l < 1e-4:
		return
	var zz := ax / l
	var xx := side
	if xx.length_squared() < 1e-8 or absf(xx.normalized().dot(zz)) > 0.99:
		xx = Vector3.UP.cross(zz)
		if xx.length_squared() < 1e-6:
			xx = Vector3.RIGHT
	xx = (xx - zz * xx.dot(zz)).normalized()
	var yy := zz.cross(xx).normalized()
	var hx := xx * (w * 0.5)
	var hy := yy * (t * 0.5)
	var c: Array = [hx + hy, -hx + hy, -hx - hy, hx - hy]
	var wd: Array = [w, t, w, t]
	var o := _uo(a)
	var u0 := 0.0
	for k in 4:
		var p0: Vector3 = c[k]
		var p1: Vector3 = c[(k + 1) % 4]
		var n: Vector3 = (p0 + p1).normalized()
		var u1: float = u0 + float(wd[k])
		pk.quad(kit, key, [a + p0, a + p1, b + p1, b + p0], n, col,
				[(Vector2(u0, 0) + o) * uvk, (Vector2(u1, 0) + o) * uvk, (Vector2(u1, l) + o) * uvk, (Vector2(u0, l) + o) * uvk])
		u0 = u1 + 0.41
	if caps:
		var cc := col.darkened(0.1)
		var uv: Array = [o * uvk, (o + Vector2(w, 0)) * uvk, (o + Vector2(w, t)) * uvk, (o + Vector2(0, t)) * uvk]
		pk.quad(kit, key, [a + c[1], a + c[0], a + c[3], a + c[2]], -zz, cc, uv)
		pk.quad(kit, key, [b + c[1], b + c[0], b + c[3], b + c[2]], zz, cc, uv)


static func _ring_axes(d: Vector3, ref: Vector3) -> Array:
	var sx := d.cross(ref)
	if sx.length_squared() < 1e-6:
		sx = d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.BACK)
	sx = sx.normalized()
	return [sx, sx.cross(d).normalized()]


## A round member through the points `c` (radius `radii`: one number, or one per point): rings square to the path joined
## without gaps at the bends, smooth, UVs in metres (u round it, v along). `caps` (1 the start, 2 the end) closes its ends
## with plain discs; `col2` (alpha > 0) colours every other facet (bark's furrows).
static func _pipe(pk: PropKit, kit: Dictionary, key: String, c: Array, radii, sides: int, col: Color, caps := 3, ref := Vector3.UP, col2 := Color(0, 0, 0, 0)) -> void:
	var n := c.size()
	if n < 2:
		return
	var rings: Array = []
	var rr: Array = []
	for i in n:
		var d: Vector3 = ((c[mini(i + 1, n - 1)] as Vector3) - (c[maxi(i - 1, 0)] as Vector3)).normalized()
		var ax: Array = _ring_axes(d, ref)
		var ring: Array = []
		for k in sides:
			var a: float = TAU * float(k) / float(sides)
			ring.append((ax[0] as Vector3) * cos(a) + (ax[1] as Vector3) * sin(a))
		rings.append(ring)
		rr.append(float(radii[i]) if radii is Array else float(radii))
	var o := _uo(c[0])
	var v0 := 0.0
	for i in n - 1:
		var p: Vector3 = c[i]
		var q: Vector3 = c[i + 1]
		var r0: float = rr[i]
		var r1: float = rr[i + 1]
		var v1: float = v0 + (q - p).length()
		var step: float = TAU * (r0 + r1) * 0.5 / float(sides)
		for k in sides:
			var k1: int = (k + 1) % sides
			var n00: Vector3 = rings[i][k]
			var n01: Vector3 = rings[i][k1]
			var n10: Vector3 = rings[i + 1][k]
			var n11: Vector3 = rings[i + 1][k1]
			var out: Vector3 = (n00 + n01 + n10 + n11).normalized()
			var cc: Color = col2 if (col2.a > 0.0 and k % 2 == 1) else col
			var ua: float = step * float(k)
			var ub: float = step * float(k + 1)
			pk.tri(kit, key, p + n00 * r0, p + n01 * r0, q + n11 * r1, n00, n01, n11, cc, out,
					(Vector2(ua, v0) + o) * uvk, (Vector2(ub, v0) + o) * uvk, (Vector2(ub, v1) + o) * uvk)
			pk.tri(kit, key, p + n00 * r0, q + n11 * r1, q + n10 * r1, n00, n11, n10, cc, out,
					(Vector2(ua, v0) + o) * uvk, (Vector2(ub, v1) + o) * uvk, (Vector2(ua, v1) + o) * uvk)
		v0 = v1
	for e in 2:
		if (caps & (1 << e)) == 0:
			continue
		var i: int = 0 if e == 0 else n - 1
		var p: Vector3 = c[i]
		var d: Vector3 = ((c[mini(i + 1, n - 1)] as Vector3) - (c[maxi(i - 1, 0)] as Vector3)).normalized() * (-1.0 if e == 0 else 1.0)
		var r: float = rr[i]
		for k in sides:
			var k1: int = (k + 1) % sides
			pk.tri(kit, key, p, p + (rings[i][k] as Vector3) * r, p + (rings[i][k1] as Vector3) * r, d, d, d, col.darkened(0.15), d)


## The cut face of a log at `c` (the log's axis `axis`, the face looking along axis * sgn): one fan in log_wood.gdshader
## (key "log"), which draws the growth rings, sapwood and heartwood, checks, saw marks and (on a barked log, `detail` 1 or
## more) the bark's rim from the face's own coordinates. `outline` (optional) is the log's section there as radii for
## `sides` angles, so the end matches an uneven log; `seed` (0..1) its draw, `shade` how much darker.
static func _cut(pk: PropKit, kit: Dictionary, c: Vector3, axis: Vector3, sgn: float, r: float, sides: int, detail := 1, ref := Vector3.UP,
		seed_v := -1.0, shade := 0.0, outline: Array = []) -> void:
	var ax: Array = _ring_axes(axis, ref)
	var n: Vector3 = axis * sgn
	if seed_v < 0.0:
		seed_v = _seed_of(c)
	var data := Color(clampf(r / 0.5, 0.0, 1.0), seed_v, shade, 1.0 if detail >= 1 else 0.7)
	for k in sides:
		var k1: int = (k + 1) % sides
		var a0: float = TAU * float(k) / float(sides)
		var a1: float = TAU * float(k + 1) / float(sides)
		var r0: float = float(outline[k]) if outline.size() == sides else r
		var r1: float = float(outline[k1]) if outline.size() == sides else r
		var d0: Vector3 = (ax[0] as Vector3) * cos(a0) + (ax[1] as Vector3) * sin(a0)
		var d1: Vector3 = (ax[0] as Vector3) * cos(a1) + (ax[1] as Vector3) * sin(a1)
		pk.tri(kit, "log", c, c + d0 * r0, c + d1 * r1, n, n, n, data, n,
				Vector2.ZERO, Vector2(cos(a0), sin(a0)) * r0 / r, Vector2(cos(a1), sin(a1)) * r1 / r)


## A seed (0..1) from a place, so each log draws its own rings, checks and knots.
static func _seed_of(p: Vector3) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453, 1.0)


## A length of round timber along the polyline `c` (radius `r`, or one per point) in log_wood.gdshader (key "log"):
## bark, or peeled wood when `peeled`. Its section may be uneven: `outline` radii (as fractions of the radius) for
## `sides` angles round it, the same all along. No end faces (see _cut).
static func _log_pipe(pk: PropKit, kit: Dictionary, c: Array, radii, sides: int, peeled: bool, seed_v: float, shade := 0.0,
		ref := Vector3.UP, outline: Array = []) -> void:
	var n := c.size()
	if n < 2:
		return
	var part: float = 0.35 if peeled else 0.0
	var v0 := 0.0
	var prev: Array = []
	for i in n:
		var d: Vector3 = ((c[mini(i + 1, n - 1)] as Vector3) - (c[maxi(i - 1, 0)] as Vector3)).normalized()
		var ax: Array = _ring_axes(d, ref)
		var rr: float = float(radii[i]) if radii is Array else float(radii)
		if i > 0:
			v0 += (c[i] as Vector3).distance_to(c[i - 1])
		var ring: Array = []
		for k in sides + 1:
			var a: float = TAU * float(k) / float(sides)
			var f: float = float(outline[k % sides]) if outline.size() == sides else 1.0
			var dir: Vector3 = (ax[0] as Vector3) * cos(a) + (ax[1] as Vector3) * sin(a)
			ring.append([(c[i] as Vector3) + dir * rr * f, dir, Vector2(float(k) / float(sides), v0), Color(clampf(rr / 0.5, 0.0, 1.0), seed_v, shade, part)])
		if i > 0:
			for k in sides:
				var p00: Array = prev[k]
				var p01: Array = prev[k + 1]
				var p10: Array = ring[k]
				var p11: Array = ring[k + 1]
				var out: Vector3 = ((p00[1] as Vector3) + (p11[1] as Vector3)).normalized()
				pk.tri_c(kit, "log", p00[0], p01[0], p11[0], p00[1], p01[1], p11[1], p00[3], p01[3], p11[3], out, p00[2], p01[2], p11[2])
				pk.tri_c(kit, "log", p00[0], p11[0], p10[0], p00[1], p11[1], p10[1], p00[3], p11[3], p10[3], out, p00[2], p11[2], p10[2])
		prev = ring


## A round log from a to b (radius ra to rb), in log_wood.gdshader: bark (`bark`) or peeled cedar round it, an uneven
## section (a little oval, lumpy), a slight bow along it, and cut faces at the ends named in `ends` (1: a, 2: b) with the
## same outline. `shade` darkens it (0..1). `sides` is doubled (at least 10): eight flat faces read as a pencil.
static func _log(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, ra: float, rb: float, sides := 8, bark := true, ends := 3, shade := 0.0, detail := 1, ref := Vector3.UP) -> void:
	var sd: int = maxi(10, sides * 2)
	var seed_v: float = _seed_of(a + b * 0.37)
	var outline: Array = []
	var ph: float = seed_v * TAU
	for k in sd:
		var t: float = TAU * float(k) / float(sd)
		outline.append(1.0 + 0.045 * cos(2.0 * t + ph) + 0.02 * sin(3.0 * t + ph * 2.3) + 0.012 * sin(5.0 * t + ph * 4.1))
	var length: float = a.distance_to(b)
	var d := (b - a).normalized()
	var bow_dir: Vector3 = (_ring_axes(d, ref)[0] as Vector3) * cos(ph * 1.7) + (_ring_axes(d, ref)[1] as Vector3) * sin(ph * 1.7)
	var bow: float = length * 0.006 * (0.4 + seed_v)
	var segs: int = clampi(int(ceil(length / 1.0)), 2, 8)
	var line: Array = []
	var radii: Array = []
	for i in segs + 1:
		var t: float = float(i) / float(segs)
		line.append(a.lerp(b, t) + bow_dir * bow * sin(PI * t))
		radii.append(lerpf(ra, rb, t) * (1.0 + 0.025 * sin(t * 9.0 + ph)))
	_log_pipe(pk, kit, line, radii, sd, not bark, seed_v, shade, ref, outline)
	var dt: int = detail if bark else 0
	var oa: Array = []
	var ob: Array = []
	for f in outline:
		oa.append(float(f) * float(radii[0]))
		ob.append(float(f) * float(radii[segs]))
	if ends & 1:
		_cut(pk, kit, line[0], ((line[1] as Vector3) - (line[0] as Vector3)).normalized(), -1.0, float(radii[0]), sd, maxi(dt, 1) if bark else 0, ref, seed_v, shade, oa)
	if ends & 2:
		_cut(pk, kit, line[segs], ((line[segs] as Vector3) - (line[segs - 1] as Vector3)).normalized(), 1.0, float(radii[segs]), sd, maxi(dt, 1) if bark else 0, ref, fposmod(seed_v * 7.3, 1.0), shade, ob)


## A few turns of rope round a member at `c` along `axis` (an open sleeve).
static func _lash(pk: PropKit, kit: Dictionary, c: Vector3, axis: Vector3, r: float, w: float, col: Color, sides := 5) -> void:
	_pipe(pk, kit, "rope", [c - axis * (w * 0.5), c + axis * (w * 0.5)], r, sides, col, 0)


## A box centred at `c` turned by `basis`, UVs in metres.
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## A plank surface: a quad p[0..3] facing n with "sugi"'s boards running along p0->p1 (u), UVs in metres.
static func _planks(pk: PropKit, kit: Dictionary, key: String, p: Array, n: Vector3, col: Color) -> void:
	var lu: float = ((p[1] as Vector3) - (p[0] as Vector3)).length()
	var lv: float = ((p[3] as Vector3) - (p[0] as Vector3)).length()
	var o := _uo(p[0])
	pk.quad(kit, key, p, n, col, [o * uvk, (o + Vector2(lu, 0)) * uvk, (o + Vector2(lu, lv)) * uvk, (o + Vector2(0, lv)) * uvk])


## A lumpy stone resting on `p` (its lowest point a little under it).
static func _stone(pk: PropKit, kit: Dictionary, p: Vector3, r: float, col: Color, squash := 0.6) -> void:
	pk.lathe(kit, "ishi", p - Vector3(0, r * 0.15, 0), [Vector2(0.0, 0.0), Vector2(r * 0.8, r * 0.1), Vector2(r, r * squash * 0.6), Vector2(r * 0.7, r * squash * 1.1),
			Vector2(0.0, r * squash * 1.3)], 5, col, false, Basis(Vector3.UP, p.x * 3.0 + p.z))


## An onion-shaped giboshi standing on `p` (a post's top), `r` its widest radius: 2.8 r tall.
static func _giboshi(pk: PropKit, kit: Dictionary, p: Vector3, r: float, col := BRONZE) -> void:
	pk.lathe(kit, "metal", p, [Vector2(r * 1.02, 0.0), Vector2(r * 1.02, r * 0.3), Vector2(r * 0.55, r * 0.5), Vector2(r * 0.98, r * 1.3), Vector2(r * 0.6, r * 2.1), Vector2(0.0, r * 2.8)],
			5, col, false, Basis(Vector3.UP, PI * 0.25))


## A straw hat (kasa) hung at `p`, its crown along `axis`.
static func _kasa(pk: PropKit, kit: Dictionary, p: Vector3, axis := Vector3.UP, r := 0.24) -> void:
	var side := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.BACK).normalized()
	var b := Basis(side, axis, side.cross(axis))
	pk.lathe(kit, "leaf", p, [Vector2(r, 0.0), Vector2(r * 0.5, r * 0.3), Vector2(0.0, r * 0.5)], 8, STRAW, false, b)


# ======================================================================================
#  Part A: rafts
# ======================================================================================

static func raft_width(logs: int) -> float:
	return float(logs) * RAFT_PITCH + 0.04


## One section of a raft train (ikada), centred, its logs along z, afloat: the waterline at y = 0, the logs' tops at 0.24 to
## 0.26, three cross poles lashed over them with vine (to 0.41) and iron dogs across the joints. Peeled cedar.
static func log_raft(pk: PropKit, kit: Dictionary, logs := 10, length := 7.5, rng: RandomNumberGenerator = null) -> void:
	rng = _rng(rng, 11)
	var w := raft_width(logs)
	var x0: float = -w * 0.5 + RAFT_PITCH * 0.5 + 0.02
	var xs: Array = []
	var tops: Array = []
	for i in logs:
		var r: float = rng.randf_range(0.158, 0.186)
		var top: float = 0.26 - rng.randf() * 0.02
		var za: float = -length * 0.5 + rng.randf() * 0.32
		var zb: float = length * 0.5 - rng.randf() * 0.32
		var x: float = x0 + float(i) * RAFT_PITCH + rng.randf_range(-0.008, 0.008)
		var rb: float = r * rng.randf_range(0.9, 0.97)
		# Butt ends alternate, as the raftsmen laid them.
		if i % 2 == 0:
			_log(pk, kit, Vector3(x, top - r, za), Vector3(x, top - rb, zb), r, rb, 8, false, 3, rng.randf() * 0.14)
		else:
			_log(pk, kit, Vector3(x, top - rb, za), Vector3(x, top - r, zb), rb, r, 8, false, 3, rng.randf() * 0.14)
		xs.append(x)
		tops.append(top)
	var pz: float = length * 0.5 - 0.8
	var pr := 0.055
	var py := 0.262 + pr
	var k := 0
	for z in [-pz, 0.0, pz]:
		_log(pk, kit, Vector3(-w * 0.5 - 0.14, py, z), Vector3(w * 0.5 + 0.14, py, z + rng.randf_range(-0.04, 0.04)), pr, pr * 0.9, 6, true, 3, 0.1, 0)
		for i in logs:
			if k == 1 and i % 2 == 1:
				continue
			_lash(pk, kit, Vector3(xs[i], py, z), Vector3.RIGHT, pr + 0.022, 0.085, VINE.darkened(0.15 * float(i % 3)))
		k += 1
	# Iron dogs (kasugai) across neighbouring logs near both ends.
	var dz: float = length * 0.5 - 0.42
	for i in range(1, logs - 1, 3):
		for sz in [-1.0, 1.0]:
			var y: float = maxf(float(tops[i]), float(tops[i + 1])) + 0.012
			pk.beam(kit, "steel", Vector3(float(xs[i]) - 0.04, y, sz * dz), Vector3(float(xs[i + 1]) + 0.04, y, sz * dz), 0.035, 0.024, IRON, Vector3.BACK)


## What rides on a drifting raft, centred, standing on y = RAFT_DECK (0.30): 0 a small thatched shelter and a brazier,
## 1 a deck load of short logs and a coil of rope, 2 a long sweep oar on its forked stand at the stern (-z) with a
## raftsman's straw hat and coat on a post.
static func raft_cargo(pk: PropKit, kit: Dictionary, variant: int, rng: RandomNumberGenerator = null) -> void:
	rng = _rng(rng, 23)
	var y0 := RAFT_DECK
	match variant:
		0:
			# A floor of boards, an A-frame shelter of poles under thatch.
			var hx := 1.05
			var z0 := -0.7
			var z1 := 1.7
			pk.block(kit, "sugi", Vector3(-hx, y0 - 0.02, z0), Vector3(hx, y0 + 0.045, z1), CEDAR.lightened(0.12), uvk)
			var ridge := y0 + 1.75
			var eave := y0 + 0.5
			var ex := hx + 0.28
			for z in [z0 + 0.08, z1 - 0.08]:
				for sx in [-1.0, 1.0]:
					_bar(pk, kit, "hinoki", Vector3(sx * hx * 0.94, y0 + 0.03, z), Vector3(sx * hx * 0.94, y0 + 0.62, z), 0.08, 0.08, AGED, Vector3.RIGHT, false)
					_bar(pk, kit, "hinoki", Vector3(sx * (ex - 0.06), eave - 0.03, z), Vector3(-sx * 0.05, ridge + 0.03, z), 0.07 - 0.006 * sx, 0.07, AGED, Vector3.BACK)
				_bar(pk, kit, "hinoki", Vector3(0, y0 + 0.03, z), Vector3(0, ridge - 0.1, z), 0.08, 0.08, AGED, Vector3.RIGHT, false)
			_log(pk, kit, Vector3(0, ridge - 0.06, z0 - 0.25), Vector3(0, ridge - 0.06, z1 + 0.25), 0.05, 0.045, 6, true, 3, 0.0, 0)
			for sx in [-1.0, 1.0]:
				var out := Vector3(sx * (ridge - eave), ex, 0).normalized()
				var lift: Vector3 = out * 0.045
				roof(pk, kit, "hiwada", Vector3(sx * ex, eave, z0 - 0.2) + lift, Vector3(sx * ex, eave, z1 + 0.2) + lift, Vector3(0, ridge, z1 + 0.2) + lift,
						Vector3(0, ridge, z0 - 0.2) + lift, THATCH_TINT, out)
			# The ridge roll.
			_pipe(pk, kit, "hiwada", [Vector3(0, ridge + 0.07, z0 - 0.24), Vector3(0, ridge + 0.07, z1 + 0.24)], 0.085, 6, THATCH_TINT.darkened(0.2), 3)
			# The brazier before it: a wooden hibachi box of ash with glowing charcoal and an iron kettle on its trivet.
			var bz := -1.75
			pk.block(kit, "hinoki", Vector3(-0.3, y0, bz - 0.3), Vector3(0.3, y0 + 0.3, bz + 0.3), AGED_DARK, uvk)
			pk.block(kit, "ishi", Vector3(-0.25, y0 + 0.2, bz - 0.25), Vector3(0.25, y0 + 0.315, bz + 0.25), Color(0.62, 0.60, 0.56), uvk)
			pk.lathe(kit, "neon", Vector3(0, y0 + 0.315, bz), [Vector2(0.12, 0.0), Vector2(0.07, 0.03), Vector2(0.0, 0.035)], 6, Color(1.0, 0.42, 0.12), true)
			for a in 3:
				var d := Vector3(cos(TAU * a / 3.0), 0, sin(TAU * a / 3.0))
				pk.beam(kit, "steel", Vector3(0, y0 + 0.31, bz) + d * 0.15, Vector3(0, y0 + 0.47, bz) + d * 0.1, 0.015, 0.015, IRON)
			pk.lathe(kit, "metal", Vector3(0, y0 + 0.46, bz), [Vector2(0.0, 0.0), Vector2(0.11, 0.01), Vector2(0.135, 0.08), Vector2(0.10, 0.15), Vector2(0.04, 0.17), Vector2(0.0, 0.2)], 8, IRON.lightened(0.08))
			pk.beam(kit, "metal", Vector3(0.1, y0 + 0.56, bz), Vector3(0.2, y0 + 0.6, bz), 0.025, 0.025, IRON.lightened(0.08))
		1:
			# Short logs on two bearers, lashed down, and a coil of rope.
			var lx := -0.45
			var r := 0.17
			for z in [-0.75, 0.75]:
				_bar(pk, kit, "hinoki", Vector3(lx - 0.75, y0 + 0.05, z), Vector3(lx + 0.75, y0 + 0.05, z), 0.12, 0.1, AGED_DARK, Vector3.BACK)
			var rows: Array = [4, 3]
			for j in rows.size():
				var cnt: int = rows[j]
				for i in cnt:
					var x: float = lx + (float(i) - float(cnt - 1) * 0.5) * r * 2.0
					var y: float = y0 + 0.1 + r + float(j) * r * 1.73
					var rr: float = r * rng.randf_range(0.9, 0.99)
					var zz: float = rng.randf_range(-0.12, 0.12)
					_log(pk, kit, Vector3(x, y - (r - rr), zz - 1.15), Vector3(x, y - (r - rr), zz + 1.15), rr, rr * 0.95, 8, true, 3, rng.randf() * 0.15, 1)
			for z in [-0.5, 0.5]:
				var top: float = y0 + 0.1 + r * 2.0 + r * 1.73
				_pipe(pk, kit, "rope", [Vector3(lx - 0.74, y0 + 0.11, z), Vector3(lx - 0.6, y0 + 0.1 + r * 1.2, z), Vector3(lx - 0.36, top + 0.012, z), Vector3(lx + 0.36, top + 0.012, z),
						Vector3(lx + 0.6, y0 + 0.1 + r * 1.2, z), Vector3(lx + 0.74, y0 + 0.11, z)], 0.016, 4, ROPE, 0)
			var cc := Vector3(0.95, y0, 0.55)
			for j in 3:
				var cr: float = 0.34 - 0.02 * float(j)
				pk.lathe(kit, "rope", cc + Vector3(0, 0.035 + 0.066 * float(j), 0), [Vector2(cr - 0.07, 0.0), Vector2(cr - 0.035, -0.035), Vector2(cr, 0.0), Vector2(cr - 0.035, 0.035), Vector2(cr - 0.07, 0.0)],
						10, ROPE.darkened(0.08 * float(j % 2)))
			# A peavey (tobi hook) laid beside it.
			_pipe(pk, kit, "hinoki", [Vector3(0.75, y0 + 0.03, -1.6), Vector3(1.0, y0 + 0.03, -0.15)], 0.022, 5, AGED, 3)
			pk.beam(kit, "steel", Vector3(0.745, y0 + 0.03, -1.63), Vector3(0.70, y0 + 0.03, -1.8), 0.02, 0.02, IRON)
		_:
			# The sweep: a forked post at the stern, the oar through it trailing in the water, hat and coat on a post.
			var sz := -3.15
			_bar(pk, kit, "hinoki", Vector3(0, y0 - 0.06, sz), Vector3(0, y0 + 0.95, sz), 0.13, 0.13, AGED, Vector3.RIGHT, false)
			for sx in [-1.0, 1.0]:
				_bar(pk, kit, "hinoki", Vector3(sx * 0.03, y0 + 0.9, sz), Vector3(sx * 0.14, y0 + 1.22, sz), 0.07, 0.11 - 0.008 * sx, AGED, Vector3.RIGHT)
				# Braces down to the logs.
				_bar(pk, kit, "hinoki", Vector3(sx * 0.05, y0 + 0.55, sz), Vector3(sx * 0.55, y0 - 0.02, sz), 0.06, 0.08, AGED_DARK, Vector3.BACK, false)
			_bar(pk, kit, "hinoki", Vector3(0, y0 + 0.5, sz + 0.04), Vector3(0, y0 - 0.02, sz + 0.6), 0.06, 0.08, AGED_DARK, Vector3.RIGHT, false)
			var oa := Vector3(0, y0 + 1.72, -0.55)
			var ob := Vector3(0, -0.28, -6.3)
			var fork := oa.lerp(ob, (sz - oa.z) / (ob.z - oa.z))
			# The loom rests in the fork (its underside on the post's head).
			var drop: float = fork.y - (y0 + 1.0)
			oa.y -= drop
			ob.y -= drop
			_pipe(pk, kit, "hinoki", [oa, oa.lerp(ob, 0.72)], [0.04, 0.05], 6, AGED.lightened(0.1), 3)
			var d := (ob - oa).normalized()
			_bar(pk, kit, "hinoki", oa.lerp(ob, 0.7), ob, 0.26, 0.035, AGED.lightened(0.05), Vector3.RIGHT)
			_lash(pk, kit, oa.lerp(ob, (sz - oa.z) / (ob.z - oa.z)), d, 0.062, 0.2, ROPE)
			pk.beam(kit, "hinoki", oa + Vector3(-0.2, 0.0, 0.0), oa + Vector3(0.2, 0.0, 0.0), 0.05, 0.05, AGED, Vector3.UP, uvk)
			# The post with the hat and the straw coat (mino).
			var pp := Vector3(0.75, y0, -1.5)
			_pipe(pk, kit, "hinoki", [pp - Vector3(0, 0.06, 0), pp + Vector3(0, 1.55, 0)], [0.05, 0.04], 6, AGED, 2)
			pk.beam(kit, "hinoki", pp + Vector3(-0.3, 1.3, 0), pp + Vector3(0.3, 1.3, 0), 0.04, 0.04, AGED, Vector3.UP, uvk)
			_kasa(pk, kit, pp + Vector3(0, 1.5, 0), Vector3.UP, 0.27)
			pk.lathe(kit, "leaf", pp + Vector3(0, 0.55, 0), [Vector2(0.36, 0.0), Vector2(0.32, 0.3), Vector2(0.2, 0.62), Vector2(0.07, 0.78)], 7, STRAW.darkened(0.12), true)
			pk.lathe(kit, "leaf", pp + Vector3(0, 0.93, 0), [Vector2(0.3, 0.0), Vector2(0.2, 0.25), Vector2(0.06, 0.42)], 7, STRAW.darkened(0.02), true)


# ======================================================================================
#  Part A: forestry
# ======================================================================================

## A pyramid of cedar logs on two bearers between four stakes, the logs along z, centred: `base` logs in the bottom row,
## up to four rows. About base * 0.5m wide, 2m high.
static func log_stack(pk: PropKit, kit: Dictionary, base := 6, length := 6.0, rng: RandomNumberGenerator = null) -> void:
	rng = _rng(rng, 31)
	var r := 0.25
	var bz: float = length * 0.3
	var hw: float = float(base) * r
	var by := 0.2
	for sz in [-1.0, 1.0]:
		_log(pk, kit, Vector3(-hw - 0.45, by * 0.5, sz * bz), Vector3(hw + 0.45, by * 0.5, sz * bz), by * 0.5, by * 0.47, 6, true, 3, 0.2, 0)
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * (hw + 0.09), 0, sz * bz + 0.17)
			_log(pk, kit, p + Vector3(0, -0.8, 0), p + Vector3(sx * 0.03, 1.45, 0), 0.075, 0.06, 6, true, 2, 0.1, 0)
	var rows: int = mini(base, 4)
	for j in rows:
		var cnt: int = base - j
		for i in cnt:
			var x: float = (float(i) - float(cnt - 1) * 0.5) * r * 2.0
			var y: float = by + r + float(j) * r * 1.732
			var ra: float = r * rng.randf_range(0.9, 1.0)
			var rb: float = ra * rng.randf_range(0.88, 0.97)
			var zz: float = rng.randf_range(-0.22, 0.22)
			var hl: float = length * 0.5 + rng.randf_range(-0.15, 0.1)
			var a := Vector3(x, y - (r - ra), zz - hl)
			var b := Vector3(x, y - (r - rb), zz + hl)
			if (i + j) % 2 == 0:
				_log(pk, kit, a, b, ra, rb, 8, true, 3, rng.randf() * 0.18, 2)
			else:
				_log(pk, kit, Vector3(a.x, b.y, a.z), Vector3(b.x, a.y, b.z), rb, ra, 8, true, 3, rng.randf() * 0.18, 2)


## A loose jumble of logs at a landing: most lie on the ground more or less along z, the rest across them.
static func log_pile(pk: PropKit, kit: Dictionary, n := 9, length := 4.0, rng: RandomNumberGenerator = null) -> void:
	rng = _rng(rng, 37)
	var n0: int = maxi(2, int(ceil(float(n) * 0.6)))
	var r0 := 0.2
	var x := -float(n0 - 1) * 0.5 * 0.5
	var top := 0.0
	for i in n0:
		var r: float = r0 * rng.randf_range(0.85, 1.15)
		var yaw: float = rng.randf_range(-0.16, 0.16)
		var d := Vector3(sin(yaw), 0, cos(yaw))
		var c := Vector3(x, r, rng.randf_range(-0.4, 0.4))
		var hl: float = length * 0.5 * rng.randf_range(0.85, 1.0)
		_log(pk, kit, c - d * hl, c + d * hl + Vector3(0, -r * 0.06, 0), r, r * 0.94, 8, true, 3, rng.randf() * 0.18, 1)
		top = maxf(top, r * 2.0)
		x += 0.5 + rng.randf_range(-0.04, 0.06)
	var span: float = float(n0 - 1) * 0.5
	for i in n - n0:
		var r: float = r0 * rng.randf_range(0.8, 1.05)
		var yaw: float = (rng.randf_range(0.7, 1.25)) * (1.0 if i % 2 == 0 else -1.0)
		var d := Vector3(sin(yaw), 0, cos(yaw))
		var c := Vector3(rng.randf_range(-0.3, 0.3) * span, top + r - 0.03, lerpf(-0.3, 0.3, float(i) / maxf(1.0, float(n - n0 - 1))) * length)
		var hl: float = minf(length * 0.5, span * 0.5 / maxf(absf(d.x), 0.3) + 0.5)
		_log(pk, kit, c - d * hl, c + d * hl, r, r * 0.93, 8, true, 3, rng.randf() * 0.18, 1)


## Sawn boards stickered to dry, the boards along z, centred: a stack `w` wide and `h` high on two bearers, a sheet of
## corrugated tin over it weighted with stones.
static func plank_stack(pk: PropKit, kit: Dictionary, w := 1.2, h := 1.4, length := 4.0) -> void:
	var bz: float = length * 0.32
	for sz in [-1.0, 1.0]:
		_bar(pk, kit, "hinoki", Vector3(-w * 0.5 - 0.12, 0.06, sz * bz), Vector3(w * 0.5 + 0.12, 0.06, sz * bz), 0.14, 0.12, AGED_DARK, Vector3.BACK)
	var bt := 0.05
	var stk := 0.03
	var y := 0.12
	var k := 0
	while y + bt <= h:
		var jz: float = 0.07 * sin(float(k) * 2.4)
		var jx: float = 0.025 * sin(float(k) * 1.3 + 1.0)
		var col: Color = SAWN.darkened(0.06 * float(k % 3))
		# A layer: its top and bottom boarded along z, the four edges.
		var lo := Vector3(-w * 0.5 + jx, y, -length * 0.5 + jz)
		var hi := Vector3(w * 0.5 + jx, y + bt, length * 0.5 + jz)
		_planks(pk, kit, "sugi", [Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z)], Vector3.UP, col)
		_planks(pk, kit, "sugi", [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)], Vector3.DOWN, col.darkened(0.3))
		for sx in [-1.0, 1.0]:
			var xx: float = lo.x if sx < 0.0 else hi.x
			pk.quad(kit, "wood", [Vector3(xx, lo.y, lo.z), Vector3(xx, lo.y, hi.z), Vector3(xx, hi.y, hi.z), Vector3(xx, hi.y, lo.z)], Vector3(sx, 0, 0), col.darkened(0.08))
		for sz in [-1.0, 1.0]:
			var zz: float = lo.z if sz < 0.0 else hi.z
			pk.quad(kit, "wood", [Vector3(lo.x, lo.y, zz), Vector3(hi.x, lo.y, zz), Vector3(hi.x, hi.y, zz), Vector3(lo.x, hi.y, zz)], Vector3(0, 0, sz), SAPWOOD.darkened(0.05 * float(k % 2)))
		y += bt
		if y + stk + bt <= h:
			for sz in [-1.0, 0.0, 1.0]:
				_bar(pk, kit, "hinoki", Vector3(-w * 0.5 - 0.04, y + stk * 0.5, sz * bz), Vector3(w * 0.5 + 0.04, y + stk * 0.5, sz * bz), 0.045, stk, AGED, Vector3.BACK)
		y += stk
		k += 1
	y -= stk
	# The tin, a little askew, on two battens; stones on it.
	for sz in [-1.0, 1.0]:
		_bar(pk, kit, "hinoki", Vector3(-w * 0.5 - 0.1, y + 0.02, sz * bz * 0.9), Vector3(w * 0.5 + 0.1, y + 0.02, sz * bz * 0.9), 0.05, 0.04, AGED_DARK, Vector3.BACK)
	var tb := Basis(Vector3.UP, 0.035) * Basis(Vector3.BACK, 0.03)
	var tc := Vector3(0.02, y + 0.062, 0.05)
	pk.box(kit, "iron", Transform3D(tb, tc), Vector3(w + 0.36, 0.016, length + 0.3), Color(0.60, 0.62, 0.64), uvk)
	for s in [[-0.25, -0.9, 0.16], [0.2, 0.3, 0.19], [-0.1, 1.3, 0.14]]:
		var sp: Vector3 = tc + tb * Vector3(float(s[0]) * w, 0.008, float(s[1]) * length / 4.0)
		_stone(pk, kit, sp, float(s[2]), GRANITE.darkened(0.1))


# ======================================================================================
#  Part A: the sawmill and its wheel
# ======================================================================================

const MILL_WHEEL_R := 2.4
const MILL_WHEEL_W := 1.1
const MILL_AXLE := Vector3(1.3, 2.75, -5.15)
## The wheel's buckets: how many, and how far (radians) each one's elbow bends back from its start to the rim.
const WHEEL_BUCKETS := 16
const WHEEL_BUCKET_BACK := 0.24


## The wheel's axle (its middle) in the sawmill's frame: put water_wheel()'s mesh here and turn it about x.
static func sawmill_wheel_at() -> Vector3:
	return MILL_AXLE


## The sawmill's box: x 0..16, y to the ridge, 9 deep (z 0..-9).
static func sawmill_size() -> Vector3:
	return Vector3(16.0, 5.8, 9.0)


static func _push(pk: PropKit, t: Transform3D) -> Transform3D:
	var saved := pk.xf
	pk.set_frame(pk.xf * t)
	return saved


## An overshot water wheel centred on its axle, the axle along x: two shrouds of rim boards, sixteen buckets on a sole,
## eight spokes a side on a wooden hub, an iron axle reaching 0.65 past each side (to its bearings). Turn it about x.
static func water_wheel(pk: PropKit, kit: Dictionary, r := 2.4, w := 1.1) -> void:
	var wet := AGED_DARK
	var hx: float = w * 0.5
	var ab := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
	_pipe(pk, kit, "metal", [Vector3(-hx - 0.65, 0, 0), Vector3(hx + 0.65, 0, 0)], 0.075, 8, IRON.lightened(0.1), 3)
	_pipe(pk, kit, "hinoki", [Vector3(-hx + 0.04, 0, 0), Vector3(hx - 0.04, 0, 0)], 0.27, 8, wet, 3)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hx - 0.03)
		_shroud(pk, kit, x, r, 0.44, 0.06, wet.lightened(0.06))
		for k in 8:
			var a: float = TAU * float(k) / 8.0 + (0.0 if sx < 0.0 else 0.0)
			var d := Vector3(0, cos(a), sin(a))
			_bar(pk, kit, "hinoki", Vector3(sx * (hx - 0.1), 0, 0) + d * 0.22, Vector3(sx * (hx - 0.1), 0, 0) + d * (r - 0.3), 0.07, 0.11, wet.lightened(0.1), Vector3.RIGHT, false)
		# An iron band round the hub's end.
		_pipe(pk, kit, "metal", [Vector3(sx * (hx - 0.18), 0, 0), Vector3(sx * (hx - 0.05), 0, 0)], 0.285, 8, IRON, 0)
	# The sole (the buckets' floor), seen from outside and from inside.
	pk.lathe(kit, "wood", Vector3.ZERO, [Vector2(r - 0.40, -hx + 0.06), Vector2(r - 0.40, hx - 0.06)], 16, wet, false, ab)
	pk.lathe(kit, "wood", Vector3.ZERO, [Vector2(r - 0.43, hx - 0.06), Vector2(r - 0.43, -hx + 0.06)], 16, wet.darkened(0.25), false, ab)
	# The buckets: each a board standing out from the sole (the start) and one bent back against the turn to the rim (the
	# elbow), so on the loaded side (the top runs toward +z) each one is a cup that holds its water until near the bottom.
	# (They had leaned the other way, with the turn, and would have spilled as they filled.)
	for k in WHEEL_BUCKETS:
		var a0: float = TAU * float(k) / float(WHEEL_BUCKETS)
		var a1: float = a0 - WHEEL_BUCKET_BACK
		var p0 := Vector3(0, cos(a0), sin(a0)) * (r - 0.41)
		var pe := Vector3(0, cos(a0), sin(a0)) * (r - 0.21)
		var p1 := Vector3(0, cos(a1), sin(a1)) * (r - 0.01)
		for seg in [[p0, pe], [pe, p1]]:
			var sa: Vector3 = seg[0]
			var sb: Vector3 = seg[1]
			var n := (sb - sa).cross(Vector3.RIGHT).normalized()
			pk.panel(kit, "wood", [sa + Vector3(-hx + 0.06, 0, 0), sa + Vector3(hx - 0.06, 0, 0), sb + Vector3(hx - 0.06, 0, 0), sb + Vector3(-hx + 0.06, 0, 0)], n, wet.lightened(0.04), wet.darkened(0.1))


## One shroud of the wheel at x (its middle), `t` thick: sixteen curved felloe boards from r - `depth` to r, each a little
## apart from the next (a dark joint), drawn in the cypress's grain (UVs in metres along the board), two iron bolts over
## each joint. It had been one flat-coloured sixteen-sided ring.
static func _shroud(pk: PropKit, kit: Dictionary, x: float, r: float, depth: float, t: float, col: Color) -> void:
	var n := WHEEL_BUCKETS
	var sub := 4
	var gap := 0.004
	var ri: float = r - depth
	for k in n:
		var a0: float = TAU * float(k) / float(n) + gap
		var a1: float = TAU * float(k + 1) / float(n) - gap
		var tone: Color = col.darkened(0.06 * float(k % 3)).lightened(0.04 * float((k * 7) % 2))
		for j in sub:
			var b0: float = lerpf(a0, a1, float(j) / float(sub))
			var b1: float = lerpf(a0, a1, float(j + 1) / float(sub))
			var d0 := Vector3(0, cos(b0), sin(b0))
			var d1 := Vector3(0, cos(b1), sin(b1))
			var u0: float = (b0 - a0) * r
			var u1: float = (b1 - a0) * r
			for sx in [-1.0, 1.0]:
				var fx: float = x + sx * t * 0.5
				var nn := Vector3(sx, 0, 0)
				pk.tri(kit, "hinoki", Vector3(fx, 0, 0) + d0 * ri, Vector3(fx, 0, 0) + d0 * r, Vector3(fx, 0, 0) + d1 * r, nn, nn, nn, tone, nn,
						Vector2(u0, 0.0) * uvk, Vector2(u0, depth) * uvk, Vector2(u1, depth) * uvk)
				pk.tri(kit, "hinoki", Vector3(fx, 0, 0) + d0 * ri, Vector3(fx, 0, 0) + d1 * r, Vector3(fx, 0, 0) + d1 * ri, nn, nn, nn, tone, nn,
						Vector2(u0, 0.0) * uvk, Vector2(u1, depth) * uvk, Vector2(u1, 0.0) * uvk)
			# The rim's outer edge and the inner edge.
			for e in [[r, 1.0], [ri, -1.0]]:
				var rr: float = e[0]
				var o0: Vector3 = d0 * float(e[1])
				var o1: Vector3 = d1 * float(e[1])
				pk.tri(kit, "hinoki", Vector3(x - t * 0.5, 0, 0) + d0 * rr, Vector3(x + t * 0.5, 0, 0) + d0 * rr, Vector3(x + t * 0.5, 0, 0) + d1 * rr, o0, o0, o1, tone.darkened(0.1), (o0 + o1).normalized(),
						Vector2(u0, 0.0) * uvk, Vector2(u0, t) * uvk, Vector2(u1, t) * uvk)
				pk.tri(kit, "hinoki", Vector3(x - t * 0.5, 0, 0) + d0 * rr, Vector3(x + t * 0.5, 0, 0) + d1 * rr, Vector3(x - t * 0.5, 0, 0) + d1 * rr, o0, o1, o1, tone.darkened(0.1), (o0 + o1).normalized(),
						Vector2(u0, 0.0) * uvk, Vector2(u1, t) * uvk, Vector2(u1, 0.0) * uvk)
		# The board's ends, facing along the ring (the joint).
		for e2 in [[a0, -1.0], [a1, 1.0]]:
			var dd := Vector3(0, cos(float(e2[0])), sin(float(e2[0])))
			var tn := Vector3(0, -sin(float(e2[0])), cos(float(e2[0]))) * float(e2[1])
			pk.quad(kit, "wood", [Vector3(x - t * 0.5, 0, 0) + dd * ri, Vector3(x + t * 0.5, 0, 0) + dd * ri, Vector3(x + t * 0.5, 0, 0) + dd * r, Vector3(x - t * 0.5, 0, 0) + dd * r], tn, col.darkened(0.35))
		# Two bolt heads over the joint at the board's start, on the outer face.
		var ja := TAU * float(k) / float(n)
		var jd := Vector3(0, cos(ja), sin(ja))
		var outx: float = x + signf(x) * (t * 0.5 + 0.008)
		for rb in [ri + depth * 0.28, ri + depth * 0.72]:
			_box(pk, kit, "metal", Vector3(outx, 0, 0) + jd * rb, Basis(Vector3.RIGHT, ja), Vector3(0.016, 0.045, 0.045), IRON)


## A water-powered sawmill: front z = 0 facing +z, x 0..16, 9 deep. An open-sided timber shed under a cedar-bark roof (x 2.3 to
## 12.5), in it a frame saw driven by a shaft and crank from the wheel's axle, a log half sawn on its carriage, a stack
## of planks, a sawdust heap; a boarded lean-to office with a sliding door at its +x end; at its -x end the wheel's
## stone pit and timber frame, and a flume on trestles coming in from behind (z = -9, its water 5.65m up) over the wheel.
## The wheel is water_wheel()'s mesh, placed at sawmill_wheel_at(). `with_water` false leaves the still water out of the flume
## (a stage that runs its own flowing water through it: Yoshino Rapids).
static func sawmill(pk: PropKit, kit: Dictionary, labels: Array, with_water := true) -> void:
	var ax := MILL_AXLE
	var r := MILL_WHEEL_R
	var tim := AGED
	# --- The wheel pit and its frame ---
	for x in [[0.12, 0.62], [1.98, 2.48]]:
		pk.block(kit, "ishi", Vector3(x[0], -1.2, ax.z - r - 0.3), Vector3(x[1], 0.45, ax.z + r + 0.3), GRANITE_MOSSY, uvk)
	var beam_y: float = ax.y + r + 0.07
	for x in [0.37, 2.23]:
		_bar(pk, kit, "hinoki", Vector3(x, 0.4, ax.z), Vector3(x, beam_y + 0.02, ax.z), 0.26, 0.26, tim, Vector3.RIGHT, false)
		pk.block(kit, "hinoki", Vector3(x - 0.17, ax.y - 0.16, ax.z - 0.2), Vector3(x + 0.17, ax.y + 0.14, ax.z + 0.2), AGED_DARK, uvk)
		pk.block(kit, "steel", Vector3(x - 0.185, ax.y - 0.05, ax.z - 0.12), Vector3(x + 0.185, ax.y + 0.17, ax.z + 0.12), IRON)
		for sz in [-1.0, 1.0]:
			_bar(pk, kit, "hinoki", Vector3(x, 0.42, ax.z + sz * 1.5), Vector3(x, 2.25, ax.z + sz * 0.1), 0.16, 0.14, tim.darkened(0.1), Vector3.RIGHT, false)
	_bar(pk, kit, "hinoki", Vector3(0.15, beam_y + 0.1, ax.z), Vector3(2.45, beam_y + 0.1, ax.z), 0.24, 0.2, tim, Vector3.BACK)
	# --- The flume: a boarded trough on two trestles and the wheel's frame ---
	var fy: float = beam_y + 0.2
	var fz0 := -9.0
	var fz1: float = ax.z + 0.45
	var fxa := 1.03
	var fxb := 1.57
	var board := CEDAR.lightened(0.12)
	_planks(pk, kit, "sugi", [Vector3(fxa - 0.05, fy, fz1), Vector3(fxa - 0.05, fy, fz0), Vector3(fxb + 0.05, fy, fz0), Vector3(fxb + 0.05, fy, fz1)], Vector3.DOWN, board.darkened(0.3))
	_planks(pk, kit, "sugi", [Vector3(fxa, fy + 0.045, fz1), Vector3(fxa, fy + 0.045, fz0), Vector3(fxb, fy + 0.045, fz0), Vector3(fxb, fy + 0.045, fz1)], Vector3.UP, board.darkened(0.35))
	for s in [[fxa - 0.05, fxa, -1.0], [fxb, fxb + 0.05, 1.0]]:
		var xo: float = s[0] if float(s[2]) < 0.0 else s[1]
		var xi: float = s[1] if float(s[2]) < 0.0 else s[0]
		_planks(pk, kit, "sugi", [Vector3(xo, fy, fz1), Vector3(xo, fy, fz0), Vector3(xo, fy + 0.36, fz0), Vector3(xo, fy + 0.36, fz1)], Vector3(float(s[2]), 0, 0), board)
		_planks(pk, kit, "sugi", [Vector3(xi, fy + 0.045, fz1), Vector3(xi, fy + 0.045, fz0), Vector3(xi, fy + 0.36, fz0), Vector3(xi, fy + 0.36, fz1)], Vector3(-float(s[2]), 0, 0), board.darkened(0.25))
		pk.quad(kit, "wood", [Vector3(xo, fy + 0.36, fz1), Vector3(xo, fy + 0.36, fz0), Vector3(xi, fy + 0.36, fz0), Vector3(xi, fy + 0.36, fz1)], Vector3.UP, board)
		for z in [fz0, fz1]:
			pk.quad(kit, "wood", [Vector3(xo, fy, z), Vector3(xi, fy, z), Vector3(xi, fy + 0.36, z), Vector3(xo, fy + 0.36, z)], Vector3(0, 0, 1.0 if z > fz0 + 0.1 else -1.0), board.darkened(0.1))
	pk.quad(kit, "wood", [Vector3(fxa, fy, fz1), Vector3(fxb, fy, fz1), Vector3(fxb, fy + 0.045, fz1), Vector3(fxa, fy + 0.045, fz1)], Vector3(0, 0, 1), board.darkened(0.1))
	# Cleats across the trough's top, and the water in it, falling off its lip.
	var fzc := fz0 + 0.5
	while fzc < fz1 - 0.3:
		_bar(pk, kit, "hinoki", Vector3(fxa - 0.09, fy + 0.385, fzc), Vector3(fxb + 0.09, fy + 0.385, fzc), 0.07, 0.05, tim, Vector3.BACK)
		fzc += 1.1
	if with_water:
		pk.quad(kit, "pane", [Vector3(fxa, fy + 0.24, fz1), Vector3(fxa, fy + 0.24, fz0), Vector3(fxb, fy + 0.24, fz0), Vector3(fxb, fy + 0.24, fz1)], Vector3.UP, WATER_COL)
		var lip0 := Vector3(0, fy + 0.24, fz1)
		var lip1 := Vector3(0, fy + 0.1, fz1 + 0.16)
		var lip2 := Vector3(0, fy - 0.2, fz1 + 0.26)
		for seg in [[lip0, lip1], [lip1, lip2]]:
			var sa: Vector3 = seg[0]
			var sb: Vector3 = seg[1]
			var nn := Vector3(0, sb.z - sa.z, sa.y - sb.y).normalized()
			pk.panel(kit, "pane", [sa + Vector3(fxa + 0.03, 0, 0), sa + Vector3(fxb - 0.03, 0, 0), sb + Vector3(fxb - 0.03, 0, 0), sb + Vector3(fxa + 0.03, 0, 0)], nn, WATER_COL.lightened(0.25), WATER_COL)
	for z in [-8.75, -7.9]:
		_bar(pk, kit, "hinoki", Vector3(0.55, fy - 0.09, z), Vector3(2.05, fy - 0.09, z), 0.16, 0.18, tim, Vector3.BACK)
		for sx in [-1.0, 1.0]:
			_bar(pk, kit, "hinoki", Vector3(1.3 + sx * 0.85, -0.6, z), Vector3(1.3 + sx * 0.55, fy - 0.17, z), 0.16, 0.16, tim, Vector3.BACK, false)
			_bar(pk, kit, "hinoki", Vector3(1.3 + sx * 0.78, 0.9, z + 0.13 + sx * 0.03), Vector3(1.3 - sx * 0.6, fy - 0.9, z + 0.13 + sx * 0.03), 0.05, 0.14, tim.darkened(0.12), Vector3.BACK)
		_bar(pk, kit, "hinoki", Vector3(0.35, 2.6, z - 0.1), Vector3(2.25, 2.6, z - 0.1), 0.05, 0.14, tim.darkened(0.12), Vector3.BACK)
	# --- The shed ---
	var px: Array = [2.8, 6.2, 9.9, 12.0]
	var zf := -0.9
	var zb := -8.1
	var zr := -4.5
	var ridge := 5.4
	var slope := 0.5
	var plate := 3.3
	for x in px:
		for z in [zf, zb]:
			pk.block(kit, "ishi", Vector3(x - 0.24, -1.0, z - 0.24), Vector3(x + 0.24, 0.14, z + 0.24), GRANITE, uvk)
			_bar(pk, kit, "hinoki", Vector3(x, 0.1, z), Vector3(x, plate + 0.02, z), 0.22, 0.22, tim, Vector3.RIGHT, false)
			# A knee brace along the plate.
			var bx: float = 0.9 if x < 11.0 else -0.9
			_bar(pk, kit, "hinoki", Vector3(x, plate - 1.0, z), Vector3(x + bx, plate + 0.02, z), 0.1, 0.12, tim.darkened(0.08), Vector3.BACK, false)
		_bar(pk, kit, "hinoki", Vector3(x, plate - 0.11, zf + 0.2), Vector3(x, plate - 0.11, zb - 0.2), 0.2, 0.22, tim, Vector3.RIGHT)
		_bar(pk, kit, "hinoki", Vector3(x, plate - 0.02, zr), Vector3(x, ridge - 0.3, zr), 0.18, 0.18, tim, Vector3.RIGHT, false)
	for z in [zf, zb]:
		_bar(pk, kit, "hinoki", Vector3(2.45, plate + 0.11, z), Vector3(12.35, plate + 0.11, z), 0.24, 0.22, tim, Vector3.BACK)
	_bar(pk, kit, "hinoki", Vector3(2.4, ridge - 0.225, zr), Vector3(12.4, ridge - 0.225, zr), 0.2, 0.19, tim, Vector3.BACK)
	var rx0 := 2.3
	var rx1 := 12.5
	for sz in [1.0, -1.0]:
		var ez: float = zr + sz * 4.5
		var ey: float = ridge - slope * 4.5
		var out := Vector3(0, 1.0, sz * slope).normalized()
		roof(pk, kit, "hiwada", Vector3(rx0, ey, ez), Vector3(rx1, ey, ez), Vector3(rx1, ridge, zr), Vector3(rx0, ridge, zr), THATCH_TINT, out)
		# Rafters under it, their feet at the eave.
		var xr := rx0 + 0.2
		while xr < rx1:
			_bar(pk, kit, "hinoki", Vector3(xr, ey - 0.095, ez - sz * 0.06) , Vector3(xr, ridge - 0.095 - slope * 0.12, zr + sz * 0.12), 0.07, 0.1, tim.lightened(0.08), Vector3.RIGHT)
			xr += 0.68
		# An eave board and the gables' barge boards.
		_bar(pk, kit, "hinoki", Vector3(rx0, ey - 0.07, ez + sz * 0.03), Vector3(rx1, ey - 0.07, ez + sz * 0.03), 0.04, 0.16, tim.darkened(0.15), Vector3.BACK)
		for x in [rx0 - 0.03, rx1 + 0.03]:
			_bar(pk, kit, "hinoki", Vector3(x, ey - 0.06, ez), Vector3(x, ridge - 0.06, zr), 0.05 + 0.012 * sz, 0.2, tim.darkened(0.15), Vector3.RIGHT)
	_pipe(pk, kit, "hiwada", [Vector3(rx0 - 0.04, ridge + 0.02, zr), Vector3(rx1 + 0.04, ridge + 0.02, zr)], 0.14, 6, THATCH_TINT.darkened(0.25), 3)
	# --- The drive: the shaft from the wheel, its bearings, the crank and the pitman ---
	var sx1 := 7.3
	_pipe(pk, kit, "metal", [Vector3(ax.x + MILL_WHEEL_W * 0.5 + 0.66, ax.y, ax.z), Vector3(sx1, ax.y, ax.z)], 0.07, 8, IRON.lightened(0.1), 0)
	for x in [4.3, 6.55]:
		_bar(pk, kit, "hinoki", Vector3(x, -0.5, ax.z), Vector3(x, ax.y - 0.12, ax.z), 0.22, 0.24, tim, Vector3.RIGHT, false)
		pk.block(kit, "hinoki", Vector3(x - 0.15, ax.y - 0.14, ax.z - 0.18), Vector3(x + 0.15, ax.y + 0.13, ax.z + 0.18), AGED_DARK, uvk)
		for sz in [-1.0, 1.0]:
			_bar(pk, kit, "hinoki", Vector3(x, 0.0, ax.z + sz * 1.0), Vector3(x, 1.9, ax.z + sz * 0.08), 0.1, 0.12, tim.darkened(0.1), Vector3.RIGHT, false)
	_pipe(pk, kit, "metal", [Vector3(sx1, ax.y, ax.z), Vector3(sx1 + 0.08, ax.y, ax.z)], 0.42, 12, IRON.lightened(0.05), 3)
	var pin := Vector3(sx1 + 0.15, ax.y - 0.3, ax.z + 0.1)
	_pipe(pk, kit, "metal", [Vector3(sx1 + 0.07, pin.y, pin.z), Vector3(sx1 + 0.21, pin.y, pin.z)], 0.035, 6, IRON, 2)
	var gz := -4.5
	var stile_pin := Vector3(pin.x, 1.2, gz - 0.2)
	_bar(pk, kit, "hinoki", pin, stile_pin, 0.05, 0.08, SAWN.darkened(0.2), Vector3.RIGHT)
	_pipe(pk, kit, "metal", [Vector3(pin.x, 1.2, gz - 0.27), Vector3(pin.x, 1.2, gz - 0.03)], 0.03, 6, IRON, 1)
	# --- The saw gate, the sash and its blade ---
	var gx0 := 7.1
	var gx1 := 9.3
	var cx := 8.2
	for x in [gx0, gx1]:
		_bar(pk, kit, "hinoki", Vector3(x, -0.5, gz), Vector3(x, 4.0, gz), 0.3, 0.3, tim, Vector3.RIGHT, false)
		pk.block(kit, "ishi", Vector3(x - 0.3, -1.0, gz - 0.3), Vector3(x + 0.3, 0.1, gz + 0.3), GRANITE, uvk)
	_bar(pk, kit, "hinoki", Vector3(gx0 - 0.35, 4.13, gz), Vector3(gx1 + 0.35, 4.13, gz), 0.34, 0.28, tim, Vector3.BACK)
	var sash := SAWN.darkened(0.12)
	for x in [gx0 + 0.3, gx1 - 0.3]:
		_bar(pk, kit, "hinoki", Vector3(x, 0.2, gz), Vector3(x, 3.5, gz), 0.1, 0.12, sash, Vector3.RIGHT)
	for y in [0.26, 3.44]:
		_bar(pk, kit, "hinoki", Vector3(gx0 + 0.35, y, gz), Vector3(gx1 - 0.35, y, gz), 0.09, 0.11, sash, Vector3.BACK, false)
	_box(pk, kit, "metal", Vector3(cx, 1.85, gz), Basis(), Vector3(0.012, 3.08, 0.15), Color(0.62, 0.63, 0.66))
	# --- The rails, the carriage and its log ---
	var rails: Array = [cx - 0.45, cx + 0.45]
	for x in rails:
		_bar(pk, kit, "hinoki", Vector3(x, 0.05, -8.4), Vector3(x, 0.05, -1.2), 0.1, 0.1, tim.darkened(0.15), Vector3.RIGHT)
		_bar(pk, kit, "hinoki", Vector3(x, 0.42, -6.7), Vector3(x, 0.42, -2.5), 0.14, 0.16, tim.lightened(0.05), Vector3.RIGHT)
		for z in [-6.2, -2.95]:
			_pipe(pk, kit, "metal", [Vector3(x - 0.035, 0.22, z), Vector3(x + 0.035, 0.22, z)], 0.12, 8, IRON.lightened(0.06), 3)
	for z in [-6.45, -5.3, -3.6, -2.75]:
		_bar(pk, kit, "hinoki", Vector3(cx - 0.6, 0.57, z), Vector3(cx + 0.6, 0.57, z), 0.16, 0.14, tim, Vector3.BACK)
	var lr := 0.36
	var ly: float = 0.64 + lr - 0.02
	_log(pk, kit, Vector3(cx, ly, -7.0), Vector3(cx, ly, -2.3), lr, lr * 0.96, 10, true, 3, 0.0, 2)
	# The kerf, as far as the blade has come.
	pk.block(kit, "wood", Vector3(cx - 0.011, ly - lr - 0.01, gz), Vector3(cx + 0.011, ly + lr + 0.008, -2.3 + 0.004), Color(0.2, 0.13, 0.09))
	# Iron dogs gripping the log on the bolsters.
	for z in [-6.45, -2.75]:
		for sx in [-1.0, 1.0]:
			pk.beam(kit, "steel", Vector3(cx + sx * 0.5, 0.64, z + 0.1), Vector3(cx + sx * 0.3, 0.86, z + 0.1), 0.03, 0.03, IRON)
	# --- Planks, sawdust, logs waiting ---
	var saved := _push(pk, Transform3D(Basis(), Vector3(10.95, 0, -4.6)))
	plank_stack(pk, kit, 1.0, 1.25, 3.6)
	pk.set_frame(saved)
	pk.lathe(kit, "wood", Vector3(6.0, 0, -2.6), [Vector2(0.95, -0.02), Vector2(0.6, 0.22), Vector2(0.25, 0.46), Vector2(0.0, 0.52)], 9, SAWN.lightened(0.05))
	pk.lathe(kit, "wood", Vector3(8.2, 0, -5.0), [Vector2(0.5, -0.02), Vector2(0.25, 0.14), Vector2(0.0, 0.2)], 7, SAWN.lightened(0.05))
	_log(pk, kit, Vector3(3.6, 0.3, -6.9), Vector3(3.75, 0.3, -2.4), 0.3, 0.28, 8, true, 3, 0.05, 2)
	_log(pk, kit, Vector3(4.25, 0.27, -7.3), Vector3(4.2, 0.27, -2.9), 0.27, 0.25, 8, true, 3, 0.12, 2)
	_log(pk, kit, Vector3(3.95, 0.3 + 0.47, -7.0), Vector3(3.98, 0.3 + 0.45, -2.7), 0.25, 0.24, 8, true, 3, 0.0, 2)
	# --- The office: a boarded lean-to under a roof of its own ---
	var ox0 := 12.2
	var ox1 := 15.6
	var oz0 := -1.5
	var oz1 := -6.5
	var oh0 := 3.05
	var oh1 := 2.5
	var wallc := CEDAR.lightened(0.08)
	pk.block(kit, "ishi", Vector3(ox0 - 0.05, -1.0, oz1 - 0.06), Vector3(ox1 + 0.06, 0.12, oz0 + 0.06), GRANITE, uvk)
	for z in [oz0, oz1]:
		var out := Vector3(0, 0, 1.0 if z == oz0 else -1.0)
		wall(pk, kit, "sugi", Vector3(ox0, 0, z), Vector3(ox1, 0, z), 0.12, oh1, wallc, out)
		pk.tri(kit, "sugi", Vector3(ox0, oh1, z), Vector3(ox1, oh1, z), Vector3(ox0, oh0, z), out, out, out, wallc, out, Vector2(0, oh1) * uvk, Vector2(ox1 - ox0, oh1) * uvk, Vector2(0, oh0) * uvk)
	wall(pk, kit, "sugi", Vector3(ox1, 0, oz0), Vector3(ox1, 0, oz1), 0.12, oh1, wallc, Vector3(1, 0, 0))
	wall(pk, kit, "sugi", Vector3(ox0, 0, oz0), Vector3(ox0, 0, oz1), 0.12, oh0, wallc.darkened(0.1), Vector3(-1, 0, 0))
	for c in [[ox0, oz0, oh0], [ox1, oz0, oh1], [ox0, oz1, oh0], [ox1, oz1, oh1]]:
		_bar(pk, kit, "hinoki", Vector3(c[0], 0.1, c[1]), Vector3(c[0], float(c[2]) + 0.02, c[1]), 0.16, 0.16, tim, Vector3.RIGHT, false)
	var osl: float = (oh0 - oh1) / (ox1 - ox0)
	var oe := ox1 + 0.4
	roof(pk, kit, "hiwada", Vector3(oe, oh1 - osl * 0.4 + 0.08, oz0 + 0.4), Vector3(oe, oh1 - osl * 0.4 + 0.08, oz1 - 0.4), Vector3(ox0 + 0.02, oh0 + 0.08, oz1 - 0.4),
			Vector3(ox0 + 0.02, oh0 + 0.08, oz0 + 0.4), THATCH_TINT, Vector3(osl, 1, 0).normalized())
	for z in [oz0 + 0.4, oz1 - 0.4]:
		_bar(pk, kit, "hinoki", Vector3(oe, oh1 - osl * 0.4 + 0.01, z), Vector3(ox0 + 0.02, oh0 + 0.01, z), 0.05, 0.16, tim.darkened(0.15), Vector3.BACK)
	# The sliding door on its rail, a paper window with its lattice, the name board.
	var fz: float = oz0
	pk.block(kit, "hinoki", Vector3(12.97, 0.135, fz + 0.03), Vector3(13.93, 2.0, fz + 0.075), CEDAR_DARK.lightened(0.1), uvk)
	for x in [12.95, 13.45, 13.95]:
		pk.block(kit, "hinoki", Vector3(x - 0.04, 0.12, fz + 0.04), Vector3(x + 0.04, 2.02, fz + 0.1), tim, uvk)
	for y in [0.16, 1.05, 1.98]:
		pk.block(kit, "hinoki", Vector3(12.95, y - 0.04, fz + 0.045), Vector3(13.95, y + 0.04, fz + 0.09), tim.darkened(0.06), uvk)
	pk.block(kit, "hinoki", Vector3(12.6, 2.04, fz + 0.02), Vector3(15.2, 2.12, fz + 0.13), tim.darkened(0.1), uvk)
	pk.block(kit, "steel", Vector3(13.82, 0.95, fz + 0.1), Vector3(13.88, 1.15, fz + 0.125), IRON)
	pk.block(kit, "washi", Vector3(14.35, 1.05, fz + 0.01), Vector3(15.25, 1.9, fz + 0.035), PAPER)
	for x in [14.3, 14.6, 14.8, 15.0, 15.3]:
		var fw: float = 0.04 if (x == 14.3 or x == 15.3) else 0.016
		pk.block(kit, "hinoki", Vector3(x - fw, 1.0, fz + 0.02), Vector3(x + fw, 1.95, fz + 0.06), tim, uvk)
	for y in [1.0, 1.32, 1.63, 1.95]:
		var fh: float = 0.04 if (y == 1.0 or y == 1.95) else 0.016
		pk.block(kit, "hinoki", Vector3(14.3, y - fh, fz + 0.025), Vector3(15.3, y + fh, fz + 0.065), tim, uvk)
	pk.block(kit, "hinoki", Vector3(13.0, 2.2, fz + 0.02), Vector3(15.0, 2.47, fz + 0.06), SAWN.darkened(0.15), uvk)
	labels.append(["YOSHINO SEIZAI", Vector3(14.0, 2.335, fz + 0.09), Vector3(0, 0, 1), 0.17, Color(0.08, 0.06, 0.05), 1.8])


# ======================================================================================
#  Part A: boats, the fish weir, the timber sledge
# ======================================================================================

## The hull's stations: [z, half width at the gunwale, half width of the bottom, the bottom's y, the gunwale's y].
const BOAT_ST := [[-3.5, 0.50, 0.33, -0.03, 0.47], [-2.4, 0.63, 0.43, -0.12, 0.42], [-0.5, 0.66, 0.46, -0.14, 0.40], [1.2, 0.62, 0.41, -0.13, 0.42],
		[2.4, 0.49, 0.28, -0.07, 0.50], [3.1, 0.31, 0.14, 0.12, 0.62], [3.5, 0.13, 0.06, 0.38, 0.74]]


## The inside floor's height and half width at z (for standing things in the boat).
static func _boat_floor(z: float) -> Vector2:
	for i in BOAT_ST.size() - 1:
		var a: Array = BOAT_ST[i]
		var b: Array = BOAT_ST[i + 1]
		if z <= float(b[0]) or i == BOAT_ST.size() - 2:
			var u: float = clampf((z - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return Vector2(lerpf(a[3], b[3], u) + 0.045, lerpf(a[2], b[2], u) - 0.03)
	return Vector2(0.0, 0.3)


## A flat-bottomed wooden river boat, about 7 x 1.3m, its bow toward +z, the waterline at y = 0 (it draws 0.14):
## 0 empty with its pole laid in it, 1 a fisherman's with baskets and a hat on a post, 2 a pleasure boat under a little
## roof (yakata) hung with paper lanterns.
static func river_boat(pk: PropKit, kit: Dictionary, variant := 0) -> void:
	var col := CEDAR.lightened(0.16)
	var inner := CEDAR.lightened(0.26)
	var th := 0.04
	var n := BOAT_ST.size()
	for i in n - 1:
		var a: Array = BOAT_ST[i]
		var b: Array = BOAT_ST[i + 1]
		var za: float = a[0]
		var zb: float = b[0]
		# The bottom, outside and in.
		_planks(pk, kit, "hinoki", [Vector3(-float(a[2]), a[3], za), Vector3(float(a[2]), a[3], za), Vector3(float(b[2]), b[3], zb), Vector3(-float(b[2]), b[3], zb)], Vector3.DOWN, col.darkened(0.3))
		_planks(pk, kit, "hinoki", [Vector3(-float(a[2]) + th, float(a[3]) + th, za), Vector3(float(a[2]) - th, float(a[3]) + th, za), Vector3(float(b[2]) - th, float(b[3]) + th, zb),
				Vector3(-float(b[2]) + th, float(b[3]) + th, zb)], Vector3.UP, inner.darkened(0.1))
		for sx in [-1.0, 1.0]:
			var a0 := Vector3(sx * float(a[2]), a[3], za)
			var a1 := Vector3(sx * float(a[1]), a[4], za)
			var b0 := Vector3(sx * float(b[2]), b[3], zb)
			var b1 := Vector3(sx * float(b[1]), b[4], zb)
			var out := (a1 - a0).cross(b0 - a0).normalized()
			if out.x * sx < 0.0:
				out = -out
			_planks(pk, kit, "hinoki", [a0, a1, b1, b0], out, col)
			var i0 := a0 + Vector3(-sx * th, th, 0)
			var i1 := a1 + Vector3(-sx * th, 0, 0)
			var j0 := b0 + Vector3(-sx * th, th, 0)
			var j1 := b1 + Vector3(-sx * th, 0, 0)
			_planks(pk, kit, "hinoki", [i0, i1, j1, j0], -out, inner)
			pk.quad(kit, "hinoki", [a1, i1, j1, b1], Vector3.UP, inner.lightened(0.05))
			# The rubbing strake under the gunwale.
			_bar(pk, kit, "hinoki", a1 + Vector3(sx * 0.02, -0.05, 0), b1 + Vector3(sx * 0.02, -0.05, 0), 0.045, 0.07, col.darkened(0.12), Vector3.RIGHT, i == 0 or i == n - 2)
	# The transom and the bow board, outside and in.
	for e in [0, n - 1]:
		var s: Array = BOAT_ST[e]
		var z: float = s[0]
		var sg: float = -1.0 if e == 0 else 1.0
		pk.quad(kit, "hinoki", [Vector3(-float(s[2]), s[3], z), Vector3(float(s[2]), s[3], z), Vector3(float(s[1]), s[4], z), Vector3(-float(s[1]), s[4], z)], Vector3(0, 0, sg), col.darkened(0.06))
		var zi: float = z - sg * th
		pk.quad(kit, "hinoki", [Vector3(-float(s[2]) + th, float(s[3]) + th, zi), Vector3(float(s[2]) - th, float(s[3]) + th, zi), Vector3(float(s[1]) - th, s[4], zi), Vector3(-float(s[1]) + th, s[4], zi)],
				Vector3(0, 0, -sg), inner)
		pk.quad(kit, "hinoki", [Vector3(-float(s[1]), s[4], z), Vector3(float(s[1]), s[4], z), Vector3(float(s[1]) - th, s[4], zi), Vector3(-float(s[1]) + th, s[4], zi)], Vector3.UP, inner.lightened(0.05))
	# Thwarts and a bow deck.
	for z in [-2.6, -0.4, 1.6]:
		var f := _boat_floor(z)
		var hwz: float = f.y + 0.2 * (0.34 - 0.0) + 0.1
		_bar(pk, kit, "hinoki", Vector3(-hwz, f.x + 0.3, z), Vector3(hwz, f.x + 0.3, z), 0.16, 0.035, inner.darkened(0.08), Vector3.BACK, false)
	match variant:
		0:
			_pipe(pk, kit, "hinoki", [Vector3(0.28, _boat_floor(-2.6).x + 0.345, -3.1), Vector3(0.22, _boat_floor(1.6).x + 0.345, 2.3)], [0.03, 0.022], 5, BAMBOO_DRY, 3)
			pk.lathe(kit, "rope", Vector3(-0.1, _boat_floor(2.6).x + 0.05, 2.6), [Vector2(0.1, 0.0), Vector2(0.17, 0.04), Vector2(0.1, 0.08)], 8, ROPE)
		1:
			_pipe(pk, kit, "hinoki", [Vector3(0.3, _boat_floor(-2.6).x + 0.345, -3.2), Vector3(0.24, _boat_floor(1.6).x + 0.345, 2.2)], [0.03, 0.022], 5, BAMBOO_DRY, 3)
			# Fish baskets (biku) and a net float.
			for b in [[-0.15, 0.5, 0.2], [0.14, 0.95, 0.16], [-0.1, -1.2, 0.18]]:
				var fl := _boat_floor(b[1])
				var br: float = b[2]
				pk.lathe(kit, "rope", Vector3(b[0], fl.x, b[1]), [Vector2(br * 0.7, 0.0), Vector2(br, br * 0.8), Vector2(br * 0.9, br * 1.5), Vector2(br * 0.55, br * 1.8), Vector2(br * 0.6, br * 2.0)], 8, BAMBOO_DRY.darkened(0.1))
				pk.lathe(kit, "rope", Vector3(b[0], fl.x + br * 1.8, b[1]), [Vector2(0.0, 0.0), Vector2(br * 0.55, 0.0)], 8, Color(0.12, 0.10, 0.08), true)
			# The pole stand at the stern with the fisherman's hat.
			var ps := Vector3(-0.2, _boat_floor(-3.0).x, -3.0)
			_pipe(pk, kit, "hinoki", [ps, ps + Vector3(0, 1.35, 0)], [0.035, 0.028], 5, AGED, 2)
			_kasa(pk, kit, ps + Vector3(0, 1.3, 0), Vector3.UP, 0.25)
		_:
			# The yakata: a low roof on four posts over the middle, lanterns under its eaves, benches along the sides.
			var z0 := -1.9
			var z1 := 1.5
			var hx := 0.56
			var ey := 1.62
			var ry := 1.98
			for z in [z0, z1]:
				var fl := _boat_floor(z)
				for sx in [-1.0, 1.0]:
					_bar(pk, kit, "urushi", Vector3(sx * hx, fl.x - 0.02, z), Vector3(sx * hx, ey + 0.02, z), 0.06, 0.06, VERMILION, Vector3.RIGHT, false)
				_bar(pk, kit, "urushi", Vector3(-hx - 0.1, ey, z), Vector3(hx + 0.1, ey, z), 0.06, 0.07, VERMILION, Vector3.BACK)
				_bar(pk, kit, "urushi", Vector3(0, ey + 0.03, z), Vector3(0, ry - 0.06, z), 0.05, 0.05, VERMILION, Vector3.RIGHT, false)
			for sx in [-1.0, 1.0]:
				_bar(pk, kit, "urushi", Vector3(sx * hx, ey, z0 - 0.12), Vector3(sx * hx, ey, z1 + 0.12), 0.06, 0.07, VERMILION, Vector3.RIGHT)
				var ex: float = hx + 0.26
				var out := Vector3(sx * (ry - ey + 0.1), ex, 0).normalized()
				roof(pk, kit, "hiwada", Vector3(sx * ex, ey - 0.06, z0 - 0.3) + out * 0.04, Vector3(sx * ex, ey - 0.06, z1 + 0.3) + out * 0.04, Vector3(0, ry, z1 + 0.3) + out * 0.04,
						Vector3(0, ry, z0 - 0.3) + out * 0.04, THATCH_TINT, out)
				for k in 4:
					var lz: float = lerpf(z0 + 0.1, z1 - 0.1, float(k) / 3.0)
					var lp := Vector3(sx * (ex - 0.07), ey - 0.14, lz)
					pk.beam(kit, "steel", lp + Vector3(0, 0.02, 0), lp + Vector3(0, 0.1, 0), 0.012, 0.012, IRON)
					pk.lathe(kit, "washi", lp + Vector3(0, -0.2, 0), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.1, 0.07), Vector2(0.1, 0.15), Vector2(0.06, 0.22), Vector2(0.0, 0.22)], 6,
							PAPER_RED if k % 2 == 0 else PAPER_WARM)
				_bar(pk, kit, "hinoki", Vector3(sx * 0.4, _boat_floor(0.0).x + 0.26, z0 + 0.2), Vector3(sx * 0.4, _boat_floor(0.0).x + 0.26, z1 - 0.2), 0.22, 0.035, inner, Vector3.RIGHT)
			_pipe(pk, kit, "urushi", [Vector3(0, ry + 0.02, z0 - 0.33), Vector3(0, ry + 0.02, z1 + 0.33)], 0.05, 6, BLACK_LAC, 3)
			_pipe(pk, kit, "hinoki", [Vector3(0.2, _boat_floor(-2.6).x + 0.345, -3.3), Vector3(0.62, 0.6, -1.0)], [0.03, 0.024], 5, BAMBOO_DRY, 3)


## A bamboo fish weir (yana), `w` wide: a slatted platform rising out of the water toward +z (the water at y = 0 runs down
## onto it from -z and falls through the slats, the fish stay), on stakes driven into the bed, wings of stakes leading the
## current in, and a thatched watch hut on stilts at its +x side.
static func yana(pk: PropKit, kit: Dictionary, w := 9.0) -> void:
	var za := -3.0
	var zb := 4.2
	var ya := -0.3
	var yb := 1.25
	var hw: float = w * 0.5
	var sl: float = (yb - ya) / (zb - za)
	var dirv := Vector3(0, yb - ya, zb - za).normalized()
	var up := Vector3(0, zb - za, -(yb - ya)).normalized()
	# Cross poles on stakes.
	for kz in 4:
		var z: float = lerpf(za + 0.4, zb - 0.3, float(kz) / 3.0)
		var y: float = ya + sl * (z - za) - 0.09
		_log(pk, kit, Vector3(-hw - 0.3, y, z), Vector3(hw + 0.3, y, z), 0.07, 0.065, 6, true, 3, 0.15, 0)
		var nx: int = maxi(2, int(round(w / 1.8)))
		for kx in nx + 1:
			var x: float = lerpf(-hw, hw, float(kx) / float(nx))
			_log(pk, kit, Vector3(x, FOOT, z + 0.1), Vector3(x, y + 0.03, z + 0.1), 0.065, 0.055, 6, true, 2, 0.2, 0)
			_lash(pk, kit, Vector3(x, y + 0.02, z + 0.06), Vector3.UP, 0.1, 0.08, VINE, 5)
	# The slats: split bamboo, gaps between.
	var ns: int = int(w / 0.24)
	for k in ns:
		var x: float = -hw + (float(k) + 0.5) * w / float(ns)
		var c: Color = BAMBOO_DRY.darkened(0.12 * float(k % 3)) if k % 5 != 0 else BAMBOO.darkened(0.1)
		_bar(pk, kit, "hinoki", Vector3(x, ya, za) + up * 0.012, Vector3(x, yb, zb) + up * 0.012, 0.15, 0.03, c, Vector3.RIGHT)
	# Side boards keeping the fish on, and the wings of stakes upstream.
	for sx in [-1.0, 1.0]:
		_bar(pk, kit, "hinoki", Vector3(sx * (hw + 0.05), ya + 0.14, za) , Vector3(sx * (hw + 0.05), yb + 0.14, zb), 0.04, 0.3, AGED, Vector3.RIGHT)
		for k in 7:
			var u: float = float(k) / 6.0
			var p := Vector3(sx * (hw + 0.2 + u * 3.2), 0, za - 0.3 - u * 4.5)
			_log(pk, kit, p + Vector3(0, FOOT, 0), p + Vector3(0, 0.55, 0), 0.06, 0.05, 6, true, 2, 0.2, 0)
		_log(pk, kit, Vector3(sx * (hw + 0.2), 0.3, za - 0.36), Vector3(sx * (hw + 3.4), 0.3, za - 4.86), 0.05, 0.045, 6, true, 3, 0.1, 0)
	# The watch hut: a platform on four stilts, a thatched roof, a ladder.
	var hx: float = hw + 2.0
	var hz := 2.2
	var py := 1.7
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_log(pk, kit, Vector3(hx + sx * 1.0, FOOT, hz + sz * 1.0), Vector3(hx + sx * 0.95, py + 1.25, hz + sz * 0.95), 0.08, 0.06, 6, true, 2, 0.1, 0)
	pk.block(kit, "sugi", Vector3(hx - 1.15, py - 0.06, hz - 1.15), Vector3(hx + 1.15, py, hz + 1.15), CEDAR.lightened(0.1), uvk)
	for sx in [-1.0, 1.0]:
		_bar(pk, kit, "hinoki", Vector3(hx + sx * 1.0, py - 0.13, hz - 1.2), Vector3(hx + sx * 1.0, py - 0.13, hz + 1.2), 0.1, 0.14, AGED, Vector3.RIGHT)
		var out := Vector3(sx * 0.75, 1.45, 0).normalized()
		roof(pk, kit, "hiwada", Vector3(hx + sx * 1.45, py + 1.15, hz - 1.4), Vector3(hx + sx * 1.45, py + 1.15, hz + 1.4), Vector3(hx, py + 1.9, hz + 1.4), Vector3(hx, py + 1.9, hz - 1.4), THATCH_TINT, out)
	for sz in [-1.0, 1.0]:
		_bar(pk, kit, "hinoki", Vector3(hx - 1.3, py + 1.2, hz + sz * 0.95), Vector3(hx + 1.3, py + 1.2, hz + sz * 0.95), 0.07, 0.08, AGED, Vector3.BACK)
		_bar(pk, kit, "hinoki", Vector3(hx, py + 1.2, hz + sz * 0.95), Vector3(hx, py + 1.84, hz + sz * 0.95), 0.06, 0.06, AGED, Vector3.RIGHT, false)
	_pipe(pk, kit, "hiwada", [Vector3(hx, py + 1.94, hz - 1.45), Vector3(hx, py + 1.94, hz + 1.45)], 0.08, 6, THATCH_TINT.darkened(0.2), 3)
	for sx in [-1.0, 1.0]:
		_bar(pk, kit, "hinoki", Vector3(hx + sx * 0.25, FOOT * 0.3, hz - 1.9), Vector3(hx + sx * 0.25, py + 0.1, hz - 1.17), 0.05, 0.05, AGED, Vector3.RIGHT)
	for k in 6:
		var u: float = lerpf(0.42, 0.97, float(k) / 5.0)
		var lp := Vector3(hx, lerpf(FOOT * 0.3, py + 0.1, u), lerpf(hz - 1.9, hz - 1.17, u))
		_bar(pk, kit, "hinoki", lp + Vector3(-0.3, 0, 0), lp + Vector3(0.3, 0, 0), 0.04, 0.04, AGED, Vector3.BACK)


## A timber sledge (kinma) loaded with logs on its corduroy track of cross poles, centred, its nose toward +z: 3.2m of
## sledge on 6m of track, 1.3m to the top of its load.
static func kinma_sled(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator = null) -> void:
	rng = _rng(rng, 43)
	# The track: cross poles half sunk in the ground.
	for k in 11:
		var z: float = -3.0 + 0.6 * float(k)
		_log(pk, kit, Vector3(-0.85, 0.035, z + rng.randf_range(-0.04, 0.04)), Vector3(0.85, 0.035, z + rng.randf_range(-0.04, 0.04)), 0.075, 0.07, 6, true, 3, rng.randf() * 0.2, 0)
	var ry := 0.11
	for sx in [-1.0, 1.0]:
		# A runner, turned up at the nose.
		_bar(pk, kit, "hinoki", Vector3(sx * 0.42, ry + 0.07, -1.6), Vector3(sx * 0.42, ry + 0.07, 1.25), 0.1, 0.14, AGED, Vector3.RIGHT)
		_bar(pk, kit, "hinoki", Vector3(sx * 0.42, ry + 0.065, 1.2), Vector3(sx * 0.42, ry + 0.34, 1.75), 0.088, 0.13, AGED, Vector3.RIGHT)
		for z in [-1.1, 0.7]:
			_bar(pk, kit, "hinoki", Vector3(sx * 0.5, ry + 0.3, z + 0.11), Vector3(sx * 0.56, ry + 1.05, z + 0.11), 0.06, 0.06, AGED_DARK, Vector3.RIGHT)
	for z in [-1.1, 0.7]:
		_bar(pk, kit, "hinoki", Vector3(-0.6, ry + 0.2, z), Vector3(0.6, ry + 0.2, z), 0.14, 0.12, AGED_DARK, Vector3.BACK)
	var r := 0.16
	var rows: Array = [3, 2]
	for j in rows.size():
		var cnt: int = rows[j]
		for i in cnt:
			var x: float = (float(i) - float(cnt - 1) * 0.5) * r * 2.0
			var y: float = ry + 0.26 + r + float(j) * r * 1.73
			var rr: float = r * rng.randf_range(0.9, 1.0)
			var zz: float = rng.randf_range(-0.15, 0.1)
			_log(pk, kit, Vector3(x, y - (r - rr), zz - 1.9), Vector3(x, y - (r - rr), zz + 1.6), rr, rr * 0.93, 8, true, 3, rng.randf() * 0.15, 1)
	# The chain over the load and the drag rope lying ahead.
	var top: float = ry + 0.26 + r * 2.0 + r * 1.73
	_pipe(pk, kit, "steel", [Vector3(-0.53, ry + 0.5, -0.2), Vector3(-0.36, top - 0.1, -0.2), Vector3(-0.16, top + 0.015, -0.2), Vector3(0.16, top + 0.015, -0.2), Vector3(0.36, top - 0.1, -0.2),
			Vector3(0.53, ry + 0.5, -0.2)], 0.018, 4, IRON, 0)
	_pipe(pk, kit, "rope", [Vector3(-0.42, ry + 0.33, 1.72), Vector3(-0.2, 0.13, 2.3), Vector3(0.0, 0.13, 2.9), Vector3(0.2, 0.13, 2.3), Vector3(0.42, ry + 0.33, 1.72)], 0.02, 4, ROPE, 0)


# ======================================================================================
#  Part B: helpers (game metres; a bridge's t runs along -z)
# ======================================================================================

## The first few offending places the last corridor check found.
static var corridor_notes := PackedStringArray()


static func _dy(deck_y: Callable, span: float, t: float) -> float:
	return float(deck_y.call(clampf(t, 0.0, span)))


static func _gy(ground_y: Callable, x: float, t: float) -> float:
	return float(ground_y.call(x, t))


## The ends' heights of a straight member from t0 to t1 lying `drop` under the deck: lowered until it is nowhere higher
## than that (a chord across a dip would rise through the deck).
static func _chord(deck_y: Callable, span: float, t0: float, t1: float, drop: float) -> Vector2:
	var y0: float = _dy(deck_y, span, t0) - drop
	var y1: float = _dy(deck_y, span, t1) - drop
	var over := 0.0
	for k in range(1, 6):
		var u: float = float(k) / 6.0
		over = maxf(over, lerpf(y0, y1, u) - (_dy(deck_y, span, lerpf(t0, t1, u)) - drop))
	return Vector2(y0 - over, y1 - over)


static func _stations(span: float, step: float, min_n := 1) -> Array:
	var n: int = maxi(min_n, roundi(span / step))
	var ts: Array = []
	for k in n + 1:
		ts.append(span * float(k) / float(n))
	return ts


## A deck slab between x0 and x1 following the deck from `top` to `bot` under its surface, boarded across (u along x).
static func _deck_slab(pk: PropKit, kit: Dictionary, key: String, ts: Array, span: float, x0: float, x1: float, top: float, bot: float, deck_y: Callable, col: Color) -> void:
	for k in ts.size() - 1:
		var ta: float = ts[k]
		var tb: float = ts[k + 1]
		var ch := _chord(deck_y, span, ta, tb, top)
		var th: float = bot - top
		var a0 := Vector3(x0, ch.x, -ta)
		var a1 := Vector3(x1, ch.x, -ta)
		var b0 := Vector3(x0, ch.y, -tb)
		var b1 := Vector3(x1, ch.y, -tb)
		var dn := Vector3(0, -th, 0)
		_planks(pk, kit, key, [a0, a1, b1, b0], Vector3.UP, col)
		_planks(pk, kit, key, [a0 + dn, a1 + dn, b1 + dn, b0 + dn], Vector3.DOWN, col.darkened(0.3))
		_planks(pk, kit, key, [a0 + dn, b0 + dn, b0, a0], Vector3.LEFT, col.darkened(0.12))
		_planks(pk, kit, key, [a1 + dn, b1 + dn, b1, a1], Vector3.RIGHT, col.darkened(0.12))
		if k == 0:
			_planks(pk, kit, key, [a0 + dn, a1 + dn, a1, a0], Vector3.BACK, col.darkened(0.12))
		if k == ts.size() - 2:
			_planks(pk, kit, key, [b0 + dn, b1 + dn, b1, b0], Vector3.FORWARD, col.darkened(0.12))


## A vermilion koran along `feet` (the posts' feet on the edge beam, one post each): square posts under giboshi, a top
## rail, two lighter rails and a strut in each bay, `hgt` to the giboshi's tips. `skip_ends`: no post at the two ends
## (a lantern post or a pylon stands there).
static func _koran(pk: PropKit, kit: Dictionary, feet: Array, hgt := 1.6, skip_ends := false) -> void:
	var n := feet.size()
	var ph: float = hgt - 0.36
	for i in n:
		if skip_ends and (i == 0 or i == n - 1):
			continue
		var f: Vector3 = feet[i]
		_bar(pk, kit, "urushi", f - Vector3(0, 0.06, 0), f + Vector3(0, ph, 0), 0.2, 0.2, VERMILION, Vector3.RIGHT, false)
		_giboshi(pk, kit, f + Vector3(0, ph - 0.01, 0), 0.128)
	for i in n - 1:
		var a: Vector3 = feet[i]
		var b: Vector3 = feet[i + 1]
		_bar(pk, kit, "urushi", a + Vector3(0, ph - 0.2, 0), b + Vector3(0, ph - 0.2, 0), 0.12, 0.13, VERMILION, Vector3.RIGHT, false)
		_bar(pk, kit, "urushi", a + Vector3(0, ph * 0.52, 0), b + Vector3(0, ph * 0.52, 0), 0.09, 0.07, VERMILION.darkened(0.06), Vector3.RIGHT, false)
		_bar(pk, kit, "urushi", a + Vector3(0, ph * 0.24, 0), b + Vector3(0, ph * 0.24, 0), 0.09, 0.07, VERMILION.darkened(0.06), Vector3.RIGHT, false)
		var m: Vector3 = (a + b) * 0.5
		_bar(pk, kit, "urushi", m - Vector3(0, 0.03, 0), m + Vector3(0, ph * 0.52, 0), 0.07, 0.07, VERMILION.darkened(0.03), Vector3.RIGHT, false)


## A tall vermilion end post with a paper lantern under a little black roof, standing on `f`: 3.1m.
static func _lantern_post(pk: PropKit, kit: Dictionary, f: Vector3) -> void:
	_bar(pk, kit, "urushi", f - Vector3(0, 0.06, 0), f + Vector3(0, 2.3, 0), 0.28, 0.28, VERMILION, Vector3.RIGHT, false)
	_lantern(pk, kit, f + Vector3(0, 2.3, 0), 1.0)


## A square paper lantern standing on `p`: a black base, paper between four black bars, a flared black roof, a knob.
static func _lantern(pk: PropKit, kit: Dictionary, p: Vector3, s := 1.0) -> void:
	pk.block(kit, "urushi", p + Vector3(-0.2, -0.02, -0.2) * s, p + Vector3(0.2, 0.07, 0.2) * s, BLACK_LAC)
	pk.block(kit, "washi", p + Vector3(-0.16, 0.07, -0.16) * s, p + Vector3(0.16, 0.5, 0.16) * s, PAPER_WARM)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bar(pk, kit, "urushi", p + Vector3(sx * 0.165, 0.06, sz * 0.165) * s, p + Vector3(sx * 0.165, 0.51, sz * 0.165) * s, 0.035 * s, 0.035 * s, BLACK_LAC, Vector3.RIGHT, false)
	pk.lathe(kit, "urushi", p + Vector3(0, 0.5, 0) * s, [Vector2(0.0, -0.005), Vector2(0.31 * s, 0.0), Vector2(0.32 * s, 0.035 * s), Vector2(0.13 * s, 0.17 * s), Vector2(0.05 * s, 0.24 * s), Vector2(0.0, 0.3 * s)],
			4, BLACK_LAC.lightened(0.06), true, Basis(Vector3.UP, PI * 0.25))


## Stone abutments and wing walls at both ends: a back wall under the deck's end, a bearing shelf `shelf` under the deck
## for the stringers or girders, and a wing wall each side beside the road with a coping.
static func _abutments(pk: PropKit, kit: Dictionary, span: float, hw: float, deck_y: Callable, ground_y: Callable, shelf: float) -> void:
	for e in 2:
		var t0: float = 0.0 if e == 0 else span
		var inw: float = 1.0 if e == 0 else -1.0
		var d: float = _dy(deck_y, span, t0)
		var gmin: float = d - 1.5
		for x in [-hw - 1.0, 0.0, hw + 1.0]:
			for tt in [t0 + inw * 0.8, t0, t0 - inw * 5.0]:
				gmin = minf(gmin, _gy(ground_y, x, tt))
		var bot: float = gmin - 1.5
		var za: float = -(t0 - inw * 1.5)
		var zb: float = -t0
		var zc: float = -(t0 + inw * 0.7)
		pk.block(kit, "ishi", Vector3(-hw - 0.5, bot, minf(za, zb)), Vector3(hw + 0.5, d - 0.05, maxf(za, zb)), GRANITE, uvk)
		pk.block(kit, "ishi", Vector3(-hw - 0.9, bot, minf(zb, zc)), Vector3(hw + 0.9, d - shelf, maxf(zb, zc)), GRANITE.darkened(0.06), uvk)
		var zw0: float = -(t0 - inw * 5.0)
		var zw1: float = -(t0 + inw * 0.2)
		for sx in [-1.0, 1.0]:
			var xa: float = sx * (hw + 0.08)
			var xb: float = sx * (hw + 1.1)
			pk.block(kit, "ishi", Vector3(minf(xa, xb), bot, minf(zw0, zw1)), Vector3(maxf(xa, xb), d + 0.3, maxf(zw0, zw1)), GRANITE_MOSSY.lerp(GRANITE, 0.5), uvk)
			var xc: float = sx * (hw + 0.04)
			var xd: float = sx * (hw + 1.16)
			pk.block(kit, "ishi", Vector3(minf(xc, xd), d + 0.3, minf(zw0, zw1) - 0.05), Vector3(maxf(xc, xd), d + 0.42, maxf(zw0, zw1) + 0.05), GRANITE.lightened(0.08), uvk)


# ======================================================================================
#  Part B1: road bridges
# ======================================================================================

## A road bridge from z = 0 to z = -span. Style 0: a timber trestle (bents of round piles every 7 to 8m with tie beams and
## cross braces down into the ground, stringers on cap beams, a plank deck); style 1: a vermilion steel deck arch (ribs
## springing from concrete skewbacks in the banks, spandrel columns, girders, a concrete deck, end pylons). Both carry
## vermilion railings with giboshi at x = +-(hw + 0.25), 1.6m high, and stand on stone abutments with wing walls.
static func road_bridge(pk: PropKit, kit: Dictionary, span: float, hw: float, deck_y: Callable, ground_y: Callable, style := 0) -> void:
	if style == 1:
		_arch_bridge(pk, kit, span, hw, deck_y, ground_y)
		_abutments(pk, kit, span, hw, deck_y, ground_y, 1.12)
	else:
		_trestle_bridge(pk, kit, span, hw, deck_y, ground_y)
		_abutments(pk, kit, span, hw, deck_y, ground_y, 0.59)


static func _trestle_bridge(pk: PropKit, kit: Dictionary, span: float, hw: float, deck_y: Callable, ground_y: Callable) -> void:
	var nb: int = maxi(1, roundi(span / 7.5))
	var ts: Array = _stations(span, span / float(nb * 3))
	var bay: float = span / float(nb)
	_deck_slab(pk, kit, "sugi", ts, span, -(hw + 0.55), hw + 0.55, 0.04, 0.16, deck_y, CEDAR.lightened(0.14))
	# The edge beams the railings stand on, and the railings.
	for sx in [-1.0, 1.0]:
		var feet: Array = []
		for k in ts.size():
			feet.append(Vector3(sx * (hw + 0.25), _dy(deck_y, span, ts[k]) + 0.14, -float(ts[k])))
		for k in ts.size() - 1:
			var a: Vector3 = feet[k]
			var b: Vector3 = feet[k + 1]
			_bar(pk, kit, "urushi", a - Vector3(0, 0.1, 0), b - Vector3(0, 0.1, 0), 0.3, 0.2, VERMILION.darkened(0.08), Vector3.RIGHT, k == 0 or k == ts.size() - 2)
		_koran(pk, kit, feet, 1.6, true)
		_lantern_post(pk, kit, feet[0])
		_lantern_post(pk, kit, feet[feet.size() - 1])
	# Stringers from bent to bent (in shorter pieces where the deck curves too much for one).
	var nstr: int = 5 if hw < 6.5 else 7
	for b in nb:
		var ta: float = bay * float(b)
		var tb: float = bay * float(b + 1)
		var straight := _chord(deck_y, span, ta, tb, 0.16)
		var sag: float = (_dy(deck_y, span, (ta + tb) * 0.5) - 0.16) - (straight.x + straight.y) * 0.5
		var pieces: int = 1 if sag < 0.035 else 3
		for pz in pieces:
			var t0: float = lerpf(ta, tb, float(pz) / float(pieces))
			var t1: float = lerpf(ta, tb, float(pz + 1) / float(pieces))
			var ch := _chord(deck_y, span, t0, t1, 0.16 + 0.21)
			for i in nstr:
				var x: float = lerpf(-(hw - 0.35), hw - 0.35, float(i) / float(nstr - 1))
				_bar(pk, kit, "hinoki", Vector3(x, ch.x, -t0 + 0.02), Vector3(x, ch.y, -t1 - 0.02), 0.32, 0.42, AGED.darkened(0.08 * float(i % 2)), Vector3.RIGHT, false)
	# The bents.
	var npile: int = 4 if hw < 6.5 else 5
	for b in range(1, nb):
		var t: float = bay * float(b)
		var d: float = _dy(deck_y, span, t)
		var cap_bot: float = d - 0.58 - 0.45
		_bar(pk, kit, "hinoki", Vector3(-(hw + 0.8), cap_bot + 0.225, -t), Vector3(hw + 0.8, cap_bot + 0.225, -t), 0.42, 0.45, AGED, Vector3.BACK)
		var gmax := -INF
		var xo: float = hw + 0.15
		var any := false
		for i in npile:
			var x: float = lerpf(-xo, xo, float(i) / float(npile - 1))
			var g: float = _gy(ground_y, x, t)
			gmax = maxf(gmax, g)
			if g > cap_bot - 0.3:
				continue
			any = true
			_pipe(pk, kit, "hinoki", [Vector3(x, g - 1.2, -t), Vector3(x, cap_bot + 0.1, -t)], [0.27, 0.23], 8, BARK.lightened(0.12), 0, Vector3.BACK, BARK_DARK.lightened(0.1))
		if not any:
			continue
		var levels: Array = [cap_bot - 0.2]
		var y: float = cap_bot - 3.0
		while y > gmax + 0.9:
			levels.append(y)
			_bar(pk, kit, "hinoki", Vector3(-(xo + 0.6), y, -t), Vector3(xo + 0.6, y, -t), 0.14, 0.3, AGED.darkened(0.1), Vector3.BACK)
			y -= 3.0
		if levels.size() > 1 and float(levels[levels.size() - 1]) - (gmax + 0.3) > 2.2:
			levels.append(gmax + 0.3)
		for j in levels.size() - 1:
			var yu: float = float(levels[j]) - 0.25
			var yl: float = float(levels[j + 1]) + 0.25
			_bar(pk, kit, "hinoki", Vector3(-xo, yu, -t + 0.3), Vector3(xo, yl, -t + 0.3), 0.12, 0.2, AGED_DARK.lightened(0.1), Vector3.BACK)
			_bar(pk, kit, "hinoki", Vector3(xo, yu, -t - 0.3), Vector3(-xo, yl, -t - 0.3), 0.12, 0.2, AGED_DARK.lightened(0.1), Vector3.BACK)


static func _arch_bridge(pk: PropKit, kit: Dictionary, span: float, hw: float, deck_y: Callable, ground_y: Callable) -> void:
	var red := VERMILION
	var np: int = maxi(4, roundi(span / 5.0))
	if np % 2 == 1:
		np += 1
	var tc: Array = _stations(span, span / float(np))
	var tf: Array = _stations(span, span / float(np * 2))
	_deck_slab(pk, kit, "concrete", tf, span, -(hw + 0.6), hw + 0.6, 0.04, 0.30, deck_y, CONCRETE_COL)
	for sx in [-1.0, 1.0]:
		var feet: Array = []
		for k in tf.size():
			feet.append(Vector3(sx * (hw + 0.25), _dy(deck_y, span, tf[k]) + 0.16, -float(tf[k])))
		for k in tf.size() - 1:
			var a: Vector3 = feet[k]
			var b: Vector3 = feet[k + 1]
			_bar(pk, kit, "concrete", a + Vector3(sx * 0.08, -0.11, 0), b + Vector3(sx * 0.08, -0.11, 0), 0.5, 0.22, CONCRETE_COL.lightened(0.05), Vector3.RIGHT, false)
		_koran(pk, kit, feet, 1.6, false)
	# Girders and cross beams.
	var gx: float = hw - 0.6
	var xs: Array = [-gx, gx] if hw < 4.5 else [-gx, -gx / 3.0, gx / 3.0, gx]
	for k in np:
		var ch := _chord(deck_y, span, tc[k], tc[k + 1], 0.30 + 0.40)
		for x in xs:
			_bar(pk, kit, "urushi", Vector3(x, ch.x, -float(tc[k]) + 0.02), Vector3(x, ch.y, -float(tc[k + 1]) - 0.02), 0.34, 0.8, red, Vector3.RIGHT, false)
	for k in range(1, np):
		var d: float = _dy(deck_y, span, tc[k])
		_bar(pk, kit, "urushi", Vector3(-gx, d - 0.62, -float(tc[k])), Vector3(gx, d - 0.62, -float(tc[k])), 0.22, 0.5, red.darkened(0.1), Vector3.BACK, false)
	# The arch: its springings found on the banks, its crown just under the girders.
	var tm: float = span * 0.5
	var crown: float = _dy(deck_y, span, tm) - 1.10 - 0.45
	var gmin := INF
	for k in 41:
		gmin = minf(gmin, _gy(ground_y, 0.0, span * float(k) / 40.0))
	var rise: float = clampf(span * 0.2, 2.0, maxf(2.0, crown - gmin - 0.6))
	var spring: Array = []
	for e in 2:
		var inw: float = 1.0 if e == 0 else -1.0
		var t0: float = 0.0 if e == 0 else span
		var found := span * 0.3
		var ys: float = crown - rise
		var hit := false
		var s := 0.5
		while s <= span * 0.3:
			if _gy(ground_y, 0.0, t0 + inw * s) < ys - 0.3:
				found = s
				hit = true
				break
			s += 0.5
		if not hit:
			ys = minf(_gy(ground_y, 0.0, t0 + inw * found) + 0.3, crown - 1.0)
		spring.append(Vector2(t0 + inw * found, ys))
	var sa: Vector2 = spring[0]
	var sb: Vector2 = spring[1]
	var f: float = crown - (sa.y + sb.y) * 0.5
	var arch := func(t: float, ff: float) -> float:
		var u: float = clampf((t - sa.x) / (sb.x - sa.x), 0.0, 1.0)
		return lerpf(sa.y, sb.y, u) + 4.0 * ff * u * (1.0 - u)
	for it in 4:
		var over := 0.0
		for k in 33:
			var t: float = lerpf(sa.x, sb.x, float(k) / 32.0)
			over = maxf(over, float(arch.call(t, f)) + 0.36 - (_dy(deck_y, span, t) - 1.12))
		if over <= 0.0:
			break
		f -= over * 1.05
	var nseg := 16
	for x in xs:
		for k in nseg:
			var t0: float = lerpf(sa.x, sb.x, float(k) / float(nseg))
			var t1: float = lerpf(sa.x, sb.x, float(k + 1) / float(nseg))
			var p0 := Vector3(x, arch.call(t0, f), -t0)
			var p1 := Vector3(x, arch.call(t1, f), -t1)
			var dd := (p1 - p0).normalized() * 0.03
			_bar(pk, kit, "urushi", p0 - dd, p1 + dd, 0.42, 0.7, red.darkened(0.04), Vector3.RIGHT, false)
	# Columns: on the arch between its springings, on plinths on the banks outside them.
	for k in range(1, np):
		var t: float = tc[k]
		var top: float = _dy(deck_y, span, t) - 1.08
		var on_arch: bool = t > sa.x + 0.4 and t < sb.x - 0.4
		for x in xs:
			var bot: float
			if on_arch:
				bot = float(arch.call(t, f)) + 0.2
			else:
				var g: float = _gy(ground_y, x, t)
				bot = g - 0.9
				if top - g > 0.4:
					pk.block(kit, "concrete", Vector3(x - 0.4, g - 1.2, -t - 0.4), Vector3(x + 0.4, g + 0.25, -t + 0.4), CONCRETE_COL, uvk)
			if top - bot > 0.45:
				_bar(pk, kit, "urushi", Vector3(x, bot, -t), Vector3(x, top, -t), 0.28, 0.3, red, Vector3.RIGHT, false)
		if on_arch:
			var ya: float = arch.call(t, f)
			_bar(pk, kit, "urushi", Vector3(-gx, ya, -t), Vector3(gx, ya, -t), 0.22, 0.26, red.darkened(0.12), Vector3.BACK, false)
			if k + 1 < np and float(tc[k + 1]) < sb.x - 0.4:
				var yb: float = arch.call(tc[k + 1], f)
				var s1: float = 1.0 if k % 2 == 0 else -1.0
				_bar(pk, kit, "urushi", Vector3(-gx * s1, ya, -t), Vector3(gx * s1, yb, -float(tc[k + 1])), 0.14, 0.14, red.darkened(0.16), Vector3.UP, false)
	# The skewbacks.
	for e in 2:
		var sp: Vector2 = spring[e]
		var inw: float = 1.0 if e == 0 else -1.0
		var bot := sp.y - 1.5
		for x in [-gx - 1.0, 0.0, gx + 1.0]:
			for tt in [sp.x - inw * 2.6, sp.x + inw * 0.6]:
				bot = minf(bot, _gy(ground_y, x, tt) - 1.5)
		var za: float = -(sp.x - inw * 2.6)
		var zb: float = -(sp.x + inw * 0.6)
		pk.block(kit, "concrete", Vector3(-gx - 1.0, bot, minf(za, zb)), Vector3(gx + 1.0, sp.y + 0.75, maxf(za, zb)), CONCRETE_COL.darkened(0.05), uvk)
	# End pylons with lanterns.
	for e in 2:
		var t0: float = 0.0 if e == 0 else span
		var inw: float = 1.0 if e == 0 else -1.0
		var d: float = _dy(deck_y, span, t0)
		var za: float = -(t0 - inw * 1.4)
		var zb: float = -(t0 + inw * 0.3)
		for sx in [-1.0, 1.0]:
			var xa: float = sx * (hw + 0.06)
			var xb: float = sx * (hw + 1.3)
			var g: float = minf(_gy(ground_y, sx * (hw + 0.7), t0), d) - 2.0
			pk.block(kit, "concrete", Vector3(minf(xa, xb), g, minf(za, zb)), Vector3(maxf(xa, xb), d + 3.2, maxf(za, zb)), CONCRETE_COL, uvk)
			var c := Vector3((xa + xb) * 0.5 + sx * 0.03, d + 3.2, (za + zb) * 0.5)
			pk.block(kit, "concrete", c + Vector3(-0.66, 0.0, -0.93), c + Vector3(0.66, 0.22, 0.93), CONCRETE_COL.lightened(0.08), uvk)
			pk.block(kit, "urushi", Vector3(minf(xa, xb) - 0.03, d + 2.5, minf(za, zb) - 0.03), Vector3(maxf(xa, xb) + 0.03, d + 2.72, maxf(za, zb) + 0.03), red)
			_lantern(pk, kit, c + Vector3(0, 0.22, 0), 1.5)


# ======================================================================================
#  Part B2: the suspension bridge
# ======================================================================================

## A tsuribashi from z = 0 to z = -span: a weathered steel portal tower at each end (legs at x = +-(hw + 0.9), the portal
## beam 12.3m over the deck, a tiled cap), two main cables a side sagging to 2.5m over the deck at mid span, hangers every
## 3m to cross beams under the deck, timber stringers and planks, wire netting 1.5m high at x = +-(hw + 0.2), back stays
## to concrete anchor blocks 14m behind the towers, and wind guys to the valley's sides where they are within 40m.
static func suspension_bridge(pk: PropKit, kit: Dictionary, span: float, hw: float, deck_y: Callable, ground_y: Callable) -> void:
	var ts: Array = _stations(span, 3.0, 2)
	var n := ts.size() - 1
	_deck_slab(pk, kit, "sugi", ts, span, -(hw + 0.36), hw + 0.36, 0.04, 0.13, deck_y, CEDAR.lightened(0.14))
	for k in n:
		var ch := _chord(deck_y, span, ts[k], ts[k + 1], 0.25)
		for i in 4:
			var x: float = lerpf(-(hw - 0.4), hw - 0.4, float(i) / 3.0)
			_bar(pk, kit, "hinoki", Vector3(x, ch.x, -float(ts[k])), Vector3(x, ch.y, -float(ts[k + 1])), 0.2, 0.24, AGED, Vector3.RIGHT, false)
	var d_mid: float = _dy(deck_y, span, span * 0.5)
	var top: Array = [_dy(deck_y, span, 0.0) + 14.06, _dy(deck_y, span, span) + 14.06]
	var sag: float = (float(top[0]) + float(top[1])) * 0.5 - (d_mid + 2.5)
	var cable := func(t: float) -> float:
		var u: float = clampf(t / span, 0.0, 1.0)
		return lerpf(top[0], top[1], u) - 4.0 * sag * u * (1.0 - u)
	for sx in [-1.0, 1.0]:
		# The main cables and their back stays.
		for xo in [0.4, 0.62]:
			var pts: Array = []
			for k in n + 1:
				pts.append(Vector3(sx * (hw + xo), cable.call(ts[k]), -float(ts[k])))
			_pipe(pk, kit, "steel", pts, 0.055, 6, CABLE, 0)
			for e in 2:
				var t0: float = 0.0 if e == 0 else span
				var ta: float = t0 + (-14.0 if e == 0 else 14.0)
				var g: float = _gy(ground_y, sx * (hw + 0.5), ta)
				_pipe(pk, kit, "steel", [Vector3(sx * (hw + xo), top[e], -t0), Vector3(sx * (hw + xo), g + 0.7, -ta)], 0.055, 6, CABLE, 0)
		for e in 2:
			var ta: float = -14.0 if e == 0 else span + 14.0
			var g: float = _gy(ground_y, sx * (hw + 0.5), ta)
			var xa: float = sx * (hw + 0.1)
			var xb: float = sx * (hw + 1.3)
			pk.block(kit, "concrete", Vector3(minf(xa, xb), g - 1.5, -ta - 1.1), Vector3(maxf(xa, xb), g + 1.15, -ta + 1.1), CONCRETE_COL, uvk)
			pk.block(kit, "steel", Vector3(sx * (hw + 0.51) - 0.3, g + 1.15, -ta - 0.25), Vector3(sx * (hw + 0.51) + 0.3, g + 1.21, -ta + 0.25), RUST)
		# Hangers and their clamps; the netting's posts, cables and strands; a toe board.
		var feet: Array = []
		for k in n + 1:
			var t: float = ts[k]
			var d: float = _dy(deck_y, span, t)
			feet.append(Vector3(sx * (hw + 0.2), d, -t))
			_bar(pk, kit, "steel", Vector3(sx * (hw + 0.2), d - 0.12, -t), Vector3(sx * (hw + 0.2), d + 1.5, -t), 0.07, 0.07, IRON.lightened(0.12), Vector3.RIGHT)
			if k > 0 and k < n:
				var cy: float = cable.call(t)
				pk.block(kit, "steel", Vector3(sx * (hw + 0.51) - 0.19, cy - 0.09, -t - 0.07), Vector3(sx * (hw + 0.51) + 0.19, cy + 0.09, -t + 0.07), IRON.lightened(0.1))
				_pipe(pk, kit, "steel", [Vector3(sx * (hw + 0.51), cy - 0.08, -t), Vector3(sx * (hw + 0.51), d - 0.5, -t)], 0.02, 3, CABLE.lightened(0.1), 0)
		for h in [0.5, 1.0, 1.46]:
			var pts: Array = []
			for fp in feet:
				pts.append((fp as Vector3) + Vector3(0, h, 0))
			_pipe(pk, kit, "steel", pts, 0.014, 3, CABLE, 0, Vector3.RIGHT)
		for k in n:
			var a: Vector3 = feet[k]
			var b: Vector3 = feet[k + 1]
			for u in [0.25, 0.5, 0.75]:
				var m: Vector3 = a.lerp(b, u)
				_pipe(pk, kit, "steel", [m - Vector3(0, 0.03, 0), m + Vector3(0, 1.46, 0)], 0.008, 3, CABLE.darkened(0.2), 0)
			_bar(pk, kit, "hinoki", a + Vector3(sx * 0.1, 0.085, 0), b + Vector3(sx * 0.1, 0.085, 0), 0.06, 0.25, AGED.darkened(0.1), Vector3.RIGHT, k == 0 or k == n - 1)
	# Cross beams under the deck at the hangers.
	for k in range(1, n):
		var t: float = ts[k]
		var d: float = _dy(deck_y, span, t)
		_bar(pk, kit, "steel", Vector3(-(hw + 0.72), d - 0.5, -t), Vector3(hw + 0.72, d - 0.5, -t), 0.2, 0.26, RUST, Vector3.BACK)
	# The towers.
	for e in 2:
		var t0: float = 0.0 if e == 0 else span
		var d: float = _dy(deck_y, span, t0)
		var z: float = -t0
		for sx in [-1.0, 1.0]:
			var x: float = sx * (hw + 0.9)
			var g: float = minf(_gy(ground_y, x, t0), d)
			pk.block(kit, "concrete", Vector3(x - 0.6, g - 2.0, z - 0.7), Vector3(x + 0.6, minf(g + 0.4, d - 0.2), z + 0.7), CONCRETE_COL, uvk)
			_bar(pk, kit, "steel", Vector3(x, g - 0.5, z), Vector3(x, d + 13.72, z), 0.6, 0.8, RUST, Vector3.RIGHT, false)
			# Rivetted bands up the leg.
			var by: float = d + 1.0
			while by < d + 12.0:
				pk.block(kit, "steel", Vector3(x - 0.32, by, z - 0.42), Vector3(x + 0.32, by + 0.14, z + 0.42), RUST.darkened(0.2))
				by += 3.6
			for st in [-1.0, 1.0]:
				_bar(pk, kit, "hinoki", Vector3(sx * (hw + 1.2), d + 14.0, z + st * 0.36), Vector3(sx * (hw + 1.2), d + 14.52, z + st * 0.36), 0.12, 0.12, AGED_DARK, Vector3.RIGHT, false)
			# Saddles under the cables.
			pk.block(kit, "steel", Vector3(sx * (hw + 0.51) - 0.26, d + 13.99, z - 0.3), Vector3(sx * (hw + 0.51) + 0.26, d + 14.03, z + 0.3), IRON.lightened(0.1))
		_bar(pk, kit, "steel", Vector3(-(hw + 1.25), d + 12.75, z), Vector3(hw + 1.25, d + 12.75, z), 0.6, 0.8, RUST.lightened(0.04), Vector3.BACK)
		_bar(pk, kit, "steel", Vector3(-(hw + 1.45), d + 13.85, z), Vector3(hw + 1.45, d + 13.85, z), 1.0, 0.3, RUST.darkened(0.08), Vector3.BACK)
		_bar(pk, kit, "steel", Vector3(-(hw + 1.25), d - 1.3, z), Vector3(hw + 1.25, d - 1.3, z), 0.5, 0.6, RUST.lightened(0.04), Vector3.BACK)
		for st in [-1.0, 1.0]:
			var out := Vector3(0, 1.0, st * 0.45).normalized()
			roof(pk, kit, "kawara", Vector3(-(hw + 2.0), d + 14.4, z + st * 1.1), Vector3(hw + 2.0, d + 14.4, z + st * 1.1), Vector3(hw + 2.0, d + 14.9, z), Vector3(-(hw + 2.0), d + 14.9, z), KAWARA, out)
			_bar(pk, kit, "hinoki", Vector3(-(hw + 1.9), d + 14.47, z + st * 0.36), Vector3(hw + 1.9, d + 14.47, z + st * 0.36), 0.16, 0.1, AGED_DARK, Vector3.BACK)
		_pipe(pk, kit, "kawara", [Vector3(-(hw + 2.05), d + 14.9, z), Vector3(hw + 2.05, d + 14.9, z)], 0.13, 6, KAWARA_OLD, 3)
	# Wind guys.
	for tu in [0.33, 0.67]:
		var k: int = clampi(roundi(tu * float(n)), 1, n - 1)
		var t: float = ts[k]
		var d: float = _dy(deck_y, span, t)
		for sx in [-1.0, 1.0]:
			var s0 := Vector3(sx * (hw + 0.7), d - 0.5, -t)
			var dirv := Vector3(sx * 0.75, -0.5, 0.43 if tu < 0.5 else -0.43).normalized()
			var s := 1.0
			while s <= 40.0:
				var p: Vector3 = s0 + dirv * s
				if _gy(ground_y, p.x, -p.z) >= p.y:
					_pipe(pk, kit, "steel", [s0, p + dirv * 0.3], 0.03, 4, CABLE, 0)
					pk.block(kit, "concrete", p + Vector3(-0.6, -1.0, -0.6), p + Vector3(0.6, 0.45, 0.6), CONCRETE_COL, uvk)
					break
				s += 0.5


# ======================================================================================
#  Part B3/B4: along a path (the kit's frame is the world)
# ======================================================================================

## Frames along a path: [forward, right, up] at each point.
static func _path_frames(pts: PackedVector3Array, rights: PackedVector3Array) -> Array:
	var out: Array = []
	var n := pts.size()
	for i in n:
		var f: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var r: Vector3 = rights[mini(i, rights.size() - 1)]
		r = (r - f * r.dot(f)).normalized()
		out.append([f, r, r.cross(f).normalized()])
	return out


## A kakehashi: a plank road bolted to a cliff along `pts` (the deck surface's middle, about every 2m) with `rights` the
## right of travel at each; `side` +1 when the drop is on the right, -1 on the left; `ground_y.call(x, z)` the rock's
## height. Cross joists at every point from 0.6 inside the cliff edge to 0.45 past the valley edge, two stringers and the
## planks on them, at every second point a strut from the joist's valley end down and back into the rock (or a post to
## the ground, or a short strut under the deck where the rock is out of reach), iron straps and shoes, a log kerb along
## the valley edge (its top 0.35 over the deck) and an iron post and chain railing 1.5m high outside it.
static func ledge_walk(pk: PropKit, kit: Dictionary, pts: PackedVector3Array, rights: PackedVector3Array, hw: float, side: float, ground_y: Callable) -> void:
	var n := pts.size()
	if n < 2:
		return
	var fr: Array = _path_frames(pts, rights)
	var sd: float = 1.0 if side >= 0.0 else -1.0
	# A point at lateral v (toward the valley) and height h over the deck at point i.
	var at := func(i: int, v: float, h: float) -> Vector3:
		return pts[i] + (fr[i][1] as Vector3) * (sd * v) + (fr[i][2] as Vector3) * h
	var plank := CEDAR.lightened(0.14)
	var kerb: Array = []
	var arc: Array = [0.0]
	for i in n:
		kerb.append(at.call(i, hw + 0.26, 0.15))
		if i > 0:
			arc.append(float(arc[i - 1]) + (pts[i] - pts[i - 1]).length())
	for i in n - 1:
		var up: Vector3 = fr[i][2]
		var rv: Vector3 = (fr[i][1] as Vector3) * sd
		# Planks: top, underside and the valley edge.
		var a0: Vector3 = at.call(i, -(hw + 0.15), -0.04)
		var a1: Vector3 = at.call(i, hw + 0.47, -0.04)
		var b0: Vector3 = at.call(i + 1, -(hw + 0.15), -0.04)
		var b1: Vector3 = at.call(i + 1, hw + 0.47, -0.04)
		var dn: Vector3 = up * -0.09
		_planks(pk, kit, "sugi", [a0, a1, b1, b0], up, plank)
		_planks(pk, kit, "sugi", [a0 + dn, a1 + dn, b1 + dn, b0 + dn], -up, plank.darkened(0.3))
		_planks(pk, kit, "sugi", [a1 + dn, b1 + dn, b1, a1], rv, plank.darkened(0.12))
		for v in [-(hw - 0.6), hw + 0.2]:
			var s0: Vector3 = at.call(i, v, -0.235)
			var s1: Vector3 = at.call(i + 1, v, -0.235)
			var e := (s1 - s0).normalized() * 0.03
			_bar(pk, kit, "hinoki", s0 - e, s1 + e, 0.26, 0.21, AGED, rv, false)
	var ks: float = _seed_of(kerb[0])
	_log_pipe(pk, kit, kerb, 0.185, 12, false, ks, 0.0)
	_cut(pk, kit, kerb[0], ((kerb[1] as Vector3) - (kerb[0] as Vector3)).normalized(), -1.0, 0.185, 12, 1, Vector3.UP, ks)
	_cut(pk, kit, kerb[n - 1], ((kerb[n - 1] as Vector3) - (kerb[n - 2] as Vector3)).normalized(), 1.0, 0.185, 12, 1, Vector3.UP, fposmod(ks * 3.1, 1.0))
	for i in n:
		var rv: Vector3 = (fr[i][1] as Vector3) * sd
		var fw: Vector3 = fr[i][0]
		var ja: Vector3 = at.call(i, -(hw + 0.6), -0.47)
		var jb: Vector3 = at.call(i, hw + 0.45, -0.47)
		_bar(pk, kit, "hinoki", ja, jb, 0.22, 0.26, AGED.darkened(0.08), fw)
		if i % 2 != 0:
			continue
		# An iron dog holding the kerb log down.
		var kp: Vector3 = kerb[i]
		pk.beam(kit, "steel", kp + (fr[i][2] as Vector3) * 0.19 - rv * 0.12, kp + (fr[i][2] as Vector3) * 0.19 + rv * 0.12, 0.05, 0.02, IRON, fw)
		var s0: Vector3 = at.call(i, hw + 0.3, -0.6)
		var g0: float = float(ground_y.call(s0.x, s0.z))
		if g0 > s0.y - 0.5:
			continue
		var hd := Vector3(rv.x, 0, rv.z).normalized()
		var dirv: Vector3 = (-hd * cos(deg_to_rad(55.0)) + Vector3.DOWN * sin(deg_to_rad(55.0))).normalized()
		var hit := Vector3.ZERO
		var found := false
		var s := 0.25
		while s <= 14.0:
			var p: Vector3 = s0 + dirv * s
			if float(ground_y.call(p.x, p.z)) >= p.y:
				hit = p
				found = true
				break
			s += 0.25
		# The strap round the joist's end.
		_bar(pk, kit, "steel", at.call(i, hw + 0.2, -0.47), at.call(i, hw + 0.32, -0.47), 0.255, 0.3, IRON.lightened(0.06), fw, false)
		if found:
			_bar(pk, kit, "hinoki", s0 + dirv * -0.05, hit + dirv * 0.5, 0.2, 0.2, AGED, fw, false)
			_bar(pk, kit, "steel", hit - dirv * 0.3, hit + dirv * 0.1, 0.27, 0.27, IRON.lightened(0.06), fw)
		elif s0.y - g0 <= 16.0:
			_bar(pk, kit, "hinoki", s0 + Vector3(0, 0.02, 0), Vector3(s0.x, g0 - 0.6, s0.z), 0.22, 0.22, AGED, fw, false)
			_stone(pk, kit, Vector3(s0.x, g0, s0.z), 0.45, GRANITE, 0.45)
		else:
			var e1: Vector3 = at.call(i, -hw, -0.6) + Vector3.DOWN * ((2.0 * hw + 0.3) * tan(deg_to_rad(50.0)))
			_bar(pk, kit, "hinoki", s0, e1 + (e1 - s0).normalized() * 0.4, 0.2, 0.2, AGED, fw, false)
			_bar(pk, kit, "steel", e1 - (e1 - s0).normalized() * 0.3, e1 + (e1 - s0).normalized() * 0.1, 0.27, 0.27, IRON.lightened(0.06), fw)
	# The railing: posts every 3m by distance along, two chains sagging between them.
	var total: float = arc[n - 1]
	var np: int = maxi(1, roundi(total / 3.0))
	var posts: Array = []
	for k in np + 1:
		var sdist: float = total * float(k) / float(np)
		var i := 0
		while i < n - 2 and float(arc[i + 1]) < sdist:
			i += 1
		var u: float = clampf((sdist - float(arc[i])) / maxf(float(arc[i + 1]) - float(arc[i]), 0.001), 0.0, 1.0)
		var base: Vector3 = (at.call(i, hw + 0.52, 0.0) as Vector3).lerp(at.call(i + 1, hw + 0.52, 0.0), u)
		var rv: Vector3 = (fr[i][1] as Vector3) * sd
		var up: Vector3 = fr[i][2]
		_bar(pk, kit, "steel", base - up * 0.34, base + up * 1.5, 0.07, 0.07, IRON.lightened(0.08), rv)
		_bar(pk, kit, "steel", base - up * 0.235 - rv * 0.2, base - up * 0.235 + rv * 0.02, 0.12, 0.1, IRON.lightened(0.04), fr[i][0], false)
		posts.append([base, up])
	for k in np:
		var pa: Vector3 = posts[k][0]
		var pb: Vector3 = posts[k + 1][0]
		var ua: Vector3 = posts[k][1]
		var ub: Vector3 = posts[k + 1][1]
		for h in [1.42, 0.85]:
			var a: Vector3 = pa + ua * h
			var b: Vector3 = pb + ub * h
			_pipe(pk, kit, "steel", [a, a.lerp(b, 0.33) - Vector3(0, 0.14, 0), a.lerp(b, 0.67) - Vector3(0, 0.14, 0), b], 0.022, 3, IRON.lightened(0.15), 0, Vector3.RIGHT)


## A shura, a log-built timber slide the cars race down, along `pts`/`rights` (as ledge_walk's): slanting walls of three
## logs either side (their inner faces at hw + 0.1 from the middle, their tops 1.5 over the deck) held by stakes, cross
## sleepers on two log stringers under the deck, and trestle bents down to the ground (posts 14m at most) wherever it
## lies more than 0.5 under the deck.
static func timber_chute(pk: PropKit, kit: Dictionary, pts: PackedVector3Array, rights: PackedVector3Array, hw: float, ground_y: Callable) -> void:
	var n := pts.size()
	if n < 2:
		return
	var fr: Array = _path_frames(pts, rights)
	var at := func(i: int, v: float, h: float) -> Vector3:
		return pts[i] + (fr[i][1] as Vector3) * v + (fr[i][2] as Vector3) * h
	var r := 0.27
	for sx in [-1.0, 1.0]:
		for k in 3:
			var line: Array = []
			for i in n:
				line.append(at.call(i, sx * (hw + 0.1 + r + 0.1 * float(k)), 0.2 + 0.5 * float(k)))
			var rr: float = r * (1.0 - 0.04 * float(k))
			var ls: float = _seed_of(line[0] + Vector3(0, float(k), 0))
			_log_pipe(pk, kit, line, rr, 12, true, ls, 0.06 * float(k))
			_cut(pk, kit, line[0], ((line[1] as Vector3) - (line[0] as Vector3)).normalized(), -1.0, rr, 12, 0, Vector3.UP, ls, 0.06 * float(k))
			_cut(pk, kit, line[n - 1], ((line[n - 1] as Vector3) - (line[n - 2] as Vector3)).normalized(), 1.0, rr, 12, 0, Vector3.UP, fposmod(ls * 3.1, 1.0), 0.06 * float(k))
		var sline: Array = []
		for i in n:
			sline.append(at.call(i, sx * hw * 0.6, -0.52))
		var ss: float = _seed_of(sline[0])
		_log_pipe(pk, kit, sline, 0.16, 10, false, ss, 0.1)
		_cut(pk, kit, sline[0], ((sline[1] as Vector3) - (sline[0] as Vector3)).normalized(), -1.0, 0.16, 10, 1, Vector3.UP, ss, 0.1)
		_cut(pk, kit, sline[n - 1], ((sline[n - 1] as Vector3) - (sline[n - 2] as Vector3)).normalized(), 1.0, 0.16, 10, 1, Vector3.UP, ss, 0.1)
	for i in n:
		var rv: Vector3 = fr[i][1]
		_log(pk, kit, at.call(i, -(hw + 1.2), -0.2), at.call(i, hw + 1.2, -0.2), 0.16, 0.15, 6, true, 3, 0.1 * float(i % 2), 0, fr[i][0])
		if i % 2 != 0:
			continue
		for sx in [-1.0, 1.0]:
			# A stake outside the wall, through the sleeper's end into the ground where it is near.
			var sp: Vector3 = at.call(i, sx * (hw + 0.1 + r * 2.0 + 0.2 + 0.11), 0.0)
			var g: float = float(ground_y.call(sp.x, sp.z))
			var foot: float = g - 0.7 if sp.y - g < 2.5 else sp.y - 0.55
			_log(pk, kit, Vector3(sp.x, foot, sp.z), sp + (fr[i][2] as Vector3) * 1.62 - rv * (sx * 0.1), 0.1, 0.085, 6, true, 2, 0.1, 0)
		# A bent under the stringers.
		var p0: Vector3 = at.call(i, 0.0, 0.0)
		var gmid: float = float(ground_y.call(p0.x, p0.z))
		if p0.y - gmid <= 0.5:
			continue
		var feet: Array = []
		for sx in [-1.0, 1.0]:
			var tp: Vector3 = at.call(i, sx * hw * 0.6, -0.64)
			var g: float = float(ground_y.call(tp.x, tp.z))
			var by: float = maxf(g - 0.8, tp.y - 14.0)
			if tp.y - by < 0.3:
				continue
			_pipe(pk, kit, "hinoki", [Vector3(tp.x, by, tp.z), tp], [0.2, 0.17], 6, BARK.lightened(0.1), 0, fr[i][0], BARK_DARK.lightened(0.08))
			feet.append([tp, maxf(g, by)])
		if feet.size() == 2:
			var ta: Vector3 = feet[0][0]
			var tb: Vector3 = feet[1][0]
			var hgt: float = minf(ta.y - float(feet[0][1]), tb.y - float(feet[1][1]))
			if hgt > 2.5:
				var dz: Vector3 = (fr[i][0] as Vector3) * 0.2
				_bar(pk, kit, "hinoki", ta - Vector3(0, 0.3, 0) + dz, Vector3(tb.x, tb.y - hgt + 0.3, tb.z) + dz, 0.1, 0.18, AGED_DARK.lightened(0.1), fr[i][0])
				_bar(pk, kit, "hinoki", tb - Vector3(0, 0.3, 0) - dz, Vector3(ta.x, ta.y - hgt + 0.3, ta.z) - dz, 0.1, 0.18, AGED_DARK.lightened(0.1), fr[i][0])


# ======================================================================================
#  Part B: the mill race (game metres)
# ======================================================================================

## The sawmill's own flume in its life-size frame: [the trough's middle x, its inside half width, its floor's top y, the
## back end's z (where a longer flume carries on), the lip's z (over the wheel)], for a stage that brings the water in.
static func sawmill_flume() -> Array:
	var fy: float = MILL_AXLE.y + MILL_WHEEL_R + 0.07 + 0.2
	return [1.3, 0.27, fy + 0.045, -9.0, MILL_AXLE.z + 0.45]


## A raised wooden flume (kakehi) along the world points `pts` (the trough floor's top on its middle line, the water
## running toward the last point): the sawmill's trough at game size (inside `iw` wide, walls `wh` high, boarded), cleats
## across its top, and every `bay` metres a trestle from `ground_y.call(x, z)` up under it: two splayed legs on stone pads, a
## cap, X braces and long ledgers where it stands tall, a sleeper where it lies on the ground. Its ends are open.
static func flume(pk: PropKit, kit: Dictionary, pts: PackedVector3Array, ground_y: Callable, iw := 0.86, wh := 0.58, bay := 3.6) -> void:
	var n := pts.size()
	if n < 2:
		return
	var wt := 0.08
	var ft := 0.08
	var board := CEDAR.lightened(0.12)
	var tim := AGED
	var hw: float = iw * 0.5
	for i in n - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var r := d.cross(Vector3.UP).normalized()
		var up := Vector3.UP
		# The floor: its top inside the walls, its underside across them.
		_planks(pk, kit, "sugi", [a - r * hw + up * 0.0, b - r * hw, b + r * hw, a + r * hw], Vector3.UP, board.darkened(0.35))
		_planks(pk, kit, "sugi", [a + r * (hw + wt) - up * ft, b + r * (hw + wt) - up * ft, b - r * (hw + wt) - up * ft, a - r * (hw + wt) - up * ft], Vector3.DOWN, board.darkened(0.3))
		for sx in [-1.0, 1.0]:
			var ri: Vector3 = r * (sx * hw)
			var ro: Vector3 = r * (sx * (hw + wt))
			var out: Vector3 = r * sx
			# Outside and inside faces of the wall, its top edge.
			_planks(pk, kit, "sugi", [a + ro - up * ft, b + ro - up * ft, b + ro + up * wh, a + ro + up * wh], out, board)
			_planks(pk, kit, "sugi", [a + ri, b + ri, b + ri + up * wh, a + ri + up * wh], -out, board.darkened(0.25))
			pk.quad(kit, "wood", [a + ri + up * wh, b + ri + up * wh, b + ro + up * wh, a + ro + up * wh], Vector3.UP, board)
		# A cleat across the top every 1.8m.
		var seg_len: float = Vector2(b.x - a.x, b.z - a.z).length()
		var t := 0.9
		while t < seg_len:
			var c: Vector3 = a.lerp(b, t / seg_len) + up * (wh + 0.05)
			_bar(pk, kit, "hinoki", c - r * (hw + wt + 0.14), c + r * (hw + wt + 0.14), 0.11, 0.08, tim, d)
			t += 1.8
	# The trestles, every `bay` along its length.
	var total := 0.0
	var lens := PackedFloat32Array([0.0])
	for i in n - 1:
		total += Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
		lens.append(total)
	var prev_mid: Array = []
	var k := 0
	var s := 0.6
	while s <= total - 0.4:
		var j := 0
		while j < n - 2 and lens[j + 1] < s:
			j += 1
		var u: float = (s - lens[j]) / maxf(lens[j + 1] - lens[j], 0.001)
		var p: Vector3 = pts[j].lerp(pts[j + 1], u)
		var d := Vector3(pts[j + 1].x - pts[j].x, 0.0, pts[j + 1].z - pts[j].z).normalized()
		var r := d.cross(Vector3.UP).normalized()
		var cap_y: float = p.y - ft - 0.12
		var g_mid: float = float(ground_y.call(p.x, p.z))
		if cap_y - g_mid < 0.5:
			# On the ground: a sleeper log under it.
			_log(pk, kit, Vector3(p.x, cap_y - 0.06, p.z) - r * (hw + 0.5), Vector3(p.x, cap_y - 0.06, p.z) + r * (hw + 0.5), 0.13, 0.12, 6, true, 3, 0.1, 0, d)
			prev_mid = []
			s += bay
			k += 1
			continue
		_bar(pk, kit, "hinoki", Vector3(p.x, cap_y, p.z) - r * (hw + 0.45), Vector3(p.x, cap_y, p.z) + r * (hw + 0.45), 0.2, 0.22, tim, d)
		var legs: Array = []
		for sx in [-1.0, 1.0]:
			var top: Vector3 = Vector3(p.x, cap_y - 0.1, p.z) + r * (sx * (hw + 0.25))
			var h_est: float = top.y - g_mid
			var foot_xz: Vector3 = top + r * (sx * (0.35 + h_est * 0.09))
			var g: float = float(ground_y.call(foot_xz.x, foot_xz.z))
			var foot := Vector3(foot_xz.x, g - 0.15, foot_xz.z)
			_bar(pk, kit, "hinoki", foot, top, 0.2, 0.2, tim.darkened(0.06), d, false)
			pk.block(kit, "ishi", Vector3(foot.x - 0.3, g - 0.35, foot.z - 0.3), Vector3(foot.x + 0.3, g + 0.12, foot.z + 0.3), GRANITE_MOSSY, uvk)
			legs.append([foot, top])
		var hgt: float = cap_y - g_mid
		if hgt > 2.2:
			# X braces across the bent, a little in front of and behind the legs.
			var la: Array = legs[0]
			var lb: Array = legs[1]
			var lo := 0.25
			var hi := 0.85
			var dz: Vector3 = d * 0.13
			_bar(pk, kit, "hinoki", (la[0] as Vector3).lerp(la[1], lo) + dz, (lb[0] as Vector3).lerp(lb[1], hi) + dz, 0.08, 0.16, AGED_DARK.lightened(0.1), d)
			_bar(pk, kit, "hinoki", (lb[0] as Vector3).lerp(lb[1], lo) - dz, (la[0] as Vector3).lerp(la[1], hi) - dz, 0.08, 0.16, AGED_DARK.lightened(0.1), d)
			if hgt > 4.5:
				_bar(pk, kit, "hinoki", (la[0] as Vector3).lerp(la[1], 0.5), (lb[0] as Vector3).lerp(lb[1], 0.5), 0.14, 0.16, tim, d)
		# Ledgers to the last bent along each side where it stands tall.
		var mids: Array = []
		for l in legs:
			mids.append((l[0] as Vector3).lerp(l[1], 0.55))
		if hgt > 3.0 and prev_mid.size() == 2:
			for q in 2:
				_bar(pk, kit, "hinoki", prev_mid[q], mids[q], 0.12, 0.14, tim.darkened(0.04), r)
		prev_mid = mids if hgt > 3.0 else []
		s += bay
		k += 1


## A culvert's stone headwall across a channel (game metres; the frame's origin on the channel's middle at its bed, +z out of
## the culvert, x across): a wall `w` wide rising `h` over the bed, a squared opening `ow` wide and `oh` high under a
## lintel, a dark barrel `depth` deep behind it, a coping on top.
static func culvert_head(pk: PropKit, kit: Dictionary, w := 4.4, h := 2.2, ow := 1.6, oh := 1.2, depth := 4.0) -> void:
	var col := GRANITE_MOSSY
	var t := 0.7
	var hw: float = w * 0.5
	var ho: float = ow * 0.5
	for sx in [-1.0, 1.0]:
		var x0: float = sx * ho
		var x1: float = sx * hw
		pk.block(kit, "ishi", Vector3(minf(x0, x1), -0.6, -t), Vector3(maxf(x0, x1), h, 0.0), col.lightened(0.03 * sx), uvk)
	# The lintel and the wall over it.
	pk.block(kit, "ishi", Vector3(-ho - 0.25, oh, -t - 0.02), Vector3(ho + 0.25, oh + 0.38, 0.06), GRANITE, uvk)
	if h > oh + 0.38:
		pk.block(kit, "ishi", Vector3(-ho, oh + 0.38, -t), Vector3(ho, h, 0.0), col, uvk)
	# The coping, proud of the wall.
	pk.block(kit, "ishi", Vector3(-hw - 0.08, h, -t - 0.1), Vector3(hw + 0.08, h + 0.22, 0.12), GRANITE.darkened(0.05), uvk)
	# The barrel: dark inside faces.
	var dark := Color(0.07, 0.07, 0.06)
	var z0 := -0.02
	var z1: float = -depth
	pk.quad(kit, "ishi", [Vector3(-ho, -0.3, z0), Vector3(-ho, -0.3, z1), Vector3(-ho, oh, z1), Vector3(-ho, oh, z0)], Vector3.RIGHT, dark)
	pk.quad(kit, "ishi", [Vector3(ho, -0.3, z1), Vector3(ho, -0.3, z0), Vector3(ho, oh, z0), Vector3(ho, oh, z1)], Vector3.LEFT, dark)
	pk.quad(kit, "ishi", [Vector3(-ho, oh, z0), Vector3(-ho, oh, z1), Vector3(ho, oh, z1), Vector3(ho, oh, z0)], Vector3.DOWN, dark)
	pk.quad(kit, "ishi", [Vector3(-ho, -0.3, z1), Vector3(ho, -0.3, z1), Vector3(ho, oh, z1), Vector3(-ho, oh, z1)], Vector3.BACK, Color(0.02, 0.02, 0.02))
	# Stones on the bed in front of it.
	for k in 5:
		var fx: float = (float(k) - 2.0) * ow * 0.32
		_stone(pk, kit, Vector3(fx, -0.25, 0.5 + 0.35 * float(k % 2)), 0.22 + 0.05 * float(k % 3), GRANITE_MOSSY.darkened(0.1 * float(k % 2)))


## A mill pond's sluice (game metres; the frame's origin on the flume's floor at its mouth, +z downstream, x across): two
## grooved posts either side of the trough, a beam across them, the gate board drawn up on its rack and a stone sill.
static func sluice(pk: PropKit, kit: Dictionary, iw := 0.86, wh := 0.58) -> void:
	var tim := AGED
	var hw: float = iw * 0.5
	var top: float = wh + 1.5
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hw + 0.2)
		_bar(pk, kit, "hinoki", Vector3(x, -1.2, 0.0), Vector3(x, top, 0.0), 0.24, 0.24, tim.darkened(0.05), Vector3.RIGHT, true)
	_bar(pk, kit, "hinoki", Vector3(-hw - 0.45, top - 0.12, 0.0), Vector3(hw + 0.45, top - 0.12, 0.0), 0.22, 0.24, tim, Vector3.BACK)
	# The gate board, raised: the water runs under it.
	pk.block(kit, "hinoki", Vector3(-hw - 0.02, wh * 0.55, -0.05), Vector3(hw + 0.02, wh + 0.75, 0.05), AGED_DARK, uvk)
	# Its rack: a toothed stem up through the beam, a wheel on a spindle.
	_bar(pk, kit, "hinoki", Vector3(0.0, wh + 0.7, 0.0), Vector3(0.0, top + 0.35, 0.0), 0.12, 0.12, tim.lightened(0.05), Vector3.RIGHT)
	pk.block(kit, "steel", Vector3(-0.09, top - 0.02, -0.15), Vector3(0.09, top + 0.12, 0.15), IRON)
	pk.lathe(kit, "metal", Vector3(0.0, top + 0.08, 0.2), [Vector2(0.28, -0.03), Vector2(0.28, 0.03), Vector2(0.0, 0.03)], 10, IRON.lightened(0.1), false, Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)))
	pk.block(kit, "ishi", Vector3(-hw - 0.6, -0.5, -0.4), Vector3(hw + 0.6, -0.06, 0.4), GRANITE_MOSSY, uvk)


## A mooring post (life size, its foot at the origin): a peeled log driven into the bank, `h` standing, a few turns of rope.
static func mooring_post(pk: PropKit, kit: Dictionary, h := 1.5) -> void:
	_log(pk, kit, Vector3(0, -0.9, 0), Vector3(0, h, 0), 0.12, 0.1, 7, false, 2, 0.1, 0, Vector3.RIGHT)
	_lash(pk, kit, Vector3(0, h - 0.35, 0), Vector3.UP, 0.135, 0.16, ROPE)


## A rope between two life-size points (a mooring line), sagging `sag` in its middle.
static func mooring_rope(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, sag := 0.35) -> void:
	var pts: Array = []
	for k in 9:
		var t: float = float(k) / 8.0
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	_pipe(pk, kit, "rope", pts, 0.028, 5, ROPE, 0)


# ======================================================================================
#  Corridor checks
# ======================================================================================

static func _tris_of(src) -> PackedVector3Array:
	if src is Dictionary:
		return PropKit.kit_triangles(src)
	var out := PackedVector3Array()
	var mesh := src as Mesh
	if mesh != null:
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null or (idx as PackedInt32Array).is_empty():
				out.append_array(v)
			else:
				for i in (idx as PackedInt32Array):
					out.append(v[i])
	return out


static func _samples(a: Vector3, b: Vector3, c: Vector3) -> Array:
	var m: int = clampi(int(ceil(maxf((b - a).length(), maxf((c - b).length(), (a - c).length())) / 0.6)), 2, 14)
	var out: Array = []
	for i in m + 1:
		for j in m + 1 - i:
			var u: float = float(i) / float(m)
			var v: float = float(j) / float(m)
			out.append(a * (1.0 - u - v) + b * u + c * v)
	return out


## Counts the triangles of a bridge's kit (before commit) or mesh that reach into the road's corridor: |x| < hw from 2cm
## under the deck surface to `head` (12m) over it, the deck carried on level past both ends. 0 is right.
static func check_corridor(src, span: float, hw: float, deck_y: Callable, head := 12.0) -> int:
	var tris := _tris_of(src)
	corridor_notes = PackedStringArray()
	var bad := 0
	for i in range(0, tris.size(), 3):
		var a: Vector3 = tris[i]
		var b: Vector3 = tris[i + 1]
		var c: Vector3 = tris[i + 2]
		if minf(absf(a.x), minf(absf(b.x), absf(c.x))) >= hw and a.x * b.x > 0.0 and a.x * c.x > 0.0:
			continue
		for p in _samples(a, b, c):
			if absf(p.x) >= hw - 0.005:
				continue
			var d: float = _dy(deck_y, span, -p.z)
			if p.y > d - 0.02 + 0.002 and p.y < d + head - 0.002:
				bad += 1
				if corridor_notes.size() < 12:
					corridor_notes.append("(%.2f, %.2f, %.2f) deck %.2f" % [p.x, p.y, p.z, d])
				break
	return bad


## The same along a path (ledge_walk, timber_chute): within hw of the middle, from 2cm under the deck to `head` over it.
static func check_path_corridor(src, pts: PackedVector3Array, rights: PackedVector3Array, hw: float, head := 12.0) -> int:
	var tris := _tris_of(src)
	corridor_notes = PackedStringArray()
	var fr: Array = _path_frames(pts, rights)
	var n := pts.size()
	var bad := 0
	for i in range(0, tris.size(), 3):
		var a: Vector3 = tris[i]
		var b: Vector3 = tris[i + 1]
		var c: Vector3 = tris[i + 2]
		var cen: Vector3 = (a + b + c) / 3.0
		var best := 0
		var bd := INF
		for k in n - 1:
			var dd: float = Geometry3D.get_closest_point_to_segment(cen, pts[k], pts[k + 1]).distance_squared_to(cen)
			if dd < bd:
				bd = dd
				best = k
		if bd > (hw + head + 4.0) * (hw + head + 4.0):
			continue
		var hit := false
		for p in _samples(a, b, c):
			for k in range(maxi(0, best - 1), mini(n - 1, best + 2)):
				var seg: Vector3 = pts[k + 1] - pts[k]
				var u: float = (p - pts[k]).dot(seg) / maxf(seg.length_squared(), 1e-6)
				if u < 0.0 or u > 1.0:
					continue
				var o: Vector3 = pts[k] + seg * u
				var rv: Vector3 = ((fr[k][1] as Vector3).lerp(fr[k + 1][1], u)).normalized()
				var up: Vector3 = ((fr[k][2] as Vector3).lerp(fr[k + 1][2], u)).normalized()
				var lat: float = (p - o).dot(rv)
				var h: float = (p - o).dot(up)
				if absf(lat) < hw - 0.005 and h > -0.02 + 0.002 and h < head:
					hit = true
					if corridor_notes.size() < 12:
						corridor_notes.append("%s lateral %.2f height %.3f" % [p.snappedf(0.01), lat, h])
					break
			if hit:
				break
		if hit:
			bad += 1
	return bad
