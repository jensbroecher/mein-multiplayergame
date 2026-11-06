extends RefCounted
## Zeche Kronprinz (Kronburg GP, stage 3): the closed colliery's buildings and its heritage dressing. Schacht I's Malakoff
## tower, Schacht II's steel Doppelbock headframe with its shaft hall and separate sheave wheels, the winding engine houses,
## the Lohnhalle with the Kaue (pay hall and wash house, one long building with a clock tower), the coal washer the lap
## drives under, enclosed conveyor galleries on lattice trestles, the concrete loading bunker over the colliery railway,
## mine carts on a 600mm display line, the Kronprinzenblick landmark on the spoil heap's summit, fences, floodlight masts,
## heritage boards, skips, cable drums, and the brownfield plants (buddleia, goldenrod) as MultiMesh meshes. Fictional
## throughout: Zeche Kronprinz, Schacht I and II, founded 1871, closed 1986.
##
## Everything is built at LIFE size through a PropKit in its own frame (y = 0 the ground, footings down to y = -3 or so,
## the front toward +z unless a builder says otherwise) and grown by the caller (PROP_SCALE 1.6). UVs are in metres times
## `uvk` (the caller's scale) where a shader reads them (brick, ashlar, concrete, slate, corrugated iron), in life metres on
## glazing (steel_glazing draws its panes) and on the fence's chain link. Labels are [text, position, outward normal, cap
## height, colour, board width] in life-size kit coordinates.
##
## Material keys (make_material): SteelworksKit's "brick" (ruhr_brick), "glass" (steel_glazing, the outer face only),
## "rusty", "corten", "grime", "shell", "roofing", "heap" (industrial_paint), "hazard", "lamp" (lit), "lens" (unlit lamp);
## KronburgTownKit's "ashlar" (sandstone), "kslate" (slate), "gold", "enamel", "pane"; YardKit's "concrete", "iron"
## (corrugated, ribs along v), "timber", "painted", "stone"; CampKit's vertex-colour "steel", "metal", "matte", "paint",
## "rubber", "wood"; and this kit's own: "coal" (glossy black lumps), "zplant" (zeche_plant.gdshader: two-sided leaves and
## flower spikes, swaying) and "zfence" (zeche_fence.gdshader: rusty chain link, two-sided, discarded between the wires).
##
## Faces never share a plane: trims, bands, tablets and frames stand 2.5cm or more proud of what is behind them and parts
## that meet overlap or step. Godot's front faces wind clockwise: PropKit.tri winds every triangle for the `out` it's given.

const PropKit = preload("res://PropKit.gd")
const SW = preload("res://SteelworksKit.gd")
const KT = preload("res://KronburgTownKit.gd")
const YK = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")

static var uvk := 1.6
static var _mats := {}

const SW_KEYS := ["hot", "glass", "skylight", "rusty", "corten", "grime", "floor", "shell", "roofing", "hazard", "lamp", "lens", "heap", "brick"]
const KT_KEYS := ["biber", "ashlar", "kslate", "kbrick", "pane", "gold", "enamel", "leaf", "kwater", "hedge"]
const TANGENT_KEYS := ["iron", "concrete", "slate", "kslate", "biber", "tile", "zinc"]

const WHITE := Color(1, 1, 1)
const BRICK := Color(0.47, 0.22, 0.15)
const BRICK_DARK := Color(0.33, 0.15, 0.11)
const SAND := Color(0.80, 0.73, 0.60)
const SAND_DARK := Color(0.66, 0.59, 0.47)
const CARVED := Color(0.22, 0.17, 0.12)
const SLATE := Color(0.30, 0.31, 0.35)
const CONC := Color(0.66, 0.65, 0.61)
const CONC_DARK := Color(0.52, 0.51, 0.48)
const GREEN_GREY := Color(0.29, 0.37, 0.33)
const RUST_RED := Color(0.47, 0.21, 0.14)
const STEEL_DARK := Color(0.15, 0.16, 0.16)
const CLAD := Color(0.47, 0.51, 0.48)
const CLAD_BROWN := Color(0.46, 0.33, 0.25)
const DOOR_GREEN := Color(0.15, 0.29, 0.23)
const BLACK := Color(0.02, 0.02, 0.02)
const CREAM := Color(0.92, 0.89, 0.80)
const SIGN_YELLOW := Color(0.98, 0.80, 0.10)

const UP := Vector3.UP
## The display line's rail top over its ground (narrow_gauge), where a mine cart's frame (y = 0 its wheels' treads) goes.
const NG_RAIL_TOP := 0.227
## The display line's rails' centres either side of its middle (600mm gauge between the heads' inner edges).
const NG_HALF := 0.318


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"zplant":
			var p := ShaderMaterial.new()
			p.shader = load("res://zeche_plant.gdshader")
			return p
		"zfence":
			var f := ShaderMaterial.new()
			f.shader = load("res://zeche_fence.gdshader")
			return f
		"coal":
			var c := StandardMaterial3D.new()
			c.vertex_color_use_as_albedo = true
			c.vertex_color_is_srgb = true
			c.roughness = 0.62
			c.metallic = 0.0
			c.metallic_specular = 0.55
			return c
	if key in SW_KEYS:
		return SW.make_material(key)
	if key in KT_KEYS:
		return KT.make_material(key)
	return YK.make_material(key)


## A kit growing everything by `scale`, its materials shared with every other kit made here.
static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	SW.uvk = scale
	YK.uvk = scale
	SW._lx = Transform3D.IDENTITY
	return pk


## The materials made so far, by key (the generator saves them so every mesh shares one per key).
static func materials() -> Dictionary:
	return _mats


## Commits a kit with tangents on the surfaces whose shaders read a normal map, each surface named after its key.
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in TANGENT_KEYS:
		if kit.has(key):
			var s: SurfaceTool = kit[key]
			s.index()
			s.generate_tangents()
	var mesh := ArrayMesh.new()
	var keys: Array = kit.keys()
	keys.sort()
	for key in keys:
		var st: SurfaceTool = kit[key]
		st.index()
		var before := mesh.get_surface_count()
		st.commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(before, pk.material_for.call(key))
			mesh.surface_set_name(before, key)
	return mesh


# ======================================================================================
#  Helpers
# ======================================================================================

static func _push(pk: PropKit, t: Transform3D) -> Array:
	return SW._push(pk, t)


static func _pop(pk: PropKit, saved: Array) -> void:
	SW._pop(pk, saved)


static func _lbl(labels: Array, text: String, p: Vector3, n: Vector3, cap: float, col: Color, w := 0.0) -> void:
	SW._label(labels, text, p, n, cap, col, w)


## A wall's frame: x along it, y up, z out of it, at p0 (its foot at u = 0).
static func _wf(p0: Vector3, along: Vector3, out: Vector3) -> Transform3D:
	return Transform3D(Basis(along, UP, out), p0)


## A box centred at `c` turned by `basis`, UVs in metres.
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## A beam's four long sides from a to b (no end caps: lattice members whose ends meet other members), `w` wide along
## `side` (or any horizontal), `t` thick.
static func _bar(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, t: float, col: Color, side := Vector3.ZERO) -> void:
	var ax := b - a
	var length := ax.length()
	if length < 1e-4:
		return
	var z := ax / length
	var x := side
	if x.length_squared() < 1e-8 or absf(x.normalized().dot(z)) > 0.99:
		x = UP.cross(z)
		if x.length_squared() < 1e-6:
			x = Vector3.RIGHT
	x = (x - z * x.dot(z)).normalized()
	var y := z.cross(x).normalized()
	var hx: Vector3 = x * (w * 0.5)
	var hy: Vector3 = y * (t * 0.5)
	var c: Array = [-hx - hy, hx - hy, hx + hy, -hx + hy]
	var ns: Array = [-y, x, y, -x]
	for k in range(4):
		var p: Vector3 = c[k]
		var q: Vector3 = c[(k + 1) % 4]
		pk.quad(kit, key, [a + p, a + q, b + q, b + p], ns[k], col)


## A masonry quad facing `out` (u along, v up, UVs in metres from p0).
static func _mq(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v0: float, v1: float, col: Color) -> void:
	if u1 - u0 < 1e-4 or v1 - v0 < 1e-4:
		return
	pk.quad(kit, key, [p0 + along * u0 + UP * v0, p0 + along * u1 + UP * v0, p0 + along * u1 + UP * v1, p0 + along * u0 + UP * v1], out, col,
			[Vector2(u0, v0) * uvk, Vector2(u1, v0) * uvk, Vector2(u1, v1) * uvk, Vector2(u0, v1) * uvk])


## An axis-aligned block with masonry UVs: its four sides as walls (u along each, v up), its top (and bottom) in plan.
static func _mblock(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color, top := true, bottom := false) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var dx: float = hi.x - lo.x
	var dz: float = hi.z - lo.z
	_mq(pk, kit, key, Vector3(lo.x, 0, hi.z), Vector3.RIGHT, Vector3.BACK, 0.0, dx, lo.y, hi.y, col)
	_mq(pk, kit, key, Vector3(hi.x, 0, lo.z), Vector3.LEFT, Vector3.FORWARD, 0.0, dx, lo.y, hi.y, col)
	_mq(pk, kit, key, Vector3(hi.x, 0, hi.z), Vector3.FORWARD, Vector3.RIGHT, 0.0, dz, lo.y, hi.y, col)
	_mq(pk, kit, key, Vector3(lo.x, 0, lo.z), Vector3.BACK, Vector3.LEFT, 0.0, dz, lo.y, hi.y, col)
	if top:
		pk.quad(kit, key, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], UP, col,
				[Vector2(lo.x, lo.z) * uvk, Vector2(hi.x, lo.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(lo.x, hi.z) * uvk])
	if bottom:
		pk.quad(kit, key, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)], Vector3.DOWN, col.darkened(0.2),
				[Vector2(lo.x, lo.z) * uvk, Vector2(lo.x, hi.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(hi.x, lo.z) * uvk])


## The four outer faces of the rectangle round `c` (half sizes hx, hz) grown by d, from y0 to y1, masonry UVs.
static func _ring_sides(pk: PropKit, kit: Dictionary, key: String, c: Vector3, hx: float, hz: float, d: float, y0: float, y1: float, col: Color) -> void:
	var X: float = hx + d
	var Z: float = hz + d
	_mq(pk, kit, key, c + Vector3(-X, 0, Z), Vector3.RIGHT, Vector3.BACK, 0.0, X * 2.0, y0, y1, col)
	_mq(pk, kit, key, c + Vector3(X, 0, -Z), Vector3.LEFT, Vector3.FORWARD, 0.0, X * 2.0, y0, y1, col)
	_mq(pk, kit, key, c + Vector3(X, 0, Z), Vector3.FORWARD, Vector3.RIGHT, 0.0, Z * 2.0, y0, y1, col)
	_mq(pk, kit, key, c + Vector3(-X, 0, -Z), Vector3.BACK, Vector3.LEFT, 0.0, Z * 2.0, y0, y1, col)


## A flat ring between the rectangle round `c` grown by d0 and grown by d1, at y, facing up (or down).
static func _ring_flat(pk: PropKit, kit: Dictionary, key: String, c: Vector3, hx: float, hz: float, d0: float, d1: float, y: float, up: bool, col: Color) -> void:
	var n: Vector3 = UP if up else Vector3.DOWN
	var i: Array = [Vector2(-hx - d0, -hz - d0), Vector2(hx + d0, -hz - d0), Vector2(hx + d0, hz + d0), Vector2(-hx - d0, hz + d0)]
	var o: Array = [Vector2(-hx - d1, -hz - d1), Vector2(hx + d1, -hz - d1), Vector2(hx + d1, hz + d1), Vector2(-hx - d1, hz + d1)]
	for k in range(4):
		var a: Vector2 = i[k]
		var b: Vector2 = i[(k + 1) % 4]
		var cc: Vector2 = o[(k + 1) % 4]
		var dd: Vector2 = o[k]
		pk.quad(kit, key, [c + Vector3(a.x, y, a.y), c + Vector3(b.x, y, b.y), c + Vector3(cc.x, y, cc.y), c + Vector3(dd.x, y, dd.y)], n, col,
				[Vector2(a.x, a.y) * uvk, Vector2(b.x, b.y) * uvk, Vector2(cc.x, cc.y) * uvk, Vector2(dd.x, dd.y) * uvk])


## A stepped cornice (or a band) round a rectangular block: `steps` are Vector2(proud, height) from y0 up; each step's face,
## the underside where it stands out further than the one below, the ledge where the next steps back, and the top (from
## `inset` behind the wall face out to the last step).
static func _cornice(pk: PropKit, kit: Dictionary, key: String, c: Vector3, hx: float, hz: float, y0: float, steps: Array, col: Color, inset := 0.3,
		top := true) -> void:
	var y: float = y0
	var prev := 0.0
	for k in range(steps.size()):
		var s: Vector2 = steps[k]
		if s.x > prev:
			_ring_flat(pk, kit, key, c, hx, hz, prev, s.x, y, false, col.darkened(0.25))
		elif s.x < prev:
			_ring_flat(pk, kit, key, c, hx, hz, s.x, prev, y, true, col)
		_ring_sides(pk, kit, key, c, hx, hz, s.x, y, y + s.y, col)
		y += s.y
		prev = s.x
	if top:
		_ring_flat(pk, kit, key, c, hx, hz, -inset, prev, y, true, col.lightened(0.04))


## A straight band of stone (or brick) along a wall: [u0, u1] x [v0, v1] standing d proud, with its top, underside and ends.
static func _band(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v0: float, v1: float, d: float,
		col: Color, back := 0.05) -> void:
	var wf := _wf(p0, along, out)
	KT._prism(pk, kit, key, wf, PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]), -back, d, col, Vector2(0, 1))


## A wall [u0, u1] x [v0, v1] in the plane through p0 (u along `along`, v up), facing `out`, with rectangular holes
## ([Rect2(u, v, w, h), reveal?]): its face (and, with `inner`, the face `thick` behind), and each hole's reveals through
## the depth (jambs, sill and head) unless reveal is false.
static func _wall(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v0: float, v1: float,
		holes: Array, col: Color, thick := 0.5, inner := false) -> void:
	var us: Array = [u0, u1]
	var vs: Array = [v0, v1]
	for h in holes:
		var r: Rect2 = h[0]
		us.append_array([r.position.x, r.end.x])
		vs.append_array([r.position.y, r.end.y])
	us = SW._cuts(us, u0, u1)
	vs = SW._cuts(vs, v0, v1)
	var icol: Color = col.darkened(0.12)
	for b in range(vs.size() - 1):
		var va: float = vs[b]
		var vb: float = vs[b + 1]
		var vm: float = (va + vb) * 0.5
		var a := 0
		while a < us.size() - 1:
			if SW._in_hole(holes, (float(us[a]) + float(us[a + 1])) * 0.5, vm):
				a += 1
				continue
			var e := a + 1
			while e < us.size() - 1 and not SW._in_hole(holes, (float(us[e]) + float(us[e + 1])) * 0.5, vm):
				e += 1
			_mq(pk, kit, key, p0, along, out, us[a], us[e], va, vb, col)
			if inner:
				_mq(pk, kit, key, p0 - out * thick, along, -out, us[a], us[e], va, vb, icol)
			a = e
	if thick <= 0.0:
		return
	var back: Vector3 = -out * thick
	for h in holes:
		if h.size() > 1 and not h[1]:
			continue
		var r: Rect2 = h[0]
		for side in [0, 1]:
			var u: float = r.position.x if side == 0 else r.end.x
			var n: Vector3 = along if side == 0 else -along
			var pa: Vector3 = p0 + along * u + UP * r.position.y
			var pb: Vector3 = p0 + along * u + UP * r.end.y
			pk.quad(kit, key, [pa, pb, pb + back, pa + back], n, col.darkened(0.1),
					[Vector2(0, r.position.y) * uvk, Vector2(0, r.end.y) * uvk, Vector2(thick, r.end.y) * uvk, Vector2(thick, r.position.y) * uvk])
		for side in [0, 1]:
			var v: float = r.position.y if side == 0 else r.end.y
			if (side == 0 and v <= v0 + 0.001) or (side == 1 and v >= v1 - 0.001):
				continue
			var n2: Vector3 = UP if side == 0 else Vector3.DOWN
			var qa: Vector3 = p0 + along * r.position.x + UP * v
			var qb: Vector3 = p0 + along * r.end.x + UP * v
			pk.quad(kit, key, [qa, qb, qb + back, qa + back], n2, col.darkened(0.18),
					[Vector2(r.position.x, 0) * uvk, Vector2(r.end.x, 0) * uvk, Vector2(r.end.x, thick) * uvk, Vector2(r.position.x, thick) * uvk])


## A polygon of wall (u, v) in the plane through p0 facing `out`, UVs in metres (a gable).
static func _wpoly(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, poly: PackedVector2Array, col: Color) -> void:
	KT._pface(pk, kit, key, _wf(p0, along, out), poly, 0.0, col)


## A pane of steel glazing facing `out` centred at c (w along, h up), UVs in life metres (the shader draws the panes).
static func _glass(pk: PropKit, kit: Dictionary, c: Vector3, along: Vector3, out: Vector3, w: float, h: float, up := UP) -> void:
	var hu: Vector3 = along * (w * 0.5)
	var hv: Vector3 = up * (h * 0.5)
	pk.quad(kit, "glass", [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv], out, WHITE, [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])


## The rectangle a wall leaves for an arched opening: Rect2(cu - half, v0, 2 half, hs + rise).
static func _arch_hole(cu: float, v0: float, half: float, hs: float, rise: float) -> Array:
	return [Rect2(cu - half, v0, half * 2.0, hs + rise), true]


## An arched opening in a wall that `_wall` cut with `_arch_hole(cu, v0, half, hs, rise)`: the spandrels over the arch
## (and their inner face with "inner"), the arch's soffit through the wall's depth, and by the options in `o`:
##   "segs" (10, even) the arch's facets; "trim" a key for the ring of voussoirs standing 5cm proud ("" none), "trim_col",
##   "trim_w" (0.35); "keystone" (false); "glass" (true: steel glazing 16cm in, a transom at the springing and a mullion);
##   "door" (a colour: a door leaf below the springing, glass above); "dark" (a black panel deep in, no glass); "sill"
##   (true: a stone sill), "sill_key" ("ashlar"), "sill_col"; "inner" (false).
## A round arch when rise == half, else segmental.
static func _arch_open(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, cu: float, v0: float, half: float, hs: float,
		rise: float, thick: float, col: Color, o := {}) -> void:
	var segs: int = o.get("segs", 10)
	var spring: float = v0 + hs
	var top: float = spring + rise
	var kind := "round" if absf(rise - half) < 0.01 else "seg"
	var rr: float = (half * half + rise * rise) / (2.0 * maxf(rise, 0.01))
	var ctr := Vector2(cu, spring + rise - rr)
	var arc: PackedVector2Array = KT._arch(cu, spring, half, kind, segs, rise)
	var wf := _wf(p0, along, out)
	var mid: int = segs / 2
	var depths: Array = [0.0]
	if o.get("inner", false):
		depths.append(-thick)
	for d in depths:
		var n: Vector3 = out if d == 0.0 else -out
		var c: Color = col if d == 0.0 else col.darkened(0.12)
		for k in range(segs):
			var corner := Vector2(cu - half, top) if k < mid else Vector2(cu + half, top)
			var a0: Vector2 = arc[k]
			var a1: Vector2 = arc[k + 1]
			pk.tri(kit, key, wf * Vector3(corner.x, corner.y, d), wf * Vector3(a0.x, a0.y, d), wf * Vector3(a1.x, a1.y, d), n, n, n, c, n,
					corner * uvk, a0 * uvk, a1 * uvk)
	var run := 0.0
	for k in range(segs):
		var a0: Vector2 = arc[k]
		var a1: Vector2 = arc[k + 1]
		var am: Vector2 = (a0 + a1) * 0.5 - ctr
		var inward: Vector3 = -(along * am.x + UP * am.y).normalized()
		var r1: float = run + a0.distance_to(a1)
		pk.quad(kit, key, [wf * Vector3(a0.x, a0.y, 0.0), wf * Vector3(a1.x, a1.y, 0.0), wf * Vector3(a1.x, a1.y, -thick), wf * Vector3(a0.x, a0.y, -thick)],
				inward, col.darkened(0.18), [Vector2(run, 0) * uvk, Vector2(r1, 0) * uvk, Vector2(r1, thick) * uvk, Vector2(run, thick) * uvk])
		run = r1
	var trim: String = o.get("trim", "")
	var tw: float = o.get("trim_w", 0.35)
	if trim != "":
		KT._arch_ring(pk, kit, trim, wf, cu, spring, half, kind, tw, 0.0, 0.05, o.get("trim_col", SAND), v0 if o.get("trim_foot", false) else NAN, segs, rise)
	if o.get("keystone", false):
		_box(pk, kit, o.get("trim", "ashlar") if trim != "" else "ashlar", wf * Vector3(cu, top + tw * 0.45, 0.04), Basis(along, UP, out),
				Vector3(minf(0.5, half * 0.5), tw + 0.3, 0.1), o.get("trim_col", SAND).lightened(0.05))
	var bas := Basis(along, UP, out)
	if o.get("dark", false):
		pk.quad(kit, "matte", [wf * Vector3(cu - half, v0, -thick + 0.04), wf * Vector3(cu + half, v0, -thick + 0.04), wf * Vector3(cu + half, top, -thick + 0.04),
				wf * Vector3(cu - half, top, -thick + 0.04)], out, BLACK)
	elif o.has("door"):
		var dcol: Color = o["door"]
		var gd: float = minf(0.3, thick * 0.6)
		_box(pk, kit, "paint", wf * Vector3(cu, (v0 + spring) * 0.5, -gd - 0.03), bas, Vector3(half * 2.0, spring - v0, 0.06), dcol)
		for sx in [-0.5, 0.5]:
			for py in [0.27, 0.72]:
				_box(pk, kit, "paint", wf * Vector3(cu + sx * half, lerpf(v0, spring, py), -gd + 0.015), bas, Vector3(half * 0.72, (spring - v0) * 0.32, 0.03),
						dcol.lightened(0.07))
		_box(pk, kit, "paint", wf * Vector3(cu, (v0 + spring) * 0.5, -gd + 0.02), bas, Vector3(0.06, spring - v0, 0.04), dcol.darkened(0.25))
		_glass(pk, kit, wf * Vector3(cu, (spring + top) * 0.5, -gd), along, out, half * 2.0, top - spring)
		_box(pk, kit, "steel", wf * Vector3(cu, spring + 0.04, -gd + 0.04), bas, Vector3(half * 2.0, 0.08, 0.06), STEEL_DARK)
	elif o.get("glass", true):
		var gd2 := 0.16
		_glass(pk, kit, wf * Vector3(cu, (v0 + top) * 0.5, -gd2), along, out, half * 2.0, top - v0)
		_box(pk, kit, "steel", wf * Vector3(cu, spring, -gd2 + 0.04), bas, Vector3(half * 2.0, 0.08, 0.06), STEEL_DARK)
		_box(pk, kit, "steel", wf * Vector3(cu, (v0 + spring) * 0.5, -gd2 + 0.05), bas, Vector3(0.08, spring - v0, 0.06), STEEL_DARK)
	if o.get("sill", true):
		_box(pk, kit, o.get("sill_key", "ashlar"), wf * Vector3(cu, v0 - 0.08, 0.12), bas, Vector3(half * 2.0 + 0.3, 0.16, 0.22), o.get("sill_col", SAND))


## A rectangular steel window in a hole `_wall` cut: glass `depth` in, a sill (stone or steel) and a lintel.
static func _rect_window(pk: PropKit, kit: Dictionary, p0: Vector3, along: Vector3, out: Vector3, cu: float, v0: float, w: float, h: float, depth := 0.15,
		sill_key := "concrete", sill_col := CONC) -> void:
	var wf := _wf(p0, along, out)
	var bas := Basis(along, UP, out)
	_glass(pk, kit, wf * Vector3(cu, v0 + h * 0.5, -depth), along, out, w, h)
	if sill_key != "":
		_box(pk, kit, sill_key, wf * Vector3(cu, v0 - 0.06, 0.12), bas, Vector3(w + 0.16, 0.12, 0.22), sill_col)


## A Rundbogenfries (a corbel table of little round arches) along a wall: the band [u0, u1] from v_top down `h`, its lower
## edge arches `pitch` apart hanging between little corbels, standing `d` proud.
static func _frieze(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v_top: float, h: float,
		pitch: float, d: float, col: Color) -> void:
	var n: int = maxi(int(round((u1 - u0) / pitch)), 1)
	var pw: float = (u1 - u0) / float(n)
	var cw: float = pw * 0.22
	var vb: float = v_top - h
	var r: float = (pw - cw) * 0.5
	var vs: float = vb + h * 0.18
	r = minf(r, v_top - vs - 0.12)
	var ol := PackedVector2Array()
	ol.append(Vector2(u0, v_top))
	ol.append(Vector2(u0, vb))
	for i in range(n):
		var ua: float = u0 + pw * float(i)
		ol.append(Vector2(ua + cw * 0.5, vb))
		ol.append(Vector2(ua + cw * 0.5, vs))
		var uc: float = ua + pw * 0.5
		for k in range(1, 6):
			var a: float = PI - PI * float(k) / 6.0
			ol.append(Vector2(uc + cos(a) * r, vs + sin(a) * r))
		ol.append(Vector2(ua + pw - cw * 0.5, vs))
		ol.append(Vector2(ua + pw - cw * 0.5, vb))
	ol.append(Vector2(u1, vb))
	ol.append(Vector2(u1, v_top))
	KT._prism(pk, kit, key, _wf(p0, along, out), ol, -0.05, d, col, Vector2(0, 1))


## A hipped roof over the rectangle round c (hx, hz, at the eave height y), rising `pitch` per metre: two trapezoids along
## the longer side and two hips, each with its underside 4cm below. Returns the ridge's height.
static func _hip_roof(pk: PropKit, kit: Dictionary, key: String, c: Vector3, hx: float, hz: float, y: float, pitch: float, col: Color) -> float:
	var along_x: bool = hx >= hz
	var hs: float = hz if along_x else hx
	var ry: float = y + hs * pitch
	var rl: float = (hx if along_x else hz) - hs
	if along_x:
		var r0 := c + Vector3(-rl, ry, 0)
		var r1 := c + Vector3(rl, ry, 0)
		SW._roof(pk, kit, key, c + Vector3(hx, y, hz), c + Vector3(-hx, y, hz), r0, r1, col, Vector3(0, 1, pitch).normalized())
		SW._roof(pk, kit, key, c + Vector3(-hx, y, -hz), c + Vector3(hx, y, -hz), r1, r0, col, Vector3(0, 1, -pitch).normalized())
		_roof_tri(pk, kit, key, c + Vector3(-hx, y, hz), c + Vector3(-hx, y, -hz), r0, col, Vector3(-pitch, 1, 0).normalized())
		_roof_tri(pk, kit, key, c + Vector3(hx, y, -hz), c + Vector3(hx, y, hz), r1, col, Vector3(pitch, 1, 0).normalized())
	else:
		var r0b := c + Vector3(0, ry, -rl)
		var r1b := c + Vector3(0, ry, rl)
		SW._roof(pk, kit, key, c + Vector3(hx, y, -hz), c + Vector3(hx, y, hz), r1b, r0b, col, Vector3(pitch, 1, 0).normalized())
		SW._roof(pk, kit, key, c + Vector3(-hx, y, hz), c + Vector3(-hx, y, -hz), r0b, r1b, col, Vector3(-pitch, 1, 0).normalized())
		_roof_tri(pk, kit, key, c + Vector3(-hx, y, -hz), c + Vector3(hx, y, -hz), r0b, col, Vector3(0, 1, -pitch).normalized())
		_roof_tri(pk, kit, key, c + Vector3(hx, y, hz), c + Vector3(-hx, y, hz), r1b, col, Vector3(0, 1, pitch).normalized())
	return ry


