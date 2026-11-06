extends RefCounted
## The Kronburger Hütte's industrial set pieces (Kronburg GP, stage 1, regenerate_kronburg.gd): Walzwerk 2 (the rolling
## mill hall the lap drives through, with its mill train, cranes and pulpit), Hochofen 3 (the blast furnace with its
## skip hoist, dust catcher and cast house), the hot-blast stoves (Cowper) and their chimney, a disc gas holder,
## chimneys and a cooling tower, pipe bridges and pipe runs, the headframe of the old colliery Zeche Kronprinz with its
## winding engine house, a torpedo ladle car, the works gate, the steel crown on the slag heap, the canal basin's ore
## unloading bridge, an inland barge and ore heaps. All fictional: generic Ruhr types, no real works or landmarks.
##
## Everything is built through a PropKit at LIFE size, in its own frame (y = 0 the ground or floor, footings down to
## y = -3) and grown by the caller (PROP_SCALE 1.6). UVs are in metres times `uvk` (the caller's scale) where a shader
## reads them (brick, concrete, corrugated iron), in life metres on glazing (steel_glazing.gdshader draws the panes).
## Labels are [text, position, outward normal, cap height, colour, board width] in life-size kit coordinates.
##
## Material keys (make_material): "brick" and "concrete" (hut_masonry 2 and 8), "iron" (hut_roof_iron), "timber"
## (hut_wood), "steel"/"metal"/"matte"/"rubber"/"paint" (vertex colour), "glass" and "skylight" (steel_glazing: the outer
## and inner face of a window), "hot" (hot_steel.gdshader: glowing steel, the vertex colour its glow, hot_colour(t)),
## "rusty", "corten", "grime", "floor" (industrial_paint.gdshader: weathering from the world position), "hazard"
## (hazard_stripes.gdshader), "lamp" (LampGlow: lit lamps inside the hall), "lens" (an unlit outdoor lamp), "heap"
## (ore and coal). Every mesh made here starts (alphabetically) with an opaque key, so DressingColliders never takes
## one for see-through.

const PropKit = preload("res://PropKit.gd")
const YardKit = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")
const LampGlow = preload("res://LampGlow.gd")

static var uvk := 1.6
static var _mats := {}
## The current sub-assembly's offset inside the kit's own frame (labels are given in kit coordinates).
static var _lx := Transform3D.IDENTITY

const TANGENT_KEYS := ["iron", "concrete", "slate"]

const WHITE := Color(1, 1, 1)
const BRICK := Color(0.44, 0.21, 0.15)
const BRICK_DARK := Color(0.33, 0.16, 0.12)
const FIREBRICK := Color(0.80, 0.66, 0.46)
const CONCRETE := Color(0.64, 0.63, 0.60)
const STEEL := Color(0.26, 0.31, 0.30)
const STEEL_DARK := Color(0.16, 0.18, 0.18)
const MACHINE := Color(0.19, 0.31, 0.27)
const CRANE_YELLOW := Color(0.93, 0.68, 0.10)
const ROOF_GREY := Color(0.50, 0.49, 0.46)
const CASING := Color(0.34, 0.34, 0.35)
const RAIL_GREY := Color(0.40, 0.40, 0.41)
const SIGN_YELLOW := Color(0.98, 0.80, 0.10)
const SIGN_BLUE := Color(0.10, 0.30, 0.62)
const ENAMEL_GREEN := Color(0.09, 0.24, 0.18)
const CREAM := Color(0.94, 0.91, 0.82)
const BLACK := Color(0.03, 0.03, 0.03)
const GAS_GREEN := Color(0.33, 0.39, 0.35)
const RED_WHITE_RED := Color(0.72, 0.13, 0.10)


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"hot":
			var h := ShaderMaterial.new()
			h.shader = load("res://hot_steel.gdshader")
			return h
		"glass", "skylight":
			var g := ShaderMaterial.new()
			g.shader = load("res://steel_glazing.gdshader")
			g.set_shader_parameter("inside", key == "skylight")
			return g
		"rusty", "corten", "grime", "floor", "shell", "roofing":
			var p := ShaderMaterial.new()
			p.shader = load("res://industrial_paint.gdshader")
			match key:
				"rusty":
					p.set_shader_parameter("rust_amount", 0.4)
					p.set_shader_parameter("grime", 0.45)
					p.set_shader_parameter("rough", 0.6)
					p.set_shader_parameter("metal", 0.25)
				"corten":
					p.set_shader_parameter("corten", 1.0)
					p.set_shader_parameter("rust_color", Color(0.52, 0.25, 0.11))
					p.set_shader_parameter("grime", 0.3)
					p.set_shader_parameter("patch_size", 1.6)
				"grime":
					p.set_shader_parameter("rust_amount", 0.12)
					p.set_shader_parameter("rust_color", Color(0.36, 0.27, 0.2))
					p.set_shader_parameter("grime", 0.5)
					p.set_shader_parameter("rough", 0.9)
					p.set_shader_parameter("metal", 0.0)
					p.set_shader_parameter("patch_size", 5.0)
				"floor":
					p.set_shader_parameter("rust_amount", 0.15)
					p.set_shader_parameter("rust_color", Color(0.30, 0.22, 0.15))
					p.set_shader_parameter("grime", 0.6)
					p.set_shader_parameter("rough", 0.8)
					p.set_shader_parameter("metal", 0.0)
					p.set_shader_parameter("patch_size", 2.5)
				"roofing":
					# Slate or tarred roofs (the colliery's buildings): no rust, weathered and streaked.
					p.set_shader_parameter("rust_amount", 0.0)
					p.set_shader_parameter("grime", 0.4)
					p.set_shader_parameter("rough", 0.82)
					p.set_shader_parameter("metal", 0.0)
					p.set_shader_parameter("patch_size", 2.0)
				"shell":
					# Sheet steel with less rust (the gas holder, the stoves): weathered paint.
					p.set_shader_parameter("rust_amount", 0.22)
					p.set_shader_parameter("grime", 0.55)
					p.set_shader_parameter("rough", 0.7)
					p.set_shader_parameter("metal", 0.15)
					p.set_shader_parameter("patch_size", 4.0)
			return p
		"hazard":
			var z := ShaderMaterial.new()
			z.shader = load("res://hazard_stripes.gdshader")
			return z
		"lamp":
			return LampGlow.material(2.2)
		"lens":
			var l := CampKit.make_material("plastic")
			l.roughness = 0.15
			l.metallic = 0.3
			return l
		"heap":
			var hp := ShaderMaterial.new()
			hp.shader = load("res://industrial_paint.gdshader")
			hp.set_shader_parameter("rust_amount", 0.35)
			hp.set_shader_parameter("rust_color", Color(0.24, 0.14, 0.1))
			hp.set_shader_parameter("grime", 0.45)
			hp.set_shader_parameter("rough", 1.0)
			hp.set_shader_parameter("metal", 0.0)
			hp.set_shader_parameter("patch_size", 1.8)
			return hp
		"brick":
			var b := ShaderMaterial.new()
			b.shader = load("res://ruhr_brick.gdshader")
			return b
		"concrete", "iron", "timber", "painted", "stone", "slate":
			return YardKit.make_material(key)
	return CampKit.make_material(key)


## A kit growing everything by `scale`, its materials shared with every other kit made here.
static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	YardKit.uvk = scale
	_lx = Transform3D.IDENTITY
	return pk


## The materials made so far, by key (the generator saves them so every mesh shares one per key).
static func materials() -> Dictionary:
	return _mats


## Commits a kit with tangents on the surfaces whose shaders read a normal map.
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in TANGENT_KEYS:
		if kit.has(key):
			var st: SurfaceTool = kit[key]
			st.index()
			st.generate_tangents()
	return pk.commit(kit)


## The glow of steel at temperature `t` (0: just glowing, dull red; 0.5 cherry-orange; 1 yellow-white), for "hot".
static func hot_colour(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var stops: Array = [Color(0.30, 0.03, 0.01), Color(0.62, 0.10, 0.02), Color(0.95, 0.32, 0.05), Color(1.0, 0.62, 0.22), Color(1.0, 0.88, 0.62)]
	var f: float = t * float(stops.size() - 1)
	var i: int = mini(int(f), stops.size() - 2)
	return (stops[i] as Color).lerp(stops[i + 1], f - float(i))


# ======================================================================================
#  Helpers
# ======================================================================================

## Moves the kit's frame by `t` (a local offset for a sub-assembly); returns the frame to put back with `_pop`.
static func _push(pk: PropKit, t: Transform3D) -> Array:
	var saved: Array = [pk.xf, _lx]
	pk.set_frame(pk.xf * t)
	_lx = _lx * t
	return saved


static func _pop(pk: PropKit, saved: Array) -> void:
	pk.set_frame(saved[0])
	_lx = saved[1]


static func _label(labels: Array, text: String, p: Vector3, n: Vector3, cap: float, col: Color, w := 0.0) -> void:
	labels.append([text, _lx * p, (_lx.basis * n).normalized(), cap, col, w])


## Axis-aligned block between two corners, UVs in metres.
static func _blk(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	pk.block(kit, key, Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z)), Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z)), col, uvk)


## A box centred at `c` turned by `basis`, UVs in metres.
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## An I-section from a to b: `d` deep along `up` (made square to the axis), flanges `f` wide.
static func _ibeam(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, d: float, f: float, col: Color, up := Vector3.UP, tw := 0.03, tf := 0.04) -> void:
	var ax := b - a
	if ax.length_squared() < 1e-8:
		return
	ax = ax.normalized()
	var u := up - ax * up.dot(ax)
	if u.length_squared() < 1e-6:
		u = Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.BACK
	u = u.normalized()
	var s := ax.cross(u).normalized()
	pk.beam(kit, key, a, b, tw, d - tf * 2.0 + 0.012, col, s)
	for sg in [-1.0, 1.0]:
		var o: Vector3 = u * (sg * (d * 0.5 - tf * 0.5))
		pk.beam(kit, key, a + o, b + o, f, tf, col, s)


## Sorted, unique cut positions clamped to [lo, hi].
static func _cuts(vals: Array, lo: float, hi: float) -> Array:
	var out: Array = []
	vals.sort()
	for v in vals:
		var c: float = clampf(v, lo, hi)
		if out.is_empty() or c - float(out[-1]) > 0.002:
			out.append(c)
	return out


static func _in_hole(holes: Array, u: float, v: float) -> bool:
	for h in holes:
		if (h[0] as Rect2).has_point(Vector2(u, v)):
			return true
	return false


## One rectangle of a wall: its outer face (facing `out`) and its inner face `thick` behind.
static func _wall_rect(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, ua: float, ub: float, va: float, vb: float,
		col: Color, icol: Color, thick: float) -> void:
	var pts: Array = [p0 + along * ua + Vector3.UP * va, p0 + along * ub + Vector3.UP * va, p0 + along * ub + Vector3.UP * vb, p0 + along * ua + Vector3.UP * vb]
	var uv: Array = [Vector2(ua, va) * uvk, Vector2(ub, va) * uvk, Vector2(ub, vb) * uvk, Vector2(ua, vb) * uvk]
	pk.quad(kit, key, pts, out, col, uv)
	if thick > 0.0:
		var back: Vector3 = -out * thick
		pk.quad(kit, key, [pts[0] + back, pts[1] + back, pts[2] + back, pts[3] + back], -out, icol, uv)


## A wall with openings: the plane through p0 (u along `along`, v up), faces out toward `out`, `thick` deep, between
## u0..u1 and v0..v1 (v is the height: p0.y should be 0). `holes` are [Rect2(u, v, w, h), reveal?]: each gets jambs, a sill
## and a head through the wall's depth unless reveal is false (a portal frame covers it).
static func _wall_holes(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, u0: float, u1: float,
		v0: float, v1: float, holes: Array, col: Color, thick: float, reveal_key := "") -> void:
	var us: Array = [u0, u1]
	var vs: Array = [v0, v1]
	for h in holes:
		var r: Rect2 = h[0]
		us.append_array([r.position.x, r.end.x])
		vs.append_array([r.position.y, r.end.y])
	us = _cuts(us, u0, u1)
	vs = _cuts(vs, v0, v1)
	var icol: Color = col.darkened(0.12)
	for b in range(vs.size() - 1):
		var va: float = vs[b]
		var vb: float = vs[b + 1]
		var vm: float = (va + vb) * 0.5
		var a := 0
		while a < us.size() - 1:
			if _in_hole(holes, (float(us[a]) + float(us[a + 1])) * 0.5, vm):
				a += 1
				continue
			var e := a + 1
			while e < us.size() - 1 and not _in_hole(holes, (float(us[e]) + float(us[e + 1])) * 0.5, vm):
				e += 1
			_wall_rect(pk, kit, key, p0, along, out, us[a], us[e], va, vb, col, icol, thick)
			a = e
	var rk: String = key if reveal_key == "" else reveal_key
	for h in holes:
		if h.size() > 1 and not h[1]:
			continue
		var r: Rect2 = h[0]
		var back: Vector3 = -out * thick
		for side in [0, 1]:
			var u: float = r.position.x if side == 0 else r.end.x
			var n: Vector3 = along if side == 0 else -along
			var pa: Vector3 = p0 + along * u + Vector3.UP * r.position.y
			var pb: Vector3 = p0 + along * u + Vector3.UP * r.end.y
			pk.quad(kit, rk, [pa, pb, pb + back, pa + back], n, col.darkened(0.08),
					[Vector2(0, r.position.y) * uvk, Vector2(0, r.end.y) * uvk, Vector2(thick, r.end.y) * uvk, Vector2(thick, r.position.y) * uvk])
		for side in [0, 1]:
			var v: float = r.position.y if side == 0 else r.end.y
			if (side == 0 and v <= v0 + 0.001) or (side == 1 and v >= v1 - 0.001):
				continue
			var n2: Vector3 = Vector3.UP if side == 0 else Vector3.DOWN
			var qa: Vector3 = p0 + along * r.position.x + Vector3.UP * v
			var qb: Vector3 = p0 + along * r.end.x + Vector3.UP * v
			pk.quad(kit, rk, [qa, qb, qb + back, qa + back], n2, col.darkened(0.15),
					[Vector2(r.position.x, 0) * uvk, Vector2(r.end.x, 0) * uvk, Vector2(r.end.x, thick) * uvk, Vector2(r.position.x, thick) * uvk])


## A polygon of wall (u, v) in the plane through p0, both faces (the inner `thick` behind), UVs in metres.
static func _wall_poly(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, poly: PackedVector2Array, col: Color, thick: float) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	for side in [0, 1]:
		var n: Vector3 = out if side == 0 else -out
		var off: Vector3 = Vector3.ZERO if side == 0 else -out * thick
		var c: Color = col if side == 0 else col.darkened(0.12)
		for i in range(0, tris.size(), 3):
			var a: Vector2 = poly[tris[i]]
			var b: Vector2 = poly[tris[i + 1]]
			var d: Vector2 = poly[tris[i + 2]]
			pk.tri(kit, key, p0 + along * a.x + Vector3.UP * a.y + off, p0 + along * b.x + Vector3.UP * b.y + off, p0 + along * d.x + Vector3.UP * d.y + off,
					n, n, n, c, n, a * uvk, b * uvk, d * uvk)


