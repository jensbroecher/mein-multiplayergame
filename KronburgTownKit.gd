extends "res://YardKit.gd"
## Kronburg GP's town (regenerate_kronburg.gd, stage 1, Kronburger Hütte): the half-timbered old town (Altstadt) on the
## hill, its church St. Lamberti, the town hall on the market square with its fountain, the town gate, the colliery
## workers' brick terraces (Zechensiedlung), the corner kiosk (Trinkhalle), the street furniture and the castle ruin.
##
## Everything is built at life size through YardKit's kit machinery (its hut shaders, UVs in world metres: `uvk` is the
## caller's scale) and grown by the generator's PROP_SCALE (1.6). Make a kit with `new_kit(scale)`, set its frame to a
## building's place (scaled by PROP_SCALE), call a builder, `commit(pk, kit)`.
##
## A building's frame: its street front in the plane z = 0 facing +z, x from 0 to w along the street, the back at z = -d,
## y = 0 the ground at the front (the generator puts it at the highest ground under the footprint). Footings and plinths
## run down to y = -4 (FOOT) so a house on a slope never floats. Upper storeys of the half-timbered houses jetty out over
## the street (+z): `house_extent()` says how far.
##
## Labels go into `labels` as YardKit's [text, position, outward normal, cap height, colour, board width], life size in
## the building's frame. No colliders: DressingColliders gives every single mesh its own at race time.
##
## The builders (life size; every footing to FOOT, -4, the castle's to -6):
##   fachwerk_house(pk, kit, w, d, floors, variant, rng, labels)  front z = 0 facing +z, x 0..w, back -d (house_extent)
##   church(pk, kit, labels)          St. Lamberti: tower front z = 0, x centred, nave to -47, apse to -61; 67m to the cock
##   rathaus(pk, kit, labels)         front z = 0, x 0..22, 14 deep; stepped gable to 30.7m, bell turret on the ridge
##   market_fountain(pk, kit)         centred, 7m across its basin's corners, 8.5m over its step; crown to 5.6m
##   town_gate(pk, kit, labels)       arch centred on the origin, road along z: tower x +-8, z +-5; walls to x +-20
##   brick_terrace(pk, kit, units, variant, rng)  x 0..7*units, gardens z 0..-5, houses to -13.5, stables to -16.7
##   trinkhalle(pk, kit, labels)      front z = 0, x 0..4, 3 deep (roof to 4.35 wide, table and bin to z 1.6, crates x 4.4-5.3)
##   litfass(pk, kit)                 centred, 1.5m across its foot, 3.85m
##   ortsschild(pk, kit, labels, text, sub), peitschen_lamp, old_lantern_post, bus_stop(pk, kit, labels), bollard,
##   street_bench, bike_rack, glass_containers, beer_crates(pk, kit, n)
##   castle_ruin(pk, kit)             centred, about 53 x 49m, the keep 30m to its highest stone
##   allotment(pk, kit, w, d, rng), beer_garden(pk, kit, w, d, rng): front z = 0, x 0..w, back -d; maibaum(pk, kit): 26m
##
## Faces never share a plane: the timber frame stands 2.5cm proud of the infill (TP), window frames 5cm, panes 2cm, and
## where timbers meet they are cut to each other (braces clipped to their panel, rails between posts) instead of
## overlapping. Godot's front faces wind clockwise: PropKit.tri winds every triangle for the `out` it is given.

const YardKitBase = preload("res://YardKit.gd")
const ShopNames = preload("res://ShopNames.gd")

## Extra keys: "biber" (hut_masonry style 9, plain tiles), "ashlar" (style 10, dressed sandstone), "kslate" (style 11, slate
## scales: the slate-hung walls, slate roofs and spires), "kbrick" (style 12, Ruhr brick), "pane" (opaque glossy
## glass: transparent panes sort badly), "gold", "kwater" (kronburg_water.gdshader), "hedge" (hedge.gdshader), "leaf"
## (two-sided vertex colour), "enamel" (glossy sign paint).
const KMASONRY := {"biber": 9, "ashlar": 10, "kslate": 11, "kbrick": 12}
const KTANGENTS := ["tile", "iron", "concrete", "zinc", "slate", "biber", "kslate"]
static var _kmats := {}

const FOOT := -4.0
## The timber frame's (and other trim's) standing off the wall.
const TP := 0.025

const WIN_WHITE := Color(0.95, 0.95, 0.92)
const GLASS := Color(0.07, 0.10, 0.13)
const BEAM_BLACK := Color(0.11, 0.10, 0.09)
const OXBLOOD := Color(0.42, 0.13, 0.10)
const BEAM_BROWN := Color(0.33, 0.21, 0.13)
const INFILL_WHITE := Color(0.95, 0.94, 0.89)
const INFILLS := [Color(0.94, 0.88, 0.72), Color(0.91, 0.76, 0.50), Color(0.93, 0.79, 0.75), Color(0.95, 0.90, 0.62),
		Color(0.83, 0.88, 0.78), Color(0.86, 0.88, 0.89)]
const BIBER_RED := Color(0.64, 0.30, 0.20)
const BIBERS := [Color(0.56, 0.25, 0.17), Color(0.50, 0.22, 0.15), Color(0.42, 0.24, 0.18), Color(0.58, 0.31, 0.22)]
const SLATE := Color(0.30, 0.31, 0.33)
const SANDSTONE := Color(0.74, 0.66, 0.52)
const RUBBLE := Color(0.70, 0.64, 0.55)
const BERG_GREEN := Color(0.12, 0.37, 0.22)
const SHUTTERS := [Color(0.18, 0.40, 0.26), Color(0.55, 0.16, 0.12), Color(0.20, 0.33, 0.52), Color(0.44, 0.52, 0.44)]
const DOORS := [Color(0.42, 0.27, 0.15), Color(0.13, 0.30, 0.21), Color(0.40, 0.13, 0.10), Color(0.16, 0.26, 0.42), Color(0.30, 0.20, 0.12)]
const GERANIUM := [Color(0.85, 0.10, 0.14), Color(0.92, 0.30, 0.45), Color(0.95, 0.92, 0.90), Color(0.80, 0.08, 0.22)]
const BRASS := Color(0.80, 0.64, 0.30)
const KR_RED := Color(0.72, 0.10, 0.10)
const KR_GOLD := Color(0.92, 0.72, 0.22)


static func make_material(key: String) -> Material:
	if KMASONRY.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://hut_masonry.gdshader")
		m.set_shader_parameter("style", KMASONRY[key])
		return m
	match key:
		"pane":
			var g := StandardMaterial3D.new()
			g.vertex_color_use_as_albedo = true
			g.vertex_color_is_srgb = true
			g.metallic = 0.15
			g.roughness = 0.1
			g.metallic_specular = 0.6
			return g
		"gold":
			var au := StandardMaterial3D.new()
			au.vertex_color_use_as_albedo = true
			au.vertex_color_is_srgb = true
			au.metallic = 1.0
			au.roughness = 0.3
			return au
		"enamel":
			var e := StandardMaterial3D.new()
			e.vertex_color_use_as_albedo = true
			e.vertex_color_is_srgb = true
			e.roughness = 0.32
			return e
		"leaf":
			var l := StandardMaterial3D.new()
			l.vertex_color_use_as_albedo = true
			l.vertex_color_is_srgb = true
			l.roughness = 0.9
			l.cull_mode = BaseMaterial3D.CULL_DISABLED
			return l
		"kwater":
			var wm := ShaderMaterial.new()
			wm.shader = load("res://kronburg_water.gdshader")
			return wm
		"hedge":
			var hm := ShaderMaterial.new()
			hm.shader = load("res://hedge.gdshader")
			return hm
	return YardKitBase.make_material(key)


static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _kmats.has(k):
			_kmats[k] = make_material(k)
		return _kmats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	return pk


## Commits a kit with tangents on the surfaces whose shaders read a normal map.
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in KTANGENTS:
		if kit.has(key):
			var s: SurfaceTool = kit[key]
			s.index()
			s.generate_tangents()
	# PropKit.commit, with each surface named after its key.
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
#  Helpers: wall frames, prisms in a wall's plane, clipping
# ======================================================================================

## A wall's frame: x along the wall (u), y up (v is the building's own y), z out of it; `o` the wall's foot at u = 0.
static func _wf(o: Vector3, out: Vector3) -> Transform3D:
	var u: Vector3 = Vector3.UP.cross(out).normalized()
	return Transform3D(Basis(u, Vector3.UP, out), o)


## An outline in a frame's x-y plane extruded along its z from d0 to d1: the face at d1 (and at d0 with `back`) and the rim.
## UVs in metres (times uvk): on the faces across and along `along` (so a timber's grain runs along it), round the rim
## (depth, distance along the outline).
static func _prism(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, ol: PackedVector2Array, d0: float, d1: float, col: Color,
		along := Vector2.ZERO, back := false, rim_abs := false) -> void:
	var n := ol.size()
	if n < 3:
		return
	var area: float = PropKit._signed_area(ol)
	if absf(area) < 1e-7:
		return
	var ccw := area > 0.0
	var tris := Geometry2D.triangulate_polygon(ol)
	var nf: Vector3 = wf.basis.z.normalized()
	var al: Vector2 = along.normalized() if along.length_squared() > 1e-8 else Vector2(0, 1)
	var pe := Vector2(al.y, -al.x)
	for i in range(0, tris.size(), 3):
		var a: Vector2 = ol[tris[i]]
		var b: Vector2 = ol[tris[i + 1]]
		var c: Vector2 = ol[tris[i + 2]]
		var ua := Vector2(a.dot(pe), a.dot(al)) * uvk
		var ub := Vector2(b.dot(pe), b.dot(al)) * uvk
		var uc := Vector2(c.dot(pe), c.dot(al)) * uvk
		pk.tri(kit, key, wf * Vector3(a.x, a.y, d1), wf * Vector3(b.x, b.y, d1), wf * Vector3(c.x, c.y, d1), nf, nf, nf, col, nf, ua, ub, uc)
		if back:
			pk.tri(kit, key, wf * Vector3(a.x, a.y, d0), wf * Vector3(b.x, b.y, d0), wf * Vector3(c.x, c.y, d0), -nf, -nf, -nf, col, -nf, ua, ub, uc)
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
		if rim_abs:
			# Masonry extruded upright (a plan's outline): u along the outline, v the depth itself (its height).
			pk.quad(kit, key, [wf * Vector3(p.x, p.y, d0), wf * Vector3(q.x, q.y, d0), wf * Vector3(q.x, q.y, d1), wf * Vector3(p.x, p.y, d1)], o3, col,
					[Vector2(run, d0) * uvk, Vector2(run + el, d0) * uvk, Vector2(run + el, d1) * uvk, Vector2(run, d1) * uvk])
		else:
			pk.quad(kit, key, [wf * Vector3(p.x, p.y, d0), wf * Vector3(q.x, q.y, d0), wf * Vector3(q.x, q.y, d1), wf * Vector3(p.x, p.y, d1)], o3, col,
					[Vector2(0.0, run) * uvk, Vector2(0.0, run + el) * uvk, Vector2(dd, run + el) * uvk, Vector2(dd, run) * uvk])
		run += el


## A frame `fw` wide round the inside of [u0, u1] x [v0, v1], standing d0..d1 off a wall: its front, its outer rim and the
## reveal inside it (24 triangles: four boxes would be 40).
static func _ring_rect(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, fw: float,
		d0: float, d1: float, col: Color) -> void:
	var o: Array = [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
	var i: Array = [Vector2(u0 + fw, v0 + fw), Vector2(u1 - fw, v0 + fw), Vector2(u1 - fw, v1 - fw), Vector2(u0 + fw, v1 - fw)]
	var nf: Vector3 = wf.basis.z.normalized()
	for k in range(4):
		var a: Vector2 = o[k]
		var b: Vector2 = o[(k + 1) % 4]
		var c: Vector2 = i[(k + 1) % 4]
		var d: Vector2 = i[k]
		pk.quad(kit, key, [wf * Vector3(a.x, a.y, d1), wf * Vector3(b.x, b.y, d1), wf * Vector3(c.x, c.y, d1), wf * Vector3(d.x, d.y, d1)], nf, col,
				[a * uvk, b * uvk, c * uvk, d * uvk])
		var e: Vector2 = (b - a).normalized()
		var on: Vector3 = (wf.basis * Vector3(e.y, -e.x, 0.0)).normalized()
		pk.quad(kit, key, [wf * Vector3(a.x, a.y, d0), wf * Vector3(b.x, b.y, d0), wf * Vector3(b.x, b.y, d1), wf * Vector3(a.x, a.y, d1)], on, col)
		pk.quad(kit, key, [wf * Vector3(d.x, d.y, d0), wf * Vector3(c.x, c.y, d0), wf * Vector3(c.x, c.y, d1), wf * Vector3(d.x, d.y, d1)], -on, col.darkened(0.12))


## A rectangle [u0, u1] x [v0, v1] standing from d0 to d1 off a wall (its grain along the longer side).
static func _rect(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, d0: float, d1: float,
		col: Color, back := false) -> void:
	if u1 - u0 < 1e-4 or v1 - v0 < 1e-4:
		return
	# Timber's grain runs along its length; everything else keeps the wall's (u, v), so masonry courses stay level.
	var al := Vector2(0, 1)
	if key == "timber" and (u1 - u0) >= (v1 - v0):
		al = Vector2(1, 0)
	_prism(pk, kit, key, wf, _rp(u0, v0, u1, v1), d0, d1, col, al, back)


## A flat face [u0, u1] x [v0, v1] at depth d in a wall frame, facing out of it, UVs (u, v) in metres.
static func _face(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, d: float, col: Color) -> void:
	if u1 - u0 < 1e-4 or v1 - v0 < 1e-4:
		return
	var n: Vector3 = wf.basis.z.normalized()
	pk.quad(kit, key, [wf * Vector3(u0, v0, d), wf * Vector3(u1, v0, d), wf * Vector3(u1, v1, d), wf * Vector3(u0, v1, d)], n, col,
			[Vector2(u0, v0) * uvk, Vector2(u1, v0) * uvk, Vector2(u1, v1) * uvk, Vector2(u0, v1) * uvk])


## A flat polygon at depth d in a wall frame, facing out, UVs (u, v) in metres.
static func _pface(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, ol: PackedVector2Array, d: float, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(ol)
	var n: Vector3 = wf.basis.z.normalized()
	for i in range(0, tris.size(), 3):
		var a: Vector2 = ol[tris[i]]
		var b: Vector2 = ol[tris[i + 1]]
		var c: Vector2 = ol[tris[i + 2]]
		pk.tri(kit, key, wf * Vector3(a.x, a.y, d), wf * Vector3(b.x, b.y, d), wf * Vector3(c.x, c.y, d), n, n, n, col, n, a * uvk, b * uvk, c * uvk)


static func _rp(u0: float, v0: float, u1: float, v1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])


## A band `w` wide along the line through a and b, running far past both.
static func _band(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var t: Vector2 = (b - a).normalized()
	var nn := Vector2(-t.y, t.x) * (w * 0.5)
	var e: Vector2 = t * 60.0
	return PackedVector2Array([a - e - nn, b + e - nn, b + e + nn, a - e + nn])


## The pieces of `poly` inside `area` (both convex or simple; holes dropped).
static func _clip(poly: PackedVector2Array, area: PackedVector2Array) -> Array:
	var out: Array = []
	for r in Geometry2D.intersect_polygons(poly, area):
		if (r as PackedVector2Array).size() >= 3 and absf(PropKit._signed_area(r)) > 1e-5:
			out.append(r)
	return out


## The union of a list of polygons (holes dropped).
static func _union(polys: Array) -> Array:
	var acc: Array = []
	for p in polys:
		var merged := false
		for i in range(acc.size()):
			var m := Geometry2D.merge_polygons(acc[i], p)
			if m.size() == 1:
				acc[i] = m[0]
				merged = true
				break
		if not merged:
			acc.append(p)
	return acc


## Timber pieces (polygons in a wall frame) standing TP off the infill, each with its grain along `along`.
static func _timbers(pk: PropKit, kit: Dictionary, wf: Transform3D, polys: Array, col: Color, along := Vector2(0, 1), d1 := TP) -> void:
	for p in polys:
		_prism(pk, kit, "timber", wf, _simplify(p), 0.0, d1, col, along)


## An outline without its near-duplicate points (closer than 1.5cm) and the points where it runs on almost straight:
## clipping leaves both, and every point is two more triangles round the rim.
static func _simplify(poly: PackedVector2Array) -> PackedVector2Array:
	var pts: Array = Array(poly)
	var changed := true
	while changed and pts.size() > 3:
		changed = false
		for i in range(pts.size()):
			var a: Vector2 = pts[(i - 1 + pts.size()) % pts.size()]
			var b: Vector2 = pts[i]
			var c: Vector2 = pts[(i + 1) % pts.size()]
			var ab: Vector2 = b - a
			var bc: Vector2 = c - b
			if ab.length() < 0.015 or absf(ab.normalized().cross(bc.normalized())) < 0.02 and ab.dot(bc) > 0.0:
				pts.remove_at(i)
				changed = true
				break
	return PackedVector2Array(pts)


## An axis-aligned block between two corners with masonry UVs: its sides as walls (u along, v up), its top too.
static func _wblock(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color, top := true, bottom := false) -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	wall(pk, kit, key, Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z), lo.y, hi.y, col, Vector3(0, 0, 1), lo.x)
	wall(pk, kit, key, Vector3(hi.x, 0, lo.z), Vector3(lo.x, 0, lo.z), lo.y, hi.y, col, Vector3(0, 0, -1), -hi.x)
	wall(pk, kit, key, Vector3(hi.x, 0, hi.z), Vector3(hi.x, 0, lo.z), lo.y, hi.y, col, Vector3(1, 0, 0), -hi.z)
	wall(pk, kit, key, Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), lo.y, hi.y, col, Vector3(-1, 0, 0), lo.z)
	if top:
		pk.quad(kit, key, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], Vector3.UP, col,
				[Vector2(lo.x, lo.z) * uvk, Vector2(hi.x, lo.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(lo.x, hi.z) * uvk])
	if bottom:
		pk.quad(kit, key, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)], Vector3.DOWN, col,
				[Vector2(lo.x, lo.z) * uvk, Vector2(lo.x, hi.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(hi.x, lo.z) * uvk])


## A small diamond (octahedron) at c: blossoms, knobs, fruit.
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


## A bush standing on c: a lumpy faceted mound r across, a second smaller one beside it.
static func _bush(pk: PropKit, kit: Dictionary, c: Vector3, r: float, col: Color, rng: RandomNumberGenerator) -> void:
	for k in range(2):
		var rr: float = r * (1.0 if k == 0 else 0.65)
		var off: Vector3 = Vector3.ZERO if k == 0 else Vector3(r * 0.55, 0, -r * 0.3)
		var prof: Array = [Vector2(0.001, -0.1), Vector2(rr * 0.8, -0.05), Vector2(rr * (1.0 + rng.randf() * 0.1), rr * 0.45),
				Vector2(rr * (0.85 + rng.randf() * 0.1), rr * 0.95), Vector2(rr * 0.45, rr * 1.25), Vector2(0.001, rr * 1.32)]
		pk.lathe(kit, "leaf", c + off, prof, 7, col.darkened(0.06 * float(k)), true, Basis(Vector3.UP, rng.randf() * TAU))


## A polyline tube through `pts` (radius r, `segs` sides), its joints overlapping.
static func _tube_path(pk: PropKit, kit: Dictionary, key: String, pts: Array, r: float, segs: int, col: Color) -> void:
	for i in range(pts.size() - 1):
		pk.tube(kit, key, pts[i], pts[i + 1], r, r, segs, col, i == 0 or i == pts.size() - 2)


## Catmull-Rom points through `ctrl` (closed or open), `per` samples a span.
static func _spline(ctrl: Array, per: int, closed: bool) -> Array:
	var out: Array = []
	var n: int = ctrl.size()
	var spans: int = n if closed else n - 1
	for i in range(spans):
		var p0 = ctrl[(i - 1 + n) % n] if (closed or i > 0) else ctrl[i]
		var p1 = ctrl[i]
		var p2 = ctrl[(i + 1) % n]
		var p3 = ctrl[(i + 2) % n] if (closed or i + 2 < n) else ctrl[(i + 1) % n]
		for k in range(per):
			var t: float = float(k) / float(per)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		out.append(ctrl[n - 1])
	else:
		out.append(out[0])
	return out


## Points along an arch from its left springing to its right one: round (a semicircle over `half`), pointed (two arcs
## of radius `half` * 2 * `sharp`, `sharp` 0.5 a round arch, 1 equilateral) or segmental (`rise` over the span).
static func _arch(cu: float, spring: float, half: float, kind: String, segs := 12, rise := 0.0, sharp := 0.8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		"round":
			for k in range(segs + 1):
				var a: float = PI - PI * float(k) / float(segs)
				pts.append(Vector2(cu + cos(a) * half, spring + sin(a) * half))
		"pointed":
			var r: float = half * 2.0 * sharp
			# Left arc centred right of the middle, right arc centred left of it; they meet over the middle.
			var cxl: float = cu - half + r
			var top_a: float = acos(clampf((cu - cxl) / r, -1.0, 1.0))
			var hs: int = maxi(segs / 2, 3)
			for k in range(hs + 1):
				var a: float = lerpf(PI, top_a, float(k) / float(hs))
				pts.append(Vector2(cxl + cos(a) * r, spring + sin(a) * r))
			var cxr: float = cu + half - r
			for k in range(1, hs + 1):
				var a2: float = lerpf(PI - top_a, 0.0, float(k) / float(hs))
				pts.append(Vector2(cxr + cos(a2) * r, spring + sin(a2) * r))
		_:
			var rr: float = (half * half + rise * rise) / (2.0 * maxf(rise, 0.01))
			var cy: float = spring + rise - rr
			var a0: float = atan2(spring - cy, -half)
			var a1: float = atan2(spring - cy, half)
			for k in range(segs + 1):
				var a3: float = lerpf(a0, a1, float(k) / float(segs))
				pts.append(Vector2(cu + cos(a3) * rr, cy + sin(a3) * rr))
	return pts


## The height of an arch's intrados (from `_arch`'s points) over u: the highest point at or near u.
static func _arch_height(pts: PackedVector2Array, u: float) -> float:
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if (u >= a.x and u <= b.x) or (u <= a.x and u >= b.x):
			var t: float = (u - a.x) / (b.x - a.x) if absf(b.x - a.x) > 1e-6 else 0.0
			return lerpf(a.y, b.y, t)
	return pts[0].y


## An arched ring (an arch's voussoirs, a window's surround): the band between the intrados `inner` and the same arch
## grown by `w`, standing d0..d1 off the wall, with its soffit (the inner rim) and its outer rim; and its jambs down to
## `foot` (the jambs as rectangles `w` wide) when foot < the springing.
static func _arch_ring(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, cu: float, spring: float, half: float, kind: String, w: float,
		d0: float, d1: float, col: Color, foot := NAN, segs := 12, rise := 0.0, sharp := 0.8) -> void:
	var inn := _arch(cu, spring, half, kind, segs, rise, sharp)
	var out: PackedVector2Array
	if kind == "pointed":
		out = _arch(cu, spring, half + w, kind, segs, 0.0, (half * 2.0 * sharp + w) / (2.0 * (half + w)))
	elif kind == "round":
		out = _arch(cu, spring, half + w, kind, segs)
	else:
		out = _arch(cu, spring, half + w, kind, segs, rise + w)
	var nf: Vector3 = wf.basis.z.normalized()
	for i in range(inn.size() - 1):
		var a: Vector2 = inn[i]
		var b: Vector2 = inn[i + 1]
		var c: Vector2 = out[i + 1]
		var d: Vector2 = out[i]
		pk.quad(kit, key, [wf * Vector3(a.x, a.y, d1), wf * Vector3(b.x, b.y, d1), wf * Vector3(c.x, c.y, d1), wf * Vector3(d.x, d.y, d1)], nf, col,
				[a * uvk, b * uvk, c * uvk, d * uvk])
		# Soffit (facing the opening) and the outer rim.
		var e: Vector2 = b - a
		var m: Vector2 = (a + b) * 0.5
		var ctr := Vector2(cu, spring)
		var o2: Vector2 = Vector2(e.y, -e.x).normalized()
		if o2.dot(ctr - m) < 0.0:
			o2 = -o2
		pk.quad(kit, key, [wf * Vector3(a.x, a.y, d0), wf * Vector3(b.x, b.y, d0), wf * Vector3(b.x, b.y, d1), wf * Vector3(a.x, a.y, d1)],
				(wf.basis * Vector3(o2.x, o2.y, 0)).normalized(), col.darkened(0.08))
		var f: Vector2 = c - d
		var o3: Vector2 = Vector2(f.y, -f.x).normalized()
		if o3.dot((c + d) * 0.5 - ctr) < 0.0:
			o3 = -o3
		pk.quad(kit, key, [wf * Vector3(d.x, d.y, d0), wf * Vector3(c.x, c.y, d0), wf * Vector3(c.x, c.y, d1), wf * Vector3(d.x, d.y, d1)],
				(wf.basis * Vector3(o3.x, o3.y, 0)).normalized(), col)
	if not is_nan(foot) and foot < spring - 0.01:
		_rect(pk, kit, key, wf, cu - half - w, foot, cu - half, spring, d0, d1, col)
		_rect(pk, kit, key, wf, cu + half, foot, cu + half + w, spring, d0, d1, col)


## A wall with arched openings cut out of it: the outline of [u0, u1] x [v0, v1] less each opening ([cu, half, spring,
## kind, foot]) that reaches its foot edge (an arcade, a gate), as one polygon, extruded d0..d1 (a slab with the openings'
## soffits as its rim) or (d0 == d1) a flat face.
static func _arcade_wall(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, ops: Array,
		d0: float, d1: float, col: Color, back := false) -> void:
	var ol := PackedVector2Array()
	ol.append(Vector2(u0, v0))
	var sorted_ops := ops.duplicate()
	sorted_ops.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for o in sorted_ops:
		var cu: float = o[0]
		var half: float = o[1]
		var spring: float = o[2]
		ol.append(Vector2(cu - half, v0))
		var arc := _arch(cu, spring, half, o[3], 14)
		for p in arc:
			ol.append(p)
		ol.append(Vector2(cu + half, v0))
	ol.append(Vector2(u1, v0))
	ol.append(Vector2(u1, v1))
	ol.append(Vector2(u0, v1))
	if d1 - d0 < 1e-4:
		_pface(pk, kit, key, wf, ol, d1, col)
	else:
		_prism(pk, kit, key, wf, ol, d0, d1, col, Vector2(0, 1), back)


# ======================================================================================
#  Half-timbered walls
# ======================================================================================

const PW := 0.2       # post width
const PLH := 0.2      # sill and head plate height
const RH := 0.16      # rail height
const BW := 0.17      # brace width


## One storey of a half-timbered wall in its frame `wf` (u from 0 to `length`, v the building's y, z out): the infill from
## v0 to v1, and over it the frame: a sill plate (`sill`), a head plate, corner posts, a post either side of every opening
## (`ops`: [u middle, width, bottom, top]), studs in wide panels, rails under and over the windows, St Andrew's crosses in
## the fields under them (`s.cross`), K braces beside the corner posts (a "halber Mann", `s.mann`) and on both sides of a
## stud in a wide panel (a "Mann"). `s`: beam, infill, infill_key, cross, mann. The openings' windows and doors are the
## caller's.
static func _fw_wall(pk: PropKit, kit: Dictionary, wf: Transform3D, length: float, v0: float, v1: float, ops: Array, s: Dictionary, sill := true,
		corners := true) -> void:
	var beam: Color = s["beam"]
	_face(pk, kit, s["infill_key"], wf, 0.0, v0, length, v1, 0.0, s["infill"])
	var vb: float = v0 + (PLH if sill else 0.0)
	var vt: float = v1 - PLH
	if sill:
		_rect(pk, kit, "timber", wf, 0.0, v0, length, vb, 0.0, TP, beam)
	_rect(pk, kit, "timber", wf, 0.0, vt, length, v1, 0.0, TP, beam)
	# Posts [u0, u1, kind]: 0 corner, 1 an opening's, 2 a stud.
	var posts: Array = []
	if corners:
		posts.append([0.0, PW, 0])
		posts.append([length - PW, length, 0])
	else:
		posts.append([-0.001, 0.0, 0])
		posts.append([length, length + 0.001, 0])
	for o in ops:
		var hw: float = float(o[1]) * 0.5
		for e in [[float(o[0]) - hw - PW, float(o[0]) - hw], [float(o[0]) + hw, float(o[0]) + hw + PW]]:
			var covered := false
			for p in posts:
				if float(e[0]) < float(p[1]) + 0.06 and float(e[1]) > float(p[0]) - 0.06:
					covered = true
			if not covered:
				posts.append([maxf(float(e[0]), 0.0), minf(float(e[1]), length), 1])
	posts.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	# Merge posts that leave less than a hand's width between them.
	var merged: Array = []
	for p in posts:
		if not merged.is_empty() and float(p[0]) < float(merged[-1][1]) + 0.22:
			merged[-1][1] = maxf(float(merged[-1][1]), float(p[1]))
			merged[-1][2] = mini(int(merged[-1][2]), int(p[2]))
		else:
			merged.append(p.duplicate())
	# Studs in wide panels without an opening.
	var full: Array = []
	for i in range(merged.size()):
		full.append(merged[i])
		if i == merged.size() - 1:
			break
		var a: float = merged[i][1]
		var b: float = merged[i + 1][0]
		var gap: float = s.get("stud_gap", 1.35)
		if _op_in(ops, a, b) < 0 and b - a > gap * 1.3:
			var m: int = int(ceil((b - a) / gap))
			var step: float = (b - a + PW) / float(m)
			for k in range(1, m):
				var c: float = a - PW * 0.5 + step * float(k)
				full.append([c - PW * 0.5, c + PW * 0.5, 2])
	for p in full:
		if float(p[1]) - float(p[0]) > 0.01:
			_rect(pk, kit, "timber", wf, p[0], vb, p[1], vt, 0.0, TP, beam)
	# The standard rail heights: under and over the first window.
	var r_lo: float = vb + 0.8
	var r_hi: float = -1.0
	for o in ops:
		if float(o[2]) > vb + 0.3:
			r_lo = o[2]
			r_hi = o[3]
			break
	for i in range(full.size() - 1):
		var a: float = full[i][1]
		var b: float = full[i + 1][0]
		if b - a < 0.05:
			continue
		var oi: int = _op_in(ops, a, b)
		if oi >= 0:
			var o: Array = ops[oi]
			var ob: float = o[2]
			var ot: float = o[3]
			if ob > vb + RH + 0.1:
				_rect(pk, kit, "timber", wf, a, ob - RH, b, ob, 0.0, TP, beam)
				if s.get("cross", false) and ob - RH - vb > 0.38:
					_timbers(pk, kit, wf, _cross(a, vb, b, ob - RH), beam)
			if ot < vt - RH - 0.12:
				_rect(pk, kit, "timber", wf, a, ot, b, ot + RH, 0.0, TP, beam)
			continue
		var kl: int = full[i][2]
		var kr: int = full[i + 1][2]
		var sm: bool = s.get("stud_mann", true)
		var brace_l: bool = s.get("mann", false) and (kl == 0 and corners or kl == 2 and sm)
		var brace_r: bool = s.get("mann", false) and (kr == 0 and corners or kr == 2 and sm)
		if (brace_l or brace_r) and b - a >= 0.5 and vt - vb >= 1.5:
			_timbers(pk, kit, wf, _kbraces(a, vb, b, vt, brace_l, brace_r), beam)
		else:
			if r_lo > vb + RH + 0.1 and r_lo < vt - 0.3:
				_rect(pk, kit, "timber", wf, a, r_lo - RH, b, r_lo, 0.0, TP, beam)
				if s.get("cross", false) and r_lo - RH - vb > 0.38 and b - a > 0.5:
					_timbers(pk, kit, wf, _cross(a, vb, b, r_lo - RH), beam)
			if r_hi > 0.0 and r_hi < vt - RH - 0.12 and s.get("rail_hi", true):
				_rect(pk, kit, "timber", wf, a, r_hi, b, r_hi + RH, 0.0, TP, beam)


## The opening whose panel is [a, b] (its posts' inner faces), or -1.
static func _op_in(ops: Array, a: float, b: float) -> int:
	for i in range(ops.size()):
		var o: Array = ops[i]
		var hw: float = float(o[1]) * 0.5
		if float(o[0]) - hw > a - 0.07 and float(o[0]) + hw < b + 0.07:
			return i
	return -1


## A St Andrew's cross filling the field [u0, u1] x [v0, v1] corner to corner, as one outline.
static func _cross(u0: float, v0: float, u1: float, v1: float) -> Array:
	var area := _rp(u0, v0, u1, v1)
	var parts: Array = []
	parts.append_array(_clip(_band(Vector2(u0, v0), Vector2(u1, v1), BW), area))
	parts.append_array(_clip(_band(Vector2(u0, v1), Vector2(u1, v0), BW), area))
	return _union(parts)


## K braces in the panel [u0, u1] x [v0, v1]: from the post on the left (and/or the right) at mid height, down to the sill
## and up to the head plate near the far post.
static func _kbraces(u0: float, v0: float, u1: float, v1: float, left: bool, right: bool) -> Array:
	var area := _rp(u0, v0, u1, v1)
	var vm: float = (v0 + v1) * 0.5
	var parts: Array = []
	var reach: float = minf(u1 - u0, 1.25)
	if left:
		parts.append_array(_clip(_band(Vector2(u0, vm), Vector2(u0 + reach - 0.08, v0), BW), area))
		parts.append_array(_clip(_band(Vector2(u0, vm), Vector2(u0 + reach - 0.08, v1), BW), area))
	if right:
		parts.append_array(_clip(_band(Vector2(u1, vm), Vector2(u1 - reach + 0.08, v0), BW), area))
		parts.append_array(_clip(_band(Vector2(u1, vm), Vector2(u1 - reach + 0.08, v1), BW), area))
	return _union(parts)


## A half-timbered gable in its wall frame: the triangle from (0, v0) to (span, v0) to the apex at (span / 2, apex) (the
## roof's underside), its infill, a sill plate, a rafter along each slope, a king post, posts beside the windows (`ops`),
## rails under and over them, a collar rail at `collar` (if it fits) and crosses under the windows (`s.cross`). Everything
## inside is clipped to the triangle under the rafters.
static func _fw_gable(pk: PropKit, kit: Dictionary, wf: Transform3D, span: float, v0: float, apex: float, ops: Array, s: Dictionary,
		collar := -1.0, king := true, king_top := -1.0) -> void:
	var beam: Color = s["beam"]
	var half: float = span * 0.5
	var tri := PackedVector2Array([Vector2(0, v0), Vector2(span, v0), Vector2(half, apex)])
	_pface(pk, kit, s["infill_key"], wf, tri, 0.0, s["infill"])
	var slope: float = (apex - v0) / half
	var cs: float = sqrt(1.0 + slope * slope)
	var rw: float = PW * cs      # the rafter's height measured upright
	# The sill plate, cut where the slopes meet it.
	_timbers(pk, kit, wf, _clip(_rp(0.0, v0, span, v0 + PLH), tri), beam, Vector2(1, 0))
	# The rafters along the slopes, meeting on the middle line.
	var lraft := PackedVector2Array([Vector2(0, v0), Vector2(half, apex), Vector2(half, apex - rw), Vector2(rw / slope, v0)])
	var rraft := PackedVector2Array([Vector2(span - rw / slope, v0), Vector2(half, apex - rw), Vector2(half, apex), Vector2(span, v0)])
	var above_sill := _rp(-1.0, v0 + PLH, span + 1.0, apex + 1.0)
	_timbers(pk, kit, wf, _clip(lraft, above_sill), beam, Vector2(half, apex - v0))
	_timbers(pk, kit, wf, _clip(rraft, above_sill), beam, Vector2(-half, apex - v0))
	var inner := PackedVector2Array([Vector2(rw / slope + PLH / slope, v0 + PLH), Vector2(span - rw / slope - PLH / slope, v0 + PLH), Vector2(half, apex - rw)])
	# Posts: the king post, the openings' posts, studs between.
	var posts: Array = []
	if king:
		posts.append([half - PW * 0.5, half + PW * 0.5])
	for o in ops:
		var hw: float = float(o[1]) * 0.5
		for e in [[float(o[0]) - hw - PW, float(o[0]) - hw], [float(o[0]) + hw, float(o[0]) + hw + PW]]:
			var covered := false
			for p in posts:
				if float(e[0]) < float(p[1]) + 0.06 and float(e[1]) > float(p[0]) - 0.06:
					covered = true
			if not covered:
				posts.append(e)
	posts.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	# Studs where the gable is wide enough between the outermost post and the rafter's foot.
	var studs: Array = []
	var lo_edge: float = rw / slope + PLH / slope
	if posts.is_empty():
		pass
	else:
		var first: float = posts[0][0]
		if first - lo_edge > 1.6:
			var c: float = lerpf(lo_edge, first, 0.5)
			studs.append([c - PW * 0.5, c + PW * 0.5])
		var last: float = posts[-1][1]
		if span - lo_edge - last > 1.6:
			var c2: float = lerpf(last, span - lo_edge, 0.5)
			studs.append([c2 - PW * 0.5, c2 + PW * 0.5])
	posts.append_array(studs)
	posts.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for p in posts:
		var top: float = apex + 1.0
		if king and absf((float(p[0]) + float(p[1])) * 0.5 - half) < 0.01 and king_top > 0.0:
			top = king_top
		_timbers(pk, kit, wf, _clip(_rp(p[0], v0 + PLH, p[1], top), inner), beam)
	# Rails between the posts (and from the outer posts to the rafters), cut to the triangle.
	var edges: Array = [lo_edge - 2.0]
	for p in posts:
		edges.append(p[0])
		edges.append(p[1])
	edges.append(span + 2.0)
	for i in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i + 1]
		if b - a < 0.05:
			continue
		var oi: int = _op_in(ops, a, b)
		if oi >= 0:
			var o: Array = ops[oi]
			if float(o[2]) > v0 + PLH + RH + 0.1:
				_timbers(pk, kit, wf, _clip(_rp(a, float(o[2]) - RH, b, o[2]), inner), beam, Vector2(1, 0))
				if s.get("cross", false) and float(o[2]) - RH - v0 - PLH > 0.38:
					_timbers(pk, kit, wf, _cross(a, v0 + PLH, b, float(o[2]) - RH), beam)
			_timbers(pk, kit, wf, _clip(_rp(a, o[3], b, float(o[3]) + RH), inner), beam, Vector2(1, 0))
		elif collar > 0.0:
			_timbers(pk, kit, wf, _clip(_rp(a, collar, b, collar + RH), inner), beam, Vector2(1, 0))
	if collar > 0.0 and king and king_top > 0.0:
		_timbers(pk, kit, wf, _clip(_rp(half - PW * 0.5, collar, half + PW * 0.5, collar + RH), inner), beam, Vector2(1, 0))
	if collar > 0.0:
		# The collar runs across the windows' panels too, above their lintel rails.
		for o in ops:
			if float(o[3]) + RH + 0.05 < collar:
				var hw2: float = float(o[1]) * 0.5
				_timbers(pk, kit, wf, _clip(_rp(float(o[0]) - hw2, collar, float(o[0]) + hw2, collar + RH), inner), beam, Vector2(1, 0))