## A triangle of roof (a hip, a pyramid's face) facing `out`, UVs along its eave and up, with its underside 4cm below.
static func _roof_tri(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, apex: Vector3, col: Color, out: Vector3, under := true) -> void:
	var l: float = a.distance_to(b)
	var e: Vector3 = (b - a) / maxf(l, 1e-4)
	var u_apex: float = (apex - a).dot(e)
	var v_apex: float = ((apex - a) - e * u_apex).length()
	var ua := Vector2.ZERO
	var ub := Vector2(l, 0) * uvk
	var uc := Vector2(u_apex, v_apex) * uvk
	pk.tri(kit, key, a, b, apex, out, out, out, col, out, ua, ub, uc)
	if under:
		var dn := Vector3(0, -0.04, 0)
		pk.tri(kit, key, a + dn, b + dn, apex + dn, -out, -out, -out, col.darkened(0.4), -out, ua, ub, uc)


## A pyramid roof over the rectangle round c (hx, hz) from y up to its apex.
static func _pyramid(pk: PropKit, kit: Dictionary, key: String, c: Vector3, hx: float, hz: float, y: float, apex_y: float, col: Color, under := false) -> void:
	var ap := c + Vector3(0, apex_y, 0)
	var corners: Array = [Vector3(-hx, y, hz), Vector3(hx, y, hz), Vector3(hx, y, -hz), Vector3(-hx, y, -hz)]
	var h: float = apex_y - y
	var outs: Array = [Vector3(0, hz, h).normalized(), Vector3(h, hx, 0).normalized(), Vector3(0, hz, -h).normalized(), Vector3(-h, hx, 0).normalized()]
	for k in range(4):
		_roof_tri(pk, kit, key, c + (corners[k] as Vector3), c + (corners[(k + 1) % 4] as Vector3), ap, col, outs[k], under)


## A gable roof along z over x in [-hx, hx] (eaves at y, with `oh` overhang) from z0 to z1, its ridge at ridge_y over x = cx.
static func _gable_roof_z(pk: PropKit, kit: Dictionary, key: String, cx: float, hx: float, z0: float, z1: float, y: float, ridge_y: float, oh: float, col: Color) -> void:
	var sl: float = (ridge_y - y) / hx
	for sx in [-1.0, 1.0]:
		var e: float = cx + sx * (hx + oh)
		var ey: float = y - oh * sl
		if sx > 0.0:
			SW._roof(pk, kit, key, Vector3(e, ey, z1), Vector3(e, ey, z0), Vector3(cx, ridge_y, z0), Vector3(cx, ridge_y, z1), col, Vector3(sl, 1, 0).normalized())
		else:
			SW._roof(pk, kit, key, Vector3(e, ey, z0), Vector3(e, ey, z1), Vector3(cx, ridge_y, z1), Vector3(cx, ridge_y, z0), col, Vector3(-sl, 1, 0).normalized())


## A gable roof along x over z in [cz - hz, cz + hz] (eaves at y, `oh` overhang) from x0 to x1, its ridge at ridge_y.
static func _gable_roof_x(pk: PropKit, kit: Dictionary, key: String, cz: float, hz: float, x0: float, x1: float, y: float, ridge_y: float, oh: float, col: Color) -> void:
	var sl: float = (ridge_y - y) / hz
	for sz in [-1.0, 1.0]:
		var e: float = cz + sz * (hz + oh)
		var ey: float = y - oh * sl
		if sz > 0.0:
			SW._roof(pk, kit, key, Vector3(x0, ey, e), Vector3(x1, ey, e), Vector3(x1, ridge_y, cz), Vector3(x0, ridge_y, cz), col, Vector3(0, 1, sl).normalized())
		else:
			SW._roof(pk, kit, key, Vector3(x1, ey, e), Vector3(x0, ey, e), Vector3(x0, ridge_y, cz), Vector3(x1, ridge_y, cz), col, Vector3(0, 1, -sl).normalized())


## A truncated pyramid (a hopper) from the rectangle (hx0, hz0) at y0 to (hx1, hz1) at y1 round (cx, cz): its four sloped
## faces facing out (and, with `inside`, facing in), UVs in metres.
static func _hopper(pk: PropKit, kit: Dictionary, key: String, cx: float, cz: float, y0: float, hx0: float, hz0: float, y1: float, hx1: float, hz1: float,
		col: Color, inside := false) -> void:
	var a: Array = [Vector3(-hx0, y0, -hz0), Vector3(hx0, y0, -hz0), Vector3(hx0, y0, hz0), Vector3(-hx0, y0, hz0)]
	var b: Array = [Vector3(-hx1, y1, -hz1), Vector3(hx1, y1, -hz1), Vector3(hx1, y1, hz1), Vector3(-hx1, y1, hz1)]
	var c := Vector3(cx, 0, cz)
	for k in range(4):
		var p0: Vector3 = c + (a[k] as Vector3)
		var p1: Vector3 = c + (a[(k + 1) % 4] as Vector3)
		var p2: Vector3 = c + (b[(k + 1) % 4] as Vector3)
		var p3: Vector3 = c + (b[k] as Vector3)
		var mid: Vector3 = (p0 + p1 + p2 + p3) * 0.25
		var n: Vector3 = (p1 - p0).cross(p3 - p0).normalized()
		if n.dot(mid - Vector3(cx, mid.y, cz)) < 0.0:
			n = -n
		var l: float = p0.distance_to(p1)
		var h: float = p0.distance_to(p3)
		var uv: Array = [Vector2(0, 0), Vector2(l, 0) * uvk, Vector2(l, h) * uvk, Vector2(0, h) * uvk]
		pk.quad(kit, key, [p0, p1, p2, p3], n, col, uv)
		if inside:
			pk.quad(kit, key, [p0, p1, p2, p3], -n, col.darkened(0.35), uv)


## A spoked wheel (a winding sheave) of radius r round c turning about x: a grooved rim `rw` wide, a hub, `spokes` flat
## spokes alternately in two planes (a dished wheel), and the axle `axle` either side.
static func _sheave(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, rw: float, spokes: int, col: Color, axle := 0.9, segs := 32) -> void:
	var wb := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
	var h: float = rw * 0.5
	var dr: float = r * 0.07
	pk.lathe(kit, key, c, [Vector2(r - dr, -h), Vector2(r + 0.05, -h), Vector2(r + 0.05, -h * 0.55), Vector2(r - dr * 0.25, -h * 0.12),
			Vector2(r - dr * 0.25, h * 0.12), Vector2(r + 0.05, h * 0.55), Vector2(r + 0.05, h), Vector2(r - dr, h), Vector2(r - dr, -h)], segs, col, false, wb)
	var ax := Vector3.RIGHT
	var hub_r: float = r * 0.13
	pk.tube(kit, key, c - ax * (h + 0.25), c + ax * (h + 0.25), hub_r, hub_r, 14, col.darkened(0.15), true)
	pk.tube(kit, key, c - ax * axle, c + ax * axle, r * 0.05, r * 0.05, 10, STEEL_DARK, true)
	for k in range(spokes):
		var a: float = TAU * float(k) / float(spokes)
		var d := Vector3(0, cos(a), sin(a))
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var p0: Vector3 = c + d * (hub_r * 0.9) + ax * (side * (h + 0.15))
		var p1: Vector3 = c + d * (r - dr * 0.95) + ax * (side * h * 0.3)
		pk.beam(kit, key, p0, p1, r * 0.05, r * 0.024, col, Vector3(0, -sin(a), cos(a)))


## A vertical ladder from `base` up to `top` standing off a face looking `out`: two stiles, rungs every 0.5m, and from
## 2.5m up a cage of half hoops every 2m with three straps; a rest landing every `rest` metres (0: none).
static func _cage_ladder(pk: PropKit, kit: Dictionary, base: Vector3, top: Vector3, out: Vector3, col := STEEL_DARK, rest := 0.0) -> void:
	var across: Vector3 = out.cross(UP).normalized()
	var stand: Vector3 = out * 0.16
	for sx in [-1.0, 1.0]:
		_bar(pk, kit, "steel", base + across * (sx * 0.23) + stand, top + across * (sx * 0.23) + stand, 0.06, 0.05, col, across)
	var h: float = top.y - base.y
	var n: int = int(h / 0.5)
	for k in range(1, n + 1):
		var p: Vector3 = base.lerp(top, float(k) / float(n + 1)) + stand
		_bar(pk, kit, "steel", p - across * 0.23, p + across * 0.23, 0.035, 0.035, col, UP)
	if h < 3.0:
		return
	var y: float = base.y + 2.5
	while y < top.y - 0.3:
		var c: Vector3 = base.lerp(top, (y - base.y) / h) + stand
		var prev := Vector3.ZERO
		for k in range(4):
			var a: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 3.0)
			var p2: Vector3 = c + out * (0.55 * cos(a)) + across * (0.4 * sin(a))
			if k > 0:
				_bar(pk, kit, "steel", prev, p2, 0.05, 0.012, col, UP)
			prev = p2
		y += 2.0
	for a2 in [-1.1, 0.0, 1.1]:
		var o2: Vector3 = out * (0.55 * cos(a2)) + across * (0.4 * sin(a2))
		_bar(pk, kit, "steel", base + Vector3(0, 2.5, 0) + stand + o2, top + stand + o2 - Vector3(0, 0.3, 0), 0.05, 0.012, col, across)
	if rest > 0.0:
		var ry: float = base.y + rest
		while ry < top.y - 2.0:
			var c2: Vector3 = Vector3(base.x, ry, base.z) + out * 0.9
			_box(pk, kit, "steel", c2, Basis(across, UP, out), Vector3(1.4, 0.08, 1.4), col)
			SW._railing(pk, kit, [c2 + across * 0.7 - out * 0.5, c2 + across * 0.7 + out * 0.7, c2 - across * 0.7 + out * 0.7, c2 - across * 0.7 - out * 0.5],
					1.05, col, "steel")
			ry += rest


## A lattice girder from a to b with four chords and laced faces (bits in `faces`: 1 the top, 2 the bottom, 4 the -side,
## 8 the +side), made of capless bars: SteelworksKit._lattice at two thirds of its triangles.
static func _lat(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, h: float, panel: float, col: Color, up := UP,
		chord := 0.24, lace := 0.11, faces := 15) -> void:
	var ax := b - a
	var length := ax.length()
	if length < 0.01:
		return
	var z := ax / length
	var u := up - z * up.dot(z)
	if u.length_squared() < 1e-6:
		u = Vector3.BACK
	u = u.normalized()
	var s := z.cross(u).normalized()
	var corner := func(i: int, j: int) -> Vector3:
		return s * (w * 0.5 * float(i)) + u * (h * 0.5 * float(j))
	for i in [-1, 1]:
		for j in [-1, 1]:
			var o: Vector3 = corner.call(i, j)
			_bar(pk, kit, key, a + o, b + o, chord, chord, col, s)
	var n: int = maxi(int(round(length / panel)), 1)
	var fdefs: Array = [[1, Vector2i(-1, 1), Vector2i(1, 1)], [2, Vector2i(-1, -1), Vector2i(1, -1)], [4, Vector2i(-1, -1), Vector2i(-1, 1)], [8, Vector2i(1, -1), Vector2i(1, 1)]]
	for k in range(n + 1):
		var p: Vector3 = a + ax * (float(k) / float(n))
		var p1: Vector3 = a + ax * (float(k + 1) / float(n))
		for f in fdefs:
			if (faces & int(f[0])) == 0:
				continue
			var c0: Vector3 = corner.call(f[1].x, f[1].y)
			var c1: Vector3 = corner.call(f[2].x, f[2].y)
			_bar(pk, kit, key, p + c0, p + c1, lace, lace, col, z)
			if k < n:
				if k % 2 == 0:
					_bar(pk, kit, key, p + c0, p1 + c1, lace * 0.86, lace * 0.86, col)
				else:
					_bar(pk, kit, key, p + c1, p1 + c0, lace * 0.8, lace * 0.8, col)


# ======================================================================================
#  Schacht I: the Malakoff tower
# ======================================================================================

const MK_W := 8.4         # the main walls' outer faces
const MK_P := 9.0         # the corner piers' outer faces
const MK_PI := 6.0        # the piers' inner edges
const MK_PL := 1.0        # the plinth's top (the portal's sill)
const MK_T := 0.9         # the walls' depth at the openings
const MK_FRIEZE := 27.0   # the frieze's top, the cornice's foot
const MK_PARA := 27.7     # the parapet's foot
const MK_PARA_TOP := 30.2
const MK_PIER_TOP := 28.0 # the piers' shafts end under their turret caps
const MK_ROOF_APEX := 33.6


## Schacht I's Malakoff tower (1871): a fortress-like square brick tower, its frame centred on the shaft, y = 0 the ground,
## the portal toward +z. Main walls at ±8.4 between corner piers 3m square (outer faces ±9.0) that rise into crenellated
## turrets; an ashlar plinth (±9.3, to y 1.0) and, in front of the portal, five steps out to z 11.05. Three tiers of
## round-arched steel windows between sandstone string courses (8.8, 17.6), lisenes dividing each face into three bays,
## arrow slits up the piers, a corbel table of little arches under a stepped cornice (to 27.7), a crenellated parapet to
## 30.2, the turrets' merlons to 31.4, and a slate pyramid inside the parapet to 33.6 with a lightning rod to 35.2. On the
## back (-z) the two round-arched rope openings (dark) high up; SCHACHT I on a tablet on the front's top tier, 1871 over
## the portal. Footprint x, z ±9.3 (z to 11.05 with the steps).
static func malakoff_tower(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	_mblock(pk, kit, "ashlar", Vector3(-9.3, -2.0, -9.3), Vector3(9.3, MK_PL, 9.3), SAND_DARK)
	# The portal's steps: each tread its own block, a step's depth further out and 20cm lower.
	for k in range(1, 6):
		var top: float = MK_PL - 0.2 * float(k)
		_mblock(pk, kit, "ashlar", Vector3(-2.6 - 0.15 * float(k), -0.4, 9.3 + 0.35 * float(k - 1)), Vector3(2.6 + 0.15 * float(k), top, 9.3 + 0.35 * float(k)), SAND)
	var outs: Array = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]
	for fi in range(4):
		var out: Vector3 = outs[fi]
		var along: Vector3 = UP.cross(out)
		var p0: Vector3 = out * MK_W
		var front: bool = fi == 0
		var back: bool = fi == 2
		var holes: Array = []
		var ops: Array = []   # [cu, v0, half, hs, rise, options]
		for bu in [-3.6, 0.0, 3.6]:
			if front and bu == 0.0:
				ops.append([0.0, MK_PL, 1.7, 3.6, 1.7, {"trim": "ashlar", "trim_w": 0.5, "keystone": true, "door": DOOR_GREEN, "sill": false, "segs": 12, "trim_foot": true}])
			else:
				ops.append([bu, 3.0, 0.75, 3.6, 0.75, {"trim": "ashlar", "trim_w": 0.3, "keystone": true}])
			ops.append([bu, 10.6, 0.85, 4.6, 0.85, {"trim": "ashlar", "trim_w": 0.3, "keystone": true}])
			if back and bu != 0.0:
				ops.append([bu, 19.2, 1.1, 4.0, 1.1, {"trim": "ashlar", "trim_w": 0.35, "keystone": true, "dark": true, "sill": true, "segs": 12}])
			elif not (front and bu == 0.0):
				for du in [-0.66, 0.66]:
					ops.append([bu + du, 19.6, 0.42, 2.6, 0.42, {"trim": "brick", "trim_col": BRICK_DARK, "trim_w": 0.22, "segs": 8}])
		for op in ops:
			holes.append(_arch_hole(op[0], op[1], op[2], op[3], op[4]))
		_wall(pk, kit, "brick", p0, along, out, -MK_PI - 0.05, MK_PI + 0.05, MK_PL, MK_PARA, holes, BRICK, MK_T)
		for op in ops:
			_arch_open(pk, kit, "brick", p0, along, out, op[0], op[1], op[2], op[3], op[4], MK_T, BRICK, op[5])
		# Lisenes between the bays, the string courses over them, the frieze and the cornice.
		for lu in [-1.8, 1.8]:
			_band(pk, kit, "brick", p0, along, out, lu - 0.25, lu + 0.25, 8.9 if front else MK_PL - 0.05, MK_FRIEZE - 1.0, 0.1, BRICK_DARK)
		for by in [8.8, 17.6]:
			_band(pk, kit, "ashlar", p0, along, out, -MK_PI - 0.02, MK_PI + 0.02, by, by + 0.4, 0.15, SAND)
			_band(pk, kit, "ashlar", p0, along, out, -MK_PI - 0.02, MK_PI + 0.02, by + 0.4, by + 0.52, 0.08, SAND_DARK)
		_frieze(pk, kit, "brick", p0, along, out, -MK_PI - 0.02, MK_PI + 0.02, MK_FRIEZE, 1.0, 1.0, 0.12, BRICK_DARK)
		var steps: Array = [[0.22, 0.22], [0.36, 0.24], [0.5, 0.24]]
		var y: float = MK_FRIEZE
		for s in steps:
			_band(pk, kit, "ashlar" if s[0] == 0.5 else "brick", p0, along, out, -MK_PI - 0.03, MK_PI + 0.03, y, y + float(s[1]), float(s[0]),
					SAND if s[0] == 0.5 else BRICK_DARK, 0.05 + float(s[0]) * 0.1)
			y += float(s[1])
		# The parapet: a crenellated slab standing on the cornice, its inner face visible from above.
		var ol := PackedVector2Array([Vector2(MK_PI + 0.05, MK_PARA), Vector2(MK_PI + 0.05, MK_PARA_TOP)])
		var u: float = MK_PI + 0.05
		var merlon := 0.9
		var crenel := 0.75
		var cnt: int = int(floor((2.0 * MK_PI + 0.1 + crenel) / (merlon + crenel)))
		var gap: float = ((2.0 * MK_PI + 0.1) - float(cnt) * merlon) / float(cnt - 1)
		for k in range(cnt):
			var ue: float = u - merlon
			ol.append(Vector2(ue, MK_PARA_TOP))
			if k < cnt - 1:
				ol.append(Vector2(ue, MK_PARA_TOP - 1.0))
				ol.append(Vector2(ue - gap, MK_PARA_TOP - 1.0))
				ol.append(Vector2(ue - gap, MK_PARA_TOP))
			u = ue - gap
		ol.append(Vector2(-MK_PI - 0.05, MK_PARA))
		KT._prism(pk, kit, "brick", _wf(p0, along, out), ol, -0.6, 0.44, BRICK, Vector2(0, 1), true)
		# Tablets: SCHACHT I over the front's top tier, the year over the portal.
		if front:
			_band(pk, kit, "ashlar", p0, along, out, -2.2, 2.2, 19.9, 21.5, 0.14, SAND)
			_band(pk, kit, "ashlar", p0, along, out, -2.3, 2.3, 19.8, 21.6, 0.12, SAND_DARK)
			_lbl(labels, "SCHACHT I", p0 + UP * 20.7 + out * 0.17, out, 0.66, CARVED, 4.1)
			_band(pk, kit, "ashlar", p0, along, out, -0.9, 0.9, 7.55, 8.45, 0.1, SAND)
			_lbl(labels, "1871", p0 + UP * 8.0 + out * 0.13, out, 0.5, CARVED, 1.6)
			var wfo := _wf(p0, along, out)
			KT._circle_ring(pk, kit, "ashlar", wfo, Vector2(0, 23.9), 0.75, 1.08, 0.0, 0.1, SAND)
			_glass(pk, kit, wfo * Vector3(0, 23.9, 0.03), along, out, 1.2, 1.2)
	# The corner piers: shafts, string courses, arrow slits, corbelled caps and crenellated turrets.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * 7.5, 0, sz * 7.5)
			_mblock(pk, kit, "brick", c + Vector3(-1.5, MK_PL, -1.5), c + Vector3(1.5, MK_PIER_TOP, 1.5), BRICK, false)
			for by2 in [8.75, 17.55]:
				_cornice(pk, kit, "ashlar", c, 1.5, 1.5, by2, [Vector2(0.12, 0.5)], SAND, 0.0)
			_cornice(pk, kit, "brick", c, 1.5, 1.5, 26.22, [Vector2(0.1, 0.4), Vector2(0.22, 0.4), Vector2(0.34, 0.5), Vector2(0.3, 0.48)], BRICK_DARK, 0.0, false)
			_mblock(pk, kit, "brick", c + Vector3(-1.8, MK_PIER_TOP, -1.8), c + Vector3(1.8, 30.0, 1.8), BRICK, true)
			_cornice(pk, kit, "ashlar", c, 1.8, 1.8, 29.75, [Vector2(0.08, 0.25)], SAND, 0.0)
			for mx in [-1.0, 0.0, 1.0]:
				for mz in [-1.0, 0.0, 1.0]:
					if mx == 0.0 and mz == 0.0:
						continue
					var hw := Vector2(0.35 if mx != 0.0 else 0.6, 0.35 if mz != 0.0 else 0.6)
					var mc: Vector3 = c + Vector3(mx * (1.8 - hw.x), 0, mz * (1.8 - hw.y))
					if mx != 0.0 and mz == 0.0:
						hw.x = 0.22
						mc.x = c.x + mx * (1.8 - 0.22)
					if mz != 0.0 and mx == 0.0:
						hw.y = 0.22
						mc.z = c.z + mz * (1.8 - 0.22)
					_mblock(pk, kit, "brick", mc + Vector3(-hw.x, 30.0, -hw.y), mc + Vector3(hw.x, 31.4, hw.y), BRICK)
			# Arrow slits on the piers' two outer faces.
			for f in [[Vector3(sx, 0, 0), Vector3(0, 0, -sx)], [Vector3(0, 0, sz), Vector3(sz, 0, 0)]]:
				var o: Vector3 = f[0]
				var al: Vector3 = f[1]
				var fc: Vector3 = c + o * 1.5
				for sy in [5.0, 13.4, 22.2]:
					_box(pk, kit, "ashlar", fc + UP * sy + o * 0.03, Basis(al, UP, o), Vector3(0.6, 2.2, 0.12), SAND)
					_box(pk, kit, "matte", fc + UP * sy + o * 0.1, Basis(al, UP, o), Vector3(0.16, 1.6, 0.04), BLACK)
	# The roof: a slate pyramid inside the parapet, a lightning rod on its apex.
	_pyramid(pk, kit, "kslate", Vector3.ZERO, 8.15, 8.15, 28.0, MK_ROOF_APEX, SLATE)
	_box(pk, kit, "steel", Vector3(0, MK_ROOF_APEX - 0.1, 0), Basis(), Vector3(0.5, 0.35, 0.5), STEEL_DARK)
	pk.tube(kit, "steel", Vector3(0, MK_ROOF_APEX, 0), Vector3(0, MK_ROOF_APEX + 1.6, 0), 0.04, 0.015, 6, STEEL_DARK, true)


# ======================================================================================
#  Schacht II: the Doppelbock headframe
# ======================================================================================

const HF_COL := Color(0.30, 0.38, 0.34)
const HF_SHEAVE_COL := Color(0.25, 0.32, 0.29)
const HF_G := 3.0            # the guide frame's columns at (±HF_G, ±HF_G)
const HF_HEAD := 53.6        # the head girders' underside
const HF_DECK := 55.12       # the sheave platform's top
const HF_R := 3.6            # the sheaves' radius
const HF_HUB_X := 1.2
const HF_HUB_Y := 57.0
const HF_HUB_Z := 3.7
const HF_FOOT := Vector2(6.4, 13.6)      # the struts' feet (±x, ±z)
const HF_TOP := Vector3(3.6, 53.0, 6.6)  # the struts' heads (±x, y, ±z)
const HF_HALL := Vector3(8.0, 11.0, 7.5) # the shaft hall: half x, eaves, half z
const HF_HALL_RIDGE := 15.0


