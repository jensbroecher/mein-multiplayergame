extends RefCounted
## The Kronburg GP finale's dock zone (a point-to-point rally through the city's docks): the demolition site
## (Abrissbaustelle) and the scrapyard (Schrottplatz) the route runs through. A lattice-boom crawler crane rigged for
## demolition and its wrecking ball (a hazard: the caller swings the ball as a pendulum from CRANE_TIP), the 1960s office
## block it is knocking down, rubble heaps, wrecked cars and their crushed bales, bale walls, scrap heaps, a scrap
## material handler (a hazard: the caller slews its upper on the slew ring and its magnet hangs from the stick's tip with a
## wreck stuck under it), a car baler, the yard's office containers and sign, a weighbridge, the corrugated fence, skips,
## tyres, drums and roll-off sorting bins. Fictional throughout: Abbruch Brandt (the demolition firm), Schrott & Metalle
## König (the yard), Korvald (the crane's maker), Ormbach (the handler's), Schauberg (the baler's), the Kronburger
## Bausparkasse (the block's old tenant); the cars are generic shapes of no make.
##
## Everything is built at LIFE size through a PropKit in its own frame (y = 0 the ground, footings down to about y = -1.5,
## the front toward +z unless a builder says otherwise) and grown by the caller (PROP_SCALE 1.6). UVs are in metres times
## `uvk` (the caller's scale) where a shader reads them. Labels are [text, position, outward normal, cap height, colour,
## board width] in life-size kit coordinates. `<name>_solids(...)` give the boxes for colliders, [Transform3D (life, the
## prop's frame), Vector3 size], for the same arguments as the builder.
##
## Material keys (make_material): this kit's "scrap" and "scrapm" (scrap_metal.gdshader: the vertex colour the paint, its
## alpha the wear; world space for what stands still, object space ("scrapm") for what moves), "room" (scrap_room.gdshader:
## the office block's finishes, alpha the finish's id, see ROOM_*), "rustiron" (hut_roof_iron, rusted), "tyre"
## (tyre_wall.gdshader), "glassdark"; SteelworksKit's "rusty", "corten", "grime", "shell", "heap", "hazard", "lens",
## "brick"; YardKit's "concrete", "iron", "timber", "painted", "stone"; CampKit's vertex-colour "steel", "metal", "matte",
## "rubber", "paint", "plastic", "chrome", "canvas", "wood". Moving parts (the ball, the handler's upper, the magnet) use
## only "scrapm" and vertex-colour keys, so nothing on them is patterned from the world position.
##
## Faces never share a plane: trims, glass, frames and lettering boards stand 2.5cm or more proud of what is behind them
## and parts that meet overlap or step. Godot's front faces wind clockwise: PropKit.tri winds every triangle for the `out`
## it is given.

const PropKit = preload("res://PropKit.gd")
const SW = preload("res://SteelworksKit.gd")
const YK = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")

static var uvk := 1.6
static var _mats := {}
## The current sub-assembly's offset inside the prop's frame (labels are given in prop coordinates).
static var _lx := Transform3D.IDENTITY

const SW_KEYS := ["rusty", "corten", "grime", "shell", "heap", "hazard", "lens", "brick", "floor"]
const YK_KEYS := ["concrete", "iron", "timber", "painted", "stone", "plaster", "lapboards", "battens"]
const TANGENT_KEYS := ["iron", "rustiron", "concrete", "slate", "tile", "zinc"]

const UP := Vector3.UP
const WHITE := Color(1, 1, 1)
const BLACK := Color(0.03, 0.03, 0.03)
const STEEL_DARK := Color(0.15, 0.16, 0.16)
const RUBBER := Color(0.06, 0.06, 0.065)
const SIGN_YELLOW := Color(0.98, 0.80, 0.10)
const RAIL_YELLOW := Color(0.92, 0.72, 0.12)
const GLASS := Color(0.09, 0.12, 0.14)
const CONC := Color(0.64, 0.63, 0.60)
const RUST := Color(0.42, 0.22, 0.12)

## The office block's finishes (scrap_room.gdshader): the vertex colour's alpha is (id + 0.5) / 16.
const ROOM_PAINT := 0
const ROOM_STRIPES := 1
const ROOM_CIRCLES := 2
const ROOM_SPRIGS := 3
const ROOM_TILES := 4
const ROOM_MOSAIC := 5
const ROOM_WASCHBETON := 6
const ROOM_LINO := 7
const ROOM_STRIPS := 8
const ROOM_CARPET := 9
const ROOM_CEILING := 10
const ROOM_BROKEN := 11
const ROOM_STAIRWELL := 12
## The scale "room" UVs are written at (the props' PROP_SCALE).
const ROOM_UNIT := 1.6


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"scrap", "scrapm":
			var s := ShaderMaterial.new()
			s.shader = load("res://scrap_metal.gdshader")
			s.set_shader_parameter("object_space", key == "scrapm")
			return s
		"room":
			# UVs are life metres times the props' scale, 1.6, whatever kit made the material first (a moving part's kit
			# grows nothing, and the generator commits the batches after one).
			var r := ShaderMaterial.new()
			r.shader = load("res://scrap_room.gdshader")
			r.set_shader_parameter("unit", ROOM_UNIT)
			r.set_shader_parameter("damage", 0.3)
			return r
		"rustiron":
			var i := ShaderMaterial.new()
			i.shader = load("res://hut_roof_iron.gdshader")
			i.set_shader_parameter("rust_amount", 0.72)
			return i
		"tyre":
			var t := ShaderMaterial.new()
			t.shader = load("res://tyre_wall.gdshader")
			return t
		"glassdark":
			var g := CampKit.make_material("plastic")
			g.roughness = 0.08
			g.metallic = 0.5
			return g
	if key in SW_KEYS:
		return SW.make_material(key)
	if key in YK_KEYS:
		return YK.make_material(key)
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
	SW.uvk = scale
	YK.uvk = scale
	_lx = Transform3D.IDENTITY
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

## Moves the kit's frame by `t` (a sub-assembly's offset); returns what `_pop` puts back.
static func _push(pk: PropKit, t: Transform3D) -> Array:
	var saved: Array = [pk.xf, _lx]
	pk.set_frame(pk.xf * t)
	_lx = _lx * t
	return saved


static func _pop(pk: PropKit, saved: Array) -> void:
	pk.set_frame(saved[0])
	_lx = saved[1]


static func _lbl(labels: Array, text: String, p: Vector3, n: Vector3, cap: float, col: Color, w := 0.0) -> void:
	labels.append([text, _lx * p, (_lx.basis * n).normalized(), cap, col, w])