# ======================================================================================
#  Windows, doors, flowers
# ======================================================================================

## A casement window in a wall frame: the opening [u - w/2, u + w/2] x [v0, v1]. Its frame (7cm wide, 5cm proud), the
## panes 2cm proud, glazing bars (a meeting stile and `rows` - 1 bars across, the stile cut between them), a sill under it,
## and, as `o` asks: "frame" colour, "casing" (a wide painted surround: the Bergisch houses), "sill" key and colour,
## "shutter" (a colour with alpha: folded-back shutters either side), "box" (a flower box of geraniums), "rows".
static func _win(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, w: float, o := {}) -> void:
	var fc: Color = o.get("frame", WIN_WHITE)
	var F := 0.07
	var x0: float = u - w * 0.5
	var x1: float = u + w * 0.5
	_face(pk, kit, "pane", wf, x0 + 0.03, v0 + 0.03, x1 - 0.03, v1 - 0.03, 0.02, o.get("glass", GLASS))
	_ring_rect(pk, kit, "painted", wf, x0, v0, x1, v1, F, 0.0, 0.05, fc)
	var rows: int = o.get("rows", 3)
	var gb := 0.04
	var ys: Array = [v0 + F]
	for r in range(1, rows):
		var y: float = lerpf(v0 + F, v1 - F, float(r) / float(rows))
		if rows == 2:
			y = lerpf(v0 + F, v1 - F, 0.64)
		_face(pk, kit, "painted", wf, x0 + F, y - gb * 0.5, x1 - F, y + gb * 0.5, 0.042, fc)
		ys.append(y - gb * 0.5)
		ys.append(y + gb * 0.5)
	ys.append(v1 - F)
	# The glazing bars are flat strips 2cm in front of the panes (the frame round them gives the depth).
	for k in range(0, ys.size(), 2):
		_face(pk, kit, "painted", wf, u - 0.03, ys[k], u + 0.03, ys[k + 1], 0.042, fc)
	if o.get("casing", false):
		var cw := 0.13
		var cc: Color = o.get("casing_col", WIN_WHITE)
		_rect(pk, kit, "painted", wf, x0 - cw, v0 - 0.02, x0, v1 + cw, 0.0, 0.035, cc)
		_rect(pk, kit, "painted", wf, x1, v0 - 0.02, x1 + cw, v1 + cw, 0.0, 0.035, cc)
		_rect(pk, kit, "painted", wf, x0, v1, x1, v1 + cw, 0.0, 0.035, cc)
		# A little cornice over it.
		_rect(pk, kit, "painted", wf, x0 - cw - 0.05, v1 + cw, x1 + cw + 0.05, v1 + cw + 0.07, 0.0, 0.08, cc)
	var sk: String = o.get("sill", "painted")
	var scol: Color = o.get("sill_col", fc)
	# The sill's top 1.5cm up the frame (inside it): level with the frame's foot it lay in the plane of the rail under it.
	_rect(pk, kit, sk, wf, x0 - 0.07, v0 - 0.07, x1 + 0.07, v0 + 0.015, 0.0, 0.1, scol)
	var sh: Color = o.get("shutter", Color(0, 0, 0, 0))
	if sh.a > 0.0:
		var lw: float = w * 0.5 + 0.02
		for sx in [-1.0, 1.0]:
			var a: float = (x0 - 0.03 - lw) if sx < 0.0 else (x1 + 0.03)
			var b: float = a + lw
			if o.get("casing", false):
				a += sx * 0.13
				b += sx * 0.13
			# In front of a stone surround's 6cm, apart from it.
			_rect(pk, kit, "painted", wf, a, v0 + 0.025, b, v1, 0.07, 0.1, sh)
			var ph: float = (v1 - v0 - 0.3) * 0.5
			_rect(pk, kit, "painted", wf, a + 0.08, v0 + 0.1, b - 0.08, v0 + 0.1 + ph, 0.1, 0.115, sh.lightened(0.12))
			_rect(pk, kit, "painted", wf, a + 0.08, v1 - 0.1 - ph, b - 0.08, v1 - 0.1, 0.1, 0.115, sh.lightened(0.12))
	if o.get("box", false):
		_flower_box(pk, kit, wf, u, v0 - 0.07, w + 0.1, o.get("bloom", GERANIUM[0]), int(absf(u * 37.0 + v0 * 11.0)))


## A flower box hanging under a window sill (its top at `v`): a planked box on two brackets, a mound of leaves and
## geranium heads in it.
static func _flower_box(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v: float, w: float, bloom: Color, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var x0: float = u - w * 0.5
	var x1: float = u + w * 0.5
	_rect(pk, kit, "timber", wf, x0, v - 0.3, x1, v - 0.06, 0.04, 0.3, Color(0.46, 0.31, 0.19), true)
	for sx in [x0 + 0.12, x1 - 0.12]:
		pk.beam(kit, "steel", wf * Vector3(sx, v - 0.55, 0.01), wf * Vector3(sx, v - 0.3, 0.26), 0.03, 0.03, CAST)
	# The leaves: a low hump along the box.
	var hump := PackedVector2Array()
	var n := 9
	for k in range(n + 1):
		var t: float = float(k) / float(n)
		hump.append(Vector2(lerpf(x0 + 0.02, x1 - 0.02, t), v - 0.06 + (0.14 + 0.05 * sin(t * 17.0 + float(seed_v))) * sin(t * PI)))
	hump.append(Vector2(x1 - 0.02, v - 0.07))
	hump.append(Vector2(x0 + 0.02, v - 0.07))
	_prism(pk, kit, "leaf", wf, hump, 0.07, 0.29, Color(0.22, 0.40, 0.18), Vector2(1, 0), true)
	# Leaves trailing over the front.
	for k in range(int(w / 0.3)):
		var lu: float = lerpf(x0 + 0.1, x1 - 0.1, (float(k) + rng.randf()) / maxf(float(int(w / 0.3)), 1.0))
		_blob(pk, kit, "leaf", wf * Vector3(lu, v - 0.12 - rng.randf() * 0.12, 0.31), (wf.basis * Vector3(0.07, 0.06, 0.03)).abs(), Color(0.24, 0.44, 0.2))
	# Flower heads on top and along the front.
	var heads: int = int(w / 0.18)
	for k in range(heads):
		var hu: float = lerpf(x0 + 0.08, x1 - 0.08, (float(k) + 0.5) / float(heads)) + rng.randf_range(-0.04, 0.04)
		var c: Vector3 = wf * Vector3(hu, v + 0.05 + rng.randf() * 0.1, rng.randf_range(0.12, 0.28))
		_blob(pk, kit, "leaf", c, Vector3(0.06, 0.05, 0.06), bloom.lightened(rng.randf_range(-0.08, 0.1)))


## A front door: a panelled leaf [u - w/2, u + w/2] x [v0, v0 + h] 3.5cm proud, a transom light over it (`transom`
## metres, 0 for none), a surround (`sur_key`, `sur_col`) 20cm wide and 10cm proud with a keystone, a brass knob, and steps
## from the sill v0 down to `ground` (they run on a metre under it, for a street falling away).
static func _door(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, h: float, col: Color, sur_key: String, sur_col: Color,
		ground: float, transom := 0.4, glazed := false) -> void:
	var x0: float = u - w * 0.5
	var x1: float = u + w * 0.5
	if glazed:
		_rect(pk, kit, "painted", wf, x0, v0, x1, v0 + h, 0.0, 0.035, col)
		_face(pk, kit, "pane", wf, x0 + 0.12, v0 + h * 0.36, x1 - 0.12, v0 + h - 0.12, 0.045, GLASS)
		_rect(pk, kit, "painted", wf, x0 + 0.12, v0 + 0.12, x1 - 0.12, v0 + h * 0.32, 0.035, 0.05, col.lightened(0.1))
	else:
		_rect(pk, kit, "painted", wf, x0, v0, x1, v0 + h, 0.0, 0.035, col)
		var pw: float = (w - 0.3) * 0.5
		for cx in [x0 + 0.1, x0 + 0.2 + pw]:
			_rect(pk, kit, "painted", wf, cx, v0 + 0.15, cx + pw, v0 + h * 0.42, 0.035, 0.052, col.lightened(0.09))
			_rect(pk, kit, "painted", wf, cx, v0 + h * 0.5, cx + pw, v0 + h - 0.12, 0.035, 0.052, col.lightened(0.09))
	pk.tube(kit, "gold", wf * Vector3(u + w * 0.34, v0 + 1.0, 0.035), wf * Vector3(u + w * 0.34, v0 + 1.0, 0.1), 0.03, 0.035, 8, BRASS)
	var top: float = v0 + h
	if transom > 0.0:
		_rect(pk, kit, "painted", wf, x0, top, x1, top + 0.06, 0.0, 0.05, WIN_WHITE)
		_face(pk, kit, "pane", wf, x0, top + 0.06, x1, top + transom, 0.02, GLASS)
		for k in range(1, 4):
			var bx: float = lerpf(x0, x1, float(k) / 4.0)
			_rect(pk, kit, "painted", wf, bx - 0.02, top + 0.06, bx + 0.02, top + transom, 0.02, 0.04, WIN_WHITE)
		top += transom
	var sw := 0.2
	_rect(pk, kit, sur_key, wf, x0 - sw, v0, x0, top, 0.0, 0.1, sur_col)
	_rect(pk, kit, sur_key, wf, x1, v0, x1 + sw, top, 0.0, 0.1, sur_col)
	_rect(pk, kit, sur_key, wf, x0 - sw - 0.04, top, x1 + sw + 0.04, top + 0.24, 0.0, 0.12, sur_col)
	_rect(pk, kit, sur_key, wf, u - 0.13, top - 0.06, u + 0.13, top + 0.28, 0.12, 0.15, sur_col.lightened(0.08))
	_steps(pk, kit, wf, u, v0, w + 0.7, ground)


## Stone steps up to a sill at v0 from `ground`, centred on u, `w` wide; each lower step 28cm further out and 10cm wider.
static func _steps(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, ground: float, col := SANDSTONE) -> void:
	var rise: float = v0 - ground
	if rise < 0.05:
		return
	var n: int = maxi(1, int(ceil(rise / 0.19 - 0.01)))
	var sh: float = rise / float(n)
	var d0 := 0.0
	for k in range(n):
		# The top tread 2cm under the sill: level with it, it shared its plane with the sill plate's top.
		var top: float = v0 - sh * float(k) - (0.02 if k == 0 else 0.0)
		var d1: float = 0.28 * float(k + 1) + 0.04
		var hw: float = w * 0.5 + 0.05 * float(k)
		_rect(pk, kit, "ashlar", wf, u - hw, ground - 1.0, u + hw, top, d0, d1, col.lightened(0.04 - 0.03 * float(k % 2)))
		d0 = d1


# ======================================================================================
#  Roofs
# ======================================================================================

## A pitched roof in the frame `rf` (x across from wall to wall, 0 to `span`; y up; z along the ridge from z0 to z1, the
## gables), on walls whose plates are at y = yp: two planes in `key` (biber, slate) over boarded undersides 9cm below,
## overhanging the eaves by `oh` and the gables by `verge`; a ridge roll, verge boards along the four rakes, fascias and
## gutters. Returns {ridge, top0, t, eave, za, zb}: the top surface is top0 + t * x up from either eave wall.
static func _roof(pk: PropKit, kit: Dictionary, rf: Transform3D, span: float, z0: float, z1: float, yp: float, pitch: float, oh: float, verge: float,
		key: String, col: Color, trim: Color, gutters := true, ends := 3) -> Dictionary:
	var t: float = tan(deg_to_rad(pitch))
	var half: float = span * 0.5
	var top0: float = yp + 0.08
	var eave: float = top0 - t * oh
	var ridge: float = top0 + t * half
	# `ends`: bit 1 the z0 gable, bit 2 the z1 gable get the verge and its boards (an end that runs into a wall or
	# another roof gets neither).
	var za: float = z0 - (verge if ends & 1 else 0.0)
	var zb: float = z1 + (verge if ends & 2 else 0.0)
	var nl: Vector3 = (rf.basis * Vector3(-t, 1.0, 0.0)).normalized()
	var nr: Vector3 = (rf.basis * Vector3(t, 1.0, 0.0)).normalized()
	var dn := Vector3(0, -0.09, 0)
	var board := Color(0.50, 0.36, 0.24)
	# Left (x < half) and right planes, u along the eave and v up the slope.
	roof(pk, kit, key, rf * Vector3(-oh, eave, zb), rf * Vector3(-oh, eave, za), rf * Vector3(half, ridge, za), rf * Vector3(half, ridge, zb), col, nl, false)
	roof(pk, kit, key, rf * Vector3(span + oh, eave, za), rf * Vector3(span + oh, eave, zb), rf * Vector3(half, ridge, zb), rf * Vector3(half, ridge, za), col, nr, false)
	roof(pk, kit, "lapboards", rf * Vector3(-oh, eave - 0.09, za), rf * Vector3(-oh, eave - 0.09, zb), rf * Vector3(half, ridge - 0.09, zb), rf * Vector3(half, ridge - 0.09, za), board, -nl, false)
	roof(pk, kit, "lapboards", rf * Vector3(span + oh, eave - 0.09, zb), rf * Vector3(span + oh, eave - 0.09, za), rf * Vector3(half, ridge - 0.09, za), rf * Vector3(half, ridge - 0.09, zb), board, -nr, false)
	# The ridge: rounded ridge tiles, or a slate roll.
	var rr: float = 0.12 if key == "biber" else 0.08
	pk.tube(kit, "paint" if key != "biber" else "matte", rf * Vector3(half, ridge + rr * 0.35, za - 0.02), rf * Vector3(half, ridge + rr * 0.35, zb + 0.02), rr, rr, 6,
			col.darkened(0.12) if key == "biber" else SLATE.darkened(0.2), true)
	# Fascias along the eaves (covering the roof's edge), gutters and their hangers.
	# The fascias stop inside the verge boards (their ends had lain in the boards' faces).
	var fa: float = za + (0.06 if ends & 1 else 0.0)
	var fb: float = zb - (0.06 if ends & 2 else 0.0)
	for side in [-1.0, 1.0]:
		var ex: float = -oh if side < 0.0 else span + oh
		var fx: float = ex + side * 0.025
		pk.block(kit, "timber", rf * Vector3(minf(fx - 0.025, fx + 0.025), eave - 0.24, fa), rf * Vector3(maxf(fx - 0.025, fx + 0.025), eave + 0.015, fb), trim, uvk)
		if gutters:
			var gx: float = ex + side * 0.12
			pk.tube(kit, "metal", rf * Vector3(gx, eave - 0.2, za + 0.05), rf * Vector3(gx, eave - 0.2, zb - 0.05), 0.075, 0.075, 6, Color(0.55, 0.57, 0.55), true)
	# Verge boards along the rakes of both gables: standing 3cm over the tiles, 26cm deep.
	for g in [[zb, 1.0, 2], [za, -1.0, 1]]:
		if not (ends & int(g[2])):
			continue
		var gz: float = g[0]
		var sg: float = g[1]
		var vf := Transform3D(rf.basis * Basis(Vector3(sg, 0, 0), Vector3.UP, Vector3(0, 0, sg)), rf * Vector3(0, 0, gz))
		for side2 in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			var xa: float = -oh - 0.05
			var xb: float = half
			# In the board frame u = sg * x.
			var top_a := Vector2(xa, eave + 0.03 - t * 0.05)
			var top_b := Vector2(xb, ridge + 0.03)
			pts.append(top_a)
			pts.append(Vector2(xa, top_a.y - 0.26))
			pts.append(Vector2(xb, ridge + 0.03 - 0.26))
			pts.append(top_b)
			var ol := PackedVector2Array()
			for p in pts:
				var x: float = p.x if side2 < 0.0 else span - p.x
				ol.append(Vector2(sg * x, p.y))
			_prism(pk, kit, "timber", vf, ol, -0.05, 0.0, trim, Vector2(1, t).normalized())
	return {"ridge": ridge, "top0": top0, "t": t, "eave": eave, "za": za, "zb": zb}


## A chimney through a roof at (x, z) in the frame `rf`: brick from under the roof's surface (`y_in`) to `top`, a stone cap.
static func _chimney(pk: PropKit, kit: Dictionary, rf: Transform3D, x: float, z: float, y_in: float, top: float, plaster := false) -> void:
	var key: String = "plaster" if plaster else "kbrick"
	var col: Color = Color(0.86, 0.84, 0.80) if plaster else BRICK
	_wblock(pk, kit, key, rf * Vector3(x - 0.32, y_in, z - 0.4), rf * Vector3(x + 0.32, top, z + 0.4), col)
	_wblock(pk, kit, "ashlar", rf * Vector3(x - 0.4, top, z - 0.48), rf * Vector3(x + 0.4, top + 0.12, z + 0.48), SANDSTONE)
	for dz in [-0.18, 0.18]:
		pk.tube(kit, "matte", rf * Vector3(x, top + 0.12, z + dz), rf * Vector3(x, top + 0.4, z + dz), 0.09, 0.08, 6, Color(0.5, 0.25, 0.18), true)


# ======================================================================================
#  Half-timbered houses
# ======================================================================================

const SHOPS := [
	["Bäckerei Brinkmann", "pretzel", [Color(0.95, 0.90, 0.78), Color(0.55, 0.32, 0.18)], Color(0.38, 0.22, 0.12)],
	["Metzgerei Kötter", "ox", [Color(0.92, 0.92, 0.9), Color(0.70, 0.10, 0.10)], Color(0.55, 0.10, 0.08)],
	["Kronen-Apotheke", "apotheke", [Color(0.94, 0.94, 0.9), Color(0.16, 0.42, 0.28)], Color(0.14, 0.34, 0.24)],
	["Café Lamberti", "cup", [Color(0.95, 0.92, 0.82), Color(0.12, 0.36, 0.24)], Color(0.12, 0.28, 0.20)],
	["Buchhandlung Overkamp", "book", [Color(0.94, 0.94, 0.92), Color(0.16, 0.28, 0.52)], Color(0.14, 0.22, 0.40)],
]

## The colours and choices for a house of variant v (0 white and black, 1 coloured on a stone ground floor, 2 Bergisch
## slate, 3 a shop, 4 eaves to the street).
static func _house_style(v: int, rng: RandomNumberGenerator) -> Dictionary:
	var s := {
		"beam": BEAM_BLACK, "infill": INFILL_WHITE, "infill_key": "plaster", "roof_key": "biber", "roof": BIBERS[rng.randi() % BIBERS.size()],
		"ground": "fw", "jetty": rng.randf_range(0.32, 0.45), "gjetty": 0.22, "cross": rng.randf() < 0.75, "mann": true,
		"shutter": Color(0, 0, 0, 0), "boxes": rng.randf_range(0.2, 0.6), "frame": WIN_WHITE, "door": DOORS[rng.randi() % DOORS.size()],
		"pitch": rng.randf_range(50.0, 56.0), "casing": false, "shop": -1, "hoist": rng.randf() < 0.55, "trim": BEAM_BLACK,
		"stone_key": "ashlar", "stone": SANDSTONE.lerp(RUBBLE, rng.randf()), "bloom": GERANIUM[rng.randi() % GERANIUM.size()],
	}
	match v:
		0:
			if rng.randf() < 0.3:
				s["beam"] = Color(0.24, 0.15, 0.10)
		1:
			s["infill"] = INFILLS[rng.randi() % INFILLS.size()]
			s["beam"] = OXBLOOD if rng.randf() < 0.55 else BEAM_BROWN
			s["ground"] = "stone"
			s["stone_key"] = "ashlar" if rng.randf() < 0.6 else "stone"
			s["shutter"] = SHUTTERS[rng.randi() % SHUTTERS.size()] if rng.randf() < 0.5 else Color(0, 0, 0, 0)
		2:
			s["infill_key"] = "kslate"
			s["infill"] = SLATE.lightened(rng.randf_range(-0.05, 0.05))
			s["roof_key"] = "kslate"
			s["roof"] = SLATE.darkened(0.05)
			s["ground"] = "slate"
			s["jetty"] = rng.randf_range(0.12, 0.2)
			s["gjetty"] = 0.0
			s["shutter"] = BERG_GREEN
			s["casing"] = true
			s["door"] = BERG_GREEN if rng.randf() < 0.6 else WIN_WHITE.darkened(0.05)
			s["trim"] = WIN_WHITE
			s["hoist"] = false
			s["boxes"] = 0.15
		3:
			s["shop"] = rng.randi() % SHOPS.size()
			s["ground"] = "shop"
			if rng.randf() < 0.5:
				s["infill"] = INFILLS[rng.randi() % INFILLS.size()]
				s["beam"] = OXBLOOD if rng.randf() < 0.5 else BEAM_BROWN
		4:
			if rng.randf() < 0.5:
				s["infill"] = INFILLS[rng.randi() % INFILLS.size()]
				s["beam"] = OXBLOOD if rng.randf() < 0.5 else BEAM_BROWN
			s["ground"] = "stone" if rng.randf() < 0.4 else "fw"
			s["pitch"] = rng.randf_range(48.0, 54.0)
	if v != 2:
		s["trim"] = s["beam"]
	return s


## How far a house of these parameters reaches out past its ground-floor front (z = 0) toward the street (+z), life size:
## "steps" its front steps (on the ground; a shop's awning reaches as far, 2.2m up), "upper" its jettied storeys and the
## roof's verge or eaves over them (from about 3.4m up), "max" anything at all (the gable's hoist beam near the apex, a
## shop's guild sign at the first floor). The jetty is drawn per house (0.32-0.45m a storey; Bergisch 0.12-0.2m): these
## are the most it can be.
static func house_extent(floors: int, variant: int) -> Dictionary:
	var v: int = variant % 5
	var n: int = clampi(floors, 2, 4)
	var j: float = 0.2 if v == 2 else 0.45
	var upper: float = j * float(n - 1) + (0.55 + 0.3 if v == 4 else (0.0 if v == 2 else 0.22) + 0.32 + 0.06)
	# Five steps up to a door sill at 0.8m (half-timbered or slate ground floors), three to a stone ground floor's 0.45m;
	# a shop's four steps and its awning 1.25m.
	var steps: float = [1.45, 0.9, 1.45, 1.25, 1.45][v]
	var most: float = maxf(upper, steps)
	if v == 3:
		most = maxf(most, j + 1.25)
	if v != 2 and v != 4:
		most = maxf(most, j * float(n - 1) + 0.22 + 1.0)
	return {"steps": steps, "upper": upper, "max": most}


## A half-timbered town house (Fachwerkhaus) `w` wide along the street and `d` deep, `floors` (2-4) full storeys under a
## steep roof, built in its frame (see the file's header). `variant` % 5: 0 white infill and black beams under red plain
## tiles; 1 coloured infill and oxblood or brown beams over a stone ground floor; 2 a Bergisch house hung with slate
## (white windows, green shutters, a slate roof); 3 a shop on the ground floor (a shop window, an awning, a hanging guild
## sign, its name on a board: Bäckerei, Metzgerei, Apotheke, Café, Buchhandlung); 4 eaves to the street with a row of
## dormers. The other four turn their gable to the street. Upper storeys jetty out over the street (`house_extent`); the
## footings run down to FOOT.
static func fachwerk_house(pk: PropKit, kit: Dictionary, w: float, d: float, floors: int, variant: int, rng: RandomNumberGenerator, labels: Array) -> void:
	var v: int = variant % 5
	var s := _house_style(v, rng)
	var n: int = clampi(floors, 2, 4)
	var J: float = s["jetty"]
	var hu: float = rng.randf_range(2.55, 2.75)
	var fz := 0.24
	var h0: float = 3.4 if v == 3 else 3.2
	var pl := 0.6
	# Storeys: [y0, y1, front z].
	var st: Array = [[0.0, h0, 0.0]]
	for k in range(1, n):
		var y0: float = float(st[k - 1][1]) + fz
		st.append([y0, y0 + hu, J * float(k)])
	var ye: float = st[n - 1][1]
	var zt: float = st[n - 1][2]
	if v == 4:
		_house_trauf(pk, kit, w, d, s, st, fz, pl, rng, labels)
		return
	var yg: float = ye + fz
	var zg: float = zt + float(s["gjetty"])
	# Window columns across the front.
	var ncol: int = clampi(int((w - 0.6) / 2.05), 2, 4)
	var ww: float = rng.randf_range(0.82, 1.0)
	var cols: Array = []
	for i in range(ncol):
		cols.append(w * (float(i) + 0.5) / float(ncol))
	var door_col: int = 0 if rng.randf() < 0.5 else ncol - 1
	_ground_floor(pk, kit, w, d, s, st[0], pl, cols, ww, door_col, rng, labels)
	# Upper storeys: front, sides, back.
	for k in range(1, n):
		var y0: float = st[k][0]
		var y1: float = st[k][1]
		var zf: float = st[k][2]
		var wb: float = y0 + PLH + 0.78
		var wt: float = y1 - PLH
		var ops: Array = []
		for c in cols:
			ops.append([c, ww, wb, wt])
		var fwf := _wf(Vector3(0, 0, zf), Vector3(0, 0, 1))
		_storey_wall(pk, kit, fwf, w, y0, y1, ops, s, true)
		for o in ops:
			_win(pk, kit, fwf, o[0], o[2], o[3], ww, _win_opts(s, rng))
		# Floor zone under this storey: beam heads over the jetty.
		_floor_zone(pk, kit, w, d, s, float(st[k - 1][1]), y0, float(st[k - 1][2]), zf)
		# The sides: a window or two.
		var length: float = d + zf
		var side_ops: Array = []
		var ns: int = 1 if d < 9.5 else 2
		for i in range(ns):
			side_ops.append([length * (float(i) + 0.5) / float(ns) + 0.3, 0.8, wb, wt])
		for side in [-1.0, 1.0]:
			var swf: Transform3D = _wf(Vector3(w, 0, zf), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(0, 0, -d), Vector3(-1, 0, 0))
			var sops: Array = side_ops if side > 0.0 else _mirror_ops(side_ops, length)
			_storey_wall(pk, kit, swf, length, y0, y1, sops, s, true, true)
			for o in sops:
				_win(pk, kit, swf, o[0], o[2], o[3], 0.8, _win_opts(s, rng, false))
		# The back.
		var bwf := _wf(Vector3(w, 0, -d), Vector3(0, 0, -1))
		var bops: Array = [[w * 0.3, 0.8, wb, wt], [w * 0.72, 0.8, wb, wt]]
		_storey_wall(pk, kit, bwf, w, y0, y1, bops, s, true, true)
		for o in bops:
			_win(pk, kit, bwf, o[0], o[2], o[3], 0.8, _win_opts(s, rng, false))
	# The attic floor zone, the gables and the roof.
	_floor_zone(pk, kit, w, d, s, ye, yg, zt, zg)
	var t: float = tan(deg_to_rad(float(s["pitch"])))
	var apex: float = yg - 0.01 + t * w * 0.5
	var gs: Dictionary = s.duplicate()
	gs["infill"] = s["infill"]
	var gwf := _wf(Vector3(0, 0, zg), Vector3(0, 0, 1))
	var gw := 0.7
	var gb: float = yg + PLH + 0.55
	var gt: float = gb + 0.95
	# Either side of the king post (the casings of a slate-hung gable's windows need room between them).
	var go: float = PW * 0.5 + gw * 0.5 + (0.25 if s["casing"] else 0.0)
	var gops: Array = [[w * 0.5 - go, gw, gb, gt], [w * 0.5 + go, gw, gb, gt]]
	var collar: float = gt + RH + 0.35
	var hoist: bool = s["hoist"] and apex - collar > 2.3
	if s["infill_key"] == "kslate":
		_slate_gable(pk, kit, gwf, w, yg, apex, s)
	else:
		_fw_gable(pk, kit, gwf, w, yg, apex, gops, gs, collar if apex - collar > 1.0 else -1.0, true, collar if hoist else -1.0)
	for o in gops:
		_win(pk, kit, gwf, o[0], o[2], o[3], gw, _win_opts(s, rng, false))
	if hoist:
		# A loading hatch under the hoist beam at the top of the gable.
		var hb: float = collar + RH
		var hh: float = minf(1.05, apex - hb - 1.25)
		var hw := 0.8
		if hh > 0.6:
			# Its frame, cut to the gable under the rafters (as _fw_gable's own timbers are).
			var sl: float = (apex - yg) / (w * 0.5)
			var rwv: float = PW * sqrt(1.0 + sl * sl)
			var inner := PackedVector2Array([Vector2((rwv + PLH) / sl, yg + PLH), Vector2(w - (rwv + PLH) / sl, yg + PLH), Vector2(w * 0.5, apex - rwv)])
			_timbers(pk, kit, gwf, _clip(_rp(w * 0.5 - hw * 0.5 - PW, hb, w * 0.5 - hw * 0.5, hb + hh + PW), inner), s["beam"])
			_timbers(pk, kit, gwf, _clip(_rp(w * 0.5 + hw * 0.5, hb, w * 0.5 + hw * 0.5 + PW, hb + hh + PW), inner), s["beam"])
			_timbers(pk, kit, gwf, _clip(_rp(w * 0.5 - hw * 0.5, hb + hh, w * 0.5 + hw * 0.5, hb + hh + PW), inner), s["beam"], Vector2(1, 0))
			_rect(pk, kit, "painted", gwf, w * 0.5 - hw * 0.5, hb, w * 0.5 + hw * 0.5, hb + hh, 0.0, 0.04, s["door"])
			for k in range(1, 4):
				var by: float = hb + hh * float(k) / 4.0
				_rect(pk, kit, "painted", gwf, w * 0.5 - hw * 0.5 + 0.05, by - 0.03, w * 0.5 + hw * 0.5 - 0.05, by + 0.03, 0.04, 0.06, s["door"].darkened(0.2))
			var by2: float = minf(hb + hh + PW + 0.35, apex - 0.55)
			pk.block(kit, "timber", Vector3(w * 0.5 - 0.11, by2 - 0.13, zg - 0.3), Vector3(w * 0.5 + 0.11, by2 + 0.13, zg + 1.0), s["beam"], uvk)
			pk.tube(kit, "steel", Vector3(w * 0.5 - 0.04, by2 - 0.2, zg + 0.85), Vector3(w * 0.5 + 0.04, by2 - 0.2, zg + 0.85), 0.11, 0.11, 10, CAST)
			pk.beam(kit, "steel", Vector3(w * 0.5, by2 - 0.13, zg + 0.85), Vector3(w * 0.5, by2 - 0.85, zg + 0.85), 0.015, 0.015, CAST)
			pk.tube(kit, "steel", Vector3(w * 0.5, by2 - 0.85, zg + 0.85), Vector3(w * 0.5, by2 - 1.0, zg + 0.88), 0.03, 0.01, 6, CAST)
	# The back gable: plainer.
	var bgwf := _wf(Vector3(w, 0, -d), Vector3(0, 0, -1))
	if s["infill_key"] == "kslate":
		_slate_gable(pk, kit, bgwf, w, yg, apex, s)
	else:
		_fw_gable(pk, kit, bgwf, w, yg, apex, [[w * 0.5 + 0.4, 0.6, gb, gb + 0.8]], s, collar if apex - collar > 1.0 else -1.0)
		_win(pk, kit, bgwf, w * 0.5 + 0.4, gb, gb + 0.8, 0.6, _win_opts(s, rng, false))
	var rf := Transform3D(Basis(), Vector3.ZERO)
	var r := _roof(pk, kit, rf, w, -d, zg, yg, s["pitch"], 0.38, 0.32, s["roof_key"], s["roof"], s["trim"])
	_chimney(pk, kit, rf, w * 0.5 + (0.0 if rng.randf() < 0.5 else w * 0.18), -d * rng.randf_range(0.45, 0.7), yg + 0.5, float(r["ridge"]) + 0.9,
			s["infill_key"] == "kslate")
	# A downpipe at each back corner, from the gutter down the corner.
	for side3 in [-1.0, 1.0]:
		var gx: float = -0.5 if side3 < 0.0 else w + 0.5
		var px: float = -0.09 if side3 < 0.0 else w + 0.09
		var ey: float = r["eave"]
		_tube_path(pk, kit, "metal", [Vector3(gx, ey - 0.22, -d + 0.2), Vector3(gx, ey - 0.45, -d + 0.2), Vector3(px, ey - 0.85, -d + 0.2),
				Vector3(px, -0.3, -d + 0.2)], 0.05, 6, Color(0.55, 0.57, 0.55))


## The window options for this house: its frame colour, casing, shutters and (now and then) a flower box.
static func _win_opts(s: Dictionary, rng: RandomNumberGenerator, front := true) -> Dictionary:
	var o := {"frame": s["frame"], "casing": s["casing"], "rows": 3 if front else 2}
	if s["casing"]:
		o["frame"] = WIN_WHITE
	if front and (s["shutter"] as Color).a > 0.0:
		o["shutter"] = s["shutter"]
	if front and rng.randf() < float(s["boxes"]):
		o["box"] = true
		o["bloom"] = s["bloom"]
	return o


## Openings mirrored along a wall of length L (for the wall on the other side, whose u runs the other way).
static func _mirror_ops(ops: Array, length: float) -> Array:
	var out: Array = []
	for o in ops:
		var m: Array = o.duplicate()
		m[0] = length - float(o[0])
		out.append(m)
	return out


## One storey's wall: half-timbered, or slate-hung (the Bergisch houses: slate from v0 to v1 behind the windows).
static func _storey_wall(pk: PropKit, kit: Dictionary, wf: Transform3D, length: float, v0: float, v1: float, ops: Array, s: Dictionary, sill: bool, plain := false) -> void:
	if s["infill_key"] == "kslate":
		_face(pk, kit, "kslate", wf, 0.0, v0, length, v1, 0.0, s["infill"])
		return
	var ss: Dictionary = s
	if plain:
		ss = s.duplicate()
		ss["cross"] = false
		ss["stud_mann"] = false
		ss["stud_gap"] = 2.0
		ss["rail_hi"] = false
	_fw_wall(pk, kit, wf, length, v0, v1, ops, ss, sill)


## A slate-hung gable: the triangle in slate, with white corner boards along its rakes.
static func _slate_gable(pk: PropKit, kit: Dictionary, wf: Transform3D, span: float, v0: float, apex: float, s: Dictionary) -> void:
	_pface(pk, kit, "kslate", wf, PackedVector2Array([Vector2(0, v0), Vector2(span, v0), Vector2(span * 0.5, apex)]), 0.0, s["infill"])


## The floor zone between a storey's top (ya) and the next one's foot (yb): the beam heads standing out from the lower
## front (za) to the upper one (zb), a filler between them, the jetty's boarded underside, and curved brackets (Knaggen)
## under the corner heads; on the sides a solid beam. Without a jetty a plain band.
static func _floor_zone(pk: PropKit, kit: Dictionary, w: float, d: float, s: Dictionary, ya: float, yb: float, za: float, zb: float) -> void:
	var beam: Color = s["beam"]
	if s["infill_key"] == "kslate":
		_face(pk, kit, "kslate", _wf(Vector3(0, 0, zb), Vector3(0, 0, 1)), 0.0, ya, w, yb, 0.0, s["infill"])
		if zb > za + 0.01:
			pk.quad(kit, "lapboards", [Vector3(0, ya, za), Vector3(w, ya, za), Vector3(w, ya, zb), Vector3(0, ya, zb)], Vector3.DOWN, Color(0.92, 0.92, 0.9))
		for side in [-1.0, 1.0]:
			var swf: Transform3D = _wf(Vector3(w, 0, zb), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(0, 0, -d), Vector3(-1, 0, 0))
			_face(pk, kit, "kslate", swf, 0.0, ya, d + zb, yb, 0.0, s["infill"])
		_face(pk, kit, "kslate", _wf(Vector3(w, 0, -d), Vector3(0, 0, -1)), 0.0, ya, w, yb, 0.0, s["infill"])
		return
	# Sides and back: a solid beam.
	for side in [-1.0, 1.0]:
		var swf: Transform3D = _wf(Vector3(w, 0, zb), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(0, 0, -d), Vector3(-1, 0, 0))
		_rect(pk, kit, "timber", swf, 0.0, ya, d + zb, yb, 0.0, TP, beam)
	_rect(pk, kit, "timber", _wf(Vector3(w, 0, -d), Vector3(0, 0, -1)), 0.0, ya, w, yb, 0.0, TP, beam)
	if zb < za + 0.05:
		_rect(pk, kit, "timber", _wf(Vector3(0, 0, za), Vector3(0, 0, 1)), 0.0, ya, w, yb, 0.0, TP, beam)
		return
	pk.quad(kit, "lapboards", [Vector3(0, ya + 0.05, za), Vector3(w, ya + 0.05, za), Vector3(w, ya + 0.05, zb - 0.04), Vector3(0, ya + 0.05, zb - 0.04)],
			Vector3.DOWN, beam.lightened(0.25))
	pk.quad(kit, "timber", [Vector3(0, ya - 0.01, za), Vector3(w, ya - 0.01, za), Vector3(w, ya + 0.06, za), Vector3(0, ya + 0.06, za)], Vector3(0, 0, 1), beam)
	pk.quad(kit, "timber", [Vector3(0, ya + 0.05, zb - 0.04), Vector3(w, ya + 0.05, zb - 0.04), Vector3(w, yb, zb - 0.04), Vector3(0, yb, zb - 0.04)],
			Vector3(0, 0, 1), beam.lightened(0.06))
	var nh: int = maxi(int(round((w - 0.2) / 0.95)), 2)
	for k in range(nh + 1):
		var x: float = lerpf(0.1, w - 0.1, float(k) / float(nh))
		pk.block(kit, "timber", Vector3(x - 0.09, ya, za + TP), Vector3(x + 0.09, yb, zb + 0.01), beam, uvk)
	# Knaggen under the corner heads: a curved bracket from the lower corner post up under the head.
	for xc in [0.1, w - 0.1]:
		var bf := Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), Vector3(xc + 0.075, 0, 0))
		var ol := PackedVector2Array()
		var z0: float = za + TP
		var z1: float = zb - 0.06
		var drop := 0.75
		ol.append(Vector2(z0, ya))
		ol.append(Vector2(z0, ya - drop))
		for k in range(1, 7):
			var a: float = PI - PI * 0.5 * float(k) / 6.0
			ol.append(Vector2(z1 + cos(a) * (z1 - z0), ya - drop + sin(a) * drop))
		_prism(pk, kit, "timber", bf, ol, 0.0, 0.15, beam, Vector2(0, 1), true)