## Schacht II's headframe, a steel Doppelbock: centred on the shaft, y = 0 the ground. A braced guide frame (columns at
## x, z ±3.0) carries the head (girders 53.6..55.0 over x ±4.85, z ±7.85, a railed grating platform on top at 55.12),
## and on each side toward ±z a strut of two lattice legs (feet at x ±6.4, z ±13.6 on concrete footings to ±14.8, heads at
## x ±3.6, y 53, z ±6.6) braced together, so the pull of each winding engine's rope (+z for the sheave at z +3.45, -z for
## the one at -3.7) is taken by the strut on its side. The two 7.2m sheaves are separate meshes (headframe_sheave, at
## headframe_sheave_hubs(): x ∓1.2, y 57.0, z ±3.7, turning about x); they hang down through slots in the platform between
## their bearing girders to 53.4 and stand up to 60.65. This builds their bearings on the girders and the ropes down the shaft
## into the shaft hall's roof, a railing round each slot and two red aviation lights (lit) on short masts to 58.6, not the
## wheels. A caged ladder up the guide frame's -x face; ZECHE KRONPRINZ on name boards along the head's ±x sides. The brick
## shaft hall (x ±8, z ±7.5, eaves 11, slate roof to 15 along z) round the frame's foot: SCHACHT II on its +z gable over
## the doors. Footprint x ±8.3, z ±14.8.
static func headframe(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var col := HF_COL
	# The guide frame: four columns, girders round it every ~5.6m from over the hall's roof, crossed bracing on its faces.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pk.beam(kit, "shell", Vector3(sx * HF_G, -0.5, sz * HF_G), Vector3(sx * HF_G, HF_HEAD, sz * HF_G), 0.6, 0.6, col)
	# Ring girders every 5.5m from over the hall's roof; the last stays under the sheaves' rims (they hang down to 52.2).
	var levels: Array = []
	var ly := 13.6
	while ly < 47.0:
		levels.append(ly)
		ly += 5.5
	levels.append(51.5)
	var cs: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for li in range(levels.size()):
		var yl: float = levels[li]
		for i in range(4):
			var ca: Vector2 = cs[i]
			var cb: Vector2 = cs[(i + 1) % 4]
			var a := Vector3(ca.x * HF_G, yl, ca.y * HF_G)
			var b := Vector3(cb.x * HF_G, yl, cb.y * HF_G)
			var inward: Vector3 = -Vector3((ca.x + cb.x) * 0.5, 0, (ca.y + cb.y) * 0.5)
			a += (b - a).normalized() * 0.3 + inward * 0.0
			b -= (b - a).normalized() * 0.3
			SW._ibeam(pk, kit, "shell", a, b, 0.5, 0.3, col)
			if li < levels.size() - 1:
				var y2: float = levels[li + 1]
				var a2 := Vector3(ca.x * HF_G, y2, ca.y * HF_G)
				var b2 := Vector3(cb.x * HF_G, y2, cb.y * HF_G)
				var o: Vector3 = Vector3((ca.x + cb.x) * 0.5, 0, (ca.y + cb.y) * 0.5) * 0.32
				_bar(pk, kit, "shell", a + o + Vector3(0, 0.25, 0), b2 + o - Vector3(0, 0.25, 0), 0.16, 0.05, col)
				_bar(pk, kit, "shell", b + o + Vector3(0, 0.25, 0) - (b - a).normalized() * 0.0, a2 + o - Vector3(0, 0.25, 0), 0.16, 0.05, col)
	# The struts: two lattice legs on each side, tied together with lattice girders and crossed between the ties.
	for sz in [-1.0, 1.0]:
		var feet: Array = []
		var heads: Array = []
		for sx in [-1.0, 1.0]:
			var foot := Vector3(sx * HF_FOOT.x, 0.6, sz * HF_FOOT.y)
			var head := Vector3(sx * HF_TOP.x, HF_TOP.y, sz * HF_TOP.z)
			feet.append(foot)
			heads.append(head)
			_lat(pk, kit, "shell", foot, head, 1.7, 1.5, 2.5, col, Vector3(0, 0, sz), 0.34, 0.15)
			_box(pk, kit, "concrete", foot + Vector3(0, -1.8, 0), Basis(), Vector3(2.4, 3.6, 2.4), CONC)
			_box(pk, kit, "shell", foot + Vector3(0, 0.15, 0), Basis(), Vector3(1.6, 0.3, 1.6), col.darkened(0.2))
		var ties: Array = [0.0, 0.27, 0.52, 0.76, 0.97]
		for ti in range(ties.size()):
			var t: float = ties[ti]
			var pa: Vector3 = (feet[0] as Vector3).lerp(heads[0], t)
			var pb: Vector3 = (feet[1] as Vector3).lerp(heads[1], t)
			if t > 0.0:
				_lat(pk, kit, "shell", pa + Vector3(0.6, 0, 0), pb - Vector3(0.6, 0, 0), 0.5, 1.0, 1.4, col, UP, 0.16, 0.08, 12)
			if ti < ties.size() - 1:
				var qa: Vector3 = (feet[0] as Vector3).lerp(heads[0], ties[ti + 1])
				var qb: Vector3 = (feet[1] as Vector3).lerp(heads[1], ties[ti + 1])
				_bar(pk, kit, "shell", pa + Vector3(0.6, 0.5, 0), qb - Vector3(0.6, 0.5, 0), 0.2, 0.1, col)
				_bar(pk, kit, "shell", pb - Vector3(0.6, -0.5, 0), qa + Vector3(0.6, -0.5, 0), 0.2, 0.1, col)
		# Each strut's head bears on the head's end girder.
		for sx in [-1.0, 1.0]:
			var hd := Vector3(sx * HF_TOP.x, HF_TOP.y, sz * HF_TOP.z)
			_box(pk, kit, "shell", hd + Vector3(0, 0.35, sz * 0.4), Basis(), Vector3(1.5, 0.9, 1.9), col.darkened(0.1))
	# The head: bearing girders along z (two either side of each sheave), edge girders, cross girders a little shallower.
	for gx in [-1.95, -0.45, 0.45, 1.95]:
		SW._ibeam(pk, kit, "shell", Vector3(gx, (HF_HEAD + 55.0) * 0.5, -7.85), Vector3(gx, (HF_HEAD + 55.0) * 0.5, 7.85), 55.0 - HF_HEAD, 0.45, col, Vector3.RIGHT)
	for ex in [-4.6, 4.6]:
		SW._ibeam(pk, kit, "shell", Vector3(ex, 54.375, -7.85), Vector3(ex, 54.375, 7.85), 1.15, 0.4, col, Vector3.RIGHT)
	for cz in [-7.6, 7.6]:
		SW._ibeam(pk, kit, "shell", Vector3(-4.85, 54.3, cz), Vector3(4.85, 54.3, cz), 1.1, 0.4, col)
	# Over the guide frame's columns the cross girders stop either side of the sheave that hangs through there.
	for cz in [-HF_G, HF_G]:
		var bx: float = -HF_HUB_X if cz > 0.0 else HF_HUB_X
		SW._ibeam(pk, kit, "shell", Vector3(-4.85, 54.3, cz), Vector3(bx - 0.75, 54.3, cz), 1.1, 0.4, col)
		SW._ibeam(pk, kit, "shell", Vector3(bx + 0.75, 54.3, cz), Vector3(4.85, 54.3, cz), 1.1, 0.4, col)
	# The deck: grating plates round the sheaves' slots (each sheave hangs through its bay from z 0.05 to 7.35).
	var plates: Array = [Rect2(-4.85, -7.85, 2.65, 15.7), Rect2(2.2, -7.85, 2.65, 15.7), Rect2(-0.68, -7.85, 1.36, 15.7),
			Rect2(-2.2, -7.85, 1.52, 7.9), Rect2(-2.2, 7.35, 1.52, 0.5), Rect2(0.68, -7.85, 1.52, 0.5), Rect2(0.68, -0.05, 1.52, 7.9)]
	for r in plates:
		var rr: Rect2 = r
		_box(pk, kit, "steel", Vector3(rr.get_center().x, 55.06, rr.get_center().y), Basis(), Vector3(rr.size.x, 0.12, rr.size.y), STEEL_DARK)
	SW._railing(pk, kit, [Vector3(-4.8, HF_DECK, -7.8), Vector3(4.8, HF_DECK, -7.8), Vector3(4.8, HF_DECK, 7.8), Vector3(-4.8, HF_DECK, 7.8), Vector3(-4.8, HF_DECK, -7.8)],
			1.1, Color(0.62, 0.62, 0.58), "steel")
	# Name boards along the head's sides.
	for sx in [-1.0, 1.0]:
		var bo := Vector3(sx, 0, 0)
		_box(pk, kit, "paint", Vector3(sx * 4.9, 54.35, 0), Basis(Vector3(0, 0, -sx), UP, bo), Vector3(10.0, 1.1, 0.06), Color(0.86, 0.84, 0.76))
		_lbl(labels, "ZECHE KRONPRINZ", Vector3(sx * 4.94, 54.35, 0), bo, 0.62, Color(0.12, 0.2, 0.17), 9.4)
	# The sheaves' bearings and the ropes down the shaft (the wheels themselves: headframe_sheave).
	for hub in headframe_sheave_hubs():
		var h: Vector3 = hub
		for bx in [-0.75, 0.75]:
			_box(pk, kit, "shell", Vector3(h.x + bx, (55.3 + h.y - 0.3) * 0.5, h.z), Basis(), Vector3(0.5, h.y - 0.3 - 55.3, 1.2), col.darkened(0.15))
			_box(pk, kit, "shell", Vector3(h.x + bx, 55.21, h.z), Basis(), Vector3(0.62, 0.18, 1.8), col.darkened(0.25))
			_box(pk, kit, "steel", Vector3(h.x + bx, h.y, h.z), Basis(), Vector3(0.56, 0.62, 0.95), STEEL_DARK)
			pk.tube(kit, "steel", Vector3(h.x + bx, h.y + 0.3, h.z), Vector3(h.x + bx, h.y + 0.45, h.z), 0.12, 0.08, 6, STEEL_DARK, true)
		var down_z: float = h.z - HF_R * signf(h.z)
		for rx in [-0.08, 0.08]:
			_bar(pk, kit, "steel", Vector3(h.x + rx, h.y, down_z), Vector3(h.x + rx, HF_HALL_RIDGE - 1.2, down_z), 0.055, 0.055, Color(0.12, 0.12, 0.12))
	# A railing round each sheave's slot, and an aviation light on a short mast at each end of the head.
	for hub in headframe_sheave_hubs():
		var hh: Vector3 = hub
		var z0: float = hh.z - HF_R - 0.25
		var z1: float = hh.z + HF_R + 0.25
		SW._railing(pk, kit, [Vector3(hh.x - 1.12, HF_DECK, z0), Vector3(hh.x - 1.12, HF_DECK, z1), Vector3(hh.x + 1.12, HF_DECK, z1), Vector3(hh.x + 1.12, HF_DECK, z0),
				Vector3(hh.x - 1.12, HF_DECK, z0)], 1.0, Color(0.62, 0.62, 0.58), "steel")
	for sz in [-1.0, 1.0]:
		_bar(pk, kit, "steel", Vector3(4.6, HF_DECK, sz * 7.7), Vector3(4.6, HF_DECK + 3.2, sz * 7.7), 0.08, 0.08, STEEL_DARK)
		pk.lathe(kit, "lamp", Vector3(4.6, HF_DECK + 3.2, sz * 7.7), [Vector2(0.001, 0.0), Vector2(0.14, 0.02), Vector2(0.14, 0.18), Vector2(0.001, 0.26)], 8, Color(1.0, 0.15, 0.08))
	# A caged ladder up the guide frame's -x face with rest landings.
	_cage_ladder(pk, kit, Vector3(-HF_G - 0.3, 13.8, 0), Vector3(-HF_G - 0.3, HF_DECK, 0), Vector3.LEFT, STEEL_DARK, 11.0)
	_shaft_hall(pk, kit, labels)


## The shaft hall round the headframe's foot: brick, x ±8, z ±7.5, a slate roof along z to 15; doors on the +z gable.
static func _shaft_hall(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hx: float = HF_HALL.x
	var hz: float = HF_HALL.z
	var eh: float = HF_HALL.y
	var pl := 0.8
	_mblock(pk, kit, "ashlar", Vector3(-hx - 0.2, -2.0, -hz - 0.2), Vector3(hx + 0.2, pl, hz + 0.2), SAND_DARK)
	var sl: float = (HF_HALL_RIDGE - eh) / hx
	for fi in range(4):
		var out: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][fi]
		var along: Vector3 = UP.cross(out)
		var half: float = hx if fi % 2 == 0 else hz
		var p0: Vector3 = out * (hz if fi % 2 == 0 else hx)
		var ops: Array = []
		var holes: Array = []
		if fi == 0:
			holes.append([Rect2(-2.2, pl, 4.4, 4.8), true])
			for u in [-5.2, 5.2]:
				ops.append([u, 2.8, 0.85, 3.2, 0.45])
		elif fi % 2 == 1:
			for u in [-5.25, -1.75, 1.75, 5.25]:
				ops.append([u, 2.8, 0.85, 3.6, 0.45])
		else:
			for u in [-4.5, 0.0, 4.5]:
				ops.append([u, 2.8, 0.85, 3.6, 0.45])
		for op in ops:
			holes.append(_arch_hole(op[0], op[1], op[2], op[3], op[4]))
		var top: float = eh + 0.25 if fi % 2 == 1 else eh
		_wall(pk, kit, "brick", p0, along, out, -half, half, pl, top, holes, BRICK, 0.5)
		for op in ops:
			_arch_open(pk, kit, "brick", p0, along, out, op[0], op[1], op[2], op[3], op[4], 0.5, BRICK,
					{"trim": "brick", "trim_col": BRICK_DARK, "trim_w": 0.26, "segs": 6})
		_band(pk, kit, "brick", p0, along, out, -half - 0.02, half + 0.02, pl, pl + 0.35, 0.06, BRICK_DARK)
		if fi == 0:
			# The doors: a pair of steel leaves under a steel lintel.
			var wf := _wf(p0, along, out)
			var bas := Basis(along, UP, out)
			for sx in [-1.0, 1.0]:
				_box(pk, kit, "paint", wf * Vector3(sx * 1.1, pl + 2.4, -0.3), bas, Vector3(2.2, 4.8, 0.08), DOOR_GREEN)
				for k in range(4):
					_box(pk, kit, "paint", wf * Vector3(sx * 1.1, pl + 0.6 + 1.2 * float(k), -0.24), bas, Vector3(2.0, 0.1, 0.04), DOOR_GREEN.darkened(0.2))
			_box(pk, kit, "steel", wf * Vector3(0, pl + 4.95, 0.06), bas, Vector3(5.0, 0.3, 0.12), STEEL_DARK)
		# The gables on ±z with a round window and (front) the shaft's name.
		if fi % 2 == 0:
			var poly := PackedVector2Array([Vector2(-hx, eh), Vector2(hx, eh), Vector2(hx, eh + 0.15), Vector2(0, HF_HALL_RIDGE - 0.1), Vector2(-hx, eh + 0.15)])
			_wpoly(pk, kit, "brick", p0, along, out, poly, BRICK)
			var wf2 := _wf(p0, along, out)
			KT._circle_ring(pk, kit, "ashlar", wf2, Vector2(0, eh + 1.6), 0.7, 1.0, 0.0, 0.08, SAND)
			_glass(pk, kit, wf2 * Vector3(0, eh + 1.6, 0.03), along, out, 1.1, 1.1)
			if fi == 0:
				_band(pk, kit, "ashlar", p0, along, out, -2.0, 2.0, 7.0, 8.0, 0.1, SAND)
				_lbl(labels, "SCHACHT II", p0 + UP * 7.5 + out * 0.13, out, 0.62, CARVED, 3.6)
	_cornice(pk, kit, "brick", Vector3.ZERO, hx, hz, eh - 0.6, [Vector2(0.12, 0.3), Vector2(0.24, 0.3)], BRICK_DARK, 0.2, false)
	_gable_roof_z(pk, kit, "kslate", 0.0, hx, -hz - 0.35, hz + 0.35, eh + 0.25, HF_HALL_RIDGE, 0.45, SLATE)
	pk.beam(kit, "steel", Vector3(0, HF_HALL_RIDGE + 0.04, -hz - 0.4), Vector3(0, HF_HALL_RIDGE + 0.04, hz + 0.4), 0.3, 0.1, Color(0.2, 0.2, 0.22))


## One of Schacht II's sheave wheels, built round its hub at the origin turning about local x: a 7.2m spoked wheel with a
## grooved rim 0.55 wide, 16 spokes in two planes, the hub and its axle out to x ±0.9 (into the bearings). In plain
## vertex-colour steel ("steel"): a world-space weathering shader would swim over a turning wheel.
static func headframe_sheave(pk: PropKit, kit: Dictionary) -> void:
	_sheave(pk, kit, "steel", Vector3.ZERO, HF_R, 0.55, 16, HF_SHEAVE_COL, 0.9, 36)


## The two sheaves' hubs in the headframe's frame (life size): the one at +z sends its rope to an engine on +z, the other to
## -z. Both turn about x.
static func headframe_sheave_hubs() -> Array:
	return [Vector3(-HF_HUB_X, HF_HUB_Y, HF_HUB_Z), Vector3(HF_HUB_X, HF_HUB_Y, -HF_HUB_Z)]


## Where each sheave's rope leaves the top of its wheel for its winding engine, [point, horizontal direction], in the
## headframe's frame: draw the rope from there down to a winding house's inlet (winding_house_rope_inlets).
static func headframe_rope_exits() -> Array:
	return [[Vector3(-HF_HUB_X, HF_HUB_Y + HF_R, HF_HUB_Z), Vector3.BACK], [Vector3(HF_HUB_X, HF_HUB_Y + HF_R, -HF_HUB_Z), Vector3.FORWARD]]


# ======================================================================================
#  The winding engine houses
# ======================================================================================

## [half x, half z, eaves, ridge] for each variant.
const WH_DIMS := [[8.0, 15.0, 12.5, 18.0], [6.5, 11.0, 10.0, 15.0]]
const WH_PL := 1.0
const WH_T := 0.6
const WH_RL := 0.4   # the roof's line over the cornice


## A winding engine house (Fördermaschinenhaus): centred, its long axis along z, the front gable toward +z with the
## plaque, the rope gable toward -z. Variant 0 (Schacht II): x ±8, z ±15, eaves 12.5, a slate roof to 18 with a roof
## lantern along the ridge to 20.4; tall round-arched windows in five bays a side between lisenes, a corbel table under
## a cornice, a great arched window between two lower ones in the front gable, an oculus over them. Variant 1 (smaller,
## Schacht I's): x ±6.5, z ±11, eaves 10, ridge 15, stepped gables (Treppengiebel) rising 0.6-0.9 over the roof with
## sandstone caps, four bays a side, a louvred ventilator on the ridge to 17.3. Both on an ashlar plinth (to 1.0, its edge
## 0.25 out). The plaque reads `text` (default FÖRDERMASCHINE SCHACHT II, variant 1 SCHACHT I). The rope gable has two dark
## round-arched rope openings high up (winding_house_rope_inlets) over a door and two windows.
static func winding_house(pk: PropKit, kit: Dictionary, labels: Array, variant := 0, text := "") -> void:
	var v1: bool = variant == 1
	var d: Array = WH_DIMS[1 if v1 else 0]
	var hx: float = d[0]
	var hz: float = d[1]
	var eave: float = d[2]
	var ridge: float = d[3]
	if text == "":
		text = "FÖRDERMASCHINE SCHACHT I" if v1 else "FÖRDERMASCHINE SCHACHT II"
	var sl: float = (ridge - eave - WH_RL) / hx
	_mblock(pk, kit, "ashlar", Vector3(-hx - 0.25, -2.0, -hz - 0.25), Vector3(hx + 0.25, WH_PL, hz + 0.25), SAND_DARK)
	var trim := {"trim": "ashlar", "trim_w": 0.32, "keystone": true, "trim_col": SAND}
	# The long walls: arched windows in bays between lisenes, a corbel table under the cornice.
	var nb: int = 4 if v1 else 5
	var bay: float = 2.0 * hz / float(nb)
	for sx in [-1.0, 1.0]:
		var out := Vector3(sx, 0, 0)
		var along: Vector3 = UP.cross(out)
		var p0: Vector3 = out * hx
		var ops: Array = []
		for k in range(nb):
			var cu: float = -hz + bay * (float(k) + 0.5)
			ops.append([cu, 2.4, 1.0 if v1 else 1.15, 4.6 if v1 else 6.1, 1.0 if v1 else 1.15])
		var holes: Array = []
		for op in ops:
			holes.append(_arch_hole(op[0], op[1], op[2], op[3], op[4]))
		_wall(pk, kit, "brick", p0, along, out, -hz, hz, WH_PL, eave + WH_RL - 0.06, holes, BRICK, WH_T)
		for op in ops:
			_arch_open(pk, kit, "brick", p0, along, out, op[0], op[1], op[2], op[3], op[4], WH_T, BRICK, trim)
		for k in range(nb + 1):
			var u: float = -hz + bay * float(k)
			var ua: float = maxf(u - 0.35, -hz - 0.18)
			var ub: float = minf(u + 0.35, hz + 0.18)
			if k == 0:
				ub = -hz + 0.7
			elif k == nb:
				ua = hz - 0.7
			_band(pk, kit, "brick", p0, along, out, ua, ub, WH_PL - 0.04, eave - 1.25, 0.18, BRICK_DARK, 0.0)
		_frieze(pk, kit, "brick", p0, along, out, -hz + 0.7, hz - 0.7, eave - 0.5, 0.75, 1.0, 0.1, BRICK_DARK)
		_band(pk, kit, "ashlar", p0, along, out, -hz - 0.1, hz + 0.1, WH_PL - 0.02, WH_PL + 0.3, 0.1, SAND, 0.0)
	_cornice(pk, kit, "brick", Vector3.ZERO, hx, hz, eave - 0.45, [Vector2(0.16, 0.15), Vector2(0.28, 0.15), Vector2(0.4, 0.15)], BRICK_DARK, 0.3)
	# The gables.
	for e in [1.0, -1.0]:
		var out := Vector3(0, 0, e)
		var along: Vector3 = UP.cross(out)
		var p0: Vector3 = out * hz
		var wf := _wf(p0, along, out)
		var ops: Array = []
		var holes: Array = []
		var o_win := trim
		if e > 0.0:
			if v1:
				ops = [[0.0, 2.2, 1.3, 4.2, 1.3, o_win], [-3.7, 2.2, 0.65, 3.4, 0.65, o_win], [3.7, 2.2, 0.65, 3.4, 0.65, o_win]]
			else:
				ops = [[0.0, 2.4, 1.6, 5.8, 1.6, o_win], [-4.6, 2.4, 0.8, 4.4, 0.8, o_win], [4.6, 2.4, 0.8, 4.4, 0.8, o_win]]
		else:
			var dark := {"trim": "ashlar", "trim_w": 0.3, "keystone": true, "trim_col": SAND, "dark": true}
			if v1:
				ops = [[-1.7, 6.6, 0.65, 1.3, 0.65, dark], [1.7, 6.6, 0.65, 1.3, 0.65, dark], [-4.2, 2.2, 0.65, 3.0, 0.65, o_win], [4.2, 2.2, 0.65, 3.0, 0.65, o_win]]
			else:
				ops = [[-2.0, 9.0, 0.75, 1.6, 0.75, dark], [2.0, 9.0, 0.75, 1.6, 0.75, dark], [-5.4, 2.4, 0.8, 4.0, 0.8, o_win], [5.4, 2.4, 0.8, 4.0, 0.8, o_win]]
			holes.append([Rect2(-1.5, WH_PL, 3.0, 4.2), true])
		for op in ops:
			holes.append(_arch_hole(op[0], op[1], op[2], op[3], op[4]))
		_wall(pk, kit, "brick", p0, along, out, -hx, hx, WH_PL, eave, holes, BRICK, WH_T)
		for op in ops:
			_arch_open(pk, kit, "brick", p0, along, out, op[0], op[1], op[2], op[3], op[4], WH_T, BRICK, op[5])
		_band(pk, kit, "brick", p0, along, out, -hx + 0.0, -hx + 0.7, WH_PL - 0.04, eave - 1.25, 0.18, BRICK_DARK, 0.0)
		_band(pk, kit, "brick", p0, along, out, hx - 0.7, hx, WH_PL - 0.04, eave - 1.25, 0.18, BRICK_DARK, 0.0)
		_band(pk, kit, "ashlar", p0, along, out, -hx, hx, WH_PL - 0.02, WH_PL + 0.3, 0.1, SAND, 0.0)
		if e < 0.0:
			# The rope gable's door: boarded leaves under a steel lintel, two steps.
			var bas := Basis(along, UP, out)
			for sx in [-0.75, 0.75]:
				_box(pk, kit, "painted", wf * Vector3(sx, WH_PL + 2.1, -0.32), bas, Vector3(1.48, 4.2, 0.08), DOOR_GREEN)
				for k in range(3):
					_box(pk, kit, "painted", wf * Vector3(sx, WH_PL + 0.6 + 1.5 * float(k), -0.26), bas, Vector3(1.3, 0.12, 0.04), DOOR_GREEN.darkened(0.25))
			_box(pk, kit, "steel", wf * Vector3(0, WH_PL + 4.35, 0.05), bas, Vector3(3.6, 0.3, 0.1), STEEL_DARK)
			for k in range(1, 4):
				_mblock(pk, kit, "ashlar", Vector3(-1.9 - 0.1 * float(k), -0.4, -hz - 0.25 - 0.32 * float(k)), Vector3(1.9 + 0.1 * float(k), WH_PL - 0.25 * float(k), -hz - 0.25 - 0.32 * float(k - 1)), SAND)
		else:
			# The plaque over the great window.
			var ty: float = 8.4 if v1 else 10.6
			var tw: float = 4.8 if v1 else 5.4
			_band(pk, kit, "ashlar", p0, along, out, -tw, tw, ty, ty + 0.95, 0.12, SAND)
			_band(pk, kit, "ashlar", p0, along, out, -tw - 0.12, tw + 0.12, ty - 0.12, ty + 1.07, 0.06, SAND_DARK)
			_lbl(labels, text, p0 + UP * (ty + 0.475) + out * 0.15, out, 0.42 if v1 else 0.48, CARVED, tw * 2.0 - 0.4)
		# The gable over the cornice: plain under a verge (variant 0) or stepped over the roof (variant 1).
		if v1:
			# The stepped gable stops 1cm short of the long walls' planes (they run on up to the roof beside it).
			var gx: float = hx - 0.01
			var ol := PackedVector2Array([Vector2(-gx, eave)])
			var n_st := 4
			var s: float = hx / (float(n_st) + 0.5)
			var tops: Array = []
			for i in range(n_st):
				var xi: float = -hx + s * float(i + 1)
				tops.append(eave + WH_RL + (xi + hx) * sl + 0.6)
			for i in range(n_st):
				var xa: float = -hx + s * float(i)
				ol.append(Vector2(maxf(xa, -gx), tops[i]))
				ol.append(Vector2(xa + s, tops[i]))
			var top_y: float = ridge + 0.9
			ol.append(Vector2(-s * 0.5, top_y))
			ol.append(Vector2(s * 0.5, top_y))
			for i in range(n_st - 1, -1, -1):
				var xb: float = hx - s * float(i)
				ol.append(Vector2(xb - s, tops[i]))
				ol.append(Vector2(minf(xb, gx), tops[i]))
			ol.append(Vector2(gx, eave))
			# The outline as built runs clockwise: reverse it for the prism.
			var olr := PackedVector2Array()
			for k in range(ol.size() - 1, -1, -1):
				olr.append(ol[k])
			KT._prism(pk, kit, "brick", wf, olr, -WH_T, 0.0, BRICK, Vector2(0, 1), true)
			var bas2 := Basis(along, UP, out)
			for i in range(n_st):
				for m in [-1.0, 1.0]:
					var xc: float = m * (hx - s * (float(i) + 0.5))
					_box(pk, kit, "ashlar", wf * Vector3(xc, float(tops[i]) + 0.08, -WH_T * 0.5), bas2, Vector3(s + 0.12, 0.16, WH_T + 0.14), SAND)
			_box(pk, kit, "ashlar", wf * Vector3(0, top_y + 0.08, -WH_T * 0.5), bas2, Vector3(s + 0.12, 0.16, WH_T + 0.14), SAND)
			_box(pk, kit, "ashlar", wf * Vector3(0, top_y + 0.5, -WH_T * 0.5), bas2, Vector3(0.36, 0.7, 0.36), SAND)
			KT._circle_ring(pk, kit, "ashlar", wf, Vector2(0, eave + 2.0), 0.55, 0.82, 0.0, 0.08, SAND)
			_glass(pk, kit, wf * Vector3(0, eave + 2.0, 0.03), along, out, 0.85, 0.85)
		else:
			var poly := PackedVector2Array([Vector2(-hx, eave), Vector2(hx, eave), Vector2(hx, eave + WH_RL - 0.06), Vector2(0, ridge - 0.1), Vector2(-hx, eave + WH_RL - 0.06)])
			_wpoly(pk, kit, "brick", p0, along, out, poly, BRICK)
			KT._circle_ring(pk, kit, "ashlar", wf, Vector2(0, eave + 2.3), 0.85, 1.2, 0.0, 0.08, SAND)
			_glass(pk, kit, wf * Vector3(0, eave + 2.3, 0.03), along, out, 1.3, 1.3)
			# A sandstone coping under the verge along both rakes, meeting under a block at the apex.
			for m in [-1.0, 1.0]:
				var a := Vector3(m * (hx + 0.05), eave + WH_RL - 0.02, 0)
				var b := Vector3(m * 0.3, ridge - 0.02 - 0.3 * sl, 0)
				pk.beam(kit, "ashlar", wf * (a + Vector3(0, 0, 0.06)), wf * (b + Vector3(0, 0, 0.06)), 0.3, 0.12, SAND, along.cross(UP))
			_box(pk, kit, "ashlar", wf * Vector3(0, ridge - 0.2, 0.07), Basis(along, UP, out), Vector3(0.7, 0.4, 0.16), SAND)
	# The roof (and in variant 0 its verges over the gables).
	var oh := 0.55
	if v1:
		_gable_roof_z(pk, kit, "kslate", 0.0, hx, -hz + WH_T * 0.5, hz - WH_T * 0.5, eave + WH_RL, ridge, oh, SLATE)
	else:
		_gable_roof_z(pk, kit, "kslate", 0.0, hx, -hz - 0.35, hz + 0.35, eave + WH_RL, ridge, oh, SLATE)
	var rz: float = hz - WH_T * 0.5 if v1 else hz + 0.4
	pk.beam(kit, "steel", Vector3(0, ridge + 0.04, -rz), Vector3(0, ridge + 0.04, rz), 0.3, 0.1, Color(0.2, 0.2, 0.22))
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(sx * (hx + oh + 0.05), eave + WH_RL - (oh + 0.05) * sl, -rz), Vector3(sx * (hx + oh + 0.05), eave + WH_RL - (oh + 0.05) * sl, rz), 0.11, 0.11, 6,
				STEEL_DARK, true)
		for sz in [-1.0, 1.0]:
			var dp := Vector3(sx * (hx + 0.2), 0, sz * (hz - 0.9))
			pk.tube(kit, "steel", dp + Vector3(sx * (oh - 0.15), eave + WH_RL - oh * sl - 0.1, 0), dp + Vector3(0, eave - 0.7, 0), 0.07, 0.07, 6, STEEL_DARK, false)
			pk.tube(kit, "steel", dp + Vector3(0, eave - 0.7, 0), dp + Vector3(0, 0.3, 0), 0.07, 0.07, 6, STEEL_DARK, true)
	# The roof lantern (variant 0) or a louvred ventilator (variant 1) on the ridge.
	if v1:
		_ventilator(pk, kit, Vector3(0, ridge - 0.6, 0), 0.9, 2.2)
	else:
		var lz := 6.0
		var ly0: float = ridge - 1.3 * sl - 0.2
		var ly1: float = ridge + 1.4
		for sx in [-1.0, 1.0]:
			var out := Vector3(sx, 0, 0)
			_mq(pk, kit, "painted", Vector3(sx * 1.3, 0, 0), UP.cross(out), out, -lz, lz, ly0, ly1, Color(0.24, 0.3, 0.27))
			for k in range(8):
				var yy: float = ly0 + 0.6 + float(k) * 0.24
				if yy > ly1 - 0.15:
					break
				_box(pk, kit, "painted", Vector3(sx * 1.36, yy, 0), Basis(Vector3(0, 0, 1), UP, out), Vector3(lz * 2.0 - 0.6, 0.06, 0.08),
						Color(0.2, 0.26, 0.23))
			for k in range(5):
				var zz: float = -lz + 0.1 + float(k) * (lz * 2.0 - 0.2) / 4.0
				_box(pk, kit, "painted", Vector3(sx * 1.38, (ly0 + ly1) * 0.5, zz), Basis(), Vector3(0.1, ly1 - ly0, 0.16), Color(0.28, 0.34, 0.3))
		for e2 in [-1.0, 1.0]:
			_wpoly(pk, kit, "painted", Vector3(0, 0, e2 * lz), Vector3(e2, 0, 0), Vector3(0, 0, e2),
					PackedVector2Array([Vector2(-1.3, ly0), Vector2(1.3, ly0), Vector2(1.3, ly1), Vector2(0, ly1 + 0.85), Vector2(-1.3, ly1)]), Color(0.24, 0.3, 0.27))
		_gable_roof_z(pk, kit, "kslate", 0.0, 1.3, -lz - 0.3, lz + 0.3, ly1, ly1 + 0.85, 0.3, SLATE)