static func _rng(seed_v: int, salt := 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(seed_v * 7919 + salt * 104729 + 17)
	return r


## A room finish's colour: the tint with the finish's id in its alpha.
static func room(col: Color, id: int) -> Color:
	return Color(col.r, col.g, col.b, (float(id) + 0.5) / 16.0)


## A colour for "scrap"/"scrapm": the paint with its wear in the alpha.
static func worn(col: Color, wear: float) -> Color:
	return Color(col.r, col.g, col.b, clampf(wear, 0.0, 1.0))


## A box centred at `c` turned by `basis`, UVs in metres.
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## An axis-aligned box between two corners, UVs in metres.
static func _blk(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	pk.block(kit, key, lo, hi, col, uvk)


## A beam's four long sides from a to b (no end caps: members whose ends meet other members), `w` wide along `side` (or any
## horizontal), `t` thick.
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


## A round bar from a to b (radius r, `segs` sides), open ended unless `caps`.
static func _rod(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, r: float, segs: int, col: Color, caps := false) -> void:
	pk.tube(kit, key, a, b, r, r, segs, col, caps)


## A polyline of round bar (rope, cable, rebar), open ended.
static func _rods(pk: PropKit, kit: Dictionary, key: String, pts: Array, r: float, segs: int, col: Color) -> void:
	for i in range(pts.size() - 1):
		_rod(pk, kit, key, pts[i], pts[i + 1], r, segs, col)


## A flat triangle facing away from `inside` (a point within the solid it bounds), UVs projected on its plane in metres.
static func _ftri(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3, uv := false) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	if uv:
		var e1 := (b - a).normalized()
		var e2 := n.cross(e1)
		pk.tri(kit, key, a, b, c, n, n, n, col, n, Vector2.ZERO, Vector2((b - a).dot(e1), (b - a).dot(e2)) * uvk,
				Vector2((c - a).dot(e1), (c - a).dot(e2)) * uvk)
	else:
		pk.tri(kit, key, a, b, c, n, n, n, col, n)


## A lumpy block (rubble, a scrap lump): a box of half sizes `half` round `c`, turned by `basis`, each corner moved by up to
## `jit` of the size, flat shaded (12 triangles). Each face a shade off `col`.
static func _chunk(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, half: Vector3, jit: float, rng: RandomNumberGenerator, col: Color,
		uv := false) -> void:
	var p: Array = []
	for i in range(8):
		var sx: float = 1.0 if (i & 1) else -1.0
		var sy: float = 1.0 if (i & 2) else -1.0
		var sz: float = 1.0 if (i & 4) else -1.0
		var lp := Vector3(sx * half.x * (1.0 + rng.randf_range(-jit, jit)), sy * half.y * (1.0 + rng.randf_range(-jit, jit)),
				sz * half.z * (1.0 + rng.randf_range(-jit, jit)))
		lp += Vector3(rng.randf_range(-jit, jit) * half.x, rng.randf_range(-jit, jit) * half.y, rng.randf_range(-jit, jit) * half.z) * 0.5
		p.append(c + basis * lp)
	var faces: Array = [[0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1], [2, 3, 7, 6], [0, 1, 3, 2], [4, 6, 7, 5]]
	for f in faces:
		var fc: Color = col.darkened(rng.randf_range(0.0, 0.12))
		_ftri(pk, kit, key, p[f[0]], p[f[1]], p[f[2]], fc, c, uv)
		_ftri(pk, kit, key, p[f[0]], p[f[2]], p[f[3]], fc, c, uv)


## A lathe whose profile carries its colours: [radius, height, Color] from the bottom up, round the local vertical through
## `c` turned by `basis`. Smooth round the axis; the colour changes at each ring.
static func _lathe_c(pk: PropKit, kit: Dictionary, key: String, c: Vector3, prof: Array, segs: int, basis := Basis()) -> void:
	for k in range(prof.size() - 1):
		var p0: Array = prof[k]
		var p1: Array = prof[k + 1]
		var r0: float = p0[0]
		var y0: float = p0[1]
		var r1: float = p1[0]
		var y1: float = p1[1]
		var d := Vector2(r1 - r0, y1 - y0)
		if d.length_squared() < 1e-12:
			continue
		var n2 := Vector2(d.y, -d.x).normalized()
		var c0: Color = p0[2]
		var c1: Color = p1[2]
		for j in range(segs):
			var t0 := TAU * j / segs
			var t1 := TAU * (j + 1) / segs
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var um := (u0 + u1).normalized()
			var out := basis * (um * n2.x + UP * n2.y)
			var n0 := basis * (u0 * n2.x + UP * n2.y)
			var n1 := basis * (u1 * n2.x + UP * n2.y)
			var q00 := c + basis * (u0 * r0 + UP * y0)
			var q01 := c + basis * (u1 * r0 + UP * y0)
			var q10 := c + basis * (u0 * r1 + UP * y1)
			var q11 := c + basis * (u1 * r1 + UP * y1)
			var cm: Color = c0.lerp(c1, 0.5)
			if r0 > 1e-5:
				pk.tri(kit, key, q00, q01, q11, n0, n1, n1, cm, out)
			if r1 > 1e-5:
				pk.tri(kit, key, q00, q11, q10, n0, n1, n0, cm, out)


## One chain link round `c`: a stretched hexagon of round wire (radius rw) in the plane of `along` and `side`, `a` its half
## length and `b` its half width to the wire's centre (48 triangles).
static func _link(pk: PropKit, kit: Dictionary, key: String, c: Vector3, along: Vector3, side: Vector3, a: float, b: float, rw: float, col: Color) -> void:
	var nrm := along.cross(side).normalized()
	var np := 6
	var pts: Array = []
	for k in range(np):
		var th := TAU * float(k) / float(np)
		pts.append(c + along * (a * cos(th)) + side * (b * sin(th)))
	var rings: Array = []
	for k in range(np):
		var p: Vector3 = pts[k]
		var pn: Vector3 = pts[(k + 1) % np]
		var pp: Vector3 = pts[(k - 1 + np) % np]
		var t: Vector3 = (pn - pp).normalized()
		var r: Vector3 = p - c
		r = (r - t * r.dot(t)).normalized()
		var ring: Array = []
		for j in range(4):
			var ph := TAU * (float(j) + 0.5) / 4.0
			var d: Vector3 = r * cos(ph) + nrm * sin(ph)
			ring.append([p + d * rw, d])
		rings.append(ring)
	for k in range(np):
		var r0: Array = rings[k]
		var r1: Array = rings[(k + 1) % np]
		for j in range(4):
			var j1 := (j + 1) % 4
			var a0: Array = r0[j]
			var a1: Array = r0[j1]
			var b0: Array = r1[j]
			var b1: Array = r1[j1]
			var o: Vector3 = ((a0[1] as Vector3) + (b1[1] as Vector3)).normalized()
			pk.tri(kit, key, a0[0], a1[0], b1[0], a0[1], a1[1], b1[1], col, o)
			pk.tri(kit, key, a0[0], b1[0], b0[0], a0[1], b1[1], b0[1], col, o)


## A chain of links from a to b, each `pitch` long inside, of wire `rw`, alternate links turned a quarter round.
static func _chain(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, pitch: float, rw: float, col: Color, side0 := Vector3.RIGHT) -> void:
	var ax := b - a
	var length := ax.length()
	if length < 1e-3:
		return
	var d := ax / length
	var n: int = maxi(1, int(round(length / pitch)))
	var p: float = length / float(n)
	var s0 := (side0 - d * side0.dot(d))
	if s0.length_squared() < 1e-6:
		s0 = Vector3.FORWARD - d * Vector3.FORWARD.dot(d)
	s0 = s0.normalized()
	var s1 := d.cross(s0).normalized()
	for i in range(n):
		var c := a + d * (p * (float(i) + 0.5))
		_link(pk, kit, key, c, d, s0 if i % 2 == 0 else s1, p * 0.5 + rw, p * 0.3 + rw, rw, col)


## An outline given in (z, y) extruded across x from x0 to x1 (PropKit.extrude in a frame turned a quarter round).
static func _extrude_zy(pk: PropKit, kit: Dictionary, key: String, ol: PackedVector2Array, x0: float, x1: float, bevel: float, col: Color, uv := false) -> void:
	var s := _push(pk, Transform3D(Basis(UP, -PI * 0.5), Vector3.ZERO))
	pk.extrude(kit, key, ol, -x1, -x0, bevel, col, Callable(), uvk if uv else 0.0)
	_pop(pk, s)


## An outline in plan, (x, z), extruded up from y0 to y1.
static func _extrude_plan(pk: PropKit, kit: Dictionary, key: String, ol: PackedVector2Array, y0: float, y1: float, bevel: float, col: Color, uv := false) -> void:
	var flipped := PackedVector2Array()
	for p in ol:
		flipped.append(Vector2(p.x, -p.y))
	var s := _push(pk, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
	pk.extrude(kit, key, flipped, y0, y1, bevel, col, Callable(), uvk if uv else 0.0)
	_pop(pk, s)


## A flat polygon in a wall's frame (x along, y up, z out of it) at depth d, facing out (or back), UVs (u, v) in metres.
static func _pface(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, ol: PackedVector2Array, d: float, col: Color, back := false) -> void:
	var tris := Geometry2D.triangulate_polygon(ol)
	var n: Vector3 = wf.basis.z.normalized()
	if back:
		n = -n
	for i in range(0, tris.size(), 3):
		var a: Vector2 = ol[tris[i]]
		var b: Vector2 = ol[tris[i + 1]]
		var c: Vector2 = ol[tris[i + 2]]
		pk.tri(kit, key, wf * Vector3(a.x, a.y, d), wf * Vector3(b.x, b.y, d), wf * Vector3(c.x, c.y, d), n, n, n, col, n, a * uvk, b * uvk, c * uvk)


## A slab of wall (or floor) in a frame wf (x along, y up, z out): the outline's face at z 0 (`col_out`), its back at -thick
## (`col_in`) and its rim through the depth (`col_rim`, the broken edges), all with UVs in metres.
static func _wall_poly(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, ol: PackedVector2Array, thick: float, col_out: Color, col_in: Color,
		col_rim: Color) -> void:
	if ol.size() < 3 or absf(PropKit._signed_area(ol)) < 1e-6:
		return
	_pface(pk, kit, key, wf, ol, 0.0, col_out)
	_pface(pk, kit, key, wf, ol, -thick, col_in, true)
	var ccw := PropKit._signed_area(ol) > 0.0
	var run := 0.0
	for i in range(ol.size()):
		var p: Vector2 = ol[i]
		var q: Vector2 = ol[(i + 1) % ol.size()]
		var e := q - p
		var el := e.length()
		if el < 1e-5:
			continue
		var o2: Vector2 = (Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)) / el
		var o3: Vector3 = (wf.basis * Vector3(o2.x, o2.y, 0.0)).normalized()
		pk.quad(kit, key, [wf * Vector3(p.x, p.y, 0.0), wf * Vector3(q.x, q.y, 0.0), wf * Vector3(q.x, q.y, -thick), wf * Vector3(p.x, p.y, -thick)], o3, col_rim,
				[Vector2(run, 0.0) * uvk, Vector2(run + el, 0.0) * uvk, Vector2(run + el, thick) * uvk, Vector2(run, thick) * uvk])
		run += el


## A box with a colour per face (UVs in metres): `cols` for -x, +x, -y, +y, -z, +z, the box's corners lo and hi.
static func _box6(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, cols: Array) -> void:
	var x0 := lo.x
	var y0 := lo.y
	var z0 := lo.z
	var x1 := hi.x
	var y1 := hi.y
	var z1 := hi.z
	var dz := z1 - z0
	pk.quad(kit, key, [Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1)], Vector3.LEFT, cols[0],
			[Vector2(0, y0) * uvk, Vector2(dz, y0) * uvk, Vector2(dz, y1) * uvk, Vector2(0, y1) * uvk])
	pk.quad(kit, key, [Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, cols[1],
			[Vector2(z0, y0) * uvk, Vector2(z1, y0) * uvk, Vector2(z1, y1) * uvk, Vector2(z0, y1) * uvk])
	pk.quad(kit, key, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)], Vector3.DOWN, cols[2],
			[Vector2(x0, z0) * uvk, Vector2(x1, z0) * uvk, Vector2(x1, z1) * uvk, Vector2(x0, z1) * uvk])
	pk.quad(kit, key, [Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], UP, cols[3],
			[Vector2(x0, z0) * uvk, Vector2(x0, z1) * uvk, Vector2(x1, z1) * uvk, Vector2(x1, z0) * uvk])
	pk.quad(kit, key, [Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0)], Vector3.FORWARD, cols[4],
			[Vector2(x1, y0) * uvk, Vector2(x0, y0) * uvk, Vector2(x0, y1) * uvk, Vector2(x1, y1) * uvk])
	pk.quad(kit, key, [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.BACK, cols[5],
			[Vector2(x0, y0) * uvk, Vector2(x1, y0) * uvk, Vector2(x1, y1) * uvk, Vector2(x0, y1) * uvk])


## A solid box for the caller's colliders: [Transform3D, size].
static func _solid(c: Vector3, size: Vector3, basis := Basis()) -> Array:
	return [Transform3D(basis, c), size]


## An axis-aligned solid between two corners.
static func _solid_lh(lo: Vector3, hi: Vector3) -> Array:
	return [Transform3D(Basis(), (lo + hi) * 0.5), (hi - lo).abs()]


## A smooth value noise in 2D (for mounds and heaps), 0..1.
static func _vn(x: float, z: float, s: int) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - float(ix)
	var fz := z - float(iz)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := _h2(ix, iz, s)
	var b := _h2(ix + 1, iz, s)
	var c := _h2(ix, iz + 1, s)
	var d := _h2(ix + 1, iz + 1, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


static func _h2(x: int, z: int, s: int) -> float:
	var h: int = hash(Vector3i(x, z, s & 0x3FFFFFFF))
	return float(h & 0xFFFF) / 65535.0


static func _pick_weighted(items: Array, weights: Array, t: float) -> Variant:
	var total := 0.0
	for w in weights:
		total += float(w)
	var x: float = t * total
	for i in range(items.size()):
		x -= float(weights[i])
		if x <= 0.0:
			return items[i]
	return items[items.size() - 1]


# ======================================================================================
#  More helpers: lettering, crumpling, wrecked cars, bales, mounds, tyres, drums, tracks, lattice booms
# ======================================================================================

const MK = preload("res://MatatuKit.gd")

## `text` in MatatuKit's block capitals (GLYPHS, five cells high), `cell` metres a cell, centred on `centre`, reading along
## `right` with its up along `up`, facing right x up; each run of lit cells one quad (stand it 2.5cm proud of its ground).
## For lettering on the moving parts, which get no labels.
static func _pixel_text(pk: PropKit, kit: Dictionary, key: String, centre: Vector3, right: Vector3, up: Vector3, cell: float, text: String, col: Color) -> void:
	var face := right.cross(up).normalized()
	var cells := 0
	for ch in text:
		cells += ((MK.GLYPHS[ch][0] as String).length() if MK.GLYPHS.has(ch) else 2) + 1
	cells -= 1
	var origin := centre - right * (float(cells) * cell * 0.5) - up * (2.5 * cell)
	var x := 0
	for ch in text:
		if not MK.GLYPHS.has(ch):
			x += 3
			continue
		var rows: Array = MK.GLYPHS[ch]
		for r in range(5):
			var row: String = rows[r]
			var i := 0
			while i < row.length():
				if row[i] != "X":
					i += 1
					continue
				var j := i
				while j < row.length() and row[j] == "X":
					j += 1
				var lo := origin + right * (float(x + i) * cell) + up * (float(4 - r) * cell)
				var span := right * (float(j - i) * cell)
				pk.quad(kit, key, [lo, lo + span, lo + span + up * cell, lo + up * cell], face, col)
				i = j
		x += (rows[0] as String).length() + 1


static func _h3(x: int, y: int, z: int, s: int) -> float:
	return float(hash(Vector4i(x, y, z, s & 0x3FFFFFFF)) & 0xFFFF) / 65535.0


## A smooth value noise in 3D, 0..1.
static func _vn3(p: Vector3, s: int) -> float:
	var ix := floori(p.x)
	var iy := floori(p.y)
	var iz := floori(p.z)
	var f := Vector3(p.x - float(ix), p.y - float(iy), p.z - float(iz))
	f = f * f * (Vector3(3, 3, 3) - f * 2.0)
	var a := lerpf(_h3(ix, iy, iz, s), _h3(ix + 1, iy, iz, s), f.x)
	var b := lerpf(_h3(ix, iy + 1, iz, s), _h3(ix + 1, iy + 1, iz, s), f.x)
	var c := lerpf(_h3(ix, iy, iz + 1, s), _h3(ix + 1, iy, iz + 1, s), f.x)
	var d := lerpf(_h3(ix, iy + 1, iz + 1, s), _h3(ix + 1, iy + 1, iz + 1, s), f.x)
	return lerpf(lerpf(a, b, f.y), lerpf(c, d, f.y), f.z)


## A crumpling offset for a point of sheet metal (amplitude `amp` either way along each axis).
static func _dent(p: Vector3, s: int, amp: float, freq := 1.6) -> Vector3:
	var q := p * freq
	return Vector3(_vn3(q, s) - 0.5, _vn3(q + Vector3(7.1, 3.3, 1.7), s + 1) - 0.5, _vn3(q + Vector3(2.9, 8.4, 5.2), s + 2) - 0.5) * (2.0 * amp)


## A quad as two flat triangles facing away from `inside` (they may not be planar: crumpled sheet).
static func _fquad(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	_ftri(pk, kit, key, a, b, c, col, inside)
	_ftri(pk, kit, key, a, c, d, col, inside)


## The wrecks' paint: faded saloon colours, from the 70s to the 00s.
const CAR_PAINTS := [Color(0.62, 0.10, 0.08), Color(0.12, 0.25, 0.52), Color(0.85, 0.83, 0.78), Color(0.15, 0.15, 0.16), Color(0.55, 0.57, 0.58),
		Color(0.20, 0.40, 0.25), Color(0.80, 0.62, 0.15), Color(0.42, 0.28, 0.16), Color(0.30, 0.48, 0.62), Color(0.70, 0.40, 0.10),
		Color(0.48, 0.12, 0.30), Color(0.88, 0.88, 0.86)]
## Generic car shapes, life metres: [length, half width, stations along the car from the nose (u 0) to the tail (u 1):
## [u, the beltline, the top (roof, or bonnet and boot)]]. Fronts toward -z.
const CAR_KINDS := [
	# A saloon (notchback).
	[4.5, 0.88, [[0.0, 0.62, 0.66], [0.05, 0.74, 0.78], [0.28, 0.85, 0.9], [0.42, 0.9, 1.4], [0.66, 0.9, 1.4], [0.81, 0.92, 0.98], [0.97, 0.9, 0.94], [1.0, 0.66, 0.7]]],
	# A hatchback.
	[3.95, 0.84, [[0.0, 0.62, 0.66], [0.06, 0.74, 0.78], [0.27, 0.84, 0.88], [0.43, 0.9, 1.42], [0.8, 0.92, 1.4], [0.97, 0.9, 1.08], [1.0, 0.66, 0.72]]],
	# An estate.
	[4.65, 0.88, [[0.0, 0.62, 0.66], [0.05, 0.74, 0.78], [0.26, 0.85, 0.9], [0.4, 0.9, 1.43], [0.92, 0.92, 1.42], [0.99, 0.9, 1.1], [1.0, 0.66, 0.7]]],
	# A small van.
	[4.4, 0.9, [[0.0, 0.6, 0.66], [0.05, 0.78, 0.84], [0.17, 0.92, 1.05], [0.3, 1.0, 1.85], [0.97, 1.0, 1.86], [1.0, 0.66, 1.8]]],
]
const CAR_CLEAR := 0.28


## A car (a generic shape of no make) in `t` (its middle on the ground, the nose toward -z): `kind` a CAR_KINDS index, the
## body in `key` ("scrap" or, moving, "scrapm") painted `col` worn by `wear` (scrap_metal.gdshader's alpha), crumpled by
## `wear` and its roof squashed down by `crush` (0..1), windows dark; `wheels` a mask of the four wheels (1 front left, 2
## front right, 4 rear left, 8 rear right), tyres in "rubber", rims in "metal". About 400 triangles.
static func _car(pk: PropKit, kit: Dictionary, key: String, t: Transform3D, kind: int, col: Color, wear: float, crush: float, s: int, wheels := 15) -> void:
	var kd: Array = CAR_KINDS[clampi(kind, 0, CAR_KINDS.size() - 1)]
	var length: float = kd[0]
	var hw: float = kd[1]
	var st: Array = kd[2]
	var sv := _push(pk, t)
	var amp: float = 0.025 + wear * 0.07
	var paint := worn(col, wear)
	var glass := worn(Color(0.06, 0.07, 0.08), 0.05)
	var under := worn(Color(0.1, 0.09, 0.08), 0.85)
	var rows: Array = []
	for i in range(st.size()):
		var e: Array = st[i]
		var u: float = e[0]
		var z: float = -length * 0.5 + u * length
		var end_k: float = 1.0 - 0.12 * pow(absf(u - 0.5) * 2.0, 6.0)
		var w: float = hw * end_k
		var yb: float = CAR_CLEAR + (0.1 if u < 0.04 or u > 0.96 else 0.0)
		var belt: float = e[1]
		var top: float = e[2]
		var gh: bool = top - belt > 0.25
		if gh:
			top = belt + (top - belt) * (1.0 - crush * 0.75)
		var tw: float = 0.74 if gh else 0.9
		var pts: Array = [Vector3(-w * 0.9, yb, z), Vector3(w * 0.9, yb, z), Vector3(w, yb + 0.18, z), Vector3(w, belt, z), Vector3(w * tw, top, z),
				Vector3(-w * tw, top, z), Vector3(-w, belt, z), Vector3(-w, yb + 0.18, z)]
		var row: Array = []
		for p in pts:
			var q: Vector3 = p
			row.append(q + _dent(q, s, amp))
		rows.append([row, gh, top])
	var inside := Vector3(0, 0.62, 0)
	for i in range(rows.size() - 1):
		var r0: Array = rows[i][0]
		var r1: Array = rows[i + 1][0]
		var g: bool = rows[i][1] and rows[i + 1][1]
		var steep: bool = absf(float(rows[i + 1][2]) - float(rows[i][2])) > 0.25
		var zc: float = ((r0[0] as Vector3).z + (r1[0] as Vector3).z) * 0.5
		for k in range(8):
			var k1 := (k + 1) % 8
			var c: Color = paint
			if k == 0:
				c = under
			elif (k == 3 or k == 5) and g:
				c = glass
			elif k == 4 and steep and (rows[i][1] or rows[i + 1][1]):
				c = glass
			_fquad(pk, kit, key, r0[k], r0[k1], r1[k1], r1[k], c, Vector3(0, 0.62, zc))
	# The nose and the tail: a fan over the end rows, the grille and lamps on them, bumpers.
	for e in [0, rows.size() - 1]:
		var r: Array = rows[e][0]
		var cc := Vector3.ZERO
		for p in r:
			cc += p
		cc /= 8.0
		var out_z: float = -1.0 if e == 0 else 1.0
		for k in range(8):
			_ftri(pk, kit, key, cc, r[k], r[(k + 1) % 8], paint, cc - Vector3(0, 0, out_z))
		var zf: float = cc.z + out_z * 0.03
		var belt0: float = float(st[0 if e == 0 else st.size() - 1][1])
		var lamp_col: Color = Color(0.82, 0.82, 0.78) if e == 0 else Color(0.62, 0.08, 0.05)
		for sx in [-1.0, 1.0]:
			_box(pk, kit, "plastic", Vector3(sx * hw * 0.62, belt0 - 0.1, zf), Basis(), Vector3(0.3, 0.12, 0.1), lamp_col)
		if e == 0:
			_box(pk, kit, "plastic", Vector3(0, belt0 - 0.12, zf), Basis(), Vector3(hw * 0.75, 0.14, 0.08), Color(0.05, 0.05, 0.05))
		_box(pk, kit, "plastic", Vector3(0, CAR_CLEAR + 0.2, zf + out_z * 0.02), Basis(Vector3.UP, (_h2(s, e, 3) - 0.5) * 0.1), Vector3(hw * 2.02, 0.16, 0.12),
				Color(0.08, 0.08, 0.08))
	# Wheels.
	var axles: Array = [-length * 0.5 + length * 0.18, length * 0.5 - length * 0.19]
	var wr := 0.31
	for a in range(2):
		for sx in [-1.0, 1.0]:
			var bit: int = (1 if sx < 0.0 else 2) << (a * 2)
			var wc := Vector3(sx * (hw - 0.13), wr, axles[a])
			if wheels & bit:
				pk.tube(kit, "rubber", wc - Vector3(0.1, 0, 0), wc + Vector3(0.1, 0, 0), wr, wr, 10, RUBBER, true)
				pk.tube(kit, "metal", wc + Vector3(sx * 0.1, 0, 0), wc + Vector3(sx * 0.125, 0, 0), wr * 0.62, wr * 0.55, 8, Color(0.55, 0.55, 0.56), true)
			else:
				pk.tube(kit, "metal", wc + Vector3(-sx * 0.05, 0, 0), wc + Vector3(sx * 0.06, 0, 0), 0.14, 0.14, 8, RUST, true)
			# The wheel arch's dark liner.
			_box(pk, kit, key, wc + Vector3(sx * 0.05, 0.1, 0), Basis(), Vector3(0.12, 0.08, 0.7), under)
	_pop(pk, sv)


## A crushed car bale round `c` (turned by `basis`) about `size`: a deformed lattice (3 x 4 x 2) whose layers are the
## colours of the cars crushed into it, worn; about 40 triangles, no bottom.
static func _bale(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, rng: RandomNumberGenerator, detail := true) -> void:
	var nx := 2
	var ny := 3
	var nz := 1
	var hs := size * 0.5
	var pts := {}
	var s: int = rng.randi()
	for i in range(nx + 1):
		for j in range(ny + 1):
			for k in range(nz + 1):
				var lp := Vector3(lerpf(-hs.x, hs.x, float(i) / nx), lerpf(-hs.y, hs.y, float(j) / ny), lerpf(-hs.z, hs.z, float(k) / nz))
				var d := _dent(lp, s, 0.06, 2.2)
				if j == 0:
					d.y = absf(d.y) * 0.3
				pts[Vector3i(i, j, k)] = c + basis * (lp + d)
	var cols: Array = []
	for j in range(ny):
		var pick: float = rng.randf()
		var cc: Color
		if pick < 0.62:
			cc = worn(CAR_PAINTS[rng.randi() % CAR_PAINTS.size()], rng.randf_range(0.18, 0.55))
		elif pick < 0.8:
			cc = worn(RUST.lerp(Color(0.3, 0.27, 0.24), rng.randf()), rng.randf_range(0.7, 1.0))
		elif pick < 0.92:
			cc = worn(Color(0.07, 0.07, 0.07), 0.3)
		else:
			cc = worn(Color(0.62, 0.63, 0.63), 0.5)
		cols.append(cc)
	var inside := c
	# Front and back (k = nz, k = 0), the sides (i = 0, i = nx), the top.
	for j in range(ny):
		for i in range(nx):
			for k in [0, nz]:
				_fquad(pk, kit, key, pts[Vector3i(i, j, k)], pts[Vector3i(i + 1, j, k)], pts[Vector3i(i + 1, j + 1, k)], pts[Vector3i(i, j + 1, k)],
						(cols[j] as Color).darkened(0.05 * float((i + j) % 2)), inside)
		for i in [0, nx]:
			_fquad(pk, kit, key, pts[Vector3i(i, j, 0)], pts[Vector3i(i, j, nz)], pts[Vector3i(i, j + 1, nz)], pts[Vector3i(i, j + 1, 0)], (cols[j] as Color).darkened(0.08), inside)
	var top_c := worn((CAR_PAINTS[rng.randi() % CAR_PAINTS.size()] as Color).lerp(Color(0.3, 0.28, 0.26), 0.4), rng.randf_range(0.4, 0.9))
	for i in range(nx):
		_fquad(pk, kit, key, pts[Vector3i(i, ny, 0)], pts[Vector3i(i + 1, ny, 0)], pts[Vector3i(i + 1, ny, nz)], pts[Vector3i(i, ny, nz)], top_c.darkened(0.06 * float(i)), inside)
	if not detail:
		return
	# Now and then a rim, a bumper or a strip of trim squashed into the front.
	var front: Vector3 = basis.z.normalized()
	var r: float = rng.randf()
	if r < 0.09:
		var p: Vector3 = c + basis * Vector3(rng.randf_range(-0.3, 0.3) * size.x, rng.randf_range(-0.2, 0.25) * size.y, hs.z + 0.02)
		pk.tube(kit, "metal", p - front * 0.06, p + front * 0.04, 0.2, 0.17, 8, Color(0.5, 0.5, 0.5), true)
	elif r < 0.3:
		var y: float = rng.randf_range(-0.25, 0.3) * size.y
		pk.beam(kit, "plastic", c + basis * Vector3(-hs.x * 0.85, y, hs.z + 0.015), c + basis * Vector3(hs.x * 0.8, y + rng.randf_range(-0.08, 0.08), hs.z + 0.015),
				0.05, 0.08, Color(0.06, 0.06, 0.06) if rng.randf() < 0.6 else Color(0.7, 0.7, 0.72), basis.y)


## A mound's height at (x, z) in its frame: a superellipse dome of height `h` over the half sizes, lumpy (`lump` of its
## height), 0 at and past the edge.
static func _mound_y(x: float, z: float, hx: float, hz: float, h: float, s: int, lump := 0.22) -> float:
	var u: float = absf(x) / hx
	var v: float = absf(z) / hz
	var r: float = pow(pow(u, 2.3) + pow(v, 2.3), 1.0 / 2.3)
	if r >= 1.0:
		return 0.0
	var dome: float = 1.0 - pow(r, 1.6)
	var n: float = (_vn(x * 0.42 + 3.0, z * 0.42 - 1.0, s) - 0.5) * 2.0 + (_vn(x * 1.25 + 9.0, z * 1.25, s + 1) - 0.5)
	return maxf(0.0, h * dome * (1.0 + lump * n * (0.35 + 0.65 * (1.0 - r))))


## A mound's surface over its half sizes on an `nx` x `nz` grid (jittered), flat shaded, its rim tucked `sink` under the
## ground; `colfn(x, z, y) -> Color` colours each triangle; UVs (x, z) in metres when `uv`.
static func _mound(pk: PropKit, kit: Dictionary, key: String, hx: float, hz: float, h: float, nx: int, nz: int, s: int, colfn: Callable, uv := false, lump := 0.22,
		sink := 0.15) -> void:
	var g := {}
	for i in range(nx + 1):
		for k in range(nz + 1):
			var x: float = lerpf(-hx, hx, float(i) / nx)
			var z: float = lerpf(-hz, hz, float(k) / nz)
			if i > 0 and i < nx and k > 0 and k < nz:
				x += (_h2(i, k, s + 5) - 0.5) * (2.0 * hx / nx) * 0.6
				z += (_h2(i, k, s + 6) - 0.5) * (2.0 * hz / nz) * 0.6
			var y: float = _mound_y(x, z, hx, hz, h, s, lump)
			if y <= 0.0:
				y = -sink
			g[Vector2i(i, k)] = Vector3(x, y, z)
	for i in range(nx):
		for k in range(nz):
			var a: Vector3 = g[Vector2i(i, k)]
			var b: Vector3 = g[Vector2i(i + 1, k)]
			var c: Vector3 = g[Vector2i(i + 1, k + 1)]
			var d: Vector3 = g[Vector2i(i, k + 1)]
			if a.y < 0.0 and b.y < 0.0 and c.y < 0.0 and d.y < 0.0:
				continue
			for tr in [[a, b, c], [a, c, d]]:
				var p0: Vector3 = tr[0]
				var p1: Vector3 = tr[1]
				var p2: Vector3 = tr[2]
				var m: Vector3 = (p0 + p1 + p2) / 3.0
				var n := (p1 - p0).cross(p2 - p0).normalized()
				if n.y < 0.0:
					n = -n
				var col: Color = colfn.call(m.x, m.z, m.y)
				if uv:
					pk.tri(kit, key, p0, p1, p2, n, n, n, col, n, Vector2(p0.x, p0.z) * uvk, Vector2(p1.x, p1.z) * uvk, Vector2(p2.x, p2.z) * uvk)
				else:
					pk.tri(kit, key, p0, p1, p2, n, n, n, col, n)


## The mound's surface normal at (x, z) (from its height function).
static func _mound_n(x: float, z: float, hx: float, hz: float, h: float, s: int) -> Vector3:
	var e := 0.4
	var dx: float = _mound_y(x + e, z, hx, hz, h, s) - _mound_y(x - e, z, hx, hz, h, s)
	var dz: float = _mound_y(x, z + e, hx, hz, h, s) - _mound_y(x, z - e, hx, hz, h, s)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## A basis whose y is `up`, turned `yaw` about it.
static func _up_basis(up: Vector3, yaw: float) -> Basis:
	var y := up.normalized()
	var x := Vector3(cos(yaw), 0.0, -sin(yaw))
	x = (x - y * x.dot(y)).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## An old tyre (tyre_wall.gdshader's UVs: x round, y across the section), 14 sides, lying flat at `c` turned by `tip`; its
## paint in `col` (black: bare rubber), `seed_v` (0..1) the shader's per-tyre draw. About 220 triangles.
static func _old_tyre(pk: PropKit, kit: Dictionary, c: Vector3, r_in: float, r_out: float, h: float, seed_v: float, tip := Basis(), col := Color(0, 0, 0)) -> void:
	var rr: float = minf(h * 0.3, (r_out - r_in) * 0.32)
	var prof: Array = [[r_in + 0.01, -h * 0.5 + 0.02, 0.0], [r_in + rr, -h * 0.5, 0.1], [r_out - rr, -h * 0.5, 0.26], [r_out, -h * 0.5 + rr, 0.34],
			[r_out + 0.004, 0.0, 0.5], [r_out, h * 0.5 - rr, 0.66], [r_out - rr, h * 0.5, 0.74], [r_in + rr, h * 0.5, 0.9], [r_in + 0.01, h * 0.5 - 0.02, 1.0],
			[r_in, 0.0, 1.05], [r_in + 0.01, -h * 0.5 + 0.02, 1.1]]
	var segs := 14
	var paint := Color(col.r, col.g, col.b, seed_v)
	for kk in range(prof.size() - 1):
		var p0: Array = prof[kk]
		var p1: Array = prof[kk + 1]
		var d := Vector2(float(p1[0]) - float(p0[0]), float(p1[1]) - float(p0[1]))
		var n2 := Vector2(d.y, -d.x).normalized()
		for j in range(segs):
			var t0 := TAU * j / segs
			var t1 := TAU * (j + 1) / segs
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var q00: Vector3 = c + tip * (u0 * float(p0[0]) + UP * float(p0[1]))
			var q01: Vector3 = c + tip * (u1 * float(p0[0]) + UP * float(p0[1]))
			var q10: Vector3 = c + tip * (u0 * float(p1[0]) + UP * float(p1[1]))
			var q11: Vector3 = c + tip * (u1 * float(p1[0]) + UP * float(p1[1]))
			var n0: Vector3 = tip * (u0 * n2.x + UP * n2.y)
			var n1: Vector3 = tip * (u1 * n2.x + UP * n2.y)
			var o: Vector3 = (n0 + n1).normalized()
			pk.tri(kit, "tyre", q00, q01, q11, n0, n1, n1, paint, o, Vector2(float(j) / segs, float(p0[2])), Vector2(float(j + 1) / segs, float(p0[2])),
					Vector2(float(j + 1) / segs, float(p1[2])))
			pk.tri(kit, "tyre", q00, q11, q10, n0, n1, n0, paint, o, Vector2(float(j) / segs, float(p0[2])), Vector2(float(j + 1) / segs, float(p1[2])),
					Vector2(float(j) / segs, float(p1[2])))


## A 200-litre drum (radius 0.29, 0.88 high) standing on `p` turned by `basis` (its axis the basis' y), two rolling hoops,
## the lid's rim; painted `col` worn by `wear`, in `key`.
static func _drum(pk: PropKit, kit: Dictionary, key: String, p: Vector3, basis: Basis, col: Color, wear: float) -> void:
	var c := worn(col, wear)
	var dk := worn(col.darkened(0.25), minf(wear + 0.1, 1.0))
	var prof: Array = [[0.001, 0.0, dk], [0.28, 0.0, dk], [0.29, 0.02, c], [0.29, 0.27, c], [0.305, 0.285, dk], [0.29, 0.3, c], [0.29, 0.58, c], [0.305, 0.595, dk],
			[0.29, 0.61, c], [0.29, 0.86, c], [0.3, 0.88, dk], [0.27, 0.885, dk], [0.26, 0.87, c], [0.001, 0.87, c]]
	_lathe_c(pk, kit, key, p, prof, 12, basis)


## A hydraulic cylinder from a (its base) to b (the rod's eye): the barrel in `key` over `share` of it, a gland, the chrome
## rod, the eyes.
static func _cyl(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, r: float, col: Color, share := 0.58) -> void:
	var d: Vector3 = b - a
	var dn: Vector3 = d.normalized()
	var m: Vector3 = a + d * share
	pk.tube(kit, key, a + dn * 0.08, m, r, r, 10, col, true)
	pk.tube(kit, key, m - dn * 0.02, m + dn * 0.07, r * 1.12, r * 1.12, 10, Color(col.r, col.g, col.b, col.a).darkened(0.2), true)
	pk.tube(kit, "chrome", m + dn * 0.07, b - dn * 0.08, r * 0.58, r * 0.58, 8, Color(0.85, 0.86, 0.87), false)
	var side := dn.cross(UP)
	if side.length_squared() < 1e-4:
		side = Vector3.RIGHT
	side = side.normalized()
	for e in [a, b]:
		pk.tube(kit, "steel", (e as Vector3) - side * r * 0.7, (e as Vector3) + side * r * 0.7, r * 0.8, r * 0.8, 8, STEEL_DARK, true)


## A crawler track at x = sx between the idler (front, zf) and the sprocket (rear, zr), radius r about the axles' height yc:
## `n` shoes `hw` half wide with grousers, the frame between the runs in `fkey`/`fcol`, bottom rollers, two carriers, the
## idler, the sprocket's teeth and the travel motor.
static func _track(pk: PropKit, kit: Dictionary, sx: float, zf: float, zr: float, yc: float, r: float, hw: float, fkey: String, fcol: Color, rollers := 7) -> void:
	var run: float = zr - zf
	var perim: float = 2.0 * run + TAU * r
	var n: int = int(round(perim / 0.26))
	var shoe := Color(0.16, 0.16, 0.15)
	var out: float = signf(sx)
	var sl: float = perim / float(n)
	for k in range(n):
		var u: float = perim * float(k) / float(n)
		var p: Vector3
		var t: Vector3
		if u < run:
			p = Vector3(sx, yc - r, zf + u)
			t = Vector3(0, 0, 1)
		elif u < run + PI * r:
			var a1: float = (u - run) / r
			p = Vector3(sx, yc - cos(a1) * r, zr + sin(a1) * r)
			t = Vector3(0, sin(a1), cos(a1))
		elif u < 2.0 * run + PI * r:
			p = Vector3(sx, yc + r, zr - (u - run - PI * r))
			t = Vector3(0, 0, -1)
		else:
			var a2: float = (u - 2.0 * run - PI * r) / r
			p = Vector3(sx, yc + cos(a2) * r, zf - sin(a2) * r)
			t = Vector3(0, -sin(a2), -cos(a2))
		var nrm: Vector3 = (p - Vector3(sx, yc, clampf(p.z, zf, zr))).normalized()
		var b := Basis(Vector3.RIGHT, nrm, t)
		var col: Color = shoe.darkened(0.06 * float(k % 3))
		pk.box(kit, "steel", Transform3D(b, p + nrm * 0.035), Vector3(hw * 2.0, 0.07, sl * 0.9), col)
		pk.box(kit, "steel", Transform3D(b, p + nrm * 0.09), Vector3(hw * 2.0 - 0.04, 0.045, 0.055), col.darkened(0.1))
	var fo := PackedVector2Array([Vector2(zf + 0.12, yc - r * 0.55), Vector2(zr - 0.12, yc - r * 0.55), Vector2(zr + r * 0.35, yc + 0.05), Vector2(zr - 0.05, yc + r * 0.72),
			Vector2(zf + 0.05, yc + r * 0.72), Vector2(zf - r * 0.35, yc + 0.05)])
	_extrude_zy(pk, kit, fkey, fo, sx - hw * 0.8, sx + hw * 0.8, 0.03, fcol)
	for k in range(rollers):
		var zz: float = lerpf(zf + r * 0.7, zr - r * 0.7, float(k) / float(maxi(rollers - 1, 1)))
		_rod(pk, kit, "metal", Vector3(sx - hw * 0.75, yc - r + 0.19, zz), Vector3(sx + hw * 0.75, yc - r + 0.19, zz), 0.12, 10, Color(0.24, 0.24, 0.23), true)
	for zz in [lerpf(zf, zr, 0.3), lerpf(zf, zr, 0.7)]:
		_rod(pk, kit, "metal", Vector3(sx - hw * 0.4, yc + r - 0.16, zz), Vector3(sx + hw * 0.4, yc + r - 0.16, zz), 0.1, 10, Color(0.24, 0.24, 0.23), true)
	for wz in [zf, zr]:
		_rod(pk, kit, "steel", Vector3(sx - hw * 0.7, yc, wz), Vector3(sx + hw * 0.7, yc, wz), r - 0.08, 16, Color(0.2, 0.2, 0.2), true)
		_rod(pk, kit, "metal", Vector3(sx + out * hw * 0.7, yc, wz), Vector3(sx + out * (hw * 0.7 + 0.07), yc, wz), r * 0.4, 10, Color(0.3, 0.3, 0.29), true)
	for kt in range(13):
		var at: float = TAU * float(kt) / 13.0
		var tp := Vector3(sx - out * 0.02, yc + sin(at) * (r - 0.05), zr + cos(at) * (r - 0.05))
		pk.box(kit, "metal", Transform3D(Basis(Vector3.RIGHT, -at), tp), Vector3(hw * 0.5, 0.1, 0.11), Color(0.32, 0.31, 0.29))
	_rod(pk, kit, fkey, Vector3(sx - out * hw * 0.8, yc + 0.02, zr - 0.05), Vector3(sx - out * (hw * 0.8 + 0.35), yc + 0.02, zr - 0.05), r * 0.5, 12, fcol.lightened(0.05), true)


## A lattice boom from a to b: four tube chords (radius rc) at the corners of a section `w` x `h` (h along `up` squared to
## the axis) that varies by `prof` ([t, w, h] from 0 at a to 1 at b), laced (radius rl) on all four faces in panels about
## `panel` long, a ring of struts at every panel point, the diagonals zigzagging; splice plates every `splice` panels.
static func _boom(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, up: Vector3, prof: Array, panel: float, rc: float, rl: float, col: Color,
		splice := 4) -> void:
	var ax := b - a
	var length := ax.length()
	if length < 0.1:
		return
	var z := ax / length
	var u := (up - z * up.dot(z)).normalized()
	var sv := z.cross(u).normalized()
	var n: int = maxi(int(round(length / panel)), 2)
	var corners: Array = []
	for k in range(n + 1):
		var t: float = float(k) / float(n)
		var wh := _prof_at(prof, t)
		var p: Vector3 = a + ax * t
		var ring: Array = []
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			ring.append(p + sv * (wh.x * 0.5 * c.x) + u * (wh.y * 0.5 * c.y))
		corners.append(ring)
	for k in range(n):
		var r0: Array = corners[k]
		var r1: Array = corners[k + 1]
		for c in range(4):
			pk.tube(kit, key, r0[c], r1[c], rc, rc, 7, col, false)
			var c1 := (c + 1) % 4
			pk.tube(kit, key, r0[c], r0[c1], rl, rl, 5, col, false)
			if (k + c) % 2 == 0:
				pk.tube(kit, key, r0[c], r1[c1], rl, rl, 5, col, false)
			else:
				pk.tube(kit, key, r0[c1], r1[c], rl, rl, 5, col, false)
		if k > 0 and k % splice == 0:
			for c in range(4):
				var pc: Vector3 = r0[c]
				pk.box(kit, key, Transform3D(Basis(sv, u, z), pc), Vector3(rc * 3.2, rc * 3.2, 0.16), col.darkened(0.15))
	var rl0: Array = corners[n]
	for c in range(4):
		pk.tube(kit, key, rl0[c], rl0[(c + 1) % 4], rl, rl, 5, col, false)


static func _prof_at(prof: Array, t: float) -> Vector2:
	for i in range(prof.size() - 1):
		var p0: Array = prof[i]
		var p1: Array = prof[i + 1]
		if t <= float(p1[0]) or i == prof.size() - 2:
			var f: float = clampf((t - float(p0[0])) / maxf(float(p1[0]) - float(p0[0]), 1e-5), 0.0, 1.0)
			return Vector2(lerpf(float(p0[1]), float(p1[1]), f), lerpf(float(p0[2]), float(p1[2]), f))
	return Vector2(1, 1)


## A quad of room finish ("room") in a vertical plane: corners in order round it, facing `n`, UVs (u along `along`, v the
## height) in metres.
static func _rq(pk: PropKit, kit: Dictionary, pts: Array, n: Vector3, col: Color, along: Vector3) -> void:
	var uv: Array = []
	for p in pts:
		uv.append(Vector2((p as Vector3).dot(along), (p as Vector3).y) * uvk)
	pk.quad(kit, "room", pts, n, col, uv)


## A level rectangle of room finish (a floor facing up, a ceiling down), UVs (x, z) in metres.
static func _rh(pk: PropKit, kit: Dictionary, x0: float, x1: float, z0: float, z1: float, y: float, up: bool, col: Color) -> void:
	var pts: Array = [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	var uv: Array = [Vector2(x0, z0) * uvk, Vector2(x1, z0) * uvk, Vector2(x1, z1) * uvk, Vector2(x0, z1) * uvk]
	pk.quad(kit, "room", pts, UP if up else Vector3.DOWN, col, uv)


## A box of room finish between two corners (each face its own finish: -x, +x, -y, +y, -z, +z; null skips a face).
static func _rbox(pk: PropKit, kit: Dictionary, lo: Vector3, hi: Vector3, cols: Array) -> void:
	var x0 := lo.x
	var y0 := lo.y
	var z0 := lo.z
	var x1 := hi.x
	var y1 := hi.y
	var z1 := hi.z
	if cols[0] != null:
		_rq(pk, kit, [Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1)], Vector3.LEFT, cols[0], Vector3.FORWARD)
	if cols[1] != null:
		_rq(pk, kit, [Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, cols[1], Vector3.BACK)
	if cols[2] != null:
		_rh(pk, kit, x0, x1, z0, z1, y0, false, cols[2])
	if cols[3] != null:
		_rh(pk, kit, x0, x1, z0, z1, y1, true, cols[3])
	if cols[4] != null:
		_rq(pk, kit, [Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0)], Vector3.FORWARD, cols[4], Vector3.LEFT)
	if cols[5] != null:
		_rq(pk, kit, [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.BACK, cols[5], Vector3.RIGHT)


# ======================================================================================
#  The crawler crane and its wrecking ball (the demolition site)
# ======================================================================================

## Where the hoist line leaves the boom's head sheave (its front, toward -z): WreckingBall.gd's node hangs here and the ball's
## mesh (wrecking_ball) hangs down its -y from it. The crane is built with its boom toward -z.
const CRANE_TIP := Vector3(0, 32.0, -18.55)
const CRANE_HEAD := Vector3(0, 32.0, -18.0)
const CRANE_SHEAVE_R := 0.55
## The boom's foot pins.
const CRANE_FOOT := Vector3(0, 2.75, -1.55)
## Half the crane's footprint in plan (x across the tracks, z from the idlers to the counterweight's tail).
const CRANE_FOOT_HALF := Vector2(3.0, 5.6)
const CRANE_TRACK_X := 2.15
const CRANE_RING_Y := 1.75
## The ball: its radius, and twice the height from its centre up to where the chain's shackle meets its eye.
const BALL_R := 0.95
const BALL_H := 2.6
const KORVALD_RED := Color(0.68, 0.11, 0.07)
const UNDERCARRIAGE := Color(0.13, 0.13, 0.13)
## The bridle the pendants pull on, and the gantry's top (the boom hoist's sheaves).
const CRANE_BRIDLE := Vector3(0, 8.9, 0.75)
const CRANE_GANTRY := Vector3(0, 7.75, 2.9)


## The wrecking ball on its hoist line, hanging from the origin (the boom's head sheave, CRANE_TIP) down -y: the wire rope
## `chain_life - 3.0` long to a wedge socket, a swivel, a chain of heavy links, a shackle through the ball's eye and the
## pear-shaped ball, its centre `chain_life + BALL_H / 2` under the origin. Moving: "scrapm" and vertex colours only.
static func wrecking_ball(pk: PropKit, kit: Dictionary, chain_life: float) -> void:
	var cl: float = maxf(chain_life, 4.0)
	var steel := worn(Color(0.17, 0.17, 0.17), 0.45)
	var ys: float = -(cl - 3.0)
	# The wire rope and its wedge socket (a tapered body, two plates and the pin).
	_rod(pk, kit, "steel", Vector3.ZERO, Vector3(0, ys + 0.38, 0), 0.028, 6, Color(0.14, 0.14, 0.13), false)
	pk.tube(kit, "scrapm", Vector3(0, ys + 0.42, 0), Vector3(0, ys + 0.08, 0), 0.045, 0.1, 8, steel, true)
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "scrapm", Vector3(sx * 0.07, ys - 0.02, 0), Basis(), Vector3(0.035, 0.22, 0.17), steel)
	_rod(pk, kit, "metal", Vector3(-0.11, ys - 0.07, 0), Vector3(0.11, ys - 0.07, 0), 0.035, 8, Color(0.4, 0.4, 0.4), true)
	# The swivel.
	_lathe_c(pk, kit, "scrapm", Vector3(0, ys - 0.5, 0), [[0.05, 0.0, steel], [0.1, 0.02, steel], [0.12, 0.12, steel], [0.12, 0.24, steel], [0.08, 0.3, steel],
			[0.05, 0.36, steel], [0.05, 0.42, steel], [0.001, 0.43, steel]], 10)
	_link(pk, kit, "scrapm", Vector3(0, ys - 0.2, 0), UP, Vector3.FORWARD, 0.12, 0.07, 0.025, steel)
	# The chain, from the swivel's eye to the shackle.
	var chain_top := Vector3(0, ys - 0.56, 0)
	var chain_end := Vector3(0, -(cl - 0.22), 0)
	_chain(pk, kit, "scrapm", chain_top, chain_end, 0.17, 0.034, worn(Color(0.2, 0.19, 0.18), 0.7), Vector3.RIGHT)
	# The ball, its eye and the shackle (the bow through the chain's last link, the pin through the eye).
	var yc: float = -(cl + BALL_H * 0.5)
	var bc := worn(Color(0.13, 0.13, 0.13), 0.4)
	var r := BALL_R
	_lathe_c(pk, kit, "scrapm", Vector3(0, yc, 0), [[0.001, -r, bc], [r * 0.36, -r * 0.94, bc], [r * 0.63, -r * 0.77, bc], [r * 0.84, -r * 0.54, bc],
			[r * 0.97, -r * 0.26, bc], [r, 0.0, bc], [r * 0.97, r * 0.25, bc], [r * 0.86, r * 0.5, bc], [r * 0.67, r * 0.72, bc], [r * 0.45, r * 0.9, bc],
			[0.27, r * 1.0, bc], [0.22, r * 1.06, bc], [0.25, r * 1.08, bc], [0.25, r * 1.13, bc], [0.001, r * 1.14, bc]], 20)
	_box(pk, kit, "scrapm", Vector3(0, yc + 1.16, 0), Basis(), Vector3(0.12, 0.34, 0.36), bc)
	_rod(pk, kit, "metal", Vector3(-0.155, yc + 1.18, 0), Vector3(0.155, yc + 1.18, 0), 0.04, 8, Color(0.36, 0.36, 0.35), true)
	var bow: Array = [Vector3(-0.1, yc + 1.18, 0)]
	for k in range(7):
		var a: float = PI - PI * float(k) / 6.0
		bow.append(Vector3(cos(a) * 0.1, yc + 1.38 + sin(a) * 0.1, 0))
	bow.append(Vector3(0.1, yc + 1.18, 0))
	_rods(pk, kit, "scrapm", bow, 0.032, 6, steel)


## A lattice-boom crawler crane rigged for demolition (KORVALD's, Abbruch Brandt's), its boom toward -z: two crawlers (track
## middles at x ±CRANE_TRACK_X, 7.5m long), the carbody and slewing ring, the upper (the revolving frame, the machinery
## house, the cab front left with its demolition guard, the counterweight's slabs behind to z 5.45), the gantry, the bridle
## and pendants, the 34m lattice boom from CRANE_FOOT to its head sheaves round CRANE_HEAD, the main hoist rope over it
## (the ball's own rope hangs from CRANE_TIP: wrecking_ball). The maker's and the firm's names in labels.
static func crawler_crane(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var red := worn(KORVALD_RED, 0.06)
	var dark := worn(UNDERCARRIAGE, 0.07)
	# The crawlers and the carbody.
	for sx in [-1.0, 1.0]:
		_track(pk, kit, sx * CRANE_TRACK_X, -3.15, 3.15, 0.66, 0.58, 0.45, "scrap", dark, 9)
		_lbl(labels, "KORVALD", Vector3(sx * (CRANE_TRACK_X + 0.4), 0.72, 0.0), Vector3(sx, 0, 0), 0.2, Color(0.95, 0.95, 0.92), 2.4)
	_extrude_zy(pk, kit, "scrap", PackedVector2Array([Vector2(-1.5, 0.55), Vector2(1.5, 0.55), Vector2(1.5, 1.45), Vector2(-1.5, 1.45)]), -1.75, 1.75, 0.06, dark)
	_lathe_c(pk, kit, "steel", Vector3(0, 1.45, 0), [[1.1, 0.0, Color(0.2, 0.2, 0.2)], [1.4, 0.0, Color(0.2, 0.2, 0.2)], [1.4, 0.15, Color(0.24, 0.24, 0.24)],
			[1.5, 0.16, Color(0.18, 0.18, 0.18)], [1.5, CRANE_RING_Y - 1.45 + 0.1, Color(0.18, 0.18, 0.18)], [1.2, CRANE_RING_Y - 1.45 + 0.1, Color(0.18, 0.18, 0.18)]], 28)
	# The revolving frame and the boom's foot brackets.
	var fy0 := CRANE_RING_Y + 0.1
	var fy1 := fy0 + 0.5
	_blk(pk, kit, "scrap", Vector3(-1.6, fy0, -2.3), Vector3(1.6, fy1, 3.4), worn(Color(0.2, 0.2, 0.2), 0.08))
	for sx in [-1.0, 1.0]:
		var bo := PackedVector2Array([Vector2(-2.25, fy1 - 0.02), Vector2(-0.6, fy1 - 0.02), Vector2(-0.95, CRANE_FOOT.y + 0.45), Vector2(-1.55, CRANE_FOOT.y + 0.55),
				Vector2(-2.1, CRANE_FOOT.y + 0.3)])
		for inner in [0.6, 0.86]:
			_extrude_zy(pk, kit, "scrap", bo, sx * inner - 0.05, sx * inner + 0.05, 0.0, red.darkened(0.1))
	_rod(pk, kit, "metal", Vector3(-0.98, CRANE_FOOT.y, CRANE_FOOT.z), Vector3(0.98, CRANE_FOOT.y, CRANE_FOOT.z), 0.09, 10, Color(0.4, 0.4, 0.4), true)
	_crane_house(pk, kit, labels, red, fy1)
	_crane_cab(pk, kit, red, fy1)
	_crane_counterweight(pk, kit, labels, fy0)
	_crane_gantry(pk, kit, red, fy1)
	_crane_boom(pk, kit, labels, red)


static func _crane_house(pk: PropKit, kit: Dictionary, labels: Array, red: Color, y0: float) -> void:
	var y1 := 4.6
	_blk(pk, kit, "scrap", Vector3(-1.1, y0, -0.6), Vector3(2.4, y1, 3.35), red)
	# The roof's rim, the panel joints and doors on the sides, the louvres at the rear right, a vent hood over the engine.
	_blk(pk, kit, "scrap", Vector3(-1.13, y1 - 0.02, -0.63), Vector3(2.43, y1 + 0.06, 3.38), worn(Color(0.16, 0.16, 0.16), 0.08))
	for sx in [-1.1, 2.4]:
		var o: float = 0.012 * signf(sx - 0.65)
		for z in [0.35, 1.25, 2.15]:
			_box(pk, kit, "scrap", Vector3(sx + o, (y0 + y1) * 0.5, z), Basis(), Vector3(0.02, y1 - y0 - 0.3, 0.025), red.darkened(0.35))
		_box(pk, kit, "scrap", Vector3(sx + o * 2.0, y0 + 1.1, 0.8), Basis(), Vector3(0.03, 0.04, 0.22), Color(0.1, 0.1, 0.1))
	for k in range(7):
		var y: float = y0 + 0.5 + 0.22 * float(k)
		_box(pk, kit, "scrap", Vector3(2.42, y, 2.85), Basis(Vector3.BACK, 0.35), Vector3(0.05, 0.03, 0.75), worn(Color(0.1, 0.1, 0.1), 0.3))
	_blk(pk, kit, "scrap", Vector3(0.3, y1 + 0.06, 1.6), Vector3(1.9, y1 + 0.35, 3.0), red.darkened(0.08))
	# The exhaust and its rain cap, the beacon, handrails round the roof.
	pk.tube(kit, "steel", Vector3(1.75, y1 + 0.3, 2.75), Vector3(1.75, y1 + 1.15, 2.75), 0.09, 0.09, 10, Color(0.15, 0.15, 0.15), false)
	_box(pk, kit, "steel", Vector3(1.75, y1 + 1.18, 2.72), Basis(Vector3.RIGHT, 0.35), Vector3(0.22, 0.02, 0.24), Color(0.15, 0.15, 0.15))
	pk.lathe(kit, "lens", Vector3(-0.6, y1 + 0.06, 2.9), [Vector2(0.001, 0.0), Vector2(0.09, 0.0), Vector2(0.085, 0.16), Vector2(0.001, 0.19)], 10, Color(1.0, 0.6, 0.08))
	SW._railing(pk, kit, [Vector3(2.3, y1 + 0.06, -0.5), Vector3(2.3, y1 + 0.06, 3.25), Vector3(-1.0, y1 + 0.06, 3.25)], 0.9, Color(0.92, 0.75, 0.1), "paint")
	# A walkway along the right side over the track.
	_blk(pk, kit, "steel", Vector3(2.42, y0 - 0.06, -0.4), Vector3(2.95, y0, 3.2), Color(0.25, 0.25, 0.25))
	SW._railing(pk, kit, [Vector3(2.9, y0, -0.3), Vector3(2.9, y0, 3.1)], 1.0, Color(0.92, 0.75, 0.1), "paint")
	for sx in [-1.0, 1.0]:
		var x: float = -1.1 - 0.035 if sx < 0.0 else 2.4 + 0.035
		_lbl(labels, "ABBRUCH BRANDT", Vector3(x, 3.75, 1.7 if sx < 0.0 else 1.1), Vector3(sx, 0, 0), 0.34, Color(0.97, 0.96, 0.92), 3.0)
		_lbl(labels, "KRONBURG", Vector3(x, 3.25, 1.7 if sx < 0.0 else 1.1), Vector3(sx, 0, 0), 0.2, Color(0.97, 0.96, 0.92), 2.0)


## The cab front left: a shell with a raked windscreen, glass all round, the demolition guard (a grid of bars in front of
## the windscreen and over the roof), the door, mirror, wipers, work lights.
static func _crane_cab(pk: PropKit, kit: Dictionary, red: Color, y0: float) -> void:
	var x0 := -2.55
	var x1 := -1.2
	var cy0: float = y0 - 0.35
	var ol := PackedVector2Array([Vector2(-0.35, cy0), Vector2(-2.35, cy0), Vector2(-2.6, cy0 + 0.45), Vector2(-2.45, 4.2), Vector2(-2.3, 4.35), Vector2(-0.35, 4.35)])
	_extrude_zy(pk, kit, "scrap", ol, x0, x1, 0.04, worn(Color(0.86, 0.85, 0.82), 0.05))
	_blk(pk, kit, "scrap", Vector3(x0 - 0.03, 4.33, -2.48), Vector3(x1 + 0.03, 4.42, -0.3), red)
	_blk(pk, kit, "scrap", Vector3(x0 + 0.1, cy0 - 0.15, -2.2), Vector3(-1.6, cy0, -0.5), worn(Color(0.2, 0.2, 0.2), 0.08))
	# The windscreen on the raked face.
	var a := Vector3(0, cy0 + 0.45, -2.6)
	var b := Vector3(0, 4.2, -2.45)
	var along: Vector3 = (b - a).normalized()
	var n := Vector3(0, -along.z, along.y)
	if n.z > 0.0:
		n = -n
	var mid: Vector3 = a.lerp(b, 0.52)
	_box(pk, kit, "glassdark", Vector3((x0 + x1) * 0.5, mid.y, mid.z) + n * 0.02, Basis(Vector3.RIGHT, along, n), Vector3(1.15, 1.85, 0.02), GLASS)
	# The side glass (the door on the left), the rear window.
	_box(pk, kit, "glassdark", Vector3(x0 - 0.02, 3.35, -1.65), Basis(), Vector3(0.02, 1.4, 1.2), GLASS)
	_box(pk, kit, "glassdark", Vector3(x0 - 0.02, 3.5, -0.75), Basis(), Vector3(0.02, 1.1, 0.5), GLASS)
	_box(pk, kit, "glassdark", Vector3(x1 + 0.02, 3.45, -1.7), Basis(), Vector3(0.02, 1.2, 1.1), GLASS)
	_box(pk, kit, "glassdark", Vector3((x0 + x1) * 0.5, 3.6, -0.33), Basis(), Vector3(1.0, 0.9, 0.02), GLASS)
	_box(pk, kit, "scrap", Vector3(x0 - 0.05, 2.8, -1.15), Basis(), Vector3(0.03, 0.04, 0.2), Color(0.1, 0.1, 0.1, 0.2))
	# The demolition guard: a frame in front of the windscreen (on brackets off the roof and the floor) and over the roof.
	var gw := 0.16
	var g0: Vector3 = a + n * gw
	var g1: Vector3 = b + n * gw
	for k in range(6):
		var x: float = lerpf(x0 + 0.05, x1 - 0.05, float(k) / 5.0)
		pk.beam(kit, "steel", Vector3(x, g0.y, g0.z), Vector3(x, g1.y + 0.05, g1.z), 0.05, 0.05, Color(0.15, 0.15, 0.15), Vector3.RIGHT)
	for t in [0.0, 0.33, 0.66, 1.0]:
		var p: Vector3 = g0.lerp(g1, t) + n * 0.045
		pk.beam(kit, "steel", Vector3(x0, p.y, p.z), Vector3(x1, p.y, p.z), 0.06, 0.06, Color(0.15, 0.15, 0.15), n)
	for k in range(5):
		var x2: float = lerpf(x0 + 0.05, x1 - 0.05, float(k) / 4.0)
		pk.beam(kit, "steel", Vector3(x2, 4.5, g1.z), Vector3(x2, 4.5, -0.4), 0.05, 0.05, Color(0.15, 0.15, 0.15), Vector3.RIGHT)
	for z in [g1.z, -1.4, -0.4]:
		pk.beam(kit, "steel", Vector3(x0, 4.46, z), Vector3(x1, 4.46, z), 0.07, 0.07, Color(0.15, 0.15, 0.15))
	for x3 in [x0 + 0.04, x1 - 0.04]:
		pk.beam(kit, "steel", Vector3(x3, 4.42, -0.4), Vector3(x3, 4.53, -0.4), 0.06, 0.06, Color(0.15, 0.15, 0.15))
	# Wipers, the mirror, a work light on the guard.
	for x4 in [x0 + 0.35, x1 - 0.4]:
		pk.beam(kit, "steel", a.lerp(b, 0.1) + n * 0.035 + Vector3(x4, 0, 0), a.lerp(b, 0.62) + n * 0.035 + Vector3(x4 + 0.2, 0, 0), 0.025, 0.012, BLACK)
	pk.beam(kit, "steel", Vector3(x0, 3.9, -2.3), Vector3(x0 - 0.35, 4.05, -2.45), 0.03, 0.03, BLACK)
	_box(pk, kit, "plastic", Vector3(x0 - 0.42, 3.9, -2.47), Basis(Vector3.UP, 0.4), Vector3(0.2, 0.3, 0.04), BLACK)
	_box(pk, kit, "scrap", Vector3((x0 + x1) * 0.5, 4.62, -2.3), Basis(), Vector3(0.3, 0.16, 0.14), Color(0.12, 0.12, 0.12, 0.2))
	_box(pk, kit, "lens", Vector3((x0 + x1) * 0.5, 4.62, -2.38), Basis(), Vector3(0.24, 0.12, 0.02), Color(0.9, 0.9, 0.85))


## The counterweight behind the house: four slabs with chamfered tails, its lifting lugs, hazard boards at the rear corners.
static func _crane_counterweight(pk: PropKit, kit: Dictionary, labels: Array, y0: float) -> void:
	var col := worn(Color(0.14, 0.14, 0.14), 0.08)
	var ys: Array = [y0, y0 + 0.62, y0 + 1.24, y0 + 1.86]
	for k in range(4):
		var ya: float = float(ys[k]) + (0.0 if k == 0 else 0.015)
		var yb: float = float(ys[k]) + 0.61
		var ol := PackedVector2Array([Vector2(-2.35, 3.35), Vector2(2.35, 3.35), Vector2(2.35, 4.95), Vector2(1.85, 5.45), Vector2(-1.85, 5.45), Vector2(-2.35, 4.95)])
		_extrude_plan(pk, kit, "scrap", ol, ya, yb, 0.03, col.darkened(0.05 * float(k % 2)))
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "steel", Vector3(sx * 1.5, ys[3] + 0.7, 4.4), Basis(), Vector3(0.08, 0.2, 0.4), Color(0.2, 0.2, 0.2))
		var hb := Basis(Vector3.UP, sx * PI * 0.25)
		_box(pk, kit, "hazard", Vector3(sx * 2.1, y0 + 1.25, 5.2) + Vector3(sx, 0, 1).normalized() * 0.03, hb, Vector3(0.62, 1.9, 0.02), WHITE)
		_lbl(labels, "KORVALD", Vector3(sx * 2.385, y0 + 1.55, 4.3), Vector3(sx, 0, 0), 0.5, Color(0.96, 0.95, 0.9), 1.8)
	_lbl(labels, "KORVALD", Vector3(0, y0 + 1.55, 5.485), Vector3(0, 0, 1), 0.5, Color(0.96, 0.95, 0.9), 3.4)


## The gantry (an A-frame over the house's rear) with the boom hoist's sheaves, the bridle and its reeving, the pendants up
## to the boom's head.
static func _crane_gantry(pk: PropKit, kit: Dictionary, red: Color, y0: float) -> void:
	var top := CRANE_GANTRY
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "scrap", Vector3(sx * 1.2, 4.6, 3.2), Vector3(sx * 0.62, top.y - 0.1, top.z + 0.05), 0.2, 0.2, red)
		pk.beam(kit, "scrap", Vector3(sx * 1.2, 4.6, 0.8), Vector3(sx * 0.62, top.y - 0.1, top.z - 0.05), 0.16, 0.16, red)
		_blk(pk, kit, "scrap", Vector3(sx * 1.2 - 0.18, 4.6, 0.6), Vector3(sx * 1.2 + 0.18, 4.75, 3.4), red.darkened(0.15))
	pk.beam(kit, "scrap", Vector3(-0.8, top.y, top.z), Vector3(0.8, top.y, top.z), 0.3, 0.3, red.darkened(0.1))
	for k in range(4):
		var x: float = -0.3 + 0.2 * float(k)
		_rod(pk, kit, "steel", Vector3(x - 0.04, top.y + 0.32, top.z), Vector3(x + 0.04, top.y + 0.32, top.z), 0.28, 12, Color(0.22, 0.22, 0.22), true)
	var br := CRANE_BRIDLE
	pk.beam(kit, "scrap", br + Vector3(-0.7, 0, 0), br + Vector3(0.7, 0, 0), 0.22, 0.26, red.darkened(0.1))
	for k in range(4):
		var x2: float = -0.3 + 0.2 * float(k)
		_rod(pk, kit, "steel", br + Vector3(x2 - 0.04, -0.02, 0.15), br + Vector3(x2 + 0.04, -0.02, 0.15), 0.24, 12, Color(0.22, 0.22, 0.22), true)
	# The reeving: ropes from the gantry's sheaves to the bridle's.
	for k in range(8):
		var x3: float = -0.33 + 0.66 * float(k) / 7.0
		var up_side: bool = k % 2 == 0
		_rod(pk, kit, "steel", Vector3(x3, top.y + (0.58 if up_side else 0.06), top.z), br + Vector3(x3, 0.22 if up_side else -0.24, 0.15), 0.016, 4,
				Color(0.12, 0.12, 0.12), false)
	# The pendants: flat straps from the bridle's ends to the head's lugs.
	var lug := _crane_head_lug()
	for sx in [-1.0, 1.0]:
		var a := br + Vector3(sx * 0.62, 0.0, -0.05)
		var b := lug + Vector3(sx * 0.52, 0, 0)
		pk.beam(kit, "steel", a, b, 0.09, 0.035, Color(0.2, 0.2, 0.2), Vector3.RIGHT)
		var mid: Vector3 = a.lerp(b, 0.5)
		_box(pk, kit, "steel", mid, Basis(Vector3.RIGHT, (b - a).normalized(), Vector3.RIGHT.cross((b - a).normalized())), Vector3(0.14, 0.3, 0.06), Color(0.22, 0.22, 0.22))


## Where the pendants pin onto the boom's head (its top, behind the sheave).
static func _crane_head_lug() -> Vector3:
	var d: Vector3 = (CRANE_HEAD - CRANE_FOOT).normalized()
	var u: Vector3 = (UP - d * UP.dot(d)).normalized()
	return CRANE_HEAD + u * 0.95 - d * 0.35


## The lattice boom (tube chords and lacing, 1.8m square in the middle, narrowing to its foot pins and its head), KORVALD's
## boards on its sides, the head (side plates, the sheave the hoist line leaves from, the guide rollers, a red light), the
## main hoist rope from the house over the boom to the head, a work light at the foot.
static func _crane_boom(pk: PropKit, kit: Dictionary, labels: Array, red: Color) -> void:
	var f := CRANE_FOOT
	var h := CRANE_HEAD
	var d: Vector3 = (h - f).normalized()
	var u: Vector3 = (UP - d * UP.dot(d)).normalized()
	var length: float = f.distance_to(h)
	var a: Vector3 = f + d * 0.15
	var e: Vector3 = h - d * 1.35
	var prof: Array = [[0.0, 1.5, 0.75], [0.07, 1.8, 1.7], [0.9, 1.8, 1.7], [1.0, 1.15, 1.05]]
	_boom(pk, kit, "scrap", a, e, u, prof, 1.55, 0.075, 0.034, red, 4)
	# The foot: lugs round the pin.
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "scrap", f + Vector3(sx * 0.745, 0, 0) + d * 0.2, Basis(Vector3.RIGHT, d, Vector3.RIGHT.cross(d)), Vector3(0.12, 0.6, 0.5), red.darkened(0.1))
	# The head: side plates (a profile in the boom's plane) round the sheave, the sheave and its pin, a guide roller.
	var ol := PackedVector2Array()
	for p in [e - u * 0.55, e + u * 0.55, _crane_head_lug() + d * 0.1, h + d * 0.62 + u * 0.15, h + d * 0.35 - u * 0.62, h - d * 0.55 - u * 0.75]:
		ol.append(Vector2((p as Vector3).z, (p as Vector3).y))
	for sx in [-1.0, 1.0]:
		_extrude_zy(pk, kit, "scrap", ol, sx * 0.44 - 0.03, sx * 0.44 + 0.03, 0.0, red.darkened(0.08))
		pk.beam(kit, "scrap", e + u * 0.55 + Vector3(sx * 0.44, 0, 0), e + u * 0.85 + Vector3(sx * 0.9, 0, 0) - d * 0.25, 0.08, 0.08, red)
	_rod(pk, kit, "steel", h - Vector3(0.11, 0, 0), h + Vector3(0.11, 0, 0), CRANE_SHEAVE_R, 18, Color(0.24, 0.24, 0.24), true)
	_rod(pk, kit, "metal", h - Vector3(0.5, 0, 0), h + Vector3(0.5, 0, 0), 0.07, 8, Color(0.45, 0.45, 0.45), true)
	var gr: Vector3 = h - d * 0.9 + u * 0.15
	_rod(pk, kit, "steel", gr - Vector3(0.3, 0, 0), gr + Vector3(0.3, 0, 0), 0.12, 10, Color(0.25, 0.25, 0.25), true)
	pk.lathe(kit, "lens", h + d * 0.55 + u * 0.25, [Vector2(0.001, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.1), Vector2(0.001, 0.13)], 8, Color(0.9, 0.1, 0.06))
	# KORVALD's boards on the boom's sides, its name on them.
	var t0: float = 0.22
	var bc: Vector3 = f + d * (length * t0 + 2.6)
	var wh := _prof_at(prof, t0 + 0.08)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (wh.x * 0.5 + 0.1)
		_box(pk, kit, "scrap", Vector3(x, bc.y, bc.z), Basis(Vector3.RIGHT, u, -d), Vector3(0.04, 0.85, 5.2), worn(Color(0.9, 0.89, 0.85), 0.06))
		for k in range(3):
			var pz: Vector3 = bc + d * (-2.0 + 2.0 * float(k))
			pk.beam(kit, "steel", Vector3(sx * wh.x * 0.5, pz.y, pz.z), Vector3(x, pz.y, pz.z), 0.05, 0.05, Color(0.2, 0.2, 0.2))
		# The name along the board (a label can't lean with the boom): up the boom on the +x side, down it on the -x side.
		_pixel_text(pk, kit, "paint", Vector3(x + sx * 0.045, bc.y, bc.z), d * sx, u, 0.125, "KORVALD", KORVALD_RED)
	# The main hoist rope: from the house over a guide sheave on the boom's foot to the head sheave's top.
	var g0: Vector3 = f + d * 2.2 + u * 1.05
	_rod(pk, kit, "steel", g0 - Vector3(0.12, 0, 0), g0 + Vector3(0.12, 0, 0), 0.22, 10, Color(0.24, 0.24, 0.24), true)
	_rod(pk, kit, "steel", Vector3(0, 4.0, -0.62), g0 + u * 0.22, 0.022, 5, Color(0.13, 0.13, 0.12), false)
	_rod(pk, kit, "steel", g0 + u * 0.22, h + Vector3(0, CRANE_SHEAVE_R, 0), 0.022, 5, Color(0.13, 0.13, 0.12), false)
	# A work light on the boom's foot, aimed down the line.
	var wl: Vector3 = f + d * 3.4 - u * 0.95
	_box(pk, kit, "scrap", wl, Basis(), Vector3(0.3, 0.22, 0.16), worn(Color(0.15, 0.15, 0.15), 0.2))
	_box(pk, kit, "lens", wl + Vector3(0, 0, -0.09), Basis(), Vector3(0.24, 0.16, 0.02), Color(0.92, 0.92, 0.86))


static func crawler_crane_solids() -> Array:
	var s: Array = []
	for sx in [-1.0, 1.0]:
		s.append(_solid_lh(Vector3(sx * CRANE_TRACK_X - 0.5, 0.0, -3.8), Vector3(sx * CRANE_TRACK_X + 0.5, 1.3, 3.8)))
	s.append(_solid_lh(Vector3(-1.65, 0.5, -1.5), Vector3(1.65, CRANE_RING_Y, 1.5)))
	s.append(_solid_lh(Vector3(-2.6, CRANE_RING_Y, -2.65), Vector3(2.45, 4.6, 3.35)))
	s.append(_solid_lh(Vector3(-2.35, CRANE_RING_Y + 0.1, 3.35), Vector3(2.35, CRANE_RING_Y + 2.55, 5.45)))
	return s


# ======================================================================================
#  The office block being knocked down (the Kronburger Bausparkasse's, 1960s)
# ======================================================================================

## Ten 3.8m bays (x from -19 to 19), 15m deep (the front at z 0 toward +z, the back at z -15), storeys of RUIN_STOREY from
## RUIN_Y0, slabs RUIN_SLAB thick. A front room to the corridor's walls at z -6.0 and -8.2, back rooms behind.
const RUIN_BAY := 3.8
const RUIN_BAYS := 10
const RUIN_HALF := 19.0
const RUIN_DEPTH := 15.0
const RUIN_Y0 := 0.45
const RUIN_STOREY := 3.5
const RUIN_SLAB := 0.3
const RUIN_CORR0 := 6.0
const RUIN_CORR1 := 8.2
const RUIN_WALL := 0.12
const RUIN_SILL := 1.0
const RUIN_MOSAIC := Color(0.33, 0.5, 0.56)
const RUIN_WASCH := Color(0.72, 0.68, 0.6)
const RUIN_CONC := Color(0.63, 0.62, 0.59)
const RUIN_ALU := Color(0.6, 0.61, 0.6)
## Rubble's tints: crushed concrete, brick dust, plaster, earth.
const RUBBLE_TINTS := [Color(0.5, 0.49, 0.46), Color(0.44, 0.42, 0.39), Color(0.55, 0.42, 0.34), Color(0.6, 0.57, 0.5), Color(0.38, 0.34, 0.29)]
## The bite the ball has taken out of the first floor's slab edge over the smashed ground floor (bays 4 and 5).
const RUIN_NOTCH := Vector2(-1.7, 1.7)
## The papers and paints of the rooms laid open ([finish, tint]) and their floors.
const RUIN_PAPER := [[ROOM_STRIPES, Color(0.8, 0.75, 0.58)], [ROOM_CIRCLES, Color(0.92, 0.62, 0.28)], [ROOM_SPRIGS, Color(0.86, 0.82, 0.7)],
		[ROOM_PAINT, Color(0.62, 0.75, 0.62)], [ROOM_PAINT, Color(0.88, 0.8, 0.6)], [ROOM_STRIPES, Color(0.62, 0.72, 0.8)], [ROOM_CIRCLES, Color(0.58, 0.72, 0.42)],
		[ROOM_PAINT, Color(0.8, 0.62, 0.64)], [ROOM_TILES, Color(0.86, 0.88, 0.82)], [ROOM_SPRIGS, Color(0.82, 0.86, 0.9)], [ROOM_CIRCLES, Color(0.75, 0.42, 0.25)],
		[ROOM_PAINT, Color(0.92, 0.9, 0.84)]]
const RUIN_FLOORS := [[ROOM_LINO, Color(0.55, 0.6, 0.5)], [ROOM_STRIPS, Color(0.72, 0.52, 0.32)], [ROOM_CARPET, Color(0.45, 0.3, 0.2)],
		[ROOM_CARPET, Color(0.3, 0.42, 0.3)], [ROOM_LINO, Color(0.72, 0.64, 0.44)], [ROOM_CARPET, Color(0.55, 0.22, 0.16)], [ROOM_LINO, Color(0.5, 0.52, 0.55)]]


## How many storeys each bay still has: the east end (x < 0) knocked down in steps, the west end whole.
static func _ruin_tops(n: int) -> Array:
	var t: Array = []
	for i in range(RUIN_BAYS):
		var v: int = n
		match i:
			0:
				v = maxi(1, n - 5)
			1:
				v = maxi(1, n - 4)
			2:
				v = maxi(2, n - 2)
			3:
				v = maxi(2, n - 1)
		t.append(v)
	return t


static func _rx(i: int) -> float:
	return -RUIN_HALF + float(i) * RUIN_BAY


static func _ry(k: int) -> float:
	return RUIN_Y0 + float(k) * RUIN_STOREY


## A front cell's state: -1 gone, 0 whole, 1 stripped (the facade torn off, the rooms open to the street), 2 smashed by the
## ball (the ground floor of bays 4 and 5), 3 the glass gone.
static func _ruin_face(i: int, k: int, tops: Array, n: int) -> int:
	if k >= int(tops[i]):
		return -1
	if (i == 4 or i == 5) and k == 0:
		return 2
	if (i == 4 or i == 5) and k == 1:
		return 3
	if i <= 3 and k >= int(tops[i]) - (2 if i <= 1 else 1):
		return 1
	if i == 4 and k >= n - 2:
		return 1
	return 0


## A room's finishes: [walls, floor], rooms two bays wide (`r` = bay / 2), the back rooms their own.
static func _ruin_finish(r: int, k: int, back: bool) -> Array:
	if k == 0 and not back:
		return [room(Color(0.9, 0.86, 0.74), ROOM_PAINT), room(Color(0.52, 0.52, 0.5), ROOM_LINO)]
	var h: int = absi(hash(Vector3i(r, k, 7 if back else 3)))
	var p: Array = RUIN_PAPER[h % RUIN_PAPER.size()]
	var f: Array = RUIN_FLOORS[(h >> 7) % RUIN_FLOORS.size()]
	return [room(p[1], p[0]), room(f[1], f[0])]


static func _ruin_corridor() -> Array:
	return [room(Color(0.42, 0.56, 0.48), ROOM_STAIRWELL), room(Color(0.5, 0.5, 0.47), ROOM_LINO)]


static func _ruin_ceiling() -> Color:
	return room(Color(0.92, 0.91, 0.87), ROOM_CEILING)


static func _ruin_broken() -> Color:
	return room(RUIN_CONC, ROOM_BROKEN)


## The office block, its front toward +z (x -19..19, z -15..0), half knocked down: `storeys` storeys (7: 25m to the roof),
## the east end (x < -3.8) down in steps to two storeys, the rooms there open to the street with their wallpaper, floors
## hanging, rebar; the ground floor of bays 4 and 5 (x -3.8..3.8, where the ball strikes the front at about 3m up) smashed
## open and the first floor's slab edge bitten out over it; a glass-mosaic and exposed-aggregate facade with ribbon windows
## (many panes broken); the entrance with its canopy (bay 7); the old rooftop sign; Abbruch Brandt's banner.
static func ruin_building(pk: PropKit, kit: Dictionary, labels: Array, storeys: int) -> void:
	var n: int = clampi(storeys, 3, 12)
	var tops := _ruin_tops(n)
	var rng := _rng(n, 77)
	for i in range(RUIN_BAYS):
		for k in range(int(tops[i]) + 1):
			_ruin_slab(pk, kit, i, k, tops, n, rng)
	for i in range(RUIN_BAYS):
		for k in range(int(tops[i])):
			_ruin_front(pk, kit, i, k, tops, n, rng)
			_ruin_back(pk, kit, i, k, rng)
			_ruin_corridor_walls(pk, kit, i, k, tops)
	_ruin_partitions(pk, kit, tops)
	_ruin_columns(pk, kit, tops, n, rng)
	_ruin_gable(pk, kit, n)
	_ruin_hanging_slab(pk, kit, tops)
	_ruin_crater(pk, kit, rng)
	_ruin_entrance(pk, kit, labels)
	_ruin_roof(pk, kit, labels, tops, n)
	_ruin_debris(pk, kit, tops, n, rng)
	# Abbruch Brandt's banner on the whole front's second floor, west end.
	var by: float = _ry(2) + 0.5
	_blk(pk, kit, "plastic", Vector3(11.6, by, 0.02), Vector3(18.4, by + 2.2, 0.045), Color(0.92, 0.9, 0.86))
	_blk(pk, kit, "plastic", Vector3(11.6, by + 1.75, 0.045), Vector3(18.4, by + 2.2, 0.07), KORVALD_RED)
	for bx in [11.75, 18.25]:
		for byy in [by + 0.15, by + 2.05]:
			_rod(pk, kit, "steel", Vector3(bx, byy, -0.02), Vector3(bx, byy, 0.095), 0.03, 6, Color(0.6, 0.6, 0.6), true)
	_lbl(labels, "ABBRUCH BRANDT", Vector3(15.0, by + 1.15, 0.075), Vector3(0, 0, 1), 0.5, KORVALD_RED, 6.4)
	_lbl(labels, "RUECKBAU  ENTKERNUNG  RECYCLING", Vector3(15.0, by + 0.45, 0.075), Vector3(0, 0, 1), 0.24, Color(0.15, 0.15, 0.15), 6.4)
	_lbl(labels, "KRONBURG  0 21 47 / 38 60", Vector3(15.0, by + 1.98, 0.1), Vector3(0, 0, 1), 0.2, Color(0.97, 0.96, 0.92), 6.2)


## Slab k over bay i (k 0 the ground floor's, on the ground): its floor (a ledge at the front, the front room's, the
## corridor's and the back room's finishes) or the roof, the ceiling under it, its edges (exposed edges broken, rebar out).
static func _ruin_slab(pk: PropKit, kit: Dictionary, i: int, k: int, tops: Array, n: int, rng: RandomNumberGenerator) -> void:
	var x0 := _rx(i)
	var x1 := x0 + RUIN_BAY
	var yt := _ry(k)
	var yb: float = yt - RUIN_SLAB if k > 0 else -0.4
	var r: int = i >> 1
	var wash := room(RUIN_WASCH, ROOM_WASCHBETON)
	if k == n:
		pk.quad(kit, "grime", [Vector3(x0, yt, 0.0), Vector3(x1, yt, 0.0), Vector3(x1, yt, -RUIN_DEPTH), Vector3(x0, yt, -RUIN_DEPTH)], UP, Color(0.3, 0.3, 0.29))
	else:
		var fr: Array = _ruin_finish(r, k, false)
		var bk: Array = _ruin_finish(r, k, true)
		_rh(pk, kit, x0, x1, 0.0, -0.05, yt, true, wash)
		_rh(pk, kit, x0, x1, -0.05, -RUIN_CORR0, yt, true, fr[1])
		_rh(pk, kit, x0, x1, -RUIN_CORR0, -RUIN_CORR1, yt, true, _ruin_corridor()[1])
		_rh(pk, kit, x0, x1, -RUIN_CORR1, -RUIN_DEPTH + 0.05, yt, true, bk[1])
		_rh(pk, kit, x0, x1, -RUIN_DEPTH + 0.05, -RUIN_DEPTH, yt, true, wash)
	if k > 0:
		var ceil := _ruin_ceiling()
		if k == 1 and (i == 4 or i == 5):
			var nx0: float = maxf(x0, RUIN_NOTCH.x)
			var nx1: float = minf(x1, RUIN_NOTCH.y)
			if nx0 > x0:
				_rh(pk, kit, x0, nx0, 0.0, -0.5, yb, false, ceil)
			if nx1 < x1:
				_rh(pk, kit, nx1, x1, 0.0, -0.5, yb, false, ceil)
			_rh(pk, kit, x0, x1, -0.5, -RUIN_DEPTH, yb, false, ceil)
		else:
			_rh(pk, kit, x0, x1, 0.0, -RUIN_DEPTH, yb, false, ceil)
	# The fascia (the slab's edge on the front and back).
	if not (k == 1 and (i == 4 or i == 5)):
		_rq(pk, kit, [Vector3(x0, yb, 0.0), Vector3(x1, yb, 0.0), Vector3(x1, yt, 0.0), Vector3(x0, yt, 0.0)], Vector3.BACK, wash, Vector3.RIGHT)
	_rq(pk, kit, [Vector3(x1, yb, -RUIN_DEPTH), Vector3(x0, yb, -RUIN_DEPTH), Vector3(x0, yt, -RUIN_DEPTH), Vector3(x1, yt, -RUIN_DEPTH)], Vector3.FORWARD, wash,
			Vector3.LEFT)
	# The east edge, broken off where the bay beside it is gone at this level.
	if i == 0 or k > int(tops[i - 1]):
		var brk := _ruin_broken()
		_rq(pk, kit, [Vector3(x0, yb, 0.0), Vector3(x0, yb, -RUIN_DEPTH), Vector3(x0, yt, -RUIN_DEPTH), Vector3(x0, yt, 0.0)], Vector3.LEFT, brk, Vector3.FORWARD)
		if k > 0:
			_ruin_rebar_edge(pk, kit, x0, yb, yt, rng)
			for c in range(3):
				var cz: float = rng.randf_range(-13.5, -1.0)
				_chunk(pk, kit, "room", Vector3(x0 - 0.12, yb + 0.12, cz), Basis(UP, rng.randf() * TAU), Vector3(0.25, 0.15, 0.4) * rng.randf_range(0.7, 1.3),
						0.3, rng, brk, true)


## Rebar sticking out of a broken slab edge at x0 toward -x, bent down.
static func _ruin_rebar_edge(pk: PropKit, kit: Dictionary, x0: float, yb: float, yt: float, rng: RandomNumberGenerator) -> void:
	var rc := worn(RUST, 0.95)
	var nb: int = 7
	for b in range(nb):
		var z: float = lerpf(-0.6, -14.2, (float(b) + rng.randf_range(0.1, 0.9)) / float(nb))
		var y: float = yb + 0.07 if rng.randf() < 0.5 else yt - 0.06
		var l: float = rng.randf_range(0.3, 1.1)
		var droop: float = rng.randf_range(0.1, 0.9) * l
		var p0 := Vector3(x0 + 0.15, y, z)
		var p1 := Vector3(x0 - l * 0.45, y - droop * 0.2, z + rng.randf_range(-0.1, 0.1))
		var p2 := Vector3(x0 - l, y - droop, z + rng.randf_range(-0.25, 0.25))
		_rods(pk, kit, "scrap", [p0, p1, p2], 0.013, 4, rc)


## The front of cell (i, k): the spandrel (glass mosaic; on the ground floor a low exposed-aggregate plinth wall), the window
## band's aluminium frames and dark glass (some panes broken), by the cell's state.
static func _ruin_front(pk: PropKit, kit: Dictionary, i: int, k: int, tops: Array, n: int, rng: RandomNumberGenerator) -> void:
	var st: int = _ruin_face(i, k, tops, n)
	if st < 0:
		return
	var x0 := _rx(i)
	var x1 := x0 + RUIN_BAY
	var yk := _ry(k)
	var yn: float = _ry(k + 1) - RUIN_SLAB
	var r: int = i >> 1
	var fin: Array = _ruin_finish(r, k, false)
	var ground: bool = k == 0
	var ys: float = yk + (0.4 if ground else RUIN_SILL)
	if st == 1:
		# Stripped: a stub of the spandrel at one side and a bent frame member.
		if rng.randf() < 0.6:
			var left: bool = rng.randf() < 0.5
			var w: float = rng.randf_range(0.5, 1.4)
			var ua: float = x0 if left else x1 - w
			var ub: float = ua + w
			var ol := PackedVector2Array([Vector2(ua, yk), Vector2(ub, yk), Vector2(ub, yk + rng.randf_range(0.1, 0.5)), Vector2(lerpf(ua, ub, 0.6), yk + rng.randf_range(0.3, 0.8)),
					Vector2(ua, yk + rng.randf_range(0.5, RUIN_SILL))])
			if not left:
				ol = PackedVector2Array([Vector2(ua, yk), Vector2(ub, yk), Vector2(ub, yk + rng.randf_range(0.5, RUIN_SILL)), Vector2(lerpf(ua, ub, 0.4), yk + rng.randf_range(0.3, 0.8)),
						Vector2(ua, yk + rng.randf_range(0.1, 0.5))])
			_wall_poly(pk, kit, "room", Transform3D(Basis(), Vector3(0, 0, -0.05)), ol, 0.15, room(RUIN_MOSAIC, ROOM_MOSAIC), fin[0], _ruin_broken())
		if rng.randf() < 0.5:
			var bx: float = rng.randf_range(x0 + 0.4, x1 - 0.4)
			pk.beam(kit, "metal", Vector3(bx, yn - 0.02, -0.11), Vector3(bx + rng.randf_range(-0.6, 0.6), yn - rng.randf_range(1.0, 2.2), rng.randf_range(-0.1, 0.4)), 0.06, 0.08,
					RUIN_ALU)
		return
	if st == 2:
		return
	# The spandrel: a box from z -0.2 (its back, the room's wall) to -0.05 (the mosaic, or exposed aggregate on the ground
	# floor), the window board on it, an aluminium sill flashing 2.5cm proud.
	var face_col: Color = room(RUIN_WASCH, ROOM_WASCHBETON) if ground else room(RUIN_MOSAIC, ROOM_MOSAIC)
	var door: bool = ground and i == 7
	if not door:
		_rq(pk, kit, [Vector3(x0, yk, -0.05), Vector3(x1, yk, -0.05), Vector3(x1, ys, -0.05), Vector3(x0, ys, -0.05)], Vector3.BACK, face_col, Vector3.RIGHT)
		_rq(pk, kit, [Vector3(x1, yk, -0.2), Vector3(x0, yk, -0.2), Vector3(x0, ys, -0.2), Vector3(x1, ys, -0.2)], Vector3.FORWARD, fin[0], Vector3.LEFT)
		_rh(pk, kit, x0, x1, -0.05, -0.2, ys, true, room(Color(0.9, 0.89, 0.86), ROOM_PAINT))
		_blk(pk, kit, "metal", Vector3(x0, ys - 0.04, -0.06), Vector3(x1, ys + 0.015, -0.025), RUIN_ALU)
		# A radiator under the window inside.
		if not ground:
			_blk(pk, kit, "metal", Vector3(x0 + 0.5, yk + 0.15, -0.36), Vector3(x1 - 0.5, ys - 0.25, -0.28), Color(0.86, 0.85, 0.8))
	# The frames: a cover strip on the bay's line (and the last bay's end), mullions, a transom; the glass in between.
	var ft := 0.06
	_blk(pk, kit, "metal", Vector3(x0 - 0.05, ys, -0.17), Vector3(x0 + 0.05, yn, -0.055), RUIN_ALU)
	if i == RUIN_BAYS - 1:
		_blk(pk, kit, "metal", Vector3(x1 - 0.05, ys, -0.17), Vector3(x1 - 0.0, yn, -0.055), RUIN_ALU)
	var panes: int = 2 if ground else 3
	var yt: float = yn - (0.6 if ground else 0.55)
	var p_broken: float = 1.0 if st == 3 else (0.1 + (0.35 if i <= 4 else 0.0) + (0.15 if k >= n - 2 else 0.0))
	if door:
		_ruin_doors(pk, kit, x0, x1, yk, yt)
	for j in range(1, panes):
		var mx: float = x0 + RUIN_BAY * float(j) / float(panes)
		_blk(pk, kit, "metal", Vector3(mx - ft * 0.5, ys, -0.155), Vector3(mx + ft * 0.5, yn, -0.07), RUIN_ALU)
	_blk(pk, kit, "metal", Vector3(x0 + 0.05, yt - 0.03, -0.15), Vector3(x1 - 0.05, yt + 0.03, -0.075), RUIN_ALU)
	for j in range(panes):
		var pa: float = x0 + RUIN_BAY * float(j) / float(panes) + (0.05 if j == 0 else ft * 0.5)
		var pb: float = x0 + RUIN_BAY * float(j + 1) / float(panes) - (0.05 if j == panes - 1 else ft * 0.5)
		for row in range(2):
			var ya: float = (ys if row == 0 else yt + 0.03)
			var yb: float = (yt - 0.03 if row == 0 else yn)
			if door and row == 0:
				continue
			if rng.randf() < p_broken:
				# Broken: a shard or two left in a corner.
				if rng.randf() < 0.55:
					var cx: float = pa if rng.randf() < 0.5 else pb
					var cy: float = ya if rng.randf() < 0.6 else yb
					var sx: float = minf((pb - pa) * rng.randf_range(0.1, 0.35), 0.4) * (1.0 if cx == pa else -1.0)
					var sy: float = minf((yb - ya) * rng.randf_range(0.1, 0.4), 0.5) * (1.0 if cy == ya else -1.0)
					pk.tri(kit, "glassdark", Vector3(cx, cy, -0.11), Vector3(cx + sx, cy, -0.11), Vector3(cx, cy + sy, -0.11), Vector3.BACK, Vector3.BACK, Vector3.BACK,
							GLASS, Vector3.BACK)
				continue
			pk.quad(kit, "glassdark", [Vector3(pa, ya, -0.11), Vector3(pb, ya, -0.11), Vector3(pb, yb, -0.11), Vector3(pa, yb, -0.11)], Vector3.BACK,
					GLASS.lerp(Color(0.2, 0.26, 0.3), rng.randf() * 0.35))


## The entrance's glass doors (bay 7): two pairs of leaves in steel frames with push bars, under the transom.
static func _ruin_doors(pk: PropKit, kit: Dictionary, x0: float, x1: float, yk: float, yt: float) -> void:
	for pair in range(2):
		var cx: float = lerpf(x0, x1, 0.27 + 0.46 * float(pair))
		for leaf in [-1.0, 1.0]:
			var la: float = cx + (0.0 if leaf > 0.0 else -0.82)
			var lb: float = la + 0.82
			_blk(pk, kit, "metal", Vector3(la, yk, -0.16), Vector3(lb, yk + 0.12, -0.08), Color(0.25, 0.26, 0.26))
			_blk(pk, kit, "metal", Vector3(la, yt - 0.1, -0.16), Vector3(lb, yt - 0.03, -0.08), Color(0.25, 0.26, 0.26))
			for e in [la, lb - 0.07]:
				_blk(pk, kit, "metal", Vector3(e, yk + 0.12, -0.16), Vector3(e + 0.07, yt - 0.1, -0.08), Color(0.25, 0.26, 0.26))
			pk.quad(kit, "glassdark", [Vector3(la + 0.07, yk + 0.12, -0.12), Vector3(lb - 0.07, yk + 0.12, -0.12), Vector3(lb - 0.07, yt - 0.1, -0.12),
					Vector3(la + 0.07, yt - 0.1, -0.12)], Vector3.BACK, GLASS)
			_rod(pk, kit, "chrome", Vector3(la + 0.15, yk + 1.05, -0.05), Vector3(lb - 0.15, yk + 1.05, -0.05), 0.02, 6, Color(0.8, 0.8, 0.8), true)
	_blk(pk, kit, "metal", Vector3(x0 + 0.05, yk - 0.01, -0.2), Vector3(x1 - 0.05, yk + 0.02, -0.04), Color(0.3, 0.3, 0.3))


## The back of cell (i, k), facing -z: an exposed-aggregate spandrel, the window band's frames and glass.
static func _ruin_back(pk: PropKit, kit: Dictionary, i: int, k: int, rng: RandomNumberGenerator) -> void:
	var x0 := _rx(i)
	var x1 := x0 + RUIN_BAY
	var yk := _ry(k)
	var yn: float = _ry(k + 1) - RUIN_SLAB
	var ys: float = yk + RUIN_SILL
	var zb: float = -RUIN_DEPTH
	var fin: Array = _ruin_finish(i >> 1, k, true)
	_rq(pk, kit, [Vector3(x1, yk, zb + 0.05), Vector3(x0, yk, zb + 0.05), Vector3(x0, ys, zb + 0.05), Vector3(x1, ys, zb + 0.05)], Vector3.FORWARD,
			room(RUIN_WASCH, ROOM_WASCHBETON), Vector3.LEFT)
	_rq(pk, kit, [Vector3(x0, yk, zb + 0.2), Vector3(x1, yk, zb + 0.2), Vector3(x1, ys, zb + 0.2), Vector3(x0, ys, zb + 0.2)], Vector3.BACK, fin[0], Vector3.RIGHT)
	_rh(pk, kit, x0, x1, zb + 0.2, zb + 0.05, ys, true, room(Color(0.9, 0.89, 0.86), ROOM_PAINT))
	_blk(pk, kit, "metal", Vector3(x0, ys - 0.04, zb + 0.025), Vector3(x1, ys + 0.015, zb + 0.06), RUIN_ALU)
	_blk(pk, kit, "metal", Vector3(x0 - 0.05, ys, zb + 0.055), Vector3(x0 + 0.05, yn, zb + 0.17), RUIN_ALU)
	if i == RUIN_BAYS - 1:
		_blk(pk, kit, "metal", Vector3(x1 - 0.05, ys, zb + 0.055), Vector3(x1, yn, zb + 0.17), RUIN_ALU)
	for j in range(1, 3):
		var mx: float = x0 + RUIN_BAY * float(j) / 3.0
		_blk(pk, kit, "metal", Vector3(mx - 0.03, ys, zb + 0.07), Vector3(mx + 0.03, yn, zb + 0.155), RUIN_ALU)
	for j in range(3):
		if rng.randf() < 0.15:
			continue
		var pa: float = x0 + RUIN_BAY * float(j) / 3.0 + 0.04
		var pb: float = x0 + RUIN_BAY * float(j + 1) / 3.0 - 0.04
		pk.quad(kit, "glassdark", [Vector3(pb, ys, zb + 0.11), Vector3(pa, ys, zb + 0.11), Vector3(pa, yn, zb + 0.11), Vector3(pb, yn, zb + 0.11)], Vector3.FORWARD, GLASS)


## A wall between x0 and x1 at z (its two faces at z and z - RUIN_WALL), from y0 to y1, with a door hole (its left edge at
## `door` from x0; negative: none), the front face (+z) in `cf` and the back in `cb`; its ends broken where `end0`/`end1`.
static func _ruin_wall_x(pk: PropKit, kit: Dictionary, x0: float, x1: float, z: float, y0: float, y1: float, cf: Color, cb: Color, door: float, end0 := false,
		end1 := false) -> void:
	var zb: float = z - RUIN_WALL
	var spans: Array = [[x0, x1, y0, y1]]
	if door >= 0.0:
		var da: float = x0 + door
		var db: float = da + 0.9
		var dh: float = y0 + 2.05
		spans = [[x0, da, y0, y1], [db, x1, y0, y1], [da, db, dh, y1]]
		_rq(pk, kit, [Vector3(da, y0, z), Vector3(da, y0, zb), Vector3(da, dh, zb), Vector3(da, dh, z)], Vector3.RIGHT, cf, Vector3.FORWARD)
		_rq(pk, kit, [Vector3(db, y0, zb), Vector3(db, y0, z), Vector3(db, dh, z), Vector3(db, dh, zb)], Vector3.LEFT, cf, Vector3.BACK)
		pk.quad(kit, "room", [Vector3(da, dh, z), Vector3(db, dh, z), Vector3(db, dh, zb), Vector3(da, dh, zb)], Vector3.DOWN, cf)
		# The door leaf, ajar and dark.
		_rq(pk, kit, [Vector3(da + 0.02, y0, z - 0.04), Vector3(db - 0.02, y0, z - 0.04), Vector3(db - 0.02, dh - 0.02, z - 0.04), Vector3(da + 0.02, dh - 0.02, z - 0.04)],
				Vector3.BACK, room(Color(0.5, 0.36, 0.22), ROOM_STRIPS), Vector3.RIGHT)
		_rq(pk, kit, [Vector3(db - 0.02, y0, z - 0.06), Vector3(da + 0.02, y0, z - 0.06), Vector3(da + 0.02, dh - 0.02, z - 0.06), Vector3(db - 0.02, dh - 0.02, z - 0.06)],
				Vector3.FORWARD, room(Color(0.5, 0.36, 0.22), ROOM_STRIPS), Vector3.LEFT)
	for sp in spans:
		var a: float = sp[0]
		var b: float = sp[1]
		var ya: float = sp[2]
		var yb: float = sp[3]
		_rq(pk, kit, [Vector3(a, ya, z), Vector3(b, ya, z), Vector3(b, yb, z), Vector3(a, yb, z)], Vector3.BACK, cf, Vector3.RIGHT)
		_rq(pk, kit, [Vector3(b, ya, zb), Vector3(a, ya, zb), Vector3(a, yb, zb), Vector3(b, yb, zb)], Vector3.FORWARD, cb, Vector3.LEFT)
	var brk := _ruin_broken()
	if end0:
		_rq(pk, kit, [Vector3(x0, y0, z), Vector3(x0, y0, zb), Vector3(x0, y1, zb), Vector3(x0, y1, z)], Vector3.LEFT, brk, Vector3.FORWARD)
	if end1:
		_rq(pk, kit, [Vector3(x1, y0, zb), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x1, y1, zb)], Vector3.RIGHT, brk, Vector3.BACK)