## A glazed opening's glass: the outer face ("glass", facing `out`) and 2cm behind it the inner ("skylight"), u along
## `along`, v along `up`, UVs in life metres for the pane grid. `c` is the pane's middle.
static func _glazing(pk: PropKit, kit: Dictionary, c: Vector3, along: Vector3, up: Vector3, out: Vector3, w: float, h: float) -> void:
	var hu: Vector3 = along * (w * 0.5)
	var hv: Vector3 = up * (h * 0.5)
	var pts: Array = [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
	var uv: Array = [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	pk.quad(kit, "glass", pts, out, WHITE, uv)
	var back: Vector3 = -out * 0.02
	pk.quad(kit, "skylight", [pts[0] + back, pts[1] + back, pts[2] + back, pts[3] + back], -out, WHITE, uv)


## A steel window frame round a glazed opening on the outside: four bars standing `proud` out of the glass, a heavier
## mullion and transom (the frame's own sections).
static func _window_frame(pk: PropKit, kit: Dictionary, c: Vector3, along: Vector3, out: Vector3, w: float, h: float, col := STEEL, mullions := 1, transoms := 1) -> void:
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized())
	if basis.z.dot(out) < 0.0:
		basis = Basis(along, Vector3.UP, -basis.z)
	# The bars meet face to face (none overlaps another in one plane): the head and sill across the full width, the
	# jambs between them, the mullions 1.5cm behind the frame's face and the transoms 1.5cm behind the mullions.
	var fw := 0.1
	for sv in [-1.0, 1.0]:
		_box(pk, kit, "steel", c + Vector3.UP * (sv * (h * 0.5 + fw * 0.5)) + out * 0.04, basis, Vector3(w + fw * 2.0, fw, 0.08), col)
	for su in [-1.0, 1.0]:
		_box(pk, kit, "steel", c + along * (su * (w * 0.5 + fw * 0.5)) + out * 0.04, basis, Vector3(fw, h, 0.08), col)
	for k in range(mullions):
		var u: float = (float(k + 1) / float(mullions + 1) - 0.5) * w
		_box(pk, kit, "steel", c + along * u + out * 0.05, basis, Vector3(0.07, h, 0.06), col)
	for k in range(transoms):
		var v: float = (float(k + 1) / float(transoms + 1) - 0.5) * h
		_box(pk, kit, "steel", c + Vector3.UP * v + out * 0.035, basis, Vector3(w, 0.07, 0.06), col)


## A roof plane p0 p1 (along the eave) p2 p3 (up the slope) facing `out`, with its underside 4cm below (darker).
static func _roof(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color, out: Vector3, under := true) -> void:
	var lu: float = (p1 - p0).length()
	var lv: float = (p3 - p0).length()
	var uv := [Vector2(0, 0), Vector2(lu, 0) * uvk, Vector2(lu, lv) * uvk, Vector2(0, lv) * uvk]
	pk.quad(kit, key, [p0, p1, p2, p3], out, col, uv)
	if under:
		var dn := Vector3(0, -0.04, 0)
		pk.quad(kit, key, [p0 + dn, p1 + dn, p2 + dn, p3 + dn], -out, col.darkened(0.4), uv)


## A surface of revolution about the vertical through `c` with UVs in metres (u round, v up the profile): `profile`
## holds (radius, height) from the bottom up, walking the outside.
static func _lathe_uv(pk: PropKit, kit: Dictionary, key: String, c: Vector3, profile: Array, segs: int, col: Color, inward := false, flat := false) -> void:
	var s_run := 0.0
	for k in range(profile.size() - 1):
		var p0: Vector2 = profile[k]
		var p1: Vector2 = profile[k + 1]
		var d := p1 - p0
		var dl := d.length()
		if dl < 1e-6:
			continue
		var n2 := Vector2(d.y, -d.x).normalized()
		if inward:
			n2 = -n2
		var rm: float = maxf((p0.x + p1.x) * 0.5, 0.05)
		for j in range(segs):
			var t0 := TAU * j / segs
			var t1 := TAU * (j + 1) / segs
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var um := (u0 + u1).normalized()
			var out := um * n2.x + Vector3.UP * n2.y
			var na := out if flat else u0 * n2.x + Vector3.UP * n2.y
			var nb := out if flat else u1 * n2.x + Vector3.UP * n2.y
			var q00 := c + u0 * p0.x + Vector3.UP * p0.y
			var q01 := c + u1 * p0.x + Vector3.UP * p0.y
			var q10 := c + u0 * p1.x + Vector3.UP * p1.y
			var q11 := c + u1 * p1.x + Vector3.UP * p1.y
			var a0: float = t0 * rm * uvk
			var a1: float = t1 * rm * uvk
			var v0: float = s_run * uvk
			var v1: float = (s_run + dl) * uvk
			if p0.x > 1e-5 or p1.x > 1e-5:
				pk.tri(kit, key, q00, q01, q11, na, nb, nb, col, out, Vector2(a0, v0), Vector2(a1, v0), Vector2(a1, v1))
				pk.tri(kit, key, q00, q11, q10, na, nb, na, col, out, Vector2(a0, v0), Vector2(a1, v1), Vector2(a0, v1))
		s_run += dl


## A polyline guard rail: posts every 1.5m or so, a top rail, a knee rail and a toe board.
static func _railing(pk: PropKit, kit: Dictionary, pts: Array, h := 1.1, col := CRANE_YELLOW, key := "paint") -> void:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n: int = maxi(int(ceil(a.distance_to(b) / 1.6)), 1)
		var closed: bool = (pts[0] as Vector3).distance_to(pts[-1]) < 0.01
		for k in range(n + 1):
			if k == 0 and i > 0:
				continue
			if k == n and closed and i == pts.size() - 2:
				continue
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			pk.beam(kit, key, p, p + Vector3.UP * h, 0.045, 0.045, col)
		pk.beam(kit, key, a + Vector3.UP * h, b + Vector3.UP * h, 0.075, 0.06, col)
		pk.beam(kit, key, a + Vector3.UP * h * 0.52, b + Vector3.UP * h * 0.52, 0.07, 0.045, col)
		pk.beam(kit, key, a + Vector3.UP * 0.075, b + Vector3.UP * 0.075, 0.025, 0.12, col.darkened(0.2))


## A ring of railing of radius r round `c` at height y, `n` posts.
static func _ring_rail(pk: PropKit, kit: Dictionary, c: Vector3, r: float, n: int, h := 1.1, col := STEEL, key := "steel") -> void:
	var pts: Array = []
	for k in range(n + 1):
		var a: float = TAU * float(k) / float(n)
		pts.append(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
	_railing(pk, kit, pts, h, col, key)


## A ring walkway round a cylinder: a grating annulus from r0 to r1 at y (top), with its edge and brackets.
static func _ring_deck(pk: PropKit, kit: Dictionary, c: Vector3, r0: float, r1: float, segs: int, col := STEEL_DARK, rail := true) -> void:
	pk.lathe(kit, "steel", c, [Vector2(r1, -0.12), Vector2(r1, 0.0), Vector2(r0, 0.0)], segs, col, true)
	pk.lathe(kit, "steel", c, [Vector2(r0, -0.12), Vector2(r1, -0.12)], segs, col.darkened(0.3), true)
	for k in range(int(segs * 0.5)):
		var a: float = TAU * float(k * 2) / float(segs)
		var d := Vector3(cos(a), 0, sin(a))
		pk.beam(kit, "steel", c + d * r0 + Vector3(0, -0.12, 0), c + d * (r0 + (r1 - r0) * 0.15) + Vector3(0, -1.2, 0), 0.1, 0.1, col)
	if rail:
		_ring_rail(pk, kit, c, r1 - 0.06, segs, 1.1, col, "steel")


## A steel stair from `a` (foot) to `b` (head): stringers, treads every ~0.2m rise, a handrail each side; `w` wide.
static func _stair(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, w := 0.9, col := STEEL, rail_col := CRANE_YELLOW) -> void:
	var run := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if run.length() < 0.01:
		return
	var dir := run.normalized()
	var across := Vector3(-dir.z, 0.0, dir.x)
	for sd in [-0.5, 0.5]:
		var o: Vector3 = across * (sd * w)
		var o2: Vector3 = across * (sd * w + signf(sd) * 0.06)
		pk.beam(kit, "steel", a + o, b + o, 0.05, 0.22, col, across)
		pk.beam(kit, "paint", a + o2 + Vector3.UP * 1.0, b + o2 + Vector3.UP * 1.0, 0.06, 0.06, rail_col)
		for k in range(4):
			var p: Vector3 = a.lerp(b, float(k) / 3.0) + o2
			pk.beam(kit, "paint", p, p + Vector3.UP * 1.0, 0.04, 0.04, rail_col)
	var steps: int = maxi(int(ceil((b.y - a.y) / 0.2)), 1)
	for k in range(steps + 1):
		var p2: Vector3 = a.lerp(b, float(k) / float(steps))
		_box(pk, kit, "steel", p2 + Vector3.UP * 0.03, Basis(across, Vector3.UP, dir), Vector3(w, 0.04, 0.26), STEEL_DARK)


## A box lattice girder from a to b: four chords at the corners of a w x h section (w along the horizontal side, h along
## `up` squared to the axis), panels about `panel` long with posts and diagonals on the faces in `faces` (bits: 1 top,
## 2 bottom, 4 the -side face, 8 the +side face).
static func _lattice(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, h: float, panel: float, col: Color, up := Vector3.UP,
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
			pk.beam(kit, key, a + o, b + o, chord, chord, col, s)
	var n: int = maxi(int(round(length / panel)), 1)
	# Faces: [corner a, corner b] pairs: top (j = 1), bottom (j = -1), -side (i = -1), +side (i = 1).
	var fdefs: Array = [[1, Vector2i(-1, 1), Vector2i(1, 1)], [2, Vector2i(-1, -1), Vector2i(1, -1)], [4, Vector2i(-1, -1), Vector2i(-1, 1)], [8, Vector2i(1, -1), Vector2i(1, 1)]]
	for k in range(n + 1):
		var p: Vector3 = a + ax * (float(k) / float(n))
		var p1: Vector3 = a + ax * (float(k + 1) / float(n))
		for f in fdefs:
			if (faces & int(f[0])) == 0:
				continue
			var c0: Vector3 = corner.call(f[1].x, f[1].y)
			var c1: Vector3 = corner.call(f[2].x, f[2].y)
			pk.beam(kit, key, p + c0, p + c1, lace, lace, col, z)
			if k < n:
				if k % 2 == 0:
					pk.beam(kit, key, p + c0, p1 + c1, lace, lace, col)
				else:
					pk.beam(kit, key, p + c1, p1 + c0, lace, lace, col)


## A four-legged lattice tower from `base` (the middle of its foot) up `h`, `hb` the half width at the foot and `ht` at the
## top, braced every `panel` with horizontals and crossed diagonals on all four faces; feet on concrete pads to y - 3.
static func _tower(pk: PropKit, kit: Dictionary, key: String, base: Vector3, h: float, hb: float, ht: float, panel: float, col: Color, leg := 0.3, lace := 0.12, footings := true) -> void:
	var cs: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c in cs:
		var p0: Vector3 = base + Vector3(c.x * hb, 0.0, c.y * hb)
		var p1: Vector3 = base + Vector3(c.x * ht, h, c.y * ht)
		pk.beam(kit, key, p0, p1, leg, leg, col)
		if footings:
			_blk(pk, kit, "concrete", p0 + Vector3(-leg - 0.25, -3.0, -leg - 0.25), p0 + Vector3(leg + 0.25, 0.25, leg + 0.25), CONCRETE)
	var n: int = maxi(int(round(h / panel)), 1)
	for k in range(n + 1):
		var t0: float = float(k) / float(n)
		var t1: float = float(k + 1) / float(n)
		var y0: float = h * t0
		var y1: float = h * t1
		var r0: float = lerpf(hb, ht, t0)
		var r1: float = lerpf(hb, ht, t1)
		for i in range(4):
			var ca: Vector2 = cs[i]
			var cb: Vector2 = cs[(i + 1) % 4]
			var a0: Vector3 = base + Vector3(ca.x * r0, y0, ca.y * r0)
			var b0: Vector3 = base + Vector3(cb.x * r0, y0, cb.y * r0)
			if k > 0:
				pk.beam(kit, key, a0, b0, lace, lace, col)
			if k < n:
				var a1: Vector3 = base + Vector3(ca.x * r1, y1, ca.y * r1)
				var b1: Vector3 = base + Vector3(cb.x * r1, y1, cb.y * r1)
				pk.beam(kit, key, a0, b1, lace * 0.8, lace * 0.8, col)
				pk.beam(kit, key, b0, a1, lace * 0.8, lace * 0.8, col)


## A pipe along `pts` (a polyline), radius r: tubes, a rounded joint at each bend, flanges every `flange_every` metres
## (0: none) and at the ends.
static func _pipe(pk: PropKit, kit: Dictionary, key: String, pts: Array, r: float, col: Color, segs := 12, flange_every := 0.0, caps := true) -> void:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		pk.tube(kit, key, a, b, r, r, segs, col, false)
		if flange_every > 0.0:
			var l: float = a.distance_to(b)
			var nf: int = int(floor(l / flange_every))
			for k in range(1, nf + 1):
				var t: float = float(k) * flange_every / l
				if t > 0.97:
					break
				var c: Vector3 = a.lerp(b, t)
				var d: Vector3 = (b - a).normalized() * 0.06
				pk.tube(kit, key, c - d, c + d, r * 1.16, r * 1.16, segs, col.darkened(0.12), true)
	for i in range(1, pts.size() - 1):
		var c2: Vector3 = pts[i]
		var prof: Array = []
		for k in range(5):
			var t2: float = -PI * 0.5 + PI * float(k) / 4.0
			prof.append(Vector2(cos(t2) * r * 1.0, sin(t2) * r))
		pk.lathe(kit, key, c2, prof, segs, col)
	if caps:
		for e in [0, pts.size() - 1]:
			var p: Vector3 = pts[e]
			var q: Vector3 = pts[1] if e == 0 else pts[pts.size() - 2]
			var d2: Vector3 = (p - q).normalized()
			pk.tube(kit, key, p - d2 * 0.12, p + d2 * 0.04, r * 1.18, r * 1.18, segs, col.darkened(0.15), true)


## A hanging industrial lamp: a rod from `top` down `drop`, a dish reflector with its glowing bulb under it.
static func _pendant(pk: PropKit, kit: Dictionary, top: Vector3, drop: float) -> void:
	var c: Vector3 = top - Vector3(0, drop, 0)
	pk.beam(kit, "steel", top + Vector3(0, 0.05, 0), c + Vector3(0, 0.3, 0), 0.04, 0.04, STEEL_DARK)
	pk.lathe(kit, "steel", c, [Vector2(0.5, -0.02), Vector2(0.55, 0.0), Vector2(0.42, 0.14), Vector2(0.16, 0.3), Vector2(0.1, 0.42), Vector2(0.001, 0.44)], 10, Color(0.30, 0.36, 0.34), true)
	pk.lathe(kit, "steel", c + Vector3(0, 0.01, 0), [Vector2(0.001, 0.28), Vector2(0.15, 0.27), Vector2(0.4, 0.12), Vector2(0.5, -0.0)], 10, Color(0.75, 0.75, 0.72), true)
	pk.lathe(kit, "lamp", c + Vector3(0, 0.01, 0), [Vector2(0.001, 0.0), Vector2(0.48, 0.0)], 10, Color(1.0, 0.92, 0.78), true)


## A sign on a post facing `out` (axis-aligned): a board w x h with `text` (cap height `cap`), its foot at `p`; a warning
## triangle above when `warn`, a blue disc when `must`.
static func _sign(pk: PropKit, kit: Dictionary, labels: Array, p: Vector3, out: Vector3, text: String, bg: Color, fg: Color, w := 1.6, h := 0.7, post := 2.4,
		warn := false, must := false) -> void:
	var across: Vector3 = Vector3.UP.cross(out).normalized()
	var basis := Basis(across, Vector3.UP, out)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "steel", p + across * (sx * (w * 0.5 - 0.15)) + Vector3(0, -0.6, 0), p + across * (sx * (w * 0.5 - 0.15)) + Vector3(0, post + h + (1.3 if warn or must else 0.0), 0), 0.04, 0.04, 6, Color(0.6, 0.6, 0.6), true)
	var mid: Vector3 = p + Vector3(0, post + h * 0.5, 0) + out * 0.06
	_box(pk, kit, "paint", mid, basis, Vector3(w, h, 0.04), bg)
	_box(pk, kit, "paint", mid - out * 0.03, basis, Vector3(w + 0.04, h + 0.04, 0.02), Color(0.2, 0.2, 0.2))
	_label(labels, text, mid + out * 0.035, out, cap_for(text, w, h), fg, w - 0.12)
	if warn:
		var c: Vector3 = p + Vector3(0, post + h + 0.62, 0) + out * 0.06
		var r := 0.62
		var tri_pts: Array = []
		for k in range(3):
			var a: float = PI * 0.5 + TAU * float(k) / 3.0
			tri_pts.append(c + across * (cos(a) * r) + Vector3.UP * (sin(a) * r))
		pk.tri(kit, "paint", tri_pts[0], tri_pts[1], tri_pts[2], out, out, out, Color(0.06, 0.06, 0.06), out)
		var ti: Array = []
		for k in range(3):
			ti.append(c + (tri_pts[k] - c) * 0.78 + out * 0.012)
		pk.tri(kit, "paint", ti[0], ti[1], ti[2], out, out, out, SIGN_YELLOW, out)
		_box(pk, kit, "paint", c + Vector3(0, 0.02, 0) + out * 0.02, basis, Vector3(0.07, 0.3, 0.01), BLACK)
		_box(pk, kit, "paint", c + Vector3(0, -0.22, 0) + out * 0.02, basis, Vector3(0.07, 0.07, 0.01), BLACK)
		pk.tri(kit, "paint", tri_pts[0] - out * 0.02, tri_pts[2] - out * 0.02, tri_pts[1] - out * 0.02, -out, -out, -out, Color(0.5, 0.5, 0.5), -out)
	if must:
		var c2: Vector3 = p + Vector3(0, post + h + 0.62, 0) + out * 0.05
		pk.tube(kit, "paint", c2 - out * 0.02, c2 + out * 0.02, 0.55, 0.55, 18, SIGN_BLUE, true)
		pk.tube(kit, "paint", c2 + out * 0.02, c2 + out * 0.03, 0.42, 0.42, 18, WHITE, true)
		pk.tube(kit, "paint", c2 + out * 0.03, c2 + out * 0.04, 0.36, 0.36, 18, SIGN_BLUE, true)


## A cap height that fits `text` on a board w x h (the generator shrinks one that would still run past it).
static func cap_for(text: String, w: float, h: float) -> float:
	return minf(h * 0.42, (w - 0.15) / maxf(float(text.length()) * 0.72, 1.0))


# ======================================================================================
#  Walzwerk 2: the rolling mill hall
# ======================================================================================

const HALL_HW := 18.4       # outer face of the long walls
const HALL_WT := 0.5        # brick wall thickness
const HALL_IN := 16.3       # crane column (inner chord) centre line, the runway's line
const HALL_OUT := 18.1      # wall column (outer chord) centre line, in the wall
const RUN_BOT := 13.6       # crane runway girder underside
const RUN_TOP := 15.0
const RAIL_TOP := 15.15
const EAVE := 19.6
const SLOPE := 0.19
const MON_X := 4.8          # the roof monitor's sides
const MON_TOP := 24.0
const RIDGE := 24.6
const GATE_HW := 8.3        # the gable's opening; its portal posts stand inside it
const GATE_POST := 8.0      # the posts' inner faces: 16m clear
const GATE_H := 13.0        # the lintel's underside
const TRUSS_BOT := 18.6
const PLINTH := 0.6
const MILL_X := 10.6        # the mill train's roll line (x > 0 side)
const BARRIER_X := 7.6      # the safety barrier's road face
const CRANE_BOT := 14.75    # the crane bridge girders' underside


static func hall_roof_y(ax: float) -> float:
	return EAVE + (HALL_HW - ax) * SLOPE


static func _mon_roof_y(ax: float) -> float:
	return RIDGE - ax * (RIDGE - (MON_TOP - 0.1)) / (MON_X + 0.5)


## Walzwerk 2: the road runs along -z through it, in at z = 0 and out at z = -length, centred on x = 0; floor at y = 0.
## Outside x -19.3..19.3 (the eaves' gutters; the reheating furnace's brick stack stands outside the +x wall at (22.6,
## -11.2), its plinth to x 25.3), z 0.4..-length - 0.4 (the roof's overhang), ridge 24.6 (25.7 over the ventilators). Its
## frames stand every ~7.5m (length - 0.5 split into whole bays). The gateways in both gables are 16m clear (posts' inner
## faces at x ±8) and 13m high (the lintel's underside).
## The corridor (scratch/steelworks_corridor_check.gd): nothing within |x| < 6 below y 12, nothing within |x| < 7.5 below
## 1.2 but the floor, no floor within |x| < 4.5 (the generator lays the road there); the floor slab's top is at -0.02 from
## |x| 4.5 to the walls. A striped kerb and railing at |x| 7.6..8.0 keep the cars off the works.
## Inside: +x the mill train on the roll line x 10.6 (MILL_X): the reheating furnace (x 8.6..15.6, z -5.5..-30), roller
## tables, the roughing stand (z -50), the finishing stand (z -72), the run-out table and the cooling bed (z -98..-142);
## -x spare rolls, plate stacks, the control pulpit (z -61, x -15.5..-8.6, cabin 4.7..7.8 up), the coil store, a skip.
## Two cranes (underside 14.75, at z -40 and -96; a crane may stand anywhere from z -6 to -length + 6); lamps above the
## cranes' reach and floods on the crane columns. hall_fx_spots() lists where sparks, steam and lights belong.
static func rolling_hall(pk: PropKit, kit: Dictionary, length: float, labels: Array) -> void:
	var n_bays: int = maxi(int(round((length - 0.5) / 7.5)), 2)
	var bay: float = (length - 0.5) / float(n_bays)
	var frames: Array = []
	for i in range(n_bays + 1):
		frames.append(-0.25 - float(i) * bay)
	_hall_floor(pk, kit, length)
	_hall_walls(pk, kit, length, frames)
	for zf in [0.0, -length]:
		_hall_gable(pk, kit, zf, length, labels)
	_hall_frames(pk, kit, length, frames)
	_hall_roof(pk, kit, length, frames)
	_hall_lamps(pk, kit, frames)
	_hall_barrier(pk, kit, length)
	_mill_train(pk, kit, length, labels)
	_hall_west_side(pk, kit, length, labels)
	_crane(pk, kit, labels, -40.0, 9.5, 12.6, "", 1)
	_crane(pk, kit, labels, -96.0, -11.4, 6.2, "coil", 2)
	_hall_signs(pk, kit, labels, length)


## Good spots (kit coordinates) for the generator's effects and lights: [kind, position, note].
static func hall_fx_spots(length := 150.0) -> Array:
	return [
		["furnace_glow_light", Vector3(8.0, 2.2, -18.0), "orange OmniLight before the furnace's door slots, range ~10"],
		["furnace_mouth_light", Vector3(MILL_X, 1.8, -31.5), "the discharge door: orange-yellow OmniLight, range ~12"],
		["stand1_sparks_steam", Vector3(MILL_X, 1.3, -50.0), "roughing stand roll gap: sparks and descaling steam"],
		["stand2_sparks_steam", Vector3(MILL_X, 1.3, -72.0), "finishing stand roll gap: sparks and steam"],
		["stand_lights", Vector3(MILL_X - 1.5, 2.0, -61.0), "orange OmniLight between the stands, range ~16"],
		["cooling_bed_shimmer", Vector3(12.5, 1.4, -108.0), "heat haze / faint steam over the hot end of the cooling bed"],
		["cooling_bed_light", Vector3(11.5, 2.0, -110.0), "dull red OmniLight, range ~10"],
		["stack_smoke", Vector3(22.6, 37.0, -11.2), "the reheating furnace's stack outside the +x wall: smoke"],
		["hall_fill_light", Vector3(0.0, 16.0, -length * 0.5), "a few soft white OmniLights under the lamps (y 16) along the road if it reads dark"],
	]


## Good spots (kit coordinates, origin as each builder's) for smoke, steam, sparks and lights on the other pieces.
static func works_fx_spots() -> Array:
	return [
		["furnace_tap_hole", Vector3(6.6, 7.7, 0.0), "blast_furnace: the tap hole (sparks, orange OmniLight range ~14)"],
		["furnace_runner", Vector3(14.5, 7.9, 0.0), "blast_furnace: over the iron runner in the cast house (fume, orange light)"],
		["furnace_pour", Vector3(24.1, 5.5, 0.0), "blast_furnace: the stream into the torpedo car (sparks, light ~10)"],
		["furnace_bleeders", Vector3(4.2, 74.5, 0.0), "blast_furnace: the bleeders' tops at x ±4.2 (a thin plume now and then)"],
		["furnace_tuyeres", Vector3(0.0, 10.4, 0.0), "blast_furnace: the tuyere ring (radius 6.5) glows; a warm light under the bustle pipe"],
		["cowper_chimney", Vector3(-19.0, 70.0, 0.0), "cowpers: the 70m chimney's top (smoke)"],
		["cooling_tower", Vector3(0.0, 50.0, 0.0), "cooling_tower: the lip (radius 13.1): the steam plume"],
		["chimney_top", Vector3(0.0, 1.0, 0.0), "chimney(h): its top is at (0, h, 0)"],
		["torpedo_mouth", Vector3(0.0, 5.75, 0.0), "torpedo_car: the mouth (a faint shimmer/fume)"],
	]


static func _hall_floor(pk: PropKit, kit: Dictionary, length: float) -> void:
	# The slab beside the road on each side (none within |x| < 4.5: the road is laid there), its top at -0.02.
	for s in [-1.0, 1.0]:
		var x0: float = 4.5 * s
		var x1: float = (HALL_HW - HALL_WT + 0.05) * s
		var lo := Vector3(minf(x0, x1), -0.52, -length - 0.1)
		var hi := Vector3(maxf(x0, x1), -0.02, 0.1)
		_blk(pk, kit, "floor", lo, hi, Color(0.56, 0.52, 0.46))
		# Its edge along the road goes down a metre (the ground may be graded a little under it).
		pk.quad(kit, "floor", [Vector3(x0, -1.2, 0.1), Vector3(x0, -1.2, -length - 0.1), Vector3(x0, -0.52, -length - 0.1), Vector3(x0, -0.52, 0.1)],
				Vector3(-s, 0, 0), Color(0.5, 0.49, 0.46))


## The long walls: brick infill between the wall columns (Backstein-Fachwerk), a lower and an upper tier of steel windows
## in every bay, steel rails across the facade at the sill, the window heads and the eaves, a concrete plinth, downpipes.
static func _hall_walls(pk: PropKit, kit: Dictionary, length: float, frames: Array) -> void:
	var n_bays: int = frames.size() - 1
	for s in [-1.0, 1.0]:
		var out := Vector3(s, 0, 0)
		var along := Vector3(0, 0, -1)
		for i in range(n_bays):
			var za: float = -0.5 if i == 0 else float(frames[i]) - 0.25
			var zb: float = -length + 0.5 if i == n_bays - 1 else float(frames[i + 1]) + 0.25
			var w: float = za - zb
			var p0 := Vector3(s * HALL_HW, 0.0, za)
			var ww := 4.6
			var wu: float = (w - ww) * 0.5
			var holes: Array = [[Rect2(wu, 5.4, ww, 7.4), true], [Rect2(wu, 13.7, ww, 4.9), true]]
			_wall_holes(pk, kit, "brick", p0, along, out, 0.0, w, PLINTH, EAVE - 0.07, holes, BRICK, HALL_WT)
			for h in holes:
				var r: Rect2 = h[0]
				var c: Vector3 = p0 + along * (r.position.x + r.size.x * 0.5) + Vector3.UP * (r.position.y + r.size.y * 0.5) - out * 0.16
				_glazing(pk, kit, c, along, Vector3.UP, out, r.size.x - 0.2, r.size.y - 0.2)
				_window_frame(pk, kit, c, along, out, r.size.x - 0.2, r.size.y - 0.2, STEEL, 1, 1 if r.size.y > 6.0 else 0)
				# A concrete sill outside.
				_blk(pk, kit, "concrete", p0 + along * (r.position.x - 0.12) + Vector3(0, r.position.y - 0.16, 0),
						p0 + along * (r.end.x + 0.12) + Vector3(0, r.position.y, 0) + out * 0.14, CONCRETE.lightened(0.05))
			# The wall's top under the eaves.
			pk.quad(kit, "brick", [p0 + Vector3(0, EAVE - 0.07, 0), p0 + along * w + Vector3(0, EAVE - 0.07, 0), p0 + along * w + Vector3(0, EAVE - 0.07, 0) - out * HALL_WT,
					p0 + Vector3(0, EAVE - 0.07, 0) - out * HALL_WT], Vector3.UP, BRICK_DARK)
		# The steel rails across the facade (12cm proud of the brick, in front of the column faces).
		for y in [[4.85, 5.15], [13.0, 13.45], [19.05, 19.45]]:
			_blk(pk, kit, "steel", Vector3(s * HALL_HW, y[0], -0.82), Vector3(s * (HALL_HW + 0.12), y[1], -length + 0.82), STEEL)
		# The plinth (between the gables' plinths).
		_blk(pk, kit, "concrete", Vector3(s * (HALL_HW - HALL_WT - 0.05), -3.0, -0.6), Vector3(s * (HALL_HW + 0.18), PLINTH, -length + 0.6), CONCRETE)
		# Downpipes every other frame, from the gutter to the plinth.
		for i in range(1, n_bays, 2):
			var zd: float = float(frames[i]) - 0.55
			pk.tube(kit, "steel", Vector3(s * (HALL_HW + 0.3), PLINTH + 0.1, zd), Vector3(s * (HALL_HW + 0.3), EAVE - 0.25, zd), 0.075, 0.075, 6, STEEL_DARK, false)
			pk.beam(kit, "steel", Vector3(s * (HALL_HW + 0.3), EAVE - 0.25, zd), Vector3(s * (HALL_HW + 0.62), EAVE - 0.12, zd), 0.12, 0.12, STEEL_DARK)
			pk.beam(kit, "steel", Vector3(s * (HALL_HW + 0.3), PLINTH + 0.1, zd), Vector3(s * (HALL_HW + 0.55), PLINTH - 0.05, zd), 0.13, 0.13, STEEL_DARK)
	# The reheating furnace's stack outside the +x wall, its flue through the wall.
	var saved := _push(pk, Transform3D(Basis(), Vector3(22.6, 0.0, -11.2)))
	chimney(pk, kit, 36.0, 0)
	_pop(pk, saved)
	_pipe(pk, kit, "rusty", [Vector3(15.2, 4.0, -11.2), Vector3(21.2, 4.0, -11.2)], 0.85, CASING, 14, 2.5, false)
	for x in [16.5, 20.0]:
		_blk(pk, kit, "steel", Vector3(x - 0.15, -0.0, -11.5), Vector3(x + 0.15, 3.2, -10.9), STEEL)


## A gable wall at z = zf (0: the way in, facing +z; -length: the way out): brick on a plinth, the gateway (posts,
## lintel girder with the works' name, a roller shutter box inside), pilasters, windows and a door either side, the
## gable over the eaves stepping up with the monitor, the hall's name in big letters and a round window.
static func _hall_gable(pk: PropKit, kit: Dictionary, zf: float, _length: float, labels: Array) -> void:
	var s: float = 1.0 if zf > -1.0 else -1.0
	var out := Vector3(0, 0, s)
	var along := Vector3(1, 0, 0)
	var p0 := Vector3(0, 0, zf)
	var holes: Array = [[Rect2(-GATE_HW, 0.0, GATE_HW * 2.0, 13.3), false]]
	for sx in [-1.0, 1.0]:
		for wx in [[9.8, 11.6], [13.9, 15.7]]:
			var xa: float = minf(sx * wx[0], sx * wx[1])
			holes.append([Rect2(xa, 4.6, 1.8, 7.4), true])
		var dx: float = minf(sx * 12.0, sx * 13.5)
		holes.append([Rect2(dx, PLINTH, 1.5, 2.5), true])
	_wall_holes(pk, kit, "brick", p0, along, out, -HALL_HW, HALL_HW, PLINTH, EAVE - 0.07, holes, BRICK, HALL_WT)
	# The gable over the eaves, stepping up with the monitor.
	var gy := -0.07
	var poly := PackedVector2Array([Vector2(-HALL_HW, EAVE + gy), Vector2(HALL_HW, EAVE + gy), Vector2(MON_X, hall_roof_y(MON_X) + gy),
			Vector2(MON_X, _mon_roof_y(MON_X) + gy), Vector2(0.0, RIDGE + gy), Vector2(-MON_X, _mon_roof_y(MON_X) + gy), Vector2(-MON_X, hall_roof_y(MON_X) + gy)])
	_wall_poly(pk, kit, "brick", p0, along, out, poly, BRICK, HALL_WT)
	# Windows and the doors.
	for h in holes.slice(1):
		var r: Rect2 = h[0]
		var c: Vector3 = p0 + along * (r.position.x + r.size.x * 0.5) + Vector3.UP * (r.position.y + r.size.y * 0.5) - out * 0.16
		if r.size.y > 4.0:
			_glazing(pk, kit, c, along, Vector3.UP, out, r.size.x - 0.2, r.size.y - 0.2)
			_window_frame(pk, kit, c, along, out, r.size.x - 0.2, r.size.y - 0.2, STEEL, 0, 1)
			_blk(pk, kit, "concrete", Vector3(r.position.x - 0.12, r.position.y - 0.16, zf), Vector3(r.end.x + 0.12, r.position.y, zf + s * 0.14), CONCRETE.lightened(0.05))
		else:
			# A steel door set in the opening, a step and a lamp over it.
			_box(pk, kit, "paint", c + out * 0.02, Basis(), Vector3(r.size.x, r.size.y, 0.06), Color(0.30, 0.36, 0.34))
			for k in range(3):
				_box(pk, kit, "paint", c + out * 0.06 + Vector3(0, -0.8 + 0.8 * float(k), 0), Basis(), Vector3(r.size.x - 0.2, 0.05, 0.03), Color(0.24, 0.29, 0.28))
			_blk(pk, kit, "concrete", Vector3(r.position.x - 0.3, -0.5, zf), Vector3(r.end.x + 0.3, PLINTH, zf + s * 1.0), CONCRETE)
			_blk(pk, kit, "steel", Vector3(r.position.x + 0.45, r.end.y + 0.35, zf), Vector3(r.end.x - 0.45, r.end.y + 0.55, zf + s * 0.35), STEEL_DARK)
	# The plinth either side of the gateway.
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "concrete", Vector3(sx * GATE_HW, -3.0, zf + s * 0.18), Vector3(sx * (HALL_HW + 0.18), PLINTH, zf - s * 0.6), CONCRETE)
	# Pilasters: the corners and either side of the gateway, standing proud of both faces.
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "brick", Vector3(sx * (HALL_HW - 0.7), PLINTH, zf + s * 0.12), Vector3(sx * (HALL_HW + 0.12), EAVE - 0.12, zf - s * 0.8), BRICK_DARK)
		_blk(pk, kit, "brick", Vector3(sx * GATE_HW, PLINTH, zf + s * 0.12), Vector3(sx * (GATE_HW + 1.0), 14.6, zf - s * 0.62), BRICK_DARK)
		_blk(pk, kit, "concrete", Vector3(sx * (GATE_HW - 0.06), 14.6, zf + s * 0.2), Vector3(sx * (GATE_HW + 1.06), 14.85, zf - s * 0.7), CONCRETE.lightened(0.08))
	# A corbelled brick band across the gable at the eaves.
	_blk(pk, kit, "brick", Vector3(-HALL_HW + 0.7, EAVE - 0.6, zf + s * 0.1), Vector3(HALL_HW - 0.7, EAVE - 0.3, zf), BRICK_DARK)
	# The gateway: steel posts (striped at the foot), the lintel girder, the name board.
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(sx * GATE_POST, 2.5, zf + s * 0.2), Vector3(sx * (GATE_HW + 0.1), GATE_H, zf - s * 0.7), STEEL)
		_blk(pk, kit, "hazard", Vector3(sx * GATE_POST, -0.02, zf + s * 0.2), Vector3(sx * (GATE_HW + 0.1), 2.5, zf - s * 0.7), WHITE)
	_blk(pk, kit, "steel", Vector3(-GATE_HW - 0.1, GATE_H, zf + s * 0.2), Vector3(GATE_HW + 0.1, 14.3, zf - s * 0.7), STEEL)
	_blk(pk, kit, "paint", Vector3(-7.4, 13.22, zf + s * 0.2), Vector3(7.4, 14.08, zf + s * 0.25), ENAMEL_GREEN)
	_label(labels, "KRONBURGER HÜTTE", Vector3(0, 13.65, zf + s * 0.27), out, 0.52, CREAM, 14.2)
	# The roller shutter's box over the opening inside.
	pk.tube(kit, "steel", Vector3(-GATE_HW - 0.3, 14.95, zf - s * 1.15), Vector3(GATE_HW + 0.3, 14.95, zf - s * 1.15), 0.55, 0.55, 10, Color(0.42, 0.44, 0.44), true)
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(sx * GATE_POST, 2.5, zf - s * 0.7), Vector3(sx * (GATE_POST + 0.2), 14.6, zf - s * 0.95), Color(0.42, 0.44, 0.44))
	# The hall's name in big letters over the gateway, the year on a sandstone plaque, a round window in the gable.
	_label(labels, "WALZWERK 2", Vector3(0, 16.85, zf + s * 0.06), out, 1.85, Color(0.93, 0.9, 0.8), 15.0)
	_blk(pk, kit, "stone", Vector3(-1.1, 19.95, zf + s * 0.05), Vector3(1.1, 20.75, zf), Color(0.72, 0.62, 0.46))
	_label(labels, "1911", Vector3(0, 20.35, zf + s * 0.07), out, 0.5, Color(0.25, 0.18, 0.12), 2.0)
	var oc := Vector3(0, 22.2, zf)
	pk.tube(kit, "brick", oc - out * 0.02, oc + out * 0.12, 1.45, 1.45, 20, BRICK_DARK, false, uvk)
	pk.lathe(kit, "brick", oc + out * 0.12, [Vector2(1.45, 0.0), Vector2(1.12, 0.0)], 20, BRICK_DARK, true, Basis(Vector3(1, 0, 0), Vector3(0, 0, s), Vector3(0, -s, 0)))
	pk.tube(kit, "steel", oc + out * 0.02, oc + out * 0.06, 1.13, 1.13, 20, STEEL, false)
	var gb := Basis(Vector3(1, 0, 0), Vector3(0, 0, s), Vector3(0, -s, 0))
	pk.lathe(kit, "lens", oc + out * 0.05, [Vector2(1.13, 0.0), Vector2(0.001, 0.0)], 20, Color(0.06, 0.08, 0.09), true, gb)
	for k in range(4):
		var a: float = PI * 0.25 * float(k)
		pk.beam(kit, "steel", oc + out * (0.08 + 0.016 * float(k)) + Vector3(cos(a), sin(a), 0) * 1.1, oc + out * (0.08 + 0.016 * float(k)) - Vector3(cos(a), sin(a), 0) * 1.1, 0.07, 0.012, STEEL, out)
	pk.lathe(kit, "lamp", oc - out * (HALL_WT + 0.03), [Vector2(1.0, 0.0), Vector2(0.001, 0.0)], 16, Color(0.5, 0.53, 0.57), true, Basis(Vector3(1, 0, 0), Vector3(0, 0, -s), Vector3(0, s, 0)))


## The steel frames: per frame a crane column (two chords laced together, the inner one carrying the runway girder, the
## outer one in the wall up to the eaves) each side and a roof truss with the monitor's posts and rafters; the runway
## girders with their rails, the purlins, bracing in the end bays.
static func _hall_frames(pk: PropKit, kit: Dictionary, length: float, frames: Array) -> void:
	var n: int = frames.size() - 1
	for i in range(n + 1):
		var zf: float = frames[i]
		var end_frame: bool = i == 0 or i == n
		for s in [-1.0, 1.0]:
			# The inner chord (at the end frames just inside the gable, carrying the runway's end).
			var zc: float = zf
			if i == 0:
				zc = -0.5 - 0.25
			elif i == n:
				zc = -length + 0.5 + 0.25
			var cin := Vector3(s * HALL_IN, 0.0, zc)
			_blk(pk, kit, "concrete", Vector3(s * 15.75, -3.0, zc - 0.55), Vector3(s * (HALL_HW - HALL_WT - 0.02), 0.3, zc + 0.55), CONCRETE)
			_ibeam(pk, kit, "steel", cin + Vector3(0, 0.3, 0), cin + Vector3(0, RUN_BOT, 0), 0.5, 0.45, STEEL, Vector3(1, 0, 0), 0.035, 0.05)
			_blk(pk, kit, "hazard", Vector3(s * 16.02, 0.28, zc - 0.25), Vector3(s * 16.58, 2.2, zc + 0.25), WHITE)
			_blk(pk, kit, "steel", Vector3(s * 15.95, RUN_BOT - 0.06, zc - 0.32), Vector3(s * 16.65, RUN_BOT + 0.02, zc + 0.32), STEEL_DARK)
			if end_frame:
				continue
			# The outer chord, in the wall from the plinth to the eaves.
			_blk(pk, kit, "steel", Vector3(s * 17.75, 0.3, zf - 0.25), Vector3(s * 18.45, EAVE - 0.05, zf + 0.25), STEEL)
			# Lacing between the chords in two planes, the bracket under the runway.
			for pz in [-0.17, 0.17]:
				var y := 0.8
				var k := 0
				while y < RUN_BOT - 1.2:
					var xa: float = s * (16.55 if k % 2 == 0 else 17.75)
					var xb: float = s * (17.75 if k % 2 == 0 else 16.55)
					pk.beam(kit, "steel", Vector3(xa, y, zf + pz), Vector3(xb, y + 1.1, zf + pz), 0.09, 0.07, STEEL)
					y += 1.1
					k += 1
				pk.beam(kit, "steel", Vector3(s * 16.55, 0.6, zf + pz), Vector3(s * 17.75, 0.6, zf + pz), 0.16, 0.08, STEEL, Vector3.UP)
			_blk(pk, kit, "steel", Vector3(s * 16.5, RUN_BOT - 0.7, zf - 0.22), Vector3(s * 17.8, RUN_BOT, zf + 0.22), STEEL)
			pk.beam(kit, "steel", Vector3(s * 16.55, RUN_BOT - 0.7, zf), Vector3(s * 17.75, RUN_BOT - 2.3, zf), 0.14, 0.14, STEEL)
			# The knee brace from the wall column to the truss.
			pk.beam(kit, "steel", Vector3(s * 17.75, 16.6, zf), Vector3(s * 15.4, TRUSS_BOT - 0.1, zf), 0.16, 0.16, STEEL)
		if not end_frame:
			_hall_truss(pk, kit, zf)
	# The runway girders and their rails, stiffeners on the faces toward the road.
	for s in [-1.0, 1.0]:
		var a := Vector3(s * HALL_IN, (RUN_BOT + RUN_TOP) * 0.5, -0.48)
		var b := Vector3(s * HALL_IN, (RUN_BOT + RUN_TOP) * 0.5, -length + 0.48)
		_ibeam(pk, kit, "steel", a, b, RUN_TOP - RUN_BOT, 0.6, STEEL, Vector3.UP, 0.03, 0.06)
		_blk(pk, kit, "steel", Vector3(s * HALL_IN - 0.07, RUN_TOP - 0.005, -0.48), Vector3(s * HALL_IN + 0.07, RAIL_TOP, -length + 0.48), RAIL_GREY)
		var z := -2.5
		while z > -length + 2.0:
			_blk(pk, kit, "steel", Vector3(s * HALL_IN - s * 0.015, RUN_BOT + 0.05, z - 0.06), Vector3(s * HALL_IN - s * 0.27, RUN_TOP - 0.06, z + 0.06), STEEL)
			z -= 2.5
		# Crane end stops at both ends.
		for ze in [-1.2, -length + 1.2]:
			_blk(pk, kit, "hazard", Vector3(s * HALL_IN - 0.3, RAIL_TOP, ze - 0.3), Vector3(s * HALL_IN + 0.3, RAIL_TOP + 0.9, ze + 0.3), WHITE)
	# The purlins: along the hall on the trusses' top chords, square to the roof.
	for s in [-1.0, 1.0]:
		var nrm := Vector3(s * SLOPE, 1.0, 0.0).normalized()
		var slope_dir := Vector3(s, -SLOPE, 0.0).normalized()
		for ax in [17.6, 15.4, 12.9, 10.4, 7.6, 5.1]:
			var c := Vector3(s * ax, hall_roof_y(ax), 0.0) - nrm * 0.22
			pk.beam(kit, "steel", Vector3(c.x, c.y, -0.3), Vector3(c.x, c.y, -length + 0.3), 0.16, 0.3, STEEL, slope_dir)
		# Monitor purlins and the ridge beam.
		var mn := Vector3(s * (RIDGE - MON_TOP + 0.1) / (MON_X + 0.5), 1.0, 0.0).normalized()
		var c2 := Vector3(s * 2.6, _mon_roof_y(2.6), 0.0) - mn * 0.2
		pk.beam(kit, "steel", Vector3(c2.x, c2.y, -0.3), Vector3(c2.x, c2.y, -length + 0.3), 0.14, 0.26, STEEL, Vector3(s, -(RIDGE - MON_TOP) / MON_X, 0).normalized())
	pk.beam(kit, "steel", Vector3(0, RIDGE - 0.3, -0.3), Vector3(0, RIDGE - 0.3, -length + 0.3), 0.18, 0.3, STEEL)
	# Roof bracing in the end bays (crossed rods under the purlins) and longitudinal ties along the bottom chords.
	for ends in [[frames[1], frames[2]], [frames[n - 2], frames[n - 1]]]:
		for s in [-1.0, 1.0]:
			var za: float = ends[0]
			var zb: float = ends[1]
			var y0: float = hall_roof_y(16.0) - 0.62
			var y1: float = hall_roof_y(7.0) - 0.62
			pk.beam(kit, "steel", Vector3(s * 16.0, y0, za), Vector3(s * 7.0, y1, zb), 0.06, 0.06, STEEL_DARK)
			pk.beam(kit, "steel", Vector3(s * 16.0, y0, zb), Vector3(s * 7.0, y1, za), 0.06, 0.06, STEEL_DARK)
	for x in [-10.4, 0.0, 10.4]:
		pk.beam(kit, "steel", Vector3(x, TRUSS_BOT, float(frames[1])), Vector3(x, TRUSS_BOT, float(frames[n - 1])), 0.12, 0.12, STEEL, Vector3.UP)


## One roof truss at z: the bottom chord, the top chords under the purlins, posts and diagonals, the monitor's posts and
## rafters, a king post and a tie across under the monitor.
static func _hall_truss(pk: PropKit, kit: Dictionary, z: float) -> void:
	var m := 0.2
	var side := Vector3(0, 0, 1)
	pk.beam(kit, "steel", Vector3(-17.8, TRUSS_BOT, z), Vector3(17.8, TRUSS_BOT, z), 0.26, 0.24, STEEL, side)
	var pts: Array = [17.75, 15.4, 12.9, 10.4, 7.6, MON_X]
	var top := func(ax: float) -> float:
		return hall_roof_y(ax) - 0.52
	for s in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(s * 17.75, top.call(17.75), z), Vector3(s * MON_X, top.call(MON_X), z), 0.26, 0.26, STEEL, side)
		for k in range(1, pts.size() - 1):
			var x: float = pts[k]
			pk.beam(kit, "steel", Vector3(s * x, TRUSS_BOT, z), Vector3(s * x, top.call(x), z), m, m, STEEL, side)
		for k in range(pts.size() - 1):
			var xa: float = pts[k]
			var xb: float = pts[k + 1]
			pk.beam(kit, "steel", Vector3(s * xa, top.call(xa) if k > 0 else TRUSS_BOT + 0.3, z), Vector3(s * xb, TRUSS_BOT, z), m, m, STEEL, side)
		# The monitor's post and rafter.
		pk.beam(kit, "steel", Vector3(s * MON_X, TRUSS_BOT, z), Vector3(s * MON_X, _mon_roof_y(MON_X) - 0.45, z), 0.24, 0.24, STEEL, side)
		pk.beam(kit, "steel", Vector3(s * (MON_X + 0.12), _mon_roof_y(MON_X + 0.12) - 0.38, z), Vector3(0, RIDGE - 0.4, z), 0.22, 0.22, STEEL, side)
		pk.beam(kit, "steel", Vector3(s * MON_X, top.call(MON_X), z), Vector3(0, TRUSS_BOT, z), m, m, STEEL, side)
	pk.beam(kit, "steel", Vector3(0, TRUSS_BOT, z), Vector3(0, RIDGE - 0.4, z), m, m, STEEL, side)
	pk.beam(kit, "steel", Vector3(-MON_X, top.call(MON_X), z), Vector3(MON_X, top.call(MON_X), z), m, m, STEEL, side)