## A louvred ventilator turret on a ridge: a square box (half `r`) of slatted sides `h` tall from `base`, a slate pyramid
## and a finial.
static func _ventilator(pk: PropKit, kit: Dictionary, base: Vector3, r: float, h: float) -> void:
	var col := Color(0.24, 0.3, 0.27)
	_mblock(pk, kit, "painted", base + Vector3(-r, 0, -r), base + Vector3(r, h, r), col, false)
	for out in [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]:
		var al: Vector3 = UP.cross(out)
		for k in range(6):
			_box(pk, kit, "painted", base + out * (r + 0.04) + UP * (0.5 + float(k) * 0.26), Basis(al, UP, out), Vector3(r * 2.0 - 0.2, 0.06, 0.08), col.darkened(0.25))
	_pyramid(pk, kit, "kslate", base, r + 0.25, r + 0.25, h, h + r * 1.4, SLATE, true)
	pk.tube(kit, "steel", base + Vector3(0, h + r * 1.35, 0), base + Vector3(0, h + r * 1.4 + 0.8, 0), 0.05, 0.02, 6, STEEL_DARK, true)


## The rope openings' middles on a winding house's -z gable (in its frame), where a rope from a sheave comes in.
static func winding_house_rope_inlets(variant := 0) -> Array:
	if variant == 1:
		return [Vector3(-1.7, 7.6, -11.0), Vector3(1.7, 7.6, -11.0)]
	return [Vector3(-2.0, 10.2, -15.0), Vector3(2.0, 10.2, -15.0)]


# ======================================================================================
#  The Lohnhalle and the Kaue
# ======================================================================================

const LH_HX := 45.0
const LH_HZ := 9.0
const LH_PL := 1.2
const LH_EAVE := 12.0        # the cornice's top
const LH_ROOF_Y := 12.0      # the hipped roof's eave line (0.6 out)
const LH_PITCH := 0.75
const LH_RIS_X := 9.0        # the risalit's half width
const LH_RIS_Z := 11.0       # its front
const LH_RIS_TOP := 14.2
const LH_RIS_RIDGE := 18.6
const LH_TW := 3.2           # the tower's half width
const LH_TZ := 2.0           # the tower's middle (z)