## The corridor's two walls through cell (i, k): the front room's (its door in the room's second bay) and the back room's.
static func _ruin_corridor_walls(pk: PropKit, kit: Dictionary, i: int, k: int, tops: Array) -> void:
	var x0 := _rx(i)
	var x1 := x0 + RUIN_BAY
	var y0 := _ry(k)
	var y1: float = _ry(k + 1) - RUIN_SLAB
	var r: int = i >> 1
	var cor: Array = _ruin_corridor()
	var exposed: bool = i == 0 or k >= int(tops[i - 1])
	_ruin_wall_x(pk, kit, x0, x1, -RUIN_CORR0, y0, y1, _ruin_finish(r, k, false)[0], cor[0], 0.6 if i % 2 == 1 else -1.0, exposed)
	_ruin_wall_x(pk, kit, x0, x1, -RUIN_CORR1, y0, y1, cor[0], _ruin_finish(r, k, true)[0], 2.3 if i % 2 == 0 else -1.0, exposed)


## The partitions between the rooms (on the even bay lines), front and back, each face the finish of the room it faces (a
## room that has gone leaves its paper on the wall it shared, open to the street).
static func _ruin_partitions(pk: PropKit, kit: Dictionary, tops: Array) -> void:
	var hw: float = RUIN_WALL * 0.5
	for b in range(2, RUIN_BAYS, 2):
		var x := _rx(b)
		for k in range(int(tops[b])):
			var y0 := _ry(k)
			var y1: float = _ry(k + 1) - RUIN_SLAB
			var fl: Array = [_ruin_finish((b - 1) >> 1, k, false)[0], _ruin_finish((b - 1) >> 1, k, true)[0]]
			var fr: Array = [_ruin_finish(b >> 1, k, false)[0], _ruin_finish(b >> 1, k, true)[0]]
			for zone in range(2):
				if zone == 0 and k == 0:
					continue
				var za: float = -0.2 if zone == 0 else -RUIN_CORR1 - RUIN_WALL
				var zb: float = -RUIN_CORR0 if zone == 0 else -RUIN_DEPTH + 0.2
				_rq(pk, kit, [Vector3(x - hw, y0, zb), Vector3(x - hw, y0, za), Vector3(x - hw, y1, za), Vector3(x - hw, y1, zb)], Vector3.LEFT, fl[zone], Vector3.BACK)
				_rq(pk, kit, [Vector3(x + hw, y0, za), Vector3(x + hw, y0, zb), Vector3(x + hw, y1, zb), Vector3(x + hw, y1, za)], Vector3.RIGHT, fr[zone], Vector3.FORWARD)
				if zone == 0:
					_rq(pk, kit, [Vector3(x - hw, y0, za), Vector3(x + hw, y0, za), Vector3(x + hw, y1, za), Vector3(x - hw, y1, za)], Vector3.BACK, _ruin_broken(), Vector3.RIGHT)