## The roof: corrugated iron in two slopes from the eaves (0.6 over the walls) to the monitor, a glazed strip in each,
## the monitor's glazed sides and its own roof, gutters, verges, ventilators on the ridge.
static func _hall_roof(pk: PropKit, kit: Dictionary, length: float, frames: Array) -> void:
	var z0 := 0.4
	var z1 := -length - 0.4
	var gz0 := -3.2
	var gz1 := -length + 3.2
	for s in [-1.0, 1.0]:
		var nrm := Vector3(s * SLOPE, 1.0, 0.0).normalized()
		var e: float = HALL_HW + 0.6
		var bands: Array = [[e, 12.4, false], [12.4, 9.8, true], [9.8, MON_X, false]]
		for bd in bands:
			var xa: float = bd[0]
			var xb: float = bd[1]
			var pa := Vector3(s * xa, hall_roof_y(xa), 0)
			var pb := Vector3(s * xb, hall_roof_y(xb), 0)
			if not bd[2]:
				_roof(pk, kit, "iron", pa + Vector3(0, 0, z0), pa + Vector3(0, 0, z1), pb + Vector3(0, 0, z1), pb + Vector3(0, 0, z0), ROOF_GREY, nrm)
				continue
			# The glazed strip, iron at its ends, a flashing frame round it.
			for zr in [[z0, gz0], [gz1, z1]]:
				_roof(pk, kit, "iron", pa + Vector3(0, 0, zr[0]), pa + Vector3(0, 0, zr[1]), pb + Vector3(0, 0, zr[1]), pb + Vector3(0, 0, zr[0]), ROOF_GREY, nrm)
			var up_slope: Vector3 = (pb - pa).normalized()
			var gl: float = gz0 - gz1
			var nseg: int = maxi(int(round(gl / 7.5)), 1)
			for k in range(nseg):
				var za: float = gz0 - gl * float(k) / float(nseg)
				var zb: float = gz0 - gl * float(k + 1) / float(nseg)
				var c: Vector3 = (pa + pb) * 0.5 + Vector3(0, 0, (za + zb) * 0.5) + nrm * 0.01
				_glazing(pk, kit, c, Vector3(0, 0, -1), up_slope, nrm, za - zb, pa.distance_to(pb))
				pk.beam(kit, "steel", pa + Vector3(0, 0, zb) + nrm * 0.05, pb + Vector3(0, 0, zb) + nrm * 0.05, 0.1, 0.08, STEEL_DARK, Vector3(0, 0, 1))
			for p in [pa, pb]:
				pk.beam(kit, "steel", p + Vector3(0, 0, gz0) + nrm * 0.05, p + Vector3(0, 0, gz1) + nrm * 0.05, 0.14, 0.08, STEEL_DARK, up_slope)
		# Gutter and fascia at the eaves.
		var ey: float = hall_roof_y(e)
		pk.tube(kit, "steel", Vector3(s * (e + 0.12), ey - 0.12, z0), Vector3(s * (e + 0.12), ey - 0.12, z1), 0.16, 0.16, 8, STEEL_DARK, true)
		_blk(pk, kit, "steel", Vector3(s * (e - 0.02), ey - 0.32, z0), Vector3(s * (e + 0.03), ey + 0.02, z1), STEEL_DARK)
		# The monitor's side: an iron band under the glazing, the glazing (panels between posts), a fascia.
		var mb: float = hall_roof_y(MON_X)
		var mt: float = _mon_roof_y(MON_X)
		_blk(pk, kit, "iron", Vector3(s * (MON_X - 0.1), mb - 0.12, -0.02), Vector3(s * (MON_X + 0.04), mb + 0.32, -length + 0.02), ROOF_GREY.darkened(0.1))
		_blk(pk, kit, "iron", Vector3(s * (MON_X - 0.1), mt - 0.3, -0.02), Vector3(s * (MON_X + 0.04), mt + 0.02, -length + 0.02), ROOF_GREY.darkened(0.1))
		var g0: float = mb + 0.32
		var g1: float = mt - 0.3
		for i in range(frames.size() - 1):
			var za2: float = float(frames[i]) - (0.6 if i == 0 else 0.15)
			var zb2: float = float(frames[i + 1]) + (0.6 if i == frames.size() - 2 else 0.15)
			var c2 := Vector3(s * (MON_X - 0.03), (g0 + g1) * 0.5, (za2 + zb2) * 0.5)
			_glazing(pk, kit, c2, Vector3(0, 0, -1), Vector3.UP, Vector3(s, 0, 0), za2 - zb2, g1 - g0)
			if i > 0:
				_blk(pk, kit, "steel", Vector3(s * (MON_X - 0.08), g0, float(frames[i]) - 0.15), Vector3(s * (MON_X + 0.05), g1, float(frames[i]) + 0.15), STEEL_DARK)
		# The monitor's roof, with its own gutter.
		var mn := Vector3(s * (RIDGE - MON_TOP + 0.1) / (MON_X + 0.5), 1.0, 0.0).normalized()
		var me: float = MON_X + 0.5
		_roof(pk, kit, "iron", Vector3(s * me, _mon_roof_y(me), z0), Vector3(s * me, _mon_roof_y(me), z1), Vector3(0, RIDGE, z1), Vector3(0, RIDGE, z0), ROOF_GREY, mn)
		pk.tube(kit, "steel", Vector3(s * (me + 0.08), _mon_roof_y(me) - 0.08, z0), Vector3(s * (me + 0.08), _mon_roof_y(me) - 0.08, z1), 0.09, 0.09, 6, STEEL_DARK, true)
		# Verge boards along the roof's ends.
		for zz in [z0, z1]:
			pk.beam(kit, "steel", Vector3(s * e, hall_roof_y(e) + 0.02, zz), Vector3(s * MON_X, hall_roof_y(MON_X) + 0.02, zz), 0.05, 0.3, STEEL_DARK, Vector3(0, 0, 1))
			pk.beam(kit, "steel", Vector3(s * me, _mon_roof_y(me) + 0.02, zz), Vector3(0, RIDGE + 0.02, zz), 0.05, 0.25, STEEL_DARK, Vector3(0, 0, 1))
	pk.beam(kit, "steel", Vector3(0, RIDGE + 0.05, z0), Vector3(0, RIDGE + 0.05, z1), 0.4, 0.12, STEEL_DARK)
	# Ventilator hoods along the ridge.
	for i in range(2, frames.size() - 2, 3):
		var vz: float = float(frames[i]) - 3.7
		pk.tube(kit, "steel", Vector3(0, RIDGE - 0.2, vz), Vector3(0, RIDGE + 1.1, vz), 0.5, 0.5, 10, ROOF_GREY, false)
		pk.lathe(kit, "steel", Vector3(0, RIDGE + 1.1, vz), [Vector2(0.85, 0.0), Vector2(0.9, 0.08), Vector2(0.55, 0.45), Vector2(0.001, 0.55)], 10, ROOF_GREY.darkened(0.1), false)
		pk.lathe(kit, "steel", Vector3(0, RIDGE + 1.09, vz), [Vector2(0.001, 0.0), Vector2(0.85, 0.0)], 10, ROOF_GREY.darkened(0.4), true)


## Lamps: pendants from the purlins over x ±10.4 in the middle of every bay, hung above the cranes' reach (their
## trolleys' canopies stand at 18.55, the dishes' undersides at 18.95), and a floodlight on every crane column under the
## runway aimed down across the floor toward the road.
static func _hall_lamps(pk: PropKit, kit: Dictionary, frames: Array) -> void:
	for i in range(frames.size() - 1):
		var z: float = (float(frames[i]) + float(frames[i + 1])) * 0.5
		for s in [-1.0, 1.0]:
			var top_y: float = hall_roof_y(10.4) - 0.36
			_pendant(pk, kit, Vector3(s * 10.4, top_y, z), top_y - 19.0)
	for i in range(1, frames.size() - 1):
		var z2: float = frames[i]
		for s in [-1.0, 1.0]:
			var p := Vector3(s * 16.0, 12.4, z2)
			var out := Vector3(-s, 0, 0)
			var bas := Basis(Vector3(0, 0, s), Vector3.UP, out) * Basis(Vector3.RIGHT, deg_to_rad(35.0))
			_box(pk, kit, "steel", p + out * 0.2, Basis(), Vector3(0.4, 0.12, 0.12), STEEL_DARK)
			_box(pk, kit, "steel", p + out * 0.45, bas, Vector3(0.7, 0.45, 0.3), STEEL_DARK)
			_box(pk, kit, "lamp", p + out * 0.45 + bas * Vector3(0, 0, 0.16), bas, Vector3(0.6, 0.36, 0.02), Color(1.0, 0.93, 0.8))


## The safety barrier between the road's margin and the works on both sides: a striped concrete kerb and a yellow rail.
static func _hall_barrier(pk: PropKit, kit: Dictionary, length: float) -> void:
	for s in [-1.0, 1.0]:
		var za := -2.2
		var zb: float = -length + 2.2
		_blk(pk, kit, "hazard", Vector3(s * BARRIER_X, -0.06, za), Vector3(s * (BARRIER_X + 0.4), 0.55, zb), WHITE)
		_railing(pk, kit, [Vector3(s * (BARRIER_X + 0.2), 0.55, za), Vector3(s * (BARRIER_X + 0.2), 0.55, zb)], 0.6, CRANE_YELLOW)


# ======================================================================================
#  Walzwerk 2: the mill train (x > 0)
# ======================================================================================

static func _mill_train(pk: PropKit, kit: Dictionary, length: float, labels: Array) -> void:
	_reheat_furnace(pk, kit, labels)
	# Charging table with cold slabs before the furnace, the discharge table, between the stands, the run-out.
	_roller_table(pk, kit, -1.2, -5.2, 0.85)
	_slab(pk, kit, Vector3(MILL_X, 1.04, -3.2), Vector3(1.9, 0.24, 3.6), -1.0)
	_roller_table(pk, kit, -30.4, -48.2, 1.0)
	_slab(pk, kit, Vector3(MILL_X, 1.06, -38.0), Vector3(1.9, 0.24, 11.0), 0.93)
	_mill_stand(pk, kit, labels, -50.0, 1.0, "VORGERÜST")
	_slab(pk, kit, Vector3(MILL_X, 1.06, -50.0), Vector3(1.85, 0.2, 5.2), 0.9)
	_roller_table(pk, kit, -51.8, -70.2, 1.0)
	_slab(pk, kit, Vector3(MILL_X, 1.06, -59.8), Vector3(1.8, 0.12, 14.4), 0.82)
	_mill_stand(pk, kit, labels, -72.0, 0.85, "FERTIGGERÜST")
	_slab(pk, kit, Vector3(MILL_X, 1.06, -72.0), Vector3(1.8, 0.08, 4.0), 0.8)
	_roller_table(pk, kit, -73.8, -length + 4.0, 1.0)
	_slab(pk, kit, Vector3(MILL_X, 1.06, -86.0), Vector3(1.8, 0.05, 20.0), 0.72)
	_cooling_bed(pk, kit, -98.0, -142.0)


## A slab or plate on a roller table: `c` the middle of its underside, `t` its temperature (< 0: cold steel).
static func _slab(pk: PropKit, kit: Dictionary, c: Vector3, size: Vector3, t: float) -> void:
	var key: String = "hot" if t >= 0.0 else "rusty"
	var col: Color = hot_colour(t) if t >= 0.0 else Color(0.34, 0.31, 0.29)
	_blk(pk, kit, key, c - Vector3(size.x * 0.5, 0.0, size.z * 0.5), c + Vector3(size.x * 0.5, size.y, size.z * 0.5), col)


## A roller table (Rollgang) along the roll line from z0 to z1: side frames on legs, rollers every metre with their drive
## motors on the outer side, a dark trough under them, the pass line at y.
static func _roller_table(pk: PropKit, kit: Dictionary, z0: float, z1: float, y := 1.0) -> void:
	var hw := 1.55
	var x := MILL_X
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(x + sx * hw, y - 0.55, z0), Vector3(x + sx * (hw + 0.22), y - 0.08, z1), MACHINE)
	_blk(pk, kit, "matte", Vector3(x - hw, 0.18, z0), Vector3(x + hw, 0.26, z1), Color(0.07, 0.065, 0.06))
	var zz: float = z0
	var k := 0
	while zz > z1 + 0.5:
		zz -= 3.0
		if zz < z1 + 0.3:
			break
		for sx in [-1.0, 1.0]:
			_blk(pk, kit, "steel", Vector3(x + sx * hw, -0.02, zz - 0.15), Vector3(x + sx * (hw + 0.22), y - 0.55, zz + 0.15), MACHINE.darkened(0.2))
	var z: float = z0 - 0.5
	while z > z1 + 0.2:
		pk.tube(kit, "steel", Vector3(x - hw - 0.05, y - 0.18, z), Vector3(x + hw + 0.05, y - 0.18, z), 0.17, 0.17, 8, Color(0.42, 0.42, 0.42), false)
		if k % 2 == 0:
			_blk(pk, kit, "steel", Vector3(x + hw + 0.22, y - 0.45, z - 0.2), Vector3(x + hw + 0.62, y - 0.02, z + 0.2), MACHINE.lightened(0.05))
		z -= 1.0
		k += 1


## A four-high mill stand at z: two cast housings (posts and windows) either side of the roll line, the backup and work
## rolls in their chocks, the screw-down gear on a platform on top, the spindles to the pinion stand and the drive motor
## by the wall; `scale_s` sizes it.
static func _mill_stand(pk: PropKit, kit: Dictionary, labels: Array, z: float, sc: float, name: String) -> void:
	var x := MILL_X
	var pass_y := 1.1
	var hz: float = 1.45 * sc
	var top: float = 7.2 * sc
	var wr: float = 0.48 * sc
	var br: float = 0.85 * sc
	var col := MACHINE
	for sx in [-1.0, 1.0]:
		var hx: float = x + sx * 2.0
		# Posts, the top beam and the sole plate.
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "rusty", Vector3(hx - 0.45, 0.0, z + sz * hz - 0.42), Vector3(hx + 0.45, top, z + sz * hz + 0.42), col)
		_blk(pk, kit, "rusty", Vector3(hx - 0.42, top - 1.2 * sc, z - hz + 0.4), Vector3(hx + 0.42, top - 0.03, z + hz - 0.4), col)
		_blk(pk, kit, "steel", Vector3(hx - 0.55, -0.02, z - hz - 0.7), Vector3(hx + 0.7, 0.3, z + hz + 0.7), STEEL_DARK)
		_blk(pk, kit, "hazard", Vector3(hx - 0.47, 0.3, z - hz - 0.44), Vector3(hx + 0.47, 1.2, z - hz + 0.1), WHITE)
		# Chocks in the window.
		for ry in [pass_y + 0.06 + wr, pass_y + 0.06 + 2.0 * wr + br, pass_y - 0.06 - wr]:
			_blk(pk, kit, "steel", Vector3(hx - 0.42, ry - 0.5 * sc, z - hz + 0.42), Vector3(hx + 0.42, ry + 0.5 * sc, z + hz - 0.42), Color(0.30, 0.32, 0.33))
	# The rolls: the top backup roll, the two work rolls (the slab between them), necks into the chocks.
	var rolls: Array = [[pass_y + 0.06 + wr, wr], [pass_y + 0.06 + 2.0 * wr + br, br], [pass_y - 0.06 - wr, wr]]
	for r in rolls:
		var ry: float = r[0]
		var rr: float = r[1]
		pk.tube(kit, "metal", Vector3(x - 1.55, ry, z), Vector3(x + 1.55, ry, z), rr, rr, 18, Color(0.62, 0.62, 0.6), false)
		pk.tube(kit, "steel", Vector3(x - 2.5, ry, z), Vector3(x + 2.5, ry, z), rr * 0.55, rr * 0.55, 12, Color(0.4, 0.4, 0.4), true)
	# A pit under the bottom roll.
	_blk(pk, kit, "matte", Vector3(x - 1.5, -0.01, z - 1.0), Vector3(x + 1.5, 0.0, z + 1.0), Color(0.02, 0.02, 0.02))
	# The screw-down platform, motors and railing on top.
	var py: float = top
	_blk(pk, kit, "steel", Vector3(x - 2.55, py, z - hz - 0.3), Vector3(x + 2.55, py + 0.3, z + hz + 0.3), STEEL_DARK)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "paint", Vector3(x + sx * 2.0, py + 0.3, z), Vector3(x + sx * 2.0, py + 1.4, z), 0.45, 0.45, 12, col.lightened(0.08), true)
	pk.tube(kit, "paint", Vector3(x - 1.4, py + 1.0, z), Vector3(x + 1.4, py + 1.0, z), 0.5, 0.5, 14, Color(0.15, 0.27, 0.42), true)
	_blk(pk, kit, "paint", Vector3(x - 0.6, py + 0.3, z - 0.6), Vector3(x + 0.6, py + 1.0, z + 0.6), Color(0.2, 0.22, 0.24))
	_railing(pk, kit, [Vector3(x - 2.5, py + 0.3, z - hz - 0.25), Vector3(x + 2.5, py + 0.3, z - hz - 0.25), Vector3(x + 2.5, py + 0.3, z + hz + 0.25),
			Vector3(x - 2.5, py + 0.3, z + hz + 0.25), Vector3(x - 2.5, py + 0.3, z - hz - 0.25)], 1.05)
	# A ladder up the operator side's post.
	_ladder(pk, kit, Vector3(x - 2.15, 0.0, z + hz + 0.42), Vector3(x - 2.15, py + 0.3, z + hz + 0.42), Vector3(0, 0, 1), true)
	# Spindles from the work rolls to the pinion stand, the pinion stand, the motor.
	var pin_x0 := 14.0
	for r in [rolls[0], rolls[2]]:
		var ry2: float = r[0]
		var target_y: float = 1.5 + (0.45 if ry2 > pass_y else -0.45)
		pk.tube(kit, "steel", Vector3(x + 2.45, ry2, z), Vector3(pin_x0, target_y, z), 0.24, 0.24, 10, Color(0.36, 0.38, 0.38), false)
		for e in [[Vector3(x + 2.5, ry2, z), 0.36], [Vector3(pin_x0 - 0.1, target_y, z), 0.36]]:
			pk.tube(kit, "steel", e[0] - Vector3(0.18, 0, 0), e[0] + Vector3(0.18, 0, 0), e[1], e[1], 10, Color(0.3, 0.32, 0.32), true)
	_blk(pk, kit, "rusty", Vector3(pin_x0, -0.02, z - 1.1), Vector3(pin_x0 + 0.85, 2.6, z + 1.1), col)
	_blk(pk, kit, "steel", Vector3(pin_x0 + 0.85, -0.02, z - 1.8), Vector3(15.95, 0.5, z + 1.8), STEEL_DARK)
	pk.tube(kit, "paint", Vector3(pin_x0 + 0.95, 1.85, z), Vector3(15.9, 1.85, z), 1.35 * sc + 0.1, 1.35 * sc + 0.1, 20, Color(0.15, 0.27, 0.42), true)
	for k in range(5):
		var rx: float = lerpf(pin_x0 + 1.05, 15.8, float(k) / 4.0)
		pk.tube(kit, "paint", Vector3(rx - 0.04, 1.85, z), Vector3(rx + 0.04, 1.85, z), 1.35 * sc + 0.16, 1.35 * sc + 0.16, 20, Color(0.12, 0.22, 0.35), false)
	_blk(pk, kit, "paint", Vector3(pin_x0 + 1.2, 1.85 + 1.2 * sc, z - 0.7), Vector3(15.6, 1.85 + 1.6 * sc + 0.2, z + 0.7), Color(0.13, 0.24, 0.38))
	# Descaling water headers before the stand.
	for sy in [pass_y + 0.55, pass_y - 0.2]:
		pk.tube(kit, "steel", Vector3(x - 1.6, sy, z + hz + 0.75), Vector3(x + 1.6, sy, z + hz + 0.75), 0.1, 0.1, 8, Color(0.45, 0.45, 0.45), true)
	_label(labels, name, Vector3(x - 2.47, top - 0.6 * sc, z), Vector3(-1, 0, 0), 0.3, CREAM, 2.4)


## Stoßofen: the reheating furnace at the way in, x 8.6..15.6, z -5.5..-30: a steel casing on buckstays with inspection
## doors along the road side (their slots glowing), burners and an air main on top, the charging door at its +z end and
## the discharge door at its -z end, open and glowing, a slab coming out.
static func _reheat_furnace(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var x0 := 8.6
	var x1 := 15.6
	var z0 := -5.5
	var z1 := -30.0
	var h := 6.0
	_blk(pk, kit, "concrete", Vector3(x0 - 0.2, -0.5, z0 + 0.2), Vector3(x1 + 0.2, 0.25, z1 - 0.2), CONCRETE.darkened(0.1))
	_blk(pk, kit, "rusty", Vector3(x0, 0.25, z0), Vector3(x1, h, z1), CASING)
	_blk(pk, kit, "rusty", Vector3(x0 - 0.1, h, z0 + 0.1), Vector3(x1 + 0.1, h + 0.35, z1 - 0.1), CASING.darkened(0.15))
	# Buckstays on both long sides and tie rods over the top.
	var z := z0 - 0.8
	var k := 0
	while z > z1 + 0.5:
		for e in [[x0, -1.0], [x1, 1.0]]:
			var ex: float = e[0]
			var sd: float = e[1]
			_blk(pk, kit, "steel", Vector3(ex - sd * 0.02, 0.25, z - 0.14), Vector3(ex + sd * 0.26, h + 0.6, z + 0.14), STEEL_DARK)
		pk.beam(kit, "steel", Vector3(x0 + 0.13, h + 0.55, z), Vector3(x1 - 0.13, h + 0.55, z), 0.08, 0.08, STEEL_DARK)
		# Inspection doors on the road side between the buckstays, a glowing slot under each.
		if k % 2 == 0 and z > z1 + 1.5:
			var dz: float = z - 0.8
			_blk(pk, kit, "steel", Vector3(x0 - 0.12, 1.1, dz - 0.5), Vector3(x0 + 0.01, 2.3, dz + 0.5), Color(0.26, 0.26, 0.27))
			_blk(pk, kit, "hot", Vector3(x0 - 0.06, 0.95, dz - 0.4), Vector3(x0 + 0.005, 1.08, dz + 0.4), hot_colour(0.75))
			_blk(pk, kit, "steel", Vector3(x0 - 0.2, 2.3, dz - 0.6), Vector3(x0 + 0.01, 2.45, dz + 0.6), STEEL_DARK)
			pk.tube(kit, "hot", Vector3(x0 - 0.16, 1.85, dz), Vector3(x0 - 0.1, 1.85, dz), 0.07, 0.07, 8, hot_colour(0.95), true)
		z -= 1.6
		k += 1
	# The air main and burners along the top.
	pk.tube(kit, "rusty", Vector3(x0 + 1.4, h + 1.4, z0 + 0.6), Vector3(x0 + 1.4, h + 1.4, z1 - 0.6), 0.45, 0.45, 12, Color(0.55, 0.45, 0.3), true)
	pk.tube(kit, "rusty", Vector3(x1 - 1.4, h + 1.2, z0 + 0.6), Vector3(x1 - 1.4, h + 1.2, z1 - 0.6), 0.3, 0.3, 10, Color(0.62, 0.22, 0.12), true)
	var bz := z0 - 1.5
	while bz > z1 + 1.0:
		for bx in [x0 + 1.4, x1 - 1.4]:
			pk.tube(kit, "steel", Vector3(bx, h + 0.35, bz), Vector3(bx, h + 1.1, bz), 0.16, 0.16, 8, STEEL_DARK, true)
			_blk(pk, kit, "steel", Vector3(bx - 0.35, h + 0.35, bz - 0.35), Vector3(bx + 0.35, h + 0.7, bz + 0.35), Color(0.3, 0.3, 0.3))
		bz -= 2.5
	# A walkway on the roof with a railing on the road side, a ladder.
	_railing(pk, kit, [Vector3(x0 + 0.1, h + 0.35, z0 - 0.3), Vector3(x0 + 0.1, h + 0.35, z1 + 0.3)], 1.0)
	_ladder(pk, kit, Vector3(x1 + 0.3, 0.0, z0 - 0.2), Vector3(x1 + 0.3, h + 0.35, z0 - 0.2), Vector3(1, 0, 0), true)
	# The discharge door (-z end): a raised door over a glowing mouth, the slab coming out.
	var dx := MILL_X
	_blk(pk, kit, "hot", Vector3(dx - 1.25, 0.95, z1 - 0.04), Vector3(dx + 1.25, 1.85, z1 + 0.3), hot_colour(0.98))
	_blk(pk, kit, "steel", Vector3(dx - 1.45, 1.85, z1 - 0.5), Vector3(dx + 1.45, 3.1, z1 + 0.02), Color(0.3, 0.3, 0.31))
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(dx + sx * 1.25, 0.25, z1 - 0.45), Vector3(dx + sx * 1.6, 4.4, z1 + 0.02), STEEL_DARK)
		pk.tube(kit, "steel", Vector3(dx + sx * 1.42, 3.1, z1 - 0.3), Vector3(dx + sx * 1.42, 4.6, z1 - 0.3), 0.12, 0.12, 8, Color(0.5, 0.5, 0.5), true)
	_blk(pk, kit, "hazard", Vector3(dx - 1.6, 4.4, z1 - 0.47), Vector3(dx + 1.6, 4.75, z1 + 0.02), WHITE)
	# The charging door (+z end): closed, a cold slab before it.
	_blk(pk, kit, "steel", Vector3(dx - 1.3, 0.9, z0 - 0.02), Vector3(dx + 1.3, 2.1, z0 + 0.12), Color(0.3, 0.3, 0.31))
	_blk(pk, kit, "steel", Vector3(dx - 1.5, 2.1, z0 - 0.02), Vector3(dx + 1.5, 2.4, z0 + 0.25), STEEL_DARK)
	_label(labels, "STOSSOFEN 2", Vector3(x0 - 0.03, h - 0.8, (z0 + z1) * 0.5), Vector3(-1, 0, 0), 0.42, CREAM, 6.0)
	# Gas valve station on the outer side: pipes down to a valve with a hand wheel.
	pk.tube(kit, "rusty", Vector3(x1 + 0.5, h + 1.2, z1 + 2.0), Vector3(x1 + 0.5, 1.0, z1 + 2.0), 0.22, 0.22, 10, Color(0.75, 0.62, 0.15), true)
	pk.tube(kit, "steel", Vector3(x1 + 0.25, 2.0, z1 + 2.0), Vector3(x1 + 0.75, 2.0, z1 + 2.0), 0.36, 0.36, 12, Color(0.65, 0.15, 0.1), true)


## Kühlbett: notched racks across the bed from the run-out table to the wall, bars lying along it from glowing (by the
## table) to cold (by the wall).
static func _cooling_bed(pk: PropKit, kit: Dictionary, z0: float, z1: float) -> void:
	var xa: float = MILL_X + 1.85
	var xb := 15.8
	var z: float = z0
	while z >= z1:
		_blk(pk, kit, "steel", Vector3(xa, 0.25, z - 0.06), Vector3(xb, 0.9, z + 0.06), STEEL_DARK)
		_blk(pk, kit, "steel", Vector3(xa + 0.2, -0.02, z - 0.25), Vector3(xa + 0.6, 0.25, z + 0.25), STEEL_DARK)
		_blk(pk, kit, "steel", Vector3(xb - 0.6, -0.02, z - 0.25), Vector3(xb - 0.2, 0.25, z + 0.25), STEEL_DARK)
		z -= 1.5
	_blk(pk, kit, "matte", Vector3(xa, 0.05, z0 + 0.2), Vector3(xb, 0.12, z1 - 0.2), Color(0.09, 0.08, 0.07))
	var n := 14
	for i in range(n):
		var bx: float = lerpf(xa + 0.35, xb - 0.35, float(i) / float(n - 1))
		var t: float = 0.78 - float(i) * 0.075
		var key: String = "hot" if t > 0.05 else "rusty"
		var col: Color = hot_colour(t) if t > 0.05 else Color(0.32, 0.30, 0.29)
		_blk(pk, kit, key, Vector3(bx - 0.08, 0.9, z0 + 0.4), Vector3(bx + 0.08, 1.04, z1 - 0.4), col)
	# The skids that walk bars off the run-out table.
	for zz in [z0 - 4.0, z0 - 16.0, z0 - 28.0, z0 - 40.0]:
		_blk(pk, kit, "paint", Vector3(MILL_X + 1.6, 0.6, zz - 0.15), Vector3(xa + 0.1, 0.95, zz + 0.15), MACHINE.lightened(0.1))


# ======================================================================================
#  Walzwerk 2: the west side (x < 0), the cranes, the signs
# ======================================================================================

## The side across the road from the mill: spare rolls on their stands and chocks, plate stacks, the control pulpit
## looking across at the stands, the coil store under crane 2, a scrap skip.
static func _hall_west_side(pk: PropKit, kit: Dictionary, length: float, labels: Array) -> void:
	# Spare rolls on V-block stands at their necks.
	var radii: Array = [0.85, 0.85, 0.5, 0.5]
	for i in range(4):
		var z: float = -5.5 - float(i) * 4.0
		var r: float = radii[i]
		var yc: float = 0.55 + 0.55 * r
		for sx in [-9.75, -14.65]:
			_blk(pk, kit, "steel", Vector3(sx - 0.35, -0.02, z - 0.55), Vector3(sx + 0.35, 0.55 - 0.03, z + 0.55), MACHINE.darkened(0.25))
		pk.tube(kit, "metal", Vector3(-13.95, yc, z), Vector3(-10.45, yc, z), r, r, 18, Color(0.6, 0.6, 0.58), true)
		pk.tube(kit, "steel", Vector3(-15.2, yc, z), Vector3(-9.2, yc, z), r * 0.55, r * 0.55, 12, Color(0.45, 0.42, 0.4), true)
	for i in range(3):
		var cz: float = -20.2 - float(i) * 1.9
		_blk(pk, kit, "rusty", Vector3(-14.8, -0.02, cz - 0.7), Vector3(-13.2, 1.5, cz + 0.7), Color(0.28, 0.36, 0.42))
		_blk(pk, kit, "rusty", Vector3(-12.6, -0.02, cz - 0.7), Vector3(-11.0, 1.5, cz + 0.7), Color(0.28, 0.36, 0.42))
	# Plate stacks with timber spacers.
	for st in [[-30.0, 7], [-38.0, 11], [-112.0, 9], [-122.0, 6], [-132.0, 10]]:
		var cz2: float = st[0]
		var y := 0.0
		for k in range(int(st[1])):
			if k % 3 == 0:
				for bz in [-3.0, 0.0, 3.0]:
					_blk(pk, kit, "timber", Vector3(-14.7, y - 0.02, cz2 + bz - 0.12), Vector3(-9.3, y + 0.12, cz2 + bz + 0.12), Color(0.45, 0.35, 0.24))
				y += 0.12
			var off: float = 0.06 * float((k * 7) % 3 - 1)
			_blk(pk, kit, "rusty", Vector3(-14.4 + off, y, cz2 - 3.6 + off), Vector3(-9.6 + off, y + 0.07, cz2 + 3.6 - off), Color(0.33, 0.31, 0.3))
			y += 0.075
	_pulpit(pk, kit, labels, -61.0)
	# The coil store: coils lying on timber saddles, eyes toward the road.
	var cb := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
	for row in [[-10.0, 11], [-13.2, 7]]:
		for k in range(int(row[1])):
			var z: float = -78.0 - float(k) * 2.4
			var c := Vector3(float(row[0]), 0.98, z)
			for sz in [-0.55, 0.55]:
				_blk(pk, kit, "timber", Vector3(c.x - 0.6, -0.02, z + sz - 0.14), Vector3(c.x + 0.6, 0.2, z + sz + 0.14), Color(0.45, 0.35, 0.24))
			pk.tyre(kit, "metal", c, 0.36, 0.95, 1.3, 16, Color(0.40, 0.42, 0.44) if (k % 3) != 1 else Color(0.36, 0.33, 0.30), cb)
	# A scrap skip at the far end.
	var sz2: float = -length + 5.5
	_frustum(pk, kit, "rusty", -12.5, sz2, -0.02, 1.5, 2.0, 1.6, 1.9, 2.6, Color(0.55, 0.35, 0.1))
	for k in range(9):
		var a: float = float(k) * 0.7
		pk.beam(kit, "rusty", Vector3(-13.6 + 0.25 * float(k), 1.5, sz2 - 2.0 + 0.4 * float(k % 4)), Vector3(-12.0 + 0.2 * sin(a), 1.75 + 0.15 * float(k % 3), sz2 + 1.8 - 0.3 * float(k % 5)),
				0.12, 0.12, Color(0.38, 0.30, 0.26))


## A four-sided frustum (a skip, a hopper): the rectangle of half sizes (hx0, hz0) at y0 widening/narrowing to (hx1, hz1)
## at y1, with a floor.
static func _frustum(pk: PropKit, kit: Dictionary, key: String, cx: float, cz: float, y0: float, hx0: float, hz0: float, y1: float, hx1: float, hz1: float, col: Color) -> void:
	var lo: Array = [Vector2(-hx0, -hz0), Vector2(hx0, -hz0), Vector2(hx0, hz0), Vector2(-hx0, hz0)]
	var hi: Array = [Vector2(-hx1, -hz1), Vector2(hx1, -hz1), Vector2(hx1, hz1), Vector2(-hx1, hz1)]
	for i in range(4):
		var j: int = (i + 1) % 4
		var a0 := Vector3(cx + lo[i].x, y0, cz + lo[i].y)
		var b0 := Vector3(cx + lo[j].x, y0, cz + lo[j].y)
		var b1 := Vector3(cx + hi[j].x, y1, cz + hi[j].y)
		var a1 := Vector3(cx + hi[i].x, y1, cz + hi[i].y)
		var mid: Vector3 = (a0 + b0 + b1 + a1) * 0.25 - Vector3(cx, (y0 + y1) * 0.5, cz)
		var n: Vector3 = (b0 - a0).cross(a1 - a0).normalized()
		if n.dot(mid) < 0.0:
			n = -n
		pk.quad(kit, key, [a0, b0, b1, a1], n, col)
		pk.quad(kit, key, [a0, b0, b1, a1], -n, col.darkened(0.3))
	pk.quad(kit, key, [Vector3(cx - hx0, y0 + 0.05, cz - hz0), Vector3(cx + hx0, y0 + 0.05, cz - hz0), Vector3(cx + hx0, y0 + 0.05, cz + hz0), Vector3(cx - hx0, y0 + 0.05, cz + hz0)], Vector3.UP, col.darkened(0.4))