## The Lohnhalle (pay hall, west wing) and the Kaue (wash house, east wing) as one long brick building along x, centred:
## x ±45, z ±9, on an ashlar plinth to 1.2, cornice at 12, a slate hipped roof to 19.2 with dormers and chimneys. The
## central risalit (x ±9) stands out to z 11 with the portal (steps to z 13.2), ZECHE KRONPRINZ on a sandstone tablet
## over it, its own gable to 18.6 with 1871 and an oculus; behind it the clock tower (x ±3.2, z -1.2..5.2) with clocks on
## all four sides (centres 27.1 up), louvred belfry openings, a corbel table and a slate helm to 39.6 and a gilt finial to
## 41.4. The pay
## hall's tall arched windows, the wash house's high windows over small ones, and a door at each wing's end bay under
## LOHNHALLE and KAUE. Footprint x ±45.6 (the roof), z -9.6..13.2.
static func lohnhalle(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	_mblock(pk, kit, "ashlar", Vector3(-LH_HX - 0.25, -2.0, -LH_HZ - 0.25), Vector3(LH_HX + 0.25, LH_PL, LH_HZ + 0.25), SAND_DARK)
	_mblock(pk, kit, "ashlar", Vector3(-LH_RIS_X - 0.25, -2.0, LH_HZ + 0.25), Vector3(LH_RIS_X + 0.25, LH_PL, LH_RIS_Z + 0.25), SAND_DARK)
	for k in range(1, 7):
		var top: float = LH_PL - 0.2 * float(k)
		_mblock(pk, kit, "ashlar", Vector3(-3.0 - 0.12 * float(k), -0.4, LH_RIS_Z + 0.25 + 0.32 * float(k - 1)), Vector3(3.0 + 0.12 * float(k), top, LH_RIS_Z + 0.25 + 0.32 * float(k)), SAND)
	var trim := {"trim": "ashlar", "trim_w": 0.3, "keystone": true, "trim_col": SAND}
	var seg := {"trim": "brick", "trim_w": 0.24, "trim_col": BRICK_DARK, "segs": 6}
	var wall_top: float = LH_ROOF_Y + 0.6 * LH_PITCH - 0.06
	# The front: two wings either side of the risalit.
	var front_ops: Array = []
	for k in range(6):
		var cu: float = -42.0 + 6.0 * float(k)
		if k == 0:
			front_ops.append([cu, LH_PL, 1.1, 2.8, 1.1, {"trim": "ashlar", "trim_w": 0.35, "keystone": true, "trim_col": SAND, "door": DOOR_GREEN, "sill": false}])
			front_ops.append([cu, 7.2, 0.8, 1.8, 0.8, trim])
		else:
			front_ops.append([cu, 2.0, 1.25, 6.2, 1.25, trim])
	for k in range(6):
		var cu2: float = 12.0 + 6.0 * float(k)
		if k == 5:
			front_ops.append([cu2, LH_PL, 1.1, 2.8, 1.1, {"trim": "ashlar", "trim_w": 0.35, "keystone": true, "trim_col": SAND, "door": DOOR_GREEN, "sill": false}])
			front_ops.append([cu2, 7.2, 0.8, 1.8, 0.8, trim])
		else:
			front_ops.append([cu2, 4.4, 1.15, 4.6, 1.15, trim])
			front_ops.append([cu2, 2.0, 0.6, 1.3, 0.3, seg])
	var p0f := Vector3(0, 0, LH_HZ)
	var holes: Array = []
	for op in front_ops:
		holes.append(_arch_hole(op[0], op[1], op[2], op[3], op[4]))
	_wall(pk, kit, "brick", p0f, Vector3.RIGHT, Vector3.BACK, -LH_HX, -LH_RIS_X, LH_PL, wall_top, holes.filter(func(h): return (h[0] as Rect2).position.x < 0.0), BRICK, 0.6)
	_wall(pk, kit, "brick", p0f, Vector3.RIGHT, Vector3.BACK, LH_RIS_X, LH_HX, LH_PL, wall_top, holes.filter(func(h): return (h[0] as Rect2).position.x > 0.0), BRICK, 0.6)
	for op in front_ops:
		_arch_open(pk, kit, "brick", p0f, Vector3.RIGHT, Vector3.BACK, op[0], op[1], op[2], op[3], op[4], 0.6, BRICK, op[5])
	for side in [[-42.0, "LOHNHALLE"], [42.0, "KAUE"]]:
		var tx: float = side[0]
		_band(pk, kit, "ashlar", p0f, Vector3.RIGHT, Vector3.BACK, tx - 2.0, tx + 2.0, 5.85, 6.7, 0.12, SAND)
		_lbl(labels, side[1], p0f + Vector3(tx, 6.275, 0.15), Vector3.BACK, 0.42, CARVED, 3.6)
		for lx in [-1.6, 1.6]:
			_wall_lantern(pk, kit, p0f + Vector3(tx + lx, 4.4, 0), Vector3.BACK)
	# The back, the ends.
	var back_ops: Array = []
	for k in range(15):
		var cu3: float = -42.0 + 6.0 * float(k)
		back_ops.append([cu3, 2.4, 1.0, 2.6, 0.4, seg])
		back_ops.append([cu3, 7.4, 1.0, 2.6, 0.4, seg])
	_wall_ops(pk, kit, Vector3(0, 0, -LH_HZ), Vector3.LEFT, Vector3.FORWARD, -LH_HX, LH_HX, LH_PL, wall_top, back_ops, 0.6)
	for sx in [-1.0, 1.0]:
		var end_ops: Array = []
		for k in range(3):
			var cu4: float = -6.0 + 6.0 * float(k)
			end_ops.append([cu4, 2.4, 1.0, 2.6, 0.4, seg])
			end_ops.append([cu4, 7.4, 1.0, 2.6, 0.4, seg])
		_wall_ops(pk, kit, Vector3(sx * LH_HX, 0, 0), UP.cross(Vector3(sx, 0, 0)), Vector3(sx, 0, 0), -LH_HZ, LH_HZ, LH_PL, wall_top, end_ops, 0.6)
	# Lisenes on the front and the back, a sandstone band on the plinth, the cornice round the whole block.
	for k in range(16):
		var lx2: float = -45.0 + 6.0 * float(k)
		var ua: float = lx2 - 0.35
		var ub: float = lx2 + 0.35
		if k == 0:
			ua = -45.18
			ub = -44.3
		elif k == 15:
			ua = 44.3
			ub = 45.18
		if absf(lx2) > LH_RIS_X + 0.3:
			_band(pk, kit, "brick", p0f, Vector3.RIGHT, Vector3.BACK, ua, ub, LH_PL - 0.04, 11.3, 0.18, BRICK_DARK, 0.0)
		_band(pk, kit, "brick", Vector3(0, 0, -LH_HZ), Vector3.LEFT, Vector3.FORWARD, -ub, -ua, LH_PL - 0.04, 11.3, 0.18, BRICK_DARK, 0.0)
	for side_z in [[p0f, Vector3.RIGHT, Vector3.BACK], [Vector3(0, 0, -LH_HZ), Vector3.LEFT, Vector3.FORWARD]]:
		_band(pk, kit, "ashlar", side_z[0], side_z[1], side_z[2], -LH_HX - 0.1, LH_HX + 0.1, LH_PL - 0.02, LH_PL + 0.3, 0.1, SAND, 0.0)
	for sx in [-1.0, 1.0]:
		_band(pk, kit, "ashlar", Vector3(sx * LH_HX, 0, 0), UP.cross(Vector3(sx, 0, 0)), Vector3(sx, 0, 0), -LH_HZ, LH_HZ, LH_PL - 0.02, LH_PL + 0.3, 0.1, SAND, 0.0)
	_cornice(pk, kit, "brick", Vector3.ZERO, LH_HX, LH_HZ, 11.4, [Vector2(0.15, 0.2), Vector2(0.28, 0.2), Vector2(0.42, 0.2)], BRICK_DARK, 0.3)
	_lohnhalle_risalit(pk, kit, labels, trim)
	# The hipped roof, its dormers and chimneys.
	_hip_roof(pk, kit, "kslate", Vector3.ZERO, LH_HX + 0.6, LH_HZ + 0.6, LH_ROOF_Y, LH_PITCH, SLATE)
	for e in [1.0, -1.0]:
		for dx in [-39.0, -27.0, -15.0, 15.0, 27.0, 39.0]:
			_dormer(pk, kit, dx, e)
	for cx in [-30.0, 30.0]:
		_mblock(pk, kit, "brick", Vector3(cx - 0.5, 17.6, -1.3), Vector3(cx + 0.5, 21.2, 1.3), BRICK)
		_cornice(pk, kit, "brick", Vector3(cx, 0, 0), 0.5, 1.3, 20.7, [Vector2(0.1, 0.2), Vector2(0.06, 0.15)], BRICK_DARK, 0.0)
		for pz in [-0.6, 0.6]:
			pk.tube(kit, "matte", Vector3(cx, 21.0, pz), Vector3(cx, 21.5, pz), 0.18, 0.16, 8, Color(0.42, 0.24, 0.16), true)
	_lohnhalle_tower(pk, kit)


## A wall with arched openings `ops` ([cu, v0, half, hs, rise, options]), the openings' arches and glass.
static func _wall_ops(pk: PropKit, kit: Dictionary, p0: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v0: float, v1: float, ops: Array, thick: float,
		key := "brick", col := BRICK) -> void:
	var holes: Array = []
	for op in ops:
		holes.append(_arch_hole(op[0], op[1], op[2], op[3], op[4]))
	_wall(pk, kit, key, p0, along, out, u0, u1, v0, v1, holes, col, thick)
	for op in ops:
		_arch_open(pk, kit, key, p0, along, out, op[0], op[1], op[2], op[3], op[4], thick, col, op[5])


## A wall lantern on a scrolled bracket, its foot on the wall at `p`, standing out along `out`.
static func _wall_lantern(pk: PropKit, kit: Dictionary, p: Vector3, out: Vector3) -> void:
	var cast := Color(0.12, 0.13, 0.14)
	_box(pk, kit, "steel", p + out * 0.03, Basis(UP.cross(out), UP, out), Vector3(0.18, 0.4, 0.06), cast)
	pk.beam(kit, "steel", p + out * 0.05 + UP * 0.12, p + out * 0.55 + UP * 0.12, 0.04, 0.04, cast)
	pk.beam(kit, "steel", p + out * 0.05 - UP * 0.12, p + out * 0.45 + UP * 0.1, 0.03, 0.03, cast)
	YK.lantern(pk, kit, p + out * 0.55 + UP * 0.12 - UP * 0.62, 0.7, true)


## A gabled dormer on the Lohnhalle's front (e = 1) or back (-1) roof over the bay at x = cx: its front 2.4m in from the
## eave line, a cheek either side along the roof, a little slate roof back into the main one, a window.
static func _dormer(pk: PropKit, kit: Dictionary, cx: float, e: float) -> void:
	var zr: float = LH_HZ + 0.6
	var ym := func(z: float) -> float: return LH_ROOF_Y + (zr - z) * LH_PITCH
	var zf := 7.2
	var y0: float = ym.call(zf)
	var ye: float = y0 + 1.6
	var yr: float = ye + 0.85
	var hw := 0.9
	var zbe: float = zr - (ye - LH_ROOF_Y) / LH_PITCH
	var zbr: float = zr - (yr - LH_ROOF_Y) / LH_PITCH
	var zm := func(z: float) -> float: return z * e
	var out := Vector3(0, 0, e)
	var along: Vector3 = UP.cross(out)
	var p0 := Vector3(cx, 0, zm.call(zf))
	var col := Color(0.86, 0.84, 0.78)
	_wpoly(pk, kit, "kslate", p0, along, out, PackedVector2Array([Vector2(-hw, y0 - 0.12), Vector2(hw, y0 - 0.12), Vector2(hw, ye), Vector2(0, yr - 0.08), Vector2(-hw, ye)]), SLATE)
	_glass(pk, kit, p0 + out * 0.03 + UP * (y0 + 0.75), along, out, 1.05, 1.05)
	var bas := Basis(along, UP, out)
	for sv in [-1.0, 1.0]:
		_box(pk, kit, "painted", p0 + out * 0.06 + UP * (y0 + 0.75) + along * (sv * 0.6), bas, Vector3(0.14, 1.3, 0.08), col.darkened(0.08))
		_box(pk, kit, "painted", p0 + out * 0.06 + UP * (y0 + 0.75 + sv * 0.6), bas, Vector3(1.37, 0.14, 0.09), col.darkened(0.08))
	# The cheeks (slate-hung) along the roof's line.
	for sx in [-1.0, 1.0]:
		var co := Vector3(sx, 0, 0)
		var cheek := PackedVector3Array([Vector3(cx + sx * hw, y0 - 0.12, zm.call(zf)), Vector3(cx + sx * hw, ye, zm.call(zf)), Vector3(cx + sx * hw, ye, zm.call(zbe))])
		pk.tri(kit, "kslate", cheek[0], cheek[1], cheek[2], co, co, co, SLATE, co, Vector2(zf, y0) * uvk, Vector2(zf, ye) * uvk, Vector2(zbe, ye) * uvk)
	# The roof: from its eave over the front back to where it meets the main roof.
	var oh := 0.15
	var sl: float = (yr - ye) / hw
	for sx in [-1.0, 1.0]:
		var ea := Vector3(cx + sx * (hw + oh), ye - oh * sl, zm.call(zf + 0.3))
		var eb := Vector3(cx + sx * (hw + oh), ye - oh * sl, zm.call(zbe - 0.1))
		var ra := Vector3(cx, yr, zm.call(zf + 0.3))
		var rb := Vector3(cx, yr, zm.call(zbr))
		SW._roof(pk, kit, "kslate", ea, eb, rb, ra, SLATE, Vector3(sx * sl, 1, 0).normalized())


static func _lohnhalle_risalit(pk: PropKit, kit: Dictionary, labels: Array, trim: Dictionary) -> void:
	var p0 := Vector3(0, 0, LH_RIS_Z)
	var ops: Array = [[0.0, LH_PL, 1.8, 3.4, 1.8, {"trim": "ashlar", "trim_w": 0.5, "keystone": true, "trim_col": SAND, "door": DOOR_GREEN, "sill": false, "segs": 12}],
			[-5.5, 2.0, 0.9, 3.6, 0.9, trim], [5.5, 2.0, 0.9, 3.6, 0.9, trim]]
	for u in [-4.5, 0.0, 4.5]:
		ops.append([u, 9.6, 0.8, 2.2, 0.8, trim])
	_wall_ops(pk, kit, p0, Vector3.RIGHT, Vector3.BACK, -LH_RIS_X, LH_RIS_X, LH_PL, LH_RIS_TOP, ops, 0.7)
	for u in [-8.65, -2.95, 2.95, 8.65]:
		var ua: float = u - 0.35
		var ub: float = u + 0.35
		if u < -8.0:
			ua = -LH_RIS_X - 0.18
		elif u > 8.0:
			ub = LH_RIS_X + 0.18
		_band(pk, kit, "ashlar", p0, Vector3.RIGHT, Vector3.BACK, ua, ub, LH_PL - 0.04, 13.3, 0.18, SAND, 0.0)
	_band(pk, kit, "ashlar", p0, Vector3.RIGHT, Vector3.BACK, -7.2, 7.2, 7.75, 9.05, 0.26, SAND)
	_band(pk, kit, "ashlar", p0, Vector3.RIGHT, Vector3.BACK, -7.35, 7.35, 7.6, 9.2, 0.22, SAND_DARK)
	_lbl(labels, "ZECHE KRONPRINZ", p0 + Vector3(0, 8.4, 0.29), Vector3.BACK, 0.95, CARVED, 14.0)
	for lx in [-2.7, 2.7]:
		_wall_lantern(pk, kit, p0 + Vector3(lx, 4.6, 0.18), Vector3.BACK)
	# The side walls and the cheeks over the main roof up to the risalit's roof.
	for sx in [-1.0, 1.0]:
		var out := Vector3(sx, 0, 0)
		var zb: float = (LH_HZ + 0.6) - (LH_RIS_TOP - 0.05 - LH_ROOF_Y) / LH_PITCH
		var poly := PackedVector2Array()
		var pts: Array = [Vector2(LH_RIS_Z, LH_PL), Vector2(LH_RIS_Z, LH_RIS_TOP - 0.05), Vector2(zb, LH_RIS_TOP - 0.05),
				Vector2(LH_HZ, LH_ROOF_Y + 0.6 * LH_PITCH - 0.02), Vector2(LH_HZ, LH_PL)]
		for q in pts:
			var qq: Vector2 = q
			poly.append(Vector2(qq.x * sx * -1.0 if sx > 0.0 else qq.x, qq.y))
		_wpoly(pk, kit, "brick", Vector3(sx * LH_RIS_X, 0, 0), UP.cross(out), out, poly, BRICK)
	_cornice(pk, kit, "brick", Vector3(0, 0, (LH_HZ + LH_RIS_Z) * 0.5 - 0.5), LH_RIS_X, (LH_RIS_Z - LH_HZ) * 0.5 + 0.5, 13.3,
			[Vector2(0.15, 0.2), Vector2(0.28, 0.2), Vector2(0.42, 0.2)], BRICK_DARK, 0.3)
	# The gable: an oculus over the year.
	var top: float = LH_RIS_TOP
	var gpoly := PackedVector2Array([Vector2(-LH_RIS_X, top), Vector2(LH_RIS_X, top), Vector2(0, LH_RIS_RIDGE - 0.1)])
	_wpoly(pk, kit, "brick", p0, Vector3.RIGHT, Vector3.BACK, gpoly, BRICK)
	var wf := _wf(p0, Vector3.RIGHT, Vector3.BACK)
	_band(pk, kit, "ashlar", p0, Vector3.RIGHT, Vector3.BACK, -1.0, 1.0, 14.7, 15.4, 0.1, SAND)
	_lbl(labels, "1871", p0 + Vector3(0, 15.05, 0.13), Vector3.BACK, 0.45, CARVED, 1.8)
	KT._circle_ring(pk, kit, "ashlar", wf, Vector2(0, 16.45), 0.55, 0.82, 0.0, 0.08, SAND)
	_glass(pk, kit, wf * Vector3(0, 16.45, 0.03), Vector3.RIGHT, Vector3.BACK, 0.85, 0.85)
	var gsl: float = (LH_RIS_RIDGE - top) / LH_RIS_X
	for m in [-1.0, 1.0]:
		pk.beam(kit, "ashlar", Vector3(m * (LH_RIS_X + 0.05), top - 0.02, LH_RIS_Z + 0.06), Vector3(m * 0.3, LH_RIS_RIDGE - 0.02 - 0.3 * gsl, LH_RIS_Z + 0.06), 0.3, 0.12, SAND,
				Vector3(0, 0, 1).cross(UP))
	_box(pk, kit, "ashlar", Vector3(0, LH_RIS_RIDGE - 0.2, LH_RIS_Z + 0.07), Basis(), Vector3(0.7, 0.4, 0.16), SAND)
	# The risalit's roof back to the valleys where it meets the main roof.
	var sl: float = (LH_RIS_RIDGE - top) / LH_RIS_X
	var ex: float = LH_RIS_X + 0.45
	var ey: float = top - 0.45 * sl
	var ym_inv := func(y: float) -> float: return (LH_HZ + 0.6) - (y - LH_ROOF_Y) / LH_PITCH
	var zf: float = LH_RIS_Z + 0.35
	for sx in [-1.0, 1.0]:
		var a := Vector3(sx * ex, ey, zf)
		var b := Vector3(sx * ex, ey, ym_inv.call(ey))
		var c := Vector3(0, LH_RIS_RIDGE, ym_inv.call(LH_RIS_RIDGE))
		var d := Vector3(0, LH_RIS_RIDGE, zf)
		var n := Vector3(sx * sl, 1, 0).normalized()
		var uv: Array = [Vector2(zf, 0) * uvk, Vector2(b.z, 0) * uvk, Vector2(c.z, ex * 1.1) * uvk, Vector2(zf, ex * 1.1) * uvk]
		pk.quad(kit, "kslate", [a, b, c, d], n, SLATE, uv)
		var dn := Vector3(0, -0.04, 0)
		pk.quad(kit, "kslate", [a + dn, b + dn, c + dn, d + dn], -n, SLATE.darkened(0.4), uv)


static func _lohnhalle_tower(pk: PropKit, kit: Dictionary) -> void:
	var c := Vector3(0, 0, LH_TZ)
	var tw := LH_TW
	var top := 30.2
	for out in [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]:
		var along: Vector3 = UP.cross(out)
		var p0: Vector3 = c + out * tw
		var ops: Array = [[0.0, 21.4, 0.8, 2.6, 0.8, {"trim": "ashlar", "trim_w": 0.3, "keystone": true, "trim_col": SAND, "dark": true}]]
		_wall_ops(pk, kit, p0, along, out, -tw, tw, 12.0, top, ops, 0.5)
		var bas := Basis(along, UP, out)
		for k in range(7):
			_box(pk, kit, "painted", p0 + UP * (21.8 + 0.42 * float(k)) - out * 0.3, bas.rotated(along, -0.5), Vector3(1.55, 0.05, 0.36), Color(0.22, 0.27, 0.24))
		# Corner lisenes: those on ±z wrap round the corner over the ends of those on ±x.
		var wrap: float = 0.18 if absf(out.z) > 0.5 else 0.0
		for lu in [-tw + 0.35, tw - 0.35]:
			_band(pk, kit, "ashlar", p0, along, out, lu - 0.35 - (wrap if lu < 0.0 else 0.0), lu + 0.35 + (wrap if lu > 0.0 else 0.0), 12.0, 28.8, 0.18, SAND, 0.0)
		_band(pk, kit, "ashlar", p0, along, out, -tw + 0.7, tw - 0.7, 20.6, 20.95, 0.12, SAND)
		_frieze(pk, kit, "brick", p0, along, out, -tw + 0.7, tw - 0.7, 29.6, 0.7, 0.8, 0.1, BRICK_DARK)
		KT._circle_ring(pk, kit, "ashlar", _wf(p0, along, out), Vector2(0, 27.1), 1.36, 1.65, 0.0, 0.1, SAND)
		YK.clock_face(pk, kit, p0 + UP * 27.1, out, 1.15, 10.1, 8.6)
		pk.tube(kit, "gold", p0 + UP * 27.1 + out * 0.09, p0 + UP * 27.1 + out * 0.15, 0.13, 0.13, 10, Color(0.85, 0.66, 0.25), true)
	_cornice(pk, kit, "ashlar", c, tw, tw, top - 0.1, [Vector2(0.2, 0.15), Vector2(0.35, 0.15), Vector2(0.48, 0.2)], SAND, 0.4)
	var base_y: float = top + 0.4
	_mblock(pk, kit, "brick", c + Vector3(-tw, top, -tw), c + Vector3(tw, base_y, tw), BRICK_DARK, false)
	var apex: float = base_y + 9.0
	_pyramid(pk, kit, "kslate", c, tw + 0.55, tw + 0.55, base_y, apex, SLATE, true)
	pk.tube(kit, "gold", c + Vector3(0, apex - 0.2, 0), c + Vector3(0, apex + 0.8, 0), 0.08, 0.05, 8, Color(0.85, 0.66, 0.25), true)
	pk.lathe(kit, "gold", c + Vector3(0, apex + 0.8, 0), [Vector2(0.001, -0.3), Vector2(0.21, -0.2), Vector2(0.3, 0.0), Vector2(0.21, 0.2), Vector2(0.001, 0.3)], 10,
			Color(0.88, 0.70, 0.28))
	pk.tube(kit, "gold", c + Vector3(0, apex + 1.1, 0), c + Vector3(0, apex + 1.8, 0), 0.04, 0.01, 6, Color(0.85, 0.66, 0.25), true)


# ======================================================================================
#  The coal washer (Kohlenwäsche): the lap drives through its ground floor
# ======================================================================================

const KW_HX := 20.0
const KW_HZ := 17.0
const KW_PASS := 7.5          # the passage's clear half width: nothing within |x| <= 7.5 from y 0 to 7.0
const KW_CLEAR := 7.0         # the passage's clear height
const KW_COL_IN := 7.8        # the passage columns' inner faces
const KW_GF := 8.6            # the ground floor's ceiling (the slab's underside), the bunker band's foot
const KW_EDGE_BOT := 7.5      # the passage's edge beams' undersides
const KW_BEAM_BOT := 7.6      # the passage's cross beams' undersides
const KW_PORTAL_BOT := 7.35   # the portal lintels' undersides
const KW_BAND_TOP := 12.4     # the concrete bunker band's top, the cladding's foot
const KW_EAVE := 26.5
const KW_RIDGE := 28.0
const KW_TOWER := Rect2(-20.0, -17.0, 14.0, 18.0)   # the raw-coal tower in plan (x, z, w, d)
const KW_TOWER_TOP := 35.0
const KW_ROWS := [-16.6, -11.07, -5.53, 0.0, 5.53, 11.07, 16.6]   # the column rows along z
const GALLERY_W := 3.2
const KW_CONC := Color(0.58, 0.57, 0.54)


## The coal washer (Kohlenwäsche), the stage's drive-through: centred, the passage along z through its middle. A concrete
## ground floor (to 8.6) whose middle is an open passage the length of the building: NOTHING within |x| <= 7.5 from y = 0
## to y = 7.0 for its whole depth (z -17..17); columns either side (inner faces |x| = 7.8) with hazard-striped feet, walls
## with doors and windows set back between them (|x| 8.5), and over the passage a ceiling of edge beams (undersides 7.5),
## cross beams (7.6), portal lintels at both ends (7.35, hazard-striped) and between them twelve steel bunker hoppers with
## slide gates and chutes (lowest point 7.2), pipes and cable trays (lowest 7.85) and pendant lamps (lit, lowest 7.6).
## Over it the concrete bunker band (8.6..12.4, standing 0.15 out) and the steel-framed hall clad in corrugated iron with two
## ribbon windows round it, eaves 26.5 under a low roof to 28; the raw-coal tower (x -20..-6, z -17..1) rises to 35 (roof
## 36). KOHLENWÄSCHE on painted boards on the ±z faces (y 23.3..25.7), ZECHE KRONPRINZ on the tower's -z face. Two gallery
## stubs come in high up (coal_washer_stubs: continue them with conveyor_gallery). Footprint x ±20.3 (the stubs to -29 and
## 28), z ±17.2.
static func coal_washer(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	_kw_ground_floor(pk, kit)
	_kw_passage_ceiling(pk, kit)
	_kw_upper(pk, kit, labels)
	for s in coal_washer_stubs():
		conveyor_gallery(pk, kit, s["end"], s["inner"], s["width"])


## The gallery stubs: {"end": the stub's outer end (the gallery floor's middle), "dir": horizontal, outward, "slope": the
## rise per metre continuing outward, "width"; "inner": where it ends inside the building}. A conveyor_gallery from a point
## on the line end + dir * t + UP * slope * t back to "end" continues one seamlessly.
static func coal_washer_stubs() -> Array:
	return [
		{"end": Vector3(-29.0, 28.4 - 9.0 * 0.25 + 0.0, -8.0), "inner": Vector3(-19.7, 28.4 + 0.3 * 0.25, -8.0), "dir": Vector3.LEFT, "slope": -0.25, "width": GALLERY_W},
		{"end": Vector3(28.0, 17.3 - 8.0 * 0.15, 8.0), "inner": Vector3(19.7, 17.3 + 0.3 * 0.15, 8.0), "dir": Vector3.RIGHT, "slope": -0.15, "width": GALLERY_W},
	]


static func _kw_ground_floor(pk: PropKit, kit: Dictionary) -> void:
	var cw := 0.4
	# The passage columns (to the slab), hazard stripes round their feet on the passage side.
	for sx in [-1.0, 1.0]:
		for zc in KW_ROWS:
			var lo := Vector3(minf(sx * KW_COL_IN, sx * (KW_COL_IN + 0.8)), 0.0, float(zc) - cw)
			var hi := Vector3(maxf(sx * KW_COL_IN, sx * (KW_COL_IN + 0.8)), KW_GF, float(zc) + cw)
			_mblock(pk, kit, "concrete", lo - Vector3(0, 1.0, 0), hi, CONC, false)
			_box(pk, kit, "hazard", Vector3(sx * (KW_COL_IN + 0.0), 0.8, zc), Basis(), Vector3(0.06, 1.6, cw * 2.0 + 0.04), WHITE)
			# A bulkhead lamp on each column's passage face.
			_box(pk, kit, "steel", Vector3(sx * (KW_COL_IN - 0.1), 5.6, zc), Basis(), Vector3(0.2, 0.32, 0.5), STEEL_DARK)
			_box(pk, kit, "lamp", Vector3(sx * (KW_COL_IN - 0.215), 5.6, zc), Basis(), Vector3(0.03, 0.22, 0.38), Color(1.0, 0.9, 0.7))
	# The passage's side walls between the columns: doors and windows.
	for sx in [-1.0, 1.0]:
		var out := Vector3(-sx, 0, 0)
		var along: Vector3 = UP.cross(out)
		var p0 := Vector3(sx * 8.5, 0, 0)
		for i in range(KW_ROWS.size() - 1):
			var za: float = float(KW_ROWS[i]) + cw
			var zb: float = float(KW_ROWS[i + 1]) - cw
			var ua: float = minf(za * along.z, zb * along.z)
			var ub: float = maxf(za * along.z, zb * along.z)
			var um: float = (ua + ub) * 0.5
			var holes: Array = []
			if i % 2 == 0:
				holes.append([Rect2(um - 0.7, 0.0, 1.4, 2.6), true])
			else:
				holes.append([Rect2(um - 1.3, 2.2, 2.6, 1.6), true])
			_wall(pk, kit, "concrete", p0, along, out, ua, ub, 0.0, KW_EDGE_BOT, holes, CONC_DARK, 0.25)
			var wf := _wf(p0, along, out)
			var bas := Basis(along, UP, out)
			if i % 2 == 0:
				_box(pk, kit, "paint", wf * Vector3(um, 1.3, -0.2), bas, Vector3(1.4, 2.6, 0.06), Color(0.32, 0.38, 0.40))
				_box(pk, kit, "steel", wf * Vector3(um + 0.45, 1.1, -0.15), bas, Vector3(0.18, 0.05, 0.06), STEEL_DARK)
				_box(pk, kit, "paint", wf * Vector3(um, 3.1, 0.05), bas, Vector3(0.9, 0.35, 0.04), Color(0.1, 0.45, 0.2))
			else:
				_rect_window(pk, kit, p0, along, out, um, 2.2, 2.6, 1.6, 0.12, "concrete", CONC)
			# A grey switch cabinet and a conduit on the wall.
			_box(pk, kit, "paint", wf * Vector3(ua + 0.8, 1.6, 0.18), bas, Vector3(0.7, 1.0, 0.3), Color(0.55, 0.57, 0.56))
			pk.tube(kit, "steel", wf * Vector3(ua + 0.8, 2.1, 0.12), wf * Vector3(ua + 0.8, KW_EDGE_BOT, 0.12), 0.03, 0.03, 6, STEEL_DARK, false)
	# The side blocks' outer walls (x ±20) and their faces on ±z beside the portals.
	for sx in [-1.0, 1.0]:
		var out := Vector3(sx, 0, 0)
		var along: Vector3 = UP.cross(out)
		var p0: Vector3 = out * KW_HX
		var holes: Array = []
		for i in range(KW_ROWS.size() - 1):
			var zw: float = (float(KW_ROWS[i]) + float(KW_ROWS[i + 1])) * 0.5
			holes.append([Rect2(zw - 1.1, 2.0, 2.2, 2.8), true])
		_wall(pk, kit, "concrete", p0, along, out, -KW_HZ, KW_HZ, 0.0, KW_GF, holes, KW_CONC, 0.3)
		for h in holes:
			var r: Rect2 = h[0]
			_rect_window(pk, kit, p0, along, out, r.get_center().x, r.position.y, r.size.x, r.size.y, 0.15, "concrete", CONC.lightened(0.05))
		# Pilasters at the column rows (the corner ones end flush with the corner, the ±z faces' wrap round it).
		for zc in KW_ROWS:
			var u: float = float(zc) * along.z
			_band(pk, kit, "concrete", p0, along, out, u - 0.4, u + 0.4, 0.0, KW_GF, 0.2, KW_CONC.darkened(0.06), 0.0)
	for sz in [-1.0, 1.0]:
		var out := Vector3(0, 0, sz)
		var along: Vector3 = UP.cross(out)
		var p0: Vector3 = out * KW_HZ
		for sx in [-1.0, 1.0]:
			# u along `along` (x * sz... along = UP x out: +x for sz = 1, -x for sz = -1).
			var ua: float = minf(sx * 8.6 * along.x, sx * KW_HX * along.x)
			var ub: float = maxf(sx * 8.6 * along.x, sx * KW_HX * along.x)
			var door_u: float = sx * 12.4 * along.x
			var win_u: float = sx * 17.6 * along.x
			var holes: Array = [[Rect2(door_u - 2.0, 0.0, 4.0, 4.6), true], [Rect2(win_u - 1.0, 2.0, 2.0, 2.6), true]]
			_wall(pk, kit, "concrete", p0, along, out, ua, ub, 0.0, KW_GF, holes, KW_CONC, 0.3)
			var pu: float = sx * 15.5 * along.x
			_band(pk, kit, "concrete", p0, along, out, pu - 0.4, pu + 0.4, 0.0, KW_GF, 0.2, KW_CONC.darkened(0.06), 0.0)
			var cu: float = sx * KW_HX * along.x
			var c0: float = cu - 1.0 if cu > 0.0 else cu - 0.2
			var c1: float = cu + 0.2 if cu > 0.0 else cu + 1.0
			_band(pk, kit, "concrete", p0, along, out, c0, c1, 0.0, KW_GF, 0.2, KW_CONC.darkened(0.06), 0.0)
			_roller_door(pk, kit, p0, along, out, door_u, 0.0, 4.0, 4.6)
			_rect_window(pk, kit, p0, along, out, win_u, 2.0, 2.0, 2.6, 0.15, "concrete", CONC.lightened(0.05))
		# The portal's lintel over the passage, hazard-striped along its foot.
		_mblock(pk, kit, "concrete", Vector3(-KW_COL_IN, KW_PORTAL_BOT, minf(sz * 16.2, sz * KW_HZ)), Vector3(KW_COL_IN, KW_GF + 0.02, maxf(sz * 16.2, sz * KW_HZ)), CONC, false, true)
		_box(pk, kit, "hazard", Vector3(0, KW_PORTAL_BOT + 0.215, sz * KW_HZ), Basis(), Vector3(KW_COL_IN * 2.0, 0.47, 0.06), WHITE)


## A roller door in a hole a wall left (centre u, sill v0, w x h): its slatted curtain 15cm in, guide rails, the drum's box
## over it on the wall.
static func _roller_door(pk: PropKit, kit: Dictionary, p0: Vector3, along: Vector3, out: Vector3, cu: float, v0: float, w: float, h: float) -> void:
	var wf := _wf(p0, along, out)
	var bas := Basis(along, UP, out)
	var col := Color(0.50, 0.53, 0.52)
	_box(pk, kit, "paint", wf * Vector3(cu, v0 + h * 0.5, -0.18), bas, Vector3(w, h, 0.05), col)
	var n: int = int(h / 0.3)
	for k in range(n):
		_box(pk, kit, "paint", wf * Vector3(cu, v0 + 0.15 + float(k) * h / float(n), -0.145), bas, Vector3(w - 0.04, 0.05, 0.03), col.darkened(0.18))
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "steel", wf * Vector3(cu + sx * (w * 0.5 - 0.04), v0 + h * 0.5, -0.12), bas, Vector3(0.08, h, 0.1), STEEL_DARK)
	_box(pk, kit, "paint", wf * Vector3(cu, v0 + h + 0.3, 0.22), bas, Vector3(w + 0.3, 0.6, 0.44), col.darkened(0.1))


## A valve's hand wheel round c, its axle along basis.y: a red rim and three spokes, radius r.
static func _hand_wheel(pk: PropKit, kit: Dictionary, c: Vector3, basis: Basis, r: float) -> void:
	var red := Color(0.62, 0.12, 0.10)
	pk.tyre(kit, "paint", c, r - 0.035, r, 0.04, 14, red, basis)
	for k in range(3):
		var a: float = PI * float(k) / 3.0
		var d: Vector3 = basis.x * cos(a) + basis.z * sin(a)
		_bar(pk, kit, "paint", c - d * (r - 0.02), c + d * (r - 0.02), 0.025 + 0.004 * float(k), 0.025 + 0.004 * float(k), red.darkened(0.15), basis.y)
	pk.tube(kit, "steel", c - basis.y * 0.05, c + basis.y * 0.12, 0.04, 0.04, 6, STEEL_DARK, true)


static func _kw_passage_ceiling(pk: PropKit, kit: Dictionary) -> void:
	# The slab's underside over the passage, the edge beams, the cross beams.
	pk.quad(kit, "concrete", [Vector3(-KW_COL_IN - 0.1, KW_GF, -16.2), Vector3(-KW_COL_IN - 0.1, KW_GF, 16.2), Vector3(KW_COL_IN + 0.1, KW_GF, 16.2),
			Vector3(KW_COL_IN + 0.1, KW_GF, -16.2)], Vector3.DOWN, CONC_DARK, [Vector2(0, 0), Vector2(0, 32.4) * uvk, Vector2(15.8, 32.4) * uvk, Vector2(15.8, 0) * uvk])
	for sx in [-1.0, 1.0]:
		_mblock(pk, kit, "concrete", Vector3(minf(sx * 7.75, sx * 8.65), KW_EDGE_BOT, -16.2), Vector3(maxf(sx * 7.75, sx * 8.65), KW_GF + 0.01, 16.2), CONC, false, true)
	for i in range(1, KW_ROWS.size() - 1):
		var zc: float = KW_ROWS[i]
		_mblock(pk, kit, "concrete", Vector3(-7.9, KW_BEAM_BOT, zc - 0.3), Vector3(7.9, KW_GF - 0.005, zc + 0.3), CONC, false, true)
	# The bunker hoppers: two per bay, each a steel frustum with corner angles, a slide gate with its hand wheel and a chute.
	var rust := Color(0.30, 0.25, 0.22)
	for i in range(KW_ROWS.size() - 1):
		var zb: float = (float(KW_ROWS[i]) + float(KW_ROWS[i + 1])) * 0.5
		for sx in [-1.0, 1.0]:
			var x: float = sx * 3.6
			_hopper(pk, kit, "rusty", x, zb, KW_GF - 0.005, 1.6, 1.9, 7.86, 0.36, 0.36, rust)
			for cxz in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				_bar(pk, kit, "rusty", Vector3(x + cxz.x * 1.62, KW_GF - 0.02, zb + cxz.y * 1.92), Vector3(x + cxz.x * 0.38, 7.88, zb + cxz.y * 0.38), 0.08, 0.08, rust.darkened(0.2))
			_hopper(pk, kit, "rusty", x, zb, 8.24, 1.12, 1.33, 8.12, 0.97, 1.13, rust.darkened(0.15))
			_box(pk, kit, "steel", Vector3(x, 7.68, zb), Basis(), Vector3(1.0, 0.36, 1.1), Color(0.26, 0.3, 0.29))
			_hand_wheel(pk, kit, Vector3(x + 0.5, 7.72, zb + 0.66), Basis(Vector3.RIGHT, PI * 0.5), 0.24)
			_bar(pk, kit, "steel", Vector3(x - 0.55, 7.66, zb), Vector3(x + 0.7, 7.66, zb), 0.06, 0.06, STEEL_DARK)
			var c0 := Vector3(x, 7.55, zb)
			var c1 := Vector3(x - sx * 1.1, 7.42, zb)
			pk.beam(kit, "rusty", c0, c1, 0.7, 0.3, rust.lightened(0.05), Vector3(0, 0, 1))
		SW._pendant(pk, kit, Vector3(0, KW_GF, zb), 0.95)
	# Pipes and cable trays along the passage's sides.
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(sx * 6.4, 8.2, -KW_HZ + 0.2), Vector3(sx * 6.4, 8.2, KW_HZ - 0.2), 0.16, 0.16, 10, Color(0.22, 0.34, 0.5), true)
		pk.tube(kit, "steel", Vector3(sx * 5.8, 8.32, -KW_HZ + 0.2), Vector3(sx * 5.8, 8.32, KW_HZ - 0.2), 0.1, 0.1, 8, Color(0.62, 0.55, 0.15), true)
		_box(pk, kit, "steel", Vector3(sx * 7.1, 7.9, 0), Basis(), Vector3(0.6, 0.1, 32.4), Color(0.45, 0.46, 0.45))
		var hz := -15.0
		while hz < 15.5:
			_bar(pk, kit, "steel", Vector3(sx * 7.1, 7.95, hz), Vector3(sx * 7.1, KW_GF, hz), 0.05, 0.05, STEEL_DARK)
			hz += 2.8
		for k in range(4):
			pk.tube(kit, "matte", Vector3(sx * (6.86 + 0.14 * float(k)), 7.98, -16.2), Vector3(sx * (6.86 + 0.14 * float(k)), 7.98, 16.2), 0.035, 0.035, 5, BLACK, false)