## The ground floor of a gable-fronted house: a stone plinth (down to FOOT) and half-timbering, or stone walls, or slate,
## or a shop front; the door with its steps, the windows.
static func _ground_floor(pk: PropKit, kit: Dictionary, w: float, d: float, s: Dictionary, g: Array, pl: float, cols: Array, ww: float, door_col: int,
		rng: RandomNumberGenerator, labels: Array) -> void:
	var y1: float = g[1]
	var kind: String = s["ground"]
	var stone: Color = s["stone"]
	var fwf := _wf(Vector3.ZERO, Vector3(0, 0, 1))
	var walls: Array = [[fwf, w], [_wf(Vector3(w, 0, 0), Vector3(1, 0, 0)), d], [_wf(Vector3(w, 0, -d), Vector3(0, 0, -1)), w],
			[_wf(Vector3(0, 0, -d), Vector3(-1, 0, 0)), d]]
	var sill_v: float = pl + PLH
	if kind == "stone":
		for wl in walls:
			_face(pk, kit, s["stone_key"], wl[0], 0.0, FOOT, wl[1], y1, 0.0, stone)
		# A cornice of dressed stone along the top of the ground floor.
		for wl in walls:
			_rect(pk, kit, "ashlar", wl[0], -0.06, y1 - 0.24, float(wl[1]) + 0.06, y1, 0.0, 0.07, SANDSTONE.lightened(0.05))
		sill_v = 0.45
	else:
		_wblock(pk, kit, "stone" if kind != "shop" else "ashlar", Vector3(-0.03, FOOT, -d - 0.03), Vector3(w + 0.03, pl, 0.03), stone)
	var door_u: float = cols[door_col]
	if kind == "shop":
		_shop_front(pk, kit, w, d, s, y1, pl, door_u, rng, labels)
	else:
		var ops: Array = []
		var wb: float = sill_v + 0.75 if kind != "stone" else 1.15
		for i in range(cols.size()):
			if i == door_col:
				ops.append([door_u, 1.05, sill_v, minf(sill_v + 2.15, y1 - PLH)])
			else:
				ops.append([cols[i], ww, wb, y1 - PLH - (0.15 if kind == "stone" else 0.0)])
		if kind == "fw":
			_fw_wall(pk, kit, fwf, w, pl, y1, ops, s, true)
		elif kind == "slate":
			_face(pk, kit, "kslate", fwf, 0.0, pl, w, y1, 0.0, s["infill"])
		for i in range(ops.size()):
			var o: Array = ops[i]
			if i == door_col:
				var dh: float = float(o[3]) - float(o[2])
				var tr: float = 0.0
				if dh > 2.45:
					tr = dh - 2.05
				var sk: String = "ashlar" if kind == "stone" else "painted"
				var sc: Color = SANDSTONE if kind == "stone" else (WIN_WHITE if kind == "slate" else s["beam"])
				if kind == "fw":
					# The door sits between its posts: no surround of its own, the posts frame it.
					_door_leaf(pk, kit, fwf, door_u, o[2], 1.05, dh - tr, s["door"], tr)
					_steps(pk, kit, fwf, door_u, o[2], 1.6, 0.0)
				else:
					_door(pk, kit, fwf, door_u, o[2], 1.05, 2.0, s["door"], sk, sc, 0.0, 0.3 if kind == "stone" else 0.0)
			else:
				var wo := _win_opts(s, rng)
				if kind == "stone":
					wo["sill"] = "ashlar"
					wo["sill_col"] = SANDSTONE.lightened(0.06)
					_stone_surround(pk, kit, fwf, o[0], o[2], o[3], ww)
				_win(pk, kit, fwf, o[0], o[2], o[3], ww, wo)
	# Ground floor sides and back.
	for i in range(1, 4):
		var wl: Array = walls[i]
		if kind == "fw" or kind == "shop":
			var ops2: Array = []
			if i == 2:
				ops2 = [[float(wl[1]) * 0.5, 0.9, pl + PLH, pl + PLH + 2.0]]
			_storey_wall(pk, kit, wl[0], wl[1], pl, y1, ops2, s, true, true)
			if i == 2:
				_door_leaf(pk, kit, wl[0], float(wl[1]) * 0.5, pl + PLH, 0.9, 2.0, s["door"].darkened(0.1), 0.0)
		elif kind == "slate":
			_face(pk, kit, "kslate", wl[0], 0.0, pl, wl[1], y1, 0.0, s["infill"])
		if i == 2 and kind != "fw" and kind != "shop":
			_door(pk, kit, wl[0], float(wl[1]) * 0.5, sill_v, 0.95, 2.05, s["door"].darkened(0.1), "ashlar" if kind == "stone" else "painted",
					SANDSTONE if kind == "stone" else WIN_WHITE, 0.0, 0.0)


## A plain door leaf between the frame's posts (no surround): panels, a knob, a transom light if `transom` > 0.
static func _door_leaf(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, h: float, col: Color, transom: float) -> void:
	var x0: float = u - w * 0.5
	var x1: float = u + w * 0.5
	_rect(pk, kit, "painted", wf, x0, v0, x1, v0 + h, 0.0, 0.035, col)
	var pw: float = (w - 0.3) * 0.5
	for cx in [x0 + 0.1, x0 + 0.2 + pw]:
		_rect(pk, kit, "painted", wf, cx, v0 + 0.15, cx + pw, v0 + h * 0.42, 0.035, 0.052, col.lightened(0.09))
		_rect(pk, kit, "painted", wf, cx, v0 + h * 0.5, cx + pw, v0 + h - 0.12, 0.035, 0.052, col.lightened(0.09))
	pk.tube(kit, "gold", wf * Vector3(u + w * 0.34, v0 + 1.0, 0.035), wf * Vector3(u + w * 0.34, v0 + 1.0, 0.1), 0.03, 0.035, 8, BRASS)
	if transom > 0.0:
		_face(pk, kit, "pane", wf, x0, v0 + h + 0.06, x1, v0 + h + transom, 0.02, GLASS)
		_rect(pk, kit, "painted", wf, x0, v0 + h, x1, v0 + h + 0.06, 0.0, 0.05, WIN_WHITE)
		_rect(pk, kit, "painted", wf, u - 0.02, v0 + h + 0.06, u + 0.02, v0 + h + transom, 0.02, 0.04, WIN_WHITE)


## A dressed stone surround round a window in a stone wall: jambs and a lintel 15cm wide, 6cm proud.
static func _stone_surround(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, w: float) -> void:
	var x0: float = u - w * 0.5
	var x1: float = u + w * 0.5
	_rect(pk, kit, "ashlar", wf, x0 - 0.16, v0, x0, v1, 0.0, 0.06, SANDSTONE.lightened(0.04))
	_rect(pk, kit, "ashlar", wf, x1, v0, x1 + 0.16, v1, 0.0, 0.06, SANDSTONE.lightened(0.04))
	_rect(pk, kit, "ashlar", wf, x0 - 0.16, v1, x1 + 0.16, v1 + 0.2, 0.0, 0.06, SANDSTONE.lightened(0.04))


## The shop front on a house's ground floor (y from the plinth `pl` to `y1`): plastered, a shop window with a stall riser,
## a glazed door at `door_u`, a fascia board with the shop's name, a striped awning over the window and a guild sign on a
## wrought-iron bracket.
static func _shop_front(pk: PropKit, kit: Dictionary, w: float, _d: float, s: Dictionary, y1: float, pl: float, door_u: float, _rng: RandomNumberGenerator,
		labels: Array) -> void:
	var shop: Array = SHOPS[int(s["shop"])]
	var sc: Color = shop[3]
	var fwf := _wf(Vector3.ZERO, Vector3(0, 0, 1))
	var plaster: Color = s["infill"].lerp(Color(0.95, 0.93, 0.88), 0.4)
	_face(pk, kit, "plaster", fwf, 0.0, pl, w, y1, 0.0, plaster)
	# A head plate along the top (the frame of the storey above sits on it).
	_rect(pk, kit, "timber", fwf, 0.0, y1 - PLH, w, y1, 0.0, TP, s["beam"])
	var left_door: bool = door_u < w * 0.5
	var dx0: float = door_u - 0.6
	var dx1: float = door_u + 0.6
	var wx0: float = 0.55 if not left_door else dx1 + 0.35
	var wx1: float = (dx0 - 0.35) if not left_door else w - 0.55
	# Shop window: a stall riser of panels, the frame, glass, two mullions, a transom bar.
	_rect(pk, kit, "painted", fwf, wx0 - 0.1, pl, wx1 + 0.1, 0.95, 0.0, 0.06, sc)
	_rect(pk, kit, "painted", fwf, wx0 + 0.1, pl + 0.12, wx1 - 0.1, 0.82, 0.06, 0.075, sc.lightened(0.12))
	var top: float = 2.75
	_face(pk, kit, "pane", fwf, wx0, 0.95, wx1, top, 0.02, GLASS.lightened(0.05))
	_rect(pk, kit, "painted", fwf, wx0 - 0.1, 0.95, wx0, top, 0.0, 0.07, sc)
	_rect(pk, kit, "painted", fwf, wx1, 0.95, wx1 + 0.1, top, 0.0, 0.07, sc)
	_rect(pk, kit, "painted", fwf, wx0 - 0.1, top, wx1 + 0.1, top + 0.1, 0.0, 0.07, sc)
	_rect(pk, kit, "painted", fwf, wx0, 2.25, wx1, 2.31, 0.02, 0.05, sc)
	for k in range(1, 3):
		var mx: float = lerpf(wx0, wx1, float(k) / 3.0)
		_rect(pk, kit, "painted", fwf, mx - 0.03, 0.95, mx + 0.03, 2.25, 0.02, 0.05, sc)
		_rect(pk, kit, "painted", fwf, mx - 0.03, 2.31, mx + 0.03, top, 0.02, 0.05, sc)
	# Goods in the window: shelves of loaves, cuts, jars, cakes or books as coloured blocks behind the glass.
	# The door: glazed, with a transom; stone step.
	_door(pk, kit, fwf, door_u, pl, 1.0, 2.2, sc, "painted", sc, 0.0, 0.35, true)
	# The fascia board with the name.
	var fx0: float = minf(wx0, dx0) - 0.3
	var fx1: float = maxf(wx1, dx1) + 0.3
	_rect(pk, kit, "painted", fwf, fx0, top + 0.18, fx1, top + 0.62, 0.0, 0.08, sc)
	_rect(pk, kit, "painted", fwf, fx0 + 0.06, top + 0.24, fx1 - 0.06, top + 0.56, 0.08, 0.095, sc.darkened(0.25))
	labels.append([ShopNames.unique(String(shop[1]), String(shop[0])), Vector3((fx0 + fx1) * 0.5, top + 0.4, 0.13), Vector3(0, 0, 1), 0.2,
			KR_GOLD.lightened(0.15), fx1 - fx0 - 0.4])
	# The awning over the shop window: stripes sloping out, a valance, its arms.
	var stripes: Array = shop[2]
	var ay0: float = top + 0.14
	var aout := 1.25
	var adrop := 0.55
	var nstr: int = maxi(int((wx1 - wx0 + 0.3) / 0.32), 4)
	for k in range(nstr):
		var xa: float = lerpf(wx0 - 0.15, wx1 + 0.15, float(k) / float(nstr))
		var xb: float = lerpf(wx0 - 0.15, wx1 + 0.15, float(k + 1) / float(nstr))
		var c: Color = stripes[k % 2]
		var nrm := Vector3(0, aout, adrop).normalized()
		pk.quad(kit, "canvas", [Vector3(xa, ay0, 0.06), Vector3(xb, ay0, 0.06), Vector3(xb, ay0 - adrop, aout), Vector3(xa, ay0 - adrop, aout)], nrm, c)
		pk.quad(kit, "canvas", [Vector3(xa, ay0 - 0.02, 0.06), Vector3(xa, ay0 - adrop - 0.02, aout), Vector3(xb, ay0 - adrop - 0.02, aout), Vector3(xb, ay0 - 0.02, 0.06)],
				-nrm, c.darkened(0.3))
		# The valance: a flap hanging from the front edge, scalloped.
		var vy: float = ay0 - adrop
		pk.quad(kit, "canvas", [Vector3(xa, vy, aout + 0.01), Vector3(xb, vy, aout + 0.01), Vector3(xb, vy - 0.18, aout + 0.01), Vector3(xa, vy - 0.18, aout + 0.01)], Vector3(0, 0, 1), c)
		pk.quad(kit, "canvas", [Vector3(xa, vy, aout - 0.01), Vector3(xa, vy - 0.18, aout - 0.01), Vector3(xb, vy - 0.18, aout - 0.01), Vector3(xb, vy, aout - 0.01)], Vector3(0, 0, -1), c.darkened(0.3))
		pk.tri(kit, "canvas", Vector3(xa, vy - 0.18, aout + 0.01), Vector3(xb, vy - 0.18, aout + 0.01), Vector3((xa + xb) * 0.5, vy - 0.27, aout + 0.01),
				Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), c, Vector3(0, 0, 1))
	for ax in [wx0 - 0.1, wx1 + 0.1]:
		pk.beam(kit, "steel", Vector3(ax, ay0 - 0.9, 0.02), Vector3(ax, ay0 - adrop + 0.02, aout - 0.05), 0.04, 0.04, CAST)
	pk.tube(kit, "steel", Vector3(wx0 - 0.15, ay0 - adrop - 0.02, aout), Vector3(wx1 + 0.15, ay0 - adrop - 0.02, aout), 0.03, 0.03, 6, CAST)
	# The guild sign on its bracket, over the door's side of the front.
	var gu: float = 0.35 if left_door else w - 0.35
	_guild_sign(pk, kit, Vector3(gu, y1 + 0.24 + 0.6, float(s["jetty"])), Vector3(0, 0, 1), shop[1], labels)


## A hanging guild sign (Ausleger): a wrought-iron bracket out from the wall at `p` (on the wall's face, facing `out`), a
## scroll under it, and the emblem hanging from its end in the plane across the wall, read from along the street:
## "pretzel" (gilded), "ox" (a gilded ox's head), "apotheke" (a red board with a white A), "cup", "book".
static func _guild_sign(pk: PropKit, kit: Dictionary, p: Vector3, out: Vector3, kind: String, labels: Array) -> void:
	var reach := 1.2
	var e: Vector3 = p + out * reach
	pk.beam(kit, "steel", p + out * 0.02, e, 0.05, 0.05, CAST, Vector3.UP)
	pk.beam(kit, "steel", p - Vector3(0, 0.6, 0) + out * 0.02, p + out * reach * 0.6, 0.035, 0.035, CAST, Vector3.UP)
	pk.block(kit, "steel", p + Vector3(-0.08, -0.7, 0.0), p + Vector3(0.08, 0.1, 0.0) + out * 0.03, CAST, uvk)
	# A scroll in the bracket's corner.
	var pts: Array = []
	for k in range(9):
		var a: float = TAU * 0.85 * float(k) / 8.0
		var r: float = 0.16 - 0.012 * float(k)
		pts.append(p + out * (0.45 + cos(a) * r) + Vector3(0, -0.2 + sin(a) * r, 0))
	_tube_path(pk, kit, "steel", pts, 0.015, 5, CAST)
	# The emblem: in the plane through the bracket's line and the vertical.
	var c: Vector3 = e - out * 0.42 - Vector3(0, 0.62, 0)
	for hx in [-0.25, 0.25]:
		pk.beam(kit, "steel", e - out * (0.42 - hx) , c + out * hx + Vector3(0, 0.38, 0), 0.015, 0.015, CAST)
	var side: Vector3 = out.cross(Vector3.UP).normalized()
	var ef := Transform3D(Basis(out, Vector3.UP, side), c)
	match kind:
		"pretzel":
			# A trefoil's outline: the big loop at the bottom, the two small ones above, the arms crossing between them.
			var loop: Array = []
			for k in range(37):
				var t: float = TAU * float(k) / 36.0
				loop.append(ef * Vector3((sin(t) + 2.0 * sin(2.0 * t)) * 0.125, (cos(t) - 2.0 * cos(2.0 * t)) * 0.11 + 0.06, 0.0))
			_tube_path(pk, kit, "gold", loop, 0.045, 6, KR_GOLD)
		"ox":
			var ol := PackedVector2Array([Vector2(-0.46, 0.3), Vector2(-0.3, 0.18), Vector2(-0.18, 0.2), Vector2(-0.2, -0.1), Vector2(-0.1, -0.36),
				Vector2(0.1, -0.36), Vector2(0.2, -0.1), Vector2(0.18, 0.2), Vector2(0.3, 0.18), Vector2(0.46, 0.3), Vector2(0.34, 0.3),
				Vector2(0.16, 0.28), Vector2(0.0, 0.3), Vector2(-0.16, 0.28), Vector2(-0.34, 0.3)])
			_prism(pk, kit, "gold", ef, ol, -0.03, 0.03, KR_GOLD, Vector2(0, 1), true)
		"apotheke":
			_prism(pk, kit, "enamel", ef, _rp(-0.34, -0.4, 0.34, 0.4), -0.04, 0.04, KR_RED, Vector2(0, 1), true)
			labels.append(["A", ef * Vector3(0, 0, 0.05), side, 0.42, Color(0.98, 0.98, 0.96), 0.6])
			labels.append(["A", ef * Vector3(0, 0, -0.05), -side, 0.42, Color(0.98, 0.98, 0.96), 0.6])
		"cup":
			var ol2 := PackedVector2Array([Vector2(-0.3, 0.2), Vector2(0.3, 0.2), Vector2(0.24, -0.12), Vector2(0.12, -0.24), Vector2(-0.12, -0.24),
				Vector2(-0.24, -0.12)])
			_prism(pk, kit, "gold", ef, ol2, -0.03, 0.03, KR_GOLD, Vector2(0, 1), true)
			_prism(pk, kit, "gold", ef, _rp(-0.4, -0.32, 0.4, -0.27), -0.03, 0.03, KR_GOLD, Vector2(1, 0), true)
			var hpts: Array = []
			for k in range(9):
				var a2: float = -PI * 0.5 + PI * float(k) / 8.0
				hpts.append(ef * Vector3(0.27 + cos(a2) * 0.12, 0.02 + sin(a2) * 0.1, 0.0))
			_tube_path(pk, kit, "gold", hpts, 0.03, 5, KR_GOLD)
			for k in range(3):
				var sx: float = -0.12 + 0.12 * float(k)
				_tube_path(pk, kit, "gold", [ef * Vector3(sx, 0.26, 0), ef * Vector3(sx + 0.04, 0.36, 0), ef * Vector3(sx - 0.02, 0.46, 0)], 0.018, 4, KR_GOLD)
		_:
			var ol3 := PackedVector2Array([Vector2(-0.44, 0.2), Vector2(-0.22, 0.26), Vector2(0.0, 0.18), Vector2(0.22, 0.26), Vector2(0.44, 0.2),
				Vector2(0.44, -0.24), Vector2(0.22, -0.18), Vector2(0.0, -0.26), Vector2(-0.22, -0.18), Vector2(-0.44, -0.24)])
			_prism(pk, kit, "gold", ef, ol3, -0.03, 0.03, KR_GOLD, Vector2(0, 1), true)
			_prism(pk, kit, "enamel", ef, _rp(-0.02, -0.25, 0.02, 0.19), 0.03, 0.04, KR_RED, Vector2(0, 1), true)


## A house with its eaves to the street (traufständig): the half-timbered front with its jetties, gables on both ends, the
## roof's ridge along the street, a row of dormers on its front slope.
static func _house_trauf(pk: PropKit, kit: Dictionary, w: float, d: float, s: Dictionary, st: Array, fz: float, pl: float, rng: RandomNumberGenerator,
		labels: Array) -> void:
	var n: int = st.size()
	var ncol: int = clampi(int((w - 0.6) / 2.15), 3, 6)
	var ww: float = rng.randf_range(0.82, 0.95)
	var cols: Array = []
	for i in range(ncol):
		cols.append(w * (float(i) + 0.5) / float(ncol))
	var door_col: int = ncol / 2 if rng.randf() < 0.6 else 0
	_ground_floor(pk, kit, w, d, s, st[0], pl, cols, ww, door_col, rng, labels)
	for k in range(1, n):
		var y0: float = st[k][0]
		var y1: float = st[k][1]
		var zf: float = st[k][2]
		var wb: float = y0 + PLH + 0.78
		var wt: float = y1 - PLH
		var ops: Array = []
		for c in cols:
			ops.append([c, ww, wb, wt])
		var fwf := _wf(Vector3(0, 0, zf), Vector3(0, 0, 1))
		_storey_wall(pk, kit, fwf, w, y0, y1, ops, s, true)
		for o in ops:
			_win(pk, kit, fwf, o[0], o[2], o[3], ww, _win_opts(s, rng))
		_floor_zone(pk, kit, w, d, s, float(st[k - 1][1]), y0, float(st[k - 1][2]), zf)
		var length: float = d + zf
		for side in [-1.0, 1.0]:
			var swf: Transform3D = _wf(Vector3(w, 0, zf), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(0, 0, -d), Vector3(-1, 0, 0))
			var sops: Array = [[length * 0.5, 0.8, wb, wt]]
			_storey_wall(pk, kit, swf, length, y0, y1, sops, s, true, true)
			_win(pk, kit, swf, length * 0.5, wb, wt, 0.8, _win_opts(s, rng, false))
		var bwf := _wf(Vector3(w, 0, -d), Vector3(0, 0, -1))
		var bops: Array = []
		for i in range(maxi(ncol - 1, 2)):
			bops.append([w * (float(i) + 0.5) / float(maxi(ncol - 1, 2)), 0.8, wb, wt])
		_storey_wall(pk, kit, bwf, w, y0, y1, bops, s, true, true)
		for o in bops:
			_win(pk, kit, bwf, o[0], o[2], o[3], 0.8, _win_opts(s, rng, false))
	var ye: float = st[n - 1][1]
	var zt: float = st[n - 1][2]
	var yg: float = ye + fz
	_floor_zone(pk, kit, w, d, s, ye, yg, zt, zt)
	# The roof: its ridge along x. Roof frame: x across from the front wall (building z = zt) to the back (-d).
	var span: float = d + zt
	var rf := Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3(0, 0, zt))
	var r := _roof(pk, kit, rf, span, 0.0, w, yg, s["pitch"], 0.55, 0.28, s["roof_key"], s["roof"], s["trim"])
	var t: float = r["t"]
	var apex: float = yg - 0.01 + t * span * 0.5
	# The end gables.
	for side in [-1.0, 1.0]:
		var gwf: Transform3D = _wf(Vector3(w, 0, zt), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(0, 0, -d), Vector3(-1, 0, 0))
		var gb: float = yg + PLH + 0.55
		var gops: Array = [[span * 0.5 - PW * 0.5 - 0.35, 0.7, gb, gb + 0.95], [span * 0.5 + PW * 0.5 + 0.35, 0.7, gb, gb + 0.95]]
		if s["infill_key"] == "kslate":
			_slate_gable(pk, kit, gwf, span, yg, apex, s)
		else:
			_fw_gable(pk, kit, gwf, span, yg, apex, gops, s, gb + 0.95 + RH + 0.35)
		for o in gops:
			_win(pk, kit, gwf, o[0], o[2], o[3], 0.7, _win_opts(s, rng, false))
	# Dormers on the front slope.
	var nd: int = clampi(int(w / 3.6), 1, 3)
	for i in range(nd):
		var cx: float = w * (float(i) + 0.5) / float(nd)
		_dormer(pk, kit, rf, r, cx, 0.75, 1.5, s, rng)
	_chimney(pk, kit, rf, span * 0.5 + 0.6, w * rng.randf_range(0.25, 0.75), yg + 0.5, float(r["ridge"]) + 0.9, s["infill_key"] == "kslate")


## A gabled dormer on a roof's front slope (x < span / 2 in the roof frame `rf`, `r` the roof's numbers): its front `xd`
## in from the wall line, `dw` wide, centred at z = cz: a half-timbered front with a window, slate-hung cheeks down to the
## roof, a little gabled roof whose ridge and eaves run back until they meet the main roof.
static func _dormer(pk: PropKit, kit: Dictionary, rf: Transform3D, r: Dictionary, cz: float, xd: float, dw: float, s: Dictionary, _rng: RandomNumberGenerator) -> void:
	var t: float = r["t"]
	var top0: float = r["top0"]
	var yb: float = top0 + t * xd - 0.04
	var ye: float = yb + 1.55
	var td: float = tan(deg_to_rad(48.0))
	var doh := 0.18
	var hw: float = dw * 0.5
	var yr: float = ye + td * (hw + 0.02)
	# The front, facing down the slope (-x in the roof frame): u along +z... a wall frame facing -x.
	var fo: Vector3 = Vector3(xd, 0, cz - hw)
	var dwf := Transform3D(rf.basis * Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), rf * fo)
	var ds: Dictionary = s.duplicate()
	ds["cross"] = false
	ds["mann"] = false
	if s.has("dormer_face"):
		_face(pk, kit, s["dormer_face"], dwf, 0.0, yb, dw, ye, 0.0, s["dormer_col"])
		_pface(pk, kit, s["dormer_face"], dwf, PackedVector2Array([Vector2(0, ye), Vector2(dw, ye), Vector2(hw, yr - 0.02)]), 0.0, s["dormer_col"])
	elif s["infill_key"] == "kslate":
		_face(pk, kit, "kslate", dwf, 0.0, yb, dw, ye, 0.0, s["infill"])
		_pface(pk, kit, "kslate", dwf, PackedVector2Array([Vector2(0, ye), Vector2(dw, ye), Vector2(hw, yr)]), 0.0, s["infill"])
	else:
		_fw_wall(pk, kit, dwf, dw, yb, ye, [[hw, 0.8, yb + PLH + 0.12, ye - PLH]], ds, true)
		_pface(pk, kit, s["infill_key"], dwf, PackedVector2Array([Vector2(0, ye), Vector2(dw, ye), Vector2(hw, yr - 0.02)]), 0.0, s["infill"])
	_win(pk, kit, dwf, hw, yb + PLH + 0.12, ye - PLH, 0.8, {"frame": WIN_WHITE, "casing": s["casing"], "rows": 2})
	# The cheeks: triangles from the front back along the roof.
	var xe: float = (ye - top0) / t
	for sz in [-1.0, 1.0]:
		var z: float = cz + sz * hw
		var nrm: Vector3 = (rf.basis * Vector3(0, 0, sz)).normalized()
		pk.tri(kit, s.get("cheek_key", "kslate"), rf * Vector3(xd, yb, z), rf * Vector3(xd, ye, z), rf * Vector3(xe, ye, z), nrm, nrm, nrm, s.get("cheek_col", SLATE), nrm,
				Vector2(0, yb) * uvk, Vector2(0, ye) * uvk, Vector2(xe - xd, ye) * uvk)
	# Its roof: from the front's eaves (doh overhang) back until each line meets the main roof.
	var key: String = s["roof_key"]
	var ey: float = ye - td * doh
	var x_ridge: float = (yr - top0) / t
	var x_eave: float = (ey - top0) / t
	for sz2 in [-1.0, 1.0]:
		var ze: float = cz + sz2 * (hw + doh)
		var nrm2: Vector3 = (rf.basis * Vector3(0, 1.0, sz2 * td)).normalized()
		var p0: Vector3 = rf * Vector3(xd - doh, ey, ze)
		var p1: Vector3 = rf * Vector3(x_eave, ey, ze)
		var p2: Vector3 = rf * Vector3(x_ridge, yr + 0.02, cz)
		var p3: Vector3 = rf * Vector3(xd - doh, yr + 0.02, cz)
		roof(pk, kit, key, p0, p1, p2, p3, s["roof"], nrm2, true)
	# Verge boards on its front.
	var vf := Transform3D(rf.basis * Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), rf * Vector3(xd - doh, 0, 0))
	for sz3 in [-1.0, 1.0]:
		var ol := PackedVector2Array()
		var za: float = cz + sz3 * (hw + doh + 0.03)
		ol.append(Vector2(za, ey + 0.02))
		ol.append(Vector2(cz, yr + 0.05))
		ol.append(Vector2(cz, yr + 0.05 - 0.2))
		ol.append(Vector2(za, ey + 0.02 - 0.2))
		_prism(pk, kit, "timber", vf, ol, 0.0, 0.04, s["trim"], Vector2(1, 0), true)


# ======================================================================================
#  Gothic details: pointed windows, rings, buttresses
# ======================================================================================

const KIRCH := Color(0.62, 0.55, 0.45)       # the church's sandstone
const KIRCH_TRIM := Color(0.76, 0.69, 0.56)  # its dressings
const LEAD := Color(0.10, 0.12, 0.15)        # leaded glass