## The concrete columns on the bay lines (four rows), and their stubs with rebar over the knocked-down bays' tops.
static func _ruin_columns(pk: PropKit, kit: Dictionary, tops: Array, n: int, rng: RandomNumberGenerator) -> void:
	var cc := room(RUIN_CONC.lightened(0.06), ROOM_BROKEN)
	for b in range(RUIN_BAYS + 1):
		var h: int = 0
		if b > 0:
			h = maxi(h, int(tops[b - 1]))
		if b < RUIN_BAYS:
			h = maxi(h, int(tops[b]))
		var x: float = clampf(_rx(b), -RUIN_HALF + 0.25, RUIN_HALF - 0.25)
		for k in range(h):
			var y0 := _ry(k)
			var y1: float = _ry(k + 1) - RUIN_SLAB
			for z in [-0.6, -RUIN_CORR0 - 0.06, -RUIN_CORR1 - 0.06, -RUIN_DEPTH + 0.6]:
				var c := Vector3(x, 0, z)
				_rq(pk, kit, [c + Vector3(-0.2, y0, 0.2), c + Vector3(0.2, y0, 0.2), c + Vector3(0.2, y1, 0.2), c + Vector3(-0.2, y1, 0.2)], Vector3.BACK, cc, Vector3.RIGHT)
				_rq(pk, kit, [c + Vector3(0.2, y0, -0.2), c + Vector3(-0.2, y0, -0.2), c + Vector3(-0.2, y1, -0.2), c + Vector3(0.2, y1, -0.2)], Vector3.FORWARD, cc, Vector3.LEFT)
				_rq(pk, kit, [c + Vector3(-0.2, y0, -0.2), c + Vector3(-0.2, y0, 0.2), c + Vector3(-0.2, y1, 0.2), c + Vector3(-0.2, y1, -0.2)], Vector3.LEFT, cc, Vector3.BACK)
				_rq(pk, kit, [c + Vector3(0.2, y0, 0.2), c + Vector3(0.2, y0, -0.2), c + Vector3(0.2, y1, -0.2), c + Vector3(0.2, y1, 0.2)], Vector3.RIGHT, cc, Vector3.FORWARD)
		# Stubs over a knocked-down top.
		if h < n and b <= 4:
			var yh := _ry(h)
			for z in [-0.6, -RUIN_CORR0 - 0.06, -RUIN_DEPTH + 0.6]:
				var st: float = rng.randf_range(0.25, 0.7)
				var c2 := Vector3(x, yh, z)
				_chunk(pk, kit, "room", c2 + Vector3(0, st * 0.5, 0), Basis(UP, rng.randf_range(-0.2, 0.2)), Vector3(0.2, st * 0.5, 0.2), 0.12, rng, _ruin_broken(), true)
				for sx in [-0.13, 0.13]:
					for sz in [-0.13, 0.13]:
						var tip := c2 + Vector3(sx + rng.randf_range(-0.3, 0.3), st + rng.randf_range(0.3, 0.9), sz + rng.randf_range(-0.3, 0.3))
						_rods(pk, kit, "scrap", [c2 + Vector3(sx, 0.05, sz), c2 + Vector3(sx, st + 0.15, sz), tip], 0.012, 4, worn(RUST, 0.95))


## The west end: an exposed-aggregate gable from the ground to the parapet, a strip of stair windows.
static func _ruin_gable(pk: PropKit, kit: Dictionary, n: int) -> void:
	var wash := room(RUIN_WASCH, ROOM_WASCHBETON)
	var top: float = _ry(n) + 0.9
	_rbox(pk, kit, Vector3(RUIN_HALF - 0.22, -0.4, -RUIN_DEPTH - 0.03), Vector3(RUIN_HALF + 0.03, top, 0.03), [room(Color(0.9, 0.88, 0.82), ROOM_PAINT), wash, null, wash, wash, wash])
	for k in range(n):
		var y: float = _ry(k) + 1.6
		_blk(pk, kit, "glassdark", Vector3(RUIN_HALF + 0.03, y, -11.8), Vector3(RUIN_HALF + 0.05, y + 1.3, -10.6), GLASS)
		_blk(pk, kit, "metal", Vector3(RUIN_HALF + 0.03, y - 0.06, -11.86), Vector3(RUIN_HALF + 0.08, y, -10.54), RUIN_ALU)


## A floor slab broken off the next bay, hanging from it down onto the slab below.
static func _ruin_hanging_slab(pk: PropKit, kit: Dictionary, tops: Array) -> void:
	var kh: int = int(tops[1]) + 1
	if kh > int(tops[2]):
		return
	var hx := _rx(2)
	var hy: float = _ry(kh) - RUIN_SLAB * 0.5
	var drop: float = hy - (_ry(int(tops[1])) + RUIN_SLAB * 0.5)
	var length := RUIN_BAY * 0.98
	var ang: float = asin(clampf(drop / length, 0.0, 0.95))
	var dir := Vector3(-cos(ang), -sin(ang), 0)
	var b := Basis(dir, Vector3(-sin(ang), cos(ang), 0), Vector3(0, 0, -1))
	var c: Vector3 = Vector3(hx, hy, -5.0) + dir * (length * 0.5)
	var fin: Array = _ruin_finish(0, kh, false)
	_slab_piece(pk, kit, c, b, Vector3(length, RUIN_SLAB, 8.6), fin[1], _ruin_ceiling(), _ruin_broken())
	# Rebar holding it at the hinge.
	for k in range(9):
		var z: float = -1.0 - float(k) * 0.95
		_rods(pk, kit, "scrap", [Vector3(hx + 0.2, hy + 0.1, z), Vector3(hx - 0.05, hy + 0.05, z + 0.05), Vector3(hx - 0.2, hy - 0.25, z)], 0.013, 4, worn(RUST, 0.95))


## A slab of concrete round `c` turned by `b` (size along its x, y and z): its top (+y) in `top`, its bottom in `bot`, its
## four edges broken; UVs in metres in each face's plane.
static func _slab_piece(pk: PropKit, kit: Dictionary, c: Vector3, b: Basis, size: Vector3, top: Color, bot: Color, edge: Color) -> void:
	var hs := size * 0.5
	var ax: Array = [b.x.normalized(), b.y.normalized(), b.z.normalized()]
	for a in range(3):
		for sg in [-1.0, 1.0]:
			var n: Vector3 = ax[a] * sg
			var u: Vector3 = ax[(a + 1) % 3]
			var v: Vector3 = ax[(a + 2) % 3]
			var hu: float = hs[(a + 1) % 3]
			var hv: float = hs[(a + 2) % 3]
			var fc: Vector3 = c + n * hs[a]
			var pts: Array = [fc - u * hu - v * hv, fc + u * hu - v * hv, fc + u * hu + v * hv, fc - u * hu + v * hv]
			var uv: Array = [Vector2(-hu, -hv) * uvk, Vector2(hu, -hv) * uvk, Vector2(hu, hv) * uvk, Vector2(-hu, hv) * uvk]
			var col: Color = edge
			if a == 1:
				col = top if sg > 0.0 else bot
			pk.quad(kit, "room", pts, n, col, uv)