static func _kw_upper(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	# The concrete bunker band, 15cm out from the cladding over it, with lisenes at the column lines on ±x.
	_ring_sides(pk, kit, "concrete", Vector3.ZERO, KW_HX, KW_HZ, 0.15, KW_GF, KW_BAND_TOP, CONC)
	_ring_flat(pk, kit, "concrete", Vector3.ZERO, KW_HX, KW_HZ, 0.0, 0.15, KW_GF, false, CONC_DARK)
	_ring_flat(pk, kit, "concrete", Vector3.ZERO, KW_HX, KW_HZ, -0.05, 0.15, KW_BAND_TOP, true, CONC)
	# The cladding: corrugated iron round the hall to the eaves with two ribbon windows, flashings along them.
	var bands: Array = [Vector2(15.0, 16.8), Vector2(20.6, 22.4)]
	for fi in range(4):
		var out: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][fi]
		var along: Vector3 = UP.cross(out)
		var half: float = KW_HX if fi % 2 == 0 else KW_HZ
		var p0: Vector3 = out * (KW_HZ if fi % 2 == 0 else KW_HX)
		# The +x side has only the upper ribbon: the product gallery comes in under it.
		_clad_wall(pk, kit, p0, along, out, -half, half, KW_BAND_TOP, KW_EAVE + 0.1, [bands[1]] if fi == 1 else bands, CLAD)
		if fi % 2 == 1:
			# Steel columns proud of the cladding on the long sides, a girt at the eaves.
			for zc in KW_ROWS:
				var u: float = float(zc) * (along.z if absf(along.z) > 0.5 else 1.0)
				SW._ibeam(pk, kit, "shell", p0 + along * u + UP * KW_BAND_TOP + out * 0.22, p0 + along * u + UP * KW_EAVE + out * 0.22, 0.3, 0.3, GREEN_GREY, out)
			SW._ibeam(pk, kit, "shell", p0 + along * (-half - 0.2) + UP * (KW_EAVE - 0.2) + out * 0.22, p0 + along * (half + 0.2) + UP * (KW_EAVE - 0.2) + out * 0.22, 0.4, 0.25,
					GREEN_GREY, UP)
		else:
			# Columns either side of the middle bay (the catwalk's door), the name board on brackets in front of them.
			var wf := _wf(p0, along, out)
			var bas := Basis(along, UP, out)
			for u in [-13.33, -6.67, 6.67, 13.33]:
				SW._ibeam(pk, kit, "shell", wf * Vector3(u, KW_BAND_TOP, 0.22), wf * Vector3(u, KW_EAVE, 0.22), 0.3, 0.3, GREEN_GREY, out)
			SW._ibeam(pk, kit, "shell", wf * Vector3(-half - 0.2, KW_EAVE - 0.2, 0.22), wf * Vector3(half + 0.2, KW_EAVE - 0.2, 0.22), 0.4, 0.25, GREEN_GREY, UP)
			_box(pk, kit, "paint", wf * Vector3(0, 24.5, 0.48), bas, Vector3(36.0, 2.4, 0.12), Color(0.86, 0.84, 0.76))
			_box(pk, kit, "paint", wf * Vector3(0, 24.5, 0.42), bas, Vector3(36.3, 2.7, 0.06), Color(0.2, 0.24, 0.22))
			_lbl(labels, "KOHLENWÄSCHE", wf * Vector3(0, 24.5, 0.57), out, 1.85, Color(0.14, 0.17, 0.16), 34.0)
	# The roof over the hall (corrugated, along x) and the raw-coal tower's walls, windows and roof.
	var roof_col := Color(0.36, 0.37, 0.37)
	_gable_roof_x(pk, kit, "iron", 0.0, KW_HZ, -KW_HX - 0.35, KW_HX + 0.35, KW_EAVE, KW_RIDGE, 0.35, roof_col)
	# The gables: whole on +x; on -x only beside the tower (z 1..17), whose own wall carries on up there.
	_wpoly(pk, kit, "iron", Vector3(KW_HX, 0, 0), Vector3.FORWARD, Vector3.RIGHT,
			PackedVector2Array([Vector2(-KW_HZ, KW_EAVE + 0.1), Vector2(KW_HZ, KW_EAVE + 0.1), Vector2(0, KW_RIDGE - 0.06)]), CLAD)
	var tzt: float = KW_TOWER.end.y
	_wpoly(pk, kit, "iron", Vector3(-KW_HX, 0, 0), Vector3.BACK, Vector3.LEFT,
			PackedVector2Array([Vector2(tzt, KW_EAVE + 0.1), Vector2(KW_HZ, KW_EAVE + 0.1), Vector2(tzt, KW_RIDGE - tzt / KW_HZ * (KW_RIDGE - KW_EAVE) - 0.06)]), CLAD)
	var tx0: float = KW_TOWER.position.x
	var tx1: float = KW_TOWER.end.x
	var tz0: float = KW_TOWER.position.y
	var tz1: float = KW_TOWER.end.y
	var tc := Vector3((tx0 + tx1) * 0.5, 0, (tz0 + tz1) * 0.5)
	var thx: float = (tx1 - tx0) * 0.5
	var thz: float = (tz1 - tz0) * 0.5
	var tb: Array = [Vector2(29.5, 31.0)]
	for fi in range(4):
		var out: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][fi]
		var along: Vector3 = UP.cross(out)
		var half: float = thx if fi % 2 == 0 else thz
		var p0: Vector3 = tc + out * (thz if fi % 2 == 0 else thx)
		# Its outer faces (-z, -x) carry on over the hall's: they start at its eaves, the inner ones under its roof.
		var t0: float = KW_EAVE + 0.1 if fi >= 2 else KW_EAVE - 0.4
		_clad_wall(pk, kit, p0, along, out, -half, half, t0, KW_TOWER_TOP + 0.1, [] if fi == 3 else tb, CLAD_BROWN)
		if fi % 2 == 0:
			_wpoly(pk, kit, "iron", p0, along, out, PackedVector2Array([Vector2(-half, KW_TOWER_TOP + 0.1), Vector2(half, KW_TOWER_TOP + 0.1), Vector2(0, KW_TOWER_TOP + 0.95)]), CLAD_BROWN)
		if fi == 2:
			var wf2 := _wf(p0, along, out)
			_box(pk, kit, "paint", wf2 * Vector3(0, 33.0, 0.1), Basis(along, UP, out), Vector3(12.4, 1.5, 0.12), Color(0.86, 0.84, 0.76))
			_lbl(labels, "ZECHE KRONPRINZ", wf2 * Vector3(0, 33.0, 0.19), out, 0.92, Color(0.14, 0.17, 0.16), 11.6)
	_gable_roof_z(pk, kit, "iron", tc.x, thx, tz0 - 0.35, tz1 + 0.35, KW_TOWER_TOP, KW_TOWER_TOP + 1.0, 0.35, roof_col)
	# A glazed roof monitor along the ridge, ventilators on the slopes, a catwalk over each portal, downpipes.
	var mx0 := -4.5
	var mx1 := 18.5
	var mh := 1.6
	var my0: float = KW_RIDGE - mh / KW_HZ * (KW_RIDGE - KW_EAVE) - 0.25
	var my1: float = KW_RIDGE + 1.6
	for sz in [-1.0, 1.0]:
		var out := Vector3(0, 0, sz)
		var along: Vector3 = UP.cross(out)
		var p0 := Vector3((mx0 + mx1) * 0.5, 0, sz * mh)
		var half: float = (mx1 - mx0) * 0.5
		_mq(pk, kit, "iron", p0, along, out, -half, half, my0, KW_RIDGE + 0.2, CLAD)
		_glass(pk, kit, p0 + UP * ((KW_RIDGE + 0.2 + my1) * 0.5) - out * 0.04, along, out, half * 2.0 - 0.3, my1 - KW_RIDGE - 0.2)
		_mq(pk, kit, "iron", p0, along, out, -half, half, my1 - 0.05, my1 + 0.1, CLAD.darkened(0.2))
		var n_m: int = int(half * 2.0 / 2.3)
		for k in range(n_m + 1):
			var u: float = -half + half * 2.0 * float(k) / float(n_m)
			_box(pk, kit, "steel", p0 + along * u + UP * ((KW_RIDGE + 0.2 + my1) * 0.5) + out * 0.03, Basis(along, UP, out), Vector3(0.1, my1 - KW_RIDGE - 0.2, 0.08), STEEL_DARK)
	for sx in [-1.0, 1.0]:
		var out := Vector3(sx, 0, 0)
		var xm: float = mx1 if sx > 0.0 else mx0
		_wpoly(pk, kit, "iron", Vector3(xm, 0, 0), UP.cross(out), out, PackedVector2Array([Vector2(-mh, my0), Vector2(mh, my0), Vector2(mh, my1 + 0.1), Vector2(0, my1 + 0.55),
				Vector2(-mh, my1 + 0.1)]), CLAD)
	_gable_roof_x(pk, kit, "iron", 0.0, mh, mx0 - 0.3, mx1 + 0.3, my1 + 0.1, my1 + 0.55, 0.3, roof_col)
	for vp in [Vector2(4.0, 9.0), Vector2(11.0, -9.0), Vector2(16.0, 9.0), Vector2(-1.0, -10.0)]:
		var vy: float = KW_RIDGE - absf(vp.y) / KW_HZ * (KW_RIDGE - KW_EAVE)
		var vb := Vector3(vp.x, vy - 0.2, vp.y)
		pk.tube(kit, "steel", vb, vb + Vector3(0, 1.4, 0), 0.55, 0.55, 12, Color(0.5, 0.52, 0.5), false)
		pk.lathe(kit, "steel", vb + Vector3(0, 1.4, 0), [Vector2(0.9, 0.0), Vector2(0.95, 0.15), Vector2(0.6, 0.55), Vector2(0.001, 0.62)], 12, Color(0.46, 0.48, 0.47), true)
		pk.lathe(kit, "steel", vb + Vector3(0, 1.395, 0), [Vector2(0.001, 0.0), Vector2(0.9, 0.0)], 12, Color(0.2, 0.2, 0.2), true)
	for sz in [-1.0, 1.0]:
		var dz: float = sz * (KW_HZ + 0.15)
		var c := Vector3(0, KW_BAND_TOP, dz + sz * 0.6)
		_box(pk, kit, "steel", c + Vector3(0, 0.05, 0), Basis(), Vector3(4.0, 0.1, 1.2), STEEL_DARK)
		for bx in [-1.6, 1.6]:
			_bar(pk, kit, "steel", Vector3(bx, KW_BAND_TOP - 1.2, dz), Vector3(bx, KW_BAND_TOP, dz + sz * 1.1), 0.1, 0.1, STEEL_DARK)
		SW._railing(pk, kit, [Vector3(-2.0, KW_BAND_TOP + 0.1, dz + sz * 0.02), Vector3(-2.0, KW_BAND_TOP + 0.1, dz + sz * 1.2), Vector3(2.0, KW_BAND_TOP + 0.1, dz + sz * 1.2),
				Vector3(2.0, KW_BAND_TOP + 0.1, dz + sz * 0.02)], 1.1, SIGN_YELLOW)
		var out := Vector3(0, 0, sz)
		_box(pk, kit, "paint", Vector3(0, KW_BAND_TOP + 1.2, sz * (KW_HZ + 0.04)), Basis(UP.cross(out), UP, out), Vector3(1.0, 2.2, 0.06), Color(0.32, 0.38, 0.40))
		_box(pk, kit, "steel", Vector3(0, KW_BAND_TOP + 2.7, sz * (KW_HZ + 0.12)), Basis(), Vector3(0.4, 0.25, 0.2), STEEL_DARK)
		_box(pk, kit, "lamp", Vector3(0, KW_BAND_TOP + 2.58, sz * (KW_HZ + 0.12)), Basis(), Vector3(0.3, 0.02, 0.14), Color(1.0, 0.9, 0.7))
	for cx in [-KW_HX, KW_HX]:
		for cz in [-KW_HZ, KW_HZ]:
			var dp := Vector3(cx + signf(cx) * 0.3, 0, cz - signf(cz) * 1.4)
			pk.tube(kit, "steel", dp + Vector3(0, 0.2, 0), dp + Vector3(0, KW_EAVE - 0.1, 0), 0.08, 0.08, 6, STEEL_DARK, true)


## A clad wall: corrugated iron (ribs up) in the plane through p0 from u0 to u1, v0 to v1, with ribbon windows across it in
## `bands` (Vector2(bottom, top)): the glass 6cm in behind the cladding, its reveals, and steel flashings along them.
static func _clad_wall(pk: PropKit, kit: Dictionary, p0: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v0: float, v1: float, bands: Array,
		col: Color) -> void:
	var holes: Array = []
	for b in bands:
		var bb: Vector2 = b
		holes.append([Rect2(u0 + 0.6, bb.x, (u1 - u0) - 1.2, bb.y - bb.x), true])
	_wall(pk, kit, "iron", p0, along, out, u0, u1, v0, v1, holes, col, 0.08)
	var wf := _wf(p0, along, out)
	var bas := Basis(along, UP, out)
	for b in bands:
		var bb: Vector2 = b
		var w: float = (u1 - u0) - 1.2
		_glass(pk, kit, wf * Vector3((u0 + u1) * 0.5, (bb.x + bb.y) * 0.5, -0.06), along, out, w, bb.y - bb.x)
		_box(pk, kit, "steel", wf * Vector3((u0 + u1) * 0.5, bb.x - 0.05, 0.055), bas, Vector3(w + 0.3, 0.1, 0.09), STEEL_DARK)
		_box(pk, kit, "steel", wf * Vector3((u0 + u1) * 0.5, bb.y + 0.05, 0.055), bas, Vector3(w + 0.3, 0.1, 0.09), STEEL_DARK)
		var n: int = int(w / 6.0)
		for k in range(1, n):
			_box(pk, kit, "steel", wf * Vector3(u0 + 0.6 + w * float(k) / float(n), (bb.x + bb.y) * 0.5, 0.0), bas, Vector3(0.14, bb.y - bb.x, 0.08), STEEL_DARK)
	# Corner trims.
	for u in [u0, u1]:
		_box(pk, kit, "steel", wf * Vector3(u, (v0 + v1) * 0.5, 0.03), bas, Vector3(0.2, v1 - v0, 0.06), col.darkened(0.3))


# ======================================================================================
#  Conveyor galleries
# ======================================================================================

const CG_H := 2.7        # the gallery's height from its floor to the eaves
const CG_TRUSS := 1.7    # the truss's depth under the floor
const CG_PANEL := 3.0
const CG_TRESTLE := 25.0


## An enclosed belt conveyor gallery from a to b (kit coordinates: the belt's ends at the gallery's floor, its middle), any
## heading, sloping up to about 25 degrees: a box of corrugated iron `width` wide with a ribbon of steel windows down both
## sides and a low pitched roof (to 3.0 over the floor), on a lattice truss 1.7m deep whose posts rise outside the
## cladding to the eaves; inside a belt on one side and a walkway on the other; end walls at a and b. Its walls stand
## upright (the frames are vertical) and its floor follows the slope. Every ~25m (horizontal) between the ends a four-legged
## lattice trestle stands under it, each leg down to foot_y.call(point) (the ground's height under that foot, kit
## coordinates; a missing Callable means y = 0) on a concrete footing; the legs splay with the trestle's height. The ends
## stand on what the caller puts there (a building, a stub).
static func conveyor_gallery(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, width := GALLERY_W, foot_y := Callable()) -> void:
	var d := b - a
	var hd := Vector3(d.x, 0, d.z)
	var L: float = hd.length()
	if L < 0.5:
		return
	var h: Vector3 = hd / L
	var s: float = d.y / L
	var side: Vector3 = h.cross(UP).normalized()
	var hw: float = width * 0.5
	var steel := GREEN_GREY
	var P := func(t: float) -> Vector3: return a + h * t + UP * (s * t)
	var pa: Vector3 = P.call(0.0)
	var pb: Vector3 = P.call(L)
	var slen: float = L * sqrt(1.0 + s * s)
	# The walls: cladding under and over the window ribbon, its sill and head, the glass.
	for sg in [-1.0, 1.0]:
		var o: Vector3 = side * (sg * hw)
		var out: Vector3 = side * sg
		for seg in [[0.0, 1.05, "iron"], [1.85, CG_H, "iron"]]:
			var v0: float = seg[0]
			var v1: float = seg[1]
			pk.quad(kit, seg[2], [pa + o + UP * v0, pb + o + UP * v0, pb + o + UP * v1, pa + o + UP * v1], out, CLAD,
					[Vector2(0, v0) * uvk, Vector2(L, v0) * uvk, Vector2(L, v1) * uvk, Vector2(0, v1) * uvk])
		var gi: Vector3 = o - out * 0.06
		pk.quad(kit, "glass", [pa + gi + UP * 1.05, pb + gi + UP * 1.05, pb + gi + UP * 1.85, pa + gi + UP * 1.85], out, WHITE,
				[Vector2(0, 0), Vector2(slen, 0), Vector2(slen, 0.8), Vector2(0, 0.8)])
		pk.quad(kit, "steel", [pa + o + UP * 1.05, pb + o + UP * 1.05, pb + gi + UP * 1.05, pa + gi + UP * 1.05], UP, STEEL_DARK)
		pk.quad(kit, "steel", [pa + o + UP * 1.85, pb + o + UP * 1.85, pb + gi + UP * 1.85, pa + gi + UP * 1.85], Vector3.DOWN, STEEL_DARK)
		# Flashing over the sill.
		pk.beam(kit, "steel", pa + o + out * 0.04 + UP * 1.0, pb + o + out * 0.04 + UP * 1.0, 0.08, 0.1, STEEL_DARK, out)
	# The roof (corrugated, ribs along the gallery), its eaves 15cm out.
	var rr := Vector3.ZERO
	for sg in [-1.0, 1.0]:
		var e: Vector3 = side * (sg * (hw + 0.15)) + UP * (CG_H - 0.04)
		var r: Vector3 = UP * (CG_H + 0.3)
		var n: Vector3 = (side * sg * 0.3 + UP * (hw + 0.15)).normalized()
		var p0: Vector3 = pa + e - h * 0.15
		var p1: Vector3 = pb + e + h * 0.15
		var p2: Vector3 = pb + r + h * 0.15
		var p3: Vector3 = pa + r - h * 0.15
		var uv: Array = [Vector2(0, 0), Vector2(0, slen) * uvk, Vector2(hw, slen) * uvk, Vector2(hw, 0) * uvk]
		pk.quad(kit, "iron", [p0, p1, p2, p3], n, Color(0.38, 0.39, 0.39), uv)
		var dn := Vector3(0, -0.04, 0)
		pk.quad(kit, "iron", [p0 + dn, p1 + dn, p2 + dn, p3 + dn], -n, Color(0.2, 0.2, 0.2), uv)
	# The floor's underside and edges, and the end walls.
	var fo: Vector3 = UP * -0.18
	pk.quad(kit, "steel", [pa - side * hw + fo, pb - side * hw + fo, pb + side * hw + fo, pa + side * hw + fo], Vector3.DOWN, STEEL_DARK)
	for sg in [-1.0, 1.0]:
		pk.quad(kit, "steel", [pa + side * (sg * hw) + fo, pb + side * (sg * hw) + fo, pb + side * (sg * hw), pa + side * (sg * hw)], side * sg, STEEL_DARK)
	for e in [[pa, -h], [pb, h]]:
		var c: Vector3 = e[0]
		var n2: Vector3 = e[1]
		var poly := PackedVector2Array([Vector2(-hw, -0.18), Vector2(hw, -0.18), Vector2(hw, CG_H), Vector2(0, CG_H + 0.28), Vector2(-hw, CG_H)])
		var sd2: Vector3 = side if n2.dot(h) < 0.0 else -side
		KT._pface(pk, kit, "iron", Transform3D(Basis(sd2, UP, n2), c), poly, 0.0, CLAD)
	# Inside: the belt on its idlers along one side, the walkway along the other.
	pk.beam(kit, "rubber", pa - side * (hw * 0.4) + UP * 0.78, pb - side * (hw * 0.4) + UP * 0.78, hw * 0.75, 0.08, Color(0.05, 0.05, 0.05), side)
	pk.beam(kit, "steel", pa - side * (hw * 0.4) + UP * 0.5, pb - side * (hw * 0.4) + UP * 0.5, hw * 0.8, 0.4, Color(0.3, 0.32, 0.3), side)
	pk.beam(kit, "steel", pa + side * (hw * 0.5) + UP * 0.03, pb + side * (hw * 0.5) + UP * 0.03, hw * 0.75, 0.06, STEEL_DARK, side)
	# The truss: chords, posts up to the eaves, diagonals, the bottom bracing.
	var n_p: int = maxi(1, int(round(L / CG_PANEL)))
	var tw: float = hw + 0.1
	for sg in [-1.0, 1.0]:
		var o: Vector3 = side * (sg * tw)
		_bar(pk, kit, "shell", pa + o - UP * 0.1, pb + o - UP * 0.1, 0.22, 0.22, steel, side)
		_bar(pk, kit, "shell", pa + o - UP * CG_TRUSS, pb + o - UP * CG_TRUSS, 0.22, 0.22, steel, side)
		_bar(pk, kit, "shell", pa + o + UP * (CG_H - 0.08), pb + o + UP * (CG_H - 0.08), 0.16, 0.16, steel, side)
		for i in range(n_p + 1):
			var t: float = L * float(i) / float(n_p)
			var p: Vector3 = P.call(t)
			_bar(pk, kit, "shell", p + o - UP * CG_TRUSS, p + o + UP * CG_H, 0.18, 0.18, steel, side)
			if i < n_p:
				var q: Vector3 = P.call(L * float(i + 1) / float(n_p))
				if i % 2 == 0:
					_bar(pk, kit, "shell", p + o - UP * CG_TRUSS, q + o - UP * 0.1, 0.14, 0.14, steel, side)
				else:
					_bar(pk, kit, "shell", p + o - UP * 0.1, q + o - UP * CG_TRUSS, 0.12, 0.12, steel, side)
	for i in range(n_p + 1):
		var p: Vector3 = P.call(L * float(i) / float(n_p)) - UP * CG_TRUSS
		_bar(pk, kit, "shell", p - side * tw, p + side * tw, 0.14, 0.14, steel, h)
		if i < n_p:
			var q: Vector3 = P.call(L * float(i + 1) / float(n_p)) - UP * CG_TRUSS
			_bar(pk, kit, "shell", p - side * tw, q + side * tw, 0.1, 0.1, steel)
	# Trestles between the ends.
	var n_t: int = maxi(0, int(ceil(L / CG_TRESTLE)) - 1)
	for k in range(1, n_t + 1):
		var t: float = L * float(k) / float(n_t + 1)
		_trestle(pk, kit, P.call(t) - UP * (CG_TRUSS + 0.12), h, side, tw, foot_y, steel)


## A four-legged lattice trestle under a gallery: its cap at `top` (the truss's underside), legs from the cap's corners
## (across ±tw along `side`, ±0.9 along `h`) splaying down to the ground foot_y gives under each foot, braced in levels
## with crossed bars on all four faces, each foot on a concrete footing.
static func _trestle(pk: PropKit, kit: Dictionary, top: Vector3, h: Vector3, side: Vector3, tw: float, foot_y: Callable, col: Color) -> void:
	var g0: float = foot_y.call(top) if foot_y.is_valid() else 0.0
	var ht: float = maxf(top.y - g0, 1.0)
	var spread_s: float = 0.05 * ht
	var spread_h: float = 0.035 * ht
	var corners: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var tops: Array = []
	var feet: Array = []
	for c in corners:
		var cc: Vector2 = c
		var tp: Vector3 = top + side * (cc.x * tw) + h * (cc.y * 0.9)
		var fx: Vector3 = tp + side * (cc.x * spread_s) + h * (cc.y * spread_h)
		var fy: float = foot_y.call(Vector3(fx.x, top.y, fx.z)) if foot_y.is_valid() else 0.0
		var ft := Vector3(fx.x, fy + 0.3, fx.z)
		tops.append(tp)
		feet.append(ft)
		_bar(pk, kit, "shell", tp, ft, 0.26, 0.26, col, side)
		_mblock(pk, kit, "concrete", Vector3(fx.x - 0.55, fy - 1.4, fx.z - 0.55), Vector3(fx.x + 0.55, fy + 0.32, fx.z + 0.55), CONC)
	# The cap beams under the truss.
	_bar(pk, kit, "shell", top - side * (tw + 0.2) + h * 0.9, top + side * (tw + 0.2) + h * 0.9, 0.3, 0.3, col, h)
	_bar(pk, kit, "shell", top - side * (tw + 0.2) - h * 0.9, top + side * (tw + 0.2) - h * 0.9, 0.3, 0.3, col, h)
	var n_lv: int = maxi(1, int(round(ht / 4.5)))
	for j in range(n_lv + 1):
		var f0: float = float(j) / float(n_lv + 0)
		var f1: float = float(j + 1) / float(n_lv + 0)
		for i in range(4):
			var a0: Vector3 = (tops[i] as Vector3).lerp(feet[i], minf(f0, 0.96))
			var b0: Vector3 = (tops[(i + 1) % 4] as Vector3).lerp(feet[(i + 1) % 4], minf(f0, 0.96))
			if j > 0:
				_bar(pk, kit, "shell", a0, b0, 0.14, 0.14, col)
			if j < n_lv:
				var a1: Vector3 = (tops[i] as Vector3).lerp(feet[i], minf(f1, 0.96))
				var b1: Vector3 = (tops[(i + 1) % 4] as Vector3).lerp(feet[(i + 1) % 4], minf(f1, 0.96))
				_bar(pk, kit, "shell", a0, b1, 0.1, 0.1, col)
				_bar(pk, kit, "shell", b0, a1, 0.1, 0.1, col)


# ======================================================================================
#  The loading bunker over the colliery railway
# ======================================================================================

const VB_HX := 10.0
const VB_HZ := 20.2
const VB_ROWS := [-19.4, -12.93, -6.47, 0.0, 6.47, 12.93, 19.4]
const VB_COL_IN := 3.0       # the inner columns' inner faces: the track's clearance is |x| <= 2.6, y <= 5.6
const VB_BEAM_TOP := 9.4     # the bunker's flat underside over the track
const VB_FLAT := 3.9         # its half width; outside it the hopper walls slope up to the side walls' foot
const VB_WALL_BOT := 12.8
const VB_TOP := 22.0
const VB_HOUSE_TOP := 25.4


## The loading bunker (Verladebunker): a concrete bunker on concrete columns over a standard-gauge track along z through its
## middle, centred. Clear for the wagons: nothing within |x| <= 2.6 below y 5.6 (the inner columns' faces at |x| 2.95, the
## lowest chute at 5.9). Columns in rows every 6.47m (x ±3.4 and ±9.2, tied at 4m) carry a board-formed box (x ±10, z
## ±20.2, to 22.0) whose underside is a V: flat over the track (|x| <= 3.9, at 9.4, on beams 8.2..9.4) and sloping hopper
## walls up to the side walls' foot at 12.8; lisenes, slit windows and a cornice; over the track six concrete
## hoppers (to 7.0), each with a steel slide gate, a hand wheel and a telescopic chute; lamps under it. On the roof a
## corrugated belt house (x ±3.2, to 25.4, ridge 26.2) with a ribbon window, and a gallery stub entering its -z end at
## floor 23.0 (coal_bunker_stub); a parapet; a caged ladder up the +x side. KOHLENVERLADUNG on both ends. Footprint
## x ±10.2, z ±20.4 (the stub to -27).
static func coal_bunker(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	# Columns: the inner ones (faces at |x| 2.95) under the flat middle, the outer ones up into the sloping hopper walls,
	# tied along z at mid height; beams over the inner ones.
	for zc in VB_ROWS:
		for cx in [-3.4, 3.4]:
			_mblock(pk, kit, "concrete", Vector3(cx - 0.45, -1.0, zc - 0.45), Vector3(cx + 0.45, 8.3, zc + 0.45), CONC, false)
		for cx in [-9.2, 9.2]:
			_mblock(pk, kit, "concrete", Vector3(cx - 0.45, -1.0, zc - 0.55), Vector3(cx + 0.45, 12.6, zc + 0.55), CONC, false)
		_mblock(pk, kit, "concrete", Vector3(-3.95, 8.2, zc - 0.3), Vector3(3.95, VB_BEAM_TOP, zc + 0.3), CONC_DARK, false, true)
	for cx in [-3.4, 3.4]:
		_mblock(pk, kit, "concrete", Vector3(cx - 0.5, 8.35, -VB_HZ + 0.6), Vector3(cx + 0.5, VB_BEAM_TOP, VB_HZ - 0.6), CONC_DARK, false, true)
	for cx in [-9.2, 9.2]:
		_mblock(pk, kit, "concrete", Vector3(cx - 0.5, 11.5, -VB_HZ + 0.6), Vector3(cx + 0.5, 12.75, VB_HZ - 0.6), CONC_DARK, false, true)
		for i in range(VB_ROWS.size() - 1):
			_mblock(pk, kit, "concrete", Vector3(cx - 0.32, 4.0, float(VB_ROWS[i]) + 0.55), Vector3(cx + 0.32, 4.7, float(VB_ROWS[i + 1]) - 0.55), CONC_DARK, true, true)
	# The box: a V-shaped underside (sloping hopper walls to the flat middle over the track), walls with lisenes at the rows,
	# slit windows, a cornice.
	pk.quad(kit, "concrete", [Vector3(-VB_FLAT, VB_BEAM_TOP, -VB_HZ), Vector3(-VB_FLAT, VB_BEAM_TOP, VB_HZ), Vector3(VB_FLAT, VB_BEAM_TOP, VB_HZ), Vector3(VB_FLAT, VB_BEAM_TOP, -VB_HZ)],
			Vector3.DOWN, CONC_DARK, [Vector2(0, 0), Vector2(0, 40.4) * uvk, Vector2(VB_FLAT * 2.0, 40.4) * uvk, Vector2(VB_FLAT * 2.0, 0) * uvk])
	for sx in [-1.0, 1.0]:
		var a := Vector3(sx * VB_FLAT, VB_BEAM_TOP, -VB_HZ)
		var b := Vector3(sx * VB_FLAT, VB_BEAM_TOP, VB_HZ)
		var c2 := Vector3(sx * VB_HX, VB_WALL_BOT, VB_HZ)
		var d2 := Vector3(sx * VB_HX, VB_WALL_BOT, -VB_HZ)
		var sl_len: float = Vector2(VB_HX - VB_FLAT, VB_WALL_BOT - VB_BEAM_TOP).length()
		pk.quad(kit, "concrete", [a, b, c2, d2], Vector3(sx * (VB_WALL_BOT - VB_BEAM_TOP), -(VB_HX - VB_FLAT), 0).normalized(), CONC_DARK,
				[Vector2(0, 0), Vector2(40.4, 0) * uvk, Vector2(40.4, sl_len) * uvk, Vector2(0, sl_len) * uvk])
	for fi in range(4):
		var out: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][fi]
		var along: Vector3 = UP.cross(out)
		var half: float = VB_HX if fi % 2 == 0 else VB_HZ
		var p0: Vector3 = out * (VB_HZ if fi % 2 == 0 else VB_HX)
		var holes: Array = []
		if fi % 2 == 1:
			for i in range(VB_ROWS.size() - 1):
				var zm: float = (float(VB_ROWS[i]) + float(VB_ROWS[i + 1])) * 0.5
				var um: float = zm * along.z
				holes.append([Rect2(um - 0.3, 17.0, 0.6, 2.6), true])
		if fi % 2 == 1:
			_wall(pk, kit, "concrete", p0, along, out, -half, half, VB_WALL_BOT, VB_TOP, holes, CONC, 0.3)
		else:
			_wpoly(pk, kit, "concrete", p0, along, out, PackedVector2Array([Vector2(-VB_HX, VB_WALL_BOT), Vector2(-VB_FLAT, VB_BEAM_TOP), Vector2(VB_FLAT, VB_BEAM_TOP),
					Vector2(VB_HX, VB_WALL_BOT), Vector2(VB_HX, VB_TOP), Vector2(-VB_HX, VB_TOP)]), CONC)
		for hh in holes:
			var r: Rect2 = hh[0]
			_glass(pk, kit, _wf(p0, along, out) * Vector3(r.get_center().x, r.get_center().y, -0.15), along, out, r.size.x, r.size.y)
		var lus: Array = []
		if fi % 2 == 1:
			for zc in VB_ROWS:
				lus.append(float(zc) * along.z)
		else:
			lus = [-VB_HX + 0.4, VB_HX - 0.4]
		for lu in lus:
			var ua: float = float(lu) - 0.4
			var ub: float = float(lu) + 0.4
			if absf(lu) > half - 0.5:
				ua = maxf(ua, -half)
				ub = minf(ub, half)
			_band(pk, kit, "concrete", p0, along, out, ua, ub, VB_WALL_BOT, VB_TOP - 0.8, 0.14, CONC.lightened(0.04), 0.0)
		if fi % 2 == 0:
			_lbl(labels, "KOHLENVERLADUNG", p0 + UP * 19.6 + out * 0.04, out, 1.0, Color(0.16, 0.16, 0.15), 15.0)
			_lbl(labels, "ZECHE KRONPRINZ", p0 + UP * 18.3 + out * 0.04, out, 0.55, Color(0.16, 0.16, 0.15), 9.0)
	_cornice(pk, kit, "concrete", Vector3.ZERO, VB_HX, VB_HZ, VB_TOP - 0.8, [Vector2(0.2, 0.4), Vector2(0.32, 0.4)], CONC, 0.0, false)
	# The roof slab and its parapet.
	pk.quad(kit, "concrete", [Vector3(-VB_HX, VB_TOP + 0.3, -VB_HZ), Vector3(VB_HX, VB_TOP + 0.3, -VB_HZ), Vector3(VB_HX, VB_TOP + 0.3, VB_HZ), Vector3(-VB_HX, VB_TOP + 0.3, VB_HZ)],
			UP, CONC_DARK, [Vector2(0, 0), Vector2(20, 0) * uvk, Vector2(20, 40.4) * uvk, Vector2(0, 40.4) * uvk])
	_ring_sides(pk, kit, "concrete", Vector3.ZERO, VB_HX, VB_HZ, 0.32, VB_TOP, VB_TOP + 1.1, CONC)
	_ring_sides(pk, kit, "concrete", Vector3.ZERO, VB_HX - 0.25, VB_HZ - 0.25, -0.0, VB_TOP + 0.3, VB_TOP + 1.1, CONC_DARK)
	_ring_flat(pk, kit, "concrete", Vector3.ZERO, VB_HX, VB_HZ, -0.25, 0.32, VB_TOP + 1.1, true, CONC)
	# The hoppers over the track with their gates and chutes; lamps between them.
	for i in range(VB_ROWS.size() - 1):
		var zb: float = (float(VB_ROWS[i]) + float(VB_ROWS[i + 1])) * 0.5
		_hopper(pk, kit, "concrete", 0.0, zb, VB_BEAM_TOP + 0.002, 2.0, 2.2, 7.0, 0.55, 0.55, CONC_DARK)
		pk.quad(kit, "matte", [Vector3(-0.55, 7.0, zb - 0.55), Vector3(0.55, 7.0, zb - 0.55), Vector3(0.55, 7.0, zb + 0.55), Vector3(-0.55, 7.0, zb + 0.55)], Vector3.DOWN, BLACK)
		_box(pk, kit, "rusty", Vector3(0, 6.75, zb), Basis(), Vector3(1.5, 0.5, 1.4), Color(0.3, 0.26, 0.23))
		_hand_wheel(pk, kit, Vector3(0.84, 6.8, zb), Basis(Vector3.BACK, PI * 0.5), 0.27)
		pk.tube(kit, "rusty", Vector3(0, 6.5, zb), Vector3(0, 5.95, zb), 0.42, 0.36, 12, Color(0.32, 0.27, 0.24), true)
		pk.tube(kit, "rusty", Vector3(0, 6.46, zb), Vector3(0, 6.38, zb), 0.48, 0.48, 12, Color(0.26, 0.22, 0.2), true)
		for cx in [-1.0, 1.0]:
			_bar(pk, kit, "steel", Vector3(cx * 0.4, 7.0, zb), Vector3(cx * 0.4, 6.0, zb), 0.04, 0.04, STEEL_DARK)
		SW._pendant(pk, kit, Vector3(cx_lamp(i), VB_BEAM_TOP, float(VB_ROWS[i]) + 0.9), 1.2)
	# The belt house on the roof, and its gallery stub.
	var bh := 3.2
	var hz2: float = VB_HZ - 0.6
	for fi in range(4):
		var out: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][fi]
		var along: Vector3 = UP.cross(out)
		var half: float = bh if fi % 2 == 0 else hz2
		var p0: Vector3 = out * (hz2 if fi % 2 == 0 else bh)
		var bands: Array = [Vector2(23.4, 24.6)] if fi % 2 == 1 else []
		_clad_wall(pk, kit, p0, along, out, -half, half, VB_TOP + 0.3, VB_HOUSE_TOP + 0.05, bands, CLAD)
		if fi % 2 == 0:
			_wpoly(pk, kit, "iron", p0, along, out, PackedVector2Array([Vector2(-bh, VB_HOUSE_TOP + 0.05), Vector2(bh, VB_HOUSE_TOP + 0.05), Vector2(0, VB_HOUSE_TOP + 0.75)]), CLAD)
	_gable_roof_z(pk, kit, "iron", 0.0, bh, -hz2 - 0.3, hz2 + 0.3, VB_HOUSE_TOP, VB_HOUSE_TOP + 0.8, 0.3, Color(0.36, 0.37, 0.37))
	var st: Dictionary = coal_bunker_stub()
	conveyor_gallery(pk, kit, st["end"], st["inner"], st["width"])
	_cage_ladder(pk, kit, Vector3(VB_HX + 0.35, 0.2, 19.4), Vector3(VB_HX + 0.35, VB_TOP + 1.1, 19.4), Vector3.RIGHT, STEEL_DARK, 0.0)
	for sy in [3.0, 6.5]:
		_bar(pk, kit, "steel", Vector3(9.6, sy, 19.4), Vector3(VB_HX + 0.55, sy, 19.4), 0.08, 0.08, STEEL_DARK)