## A ring between two circles round `c` (a rose window's frame, tracery's oculus), standing d0..d1 off a wall: its front, its
## outer rim and its inner rim.
static func _circle_ring(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, c: Vector2, r_in: float, r_out: float, d0: float, d1: float,
		col: Color, segs := 16) -> void:
	var nf: Vector3 = wf.basis.z.normalized()
	for k in range(segs):
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var e0 := Vector2(cos(a0), sin(a0))
		var e1 := Vector2(cos(a1), sin(a1))
		var p0: Vector2 = c + e0 * r_in
		var p1: Vector2 = c + e1 * r_in
		var q0: Vector2 = c + e0 * r_out
		var q1: Vector2 = c + e1 * r_out
		pk.quad(kit, key, [wf * Vector3(p0.x, p0.y, d1), wf * Vector3(q0.x, q0.y, d1), wf * Vector3(q1.x, q1.y, d1), wf * Vector3(p1.x, p1.y, d1)], nf, col,
				[p0 * uvk, q0 * uvk, q1 * uvk, p1 * uvk])
		var m := (e0 + e1).normalized()
		var on: Vector3 = (wf.basis * Vector3(m.x, m.y, 0.0)).normalized()
		pk.quad(kit, key, [wf * Vector3(q0.x, q0.y, d0), wf * Vector3(q1.x, q1.y, d0), wf * Vector3(q1.x, q1.y, d1), wf * Vector3(q0.x, q0.y, d1)], on, col)
		pk.quad(kit, key, [wf * Vector3(p0.x, p0.y, d0), wf * Vector3(p1.x, p1.y, d0), wf * Vector3(p1.x, p1.y, d1), wf * Vector3(p0.x, p0.y, d1)], -on, col.darkened(0.1))


## The outline of a pointed (or round) opening: its sill, up its jambs and over its arch.
static func _opening(u: float, sill: float, half: float, spring: float, kind := "pointed", segs := 12) -> PackedVector2Array:
	var ol := PackedVector2Array([Vector2(u + half, sill), Vector2(u - half, sill)])
	ol.append_array(_arch(u, spring, half, kind, segs))
	return ol


## A tall pointed window (a lancet with tracery): `w` wide from `sill` up to its apex `h` above, in its wall frame. Its
## leaded glass 3cm proud, a dressed surround with a chamfered soffit standing 22cm out, a sill, and (with `tracery`) a
## mullion, a pointed head over each light and an oculus over both.
static func _gothic_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, sill: float, w: float, h: float, col := KIRCH_TRIM,
		tracery := true, glass := LEAD) -> void:
	var half: float = w * 0.5
	var spring: float = sill + h - 1.483 * half
	_pface(pk, kit, "pane", wf, _opening(u, sill, half, spring), 0.03, glass)
	_arch_ring(pk, kit, "ashlar", wf, u, spring, half, "pointed", 0.3, 0.0, 0.22, col, sill, 12)
	_rect(pk, kit, "ashlar", wf, u - half - 0.42, sill - 0.28, u + half + 0.42, sill, 0.0, 0.3, col)
	if not tracery:
		return
	var m := 0.18
	_rect(pk, kit, "ashlar", wf, u - m * 0.5, sill, u + m * 0.5, spring, 0.0, 0.14, col)
	var hl: float = (half - m * 0.5) * 0.5
	for side in [-1.0, 1.0]:
		_arch_ring(pk, kit, "ashlar", wf, u + side * (m * 0.5 + hl), spring, hl, "pointed", m * 0.5, 0.0, 0.14, col, NAN, 6)
	var sub_top: float = spring + 1.483 * hl + m * 0.5
	var main_top: float = spring + 1.483 * half
	var r_o: float = (main_top - sub_top) * 0.42
	_circle_ring(pk, kit, "ashlar", wf, Vector2(u, sub_top + (main_top - sub_top) * 0.46), r_o - 0.1, r_o, 0.0, 0.14, col, 12)


## A stepped buttress against a wall: in the wall's frame `wf`, centred at u, `bw` wide, standing out `depth` at its foot
## (from FOOT), set back by `steps` ([height, depth after]) with sloped weatherings, its top sloping back into the wall at `top`.
static func _buttress(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, bw: float, depth: float, steps: Array, top: float, col: Color) -> void:
	var ol := PackedVector2Array([Vector2(0.0, FOOT), Vector2(depth, FOOT)])
	var d: float = depth
	for st in steps:
		ol.append(Vector2(d, float(st[0])))
		d = st[1]
		ol.append(Vector2(d, float(st[0]) + (ol[ol.size() - 1].x - d) * 1.2))
	ol.append(Vector2(d, top))
	ol.append(Vector2(0.0, top + d * 1.3))
	# The profile lies in the plane across the wall: x out of the wall, y up, extruded along the wall.
	var n: Vector3 = wf.basis.z
	var along: Vector3 = wf.basis.x
	var bf := Transform3D(Basis(n, Vector3.UP, n.cross(Vector3.UP).normalized()), wf * Vector3(u, 0.0, 0.0))
	# n x up points along -u: start at u + bw/2 and extrude toward u - bw/2.
	bf.origin = wf * Vector3(u + bw * 0.5, 0.0, 0.0)
	if n.cross(Vector3.UP).normalized().dot(along) > 0.0:
		bf.origin = wf * Vector3(u - bw * 0.5, 0.0, 0.0)
	_prism(pk, kit, "ashlar", bf, ol, 0.0, bw, col, Vector2(0, 1), true)


# ======================================================================================
#  St. Lamberti
# ======================================================================================

const CH_TH := 6.5      # the tower's half width (it is 13m square)
const CH_TD := 13.0     # its depth, z from 0 to -13
const CH_TOP := 38.0    # the top of its masonry
const CH_NH := 7.5      # the nave's half width
const CH_NZ := -47.0    # the nave's east end
const CH_NE := 15.0     # the nave's eaves
const CH_CH := 5.0      # the choir's half width
const CH_CZ := -56.0    # where the choir's apse begins
const CH_CE := 13.0     # the choir's eaves
const CH_SPIRE := 64.0  # the spire's apex


## St. Lamberti, the town church: the west tower's front on z = 0 facing +z (its buttresses and steps reach 2.6m out),
## x centred on 0, the nave running toward -z to the choir and its apse at z = -61. A west tower 13m square of dressed
## sandstone to 38m (corner buttresses, string courses, a portal with three archivolts, a traceried west window, a clock on
## every face, paired louvred belfry openings) under an octagonal broach spire of slate scales to 64m with a lucarne on each
## cardinal face, a gilt ball and a weathercock (67m); the nave 15 x 34m with buttressed bays and tall traceried windows under a steep slate roof, an
## oculus in its east gable; the choir and its half-octagon apse.
static func church(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var stone := KIRCH
	var trim := KIRCH_TRIM
	# --- The tower.
	var faces: Array = [
		_wf(Vector3(-CH_TH, 0, 0), Vector3(0, 0, 1)), _wf(Vector3(CH_TH, 0, 0), Vector3(1, 0, 0)),
		_wf(Vector3(CH_TH, 0, -CH_TD), Vector3(0, 0, -1)), _wf(Vector3(-CH_TH, 0, -CH_TD), Vector3(-1, 0, 0))]
	var tw := CH_TH * 2.0
	for i in range(4):
		var wf: Transform3D = faces[i]
		_face(pk, kit, "ashlar", wf, 0.0, FOOT, tw, CH_TOP, 0.0, stone)
		# String courses (the west and east ones run on over the corners).
		var ext: float = 0.2 if i % 2 == 0 else -0.02
		for y in [0.6, 12.0, 23.0, 30.4]:
			_rect(pk, kit, "ashlar", wf, -ext, y - 0.3, tw + ext, y, 0.0, 0.18, trim)
		_rect(pk, kit, "ashlar", wf, -0.35 if i % 2 == 0 else 0.0, CH_TOP - 0.45, tw + (0.35 if i % 2 == 0 else 0.0), CH_TOP, 0.0, 0.35, trim)
		# Corner buttresses (none on the east face, which the nave's roof meets).
		if i != 2:
			var us: Array = [0.6, tw - 0.6]
			for u in us:
				if i == 1 and u > tw * 0.5 or i == 3 and u < tw * 0.5:
					continue
				_buttress(pk, kit, wf, u, 1.2, 1.6, [[11.0, 1.2], [22.0, 0.8]], 30.0, stone.lightened(0.03))
		# The clock and the belfry.
		clock_face(pk, kit, wf * Vector3(tw * 0.5, 27.6, 0.0), wf.basis.z, 1.55, 10.1, 8.6)
		_ring_clock(pk, kit, wf, tw * 0.5, 27.6, trim)
		for side in [-1.0, 1.0]:
			_belfry_opening(pk, kit, wf, tw * 0.5 + side * 1.6, 31.4, 1.6, 4.9, trim)
		if i == 1 or i == 3:
			_gothic_window(pk, kit, wf, tw * 0.5, 15.0, 0.9, 4.2, trim, false)
			_gothic_window(pk, kit, wf, tw * 0.5, 3.5, 0.9, 4.0, trim, false)
	# The west front: the portal, its steps, the window over it, a plaque with the church's name.
	var west: Transform3D = faces[0]
	_portal(pk, kit, west, tw * 0.5, 4.2, 1.8, trim)
	_gothic_window(pk, kit, west, tw * 0.5, 12.9, 3.2, 8.2, trim, true)
	_rect(pk, kit, "ashlar", west, tw * 0.5 + 3.4, 2.2, tw * 0.5 + 5.2, 3.2, 0.0, 0.08, trim.lightened(0.08))
	labels.append(["St. Lamberti", west * Vector3(tw * 0.5 + 4.3, 2.78, 0.1), Vector3(0, 0, 1), 0.2, Color(0.2, 0.16, 0.12), 1.6])
	labels.append(["1487", west * Vector3(tw * 0.5 + 4.3, 2.45, 0.1), Vector3(0, 0, 1), 0.14, Color(0.2, 0.16, 0.12), 1.6])
	# --- The spire: an octagon on the tower's top, broaches over the corners.
	var tc := Vector3(0.0, 0.0, -CH_TD * 0.5)
	var a: float = CH_TH + 0.38
	var y0: float = CH_TOP - 0.05
	var apex: Vector3 = tc + Vector3(0, CH_SPIRE, 0)
	var rr: float = a / cos(PI / 8.0)
	var oct: Array = []
	for k in range(8):
		var th: float = PI / 8.0 + PI / 4.0 * float(k)
		oct.append(tc + Vector3(cos(th) * rr, y0, sin(th) * rr))
	for k in range(8):
		var p1: Vector3 = oct[k]
		var p2: Vector3 = oct[(k + 1) % 8]
		var out: Vector3 = (p2 - p1).cross(apex - p1).normalized()
		if out.dot((p1 + p2) * 0.5 - tc) < 0.0:
			out = -out
		gable(pk, kit, "kslate", p1, p2, apex, SLATE, out)
		if k % 2 == 0:
			# Faces k = 0, 2, 4, 6 are the diagonal ones (between 22.5 and 67.5 degrees...): a broach over the corner.
			var thc: float = PI / 4.0 + PI / 2.0 * float(k / 2)
			var c: Vector3 = tc + Vector3(cos(thc), 0, sin(thc)) * a * sqrt(2.0) + Vector3(0, y0, 0)
			var m: Vector3 = ((p1 + p2) * 0.5).lerp(apex, 0.17)
			var o1: Vector3 = (c - p1).cross(m - p1).normalized()
			if o1.y < 0.0:
				o1 = -o1
			var o2: Vector3 = (p2 - c).cross(m - c).normalized()
			if o2.y < 0.0:
				o2 = -o2
			gable(pk, kit, "kslate", p1, c, m, SLATE, o1)
			gable(pk, kit, "kslate", c, p2, m, SLATE, o2)
	# Lucarnes on the cardinal faces (KronburgTownKit's dormer on the spire's slope), the ball, the weathercock.
	var ts: float = (CH_SPIRE - y0) / a
	var ls := {"infill_key": "kslate", "infill": SLATE, "roof_key": "kslate", "roof": SLATE, "trim": SLATE.darkened(0.35), "casing": false,
			"beam": BEAM_BLACK, "cross": false, "mann": false}
	for k in range(4):
		var dvec := Vector3(cos(PI * 0.5 * float(k)), 0, sin(PI * 0.5 * float(k)))
		var xi: Vector3 = -dvec
		var lrf := Transform3D(Basis(xi, Vector3.UP, xi.cross(Vector3.UP)), tc + dvec * a)
		_dormer(pk, kit, lrf, {"t": ts, "top0": y0}, 0.0, (44.5 - y0) / ts, 1.3, ls, null)
	pk.tube(kit, "steel", apex - Vector3(0, 0.6, 0), apex + Vector3(0, 3.3, 0), 0.07, 0.05, 8, CAST, true)
	pk.lathe(kit, "gold", apex + Vector3(0, 0.25, 0), [Vector2(0.001, 0.0), Vector2(0.35, 0.1), Vector2(0.55, 0.45), Vector2(0.55, 0.65), Vector2(0.35, 1.0), Vector2(0.001, 1.1)], 12, KR_GOLD)
	var cock := PackedVector2Array([Vector2(-0.7, 0.05), Vector2(-0.35, 0.0), Vector2(0.2, 0.0), Vector2(0.45, 0.25), Vector2(0.62, 0.62), Vector2(0.5, 0.75),
		Vector2(0.62, 0.9), Vector2(0.48, 0.95), Vector2(0.4, 0.82), Vector2(0.22, 0.45), Vector2(-0.2, 0.42), Vector2(-0.55, 0.85), Vector2(-0.75, 0.75),
		Vector2(-0.62, 0.35)])
	_prism(pk, kit, "gold", Transform3D(Basis(), apex + Vector3(0, 2.3, 0)), cock, -0.025, 0.025, KR_GOLD, Vector2(0, 1), true)
	pk.beam(kit, "steel", apex + Vector3(-0.9, 1.75, 0), apex + Vector3(0.9, 1.75, 0), 0.04, 0.04, CAST)
	pk.beam(kit, "steel", apex + Vector3(0, 1.8, -0.9), apex + Vector3(0, 1.8, 0.9), 0.04, 0.04, CAST)
	# --- The nave.
	var nl: float = -CH_TD - CH_NZ
	var nface_s := _wf(Vector3(CH_NH, 0, -CH_TD), Vector3(1, 0, 0))
	var nface_n := _wf(Vector3(-CH_NH, 0, CH_NZ), Vector3(-1, 0, 0))
	for wf2 in [nface_s, nface_n]:
		_face(pk, kit, "ashlar", wf2, 0.0, FOOT, nl, CH_NE, 0.0, stone)
		_rect(pk, kit, "ashlar", wf2, 0.0, 0.0, nl, 0.6, 0.0, 0.16, trim)
		_rect(pk, kit, "ashlar", wf2, 0.0, CH_NE - 0.5, nl, CH_NE, 0.0, 0.3, trim)
		for b in range(6):
			var uc: float = nl * (float(b) + 0.5) / 6.0
			_gothic_window(pk, kit, wf2, uc, 4.4, 2.4, 8.6, trim, true)
		for b in range(1, 7):
			# Bay lines from the tower east; the north wall's u runs from the east end.
			var ub: float = nl * float(b) / 6.0 - (0.6 if b == 6 else 0.0)
			if wf2 == nface_n:
				ub = nl - nl * float(b) / 6.0 + (0.6 if b == 6 else 0.0)
			_buttress(pk, kit, wf2, ub, 1.1, 1.7, [[9.0, 1.1]], CH_NE - 1.2, stone.lightened(0.03))
	# The nave's west wall beside the tower and its gable, and the east gable with an oculus.
	var t: float = tan(deg_to_rad(52.0))
	var ridge_u: float = CH_NE + 0.08 - 0.09 + t * CH_NH
	var ngw := _wf(Vector3(-CH_NH, 0, -CH_TD), Vector3(0, 0, 1))
	_face(pk, kit, "ashlar", ngw, 0.0, FOOT, 1.0, CH_NE, 0.0, stone)
	_face(pk, kit, "ashlar", ngw, CH_NH * 2.0 - 1.0, FOOT, CH_NH * 2.0, CH_NE, 0.0, stone)
	_pface(pk, kit, "ashlar", ngw, PackedVector2Array([Vector2(0, CH_NE), Vector2(CH_NH * 2.0, CH_NE), Vector2(CH_NH, ridge_u)]), 0.0, stone)
	var nge := _wf(Vector3(CH_NH, 0, CH_NZ), Vector3(0, 0, -1))
	_face(pk, kit, "ashlar", nge, 0.0, FOOT, CH_NH * 2.0, CH_NE, 0.0, stone)
	_pface(pk, kit, "ashlar", nge, PackedVector2Array([Vector2(0, CH_NE), Vector2(CH_NH * 2.0, CH_NE), Vector2(CH_NH, ridge_u)]), 0.0, stone)
	_pface(pk, kit, "pane", nge, _circle_pts(Vector2(CH_NH, CH_NE + 3.4), 1.25, 16), 0.03, LEAD)
	_circle_ring(pk, kit, "ashlar", nge, Vector2(CH_NH, CH_NE + 3.4), 1.25, 1.6, 0.0, 0.22, trim, 16)
	# Its tracery: four bars crossing in the middle, as one star-shaped outline.
	var oc := Vector2(CH_NH, CH_NE + 3.4)
	var bars: Array = []
	for k in range(4):
		var ang: float = PI * 0.25 * float(k)
		var dv := Vector2(cos(ang), sin(ang))
		bars.append_array(_clip(_band(oc - dv, oc + dv, 0.13), _circle_pts(oc, 1.27, 16)))
	_timbers(pk, kit, nge, _union(bars), trim, Vector2(0, 1), 0.12)
	var nrf := Transform3D(Basis(), Vector3(-CH_NH, 0, 0))
	_roof(pk, kit, nrf, CH_NH * 2.0, CH_NZ, -CH_TD, CH_NE, 52.0, 0.55, 0.4, "kslate", SLATE, SLATE.darkened(0.45), true, 1)
	# --- The choir and its apse.
	var cl: float = CH_NZ - CH_CZ
	var cs := _wf(Vector3(CH_CH, 0, CH_NZ), Vector3(1, 0, 0))
	var cn := _wf(Vector3(-CH_CH, 0, CH_CZ), Vector3(-1, 0, 0))
	for wf3 in [cs, cn]:
		_face(pk, kit, "ashlar", wf3, 0.0, FOOT, cl, CH_CE, 0.0, stone)
		_rect(pk, kit, "ashlar", wf3, 0.0, CH_CE - 0.45, cl, CH_CE, 0.0, 0.28, trim)
		_gothic_window(pk, kit, wf3, cl * 0.5, 4.0, 2.0, 7.4, trim, true)
	var crf := Transform3D(Basis(), Vector3(-CH_CH, 0, 0))
	var cr := _roof(pk, kit, crf, CH_CH * 2.0, CH_CZ, CH_NZ, CH_CE, 55.0, 0.45, 0.4, "kslate", SLATE, SLATE.darkened(0.45), true, 0)
	var apse: Array = []
	for k in range(5):
		var th2: float = -PI * 0.25 * float(k)
		apse.append(Vector3(cos(th2) * CH_CH, 0.0, CH_CZ + sin(th2) * CH_CH))
	var ridge_end := Vector3(0.0, float(cr["ridge"]), CH_CZ)
	var t2: float = cr["t"]
	var oh := 0.45
	var eave_y: float = CH_CE + 0.08 - t2 * oh
	var eaves: Array = []
	for k in range(5):
		var p: Vector3 = apse[k]
		var nprev: Vector3 = Vector3(1, 0, 0) if k == 0 else _apse_normal(apse[k - 1], apse[k])
		var nnext: Vector3 = Vector3(-1, 0, 0) if k == 4 else _apse_normal(apse[k], apse[k + 1])
		var bis: Vector3 = (nprev + nnext).normalized()
		eaves.append(Vector3(p.x, eave_y, p.z) + bis * oh / maxf(bis.dot(nnext), 0.3))
	for k in range(4):
		var p0: Vector3 = apse[k]
		var p1: Vector3 = apse[k + 1]
		var n4 := _apse_normal(p0, p1)
		var awf := _wf(p0, n4)
		var al: float = p0.distance_to(p1)
		_face(pk, kit, "ashlar", awf, 0.0, FOOT, al, CH_CE, 0.0, stone)
		_rect(pk, kit, "ashlar", awf, 0.0, CH_CE - 0.45, al, CH_CE, 0.0, 0.28, trim)
		_gothic_window(pk, kit, awf, al * 0.5, 4.0, 1.7, 7.0, trim, false)
		if k > 0:
			_buttress(pk, kit, awf, 0.0, 0.9, 1.3, [[7.5, 0.9]], CH_CE - 1.3, stone.lightened(0.03))
		var up: Vector3 = (eaves[k + 1] - eaves[k]).cross(ridge_end - eaves[k]).normalized()
		if up.y < 0.0:
			up = -up
		pk.tri(kit, "kslate", eaves[k], eaves[k + 1], ridge_end, up, up, up, SLATE, up, Vector2.ZERO, Vector2(al, 0) * uvk, Vector2(al * 0.5, 5.0) * uvk)
		var dn := Vector3(0, -0.09, 0)
		pk.tri(kit, "lapboards", eaves[k] + dn, eaves[k + 1] + dn, ridge_end + dn, -up, -up, -up, Color(0.4, 0.3, 0.22), -up)
	# Fill between the choir's straight roof planes and the apse's first and last.
	for side in [-1.0, 1.0]:
		var e0: Vector3 = Vector3(side * (CH_CH + oh), eave_y, CH_CZ)
		var e1: Vector3 = eaves[0] if side > 0.0 else eaves[4]
		var up2: Vector3 = (e1 - e0).cross(ridge_end - e0).normalized()
		if up2.y < 0.0:
			up2 = -up2
		pk.tri(kit, "kslate", e0, e1, ridge_end, up2, up2, up2, SLATE, up2)
		pk.tri(kit, "lapboards", e0 + Vector3(0, -0.09, 0), e1 + Vector3(0, -0.09, 0), ridge_end + Vector3(0, -0.09, 0), -up2, -up2, -up2, Color(0.4, 0.3, 0.22), -up2)


## The outward normal of the apse face from a to b (it runs clockwise seen from above, round the east end).
static func _apse_normal(a: Vector3, b: Vector3) -> Vector3:
	var e: Vector3 = (b - a).normalized()
	var n := Vector3(e.z, 0.0, -e.x)
	if n.dot((a + b) * 0.5 - Vector3(0, 0, CH_CZ)) < 0.0:
		n = -n
	return n


static func _circle_pts(c: Vector2, r: float, segs: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(segs):
		var a: float = TAU * float(k) / float(segs)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## A dressed stone ring round a tower clock.
static func _ring_clock(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v: float, col: Color) -> void:
	_circle_ring(pk, kit, "ashlar", wf, Vector2(u, v), 1.85, 2.15, 0.0, 0.14, col, 20)


## A belfry opening: a pointed opening dark inside, louvre boards slanting down and out across it, a dressed surround.
static func _belfry_opening(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, sill: float, w: float, h: float, col: Color) -> void:
	var half: float = w * 0.5
	var spring: float = sill + h - 1.483 * half
	_pface(pk, kit, "matte", wf, _opening(u, sill, half, spring), 0.02, Color(0.04, 0.04, 0.05))
	_arch_ring(pk, kit, "ashlar", wf, u, spring, half, "pointed", 0.26, 0.0, 0.2, col, sill, 10)
	_rect(pk, kit, "ashlar", wf, u - half - 0.3, sill - 0.22, u + half + 0.3, sill, 0.0, 0.26, col)
	var n: int = int((spring - sill) / 0.42)
	for k in range(n):
		var y: float = sill + 0.3 + 0.42 * float(k)
		pk.quad(kit, "timber", [wf * Vector3(u - half, y + 0.16, 0.04), wf * Vector3(u + half, y + 0.16, 0.04), wf * Vector3(u + half, y - 0.12, 0.18),
				wf * Vector3(u - half, y - 0.12, 0.18)], (wf.basis * Vector3(0, 0.45, 0.28)).normalized(), Color(0.30, 0.24, 0.18))


## The west portal: a pointed doorway `half` wide springing at `spring`, three archivolts stepping out from it on their own
## jambs, oak doors with iron straps filling the arch, steps in front.
static func _portal(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, spring: float, half: float, col: Color) -> void:
	var h: float = half
	var sharp := 0.8
	var depth := 0.2
	for k in range(3):
		_arch_ring(pk, kit, "ashlar", wf, u, spring, h, "pointed", 0.32, 0.0, depth, col.lightened(0.03 * float(k)), 0.0, 12, 0.0, sharp)
		var nh: float = h + 0.32
		sharp = (h * 2.0 * sharp + 0.32) / (2.0 * nh)
		h = nh
		depth += 0.2
	# A gablet (wimperg) over the archivolts.
	var top: float = spring + h * 2.0 * sharp * 0.92 + 0.1
	var tri_w := PackedVector2Array([Vector2(u - h - 0.4, spring + 0.2), Vector2(u + h + 0.4, spring + 0.2), Vector2(u, top + 2.2)])
	for piece in Geometry2D.clip_polygons(tri_w, _opening(u, 0.0, h, spring)):
		if not Geometry2D.is_polygon_clockwise(piece):
			_prism(pk, kit, "ashlar", wf, piece, 0.0, 0.16, col)
	var door := _opening(u, 0.6, half, spring)
	_pface(pk, kit, "painted", wf, door, 0.025, Color(0.30, 0.19, 0.11))
	_rect(pk, kit, "painted", wf, u - 0.03, 0.0, u + 0.03, spring + 1.3, 0.025, 0.05, Color(0.22, 0.14, 0.08))
	for y in [1.2, 2.4, 3.6]:
		for side in [-1.0, 1.0]:
			_face(pk, kit, "steel", wf, u + (side * 0.12 if side > 0.0 else -half + 0.06), y, u + (half - 0.06 if side > 0.0 else -0.12), y + 0.09, 0.04, CAST)
	pk.tube(kit, "steel", wf * Vector3(u - 0.3, 1.8, 0.04), wf * Vector3(u - 0.3, 1.8, 0.12), 0.12, 0.12, 10, CAST)
	_steps(pk, kit, wf, u, 0.6, h * 2.0 + 1.6, 0.0, KIRCH_TRIM)


# ======================================================================================
#  Shared: plan prisms, cylinders, cones, the town's arms, cross windows
# ======================================================================================

## The plan frame: a 2D outline in (x, -z) extruded up its y (`_prism`'s depth is the height).
const PLAN := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))


## An outline in plan (x, -z, relative to `c`) standing from y0 to y1: its top, its sides (UVs: along the outline and
## the height, so masonry courses run level), its underside with `bottom`.
static func _plan_prism(pk: PropKit, kit: Dictionary, key: String, c: Vector3, ol: PackedVector2Array, y0: float, y1: float, col: Color, bottom := false) -> void:
	_prism(pk, kit, key, Transform3D(PLAN, Vector3(c.x, 0.0, c.z)), ol, y0, y1, col, Vector2(0, 1), bottom, true)


## A regular polygon of `n` corners on radius r, the first at angle a0 (in plan, x and -z).
static func _ngon(r: float, n: int, a0 := 0.0, c := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(n):
		var a: float = a0 + TAU * float(k) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## An upright cylinder's wall round `c` (radius r, y0 to y1) from angle a0 to a1, facing out (or in), UVs in metres
## (round it, up it).
static func _cyl_wall(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, y0: float, y1: float, col: Color, segs: int, a0 := 0.0,
		a1 := TAU, inward := false) -> void:
	for k in range(segs):
		var t0: float = lerpf(a0, a1, float(k) / float(segs))
		var t1: float = lerpf(a0, a1, float(k + 1) / float(segs))
		var e0 := Vector3(cos(t0), 0, sin(t0))
		var e1 := Vector3(cos(t1), 0, sin(t1))
		var n0: Vector3 = -e0 if inward else e0
		var n1: Vector3 = -e1 if inward else e1
		var u0: float = r * t0
		var u1: float = r * t1
		var pa: Vector3 = c + e0 * r + Vector3(0, y0, 0)
		var pb: Vector3 = c + e1 * r + Vector3(0, y0, 0)
		var pc: Vector3 = c + e1 * r + Vector3(0, y1, 0)
		var pd: Vector3 = c + e0 * r + Vector3(0, y1, 0)
		var nm: Vector3 = (n0 + n1).normalized()
		pk.tri(kit, key, pa, pb, pc, n0, n1, n1, col, nm, Vector2(u0, y0) * uvk, Vector2(u1, y0) * uvk, Vector2(u1, y1) * uvk)
		pk.tri(kit, key, pa, pc, pd, n0, n1, n0, col, nm, Vector2(u0, y0) * uvk, Vector2(u1, y1) * uvk, Vector2(u0, y1) * uvk)


## A cone (a turret's roof) on the circle round `c` at height y0, radius r, its apex h above: UVs round the base and up
## the slope, so slate courses run level.
static func _cone(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, y0: float, h: float, col: Color, segs := 16) -> void:
	var apex: Vector3 = c + Vector3(0, y0 + h, 0)
	var sl: float = sqrt(r * r + h * h)
	for k in range(segs):
		var t0: float = TAU * float(k) / float(segs)
		var t1: float = TAU * float(k + 1) / float(segs)
		var e0 := Vector3(cos(t0), 0, sin(t0))
		var e1 := Vector3(cos(t1), 0, sin(t1))
		var n0: Vector3 = (e0 * h + Vector3(0, r, 0)).normalized()
		var n1: Vector3 = (e1 * h + Vector3(0, r, 0)).normalized()
		var nm: Vector3 = (n0 + n1).normalized()
		var pa: Vector3 = c + e0 * r + Vector3(0, y0, 0)
		var pb: Vector3 = c + e1 * r + Vector3(0, y0, 0)
		pk.tri(kit, key, pa, pb, apex, n0, n1, nm, col, nm, Vector2(r * t0, 0) * uvk, Vector2(r * t1, 0) * uvk, Vector2(r * (t0 + t1) * 0.5, sl) * uvk)


## Kronburg's arms on a wall at (u, v) (the shield's middle), `s` metres tall: a red heater shield edged in gold, a gold
## crown on it with three points, each tipped with a ball, and two red jewels in its band.
static func _arms(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v: float, s: float, d := 0.0) -> void:
	var shield := PackedVector2Array()
	var pts: Array = [Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.05)]
	for k in range(1, 6):
		var t: float = float(k) / 6.0
		pts.append(Vector2(0.5 * cos(t * PI * 0.5), 0.05 - 0.55 * sin(t * PI * 0.5) * 1.0).lerp(Vector2(0.0, -0.5), t * t * 0.4))
	pts.append(Vector2(0.0, -0.52))
	for k in range(5, 0, -1):
		var t2: float = float(k) / 6.0
		var q: Vector2 = Vector2(0.5 * cos(t2 * PI * 0.5), 0.05 - 0.55 * sin(t2 * PI * 0.5)).lerp(Vector2(0.0, -0.5), t2 * t2 * 0.4)
		pts.append(Vector2(-q.x, q.y))
	pts.append(Vector2(-0.5, 0.05))
	for q2 in pts:
		shield.append(Vector2(u, v) + q2 * s)
	var rim := PackedVector2Array()
	for q3 in pts:
		rim.append(Vector2(u, v) + (q3 * 1.1 + Vector2(0, 0.01)) * s)
	_prism(pk, kit, "gold", wf, rim, d, d + 0.04 * s, KR_GOLD)
	_prism(pk, kit, "enamel", wf, shield, d, d + 0.07 * s, KR_RED)
	var crown := PackedVector2Array([Vector2(-0.3, -0.12), Vector2(0.3, -0.12), Vector2(0.3, 0.03), Vector2(0.34, 0.24), Vector2(0.17, 0.08),
		Vector2(0.0, 0.3), Vector2(-0.17, 0.08), Vector2(-0.34, 0.24), Vector2(-0.3, 0.03)])
	var cr := PackedVector2Array()
	for q4 in crown:
		cr.append(Vector2(u, v + 0.06 * s) + q4 * s)
	_prism(pk, kit, "gold", wf, cr, d + 0.07 * s, d + 0.1 * s, KR_GOLD)
	for tip in [Vector2(0.34, 0.27), Vector2(0.0, 0.33), Vector2(-0.34, 0.27)]:
		_blob(pk, kit, "gold", wf * Vector3(u + tip.x * s, v + 0.06 * s + tip.y * s, d + 0.1 * s), Vector3.ONE * 0.04 * s, KR_GOLD)
	for jx in [-0.15, 0.15]:
		_blob(pk, kit, "enamel", wf * Vector3(u + jx * s, v + 0.0, d + 0.105 * s), Vector3.ONE * 0.03 * s, KR_RED.darkened(0.2))


## A stone cross window (Kreuzstockfenster): the opening [u ± w/2] x [v0, v0 + h], a dressed frame round it, a mullion and a
## transom at two thirds, leaded panes, a sill; with `pediment` a triangular pediment on a cornice over it.
static func _cross_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, h: float, col: Color, pediment := false,
		key := "ashlar") -> void:
	var x0: float = u - w * 0.5
	var x1: float = u + w * 0.5
	var f := 0.16
	_face(pk, kit, "pane", wf, x0, v0, x1, v0 + h, 0.02, LEAD.lightened(0.04))
	_ring_rect(pk, kit, key, wf, x0 - f, v0 - f, x1 + f, v0 + h + f, f, 0.0, 0.1, col)
	var tv: float = v0 + h * 0.66
	_rect(pk, kit, key, wf, x0, tv - 0.06, x1, tv + 0.06, 0.0, 0.07, col)
	_rect(pk, kit, key, wf, u - 0.06, v0, u + 0.06, tv - 0.06, 0.0, 0.07, col)
	_rect(pk, kit, key, wf, u - 0.06, tv + 0.06, u + 0.06, v0 + h, 0.0, 0.07, col)
	_rect(pk, kit, key, wf, x0 - f - 0.08, v0 - f - 0.12, x1 + f + 0.08, v0 - f, 0.0, 0.16, col)
	if pediment:
		var top: float = v0 + h + f
		_rect(pk, kit, key, wf, x0 - f - 0.12, top, x1 + f + 0.12, top + 0.14, 0.0, 0.16, col)
		_prism(pk, kit, key, wf, PackedVector2Array([Vector2(x0 - f - 0.1, top + 0.14), Vector2(x1 + f + 0.1, top + 0.14), Vector2(u, top + 0.14 + w * 0.32)]),
				0.0, 0.12, col)


## Quoins up a building's corner on one wall (in its frame, at u = 0 or u = length), long and short blocks in turn,
## 4cm proud, from v0 to v1.
static func _quoins(pk: PropKit, kit: Dictionary, wf: Transform3D, at_end: bool, length: float, v0: float, v1: float, col: Color, first_long := true) -> void:
	var y: float = v0
	var k := 0
	while y + 0.5 <= v1:
		var lng: bool = (k % 2 == 0) == first_long
		var bw: float = 0.85 if lng else 0.5
		if at_end:
			_rect(pk, kit, "ashlar", wf, length - bw, y + 0.02, length, y + 0.5, 0.0, 0.04, col)
		else:
			_rect(pk, kit, "ashlar", wf, 0.0, y + 0.02, bw, y + 0.5, 0.0, 0.04, col)
		y += 0.52
		k += 1


# ======================================================================================
#  The town hall
# ======================================================================================

const RH_W := 22.0
const RH_D := 14.0
const RH_ARCADE := 3.6
const RH_H0 := 5.0
const RH_F1 := 5.9
const RH_F2 := 10.0
const RH_EAVE := 14.0
const RH_PLASTER := Color(0.93, 0.84, 0.64)