## Where the ball strikes (x 0, about 3m up): the ground floor of bays 4 and 5 smashed open (the plinth wall broken off, frames
## bent and fallen), the first floor's slab edge bitten out over it (RUIN_NOTCH) with its rebar hanging, rubble inside and
## a low spill in front.
static func _ruin_crater(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var wash := room(RUIN_WASCH, ROOM_WASCHBETON)
	var brk := _ruin_broken()
	var paint: Color = _ruin_finish(2, 0, false)[0]
	var y1b: float = _ry(1) - RUIN_SLAB
	var y1t: float = _ry(1)
	# The plinth wall's stubs either side.
	var wf := Transform3D(Basis(), Vector3(0, 0, -0.05))
	var lw := PackedVector2Array([Vector2(-3.8, RUIN_Y0), Vector2(-1.15, RUIN_Y0), Vector2(-1.3, 0.58), Vector2(-1.65, 0.66), Vector2(-1.8, 0.79), Vector2(-2.3, 0.85),
			Vector2(-3.8, 0.85)])
	var rw := PackedVector2Array([Vector2(1.05, RUIN_Y0), Vector2(3.8, RUIN_Y0), Vector2(3.8, 0.85), Vector2(2.45, 0.85), Vector2(1.9, 0.74), Vector2(1.45, 0.69),
			Vector2(1.2, 0.55)])
	_wall_poly(pk, kit, "room", wf, lw, 0.25, wash, paint, brk)
	_wall_poly(pk, kit, "room", wf, rw, 0.25, wash, paint, brk)
	# The slab edge: whole above the bite, the bite (its jagged roof through 0.5 of the slab), its back face.
	_rq(pk, kit, [Vector3(-3.8, y1t - 0.09, 0.0), Vector3(3.8, y1t - 0.09, 0.0), Vector3(3.8, y1t, 0.0), Vector3(-3.8, y1t, 0.0)], Vector3.BACK, wash, Vector3.RIGHT)
	var jag: Array = [Vector2(RUIN_NOTCH.x, y1b)]
	var nj := 8
	for k in range(1, nj):
		var x: float = lerpf(RUIN_NOTCH.x, RUIN_NOTCH.y, float(k) / float(nj))
		var depth: float = (1.0 - pow(absf(float(k) / float(nj) - 0.5) * 2.0, 2.0)) * 0.17
		jag.append(Vector2(x, y1b + 0.03 + depth * rng.randf_range(0.6, 1.0)))
	jag.append(Vector2(RUIN_NOTCH.y, y1b))
	var fol := PackedVector2Array([Vector2(-3.8, y1b)])
	for p in jag:
		fol.append(p)
	fol.append_array(PackedVector2Array([Vector2(3.8, y1b), Vector2(3.8, y1t - 0.09), Vector2(-3.8, y1t - 0.09)]))
	_pface(pk, kit, "room", Transform3D.IDENTITY, fol, 0.0, wash)
	for k in range(jag.size() - 1):
		var ja: Vector2 = jag[k]
		var jb: Vector2 = jag[k + 1]
		_ftri(pk, kit, "room", Vector3(ja.x, ja.y, 0.0), Vector3(jb.x, jb.y, 0.0), Vector3(jb.x, jb.y, -0.5), brk, Vector3((ja.x + jb.x) * 0.5, y1t, -0.25), true)
		_ftri(pk, kit, "room", Vector3(ja.x, ja.y, 0.0), Vector3(jb.x, jb.y, -0.5), Vector3(ja.x, ja.y, -0.5), brk, Vector3((ja.x + jb.x) * 0.5, y1t, -0.25), true)
	var nol := PackedVector2Array()
	for k in range(jag.size() - 1, -1, -1):
		nol.append(jag[k])
	_pface(pk, kit, "room", Transform3D.IDENTITY, nol, -0.5, brk)
	for k in range(7):
		var x2: float = lerpf(RUIN_NOTCH.x + 0.25, RUIN_NOTCH.y - 0.25, float(k) / 6.0) + rng.randf_range(-0.1, 0.1)
		var hang: float = rng.randf_range(0.3, 1.0)
		_rods(pk, kit, "scrap", [Vector3(x2, y1b + 0.12, -0.42), Vector3(x2 + rng.randf_range(-0.05, 0.05), y1b + 0.05, -0.02),
				Vector3(x2 + rng.randf_range(-0.25, 0.25), y1b - hang, rng.randf_range(-0.05, 0.06))], 0.013, 4, worn(RUST, 0.95))
	# Fallen frames, shards and lumps inside; the spill on the pavement in front (low: the ball swings over it).
	for k in range(4):
		var a := Vector3(rng.randf_range(-3.2, 3.2), RUIN_Y0 + 0.05, rng.randf_range(-3.5, -0.6))
		pk.beam(kit, "metal", a, a + Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(0.0, 0.4), rng.randf_range(-1.2, 1.2)), 0.06, 0.08, RUIN_ALU)
	for k in range(14):
		var p := Vector3(rng.randf_range(-3.4, 3.4), RUIN_Y0, rng.randf_range(-4.5, -0.4))
		var s: float = rng.randf_range(0.12, 0.35)
		_chunk(pk, kit, "room", p + Vector3(0, s * 0.5, 0), Basis(UP, rng.randf() * TAU), Vector3(s, s * 0.6, s * 0.8), 0.35, rng, brk if k % 3 else wash, true)
	for k in range(18):
		var p2 := Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(0.05, 2.6))
		var s2: float = rng.randf_range(0.08, 0.28) * (1.0 - p2.z / 3.2)
		_chunk(pk, kit, "room", p2 + Vector3(0, s2 * 0.4, 0), Basis(UP, rng.randf() * TAU), Vector3(s2, s2 * 0.55, s2 * 0.85), 0.35, rng, brk if k % 4 else room(RUIN_MOSAIC, ROOM_MOSAIC), true)


## The entrance (bay 7): steps up to the ground floor, a thin canopy on two posts with the old tenant's name on its fascia.
static func _ruin_entrance(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var x0 := _rx(7) + 0.2
	var x1 := _rx(8) - 0.2
	var wash := room(RUIN_WASCH, ROOM_WASCHBETON)
	for k in range(3):
		var y: float = RUIN_Y0 * float(k + 1) / 3.0
		var z: float = 0.9 - 0.3 * float(k)
		var inset: float = 0.04 * float(k)
		_rbox(pk, kit, Vector3(x0 + inset, 0.0, 0.0), Vector3(x1 - inset, y, z), [wash, wash, null, wash, null, wash])
	var cy := 3.3
	_rbox(pk, kit, Vector3(x0 - 0.6, cy, -0.02), Vector3(x1 + 0.6, cy + 0.2, 2.3), [wash, wash, _ruin_ceiling(), room(Color(0.4, 0.4, 0.38), ROOM_BROKEN), null, wash])
	_blk(pk, kit, "plastic", Vector3(x0 - 0.2, cy - 0.02, 2.31), Vector3(x1 + 0.2, cy + 0.22, 2.335), Color(0.92, 0.9, 0.85))
	_lbl(labels, "KRONBURGER BAUSPARKASSE", Vector3((x0 + x1) * 0.5, cy + 0.1, 2.36), Vector3(0, 0, 1), 0.15, Color(0.62, 0.16, 0.12), x1 - x0 + 0.3)
	for px in [x0 - 0.3, x1 + 0.3]:
		_rod(pk, kit, "metal", Vector3(px, 0.0, 2.0), Vector3(px, cy, 2.0), 0.05, 8, Color(0.3, 0.3, 0.3), false)


## The roof over the whole bays: parapets with their coping, the lift's motor room, vents and aerials, the old sign on its
## frame; the broken edge over the knocked-down bays.
static func _ruin_roof(pk: PropKit, kit: Dictionary, labels: Array, tops: Array, n: int) -> void:
	var yr := _ry(n)
	var wash := room(RUIN_WASCH, ROOM_WASCHBETON)
	var brk := _ruin_broken()
	var xa: float = 0.0
	for i in range(RUIN_BAYS):
		if int(tops[i]) == n:
			xa = _rx(i)
			break
	var xb: float = RUIN_HALF - 0.22
	var ph := 0.9
	_rbox(pk, kit, Vector3(xa, yr, -0.25), Vector3(xb, yr + ph, 0.0), [brk, null, null, null, wash, wash])
	_rbox(pk, kit, Vector3(xa, yr, -RUIN_DEPTH), Vector3(xb, yr + ph, -RUIN_DEPTH + 0.25), [brk, null, null, null, wash, wash])
	_blk(pk, kit, "metal", Vector3(xa, yr + ph, -0.28), Vector3(xb, yr + ph + 0.05, 0.06), Color(0.5, 0.5, 0.49))
	_blk(pk, kit, "metal", Vector3(xa, yr + ph, -RUIN_DEPTH - 0.06), Vector3(xb, yr + ph + 0.05, -RUIN_DEPTH + 0.28), Color(0.5, 0.5, 0.49))
	# The lift's motor room and the stair's housing at the back, west end.
	_rbox(pk, kit, Vector3(11.0, yr, -13.8), Vector3(15.6, yr + 3.0, -9.6), [wash, wash, null, room(Color(0.35, 0.35, 0.34), ROOM_BROKEN), wash, wash])
	_blk(pk, kit, "metal", Vector3(12.2, yr + 0.05, -9.59), Vector3(13.1, yr + 2.1, -9.57), Color(0.35, 0.36, 0.35))
	_blk(pk, kit, "metal", Vector3(14.0, yr + 1.8, -9.59), Vector3(15.2, yr + 2.5, -9.57), Color(0.25, 0.26, 0.25))
	for k in range(5):
		_blk(pk, kit, "metal", Vector3(14.05, yr + 1.85 + 0.13 * float(k), -9.6), Vector3(15.15, yr + 1.9 + 0.13 * float(k), -9.54), Color(0.4, 0.4, 0.4))
	for v in [Vector3(4.0, yr, -8.0), Vector3(7.5, yr, -12.5), Vector3(17.0, yr, -4.0)]:
		pk.tube(kit, "metal", v, v + Vector3(0, 0.9, 0), 0.14, 0.14, 8, Color(0.5, 0.5, 0.5), false)
		pk.tube(kit, "metal", v + Vector3(0, 0.9, 0), v + Vector3(0, 1.05, 0), 0.22, 0.05, 8, Color(0.45, 0.45, 0.45), true)
	var am := Vector3(16.5, yr, -12.0)
	_rod(pk, kit, "metal", am, am + Vector3(0, 5.5, 0), 0.04, 6, Color(0.55, 0.55, 0.55), true)
	for k in range(4):
		var ay: float = 4.0 + 0.4 * float(k)
		_rod(pk, kit, "metal", am + Vector3(-0.6 + 0.08 * k, ay, 0), am + Vector3(0.6 - 0.08 * k, ay, 0), 0.012, 4, Color(0.55, 0.55, 0.55), true)
	# The old sign on its frame along the front: KRONBURGER BAUSPARKASSE, rusting.
	var sx0 := 1.0
	var sx1 := 17.6
	var sy0: float = yr + ph + 0.5
	var sy1: float = sy0 + 1.8
	var sz := -1.2
	_blk(pk, kit, "scrap", Vector3(sx0, sy0, sz - 0.06), Vector3(sx1, sy1, sz), worn(Color(0.93, 0.92, 0.88), 0.27))
	var k2 := 0
	var fx: float = sx0 + 0.4
	while fx < sx1:
		pk.beam(kit, "scrap", Vector3(fx, yr, sz - 0.14), Vector3(fx, sy1, sz - 0.14), 0.08, 0.08, worn(Color(0.3, 0.3, 0.3), 0.7))
		pk.beam(kit, "scrap", Vector3(fx, yr, sz - 1.6), Vector3(fx, sy0 + 0.9, sz - 0.14), 0.06, 0.06, worn(Color(0.3, 0.3, 0.3), 0.7))
		k2 += 1
		fx += 2.2
	for y in [sy0 + 0.2, sy1 - 0.2]:
		pk.beam(kit, "scrap", Vector3(sx0, y, sz - 0.14), Vector3(sx1, y, sz - 0.14), 0.07, 0.07, worn(Color(0.3, 0.3, 0.3), 0.7))
	_lbl(labels, "KRONBURGER BAUSPARKASSE", Vector3((sx0 + sx1) * 0.5, (sy0 + sy1) * 0.5, sz + 0.03), Vector3(0, 0, 1), 1.0, Color(0.66, 0.17, 0.12), sx1 - sx0 - 0.6)


## Rubble on the knocked-down bays' tops and in the rooms laid open, lumps at the broken ends.
static func _ruin_debris(pk: PropKit, kit: Dictionary, tops: Array, n: int, rng: RandomNumberGenerator) -> void:
	var brk := _ruin_broken()
	for i in range(4):
		var y := _ry(int(tops[i]))
		var x0 := _rx(i)
		for c in range(9):
			var p := Vector3(rng.randf_range(x0 + 0.3, x0 + RUIN_BAY - 0.3), y, rng.randf_range(-14.0, -0.6))
			var s: float = rng.randf_range(0.2, 0.7)
			_chunk(pk, kit, "room", p + Vector3(0, s * 0.35, 0), Basis(UP, rng.randf() * TAU), Vector3(s, s * 0.5, s * 0.8), 0.35, rng,
					brk if c % 3 else _ruin_finish(i >> 1, int(tops[i]), false)[0], true)
	# Office leftovers in the stripped rooms: a desk, a filing cabinet, a hanging lamp.
	for i in range(5):
		for k in range(int(tops[i])):
			if _ruin_face(i, k, tops, n) != 1:
				continue
			var x0 := _rx(i)
			var y := _ry(k)
			if rng.randf() < 0.6:
				var dx: float = rng.randf_range(x0 + 0.5, x0 + 2.0)
				_blk(pk, kit, "plastic", Vector3(dx, y + 0.7, -3.2), Vector3(dx + 1.5, y + 0.74, -2.4), Color(0.6, 0.45, 0.3))
				for lx in [dx + 0.05, dx + 1.4]:
					_blk(pk, kit, "metal", Vector3(lx, y, -3.15), Vector3(lx + 0.05, y + 0.7, -2.45), Color(0.3, 0.3, 0.3))
			if rng.randf() < 0.5:
				var fx: float = rng.randf_range(x0 + 0.3, x0 + RUIN_BAY - 0.8)
				_blk(pk, kit, "metal", Vector3(fx, y, -5.85), Vector3(fx + 0.47, y + 1.3, -5.25), Color(0.55, 0.57, 0.55))
			var lp := Vector3(x0 + RUIN_BAY * 0.5, _ry(k + 1) - RUIN_SLAB, -3.0)
			_rod(pk, kit, "steel", lp, lp - Vector3(0, 0.6, 0), 0.008, 4, BLACK, false)
			pk.lathe(kit, "plastic", lp - Vector3(0, 0.85, 0), [Vector2(0.25, 0.0), Vector2(0.18, 0.15), Vector2(0.04, 0.25), Vector2(0.001, 0.26)], 10,
					Color(0.85, 0.55, 0.15))


static func ruin_building_solids(storeys: int) -> Array:
	var n: int = clampi(storeys, 3, 12)
	var tops := _ruin_tops(n)
	var s: Array = []
	for i in range(RUIN_BAYS):
		var y: float = _ry(int(tops[i])) + (0.9 if int(tops[i]) == n else 0.0)
		s.append(_solid_lh(Vector3(_rx(i), -0.4, -RUIN_DEPTH), Vector3(_rx(i) + RUIN_BAY, y, 0.0)))
	s.append(_solid_lh(Vector3(_rx(7) + 0.2, 0.0, 0.0), Vector3(_rx(8) - 0.2, RUIN_Y0, 0.9)))
	s.append(_solid_lh(Vector3(_rx(7) - 0.4, 3.3, 0.0), Vector3(_rx(8) + 0.4, 3.5, 2.3)))
	for px in [_rx(7) - 0.1, _rx(8) + 0.1]:
		s.append(_solid_lh(Vector3(px - 0.08, 0.0, 1.92), Vector3(px + 0.08, 3.3, 2.08)))
	return s


# ======================================================================================
#  Rubble, skips, bales, scrap heaps, sorting bins, drums and tyres
# ======================================================================================

const SKIP_PAINTS := [Color(0.13, 0.3, 0.58), Color(0.9, 0.45, 0.08), Color(0.95, 0.74, 0.1), Color(0.2, 0.4, 0.22), Color(0.45, 0.46, 0.47), Color(0.62, 0.12, 0.09)]


## A heap of demolition rubble, `w` x `d` x `h` (life), on the ground round the origin: a lumpy mound of crushed concrete
## (dust and plaster in patches), lumps of concrete, slabs broken off with their wallpaper or tiles still on, rebar, bricks,
## timber, a radiator, pipes. Seeded.
static func rubble_heap(pk: PropKit, kit: Dictionary, w: float, d: float, h: float, seed_v: int) -> void:
	var rng := _rng(seed_v, 11)
	var hx: float = w * 0.5
	var hz: float = d * 0.5
	var s: int = seed_v & 0xFFFF
	var nx: int = clampi(int(w / 0.8), 8, 24)
	var nz: int = clampi(int(d / 0.8), 8, 24)
	var colfn := func(x: float, z: float, _y: float) -> Color:
		return _rubble_col(x, z, s)
	_mound(pk, kit, "room", hx, hz, h, nx, nz, s, colfn, true, 0.3)
	var brk := _ruin_broken()
	var n_chunks: int = clampi(int(w * d * 0.4), 18, 80)
	for c in range(n_chunks):
		var p := _mound_spot(rng, hx, hz, h, s, 0.95)
		var sz: float = rng.randf_range(0.15, 0.7) * (1.0 if rng.randf() < 0.85 else 1.8)
		var nrm := _mound_n(p.x, p.z, hx, hz, h, s)
		_chunk(pk, kit, "room", p + nrm * (sz * 0.15), _up_basis(nrm.lerp(Vector3(rng.randf() - 0.5, 1, rng.randf() - 0.5), 0.5), rng.randf() * TAU),
				Vector3(sz, sz * rng.randf_range(0.4, 0.8), sz * rng.randf_range(0.6, 1.0)), 0.3, rng, _lump_col(rng), true)
	# Slabs broken off, with what was on them: wallpaper, tiles, a floor.
	var n_slabs: int = clampi(int(w * d / 25.0), 3, 10)
	for c in range(n_slabs):
		var p2 := _mound_spot(rng, hx, hz, h, s, 0.85)
		var nrm2 := _mound_n(p2.x, p2.z, hx, hz, h, s)
		var tilt := Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf_range(0.2, 1.1))
		var b: Basis = tilt * _up_basis(nrm2, rng.randf() * TAU)
		var size := Vector3(rng.randf_range(0.8, 2.4), rng.randf_range(0.15, 0.24), rng.randf_range(0.6, 1.6))
		var pap: Array = RUIN_PAPER[rng.randi() % RUIN_PAPER.size()]
		var fl: Array = RUIN_FLOORS[rng.randi() % RUIN_FLOORS.size()]
		var top_c: Color = room(pap[1], pap[0]) if rng.randf() < 0.6 else room(fl[1], fl[0])
		_slab_piece(pk, kit, p2 + nrm2 * 0.05, b, size, top_c, _ruin_ceiling(), brk)
		for k in range(rng.randi_range(1, 3)):
			var e: Vector3 = p2 + b.x * (size.x * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)) + b.z * rng.randf_range(-0.4, 0.4) * size.z
			var dir: Vector3 = (b.x * signf((e - p2).dot(b.x)) + Vector3(rng.randf() - 0.5, rng.randf_range(-0.6, 0.6), rng.randf() - 0.5) * 0.8).normalized()
			_rods(pk, kit, "scrap", [e - dir * 0.1, e + dir * 0.4, e + dir * 0.8 + Vector3(0, -0.25, 0)], 0.012, 4, worn(RUST, 0.95))
	# Bricks in clusters, timber, a radiator, a pipe.
	for c in range(clampi(int(w * d / 30.0), 2, 6)):
		var bp := _mound_spot(rng, hx, hz, h, s, 0.8)
		for k in range(rng.randi_range(3, 7)):
			var q: Vector3 = bp + Vector3(rng.randf_range(-0.4, 0.4), 0.02, rng.randf_range(-0.4, 0.4))
			q.y = _mound_y(q.x, q.z, hx, hz, h, s) + 0.02
			_box(pk, kit, "brick", q, _up_basis(_mound_n(q.x, q.z, hx, hz, h, s), rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)),
					Vector3(0.24, 0.071, 0.115), Color(0.62, 0.3, 0.2).darkened(rng.randf() * 0.2))
	for c in range(rng.randi_range(1, 3)):
		var tp := _mound_spot(rng, hx, hz, h, s, 0.8)
		var td := Vector3(rng.randf() - 0.5, rng.randf_range(-0.2, 0.35), rng.randf() - 0.5).normalized()
		var tl: float = rng.randf_range(1.5, 3.2)
		pk.beam(kit, "timber", tp - td * tl * 0.5 + Vector3(0, 0.1, 0), tp + td * tl * 0.5 + Vector3(0, 0.1, 0), 0.12, 0.14, Color(0.6, 0.45, 0.3), Vector3.ZERO, uvk)
	if rng.randf() < 0.7:
		var rp := _mound_spot(rng, hx, hz, h, s, 0.7)
		_box(pk, kit, "metal", rp + Vector3(0, 0.2, 0), _up_basis(_mound_n(rp.x, rp.z, hx, hz, h, s), rng.randf() * TAU) * Basis(Vector3.BACK, 0.9),
				Vector3(1.2, 0.55, 0.12), Color(0.82, 0.8, 0.74))
	var pp := _mound_spot(rng, hx, hz, h, s, 0.8)
	var pd := Vector3(rng.randf() - 0.5, rng.randf_range(0.0, 0.5), rng.randf() - 0.5).normalized()
	pk.tube(kit, "scrap", pp - pd * 1.0, pp + pd * 1.4, 0.07, 0.07, 8, worn(Color(0.4, 0.4, 0.38), 0.8), true)


## Rubble's colour at (x, z): patches of the RUBBLE_TINTS, each triangle a shade off (scrap_room's broken concrete).
static func _rubble_col(x: float, z: float, s: int) -> Color:
	var t: float = _vn(x * 0.4 + 5.0, z * 0.4, s + 3)
	var i: int = int(t * 4.99)
	var c: Color = (RUBBLE_TINTS[i] as Color).lerp(RUBBLE_TINTS[(i + 1) % RUBBLE_TINTS.size()], fposmod(t * 4.99, 1.0))
	return room(c.darkened(0.14 * _h2(int(floor(x * 2.5)), int(floor(z * 2.5)), s)), ROOM_BROKEN)


## A lump of rubble's colour: mostly crushed concrete, some brick, plaster, a bit of facade.
static func _lump_col(rng: RandomNumberGenerator) -> Color:
	var r: float = rng.randf()
	if r < 0.6:
		return room(Color(0.52, 0.51, 0.48).darkened(rng.randf() * 0.15), ROOM_BROKEN)
	if r < 0.75:
		return room(Color(0.56, 0.32, 0.24), ROOM_BROKEN)
	if r < 0.88:
		return room(Color(0.7, 0.68, 0.62), ROOM_BROKEN)
	return room(RUIN_WASCH.darkened(0.1), ROOM_WASCHBETON)


## Mixed scrap's paint by two draws (0..1): rust, dark and bright steel, now and then a car's or an appliance's paint.
static func _scrap_col(u: float, t: float) -> Color:
	if u < 0.38:
		return worn(RUST.lerp(Color(0.3, 0.2, 0.14), t), 0.8 + 0.2 * t)
	if u < 0.62:
		return worn(Color(0.3, 0.3, 0.29).lerp(Color(0.18, 0.17, 0.16), t), 0.55 + 0.3 * t)
	if u < 0.76:
		return worn(Color(0.52, 0.52, 0.5).lerp(Color(0.42, 0.4, 0.38), t), 0.4 + 0.3 * t)
	if u < 0.94:
		return worn(CAR_PAINTS[int(u * 997.0) % CAR_PAINTS.size()], 0.35 + 0.4 * t)
	return worn(Color(0.86, 0.86, 0.83), 0.3 + 0.3 * t)


## A point on a mound's surface (r < `reach` of its half sizes).
static func _mound_spot(rng: RandomNumberGenerator, hx: float, hz: float, h: float, s: int, reach: float) -> Vector3:
	var a: float = rng.randf() * TAU
	var r: float = sqrt(rng.randf()) * reach
	var x: float = cos(a) * r * hx
	var z: float = sin(a) * r * hz
	return Vector3(x, _mound_y(x, z, hx, hz, h, s), z)


## A demolition skip (Absetzmulde, 4m along z at the top, 2.7 at the floor, 1.85 wide, 1.55 high) heaped with rubble: the
## body with its sloped ends, the top flange, stiffeners, the lifting trunnions and their brackets, skids, BRANDT stencilled
## on its sides. Seeded colour.
static func skip(pk: PropKit, kit: Dictionary, seed_v: int) -> void:
	var rng := _rng(seed_v, 21)
	var col := worn(SKIP_PAINTS[rng.randi() % SKIP_PAINTS.size()], rng.randf_range(0.3, 0.55))
	var hw := 0.925
	var top := 1.55
	var ol := PackedVector2Array([Vector2(-1.35, 0.12), Vector2(1.35, 0.12), Vector2(1.95, top), Vector2(-1.95, top)])
	_extrude_zy(pk, kit, "scrap", ol, -hw, hw, 0.02, col)
	# The flange round the top, stiffeners down the sides, skids under it.
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "scrap", Vector3(sx * hw - 0.04, top - 0.12, -1.97), Vector3(sx * hw + 0.04, top + 0.03, 1.97), col.darkened(0.1))
		for z in [-1.0, -0.33, 0.33, 1.0]:
			_blk(pk, kit, "scrap", Vector3(sx * (hw + 0.025) - 0.03, 0.15, z - 0.05), Vector3(sx * (hw + 0.025) + 0.03, top - 0.12, z + 0.05), col.darkened(0.05))
		_blk(pk, kit, "scrap", Vector3(sx * 0.6 - 0.07, 0.0, -1.3), Vector3(sx * 0.6 + 0.07, 0.13, 1.3), worn(Color(0.2, 0.2, 0.2), 0.7))
		# The trunnion's bracket and pin, a little forward of the middle.
		var tp := Vector3(sx * (hw + 0.03), top - 0.45, -0.15)
		_blk(pk, kit, "scrap", tp + Vector3(-0.03 if sx < 0.0 else 0.0, -0.3, -0.2), tp + Vector3(0.0 if sx < 0.0 else 0.03, 0.15, 0.2), col.darkened(0.15))
		pk.tube(kit, "metal", tp - Vector3(sx * 0.015, 0, 0), tp + Vector3(sx * 0.16, 0, 0), 0.07, 0.07, 10, Color(0.35, 0.35, 0.34), true)
		pk.tube(kit, "metal", tp + Vector3(sx * 0.16, 0, 0), tp + Vector3(sx * 0.2, 0, 0), 0.11, 0.11, 10, Color(0.35, 0.35, 0.34), true)
		_blk(pk, kit, "scrap", Vector3(sx * (hw + 0.055) - 0.012, 0.62, -0.75), Vector3(sx * (hw + 0.055) + 0.012, 1.02, 0.75), worn(Color(0.92, 0.92, 0.88), 0.3))
		_pixel_text(pk, kit, "scrap", Vector3(sx * (hw + 0.092), 0.82, 0.0), Vector3(0, 0, -sx), UP, 0.045, "BRANDT", worn(Color(0.08, 0.08, 0.08), 0.2))
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "scrap", Vector3(-hw, top - 0.12, sz * 1.95 - 0.04), Vector3(hw, top + 0.03, sz * 1.95 + 0.04), col.darkened(0.1))
	# The rubble heaped in it.
	var s: int = seed_v & 0xFFFF
	var hx := 0.85
	var hz := 1.85
	var h: float = rng.randf_range(0.3, 0.6)
	var colfn := func(x: float, z: float, _y: float) -> Color:
		return _rubble_col(x, z, s)
	var sv := _push(pk, Transform3D(Basis(), Vector3(0, top - 0.04, 0)))
	_mound(pk, kit, "room", hx, hz, h, 8, 12, s, colfn, true, 0.35, 0.06)
	for c in range(14):
		var p := _mound_spot(rng, hx, hz, h, s, 0.9)
		var sz: float = rng.randf_range(0.15, 0.45)
		_chunk(pk, kit, "room", p + Vector3(0, sz * 0.2, 0), Basis(UP, rng.randf() * TAU), Vector3(sz, sz * 0.6, sz * 0.8), 0.3, rng, _lump_col(rng), true)
	for c in range(2):
		var p3 := _mound_spot(rng, hx, hz, h, s, 0.6)
		var dd := Vector3(rng.randf() - 0.5, rng.randf_range(0.0, 0.5), rng.randf() - 0.5).normalized()
		pk.beam(kit, "timber", p3 - dd * 0.9, p3 + dd * 0.9, 0.1, 0.05, Color(0.62, 0.48, 0.32), Vector3.ZERO, uvk)
	_pop(pk, sv)