static func cx_lamp(i: int) -> float:
	return -1.8 if i % 2 == 0 else 1.8


## The bunker's gallery stub, as coal_washer_stubs' entries: its outer end, out along -z, falling 0.2 a metre outward.
static func coal_bunker_stub() -> Dictionary:
	return {"end": Vector3(0, 23.0 - 6.8 * 0.2, -27.0), "inner": Vector3(0, 23.0, -VB_HZ + 0.9), "dir": Vector3.FORWARD, "slope": -0.2, "width": GALLERY_W}


# ======================================================================================
#  Mine carts and the 600mm display line
# ======================================================================================

## A rounded rectangle (half sizes hx, hz, corner radius r, `segs` facets a corner), counter-clockwise from +x.
static func _rrect(hx: float, hz: float, r: float, segs := 3) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs: Array = [Vector2(hx - r, hz - r), Vector2(-hx + r, hz - r), Vector2(-hx + r, -hz + r), Vector2(hx - r, -hz + r)]
	for c in range(4):
		var a0: float = PI * 0.5 * float(c)
		for k in range(segs + 1):
			var a: float = a0 + PI * 0.5 * float(k) / float(segs)
			pts.append((cs[c] as Vector2) + Vector2(cos(a), sin(a)) * r)
	return pts


## A loft between two outlines (same point count) in plan at heights y0 and y1, facing away from (or, `inward`, toward)
## the middle `c`.
static func _loft(pk: PropKit, kit: Dictionary, key: String, c: Vector3, ol0: PackedVector2Array, y0: float, ol1: PackedVector2Array, y1: float, col: Color,
		inward := false) -> void:
	var n: int = ol0.size()
	for i in range(n):
		var j: int = (i + 1) % n
		var a := c + Vector3(ol0[i].x, y0, ol0[i].y)
		var b := c + Vector3(ol0[j].x, y0, ol0[j].y)
		var d := c + Vector3(ol1[i].x, y1, ol1[i].y)
		var e := c + Vector3(ol1[j].x, y1, ol1[j].y)
		var mid := (ol0[i] + ol0[j]) * 0.5
		var nrm: Vector3 = (b - a).cross(d - a).normalized()
		if nrm.dot(Vector3(mid.x, 0, mid.y)) < 0.0:
			nrm = -nrm
		if inward:
			nrm = -nrm
		pk.quad(kit, key, [a, b, e, d], nrm, col)


## A flat polygon (an outline in plan) at y facing up or down.
static func _flat(pk: PropKit, kit: Dictionary, key: String, c: Vector3, ol: PackedVector2Array, y: float, up: bool, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(ol)
	var n: Vector3 = UP if up else Vector3.DOWN
	for i in range(0, tris.size(), 3):
		var a: Vector2 = ol[tris[i]]
		var b: Vector2 = ol[tris[i + 1]]
		var d: Vector2 = ol[tris[i + 2]]
		pk.tri(kit, key, c + Vector3(a.x, y, a.y), c + Vector3(b.x, y, b.y), c + Vector3(d.x, y, d.y), n, n, n, col, n, a * uvk, b * uvk, d * uvk)


## A mine cart (Grubenhunt) at life size: its long axis along z, its four flanged wheels on the 600mm display line's rails
## (x ±0.318), y = 0 the rails' top: place it at the line's origin + (0, NG_RAIL_TOP, z). 1.62m over the buffers, 0.88
## wide, the tub's rim at 1.0. Variant 0 heaped with coal (to 1.33), 1 empty (its inside shows), 2 a rusty display cart
## planted with geraniums.
static func mine_cart(pk: PropKit, kit: Dictionary, variant := 0) -> void:
	var rusty: bool = variant == 2
	var key: String = "rusty" if rusty else "steel"
	var tub: Color = Color(0.46, 0.27, 0.17) if rusty else Color(0.22, 0.23, 0.23)
	var dark: Color = Color(0.30, 0.18, 0.12) if rusty else Color(0.10, 0.10, 0.10)
	var wr := 0.16
	for wz in [-0.42, 0.42]:
		pk.tube(kit, "steel", Vector3(-0.47, wr, wz), Vector3(0.47, wr, wz), 0.035, 0.035, 6, dark, true)
		for sx in [-1.0, 1.0]:
			var x: float = sx * NG_HALF
			pk.tube(kit, key, Vector3(x - 0.035, wr, wz), Vector3(x + 0.035, wr, wz), wr, wr, 10, dark, true)
			pk.tube(kit, key, Vector3(x - sx * 0.035, wr, wz), Vector3(x - sx * 0.055, wr, wz), wr + 0.022, wr + 0.022, 10, dark.darkened(0.2), true)
			pk.tube(kit, "steel", Vector3(x + sx * 0.035, wr, wz), Vector3(x + sx * 0.06, wr, wz), 0.06, 0.05, 8, dark, true)
			_box(pk, kit, key, Vector3(sx * 0.42, 0.23, wz), Basis(), Vector3(0.09, 0.16, 0.2), dark)
	for sx in [-1.0, 1.0]:
		_box(pk, kit, key, Vector3(sx * 0.42, 0.335, 0), Basis(), Vector3(0.06, 0.11, 1.5), dark)
	for e in [-1.0, 1.0]:
		_box(pk, kit, "wood" if not rusty else key, Vector3(0, 0.4, e * 0.76), Basis(), Vector3(0.7, 0.2, 0.12), Color(0.36, 0.26, 0.17) if not rusty else dark)
		# A coupling hook on one end, three chain links on the other.
		if e > 0.0:
			_box(pk, kit, "steel", Vector3(0, 0.4, 0.86), Basis(), Vector3(0.05, 0.12, 0.1), dark)
			_box(pk, kit, "steel", Vector3(0, 0.45, 0.9), Basis(), Vector3(0.062, 0.04, 0.06), dark)
		else:
			for k in range(3):
				var lz: float = -0.85 - 0.075 * float(k)
				_box(pk, kit, "steel", Vector3(0, 0.38, lz), Basis(Vector3(0, 0, 1), PI * 0.5 * float(k % 2)), Vector3(0.06, 0.018, 0.09), dark)
	# The tub: a rounded box flaring a little to its rim, inside walls and floor, two hoops, the rim's angle iron.
	var c := Vector3.ZERO
	var y0 := 0.38
	var y1 := 1.0
	var ob: PackedVector2Array = _rrect(0.38, 0.7, 0.12)
	var ot: PackedVector2Array = _rrect(0.44, 0.78, 0.16)
	var it: PackedVector2Array = _rrect(0.405, 0.745, 0.13)
	var ib: PackedVector2Array = _rrect(0.345, 0.665, 0.1)
	_loft(pk, kit, key, c, ob, y0, ot, y1, tub)
	_flat(pk, kit, key, c, ob, y0, false, dark)
	_loft(pk, kit, key, c, ib, y0 + 0.04, it, y1, tub.darkened(0.3), true)
	_flat(pk, kit, key, c, ib, y0 + 0.04, true, tub.darkened(0.4))
	for k in range(ot.size()):
		var j: int = (k + 1) % ot.size()
		pk.quad(kit, key, [c + Vector3(it[k].x, y1, it[k].y), c + Vector3(it[j].x, y1, it[j].y), c + Vector3(ot[j].x * 1.03, y1 + 0.02, ot[j].y * 1.02),
				c + Vector3(ot[k].x * 1.03, y1 + 0.02, ot[k].y * 1.02)], UP, tub.lightened(0.05))
	var lip0: PackedVector2Array = _rrect(0.453, 0.796, 0.17)
	_loft(pk, kit, key, c, lip0, y1 - 0.07, lip0, y1 + 0.02, tub.darkened(0.1))
	_flat(pk, kit, key, c, lip0, y1 - 0.07, false, dark)
	for hy in [0.55, 0.8]:
		var f: float = (hy - y0) / (y1 - y0)
		var hp := PackedVector2Array()
		for k in range(ob.size()):
			hp.append(ob[k].lerp(ot[k], f) * 1.03)
		_loft(pk, kit, key, c, hp, hy - 0.03, hp, hy + 0.03, tub.darkened(0.15))
	# A number plate on each side (variants 0 and 1).
	if not rusty:
		for sx in [-1.0, 1.0]:
			_box(pk, kit, "paint", Vector3(sx * 0.425, 0.68, 0.2), Basis(), Vector3(0.03, 0.12, 0.22), Color(0.88, 0.86, 0.8))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151 + variant
	if variant == 0:
		_coal_heap(pk, kit, Vector3(0, y1 - 0.05, 0), 0.41, 0.75, 0.32, rng)
		for k in range(14):
			var a: float = rng.randf() * TAU
			var rr: float = sqrt(rng.randf()) * 0.85
			var px: float = cos(a) * rr * 0.38
			var pz: float = sin(a) * rr * 0.7
			var py: float = y1 - 0.04 + 0.33 * (1.0 - rr * rr) * 0.9
			var s: float = rng.randf_range(0.05, 0.1)
			KT._blob(pk, kit, "coal", Vector3(px, py, pz), Vector3(s, s * 0.8, s * 1.1), Color(0.06, 0.06, 0.065).lightened(rng.randf() * 0.06))
	elif variant == 2:
		_flat(pk, kit, "matte", c, it, y1 - 0.12, true, Color(0.22, 0.15, 0.1))
		var blooms: Array = [Color(0.85, 0.1, 0.12), Color(0.92, 0.32, 0.46), Color(0.95, 0.93, 0.9)]
		for k in range(9):
			var px2: float = rng.randf_range(-0.28, 0.28)
			var pz2: float = rng.randf_range(-0.6, 0.6)
			KT._blob(pk, kit, "leaf", Vector3(px2, y1 + 0.02, pz2), Vector3(0.12, 0.07, 0.12), Color(0.2, 0.38, 0.14))
			var bc: Color = blooms[k % blooms.size()]
			KT._blob(pk, kit, "leaf", Vector3(px2 + 0.03, y1 + 0.13, pz2 - 0.02), Vector3(0.06, 0.05, 0.06), bc)


## A lumpy heap of coal on an elliptical foot (half sizes rx, rz) at c, `h` high: rings of facets jittered in and out.
static func _coal_heap(pk: PropKit, kit: Dictionary, c: Vector3, rx: float, rz: float, h: float, rng: RandomNumberGenerator) -> void:
	var segs := 12
	var rings: Array = [[1.0, 0.0], [0.88, 0.42], [0.62, 0.74], [0.3, 0.94]]
	var pts: Array = []
	for r in rings:
		var row: Array = []
		for k in range(segs):
			var a: float = TAU * float(k) / float(segs) + float(r[1]) * 0.6
			var inner: float = 1.0 if float(r[1]) > 0.0 else 0.0
			var j: float = 1.0 + rng.randf_range(-0.12, 0.1) * inner
			row.append(c + Vector3(cos(a) * rx * float(r[0]) * j, h * float(r[1]) + rng.randf_range(-0.02, 0.03) * inner, sin(a) * rz * float(r[0]) * j))
		pts.append(row)
	var top: Vector3 = c + Vector3(rng.randf_range(-0.04, 0.04), h, rng.randf_range(-0.06, 0.06))
	var col := Color(0.065, 0.065, 0.07)
	for i in range(rings.size()):
		for k in range(segs):
			var k1: int = (k + 1) % segs
			var a0: Vector3 = pts[i][k]
			var a1: Vector3 = pts[i][k1]
			if i + 1 < rings.size():
				var b0: Vector3 = pts[i + 1][k]
				var b1: Vector3 = pts[i + 1][k1]
				var n0: Vector3 = (a1 - a0).cross(b0 - a0).normalized()
				if n0.y < 0.0:
					n0 = -n0
				pk.tri(kit, "coal", a0, a1, b1, n0, n0, n0, col.lightened(rng.randf() * 0.05), n0)
				var n1: Vector3 = (b1 - a0).cross(b0 - a0).normalized()
				if n1.y < 0.0:
					n1 = -n1
				pk.tri(kit, "coal", a0, b1, b0, n1, n1, n1, col.lightened(rng.randf() * 0.05), n1)
			else:
				var n2: Vector3 = (a1 - a0).cross(top - a0).normalized()
				if n2.y < 0.0:
					n2 = -n2
				pk.tri(kit, "coal", a0, a1, top, n2, n2, n2, col.lightened(rng.randf() * 0.05), n2)


## A 600mm narrow-gauge display line along +z from z = 0 to `length`: a low gravel bed (top 0.06, 1.5 wide), timber sleepers
## every 0.7m, two flat-bottomed rails (centres x ±0.318) with their tops at NG_RAIL_TOP (0.227) over the ground; buffer
## stops at both ends.
static func narrow_gauge(pk: PropKit, kit: Dictionary, length: float) -> void:
	var gravel := Color(0.44, 0.42, 0.40)
	pk.extrude(kit, "heap", PackedVector2Array([Vector2(-1.05, -0.25), Vector2(1.05, -0.25), Vector2(0.75, 0.06), Vector2(-0.75, 0.06)]), -0.3, length + 0.3, 0.0, gravel)
	var n: int = int(floor(length / 0.7)) + 1
	for k in range(n):
		var z: float = 0.35 + 0.7 * float(k)
		if z > length:
			break
		_box(pk, kit, "timber", Vector3(0, 0.08, z), Basis(), Vector3(1.1, 0.12, 0.15), Color(0.34, 0.27, 0.2))
	for sx in [-1.0, 1.0]:
		var x: float = sx * NG_HALF
		pk.beam(kit, "rusty", Vector3(x, 0.146, -0.1), Vector3(x, 0.146, length + 0.1), 0.08, 0.012, Color(0.32, 0.22, 0.16))
		pk.beam(kit, "rusty", Vector3(x, 0.181, -0.1), Vector3(x, 0.181, length + 0.1), 0.013, 0.058, Color(0.32, 0.22, 0.16))
		pk.beam(kit, "steel", Vector3(x, 0.2135, -0.09), Vector3(x, 0.2135, length + 0.09), 0.036, 0.027, Color(0.48, 0.44, 0.40))
	for e in [-0.25, length + 0.25]:
		_box(pk, kit, "timber", Vector3(0, 0.3, e), Basis(), Vector3(1.0, 0.3, 0.2), Color(0.3, 0.24, 0.18))
		for sx in [-0.45, 0.45]:
			_box(pk, kit, "timber", Vector3(sx, 0.22, e + signf(e) * 0.12), Basis(), Vector3(0.14, 0.56, 0.14), Color(0.28, 0.22, 0.16))
		_box(pk, kit, "paint", Vector3(0, 0.3, e + signf(e - length * 0.5) * 0.11), Basis(), Vector3(0.6, 0.12, 0.02), Color(0.85, 0.12, 0.1))


# ======================================================================================
#  Kronprinzenblick: the landmark on the spoil heap's summit
# ======================================================================================

const SL_DECK := 21.0
const SL_HALF := 4.6
const SL_HUB := Vector3(0, 28.4, 0)
const SL_R := 5.0
const SL_WHEEL_COL := Color(0.55, 0.14, 0.10)


## Kronprinzenblick, the spoil heap's landmark (original): four raking corten legs, twisted a quarter-turn's fraction as
## they rise from feet on a 9.3m radius (footings within x, z ±9.5) to the corners of a square viewing platform (±4.6, floor
## 21.0) with corten parapets (KRONPRINZENBLICK cut into the ±z ones) and a light line under its edge; a cantilevered
## spiral stair round a central column climbs from the ground (its first tread toward +z) through the platform's middle;
## over the platform two A-frames carry a 10m winding sheave, red, its hub at (0, 28.4, 0) turning about x, its top at
## 33.5. `with_wheel` false leaves the wheel out (summit_wheel builds it alone, round its hub, to turn it). A corten plaque
## by the stair's foot. Footprint x, z ±9.5.
static func summit_landmark(pk: PropKit, kit: Dictionary, labels: Array, with_wheel := true) -> void:
	var cor := Color(0.50, 0.27, 0.15)
	var feet: Array = []
	var tops: Array = []
	for k in range(4):
		var at: float = PI * 0.25 + PI * 0.5 * float(k)
		var af: float = at + deg_to_rad(23.0)
		var top := Vector3(cos(at), 0, sin(at)) * (SL_HALF * sqrt(2.0) - 0.3) + UP * (SL_DECK - 0.55)
		var foot := Vector3(cos(af), 0, sin(af)) * 8.6
		tops.append(top)
		feet.append(foot)
		pk.beam(kit, "corten", foot - UP * 0.4, top, 0.7, 0.7, cor)
		_mblock(pk, kit, "concrete", foot + Vector3(-0.8, -1.6, -0.8), foot + Vector3(0.8, 0.25, 0.8), CONC)
		_box(pk, kit, "corten", foot + Vector3(0, 0.3, 0), Basis(), Vector3(1.2, 0.1, 1.2), cor.darkened(0.15))
	for f in [0.33, 0.66]:
		for k in range(4):
			var a: Vector3 = (feet[k] as Vector3).lerp(tops[k], f)
			var b: Vector3 = (feet[(k + 1) % 4] as Vector3).lerp(tops[(k + 1) % 4], f)
			pk.beam(kit, "corten", a, b, 0.4, 0.4, cor.darkened(0.05))
	# The platform: rim girders, deck plates round the stair's opening, parapets, the light line under its edge.
	var h := SL_HALF
	_ring_sides(pk, kit, "corten", Vector3.ZERO, h, h, 0.0, SL_DECK - 0.62, SL_DECK - 0.02, cor)
	_ring_flat(pk, kit, "corten", Vector3.ZERO, h, h, -0.45, 0.0, SL_DECK - 0.62, false, cor.darkened(0.3))
	var hp: float = h + 0.02
	for r in [Rect2(-hp, 1.9, hp * 2.0, hp - 1.9), Rect2(-hp, -hp, hp * 2.0, hp - 1.9), Rect2(1.9, -1.9, hp - 1.9, 3.8), Rect2(-hp, -1.9, hp - 1.9, 3.8)]:
		var rr: Rect2 = r
		_box(pk, kit, "steel", Vector3(rr.get_center().x, SL_DECK - 0.04, rr.get_center().y), Basis(), Vector3(rr.size.x, 0.08, rr.size.y), Color(0.24, 0.24, 0.23))
	for fi in range(4):
		var out: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][fi]
		var along: Vector3 = UP.cross(out)
		var bas := Basis(along, UP, out)
		var len_p: float = h * 2.0 + (0.08 if fi % 2 == 0 else -0.04)
		_box(pk, kit, "corten", out * (h + 0.02) + UP * (SL_DECK + 0.55), bas, Vector3(len_p, 1.1, 0.04), cor)
		_box(pk, kit, "corten", out * (h + 0.02) + UP * (SL_DECK + 1.12), bas, Vector3(len_p + 0.04, 0.06, 0.12), cor.darkened(0.1))
		_box(pk, kit, "lamp", out * (h + 0.06) + UP * (SL_DECK - 0.66), bas, Vector3(h * 2.0 - 0.2, 0.05, 0.05), Color(0.95, 0.85, 0.6))
		if fi % 2 == 0:
			_lbl(labels, "KRONPRINZENBLICK", out * (h + 0.065) + UP * (SL_DECK + 0.55), out, 0.5, Color(0.93, 0.89, 0.78), h * 2.0 - 0.6)
	SW._railing(pk, kit, [Vector3(-1.9, SL_DECK, 1.9), Vector3(1.9, SL_DECK, 1.9), Vector3(1.9, SL_DECK, -1.9), Vector3(-1.9, SL_DECK, -1.9)], 1.05, Color(0.2, 0.2, 0.2), "steel")
	# The spiral stair: a column, cantilevered treads, balusters and a handrail.
	pk.lathe(kit, "concrete", Vector3.ZERO, [Vector2(2.4, -0.6), Vector2(2.4, 0.12), Vector2(2.3, 0.15), Vector2(0.001, 0.15)], 8, CONC, true)
	pk.tube(kit, "corten", Vector3(0, 0.1, 0), Vector3(0, SL_DECK + 1.2, 0), 0.32, 0.32, 12, cor, true)
	var rise := 0.21
	var n: int = int(ceil(SL_DECK / rise))
	var step_a: float = deg_to_rad(24.0)
	var a0: float = PI * 0.5
	var prev := Vector3.ZERO
	for k in range(1, n + 1):
		var y: float = minf(rise * float(k), SL_DECK - 0.04)
		var a: float = a0 + step_a * float(k - 1)
		var dir := Vector3(cos(a), 0, sin(a))
		var tan_v := Vector3(-sin(a), 0, cos(a))
		_box(pk, kit, "steel", dir * 1.05 + UP * (y - 0.03), Basis(dir, UP, tan_v).orthonormalized(), Vector3(1.5, 0.05, 0.46), Color(0.26, 0.26, 0.25))
		var rp: Vector3 = dir * 1.75 + UP * (y + 1.0)
		if k % 3 == 1:
			_bar(pk, kit, "steel", dir * 1.75 + UP * y, rp, 0.035, 0.035, Color(0.18, 0.18, 0.18))
		if k > 1 and k % 2 == 1:
			pk.tube(kit, "steel", prev, rp, 0.03, 0.03, 4, Color(0.18, 0.18, 0.18), false)
			prev = rp
		elif k == 1:
			prev = rp
	# The A-frames carrying the sheave, its bearings.
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.95
		for sz in [-1.0, 1.0]:
			pk.beam(kit, "corten", Vector3(x, SL_DECK, sz * 3.7), Vector3(x, SL_HUB.y - 0.35, sz * 0.3), 0.36, 0.36, cor)
		pk.beam(kit, "corten", Vector3(x, SL_DECK + 2.6, -2.45), Vector3(x, SL_DECK + 2.6, 2.45), 0.26, 0.26, cor)
		_box(pk, kit, "steel", Vector3(x, SL_HUB.y - 0.12, 0), Basis(), Vector3(0.5, 0.62, 0.9), STEEL_DARK)
	if with_wheel:
		var sv := _push(pk, Transform3D(Basis(), SL_HUB))
		summit_wheel(pk, kit)
		_pop(pk, sv)
	# The plaque by the stair's foot.
	var pc := Vector3(0, 0, 3.6)
	_mblock(pk, kit, "concrete", pc + Vector3(-1.1, -0.3, -0.25), pc + Vector3(1.1, 0.5, 0.25), CONC)
	var tilt := Basis(Vector3.RIGHT, -0.5)
	_box(pk, kit, "corten", pc + Vector3(0, 0.8, 0.05), tilt, Vector3(2.0, 0.8, 0.05), cor)
	var pn: Vector3 = tilt * Vector3(0, 0, 1)
	_lbl(labels, "KRONPRINZENBLICK", pc + Vector3(0, 0.88, 0.05) + pn * 0.04, pn, 0.13, Color(0.93, 0.89, 0.78), 1.8)
	_lbl(labels, "HALDE DER ZECHE KRONPRINZ", pc + Vector3(0, 0.66, 0.05) + pn * 0.04 + tilt * Vector3(0, 0, 0), pn, 0.07, Color(0.9, 0.86, 0.76), 1.8)