## The town hall (Rathaus) on the market square: its front on z = 0 facing +z (the balcony reaches 1.3m out), x from 0 to
## 22, 14m deep. An open arcade of five round arches on sandstone piers along the ground floor (a paved walk 3.6m deep
## behind them, the main door and windows in its back wall), a frieze with RATHAUS, two plastered upper floors with quoins
## and cross windows (pediments on the first floor), a balcony on corbels over the middle arch, a stepped gable
## (Treppengiebel) to the square with the town's arms and the date, a plain tile roof behind it, and a bell turret on
## the ridge.
static func rathaus(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var W := RH_W
	var D := RH_D
	var stone := SANDSTONE
	var trim := SANDSTONE.lightened(0.08)
	var plaster := RH_PLASTER
	var front := _wf(Vector3.ZERO, Vector3(0, 0, 1))
	var axes: Array = []
	for i in range(5):
		axes.append(1.0 + 1.6 + 4.2 * float(i))
	# --- The arcade.
	_face(pk, kit, "ashlar", front, 0.0, FOOT, W, 0.0, 0.0, stone)
	var ops: Array = []
	for ax in axes:
		ops.append([ax, 1.6, 3.0, "round"])
	_arcade_wall(pk, kit, "ashlar", front, 0.0, 0.0, W, RH_H0, ops, -0.9, 0.0, stone, true)
	for i in range(6):
		var px: float = 0.5 + 4.2 * float(i)
		_rect(pk, kit, "ashlar", front, px - 0.62, 2.78, px + 0.62, 3.0, 0.0, 0.1, trim)
		_rect(pk, kit, "ashlar", front, px - 0.58, 0.0, px + 0.58, 0.45, 0.0, 0.08, trim)
	for ax2 in axes:
		_arch_ring(pk, kit, "ashlar", front, ax2, 3.0, 1.6, "round", 0.3, 0.0, 0.06, trim, NAN, 12)
		_rect(pk, kit, "ashlar", front, float(ax2) - 0.2, 4.45, float(ax2) + 0.2, 4.95, 0.06, 0.12, trim.lightened(0.05))
	_wblock(pk, kit, "concrete", Vector3(0.02, -0.6, -RH_ARCADE), Vector3(W - 0.02, 0.1, -0.02), Color(0.58, 0.56, 0.52))
	pk.quad(kit, "plaster", [Vector3(0, 4.72, -0.9), Vector3(0, 4.72, -RH_ARCADE), Vector3(W, 4.72, -RH_ARCADE), Vector3(W, 4.72, -0.9)], Vector3.DOWN,
			Color(0.95, 0.93, 0.88))
	for bx in axes:
		pk.block(kit, "timber", Vector3(float(bx) - 0.12, 4.42, -RH_ARCADE), Vector3(float(bx) + 0.12, 4.72, -0.9), Color(0.33, 0.22, 0.14), uvk)
	var inner := _wf(Vector3(0, 0, -RH_ARCADE), Vector3(0, 0, 1))
	_face(pk, kit, "ashlar", inner, 0.0, 0.1, W, 4.72, 0.0, stone.lightened(0.04))
	_face(pk, kit, "ashlar", _wf(Vector3(0, 0, -0.9), Vector3(1, 0, 0)), 0.0, 0.1, RH_ARCADE - 0.9, 4.72, 0.0, stone.lightened(0.04))
	_face(pk, kit, "ashlar", _wf(Vector3(W, 0, -RH_ARCADE), Vector3(-1, 0, 0)), 0.0, 0.1, RH_ARCADE - 0.9, 4.72, 0.0, stone.lightened(0.04))
	for i2 in range(5):
		if i2 == 2:
			_round_door(pk, kit, inner, axes[i2], 0.1, 2.2, 3.3, Color(0.30, 0.18, 0.10), trim)
		else:
			_cross_window(pk, kit, inner, axes[i2], 1.3, 1.2, 1.9, trim)
	# --- The upper floors.
	_face(pk, kit, "plaster", front, 0.0, RH_H0, W, RH_EAVE, 0.0, plaster)
	_rect(pk, kit, "ashlar", front, -0.05, RH_H0, W + 0.05, RH_F1, 0.0, 0.12, trim)
	# The name on the main cornice under the gable (the balcony's corbels hang over the frieze below it).
	labels.append(["RATHAUS", Vector3(W * 0.5, RH_EAVE - 0.225, 0.42), Vector3(0, 0, 1), 0.3, KR_GOLD.lightened(0.1), 6.0])
	_rect(pk, kit, "ashlar", front, -0.05, RH_F2 - 0.25, W + 0.05, RH_F2, 0.0, 0.14, trim)
	_rect(pk, kit, "ashlar", front, -0.3, RH_EAVE - 0.45, W + 0.3, RH_EAVE, 0.0, 0.4, trim)
	_quoins(pk, kit, front, false, W, RH_F1, RH_EAVE - 0.45, trim)
	_quoins(pk, kit, front, true, W, RH_F1, RH_EAVE - 0.45, trim)
	for i3 in range(5):
		var ax3: float = axes[i3]
		if i3 == 2:
			_balcony_door(pk, kit, front, ax3, RH_F1 + 0.05, 1.5, 3.0, trim)
		else:
			_cross_window(pk, kit, front, ax3, RH_F1 + 0.9, 1.3, 2.4, trim, true)
		_cross_window(pk, kit, front, ax3, RH_F2 + 0.75, 1.3, 2.2, trim)
	_balcony(pk, kit, axes[2], RH_F1, trim)
	# --- The sides and the back.
	var sides: Array = [_wf(Vector3(W, 0, 0), Vector3(1, 0, 0)), _wf(Vector3(0, 0, -D), Vector3(-1, 0, 0))]
	for si in range(2):
		var swf: Transform3D = sides[si]
		var front_end: bool = si == 1
		# Ground floor: dressed stone behind the arcade's end, plaster above, quoins at the front corner.
		var g0: float = 0.9 if not front_end else 0.0
		var g1: float = D if not front_end else D - 0.9
		_face(pk, kit, "ashlar", swf, g0, FOOT, g1, RH_H0, 0.0, stone)
		_face(pk, kit, "plaster", swf, 0.0, RH_H0, D, RH_EAVE, 0.0, plaster)
		# The bands stop 5cm short of the front corner, where the front's own run past it.
		var b0: float = 0.05 if not front_end else 0.0
		var b1: float = D - (0.05 if front_end else 0.0)
		_rect(pk, kit, "ashlar", swf, b0, RH_H0, b1, RH_F1, 0.0, 0.12, trim)
		_rect(pk, kit, "ashlar", swf, b0, RH_F2 - 0.25, b1, RH_F2, 0.0, 0.14, trim)
		_rect(pk, kit, "ashlar", swf, b0, RH_EAVE - 0.45, b1, RH_EAVE, 0.0, 0.3, trim)
		_quoins(pk, kit, swf, front_end, D, RH_F1, RH_EAVE - 0.45, trim, false)
		for zi in [3.4, 7.0, 10.6]:
			var u: float = zi if not front_end else D - zi
			_cross_window(pk, kit, swf, u, RH_F1 + 0.9, 1.2, 2.3, trim)
			_cross_window(pk, kit, swf, u, RH_F2 + 0.75, 1.2, 2.1, trim)
		for zg in [6.4, 11.0]:
			_cross_window(pk, kit, swf, zg if not front_end else D - zg, 1.4, 1.1, 1.8, trim)
	var back := _wf(Vector3(W, 0, -D), Vector3(0, 0, -1))
	_face(pk, kit, "ashlar", back, 0.0, FOOT, W, RH_H0, 0.0, stone)
	_face(pk, kit, "plaster", back, 0.0, RH_H0, W, RH_EAVE, 0.0, plaster)
	_rect(pk, kit, "ashlar", back, -0.05, RH_EAVE - 0.45, W + 0.05, RH_EAVE, 0.0, 0.3, trim)
	for i4 in range(5):
		var bx2: float = W - float(axes[i4])
		_cross_window(pk, kit, back, bx2, RH_F1 + 0.9, 1.2, 2.3, trim)
		_cross_window(pk, kit, back, bx2, RH_F2 + 0.75, 1.2, 2.1, trim)
		if i4 == 2:
			_round_door(pk, kit, back, bx2, 0.3, 1.6, 2.7, Color(0.30, 0.18, 0.10), trim)
			_steps(pk, kit, back, bx2, 0.3, 2.2, 0.0)
		else:
			_cross_window(pk, kit, back, bx2, 1.4, 1.1, 1.8, trim)
	# --- The stepped gable, the roof, the back gable, the bell turret.
	var t: float = tan(deg_to_rad(55.0))
	var half: float = W * 0.5
	var top0: float = RH_EAVE + 0.08
	var n := 6
	var sw: float = half / (float(n) + 0.5)
	var ol := PackedVector2Array([Vector2(0, RH_EAVE), Vector2(W, RH_EAVE)])
	var tops: Array = []
	for k in range(n):
		tops.append(top0 + t * float(k + 1) * sw + 0.4)
	for k in range(n):
		ol.append(Vector2(W - sw * float(k), float(tops[k])))
		ol.append(Vector2(W - sw * float(k + 1), float(tops[k])))
	var crest: float = top0 + t * half + 0.9
	ol.append(Vector2(half + sw * 0.5, crest))
	ol.append(Vector2(half - sw * 0.5, crest))
	for k in range(n - 1, -1, -1):
		ol.append(Vector2(sw * float(k + 1), float(tops[k])))
		ol.append(Vector2(sw * float(k), float(tops[k])))
	_prism(pk, kit, "ashlar", front, ol, -0.6, 0.0, stone, Vector2(0, 1), true)
	for k in range(n):
		for side in [0, 1]:
			var xa: float = sw * float(k) if side == 0 else W - sw * float(k + 1)
			_wblock(pk, kit, "ashlar", Vector3(xa - 0.06, float(tops[k]), -0.68), Vector3(xa + sw + 0.06, float(tops[k]) + 0.14, 0.08), trim)
			pk.lathe(kit, "ashlar", Vector3(xa + (0.12 if side == 0 else sw - 0.12), float(tops[k]) + 0.14, -0.3),
					[Vector2(0.001, 0.0), Vector2(0.16, 0.0), Vector2(0.16, 0.12), Vector2(0.07, 0.2), Vector2(0.13, 0.36), Vector2(0.001, 0.5)], 8, trim)
	_wblock(pk, kit, "ashlar", Vector3(half - sw * 0.5 - 0.06, crest, -0.68), Vector3(half + sw * 0.5 + 0.06, crest + 0.16, 0.08), trim)
	pk.lathe(kit, "gold", Vector3(half, crest + 0.16, -0.3), [Vector2(0.001, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.5), Vector2(0.22, 0.65),
			Vector2(0.24, 0.8), Vector2(0.16, 0.95), Vector2(0.001, 1.0)], 10, KR_GOLD)
	for gx in [4.3, 8.0, 14.0, 17.7]:
		_cross_window(pk, kit, front, gx, RH_EAVE + 0.9, 1.0, 1.6, trim)
	_arms(pk, kit, front, half, RH_EAVE + 1.75, 1.9, 0.0)
	for gx2 in [8.4, 13.6]:
		_cross_window(pk, kit, front, gx2, RH_EAVE + 4.6, 0.9, 1.4, trim)
	_cross_window(pk, kit, front, half, RH_EAVE + 7.7, 0.9, 1.3, trim)
	_pface(pk, kit, "pane", front, _circle_pts(Vector2(half, RH_EAVE + 11.0), 0.42, 12), 0.02, LEAD)
	_circle_ring(pk, kit, "ashlar", front, Vector2(half, RH_EAVE + 11.0), 0.42, 0.62, 0.0, 0.1, trim, 12)
	labels.append(["1592", Vector3(half, RH_EAVE + 9.85, 0.05), Vector3(0, 0, 1), 0.36, Color(0.25, 0.18, 0.12), 1.6])
	var rf := Transform3D(Basis(), Vector3.ZERO)
	var r := _roof(pk, kit, rf, W, -D, -0.3, RH_EAVE, 55.0, 0.45, 0.35, "biber", BIBERS[1], Color(0.30, 0.20, 0.13), true, 1)
	var bg := _wf(Vector3(W, 0, -D), Vector3(0, 0, -1))
	var ridge_u: float = top0 - 0.09 + t * half
	_pface(pk, kit, "plaster", bg, PackedVector2Array([Vector2(0, RH_EAVE), Vector2(W, RH_EAVE), Vector2(half, ridge_u)]), 0.0, plaster)
	for gx3 in [7.0, 15.0]:
		_cross_window(pk, kit, bg, gx3, RH_EAVE + 1.2, 1.0, 1.5, trim)
	_bell_turret(pk, kit, Vector3(half, float(r["ridge"]), -D * 0.5))


## A round-arched double door: oak leaves with panels filling the arch, a dressed surround with a keystone; `v0` the sill.
static func _round_door(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, h: float, col: Color, trim: Color) -> void:
	var half: float = w * 0.5
	var spring: float = v0 + h - half
	_pface(pk, kit, "painted", wf, _opening(u, v0, half, spring, "round", 12), 0.03, col)
	_rect(pk, kit, "painted", wf, u - 0.025, v0, u + 0.025, spring + half - 0.05, 0.03, 0.06, col.darkened(0.3))
	for side in [-1.0, 1.0]:
		for k in range(3):
			var py: float = v0 + 0.2 + float(k) * (spring - v0 - 0.2) / 3.0
			_rect(pk, kit, "painted", wf, u + side * 0.1 if side > 0.0 else u - half + 0.12, py, u + half - 0.12 if side > 0.0 else u - 0.1, py + (spring - v0 - 0.2) / 3.0 - 0.15,
					0.03, 0.05, col.lightened(0.08))
	_arch_ring(pk, kit, "ashlar", wf, u, spring, half, "round", 0.26, 0.0, 0.14, trim, v0, 12)
	_rect(pk, kit, "ashlar", wf, u - 0.16, spring + half - 0.05, u + 0.16, spring + half + 0.36, 0.14, 0.2, trim.lightened(0.06))
	pk.tube(kit, "gold", wf * Vector3(u - 0.18, v0 + 1.1, 0.05), wf * Vector3(u - 0.18, v0 + 1.1, 0.12), 0.05, 0.05, 8, BRASS)
	pk.tube(kit, "gold", wf * Vector3(u + 0.18, v0 + 1.1, 0.05), wf * Vector3(u + 0.18, v0 + 1.1, 0.12), 0.05, 0.05, 8, BRASS)


## The balcony door on the first floor: a glazed double door with a stone surround and a segmental pediment.
static func _balcony_door(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, h: float, trim: Color) -> void:
	var x0: float = u - w * 0.5
	var x1: float = u + w * 0.5
	_face(pk, kit, "pane", wf, x0, v0, x1, v0 + h, 0.02, LEAD.lightened(0.04))
	_ring_rect(pk, kit, "painted", wf, x0, v0, x1, v0 + h, 0.08, 0.0, 0.05, Color(0.20, 0.30, 0.24))
	_rect(pk, kit, "painted", wf, u - 0.04, v0 + 0.08, u + 0.04, v0 + h - 0.08, 0.02, 0.05, Color(0.20, 0.30, 0.24))
	for k in range(1, 4):
		_face(pk, kit, "painted", wf, x0 + 0.08, v0 + h * float(k) / 4.0 - 0.025, x1 - 0.08, v0 + h * float(k) / 4.0 + 0.025, 0.04, Color(0.20, 0.30, 0.24))
	_ring_rect(pk, kit, "ashlar", wf, x0 - 0.2, v0 - 0.03, x1 + 0.2, v0 + h + 0.2, 0.2, 0.0, 0.1, trim)
	_rect(pk, kit, "ashlar", wf, x0 - 0.3, v0 + h + 0.2, x1 + 0.3, v0 + h + 0.36, 0.0, 0.16, trim)
	var arc := _arch(u, v0 + h + 0.36, w * 0.5 + 0.3, "segment", 8, 0.45)
	_prism(pk, kit, "ashlar", wf, arc, 0.0, 0.12, trim)


## The balcony over the arcade's middle arch at x = u: a stone slab on three corbels, an iron railing round it.
static func _balcony(pk: PropKit, kit: Dictionary, u: float, y: float, trim: Color) -> void:
	var x0: float = u - 1.9
	var x1: float = u + 1.9
	var dz := 1.25
	# Its top 2cm over the frieze's (they had shared the plane of the first floor).
	y += 0.02
	_wblock(pk, kit, "ashlar", Vector3(x0, y - 0.3, 0.0), Vector3(x1, y, dz), trim, true, true)
	for cx in [x0 + 0.3, u, x1 - 0.3]:
		var ol := PackedVector2Array([Vector2(0.0, y - 0.28), Vector2(0.0, y - 1.2)])
		for k in range(1, 6):
			var a: float = PI - PI * 0.5 * float(k) / 5.0
			ol.append(Vector2(dz - 0.15 + cos(a) * (dz - 0.15), y - 1.2 + sin(a) * 0.92))
		_prism(pk, kit, "ashlar", Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), Vector3(float(cx) + 0.12, 0, 0)), ol, 0.0, 0.24, trim, Vector2(0, 1), true)
	var iron := Color(0.12, 0.13, 0.13)
	var rail: Array = [Vector3(x0 + 0.06, y, 0.02), Vector3(x0 + 0.06, y, dz - 0.06), Vector3(x1 - 0.06, y, dz - 0.06), Vector3(x1 - 0.06, y, 0.02)]
	for i in range(3):
		var a2: Vector3 = rail[i]
		var b2: Vector3 = rail[i + 1]
		pk.beam(kit, "steel", a2 + Vector3(0, 1.0, 0), b2 + Vector3(0, 1.0, 0), 0.06, 0.05, iron, Vector3.UP)
		pk.beam(kit, "steel", a2 + Vector3(0, 0.1, 0), b2 + Vector3(0, 0.1, 0), 0.04, 0.04, iron, Vector3.UP)
		var nb: int = int(a2.distance_to(b2) / 0.16)
		for k2 in range(nb + 1):
			var p: Vector3 = a2.lerp(b2, float(k2) / float(nb))
			pk.beam(kit, "steel", p + Vector3(0, 0.1, 0), p + Vector3(0, 1.0, 0), 0.022, 0.022, iron)


## A bell turret (Dachreiter) straddling a ridge at `c` (the ridge's height): a slate-hung base, an open octagonal belfry
## on posts with its bell, a pointed octagonal slate roof, a gilt ball and a vane.
static func _bell_turret(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	_wblock(pk, kit, "kslate", c + Vector3(-1.2, -1.6, -1.2), c + Vector3(1.2, 1.1, 1.2), SLATE)
	_wblock(pk, kit, "timber", c + Vector3(-1.35, 1.1, -1.35), c + Vector3(1.35, 1.28, 1.35), Color(0.30, 0.22, 0.15))
	var oct := _ngon(1.05, 8, PI / 8.0)
	for p in oct:
		pk.beam(kit, "timber", c + Vector3(p.x, 1.28, -p.y), c + Vector3(p.x, 3.3, -p.y), 0.14, 0.14, Color(0.30, 0.22, 0.15))
	for k in range(8):
		var a: Vector2 = oct[k]
		var b: Vector2 = oct[(k + 1) % 8]
		pk.beam(kit, "timber", c + Vector3(a.x, 1.9, -a.y), c + Vector3(b.x, 1.9, -b.y), 0.08, 0.1, Color(0.30, 0.22, 0.15), Vector3.UP)
	_plan_prism(pk, kit, "timber", c, _ngon(1.25, 8, PI / 8.0), c.y + 3.3, c.y + 3.5, Color(0.30, 0.22, 0.15), true)
	pk.lathe(kit, "gold", c + Vector3(0, 1.9, 0), [Vector2(0.001, 0.0), Vector2(0.42, 0.0), Vector2(0.4, 0.1), Vector2(0.3, 0.45), Vector2(0.24, 0.8),
			Vector2(0.12, 0.88), Vector2(0.001, 0.9)], 12, Color(0.72, 0.56, 0.28))
	var apex: Vector3 = c + Vector3(0, 7.2, 0)
	var ring := _ngon(1.5, 8, PI / 8.0)
	for k in range(8):
		var a3: Vector2 = ring[k]
		var b3: Vector2 = ring[(k + 1) % 8]
		var pa: Vector3 = c + Vector3(a3.x, 3.45, -a3.y)
		var pb: Vector3 = c + Vector3(b3.x, 3.45, -b3.y)
		var out: Vector3 = (pb - pa).cross(apex - pa).normalized()
		if out.dot((pa + pb) * 0.5 - c - Vector3(0, 3.45, 0)) < 0.0:
			out = -out
		gable(pk, kit, "kslate", pa, pb, apex, SLATE, out)
		pk.tri(kit, "lapboards", pa - Vector3(0, 0.03, 0), pb - Vector3(0, 0.03, 0), c + Vector3(0, 3.42, 0), Vector3.DOWN, Vector3.DOWN, Vector3.DOWN,
				Color(0.4, 0.3, 0.22), Vector3.DOWN)
	pk.tube(kit, "steel", apex - Vector3(0, 0.4, 0), apex + Vector3(0, 1.6, 0), 0.04, 0.03, 6, CAST, true)
	pk.lathe(kit, "gold", apex + Vector3(0, 0.1, 0), [Vector2(0.001, 0.0), Vector2(0.18, 0.08), Vector2(0.24, 0.24), Vector2(0.18, 0.4), Vector2(0.001, 0.48)], 10, KR_GOLD)
	_prism(pk, kit, "gold", Transform3D(Basis(), apex + Vector3(0, 1.15, 0)), PackedVector2Array([Vector2(-0.45, 0.0), Vector2(0.3, 0.0), Vector2(0.45, 0.12),
			Vector2(0.3, 0.24), Vector2(-0.45, 0.24), Vector2(-0.32, 0.12)]), -0.015, 0.015, KR_GOLD, Vector2(0, 1), true)


# ======================================================================================
#  The market fountain
# ======================================================================================

## The market fountain (Marktbrunnen), centred on the origin: an octagonal sandstone basin 7m across its corners on a
## step (from -1m, for a sloping square), raised panels on its faces, a coping, still water at 0.8m; in the middle a
## pedestal with four bronze spouts arcing water into the basin, a shaft with a shallow bowl overflowing in eight thin
## streams, a capital and a gilded crown (5.6m to its orb).
static func market_fountain(pk: PropKit, kit: Dictionary) -> void:
	var stone := SANDSTONE.lightened(0.05)
	var trim := SANDSTONE.lightened(0.12)
	var R := 3.5
	var t := 0.32
	var a0: float = PI / 8.0
	_plan_prism(pk, kit, "ashlar", Vector3.ZERO, _ngon(4.25, 8, a0), -1.0, 0.16, stone.darkened(0.08))
	var outer := _ngon(R, 8, a0)
	var inner := _ngon(R - t, 8, a0)
	var cop_o := _ngon(R + 0.1, 8, a0)
	var cop_i := _ngon(R - t - 0.06, 8, a0)
	for k in range(8):
		var k1: int = (k + 1) % 8
		_plan_prism(pk, kit, "ashlar", Vector3.ZERO, PackedVector2Array([outer[k], outer[k1], inner[k1], inner[k]]), 0.16, 0.92, stone)
		_plan_prism(pk, kit, "ashlar", Vector3.ZERO, PackedVector2Array([cop_o[k], cop_o[k1], cop_i[k1], cop_i[k]]), 0.92, 1.06, trim, true)
		# A raised panel on each outer face.
		var pa: Vector2 = outer[k]
		var pb: Vector2 = outer[k1]
		var mid: Vector2 = (pa + pb) * 0.5
		var out3 := Vector3(mid.x, 0, -mid.y).normalized()
		var fwf := _wf(Vector3(pa.x, 0, -pa.y), out3)
		var fl: float = pa.distance_to(pb)
		_ring_rect(pk, kit, "ashlar", fwf, 0.22, 0.3, fl - 0.22, 0.8, 0.07, 0.0, 0.035, trim)
	_plan_prism(pk, kit, "kwater", Vector3.ZERO, _ngon(R - t + 0.01, 8, a0), 0.5, 0.8, Color.WHITE)
	# The pedestal, its cornice, the spouts.
	_plan_prism(pk, kit, "ashlar", Vector3.ZERO, _ngon(0.62, 8, a0), 0.5, 1.75, stone)
	_plan_prism(pk, kit, "ashlar", Vector3.ZERO, _ngon(0.74, 8, a0), 1.75, 1.92, trim, true)
	var bronze := Color(0.42, 0.32, 0.20)
	var jet := Color(0.80, 0.90, 0.95)
	for k in range(4):
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		var d := Vector3(cos(a), 0, sin(a))
		var p0: Vector3 = d * 0.55 + Vector3(0, 1.35, 0)
		var p1: Vector3 = d * 0.95 + Vector3(0, 1.38, 0)
		pk.tube(kit, "metal", p0, p1, 0.07, 0.05, 8, bronze, true)
		_blob(pk, kit, "metal", d * 0.6 + Vector3(0, 1.35, 0), Vector3(0.14, 0.16, 0.14), bronze)
		var arc: Array = []
		for j in range(9):
			var s: float = float(j) / 8.0
			arc.append(p1 + d * (s * 1.5) + Vector3(0, 0.12 * s - 0.68 * s * s, 0))
		_tube_path(pk, kit, "enamel", arc, 0.035, 5, jet)
	# The shaft, the bowl and its streams, the capital and the crown.
	pk.lathe(kit, "matte", Vector3(0, 1.92, 0), [Vector2(0.001, 0.0), Vector2(0.34, 0.0), Vector2(0.34, 0.12), Vector2(0.27, 0.22), Vector2(0.25, 1.4),
			Vector2(0.23, 2.6), Vector2(0.001, 2.6)], 14, stone)
	pk.lathe(kit, "matte", Vector3(0, 2.6, 0), [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.6, 0.12), Vector2(1.05, 0.38), Vector2(1.18, 0.5),
			Vector2(1.18, 0.6), Vector2(1.1, 0.6), Vector2(1.1, 0.52), Vector2(0.001, 0.52)], 16, trim)
	pk.lathe(kit, "kwater", Vector3(0, 3.16, 0), [Vector2(0.001, 0.0), Vector2(1.11, 0.0)], 16, Color.WHITE)
	for k in range(8):
		var a2: float = TAU * float(k) / 8.0
		var d2 := Vector3(cos(a2), 0, sin(a2))
		var top: Vector3 = d2 * 1.2 + Vector3(0, 3.18, 0)
		_tube_path(pk, kit, "enamel", [top, top + d2 * 0.12 + Vector3(0, -0.2, 0), top + d2 * 0.2 + Vector3(0, -1.1, 0), d2 * 1.42 + Vector3(0, 0.8, 0)], 0.02, 4, jet)
	pk.lathe(kit, "matte", Vector3(0, 4.52, 0), [Vector2(0.001, 0.0), Vector2(0.26, 0.0), Vector2(0.36, 0.14), Vector2(0.44, 0.3), Vector2(0.001, 0.3)], 14, trim)
	_plan_prism(pk, kit, "ashlar", Vector3.ZERO, _ngon(0.5, 8, a0), 4.82, 4.96, trim, true)
	_crown(pk, kit, Vector3(0, 4.96, 0), 0.42)


## A gilded crown standing at `c`, its band radius r: a ring band set with red jewels, eight points (the tall ones tipped
## with balls), four arches to an orb with a cross.
static func _crown(pk: PropKit, kit: Dictionary, c: Vector3, r: float) -> void:
	var g := KR_GOLD
	pk.lathe(kit, "gold", c, [Vector2(r * 0.86, 0.0), Vector2(r, 0.0), Vector2(r, r * 0.55), Vector2(r * 0.86, r * 0.55), Vector2(r * 0.86, 0.0)], 16, g)
	pk.lathe(kit, "gold", c, [Vector2(0.001, 0.02), Vector2(r * 0.88, 0.02)], 16, g.darkened(0.2))
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		var tall: bool = k % 2 == 0
		var h: float = r * (0.75 if tall else 0.45)
		var base: Vector3 = c + d * r * 0.93 + Vector3(0, r * 0.55, 0)
		pk.lathe(kit, "gold", base, [Vector2(r * 0.14, 0.0), Vector2(0.001, h)], 4, g, true, Basis(Vector3.UP, a))
		if tall:
			_blob(pk, kit, "gold", base + Vector3(0, h + r * 0.05, 0), Vector3.ONE * r * 0.09, g)
			_blob(pk, kit, "enamel", c + d * r * 1.01 + Vector3(0, r * 0.28, 0), Vector3.ONE * r * 0.07, KR_RED)
		else:
			_blob(pk, kit, "enamel", c + d * r * 1.01 + Vector3(0, r * 0.28, 0), Vector3.ONE * r * 0.06, Color(0.1, 0.45, 0.25))
	var top: Vector3 = c + Vector3(0, r * 1.75, 0)
	for k in range(4):
		var a2: float = TAU * float(k) / 4.0 + PI * 0.25
		var d2 := Vector3(cos(a2), 0, sin(a2))
		var pts: Array = []
		for j in range(7):
			var s: float = float(j) / 6.0
			pts.append(c + d2 * r * 0.93 * cos(s * PI * 0.5) + Vector3(0, r * 0.55 + (r * 1.2) * sin(s * PI * 0.5), 0))
		_tube_path(pk, kit, "gold", pts, r * 0.05, 5, g)
	pk.lathe(kit, "gold", top - Vector3(0, r * 0.02, 0), [Vector2(0.001, 0.0), Vector2(r * 0.16, r * 0.06), Vector2(r * 0.22, r * 0.2), Vector2(r * 0.16, r * 0.36),
			Vector2(0.001, r * 0.42)], 10, g)
	pk.beam(kit, "gold", top + Vector3(0, r * 0.4, 0), top + Vector3(0, r * 0.75, 0), r * 0.05, r * 0.05, g)
	pk.beam(kit, "gold", top + Vector3(-r * 0.12, r * 0.62, 0), top + Vector3(r * 0.12, r * 0.62, 0), r * 0.05, r * 0.05, g)


# ======================================================================================
#  The town gate
# ======================================================================================

const GT_HW := 8.0       # the tower's half width across the road
const GT_HD := 5.0       # its half depth along the road
const GT_TOP := 22.0     # the top of its walls
const GT_OPEN := 5.0     # the arch's half span
const GT_SPRING := 8.6   # its springing: the crown is 13.6m up
const GT_WALL := 12.0    # each stub of town wall
const GT_WALL_H := 7.0   # its wall walk's height
const GATE_STONE := Color(0.62, 0.57, 0.50)


## The town gate (Stadttor, the Kronentor), centred on the origin with the road running along z through it: a rubble-stone
## tower 16m across and 10m deep, walls to 22m under a hipped slate roof with dormers (ridge 29m), a round arch 10m wide
## springing at 8.6m (13.6m at its crown, over 11m across its middle 8m) through a vaulted passage, dressed voussoirs, a
## machicolation box over the arch on the field side (+z) with the town's arms and the gate's name under it, windows
## and slits; and a stub of town wall 12m long either side (7m to its wall walk, crenellated on the field side, 2.4m
## thick). Footings to FOOT.
static func town_gate(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var stone := GATE_STONE
	var trim := SANDSTONE.lightened(0.05)
	var w2: float = GT_HW * 2.0
	for side in [1.0, -1.0]:
		var wf := _wf(Vector3(-GT_HW * side, 0, GT_HD * side), Vector3(0, 0, side))
		_face(pk, kit, "stone", wf, 0.0, FOOT, w2, 0.0, 0.0, stone)
		_arcade_wall(pk, kit, "stone", wf, 0.0, 0.0, w2, GT_TOP, [[GT_HW, GT_OPEN, GT_SPRING, "round"]], 0.0, 0.0, stone)
		_arch_ring(pk, kit, "ashlar", wf, GT_HW, GT_SPRING, GT_OPEN, "round", 0.75, 0.0, 0.22, trim, 0.0, 18)
		_rect(pk, kit, "ashlar", wf, GT_HW - 0.45, GT_SPRING + GT_OPEN + 0.7, GT_HW + 0.45, GT_SPRING + GT_OPEN + 1.35, 0.22, 0.3, trim.lightened(0.06))
		_quoins(pk, kit, wf, false, w2, 0.0, GT_TOP - 0.5, trim)
		_quoins(pk, kit, wf, true, w2, 0.0, GT_TOP - 0.5, trim, false)
		_rect(pk, kit, "ashlar", wf, -0.25, GT_TOP - 0.5, w2 + 0.25, GT_TOP, 0.0, 0.3, trim)
		for wx in [GT_HW - 4.2, GT_HW + 4.2]:
			_cross_window(pk, kit, wf, wx, 16.6, 1.0, 1.7, trim)
		for wx2 in [GT_HW - 5.5, GT_HW, GT_HW + 5.5]:
			if side < 0.0 or absf(wx2 - GT_HW) > 1.0:
				_slit(pk, kit, wf, wx2, 19.6, 1.6, trim)
		if side > 0.0:
			_machicolation(pk, kit, wf, GT_HW, 19.0, trim, stone)
			_arms(pk, kit, wf, GT_HW, 15.75, 1.1, 0.0)
			_rect(pk, kit, "ashlar", wf, GT_HW - 1.3, 16.72, GT_HW + 1.3, 17.28, 0.0, 0.06, trim.lightened(0.06))
			labels.append(["KRONENTOR", wf * Vector3(GT_HW, 17.0, 0.08), Vector3(0, 0, 1), 0.3, Color(0.22, 0.16, 0.10), 2.4])
	# The passage: its walls and the barrel vault.
	_face(pk, kit, "stone", _wf(Vector3(GT_OPEN, 0, -GT_HD), Vector3(-1, 0, 0)), 0.0, 0.0, GT_HD * 2.0, GT_SPRING, 0.0, stone.darkened(0.08))
	_face(pk, kit, "stone", _wf(Vector3(-GT_OPEN, 0, GT_HD), Vector3(1, 0, 0)), 0.0, 0.0, GT_HD * 2.0, GT_SPRING, 0.0, stone.darkened(0.08))
	var segs := 18
	for k in range(segs):
		var a0: float = PI * float(k) / float(segs)
		var a1: float = PI * float(k + 1) / float(segs)
		var p0 := Vector3(cos(a0) * GT_OPEN, GT_SPRING + sin(a0) * GT_OPEN, 0)
		var p1 := Vector3(cos(a1) * GT_OPEN, GT_SPRING + sin(a1) * GT_OPEN, 0)
		var n: Vector3 = -Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0)
		var u0: float = a0 * GT_OPEN
		var u1: float = a1 * GT_OPEN
		pk.quad(kit, "stone", [p0 + Vector3(0, 0, -GT_HD), p1 + Vector3(0, 0, -GT_HD), p1 + Vector3(0, 0, GT_HD), p0 + Vector3(0, 0, GT_HD)], n,
				stone.darkened(0.12), [Vector2(u0, -GT_HD) * uvk, Vector2(u1, -GT_HD) * uvk, Vector2(u1, GT_HD) * uvk, Vector2(u0, GT_HD) * uvk])
	# Ribs across the vault at its ends, and the portcullis' teeth hanging under the field-side arch.
	for k2 in range(1, 8):
		var px: float = lerpf(-GT_OPEN + 0.4, GT_OPEN - 0.4, float(k2) / 8.0)
		var top: float = GT_SPRING + sqrt(maxf(GT_OPEN * GT_OPEN - px * px, 0.0)) + 0.05
		pk.beam(kit, "timber", Vector3(px, top, GT_HD - 0.9), Vector3(px, top - 0.75, GT_HD - 0.9), 0.14, 0.14, Color(0.18, 0.14, 0.10))
		pk.lathe(kit, "steel", Vector3(px, top - 1.05, GT_HD - 0.9), [Vector2(0.001, 0.0), Vector2(0.07, 0.3), Vector2(0.001, 0.32)], 4, CAST, true)
	pk.beam(kit, "timber", Vector3(-GT_OPEN + 0.3, GT_SPRING + 3.5, GT_HD - 0.9), Vector3(GT_OPEN - 0.3, GT_SPRING + 3.5, GT_HD - 0.9), 0.16, 0.16, Color(0.18, 0.14, 0.10))
	# The sides.
	for side2 in [1.0, -1.0]:
		var swf := _wf(Vector3(GT_HW * side2, 0, GT_HD * side2), Vector3(side2, 0, 0))
		_face(pk, kit, "stone", swf, 0.0, FOOT, GT_HD * 2.0, GT_TOP, 0.0, stone)
		_rect(pk, kit, "ashlar", swf, 0.0, GT_TOP - 0.5, GT_HD * 2.0, GT_TOP, 0.0, 0.3, trim)
		_rect(pk, kit, "ashlar", swf, 0.0, 15.4, GT_HD * 2.0, 15.65, 0.0, 0.14, trim)
		_quoins(pk, kit, swf, false, GT_HD * 2.0, 0.0, GT_TOP - 0.5, trim, false)
		_quoins(pk, kit, swf, true, GT_HD * 2.0, 0.0, GT_TOP - 0.5, trim)
		_cross_window(pk, kit, swf, GT_HD, 16.6, 1.0, 1.7, trim)
		_slit(pk, kit, swf, GT_HD, 10.5, 1.6, trim)
		# A door onto the wall walk.
		_round_door(pk, kit, swf, GT_HD + 0.2 * side2, GT_WALL_H + 0.05, 1.1, 2.2, Color(0.30, 0.20, 0.12), trim)
	# The hipped roof.
	_hip_roof(pk, kit, GT_HW, GT_HD, GT_TOP, 55.0, 0.45, "kslate", SLATE, SLATE.darkened(0.4))
	# The town walls.
	for side3 in [1.0, -1.0]:
		_town_wall(pk, kit, side3, stone, trim)