## A wall of crushed car bales along x from 0 to `length` (life), `layers` high (0.66 each), one bale (2m) deep from its
## face at z 0 back to z -2, staggered like brickwork, each bale a little skew, gaps in the top layer.
static func bale_wall(pk: PropKit, kit: Dictionary, length: float, layers: int, seed_v: int) -> void:
	var rng := _rng(seed_v, 31)
	var y := 0.0
	for j in range(maxi(layers, 1)):
		var bh: float = rng.randf_range(0.62, 0.7)
		var x: float = 0.04 + (0.0 if j % 2 == 0 else rng.randf_range(0.5, 0.8))
		while x < length - 0.6:
			var bw: float = minf(rng.randf_range(1.3, 1.6), length - 0.02 - x)
			if bw < 0.6:
				break
			if j == layers - 1 and rng.randf() < 0.2:
				x += bw + 0.06
				continue
			var c := Vector3(x + bw * 0.5, y + bh * 0.5, -1.0 + rng.randf_range(-0.04, 0.02))
			var b := Basis(UP, rng.randf_range(-0.05, 0.05)) * Basis(Vector3.BACK, rng.randf_range(-0.025, 0.025))
			_bale(pk, kit, "scrap", c, b, Vector3(bw - 0.05, bh, 1.95), rng)
			x += bw + rng.randf_range(0.0, 0.06)
		y += bh


## A heap of mixed scrap `w` x `d` x `h` (life) round the origin: a lumpy mound of rusty shredded steel, wrecked cars on and in
## it (some flattened, some upside down), girders, pipes, sheet, drums, tyres, a washing machine. Seeded.
static func scrap_heap(pk: PropKit, kit: Dictionary, w: float, d: float, h: float, seed_v: int) -> void:
	var rng := _rng(seed_v, 41)
	var hx: float = w * 0.5
	var hz: float = d * 0.5
	var s: int = seed_v & 0xFFFF
	var colfn := func(x: float, z: float, _y: float) -> Color:
		return _scrap_col(_h2(int(floor(x * 2.2)), int(floor(z * 2.2)), s), _vn(x * 0.5 + 1.0, z * 0.5 + 7.0, s + 9))
	_mound(pk, kit, "scrap", hx, hz, h, clampi(int(w / 0.7), 12, 34), clampi(int(d / 0.7), 12, 34), s, colfn, false, 0.4)
	# Crumpled lumps of sheet and shredded steel all over it.
	for c in range(clampi(int(w * d * 0.45), 40, 160)):
		var pl := _mound_spot(rng, hx, hz, h, s, 0.97)
		var sz: float = rng.randf_range(0.25, 0.9)
		var nl := _mound_n(pl.x, pl.z, hx, hz, h, s)
		_chunk(pk, kit, "scrap", pl + nl * (sz * 0.1), _up_basis(nl.lerp(Vector3(rng.randf() - 0.5, 0.5, rng.randf() - 0.5), 0.6), rng.randf() * TAU),
				Vector3(sz, sz * rng.randf_range(0.25, 0.6), sz * rng.randf_range(0.5, 1.0)), 0.45, rng, _scrap_col(rng.randf(), rng.randf()))
	# Cars.
	var n_cars: int = clampi(int(w * d / 45.0), 3, 10)
	for c in range(n_cars):
		var p := _mound_spot(rng, hx, hz, h, s, 0.78)
		var nrm := _mound_n(p.x, p.z, hx, hz, h, s)
		var b: Basis = _up_basis(nrm.lerp(Vector3(rng.randf() - 0.5, 0.6, rng.randf() - 0.5), 0.35), rng.randf() * TAU)
		var flip: bool = rng.randf() < 0.25
		var crush: float = rng.randf_range(0.2, 1.0)
		var kind: int = rng.randi() % CAR_KINDS.size()
		var off: Vector3 = -b.y * 0.35
		if flip:
			b = b * Basis(Vector3.BACK, PI)
			off = -b.y * (1.4 - crush * 0.45)
		var wheels: int = rng.randi() & 15
		_car(pk, kit, "scrap", Transform3D(b, p + off), kind, CAR_PAINTS[rng.randi() % CAR_PAINTS.size()], rng.randf_range(0.45, 0.95), crush, rng.randi(), wheels)
	# Girders, pipes and bars sticking out.
	for c in range(clampi(int(w * d / 7.0), 12, 50)):
		var p2 := _mound_spot(rng, hx, hz, h, s, 0.9)
		var dd := Vector3(rng.randf() - 0.5, rng.randf_range(-0.1, 0.7), rng.randf() - 0.5).normalized()
		var l: float = rng.randf_range(1.2, 4.5)
		var a: Vector3 = p2 - dd * l * 0.45
		var bb: Vector3 = p2 + dd * l * 0.55
		var kind2: float = rng.randf()
		var cc := worn(RUST.lerp(Color(0.35, 0.33, 0.3), rng.randf()), rng.randf_range(0.7, 1.0))
		if kind2 < 0.4:
			SW._ibeam(pk, kit, "scrap", a, bb, rng.randf_range(0.14, 0.3), rng.randf_range(0.08, 0.15), cc, Vector3(rng.randf() - 0.5, 1, rng.randf() - 0.5))
		elif kind2 < 0.7:
			pk.tube(kit, "scrap", a, bb, rng.randf_range(0.04, 0.16), rng.randf_range(0.04, 0.16), 8, cc, true)
		else:
			pk.beam(kit, "scrap", a, bb, rng.randf_range(0.03, 0.08), rng.randf_range(0.03, 0.08), cc)
	# Sheets: bent panels of cladding and car doors.
	for c in range(clampi(int(w * d / 14.0), 5, 24)):
		var p3 := _mound_spot(rng, hx, hz, h, s, 0.85)
		var nrm3 := _mound_n(p3.x, p3.z, hx, hz, h, s)
		var b3: Basis = _up_basis(nrm3, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.3, 1.3))
		var sw: float = rng.randf_range(0.8, 2.2)
		var sh: float = rng.randf_range(0.6, 1.4)
		var bend: float = rng.randf_range(-0.35, 0.35)
		var sc := worn((CAR_PAINTS[rng.randi() % CAR_PAINTS.size()] as Color) if rng.randf() < 0.5 else RUST, rng.randf_range(0.4, 1.0))
		var q: Array = [p3 + b3 * Vector3(-sw * 0.5, 0, 0), p3 + b3 * Vector3(0, 0, bend), p3 + b3 * Vector3(sw * 0.5, 0, 0),
				p3 + b3 * Vector3(sw * 0.5, sh, 0), p3 + b3 * Vector3(0, sh, bend), p3 + b3 * Vector3(-sw * 0.5, sh, 0)]
		var nn: Vector3 = b3.z
		pk.panel(kit, "scrap", [q[0], q[1], q[4], q[5]], nn, sc, sc.darkened(0.2))
		pk.panel(kit, "scrap", [q[1], q[2], q[3], q[4]], nn, sc, sc.darkened(0.2))
	# Drums, tyres, a washing machine or a fridge.
	for c in range(rng.randi_range(2, 6)):
		var p4 := _mound_spot(rng, hx, hz, h, s, 0.85)
		var b4: Basis = _up_basis(Vector3(rng.randf() - 0.5, rng.randf_range(0.0, 1.0), rng.randf() - 0.5), rng.randf() * TAU)
		_drum(pk, kit, "scrap", p4 - b4.y * 0.2, b4, SKIP_PAINTS[rng.randi() % SKIP_PAINTS.size()], rng.randf_range(0.5, 0.95))
	for c in range(rng.randi_range(2, 5)):
		var p5 := _mound_spot(rng, hx, hz, h, s, 0.9)
		var tb: Basis = _up_basis(_mound_n(p5.x, p5.z, hx, hz, h, s).lerp(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5), rng.randf() * 0.8), rng.randf() * TAU)
		_old_tyre(pk, kit, p5 + tb.y * 0.05, 0.19, 0.31, 0.2, rng.randf(), tb)
	for c in range(rng.randi_range(1, 3)):
		var p7 := _mound_spot(rng, hx, hz, h, s, 0.85)
		var b7: Basis = _up_basis(_mound_n(p7.x, p7.z, hx, hz, h, s).lerp(Vector3(rng.randf() - 0.5, 0.3, rng.randf() - 0.5), 0.5), rng.randf() * TAU)
		if c == 0 and rng.randf() < 0.6:
			_bathtub(pk, kit, "scrap", Transform3D(b7, p7 - b7.y * 0.1))
		else:
			_bike(pk, kit, "scrap", Transform3D(b7, p7), rng)
	for c in range(rng.randi_range(1, 2)):
		var p6 := _mound_spot(rng, hx, hz, h, s, 0.8)
		var b6: Basis = _up_basis(_mound_n(p6.x, p6.z, hx, hz, h, s).lerp(Vector3(rng.randf() - 0.5, 0.2, rng.randf() - 0.5), 0.6), rng.randf() * TAU)
		var ws := Vector3(0.6, 0.85, 0.6) if rng.randf() < 0.5 else Vector3(0.6, 1.5, 0.62)
		_box(pk, kit, "scrap", p6 + b6.y * (ws.y * 0.3), b6, ws, worn(Color(0.88, 0.88, 0.85), rng.randf_range(0.3, 0.6)))
		_box(pk, kit, "scrap", p6 + b6.y * (ws.y * 0.3 + 0.05) + b6.z * (ws.z * 0.5 + 0.012), b6, Vector3(ws.x * 0.7, ws.x * 0.7 if ws.y < 1.0 else ws.y * 0.4, 0.025),
				worn(Color(0.2, 0.2, 0.22), 0.3))


static func scrap_heap_solids(w: float, d: float, h: float, _seed_v: int) -> Array:
	var s: Array = []
	s.append(_solid_lh(Vector3(-w * 0.43, -0.2, -d * 0.43), Vector3(w * 0.43, h * 0.4, d * 0.43)))
	s.append(_solid_lh(Vector3(-w * 0.3, h * 0.4, -d * 0.3), Vector3(w * 0.3, h * 0.72, d * 0.3)))
	s.append(_solid_lh(Vector3(-w * 0.15, h * 0.72, -d * 0.15), Vector3(w * 0.15, h * 0.92, d * 0.15)))
	return s


const SORT_KINDS := [["KUPFER", Color(0.72, 0.38, 0.2), 0.3], ["MESSING", Color(0.8, 0.64, 0.26), 0.25], ["ALU", Color(0.78, 0.79, 0.8), 0.15],
		["V2A", Color(0.62, 0.63, 0.64), 0.12], ["KABEL", Color(0.08, 0.08, 0.08), 0.3], ["BLEI", Color(0.4, 0.42, 0.44), 0.3]]


## A roll-off sorting bin (3m along z, 1.9 wide, 1.4 high) of one sorted metal: the hook frame at its front (-z), rails and
## rollers under it, ribs, its load heaped above the rim, the metal's name on a board on its side and front.
static func sorting_bin(pk: PropKit, kit: Dictionary, seed_v: int) -> void:
	var rng := _rng(seed_v, 51)
	var sk: Array = SORT_KINDS[rng.randi() % SORT_KINDS.size()]
	var col := worn(SKIP_PAINTS[rng.randi() % SKIP_PAINTS.size()], rng.randf_range(0.3, 0.6))
	var hw := 0.95
	var hl := 1.5
	var y0 := 0.22
	var y1 := 1.45
	# The box: walls, floor; the inside darker.
	_blk(pk, kit, "scrap", Vector3(-hw, y0, -hl), Vector3(hw, y1 - 0.25, hl), col)
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "scrap", Vector3(sx * hw - (0.04 if sx > 0.0 else 0.0), y1 - 0.25, -hl), Vector3(sx * hw + (0.0 if sx > 0.0 else 0.04), y1, hl), col)
		for z in [-1.0, 0.0, 1.0]:
			_blk(pk, kit, "scrap", Vector3(sx * (hw + 0.025) - 0.025, y0, z - 0.05), Vector3(sx * (hw + 0.025) + 0.025, y1, z + 0.05), col.darkened(0.08))
		_blk(pk, kit, "scrap", Vector3(sx * 0.55 - 0.07, 0.0, -hl + 0.1), Vector3(sx * 0.55 + 0.07, y0, hl), worn(Color(0.18, 0.18, 0.18), 0.6))
		pk.tube(kit, "metal", Vector3(sx * 0.55 - 0.08, 0.13, hl - 0.1), Vector3(sx * 0.55 + 0.08, 0.13, hl - 0.1), 0.13, 0.13, 10, Color(0.3, 0.3, 0.3), true)
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "scrap", Vector3(-hw + 0.04, y1 - 0.25, sz * hl - (0.04 if sz > 0.0 else 0.0)), Vector3(hw - 0.04, y1, sz * hl + (0.0 if sz > 0.0 else 0.04)), col)
	# The hook frame at the front.
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "scrap", Vector3(sx * 0.4, y0, -hl - 0.02), Vector3(sx * 0.12, 1.6, -hl - 0.3), 0.12, 0.12, col.darkened(0.15))
	pk.tube(kit, "metal", Vector3(-0.2, 1.6, -hl - 0.3), Vector3(0.2, 1.6, -hl - 0.3), 0.05, 0.05, 8, Color(0.3, 0.3, 0.3), true)
	# The load.
	var s: int = seed_v & 0xFFFF
	var kc: Color = sk[1]
	var kw: float = sk[2]
	var colfn := func(x: float, z: float, _y: float) -> Color:
		return worn(kc.darkened(0.25 * _vn(x * 3.0, z * 3.0, s)), kw + 0.2 * _vn(x * 2.0 + 4.0, z * 2.0, s))
	var sv := _push(pk, Transform3D(Basis(), Vector3(0, y1 - 0.05, 0)))
	_mound(pk, kit, "scrap", hw - 0.04, hl - 0.04, rng.randf_range(0.25, 0.45), 8, 10, s, colfn, false, 0.45, 0.06)
	for c in range(16):
		var p := _mound_spot(rng, hw - 0.1, hl - 0.1, 0.3, s, 0.8)
		var b := Basis(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized(), rng.randf() * TAU)
		if sk[0] == "KUPFER" or sk[0] == "KABEL":
			pk.tyre(kit, "scrap", p + Vector3(0, 0.08, 0), rng.randf_range(0.15, 0.3), rng.randf_range(0.2, 0.36), 0.06, 8, worn(kc, kw), b)
		else:
			_box(pk, kit, "scrap", p + Vector3(0, 0.08, 0), b, Vector3(rng.randf_range(0.1, 0.6), rng.randf_range(0.03, 0.12), rng.randf_range(0.08, 0.3)), worn(kc.lightened(0.05), kw))
	_pop(pk, sv)
	# The name boards.
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "plastic", Vector3(sx * (hw + 0.05) - 0.01, 0.75, -0.6), Vector3(sx * (hw + 0.05) + 0.01, 1.15, 0.6), Color(0.94, 0.94, 0.92))
		_pixel_text(pk, kit, "plastic", Vector3(sx * (hw + 0.086), 0.95, 0.0), Vector3(0, 0, -sx), UP, 0.055, sk[0], Color(0.08, 0.08, 0.08))
	_blk(pk, kit, "plastic", Vector3(-0.55, 0.62, -hl - 0.06), Vector3(0.55, 0.98, -hl - 0.04), Color(0.94, 0.94, 0.92))
	_pixel_text(pk, kit, "plastic", Vector3(0, 0.8, -hl - 0.085), Vector3.LEFT, UP, 0.05, sk[0], Color(0.08, 0.08, 0.08))


## Drums on two pallets (four on each, one pallet with a second tier) and a couple lying in front, mixed colours, dented.
static func drum_stack(pk: PropKit, kit: Dictionary, seed_v: int) -> void:
	var rng := _rng(seed_v, 61)
	for px in [-0.68, 0.68]:
		_pallet(pk, kit, Vector3(px, 0, -0.5), rng)
		for dx in [-0.31, 0.31]:
			for dz in [-0.26, 0.26]:
				var b := Basis(UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.03, 0.03))
				_drum(pk, kit, "scrap", Vector3(px + dx, 0.144, -0.5 + dz), b, SKIP_PAINTS[rng.randi() % SKIP_PAINTS.size()], rng.randf_range(0.3, 0.9))
				if px > 0.0 and rng.randf() < 0.75:
					_drum(pk, kit, "scrap", Vector3(px + dx, 1.03, -0.5 + dz), Basis(UP, rng.randf() * TAU), SKIP_PAINTS[rng.randi() % SKIP_PAINTS.size()], rng.randf_range(0.3, 0.9))
	for k in range(rng.randi_range(1, 3)):
		var a: float = rng.randf_range(-0.5, 0.5)
		var b2 := Basis(UP, a) * Basis(Vector3.BACK, PI * 0.5)
		_drum(pk, kit, "scrap", Vector3(-1.0 + 0.95 * float(k) + 0.44, 0.29, 0.7 + rng.randf_range(-0.1, 0.2)), b2, SKIP_PAINTS[rng.randi() % SKIP_PAINTS.size()],
				rng.randf_range(0.5, 1.0))


static func _pallet(pk: PropKit, kit: Dictionary, c: Vector3, rng: RandomNumberGenerator) -> void:
	var tc := Color(0.62, 0.5, 0.36).darkened(rng.randf() * 0.2)
	for z in [-0.44, 0.0, 0.44]:
		_box(pk, kit, "timber", c + Vector3(0, 0.05, z), Basis(), Vector3(1.2, 0.1, 0.1), tc.darkened(0.1))
	for k in range(5):
		_box(pk, kit, "timber", c + Vector3(-0.5 + 0.25 * float(k), 0.122, 0), Basis(), Vector3(0.14, 0.022, 1.0), tc)


## A pile of old tyres: columns of car tyres stacked up, a heap lying about, two lorry tyres leaning on it.
static func tyre_pile(pk: PropKit, kit: Dictionary, seed_v: int) -> void:
	var rng := _rng(seed_v, 71)
	for col in range(3):
		var c := Vector3(-0.85 + 0.85 * float(col) + rng.randf_range(-0.08, 0.08), 0, -0.75 + rng.randf_range(-0.1, 0.1))
		var nh: int = rng.randi_range(3, 7)
		for k in range(nh):
			var tip := Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf_range(0.0, 0.06))
			_old_tyre(pk, kit, c + Vector3(rng.randf_range(-0.04, 0.04), 0.1 + 0.2 * float(k), rng.randf_range(-0.04, 0.04)), 0.19, 0.31, 0.2, rng.randf(), tip)
	for k in range(rng.randi_range(5, 9)):
		var p := Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(0.0, 1.2))
		var tip2 := Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf_range(0.0, 0.5))
		_old_tyre(pk, kit, p + Vector3(0, 0.12 + 0.15 * float(k % 2), 0), 0.19 if k % 3 else 0.21, 0.31 if k % 3 else 0.36, 0.2, rng.randf(), tip2)
	for k in range(2):
		var p2 := Vector3(-0.7 + 1.3 * float(k), 0.5, 0.95)
		_old_tyre(pk, kit, p2, 0.29, 0.52, 0.3, rng.randf(), Basis(UP, rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, PI * 0.5 - 0.25))


## An old bath in frame t: an oval tub (a lathe squashed along z, hollow), white enamel chipped to black iron, on four feet.
static func _bathtub(pk: PropKit, kit: Dictionary, key: String, t: Transform3D) -> void:
	var c := worn(Color(0.88, 0.87, 0.82), 0.3)
	var ci := worn(Color(0.92, 0.91, 0.86), 0.18)
	var s := _push(pk, t * Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 2.3)), Vector3.ZERO))
	_lathe_c(pk, kit, key, Vector3(0, 0.12, 0), [[0.0, 0.0, c], [0.24, 0.0, c], [0.3, 0.06, c], [0.36, 0.42, c], [0.38, 0.47, c], [0.35, 0.48, ci],
			[0.32, 0.42, ci], [0.27, 0.1, ci], [0.2, 0.06, ci], [0.0, 0.06, ci]], 14)
	_pop(pk, s)
	for fx in [-0.18, 0.18]:
		for fz in [-0.55, 0.55]:
			pk.box(kit, key, Transform3D(t.basis, t * Vector3(fx, 0.06, fz)), Vector3(0.07, 0.14, 0.07), worn(Color(0.2, 0.2, 0.2), 0.6))


## A bicycle frame lying in frame t (its plane the local x-z plane): the diamond frame, fork, bars, saddle and its wheels
## (one bent, or gone).
static func _bike(pk: PropKit, kit: Dictionary, key: String, t: Transform3D, rng: RandomNumberGenerator) -> void:
	var col := worn([Color(0.6, 0.1, 0.08), Color(0.1, 0.25, 0.5), Color(0.15, 0.15, 0.15), Color(0.2, 0.45, 0.25)][rng.randi() % 4], rng.randf_range(0.5, 0.9))
	var q := func(u: float, v: float) -> Vector3: return t * Vector3(u, 0.03, v)
	var A: Vector3 = q.call(-0.5, 0.34)
	var B: Vector3 = q.call(0.0, 0.3)
	var S: Vector3 = q.call(-0.12, 0.85)
	var H: Vector3 = q.call(0.5, 0.8)
	var Hb: Vector3 = q.call(0.52, 0.66)
	var F: Vector3 = q.call(0.62, 0.34)
	for e in [[B, S], [S, H], [B, Hb], [A, B], [A, S], [Hb, F], [H, Hb]]:
		_rod(pk, kit, key, e[0], e[1], 0.017, 4, col)
	var by: Vector3 = t.basis.y.normalized()
	_rod(pk, kit, key, H - by * 0.24, H + by * 0.24, 0.014, 4, worn(Color(0.5, 0.5, 0.48), 0.6))
	pk.box(kit, "matte", Transform3D(t.basis, S + (S - B).normalized() * 0.06), Vector3(0.24, 0.06, 0.08), Color(0.08, 0.08, 0.08))
	for w in [A, F]:
		if rng.randf() < 0.2:
			continue
		var bent: float = rng.randf_range(0.0, 0.25)
		_link(pk, kit, "rubber", w, t.basis.x.normalized(), (t.basis.z.normalized() + by * bent).normalized(), 0.33, 0.33 * (1.0 - bent * 0.5), 0.018, RUBBER)


# ======================================================================================
#  The material handler (ORMBACH's) and its magnet
# ======================================================================================

## The slewing ring's top over the ground: SlewHazard.gd's node, the upper (material_handler_upper) turns about the y axis
## through (0, HANDLER_RING_Y, 0) of the base.
const HANDLER_RING_Y := 3.0
## The stick's tip pin in the upper's frame (the boom toward -z), 15m out: the magnet's hanging node (scrap_magnet hangs
## down its -y from it).
const HANDLER_TIP := Vector3(0, 1.45, -15.0)
## The wreck under the magnet, as a box in the hanging node's frame (centre, half size): its roof 2.47 under the pin, its
## tyres 3.87 under it, 0.58 over the ground at the end of the reach.
const MAGNET_HIT_C := Vector3(0, -3.17, 0)
const MAGNET_HIT_HALF := Vector3(0.96, 0.74, 2.3)
const MAGNET_CAR_TOP := -2.47
const ORMBACH_GREEN := Color(0.2, 0.46, 0.22)
## The arm's pins in the upper's frame: the boom's foot, its bend, its tip (the stick's pivot).
const HANDLER_F := Vector3(0, 1.15, -1.35)
const HANDLER_B := Vector3(0, 6.4, -3.9)
const HANDLER_K := Vector3(0, 10.6, -9.2)
const HANDLER_TRACK_X := 1.55