## The control pulpit (Steuerstand) on legs across the road from the stands at z: a cabin with its front glazed and
## leaning out over the mill, side windows, a stair up from the +z side.
static func _pulpit(pk: PropKit, kit: Dictionary, labels: Array, z: float) -> void:
	var x0 := -15.5
	var x1 := -8.6
	var za: float = z + 4.0
	var zb: float = z - 4.0
	var fy := 4.7
	var ry := 7.5
	for lx in [x0 + 0.3, x1 - 0.1]:
		for lz in [za - 0.3, zb + 0.3]:
			_blk(pk, kit, "hazard", Vector3(lx - 0.18, -0.02, lz - 0.18), Vector3(lx + 0.18, 2.0, lz + 0.18), WHITE)
			_blk(pk, kit, "steel", Vector3(lx - 0.16, 2.0, lz - 0.16), Vector3(lx + 0.16, fy - 0.3, lz + 0.16), STEEL)
			_blk(pk, kit, "concrete", Vector3(lx - 0.4, -0.5, lz - 0.4), Vector3(lx + 0.4, 0.08, lz + 0.4), CONCRETE)
	for lz in [za - 0.3, zb + 0.3]:
		pk.beam(kit, "steel", Vector3(x0 + 0.3, 0.4, lz), Vector3(x1 - 0.1, fy - 0.5, lz), 0.12, 0.12, STEEL)
	_blk(pk, kit, "steel", Vector3(x0 - 0.1, fy - 0.3, zb - 0.1), Vector3(x1 + 0.1, fy, za + 0.1), STEEL_DARK)
	# The cabin: back wall, roof, side walls following the leaning front, the lower front panel, the glass.
	var gx0 := -8.95
	var gx1 := -8.5
	var gy0 := 5.5
	_blk(pk, kit, "paint", Vector3(x0, fy, zb + 0.03), Vector3(x0 + 0.12, ry - 0.01, za - 0.03), Color(0.82, 0.8, 0.74))
	_blk(pk, kit, "paint", Vector3(x0 - 0.15, ry, zb - 0.15), Vector3(gx1 + 0.15, ry + 0.3, za + 0.15), Color(0.3, 0.32, 0.33))
	_blk(pk, kit, "paint", Vector3(gx0 - 0.1, fy, zb + 0.03), Vector3(gx0 + 0.02, gy0, za - 0.03), Color(0.82, 0.8, 0.74))
	var poly := PackedVector2Array([Vector2(x0, fy), Vector2(gx0, fy), Vector2(gx0, gy0), Vector2(gx1, ry), Vector2(x0, ry)])
	for e in [[za, 1.0], [zb, -1.0]]:
		_wall_poly(pk, kit, "paint", Vector3(0, 0, float(e[0])), Vector3(1, 0, 0), Vector3(0, 0, float(e[1])), poly, Color(0.82, 0.8, 0.74), 0.1)
		var wc := Vector3(-11.6, 6.35, float(e[0]) + float(e[1]) * 0.03)
		_glazing(pk, kit, wc, Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, float(e[1])), 3.6, 1.3)
		_window_frame(pk, kit, wc, Vector3(1, 0, 0), Vector3(0, 0, float(e[1])), 3.6, 1.3, Color(0.3, 0.32, 0.33), 2, 0)
	var up := Vector3(gx1 - gx0, ry - gy0, 0).normalized()
	var out := Vector3(up.y, -up.x, 0)
	var gc := Vector3((gx0 + gx1) * 0.5, (gy0 + ry) * 0.5, z)
	_glazing(pk, kit, gc, Vector3(0, 0, -1), up, out, za - zb, Vector3(gx1 - gx0, ry - gy0, 0).length())
	for k in range(7):
		var mz: float = lerpf(za - 0.13, zb + 0.13, float(k) / 6.0)
		pk.beam(kit, "steel", Vector3(gx0, gy0, mz) + out * 0.03, Vector3(gx1, ry, mz) + out * 0.03, 0.08, 0.08, Color(0.3, 0.32, 0.33), out)
	pk.beam(kit, "steel", Vector3(gx0, gy0, za - 0.06) + out * 0.03, Vector3(gx0, gy0, zb + 0.06) + out * 0.03, 0.1, 0.1, Color(0.3, 0.32, 0.33))
	# An air conditioner and an aerial on the roof, the name on the roof's fascia.
	_blk(pk, kit, "paint", Vector3(-14.6, ry + 0.3, z - 1.0), Vector3(-13.4, ry + 1.1, z + 1.0), Color(0.75, 0.75, 0.72))
	pk.tube(kit, "steel", Vector3(-14.9, ry + 0.3, z + 3.0), Vector3(-14.9, ry + 3.0, z + 3.0), 0.03, 0.02, 6, STEEL_DARK, true)
	_label(labels, "STEUERSTAND", Vector3(gx1 + 0.17, ry + 0.15, z), Vector3(1, 0, 0), 0.2, CREAM, 6.0)
	_label(labels, "STEUERSTAND", Vector3((x0 + x1) * 0.5, ry + 0.15, za + 0.17), Vector3(0, 0, 1), 0.2, CREAM, 6.0)
	# The stair up from the +z side, a landing at the door.
	_stair(pk, kit, Vector3(-14.6, 0.0, za + 6.0), Vector3(-14.6, fy, za + 0.2), 1.0, STEEL, CRANE_YELLOW)
	_box(pk, kit, "paint", Vector3(-14.5, fy + 1.1, za + 0.06), Basis(), Vector3(1.0, 2.1, 0.06), Color(0.3, 0.36, 0.34))
	_railing(pk, kit, [Vector3(-13.95, fy, za + 0.12), Vector3(x1 + 0.1, fy, za + 0.12)], 1.05)


## An overhead travelling crane at z: end carriages on the runway rails, two yellow box girders across the hall (their
## underside at CRANE_BOT, 14.75), a walkway, the trolley at x = tx with its hoist, ropes to the hook block at hook_y
## (its underside), and a load ("coil": a C-hook with a coil), the cab hung under the girders over one side.
static func _crane(pk: PropKit, kit: Dictionary, labels: Array, zc: float, tx: float, hook_y: float, load_kind: String, number: int) -> void:
	var col := CRANE_YELLOW
	var gb := CRANE_BOT
	var gt: float = gb + 1.8
	for s in [-1.0, 1.0]:
		var cx: float = s * HALL_IN
		_blk(pk, kit, "paint", Vector3(cx - 0.45, RAIL_TOP + 0.25, zc - 3.3), Vector3(cx + 0.45, gt + 0.15, zc + 3.3), col)
		for wz in [-2.5, 2.5]:
			pk.tube(kit, "steel", Vector3(cx - 0.52, RAIL_TOP + 0.42, zc + wz), Vector3(cx + 0.52, RAIL_TOP + 0.42, zc + wz), 0.42, 0.42, 12, STEEL_DARK, true)
		for e in [-1.0, 1.0]:
			pk.tube(kit, "paint", Vector3(cx, RAIL_TOP + 0.8, zc + e * 3.28), Vector3(cx, RAIL_TOP + 0.8, zc + e * 3.75), 0.2, 0.2, 8, Color(0.12, 0.12, 0.12), true)
		_blk(pk, kit, "paint", Vector3(cx - s * 0.45 - s * 0.9, gt - 0.1, zc + 1.7), Vector3(cx - s * 0.45, gt + 0.7, zc + 2.6), Color(0.15, 0.27, 0.42))
	for sz in [-1.0, 1.0]:
		var z0: float = zc + sz * 0.875
		var z1: float = zc + sz * 1.625
		_blk(pk, kit, "paint", Vector3(-15.9, gb, minf(z0, z1)), Vector3(15.9, gt, maxf(z0, z1)), col)
		var x := -14.3
		while x < 14.5:
			_blk(pk, kit, "paint", Vector3(x - 0.04, gb + 0.08, z1 - 0.02 * sz), Vector3(x + 0.04, gt - 0.08, z1 + 0.04 * sz), col.darkened(0.12))
			x += 2.2
		_label(labels, "KRAN %d" % number, Vector3(-6.0, (gb + gt) * 0.5, z1 + sz * 0.06), Vector3(0, 0, sz), 0.75, BLACK, 5.0)
		_label(labels, "50 t", Vector3(6.0, (gb + gt) * 0.5, z1 + sz * 0.06), Vector3(0, 0, sz), 0.9, BLACK, 3.5)
	# The walkway on the +z girder's outer side with its railing.
	_blk(pk, kit, "steel", Vector3(-15.75, gt - 0.08, zc + 1.62), Vector3(15.75, gt, zc + 2.45), STEEL_DARK)
	_railing(pk, kit, [Vector3(-15.6, gt, zc + 2.4), Vector3(15.6, gt, zc + 2.4)], 1.05, col)
	# The trolley: a frame on the girders, the hoist drum, motor and gearbox under a canopy.
	_blk(pk, kit, "paint", Vector3(tx - 1.9, gt, zc - 1.8), Vector3(tx + 1.9, gt + 0.55, zc + 1.8), col.darkened(0.08))
	pk.tube(kit, "steel", Vector3(tx - 0.5, gt + 1.15, zc - 1.25), Vector3(tx - 0.5, gt + 1.15, zc + 1.25), 0.55, 0.55, 14, Color(0.35, 0.36, 0.36), true)
	_blk(pk, kit, "paint", Vector3(tx + 0.4, gt + 0.55, zc - 0.9), Vector3(tx + 1.6, gt + 1.45, zc + 0.2), Color(0.15, 0.27, 0.42))
	_blk(pk, kit, "paint", Vector3(tx + 0.4, gt + 0.55, zc + 0.4), Vector3(tx + 1.4, gt + 1.3, zc + 1.4), col.darkened(0.2))
	_blk(pk, kit, "paint", Vector3(tx - 2.0, gt + 1.9, zc - 1.9), Vector3(tx + 2.0, gt + 2.0, zc + 1.9), col.darkened(0.05))
	for px in [-1.85, 1.85]:
		for pz in [-1.75, 1.75]:
			pk.beam(kit, "steel", Vector3(tx + px, gt + 0.55, zc + pz), Vector3(tx + px, gt + 1.9, zc + pz), 0.08, 0.08, STEEL_DARK)
	# Ropes down to the hook block.
	var by0: float = hook_y + 0.9
	var by1: float = hook_y + 2.0
	for rx in [-0.22, 0.22]:
		for rz in [-0.3, 0.3]:
			pk.beam(kit, "steel", Vector3(tx + rx, gt + 0.05, zc + rz), Vector3(tx + rx, by1, zc + rz), 0.035, 0.035, Color(0.2, 0.2, 0.2))
	_blk(pk, kit, "hazard", Vector3(tx - 0.5, by0, zc - 0.42), Vector3(tx + 0.5, by1, zc + 0.42), WHITE)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(tx + sx * 0.5, by1 - 0.35, zc), Vector3(tx + sx * 0.6, by1 - 0.35, zc), 0.4, 0.4, 10, STEEL_DARK, true)
	if load_kind == "coil":
		# A C-hook: a shank down beside the coil, a foot through its eye.
		var arm_y: float = hook_y - 2.6
		_blk(pk, kit, "paint", Vector3(tx - 0.2, hook_y + 0.5, zc - 0.25), Vector3(tx + 1.45, hook_y + 0.9, zc + 0.25), col)
		_blk(pk, kit, "paint", Vector3(tx + 1.05, arm_y - 0.25, zc - 0.25), Vector3(tx + 1.45, hook_y + 0.5, zc + 0.25), col)
		_blk(pk, kit, "paint", Vector3(tx - 0.95, arm_y - 0.25, zc - 0.22), Vector3(tx + 1.45, arm_y + 0.05, zc + 0.22), col)
		var cc := Vector3(tx - 0.05, arm_y + 0.05 + 0.36 - 0.02, zc)
		pk.tyre(kit, "metal", cc, 0.36, 0.95, 1.3, 16, Color(0.40, 0.42, 0.44), Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)))
	else:
		# A hook: a shank and a curved bill.
		pk.tube(kit, "steel", Vector3(tx, by0, zc), Vector3(tx, hook_y + 0.3, zc), 0.1, 0.1, 8, STEEL_DARK, true)
		var prev := Vector3(tx, hook_y + 0.3, zc)
		for k in range(1, 8):
			var a: float = PI * float(k) / 7.0 * 1.25
			var p := Vector3(tx + 0.28 - 0.28 * cos(a), hook_y + 0.3 - 0.28 * sin(a), zc)
			pk.beam(kit, "steel", prev, p, 0.13, 0.13, STEEL_DARK)
			prev = p
	# The cab, hung under the girders over the side where the trolley isn't.
	var cs: float = -signf(tx) if absf(tx) > 0.5 else 1.0
	var cx0: float = cs * 12.0
	var cx1: float = cs * 14.4
	var cy0: float = gb - 2.4
	var lo := Vector3(minf(cx0, cx1), cy0, zc - 1.5)
	var hi := Vector3(maxf(cx0, cx1), gb - 0.25, zc + 0.6)
	_blk(pk, kit, "paint", lo, Vector3(hi.x, cy0 + 0.9, hi.z), col)
	_blk(pk, kit, "paint", Vector3(lo.x - 0.1, hi.y, lo.z - 0.1), Vector3(hi.x + 0.1, hi.y + 0.12, hi.z + 0.1), col.darkened(0.1))
	_blk(pk, kit, "paint", Vector3(lo.x, cy0 + 0.9, lo.z), Vector3(hi.x, hi.y, lo.z + 0.08), col)
	var mid_y: float = (cy0 + 0.9 + hi.y) * 0.5
	var gh: float = hi.y - cy0 - 0.9
	var inner_x: float = lo.x if cs > 0.0 else hi.x
	var outer_x: float = hi.x if cs > 0.0 else lo.x
	var gx_a: float = inner_x
	var gx_b: float = outer_x - cs * 0.08
	_glazing(pk, kit, Vector3((gx_a + gx_b) * 0.5, mid_y, hi.z), Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, 1), absf(gx_b - gx_a), gh)
	_glazing(pk, kit, Vector3(inner_x, mid_y, (lo.z + 0.08 + hi.z) * 0.5), Vector3(0, 0, -1), Vector3.UP, Vector3(-cs, 0, 0), hi.z - lo.z - 0.08, gh)
	_blk(pk, kit, "paint", Vector3(minf(outer_x, outer_x - cs * 0.08), cy0 + 0.9, lo.z), Vector3(maxf(outer_x, outer_x - cs * 0.08), hi.y, hi.z), col)
	for px in [lo.x + 0.1, hi.x - 0.1]:
		for pz in [lo.z + 0.1, hi.z - 0.1]:
			pk.beam(kit, "steel", Vector3(px, hi.y + 0.1, pz), Vector3(px, gb + 0.02, pz), 0.08, 0.08, STEEL_DARK)


## Signs along the barriers, facing the traffic coming in (+z): a board on a single post (on the kerb, so nothing
## stands lower within |x| < 7.5).
static func _hall_signs(pk: PropKit, kit: Dictionary, labels: Array, length: float) -> void:
	var sx: float = BARRIER_X + 0.36
	var signs: Array = [
		[sx, -3.5, "SCHUTZHELM TRAGEN", WHITE, SIGN_BLUE, false, true],
		[sx, -33.0, "VORSICHT! HEISSES MATERIAL", SIGN_YELLOW, BLACK, true, false],
		[sx, -95.0, "ACHTUNG KRANBETRIEB", SIGN_YELLOW, BLACK, true, false],
		[-sx, -12.0, "ACHTUNG KRANBETRIEB", SIGN_YELLOW, BLACK, true, false],
		[-sx, -45.0, "GEHÖRSCHUTZ TRAGEN", WHITE, SIGN_BLUE, false, true],
		[-sx, -106.0, "STAPLERVERKEHR", SIGN_YELLOW, BLACK, true, false],
		[-sx, -length + 12.0, "RAUCHEN VERBOTEN", WHITE, Color(0.75, 0.1, 0.08), false, false],
	]
	for sg in signs:
		_post_sign(pk, kit, labels, Vector3(float(sg[0]), 0.55, float(sg[1])), Vector3(0, 0, 1), sg[2], sg[3], sg[4], sg[5], sg[6])


## A board on one post, its foot at `p`, facing `out`: a warning triangle or a blue disc above it.
static func _post_sign(pk: PropKit, kit: Dictionary, labels: Array, p: Vector3, out: Vector3, text: String, bg: Color, fg: Color, warn: bool, must: bool) -> void:
	var across: Vector3 = Vector3.UP.cross(out).normalized()
	var basis := Basis(across, Vector3.UP, out)
	var w := 1.7
	var h := 0.55
	var post_y := 1.9
	var extra: float = 1.3 if (warn or must) else 0.0
	pk.tube(kit, "steel", p - out * 0.03, p - out * 0.03 + Vector3(0, post_y + h + extra, 0), 0.05, 0.05, 6, Color(0.6, 0.6, 0.6), true)
	var mid: Vector3 = p + Vector3(0, post_y + h * 0.5, 0) + out * 0.04
	_box(pk, kit, "paint", mid, basis, Vector3(w, h, 0.03), bg)
	_box(pk, kit, "paint", mid - out * 0.025, basis, Vector3(w + 0.05, h + 0.05, 0.02), Color(0.25, 0.25, 0.25))
	_label(labels, text, mid + out * 0.025, out, cap_for(text, w, h), fg, w - 0.14)
	var c: Vector3 = p + Vector3(0, post_y + h + 0.66, 0) + out * 0.04
	if warn:
		var r := 0.6
		var tp: Array = []
		for k in range(3):
			var a: float = PI * 0.5 + TAU * float(k) / 3.0
			tp.append(c + across * (cos(a) * r) + Vector3.UP * (sin(a) * r))
		pk.tri(kit, "paint", tp[0], tp[1], tp[2], out, out, out, Color(0.06, 0.06, 0.06), out)
		pk.tri(kit, "paint", tp[0] - out * 0.02, tp[2] - out * 0.02, tp[1] - out * 0.02, -out, -out, -out, Color(0.45, 0.45, 0.45), -out)
		var ti: Array = []
		for k in range(3):
			ti.append(c + ((tp[k] as Vector3) - c) * 0.8 + out * 0.012)
		pk.tri(kit, "paint", ti[0], ti[1], ti[2], out, out, out, SIGN_YELLOW, out)
		_box(pk, kit, "paint", c + Vector3(0, 0.04, 0) + out * 0.02, basis, Vector3(0.07, 0.3, 0.012), BLACK)
		_box(pk, kit, "paint", c + Vector3(0, -0.2, 0) + out * 0.02, basis, Vector3(0.07, 0.07, 0.012), BLACK)
	elif must:
		# A blue disc (a lathe about `out`) with a white pictogram: a helmet's dome and brim.
		var db := Basis(across, out, -Vector3.UP)
		pk.lathe(kit, "paint", c, [Vector2(0.52, 0.0), Vector2(0.001, 0.0)], 18, SIGN_BLUE, true, db)
		pk.lathe(kit, "paint", c - out * 0.015, [Vector2(0.001, 0.0), Vector2(0.52, 0.0)], 18, Color(0.45, 0.45, 0.45), true, db)
		_box(pk, kit, "paint", c + out * 0.012 + Vector3(0, -0.08, 0), basis, Vector3(0.52, 0.07, 0.01), WHITE)
		_box(pk, kit, "paint", c + out * 0.03 + Vector3(0, 0.06, 0), basis, Vector3(0.36, 0.2, 0.01), WHITE)


# ======================================================================================
#  Chimneys and the cooling tower
# ======================================================================================

## A works chimney `h` tall standing at the origin. Style 0: brick, an octagonal plinth with a cornice, a round
## tapering shaft with iron bands, a corbelled head, a lightning rod and climbing irons. Style 1: concrete painted red and
## white in bands toward the top, platforms with railings and obstruction lights.
static func chimney(pk: PropKit, kit: Dictionary, h: float, style := 0) -> void:
	var r0: float = maxf(1.2, h * 0.045)
	var r1: float = r0 * 0.6
	var segs: int = 16 if h < 50.0 else 20
	if style == 0:
		var pb: float = r0 * 1.35
		var ph: float = maxf(3.0, h * 0.11)
		_blk(pk, kit, "concrete", Vector3(-pb - 0.5, -3.0, -pb - 0.5), Vector3(pb + 0.5, 0.35, pb + 0.5), CONCRETE)
		_lathe_uv(pk, kit, "brick", Vector3.ZERO, [Vector2(pb, 0.35), Vector2(pb, ph)], 8, BRICK, false, true)
		_lathe_uv(pk, kit, "brick", Vector3.ZERO, [Vector2(pb, ph), Vector2(pb + 0.2, ph + 0.15), Vector2(pb + 0.2, ph + 0.45), Vector2(pb * 0.5 + r0 * 0.5, ph + 0.5), Vector2(r0, ph + 0.6)], 8, BRICK_DARK, false, true)
		_lathe_uv(pk, kit, "brick", Vector3.ZERO, [Vector2(r0, ph + 0.55), Vector2(r1 * 1.04, h * 0.9)], segs, BRICK)
		var head: Array = [Vector2(r1 * 1.04, h * 0.9), Vector2(r1 * 1.18, h * 0.91), Vector2(r1 * 1.18, h * 0.95), Vector2(r1 * 1.08, h * 0.96),
				Vector2(r1 * 1.08, h - 0.4), Vector2(r1 * 1.2, h - 0.3), Vector2(r1 * 1.2, h), Vector2(r1 * 0.85, h), Vector2(r1 * 0.85, h - 1.5)]
		_lathe_uv(pk, kit, "brick", Vector3.ZERO, head, segs, BRICK_DARK)
		pk.lathe(kit, "matte", Vector3(0, h - 1.4, 0), [Vector2(0.001, 0.0), Vector2(r1 * 0.86, 0.0)], segs, Color(0.03, 0.03, 0.03), true)
		var y: float = h * 0.55
		while y < h * 0.9:
			var rr: float = lerpf(r0, r1 * 1.04, (y - ph) / (h * 0.9 - ph)) + 0.03
			pk.tube(kit, "steel", Vector3(0, y - 0.06, 0), Vector3(0, y + 0.06, 0), rr, rr, segs, STEEL_DARK, false)
			y += h * 0.07
		pk.tube(kit, "steel", Vector3(r1 * 0.9, h - 0.2, 0), Vector3(r1 * 0.9, h + 2.5, 0), 0.04, 0.02, 6, STEEL_DARK, true)
		# Climbing irons up the north side.
		var ky: float = ph + 1.0
		while ky < h - 0.6:
			var rk: float = lerpf(r0, r1 * 1.04, clampf((ky - ph) / (h * 0.9 - ph), 0.0, 1.0))
			pk.beam(kit, "steel", Vector3(-0.2, ky, -rk - 0.18), Vector3(0.2, ky, -rk - 0.18), 0.03, 0.03, STEEL_DARK)
			ky += 0.9
		return
	# Style 1: concrete, red and white bands over the top third.
	_blk(pk, kit, "concrete", Vector3(-r0 - 1.0, -3.0, -r0 - 1.0), Vector3(r0 + 1.0, 0.4, r0 + 1.0), CONCRETE)
	var band_from: float = h * 0.62
	var nb := 7
	var prof_y: Array = [0.4, band_from]
	for k in range(1, nb + 1):
		prof_y.append(lerpf(band_from, h, float(k) / float(nb)))
	for k in range(prof_y.size() - 1):
		var ya: float = prof_y[k]
		var yb: float = prof_y[k + 1]
		var ra: float = lerpf(r0, r1, ya / h)
		var rb: float = lerpf(r0, r1, yb / h)
		var c: Color = Color(0.70, 0.69, 0.66) if k == 0 else (RED_WHITE_RED if k % 2 == 1 else Color(0.92, 0.91, 0.88))
		pk.lathe(kit, "grime", Vector3.ZERO, [Vector2(ra, ya), Vector2(rb, yb)], segs, c)
	pk.lathe(kit, "grime", Vector3(0, h, 0), [Vector2(r1, 0.0), Vector2(r1 - 0.3, 0.0), Vector2(r1 - 0.3, -1.2)], segs, Color(0.15, 0.13, 0.12), true)
	pk.lathe(kit, "matte", Vector3(0, h - 1.1, 0), [Vector2(0.001, 0.0), Vector2(r1 - 0.3, 0.0)], segs, Color(0.03, 0.03, 0.03), true)
	for py in [h * 0.62 - 1.2, h - 4.0]:
		var pr: float = lerpf(r0, r1, py / h)
		_ring_deck(pk, kit, Vector3(0, py, 0), pr, pr + 1.2, segs)
		for k in range(4):
			var a: float = TAU * float(k) / 4.0 + 0.4
			_box(pk, kit, "lamp", Vector3(cos(a) * (pr + 0.5), py + 1.3, sin(a) * (pr + 0.5)), Basis(), Vector3(0.25, 0.25, 0.25), Color(1.0, 0.12, 0.08))
	_blk(pk, kit, "steel", Vector3(-0.6, 0.4, -r0 - 0.08), Vector3(0.6, 2.4, -r0 + 0.3), STEEL_DARK)
	_slant_ladder(pk, kit, Vector3(0, 0.4, -r0 - 0.2), Vector3(0, h - 4.0, -lerpf(r0, r1, (h - 4.0) / h) - 0.2))


## A vertical ladder from `base` up to `top` on a face looking `out`: two rails and rungs every 0.4m, and from 2.4m up a
## cage of half hoops every 1.8m with three straps (lighter than YardKit.ladder's, for the tall ones here).
static func _ladder(pk: PropKit, kit: Dictionary, base: Vector3, top: Vector3, out: Vector3, cage := false, col := STEEL_DARK) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var stand: Vector3 = out * 0.14
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", base + across * (sx * 0.23) + stand, top + across * (sx * 0.23) + stand, 0.05, 0.05, col)
	var n: int = int((top.y - base.y) / 0.4)
	for k in range(1, n + 1):
		var p: Vector3 = base.lerp(top, float(k) / float(n + 1)) + stand
		pk.beam(kit, "steel", p - across * 0.23, p + across * 0.23, 0.035, 0.035, col)
	if not cage or top.y - base.y < 3.0:
		return
	var y: float = base.y + 2.4
	while y < top.y - 0.3:
		var t: float = (y - base.y) / (top.y - base.y)
		var c: Vector3 = base.lerp(top, t) + stand
		var prev := Vector3.ZERO
		for k in range(6):
			var a: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 5.0)
			var p2: Vector3 = c + out * (0.5 * cos(a)) + across * (0.5 * sin(a))
			if k > 0:
				pk.beam(kit, "steel", prev, p2, 0.03, 0.03, col)
			prev = p2
		y += 1.8
	for a2 in [-0.9, 0.0, 0.9]:
		var o2: Vector3 = out * (0.5 * cos(a2)) + across * (0.5 * sin(a2))
		pk.beam(kit, "steel", base.lerp(top, 2.4 / (top.y - base.y)) + stand + o2, top + stand + o2 - Vector3(0, 0.3, 0), 0.03, 0.03, col)


## A ladder of two rails and rungs every 0.3m along a slanted line a..b (off a tapering shaft), facing -z/+z as it lies.
static func _slant_ladder(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, col := STEEL_DARK) -> void:
	for sx in [-0.23, 0.23]:
		pk.beam(kit, "steel", a + Vector3(sx, 0, 0), b + Vector3(sx, 0, 0), 0.05, 0.05, col)
	var n: int = int((b.y - a.y) / 0.3)
	for k in range(1, n):
		var p: Vector3 = a.lerp(b, float(k) / float(n))
		pk.beam(kit, "steel", p + Vector3(-0.23, 0, 0), p + Vector3(0.23, 0, 0), 0.035, 0.035, col)


## A hyperbolic natural-draught cooling tower about 50m tall standing at the origin: the thin concrete shell from 5m
## (radius 19) narrowing to the throat (12) at 38m and opening a little to the lip (13.1) at 50m, on a ring of
## crossed raking legs over the cold-water basin. Outside 21.2 radius (the basin's wall).
static func cooling_tower(pk: PropKit, kit: Dictionary) -> void:
	var rt := 12.0
	var yt := 38.0
	var b := 26.88
	var y0 := 5.0
	var y1 := 50.0
	var segs := 40
	var prof: Array = []
	var y: float = y0
	while y < y1 + 0.01:
		prof.append(Vector2(rt * sqrt(1.0 + pow((y - yt) / b, 2.0)), y))
		y += 2.5
	var shell := Color(0.66, 0.65, 0.62)
	pk.lathe(kit, "grime", Vector3.ZERO, prof, segs, shell)
	var inner: Array = []
	for k in range(prof.size() - 1, -1, -1):
		inner.append(Vector2((prof[k] as Vector2).x - 0.35, (prof[k] as Vector2).y))
	pk.lathe(kit, "grime", Vector3.ZERO, inner, segs, shell.darkened(0.35))
	var top: Vector2 = prof[-1]
	pk.lathe(kit, "grime", Vector3.ZERO, [Vector2(top.x - 0.35, y1), Vector2(top.x + 0.15, y1), Vector2(top.x + 0.15, y1 - 0.6), Vector2(top.x, y1 - 0.6)], segs, shell.darkened(0.08), true)
	var bot: Vector2 = prof[0]
	# The ring beam under the shell and the crossed legs.
	pk.lathe(kit, "grime", Vector3.ZERO, [Vector2(bot.x - 0.5, y0 - 0.6), Vector2(bot.x + 0.25, y0 - 0.6), Vector2(bot.x + 0.25, y0 + 0.2), Vector2(bot.x - 0.5, y0 + 0.2), Vector2(bot.x - 0.5, y0 - 0.6)], segs, shell.darkened(0.12), true)
	var nl := 36
	for k in range(nl):
		var a0: float = TAU * float(k) / float(nl)
		for sd in [-1.0, 1.0]:
			var a1: float = a0 + sd * TAU / float(nl)
			var foot := Vector3(cos(a0) * (bot.x + 0.6), -0.3, sin(a0) * (bot.x + 0.6))
			var head := Vector3(cos(a1) * bot.x, y0 - 0.5, sin(a1) * bot.x)
			pk.beam(kit, "grime", foot, head, 0.45, 0.45, shell.darkened(0.05))
		_blk(pk, kit, "concrete", Vector3(cos(a0) * (bot.x + 0.6) - 0.7, -3.0, sin(a0) * (bot.x + 0.6) - 0.7), Vector3(cos(a0) * (bot.x + 0.6) + 0.7, 0.25, sin(a0) * (bot.x + 0.6) + 0.7), CONCRETE)
	# The basin: its rim wall outside the legs, dark water inside, the fill (packing) seen through the legs.
	pk.lathe(kit, "concrete", Vector3.ZERO, [Vector2(21.2, -0.5), Vector2(21.2, 1.0), Vector2(20.8, 1.0), Vector2(20.8, 0.4)], segs, CONCRETE, true)
	pk.lathe(kit, "concrete", Vector3.ZERO, [Vector2(20.8, 0.4), Vector2(0.001, 0.4)], segs, Color(0.12, 0.15, 0.15), true)
	pk.lathe(kit, "matte", Vector3(0, 3.6, 0), [Vector2(0.001, 0.0), Vector2(bot.x - 0.4, 0.0)], segs, Color(0.16, 0.16, 0.15), true)
	pk.lathe(kit, "matte", Vector3(0, 3.6, 0), [Vector2(bot.x - 0.4, 0.0), Vector2(bot.x - 0.4, -1.2), Vector2(0.001, -1.2)], segs, Color(0.22, 0.22, 0.21), true)
	# A ladder up the outside and an aircraft light ring on the lip.
	for k in range(4):
		var a: float = TAU * float(k) / 4.0 + 0.3
		_box(pk, kit, "lamp", Vector3(cos(a) * (top.x + 0.3), y1 + 0.2, sin(a) * (top.x + 0.3)), Basis(), Vector3(0.3, 0.3, 0.3), Color(1.0, 0.15, 0.1))


# ======================================================================================
#  Hochofen 3: the blast furnace
# ======================================================================================

const BF_CAST_Y := 7.0       # the cast house floor
const BF_TOWER := 11.0       # the furnace stand's legs (±x, ±z)
const BF_TOP_Y := 46.0       # the top platform
const BF_SHELL := Color(0.27, 0.26, 0.25)

static func _bf_radius(y: float) -> float:
	var prof: Array = _bf_profile()
	for k in range(prof.size() - 1):
		var a: Vector2 = prof[k]
		var b: Vector2 = prof[k + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 0.001))
	return 3.0


static func _bf_profile() -> Array:
	return [Vector2(6.4, 0.6), Vector2(6.4, 9.6), Vector2(6.25, 10.6), Vector2(7.0, 15.5), Vector2(7.0, 18.0), Vector2(5.3, 40.0), Vector2(5.3, 42.0),
			Vector2(3.2, 45.0), Vector2(2.9, 45.6)]