## An arrow slit: a tall dark slot with a dressed surround, its middle at (u, v).
static func _slit(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v: float, h: float, trim: Color) -> void:
	_face(pk, kit, "matte", wf, u - 0.09, v - h * 0.5, u + 0.09, v + h * 0.5, 0.02, Color(0.04, 0.04, 0.05))
	_ring_rect(pk, kit, "ashlar", wf, u - 0.27, v - h * 0.5 - 0.18, u + 0.27, v + h * 0.5 + 0.18, 0.18, 0.0, 0.08, trim)


## A machicolation box (Pechnase) on corbels over the arch, its middle at u, its floor at v: stone corbels, a box with
## slits and a little slate roof.
static func _machicolation(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v: float, trim: Color, stone: Color) -> void:
	var bw := 3.0
	var dep := 1.05
	for k in range(4):
		var cu: float = u - bw * 0.5 + 0.2 + (bw - 0.4) * float(k) / 3.0
		var ol := PackedVector2Array([Vector2(0.0, v), Vector2(0.0, v - 1.6), Vector2(0.3, v - 1.6), Vector2(0.3, v - 1.15), Vector2(0.65, v - 1.15),
				Vector2(0.65, v - 0.6), Vector2(dep, v - 0.6), Vector2(dep, v)])
		var n: Vector3 = wf.basis.z
		var bf := Transform3D(Basis(n, Vector3.UP, n.cross(Vector3.UP)), wf * Vector3(cu + 0.15, 0, 0))
		_prism(pk, kit, "ashlar", bf, ol, 0.0, 0.3, trim, Vector2(0, 1), true)
	_rect(pk, kit, "stone", wf, u - bw * 0.5, v, u + bw * 0.5, v + 2.1, 0.0, dep, stone)
	for sx in [-0.8, 0.0, 0.8]:
		_face(pk, kit, "matte", wf, u + sx - 0.07, v + 0.6, u + sx + 0.07, v + 1.6, dep + 0.02, Color(0.04, 0.04, 0.05))
	var r0: Vector3 = wf * Vector3(u - bw * 0.5 - 0.15, v + 2.1, dep + 0.2)
	var r1: Vector3 = wf * Vector3(u + bw * 0.5 + 0.15, v + 2.1, dep + 0.2)
	var r2: Vector3 = wf * Vector3(u + bw * 0.5 + 0.15, v + 2.9, 0.0)
	var r3: Vector3 = wf * Vector3(u - bw * 0.5 - 0.15, v + 2.9, 0.0)
	var nrm: Vector3 = (wf.basis * Vector3(0, dep + 0.2, 0.8)).normalized()
	roof(pk, kit, "kslate", r0, r1, r2, r3, SLATE, nrm, true)
	var sw: Vector3 = wf.basis.x
	for e in [[u - bw * 0.5, -1.0], [u + bw * 0.5, 1.0]]:
		var ex: float = e[0]
		var sn: Vector3 = sw * float(e[1])
		pk.tri(kit, "stone", wf * Vector3(ex, v + 2.1, 0.0), wf * Vector3(ex, v + 2.1, dep), wf * Vector3(ex, v + 2.85, 0.0), sn, sn, sn, stone, sn)


## A hipped roof over a rectangle x in [-hw, hw], z in [-hd, hd] (hw > hd), walls up to `yp`: four planes overhanging by
## `oh`, boarded undersides, a ridge roll, finials and a vane.
static func _hip_roof(pk: PropKit, kit: Dictionary, hw: float, hd: float, yp: float, pitch: float, oh: float, key: String, col: Color, trim: Color) -> void:
	var t: float = tan(deg_to_rad(pitch))
	var top0: float = yp + 0.08
	var ey: float = top0 - t * oh
	var ry: float = top0 + t * hd
	var ex: float = hw + oh
	var ez: float = hd + oh
	var rx: float = hw - hd
	var e: Array = [Vector3(-ex, ey, ez), Vector3(ex, ey, ez), Vector3(ex, ey, -ez), Vector3(-ex, ey, -ez)]
	var rl := Vector3(-rx, ry, 0)
	var rr := Vector3(rx, ry, 0)
	var dn := Vector3(0, -0.09, 0)
	var board := Color(0.4, 0.3, 0.22)
	roof(pk, kit, key, e[0], e[1], rr, rl, col, Vector3(0, 1, t).normalized(), false)
	roof(pk, kit, key, e[2], e[3], rl, rr, col, Vector3(0, 1, -t).normalized(), false)
	roof(pk, kit, "lapboards", e[0] + dn, e[1] + dn, rr + dn, rl + dn, board, -Vector3(0, 1, t).normalized(), false)
	roof(pk, kit, "lapboards", e[2] + dn, e[3] + dn, rl + dn, rr + dn, board, -Vector3(0, 1, -t).normalized(), false)
	gable(pk, kit, key, e[1], e[2], rr, col, Vector3(t, 1, 0).normalized())
	gable(pk, kit, key, e[3], e[0], rl, col, Vector3(-t, 1, 0).normalized())
	pk.tri(kit, "lapboards", e[1] + dn, e[2] + dn, rr + dn, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, board, -Vector3(t, 1, 0).normalized())
	pk.tri(kit, "lapboards", e[3] + dn, e[0] + dn, rl + dn, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, board, -Vector3(-t, 1, 0).normalized())
	pk.tube(kit, "paint", rl + Vector3(-0.1, 0.03, 0), rr + Vector3(0.1, 0.03, 0), 0.09, 0.09, 6, trim, true)
	for k in range(4):
		var c0: Vector3 = e[k]
		var c1: Vector3 = rr if k == 1 or k == 2 else rl
		pk.tube(kit, "paint", c0 + Vector3(0, 0.03, 0), c1 + Vector3(0, 0.03, 0), 0.07, 0.07, 6, trim, true)
		var c2: Vector3 = e[(k + 1) % 4]
		pk.beam(kit, "timber", c0 + Vector3(0, -0.1, 0), c2 + Vector3(0, -0.1, 0), 0.24, 0.05, trim, Vector3.UP)
	for f in [rl, rr]:
		pk.tube(kit, "steel", f, f + Vector3(0, 1.6, 0), 0.04, 0.03, 6, CAST, true)
		pk.lathe(kit, "gold", f + Vector3(0, 0.3, 0), [Vector2(0.001, 0.0), Vector2(0.2, 0.1), Vector2(0.26, 0.3), Vector2(0.18, 0.5), Vector2(0.001, 0.56)], 10, KR_GOLD)
	_prism(pk, kit, "gold", Transform3D(Basis(), rr + Vector3(0, 1.3, 0)), PackedVector2Array([Vector2(-0.55, 0.0), Vector2(0.35, 0.0), Vector2(0.55, 0.15),
			Vector2(0.35, 0.3), Vector2(-0.55, 0.3), Vector2(-0.4, 0.15)]), -0.015, 0.015, KR_GOLD, Vector2(0, 1), true)
	# Two dormers on each long slope.
	for sz in [1.0, -1.0]:
		for dx in [-hw * 0.33, hw * 0.33]:
			var rf := Transform3D(Basis(Vector3(0, 0, -sz), Vector3.UP, Vector3(sz, 0, 0)), Vector3(0, 0, hd * sz))
			var ds := {"infill_key": "kslate", "infill": col, "roof_key": key, "roof": col, "trim": trim, "casing": false, "beam": BEAM_BLACK}
			_dormer(pk, kit, rf, {"t": t, "top0": top0}, dx * sz, 0.9, 1.3, ds, null)


## A stub of town wall from the gate's side (x = side * GT_HW) out GT_WALL metres: rubble faces on both sides to the wall
## walk at GT_WALL_H, a crenellated parapet with slits on the field side (+z), the walk, a timber rail on the town side, its
## end.
static func _town_wall(pk: PropKit, kit: Dictionary, side: float, stone: Color, _trim: Color) -> void:
	var x0: float = side * GT_HW
	var x1: float = side * (GT_HW + GT_WALL)
	var hz := 1.2
	var outer := _wf(Vector3(minf(x0, x1), 0, hz), Vector3(0, 0, 1))
	var innr := _wf(Vector3(maxf(x0, x1), 0, -hz), Vector3(0, 0, -1))
	_face(pk, kit, "stone", outer, 0.0, FOOT, GT_WALL, GT_WALL_H, 0.0, stone)
	_face(pk, kit, "stone", innr, 0.0, FOOT, GT_WALL, GT_WALL_H, 0.0, stone)
	_face(pk, kit, "stone", _wf(Vector3(x1, 0, side * hz), Vector3(side, 0, 0)), 0.0, FOOT, hz * 2.0, GT_WALL_H, 0.0, stone)
	pk.quad(kit, "stone", [Vector3(minf(x0, x1), GT_WALL_H, -hz), Vector3(maxf(x0, x1), GT_WALL_H, -hz), Vector3(maxf(x0, x1), GT_WALL_H, hz - 0.6),
			Vector3(minf(x0, x1), GT_WALL_H, hz - 0.6)], Vector3.UP, stone.darkened(0.05),
			[Vector2(minf(x0, x1), -hz) * uvk, Vector2(maxf(x0, x1), -hz) * uvk, Vector2(maxf(x0, x1), hz - 0.6) * uvk, Vector2(minf(x0, x1), hz - 0.6) * uvk])
	# The parapet: merlons 1.1m wide with 0.8m crenels, from the walk up 1.9m.
	var ol := PackedVector2Array([Vector2(GT_WALL, GT_WALL_H), Vector2(GT_WALL, GT_WALL_H + 1.9)])
	var u: float = GT_WALL
	var merlon := 1.1
	var gap := 0.8
	var lefts: Array = []
	while u - merlon - gap > 0.3:
		ol.append(Vector2(u - merlon, GT_WALL_H + 1.9))
		ol.append(Vector2(u - merlon, GT_WALL_H + 1.0))
		ol.append(Vector2(u - merlon - gap, GT_WALL_H + 1.0))
		ol.append(Vector2(u - merlon - gap, GT_WALL_H + 1.9))
		lefts.append(u - merlon * 0.5)
		u -= merlon + gap
	ol.append(Vector2(0.0, GT_WALL_H + 1.9))
	ol.append(Vector2(0.0, GT_WALL_H))
	ol.reverse()
	_prism(pk, kit, "stone", outer, ol, -0.6, 0.0, stone, Vector2(0, 1), true)
	for mu in lefts:
		_face(pk, kit, "matte", outer, float(mu) - 0.05, GT_WALL_H + 1.05, float(mu) + 0.05, GT_WALL_H + 1.7, 0.015, Color(0.04, 0.04, 0.05))
	var px: float = x0 + side * 0.4
	while absf(px - x0) < GT_WALL - 0.2:
		pk.beam(kit, "timber", Vector3(px, GT_WALL_H, -hz + 0.12), Vector3(px, GT_WALL_H + 1.0, -hz + 0.12), 0.1, 0.1, Color(0.32, 0.22, 0.14))
		px += side * 1.8
	pk.beam(kit, "timber", Vector3(x0, GT_WALL_H + 1.0, -hz + 0.12), Vector3(x1 - side * 0.2, GT_WALL_H + 1.0, -hz + 0.12), 0.08, 0.12, Color(0.32, 0.22, 0.14), Vector3.UP)


# ======================================================================================
#  The colliery estate (Zechensiedlung)
# ======================================================================================

const BRICKS := [Color(0.54, 0.24, 0.16), Color(0.44, 0.20, 0.15), Color(0.60, 0.30, 0.21)]
const TR_UNIT := 7.0      # a house's width
const TR_GARDEN := 5.0    # the front garden's depth: the houses' fronts stand at z = -5
const TR_DEPTH := 8.5     # the houses' depth
const TR_EAVE := 4.1      # the eaves (a storey and a knee wall: the attic is the half storey)
const TR_SHED := 3.2      # the stable annex's depth behind each house


## A row of colliery workers' houses (Zechensiedlung): `units` (2 or 4) houses 7m wide, x from 0 to 7 * units; the front
## gardens from z = 0 (a low hedge with a gate to each, a path, post-and-rail fences between them, shrubs) back to the
## houses' fronts at z = -5; the houses 8.5m deep, a storey and a half in red brick (variant % 3: 0 red brick and green
## doors, 1 dark brick and brown doors, 2 plastered with brick dressings) on a plinth down to FOOT, white windows under
## segmental brick arches, the doors in pairs under a gabled porch, a gabled dormer over each house, steep plain-tile
## roofs with the ridge along the row, chimneys on the party walls; behind each a brick stable annex for the goat
## (z to -16.7) with a lean-to roof and a stable door.
static func brick_terrace(pk: PropKit, kit: Dictionary, units: int, variant: int, rng: RandomNumberGenerator) -> void:
	var n: int = maxi(units, 1)
	var v: int = variant % 3
	var L: float = TR_UNIT * float(n)
	var z0: float = -TR_GARDEN
	var z1: float = z0 - TR_DEPTH
	var brick: Color = BRICKS[v]
	var wall_key := "kbrick"
	var wall_col: Color = brick
	if v == 2:
		wall_key = "plaster"
		wall_col = [Color(0.93, 0.90, 0.82), Color(0.90, 0.86, 0.74)][rng.randi() % 2]
	var dressing: Color = brick.darkened(0.12) if v != 2 else BRICKS[0].darkened(0.05)
	var door_col: Color = [Color(0.13, 0.33, 0.21), Color(0.36, 0.22, 0.12), Color(0.15, 0.30, 0.42)][v]
	var roof_col: Color = BIBERS[(v + rng.randi() % 2) % BIBERS.size()]
	var pl := 0.55
	# Plinth and walls.
	_wblock(pk, kit, "kbrick", Vector3(-0.03, FOOT, z1 - 0.03), Vector3(L + 0.03, pl, z0 + 0.03), BRICKS[1].darkened(0.15))
	var fw := _wf(Vector3(0, 0, z0), Vector3(0, 0, 1))
	var bw := _wf(Vector3(L, 0, z1), Vector3(0, 0, -1))
	_face(pk, kit, wall_key, fw, 0.0, pl, L, TR_EAVE, 0.0, wall_col)
	_face(pk, kit, wall_key, bw, 0.0, pl, L, TR_EAVE, 0.0, wall_col.darkened(0.03))
	var t: float = tan(deg_to_rad(50.0))
	var span: float = TR_DEPTH
	var apex: float = TR_EAVE + 0.08 - 0.09 + t * span * 0.5
	for side in [-1.0, 1.0]:
		var gwf: Transform3D = _wf(Vector3(L, 0, z0), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(0, 0, z1), Vector3(-1, 0, 0))
		_face(pk, kit, wall_key, gwf, 0.0, pl, span, TR_EAVE, 0.0, wall_col)
		_pface(pk, kit, wall_key, gwf, PackedVector2Array([Vector2(0, TR_EAVE), Vector2(span, TR_EAVE), Vector2(span * 0.5, apex)]), 0.0, wall_col)
		_terrace_window(pk, kit, gwf, span * 0.5, TR_EAVE + 0.5, 0.8, 1.1, dressing, v)
		_terrace_window(pk, kit, gwf, span * 0.3, 1.5, 1.0, 1.3, dressing, v)
	# A dentil course of brick under the eaves on both long walls.
	for wf in [fw, bw]:
		_rect(pk, kit, "kbrick", wf, -0.03, TR_EAVE - 0.32, L + 0.03, TR_EAVE - 0.14, 0.0, 0.05, dressing)
	# The houses: each mirrored to its neighbour so the doors pair up at the party walls.
	for i in range(n):
		var x0: float = TR_UNIT * float(i)
		var mirror: bool = i % 2 == 1
		var door_u: float = x0 + (TR_UNIT - 1.0 if not mirror else 1.0)
		var win_us: Array = [x0 + (1.7 if not mirror else TR_UNIT - 1.7), x0 + (3.9 if not mirror else TR_UNIT - 3.9)]
		for wu in win_us:
			_terrace_window(pk, kit, fw, wu, 1.45, 1.1, 1.4, dressing, v)
		_terrace_door(pk, kit, fw, door_u, pl, door_col, dressing, z0)
		if not mirror:
			_terrace_porch(pk, kit, x0 + TR_UNIT, z0, roof_col, i + 1 < n)
		elif i == 0:
			_terrace_porch(pk, kit, x0 + 1.0, z0, roof_col, false)
		# The back: a door to the yard and two windows.
		var bu: float = L - x0 - TR_UNIT * 0.5
		_terrace_window(pk, kit, bw, bu - 1.6, 1.45, 1.0, 1.3, dressing, v)
		_terrace_window(pk, kit, bw, bu + 1.4, 1.6, 0.8, 1.0, dressing, v)
		_door_leaf(pk, kit, bw, bu - 0.1, pl, 0.9, 2.05, door_col.darkened(0.15), 0.0)
		_steps(pk, kit, bw, bu - 0.1, pl, 1.4, 0.0, Color(0.6, 0.58, 0.55))
		# The front garden: a path, the hedge with a gate, a fence to the next garden, shrubs.
		_terrace_garden(pk, kit, x0, door_u, i, n, rng)
		# The stable annex behind.
		_stable(pk, kit, x0 + (0.4 if not mirror else TR_UNIT - 3.8), z1, wall_key, wall_col, door_col, roof_col)
	# The roof, its dormers and the chimneys.
	var rf := Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3(0, 0, z0))
	var r := _roof(pk, kit, rf, span, 0.0, L, TR_EAVE, 50.0, 0.4, 0.3, "biber", roof_col, Color(0.92, 0.92, 0.88) if v == 2 else Color(0.30, 0.22, 0.15))
	var ds := {"infill_key": "plaster", "infill": wall_col, "roof_key": "biber", "roof": roof_col, "trim": Color(0.92, 0.92, 0.88), "casing": false,
			"beam": BEAM_BLACK, "dormer_face": wall_key, "dormer_col": wall_col, "cheek_key": wall_key, "cheek_col": wall_col}
	for i2 in range(n):
		var mirror2: bool = i2 % 2 == 1
		var cx: float = TR_UNIT * float(i2) + (2.8 if not mirror2 else TR_UNIT - 2.8)
		_dormer(pk, kit, rf, r, cx, 0.15, 2.3, ds, rng)
	for k in range(0, n + 1, 2):
		var xx: float = clampf(TR_UNIT * float(k), 0.5, L - 0.5)
		_chimney(pk, kit, rf, span * 0.5 + 0.5, xx, TR_EAVE + 1.0, float(r["ridge"]) + 0.8, false)


## A window in a terrace house: white casement (two lights), a stone sill, a segmental arch of brick headers over it.
static func _terrace_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, h: float, dressing: Color, _v: int) -> void:
	_win(pk, kit, wf, u, v0, v0 + h, w, {"frame": WIN_WHITE, "rows": 2, "sill": "concrete", "sill_col": Color(0.72, 0.70, 0.66)})
	_arch_ring(pk, kit, "kbrick", wf, u, v0 + h + 0.02, w * 0.5 + 0.04, "segment", 0.24, 0.0, 0.035, dressing, NAN, 8, 0.2)


## A terrace house's front door: a panelled leaf with a small glazed light, a brick arch over it, two steps.
static func _terrace_door(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, pl: float, col: Color, dressing: Color, _z0: float) -> void:
	_rect(pk, kit, "painted", wf, u - 0.5, pl, u + 0.5, pl + 2.15, 0.0, 0.035, col)
	_face(pk, kit, "pane", wf, u - 0.3, pl + 1.35, u + 0.3, pl + 1.95, 0.045, GLASS)
	_rect(pk, kit, "painted", wf, u - 0.35, pl + 0.2, u + 0.35, pl + 1.15, 0.035, 0.05, col.lightened(0.1))
	_rect(pk, kit, "painted", wf, u - 0.6, pl, u - 0.5, pl + 2.25, 0.0, 0.05, WIN_WHITE)
	_rect(pk, kit, "painted", wf, u + 0.5, pl, u + 0.6, pl + 2.25, 0.0, 0.05, WIN_WHITE)
	_rect(pk, kit, "painted", wf, u - 0.5, pl + 2.15, u + 0.5, pl + 2.25, 0.0, 0.05, WIN_WHITE)
	pk.tube(kit, "gold", wf * Vector3(u + 0.35, pl + 1.0, 0.035), wf * Vector3(u + 0.35, pl + 1.0, 0.1), 0.03, 0.03, 6, BRASS)
	_arch_ring(pk, kit, "kbrick", wf, u, pl + 2.27, 0.64, "segment", 0.24, 0.0, 0.035, dressing, NAN, 8, 0.2)
	_steps(pk, kit, wf, u, pl, 1.4, 0.0, Color(0.62, 0.6, 0.56))


## A gabled porch canopy over the door(s) beside the party wall at x (both neighbours' doors when `pair`), on timber
## brackets.
static func _terrace_porch(pk: PropKit, kit: Dictionary, x: float, z0: float, roof_col: Color, pair: bool) -> void:
	var hw: float = 1.9 if pair else 0.9
	var cx: float = x if pair else x
	var y0 := 2.95
	var out := 1.1
	var rise := 0.65
	var l0 := Vector3(cx - hw, y0, z0)
	var l1 := Vector3(cx - hw, y0, z0 + out)
	var r0 := Vector3(cx + hw, y0, z0)
	var r1 := Vector3(cx + hw, y0, z0 + out)
	var t0 := Vector3(cx, y0 + rise, z0)
	var t1 := Vector3(cx, y0 + rise, z0 + out)
	var nl := Vector3(-rise, hw, 0).normalized()
	var nr := Vector3(rise, hw, 0).normalized()
	roof(pk, kit, "biber", l1, l0, t0, t1, roof_col, nl, false)
	roof(pk, kit, "biber", r0, r1, t1, t0, roof_col, nr, false)
	roof(pk, kit, "lapboards", l1 + Vector3(0, -0.06, 0), l0 + Vector3(0, -0.06, 0), t0 + Vector3(0, -0.06, 0), t1 + Vector3(0, -0.06, 0), Color(0.5, 0.36, 0.24), -nl, false)
	roof(pk, kit, "lapboards", r0 + Vector3(0, -0.06, 0), r1 + Vector3(0, -0.06, 0), t1 + Vector3(0, -0.06, 0), t0 + Vector3(0, -0.06, 0), Color(0.5, 0.36, 0.24), -nr, false)
	# Its gable: boards in front, a bargeboard.
	var gf := _wf(Vector3(cx - hw, 0, z0 + out - 0.03), Vector3(0, 0, 1))
	_pface(pk, kit, "lapboards", gf, PackedVector2Array([Vector2(0.15, y0 - 0.02), Vector2(hw * 2.0 - 0.15, y0 - 0.02), Vector2(hw, y0 + rise - 0.1)]), 0.0, WIN_WHITE)
	_prism(pk, kit, "timber", gf, PackedVector2Array([Vector2(0.0, y0 - 0.06), Vector2(hw, y0 + rise - 0.04), Vector2(hw, y0 + rise + 0.06), Vector2(0.0, y0 + 0.04)]), 0.0, 0.04,
			Color(0.3, 0.22, 0.15), Vector2(1, 0), true)
	_prism(pk, kit, "timber", gf, PackedVector2Array([Vector2(hw * 2.0, y0 - 0.06), Vector2(hw * 2.0, y0 + 0.04), Vector2(hw, y0 + rise + 0.06), Vector2(hw, y0 + rise - 0.04)]), 0.0, 0.04,
			Color(0.3, 0.22, 0.15), Vector2(1, 0), true)
	for bx in [cx - hw + 0.12, cx + hw - 0.12]:
		pk.beam(kit, "timber", Vector3(bx, y0 - 0.7, z0 + 0.03), Vector3(bx, y0 - 0.02, z0 + out - 0.15), 0.09, 0.09, Color(0.3, 0.22, 0.15))
		pk.beam(kit, "timber", Vector3(bx, y0 - 0.06, z0 + 0.02), Vector3(bx, y0 - 0.06, z0 + out - 0.05), 0.09, 0.1, Color(0.3, 0.22, 0.15))


## A front garden in front of house i (x from x0, its door at door_u): a path of concrete slabs from the street (z = 0)
## to the door, a clipped hedge along the street with a picket gate on the path, a post-and-rail fence to the next garden,
## shrubs and a rose bush.
static func _terrace_garden(pk: PropKit, kit: Dictionary, x0: float, door_u: float, i: int, n: int, rng: RandomNumberGenerator) -> void:
	var zf: float = -TR_GARDEN
	# The path.
	_wblock(pk, kit, "concrete", Vector3(door_u - 0.48, -0.2, zf + 1.3), Vector3(door_u + 0.48, 0.04, -0.02), Color(0.66, 0.64, 0.6))
	# The hedge, leaving the gate's gap.
	var hz0 := -0.62
	var hz1 := -0.06
	var gate0: float = door_u - 0.55
	var gate1: float = door_u + 0.55
	var hedge := Color(0.22, 0.38, 0.17)
	if gate0 - x0 > 0.2:
		_wblock(pk, kit, "hedge", Vector3(x0 + 0.05, -0.3, hz0), Vector3(gate0, 0.85, hz1), hedge)
	if x0 + TR_UNIT - gate1 > 0.2:
		_wblock(pk, kit, "hedge", Vector3(gate1, -0.3, hz0), Vector3(x0 + TR_UNIT - 0.05, 0.85, hz1), hedge)
	# The gate: two posts, pickets on two rails.
	var gc := Color(0.94, 0.94, 0.92)
	for gx in [gate0 + 0.04, gate1 - 0.04]:
		pk.beam(kit, "painted", Vector3(gx, -0.2, -0.34), Vector3(gx, 1.0, -0.34), 0.08, 0.08, gc)
	for ry in [0.25, 0.7]:
		pk.beam(kit, "painted", Vector3(gate0 + 0.1, ry, -0.3), Vector3(gate1 - 0.1, ry, -0.3), 0.05, 0.03, gc, Vector3.UP)
	var pkts: int = 6
	for k in range(pkts):
		var px: float = lerpf(gate0 + 0.16, gate1 - 0.16, float(k) / float(pkts - 1))
		_prism(pk, kit, "painted", _wf(Vector3(0, 0, -0.27), Vector3(0, 0, 1)), PackedVector2Array([Vector2(px - 0.035, 0.1), Vector2(px + 0.035, 0.1),
				Vector2(px + 0.035, 0.85), Vector2(px, 0.9), Vector2(px - 0.035, 0.85)]), 0.0, 0.02, gc, Vector2(0, 1), true)
	# A fence along the garden's side to the next one.
	if i < n - 1:
		var fx: float = x0 + TR_UNIT
		var fc := Color(0.42, 0.30, 0.19)
		var fz := -0.7
		while fz > zf + 0.3:
			pk.beam(kit, "timber", Vector3(fx, -0.2, fz), Vector3(fx, 0.95, fz), 0.08, 0.08, fc)
			fz -= 1.45
		for ry2 in [0.45, 0.85]:
			pk.beam(kit, "timber", Vector3(fx + 0.05, ry2, -0.7), Vector3(fx + 0.05, ry2, zf + 0.3), 0.04, 0.09, fc, Vector3(1, 0, 0))
	# Shrubs and a rose bush on the lawn either side of the path.
	for k2 in range(3):
		var sx: float = x0 + rng.randf_range(0.8, TR_UNIT - 0.8)
		if absf(sx - door_u) < 1.3:
			continue
		var sz: float = rng.randf_range(zf + 1.8, -1.3)
		var sc: Color = Color(0.20, 0.38, 0.16).lightened(rng.randf_range(-0.05, 0.1))
		var r: float = rng.randf_range(0.35, 0.6)
		_bush(pk, kit, Vector3(sx, 0, sz), r, sc, rng)
		if k2 == 0:
			for f in range(5):
				_blob(pk, kit, "leaf", Vector3(sx + rng.randf_range(-r, r) * 0.7, r * 1.25 + rng.randf() * 0.2, sz + rng.randf_range(-r, r) * 0.7),
						Vector3.ONE * 0.07, GERANIUM[rng.randi() % 2])


## A stable annex (Stall) behind a terrace house: 3.4m wide from x0, from the house's back wall at z1 out TR_SHED, walls
## to 2.4m at its back rising to 3.0 at the house, a plain-tile lean-to roof, a two-part stable door and a little window.
static func _stable(pk: PropKit, kit: Dictionary, x0: float, z1: float, key: String, col: Color, door_col: Color, roof_col: Color) -> void:
	var x1: float = x0 + 3.4
	var zb: float = z1 - TR_SHED
	var hb := 2.4
	var hf := 3.0
	_wblock(pk, kit, "kbrick", Vector3(x0 - 0.02, FOOT, zb - 0.02), Vector3(x1 + 0.02, 0.3, z1), BRICKS[1].darkened(0.15), true)
	var back := _wf(Vector3(x1, 0, zb), Vector3(0, 0, -1))
	_face(pk, kit, key, back, 0.0, 0.3, 3.4, hb, 0.0, col)
	for side in [-1.0, 1.0]:
		var swf: Transform3D = _wf(Vector3(x1, 0, z1), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(x0, 0, zb), Vector3(-1, 0, 0))
		var ol := PackedVector2Array()
		if side > 0.0:
			ol = PackedVector2Array([Vector2(0, 0.3), Vector2(TR_SHED, 0.3), Vector2(TR_SHED, hb), Vector2(0, hf)])
		else:
			ol = PackedVector2Array([Vector2(0, 0.3), Vector2(TR_SHED, 0.3), Vector2(TR_SHED, hf), Vector2(0, hb)])
		_pface(pk, kit, key, swf, ol, 0.0, col)
	# The stable door (upper and lower leaves) and a window.
	var du := 1.0
	_rect(pk, kit, "painted", back, du - 0.5, 0.3, du + 0.5, 1.25, 0.0, 0.04, door_col)
	_rect(pk, kit, "painted", back, du - 0.5, 1.29, du + 0.5, 2.15, 0.0, 0.04, door_col)
	for dy in [0.5, 1.0, 1.55, 1.95]:
		_face(pk, kit, "painted", back, du - 0.46, dy, du + 0.46, dy + 0.06, 0.05, door_col.lightened(0.15))
	_win(pk, kit, back, 2.55, 1.3, 1.9, 0.6, {"frame": WIN_WHITE, "rows": 2, "sill": "concrete", "sill_col": Color(0.7, 0.68, 0.64)})
	var t: float = (hf - hb) / TR_SHED
	var p0 := Vector3(x0 - 0.2, hb + 0.06 - t * 0.35, zb - 0.35)
	var p1 := Vector3(x1 + 0.2, hb + 0.06 - t * 0.35, zb - 0.35)
	var p2 := Vector3(x1 + 0.2, hf + 0.06, z1)
	var p3 := Vector3(x0 - 0.2, hf + 0.06, z1)
	var nrm := Vector3(0, TR_SHED, -(hf - hb)).normalized()
	roof(pk, kit, "biber", p0, p1, p2, p3, roof_col, nrm, false)
	roof(pk, kit, "lapboards", p0 + Vector3(0, -0.07, 0), p1 + Vector3(0, -0.07, 0), p2 + Vector3(0, -0.07, 0), p3 + Vector3(0, -0.07, 0), Color(0.45, 0.32, 0.2), -nrm, false)
	pk.beam(kit, "timber", p0 + Vector3(0, -0.12, -0.02), p1 + Vector3(0, -0.12, -0.02), 0.2, 0.04, Color(0.3, 0.22, 0.15), Vector3.UP)
	for e in [[p0, p3, -1.0], [p1, p2, 1.0]]:
		pk.beam(kit, "timber", (e[0] as Vector3) + Vector3(float(e[2]) * 0.02, -0.08, 0), (e[1] as Vector3) + Vector3(float(e[2]) * 0.02, -0.08, 0), 0.04, 0.18, Color(0.3, 0.22, 0.15))


# ======================================================================================
#  The corner kiosk (Trinkhalle) and the advertising column
# ======================================================================================

const ADS := [["Kronbräu Pils", Color(0.66, 0.08, 0.08), Color(0.98, 0.86, 0.3)], ["Glück Auf! Export", Color(0.08, 0.18, 0.36), Color(0.95, 0.95, 0.9)],
	["Kumpel-Brause", Color(0.98, 0.62, 0.08), Color(0.18, 0.08, 0.04)], ["Pottperle Wasser", Color(0.18, 0.52, 0.72), Color(0.98, 0.98, 0.98)],
	["Schachtbräu", Color(0.12, 0.30, 0.16), Color(0.95, 0.82, 0.35)], ["Revier-Kurier", Color(0.92, 0.92, 0.88), Color(0.70, 0.08, 0.08)]]