## The material handler's base: two crawlers (track middles at x ±HANDLER_TRACK_X, 5.2 long, 3.8 over them), the carbody,
## an octagonal pedestal raising the slewing ring's fixed race to HANDLER_RING_Y, a ladder up its back, the maker's name.
static func material_handler(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var dark := worn(UNDERCARRIAGE, 0.07)
	var green := worn(ORMBACH_GREEN, 0.06)
	for sx in [-1.0, 1.0]:
		_track(pk, kit, sx * HANDLER_TRACK_X, -2.1, 2.1, 0.55, 0.48, 0.35, "scrap", dark, 7)
		_lbl(labels, "ORMBACH", Vector3(sx * (HANDLER_TRACK_X + 0.32), 0.6, 0.0), Vector3(sx, 0, 0), 0.17, ORMBACH_GREEN.lightened(0.3), 1.6)
	_extrude_zy(pk, kit, "scrap", PackedVector2Array([Vector2(-1.3, 0.42), Vector2(1.3, 0.42), Vector2(1.1, 1.05), Vector2(-1.1, 1.05)]), -1.3, 1.3, 0.04, dark)
	var oct := Basis(UP, PI / 8.0)
	_lathe_c(pk, kit, "scrap", Vector3(0, 1.0, 0), [[1.18, 0.0, green], [1.18, 0.12, green], [1.0, 0.14, green], [1.0, HANDLER_RING_Y - 1.32, green],
			[1.16, HANDLER_RING_Y - 1.3, green], [1.16, HANDLER_RING_Y - 1.18, green], [0.9, HANDLER_RING_Y - 1.18, green]], 8, oct)
	# Ribs on the octagon's corners (the lathe turned PI / 8 puts them at 22.5 + 45k degrees, the faces between).
	for k in range(8):
		var a: float = TAU * (float(k) + 0.5) / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		_box(pk, kit, "scrap", d * 1.0 + Vector3(0, 1.75, 0), Basis(UP, -a), Vector3(0.08, 1.2, 0.08), green.darkened(0.1))
	_lathe_c(pk, kit, "steel", Vector3(0, HANDLER_RING_Y - 0.2, 0), [[0.95, 0.0, Color(0.2, 0.2, 0.2)], [1.24, 0.0, Color(0.2, 0.2, 0.2)],
			[1.24, 0.19, Color(0.22, 0.22, 0.22)], [0.95, 0.19, Color(0.22, 0.22, 0.22)]], 28)
	SW._ladder(pk, kit, Vector3(0, 1.05, 0.98), Vector3(0, HANDLER_RING_Y - 0.25, 0.98), Vector3(0, 0, 1), false, Color(0.2, 0.2, 0.2))
	_box(pk, kit, "scrap", Vector3(0, 1.62, -0.95), Basis(), Vector3(0.7, 0.36, 0.06), worn(Color(0.9, 0.9, 0.86), 0.05))
	_lbl(labels, "OMH 840", Vector3(0, 1.62, -1.005), Vector3(0, 0, -1), 0.2, Color(0.1, 0.1, 0.1), 0.62)


static func material_handler_solids() -> Array:
	var s: Array = []
	for sx in [-1.0, 1.0]:
		s.append(_solid_lh(Vector3(sx * HANDLER_TRACK_X - 0.38, 0.0, -2.6), Vector3(sx * HANDLER_TRACK_X + 0.38, 1.1, 2.6)))
	s.append(_solid_lh(Vector3(-1.3, 0.4, -1.3), Vector3(1.3, 1.05, 1.3)))
	s.append(_solid_lh(Vector3(-1.15, 1.0, -1.15), Vector3(1.15, HANDLER_RING_Y, 1.15)))
	return s


## The handler's upper, built about its slewing axis (origin on the ring's top; the arm toward -z): the turning race, the
## frame, the engine house (louvres, the magnet's generator, exhaust, handrails, ORMBACH in raised letters), the rounded
## counterweight (tail radius 3.0), the cab on its elevating riser front left with its guard, and the arm: the banana boom
## from HANDLER_F through HANDLER_B to HANDLER_K, the stick down to its tip pin at HANDLER_TIP, the boom's two cylinders and
## the stick's, hoses and the magnet's cable. Moving: "scrapm" and vertex colours only.
static func material_handler_upper(pk: PropKit, kit: Dictionary) -> void:
	var green := worn(ORMBACH_GREEN, 0.06)
	var dark := worn(Color(0.15, 0.15, 0.15), 0.06)
	_lathe_c(pk, kit, "steel", Vector3.ZERO, [[1.0, 0.0, Color(0.2, 0.2, 0.2)], [1.3, 0.0, Color(0.2, 0.2, 0.2)], [1.3, 0.13, Color(0.2, 0.2, 0.2)],
			[1.0, 0.13, Color(0.2, 0.2, 0.2)]], 28)
	_blk(pk, kit, "scrapm", Vector3(-1.45, 0.13, -2.0), Vector3(1.45, 0.55, 2.4), dark)
	for sx in [-1.0, 1.0]:
		var bo := PackedVector2Array([Vector2(-2.05, 0.5), Vector2(-0.7, 0.5), Vector2(-0.95, HANDLER_F.y + 0.42), Vector2(-1.45, HANDLER_F.y + 0.5), Vector2(-1.85, HANDLER_F.y + 0.25)])
		_extrude_zy(pk, kit, "scrapm", bo, sx * 0.42 - 0.05, sx * 0.42 + 0.05, 0.0, green.darkened(0.1))
		_blk(pk, kit, "scrapm", Vector3(sx * 0.55 - 0.1, 0.4, -2.1), Vector3(sx * 0.55 + 0.1, 0.72, -1.75), dark)
	# The engine house and the tank box beside it.
	var hy := 2.1
	_blk(pk, kit, "scrapm", Vector3(-0.55, 0.55, -0.55), Vector3(1.45, hy, 2.35), green)
	_blk(pk, kit, "scrapm", Vector3(-1.45, 0.55, 0.55), Vector3(-0.55, 1.65, 2.35), green.darkened(0.06))
	for k in range(6):
		_box(pk, kit, "scrapm", Vector3(1.465, 0.9 + 0.17 * float(k), 1.75), Basis(Vector3.BACK, 0.4), Vector3(0.05, 0.03, 0.85), worn(Color(0.08, 0.08, 0.08), 0.05))
	for z in [-0.1, 0.75]:
		_blk(pk, kit, "scrapm", Vector3(1.45, 0.62, z - 0.012), Vector3(1.465, hy - 0.08, z + 0.012), green.darkened(0.35))
	_pixel_text(pk, kit, "paint", Vector3(1.476, 1.65, 0.62), Vector3(0, 0, -1), UP, 0.045, "ORMBACH", Color(0.96, 0.95, 0.9))
	_pixel_text(pk, kit, "paint", Vector3(-1.476, 1.2, 1.45), Vector3(0, 0, 1), UP, 0.042, "ORMBACH", Color(0.96, 0.95, 0.9))
	# The magnet's generator on the roof, the exhaust, the air cleaner, handrails, the beacon.
	_blk(pk, kit, "scrapm", Vector3(0.0, hy, 0.6), Vector3(1.25, hy + 0.55, 2.1), worn(Color(0.6, 0.62, 0.6), 0.06))
	for k in range(4):
		_blk(pk, kit, "scrapm", Vector3(1.25, hy + 0.1 + 0.1 * float(k), 0.8), Vector3(1.27, hy + 0.15 + 0.1 * float(k), 1.9), Color(0.1, 0.1, 0.1, 0.05))
	pk.tube(kit, "steel", Vector3(-0.3, hy, 1.9), Vector3(-0.3, hy + 0.85, 1.9), 0.07, 0.07, 8, Color(0.15, 0.15, 0.15), false)
	pk.tube(kit, "plastic", Vector3(-0.3, hy, 1.2), Vector3(-0.3, hy + 0.35, 1.2), 0.14, 0.14, 10, Color(0.1, 0.1, 0.1), true)
	SW._railing(pk, kit, [Vector3(1.4, hy, -0.5), Vector3(1.4, hy, 2.3), Vector3(-0.5, hy, 2.3)], 0.8, Color(0.92, 0.75, 0.1), "paint")
	pk.lathe(kit, "lens", Vector3(0.6, hy + 0.55, 1.8), [Vector2(0.001, 0.0), Vector2(0.08, 0.0), Vector2(0.075, 0.15), Vector2(0.001, 0.17)], 10, Color(1.0, 0.6, 0.08))
	# The counterweight, rounded on the tail radius, with a striped band of reflectors.
	var tail := 3.0
	var cwx := 1.42
	var cw := PackedVector2Array([Vector2(-cwx, 1.9), Vector2(cwx, 1.9)])
	var z_edge: float = sqrt(tail * tail - cwx * cwx)
	cw.append(Vector2(cwx, z_edge))
	for k in range(1, 9):
		var x: float = lerpf(cwx, -cwx, float(k) / 9.0)
		cw.append(Vector2(x, sqrt(tail * tail - x * x)))
	cw.append(Vector2(-cwx, z_edge))
	_extrude_plan(pk, kit, "scrapm", cw, 0.15, 1.75, 0.05, green.darkened(0.05))
	for k in range(9):
		var xa: float = lerpf(1.3, -1.3, float(k) / 9.0)
		var xb: float = lerpf(1.3, -1.3, float(k + 1) / 9.0)
		var za: float = sqrt(tail * tail - xa * xa) + 0.025
		var zb: float = sqrt(tail * tail - xb * xb) + 0.025
		var o := Vector3((xa + xb) * 0.5, 0, (za + zb) * 0.5).normalized()
		pk.quad(kit, "paint", [Vector3(xa, 0.75, za), Vector3(xb, 0.75, zb), Vector3(xb, 0.95, zb), Vector3(xa, 0.95, za)], o,
				Color(0.95, 0.75, 0.1) if k % 2 == 0 else Color(0.05, 0.05, 0.05))
	_handler_details(pk, kit, green, dark)
	_handler_cab(pk, kit, green, dark)
	_handler_arm(pk, kit, green, dark)


## The upper's fittings: a grated walkway with a railing along the house's right side and its step, tail lamps and a
## camera on the counterweight, mirrors, a fire extinguisher, a toolbox, lifting eyes.
static func _handler_details(pk: PropKit, kit: Dictionary, green: Color, dark: Color) -> void:
	var gy := 0.55
	_blk(pk, kit, "steel", Vector3(1.47, gy - 0.06, -1.9), Vector3(2.05, gy, 2.0), Color(0.24, 0.24, 0.24))
	for k in range(13):
		var z: float = lerpf(-1.85, 1.95, float(k) / 12.0)
		_blk(pk, kit, "steel", Vector3(1.48, gy, z - 0.012), Vector3(2.04, gy + 0.015, z + 0.012), Color(0.2, 0.2, 0.2))
	for z2 in [-1.6, 0.0, 1.6]:
		pk.beam(kit, "scrapm", Vector3(1.45, gy - 0.3, z2), Vector3(2.0, gy - 0.07, z2), 0.08, 0.06, dark)
	SW._railing(pk, kit, [Vector3(2.0, gy, -1.85), Vector3(2.0, gy, 1.95)], 1.0, Color(0.92, 0.75, 0.1), "paint")
	_blk(pk, kit, "steel", Vector3(1.6, gy - 0.5, -2.25), Vector3(2.0, gy - 0.46, -1.9), Color(0.22, 0.22, 0.22))
	for sx in [-1.0, 1.0]:
		var lz: float = sqrt(9.0 - 1.0) + 0.02
		_box(pk, kit, "lens", Vector3(sx * 1.0, 1.25, lz), Basis(UP, -sx * 0.34), Vector3(0.22, 0.1, 0.04), Color(0.75, 0.08, 0.05))
		_box(pk, kit, "lens", Vector3(sx * 1.0, 1.12, lz - 0.005), Basis(UP, -sx * 0.34), Vector3(0.22, 0.06, 0.04), Color(0.95, 0.6, 0.1))
		_link(pk, kit, "scrapm", Vector3(sx * 0.8, 1.84, 2.4), UP, Vector3.BACK, 0.08, 0.06, 0.025, dark)
	_box(pk, kit, "plastic", Vector3(0, 1.62, 2.99), Basis(Vector3.RIGHT, 0.3), Vector3(0.14, 0.1, 0.12), Color(0.1, 0.1, 0.1))
	# Mirrors on stalks at the house's front corners.
	for m in [[Vector3(1.45, 2.0, -0.5), Vector3(1.75, 2.45, -0.75)], [Vector3(-0.55, 2.0, -0.5), Vector3(-0.6, 2.5, -0.9)]]:
		pk.beam(kit, "steel", m[0], m[1], 0.03, 0.03, BLACK)
		_box(pk, kit, "plastic", (m[1] as Vector3) + Vector3(0, 0.1, 0), Basis(UP, 0.5), Vector3(0.22, 0.32, 0.04), BLACK)
	# A fire extinguisher and a toolbox on the frame's left, behind the riser.
	pk.tube(kit, "paint", Vector3(-1.3, gy, 1.75), Vector3(-1.3, gy + 0.55, 1.75), 0.08, 0.08, 10, Color(0.8, 0.08, 0.05), true)
	_blk(pk, kit, "scrapm", Vector3(-1.44, gy, 1.0), Vector3(-1.0, gy + 0.32, 1.5), worn(Color(0.75, 0.1, 0.08), 0.1))


## The cab on its elevating riser front left (x -1.95..-0.75, floor 3.3 up): a parallelogram of arms from the frame, its
## cylinder, the cab (glass all round, a roof window, the guard), lights, a mirror.
static func _handler_cab(pk: PropKit, kit: Dictionary, green: Color, dark: Color) -> void:
	var x0 := -1.95
	var x1 := -0.75
	var fy := 3.3
	for x in [x0 + 0.15, x1 - 0.15]:
		for dy in [0.0, 0.6]:
			pk.beam(kit, "scrapm", Vector3(x, 0.6 + dy, 0.6), Vector3(x, fy - 0.05 + dy, -0.6), 0.14, 0.16, green.darkened(0.08))
			_rod(pk, kit, "steel", Vector3(x - 0.13, 0.6 + dy, 0.6), Vector3(x + 0.13, 0.6 + dy, 0.6), 0.06, 8, Color(0.3, 0.3, 0.3), true)
			_rod(pk, kit, "steel", Vector3(x - 0.13, fy - 0.05 + dy, -0.6), Vector3(x + 0.13, fy - 0.05 + dy, -0.6), 0.06, 8, Color(0.3, 0.3, 0.3), true)
	_cyl(pk, kit, "scrapm", Vector3(-1.35, 0.6, 0.0), Vector3(-1.35, fy * 0.5 + 0.6, -0.15), 0.09, green)
	_blk(pk, kit, "scrapm", Vector3(x0 + 0.05, fy - 0.3, -0.75), Vector3(x1 - 0.05, fy + 0.7, -0.5), dark)
	var ol := PackedVector2Array([Vector2(-0.6, fy), Vector2(-2.25, fy), Vector2(-2.45, fy + 0.5), Vector2(-2.35, fy + 2.0), Vector2(-2.2, fy + 2.15), Vector2(-0.6, fy + 2.15)])
	_extrude_zy(pk, kit, "scrapm", ol, x0, x1, 0.04, worn(Color(0.86, 0.86, 0.83), 0.04))
	_blk(pk, kit, "scrapm", Vector3(x0 - 0.03, fy + 2.13, -2.32), Vector3(x1 + 0.03, fy + 2.22, -0.55), green)
	var a := Vector3(0, fy + 0.5, -2.45)
	var b := Vector3(0, fy + 2.0, -2.35)
	var along: Vector3 = (b - a).normalized()
	var n := Vector3(0, -along.z, along.y)
	if n.z > 0.0:
		n = -n
	var mid: Vector3 = a.lerp(b, 0.5)
	_box(pk, kit, "glassdark", Vector3((x0 + x1) * 0.5, mid.y, mid.z) + n * 0.02, Basis(Vector3.RIGHT, along, n), Vector3(1.02, 1.42, 0.02), GLASS)
	_box(pk, kit, "glassdark", Vector3(x0 - 0.02, fy + 1.3, -1.45), Basis(), Vector3(0.02, 1.2, 1.4), GLASS)
	_box(pk, kit, "glassdark", Vector3(x1 + 0.02, fy + 1.3, -1.5), Basis(), Vector3(0.02, 1.2, 1.3), GLASS)
	_box(pk, kit, "glassdark", Vector3((x0 + x1) * 0.5, fy + 1.4, -0.58), Basis(), Vector3(0.9, 0.9, 0.02), GLASS)
	_box(pk, kit, "glassdark", Vector3((x0 + x1) * 0.5, fy + 2.23, -1.7), Basis(), Vector3(0.8, 0.02, 0.9), GLASS)
	# The guard in front of the windscreen and over the roof window.
	for k in range(5):
		var x2: float = lerpf(x0 + 0.06, x1 - 0.06, float(k) / 4.0)
		pk.beam(kit, "steel", Vector3(x2, a.y, a.z) + n * 0.15, Vector3(x2, b.y, b.z) + n * 0.15, 0.045, 0.045, Color(0.12, 0.12, 0.12), Vector3.RIGHT)
		pk.beam(kit, "steel", Vector3(x2, fy + 2.3, -2.3), Vector3(x2, fy + 2.3, -1.0), 0.04, 0.04, Color(0.12, 0.12, 0.12), Vector3.RIGHT)
	for t in [0.0, 0.5, 1.0]:
		var p: Vector3 = a.lerp(b, t) + n * 0.195
		pk.beam(kit, "steel", Vector3(x0, p.y, p.z), Vector3(x1, p.y, p.z), 0.05, 0.05, Color(0.12, 0.12, 0.12), n)
	for z in [-2.3, -1.0]:
		pk.beam(kit, "steel", Vector3(x0, fy + 2.345, z), Vector3(x1, fy + 2.345, z), 0.05, 0.05, Color(0.12, 0.12, 0.12))
	for x3 in [x0 + 0.1, x1 - 0.1]:
		_box(pk, kit, "scrapm", Vector3(x3, fy + 2.36, -2.2), Basis(), Vector3(0.22, 0.15, 0.14), dark)
		_box(pk, kit, "lens", Vector3(x3, fy + 2.36, -2.28), Basis(), Vector3(0.18, 0.11, 0.02), Color(0.92, 0.92, 0.86))
	pk.beam(kit, "steel", Vector3(x0, fy + 1.6, -2.2), Vector3(x0 - 0.35, fy + 1.75, -2.35), 0.03, 0.03, BLACK)
	_box(pk, kit, "plastic", Vector3(x0 - 0.42, fy + 1.6, -2.37), Basis(UP, 0.4), Vector3(0.2, 0.3, 0.04), BLACK)


## A side profile through `pts` (the arm's centre line, in the y-z plane) of half depths `hh`, as an outline in (z, y).
static func _arm_outline(pts: Array, hh: Array) -> PackedVector2Array:
	var tops := PackedVector2Array()
	var bots := PackedVector2Array()
	for i in range(pts.size()):
		var prev: Vector3 = pts[maxi(i - 1, 0)]
		var nxt: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var d: Vector3 = (nxt - prev).normalized()
		var n := Vector3(0, -d.z, d.y)
		if n.y < 0.0 or (absf(n.y) < 1e-3 and n.z > 0.0):
			n = -n
		var c: Vector3 = pts[i]
		tops.append(Vector2((c + n * float(hh[i])).z, (c + n * float(hh[i])).y))
		bots.append(Vector2((c - n * float(hh[i])).z, (c - n * float(hh[i])).y))
	var ol := PackedVector2Array()
	for p in bots:
		ol.append(p)
	for i in range(tops.size() - 1, -1, -1):
		ol.append(tops[i])
	return ol


## The arm: the banana boom, the stick, their pins, the cylinders, hoses and the magnet's cable.
static func _handler_arm(pk: PropKit, kit: Dictionary, green: Color, dark: Color) -> void:
	var f := HANDLER_F
	var b := HANDLER_B
	var k := HANDLER_K
	var t := HANDLER_TIP
	var boom: Array = [f, f.lerp(b, 0.5), b, b.lerp(k, 0.5), k]
	var bh: Array = [0.36, 0.44, 0.5, 0.44, 0.34]
	_extrude_zy(pk, kit, "scrapm", _arm_outline(boom, bh), -0.35, 0.35, 0.04, green)
	# Doubler plates welded over the bend, 2.5cm proud of the boom's sides, and a lifting eye on its top.
	var dbl: Array = [f.lerp(b, 0.62), b, b.lerp(k, 0.38)]
	for sx in [-1.0, 1.0]:
		_extrude_zy(pk, kit, "scrapm", _arm_outline(dbl, [0.3, 0.36, 0.3]), sx * 0.35 - (0.0 if sx > 0.0 else 0.025), sx * 0.35 + (0.025 if sx > 0.0 else 0.0), 0.0,
				green.darkened(0.06))
	for p in [f, k]:
		_rod(pk, kit, "scrapm", Vector3(-0.385, (p as Vector3).y, (p as Vector3).z), Vector3(0.385, (p as Vector3).y, (p as Vector3).z), 0.3, 14, green.darkened(0.08), true)
		_rod(pk, kit, "steel", Vector3(-0.55, (p as Vector3).y, (p as Vector3).z), Vector3(0.55, (p as Vector3).y, (p as Vector3).z), 0.07, 8, Color(0.3, 0.3, 0.3), true)
		for sx in [-1.0, 1.0]:
			_box(pk, kit, "scrapm", Vector3(sx * 0.42, (p as Vector3).y + 0.12, (p as Vector3).z), Basis(), Vector3(0.03, 0.4, 0.14), dark)
	# The stick: from its top end R behind the pivot down to the tip.
	var ds: Vector3 = (t - k).normalized()
	var r: Vector3 = k - ds * 1.3
	_extrude_zy(pk, kit, "scrapm", _arm_outline([r, k, k.lerp(t, 0.5), t], [0.28, 0.32, 0.27, 0.2]), -0.26, 0.26, 0.03, green.darkened(0.04))
	_rod(pk, kit, "scrapm", Vector3(-0.27, r.y, r.z), Vector3(0.27, r.y, r.z), 0.22, 12, green.darkened(0.1), true)
	_rod(pk, kit, "scrapm", Vector3(-0.3, t.y, t.z), Vector3(0.3, t.y, t.z), 0.21, 12, dark, true)
	_rod(pk, kit, "steel", Vector3(-0.38, t.y, t.z), Vector3(0.38, t.y, t.z), 0.06, 8, Color(0.35, 0.35, 0.35), true)
	# The boom's cylinders outside its sides, the stick's on its top.
	var d1: Vector3 = (b - f).normalized()
	var nb := Vector3(0, -d1.z, d1.y)
	if nb.y < 0.0:
		nb = -nb
	var rod_end: Vector3 = f.lerp(b, 0.72) - nb * 0.55
	for sx in [-1.0, 1.0]:
		var o := Vector3(sx * 0.55, 0, 0)
		_cyl(pk, kit, "scrapm", Vector3(0, 0.56, -1.92) + o, rod_end + o, 0.13, green)
		_blk(pk, kit, "scrapm", Vector3(sx * 0.33, rod_end.y - 0.15, rod_end.z - 0.2), Vector3(sx * 0.46, rod_end.y + 0.45, rod_end.z + 0.2), green.darkened(0.12))
	var d2: Vector3 = (k - b).normalized()
	var nb2 := Vector3(0, -d2.z, d2.y)
	if nb2.y < 0.0:
		nb2 = -nb2
	var cb: Vector3 = b + nb2 * 0.75 + d2 * 0.2
	_blk(pk, kit, "scrapm", Vector3(-0.15, b.y + 0.3, b.z - 0.3), Vector3(0.15, cb.y + 0.1, b.z + 0.2), green.darkened(0.1))
	_cyl(pk, kit, "scrapm", cb, r, 0.14, green)
	# Hoses along the boom's top to the stick; the magnet's cable (thicker) on to the tip.
	var top_pts: Array = []
	for i in range(boom.size()):
		var p2: Vector3 = boom[i]
		var prev: Vector3 = boom[maxi(i - 1, 0)]
		var nxt: Vector3 = boom[mini(i + 1, boom.size() - 1)]
		var d3: Vector3 = (nxt - prev).normalized()
		var n3 := Vector3(0, -d3.z, d3.y)
		if n3.y < 0.0:
			n3 = -n3
		top_pts.append(p2 + n3 * (float(bh[i]) + 0.07))
	for hx in [-0.14, 0.14]:
		var hp: Array = [Vector3(hx, 0.9, -0.6)]
		for p3 in top_pts:
			hp.append((p3 as Vector3) + Vector3(hx, 0, 0))
		hp.append(r + Vector3(hx, 0.28, 0.1))
		_rods(pk, kit, "rubber", hp, 0.035, 5, Color(0.05, 0.05, 0.05))
	var cp: Array = [Vector3(0.3, 2.1, 0.3), Vector3(0.3, 1.6, -1.0)]
	for p4 in top_pts:
		cp.append((p4 as Vector3) + Vector3(0.0, 0.05, 0))
	var nst := Vector3(0, -ds.z, ds.y)
	if nst.y < 0.0:
		nst = -nst
	cp.append(k + nst * 0.4)
	cp.append(k.lerp(t, 0.5) + nst * 0.33)
	cp.append(t + nst * 0.28 + ds * -0.3)
	cp.append(t + Vector3(0.25, 0.05, 0.3))
	_rods(pk, kit, "rubber", cp, 0.045, 6, Color(0.04, 0.04, 0.04))
	# A work light on the boom aimed down the stick.
	var wl: Vector3 = b + nb2 * 0.6 + Vector3(-0.3, 0, 0)
	_box(pk, kit, "scrapm", wl, Basis(), Vector3(0.2, 0.18, 0.24), dark)
	_box(pk, kit, "lens", wl + Vector3(0, -0.02, -0.13), Basis(), Vector3(0.16, 0.13, 0.02), Color(0.92, 0.92, 0.86))


## The scrap magnet hanging from the stick's tip pin (the origin; built down -y): a shackle round the pin, a swivel, three
## chains to the lugs of a 1.7m lifting magnet (ribs, the terminal box, the cable looping up to the stick), and a wreck held
## under it by its roof (MAGNET_CAR_TOP; MAGNET_HIT_C/HALF its box), bits of scrap stuck round the magnet's rim. `variant`
## seeds the wreck. Moving: "scrapm" and vertex colours only.
static func scrap_magnet(pk: PropKit, kit: Dictionary, variant: int) -> void:
	var rng := _rng(variant, 81)
	var steel := worn(Color(0.2, 0.2, 0.2), 0.3)
	_link(pk, kit, "scrapm", Vector3(0, -0.1, 0), UP, Vector3.FORWARD, 0.2, 0.13, 0.04, steel)
	_lathe_c(pk, kit, "scrapm", Vector3(0, -0.62, 0), [[0.06, 0.0, steel], [0.14, 0.02, steel], [0.16, 0.12, steel], [0.16, 0.24, steel], [0.1, 0.3, steel],
			[0.06, 0.34, steel], [0.06, 0.36, steel], [0.001, 0.37, steel]], 10)
	_link(pk, kit, "scrapm", Vector3(0, -0.72, 0), UP, Vector3.RIGHT, 0.12, 0.09, 0.03, steel)
	var mb := worn(Color(0.08, 0.08, 0.08), 0.25)
	var lug_y := -1.84
	for c in range(3):
		var a: float = TAU * float(c) / 3.0 + PI * 0.5
		var lp := Vector3(cos(a) * 0.58, lug_y, sin(a) * 0.58)
		_chain(pk, kit, "scrapm", Vector3(cos(a) * 0.07, -0.8, sin(a) * 0.07), lp + Vector3(0, 0.06, 0), 0.13, 0.022, worn(Color(0.22, 0.21, 0.2), 0.6), Vector3(-sin(a), 0, cos(a)))
		_box(pk, kit, "scrapm", lp + Vector3(0, -0.06, 0), Basis(UP, -a), Vector3(0.18, 0.2, 0.04), mb)
	# The magnet: a disc with a domed top, ribs, the terminal box and its cable.
	_lathe_c(pk, kit, "scrapm", Vector3.ZERO, [[0.001, -2.45, worn(Color(0.45, 0.45, 0.44), 0.5)], [0.8, -2.45, worn(Color(0.45, 0.45, 0.44), 0.5)],
			[0.85, -2.41, mb], [0.85, -2.03, mb], [0.81, -1.99, mb], [0.7, -1.96, mb], [0.3, -1.88, mb], [0.001, -1.87, mb]], 22)
	pk.tube(kit, "scrapm", Vector3(0, -2.25, 0), Vector3(0, -2.17, 0), 0.865, 0.865, 22, worn(Color(0.95, 0.72, 0.1), 0.2), false)
	for c in range(6):
		var a2: float = TAU * float(c) / 6.0
		_box(pk, kit, "scrapm", Vector3(cos(a2) * 0.55, -1.93, sin(a2) * 0.55), Basis(UP, -a2), Vector3(0.5, 0.14, 0.06), mb)
	var tb := Vector3(0.0, -1.78, 0.32)
	_box(pk, kit, "scrapm", tb, Basis(), Vector3(0.3, 0.2, 0.24), worn(Color(0.95, 0.72, 0.1), 0.2))
	_rods(pk, kit, "rubber", [tb + Vector3(0, 0.1, 0), tb + Vector3(0.05, 0.5, 0.15), Vector3(0.35, -0.9, 0.55), Vector3(0.4, -0.35, 0.45), Vector3(0.25, 0.05, 0.3)], 0.045, 6,
			Color(0.04, 0.04, 0.04))
	# The wreck, its roof against the magnet's face, tipped a little.
	var crush := 0.15
	var roof: float = 0.9 + 0.5 * (1.0 - crush * 0.75)
	var b := Basis(Vector3.BACK, rng.randf_range(-0.04, 0.04)) * Basis(Vector3.RIGHT, rng.randf_range(-0.03, 0.03))
	var wheels: int = 15 & ~(1 << rng.randi_range(0, 3))
	_car(pk, kit, "scrapm", Transform3D(b, Vector3(0, MAGNET_CAR_TOP - roof, 0)), 0, CAR_PAINTS[rng.randi() % CAR_PAINTS.size()], rng.randf_range(0.45, 0.7), crush,
			rng.randi(), wheels)
	# Scrap stuck round the rim.
	for c in range(5):
		var a3: float = rng.randf() * TAU
		var p := Vector3(cos(a3) * 0.8, -2.42 + rng.randf_range(-0.05, 0.1), sin(a3) * 0.8)
		_chunk(pk, kit, "scrapm", p, Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU), Vector3(0.22, 0.06, 0.16) * rng.randf_range(0.8, 1.6),
				0.4, rng, worn(RUST.lerp(Color(0.3, 0.3, 0.3), rng.randf()), 0.9))


# ======================================================================================
#  The car baler, the yard's office and sign, the weighbridge, the fence
# ======================================================================================

const PRESS_BLUE := Color(0.16, 0.32, 0.55)
## The baler's lid on the lane's side, open (degrees from shut).
const PRESS_LID_OPEN := 118.0


## SCHAUBERG's car baler, its loading side toward +z (x -9..9, z -5.2..5): the concrete base, the pressing chamber (x
## -5.5..3.5) with ribbed walls, the far lid shut and the near one swung open on its cylinders, the main ram's housing and
## cylinder at -x, the discharge door raised in its frame at +x over the apron with a fresh bale, a stack of bales, the power
## pack, the control cabin up on its platform with stairs, a wreck waiting on the loading side, hoses, hazard stripes.
static func car_press(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var rng := _rng(41, 5)
	var blue := worn(PRESS_BLUE, 0.07)
	var dark := worn(Color(0.16, 0.16, 0.16), 0.08)
	_blk(pk, kit, "concrete", Vector3(-9.0, -0.4, -5.2), Vector3(9.0, 0.2, 5.0), CONC)
	# The chamber: its walls, ribs, the floor's rails along the top edges.
	var cx0 := -5.5
	var cx1 := 3.5
	var ch := 2.6
	_blk(pk, kit, "scrap", Vector3(cx0, 0.2, -1.3), Vector3(cx1, ch - 0.15, 1.3), blue)
	_blk(pk, kit, "scrap", Vector3(cx0, ch - 0.15, -1.3), Vector3(cx1, ch, 1.3), worn(Color(0.3, 0.3, 0.3), 0.6))
	var x := cx0 + 0.4
	while x < cx1 - 0.2:
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "scrap", Vector3(x - 0.07, 0.2, sz * 1.3 - 0.1), Vector3(x + 0.07, ch - 0.05, sz * 1.3 + 0.1), blue.darkened(0.12))
		x += 0.75
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "hazard", Vector3(cx0, ch - 0.2, sz * 1.42 - 0.025), Vector3(cx1, ch - 0.02, sz * 1.42 + 0.025), WHITE)
	# The far lid, shut; the near one open on its hinge along the chamber's edge.
	_blk(pk, kit, "scrap", Vector3(cx0 + 0.1, ch, -1.32), Vector3(cx1 - 0.1, ch + 0.2, 0.02), blue.darkened(0.05))
	for k in range(6):
		var lx: float = lerpf(cx0 + 0.6, cx1 - 0.6, float(k) / 5.0)
		_blk(pk, kit, "scrap", Vector3(lx - 0.08, ch + 0.2, -1.28), Vector3(lx + 0.08, ch + 0.38, -0.02), blue.darkened(0.12))
	var phi: float = deg_to_rad(PRESS_LID_OPEN)
	var hinge := Vector3(0, ch + 0.05, 1.32)
	var ld := Vector3(0, sin(phi), -cos(phi))
	var ln := Vector3(0, -ld.z, ld.y)
	if ln.z < 0.0:
		ln = -ln
	var lb := Basis(Vector3.RIGHT, ld, Vector3.RIGHT.cross(ld))
	var hmid := Vector3((cx0 + cx1) * 0.5, 0, 0)
	_box(pk, kit, "scrap", hmid + hinge + ld * 0.68, lb, Vector3(cx1 - cx0 - 0.2, 1.36, 0.2), blue.darkened(0.05))
	_box(pk, kit, "hazard", hmid + hinge + ld * 1.36, lb, Vector3(cx1 - cx0 - 0.26, 0.06, 0.22), WHITE)
	for k in range(6):
		var lx2: float = lerpf(cx0 + 0.6, cx1 - 0.6, float(k) / 5.0)
		var rib_c: Vector3 = hinge + ld * 0.66 + Vector3(lx2, 0, 0)
		var rib_out: Vector3 = Vector3.RIGHT.cross(ld)
		if rib_out.dot(Vector3(0, 0, 1)) < 0.0:
			rib_out = -rib_out
		_box(pk, kit, "scrap", rib_c + rib_out * 0.18, lb, Vector3(0.16, 1.3, 0.18), blue.darkened(0.12))
	_rod(pk, kit, "steel", Vector3(cx0 + 0.03, hinge.y, hinge.z), Vector3(cx1 - 0.03, hinge.y, hinge.z), 0.09, 10, Color(0.3, 0.3, 0.3), true)
	for lx3 in [cx0 + 1.6, cx1 - 1.6]:
		var rout: Vector3 = Vector3.RIGHT.cross(ld)
		if rout.dot(Vector3(0, 0, 1)) < 0.0:
			rout = -rout
		_cyl(pk, kit, "scrap", Vector3(lx3, 0.9, 1.55), hinge + ld * 0.95 + rout * 0.3 + Vector3(lx3, 0, 0), 0.12, blue)
		_blk(pk, kit, "scrap", Vector3(lx3 - 0.2, 0.6, 1.4), Vector3(lx3 + 0.2, 1.15, 1.7), blue.darkened(0.15))
	# The ram's housing and cylinder.
	_blk(pk, kit, "scrap", Vector3(-8.0, 0.2, -1.6), Vector3(cx0, 3.2, 1.6), blue)
	_blk(pk, kit, "scrap", Vector3(-8.05, 3.15, -1.65), Vector3(cx0 + 0.05, 3.3, 1.65), blue.darkened(0.15))
	pk.tube(kit, "scrap", Vector3(-8.0, 1.7, 0), Vector3(-8.85, 1.7, 0), 0.55, 0.55, 18, blue.darkened(0.08), true)
	pk.tube(kit, "scrap", Vector3(-8.85, 1.7, 0), Vector3(-8.95, 1.7, 0), 0.62, 0.62, 18, dark, true)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		_rod(pk, kit, "steel", Vector3(-8.95, 1.7 + sin(a) * 0.5, cos(a) * 0.5), Vector3(-9.0, 1.7 + sin(a) * 0.5, cos(a) * 0.5), 0.04, 6, Color(0.3, 0.3, 0.3), true)
	for sz in [-1.0, 1.0]:
		_lbl(labels, "SCHAUBERG", Vector3(-6.75, 2.3, sz * 1.635), Vector3(0, 0, sz), 0.45, Color(0.97, 0.96, 0.92), 3.1)
		_lbl(labels, "PAKETIERPRESSE PP 3000", Vector3(-6.75, 1.65, sz * 1.635), Vector3(0, 0, sz), 0.16, Color(0.97, 0.96, 0.92), 3.0)
	# The discharge door raised in its frame, the apron, a fresh bale on it, a stack of bales.
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "scrap", Vector3(cx1, 0.2, sz * 1.55 - 0.18), Vector3(cx1 + 0.35, 5.0, sz * 1.55 + 0.18), blue.darkened(0.06))
	_blk(pk, kit, "scrap", Vector3(cx1 - 0.05, 4.8, -1.75), Vector3(cx1 + 0.4, 5.25, 1.75), blue.darkened(0.06))
	_blk(pk, kit, "scrap", Vector3(cx1 + 0.06, 2.85, -1.3), Vector3(cx1 + 0.3, 4.75, 1.3), worn(Color(0.95, 0.72, 0.1), 0.25))
	_cyl(pk, kit, "scrap", Vector3(cx1 + 0.18, 6.4, 0), Vector3(cx1 + 0.18, 4.8, 0), 0.12, blue)
	_blk(pk, kit, "scrap", Vector3(cx1 + 0.02, 5.25, -0.25), Vector3(cx1 + 0.34, 6.5, 0.25), blue.darkened(0.06))
	_blk(pk, kit, "scrap", Vector3(cx1 + 0.35, 0.2, -1.2), Vector3(6.2, 0.32, 1.2), worn(Color(0.3, 0.3, 0.3), 0.6))
	_bale(pk, kit, "scrap", Vector3(4.9, 0.66, 0.05), Basis(UP, PI * 0.5 + 0.04), Vector3(1.45, 0.66, 1.95), rng)
	for j in range(3):
		for k in range(3 - j):
			var bz: float = -1.5 + 1.5 * float(k) + 0.75 * float(j)
			_bale(pk, kit, "scrap", Vector3(7.6 + rng.randf_range(-0.05, 0.05), 0.2 + 0.33 + 0.67 * float(j), bz), Basis(UP, PI * 0.5 + rng.randf_range(-0.05, 0.05)),
					Vector3(1.45, 0.66, 1.95), rng)
	# The power pack: a cabinet with doors and louvres, its oil tank, the hoses to the ram.
	_blk(pk, kit, "scrap", Vector3(-9.0, 0.2, -5.0), Vector3(-5.8, 2.7, -2.4), blue)
	_blk(pk, kit, "scrap", Vector3(-9.05, 2.7, -5.05), Vector3(-5.75, 2.82, -2.35), dark)
	for k in range(3):
		var dx: float = -8.6 + 1.0 * float(k)
		_blk(pk, kit, "scrap", Vector3(dx, 0.4, -2.39), Vector3(dx + 0.85, 2.5, -2.37), blue.darkened(0.1))
		for j in range(5):
			_blk(pk, kit, "scrap", Vector3(dx + 0.15, 1.6 + 0.12 * float(j), -2.375), Vector3(dx + 0.7, 1.65 + 0.12 * float(j), -2.35), Color(0.08, 0.08, 0.08, 0.05))
	pk.tube(kit, "scrap", Vector3(-6.2, 2.82, -4.4), Vector3(-6.2, 3.4, -4.4), 0.08, 0.08, 8, dark, true)
	for k in range(3):
		var hx: float = -6.4 + 0.2 * float(k)
		_rods(pk, kit, "rubber", [Vector3(hx, 0.5, -2.4), Vector3(hx, 0.35, -2.0), Vector3(hx + 0.2, 0.3, -1.65), Vector3(hx + 0.3, 0.6, -1.61)], 0.045, 6, Color(0.04, 0.04, 0.04))
	# The control cabin up on its platform, the stairs, railings.
	var py := 2.1
	_blk(pk, kit, "steel", Vector3(-3.6, py - 0.12, -4.6), Vector3(0.6, py, -1.9), Color(0.25, 0.25, 0.25))
	for lx4 in [-3.5, 0.5]:
		for lz in [-4.5, -2.0]:
			pk.beam(kit, "scrap", Vector3(lx4, 0.2, lz), Vector3(lx4, py - 0.12, lz), 0.14, 0.14, dark)
	SW._stair(pk, kit, Vector3(3.2, 0.2, -3.6), Vector3(0.6, py, -3.6), 0.9, Color(0.25, 0.25, 0.25), Color(0.92, 0.75, 0.1))
	SW._railing(pk, kit, [Vector3(0.55, py, -4.55), Vector3(-3.55, py, -4.55), Vector3(-3.55, py, -1.95), Vector3(0.55, py, -1.95)], 1.0, Color(0.92, 0.75, 0.1), "paint")
	var cab := worn(Color(0.88, 0.88, 0.85), 0.08)
	_blk(pk, kit, "scrap", Vector3(-3.3, py, -4.35), Vector3(-0.6, py + 2.3, -2.4), cab)
	_blk(pk, kit, "scrap", Vector3(-3.4, py + 2.3, -4.45), Vector3(-0.5, py + 2.42, -2.3), dark)
	_box(pk, kit, "glassdark", Vector3(-1.95, py + 1.45, -2.38), Basis(), Vector3(2.3, 1.05, 0.02), GLASS)
	_box(pk, kit, "glassdark", Vector3(-0.58, py + 1.45, -3.15), Basis(), Vector3(0.02, 1.0, 0.85), GLASS)
	_box(pk, kit, "glassdark", Vector3(-3.32, py + 1.45, -3.4), Basis(), Vector3(0.02, 1.0, 1.4), GLASS)
	_box(pk, kit, "scrap", Vector3(-0.58, py + 1.0, -4.0), Basis(), Vector3(0.02, 2.0, 0.6), worn(Color(0.3, 0.32, 0.35), 0.1))
	_box(pk, kit, "scrap", Vector3(-1.2, py + 2.5, -3.3), Basis(), Vector3(0.7, 0.16, 0.45), worn(Color(0.9, 0.9, 0.88), 0.1))
	pk.lathe(kit, "lens", Vector3(-2.8, py + 2.42, -2.6), [Vector2(0.001, 0.0), Vector2(0.08, 0.0), Vector2(0.075, 0.15), Vector2(0.001, 0.17)], 10, Color(1.0, 0.6, 0.08))
	_lbl(labels, "VORSICHT PRESSE", Vector3(-1.95, py + 2.15, -2.36), Vector3(0, 0, 1), 0.13, Color(0.85, 0.1, 0.06), 2.2)
	# A wreck waiting on the loading side, nose to the ram.
	_car(pk, kit, "scrap", Transform3D(Basis(UP, PI * 0.5 + 0.08), Vector3(-1.4, 0.2, 3.7)), 1, CAR_PAINTS[4], 0.7, 0.2, 515, 11)