## Kronprinzenblick's sheave alone, round its hub at the origin turning about x (10m across, ten spokes, red; "steel": no
## world-space weathering to swim over it as it turns). summit_wheel_hub() is where it goes in the landmark's frame.
static func summit_wheel(pk: PropKit, kit: Dictionary) -> void:
	_sheave(pk, kit, "steel", Vector3.ZERO, SL_R, 0.7, 10, SL_WHEEL_COL, 1.1, 40)


static func summit_wheel_hub() -> Vector3:
	return SL_HUB


# ======================================================================================
#  Fences, masts, boards, skips and drums
# ======================================================================================

## An industrial fence along +x from x = 0 to `length`: concrete posts every ~2.5m (0.14 square, 2.2 tall, footings to
## -0.6) cranked outward (+z) at the top, rusty chain-link mesh ("zfence", 5cm off the posts' +z faces) between them with
## top, middle and bottom wires, three strands of barbed wire along the cranked arms (to 2.65 high, 0.42 out).
static func industrial_fence(pk: PropKit, kit: Dictionary, length: float) -> void:
	var n: int = maxi(1, int(ceil(length / 2.5)))
	var step: float = length / float(n)
	var post := Color(0.62, 0.61, 0.57)
	var wire := Color(0.30, 0.24, 0.2)
	for k in range(n + 1):
		var x: float = step * float(k)
		_mblock(pk, kit, "concrete", Vector3(x - 0.07, -0.6, -0.07), Vector3(x + 0.07, 2.2, 0.07), post)
		pk.beam(kit, "concrete", Vector3(x, 2.15, 0.0), Vector3(x, 2.62, 0.45), 0.1, 0.08, post.darkened(0.08), Vector3.RIGHT, uvk)
	var mz := 0.12
	for k in range(n):
		var x0: float = step * float(k)
		var x1: float = x0 + step
		pk.quad(kit, "zfence", [Vector3(x0, 0.05, mz), Vector3(x1, 0.05, mz), Vector3(x1, 2.0, mz), Vector3(x0, 2.0, mz)], Vector3.BACK, Color(0.5, 0.42, 0.34),
				[Vector2(x0, 0.05), Vector2(x1, 0.05), Vector2(x1, 2.0), Vector2(x0, 2.0)])
	for wy in [0.08, 1.0, 1.98]:
		_bar(pk, kit, "steel", Vector3(0, wy, mz + 0.01), Vector3(length, wy, mz + 0.01), 0.008, 0.008, wire)
	for f in [0.35, 0.68, 1.0]:
		var p := Vector3(0, 2.15 + 0.47 * f, 0.45 * f)
		_bar(pk, kit, "steel", p + Vector3(0, 0.05, 0), Vector3(length, p.y + 0.05, p.z), 0.012, 0.012, wire)


## A 20m floodlight mast: a tapering square lattice (1.4m at the foot, 0.6 at the top) on a concrete foundation, a caged
## ladder up its +z face, a railed platform at 19.3, and a frame of four floodlights facing +z (tilted down) to 20.9; lit
## with `lit` (glowing lenses), else plain glass lenses. Footprint 2 x 2.
static func floodlight_mast(pk: PropKit, kit: Dictionary, lit := false) -> void:
	var col := Color(0.48, 0.50, 0.49)
	_mblock(pk, kit, "concrete", Vector3(-1.0, -1.5, -1.0), Vector3(1.0, 0.4, 1.0), CONC)
	var hb := 0.7
	var ht := 0.3
	var top := 19.2
	var cs: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c in cs:
		var cc: Vector2 = c
		_bar(pk, kit, "steel", Vector3(cc.x * hb, 0.4, cc.y * hb), Vector3(cc.x * ht, top, cc.y * ht), 0.12, 0.12, col)
	var lv := 10
	for j in range(lv + 1):
		var f0: float = float(j) / float(lv)
		var y0: float = lerpf(0.4, top, f0)
		var r0: float = lerpf(hb, ht, f0)
		for i in range(4):
			var ca: Vector2 = cs[i]
			var cb: Vector2 = cs[(i + 1) % 4]
			var a0 := Vector3(ca.x * r0, y0, ca.y * r0)
			var b0 := Vector3(cb.x * r0, y0, cb.y * r0)
			_bar(pk, kit, "steel", a0, b0, 0.06, 0.06, col)
			if j < lv:
				var f1: float = float(j + 1) / float(lv)
				var r1: float = lerpf(hb, ht, f1)
				var y1: float = lerpf(0.4, top, f1)
				_bar(pk, kit, "steel", a0, Vector3(cb.x * r1, y1, cb.y * r1), 0.05, 0.05, col)
	_cage_ladder(pk, kit, Vector3(0, 0.4, 0.55), Vector3(0, top, 0.32), Vector3.BACK, Color(0.4, 0.42, 0.41), 0.0)
	_box(pk, kit, "steel", Vector3(0, top + 0.05, 0), Basis(), Vector3(1.8, 0.1, 1.8), STEEL_DARK)
	SW._railing(pk, kit, [Vector3(-0.9, top + 0.1, -0.9), Vector3(0.9, top + 0.1, -0.9), Vector3(0.9, top + 0.1, 0.9), Vector3(-0.9, top + 0.1, 0.9), Vector3(-0.9, top + 0.1, -0.9)],
			1.0, col, "steel")
	_bar(pk, kit, "steel", Vector3(-1.4, top + 1.25, 0.6), Vector3(1.4, top + 1.25, 0.6), 0.1, 0.1, col)
	_bar(pk, kit, "steel", Vector3(-1.4, top + 0.6, 0.6), Vector3(1.4, top + 0.6, 0.6), 0.1, 0.1, col)
	for sx in [-0.95, 0.95]:
		_bar(pk, kit, "steel", Vector3(sx, top + 0.1, 0.6), Vector3(sx, top + 1.3, 0.6), 0.08, 0.08, col)
	var tilt := Basis(Vector3.RIGHT, 0.45)
	for fx in [-1.05, -0.35, 0.35, 1.05]:
		for fy in [top + 0.6, top + 1.25]:
			if (fx < 0.0) == (fy > top + 1.0) and absf(fx) < 0.5:
				continue
			var c := Vector3(fx, fy, 0.85)
			_box(pk, kit, "steel", c, tilt, Vector3(0.6, 0.42, 0.28), Color(0.22, 0.23, 0.23))
			var n: Vector3 = tilt * Vector3(0, 0, 1)
			_box(pk, kit, "lamp" if lit else "lens", c + n * 0.15, tilt, Vector3(0.5, 0.32, 0.02), Color(1.0, 0.93, 0.8) if lit else Color(0.55, 0.58, 0.6))


## A heritage-trail board: a steel-framed panel 1.8 x 1.2 tilted back 10 degrees on two posts, its face toward +z, the
## middle of its foot at the origin (top 2.2). `text`'s first line is the title (white on the trail's dark red header), the
## rest the body (dark on cream), one label per line.
static func plaque_board(pk: PropKit, kit: Dictionary, labels: Array, text: String) -> void:
	var post := Color(0.18, 0.19, 0.19)
	for sx in [-0.8, 0.8]:
		_box(pk, kit, "paint", Vector3(sx, 0.75, -0.06), Basis(), Vector3(0.08, 2.0, 0.08), post)
		_box(pk, kit, "concrete", Vector3(sx, -0.2, -0.06), Basis(), Vector3(0.3, 0.5, 0.3), CONC)
	var tilt := Basis(Vector3.RIGHT, -deg_to_rad(10.0))
	var c := Vector3(0, 1.55, 0.0)
	var n: Vector3 = tilt * Vector3(0, 0, 1)
	var up2: Vector3 = tilt * Vector3(0, 1, 0)
	_box(pk, kit, "paint", c, tilt, Vector3(1.86, 1.26, 0.05), post)
	_box(pk, kit, "enamel", c + n * 0.03 - up2 * 0.11, tilt, Vector3(1.76, 0.94, 0.02), Color(0.92, 0.89, 0.80))
	_box(pk, kit, "enamel", c + n * 0.03 + up2 * 0.47, tilt, Vector3(1.76, 0.22, 0.02), Color(0.52, 0.12, 0.09))
	_box(pk, kit, "paint", c + up2 * 0.66 + n * 0.02, tilt, Vector3(1.96, 0.06, 0.14), post)
	var lines: PackedStringArray = text.split("\n")
	if lines.size() > 0:
		_lbl(labels, lines[0], c + n * 0.05 + up2 * 0.47, n, 0.1, Color(0.97, 0.95, 0.9), 1.6)
	for k in range(1, lines.size()):
		_lbl(labels, lines[k], c + n * 0.05 + up2 * (0.24 - 0.11 * float(k - 1)), n, 0.055, Color(0.15, 0.13, 0.12), 1.6)


## A rusty skip (Absetzmulde) along x: 3.2 x 1.5 at its floor, flaring to 3.9 x 1.8 at the rim (1.45 high), open, with
## side ribs, lifting trunnions and a little scrap in it, on two skids. Footprint 3.9 x 1.9.
static func rust_skip(pk: PropKit, kit: Dictionary) -> void:
	var col := Color(0.44, 0.24, 0.14)
	var ob := PackedVector2Array([Vector2(1.6, 0.75), Vector2(-1.6, 0.75), Vector2(-1.6, -0.75), Vector2(1.6, -0.75)])
	var ot := PackedVector2Array([Vector2(1.95, 0.9), Vector2(-1.95, 0.9), Vector2(-1.95, -0.9), Vector2(1.95, -0.9)])
	var ib := PackedVector2Array([Vector2(1.56, 0.71), Vector2(-1.56, 0.71), Vector2(-1.56, -0.71), Vector2(1.56, -0.71)])
	var it := PackedVector2Array([Vector2(1.91, 0.86), Vector2(-1.91, 0.86), Vector2(-1.91, -0.86), Vector2(1.91, -0.86)])
	var y0 := 0.12
	var y1 := 1.45
	_loft(pk, kit, "rusty", Vector3.ZERO, ob, y0, ot, y1, col)
	_flat(pk, kit, "rusty", Vector3.ZERO, ob, y0, false, col.darkened(0.4))
	_loft(pk, kit, "rusty", Vector3.ZERO, ib, y0 + 0.05, it, y1, col.darkened(0.25), true)
	_flat(pk, kit, "rusty", Vector3.ZERO, ib, y0 + 0.05, true, col.darkened(0.3))
	for k in range(4):
		var j: int = (k + 1) % 4
		pk.quad(kit, "rusty", [Vector3(it[k].x, y1, it[k].y), Vector3(it[j].x, y1, it[j].y), Vector3(ot[j].x, y1, ot[j].y), Vector3(ot[k].x, y1, ot[k].y)], UP, col)
	for sz in [-1.0, 1.0]:
		_box(pk, kit, "rusty", Vector3(0, 0.06, sz * 0.5), Basis(), Vector3(3.3, 0.12, 0.14), col.darkened(0.3))
		for x in [-1.2, -0.4, 0.4, 1.2]:
			var a := Vector3(x * 1.0, y0, sz * 0.78)
			var b := Vector3(x * 1.2, y1 - 0.05, sz * 0.93)
			pk.beam(kit, "rusty", a, b, 0.1, 0.06, col.darkened(0.1), Vector3.RIGHT)
		for x in [-1.1, 1.1]:
			pk.tube(kit, "rusty", Vector3(x, 1.05, sz * 0.88), Vector3(x, 1.05, sz * 1.0), 0.09, 0.09, 8, col.darkened(0.2), true)
	_box(pk, kit, "rusty", Vector3(0.3, 0.32, 0.1), Basis(Vector3.UP, 0.4), Vector3(2.2, 0.14, 0.16), Color(0.36, 0.2, 0.12))
	_box(pk, kit, "rusty", Vector3(-0.6, 0.3, -0.2), Basis(Vector3.UP, -0.9), Vector3(1.2, 0.2, 0.3), Color(0.4, 0.38, 0.35))
	pk.tyre(kit, "rubber", Vector3(0.9, 0.3, -0.3), 0.25, 0.45, 0.22, 12, Color(0.06, 0.06, 0.06))


## A wooden cable drum standing on its flanges (2m across, axis along x), half wound with black cable, its loose end on the
## ground toward +z. The origin on the ground under its middle.
static func cable_drum(pk: PropKit, kit: Dictionary) -> void:
	var r := 1.0
	var c := Vector3(0, r, 0)
	var wb := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
	var wood := Color(0.48, 0.36, 0.24)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "wood", c + Vector3(sx * 0.5, 0, 0), c + Vector3(sx * 0.58, 0, 0), r, r, 16, wood, true)
		for k in range(4):
			var a: float = TAU * float(k) / 4.0 + 0.3
			var d := Vector3(0, cos(a), sin(a))
			pk.beam(kit, "wood", c + Vector3(sx * 0.6, 0, 0) - d * 0.9, c + Vector3(sx * 0.6, 0, 0) + d * 0.9, 0.12, 0.04, wood.darkened(0.15), Vector3(0, -sin(a), cos(a)))
		pk.tube(kit, "steel", c + Vector3(sx * 0.6, 0, 0), c + Vector3(sx * 0.63, 0, 0), 0.18, 0.18, 10, STEEL_DARK, true)
	var prof: Array = []
	for k in range(9):
		var x: float = lerpf(-0.5, 0.5, float(k) / 8.0)
		prof.append(Vector2(0.72 if k % 2 == 0 else 0.76, x))
	pk.lathe(kit, "rubber", c, prof, 16, Color(0.05, 0.05, 0.05), false, wb)
	pk.tube(kit, "rubber", c + Vector3(0.3, -0.74, 0.0), Vector3(0.3, 0.05, 1.6), 0.04, 0.04, 6, Color(0.05, 0.05, 0.05), false)
	pk.tube(kit, "rubber", Vector3(0.3, 0.05, 1.6), Vector3(0.1, 0.05, 2.6), 0.04, 0.04, 6, Color(0.05, 0.05, 0.05), true)


# ======================================================================================
#  Brownfield plants (MultiMesh meshes, life size, the origin at the foot)
# ======================================================================================

## A kit for a plant: identity frame, this kit's materials, `uvk` untouched (a generator may be mid-way through a building).
static func _plant_kit() -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	return pk


## A tapering stem along `pts` (radii per point), `sides` round; with `flower` its UVs run round (x) and along (y) and its
## colour's alpha is 0 (zeche_plant draws florets on it), closed in a point at the end.
static func _stem(pk: PropKit, kit: Dictionary, pts: Array, radii: Array, sides: int, col: Color, flower := false) -> void:
	var n: int = pts.size()
	var c: Color = Color(col.r, col.g, col.b, 0.0 if flower else 1.0)
	var rings: Array = []
	for i in range(n):
		var p: Vector3 = pts[i]
		var t: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var s: Vector3 = t.cross(UP if absf(t.y) < 0.95 else Vector3.RIGHT).normalized()
		var u: Vector3 = s.cross(t).normalized()
		var ring: Array = []
		for k in range(sides):
			var a: float = TAU * float(k) / float(sides)
			ring.append([p + (s * cos(a) + u * sin(a)) * float(radii[i]), (s * cos(a) + u * sin(a))])
		rings.append(ring)
	for i in range(n - 1):
		var v0: float = float(i) / float(n - 1)
		var v1: float = float(i + 1) / float(n - 1)
		for k in range(sides):
			var k1: int = (k + 1) % sides
			var a: Array = rings[i][k]
			var b: Array = rings[i][k1]
			var d: Array = rings[i + 1][k]
			var e: Array = rings[i + 1][k1]
			var u0: float = float(k) / float(sides)
			var u1: float = float(k + 1) / float(sides)
			var nm: Vector3 = ((a[1] as Vector3) + (b[1] as Vector3)).normalized()
			pk.tri(kit, "zplant", a[0], b[0], e[0], a[1], b[1], e[1], c, nm, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
			pk.tri(kit, "zplant", a[0], e[0], d[0], a[1], e[1], d[1], c, nm, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))


## A leaf: a diamond from `base` along `dir`, `w` wide across `side`, its midrib a little raised; two triangles.
static func _leaf(pk: PropKit, kit: Dictionary, base: Vector3, dir: Vector3, side: Vector3, length: float, w: float, col: Color) -> void:
	var n: Vector3 = side.cross(dir).normalized()
	if n.y < 0.0:
		n = -n
	var tip: Vector3 = base + dir * length
	var l: Vector3 = base + dir * (length * 0.38) + side * (w * 0.5)
	var r: Vector3 = base + dir * (length * 0.38) - side * (w * 0.5)
	var nl: Vector3 = (n + side * 0.35).normalized()
	var nr: Vector3 = (n - side * 0.35).normalized()
	var c := Color(col.r, col.g, col.b, 1.0)
	pk.tri(kit, "zplant", base, l, tip, n, nl, n, c, n)
	pk.tri(kit, "zplant", base, tip, r, n, n, nr, c, n)


## Points along a quadratic Bézier.
static func _qb(p0: Vector3, p1: Vector3, p2: Vector3, n: int) -> Array:
	var out: Array = []
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		out.append(p0 * (1.0 - t) * (1.0 - t) + p1 * 2.0 * t * (1.0 - t) + p2 * t * t)
	return out


## A card for zeche_plant (a leaf fan, mode 0.75, or a plume, 0.5): a quad from `base` up `up_v` (h long) and `w` wide along
## `side`, its UVs (id..id + 1 across, 0..1 up) so each card draws its own variation.
static func _card(pk: PropKit, kit: Dictionary, base: Vector3, up_v: Vector3, side: Vector3, w: float, h: float, col: Color, mode_a: float, id: int) -> void:
	var c := Color(col.r, col.g, col.b, mode_a)
	var hs: Vector3 = side * (w * 0.5)
	var top: Vector3 = base + up_v * h
	var n: Vector3 = side.cross(up_v).normalized()
	if n.y < 0.0:
		n = -n
	var u0 := float(id)
	pk.tri(kit, "zplant", base - hs, base + hs, top + hs, n, n, n, c, n, Vector2(u0, 0), Vector2(u0 + 1.0, 0), Vector2(u0 + 1.0, 1))
	pk.tri(kit, "zplant", base - hs, top + hs, top - hs, n, n, n, c, n, Vector2(u0, 0), Vector2(u0 + 1.0, 1), Vector2(u0, 1))


## Buddleia (butterfly bush), the brownfield's shrub: 8-10 arching canes from a tight base to about 2.5m, clothed in sprays of
## lanceolate grey-green leaves (zeche_plant leaf cards, five leaves each, silvery under), each cane ending in a nodding
## conical panicle of purple florets (a few lilac or pink, the odd one spent and brown), some with a side spike. Built at life
## size round its foot, one "zplant" surface; about 0.9k triangles.
static func buddleia_mesh(seed_v: int) -> ArrayMesh:
	var pk := _plant_kit()
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var spikes: Array = [Color(0.50, 0.30, 0.66), Color(0.44, 0.22, 0.58), Color(0.56, 0.36, 0.70), Color(0.60, 0.34, 0.60)]
	var spent := Color(0.38, 0.28, 0.20)
	var bark := Color(0.40, 0.36, 0.28)
	var n_c: int = rng.randi_range(8, 10)
	var card_id := 0
	for i in range(n_c):
		var ang: float = TAU * float(i) / float(n_c) + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var height: float = rng.randf_range(1.6, 2.5)
		var reach: float = rng.randf_range(0.5, 1.1)
		var p0: Vector3 = dir * rng.randf_range(0.0, 0.14) - UP * 0.05
		var p2: Vector3 = p0 + dir * reach + UP * height * rng.randf_range(0.8, 0.92)
		var p1: Vector3 = p0 + dir * (reach * 0.2) + UP * height
		var curve: Array = _qb(p0, p1, p2, 20)
		_stem(pk, kit, _qb(p0, p1, p2, 4), [0.028, 0.022, 0.016, 0.012, 0.009], 3, bark.lerp(Color(0.35, 0.42, 0.28), rng.randf() * 0.5))
		var leaf := Color(0.38, 0.45, 0.31).lerp(Color(0.46, 0.51, 0.39), rng.randf())
		# Leaf sprays along the cane, fanning outward and up, each turned a little further round it.
		var n_cards := 9
		for k in range(n_cards):
			var t: float = 0.24 + 0.72 * float(k) / float(n_cards - 1) + rng.randf_range(-0.03, 0.03)
			var b: Vector3 = curve[clampi(int(t * 20.0), 0, 20)]
			var tn: Vector3 = (2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1)).normalized()
			var rot: float = float(k) * 2.2 + rng.randf_range(-0.5, 0.5)
			var perp: Vector3 = tn.cross(UP).normalized().rotated(tn, rot)
			var out_h := Vector3(b.x, 0, b.z)
			out_h = out_h.normalized() if out_h.length() > 0.05 else dir
			var nrm: Vector3 = (out_h + UP * 0.35 + perp * 0.4).normalized()
			var up_v: Vector3 = (perp * 0.7 + tn * 0.5 + UP * 0.25).normalized()
			up_v = (up_v - nrm * up_v.dot(nrm)).normalized()
			var side: Vector3 = nrm.cross(up_v).normalized()
			var sz: float = rng.randf_range(0.34, 0.44) * (1.0 - 0.25 * t)
			_card(pk, kit, b - up_v * 0.03, up_v, side, sz, sz, leaf.darkened(rng.randf() * 0.12), 0.75, card_id)
			card_id += 1
		# The panicle: a cone on along the cane's end, nodding at its tip.
		var tip_t: Vector3 = (p2 - p1).normalized()
		var sl: float = rng.randf_range(0.28, 0.42)
		var sp1: Vector3 = p2 + tip_t * sl * 0.55 + UP * 0.02
		var sp2: Vector3 = p2 + tip_t * sl * 0.9 - UP * sl * 0.35
		var sc: Color = spent if rng.randf() < 0.1 else spikes[rng.randi_range(0, spikes.size() - 1)]
		_stem(pk, kit, _qb(p2, sp1, sp2, 3), [0.06, 0.058, 0.04, 0.006], 4, sc, true)
		if rng.randf() < 0.6:
			var b3: Vector3 = curve[17]
			var sd3: Vector3 = tip_t.cross(UP).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
			var q3: Vector3 = b3 + (sd3 + tip_t).normalized() * sl * 0.6 - UP * sl * 0.2
			_stem(pk, kit, _qb(b3, b3 + (sd3 + UP).normalized() * sl * 0.3, q3, 2), [0.042, 0.032, 0.006], 4, sc.lightened(0.05), true)
	# Sprays round the base.
	for k in range(7):
		var a: float = TAU * float(k) / 7.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		var up_b: Vector3 = (d * 0.6 + UP * 0.8).normalized()
		var nb: Vector3 = (d * 0.8 - UP * 0.6).normalized()
		nb = (nb - up_b * nb.dot(up_b)).normalized()
		_card(pk, kit, d * 0.1, up_b, nb.cross(up_b).normalized(), 0.5, 0.55, Color(0.34, 0.41, 0.28), 0.75, card_id)
		card_id += 1
	return pk.commit(kit)


## Canada goldenrod (Kanadische Goldrute), a clump of 11-14 straight stems 0.9-1.4m tall with narrow alternate leaves, each
## topped by a pyramidal panicle (two crossed zeche_plant plume cards: arching sprays of small yellow florets). Built at life
## size round its foot, one "zplant" surface; about 0.5k triangles.
static func goldenrod_mesh(seed_v: int) -> ArrayMesh:
	var pk := _plant_kit()
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n_s: int = rng.randi_range(11, 14)
	var stem := Color(0.36, 0.42, 0.24)
	var yellow := Color(0.92, 0.74, 0.16)
	for i in range(n_s):
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * 0.3
		var base := Vector3(cos(a) * r, -0.03, sin(a) * r)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.18) + Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
		var h: float = rng.randf_range(0.9, 1.4)
		var top: Vector3 = base + UP * h + lean
		var pan: Vector3 = base.lerp(top, 0.74)
		_stem(pk, kit, [base, base.lerp(top, 0.5) + lean * 0.12, top], [0.012, 0.009, 0.004], 3, stem.lerp(Color(0.42, 0.36, 0.22), rng.randf() * 0.4))
		var lc := Color(0.32, 0.44, 0.21).lerp(Color(0.42, 0.50, 0.25), rng.randf())
		for k in range(10):
			var t: float = 0.08 + 0.064 * float(k)
			var b: Vector3 = base.lerp(top, t)
			var la: float = a + 2.4 * float(k)
			var ld := (Vector3(cos(la), 0, sin(la)) + UP * 0.75).normalized()
			_leaf(pk, kit, b, ld, Vector3(cos(la), 0, sin(la)).cross(UP).normalized(), rng.randf_range(0.1, 0.15) * (1.0 - 0.35 * t), 0.022, lc)
		# The panicle: two plume cards crossed on the stem's top.
		var yc: Color = yellow.lerp(Color(0.76, 0.70, 0.24), rng.randf() * 0.35)
		var axis: Vector3 = (top - pan).normalized()
		var ph: float = rng.randf() * PI
		var ph_dir := Vector3(cos(ph), 0, sin(ph))
		var ph2 := Vector3(-sin(ph), 0, cos(ph))
		var ph_len: float = pan.distance_to(top) + 0.06
		var pw: float = rng.randf_range(0.24, 0.32)
		_card(pk, kit, pan - axis * 0.02, axis, ph_dir, pw, ph_len, yc, 0.5, i * 2)
		_card(pk, kit, pan - axis * 0.02, axis, ph2, pw * 0.9, ph_len * 0.97, yc.darkened(0.04), 0.5, i * 2 + 1)
	return pk.commit(kit)