## The corner kiosk (Trinkhalle, a Büdchen): front on z = 0 facing +z, x from 0 to 4, 3m deep; plastered walls on a
## tiled plinth, a big sales window with a counter shelf and a hatch, a flat roof overhanging all round with a fascia
## carrying TRINKHALLE, a striped awning, enamel adverts (fictional brands) on the sides, a door at the back, crates of
## bottles beside it, a standing table and a bin in front (to z = 1.6).
static func trinkhalle(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var W := 4.0
	var D := 3.0
	var H := 2.85
	var wall := Color(0.86, 0.90, 0.82)
	var trim := Color(0.20, 0.42, 0.30)
	_wblock(pk, kit, "concrete", Vector3(-0.03, FOOT, -D - 0.03), Vector3(W + 0.03, 0.3, 0.03), Color(0.55, 0.53, 0.5))
	var walls: Array = [[_wf(Vector3(0, 0, 0), Vector3(0, 0, 1)), W], [_wf(Vector3(W, 0, 0), Vector3(1, 0, 0)), D],
			[_wf(Vector3(W, 0, -D), Vector3(0, 0, -1)), W], [_wf(Vector3(0, 0, -D), Vector3(-1, 0, 0)), D]]
	for wl in walls:
		_face(pk, kit, "plaster", wl[0], 0.0, 0.3, wl[1], H, 0.0, wall)
		# Tiles along the foot: a band of glazed tiles.
		_rect(pk, kit, "enamel", wl[0], 0.0, 0.3, wl[1], 0.75, 0.0, 0.02, Color(0.30, 0.48, 0.38))
	var front: Transform3D = walls[0][0]
	# The sales window: glass, an aluminium frame, mullions, the hatch, the counter.
	var wx0 := 0.35
	var wx1 := 3.65
	_face(pk, kit, "pane", front, wx0, 1.0, wx1, 2.4, 0.02, GLASS.lightened(0.04))
	_ring_rect(pk, kit, "metal", front, wx0 - 0.06, 0.94, wx1 + 0.06, 2.46, 0.06, 0.0, 0.05, Color(0.72, 0.73, 0.74))
	for mx in [1.45, 2.55]:
		_rect(pk, kit, "metal", front, mx - 0.03, 1.0, mx + 0.03, 2.4, 0.0, 0.045, Color(0.72, 0.73, 0.74))
	_rect(pk, kit, "metal", front, 1.48, 1.0, 2.52, 1.62, 0.045, 0.06, Color(0.72, 0.73, 0.74))
	_wblock(pk, kit, "metal", Vector3(wx0 - 0.1, 0.92, 0.0), Vector3(wx1 + 0.1, 0.98, 0.42), Color(0.78, 0.79, 0.8))
	for cx in [0.6, 3.4]:
		pk.beam(kit, "steel", Vector3(cx, 0.55, 0.02), Vector3(cx, 0.92, 0.38), 0.03, 0.03, CAST)
	# Goods behind the glass: shelves of bottles and sweets, as coloured rows.
	for row in range(3):
		var ry: float = 1.12 + 0.42 * float(row)
		for k in range(10):
			var gx: float = wx0 + 0.15 + float(k) * 0.33
			_face(pk, kit, "enamel", front, gx, ry, gx + 0.26, ry + 0.24, 0.028, [Color(0.75, 0.15, 0.12), Color(0.95, 0.75, 0.15), Color(0.15, 0.45, 0.25),
					Color(0.2, 0.35, 0.75), Color(0.85, 0.85, 0.82)][(k + row * 3) % 5])
	# The flat roof, its fascia and the name.
	_wblock(pk, kit, "concrete", Vector3(-0.35, H, -D - 0.35), Vector3(W + 0.35, H + 0.12, 0.35), Color(0.62, 0.6, 0.57), true, true)
	var fascia := _wf(Vector3(-0.35, 0, 0.35), Vector3(0, 0, 1))
	_rect(pk, kit, "enamel", fascia, 0.0, H + 0.12, W + 0.7, H + 0.62, 0.0, 0.05, trim)
	labels.append(["TRINKHALLE", Vector3(W * 0.5, H + 0.37, 0.43), Vector3(0, 0, 1), 0.27, Color(0.98, 0.96, 0.88), W + 0.3])
	for side in [-1.0, 1.0]:
		var sf: Transform3D = _wf(Vector3(W + 0.35, 0, 0.35), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(-0.35, 0, -D - 0.35), Vector3(-1, 0, 0))
		_rect(pk, kit, "enamel", sf, 0.0, H + 0.12, D + 0.7, H + 0.62, 0.0, 0.05, trim)
	_rect(pk, kit, "enamel", _wf(Vector3(W + 0.35, 0, -D - 0.35), Vector3(0, 0, -1)), 0.0, H + 0.12, W + 0.7, H + 0.62, 0.0, 0.05, trim)
	# The awning over the window.
	var ay := 2.62
	var aout := 0.95
	for k2 in range(8):
		var xa: float = lerpf(wx0 - 0.1, wx1 + 0.1, float(k2) / 8.0)
		var xb: float = lerpf(wx0 - 0.1, wx1 + 0.1, float(k2 + 1) / 8.0)
		var c: Color = [Color(0.95, 0.94, 0.9), trim][k2 % 2]
		var nrm := Vector3(0, aout, 0.42).normalized()
		pk.quad(kit, "canvas", [Vector3(xa, ay, 0.05), Vector3(xb, ay, 0.05), Vector3(xb, ay - 0.42, aout), Vector3(xa, ay - 0.42, aout)], nrm, c)
		pk.quad(kit, "canvas", [Vector3(xa, ay - 0.02, 0.05), Vector3(xa, ay - 0.44, aout), Vector3(xb, ay - 0.44, aout), Vector3(xb, ay - 0.02, 0.05)], -nrm, c.darkened(0.3))
		pk.quad(kit, "canvas", [Vector3(xa, ay - 0.42, aout), Vector3(xb, ay - 0.42, aout), Vector3(xb, ay - 0.6, aout), Vector3(xa, ay - 0.6, aout)], Vector3(0, 0, 1), c)
		pk.quad(kit, "canvas", [Vector3(xa, ay - 0.42, aout - 0.01), Vector3(xa, ay - 0.6, aout - 0.01), Vector3(xb, ay - 0.6, aout - 0.01), Vector3(xb, ay - 0.42, aout - 0.01)],
				Vector3(0, 0, -1), c.darkened(0.3))
	# Adverts: enamel boards on the sides and the front's corners.
	_ad_board(pk, kit, labels, walls[1][0], D * 0.5, 1.75, 2.2, 1.0, ADS[0])
	_ad_board(pk, kit, labels, walls[3][0], D * 0.5, 1.75, 2.2, 1.0, ADS[1])
	_ad_board(pk, kit, labels, walls[2][0], W * 0.3, 1.9, 1.5, 0.7, ADS[3])
	_ad_board(pk, kit, labels, front, 3.85, 1.95, 0.0, 0.0, ADS[2])
	# The back door.
	_door_leaf(pk, kit, walls[2][0], W * 0.72, 0.3, 0.9, 2.05, Color(0.20, 0.42, 0.30), 0.0)
	# Crates beside it, a standing table and a bin in front.
	pk.set_frame(pk.xf * Transform3D(Basis(), Vector3(W + 0.45, 0, -0.4)))
	beer_crates(pk, kit, 7)
	pk.set_frame(pk.xf * Transform3D(Basis(), -Vector3(W + 0.45, 0, -0.4)))
	_stehtisch(pk, kit, Vector3(W * 0.5 + 1.2, 0, 1.25))
	pk.lathe(kit, "metal", Vector3(-0.6, 0, 0.7), [Vector2(0.001, 0.0), Vector2(0.24, 0.0), Vector2(0.26, 0.85), Vector2(0.28, 0.9), Vector2(0.001, 0.92)], 12, Color(0.55, 0.58, 0.56))


## An enamel advertising board on a wall at (u, v), w x h (0: a small square on a bracket out from the wall).
static func _ad_board(pk: PropKit, kit: Dictionary, labels: Array, wf: Transform3D, u: float, v: float, w: float, h: float, ad: Array) -> void:
	if w <= 0.0:
		# A double-sided sign standing out from the wall's corner.
		var n: Vector3 = wf.basis.z
		var ac: Vector3 = wf.basis.x
		var c: Vector3 = wf * Vector3(u, v, 0.45)
		pk.beam(kit, "steel", wf * Vector3(u, v + 0.42, 0.0), wf * Vector3(u, v + 0.42, 0.8), 0.03, 0.03, CAST)
		_prism(pk, kit, "enamel", Transform3D(Basis(n, Vector3.UP, n.cross(Vector3.UP)), c), _rp(-0.35, -0.35, 0.35, 0.35), -0.015, 0.015, ad[1], Vector2(0, 1), true)
		labels.append([ad[0], c + ac * 0.018, ac, 0.07, ad[2], 0.62])
		labels.append([ad[0], c - ac * 0.018, -ac, 0.07, ad[2], 0.62])
		return
	_rect(pk, kit, "enamel", wf, u - w * 0.5, v - h * 0.5, u + w * 0.5, v + h * 0.5, 0.0, 0.03, ad[1])
	_ring_rect(pk, kit, "enamel", wf, u - w * 0.5 + 0.04, v - h * 0.5 + 0.04, u + w * 0.5 - 0.04, v + h * 0.5 - 0.04, 0.04, 0.03, 0.035, ad[2])
	labels.append([ad[0], wf * Vector3(u, v, 0.04), wf.basis.z, h * 0.28, ad[2], w - 0.25])


## A standing table (Stehtisch) at p: a round top on a pole with a cross foot.
static func _stehtisch(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	pk.lathe(kit, "timber", p + Vector3(0, 1.06, 0), [Vector2(0.001, 0.0), Vector2(0.38, 0.0), Vector2(0.4, 0.02), Vector2(0.4, 0.05), Vector2(0.001, 0.05)], 14,
			Color(0.55, 0.40, 0.26))
	pk.tube(kit, "steel", p + Vector3(0, 0.02, 0), p + Vector3(0, 1.06, 0), 0.035, 0.035, 8, Color(0.6, 0.62, 0.63), false)
	for a in [0.0, PI * 0.5]:
		var d := Vector3(cos(a), 0, sin(a)) * 0.32
		var lift: float = 0.03 if a == 0.0 else 0.05
		pk.beam(kit, "steel", p - d + Vector3(0, lift, 0), p + d + Vector3(0, lift, 0), 0.05, 0.04, Color(0.6, 0.62, 0.63), Vector3.UP)


## The advertising column (Litfaßsäule), standing on the origin: 1.3m across, a moulded foot, the drum pasted with
## posters (bands of colour, discs, stripes: no lettering), a cornice, a dome and a finial; 3.7m to its top.
static func litfass(pk: PropKit, kit: Dictionary) -> void:
	var green := Color(0.14, 0.28, 0.20)
	var r := 0.65
	var n := 16
	pk.lathe(kit, "paint", Vector3.ZERO, [Vector2(0.001, -0.3), Vector2(r + 0.12, -0.3), Vector2(r + 0.12, 0.12), Vector2(r + 0.06, 0.2), Vector2(r + 0.03, 0.32),
			Vector2(r, 0.36)], n, green, true)
	pk.lathe(kit, "paint", Vector3.ZERO, [Vector2(r, 0.36), Vector2(r, 2.86)], n, Color(0.82, 0.80, 0.74), true)
	pk.lathe(kit, "paint", Vector3.ZERO, [Vector2(r, 2.86), Vector2(r + 0.08, 2.9), Vector2(r + 0.12, 3.02), Vector2(r + 0.06, 3.08), Vector2(r * 0.95, 3.12),
			Vector2(r * 0.8, 3.36), Vector2(r * 0.45, 3.52), Vector2(0.001, 3.58)], n, green, false)
	pk.lathe(kit, "gold", Vector3(0, 3.56, 0), [Vector2(0.001, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.08), Vector2(0.11, 0.14), Vector2(0.001, 0.26)], 8, KR_GOLD)
	# Posters: each over two to four facets, from 0.45m to 2.75m (some split in two).
	var rng := RandomNumberGenerator.new()
	rng.seed = 3105
	var bgs: Array = [Color(0.92, 0.82, 0.18), Color(0.78, 0.12, 0.12), Color(0.12, 0.32, 0.62), Color(0.95, 0.95, 0.92), Color(0.16, 0.16, 0.18),
			Color(0.95, 0.52, 0.12), Color(0.2, 0.55, 0.32)]
	var f := 0
	var pi_ := 0
	var ap: float = r * cos(PI / float(n)) + 0.006
	while f < n:
		var span: int = mini(2 + rng.randi() % 3, n - f)
		var bg: Color = bgs[pi_ % bgs.size()]
		var fg: Color = bgs[(pi_ + 3) % bgs.size()]
		var split: bool = rng.randf() < 0.35
		for k in range(f, f + span):
			var a0: float = TAU * float(k) / float(n) + PI / float(n)
			var mid: float = a0 + PI / float(n)
			var out := Vector3(cos(mid), 0, sin(mid))
			var wf := _wf(out * ap - Vector3(sin(mid), 0, -cos(mid)) * (r * sin(PI / float(n))), out)
			var fw: float = 2.0 * r * sin(PI / float(n))
			if split:
				_face(pk, kit, "enamel", wf, 0.0, 0.45, fw, 1.55, 0.0, bg)
				_face(pk, kit, "enamel", wf, 0.0, 1.62, fw, 2.75, 0.0, fg)
			else:
				_face(pk, kit, "enamel", wf, 0.0, 0.45, fw, 2.75, 0.0, bg)
			# The poster's graphics on its middle facet: a disc, bands, a triangle.
			if k == f + span / 2:
				match pi_ % 3:
					0:
						_pface(pk, kit, "enamel", wf, _circle_pts(Vector2(fw * 0.5, 2.0), fw * 0.42, 10), 0.012, fg)
						_face(pk, kit, "enamel", wf, 0.06, 0.7, fw - 0.06, 0.82, 0.012, fg)
					1:
						for b in range(3):
							_face(pk, kit, "enamel", wf, 0.04, 0.8 + 0.25 * float(b), fw - 0.04, 0.9 + 0.25 * float(b), 0.012, fg)
					_:
						_pface(pk, kit, "enamel", wf, PackedVector2Array([Vector2(0.04, 1.75), Vector2(fw - 0.04, 1.75), Vector2(fw * 0.5, 2.55)]), 0.012, fg)
		f += span
		pi_ += 1


# ======================================================================================
#  Street furniture
# ======================================================================================

const GALV := Color(0.62, 0.64, 0.64)
const SIGN_YELLOW := Color(0.98, 0.78, 0.05)
const BUS_GREEN := Color(0.05, 0.50, 0.25)


## The place-name sign (Ortstafel): a yellow board with a black border, `text` over `sub`, on two galvanised posts;
## facing +z, centred on the origin (the posts' feet), its top 2.65m up.
static func ortsschild(pk: PropKit, kit: Dictionary, labels: Array, text: String, sub: String) -> void:
	for px in [-0.55, 0.55]:
		pk.tube(kit, "metal", Vector3(px, -0.4, -0.05), Vector3(px, 2.7, -0.05), 0.038, 0.038, 8, GALV, true)
	var wf := _wf(Vector3.ZERO, Vector3(0, 0, 1))
	var x0 := -0.65
	var x1 := 0.65
	var y0 := 1.8
	var y1 := 2.62
	_prism(pk, kit, "enamel", wf, _rp(x0, y0, x1, y1), -0.02, 0.0, SIGN_YELLOW, Vector2(0, 1), false)
	_face(pk, kit, "metal", _wf(Vector3(0, 0, -0.02), Vector3(0, 0, -1)), x0, y0, x1, y1, 0.0, Color(0.55, 0.57, 0.57))
	_ring_rect(pk, kit, "enamel", wf, x0 + 0.03, y0 + 0.03, x1 - 0.03, y1 - 0.03, 0.035, 0.0, 0.008, Color(0.05, 0.05, 0.05))
	for py in [y0 + 0.2, y1 - 0.2]:
		pk.beam(kit, "metal", Vector3(-0.62, py, -0.05), Vector3(0.62, py, -0.05), 0.05, 0.03, GALV, Vector3.UP)
	labels.append([text, Vector3(0, y0 + 0.5, 0.012), Vector3(0, 0, 1), 0.2, Color(0.04, 0.04, 0.04), 1.1])
	labels.append([sub, Vector3(0, y0 + 0.2, 0.012), Vector3(0, 0, 1), 0.075, Color(0.04, 0.04, 0.04), 1.0])


## The modern street light (Peitschenmast): a tapering galvanised pole on a foot with its door, curving over like a whip
## into an arm with a flat luminaire at its end, out toward +z; 8.7m tall, the lamp 2.3m out.
static func peitschen_lamp(pk: PropKit, kit: Dictionary) -> void:
	pk.lathe(kit, "metal", Vector3(0, -0.5, 0), [Vector2(0.001, 0.0), Vector2(0.17, 0.0), Vector2(0.17, 1.4), Vector2(0.13, 1.5), Vector2(0.001, 1.5)], 10, GALV.darkened(0.08))
	_wblock(pk, kit, "metal", Vector3(-0.06, 0.45, 0.14), Vector3(0.06, 0.8, 0.175), GALV.darkened(0.15))
	var pts: Array = [Vector3(0, 0.95, 0), Vector3(0, 6.6, 0)]
	var rc := 1.5
	for k in range(1, 7):
		var a: float = PI * 0.5 * float(k) / 6.0
		pts.append(Vector3(0, 6.6 + sin(a) * rc, rc - cos(a) * rc))
	pts.append(Vector3(0, 6.6 + rc - 0.12, rc + 0.6))
	for i in range(pts.size() - 1):
		var r0: float = lerpf(0.105, 0.055, float(i) / float(pts.size() - 1))
		var r1: float = lerpf(0.105, 0.055, float(i + 1) / float(pts.size() - 1))
		pk.tube(kit, "metal", pts[i], pts[i + 1], r0, r1, 8, GALV, i == pts.size() - 2)
	var head: Vector3 = pts[pts.size() - 1] + Vector3(0, -0.05, 0.25)
	pk.lathe(kit, "metal", head, [Vector2(0.001, -0.1), Vector2(0.3, -0.1), Vector2(0.34, -0.04), Vector2(0.3, 0.06), Vector2(0.14, 0.12), Vector2(0.001, 0.13)],
			12, GALV.lightened(0.05), false, Basis().scaled(Vector3(0.75, 1.0, 1.6)))
	pk.lathe(kit, "lamp", head + Vector3(0, -0.11, 0), [Vector2(0.001, 0.0), Vector2(0.26, 0.0), Vector2(0.001, 0.01)], 12, Color(0.95, 0.95, 0.9), false,
			Basis().scaled(Vector3(0.75, -1.0, 1.6)))


## An old-town lantern post: YardKit's cast-iron post and lantern, 3.6m, standing on the origin.
static func old_lantern_post(pk: PropKit, kit: Dictionary) -> void:
	lamp_post(pk, kit, Vector3.ZERO, 3.6)


## A bus stop: the H sign (a green H on a yellow disc, both faces) with the stop's name and a timetable case on a pole at
## the origin, and a shelter beside it (x from 1.0 to 4.8, its back at z = -1.6): steel frame, glass back and ends, a
## roof, a bench, a lit advert case at one end.
static func bus_stop(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	pk.tube(kit, "metal", Vector3(0, -0.4, 0), Vector3(0, 3.0, 0), 0.04, 0.04, 8, GALV, true)
	var disc := Transform3D(Basis(), Vector3(0, 2.68, 0.06))
	_prism(pk, kit, "enamel", disc, _circle_pts(Vector2.ZERO, 0.3, 20), -0.015, 0.015, SIGN_YELLOW, Vector2(0, 1), true)
	_circle_ring(pk, kit, "enamel", disc, Vector2.ZERO, 0.255, 0.29, 0.015, 0.022, BUS_GREEN, 20)
	var back_disc := Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)), disc.origin)
	_circle_ring(pk, kit, "enamel", back_disc, Vector2.ZERO, 0.255, 0.29, 0.015, 0.022, BUS_GREEN, 20)
	labels.append(["H", disc.origin + Vector3(0, 0, 0.024), Vector3(0, 0, 1), 0.3, BUS_GREEN, 0.4])
	labels.append(["H", disc.origin + Vector3(0, 0, -0.024), Vector3(0, 0, -1), 0.3, BUS_GREEN, 0.4])
	_prism(pk, kit, "enamel", Transform3D(Basis(), Vector3(0, 2.18, 0.06)), _rp(-0.42, -0.1, 0.42, 0.1), -0.012, 0.012, Color(0.96, 0.96, 0.93), Vector2(0, 1), true)
	labels.append(["Kronburg Markt", Vector3(0, 2.18, 0.075), Vector3(0, 0, 1), 0.07, BUS_GREEN, 0.78])
	labels.append(["Kronburg Markt", Vector3(0, 2.18, 0.045), Vector3(0, 0, -1), 0.07, BUS_GREEN, 0.78])
	_wblock(pk, kit, "metal", Vector3(-0.2, 1.25, 0.04), Vector3(0.2, 1.8, 0.12), Color(0.85, 0.85, 0.82))
	_face(pk, kit, "enamel", _wf(Vector3(0, 0, 0.12), Vector3(0, 0, 1)), -0.16, 1.3, 0.16, 1.72, 0.008, Color(0.98, 0.98, 0.96))
	for ly in [1.4, 1.48, 1.56, 1.64]:
		_face(pk, kit, "enamel", _wf(Vector3(0, 0, 0.12), Vector3(0, 0, 1)), -0.13, ly, 0.13, ly + 0.025, 0.014, Color(0.3, 0.3, 0.32))
	# The shelter.
	var x0 := 1.0
	var x1 := 4.8
	var zb := -1.6
	var hgt := 2.45
	var frame := Color(0.28, 0.30, 0.32)
	for px in [x0, (x0 + x1) * 0.5, x1]:
		pk.beam(kit, "metal", Vector3(px, -0.2, zb + 0.04), Vector3(px, hgt, zb + 0.04), 0.07, 0.07, frame)
	for px2 in [x0, x1]:
		pk.beam(kit, "metal", Vector3(px2, -0.2, -0.04), Vector3(px2, hgt - 0.05, -0.04), 0.07, 0.07, frame)
	_wblock(pk, kit, "metal", Vector3(x0 - 0.15, hgt, zb - 0.1), Vector3(x1 + 0.15, hgt + 0.12, 0.25), frame, true, true)
	var gl := Color(0.75, 0.85, 0.88, 0.25)
	pk.quad(kit, "glass", [Vector3(x0 + 0.04, 0.12, zb + 0.04), Vector3(x1 - 0.04, 0.12, zb + 0.04), Vector3(x1 - 0.04, hgt - 0.05, zb + 0.04), Vector3(x0 + 0.04, hgt - 0.05, zb + 0.04)],
			Vector3(0, 0, 1), gl)
	pk.quad(kit, "glass", [Vector3(x0 + 0.04, 0.12, zb + 0.04), Vector3(x0 + 0.04, hgt - 0.05, zb + 0.04), Vector3(x1 - 0.04, hgt - 0.05, zb + 0.04), Vector3(x1 - 0.04, 0.12, zb + 0.04)],
			Vector3(0, 0, -1), gl)
	# The advert case at the far end, the glass end at the near one.
	_wblock(pk, kit, "metal", Vector3(x1 - 0.06, 0.15, zb + 0.08), Vector3(x1 + 0.06, 2.2, -0.08), frame)
	for sn in [-1.0, 1.0]:
		_face(pk, kit, "enamel", _wf(Vector3(x1 + 0.075 * sn, 0, -0.12 if sn > 0.0 else zb + 0.12), Vector3(sn, 0, 0)), 0.0, 0.3, 1.32, 2.05, 0.0,
				Color(0.16, 0.32, 0.58) if sn > 0.0 else Color(0.85, 0.2, 0.15))
	pk.quad(kit, "glass", [Vector3(x0, 0.12, zb + 0.08), Vector3(x0, 0.12, -0.1), Vector3(x0, hgt - 0.05, -0.1), Vector3(x0, hgt - 0.05, zb + 0.08)], Vector3(-1, 0, 0), gl)
	pk.quad(kit, "glass", [Vector3(x0, 0.12, zb + 0.08), Vector3(x0, hgt - 0.05, zb + 0.08), Vector3(x0, hgt - 0.05, -0.1), Vector3(x0, 0.12, -0.1)], Vector3(1, 0, 0), gl)
	bench(pk, kit, Vector3((x0 + x1) * 0.5 - 0.3, 0.0, zb + 0.75), Vector3(0, 0, 1), 2.2)
	labels.append(["Kronburg Markt", Vector3((x0 + x1) * 0.5, hgt + 0.06, 0.26), Vector3(0, 0, 1), 0.08, Color(0.95, 0.95, 0.92), 2.0])


## A cast-iron bollard (Poller) standing on the origin: a moulded foot, a tapering body with two rings, a domed cap and a
## ball: 0.95m.
static func bollard(pk: PropKit, kit: Dictionary) -> void:
	var c := Color(0.12, 0.16, 0.14)
	pk.lathe(kit, "steel", Vector3(0, -0.3, 0), [Vector2(0.001, 0.0), Vector2(0.15, 0.0), Vector2(0.15, 0.36), Vector2(0.12, 0.42), Vector2(0.11, 0.5),
			Vector2(0.095, 0.95), Vector2(0.115, 0.98), Vector2(0.115, 1.03), Vector2(0.09, 1.06), Vector2(0.09, 1.1), Vector2(0.06, 1.18), Vector2(0.075, 1.2),
			Vector2(0.06, 1.25), Vector2(0.001, 1.26)], 12, c)


## A street bench: YardKit's slatted bench on cast-iron ends, 1.9m, its seat's front edge on the origin facing +z.
static func street_bench(pk: PropKit, kit: Dictionary) -> void:
	bench(pk, kit, Vector3.ZERO, Vector3(0, 0, 1), 1.9)


## A bike rack: three galvanised hoops (Anlehnbügel) 1m apart along x, from the origin.
static func bike_rack(pk: PropKit, kit: Dictionary) -> void:
	for i in range(3):
		var x: float = float(i) * 1.0
		var pts: Array = [Vector3(x, -0.2, -0.35), Vector3(x, 0.62, -0.35)]
		for k in range(1, 6):
			var a: float = PI * float(k) / 6.0
			pts.append(Vector3(x, 0.62 + sin(a) * 0.2, -cos(a) * 0.35))
		pts.append(Vector3(x, 0.62, 0.35))
		pts.append(Vector3(x, -0.2, 0.35))
		_tube_path(pk, kit, "metal", pts, 0.025, 6, GALV)
		pk.beam(kit, "metal", Vector3(x, 0.32, -0.33), Vector3(x, 0.32, 0.33), 0.04, 0.02, GALV, Vector3.UP)


## Three glass recycling bins (green, brown and white glass) in a row along x from the origin, 1.5m apart: rounded steel
## bodies, two rubber-flapped holes each, a lifting knob, the colour band.
static func glass_containers(pk: PropKit, kit: Dictionary) -> void:
	var cols: Array = [Color(0.18, 0.42, 0.22), Color(0.45, 0.27, 0.13), Color(0.88, 0.88, 0.85)]
	for i in range(3):
		var cx: float = float(i) * 1.5
		var body := PackedVector2Array([Vector2(-0.6, 0.0), Vector2(0.6, 0.0), Vector2(0.62, 1.35), Vector2(0.5, 1.55), Vector2(-0.5, 1.55), Vector2(-0.62, 1.35)])
		var bf := Transform3D(Basis(), Vector3(cx, 0, 0))
		_prism_bevel(pk, kit, "plastic", bf, body, -0.6, 0.6, cols[i])
		var fwf := _wf(Vector3(cx, 0, 0.6), Vector3(0, 0, 1))
		for hx in [-0.25, 0.25]:
			_pface(pk, kit, "matte", fwf, _circle_pts(Vector2(hx, 1.15), 0.12, 10), 0.012, Color(0.05, 0.05, 0.05))
			_circle_ring(pk, kit, "matte", fwf, Vector2(hx, 1.15), 0.12, 0.17, 0.0, 0.025, Color(0.1, 0.1, 0.1), 10)
		_face(pk, kit, "enamel", fwf, -0.42, 1.36, 0.42, 1.45, 0.012, Color(0.95, 0.95, 0.92) if i < 2 else Color(0.3, 0.3, 0.3))
		pk.lathe(kit, "metal", Vector3(cx, 1.55, 0), [Vector2(0.001, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.2), Vector2(0.14, 0.25), Vector2(0.14, 0.3),
				Vector2(0.001, 0.32)], 8, GALV)


## An extruded outline (x-y, across z from z0 to z1) with PropKit's bevelled edges, through the kit's frame times `bf`.
static func _prism_bevel(pk: PropKit, kit: Dictionary, key: String, bf: Transform3D, ol: PackedVector2Array, z0: float, z1: float, col: Color) -> void:
	var saved: Transform3D = pk.xf
	pk.set_frame(saved * bf)
	pk.extrude(kit, key, ol, z0, z1, 0.05, col)
	pk.set_frame(saved)


## `n` beer crates stacked four high from the origin along +x: plastic crates (brown, green, yellow in turn) with hand
## holds, the bottles' necks in rows and their caps.
static func beer_crates(pk: PropKit, kit: Dictionary, n: int) -> void:
	var cols: Array = [Color(0.36, 0.20, 0.10), Color(0.12, 0.36, 0.18), Color(0.85, 0.62, 0.10)]
	var cw := 0.4
	var cd := 0.3
	var ch := 0.31
	for i in range(n):
		var col: int = i / 4
		var lvl: int = i % 4
		var x: float = float(col) * (cw + 0.04)
		var y: float = float(lvl) * ch
		var c: Color = cols[(col + lvl) % cols.size()]
		var lo := Vector3(x, y, -cd * 0.5)
		var hi := Vector3(x + cw, y + ch - 0.01, cd * 0.5)
		pk.block(kit, "plastic", lo, hi, c)
		for sx in [-1.0, 1.0]:
			var ex: float = x if sx < 0.0 else x + cw
			pk.quad(kit, "matte", [Vector3(ex + sx * 0.012, y + ch - 0.1, -0.08), Vector3(ex + sx * 0.012, y + ch - 0.1, 0.08), Vector3(ex + sx * 0.012, y + ch - 0.04, 0.08),
					Vector3(ex + sx * 0.012, y + ch - 0.04, -0.08)], Vector3(sx, 0, 0), Color(0.05, 0.05, 0.05))
		if lvl == 3 or i == n - 1:
			# The top crate shows its bottles: four rows of necks with caps.
			for row in range(4):
				var bz: float = -cd * 0.5 + 0.0375 + 0.075 * float(row)
				pk.block(kit, "plastic", Vector3(x + 0.02, y + ch - 0.01, bz - 0.015), Vector3(x + cw - 0.02, y + ch + 0.07, bz + 0.015), Color(0.30, 0.16, 0.06))
				pk.block(kit, "metal", Vector3(x + 0.02, y + ch + 0.07, bz - 0.017), Vector3(x + cw - 0.02, y + ch + 0.085, bz + 0.017), KR_GOLD)


# ======================================================================================
#  Burg Kronburg (the castle ruin)
# ======================================================================================

const CA_STONE := Color(0.60, 0.58, 0.52)
const CA_FOOT := -6.0
## The curtain wall's corners in plan ([bearing in degrees, from +x toward +z], radius): the gate is in the wall facing +z
## (between the first two), the palas stands inside the wall to the -z.
const CA_CORNERS := [[0.0, 24.0], [52.0, 27.0], [100.0, 22.0], [150.0, 26.0], [205.0, 25.0], [258.0, 23.0], [310.0, 26.0]]