static func car_press_solids() -> Array:
	var s: Array = []
	s.append(_solid_lh(Vector3(-5.5, 0.0, -1.45), Vector3(3.5, 2.8, 1.45)))
	s.append(_solid_lh(Vector3(-9.0, 0.0, -1.65), Vector3(-5.5, 3.3, 1.65)))
	s.append(_solid_lh(Vector3(3.5, 0.0, -1.75), Vector3(3.9, 5.25, 1.75)))
	s.append(_solid_lh(Vector3(-9.0, 0.0, -5.0), Vector3(-5.8, 2.8, -2.4)))
	s.append(_solid_lh(Vector3(-3.6, 0.0, -4.6), Vector3(0.6, 4.5, -1.9)))
	s.append(_solid_lh(Vector3(4.0, 0.0, -1.0), Vector3(5.9, 1.0, 1.1)))
	s.append(_solid_lh(Vector3(6.5, 0.0, -2.3), Vector3(8.7, 2.25, 2.3)))
	s.append(_solid_lh(Vector3(-3.7, 0.0, 2.8), Vector3(0.9, 1.5, 4.6)))
	var phi: float = deg_to_rad(PRESS_LID_OPEN)
	var ld := Vector3(0, sin(phi), -cos(phi))
	s.append(_solid(Vector3(-1.0, 2.65, 1.32) + ld * 0.68, Vector3(9.0, 1.4, 0.4), Basis(Vector3.RIGHT, ld, Vector3.RIGHT.cross(ld))))
	return s


## An office container (6.06 x 2.44 x 2.6) standing at (x0, y0), its long side along x and its front toward +z: corner posts
## and frame rails, panel walls, windows with bars, `door` (its middle along x from x0, or negative: none), a roof edge.
static func _office_box(pk: PropKit, kit: Dictionary, x0: float, y0: float, col: Color, door: float, windows: Array) -> void:
	var x1: float = x0 + 6.06
	var hz := 1.22
	var y1: float = y0 + 2.6
	var frame := worn(Color(0.24, 0.26, 0.28), 0.12)
	_blk(pk, kit, "scrap", Vector3(x0 + 0.08, y0 + 0.14, -hz + 0.02), Vector3(x1 - 0.08, y1 - 0.16, hz - 0.02), col)
	for cx in [x0 + 0.08, x1 - 0.08]:
		for cz in [-hz + 0.08, hz - 0.08]:
			_box(pk, kit, "scrap", Vector3(cx, (y0 + y1) * 0.5, cz), Basis(), Vector3(0.16, 2.6, 0.16), frame)
	for yy in [y0 + 0.07, y1 - 0.08]:
		for cz in [-hz + 0.06, hz - 0.06]:
			_box(pk, kit, "scrap", Vector3((x0 + x1) * 0.5, yy, cz), Basis(), Vector3(6.06 - 0.32, 0.15, 0.12), frame)
		for cx in [x0 + 0.06, x1 - 0.06]:
			_box(pk, kit, "scrap", Vector3(cx, yy, 0), Basis(), Vector3(0.12, 0.15, 2.44 - 0.32), frame)
	_blk(pk, kit, "scrap", Vector3(x0 + 0.16, y1 - 0.16, -hz + 0.12), Vector3(x1 - 0.16, y1 - 0.1, hz - 0.12), frame.darkened(0.2))
	for w in windows:
		var wx: float = x0 + float(w)
		var wy: float = y0 + 1.55
		_blk(pk, kit, "scrap", Vector3(wx - 0.62, wy - 0.52, hz - 0.03), Vector3(wx + 0.62, wy + 0.52, hz + 0.0), worn(Color(0.85, 0.86, 0.85), 0.05))
		_box(pk, kit, "glassdark", Vector3(wx, wy, hz + 0.012), Basis(), Vector3(1.1, 0.9, 0.02), GLASS)
		for k in range(5):
			pk.tube(kit, "metal", Vector3(wx - 0.48 + 0.24 * float(k), wy - 0.48, hz + 0.08), Vector3(wx - 0.48 + 0.24 * float(k), wy + 0.48, hz + 0.08), 0.012, 0.012, 4,
					Color(0.3, 0.3, 0.3), true)
		_blk(pk, kit, "metal", Vector3(wx - 0.6, wy - 0.56, hz + 0.0), Vector3(wx + 0.6, wy - 0.52, hz + 0.1), Color(0.3, 0.3, 0.3))
	if door >= 0.0:
		var dx: float = x0 + door
		_blk(pk, kit, "scrap", Vector3(dx - 0.5, y0 + 0.16, hz - 0.02), Vector3(dx + 0.5, y0 + 2.2, hz + 0.03), worn(Color(0.35, 0.37, 0.4), 0.15))
		_box(pk, kit, "glassdark", Vector3(dx, y0 + 1.75, hz + 0.042), Basis(), Vector3(0.5, 0.5, 0.02), GLASS)
		_rod(pk, kit, "metal", Vector3(dx + 0.32, y0 + 1.05, hz + 0.07), Vector3(dx + 0.42, y0 + 1.05, hz + 0.07), 0.02, 4, Color(0.7, 0.7, 0.7), true)


## The yard's office, its front toward +z (the road): two office containers stacked on blocks (x -6.6..-0.5) and the
## goods-in container beside them, a stair and landing up to the upper one, the big sign on two posts (SCHROTT & METALLE
## KÖNIG), an air conditioner, a dish, a lamp, bins, a bench, a camera.
static func scrapyard_office(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var white := worn(Color(0.88, 0.88, 0.85), 0.04)
	var grey := worn(Color(0.6, 0.63, 0.66), 0.05)
	for bx in [-6.4, -3.6, -0.8, 0.4, 3.2, 6.0]:
		for bz in [-1.0, 1.0]:
			_blk(pk, kit, "concrete", Vector3(bx - 0.19, -0.2, bz - 0.19), Vector3(bx + 0.19, 0.19, bz + 0.19), CONC)
	_office_box(pk, kit, -6.6, 0.2, white, 4.9, [1.0, 2.9])
	_office_box(pk, kit, -6.6, 2.8, white, 4.9, [1.0, 2.9])
	_office_box(pk, kit, 0.2, 0.2, grey, 5.3, [1.3, 3.2])
	# The landing in front of the upper office's door and the stair up to it along the goods-in container's front.
	var ly := 2.8
	_blk(pk, kit, "steel", Vector3(-2.4, ly - 0.1, 1.25), Vector3(0.0, ly, 2.45), Color(0.28, 0.28, 0.28))
	for lx in [-2.35, -0.05]:
		pk.beam(kit, "steel", Vector3(lx, 0.0, 2.4), Vector3(lx, ly - 0.1, 2.4), 0.1, 0.1, Color(0.25, 0.25, 0.25))
	SW._railing(pk, kit, [Vector3(-2.38, ly, 1.3), Vector3(-2.38, ly, 2.42), Vector3(-0.9, ly, 2.42)], 1.0, Color(0.92, 0.75, 0.1), "paint")
	SW._stair(pk, kit, Vector3(3.4, 0.0, 1.85), Vector3(0.0, ly, 1.85), 0.9, Color(0.25, 0.25, 0.25), Color(0.92, 0.75, 0.1))
	# The sign: a blue board with a yellow rim on two posts over the goods-in container.
	var sx0 := 0.6
	var sx1 := 7.6
	var sy0 := 5.0
	var sy1 := 7.6
	var sz := 0.9
	for px in [sx0 + 0.5, sx1 - 0.5]:
		pk.tube(kit, "scrap", Vector3(px, -0.25, sz - 0.25), Vector3(px, sy1 - 0.05, sz - 0.25), 0.11, 0.11, 10, worn(Color(0.3, 0.3, 0.3), 0.3), true)
		_blk(pk, kit, "concrete", Vector3(px - 0.35, -0.3, sz - 0.6), Vector3(px + 0.35, 0.1, sz + 0.1), CONC)
	_blk(pk, kit, "scrap", Vector3(sx0, sy0, sz - 0.12), Vector3(sx1, sy1, sz), worn(Color(0.42, 0.43, 0.43), 0.5))
	_blk(pk, kit, "scrap", Vector3(sx0, sy0, sz), Vector3(sx1, sy1, sz + 0.025), worn(Color(0.98, 0.78, 0.1), 0.12))
	_blk(pk, kit, "scrap", Vector3(sx0 + 0.12, sy0 + 0.12, sz + 0.025), Vector3(sx1 - 0.12, sy1 - 0.12, sz + 0.05), worn(Color(0.08, 0.22, 0.52), 0.12))
	for k in range(4):
		var bx2: float = lerpf(sx0 + 0.6, sx1 - 0.6, float(k) / 3.0)
		pk.beam(kit, "scrap", Vector3(bx2, sy0 + 0.15, sz - 0.18), Vector3(bx2, sy1 - 0.15, sz - 0.18), 0.08, 0.08, worn(Color(0.3, 0.3, 0.3), 0.6))
	var mx: float = (sx0 + sx1) * 0.5
	_lbl(labels, "SCHROTT & METALLE", Vector3(mx, sy1 - 0.55, sz + 0.08), Vector3(0, 0, 1), 0.42, Color(0.98, 0.98, 0.95), sx1 - sx0 - 0.5)
	_lbl(labels, "KÖNIG", Vector3(mx, sy0 + 1.15, sz + 0.08), Vector3(0, 0, 1), 0.75, Color(0.98, 0.8, 0.12), sx1 - sx0 - 0.5)
	_lbl(labels, "ANKAUF  VERKAUF  CONTAINERDIENST", Vector3(mx, sy0 + 0.45, sz + 0.08), Vector3(0, 0, 1), 0.17, Color(0.98, 0.98, 0.95), sx1 - sx0 - 0.5)
	_lbl(labels, "TEL. 0 21 47 / 55 02 18", Vector3(mx, sy0 + 0.22, sz + 0.08), Vector3(0, 0, 1), 0.13, Color(0.98, 0.98, 0.95), 4.0)
	# Small signs at the doors.
	_blk(pk, kit, "plastic", Vector3(-2.4, 2.42, 1.255), Vector3(-1.0, 2.68, 1.28), Color(0.95, 0.95, 0.93))
	_lbl(labels, "BÜRO", Vector3(-1.7, 2.55, 1.31), Vector3(0, 0, 1), 0.2, Color(0.1, 0.2, 0.5), 1.2)
	_blk(pk, kit, "plastic", Vector3(4.6, 2.25, 1.255), Vector3(6.4, 2.6, 1.28), Color(0.95, 0.95, 0.93))
	_lbl(labels, "ANNAHME", Vector3(5.5, 2.42, 1.31), Vector3(0, 0, 1), 0.2, Color(0.1, 0.2, 0.5), 1.6)
	# The air conditioner on the upper office's end, the dish on its roof, a lamp over the doors, a camera.
	_blk(pk, kit, "scrap", Vector3(-7.15, 3.6, -0.5), Vector3(-6.62, 4.3, 0.4), worn(Color(0.86, 0.86, 0.84), 0.15))
	for k in range(5):
		_blk(pk, kit, "scrap", Vector3(-7.17, 3.7 + 0.12 * float(k), -0.4), Vector3(-7.14, 3.75 + 0.12 * float(k), 0.3), Color(0.3, 0.3, 0.3, 0.1))
	var dish := Vector3(-5.6, 5.45, -0.6)
	pk.beam(kit, "steel", dish, dish + Vector3(0, 0.5, 0), 0.05, 0.05, Color(0.5, 0.5, 0.5))
	pk.lathe(kit, "plastic", dish + Vector3(0, 0.6, 0.1), [Vector2(0.001, 0.0), Vector2(0.3, 0.06), Vector2(0.38, 0.12)], 12, Color(0.85, 0.85, 0.83), false,
			Basis(Vector3.RIGHT, PI * 0.35))
	for lx2 in [-1.7, 4.0]:
		_box(pk, kit, "scrap", Vector3(lx2, 2.62 if lx2 < 0.0 else 2.75, 1.3), Basis(), Vector3(0.3, 0.12, 0.18), worn(Color(0.2, 0.2, 0.2), 0.1))
		_box(pk, kit, "lens", Vector3(lx2, 2.55 if lx2 < 0.0 else 2.68, 1.3), Basis(), Vector3(0.24, 0.02, 0.12), Color(0.95, 0.95, 0.9))
	_box(pk, kit, "plastic", Vector3(6.1, 2.6, 1.35), Basis(UP, 0.5) * Basis(Vector3.RIGHT, -0.3), Vector3(0.12, 0.12, 0.3), Color(0.9, 0.9, 0.88))
	# Bins and a bench in front.
	for k in range(2):
		var bp := Vector3(-6.2 + 0.85 * float(k), 0.0, 2.0)
		_blk(pk, kit, "plastic", bp + Vector3(-0.3, 0.05, -0.35), bp + Vector3(0.3, 1.05, 0.35), [Color(0.15, 0.35, 0.18), Color(0.2, 0.22, 0.25)][k])
		_blk(pk, kit, "plastic", bp + Vector3(-0.32, 1.05, -0.38), bp + Vector3(0.32, 1.12, 0.38), [Color(0.12, 0.3, 0.15), Color(0.16, 0.18, 0.2)][k])
	YK.bench(pk, kit, Vector3(-4.0, 0.0, 1.9), Vector3(0, 0, 1), 1.8)


static func scrapyard_office_solids() -> Array:
	var s: Array = []
	s.append(_solid_lh(Vector3(-6.6, 0.0, -1.22), Vector3(-0.54, 5.4, 1.22)))
	s.append(_solid_lh(Vector3(0.2, 0.0, -1.22), Vector3(6.26, 2.8, 1.22)))
	for px in [1.1, 7.1]:
		s.append(_solid_lh(Vector3(px - 0.2, 0.0, 0.45), Vector3(px + 0.2, 7.6, 0.85)))
	for lx in [-2.35, -0.05]:
		s.append(_solid_lh(Vector3(lx - 0.1, 0.0, 2.3), Vector3(lx + 0.1, 2.8, 2.5)))
	s.append(_solid_lh(Vector3(-6.6, 0.0, 1.6), Vector3(-5.2, 1.1, 2.4)))
	return s


## The weighbridge, its deck along z (x ±1.6, z -7.5..6, its +z end toward the road) flush in its pit's concrete rim; yellow-
## and-black bollards along it, the weigh house beside it (x 2.5..5) with its window on the deck, the display and the
## traffic light at the road end, the sign.
static func weighbridge(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var z0 := -7.5
	var z1 := 5.5
	_blk(pk, kit, "concrete", Vector3(-1.85, -0.3, z0 - 0.25), Vector3(1.85, 0.03, z1 + 0.25), CONC.darkened(0.08))
	var n: int = 5
	for k in range(n):
		var za: float = lerpf(z0, z1, float(k) / float(n)) + 0.02
		var zb: float = lerpf(z0, z1, float(k + 1) / float(n)) - 0.02
		_blk(pk, kit, "scrap", Vector3(-1.6, 0.03, za), Vector3(1.6, 0.075, zb), worn(Color(0.42, 0.42, 0.4), 0.3))
		for j in range(6):
			var sz: float = lerpf(za + 0.2, zb - 0.2, float(j) / 5.0)
			_blk(pk, kit, "scrap", Vector3(-1.55, 0.075, sz - 0.02), Vector3(1.55, 0.09, sz + 0.02), worn(Color(0.38, 0.38, 0.36), 0.35))
	for sx in [-1.0, 1.0]:
		var z := z0
		while z <= z1 + 0.01:
			var p := Vector3(sx * 2.15, 0.0, z)
			pk.tube(kit, "hazard", p, p + Vector3(0, 1.0, 0), 0.1, 0.1, 10, WHITE, true)
			z += 2.6
	# The weigh house.
	var hw := worn(Color(0.86, 0.85, 0.8), 0.04)
	_blk(pk, kit, "concrete", Vector3(2.45, -0.2, -1.55), Vector3(5.05, 0.15, 1.55), CONC)
	_blk(pk, kit, "scrap", Vector3(2.55, 0.15, -1.4), Vector3(4.95, 2.6, 1.4), hw)
	_blk(pk, kit, "scrap", Vector3(2.45, 2.6, -1.5), Vector3(5.05, 2.75, 1.5), worn(Color(0.25, 0.25, 0.25), 0.1))
	_box(pk, kit, "glassdark", Vector3(2.53, 1.6, 0.0), Basis(), Vector3(0.02, 0.95, 1.9), GLASS)
	_blk(pk, kit, "scrap", Vector3(2.45, 1.05, -1.0), Vector3(2.55, 1.1, 1.0), worn(Color(0.3, 0.3, 0.3), 0.1))
	_box(pk, kit, "glassdark", Vector3(3.75, 1.6, 1.42), Basis(), Vector3(1.4, 0.8, 0.02), GLASS)
	_blk(pk, kit, "scrap", Vector3(4.97, 0.15, -0.5), Vector3(5.0, 2.2, 0.45), worn(Color(0.35, 0.37, 0.4), 0.12))
	_blk(pk, kit, "scrap", Vector3(4.95, 2.0, 0.9), Vector3(5.3, 2.45, 1.3), worn(Color(0.86, 0.86, 0.84), 0.12))
	_blk(pk, kit, "plastic", Vector3(2.9, 2.0, 1.42), Vector3(4.6, 2.45, 1.45), Color(0.95, 0.95, 0.93))
	_lbl(labels, "WAAGE", Vector3(3.75, 2.23, 1.48), Vector3(0, 0, 1), 0.28, Color(0.1, 0.2, 0.5), 1.6)
	# The display at the road end and the traffic light.
	var dp := Vector3(2.45, 0.0, z1 - 0.4)
	pk.tube(kit, "scrap", dp, dp + Vector3(0, 2.6, 0), 0.07, 0.07, 8, worn(Color(0.3, 0.3, 0.3), 0.3), true)
	_blk(pk, kit, "scrap", dp + Vector3(-0.75, 2.2, -0.08), dp + Vector3(0.75, 2.9, 0.08), worn(Color(0.12, 0.12, 0.12), 0.1))
	_blk(pk, kit, "lens", dp + Vector3(-0.65, 2.3, 0.08), dp + Vector3(0.65, 2.8, 0.1), Color(0.18, 0.02, 0.02))
	_lbl(labels, "12 480 KG", dp + Vector3(0, 2.55, 0.13), Vector3(0, 0, 1), 0.28, Color(1.0, 0.18, 0.08), 1.25)
	var tp := Vector3(-2.45, 0.0, z1 - 0.4)
	pk.tube(kit, "scrap", tp, tp + Vector3(0, 2.4, 0), 0.06, 0.06, 8, worn(Color(0.3, 0.3, 0.3), 0.3), true)
	_blk(pk, kit, "scrap", tp + Vector3(-0.2, 1.75, -0.12), tp + Vector3(0.2, 2.55, 0.12), worn(Color(0.1, 0.1, 0.1), 0.1))
	pk.tube(kit, "lens", tp + Vector3(0, 2.33, 0.12), tp + Vector3(0, 2.33, 0.15), 0.12, 0.12, 10, Color(0.9, 0.08, 0.04), true)
	pk.tube(kit, "lens", tp + Vector3(0, 1.97, 0.12), tp + Vector3(0, 1.97, 0.15), 0.12, 0.12, 10, Color(0.04, 0.25, 0.08), true)
	_blk(pk, kit, "plastic", tp + Vector3(-0.6, 1.0, 0.07), tp + Vector3(0.6, 1.5, 0.1), Color(0.98, 0.8, 0.1))
	_lbl(labels, "BITTE ANHALTEN", tp + Vector3(0, 1.25, 0.13), Vector3(0, 0, 1), 0.12, Color(0.08, 0.08, 0.08), 1.1)


static func weighbridge_solids() -> Array:
	var s: Array = []
	s.append(_solid_lh(Vector3(2.45, 0.0, -1.55), Vector3(5.05, 2.75, 1.55)))
	s.append(_solid_lh(Vector3(2.25, 0.0, 4.9), Vector3(2.65, 2.9, 5.3)))
	s.append(_solid_lh(Vector3(-2.65, 0.0, 4.9), Vector3(-2.25, 2.55, 5.3)))
	for sx in [-1.0, 1.0]:
		var z := -7.5
		while z <= 5.51:
			s.append(_solid_lh(Vector3(sx * 2.15 - 0.12, 0.0, z - 0.12), Vector3(sx * 2.15 + 0.12, 1.0, z + 0.12)))
			z += 2.6
	return s


## A stretch of the yard's fence along x from 0 to `length` (life), 2.6m high: corrugated sheets of every colour (and rust) on
## its outside (-z), the posts and rails inside (+z) on footings, barbed wire on cranked arms leaning out, now and then a
## warning board.
static func scrap_fence(pk: PropKit, kit: Dictionary, length: float) -> void:
	var rng := _rng(int(length * 100.0), 91)
	var pc := worn(Color(0.3, 0.3, 0.29), 0.5)
	var np: int = maxi(int(ceil(length / 2.5)), 1)
	for k in range(np + 1):
		var x: float = clampf(length * float(k) / float(np), 0.05, length - 0.05)
		_blk(pk, kit, "concrete", Vector3(x - 0.18, -0.2, 0.0), Vector3(x + 0.18, 0.12, 0.3), CONC)
		_blk(pk, kit, "scrap", Vector3(x - 0.04, 0.12, 0.04), Vector3(x + 0.04, 2.62, 0.12), pc)
		var arm := Vector3(x, 2.6, 0.06)
		pk.beam(kit, "scrap", arm, arm + Vector3(0, 0.35, -0.35), 0.04, 0.04, pc)
	for y in [0.35, 2.25]:
		_blk(pk, kit, "scrap", Vector3(0.0, y - 0.04, -0.005), Vector3(length, y + 0.04, 0.04), pc)
	for wk in range(3):
		var t: float = (float(wk) + 0.5) / 3.0
		var o := Vector3(0, 2.6 + 0.35 * t, 0.06 - 0.35 * t)
		_rod(pk, kit, "steel", o, o + Vector3(length, 0, 0), 0.008, 4, Color(0.35, 0.33, 0.3), false)
	# The sheets, edge to edge, each its own height, colour and lean.
	var cols: Array = [Color(0.62, 0.63, 0.62), Color(0.5, 0.2, 0.14), Color(0.32, 0.42, 0.32), Color(0.3, 0.4, 0.55), Color(0.62, 0.6, 0.55), Color(0.45, 0.3, 0.2)]
	var x0 := 0.0
	while x0 < length - 0.01:
		var w: float = minf(rng.randf_range(0.85, 1.05), length - x0)
		var yb: float = rng.randf_range(0.02, 0.1)
		var yt: float = rng.randf_range(2.4, 2.62)
		var lean: float = rng.randf_range(-0.03, 0.02)
		var c: Color = cols[rng.randi() % cols.size()]
		var z := -0.03
		var pts: Array = [Vector3(x0, yb, z), Vector3(x0 + w, yb, z), Vector3(x0 + w, yt, z + lean), Vector3(x0, yt, z + lean)]
		var uv: Array = [Vector2(x0, yb) * uvk, Vector2(x0 + w, yb) * uvk, Vector2(x0 + w, yt) * uvk, Vector2(x0, yt) * uvk]
		pk.panel(kit, "rustiron", pts, Vector3(0, 0, -1), c, c.darkened(0.3), uv)
		x0 += w
	# A warning board on the outside now and then.
	if rng.randf() < 0.45:
		var bx: float = rng.randf_range(1.0, maxf(length - 1.0, 1.1))
		_blk(pk, kit, "plastic", Vector3(bx - 0.45, 1.3, -0.1), Vector3(bx + 0.45, 1.8, -0.07), Color(0.98, 0.8, 0.1))
		_pixel_text(pk, kit, "plastic", Vector3(bx, 1.64, -0.125), Vector3.LEFT, UP, 0.024, "BETRETEN", Color(0.05, 0.05, 0.05))
		_pixel_text(pk, kit, "plastic", Vector3(bx, 1.46, -0.125), Vector3.LEFT, UP, 0.024, "VERBOTEN", Color(0.05, 0.05, 0.05))