## Hochofen 3 at the origin (the furnace's axis on the ground): the furnace (hearth 12.8m across, bosh 14m) in its
## four-legged stand (legs at x, z ±11) with platforms at 20, 30, 40 and the top at 46, stairs at the -x -z corner; the top
## with its charging gear and four uptakes joining into the downcomer down to the dust catcher at x -32; the bleeders to
## ~74m; the skip hoist rising at 43 degrees from its pit at z +64 (the stock house z 66..86) to the top; the cast house to
## +x (x 7..40, z -13.5..13.5, floor at 7) with the iron runner glowing from the tap hole to a spout over a torpedo car on
## a track along z at x 24 under it. Footprint: x -40..41, z -16..87; 74m to the bleeders' tops.
static func blast_furnace(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	_blk(pk, kit, "concrete", Vector3(-13.0, -3.0, -13.0), Vector3(13.0, 0.6, 13.0), CONCRETE)
	var prof: Array = _bf_profile()
	pk.lathe(kit, "rusty", Vector3.ZERO, prof, 32, BF_SHELL)
	pk.lathe(kit, "rusty", Vector3.ZERO, [Vector2(2.9, 45.6), Vector2(0.001, 45.6)], 32, BF_SHELL.darkened(0.2), true)
	# Cooling rings and stave bands, vertical cooling pipes up the stack.
	var y := 2.0
	while y < 41.5:
		var r: float = _bf_radius(y) + 0.05
		pk.tube(kit, "steel", Vector3(0, y - 0.09, 0), Vector3(0, y + 0.09, 0), r, r - (0.004 if y > 18.0 else 0.0), 32, BF_SHELL.darkened(0.25), false)
		y += 1.6 if y > 18.0 else 1.2
	for k in range(24):
		var a: float = TAU * (float(k) + 0.5) / 24.0
		var d := Vector3(cos(a), 0, sin(a))
		pk.tube(kit, "steel", d * 7.25 + Vector3(0, 18.2, 0), d * 5.55 + Vector3(0, 39.6, 0), 0.07, 0.07, 6, Color(0.4, 0.38, 0.35), false)
		pk.tube(kit, "steel", d * 6.65 + Vector3(0, 0.8, 0), d * 6.65 + Vector3(0, 9.4, 0), 0.07, 0.07, 6, Color(0.4, 0.38, 0.35), false)
	# The bustle pipe round the furnace at 13, the tuyere stocks down to the tuyeres at 10.4.
	var br := 10.6
	var by := 13.2
	var n := 28
	for k in range(n):
		var a0: float = TAU * float(k) / float(n)
		var a1: float = TAU * float(k + 1) / float(n)
		pk.tube(kit, "rusty", Vector3(cos(a0) * br, by, sin(a0) * br), Vector3(cos(a1) * br, by, sin(a1) * br), 1.05, 1.05, 12, Color(0.42, 0.38, 0.33), false)
	for k in range(20):
		var a: float = TAU * (float(k) + 0.5) / 20.0
		var d := Vector3(cos(a), 0, sin(a))
		var p0: Vector3 = d * br + Vector3(0, by - 0.9, 0)
		var p1: Vector3 = d * (br - 1.6) + Vector3(0, by - 2.2, 0)
		var p2: Vector3 = d * 6.5 + Vector3(0, 10.4, 0)
		pk.tube(kit, "steel", p0, p1, 0.24, 0.24, 8, Color(0.36, 0.34, 0.32), false)
		pk.tube(kit, "steel", p1, p2, 0.2, 0.2, 8, Color(0.36, 0.34, 0.32), false)
		pk.tube(kit, "hot", p2 + d * 0.15, p2 + d * 0.05, 0.12, 0.12, 8, hot_colour(1.0), true)
		pk.tube(kit, "steel", p1 - d * 0.1 + Vector3(0, -0.1, 0), p1 + d * 0.25 + Vector3(0, 0.1, 0), 0.34, 0.34, 8, Color(0.3, 0.3, 0.3), true)
	# The hot-blast connection from the bustle pipe toward -z (the stoves): a stub with a flange.
	pk.tube(kit, "rusty", Vector3(0, by, -br), Vector3(0, by, -br - 6.0), 1.2, 1.2, 14, Color(0.42, 0.38, 0.33), true)
	_bf_stand(pk, kit, labels)
	_bf_top(pk, kit, labels)
	_bf_dust_catcher(pk, kit)
	_bf_skip_hoist(pk, kit, labels)
	_bf_cast_house(pk, kit, labels)


## The furnace stand: four legs at ±11 up to the top platform, braced, ring platforms with railings, the stair tower.
static func _bf_stand(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var t := BF_TOWER
	_tower(pk, kit, "steel", Vector3(0, 0.6, 0), BF_TOP_Y - 0.85, t, t, 9.0, STEEL, 0.9, 0.3)
	for lvl in [20.0, 30.0, 40.0]:
		var r: float = _bf_radius(lvl) + 0.25
		_ring_deck(pk, kit, Vector3(0, lvl, 0), r, r + 2.6, 32)
		for k in range(4):
			var a: float = PI * 0.25 + PI * 0.5 * float(k)
			var d := Vector3(cos(a), 0, sin(a))
			pk.beam(kit, "steel", d * (r + 2.4) + Vector3(0, lvl - 0.24, 0), Vector3(signf(d.x) * t, lvl - 0.24, signf(d.z) * t), 0.36, 0.36, STEEL)
	# The top platform: a square deck over the stand with a hole for the furnace top, railing round its edge.
	var ty := BF_TOP_Y
	for q in [[Vector3(-t - 0.5, ty - 0.35, -t - 0.5), Vector3(t + 0.5, ty, -3.6)], [Vector3(-t - 0.5, ty - 0.35, 3.6), Vector3(t + 0.5, ty, t + 0.5)],
			[Vector3(-t - 0.5, ty - 0.35, -3.6), Vector3(-3.6, ty, 3.6)], [Vector3(3.6, ty - 0.35, -3.6), Vector3(t + 0.5, ty, 3.6)]]:
		_blk(pk, kit, "steel", q[0], q[1], STEEL_DARK)
	_railing(pk, kit, [Vector3(-t - 0.4, ty, -t - 0.4), Vector3(t + 0.4, ty, -t - 0.4), Vector3(t + 0.4, ty, t + 0.4), Vector3(-t - 0.4, ty, t + 0.4), Vector3(-t - 0.4, ty, -t - 0.4)], 1.1, CRANE_YELLOW)
	_blk(pk, kit, "rusty", Vector3(-t - 0.6, ty - 2.2, -t - 0.6), Vector3(t + 0.6, ty - 0.35, -t - 0.2), STEEL)
	_label(labels, "HOCHOFEN 3", Vector3(0, ty - 1.27, -t - 0.65), Vector3(0, 0, -1), 1.3, CREAM, 18.0)
	_blk(pk, kit, "rusty", Vector3(t + 0.2, ty - 2.2, -t - 0.2), Vector3(t + 0.6, ty - 0.35, t + 0.6), STEEL)
	_label(labels, "HOCHOFEN 3", Vector3(t + 0.65, ty - 1.27, 0), Vector3(1, 0, 0), 1.3, CREAM, 18.0)
	# The stair tower at the -x -z corner: flights back and forth up to the top.
	var sx := -t - 3.2
	var z0 := -t + 1.0
	var z1 := -t + 7.0
	var yy := 0.6
	var k := 0
	while yy < ty - 0.1:
		var y2: float = minf(yy + 3.0, ty)
		var a := Vector3(sx + (0.6 if k % 2 == 0 else -0.6), yy, z0 if k % 2 == 0 else z1)
		var b := Vector3(a.x, y2, z1 if k % 2 == 0 else z0)
		_stair(pk, kit, a, b, 1.0, STEEL, CRANE_YELLOW)
		_blk(pk, kit, "steel", Vector3(sx - 1.3, y2 - 0.12, b.z - 1.2 if k % 2 == 0 else b.z), Vector3(sx + 1.3, y2, b.z if k % 2 == 0 else b.z + 1.2), STEEL_DARK)
		yy = y2
		k += 1
	for cx in [sx - 1.35, sx + 1.35]:
		for cz in [z0 - 1.25, z1 + 1.25]:
			pk.beam(kit, "steel", Vector3(cx, 0.0, cz), Vector3(cx, ty, cz), 0.22, 0.22, STEEL)
	pk.beam(kit, "steel", Vector3(sx + 1.35, ty - 0.2, z0 - 1.25), Vector3(-t, ty - 0.2, z0 - 1.25), 0.3, 0.3, STEEL)


## The furnace's top: the charging gear housing and its hoppers, the upper stand, the uptakes joining into the
## downcomer, the bleeders.
static func _bf_top(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
	var ty := BF_TOP_Y
	# The charging gear: a housing on the top cone, two material hoppers over it, the receiving chute.
	pk.lathe(kit, "rusty", Vector3(0, 45.4, 0), [Vector2(2.6, 0.0), Vector2(2.6, 3.4), Vector2(2.0, 4.0), Vector2(0.001, 4.0)], 20, BF_SHELL.lightened(0.05), false)
	for sx in [-1.0, 1.0]:
		var hc := Vector3(sx * 2.0, 49.4, 0.5)
		pk.lathe(kit, "rusty", hc, [Vector2(0.5, 0.0), Vector2(2.0, 2.0), Vector2(2.0, 6.0), Vector2(1.9, 6.2), Vector2(0.001, 6.2)], 16, Color(0.36, 0.34, 0.3), false)
	_blk(pk, kit, "steel", Vector3(-2.2, 55.6, 0.0), Vector3(2.2, 57.5, 4.5), Color(0.32, 0.31, 0.3))
	# The upper stand, from the top platform to the gas offtake's platform at 62.
	_tower(pk, kit, "steel", Vector3(0, ty, 0), 16.0, 6.5, 4.5, 4.0, STEEL, 0.55, 0.22, false)
	_blk(pk, kit, "steel", Vector3(-5.0, 61.6, -5.0), Vector3(5.0, 62.0, -2.0), STEEL_DARK)
	_blk(pk, kit, "steel", Vector3(-5.0, 61.6, 2.0), Vector3(5.0, 62.0, 5.0), STEEL_DARK)
	_railing(pk, kit, [Vector3(-4.9, 62.0, -4.9), Vector3(4.9, 62.0, -4.9), Vector3(4.9, 62.0, 4.9), Vector3(-4.9, 62.0, 4.9), Vector3(-4.9, 62.0, -4.9)], 1.1, CRANE_YELLOW)
	# Four uptakes from the top cone up and out, then up beside the hoppers, joining in pairs over x = ±4, the pairs
	# crossing to the downcomer's head at -x.
	var ur := 1.0
	var gas := Color(0.38, 0.35, 0.31)
	for k in range(4):
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		var d := Vector3(cos(a), 0, sin(a))
		var p0: Vector3 = d * 3.3 + Vector3(0, 44.6, 0)
		var p1: Vector3 = d * 5.4 + Vector3(0, 49.0, 0)
		var p2: Vector3 = d * 5.4 + Vector3(0, 60.0, 0)
		var j := Vector3(signf(d.x) * 4.2, 64.5, 0)
		_pipe(pk, kit, "rusty", [p0, p1, p2, j], ur, gas, 12, 0.0, false)
	var ja := Vector3(4.2, 64.5, 0)
	var jb := Vector3(-4.2, 64.5, 0)
	_pipe(pk, kit, "rusty", [ja, jb], 1.25, gas, 14, 0.0, false)
	for jp in [ja, jb]:
		pk.lathe(kit, "rusty", jp, [Vector2(0.001, -1.4), Vector2(1.0, -1.2), Vector2(1.4, -0.4), Vector2(1.45, 0.4), Vector2(1.0, 1.2), Vector2(0.001, 1.4)], 14, gas)
		# A bleeder: a pipe up from the joint to its valve, a hood.
		pk.tube(kit, "rusty", jp + Vector3(0, 1.2, 0), jp + Vector3(0, 8.0, 0), 0.6, 0.6, 12, gas, false)
		pk.tube(kit, "steel", jp + Vector3(0, 8.0, 0), jp + Vector3(0, 8.6, 0), 0.9, 0.9, 12, Color(0.3, 0.3, 0.3), true)
		pk.lathe(kit, "steel", jp + Vector3(0, 8.6, 0), [Vector2(0.9, 0.0), Vector2(0.9, 0.3), Vector2(0.3, 0.9), Vector2(0.001, 1.0)], 12, Color(0.3, 0.3, 0.3), false)
		_ring_deck(pk, kit, jp + Vector3(0, 7.6, 0), 0.65, 1.9, 12)
	# The downcomer: from the -x joint over and down to the dust catcher's head.
	var dc_head := Vector3(-32.0, 38.0, 0)
	_pipe(pk, kit, "rusty", [jb, Vector3(-8.0, 64.5, 0), dc_head + Vector3(0, 1.6, 0)], 1.4, gas, 14, 0.0, false)
	# Supports for the downcomer from the stand's -x legs.
	pk.beam(kit, "steel", Vector3(-BF_TOWER, BF_TOP_Y, 0), Vector3(-14.0, 57.0, 0), 0.4, 0.4, STEEL)
	pk.beam(kit, "steel", Vector3(-BF_TOWER, BF_TOP_Y - 9.0, 0), Vector3(-14.0, 57.0, 0), 0.4, 0.4, STEEL)


## The dust catcher at x -32: a cylinder on four legs, cone top and bottom, the clean-gas main leaving toward -x.
static func _bf_dust_catcher(pk: PropKit, kit: Dictionary) -> void:
	var c := Vector3(-32.0, 0, 0)
	var col := Color(0.40, 0.37, 0.33)
	_lathe_uv(pk, kit, "rusty", c, [Vector2(0.9, 8.0), Vector2(5.5, 15.0), Vector2(5.5, 31.0), Vector2(1.4, 37.5), Vector2(1.4, 38.0)], 24, col)
	pk.lathe(kit, "rusty", c, [Vector2(0.9, 8.0), Vector2(0.001, 8.0)], 24, col.darkened(0.3), true)
	pk.tube(kit, "steel", c + Vector3(0, 6.2, 0), c + Vector3(0, 8.1, 0), 0.6, 0.6, 12, STEEL_DARK, true)
	var y := 16.5
	while y < 30.5:
		pk.tube(kit, "steel", c + Vector3(0, y - 0.08, 0), c + Vector3(0, y + 0.08, 0), 5.56, 5.56, 24, col.darkened(0.2), false)
		y += 2.0
	for k in range(4):
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		var d := Vector3(cos(a), 0, sin(a))
		pk.beam(kit, "steel", c + d * 6.2 + Vector3(0, -0.2, 0), c + d * 5.4 + Vector3(0, 16.0, 0), 0.6, 0.6, STEEL)
		_blk(pk, kit, "concrete", c + d * 6.2 + Vector3(-0.9, -3.0, -0.9), c + d * 6.2 + Vector3(0.9, 0.3, 0.9), CONCRETE)
		var e: Vector3 = Vector3(-d.z, 0, d.x)
		pk.beam(kit, "steel", c + d * 6.1 + Vector3(0, 1.0, 0), c + (d * 0.7071 + e * 0.7071).normalized() * 5.95 + Vector3(0, 12.0, 0), 0.25, 0.25, STEEL)
	_ring_deck(pk, kit, c + Vector3(0, 31.0, 0), 5.55, 7.0, 24)
	_ring_deck(pk, kit, c + Vector3(0, 16.0, 0), 5.55, 7.0, 24)
	_ladder(pk, kit, c + Vector3(0, 16.0, 7.0), c + Vector3(0, 31.0, 7.0), Vector3(0, 0, 1), true)
	_ladder(pk, kit, c + Vector3(0, 0.0, 6.4), c + Vector3(0, 16.0, 6.4), Vector3(0, 0, 1), true)
	# The clean-gas main: out of the side at 24m toward -x, down to 10m and on along -x (ends at x -46, y 10).
	_pipe(pk, kit, "rusty", [c + Vector3(-5.3, 24.0, 0), c + Vector3(-9.0, 24.0, 0), c + Vector3(-9.0, 10.0, 0), c + Vector3(-14.0, 10.0, 0)], 1.0, col, 12, 0.0, true)
	_tower(pk, kit, "steel", c + Vector3(-11.5, 0, 0), 9.0, 1.4, 1.2, 3.0, STEEL, 0.3, 0.12)


## The skip hoist: an inclined box lattice bridge from the skip pit (at z +64, the stock house round it) up to the head
## over the hoppers, on a bent halfway, rails and two skips, the winch house at its foot.
static func _bf_skip_hoist(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var a := Vector3(0, 1.0, 64.0)
	var b := Vector3(0, 58.5, 5.0)
	var col := Color(0.30, 0.34, 0.33)
	_lattice(pk, kit, "steel", a, b, 4.0, 3.0, 3.4, col, Vector3.UP, 0.32, 0.14)
	var dir: Vector3 = (b - a).normalized()
	var up: Vector3 = (Vector3.UP - dir * dir.y).normalized()
	# Rails along the bottom and the two skips (one near the top, one near the foot).
	for sx in [-0.8, 0.8]:
		pk.beam(kit, "steel", a + Vector3(sx, 0, 0) - up * 1.25, b + Vector3(sx, 0, 0) - up * 1.25, 0.12, 0.15, RAIL_GREY, Vector3(1, 0, 0))
	for t in [0.82, 0.12]:
		var p: Vector3 = a.lerp(b, t) - up * 0.4
		_box(pk, kit, "rusty", p, Basis(Vector3(1, 0, 0), up, -dir), Vector3(2.2, 1.6, 3.4), Color(0.30, 0.28, 0.26))
	# The head frame and sheaves at the top, the dump chute into the receiving hopper.
	_blk(pk, kit, "steel", Vector3(-2.4, 58.0, 2.5), Vector3(2.4, 60.8, 6.0), col)
	pk.tube(kit, "steel", Vector3(-1.6, 60.2, 4.2), Vector3(1.6, 60.2, 4.2), 0.9, 0.9, 16, Color(0.3, 0.3, 0.3), true)
	# A bent under the bridge halfway up and at its upper third.
	for t in [0.33, 0.62]:
		var p2: Vector3 = a.lerp(b, t) - up * 1.6
		for sx in [-2.6, 2.6]:
			pk.beam(kit, "steel", Vector3(sx * 1.4, 0.0, p2.z), Vector3(sx, p2.y, p2.z), 0.55, 0.55, col)
			_blk(pk, kit, "concrete", Vector3(sx * 1.4 - 0.8, -3.0, p2.z - 0.8), Vector3(sx * 1.4 + 0.8, 0.3, p2.z + 0.8), CONCRETE)
		pk.beam(kit, "steel", Vector3(-2.6, p2.y, p2.z), Vector3(2.6, p2.y, p2.z), 0.5, 0.5, col)
		var yb := 6.0
		while yb < p2.y - 4.0:
			pk.beam(kit, "steel", Vector3(-2.6 * lerpf(1.4, 1.0, yb / p2.y), yb, p2.z), Vector3(2.6 * lerpf(1.4, 1.0, (yb + 6.0) / p2.y), yb + 6.0, p2.z), 0.2, 0.2, col)
			pk.beam(kit, "steel", Vector3(2.6 * lerpf(1.4, 1.0, yb / p2.y), yb, p2.z), Vector3(-2.6 * lerpf(1.4, 1.0, (yb + 6.0) / p2.y), yb + 6.0, p2.z), 0.2, 0.2, col)
			yb += 6.0
	# The stock house round the skip pit: a steel frame clad in corrugated iron, a gable roof along z.
	var x0 := -14.0
	var x1 := 14.0
	var z0 := 62.0
	var z1 := 86.0
	var eh := 11.0
	_blk(pk, kit, "concrete", Vector3(x0 - 0.3, -3.0, z0 - 0.3), Vector3(x1 + 0.3, 1.0, z1 + 0.3), CONCRETE)
	for w in [[Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(0, 0, -1)], [Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3(0, 0, 1)],
			[Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3(-1, 0, 0)], [Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(1, 0, 0)]]:
		var wa: Vector3 = w[0]
		var wb: Vector3 = w[1]
		var o: Vector3 = w[2]
		var along: Vector3 = (wb - wa).normalized()
		var wl: float = wa.distance_to(wb)
		var holes: Array = []
		if o.z < 0.0:
			holes.append([Rect2(wl * 0.5 - 2.6, 1.0, 5.2, 5.0), true])
		_wall_holes(pk, kit, "iron", wa, along, o, 0.0, wl, 1.0, eh, holes, Color(0.45, 0.47, 0.46), 0.15)
		var nb: int = int(wl / 6.0)
		for k in range(nb + 1):
			var cp: Vector3 = wa + along * (wl * float(k) / float(nb))
			pk.beam(kit, "steel", cp + o * 0.12 + Vector3(0, 1.0, 0), cp + o * 0.12 + Vector3(0, eh, 0), 0.3, 0.3, STEEL)
	var ridge := eh + 3.6
	var rn := Vector3(-3.6, 14.0, 0).normalized()
	_roof(pk, kit, "iron", Vector3(x0 - 0.5, eh - 0.13, z0 - 0.5), Vector3(x0 - 0.5, eh - 0.13, z1 + 0.5), Vector3(0, ridge, z1 + 0.5), Vector3(0, ridge, z0 - 0.5), ROOF_GREY, rn)
	_roof(pk, kit, "iron", Vector3(x1 + 0.5, eh - 0.13, z1 + 0.5), Vector3(x1 + 0.5, eh - 0.13, z0 - 0.5), Vector3(0, ridge, z0 - 0.5), Vector3(0, ridge, z1 + 0.5), ROOF_GREY, Vector3(3.6, 14.0, 0).normalized())
	for zz in [z0, z1]:
		var o2: float = -1.0 if zz == z0 else 1.0
		pk.tri(kit, "iron", Vector3(x0, eh, zz), Vector3(x1, eh, zz), Vector3(0, ridge - 0.05, zz), Vector3(0, 0, o2), Vector3(0, 0, o2), Vector3(0, 0, o2), Color(0.45, 0.47, 0.46), Vector3(0, 0, o2),
				Vector2(0, 0), Vector2(x1 - x0, 0) * uvk, Vector2(14.0, 3.6) * uvk)
		pk.tri(kit, "iron", Vector3(x0, eh, zz), Vector3(x1, eh, zz), Vector3(0, ridge - 0.05, zz), Vector3(0, 0, -o2), Vector3(0, 0, -o2), Vector3(0, 0, -o2), Color(0.3, 0.32, 0.31), Vector3(0, 0, -o2))
	_label(labels, "MÖLLERUNG", Vector3(0, eh - 1.4, z0 - 0.08), Vector3(0, 0, -1), 0.9, CREAM, 12.0)
	# The skip pit's dark mouth in the door, the winch house behind on the roof line.
	_blk(pk, kit, "matte", Vector3(-2.5, 1.0, z0 + 0.2), Vector3(2.5, 6.0, z0 + 0.4), Color(0.04, 0.04, 0.04))
	_blk(pk, kit, "brick", Vector3(-4.0, eh - 0.2, z0 + 6.0), Vector3(4.0, eh + 4.0, z0 + 12.0), BRICK)


## The cast house: a deck at the cast floor's height (7) from the furnace out to x 40, on columns, open below for the
## torpedo track along z at x 24; corrugated walls and a gable roof with a smoke vent along its ridge; the iron runner
## glowing from the tap hole to a spout pouring into the torpedo car.
static func _bf_cast_house(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var x0 := 6.9
	var x1 := 40.0
	var hz := 13.5
	var fy := BF_CAST_Y
	var hx0 := 22.2
	var hx1 := 25.6
	var hzh := 1.8
	# The deck in four pieces round the pouring hole over the track.
	for q in [[Vector3(x0, fy - 0.6, -hz), Vector3(hx0, fy, hz)], [Vector3(hx1, fy - 0.6, -hz), Vector3(x1, fy, hz)],
			[Vector3(hx0, fy - 0.6, -hz), Vector3(hx1, fy, -hzh)], [Vector3(hx0, fy - 0.6, hzh), Vector3(hx1, fy, hz)]]:
		_blk(pk, kit, "concrete", q[0], q[1], CONCRETE.darkened(0.15))
	# Columns under the deck (clear of the track: x 24 ±2.5), and the frame's columns up to the roof.
	var xs: Array = [10.5, 16.5, 30.0, 35.0, 40.0]
	for cx in xs:
		for cz in [-hz, -4.5, 4.5, hz]:
			_blk(pk, kit, "concrete", Vector3(cx - 0.4, -3.0, cz - 0.4), Vector3(cx + 0.4, fy - 0.6, cz + 0.4), CONCRETE)
	var eh := 19.0
	var ridge := 24.0
	for cx in [10.5, 16.5, 22.0, 27.0, 33.0, 39.6]:
		for cz in [-hz, hz]:
			_ibeam(pk, kit, "steel", Vector3(cx, fy, cz), Vector3(cx, eh, cz), 0.5, 0.35, STEEL, Vector3(0, 0, 1))
		pk.beam(kit, "steel", Vector3(cx, eh, -hz), Vector3(cx, ridge - 0.3, 0), 0.35, 0.4, STEEL)
		pk.beam(kit, "steel", Vector3(cx, eh, hz), Vector3(cx, ridge - 0.3, 0), 0.35, 0.4, STEEL)
		pk.beam(kit, "steel", Vector3(cx, eh, -hz + 0.25), Vector3(cx, eh, hz - 0.25), 0.3, 0.3, STEEL)
	# Walls: corrugated iron from 9.5 to the eaves (an open band over the floor with a railing), the far gable.
	var bays: Array = [10.5, 16.5, 22.0, 27.0, 33.0, 39.6]
	for e in [[-hz, -1.0], [hz, 1.0]]:
		var zz: float = e[0]
		var o := Vector3(0, 0, float(e[1]))
		var holes: Array = []
		for bi in range(bays.size() - 1):
			var ua: float = float(bays[bi]) - (x0 + 3.0) + 0.5
			var ub: float = float(bays[bi + 1]) - (x0 + 3.0) - 0.5
			holes.append([Rect2(ua, 15.2, ub - ua, 2.6), true])
		var wall_o := Vector3(x0 + 3.0, 0, zz)
		_wall_holes(pk, kit, "iron", wall_o, Vector3(1, 0, 0), o, 0.0, x1 - x0 - 3.0, 9.6, eh, holes, Color(0.48, 0.47, 0.44), 0.12)
		for hh in holes:
			var r: Rect2 = hh[0]
			var gc: Vector3 = wall_o + Vector3(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, 0) - o * 0.06
			_glazing(pk, kit, gc, Vector3(1, 0, 0) * o.z, Vector3.UP, o, r.size.x, r.size.y)
		_railing(pk, kit, [Vector3(x0 + 3.0, fy, zz + o.z * 0.1), Vector3(x1, fy, zz + o.z * 0.1)], 1.1, CRANE_YELLOW)
		# The cladding's lower edge: a steel rail.
		_blk(pk, kit, "steel", Vector3(x0 + 3.0, 9.3, zz - 0.08), Vector3(x1, 9.6, zz + 0.08), STEEL)
	_wall_holes(pk, kit, "iron", Vector3(x1, 0, -hz), Vector3(0, 0, 1), Vector3(1, 0, 0), 0.0, hz * 2.0, fy, eh, [[Rect2(hz - 6.0, fy, 12.0, 7.0), true]], Color(0.48, 0.47, 0.44), 0.12)
	pk.tri(kit, "iron", Vector3(x1, eh, -hz), Vector3(x1, eh, hz), Vector3(x1, ridge - 0.05, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Color(0.48, 0.47, 0.44), Vector3(1, 0, 0),
			Vector2(0, eh) * uvk, Vector2(hz * 2.0, eh) * uvk, Vector2(hz, ridge) * uvk)
	pk.tri(kit, "iron", Vector3(x1 - 0.12, eh, -hz), Vector3(x1 - 0.12, eh, hz), Vector3(x1 - 0.12, ridge - 0.05, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Color(0.3, 0.3, 0.29), Vector3(-1, 0, 0))
	_label(labels, "GIESSHALLE", Vector3(x1 + 0.08, eh - 2.6, 0), Vector3(1, 0, 0), 1.1, CREAM, 16.0)
	# The roof, with a raised smoke vent along the ridge.
	var sl: float = (ridge - eh) / hz
	for sd in [-1.0, 1.0]:
		var n := Vector3(0, 1.0, sd * sl).normalized()
		var ez: float = sd * (hz + 0.6)
		var ey: float = eh - 0.6 * sl
		var vz: float = sd * 2.0
		var vy: float = ridge - 2.0 * sl
		_roof(pk, kit, "iron", Vector3(x1 + 0.5, ey, ez), Vector3(x0 + 2.5, ey, ez), Vector3(x0 + 2.5, vy, vz), Vector3(x1 + 0.5, vy, vz), ROOF_GREY.darkened(0.15), n)
		_blk(pk, kit, "steel", Vector3(x0 + 2.5, vy - 0.05, minf(vz, vz - sd * 0.1)), Vector3(x1 + 0.5, vy + 1.6, maxf(vz, vz - sd * 0.1)), Color(0.15, 0.15, 0.15))
	_roof(pk, kit, "iron", Vector3(x1 + 0.7, ridge + 1.2, -2.6), Vector3(x0 + 2.3, ridge + 1.2, -2.6), Vector3(x0 + 2.3, ridge + 2.0, 0), Vector3(x1 + 0.7, ridge + 2.0, 0), ROOF_GREY, Vector3(0, 1.0, -0.3).normalized())
	_roof(pk, kit, "iron", Vector3(x0 + 2.3, ridge + 1.2, 2.6), Vector3(x1 + 0.7, ridge + 1.2, 2.6), Vector3(x1 + 0.7, ridge + 2.0, 0), Vector3(x0 + 2.3, ridge + 2.0, 0), ROOF_GREY, Vector3(0, 1.0, 0.3).normalized())
	# The tap hole and the iron runner: a refractory trough along +x on the floor with glowing iron in it, a spout over
	# the hole, the stream down into the torpedo car's mouth below.
	var tap := Vector3(6.35, fy + 0.6, 0)
	pk.tube(kit, "hot", tap - Vector3(0.12, 0, 0), tap + Vector3(0.3, 0, 0), 0.3, 0.3, 10, hot_colour(1.0), true)
	_blk(pk, kit, "concrete", Vector3(6.4, fy - 0.01, -0.9), Vector3(hx0 + 0.6, fy + 0.65, 0.9), FIREBRICK.darkened(0.25))
	_blk(pk, kit, "hot", Vector3(6.46, fy + 0.62, -0.5), Vector3(hx0 + 0.55, fy + 0.66, 0.5), hot_colour(0.92))
	_blk(pk, kit, "steel", Vector3(hx0 + 0.6, fy + 0.15, -0.7), Vector3(hx0 + 2.2, fy + 0.55, 0.7), Color(0.3, 0.28, 0.26))
	_blk(pk, kit, "hot", Vector3(hx0 + 0.66, fy + 0.53, -0.35), Vector3(hx0 + 1.9, fy + 0.57, 0.35), hot_colour(0.95))
	_blk(pk, kit, "hot", Vector3(hx0 + 1.7, 4.2, -0.22), Vector3(hx0 + 2.1, fy + 0.5, 0.22), hot_colour(1.0))
	# The mud gun on its swing arm beside the tap hole, the drill parked on the other side.
	_box(pk, kit, "paint", Vector3(8.8, fy + 1.4, -2.6), Basis(Vector3.UP, 0.5), Vector3(1.1, 1.0, 3.4), Color(0.2, 0.32, 0.4))
	pk.beam(kit, "steel", Vector3(10.5, fy, -4.2), Vector3(9.4, fy + 1.4, -3.2), 0.35, 0.35, STEEL)
	_box(pk, kit, "paint", Vector3(9.0, fy + 1.2, 2.8), Basis(Vector3.UP, -0.6), Vector3(0.7, 0.7, 4.2), Color(0.85, 0.55, 0.12))
	# The torpedo track along z under the deck, and a torpedo car under the spout.
	for sx in [-0.75, 0.75]:
		_blk(pk, kit, "steel", Vector3(hx0 + 1.9 + sx - 0.035, -0.18, -34.0), Vector3(hx0 + 1.9 + sx + 0.035, 0.0, 34.0), RAIL_GREY)
	var z := -33.5
	while z < 34.0:
		_blk(pk, kit, "timber", Vector3(hx0 + 0.6, -0.36, z - 0.13), Vector3(hx0 + 3.2, -0.18, z + 0.13), Color(0.32, 0.26, 0.2))
		z += 0.9
	var saved := _push(pk, Transform3D(Basis(), Vector3(hx0 + 1.9, 0.0, 0.0)))
	torpedo_car(pk, kit)
	_pop(pk, saved)


# ======================================================================================
#  Cowper: the hot-blast stoves
# ======================================================================================

## `count` hot-blast stoves in a row along z, centred on the origin, 12.5m apart (each 9.2m across, 36m to the dome's
## base, 41m to its top), the hot-blast main along them at x +7.6, 12m up, its branch running on toward +x to a flange
## at (32, 12, 0) for the generator's pipe_run to the furnace; the cold-blast main at x +6.4, 4m up; the waste-gas flue
## at x -7.4 into a 70m brick chimney at (-19, 0, 0). Footprint: x -24..33, z ±(6.25 count + 2).
static func cowpers(pk: PropKit, kit: Dictionary, count := 4) -> void:
	var r := 4.6
	var h := 36.0
	var col := Color(0.40, 0.39, 0.38)
	var zs: Array = []
	for i in range(count):
		zs.append((float(i) - float(count - 1) * 0.5) * 12.5)
	for zc in zs:
		var c := Vector3(0, 0, zc)
		_blk(pk, kit, "concrete", c + Vector3(-5.6, -3.0, -5.6), c + Vector3(5.6, 0.8, 5.6), CONCRETE)
		_lathe_uv(pk, kit, "rusty", c, [Vector2(r, 0.8), Vector2(r, h)], 28, col)
		var dome: Array = []
		for k in range(9):
			var a: float = PI * 0.5 * float(k) / 8.0
			dome.append(Vector2(r * cos(a) + 0.001, h + 5.0 * sin(a)))
		pk.lathe(kit, "rusty", c, dome, 28, col.darkened(0.08))
		var y := 3.0
		while y < h - 0.5:
			pk.tube(kit, "steel", c + Vector3(0, y - 0.06, 0), c + Vector3(0, y + 0.06, 0), r + 0.04, r + 0.04, 28, col.darkened(0.25), false)
			y += 3.0
		_ring_deck(pk, kit, c + Vector3(0, 12.0, 0), r, r + 1.6, 28)
		_ring_deck(pk, kit, c + Vector3(0, h, 0), r, r + 1.3, 28)
		_ladder(pk, kit, c + Vector3(-r - 0.05, 12.0, 0), c + Vector3(-r - 0.05, h, 0), Vector3(-1, 0, 0), true)
		_ladder(pk, kit, c + Vector3(-r - 0.05, 0.8, 1.2), c + Vector3(-r - 0.05, 12.0, 1.2), Vector3(-1, 0, 0), true)
		# The hot-blast valve on its spool toward the main, an actuator on top.
		pk.tube(kit, "rusty", c + Vector3(r - 0.2, 12.0 + 1.0, 0), c + Vector3(6.5, 13.0, 0), 0.85, 0.85, 12, Color(0.55, 0.42, 0.3), false)
		_blk(pk, kit, "steel", c + Vector3(5.2, 11.8, -1.1), c + Vector3(6.6, 14.3, 1.1), Color(0.25, 0.25, 0.26))
		pk.tube(kit, "steel", c + Vector3(5.9, 14.3, 0), c + Vector3(5.9, 16.2, 0), 0.25, 0.25, 8, Color(0.6, 0.15, 0.1), true)
		# The cold-blast stub at the foot (+x) and the chimney valve (-x).
		pk.tube(kit, "rusty", c + Vector3(r - 0.2, 4.0, 0), c + Vector3(6.4, 4.0, 0), 0.55, 0.55, 10, Color(0.42, 0.44, 0.46), false)
		pk.tube(kit, "rusty", c + Vector3(-r + 0.2, 2.2, 0), c + Vector3(-7.4, 2.2, 0), 0.75, 0.75, 12, Color(0.32, 0.30, 0.28), false)
		_blk(pk, kit, "steel", c + Vector3(-6.4, 1.2, -1.0), c + Vector3(-5.4, 3.4, 1.0), Color(0.25, 0.25, 0.26))
		# A burner (the gas valve and its wheel) on the -z side.
		pk.tube(kit, "rusty", c + Vector3(0, 6.0, -r + 0.2), c + Vector3(0, 6.0, -r - 1.4), 0.6, 0.6, 10, Color(0.62, 0.52, 0.18), true)
		pk.tube(kit, "steel", c + Vector3(-0.9, 6.0, -r - 1.0), c + Vector3(0.9, 6.0, -r - 1.0), 0.06, 0.06, 6, STEEL_DARK, true)
		pk.tube(kit, "steel", c + Vector3(0.9, 5.9, -r - 1.0), c + Vector3(0.9, 6.1, -r - 1.0), 0.4, 0.4, 10, Color(0.6, 0.12, 0.1), true)
	var z0: float = float(zs[0]) - 4.0
	var z1: float = float(zs[-1]) + 4.0
	# The hot-blast main along the row, its branch toward +x (the furnace), lattice bents under them.
	var hb := Color(0.55, 0.42, 0.3)
	_pipe(pk, kit, "rusty", [Vector3(7.6, 13.0, z0), Vector3(7.6, 13.0, z1)], 1.2, hb, 14, 6.0, true)
	_pipe(pk, kit, "rusty", [Vector3(7.6, 13.0, 0.0), Vector3(32.0, 13.0, 0.0)], 1.2, hb, 14, 6.0, true)
	pk.lathe(kit, "rusty", Vector3(7.6, 13.0, 0.0), [Vector2(0.001, -1.3), Vector2(1.25, -0.9), Vector2(1.35, 0.0), Vector2(1.25, 0.9), Vector2(0.001, 1.3)], 14, hb.darkened(0.1))
	for zz in range(int(z0) + 2, int(z1), 8):
		_pipe_bent(pk, kit, Vector3(7.6, 0.0, float(zz)), 13.0 - 1.3, 2.4, Vector3(0, 0, 1))
	var xx := 14.0
	while xx < 31.0:
		_pipe_bent(pk, kit, Vector3(xx, 0.0, 0.0), 13.0 - 1.3, 2.4, Vector3(1, 0, 0))
		xx += 8.0
	# The cold-blast main (low) and the waste-gas flue into the chimney.
	_pipe(pk, kit, "rusty", [Vector3(6.4, 4.0, z0), Vector3(6.4, 4.0, z1)], 0.8, Color(0.42, 0.44, 0.46), 12, 6.0, true)
	for zz in range(int(z0) + 2, int(z1), 8):
		_blk(pk, kit, "steel", Vector3(6.1, -0.1, float(zz) - 0.2), Vector3(6.7, 3.2, float(zz) + 0.2), STEEL)
	_pipe(pk, kit, "rusty", [Vector3(-7.4, 2.2, z0), Vector3(-7.4, 2.2, z1)], 1.3, Color(0.32, 0.30, 0.28), 14, 0.0, true)
	_pipe(pk, kit, "rusty", [Vector3(-7.4, 2.2, 0.0), Vector3(-15.2, 2.2, 0.0)], 1.3, Color(0.32, 0.30, 0.28), 14, 0.0, false)
	var saved := _push(pk, Transform3D(Basis(), Vector3(-19.0, 0.0, 0.0)))
	chimney(pk, kit, 70.0, 0)
	_pop(pk, saved)
	# A walkway at the hot-blast valves' level along the row.
	_blk(pk, kit, "steel", Vector3(4.6, 11.84, z0), Vector3(5.8, 11.95, z1), STEEL_DARK)


## A pipe bent: two legs and a cross beam carrying a pipe whose underside is at `top`, legs `half` either side across
## `along` (the pipe's direction).
static func _pipe_bent(pk: PropKit, kit: Dictionary, p: Vector3, top: float, half: float, along: Vector3) -> void:
	var across: Vector3 = Vector3.UP.cross(along).normalized()
	for sd in [-1.0, 1.0]:
		var f: Vector3 = p + across * (sd * half)
		pk.beam(kit, "steel", f, f + Vector3(0, top, 0), 0.32, 0.32, STEEL, along)
		_blk(pk, kit, "concrete", f + Vector3(-0.5, -3.0, -0.5), f + Vector3(0.5, 0.25, 0.5), CONCRETE)
		pk.beam(kit, "steel", f + Vector3(0, 0.4, 0), p + across * (-sd * half * 0.85) + Vector3(0, top - 0.6, 0), 0.14, 0.14, STEEL, along)
	pk.beam(kit, "steel", p - across * (half + 0.3) + Vector3(0, top - 0.2, 0), p + across * (half + 0.3) + Vector3(0, top - 0.2, 0), 0.4, 0.4, STEEL, along)


# ======================================================================================
#  The gas holder
# ======================================================================================

## A disc-type gas holder at the origin: 24 sides, 45m across its corners (44.6 across the flats), 60m to the eaves,
## pilasters up every corner, a gallery every 8.5m, a shallow conical roof with a railing and a lantern (to 67.5), an
## outside stair winding up it, a door at the foot (facing +x), the name KRONBURG in big letters on the panels near the
## top (centred on +z). Outside 25.2 radius (the stair).
static func gasometer(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var n := 24
	var rc := 22.5
	var h := 60.0
	var col := GAS_GREEN
	var cs: Array = []
	for k in range(n + 1):
		var a: float = TAU * float(k) / float(n)
		cs.append(Vector3(cos(a) * rc, 0.0, sin(a) * rc))
	pk.lathe(kit, "concrete", Vector3.ZERO, [Vector2(rc + 1.2, -3.0), Vector2(rc + 1.2, 0.5), Vector2(rc - 0.3, 0.5)], n, CONCRETE, true)
	for k in range(n):
		var a: Vector3 = cs[k]
		var b: Vector3 = cs[k + 1]
		var mid: Vector3 = (a + b) * 0.5
		var out: Vector3 = mid.normalized()
		var w: float = a.distance_to(b)
		pk.quad(kit, "shell", [a + Vector3(0, 0.5, 0), b + Vector3(0, 0.5, 0), b + Vector3(0, h, 0), a + Vector3(0, h, 0)], out, col,
				[Vector2(0, 0.5), Vector2(w, 0.5), Vector2(w, h), Vector2(0, h)])
		# Vertical sheet joints, faint: a thin strip in the middle of each panel.
		_box(pk, kit, "shell", mid + out * 0.02 + Vector3(0, h * 0.5 + 0.25, 0), Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out), Vector3(0.06, h - 0.5, 0.04), col.darkened(0.15))
		# The pilaster at corner k.
		var cd: Vector3 = a.normalized()
		_ibeam(pk, kit, "steel", a + cd * 0.32 + Vector3(0, 0.4, 0), a + cd * 0.32 + Vector3(0, h + 0.5, 0), 0.62, 0.42, col.darkened(0.2), cd, 0.04, 0.05)
	# The galleries: a grating out to rc + 1.4 every 8.5m, railings on them; band girders under each.
	var lv := 8.5
	while lv < h + 0.1:
		for k in range(n):
			var a: Vector3 = cs[k]
			var b: Vector3 = cs[k + 1]
			var ao: Vector3 = a * ((rc + 1.4) / rc)
			var bo: Vector3 = b * ((rc + 1.4) / rc)
			var y: float = lv
			pk.quad(kit, "steel", [a + Vector3(0, y, 0), b + Vector3(0, y, 0), bo + Vector3(0, y, 0), ao + Vector3(0, y, 0)], Vector3.UP, STEEL_DARK)
			pk.quad(kit, "steel", [a + Vector3(0, y - 0.1, 0), b + Vector3(0, y - 0.1, 0), bo + Vector3(0, y - 0.1, 0), ao + Vector3(0, y - 0.1, 0)], Vector3.DOWN, STEEL_DARK.darkened(0.3))
			var o: Vector3 = ((a + b) * 0.5).normalized()
			pk.quad(kit, "steel", [ao + Vector3(0, y - 0.1, 0), bo + Vector3(0, y - 0.1, 0), bo + Vector3(0, y, 0), ao + Vector3(0, y, 0)], o, STEEL_DARK)
			# The band girder under the gallery.
			pk.quad(kit, "shell", [a + o * 0.08 + Vector3(0, y - 0.7, 0), b + o * 0.08 + Vector3(0, y - 0.7, 0), b + o * 0.08 + Vector3(0, y - 0.1, 0), a + o * 0.08 + Vector3(0, y - 0.1, 0)], o, col.darkened(0.25))
			# Railing: a post at each corner, a top and a knee rail.
			var ar: Vector3 = a * ((rc + 1.3) / rc) + Vector3(0, y, 0)
			var br2: Vector3 = b * ((rc + 1.3) / rc) + Vector3(0, y, 0)
			pk.beam(kit, "steel", ar, ar + Vector3(0, 1.1, 0), 0.06, 0.06, STEEL_DARK)
			pk.beam(kit, "steel", ar + Vector3(0, 1.1, 0), br2 + Vector3(0, 1.1, 0), 0.06, 0.06, STEEL_DARK, Vector3.UP)
			pk.beam(kit, "steel", ar + Vector3(0, 0.55, 0), br2 + Vector3(0, 0.55, 0), 0.045, 0.045, STEEL_DARK, Vector3.UP)
		lv += 8.5
	# The roof: a shallow 24-sided cone from the eaves to the lantern's ring, a railing round its edge.
	var rr := 2.8
	var ry := h + 3.6
	for k in range(n):
		var a: Vector3 = cs[k]
		var b: Vector3 = cs[k + 1]
		var ai: Vector3 = a * (rr / rc)
		var bi: Vector3 = b * (rr / rc)
		var mid: Vector3 = ((a + b) * 0.5).normalized()
		var rn: Vector3 = (mid * 3.6 + Vector3.UP * (rc - rr)).normalized()
		pk.quad(kit, "shell", [a + Vector3(0, h + 0.05, 0) + mid * 0.3, b + Vector3(0, h + 0.05, 0) + mid * 0.3, bi + Vector3(0, ry, 0), ai + Vector3(0, ry, 0)], rn, col.lightened(0.06),
				[Vector2(0, 0), Vector2(5.9, 0), Vector2(0.7, 19.0), Vector2(0, 19.0)])
		var ar2: Vector3 = a * ((rc - 0.4) / rc) + Vector3(0, h + 0.05 + 0.4 * 3.6 / (rc - rr), 0)
		var br3: Vector3 = b * ((rc - 0.4) / rc) + Vector3(0, h + 0.05 + 0.4 * 3.6 / (rc - rr), 0)
		pk.beam(kit, "steel", ar2, ar2 + Vector3(0, 1.1, 0), 0.06, 0.06, STEEL_DARK)
		pk.beam(kit, "steel", ar2 + Vector3(0, 1.1, 0), br3 + Vector3(0, 1.1, 0), 0.06, 0.06, STEEL_DARK, Vector3.UP)
		pk.beam(kit, "steel", ar2 + Vector3(0, 0.55, 0), br3 + Vector3(0, 0.55, 0), 0.045, 0.045, STEEL_DARK, Vector3.UP)
	# A walkway up the roof from the stair's head to the lantern.
	var wd: Vector3 = (cs[3] as Vector3).normalized()
	pk.beam(kit, "steel", wd * (rc - 0.5) + Vector3(0, h + 0.3, 0), wd * (rr + 0.3) + Vector3(0, ry + 0.2, 0), 0.9, 0.08, STEEL_DARK)
	# The lantern: a drum with louvres, a cone roof and a finial.
	pk.lathe(kit, "shell", Vector3(0, ry - 0.1, 0), [Vector2(rr, 0.0), Vector2(rr, 2.4)], 16, col.darkened(0.1))
	for k in range(5):
		pk.tube(kit, "steel", Vector3(0, ry + 0.45 + 0.4 * float(k), 0), Vector3(0, ry + 0.5 + 0.4 * float(k), 0), rr + 0.05, rr + 0.05, 16, Color(0.15, 0.17, 0.16), false)
	pk.lathe(kit, "shell", Vector3(0, ry + 2.3, 0), [Vector2(rr + 0.4, 0.0), Vector2(rr + 0.4, 0.15), Vector2(0.4, 1.4), Vector2(0.001, 1.5)], 16, col.lightened(0.05))
	pk.lathe(kit, "shell", Vector3(0, ry + 2.3, 0), [Vector2(0.001, 0.0), Vector2(rr + 0.4, 0.0)], 16, col.darkened(0.4), true)
	pk.tube(kit, "steel", Vector3(0, ry + 3.7, 0), Vector3(0, ry + 5.0, 0), 0.08, 0.04, 6, STEEL_DARK, true)
	# The outside stair: a straight flight across each panel, rising 2.83m, landings at the corners, round from +x.
	var sr := 24.5
	var y0 := 0.5
	var k0 := 22
	var k := 0
	while y0 < h - 0.1:
		var ka: int = (k0 + k) % n
		var kb: int = (k0 + k + 1) % n
		var pa: Vector3 = (cs[ka] as Vector3).normalized() * sr + Vector3(0, y0, 0)
		var pb: Vector3 = (cs[kb] as Vector3).normalized() * sr + Vector3(0, y0 + 2.833, 0)
		var dir: Vector3 = Vector3(pb.x - pa.x, 0, pb.z - pa.z).normalized()
		_stair(pk, kit, pa + dir * 0.7, pb - dir * 0.7, 1.0, STEEL_DARK, STEEL_DARK)
		var ld: Vector3 = (cs[kb] as Vector3).normalized()
		_box(pk, kit, "steel", ld * sr + Vector3(0, pb.y - 0.05, 0), Basis(Vector3.UP.cross(ld).normalized(), Vector3.UP, ld), Vector3(1.6, 0.1, 1.2), STEEL_DARK)
		pk.beam(kit, "steel", ld * (sr - 0.5) + Vector3(0, pb.y - 0.1, 0), ld * (rc + 0.55) + Vector3(0, pb.y - 0.4, 0), 0.12, 0.12, STEEL_DARK)
		y0 += 2.833
		k += 1
	# The door at the foot, a canopy over it.
	var dd := Vector3(1, 0, 0)
	_box(pk, kit, "paint", dd * (rc * cos(PI / float(n)) + 0.05) + Vector3(0, 2.0, 0) + Vector3(0, 0, 2.9), Basis(Vector3(0, 0, -1), Vector3.UP, dd), Vector3(2.4, 3.0, 0.1), Color(0.18, 0.2, 0.2))
	_box(pk, kit, "steel", dd * (rc * cos(PI / float(n)) + 0.8) + Vector3(0, 3.8, 0) + Vector3(0, 0, 2.9), Basis(Vector3(0, 0, -1), Vector3.UP, dd), Vector3(3.2, 0.12, 1.6), STEEL_DARK)
	# KRONBURG in letters on eight panels near the top, read from outside left to right round the holder.
	var word := "KRONBURG"
	var kc := 6
	for i in range(word.length()):
		var kk: int = kc + 3 - i
		var a2: Vector3 = cs[(kk + n) % n]
		var b2: Vector3 = cs[(kk + 1 + n) % n]
		var mid2: Vector3 = (a2 + b2) * 0.5
		_label(labels, word[i], mid2 + mid2.normalized() * 0.08 + Vector3(0, 55.2, 0), mid2.normalized(), 3.4, Color(0.92, 0.9, 0.84), 5.0)


# ======================================================================================
#  Pipes
# ======================================================================================

## A pipe bridge across the road: a box lattice truss along x from -span/2 - 5.3 to +span/2 + 5.3, its underside exactly at
## `clearance`, on lattice towers (and their footings) at |x| >= span/2 + 0.25, `n_pipes` (1-4) pipelines on its top (the
## second clad in aluminium), a walkway inside, hazard striping along its underside over the road. Past the towers the
## pipes drop to 1.6 and run on along ±x to flanges at x = ±(span/2 + 11) (z per pipe: PIPE_Z), for pipe_run to continue;
## an expansion loop over the +x tower on the biggest. Truss 4m wide (z ±2.2 with its chords), 3.4m deep.
static func pipe_bridge(pk: PropKit, kit: Dictionary, span: float, clearance: float, n_pipes := 3) -> void:
	var hs: float = span * 0.5
	var tw := 2.2
	var tx: float = hs + tw + 0.9
	var th := 3.2
	var chord := 0.3
	var cy: float = clearance + th * 0.5 + chord * 0.5 + 0.02
	var col := STEEL
	for sx in [-1.0, 1.0]:
		_tower(pk, kit, "steel", Vector3(sx * tx, 0.0, 0.0), clearance + 0.02, tw, tw * 0.8, 3.0, col, 0.35, 0.14)
		_ladder(pk, kit, Vector3(sx * (tx + tw + 0.1), 0.0, 0.0), Vector3(sx * (tx + tw * 0.8 + 0.1), clearance, 0.0), Vector3(sx, 0, 0), true)
	var xe: float = tx + tw + 0.4
	_lattice(pk, kit, "steel", Vector3(-xe, cy, 0), Vector3(xe, cy, 0), 4.0, th, 3.0, col, Vector3.UP, chord, 0.13)
	# The walkway inside on the bottom chords, the hazard striping on the bottom chord over the road.
	_blk(pk, kit, "steel", Vector3(-xe, clearance + chord + 0.02, -1.6), Vector3(xe, clearance + chord + 0.1, 1.6), STEEL_DARK)
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "hazard", Vector3(-hs, clearance + 0.03, sz * 2.0 + sz * 0.15), Vector3(hs, clearance + 0.32, sz * 2.0 + sz * 0.21), WHITE)
	# Pipes on saddles along the top.
	var top_y: float = cy + th * 0.5 + chord * 0.5
	var radii: Array = PIPE_RADII
	var zs: Array = pipe_bridge_z(n_pipes)
	var cols: Array = [Color(0.40, 0.34, 0.28), Color(0.78, 0.79, 0.8), Color(0.62, 0.55, 0.15), Color(0.28, 0.4, 0.55)]
	for i in range(clampi(n_pipes, 1, 4)):
		var r: float = radii[i]
		var z: float = zs[i]
		var py: float = top_y + 0.2 + r
		var key: String = "metal" if i == 1 else "rusty"
		var xd: float = xe + 1.0 + float(i) * 0.3
		var pts: Array = [Vector3(-hs - 11.0, 1.6, z), Vector3(-xd, 1.6, z), Vector3(-xd, py, z)]
		if i == 0:
			pts.append_array([Vector3(tx - 1.6, py, z), Vector3(tx - 1.6, py + 3.2, z), Vector3(tx + 1.6, py + 3.2, z), Vector3(tx + 1.6, py, z)])
		pts.append_array([Vector3(xd, py, z), Vector3(xd, 1.6, z), Vector3(hs + 11.0, 1.6, z)])
		_pipe(pk, kit, key, pts, r, cols[i], 12, 6.0, true)
		if i == 1:
			var x := -xd
			while x < xd:
				pk.tube(kit, "metal", Vector3(x, py, z), Vector3(x + 0.05, py, z), r + 0.02, r + 0.02, 12, cols[i].darkened(0.2), false)
				x += 1.2
		var x2: float = -xe + 1.0
		while x2 < xe:
			_blk(pk, kit, "steel", Vector3(x2 - 0.12, top_y - 0.02, z - r * 0.7), Vector3(x2 + 0.12, py - r * 0.6, z + r * 0.7), STEEL_DARK)
			x2 += 3.0
		for sx2 in [-1.0, 1.0]:
			_blk(pk, kit, "concrete", Vector3(sx2 * (hs + 8.0) - 0.4, -3.0, z - r - 0.2), Vector3(sx2 * (hs + 8.0) + 0.4, 1.6 - r, z + r + 0.2), CONCRETE)
			# The drop's bracket to the tower.
			pk.beam(kit, "steel", Vector3(sx2 * xd, clearance * 0.6, z), Vector3(sx2 * (tx + tw * 0.85), clearance * 0.6, z * 0.5), 0.14, 0.14, STEEL)


const PIPE_RADII := [0.75, 0.5, 0.42, 0.32]

## Where pipe_bridge lays its pipes across the truss (z), the biggest first: side by side, 22cm apart, centred.
static func pipe_bridge_z(n_pipes: int) -> Array:
	var n: int = clampi(n_pipes, 1, 4)
	var total: float = 0.22 * float(n - 1)
	for i in range(n):
		total += 2.0 * float(PIPE_RADII[i])
	var out: Array = []
	var z: float = -total * 0.5
	for i in range(n):
		out.append(z + float(PIPE_RADII[i]))
		z += 2.0 * float(PIPE_RADII[i]) + 0.22
	return out


## Pipes on ground supports along `points` (pipe centres; y the height over the ground at y 0): elbows at the bends,
## flanges every 9m, a support every ~6m (one post with a saddle, or a frame of two under a big pipe) on a concrete footing.
## Vertical legs get no supports.
static func pipe_run(pk: PropKit, kit: Dictionary, points: PackedVector3Array, r: float) -> void:
	var pts: Array = Array(points)
	if pts.size() < 2:
		return
	var col := Color(0.45, 0.40, 0.34)
	_pipe(pk, kit, "rusty", pts, r, col, 12 if r < 0.8 else 16, 9.0, true)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var hd := Vector3(b.x - a.x, 0, b.z - a.z)
		var hl: float = hd.length()
		if hl < 1.5 or absf(b.y - a.y) > hl * 0.6:
			continue
		var along: Vector3 = hd / hl
		var across := Vector3(-along.z, 0, along.x)
		var ns: int = maxi(int(floor(hl / 6.0)), 1)
		for k in range(ns):
			var t: float = (float(k) + 0.5) / float(ns)
			var p: Vector3 = a.lerp(b, t)
			var top: float = p.y - r - 0.04
			if top < 0.3:
				continue
			_blk(pk, kit, "concrete", Vector3(p.x - 0.5, -3.0, p.z - 0.5) - across * (r * 0.6 if r > 0.6 else 0.0), Vector3(p.x + 0.5, 0.25, p.z + 0.5) + across * (r * 0.6 if r > 0.6 else 0.0), CONCRETE)
			if r > 0.6:
				for sd in [-1.0, 1.0]:
					var f: Vector3 = Vector3(p.x, 0.0, p.z) + across * (sd * r * 0.8)
					pk.beam(kit, "steel", f + Vector3(0, 0.2, 0), f + Vector3(0, top, 0), 0.22, 0.22, STEEL, along)
				pk.beam(kit, "steel", Vector3(p.x, top - 0.12, p.z) - across * (r + 0.2), Vector3(p.x, top - 0.12, p.z) + across * (r + 0.2), 0.25, 0.25, STEEL, along)
			else:
				pk.beam(kit, "steel", Vector3(p.x, 0.2, p.z), Vector3(p.x, top - 0.1, p.z), 0.18, 0.18, STEEL, along)
				pk.beam(kit, "steel", Vector3(p.x, top - 0.08, p.z) - across * (r + 0.1), Vector3(p.x, top - 0.08, p.z) + across * (r + 0.1), 0.16, 0.16, STEEL, along)
			pk.beam(kit, "steel", Vector3(p.x, top, p.z) - across * (r * 0.75), Vector3(p.x, top + r * 0.35, p.z) - across * (r * 0.9), 0.1, 0.18, STEEL_DARK, along)
			pk.beam(kit, "steel", Vector3(p.x, top, p.z) + across * (r * 0.75), Vector3(p.x, top + r * 0.35, p.z) + across * (r * 0.9), 0.1, 0.18, STEEL_DARK, along)


# ======================================================================================
#  Zeche Kronprinz: the headframe and the winding engine house
# ======================================================================================

## An arched window in a wall built by _wall_holes with the hole Rect2(u0, v0, w, hr + w / 2): the spandrels over the arch
## on both faces, the arch's soffit through the wall, a ring of dark voussoirs, the glazing and a sill.
static func _arched_window(pk: PropKit, kit: Dictionary, p0: Vector3, along: Vector3, out: Vector3, u0: float, v0: float, w: float, hr: float, thick: float, col: Color) -> void:
	var r: float = w * 0.5
	var uc: float = u0 + r
	var vs: float = v0 + hr
	var segs := 10
	var arc: Array = []
	for k in range(segs + 1):
		var a: float = PI - PI * float(k) / float(segs)
		arc.append(Vector2(uc + cos(a) * r, vs + sin(a) * r))
	var pt := func(q: Vector2, d: float) -> Vector3:
		return p0 + along * q.x + Vector3.UP * q.y - out * d
	for face in [0, 1]:
		var d: float = 0.0 if face == 0 else thick
		var n: Vector3 = out if face == 0 else -out
		var c: Color = col if face == 0 else col.darkened(0.12)
		for k in range(segs):
			var corner := Vector2(u0, vs + r) if k * 2 < segs else Vector2(u0 + w, vs + r)
			var a0: Vector2 = arc[k]
			var a1: Vector2 = arc[k + 1]
			pk.tri(kit, "brick", pt.call(corner, d), pt.call(a0, d), pt.call(a1, d), n, n, n, c, n, corner * uvk, a0 * uvk, a1 * uvk)
	for k in range(segs):
		var a0: Vector2 = arc[k]
		var a1: Vector2 = arc[k + 1]
		var am: Vector2 = (a0 + a1) * 0.5 - Vector2(uc, vs)
		var inward: Vector3 = -(along * am.x + Vector3.UP * am.y).normalized()
		pk.quad(kit, "brick", [pt.call(a0, 0.0), pt.call(a1, 0.0), pt.call(a1, thick), pt.call(a0, thick)], inward, col.darkened(0.15))
		# Voussoirs: a band of dark brick round the arch, 4cm proud.
		var o0 := Vector2(uc, vs) + (a0 - Vector2(uc, vs)) * ((r + 0.45) / r)
		var o1 := Vector2(uc, vs) + (a1 - Vector2(uc, vs)) * ((r + 0.45) / r)
		pk.quad(kit, "brick", [pt.call(a0, -0.04), pt.call(a1, -0.04), pt.call(o1, -0.04), pt.call(o0, -0.04)], out, BRICK_DARK,
				[a0 * uvk, a1 * uvk, o1 * uvk, o0 * uvk])
		pk.quad(kit, "brick", [pt.call(o0, -0.04), pt.call(o1, -0.04), pt.call(o1, 0.0), pt.call(o0, 0.0)], (along * (o0 + o1 - Vector2(uc, vs) * 2.0).x + Vector3.UP * (o0 + o1 - Vector2(uc, vs) * 2.0).y).normalized(), BRICK_DARK)
	var gc: Vector3 = p0 + along * uc + Vector3.UP * (v0 + (hr + r) * 0.5) - out * 0.16
	_glazing(pk, kit, gc, along, Vector3.UP, out, w, hr + r)
	_box(pk, kit, "steel", p0 + along * uc + Vector3.UP * (vs) - out * 0.12, Basis(along, Vector3.UP, out), Vector3(w, 0.08, 0.06), STEEL)
	_box(pk, kit, "steel", p0 + along * uc + Vector3.UP * (v0 + hr * 0.5) - out * 0.12, Basis(along, Vector3.UP, out), Vector3(0.08, hr, 0.06), STEEL)
	_box(pk, kit, "stone", p0 + along * uc + Vector3.UP * (v0 - 0.08) + out * 0.15, Basis(along, Vector3.UP, out), Vector3(w + 0.3, 0.16, 0.3), Color(0.68, 0.6, 0.48))


## The headframe of Zeche Kronprinz over the shaft at the origin: a braced guide frame (legs at ±2.6) up to the sheave deck
## at 44, two spoked sheaves 7m across side by side (x ±1.9, hubs at 48), two raking lattice struts down toward +z to
## feet at z 27, the brick shaft hall round the frame's foot (x, z ±8, 12.5 to its ridge), the winding engine house (x ±9, z
## 44..66, ridge 22.5, tall arched windows, the ropes into its gable) behind them; ZECHE KRONPRINZ on the engine house.
## Footprint x -10..10, z -9..67; 52m to the sheaves' tops.
static func headframe(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var col := Color(0.42, 0.20, 0.13)
	var deck := 44.0
	_tower(pk, kit, "steel", Vector3.ZERO, deck - 0.12, 2.6, 2.6, 4.0, col, 0.5, 0.18)
	# The sheave deck and its railing.
	_blk(pk, kit, "steel", Vector3(-4.6, deck - 0.4, -3.4), Vector3(4.6, deck, 4.6), col.darkened(0.2))
	_railing(pk, kit, [Vector3(-4.5, deck, -3.3), Vector3(4.5, deck, -3.3), Vector3(4.5, deck, 4.5), Vector3(-4.5, deck, 4.5), Vector3(-4.5, deck, -3.3)], 1.1, Color(0.3, 0.3, 0.3), "steel")
	# The sheaves on trestles.
	var hub_y := 48.0
	var hz := 0.6
	var wb := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
	for sx in [-1.9, 1.9]:
		var c := Vector3(sx, hub_y, hz)
		_sheave(pk, kit, c, 3.5, wb)
		for bx in [-0.55, 0.55]:
			for bz in [-1.2, 1.2]:
				pk.beam(kit, "steel", Vector3(sx + bx, deck, hz + bz), Vector3(sx + bx, hub_y - 0.3, hz), 0.3, 0.3, col)
			_blk(pk, kit, "steel", Vector3(sx + bx - 0.2, hub_y - 0.45, hz - 0.35), Vector3(sx + bx + 0.2, hub_y + 0.3, hz + 0.35), STEEL_DARK)
		# The ropes: down the shaft on the -z side, off the top toward the engine house.
		pk.beam(kit, "steel", Vector3(sx, hub_y, hz - 3.42), Vector3(sx, 11.0, hz - 3.42), 0.06, 0.06, Color(0.15, 0.15, 0.15))
		pk.beam(kit, "steel", Vector3(sx, hub_y + 3.42, hz), Vector3(sx, 14.6, 44.0), 0.06, 0.06, Color(0.15, 0.15, 0.15))
	# The struts: two raking lattice girders from the head down to their feet, tied together.
	var top_l := Vector3(-3.7, deck - 0.3, 2.6)
	var top_r := Vector3(3.7, deck - 0.3, 2.6)
	var foot_l := Vector3(-6.2, 0.4, 27.0)
	var foot_r := Vector3(6.2, 0.4, 27.0)
	_lattice(pk, kit, "steel", foot_l, top_l, 1.5, 2.2, 2.4, col, Vector3.UP, 0.3, 0.13)
	_lattice(pk, kit, "steel", foot_r, top_r, 1.5, 2.2, 2.4, col, Vector3.UP, 0.3, 0.13)
	for f in [foot_l, foot_r]:
		_blk(pk, kit, "concrete", f + Vector3(-1.6, -3.4, -1.8), f + Vector3(1.6, 0.0, 1.8), CONCRETE)
	for t in [0.25, 0.45, 0.65, 0.85]:
		var pl: Vector3 = foot_l.lerp(top_l, t)
		var pr: Vector3 = foot_r.lerp(top_r, t)
		pk.beam(kit, "steel", pl, pr, 0.35, 0.35, col)
		if t < 0.8:
			var ql: Vector3 = foot_l.lerp(top_l, t + 0.2)
			var qr: Vector3 = foot_r.lerp(top_r, t + 0.2)
			pk.beam(kit, "steel", pl, qr, 0.16, 0.16, col)
			pk.beam(kit, "steel", pr, ql, 0.16, 0.16, col)
	# The shaft hall: brick, tall windows, a gable roof along x the frame rises through.
	_shaft_hall(pk, kit, labels)
	_engine_house(pk, kit, labels)


## A spoked sheave wheel of radius r centred at c, its axle along `wb.y`: a grooved rim, a hub, 16 spokes in two planes.
static func _sheave(pk: PropKit, kit: Dictionary, c: Vector3, r: float, wb: Basis) -> void:
	var col := Color(0.30, 0.31, 0.32)
	pk.lathe(kit, "steel", c, [Vector2(r - 0.28, -0.24), Vector2(r + 0.06, -0.24), Vector2(r + 0.06, -0.15), Vector2(r - 0.06, -0.03), Vector2(r - 0.06, 0.03),
			Vector2(r + 0.06, 0.15), Vector2(r + 0.06, 0.24), Vector2(r - 0.28, 0.24), Vector2(r - 0.28, -0.24)], 40, col, false, wb)
	var ax: Vector3 = wb.y
	pk.tube(kit, "steel", c - ax * 0.5, c + ax * 0.5, 0.5, 0.5, 14, col.darkened(0.2), true)
	pk.tube(kit, "steel", c - ax * 0.9, c + ax * 0.9, 0.2, 0.2, 10, STEEL_DARK, true)
	var e1: Vector3 = wb.x
	var e2: Vector3 = wb.z
	for k in range(16):
		var a: float = TAU * float(k) / 16.0
		var d: Vector3 = e1 * cos(a) + e2 * sin(a)
		var side: float = 0.2 if k % 2 == 0 else -0.2
		pk.beam(kit, "steel", c + d * 0.45 + ax * (side * 1.6), c + d * (r - 0.27) + ax * (side * 0.4), 0.12, 0.08, col, ax)


static func _shaft_hall(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hx := 8.0
	var eh := 9.0
	var ridge := 12.5
	_blk(pk, kit, "concrete", Vector3(-hx - 0.3, -3.0, -hx - 0.3), Vector3(hx + 0.3, PLINTH, hx + 0.3), CONCRETE)
	var walls: Array = [[Vector3(-hx, 0, hx), Vector3(1, 0, 0), Vector3(0, 0, 1)], [Vector3(hx, 0, -hx), Vector3(-1, 0, 0), Vector3(0, 0, -1)],
			[Vector3(-hx, 0, -hx), Vector3(0, 0, 1), Vector3(-1, 0, 0)], [Vector3(hx, 0, hx), Vector3(0, 0, -1), Vector3(1, 0, 0)]]
	for wi in range(4):
		var w: Array = walls[wi]
		var holes: Array = [[Rect2(3.0, 2.4, 2.2, 4.6), true], [Rect2(10.8, 2.4, 2.2, 4.6), true]]
		if wi == 1:
			holes = [[Rect2(5.5, PLINTH, 5.0, 4.4), true]]
		_wall_holes(pk, kit, "brick", w[0], w[1], w[2], 0.0, hx * 2.0, PLINTH, eh, holes, BRICK, 0.45)
		for hh in holes:
			var r: Rect2 = hh[0]
			var c: Vector3 = (w[0] as Vector3) + (w[1] as Vector3) * (r.position.x + r.size.x * 0.5) + Vector3.UP * (r.position.y + r.size.y * 0.5) - (w[2] as Vector3) * 0.16
			if wi == 1:
				_box(pk, kit, "paint", c + (w[2] as Vector3) * 0.0, Basis(w[1], Vector3.UP, w[2]), Vector3(r.size.x, r.size.y, 0.08), Color(0.24, 0.32, 0.3))
			else:
				_glazing(pk, kit, c, w[1], Vector3.UP, w[2], r.size.x - 0.2, r.size.y - 0.2)
				_window_frame(pk, kit, c, w[1], w[2], r.size.x - 0.2, r.size.y - 0.2, STEEL, 1, 1)
	# Gables on ±x, the roof along x.
	for sx in [-1.0, 1.0]:
		var poly := PackedVector2Array([Vector2(-hx, eh), Vector2(hx, eh), Vector2(0, ridge - 0.07)])
		_wall_poly(pk, kit, "brick", Vector3(sx * hx, 0, 0), Vector3(0, 0, -sx), Vector3(sx, 0, 0), poly, BRICK, 0.45)
	var sl: float = (ridge - eh) / hx
	for sz in [-1.0, 1.0]:
		_roof(pk, kit, "roofing", Vector3(-hx - 0.5, eh - 0.5 * sl, sz * (hx + 0.5)), Vector3(hx + 0.5, eh - 0.5 * sl, sz * (hx + 0.5)), Vector3(hx + 0.5, ridge, 0), Vector3(-hx - 0.5, ridge, 0),
				Color(0.30, 0.31, 0.34), Vector3(0, 1.0, sz * sl).normalized())
	pk.beam(kit, "steel", Vector3(-hx - 0.6, ridge + 0.05, 0), Vector3(hx + 0.6, ridge + 0.05, 0), 0.35, 0.12, Color(0.2, 0.2, 0.22))
	_label(labels, "SCHACHT 2", Vector3(0, eh - 1.0, hx + 0.03), Vector3(0, 0, 1), 0.7, CREAM, 8.0)


static func _engine_house(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hx := 9.0
	var z0 := 44.0
	var z1 := 66.0
	var eh := 16.0
	var ridge := 22.5
	_blk(pk, kit, "concrete", Vector3(-hx - 0.3, -3.0, z0 - 0.3), Vector3(hx + 0.3, PLINTH, z1 + 0.3), CONCRETE)
	var hl: float = z1 - z0
	# The long sides: four tall arched windows each between pilasters.
	for sx in [-1.0, 1.0]:
		var p0 := Vector3(sx * hx, 0, z0 if sx > 0.0 else z1)
		var along := Vector3(0, 0, 1.0 if sx > 0.0 else -1.0)
		var out := Vector3(sx, 0, 0)
		var holes: Array = []
		for k in range(4):
			holes.append([Rect2(2.5 + float(k) * 5.0, 3.0, 2.6, 8.2 + 1.3), true])
		_wall_holes(pk, kit, "brick", p0, along, out, 0.0, hl, PLINTH, eh, holes, BRICK, 0.6)
		for hh in holes:
			var r: Rect2 = hh[0]
			_arched_window(pk, kit, p0, along, out, r.position.x, r.position.y, r.size.x, 8.2, 0.6, BRICK)
		for k in range(5):
			var pu: float = clampf(1.2 + float(k) * 5.0 - 0.35, 0.0, hl - 0.7)
			_blk(pk, kit, "brick", p0 + along * pu + Vector3(0, PLINTH, 0) - out * 0.02, p0 + along * (pu + 0.7) + Vector3(0, eh - 0.4, 0) + out * 0.12, BRICK_DARK)
		_blk(pk, kit, "brick", p0 + Vector3(0, eh - 0.9, 0) - out * 0.02 + along * -0.1, p0 + along * (hl + 0.1) + Vector3(0, eh - 0.3, 0) + out * 0.2, BRICK_DARK)
	_label(labels, "ZECHE KRONPRINZ", Vector3(hx + 0.22, 13.6, (z0 + z1) * 0.5), Vector3(1, 0, 0), 1.15, Color(0.9, 0.86, 0.74), 18.0)
	_label(labels, "ZECHE KRONPRINZ", Vector3(-hx - 0.22, 13.6, (z0 + z1) * 0.5), Vector3(-1, 0, 0), 1.15, Color(0.9, 0.86, 0.74), 18.0)
	# The gables: toward the headframe (-z) the rope openings and a door; away (+z) a great arched window and the year.
	for e in [[z0, -1.0], [z1, 1.0]]:
		var zf: float = e[0]
		var sz: float = e[1]
		var p0 := Vector3(-hx * sz, 0, zf)
		var along := Vector3(sz, 0, 0)
		var out := Vector3(0, 0, sz)
		var holes: Array = []
		if sz < 0.0:
			holes = [[Rect2(hx - 1.9 - 0.6, 13.8, 1.2, 1.6), true], [Rect2(hx + 1.9 - 0.6, 13.8, 1.2, 1.6), true], [Rect2(hx - 2.0, PLINTH, 4.0, 4.6), true]]
		else:
			holes = [[Rect2(hx - 2.0, 3.0, 4.0, 9.0 + 2.0), true]]
		_wall_holes(pk, kit, "brick", p0, along, out, 0.0, hx * 2.0, PLINTH, eh, holes, BRICK, 0.6)
		var poly := PackedVector2Array([Vector2(0, eh), Vector2(hx * 2.0, eh), Vector2(hx, ridge - 0.08)])
		_wall_poly(pk, kit, "brick", p0, along, out, poly, BRICK, 0.6)
		if sz < 0.0:
			for k in range(2):
				var r: Rect2 = holes[k][0]
				_blk(pk, kit, "matte", p0 + along * r.position.x + Vector3(0, r.position.y, 0) - out * 0.55, p0 + along * r.end.x + Vector3(0, r.end.y, 0) - out * 0.5, Color(0.02, 0.02, 0.02))
			var dr: Rect2 = holes[2][0]
			_box(pk, kit, "paint", p0 + along * (dr.position.x + dr.size.x * 0.5) + Vector3(0, dr.position.y + dr.size.y * 0.5, 0) - out * 0.3, Basis(along, Vector3.UP, out), Vector3(dr.size.x, dr.size.y, 0.08), Color(0.24, 0.32, 0.3))
		else:
			_arched_window(pk, kit, p0, along, out, hx - 2.0, 3.0, 4.0, 9.0, 0.6, BRICK)
			_blk(pk, kit, "stone", p0 + along * (hx - 1.0) + Vector3(0, 17.6, 0), p0 + along * (hx + 1.0) + Vector3(0, 18.5, 0) + out * 0.06, Color(0.72, 0.62, 0.46))
			_label(labels, "1898", p0 + along * hx + Vector3(0, 18.05, 0) + out * 0.08, out, 0.55, Color(0.25, 0.18, 0.12), 1.8)
	# The slate roof with its eaves, ridge and a ventilator.
	var sl: float = (ridge - eh) / hx
	for sx in [-1.0, 1.0]:
		_roof(pk, kit, "roofing", Vector3(sx * (hx + 0.6), eh - 0.6 * sl, z1 + 0.5), Vector3(sx * (hx + 0.6), eh - 0.6 * sl, z0 - 0.5), Vector3(0, ridge, z0 - 0.5), Vector3(0, ridge, z1 + 0.5),
				Color(0.28, 0.29, 0.33), Vector3(sx * sl, 1.0, 0).normalized())
		pk.tube(kit, "steel", Vector3(sx * (hx + 0.7), eh - 0.7 * sl, z0 - 0.5), Vector3(sx * (hx + 0.7), eh - 0.7 * sl, z1 + 0.5), 0.13, 0.13, 8, STEEL_DARK, true)
	pk.beam(kit, "steel", Vector3(0, ridge + 0.05, z0 - 0.6), Vector3(0, ridge + 0.05, z1 + 0.6), 0.35, 0.12, Color(0.2, 0.2, 0.22))
	_blk(pk, kit, "roofing", Vector3(-1.4, ridge - 0.3, 52.0), Vector3(1.4, ridge + 1.6, 58.0), Color(0.28, 0.29, 0.33))
	_roof(pk, kit, "roofing", Vector3(-1.9, ridge + 1.6, 58.4), Vector3(-1.9, ridge + 1.6, 51.6), Vector3(0, ridge + 2.4, 51.6), Vector3(0, ridge + 2.4, 58.4), Color(0.28, 0.29, 0.33), Vector3(-0.8, 1.9, 0).normalized())
	_roof(pk, kit, "roofing", Vector3(1.9, ridge + 1.6, 51.6), Vector3(1.9, ridge + 1.6, 58.4), Vector3(0, ridge + 2.4, 58.4), Vector3(0, ridge + 2.4, 51.6), Color(0.28, 0.29, 0.33), Vector3(0.8, 1.9, 0).normalized())


# ======================================================================================
#  The torpedo ladle car
# ======================================================================================

## A torpedo ladle car along z on standard gauge (1.435m, rail tops at y 0, rails at x ±0.7175): two groups of two
## two-axle trucks under span bolsters, pedestals carrying the trunnions of the cigar-shaped, refractory-lined vessel (axis
## 3.4m up, 3.9m across, 22m long), its mouth on top glowing a dull red; couplers at z ±12.6. About 25.2 x 3.9 x 5.7m.
static func torpedo_car(pk: PropKit, kit: Dictionary) -> void:
	var g := 0.7175
	var wr := 0.46
	var frame := Color(0.18, 0.18, 0.19)
	for gz in [-9.0, 9.0]:
		for tz in [-2.0, 2.0]:
			var zc: float = gz + tz
			for az in [-0.9, 0.9]:
				var z: float = zc + az
				for sx in [-1.0, 1.0]:
					pk.tube(kit, "steel", Vector3(sx * (g - 0.07), wr, z), Vector3(sx * (g + 0.07), wr, z), wr, wr, 14, Color(0.25, 0.24, 0.23), true)
					pk.tube(kit, "steel", Vector3(sx * (g - 0.1), wr, z), Vector3(sx * (g - 0.07), wr, z), wr + 0.035, wr + 0.035, 14, Color(0.25, 0.24, 0.23), true)
				pk.tube(kit, "steel", Vector3(-g + 0.1, wr, z), Vector3(g - 0.1, wr, z), 0.09, 0.09, 8, STEEL_DARK, false)
			for sx in [-1.0, 1.0]:
				_blk(pk, kit, "steel", Vector3(sx * (g + 0.12), 0.25, zc - 1.55), Vector3(sx * (g + 0.4), 0.82, zc + 1.55), frame)
				pk.tube(kit, "steel", Vector3(sx * (g + 0.4), 0.3, zc - 0.3), Vector3(sx * (g + 0.4), 0.75, zc - 0.3), 0.12, 0.12, 8, Color(0.5, 0.48, 0.2), false)
			_blk(pk, kit, "steel", Vector3(-g - 0.4, 0.82, zc - 0.5), Vector3(g + 0.4, 1.02, zc + 0.5), frame)
		_blk(pk, kit, "steel", Vector3(-1.35, 1.02, gz - 3.2), Vector3(1.35, 1.45, gz + 3.2), frame)
		var pz: float = 10.3 * signf(gz)
		_blk(pk, kit, "steel", Vector3(-1.0, 1.45, pz - 0.7), Vector3(1.0, 2.95, pz + 0.7), frame.lightened(0.05))
		_blk(pk, kit, "steel", Vector3(-1.15, 2.95, pz - 0.85), Vector3(1.15, 3.4, pz + 0.85), STEEL_DARK)
		# Coupler and buffer beam at the end.
		var ez: float = 12.2 * signf(gz)
		_blk(pk, kit, "steel", Vector3(-1.4, 0.75, ez - 0.25), Vector3(1.4, 1.35, ez + 0.25), frame)
		_blk(pk, kit, "steel", Vector3(-0.18, 0.85, ez), Vector3(0.18, 1.2, ez + signf(gz) * 0.42), STEEL_DARK)
		_blk(pk, kit, "hazard", Vector3(-1.4, 0.75, ez + signf(gz) * 0.25), Vector3(1.4, 1.35, ez + signf(gz) * 0.26), WHITE)
	# The vessel: a cigar about a z axis 3.4m up.
	var vb := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
	var vc := Vector3(0, 3.4, 0)
	var shell := Color(0.30, 0.27, 0.25)
	pk.lathe(kit, "rusty", vc, [Vector2(0.001, -11.0), Vector2(0.45, -11.0), Vector2(0.45, -9.9), Vector2(1.0, -9.6), Vector2(1.85, -5.4), Vector2(1.95, -4.6),
			Vector2(1.95, 4.6), Vector2(1.85, 5.4), Vector2(1.0, 9.6), Vector2(0.45, 9.9), Vector2(0.45, 11.0), Vector2(0.001, 11.0)], 24, shell, false, vb)
	for z in [-4.2, -2.1, 2.1, 4.2]:
		pk.tube(kit, "steel", vc + Vector3(0, 0, z - 0.08), vc + Vector3(0, 0, z + 0.08), 1.99, 1.99, 24, shell.darkened(0.25), false)
	# The mouth: a raised neck on top, a crust of slag round it, the dull glow inside.
	_blk(pk, kit, "rusty", vc + Vector3(-0.95, 1.6, -1.35), vc + Vector3(0.95, 2.25, 1.35), shell.darkened(0.1))
	_blk(pk, kit, "matte", vc + Vector3(-1.02, 2.2, -1.42), vc + Vector3(1.02, 2.32, 1.42), Color(0.22, 0.2, 0.19))
	_blk(pk, kit, "hot", vc + Vector3(-0.7, 2.24, -1.05), vc + Vector3(0.7, 2.335, 1.05), hot_colour(0.3))
	# A brake platform with a hand wheel and a ladder at the -z end.
	_blk(pk, kit, "steel", Vector3(-1.3, 1.45, -12.2), Vector3(1.3, 1.53, -11.2), STEEL_DARK)
	pk.tube(kit, "steel", Vector3(0.9, 1.53, -11.8), Vector3(0.9, 2.5, -11.8), 0.04, 0.04, 6, STEEL_DARK, true)
	pk.tube(kit, "steel", Vector3(0.9, 2.5, -11.85), Vector3(0.9, 2.5, -11.75), 0.3, 0.3, 10, Color(0.6, 0.12, 0.1), true)
	_railing(pk, kit, [Vector3(-1.25, 1.53, -12.15), Vector3(1.25, 1.53, -12.15)], 1.0, CRANE_YELLOW)


# ======================================================================================
#  The works gate
# ======================================================================================

## Werkstor 1: the road runs along z through it, centred on x = 0. A lattice sign gantry across the road (posts at x
## ±9.4, its underside at 11.3, the name boards on both faces), the gatehouse (Pförtnerhaus) beside the road at x
## 11..17.5, z -4.5..4.5 with its window and canopy toward the road, raised barrier arms at x ±9, brick walls with
## iron railings running off either side, lamps. Nothing within |x| < 8.2 (8m clear each side of the middle, 11.3
## clear height under the gantry).
static func works_gate(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var px := 9.4
	var by := 11.3
	var gcol := Color(0.20, 0.27, 0.33)
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "concrete", Vector3(sx * px - 0.9, -3.0, -0.9), Vector3(sx * px + 0.9, 0.3, 0.9), CONCRETE)
		_blk(pk, kit, "hazard", Vector3(sx * px - 0.48, 0.3, -0.48), Vector3(sx * px + 0.48, 2.4, 0.48), WHITE)
		_blk(pk, kit, "paint", Vector3(sx * px - 0.45, 2.4, -0.45), Vector3(sx * px + 0.45, by + 2.75, 0.45), gcol)
	var cy: float = by + 1.32
	_lattice(pk, kit, "paint", Vector3(-px - 0.6, cy, 0), Vector3(px + 0.6, cy, 0), 1.2, 2.4, 2.4, gcol, Vector3.UP, 0.24, 0.1)
	for sz in [-1.0, 1.0]:
		var bz: float = sz * 0.78
		_blk(pk, kit, "paint", Vector3(-8.2, by + 0.3, bz - 0.04), Vector3(8.2, by + 2.3, bz + 0.04), ENAMEL_GREEN)
		_blk(pk, kit, "paint", Vector3(-8.3, by + 0.22, bz - 0.02 * sz), Vector3(8.3, by + 2.38, bz - 0.06 * sz), CREAM)
		_label(labels, "KRONBURGER HÜTTE", Vector3(0, by + 1.55, bz + sz * 0.05), Vector3(0, 0, sz), 0.82, CREAM, 15.4)
		_label(labels, "WERKSTOR 1", Vector3(0, by + 0.52, bz + sz * 0.05), Vector3(0, 0, sz), 0.32, Color(0.98, 0.8, 0.2), 6.0)
	# The gatehouse.
	var x0 := 11.0
	var x1 := 17.5
	var z0 := -4.5
	var z1 := 4.5
	var wh := 3.6
	_blk(pk, kit, "concrete", Vector3(x0 - 0.2, -3.0, z0 - 0.2), Vector3(x1 + 0.2, 0.45, z1 + 0.2), CONCRETE)
	var walls: Array = [[Vector3(x0, 0, z1), Vector3(0, 0, -1), Vector3(-1, 0, 0), [[Rect2(1.2, 1.1, 6.6, 1.7), true]]],
			[Vector3(x1, 0, z0), Vector3(0, 0, 1), Vector3(1, 0, 0), [[Rect2(3.5, 1.2, 2.0, 1.4), true]]],
			[Vector3(x0, 0, z0), Vector3(1, 0, 0), Vector3(0, 0, -1), [[Rect2(1.0, 1.2, 1.6, 1.4), true]]],
			[Vector3(x1, 0, z1), Vector3(-1, 0, 0), Vector3(0, 0, 1), [[Rect2(1.0, 0.45, 1.2, 2.2), true], [Rect2(3.6, 1.2, 1.6, 1.4), true]]]]
	for w in walls:
		var p0: Vector3 = w[0]
		var along: Vector3 = w[1]
		var out: Vector3 = w[2]
		var wl: float = (z1 - z0) if absf(along.z) > 0.5 else (x1 - x0)
		_wall_holes(pk, kit, "brick", p0, along, out, 0.0, wl, 0.45, wh, w[3], BRICK, 0.3)
		for hh in w[3]:
			var r: Rect2 = hh[0]
			var c: Vector3 = p0 + along * (r.position.x + r.size.x * 0.5) + Vector3.UP * (r.position.y + r.size.y * 0.5) - out * 0.12
			if r.size.y > 2.0:
				_box(pk, kit, "paint", c, Basis(along, Vector3.UP, out), Vector3(r.size.x, r.size.y, 0.06), Color(0.24, 0.32, 0.3))
			else:
				_glazing(pk, kit, c, along, Vector3.UP, out, r.size.x - 0.2, r.size.y - 0.2)
				_window_frame(pk, kit, c, along, out, r.size.x - 0.2, r.size.y - 0.2, CREAM, 2 if r.size.x > 3.0 else 0, 0)
				_blk(pk, kit, "concrete", c - Vector3.UP * (r.size.y * 0.5 + 0.08) - along * (r.size.x * 0.5 + 0.1) + out * 0.12, c - Vector3.UP * (r.size.y * 0.5) + along * (r.size.x * 0.5 + 0.1) + out * 0.3, CONCRETE.lightened(0.1))
	# The flat roof, overhanging toward the road as a canopy over the window, its fascia.
	_blk(pk, kit, "concrete", Vector3(9.9, wh, z0 - 0.5), Vector3(x1 + 0.5, wh + 0.32, z1 + 0.5), Color(0.82, 0.8, 0.75))
	_blk(pk, kit, "paint", Vector3(9.85, wh + 0.32, z0 - 0.55), Vector3(x1 + 0.55, wh + 0.5, z1 + 0.55), Color(0.65, 0.18, 0.12))
	_label(labels, "PFORTE", Vector3(9.83, wh + 0.16, 0.0), Vector3(-1, 0, 0), 0.24, CREAM, 3.0)
	_label(labels, "ANMELDUNG", Vector3(x0 - 0.03, 3.1, 0.0), Vector3(-1, 0, 0), 0.2, CREAM, 3.0)
	# A counter shelf under the window, a "show your pass" board on a post by the lane.
	_blk(pk, kit, "steel", Vector3(x0 - 0.45, 1.0, z1 - 7.8), Vector3(x0, 1.06, z1 - 1.2), Color(0.6, 0.6, 0.6))
	_post_sign(pk, kit, labels, Vector3(9.0, 0.0, 9.0), Vector3(0, 0, 1), "WERKSAUSWEIS VORZEIGEN", WHITE, BLACK, false, false)
	# The barriers: posts at x ±8.7, arms raised (80 degrees), red and white.
	for e in [[1.0, -3.0], [-1.0, 3.0]]:
		var sx: float = e[0]
		var bz: float = e[1]
		var pv := Vector3(sx * 9.0, 1.05, bz)
		_blk(pk, kit, "paint", Vector3(sx * 9.0 - 0.3, 0.0, bz - 0.25), Vector3(sx * 9.0 + 0.3, 1.0, bz + 0.25), Color(0.85, 0.85, 0.82))
		_blk(pk, kit, "concrete", Vector3(sx * 9.0 - 0.5, -0.5, bz - 0.45), Vector3(sx * 9.0 + 0.5, 0.05, bz + 0.45), CONCRETE)
		var ang: float = deg_to_rad(84.0)
		var dirv := Vector3(-sx * cos(ang), sin(ang), 0)
		for k in range(6):
			var a: Vector3 = pv + dirv * (0.3 + 1.05 * float(k))
			var b: Vector3 = pv + dirv * (0.3 + 1.05 * float(k + 1))
			pk.beam(kit, "paint", a, b, 0.12, 0.09, Color(0.85, 0.1, 0.08) if k % 2 == 0 else WHITE, Vector3(0, 0, 1))
		_box(pk, kit, "steel", pv - dirv * 0.35, Basis(), Vector3(0.3, 0.3, 0.35), STEEL_DARK)
	# Walls with railings off both sides, lamp posts.
	for side in [[x1 + 0.2, 34.0], [-px - 0.8, -34.0]]:
		var xa: float = side[0]
		var xb: float = side[1]
		var sgn: float = signf(xb)
		_blk(pk, kit, "concrete", Vector3(minf(xa, xb), -1.5, -0.3), Vector3(maxf(xa, xb), 0.3, 0.3), CONCRETE)
		_blk(pk, kit, "brick", Vector3(minf(xa, xb), 0.3, -0.22), Vector3(maxf(xa, xb), 1.0, 0.22), BRICK)
		var npier: int = maxi(int(round(absf(xb - xa) / 4.0)), 1)
		for kp in range(npier + 1):
			var xp: float = lerpf(xa, xb, float(kp) / float(npier))
			_blk(pk, kit, "brick", Vector3(xp - 0.3, 0.3, -0.3), Vector3(xp + 0.3, 2.3, 0.3), BRICK_DARK)
			_blk(pk, kit, "concrete", Vector3(xp - 0.36, 2.3, -0.36), Vector3(xp + 0.36, 2.45, 0.36), CONCRETE.lightened(0.1))
		var x := xa
		pk.beam(kit, "steel", Vector3(xa, 2.0, 0), Vector3(xb, 2.0, 0), 0.05, 0.05, STEEL_DARK, Vector3.UP)
		pk.beam(kit, "steel", Vector3(xa, 1.15, 0), Vector3(xb, 1.15, 0), 0.05, 0.05, STEEL_DARK, Vector3.UP)
		x = xa + sgn * 0.25
		while absf(x - xa) < absf(xb - xa):
			pk.beam(kit, "steel", Vector3(x, 1.0, 0), Vector3(x, 2.15, 0), 0.03, 0.03, STEEL_DARK)
			x += sgn * 0.25
	for lp in [Vector3(-10.6, 0, 6.0), Vector3(19.5, 0, 6.0)]:
		_lamp_mast(pk, kit, lp, 7.0, Vector3(-signf(lp.x), 0, 0))


## A street lamp: a tapered tube mast with a bracket arm toward `out` and a flat lamp head.
static func _lamp_mast(pk: PropKit, kit: Dictionary, p: Vector3, h: float, out: Vector3) -> void:
	_blk(pk, kit, "concrete", p + Vector3(-0.4, -1.5, -0.4), p + Vector3(0.4, 0.15, 0.4), CONCRETE)
	pk.tube(kit, "steel", p, p + Vector3(0, h, 0), 0.11, 0.07, 8, Color(0.4, 0.42, 0.42), false)
	pk.beam(kit, "steel", p + Vector3(0, h - 0.1, 0), p + Vector3(0, h + 0.2, 0) + out * 1.6, 0.07, 0.07, Color(0.4, 0.42, 0.42))
	var hc: Vector3 = p + Vector3(0, h + 0.15, 0) + out * 1.9
	_box(pk, kit, "steel", hc, Basis(), Vector3(0.9, 0.18, 0.45), Color(0.35, 0.37, 0.37))
	_box(pk, kit, "lens", hc - Vector3(0, 0.1, 0), Basis(), Vector3(0.75, 0.03, 0.36), Color(0.9, 0.88, 0.8))


# ======================================================================================
#  The steel crown on the slag heap
# ======================================================================================

## Die Stahlkrone: an open crown of weathering steel at the origin (its foot on the heap's top), an octagonal band 4.5m
## high (23.8m across its corners, a door on +z, windows), eight raking points rising to balls at 18.6m, a ring of bosses,
## an inner viewing deck at 7.5m reached by a spiral stair round a central column. Outside 13.6 radius (the points lean out).
static func steel_crown(pk: PropKit, kit: Dictionary) -> void:
	var n := 8
	var rc := 11.9
	var bh := 4.5
	var top := 18.0
	var col := Color(0.74, 0.46, 0.30)
	var gold := Color(0.80, 0.62, 0.28)
	var cs: Array = []
	for k in range(n + 1):
		var a: float = TAU * (float(k) + 0.5) / float(n)
		cs.append(Vector3(cos(a) * rc, 0.0, sin(a) * rc))
	pk.lathe(kit, "concrete", Vector3.ZERO, [Vector2(rc + 0.8, -3.0), Vector2(rc + 0.8, 0.3), Vector2(0.001, 0.3)], n, CONCRETE, true, Basis(Vector3.UP, -PI / float(n)))
	var thick := 0.22
	for k in range(n):
		var a: Vector3 = cs[k]
		var b: Vector3 = cs[k + 1]
		var mid: Vector3 = (a + b) * 0.5
		var out: Vector3 = mid.normalized()
		var along: Vector3 = (b - a).normalized()
		var wl: float = a.distance_to(b)
		var holes: Array = []
		var dz: Vector3 = out
		if dz.z > 0.9:
			holes = [[Rect2(wl * 0.5 - 1.3, 0.3, 2.6, 3.0), true]]
		else:
			holes = [[Rect2(wl * 0.5 - 2.6, 1.4, 1.4, 2.0), true], [Rect2(wl * 0.5 + 1.2, 1.4, 1.4, 2.0), true]]
		_wall_holes(pk, kit, "corten", a, along, out, 0.0, wl, 0.3, bh, holes, col, thick)
		pk.quad(kit, "corten", [a + Vector3(0, bh, 0), b + Vector3(0, bh, 0), b + Vector3(0, bh, 0) - out * thick, a + Vector3(0, bh, 0) - out * thick], Vector3.UP, col.darkened(0.1))
		# A rolled band along the band's top and foot, standing proud.
		var alt: float = 0.025 * float(k % 2)
		_box(pk, kit, "corten", mid + out * (0.06 + alt * 0.5) + Vector3(0, bh - 0.25, 0), Basis(along, Vector3.UP, out), Vector3(wl + 0.12, 0.4 + alt * 2.0, 0.14 + alt), col.darkened(0.15))
		_box(pk, kit, "corten", mid + out * (0.06 + alt * 0.5) + Vector3(0, 0.55, 0), Basis(along, Vector3.UP, out), Vector3(wl + 0.12, 0.5 + alt * 2.0, 0.14 + alt), col.darkened(0.15))
		# The point: a triangular plate from the band's top edge up to a leaning apex, both faces and its two edges.
		var apex: Vector3 = out * (rc * cos(PI / float(n)) + 1.7) + Vector3(0, top, 0)
		var a1: Vector3 = a + Vector3(0, bh, 0)
		var b1: Vector3 = b + Vector3(0, bh, 0)
		var pn: Vector3 = (b1 - a1).cross(apex - a1).normalized()
		if pn.dot(out) < 0.0:
			pn = -pn
		var inset: Vector3 = -out * thick
		# Openwork: the plate is a frame round a triangular opening (the plate scaled to 55% about a point low in it),
		# with a lattice cross in the opening.
		var hc: Vector3 = (a1 + b1) * 0.5 * 0.62 + apex * 0.38
		var ia: Vector3 = hc + (a1 - hc) * 0.5
		var ib: Vector3 = hc + (b1 - hc) * 0.5
		var ip: Vector3 = hc + (apex - hc) * 0.5
		var outer: Array = [a1, b1, apex]
		var inner: Array = [ia, ib, ip]
		for side in [0, 1]:
			var off: Vector3 = Vector3.ZERO if side == 0 else inset
			var fn: Vector3 = pn if side == 0 else -pn
			var fc: Color = col if side == 0 else col.darkened(0.12)
			for k2 in range(3):
				var o0: Vector3 = outer[k2]
				var o1: Vector3 = outer[(k2 + 1) % 3]
				var i0: Vector3 = inner[k2]
				var i1: Vector3 = inner[(k2 + 1) % 3]
				pk.quad(kit, "corten", [o0 + off, o1 + off, i1 + off, i0 + off], fn, fc)
		for k2 in range(3):
			var i0: Vector3 = inner[k2]
			var i1: Vector3 = inner[(k2 + 1) % 3]
			var en2: Vector3 = (hc - (i0 + i1) * 0.5).normalized()
			pk.quad(kit, "corten", [i0, i1, i1 + inset, i0 + inset], en2, col.darkened(0.2))
		for e in [[a1, apex], [b1, apex]]:
			var ea: Vector3 = e[0]
			var eb: Vector3 = e[1]
			var en: Vector3 = ((ea + eb) * 0.5 - (a1 + b1 + apex) / 3.0).normalized()
			pk.quad(kit, "corten", [ea, eb, eb + inset, ea + inset], en, col.darkened(0.2))
		var c3: Vector3 = (a1 + b1) * 0.5 * 0.9 + apex * 0.1 + pn * 0.02
		pk.beam(kit, "corten", (ia + ib) * 0.5 + inset * 0.5, ip + inset * 0.5, 0.14, 0.14, col.darkened(0.25))
		pk.beam(kit, "corten", (ia + ip) * 0.5 + inset * 0.5, (ib + ip) * 0.5 + inset * 0.5, 0.14, 0.14, col.darkened(0.25))
		var bb := Basis(pn.cross(Vector3.UP).normalized(), pn, Vector3.UP.cross(pn.cross(Vector3.UP).normalized()).normalized())
		var tb := Basis(bb.x, pn, bb.x.cross(pn).normalized())
		pk.lathe(kit, "metal", c3 + pn * 0.1, [Vector2(0.95, 0.0), Vector2(0.85, 0.25), Vector2(0.5, 0.45), Vector2(0.001, 0.5)], 14, gold, false, tb)
		var prof: Array = []
		for k2 in range(9):
			var t: float = -PI * 0.5 + PI * float(k2) / 8.0
			prof.append(Vector2(cos(t) * 0.75 + 0.001, sin(t) * 0.75))
		pk.lathe(kit, "metal", apex + Vector3(0, 0.62, 0), prof, 14, gold)
	# The viewing deck inside at 7.5, on columns, a railing round its edge and the stair well.
	var dy := 7.5
	var ro := 9.4
	var ri := 2.1
	for k in range(n):
		var a: Vector3 = (cs[k] as Vector3).normalized()
		var b: Vector3 = (cs[k + 1] as Vector3).normalized()
		pk.quad(kit, "steel", [a * ri + Vector3(0, dy, 0), b * ri + Vector3(0, dy, 0), b * ro + Vector3(0, dy, 0), a * ro + Vector3(0, dy, 0)], Vector3.UP, Color(0.36, 0.3, 0.26))
		pk.quad(kit, "corten", [a * ri + Vector3(0, dy - 0.35, 0), b * ri + Vector3(0, dy - 0.35, 0), b * ro + Vector3(0, dy - 0.35, 0), a * ro + Vector3(0, dy - 0.35, 0)], Vector3.DOWN, col.darkened(0.3))
		var mo: Vector3 = ((a + b) * 0.5).normalized()
		pk.quad(kit, "corten", [a * ro + Vector3(0, dy - 0.35, 0), b * ro + Vector3(0, dy - 0.35, 0), b * ro + Vector3(0, dy, 0), a * ro + Vector3(0, dy, 0)], mo, col.darkened(0.2))
		pk.quad(kit, "corten", [b * ri + Vector3(0, dy - 0.35, 0), a * ri + Vector3(0, dy - 0.35, 0), a * ri + Vector3(0, dy, 0), b * ri + Vector3(0, dy, 0)], -mo, col.darkened(0.2))
		pk.beam(kit, "corten", a * (ro - 0.4) + Vector3(0, 0.3, 0), a * (ro - 0.4) + Vector3(0, dy - 0.35, 0), 0.35, 0.35, col.darkened(0.2))
		_railing(pk, kit, [a * (ro - 0.1) + Vector3(0, dy, 0), b * (ro - 0.1) + Vector3(0, dy, 0)], 1.15, col.darkened(0.35), "corten")
		if k != 1:
			_railing(pk, kit, [a * (ri + 0.1) + Vector3(0, dy, 0), b * (ri + 0.1) + Vector3(0, dy, 0)], 1.1, col.darkened(0.35), "corten")
	# The spiral stair round a central column.
	pk.tube(kit, "corten", Vector3(0, 0.3, 0), Vector3(0, dy + 1.1, 0), 0.32, 0.32, 12, col.darkened(0.2), true)
	pk.lathe(kit, "metal", Vector3(0, dy + 1.1, 0), [Vector2(0.001, 0.0), Vector2(0.42, 0.05), Vector2(0.42, 0.15), Vector2(0.001, 0.2)], 12, gold, true)
	var steps := 36
	var prev := Vector3.ZERO
	for k in range(steps):
		var t: float = float(k) / float(steps)
		var a: float = PI * 0.5 + TAU * 1.08 * t
		var d := Vector3(cos(a), 0, sin(a))
		var y: float = 0.3 + (dy - 0.3) * (float(k) + 1.0) / float(steps)
		_box(pk, kit, "steel", d * 1.15 + Vector3(0, y - 0.03, 0), Basis(Vector3(-d.z, 0, d.x), Vector3.UP, d), Vector3(0.42, 0.06, 1.7), Color(0.36, 0.3, 0.26))
		var rp: Vector3 = d * 1.95 + Vector3(0, y + 1.0, 0)
		if k > 0:
			pk.beam(kit, "corten", prev, rp, 0.05, 0.05, col.darkened(0.35))
		if k % 3 == 0:
			pk.beam(kit, "corten", d * 1.95 + Vector3(0, y, 0), rp, 0.04, 0.04, col.darkened(0.35))
		prev = rp


# ======================================================================================
#  The canal basin: ore unloading bridge, barge, heaps
# ======================================================================================

## An ore unloading bridge (Erzverladebrücke): its land leg on a rail at x -24 and its quay leg on a rail at x +2 (both
## along z, rail tops at y 0), the girder 26m up running out to x +36 over the water (the canal on +x), a mast over the
## quay leg with stays, the trolley with its machinery house and cab at x +22, the grab hanging over the water at 12m, a
## receiving hopper on the land side. Footprint x -31..37, z ±7.5; 41m to the mast's top.
static func ore_crane(pk: PropKit, kit: Dictionary) -> void:
	var col := Color(0.48, 0.17, 0.11)
	var gy := 26.0
	var gh := 4.0
	var gc: float = gy + gh * 0.5 + 0.17
	for lx in [-24.0, 2.0]:
		# Rails along z.
		for sx in [-0.7, 0.7]:
			_blk(pk, kit, "steel", Vector3(lx + sx - 0.04, -0.15, -40.0), Vector3(lx + sx + 0.04, 0.0, 40.0), RAIL_GREY)
		_blk(pk, kit, "concrete", Vector3(lx - 1.2, -3.0, -40.0), Vector3(lx + 1.2, -0.15, 40.0), CONCRETE)
		for sz in [-1.0, 1.0]:
			var foot := Vector3(lx, 1.6, sz * 6.0)
			var head := Vector3(lx, gy, sz * 2.2)
			_box(pk, kit, "paint", (foot + head) * 0.5, Basis(Vector3(1, 0, 0), (head - foot).normalized(), Vector3(1, 0, 0).cross((head - foot).normalized())), Vector3(1.4, foot.distance_to(head), 1.1), col)
			# The bogie on the rail.
			_blk(pk, kit, "paint", Vector3(lx - 0.95, 0.5, sz * 6.0 - 2.2), Vector3(lx + 0.95, 1.6, sz * 6.0 + 2.2), col.darkened(0.15))
			for wz in [-1.4, 1.4]:
				pk.tube(kit, "steel", Vector3(lx - 1.0, 0.45, sz * 6.0 + wz), Vector3(lx + 1.0, 0.45, sz * 6.0 + wz), 0.45, 0.45, 12, STEEL_DARK, true)
		pk.beam(kit, "paint", Vector3(lx, 9.0, -4.9), Vector3(lx, 9.0, 4.9), 0.7, 0.7, col)
		pk.beam(kit, "paint", Vector3(lx, 9.0, -4.9), Vector3(lx, 18.0, 3.3), 0.35, 0.35, col)
		_ladder(pk, kit, Vector3(lx + 0.75, 1.6, 0.0), Vector3(lx + 0.75, gy, 0.0), Vector3(1, 0, 0), true)
	# The girder, a walkway along it, the mast and stays.
	_lattice(pk, kit, "paint", Vector3(-30.0, gc, 0), Vector3(36.0, gc, 0), 5.0, gh, 3.0, col, Vector3.UP, 0.34, 0.15)
	_blk(pk, kit, "steel", Vector3(-29.7, gy + 0.3, 2.6), Vector3(35.7, gy + 0.38, 3.6), STEEL_DARK)
	_railing(pk, kit, [Vector3(-29.6, gy + 0.38, 3.55), Vector3(35.6, gy + 0.38, 3.55)], 1.05, CRANE_YELLOW)
	var mt := Vector3(2.0, gy + gh + 11.0, 0)
	for sz in [-2.3, 2.3]:
		pk.beam(kit, "paint", Vector3(2.0, gy + gh + 0.3, sz), mt, 0.6, 0.6, col)
		pk.beam(kit, "steel", mt, Vector3(35.0, gy + gh + 0.4, sz), 0.1, 0.1, STEEL_DARK)
		pk.beam(kit, "steel", mt, Vector3(-29.0, gy + gh + 0.4, sz), 0.1, 0.1, STEEL_DARK)
	# The trolley: a machinery house on the girder's top, the cab hung under its end, the grab on its ropes.
	var tx := 22.0
	var ty: float = gy + gh + 0.34
	_blk(pk, kit, "paint", Vector3(tx - 4.0, ty, -2.8), Vector3(tx + 4.0, ty + 0.6, 2.8), col.darkened(0.1))
	_wall_holes(pk, kit, "iron", Vector3(tx - 3.6, 0, 2.4), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.0, 7.2, ty + 0.6, ty + 4.2, [], Color(0.62, 0.62, 0.6), 0.1)
	_wall_holes(pk, kit, "iron", Vector3(tx + 3.6, 0, -2.4), Vector3(-1, 0, 0), Vector3(0, 0, -1), 0.0, 7.2, ty + 0.6, ty + 4.2, [], Color(0.62, 0.62, 0.6), 0.1)
	_wall_holes(pk, kit, "iron", Vector3(tx - 3.6, 0, -2.4), Vector3(0, 0, 1), Vector3(-1, 0, 0), 0.0, 4.8, ty + 0.6, ty + 4.2, [], Color(0.62, 0.62, 0.6), 0.1)
	_wall_holes(pk, kit, "iron", Vector3(tx + 3.6, 0, 2.4), Vector3(0, 0, -1), Vector3(1, 0, 0), 0.0, 4.8, ty + 0.6, ty + 4.2, [], Color(0.62, 0.62, 0.6), 0.1)
	_roof(pk, kit, "iron", Vector3(tx - 3.9, ty + 4.2, 2.7), Vector3(tx + 3.9, ty + 4.2, 2.7), Vector3(tx + 3.9, ty + 4.9, 0), Vector3(tx - 3.9, ty + 4.9, 0), ROOF_GREY, Vector3(0, 1, 0.26).normalized())
	_roof(pk, kit, "iron", Vector3(tx + 3.9, ty + 4.2, -2.7), Vector3(tx - 3.9, ty + 4.2, -2.7), Vector3(tx - 3.9, ty + 4.9, 0), Vector3(tx + 3.9, ty + 4.9, 0), ROOF_GREY, Vector3(0, 1, -0.26).normalized())
	for sz in [-1.0, 1.0]:
		pk.tri(kit, "iron", Vector3(tx - 3.6, ty + 4.2, sz * 2.4), Vector3(tx - 3.6, ty + 4.2, 0), Vector3(tx - 3.6, ty + 4.85, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Color(0.62, 0.62, 0.6), Vector3(-1, 0, 0))
		pk.tri(kit, "iron", Vector3(tx + 3.6, ty + 4.2, sz * 2.4), Vector3(tx + 3.6, ty + 4.2, 0), Vector3(tx + 3.6, ty + 4.85, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Color(0.62, 0.62, 0.6), Vector3(1, 0, 0))
	var cab := Vector3(tx + 2.6, gy - 1.3, 0)
	_blk(pk, kit, "paint", cab + Vector3(-1.2, -1.2, -1.3), cab + Vector3(1.2, -0.4, 1.3), col)
	_blk(pk, kit, "paint", cab + Vector3(-1.3, 1.1, -1.4), cab + Vector3(1.3, 1.25, 1.4), col.darkened(0.1))
	_glazing(pk, kit, cab + Vector3(1.2, 0.35, 0), Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0), 2.6, 1.5)
	_glazing(pk, kit, cab + Vector3(0.05, 0.35, 1.3), Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, 1), 2.3, 1.5)
	_glazing(pk, kit, cab + Vector3(0.05, 0.35, -1.3), Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1), 2.3, 1.5)
	_blk(pk, kit, "paint", cab + Vector3(-1.2, -0.4, -1.3), cab + Vector3(-1.1, 1.1, 1.3), col)
	for px in [-1.0, 1.0]:
		pk.beam(kit, "steel", cab + Vector3(px, 1.25, 0), Vector3(cab.x + px, gy - 0.2, 0), 0.15, 0.15, STEEL_DARK)
	var gyb := 12.0
	for rz in [-0.5, 0.5]:
		pk.beam(kit, "steel", Vector3(tx - 0.6, ty, rz), Vector3(tx - 0.6, gyb + 2.6, rz), 0.05, 0.05, Color(0.15, 0.15, 0.15))
	_grab(pk, kit, Vector3(tx - 0.6, gyb, 0))
	# The receiving hopper under the girder on the land side, a conveyor's head leaving it.
	_frustum(pk, kit, "rusty", -10.0, 0.0, 6.0, 1.0, 1.0, 10.5, 4.2, 4.2, Color(0.4, 0.36, 0.3))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pk.beam(kit, "steel", Vector3(-10.0 + sx * 3.4, 0.0, sz * 3.4), Vector3(-10.0 + sx * 3.4, 9.8, sz * 3.4), 0.3, 0.3, STEEL)
			_blk(pk, kit, "concrete", Vector3(-10.0 + sx * 3.4 - 0.5, -3.0, sz * 3.4 - 0.5), Vector3(-10.0 + sx * 3.4 + 0.5, 0.2, sz * 3.4 + 0.5), CONCRETE)
	pk.beam(kit, "steel", Vector3(-10.0, 4.6, 0), Vector3(-30.0, 2.0, 0), 1.4, 0.4, Color(0.35, 0.36, 0.36), Vector3(0, 0, 1))
	pk.beam(kit, "heap", Vector3(-10.0, 4.85, 0), Vector3(-30.0, 2.25, 0), 0.9, 0.2, Color(0.42, 0.25, 0.18), Vector3(0, 0, 1))


## A clamshell grab hanging open: its head block at `c` (its foot), two shells below.
static func _grab(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	var col := Color(0.25, 0.25, 0.24)
	_blk(pk, kit, "steel", c + Vector3(-0.8, 1.6, -0.6), c + Vector3(0.8, 2.6, 0.6), col)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", c + Vector3(sx * 0.6, 1.6, -0.5), c + Vector3(sx * 1.4, 0.2, -0.5), 0.15, 0.15, col)
		pk.beam(kit, "steel", c + Vector3(sx * 0.6, 1.6, 0.5), c + Vector3(sx * 1.4, 0.2, 0.5), 0.15, 0.15, col)
		_box(pk, kit, "rusty", c + Vector3(sx * 1.25, -0.4, 0), Basis(Vector3(0, 0, 1), deg_to_rad(sx * 28.0)), Vector3(1.0, 1.6, 2.2), Color(0.32, 0.3, 0.28))
	pk.tube(kit, "steel", c + Vector3(0, 1.0, -0.7), c + Vector3(0, 1.0, 0.7), 0.3, 0.3, 10, col, true)


## An inland barge (Binnenschiff) at its waterline (y 0), bow toward +z, `length` long (80-110), 9.5m beam: a black hull
## with its red bottom, the cargo hold under rolling hatch covers, the wheelhouse and living quarters aft with a car on the
## roof, a mast and lights forward, KRONBURG on the bows and the stern. Draws 2.2m; the deck stands 1.75m out of the water.
static func barge(pk: PropKit, kit: Dictionary, length: float, labels: Array) -> void:
	var L: float = maxf(length, 40.0)
	var hz: float = L * 0.5
	var hw := 4.75
	# Stations: [z, half width, bottom, sheer].
	var st: Array = [[-hz, 3.4, -0.4, 2.05], [-hz + 1.5, 4.3, -1.3, 1.95], [-hz + 5.0, 4.75, -2.05, 1.8], [-hz + 9.0, hw, -2.2, 1.75],
			[hz - 10.0, hw, -2.2, 1.75], [hz - 5.0, 4.6, -1.9, 1.95], [hz - 2.2, 3.9, -1.0, 2.2], [hz - 0.6, 3.0, 0.2, 2.45], [hz, 2.4, 0.9, 2.55]]
	var black := Color(0.07, 0.07, 0.08)
	var red := Color(0.45, 0.11, 0.08)
	var sec := func(s: Array) -> Array:
		var w: float = s[1]
		var yb: float = s[2]
		var ys: float = s[3]
		var z: float = s[0]
		var wl: float = clampf(0.05, yb + 0.4, ys - 0.1)
		return [Vector3(w, ys, z), Vector3(w, wl, z), Vector3(w, yb + 0.4, z), Vector3(w - 0.4, yb, z), Vector3(-w + 0.4, yb, z), Vector3(-w, yb + 0.4, z), Vector3(-w, wl, z), Vector3(-w, ys, z)]
	for i in range(st.size() - 1):
		var r0: Array = sec.call(st[i])
		var r1: Array = sec.call(st[i + 1])
		for j in range(r0.size() - 1):
			var a: Vector3 = r0[j]
			var b: Vector3 = r0[j + 1]
			var c: Vector3 = r1[j + 1]
			var d: Vector3 = r1[j]
			var mid: Vector3 = (a + b + c + d) * 0.25
			var n: Vector3 = (b - a).cross(d - a).normalized()
			var outward := Vector3(mid.x, mid.y + 0.6, 0.0)
			if n.dot(outward) < 0.0:
				n = -n
			var colr: Color = black if (j == 0 or j == 6) else red
			pk.quad(kit, "paint", [a, b, c, d], n, colr)
		# The deck between these stations.
		var da: Vector3 = r0[0]
		var db: Vector3 = r1[0]
		pk.quad(kit, "paint", [Vector3(-da.x, da.y, da.z), da, db, Vector3(-db.x, db.y, db.z)], Vector3.UP, Color(0.30, 0.31, 0.3))
	# Bow and stern faces.
	for e in [[0, -1.0], [st.size() - 1, 1.0]]:
		var ring: Array = sec.call(st[e[0]])
		var poly := PackedVector2Array()
		for p in ring:
			poly.append(Vector2((p as Vector3).x, (p as Vector3).y))
		var tris := Geometry2D.triangulate_polygon(poly)
		var zz: float = (ring[0] as Vector3).z
		var nn := Vector3(0, 0, float(e[1]))
		for k in range(0, tris.size(), 3):
			var pa: Vector2 = poly[tris[k]]
			var pb: Vector2 = poly[tris[k + 1]]
			var pc: Vector2 = poly[tris[k + 2]]
			var cc: Color = black if (pa.y + pb.y + pc.y) / 3.0 > 0.0 else red
			pk.tri(kit, "paint", Vector3(pa.x, pa.y, zz), Vector3(pb.x, pb.y, zz), Vector3(pc.x, pc.y, zz), nn, nn, nn, cc, nn)
	# A rubbing strake and a white sheer line along each side.
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "paint", Vector3(sx * (hw + 0.06), 0.95, -hz + 6.0), Vector3(sx * (hw + 0.06), 0.95, hz - 7.0), 0.12, 0.2, Color(0.12, 0.12, 0.12), Vector3(0, 1, 0))
		pk.beam(kit, "paint", Vector3(sx * (hw + 0.03), 1.6, -hz + 9.0), Vector3(sx * (hw + 0.03), 1.6, hz - 10.0), 0.06, 0.1, WHITE, Vector3(0, 1, 0))
	# The hold: a coaming and rolling hatch covers.
	var za: float = -hz + 19.0
	var zb: float = hz - 9.5
	var cw: float = hw - 1.0
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "paint", Vector3(sx * cw - 0.12, 1.7, zb), Vector3(sx * cw + 0.12, 2.75, za), Color(0.2, 0.22, 0.22))
	for zz in [za, zb]:
		_blk(pk, kit, "paint", Vector3(-cw, 1.7, zz - 0.12), Vector3(cw, 2.75, zz + 0.12), Color(0.2, 0.22, 0.22))
	var nc: int = int((zb - za) / 4.0)
	var cl: float = (zb - za) / float(nc)
	var arch := PackedVector2Array()
	for k in range(9):
		var t: float = float(k) / 8.0
		var x: float = lerpf(cw + 0.15, -cw - 0.15, t)
		arch.append(Vector2(x, 2.75 + 0.55 * sin(PI * t)))
	arch.append(Vector2(-cw - 0.15, 2.65))
	arch.append(Vector2(cw + 0.15, 2.65))
	var arch_ccw := PackedVector2Array()
	for k in range(arch.size() - 1, -1, -1):
		arch_ccw.append(arch[k])
	for k in range(nc):
		var c0: float = za + cl * float(k) + 0.04
		var c1: float = za + cl * float(k + 1) - 0.04
		var hc: Color = Color(0.17, 0.30, 0.24) if k % 2 == 0 else Color(0.19, 0.32, 0.26)
		pk.extrude(kit, "paint", arch_ccw, c0, c1, 0.03, hc)
	# Aft: the living quarters with the car on their roof, the wheelhouse on its post, the stern mast and flag.
	var q0: float = -hz + 1.6
	var q1: float = -hz + 11.0
	var qh := 2.6
	var white := Color(0.9, 0.9, 0.88)
	_blk(pk, kit, "paint", Vector3(-3.7, 1.7, q0), Vector3(3.7, 1.7 + qh, q1), white)
	for sx in [-1.0, 1.0]:
		for k in range(4):
			var wz: float = q0 + 1.3 + float(k) * 2.2
			_glazing(pk, kit, Vector3(sx * 3.72, 1.7 + 1.5, wz), Vector3(0, 0, -sx), Vector3.UP, Vector3(sx, 0, 0), 1.2, 0.9)
	_blk(pk, kit, "paint", Vector3(-3.85, 1.7 + qh, q0 - 0.15), Vector3(3.85, 1.7 + qh + 0.14, q1 + 0.15), Color(0.25, 0.27, 0.27))
	_railing(pk, kit, [Vector3(-3.7, 1.7 + qh + 0.14, q0), Vector3(3.7, 1.7 + qh + 0.14, q0), Vector3(3.7, 1.7 + qh + 0.14, q1), Vector3(-3.7, 1.7 + qh + 0.14, q1), Vector3(-3.7, 1.7 + qh + 0.14, q0)], 1.0, white, "paint")
	_car(pk, kit, Vector3(0.0, 1.7 + qh + 0.14, q0 + 4.0), Color(0.12, 0.22, 0.45))
	var wh0: float = q1 + 0.6
	var wh1: float = wh0 + 4.2
	var wy: float = 1.7 + qh + 0.8
	pk.tube(kit, "steel", Vector3(0, 1.7, (wh0 + wh1) * 0.5), Vector3(0, wy, (wh0 + wh1) * 0.5), 0.5, 0.5, 12, Color(0.6, 0.6, 0.6), false)
	_blk(pk, kit, "paint", Vector3(-2.6, wy, wh0), Vector3(2.6, wy + 0.9, wh1), white)
	for g in [[Vector3(0, wy + 1.6, wh1), Vector3(-1, 0, 0), Vector3(0, 0, 1), 5.2], [Vector3(0, wy + 1.6, wh0), Vector3(1, 0, 0), Vector3(0, 0, -1), 5.2],
			[Vector3(2.6, wy + 1.6, (wh0 + wh1) * 0.5), Vector3(0, 0, 1), Vector3(1, 0, 0), 4.2], [Vector3(-2.6, wy + 1.6, (wh0 + wh1) * 0.5), Vector3(0, 0, -1), Vector3(-1, 0, 0), 4.2]]:
		_glazing(pk, kit, g[0], g[1], Vector3.UP, g[2], g[3], 1.4)
	for px in [-2.5, 2.5]:
		for pz in [wh0 + 0.1, wh1 - 0.1]:
			_blk(pk, kit, "paint", Vector3(px - 0.06, wy + 0.9, pz - 0.06), Vector3(px + 0.06, wy + 2.3, pz + 0.06), white)
	_blk(pk, kit, "paint", Vector3(-2.9, wy + 2.3, wh0 - 0.3), Vector3(2.9, wy + 2.5, wh1 + 0.3), white)
	pk.beam(kit, "steel", Vector3(0, wy + 2.5, (wh0 + wh1) * 0.5), Vector3(0, wy + 4.0, (wh0 + wh1) * 0.5), 0.12, 0.12, Color(0.6, 0.6, 0.6))
	_box(pk, kit, "paint", Vector3(0, wy + 3.6, (wh0 + wh1) * 0.5), Basis(), Vector3(2.4, 0.12, 0.25), Color(0.85, 0.85, 0.85))
	pk.tube(kit, "steel", Vector3(0, 1.9, -hz + 0.5), Vector3(0, 6.6, -hz + 0.5), 0.05, 0.04, 6, Color(0.7, 0.7, 0.7), true)
	for fk in range(3):
		var fc: Color = [Color(0.05, 0.05, 0.05), Color(0.8, 0.08, 0.06), Color(0.95, 0.75, 0.05)][fk]
		_blk(pk, kit, "paint", Vector3(-0.01, 6.4 - 0.3 * float(fk) - 0.3, -hz + 0.55), Vector3(0.01, 6.4 - 0.3 * float(fk), -hz - 0.85), fc)
	# Forward: the mast with its lights, the anchor winch, bollards along the sides.
	pk.tube(kit, "steel", Vector3(0, 2.4, hz - 3.0), Vector3(0, 7.5, hz - 3.0), 0.09, 0.07, 8, Color(0.7, 0.7, 0.7), true)
	_box(pk, kit, "lens", Vector3(0, 7.2, hz - 2.92), Basis(), Vector3(0.2, 0.25, 0.12), Color(0.95, 0.95, 0.9))
	_blk(pk, kit, "paint", Vector3(-1.0, 2.4, hz - 5.8), Vector3(1.0, 3.1, hz - 4.6), Color(0.25, 0.3, 0.3))
	for sx in [-1.0, 1.0]:
		var bz: float = -hz + 13.0
		while bz < hz - 6.0:
			pk.tube(kit, "steel", Vector3(sx * (hw - 0.45), 1.75, bz), Vector3(sx * (hw - 0.45), 2.15, bz), 0.15, 0.15, 8, Color(0.15, 0.15, 0.15), true)
			bz += 14.0
	# The names.
	for sx in [-1.0, 1.0]:
		_label(labels, "KRONBURG", Vector3(sx * (hw + 0.05), 1.3, hz - 13.0), Vector3(sx, 0, 0), 0.62, WHITE, 6.0)
	_label(labels, "KRONBURG", Vector3(0, 1.0, -hz - 0.03), Vector3(0, 0, -1), 0.5, WHITE, 5.0)


## A small car (4.3m, nose +z) standing on `p`: a body, a glasshouse, four wheels.
static func _car(pk: PropKit, kit: Dictionary, p: Vector3, col: Color) -> void:
	_blk(pk, kit, "paint", p + Vector3(-0.85, 0.3, -2.15), p + Vector3(0.85, 0.95, 2.15), col)
	_box(pk, kit, "paint", p + Vector3(0, 1.25, -0.25), Basis(), Vector3(1.5, 0.6, 2.2), col.darkened(0.05))
	for g in [[Vector3(0, 1.25, 0.86), Vector3(-1, 0, 0), Vector3(0, 0, 1), 1.4], [Vector3(0.76, 1.25, -0.25), Vector3(0, 0, 1), Vector3(1, 0, 0), 2.0], [Vector3(-0.76, 1.25, -0.25), Vector3(0, 0, -1), Vector3(-1, 0, 0), 2.0]]:
		_box(pk, kit, "lens", p + (g[0] as Vector3), Basis(g[1], Vector3.UP, g[2]), Vector3(g[3], 0.45, 0.02), Color(0.1, 0.12, 0.14))
	for wz in [-1.35, 1.35]:
		for sx in [-1.0, 1.0]:
			pk.tube(kit, "rubber", p + Vector3(sx * 0.7, 0.32, wz), p + Vector3(sx * 0.92, 0.32, wz), 0.32, 0.32, 10, Color(0.05, 0.05, 0.05), true)


## An ore (or coal) heap, `length` along z, `width` across, `height` high, at the angle of repose with lumps, its edge
## sunk below y 0 so it sits on uneven ground. Centred on the origin.
static func stockpile(pk: PropKit, kit: Dictionary, length := 60.0, width := 24.0, height := 10.0, coal := false) -> void:
	var nx := 22
	var nz: int = maxi(int(length / 2.5), 8)
	var hw: float = width * 0.5 + 1.0
	var hl: float = length * 0.5 + 1.0
	var repose := 0.72
	var hf := func(x: float, z: float) -> float:
		var dx: float = width * 0.5 - absf(x)
		var dz: float = length * 0.5 - absf(z)
		var e: float = minf(dx, dz)
		var hh: float = minf(height, e * repose)
		var ridge: float = height - 0.15 * height * (sin(z * 0.21) * 0.5 + 0.5)
		hh = minf(hh, ridge)
		var lump: float = sin(x * 1.3 + z * 0.7) * cos(z * 1.1 - x * 0.4) * 0.35 + sin(x * 3.1 - z * 2.3) * 0.15
		return maxf(hh + lump * clampf(hh, 0.0, 1.0), -0.6) if e > -0.8 else -0.6
	var grid: Array = []
	for i in range(nx + 1):
		var row: Array = []
		for j in range(nz + 1):
			var x: float = lerpf(-hw, hw, float(i) / float(nx))
			var z: float = lerpf(-hl, hl, float(j) / float(nz))
			row.append(Vector3(x, hf.call(x, z), z))
		grid.append(row)
	var base: Color = Color(0.07, 0.07, 0.075) if coal else Color(0.38, 0.22, 0.155)
	var nrm := func(i: int, j: int) -> Vector3:
		var a: Vector3 = grid[maxi(i - 1, 0)][j]
		var b: Vector3 = grid[mini(i + 1, nx)][j]
		var c: Vector3 = grid[i][maxi(j - 1, 0)]
		var d: Vector3 = grid[i][mini(j + 1, nz)]
		return (d - c).cross(b - a).normalized()
	for i in range(nx):
		for j in range(nz):
			var p00: Vector3 = grid[i][j]
			var p10: Vector3 = grid[i + 1][j]
			var p01: Vector3 = grid[i][j + 1]
			var p11: Vector3 = grid[i + 1][j + 1]
			var h: float = (p00.y + p11.y) * 0.5
			var c: Color = base
			c.a = 1.0
			if not coal and h > height * 0.6:
				c = c.lerp(Color(0.52, 0.32, 0.2), 0.3)
			var n00: Vector3 = nrm.call(i, j)
			var n10: Vector3 = nrm.call(i + 1, j)
			var n01: Vector3 = nrm.call(i, j + 1)
			var n11: Vector3 = nrm.call(i + 1, j + 1)
			pk.tri(kit, "heap", p00, p10, p11, n00, n10, n11, c, (n00 + n11).normalized())
			pk.tri(kit, "heap", p00, p11, p01, n00, n11, n01, c, (n00 + n11).normalized())