## Burg Kronburg, the castle ruin on the hill, centred on the origin (about 54 x 52m): the round keep (Bergfried) 10m
## across, its broken top stepping between 17 and 25m, its raised doorway and slits; a curtain wall of rubble stone 2.2m
## thick (6-9m, stepped and broken, two breaches with rubble heaped in them), a gate arch on the +z side, stumps of
## round towers at its corners; the palas' long wall standing 13m inside the wall to the -z with two rows of empty
## arched windows, stubs of its side walls; rubble heaps and fallen blocks. The gate is in the wall between bearings 52
## and 100 degrees (its arch faces about +z, 22m out); the breaches face -x and -z+x. Footings to CA_FOOT (-6).
static func castle_ruin(pk: PropKit, kit: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var stone := CA_STONE
	# The keep.
	_ruin_tower(pk, kit, Vector3.ZERO, 5.0, 2.4, 23.0, rng, stone, 22, true, [[0.1, 0.32, 7.0]])
	var kdir := Vector3(0, 0, 1)
	var kwf := _wf(kdir * 5.02, kdir)
	_pface(pk, kit, "matte", kwf, _opening(0.0, 7.4, 0.65, 9.0, "round", 8), 0.0, Color(0.05, 0.05, 0.05))
	_arch_ring(pk, kit, "stone", kwf, 0.0, 9.0, 0.65, "round", 0.35, 0.0, 0.1, stone.lightened(0.08), 7.4, 8)
	for sl in [[0.9, 13.5], [2.2, 4.0], [-1.0, 18.0]]:
		var a: float = float(sl[0])
		var d := Vector3(cos(a), 0, sin(a))
		_slit(pk, kit, _wf(d * 5.02, d), 0.0, float(sl[1]), 1.4, stone.lightened(0.06))
	# The curtain wall and its corner towers.
	var pts: Array = []
	for c in CA_CORNERS:
		var a2: float = deg_to_rad(float(c[0]))
		pts.append(Vector3(cos(a2), 0, sin(a2)) * float(c[1]))
	for i in range(pts.size()):
		var a3: Vector3 = pts[i]
		var b3: Vector3 = pts[(i + 1) % pts.size()]
		_ruin_wall(pk, kit, a3, b3, 2.2, 7.5, rng, stone, i == 3 or i == 5, i == 1)
	for i2 in range(pts.size()):
		var tr: float = 2.9 if i2 % 2 == 0 else 2.4
		_ruin_tower(pk, kit, pts[i2], tr, tr, rng.randf_range(9.5, 13.0), rng, stone, 14, false, [])
	# The palas: its long wall facing the courtyard (+z), two rows of arched windows, its side walls' stubs.
	var pz := -13.5
	var pw := _wf(Vector3(-9.0, 0, pz), Vector3(0, 0, 1))
	_rect(pk, kit, "stone", pw, 0.0, CA_FOOT, 18.0, 3.4, -1.6, 0.0, stone, true)
	var ops1: Array = []
	var ops2: Array = []
	for wx in [2.7, 6.9, 11.1, 15.3]:
		ops1.append([wx, 0.7, 5.3])
		ops2.append([wx, 0.75, 9.9])
	_ruin_slab(pk, kit, pw, 18.0, 3.4, [[0.0, 18.0, 8.0]], ops1, 1.6, stone)
	var tops: Array = []
	var u := 0.0
	while u < 18.0 - 0.01:
		var seg: float = minf(rng.randf_range(1.2, 2.6), 18.0 - u)
		# Broken lower past the last window; over the windows it stays clear of their arches.
		tops.append([u, u + seg, rng.randf_range(11.2, 14.0) - (3.5 if u > 16.2 else 0.0)])
		u += seg
	_ruin_slab(pk, kit, pw, 18.0, 8.0, tops, ops2, 1.6, stone)
	for side in [-1.0, 1.0]:
		# The stubs run back from behind the long wall: u from the palas outward (+x side) or toward it (-x side).
		var swf := _wf(Vector3(-9.0, 0, pz - 7.0), Vector3(-1, 0, 0)) if side < 0.0 else _wf(Vector3(9.0, 0, pz - 1.6), Vector3(1, 0, 0))
		var st: Array = [[0.0, 2.2, rng.randf_range(8.0, 10.0)], [2.2, 4.0, rng.randf_range(5.5, 7.5)], [4.0, 5.4, rng.randf_range(2.5, 4.5)]]
		if side < 0.0:
			st = [[0.0, 1.4, rng.randf_range(2.5, 4.5)], [1.4, 3.2, rng.randf_range(5.5, 7.5)], [3.2, 5.4, rng.randf_range(8.0, 10.0)]]
		_ruin_slab(pk, kit, swf, 5.4, CA_FOOT, st, [], 1.4, stone)
	# Rubble: heaps in the breaches and round the keep's foot, fallen blocks.
	for hp in [[pts[3].lerp(pts[4], 0.5), 3.4], [pts[5].lerp(pts[6], 0.5), 3.0], [Vector3(4.5, 0, 4.0), 2.2], [Vector3(6.0, 0, -9.5), 2.6]]:
		_rubble(pk, kit, hp[0], float(hp[1]), rng, stone)


## A ruined round tower at c: walls `thick` thick (solid, with a flat broken top, when thick >= r) from CA_FOOT up to about
## h, its top in steps of different heights from segment to segment; `breaches` [from, to (fractions round it), drop]
## bring the top down there.
static func _ruin_tower(pk: PropKit, kit: Dictionary, c: Vector3, r: float, thick: float, h: float, rng: RandomNumberGenerator, col: Color, segs: int,
		hollow: bool, breaches: Array) -> void:
	var hs: Array = []
	for k in range(segs):
		var hh: float = h + rng.randf_range(-1.6, 1.1)
		var f: float = (float(k) + 0.5) / float(segs)
		for b in breaches:
			if f > float(b[0]) and f < float(b[1]):
				hh -= float(b[2]) * sin((f - float(b[0])) / (float(b[1]) - float(b[0])) * PI) + rng.randf() * 1.2
		hs.append(hh)
	var ri: float = r - thick
	for k in range(segs):
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var e0 := Vector3(cos(a0), 0, sin(a0))
		var e1 := Vector3(cos(a1), 0, sin(a1))
		var hk: float = hs[k]
		_cyl_wall(pk, kit, "stone", c, r, CA_FOOT, hk, col, 1, a0, a1)
		if hollow and ri > 0.3:
			_cyl_wall(pk, kit, "stone", c, ri, CA_FOOT, hk - 0.15, col.darkened(0.15), 1, a0, a1, true)
			pk.quad(kit, "stone", [c + e0 * ri + Vector3(0, hk - 0.15, 0), c + e1 * ri + Vector3(0, hk - 0.15, 0), c + e1 * r + Vector3(0, hk, 0), c + e0 * r + Vector3(0, hk, 0)],
					Vector3.UP, col.lightened(0.04), [Vector2(a0 * ri, ri) * uvk, Vector2(a1 * ri, ri) * uvk, Vector2(a1 * r, r) * uvk, Vector2(a0 * r, r) * uvk])
		else:
			pk.tri(kit, "stone", c + Vector3(0, hk, 0), c + e0 * r + Vector3(0, hk, 0), c + e1 * r + Vector3(0, hk, 0), Vector3.UP, Vector3.UP, Vector3.UP,
					col.lightened(0.04), Vector3.UP, Vector2.ZERO, Vector2(a0 * r, r) * uvk, Vector2(a1 * r, r) * uvk)
		# The step up or down to the next segment's top: a face across the wall at their boundary.
		var hn: float = hs[(k + 1) % segs]
		if absf(hn - hk) > 0.02:
			var lo: float = minf(hn, hk)
			var hi: float = maxf(hn, hk)
			var inner_r: float = ri if hollow and ri > 0.3 else 0.0
			var tang := Vector3(-sin(a1), 0, cos(a1))
			var facing: Vector3 = tang if hn < hk else -tang
			pk.quad(kit, "stone", [c + e1 * inner_r + Vector3(0, lo, 0), c + e1 * r + Vector3(0, lo, 0), c + e1 * r + Vector3(0, hi, 0), c + e1 * inner_r + Vector3(0, hi, 0)],
					facing, col.darkened(0.05), [Vector2(inner_r, lo) * uvk, Vector2(r, lo) * uvk, Vector2(r, hi) * uvk, Vector2(inner_r, hi) * uvk])


## A stretch of ruined curtain wall from a to b (plan points), `thick` thick on the inside of the line, its top in steps
## about `base` high; a breach brings its middle down to rubble height, a gate puts a round arch through it.
static func _ruin_wall(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, thick: float, base: float, rng: RandomNumberGenerator, col: Color,
		breach: bool, gate: bool) -> void:
	var mid: Vector3 = (a + b) * 0.5
	var along: Vector3 = (b - a).normalized()
	var n := Vector3(along.z, 0, -along.x)
	if n.dot(mid) < 0.0:
		n = -n
	var wf := _wf(a, n)
	var length: float = a.distance_to(b)
	if wf.basis.x.dot(along) < 0.0:
		wf = _wf(b, n)
	var tops: Array = []
	var u := 0.0
	while u < length - 0.01:
		var seg: float = minf(rng.randf_range(1.2, 2.8), length - u)
		var h: float = base + rng.randf_range(-1.8, 1.5)
		var f: float = (u + seg * 0.5) / length
		if breach and f > 0.3 and f < 0.7:
			h = rng.randf_range(0.8, 2.6)
		elif breach and (f > 0.22 and f < 0.78):
			h -= 2.5
		if gate:
			h = maxf(h, 6.8)
		tops.append([u, u + seg, h])
		u += seg
	if gate:
		_rect(pk, kit, "stone", wf, 0.0, CA_FOOT, length, 0.0, -thick, 0.0, col, true)
		_ruin_slab(pk, kit, wf, length, 0.0, tops, [[length * 0.5, 2.1, 3.2]], thick, col)
		_arch_ring(pk, kit, "stone", wf, length * 0.5, 3.2, 2.1, "round", 0.55, 0.0, 0.12, col.lightened(0.1), 0.0, 10)
	else:
		_ruin_slab(pk, kit, wf, length, CA_FOOT, tops, [], thick, col)


## A slab of ruined wall in its frame: from y0 up to stepped tops ([u0, u1, height] in order along u), `thick` thick
## behind the face (both faces drawn), arched openings ([u, half, springing], rising from y0) cut out of it.
static func _ruin_slab(pk: PropKit, kit: Dictionary, wf: Transform3D, length: float, y0: float, tops: Array, ops: Array, thick: float, col: Color) -> void:
	var ol := PackedVector2Array([Vector2(0.0, y0)])
	for o in ops:
		var cu: float = o[0]
		var half: float = o[1]
		ol.append(Vector2(cu - half, y0))
		ol.append_array(_arch(cu, float(o[2]), half, "round", 8))
		ol.append(Vector2(cu + half, y0))
	ol.append(Vector2(length, y0))
	for k in range(tops.size() - 1, -1, -1):
		var t: Array = tops[k]
		ol.append(Vector2(float(t[1]), float(t[2])))
		ol.append(Vector2(float(t[0]), float(t[2])))
	_prism(pk, kit, "stone", wf, ol, -thick, 0.0, col, Vector2(0, 1), true)


## A heap of rubble at c, r across: a lumpy faceted mound and blocks lying about it.
static func _rubble(pk: PropKit, kit: Dictionary, c: Vector3, r: float, rng: RandomNumberGenerator, col: Color) -> void:
	var prof: Array = [Vector2(0.001, -0.5), Vector2(r * 1.05, -0.5), Vector2(r * (0.95 + rng.randf() * 0.1), 0.1), Vector2(r * 0.7, r * 0.3),
			Vector2(r * 0.4, r * (0.5 + rng.randf() * 0.15)), Vector2(0.001, r * 0.55)]
	pk.lathe(kit, "matte", c, prof, 9, Color(0.36, 0.34, 0.30), true, Basis(Vector3.UP, rng.randf() * TAU))
	for k in range(9):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(0.2, 1.1) * r
		var p: Vector3 = c + Vector3(cos(a) * d, 0, sin(a) * d)
		var hgt: float = maxf(0.0, r * 0.55 * (1.0 - d / (r * 1.05)))
		var s := Vector3(rng.randf_range(0.4, 0.9), rng.randf_range(0.3, 0.5), rng.randf_range(0.4, 0.8))
		var bs := Basis(Vector3(rng.randf() - 0.5, 1.0, rng.randf() - 0.5).normalized(), rng.randf() * TAU) * Basis(Vector3.UP, rng.randf() * TAU)
		pk.box(kit, "stone", Transform3D(bs, p + Vector3(0, hgt + s.y * 0.3, 0)), s, col.lightened(rng.randf_range(-0.05, 0.08)), uvk)


# ======================================================================================
#  Extras: an allotment, a beer garden, a maypole
# ======================================================================================

## An allotment garden (Schrebergarten) w x d: its gate in the front (z = 0) on a green picket fence, hedges round the
## other sides, a garden shed (Laube) with a porch at the back left, raised vegetable beds, a rain barrel, garden gnomes
## in red hats, stepping stones and a flagpole flying a pennant in the town's colours.
static func allotment(pk: PropKit, kit: Dictionary, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var fence := Color(0.20, 0.42, 0.26)
	var gx: float = w * 0.5
	# The front fence: posts, two rails, pickets, a gate.
	var x := 0.1
	while x < w - 0.05:
		if absf(x - gx) > 0.6:
			_prism(pk, kit, "painted", _wf(Vector3(0, 0, -0.08), Vector3(0, 0, 1)), PackedVector2Array([Vector2(x - 0.04, -0.1), Vector2(x + 0.04, -0.1),
					Vector2(x + 0.04, 0.95), Vector2(x, 1.0), Vector2(x - 0.04, 0.95)]), 0.0, 0.02, fence, Vector2(0, 1), true)
		x += 0.16
	for ry in [0.3, 0.75]:
		pk.beam(kit, "painted", Vector3(0.0, ry, -0.12), Vector3(gx - 0.6, ry, -0.12), 0.06, 0.03, fence, Vector3.UP)
		pk.beam(kit, "painted", Vector3(gx + 0.6, ry, -0.12), Vector3(w, ry, -0.12), 0.06, 0.03, fence, Vector3.UP)
	for px in [gx - 0.6, gx + 0.6]:
		pk.beam(kit, "painted", Vector3(px, -0.2, -0.12), Vector3(px, 1.15, -0.12), 0.1, 0.1, fence)
	_prism(pk, kit, "painted", _wf(Vector3(0, 0, -0.2), Vector3(0, 0, 1)), PackedVector2Array([Vector2(gx - 0.52, 0.1), Vector2(gx + 0.52, 0.1),
			Vector2(gx + 0.52, 0.95), Vector2(gx - 0.52, 0.95)]), 0.0, 0.03, fence.lightened(0.1), Vector2(0, 1), true)
	# Hedges round the sides and the back.
	var hc := Color(0.20, 0.36, 0.15)
	_wblock(pk, kit, "hedge", Vector3(0.0, -0.2, -d), Vector3(0.6, 1.4, -0.3), hc)
	_wblock(pk, kit, "hedge", Vector3(w - 0.6, -0.2, -d), Vector3(w, 1.4, -0.3), hc)
	_wblock(pk, kit, "hedge", Vector3(0.6, -0.2, -d), Vector3(w - 0.6, 1.4, -d + 0.6), hc)
	# The shed (Laube) at the back left, its porch toward the garden.
	var sx0 := 1.0
	var sx1 := 4.4
	var sz1: float = -d + 0.9
	var sz0: float = sz1 + 2.6
	var walls := Color(0.36, 0.48, 0.32) if rng.randf() < 0.5 else Color(0.55, 0.38, 0.22)
	_wblock(pk, kit, "concrete", Vector3(sx0 - 0.1, -0.4, sz1 - 0.1), Vector3(sx1 + 0.1, 0.15, sz0 + 1.4), Color(0.62, 0.6, 0.56))
	var fw := _wf(Vector3(sx0, 0, sz0), Vector3(0, 0, 1))
	_face(pk, kit, "lapboards", fw, 0.0, 0.15, sx1 - sx0, 2.3, 0.0, walls)
	_face(pk, kit, "lapboards", _wf(Vector3(sx1, 0, sz1), Vector3(0, 0, -1)), 0.0, 0.15, sx1 - sx0, 2.3, 0.0, walls)
	var rise := 1.0
	for side in [-1.0, 1.0]:
		var swf: Transform3D = _wf(Vector3(sx1, 0, sz0), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(sx0, 0, sz1), Vector3(-1, 0, 0))
		_pface(pk, kit, "lapboards", swf, PackedVector2Array([Vector2(0, 0.15), Vector2(sz0 - sz1, 0.15), Vector2(sz0 - sz1, 2.3), Vector2((sz0 - sz1) * 0.5, 2.3 + rise),
				Vector2(0, 2.3)]), 0.0, walls)
	_door_leaf(pk, kit, fw, 1.0, 0.15, 0.85, 1.95, walls.darkened(0.3), 0.0)
	_win(pk, kit, fw, 2.3, 1.0, 1.9, 0.9, {"frame": WIN_WHITE, "rows": 2, "shutter": Color(0.85, 0.75, 0.2), "box": true, "bloom": GERANIUM[0]})
	# Its roof (felt), the ridge across x, a porch roof carried out on two posts.
	var rz: float = (sz0 + sz1) * 0.5
	var felt := Color(0.22, 0.23, 0.25)
	var ro := 0.3
	var t: float = rise / ((sz0 - sz1) * 0.5)
	var e0 := Vector3(sx0 - ro, 2.3 - t * 1.4, sz0 + 1.4)
	var e1 := Vector3(sx1 + ro, 2.3 - t * 1.4, sz0 + 1.4)
	var r0 := Vector3(sx0 - ro, 2.3 + rise + 0.05, rz)
	var r1 := Vector3(sx1 + ro, 2.3 + rise + 0.05, rz)
	roof(pk, kit, "matte", e0, e1, r1, r0, felt, Vector3(0, 1, t).normalized(), true)
	roof(pk, kit, "matte", Vector3(sx1 + ro, 2.3 - t * ro + 0.05, sz1 - ro), Vector3(sx0 - ro, 2.3 - t * ro + 0.05, sz1 - ro), r0, r1, felt, Vector3(0, 1, -t).normalized(), true)
	for px2 in [sx0 + 0.05, sx1 - 0.05]:
		pk.beam(kit, "timber", Vector3(px2, 0.15, sz0 + 1.3), Vector3(px2, 2.3 - t * 1.3, sz0 + 1.3), 0.1, 0.1, Color(0.4, 0.28, 0.17))
	# Raised beds with rows of vegetables, a bed of cabbages.
	for b in range(3):
		var bx0: float = w * 0.45 + float(b) * 1.6
		if bx0 + 1.2 > w - 0.8:
			break
		var bz0 := -1.4
		var bz1: float = maxf(-d + 2.2, -6.5)
		_wblock(pk, kit, "timber", Vector3(bx0, -0.2, bz1), Vector3(bx0 + 1.2, 0.32, bz0), Color(0.45, 0.32, 0.2))
		pk.quad(kit, "matte", [Vector3(bx0 + 0.05, 0.33, bz1 + 0.05), Vector3(bx0 + 1.15, 0.33, bz1 + 0.05), Vector3(bx0 + 1.15, 0.33, bz0 - 0.05), Vector3(bx0 + 0.05, 0.33, bz0 - 0.05)],
				Vector3.UP, Color(0.28, 0.20, 0.13))
		for row in range(3):
			var rx: float = bx0 + 0.25 + 0.35 * float(row)
			if b == 1:
				var zz: float = bz0 - 0.3
				while zz > bz1 + 0.2:
					_blob(pk, kit, "leaf", Vector3(rx, 0.45, zz), Vector3(0.16, 0.12, 0.16), Color(0.38, 0.55, 0.32))
					zz -= 0.45
			else:
				_wblock(pk, kit, "leaf", Vector3(rx - 0.08, 0.33, bz1 + 0.15), Vector3(rx + 0.08, 0.33 + 0.18 + 0.1 * float(row % 2), bz0 - 0.15),
						Color(0.24, 0.46, 0.2).lightened(0.05 * float(row)))
	# The rain barrel by the shed, stepping stones, gnomes, the flagpole.
	pk.lathe(kit, "plastic", Vector3(sx1 + 0.55, 0, sz0 - 0.3), [Vector2(0.001, 0.0), Vector2(0.36, 0.0), Vector2(0.4, 0.5), Vector2(0.36, 1.0), Vector2(0.38, 1.02),
			Vector2(0.001, 1.02)], 12, Color(0.18, 0.32, 0.2))
	var zz2 := -0.6
	while zz2 > sz0 + 1.6:
		pk.lathe(kit, "concrete", Vector3(gx + sin(zz2) * 0.3, 0, zz2), [Vector2(0.001, 0.0), Vector2(0.28, 0.0), Vector2(0.28, 0.05), Vector2(0.001, 0.05)], 8,
				Color(0.62, 0.6, 0.57))
		zz2 -= 0.65
	for g in range(3):
		_gnome(pk, kit, Vector3(rng.randf_range(0.9, w * 0.4), 0, rng.randf_range(-2.0, sz0 + 1.8)), rng.randf() * TAU,
				[Color(0.2, 0.36, 0.7), Color(0.2, 0.5, 0.25), Color(0.6, 0.3, 0.15)][g])
	var fp := Vector3(w - 1.2, 0, sz0 + 0.5)
	pk.tube(kit, "painted", fp + Vector3(0, -0.3, 0), fp + Vector3(0, 5.0, 0), 0.05, 0.035, 8, WIN_WHITE, true)
	pk.lathe(kit, "gold", fp + Vector3(0, 5.0, 0), [Vector2(0.001, 0.0), Vector2(0.07, 0.05), Vector2(0.001, 0.14)], 8, KR_GOLD)
	var pf := Transform3D(Basis(), fp + Vector3(0.05, 4.4, 0))
	_prism(pk, kit, "leaf", pf, PackedVector2Array([Vector2(0, 0.0), Vector2(2.2, 0.28), Vector2(0, 0.28)]), -0.005, 0.005, KR_GOLD, Vector2(1, 0), true)
	_prism(pk, kit, "leaf", pf, PackedVector2Array([Vector2(0, 0.28), Vector2(2.2, 0.28), Vector2(0, 0.56)]), -0.005, 0.005, KR_RED, Vector2(1, 0), true)


## A garden gnome at p facing `yaw`: a coat, a white beard, a pink face, a tall red cap; 0.45m.
static func _gnome(pk: PropKit, kit: Dictionary, p: Vector3, yaw: float, coat: Color) -> void:
	var f := Basis(Vector3.UP, yaw)
	pk.lathe(kit, "plastic", p, [Vector2(0.001, 0.0), Vector2(0.11, 0.0), Vector2(0.1, 0.12), Vector2(0.08, 0.22), Vector2(0.001, 0.24)], 8, coat)
	pk.lathe(kit, "plastic", p, [Vector2(0.001, 0.0), Vector2(0.115, 0.0), Vector2(0.115, 0.03), Vector2(0.001, 0.03)], 8, Color(0.2, 0.14, 0.1))
	_blob(pk, kit, "plastic", p + Vector3(0, 0.29, 0), Vector3(0.06, 0.06, 0.06), Color(0.95, 0.72, 0.6))
	_blob(pk, kit, "plastic", p + f * Vector3(0, 0.24, 0.05), Vector3(0.06, 0.07, 0.04), Color(0.96, 0.96, 0.94))
	pk.lathe(kit, "plastic", p + Vector3(0, 0.31, 0), [Vector2(0.07, 0.0), Vector2(0.05, 0.08), Vector2(0.02, 0.15), Vector2(0.001, 0.2)], 8, Color(0.85, 0.08, 0.08))


## A beer garden (Biergarten) w x d: a low white fence along the front with an opening, a serving hut at the back with
## its counter, beer-tent table sets in rows, square parasols over them, string lights on poles round it.
static func beer_garden(pk: PropKit, kit: Dictionary, w: float, d: float, _rng: RandomNumberGenerator) -> void:
	var white := Color(0.94, 0.94, 0.9)
	var x := 0.1
	while x < w:
		if absf(x - w * 0.5) > 1.2:
			pk.beam(kit, "painted", Vector3(x, -0.2, -0.1), Vector3(x, 0.8, -0.1), 0.07, 0.07, white)
		x += 1.2
	for ry in [0.35, 0.75]:
		pk.beam(kit, "painted", Vector3(0.1, ry, -0.1), Vector3(w * 0.5 - 1.2, ry, -0.1), 0.05, 0.08, white, Vector3.UP)
		pk.beam(kit, "painted", Vector3(w * 0.5 + 1.2, ry, -0.1), Vector3(w - 0.1, ry, -0.1), 0.05, 0.08, white, Vector3.UP)
	# The serving hut (Ausschank) at the back.
	var hx0: float = w * 0.5 - 2.2
	var hx1: float = w * 0.5 + 2.2
	var hz1: float = -d
	var hz0: float = -d + 2.6
	var wood := Color(0.52, 0.36, 0.22)
	_wblock(pk, kit, "concrete", Vector3(hx0 - 0.1, -0.4, hz1), Vector3(hx1 + 0.1, 0.15, hz0 + 0.1), Color(0.6, 0.58, 0.54))
	var hf := _wf(Vector3(hx0, 0, hz0), Vector3(0, 0, 1))
	_face(pk, kit, "lapboards", hf, 0.0, 0.15, hx1 - hx0, 1.05, 0.0, wood)
	_face(pk, kit, "lapboards", hf, 0.0, 2.25, hx1 - hx0, 2.6, 0.0, wood)
	_face(pk, kit, "lapboards", hf, 0.0, 1.05, 0.25, 2.25, 0.0, wood)
	_face(pk, kit, "lapboards", hf, hx1 - hx0 - 0.25, 1.05, hx1 - hx0, 2.25, 0.0, wood)
	_face(pk, kit, "matte", _wf(Vector3(hx0, 0, hz0 - 0.6), Vector3(0, 0, 1)), 0.25, 1.05, hx1 - hx0 - 0.25, 2.25, 0.0, Color(0.12, 0.1, 0.08))
	for u2 in [0.25, hx1 - hx0 - 0.25]:
		_face(pk, kit, "matte", _wf(Vector3(hx0 + u2, 0, hz0 - 0.6), Vector3(1 if u2 < 1.0 else -1, 0, 0)), -0.6 if u2 < 1.0 else 0.0, 1.05, 0.6 if u2 >= 1.0 else 0.0, 2.25, 0.0,
				Color(0.15, 0.12, 0.1))
	_wblock(pk, kit, "timber", Vector3(hx0 + 0.1, 1.05, hz0 - 0.05), Vector3(hx1 - 0.1, 1.12, hz0 + 0.4), Color(0.4, 0.26, 0.15))
	pk.quad(kit, "matte", [Vector3(hx0 + 0.25, 2.25, hz0 - 0.6), Vector3(hx0 + 0.25, 2.25, hz0), Vector3(hx1 - 0.25, 2.25, hz0), Vector3(hx1 - 0.25, 2.25, hz0 - 0.6)],
			Vector3.DOWN, Color(0.15, 0.12, 0.1))
	for side in [-1.0, 1.0]:
		var swf: Transform3D = _wf(Vector3(hx1, 0, hz0), Vector3(1, 0, 0)) if side > 0.0 else _wf(Vector3(hx0, 0, hz1), Vector3(-1, 0, 0))
		_face(pk, kit, "lapboards", swf, 0.0, 0.15, hz0 - hz1, 2.6, 0.0, wood)
	_face(pk, kit, "lapboards", _wf(Vector3(hx1, 0, hz1), Vector3(0, 0, -1)), 0.0, 0.15, hx1 - hx0, 3.2, 0.0, wood)
	var rp0 := Vector3(hx0 - 0.4, 2.55, hz0 + 0.9)
	var rp1 := Vector3(hx1 + 0.4, 2.55, hz0 + 0.9)
	var rp2 := Vector3(hx1 + 0.4, 3.3, hz1 - 0.3)
	var rp3 := Vector3(hx0 - 0.4, 3.3, hz1 - 0.3)
	roof(pk, kit, "biber", rp0, rp1, rp2, rp3, BIBERS[0], Vector3(0, hz0 - hz1 + 1.2, 0.75).normalized(), true)
	for tri_side in [[hx0, -1.0], [hx1, 1.0]]:
		var tx: float = tri_side[0]
		var tn := Vector3(float(tri_side[1]), 0, 0)
		pk.tri(kit, "lapboards", Vector3(tx, 2.6, hz0), Vector3(tx, 2.6, hz1), Vector3(tx, 3.2, hz1), tn, tn, tn, wood, tn)
	_wblock(pk, kit, "painted", Vector3(hx0 + 0.6, 2.62, hz0 + 0.02), Vector3(hx1 - 0.6, 3.0, hz0 + 0.06), Color(0.12, 0.30, 0.20))
	# Table sets in rows, parasols over them.
	var cols: int = maxi(int((w - 2.0) / 3.4), 1)
	var rows: int = maxi(int((d - 4.6) / 2.8), 1)
	for ci in range(cols):
		for ri in range(rows):
			var c := Vector3(1.6 + (float(ci) + 0.5) * (w - 3.2) / float(cols), 0, -1.8 - (float(ri) + 0.5) * (d - 5.0) / float(rows))
			_bierbank(pk, kit, c)
			if (ci + ri) % 2 == 0:
				_parasol(pk, kit, c + Vector3(1.6, 0, 0), [Color(0.95, 0.93, 0.85), KR_RED][(ci + ri / 2) % 2])
	# String lights round it on poles.
	var poles: Array = [Vector3(0.3, 0, -0.3), Vector3(w - 0.3, 0, -0.3), Vector3(w - 0.3, 0, hz0 + 0.3), Vector3(0.3, 0, hz0 + 0.3)]
	for p in poles:
		pk.tube(kit, "timber", p + Vector3(0, -0.3, 0), p + Vector3(0, 3.6, 0), 0.06, 0.05, 6, Color(0.4, 0.28, 0.17), true)
	for i in range(4):
		var a: Vector3 = poles[i] + Vector3(0, 3.5, 0)
		var b: Vector3 = poles[(i + 1) % 4] + Vector3(0, 3.5, 0)
		var nseg: int = maxi(int(a.distance_to(b) / 1.0), 2)
		var prev: Vector3 = a
		for k in range(1, nseg + 1):
			var t: float = float(k) / float(nseg)
			var q: Vector3 = a.lerp(b, t) - Vector3(0, 0.5 * 4.0 * t * (1.0 - t), 0)
			pk.beam(kit, "steel", prev, q, 0.012, 0.012, CAST)
			_blob(pk, kit, "lamp", q - Vector3(0, 0.06, 0), Vector3(0.05, 0.07, 0.05), [Color(1.0, 0.85, 0.5), Color(1.0, 0.5, 0.35), Color(0.6, 0.85, 0.5)][k % 3])
			prev = q


## A beer-tent table set (Bierzeltgarnitur) centred on c, along x: a table 2.2 x 0.5m on folding legs, a bench each side.
static func _bierbank(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	var wood := Color(0.62, 0.45, 0.28)
	var leg := Color(0.3, 0.3, 0.32)
	_wblock(pk, kit, "timber", c + Vector3(-1.1, 0.74, -0.25), c + Vector3(1.1, 0.77, 0.25), wood, true, true)
	for lx in [-0.85, 0.85]:
		pk.beam(kit, "steel", c + Vector3(lx, 0.0, -0.22), c + Vector3(lx, 0.74, 0.0), 0.03, 0.03, leg)
		pk.beam(kit, "steel", c + Vector3(lx, 0.0, 0.22), c + Vector3(lx, 0.74, 0.0), 0.03, 0.03, leg)
	for bz in [-0.62, 0.62]:
		_wblock(pk, kit, "timber", c + Vector3(-1.1, 0.44, bz - 0.125), c + Vector3(1.1, 0.47, bz + 0.125), wood, true, true)
		for lx2 in [-0.85, 0.85]:
			pk.beam(kit, "steel", c + Vector3(lx2, 0.0, bz - 0.1), c + Vector3(lx2, 0.44, bz), 0.025, 0.025, leg)
			pk.beam(kit, "steel", c + Vector3(lx2, 0.0, bz + 0.1), c + Vector3(lx2, 0.44, bz), 0.025, 0.025, leg)


## A square market parasol at c: a weighted foot, a pole, a canopy 3m square in four sloping panels (both faces).
static func _parasol(pk: PropKit, kit: Dictionary, c: Vector3, col: Color) -> void:
	pk.lathe(kit, "concrete", c, [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.12), Vector2(0.001, 0.12)], 8, Color(0.55, 0.55, 0.52))
	pk.tube(kit, "metal", c, c + Vector3(0, 2.75, 0), 0.03, 0.03, 6, Color(0.85, 0.85, 0.83), true)
	var top: Vector3 = c + Vector3(0, 2.8, 0)
	var e: Array = [Vector3(-1.5, 2.25, -1.5), Vector3(1.5, 2.25, -1.5), Vector3(1.5, 2.25, 1.5), Vector3(-1.5, 2.25, 1.5)]
	for k in range(4):
		var a: Vector3 = c + e[k]
		var b: Vector3 = c + e[(k + 1) % 4]
		var n: Vector3 = (b - a).cross(top - a).normalized()
		if n.y < 0.0:
			n = -n
		pk.tri(kit, "canvas", a, b, top, n, n, n, col, n)
		pk.tri(kit, "canvas", a + Vector3(0, -0.01, 0), b + Vector3(0, -0.01, 0), top + Vector3(0, -0.01, 0), -n, -n, -n, col.darkened(0.3), -n)
		pk.quad(kit, "canvas", [a, b, b + Vector3(0, -0.2, 0), a + Vector3(0, -0.2, 0)], (a + b - 2.0 * c).normalized() * Vector3(1, 0, 1), col)
		pk.quad(kit, "canvas", [a, a + Vector3(0, -0.2, 0), b + Vector3(0, -0.2, 0), b], -((a + b - 2.0 * c).normalized() * Vector3(1, 0, 1)), col.darkened(0.3))


## A maypole (Maibaum) standing on the origin: a pole 24m tall painted in a red and white spiral, a stone plinth and its
## iron straps, guild boards on bars up both sides (the miners' hammer and pick, a crown, a pretzel, a tower), a green
## wreath with ribbons, the town's crown at the top.
static func maibaum(pk: PropKit, kit: Dictionary) -> void:
	_plan_prism(pk, kit, "ashlar", Vector3.ZERO, _ngon(1.0, 8, PI / 8.0), -1.0, 0.6, SANDSTONE)
	var h := 24.0
	var segs := 10
	var slice := 0.6
	var y := 0.6
	while y < h - 0.01:
		var y1: float = minf(y + slice, h)
		var r0: float = lerpf(0.24, 0.1, y / h)
		var r1: float = lerpf(0.24, 0.1, y1 / h)
		for j in range(segs):
			var a0: float = TAU * float(j) / float(segs)
			var a1: float = TAU * float(j + 1) / float(segs)
			var stripe: int = int(floor(float(j) / float(segs) * 4.0 + y / 1.6)) % 2
			var col: Color = KR_RED if stripe == 0 else Color(0.95, 0.95, 0.92)
			var e0 := Vector3(cos(a0), 0, sin(a0))
			var e1 := Vector3(cos(a1), 0, sin(a1))
			pk.quad(kit, "painted", [e0 * r0 + Vector3(0, y, 0), e1 * r0 + Vector3(0, y, 0), e1 * r1 + Vector3(0, y1, 0), e0 * r1 + Vector3(0, y1, 0)], (e0 + e1).normalized(), col)
		y = y1
	# Its iron straps to the plinth's two posts.
	for side in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(side * 0.3 - 0.06, 0.6, -0.15), Vector3(side * 0.3 + 0.06, 3.0, 0.15), CAST)
		for sy in [1.2, 2.6]:
			pk.beam(kit, "steel", Vector3(side * 0.24, sy, -0.18), Vector3(side * 0.24, sy, 0.18), 0.05, 0.08, CAST)
	# Guild boards: bars across the pole, a board at each end, an emblem on each.
	var levels: Array = [[7.0, "mining", "crown"], [11.0, "pretzel", "tower"], [15.0, "crown", "mining"]]
	for lv in levels:
		var ly: float = lv[0]
		pk.beam(kit, "steel", Vector3(-1.6, ly, 0), Vector3(1.6, ly, 0), 0.05, 0.05, CAST)
		for k in range(2):
			var bx: float = -1.6 if k == 0 else 1.6
			var bf := Transform3D(Basis(), Vector3(bx, ly - 0.75, 0))
			_prism(pk, kit, "painted", bf, _rp(-0.42, -0.55, 0.42, 0.55), -0.03, 0.03, Color(0.12, 0.28, 0.5), Vector2(0, 1), true)
			_maypole_emblem(pk, kit, bf, String(lv[1 + k]))
	# The wreath, its ribbons and the crown.
	var wy := h - 3.0
	var wr := 1.0
	var prev := Vector3(wr, wy, 0)
	for k2 in range(1, 17):
		var a: float = TAU * float(k2) / 16.0
		var q := Vector3(cos(a) * wr, wy, sin(a) * wr)
		pk.tube(kit, "leaf", prev, q, 0.13, 0.13, 6, Color(0.16, 0.36, 0.16), false)
		if k2 % 2 == 0:
			pk.quad(kit, "leaf", [q + Vector3(0, -0.05, 0), q + Vector3(0.0, -0.05, 0.08), q + Vector3(0.05, -1.6, 0.08), q + Vector3(0.05, -1.6, 0.0)],
					Vector3(1, 0, 0), [KR_RED, Color(0.95, 0.95, 0.92), KR_GOLD][k2 % 3])
		prev = q
	for sp in range(4):
		var a2: float = TAU * float(sp) / 4.0
		pk.beam(kit, "steel", Vector3(0, wy + 0.8, 0), Vector3(cos(a2) * wr, wy, sin(a2) * wr), 0.02, 0.02, CAST)
	_crown(pk, kit, Vector3(0, h, 0), 0.4)


## An emblem on a maypole's guild board (its frame's xy plane, both faces): "mining" (hammer and pick crossed: Schlägel und
## Eisen), "crown", "pretzel", "tower".
static func _maypole_emblem(pk: PropKit, kit: Dictionary, bf: Transform3D, kind: String) -> void:
	var g := KR_GOLD
	var polys: Array = []
	match kind:
		"mining":
			polys.append_array(_union([_clip(_band(Vector2(-0.3, -0.35), Vector2(0.3, 0.3), 0.07), _rp(-0.4, -0.45, 0.4, 0.45))[0],
					_clip(_band(Vector2(0.3, -0.35), Vector2(-0.3, 0.3), 0.07), _rp(-0.4, -0.45, 0.4, 0.45))[0]]))
			polys.append(PackedVector2Array([Vector2(0.14, 0.22), Vector2(0.36, 0.44), Vector2(0.44, 0.36), Vector2(0.22, 0.14)]))
			polys.append(PackedVector2Array([Vector2(-0.36, 0.2), Vector2(-0.16, 0.3), Vector2(-0.24, 0.42), Vector2(-0.44, 0.28)]))
		"crown":
			polys.append(PackedVector2Array([Vector2(-0.3, -0.2), Vector2(0.3, -0.2), Vector2(0.3, 0.0), Vector2(0.36, 0.25), Vector2(0.17, 0.08),
					Vector2(0.0, 0.32), Vector2(-0.17, 0.08), Vector2(-0.36, 0.25), Vector2(-0.3, 0.0)]))
		"pretzel":
			polys.append(_circle_pts(Vector2(0, 0.02), 0.3, 12))
		_:
			polys.append(PackedVector2Array([Vector2(-0.22, -0.4), Vector2(0.22, -0.4), Vector2(0.22, 0.2), Vector2(0.28, 0.2), Vector2(0.28, 0.32),
					Vector2(0.14, 0.32), Vector2(0.14, 0.24), Vector2(0.04, 0.24), Vector2(0.04, 0.32), Vector2(-0.04, 0.32), Vector2(-0.04, 0.24),
					Vector2(-0.14, 0.24), Vector2(-0.14, 0.32), Vector2(-0.28, 0.32), Vector2(-0.28, 0.2), Vector2(-0.22, 0.2)]))
	for p in polys:
		_prism(pk, kit, "gold", bf, p, 0.03, 0.045, g)
		_prism(pk, kit, "gold", Transform3D(bf.basis * Basis(Vector3.UP, PI), bf.origin), _mirror_x(p), 0.03, 0.045, g)
	if kind == "pretzel":
		_prism(pk, kit, "painted", bf, _circle_pts(Vector2(0, 0.02), 0.18, 10), 0.045, 0.05, Color(0.12, 0.28, 0.5))
		_prism(pk, kit, "painted", Transform3D(bf.basis * Basis(Vector3.UP, PI), bf.origin), _circle_pts(Vector2(0, 0.02), 0.18, 10), 0.045, 0.05, Color(0.12, 0.28, 0.5))


static func _mirror_x(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in p:
		out.append(Vector2(-q.x, q.y))
	return out
