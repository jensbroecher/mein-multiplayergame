extends RefCounted
## The Kronburg GP finale's building site (Baustelle) in the dock zone: a tower crane (its mast, and the slewing top built
## apart for a script to turn), a crawler excavator (its undercarriage, and the upper with the digging arm built apart for a
## script to slew over the road's edge), a tandem road roller (driven back and forth by a script), the German Bauzaun with
## green privacy banners, site office containers, a skip, a portable toilet, stacks of rebar, formwork panels, brick pallets,
## concrete pipes, a cable drum, a sand pile, a concrete mixer truck, a site dumper, the Bauschild, Leitbaken and their
## warning lamps, tube-and-board scaffolding, and the multi-storey car park under construction that the route drives
## through. Fictional throughout: the builder KRONBAU GmbH, the machines' makers, the project "Neubau Parkhaus Hafen-Ost".
##
## Everything is built at LIFE size through a PropKit in its own frame (y = 0 the ground, footings down to y = -1.5, the
## front toward +z unless a builder says otherwise; machines face -z) and grown by the caller (PROP_SCALE 1.6). UVs are in
## metres times `uvk` (the caller's scale) where a tiling shader reads them (concrete, corrugated iron, timber, masonry), in
## life metres on the wire grids, the banner and the red-and-white stripes. Labels are [text, position, outward normal, cap
## height, colour, board width] in life-size kit coordinates. Solids are [Transform3D, Vector3 size] boxes in life metres in
## the prop's own frame (the `*_solids` functions).
##
## Material keys (make_material): this kit's own "bpaint" (baustelle_paint.gdshader: weathered machine paint, yellow-black
## hazard stripes at vertex alpha 0.5, red-and-white warning stripes at alpha 0.2; laid in the mesh's own frame, so it rides
## along on the parts that move), "bmesh", "bnet", "brebar" (baustelle_mesh.gdshader: the Bauzaun's welded mesh, the green
## privacy banner, reinforcing mats; two-sided, discarded between the wires), "bclad" (hut_roof_iron as a container's
## corrugated walls), "bsand" and "brubble" (mina_rubble.gdshader with the sand and pebble textures), "btyre"
## (mina_tyre.gdshader with the Ruhr's dust); SteelworksKit's "rusty", "grime", "shell", "hazard", "lamp" (lit), "lens";
## KronburgTownKit's "ashlar" (here blockwork, its UVs scaled to 25cm courses), "pane" (opaque dark glass), "enamel",
## "gold"; YardKit's "concrete", "timber", "painted", "iron"; CampKit's vertex-colour "steel", "metal", "matte", "paint",
## "rubber", "chrome", "plastic", "wood", "canvas". The moving parts (the crane's top, the excavator's upper, the roller,
## the Leitbake) use only keys whose look does not come from the world position.
##
## Faces never share a plane: trims, glass and panels stand 2.5cm or more proud of what is behind them and parts that meet
## overlap or step. Godot's front faces wind clockwise: PropKit.tri winds every triangle for the `out` it's given.

const PropKit = preload("res://PropKit.gd")
const SW = preload("res://SteelworksKit.gd")
const KT = preload("res://KronburgTownKit.gd")
const YK = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")

static var uvk := 1.6
static var _mats := {}

const SW_KEYS := ["glass", "skylight", "rusty", "corten", "grime", "shell", "hazard", "lamp", "lens", "heap", "brick"]
const KT_KEYS := ["ashlar", "kbrick", "pane", "gold", "enamel"]
const TANGENT_KEYS := ["iron", "concrete", "bclad"]

const UP := Vector3.UP
const WHITE := Color(0.93, 0.93, 0.91)
const BLACK := Color(0.03, 0.03, 0.03)
const DARK := Color(0.12, 0.12, 0.13)
const UNDERCARRIAGE := Color(0.13, 0.13, 0.13)
const STEEL_GREY := Color(0.36, 0.37, 0.38)
const GALV := Color(0.70, 0.72, 0.73)
const CONC := Color(0.70, 0.69, 0.66)
const CONC_FRESH := Color(0.60, 0.60, 0.58)
const CRANE_YELLOW := Color(0.95, 0.72, 0.10)
const EXC_YELLOW := Color(0.96, 0.64, 0.08)
const ROLLER_ORANGE := Color(0.92, 0.46, 0.08)
const DUMPER_YELLOW := Color(0.95, 0.76, 0.12)
## KRONBAU's colours: a deep blue and a yellow.
const KB_BLUE := Color(0.07, 0.20, 0.46)
const KB_YELLOW := Color(0.98, 0.78, 0.12)
const NET_GREEN := Color(0.11, 0.33, 0.21)
const GLASS_DARK := Color(0.10, 0.14, 0.18)
const RUST := Color(0.45, 0.24, 0.14)
const TIMBER := Color(0.72, 0.56, 0.36)
const PLY_YELLOW := Color(0.88, 0.72, 0.32)
const WARN_RED := Color(0.80, 0.07, 0.05, 0.2)
const AMBER := Color(1.0, 0.62, 0.08)
const RED_LAMP := Color(1.0, 0.12, 0.06)
## bpaint's vertex alpha for yellow-and-black hazard stripes.
const HAZ := 0.5

## The builder, on the fence banners, the crane, the sign and the site office.
const BUILDER := "KRONBAU GmbH"


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"bpaint":
			var p := ShaderMaterial.new()
			p.shader = load("res://baustelle_paint.gdshader")
			return p
		"bmesh", "bnet", "brebar":
			var m := ShaderMaterial.new()
			m.shader = load("res://baustelle_mesh.gdshader")
			match key:
				"bmesh":
					m.set_shader_parameter("mode", 0)
					m.set_shader_parameter("cell", Vector2(0.1, 0.3))
					m.set_shader_parameter("wire", 0.0045)
				"bnet":
					m.set_shader_parameter("mode", 1)
					m.set_shader_parameter("extent", Vector2(BANNER_W, BANNER_H))
				"brebar":
					m.set_shader_parameter("mode", 2)
					m.set_shader_parameter("cell", Vector2(0.15, 0.15))
					m.set_shader_parameter("wire", 0.01)
			return m
		"bclad":
			var c := ShaderMaterial.new()
			c.shader = load("res://hut_roof_iron.gdshader")
			c.set_shader_parameter("pitch", 0.28 * 1.6)
			c.set_shader_parameter("sheet_w", 400.0)
			c.set_shader_parameter("sheet_len", 400.0)
			c.set_shader_parameter("rust_amount", 0.05)
			return c
		"bsand", "brubble":
			var r := ShaderMaterial.new()
			r.shader = load("res://mina_rubble.gdshader")
			if key == "bsand":
				r.set_shader_parameter("pebble_tex", load("res://materials/sand.png"))
				r.set_shader_parameter("pebble_normal", load("res://materials/sand_normal.png"))
				r.set_shader_parameter("scale", 0.6)
				r.set_shader_parameter("grain", 0.9)
			else:
				r.set_shader_parameter("pebble_tex", load("res://materials/dark_canyon_rock.png"))
				r.set_shader_parameter("pebble_normal", load("res://materials/dark_canyon_rock_normal.png"))
				r.set_shader_parameter("scale", 0.55)
				r.set_shader_parameter("grain", 1.7)
			return r
		"btyre":
			var t := ShaderMaterial.new()
			t.shader = load("res://mina_tyre.gdshader")
			t.set_shader_parameter("dust", Color(0.50, 0.47, 0.42))
			t.set_shader_parameter("dust_top", 1.1)
			t.set_shader_parameter("lugs", 30.0)
			return t
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


## `col` with the alpha `a` (bpaint's stripe codes).
static func _a(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, a)


## A box centred at `c` turned by `basis`, UVs in metres.
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## An axis-aligned block between two corners (in any order), UVs in metres.
static func _blk(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color) -> void:
	pk.block(kit, key, Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)), Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)), col, uvk)


## An axis-aligned block without its bottom face (standing on something), UVs in metres.
static func _blk_nb(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	pk.box(kit, key, Transform3D(Basis(), (lo + hi) * 0.5), hi - lo, col, uvk, true)


## A beam's four long sides from a to b (no end caps: members whose ends meet other members), `w` wide along `side` (or
## any horizontal), `t` thick.
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


## A round bar from a to b, radius r.
static func _rod(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, r: float, segs: int, col: Color, caps := true) -> void:
	pk.tube(kit, key, a, b, r, r, segs, col, caps)


## A polyline of round bar (a rope, a hose, a hook), radius r, no caps between its pieces.
static func _rope(pk: PropKit, kit: Dictionary, key: String, pts: Array, r: float, segs: int, col: Color) -> void:
	for i in range(pts.size() - 1):
		pk.tube(kit, key, pts[i], pts[i + 1], r, r, segs, col, i == 0 or i == pts.size() - 2)


## An outline in the side plane (Vector2(z, y)) extruded across x from x0 to x1, its edges bevelled by `bevel`.
static func _side_prism(pk: PropKit, kit: Dictionary, key: String, outline: PackedVector2Array, x0: float, x1: float, col: Color, bevel := 0.0, uv := 0.0) -> void:
	# The kit's x turned onto z and its z onto -x (a quarter turn about y), so the extrusion runs across x.
	var saved := _push(pk, Transform3D(Basis(UP, -PI * 0.5), Vector3.ZERO))
	pk.extrude(kit, key, outline, -x1, -x0, bevel, col, Callable(), uv)
	_pop(pk, saved)


## An outline in plan (Vector2(x, z)) extruded up from y0 to y1, its edges bevelled by `bevel`.
static func _plan_prism(pk: PropKit, kit: Dictionary, key: String, outline: PackedVector2Array, y0: float, y1: float, col: Color, bevel := 0.0, uv := 0.0) -> void:
	# The kit's y turned onto z and its z onto -y (a quarter turn about x), so the extrusion runs up.
	var saved := _push(pk, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	pk.extrude(kit, key, outline, -y1, -y0, bevel, col, Callable(), uv)
	_pop(pk, saved)


## A flat quad with its corner at p0, `w` along `along` and `h` along `up`, facing `out`, UVs from (0, 0) in metres times
## `uvs` (pass uvk for the tiling shaders, 1.0 for life metres).
static func _panel(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, upv: Vector3, out: Vector3, w: float, h: float, col: Color, uvs := 1.0) -> void:
	pk.quad(kit, key, [p0, p0 + along * w, p0 + along * w + upv * h, p0 + upv * h], out, col,
			[Vector2(0, 0), Vector2(w * uvs, 0), Vector2(w * uvs, h * uvs), Vector2(0, h * uvs)])


## A pane of dark glass (KronburgTownKit's "pane") centred at `c`, `w` along `along`, `h` along `upv`, facing `out`.
static func _pane(pk: PropKit, kit: Dictionary, c: Vector3, along: Vector3, upv: Vector3, out: Vector3, w: float, h: float, col := GLASS_DARK) -> void:
	var hu: Vector3 = along * (w * 0.5)
	var hv: Vector3 = upv * (h * 0.5)
	pk.quad(kit, "pane", [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv], out, col)


## A solid box for a collider: [Transform3D, size] in the prop's frame (life metres).
static func _solid(list: Array, c: Vector3, size: Vector3, basis := Basis()) -> void:
	list.append([Transform3D(basis, c), size])


## A solid box between two corners.
static func _solid_blk(list: Array, a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	list.append([Transform3D(Basis(), (lo + hi) * 0.5), hi - lo])


## A solid box along a..b (its long axis), `w` across and `t` thick (the beam's frame).
static func _solid_beam(list: Array, a: Vector3, b: Vector3, w: float, t: float) -> void:
	var ax := b - a
	var length := ax.length()
	if length < 1e-4:
		return
	var z := ax / length
	var x := UP.cross(z)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	list.append([Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(w, t, length)])


## A tyre about the x axis through `c`, mina_tyre's UVs (x round, y across the section: sidewall, tread, sidewall), and the
## rim's disc, hub and nuts on its outer side (`out` +1 or -1 along x).
static func _wheel(pk: PropKit, kit: Dictionary, c: Vector3, r_in: float, r_out: float, w: float, out: float, rim_col: Color, segs := 14, nuts := 8) -> void:
	var tip := Basis(Vector3.BACK, PI * 0.5)   # the lathe's y onto -x: the wheel turns about x
	var rr: float = minf(w * 0.3, (r_out - r_in) * 0.32)
	var h: float = w * 0.5
	var prof: Array = [[r_in + 0.01, -h + 0.02, 0.0], [r_in + rr * 0.8, -h, 0.08], [r_out - rr, -h + 0.002, 0.26], [r_out, -h + rr, 0.34],
			[r_out + 0.006, 0.0, 0.5], [r_out, h - rr, 0.66], [r_out - rr, h - 0.002, 0.74], [r_in + rr * 0.8, h, 0.92], [r_in + 0.01, h - 0.02, 1.0]]
	for k in range(prof.size() - 1):
		var p0: Array = prof[k]
		var p1: Array = prof[k + 1]
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
			pk.tri(kit, "btyre", q00, q01, q11, n0, n1, n1, BLACK, o, Vector2(float(j) / segs, float(p0[2])), Vector2(float(j + 1) / segs, float(p0[2])),
					Vector2(float(j + 1) / segs, float(p1[2])))
			pk.tri(kit, "btyre", q00, q11, q10, n0, n1, n0, BLACK, o, Vector2(float(j) / segs, float(p0[2])), Vector2(float(j + 1) / segs, float(p1[2])),
					Vector2(float(j) / segs, float(p1[2])))
	# The rim: a dished disc on the outer side, its barrel inside the tyre, the hub and nuts.
	var ox := Vector3(out, 0, 0)
	pk.tube(kit, "paint", c - ox * (h - 0.03), c + ox * (h - 0.05), r_in, r_in, segs, rim_col.darkened(0.3), false)
	var db := Basis(Vector3.BACK, -PI * 0.5 * out)   # the lathe's y onto +out x
	pk.lathe(kit, "paint", c + ox * (h * 0.35), [Vector2(r_in + 0.005, 0.0), Vector2(r_in * 0.85, 0.04), Vector2(r_in * 0.45, 0.07), Vector2(0.001, 0.08)], segs, rim_col, false, db)
	pk.tube(kit, "steel", c + ox * (h * 0.35 + 0.07), c + ox * (h * 0.35 + 0.16), r_in * 0.3, r_in * 0.24, 8, Color(0.25, 0.25, 0.25), true)
	for k in range(nuts):
		var a: float = TAU * float(k) / float(nuts)
		var bp: Vector3 = c + ox * (h * 0.35 + 0.07) + Vector3(0, sin(a), cos(a)) * (r_in * 0.42)
		pk.tube(kit, "steel", bp, bp + ox * 0.035, 0.018, 0.018, 4, Color(0.3, 0.3, 0.3), true)


## A loft between two outlines in plan (same point count, counter-clockwise from above) at heights y0 and y1, facing out (or
## in, for a container's inside).
static func _loft(pk: PropKit, kit: Dictionary, key: String, ol0: PackedVector2Array, y0: float, ol1: PackedVector2Array, y1: float, col: Color, inward := false) -> void:
	var n := ol0.size()
	for i in range(n):
		var j := (i + 1) % n
		var a := Vector3(ol0[i].x, y0, ol0[i].y)
		var b := Vector3(ol0[j].x, y0, ol0[j].y)
		var c := Vector3(ol1[j].x, y1, ol1[j].y)
		var d := Vector3(ol1[i].x, y1, ol1[i].y)
		var e := Vector2(ol0[j].x - ol0[i].x, ol0[j].y - ol0[i].y)
		var o := Vector3(e.y, 0.0, -e.x).normalized()
		var mid := (a + b + c + d) * 0.25
		if o.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
			o = -o
		var nrm: Vector3 = (c - a).cross(b - a).normalized()
		if nrm.dot(o) < 0.0:
			nrm = -nrm
		if inward:
			nrm = -nrm
		pk.quad(kit, key, [a, b, c, d], nrm, col)


## A flat polygon in plan at height y facing up (or down).
static func _flat(pk: PropKit, kit: Dictionary, key: String, ol: PackedVector2Array, y: float, up: bool, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(ol)
	var n: Vector3 = UP if up else Vector3.DOWN
	for i in range(0, tris.size(), 3):
		pk.tri(kit, key, Vector3(ol[tris[i]].x, y, ol[tris[i]].y), Vector3(ol[tris[i + 1]].x, y, ol[tris[i + 1]].y), Vector3(ol[tris[i + 2]].x, y, ol[tris[i + 2]].y),
				n, n, n, col, n)


## A rectangle in plan (half sizes) as an outline, counter-clockwise from above.
static func _rect(cx: float, cz: float, hx: float, hz: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - hx, cz + hz), Vector2(cx + hx, cz + hz), Vector2(cx + hx, cz - hz), Vector2(cx - hx, cz - hz)])


## A heap of loose material over an outline in plan: a grid of `nx` x `nz` cells between the half sizes, its height falling to
## the edges (a rounded dome times `h`) with noise, from `base` up; drawn in `key`.
static func _heap(pk: PropKit, kit: Dictionary, key: String, c: Vector3, hx: float, hz: float, h: float, nx: int, nz: int, col: Color, rng: RandomNumberGenerator,
		base := 0.0) -> void:
	var hs: Array = []
	for i in range(nx + 1):
		var row: Array = []
		for k in range(nz + 1):
			var u: float = lerpf(-1.0, 1.0, float(i) / float(nx))
			var v: float = lerpf(-1.0, 1.0, float(k) / float(nz))
			var d: float = clampf(maxf(absf(u), absf(v)) * 0.7 + Vector2(u, v).length() * 0.3, 0.0, 1.0)
			var y: float = base + h * (1.0 - d * d) * (0.8 + 0.4 * rng.randf())
			if i == 0 or k == 0 or i == nx or k == nz:
				y = base
			row.append(y)
		hs.append(row)
	for i in range(nx):
		for k in range(nz):
			var p: Array = []
			for dd in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var ii: int = i + dd.x
				var kk: int = k + dd.y
				p.append(c + Vector3(lerpf(-hx, hx, float(ii) / float(nx)), float(hs[ii][kk]), lerpf(-hz, hz, float(kk) / float(nz))))
			var n1: Vector3 = ((p[2] as Vector3) - (p[0] as Vector3)).cross((p[1] as Vector3) - (p[0] as Vector3)).normalized()
			if n1.y < 0.0:
				n1 = -n1
			var cc: Color = col.darkened(0.08 * rng.randf())
			pk.tri(kit, key, p[0], p[1], p[2], n1, n1, n1, cc, n1)
			var n2: Vector3 = ((p[3] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).normalized()
			if n2.y < 0.0:
				n2 = -n2
			pk.tri(kit, key, p[0], p[2], p[3], n2, n2, n2, cc, n2)


# ======================================================================================
#  The tower crane
# ======================================================================================

const TC_FOUND_HALF := 2.75   # the foundation block's half size (5.5 x 5.5, from y -1.5 to TC_FOUND_TOP)
const TC_FOUND_TOP := 0.1
const TC_MAST_HALF := 0.8     # the mast's chords' centre lines at (±0.8, ±0.8): 1.75 square over the chords
const TC_PANEL := 2.0         # the mast's bracing panels
const TC_DECK_Y := 1.0        # the turntable's top, in the top's frame (the mast's top at 0)
const TC_JIB_Y := 1.05        # the jib's bottom chords' centre line
const TC_JIB_H := 1.5         # its top chord over the bottom ones
const TC_JIB_HALF := 0.75     # the bottom chords at x ±0.75
const TC_JIB_LEN := 50.0      # the jib's tip at z = -50
const TC_CJIB_LEN := 14.0     # the counter-jib's end at z = +14
const TC_HEAD_Y := 11.0       # the tower head's apex
## The trolley's middle along the jib (the top's frame), where the hook hangs.
const TROLLEY_Z := -30.0
## The hook block's middle (15m under the jib's chords) and the load's middle, in the top's frame.
const TC_HOOK_Y := -13.95
const TC_LOAD_Y := -17.6


## A tower crane's mast: a 5.5 x 5.5m concrete foundation block (y -1.5 to 0.1) with base plates, a square lattice mast
## (chords 1.75 square, yellow) braced every 2m with section joints every 5.8m, a ladder inside up its +x side with rest
## platforms every 9m, and at the top (y = h) a frame carrying the slewing ring's fixed race (radius 1.0, from h - 0.2 to h).
## The crane's top (tower_crane_top) goes on at (0, h, 0).
static func tower_crane_mast(pk: PropKit, kit: Dictionary, h: float) -> void:
	var col := CRANE_YELLOW
	var m := TC_MAST_HALF
	_blk(pk, kit, "concrete", Vector3(-TC_FOUND_HALF, -1.5, -TC_FOUND_HALF), Vector3(TC_FOUND_HALF, TC_FOUND_TOP, TC_FOUND_HALF), CONC)
	var y0 := TC_FOUND_TOP + 0.12
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var p := Vector3(cx * m, TC_FOUND_TOP, cz * m)
			_blk_nb(pk, kit, "bpaint", p + Vector3(-0.26, 0.0, -0.26), p + Vector3(0.26, 0.12, 0.26), DARK)
			for bx in [-0.18, 0.18]:
				for bz in [-0.18, 0.18]:
					_rod(pk, kit, "steel", p + Vector3(bx, 0.1, bz), p + Vector3(bx, 0.2, bz), 0.025, 6, STEEL_GREY)
	var top: float = h - 0.35
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_bar(pk, kit, "bpaint", Vector3(cx * m, y0, cz * m), Vector3(cx * m, top, cz * m), 0.15, 0.15, col)
	# Section joints: fish plates round each chord every 5.8m.
	var sy: float = y0 + 5.8
	while sy < top - 1.0:
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				_blk(pk, kit, "bpaint", Vector3(cx * m - 0.11, sy - 0.15, cz * m - 0.11), Vector3(cx * m + 0.11, sy + 0.15, cz * m + 0.11), col.darkened(0.1))
		sy += 5.8
	# Bracing: a horizontal round each panel, a diagonal across each face, zigzagging up.
	var corners: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var n: int = maxi(int(round((top - y0) / TC_PANEL)), 1)
	for k in range(n + 1):
		var ya: float = lerpf(y0, top, float(k) / float(n))
		var yb: float = lerpf(y0, top, float(k + 1) / float(n))
		for f in range(4):
			var a2: Vector2 = corners[f]
			var b2: Vector2 = corners[(f + 1) % 4]
			var pa := Vector3(a2.x * m, ya, a2.y * m)
			var pb := Vector3(b2.x * m, ya, b2.y * m)
			_bar(pk, kit, "bpaint", pa, pb, 0.07, 0.07, col)
			if k < n:
				if (k + f) % 2 == 0:
					_bar(pk, kit, "bpaint", pa, Vector3(b2.x * m, yb, b2.y * m), 0.06, 0.06, col)
				else:
					_bar(pk, kit, "bpaint", pb, Vector3(a2.x * m, yb, a2.y * m), 0.06, 0.06, col)
	# The ladder inside, up the +x side, and its rest platforms.
	var lx := 0.5
	for sz in [-0.22, 0.22]:
		_bar(pk, kit, "steel", Vector3(lx, y0, sz), Vector3(lx, top, sz), 0.03, 0.06, STEEL_GREY, Vector3.FORWARD)
	var rungs: int = int((top - y0) / 0.3)
	for k in range(1, rungs):
		var ry: float = y0 + 0.3 * float(k)
		_bar(pk, kit, "steel", Vector3(lx, ry, -0.22), Vector3(lx, ry, 0.22), 0.028, 0.028, STEEL_GREY)
	var py: float = y0 + 9.0
	while py < top - 2.0:
		_blk(pk, kit, "steel", Vector3(-0.72, py - 0.05, -0.72), Vector3(0.3, py, 0.72), Color(0.3, 0.31, 0.3))
		py += 9.0
	# The top frame and the slewing ring's fixed race.
	for f in range(4):
		var a3: Vector2 = corners[f]
		var b3: Vector2 = corners[(f + 1) % 4]
		_bar(pk, kit, "bpaint", Vector3(a3.x * m, top + 0.08, a3.y * m), Vector3(b3.x * m, top + 0.08, b3.y * m), 0.18, 0.18, col.darkened(0.08))
	_blk(pk, kit, "bpaint", Vector3(-0.98, top + 0.17, -0.98), Vector3(0.98, h - 0.2, 0.98), col.darkened(0.12))
	pk.lathe(kit, "steel", Vector3(0, h - 0.2, 0), [Vector2(0.72, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.2), Vector2(0.72, 0.2)], 24, STEEL_GREY)


static func tower_crane_mast_solids(h: float) -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-TC_FOUND_HALF, -1.5, -TC_FOUND_HALF), Vector3(TC_FOUND_HALF, TC_FOUND_TOP, TC_FOUND_HALF))
	_solid_blk(s, Vector3(-0.9, TC_FOUND_TOP, -0.9), Vector3(0.9, h, 0.9))
	return s


## The slewing part of the tower crane (a hammerhead), built about the origin, which goes on the mast's top: the slewing
## ring's turning race (y 0.01 to 0.23) and the turntable (to TC_DECK_Y 1.0); the operator's cab beside the jib's root (x
## -2.35..-1.0); the tower head, a lattice pyramid to TC_HEAD_Y (11.0) with an aviation light and an anemometer; the jib
## toward -z (TC_JIB_LEN 50, a triangular lattice: bottom chords at x ±0.75, y 1.05, the top chord 1.5 over them) held by two
## pendants from the apex, with its trolley at TROLLEY_Z (-30), the hook block 15m under it (TC_HOOK_Y) and the load (`load`:
## "rebar" a bundle of bars on a two-leg chain, "skip" a concrete skip on its bail, "none") at TC_LOAD_Y; the counter-jib
## toward +z (TC_CJIB_LEN 14) with its walkway, railings, the hoist winch, a switch cabinet, four concrete counterweight slabs
## hanging at its end, and BUILDER's name on boards along both railings (labels facing ±x).
static func tower_crane_top(pk: PropKit, kit: Dictionary, labels: Array, load := "rebar") -> void:
	var col := CRANE_YELLOW
	pk.lathe(kit, "steel", Vector3(0, 0.01, 0), [Vector2(0.78, 0.0), Vector2(1.06, 0.0), Vector2(1.06, 0.22), Vector2(0.78, 0.22)], 24, Color(0.2, 0.2, 0.21))
	_blk(pk, kit, "bpaint", Vector3(-1.05, 0.23, -1.05), Vector3(1.05, TC_DECK_Y - 0.06, 1.05), col)
	_blk(pk, kit, "steel", Vector3(-1.3, TC_DECK_Y - 0.06, -1.3), Vector3(1.3, TC_DECK_Y, 1.3), Color(0.3, 0.31, 0.3))
	_crane_cab(pk, kit)
	_crane_head(pk, kit, col)
	_crane_jib(pk, kit, col)
	_crane_counter_jib(pk, kit, labels, col)
	_crane_hook(pk, kit, load)


static func _crane_cab(pk: PropKit, kit: Dictionary) -> void:
	var col := CRANE_YELLOW
	# Its bracket off the turntable's side and a floor walkway.
	_blk(pk, kit, "bpaint", Vector3(-2.45, 0.12, -2.5), Vector3(-1.0, 0.3, -0.5), col.darkened(0.15))
	_bar(pk, kit, "bpaint", Vector3(-1.05, 0.2, -1.9), Vector3(-1.05, 0.9, -1.0), 0.12, 0.12, col.darkened(0.15))
	var ol := PackedVector2Array([Vector2(-0.5, 0.3), Vector2(-0.5, 2.55), Vector2(-2.3, 2.55), Vector2(-2.4, 2.45), Vector2(-2.4, 0.8), Vector2(-2.15, 0.3)])
	_side_prism(pk, kit, "bpaint", ol, -2.35, -1.0, Color(0.92, 0.9, 0.86), 0.04)
	_blk(pk, kit, "bpaint", Vector3(-2.42, 2.53, -2.5), Vector3(-0.95, 2.62, -0.45), col)
	# Glazing: the front, the slanted lower front, the outer side, half the inner side.
	_pane(pk, kit, Vector3(-1.675, 1.63, -2.425), Vector3.RIGHT, UP, Vector3.FORWARD, 1.17, 1.5)
	var a := Vector3(0, 0.8, -2.4)
	var b := Vector3(0, 0.3, -2.15)
	var nrm := Vector3(0, -0.25, -0.5).normalized()
	var mid: Vector3 = (a + b) * 0.5 + nrm * 0.025
	_pane(pk, kit, Vector3(-1.675, mid.y, mid.z), Vector3.RIGHT, (a - b).normalized(), nrm, 1.1, 0.42)
	_pane(pk, kit, Vector3(-2.375, 1.62, -1.45), Vector3.BACK, UP, Vector3.LEFT, 1.6, 1.45)
	_pane(pk, kit, Vector3(-0.975, 1.7, -1.75), Vector3.BACK, UP, Vector3.RIGHT, 0.95, 1.2)
	# A wiper and a grab rail.
	_bar(pk, kit, "steel", Vector3(-1.7, 1.0, -2.45), Vector3(-1.5, 1.95, -2.45), 0.02, 0.012, BLACK)
	_rod(pk, kit, "steel", Vector3(-2.4, 0.6, -0.4), Vector3(-2.4, 2.3, -0.4), 0.02, 5, GALV)


static func _crane_head(pk: PropKit, kit: Dictionary, col: Color) -> void:
	var y0 := TC_DECK_Y
	var yt := TC_HEAD_Y - 0.35
	var b0 := 0.8
	var b1 := 0.28
	var corners: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c in corners:
		var cc: Vector2 = c
		_bar(pk, kit, "bpaint", Vector3(cc.x * b0, y0, cc.y * b0), Vector3(cc.x * b1, yt, cc.y * b1), 0.16, 0.16, col)
	var n := 4
	for k in range(n + 1):
		var t0: float = float(k) / float(n)
		var t1: float = float(k + 1) / float(n)
		var ya: float = lerpf(y0 + 0.2, yt, t0)
		var yb: float = lerpf(y0 + 0.2, yt, t1)
		var ra: float = lerpf(b0, b1, (ya - y0) / (yt - y0))
		var rb: float = lerpf(b0, b1, (yb - y0) / (yt - y0))
		for f in range(4):
			var a2: Vector2 = corners[f]
			var c2: Vector2 = corners[(f + 1) % 4]
			if k > 0:
				_bar(pk, kit, "bpaint", Vector3(a2.x * ra, ya, a2.y * ra), Vector3(c2.x * ra, ya, c2.y * ra), 0.07, 0.07, col)
			if k < n:
				if (k + f) % 2 == 0:
					_bar(pk, kit, "bpaint", Vector3(a2.x * ra, ya, a2.y * ra), Vector3(c2.x * rb, yb, c2.y * rb), 0.06, 0.06, col)
				else:
					_bar(pk, kit, "bpaint", Vector3(c2.x * ra, ya, c2.y * ra), Vector3(a2.x * rb, yb, a2.y * rb), 0.06, 0.06, col)
	# The apex: a cap with the pendants' pin plates, a little platform, the aviation light and the anemometer.
	_blk(pk, kit, "bpaint", Vector3(-0.42, yt - 0.05, -0.42), Vector3(0.42, TC_HEAD_Y, 0.42), col.darkened(0.08))
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "bpaint", Vector3(-0.2, TC_HEAD_Y - 0.5, sz * 0.42 - 0.03), Vector3(0.2, TC_HEAD_Y - 0.05, sz * 0.42 + 0.03), col.darkened(0.2))
	_rod(pk, kit, "steel", Vector3(0.2, TC_HEAD_Y, 0.2), Vector3(0.2, TC_HEAD_Y + 0.6, 0.2), 0.03, 6, STEEL_GREY)
	pk.lathe(kit, "lamp", Vector3(0.2, TC_HEAD_Y + 0.6, 0.2), [Vector2(0.001, 0.0), Vector2(0.08, 0.0), Vector2(0.08, 0.12), Vector2(0.001, 0.16)], 8, RED_LAMP)
	_rod(pk, kit, "steel", Vector3(-0.25, TC_HEAD_Y, -0.2), Vector3(-0.25, TC_HEAD_Y + 1.4, -0.2), 0.025, 6, STEEL_GREY)
	for k in range(3):
		var a: float = TAU * float(k) / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var tip: Vector3 = Vector3(-0.25, TC_HEAD_Y + 1.45, -0.2) + d * 0.22
		_rod(pk, kit, "steel", Vector3(-0.25, TC_HEAD_Y + 1.45, -0.2), tip, 0.01, 4, STEEL_GREY, false)
		pk.lathe(kit, "plastic", tip, [Vector2(0.001, -0.04), Vector2(0.05, -0.02), Vector2(0.05, 0.02), Vector2(0.001, 0.04)], 6, WHITE)


## The jib's chords and lacing (bottom chords at ±TC_JIB_HALF, TC_JIB_Y; the top chord at x 0 over them), its tip frame, the
## two pendants from the apex, the trolley ropes along it and the tip's light.
static func _crane_jib(pk: PropKit, kit: Dictionary, col: Color) -> void:
	var yb := TC_JIB_Y
	var yt := TC_JIB_Y + TC_JIB_H
	var z0 := -1.0
	var z1 := -TC_JIB_LEN
	var zt1 := z1 + 1.2
	for sx in [-1.0, 1.0]:
		_bar(pk, kit, "bpaint", Vector3(sx * TC_JIB_HALF, yb, z0), Vector3(sx * TC_JIB_HALF, yb, z1), 0.15, 0.14, col)
	_bar(pk, kit, "bpaint", Vector3(0, yt, z0), Vector3(0, yt, zt1), 0.14, 0.14, col)
	var n: int = int(round((zt1 - z0) / -2.45))
	for k in range(n + 1):
		var za: float = lerpf(z0, zt1, float(k) / float(n))
		var zb: float = lerpf(z0, zt1, float(k + 1) / float(n))
		var zm: float = (za + zb) * 0.5
		_bar(pk, kit, "bpaint", Vector3(-TC_JIB_HALF, yb, za), Vector3(TC_JIB_HALF, yb, za), 0.06, 0.06, col)
		if k < n:
			for sx in [-1.0, 1.0]:
				var bot_a := Vector3(sx * TC_JIB_HALF, yb, za)
				var bot_b := Vector3(sx * TC_JIB_HALF, yb, zb)
				var topm := Vector3(0, yt, zm)
				_bar(pk, kit, "bpaint", bot_a, topm, 0.065, 0.065, col)
				_bar(pk, kit, "bpaint", topm, bot_b, 0.065, 0.065, col)
			if k % 2 == 0:
				_bar(pk, kit, "bpaint", Vector3(-TC_JIB_HALF, yb, za), Vector3(TC_JIB_HALF, yb, zb), 0.05, 0.05, col)
			else:
				_bar(pk, kit, "bpaint", Vector3(TC_JIB_HALF, yb, za), Vector3(-TC_JIB_HALF, yb, zb), 0.05, 0.05, col)
	# The tip: the top chord down to the bottom chords' ends, a cross member, the light.
	for sx in [-1.0, 1.0]:
		_bar(pk, kit, "bpaint", Vector3(0, yt, zt1), Vector3(sx * TC_JIB_HALF, yb, z1), 0.1, 0.1, col)
	_bar(pk, kit, "bpaint", Vector3(-TC_JIB_HALF, yb, z1), Vector3(TC_JIB_HALF, yb, z1), 0.12, 0.12, col)
	pk.lathe(kit, "lamp", Vector3(0, yt + 0.07, zt1), [Vector2(0.001, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.1), Vector2(0.001, 0.14)], 8, RED_LAMP)
	# The pendants (two bars each) from the apex's pin plates to the top chord.
	var apex := Vector3(0, TC_HEAD_Y - 0.25, -0.42)
	for pz in [-22.0, -40.0]:
		for sx in [-0.07, 0.07]:
			_rod(pk, kit, "steel", apex + Vector3(sx, 0, 0), Vector3(sx, yt + 0.05, pz), 0.032, 5, col.darkened(0.25), false)
		_blk(pk, kit, "bpaint", Vector3(-0.14, yt - 0.02, pz - 0.2), Vector3(0.14, yt + 0.16, pz + 0.2), col.darkened(0.2))
	# The trolley's ropes along the jib, between the bottom chords.
	for sx in [-0.12, 0.12]:
		_rod(pk, kit, "steel", Vector3(sx, yb - 0.18, z0 - 0.3), Vector3(sx, yb - 0.18, z1 + 0.6), 0.012, 4, Color(0.18, 0.18, 0.18), false)
	# The trolley.
	var tz := TROLLEY_Z
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "bpaint", Vector3(sx * 0.92 - 0.04, 0.42, tz - 0.85), Vector3(sx * 0.92 + 0.04, 1.36, tz + 0.85), col.darkened(0.05))
		for wz in [-0.55, 0.55]:
			_rod(pk, kit, "steel", Vector3(sx * 0.62, 1.24, tz + wz), Vector3(sx * 0.95, 1.24, tz + wz), 0.12, 10, DARK)
	for wz in [-0.6, 0.6]:
		_blk(pk, kit, "bpaint", Vector3(-0.96, 0.42, tz + wz - 0.08), Vector3(0.96, 0.58, tz + wz + 0.08), col.darkened(0.1))
	for sx in [-0.3, 0.3]:
		_rod(pk, kit, "steel", Vector3(sx - 0.04, 0.5, tz), Vector3(sx + 0.04, 0.5, tz), 0.22, 12, DARK)
		for dz in [-0.2, 0.2]:
			_rod(pk, kit, "steel", Vector3(sx, 0.3, tz + dz), Vector3(sx * 0.6, TC_HOOK_Y + 0.45, tz + dz * 0.5), 0.014, 4, Color(0.15, 0.15, 0.15), false)


static func _crane_counter_jib(pk: PropKit, kit: Dictionary, labels: Array, col: Color) -> void:
	var z0 := 1.0
	var z1 := TC_CJIB_LEN
	var yd := 1.5
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "bpaint", Vector3(sx * 0.85 - 0.1, 0.98, z0), Vector3(sx * 0.85 + 0.1, yd - 0.02, z1), col)
	var zc: float = z0 + 0.3
	while zc < z1:
		_blk(pk, kit, "bpaint", Vector3(-0.75, 1.1, zc - 0.07), Vector3(0.75, yd - 0.04, zc + 0.07), col.darkened(0.08))
		zc += 2.6
	_blk(pk, kit, "steel", Vector3(-1.05, yd - 0.04, z0 + 0.1), Vector3(1.05, yd + 0.01, 10.6), Color(0.3, 0.31, 0.3))
	for sx in [-1.0, 1.0]:
		SW._railing(pk, kit, [Vector3(sx * 1.0, yd, z0 + 0.4), Vector3(sx * 1.0, yd, 10.5)], 1.1, col, "paint")
	SW._railing(pk, kit, [Vector3(-1.0, yd, 10.5), Vector3(1.0, yd, 10.5)], 1.1, col, "paint")
	# The hoist winch: drum, flanges, gearbox and motor.
	var wz := 7.4
	_rod(pk, kit, "steel", Vector3(-0.55, 2.05, wz), Vector3(0.55, 2.05, wz), 0.34, 16, Color(0.22, 0.22, 0.22))
	for sx in [-0.58, 0.58]:
		_rod(pk, kit, "bpaint", Vector3(sx - 0.03, 2.05, wz), Vector3(sx + 0.03, 2.05, wz), 0.48, 16, col.darkened(0.2))
		_blk(pk, kit, "bpaint", Vector3(sx - 0.06, yd, wz - 0.35), Vector3(sx + 0.06, 2.1, wz + 0.35), col.darkened(0.25))
	_blk(pk, kit, "bpaint", Vector3(0.62, yd, wz - 0.4), Vector3(1.0, 2.45, wz + 0.4), Color(0.25, 0.3, 0.33))
	_rod(pk, kit, "bpaint", Vector3(0.0, 1.95, wz + 0.75), Vector3(0.0, 1.95, wz + 1.6), 0.26, 12, Color(0.25, 0.3, 0.33))
	_blk(pk, kit, "bpaint", Vector3(-0.3, yd, wz + 0.55), Vector3(0.3, 1.7, wz + 1.75), DARK)
	# The switch cabinet.
	_blk(pk, kit, "bpaint", Vector3(-0.85, yd, 3.4), Vector3(-0.15, 2.65, 4.2), Color(0.62, 0.63, 0.62))
	_blk(pk, kit, "steel", Vector3(-0.83, 2.2, 4.2), Vector3(-0.55, 2.4, 4.23), DARK)
	# The counterweight slabs hanging at the end, their lifting lugs on the girders.
	for k in range(4):
		var za: float = 10.85 + 0.66 * float(k)
		_blk(pk, kit, "concrete", Vector3(-0.72, -1.55, za), Vector3(0.72, 1.42, za + 0.6), CONC.darkened(0.04 * float(k % 2)))
		for sx in [-0.75, 0.75]:
			_blk(pk, kit, "steel", Vector3(sx - 0.05, 1.3, za + 0.2), Vector3(sx + 0.05, 1.58, za + 0.4), DARK)
	pk.lathe(kit, "lamp", Vector3(0, 1.48, z1 - 0.15), [Vector2(0.001, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.1), Vector2(0.001, 0.14)], 8, RED_LAMP)
	# The pendants to the counter-jib's end.
	var apex := Vector3(0, TC_HEAD_Y - 0.25, 0.42)
	for sx in [-1.0, 1.0]:
		_rod(pk, kit, "steel", apex + Vector3(sx * 0.1, 0, 0), Vector3(sx * 0.85, yd, z1 - 0.3), 0.035, 5, col.darkened(0.25), false)
	# BUILDER's boards along both railings.
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.1
		_blk(pk, kit, "enamel", Vector3(x - 0.02, yd + 0.12, 3.2), Vector3(x + 0.02, yd + 1.02, 10.2), KB_BLUE)
		_blk(pk, kit, "enamel", Vector3(x - 0.025, yd + 0.12, 3.2), Vector3(x + 0.025, yd + 0.22, 10.2), KB_YELLOW)
		_lbl(labels, "KRONBAU", Vector3(x + sx * 0.03, yd + 0.62, 6.7), Vector3(sx, 0, 0), 0.5, Color(0.98, 0.97, 0.94), 6.6)


## The hook block (yellow-and-black), its hook, and the load on it.
static func _crane_hook(pk: PropKit, kit: Dictionary, load: String) -> void:
	var tz := TROLLEY_Z
	var hy := TC_HOOK_Y
	_box(pk, kit, "bpaint", Vector3(0, hy, tz), Basis(), Vector3(0.62, 0.8, 0.34), _a(CRANE_YELLOW, HAZ))
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "bpaint", Vector3(-0.36, hy - 0.42, tz + sz * 0.17), Vector3(0.36, hy + 0.32, tz + sz * 0.2), DARK)
	_rod(pk, kit, "steel", Vector3(0, hy - 0.4, tz), Vector3(0, hy - 0.62, tz), 0.06, 8, STEEL_GREY)
	# The hook: a shank and a bowl round to its tip, with the safety latch.
	var hc := Vector3(0, hy - 0.86, tz)
	var pts: Array = [Vector3(0.0, hy - 0.62, tz), hc + Vector3(0.14, 0.04, 0)]
	for k in range(8):
		var a: float = deg_to_rad(-10.0 - 30.0 * float(k))
		pts.append(hc + Vector3(cos(a) * 0.15, sin(a) * 0.15, 0))
	_rope(pk, kit, "steel", pts, 0.045, 8, Color(0.26, 0.26, 0.27))
	_bar(pk, kit, "steel", hc + Vector3(0.14, 0.04, 0), (pts[-1] as Vector3), 0.03, 0.01, CRANE_YELLOW)
	var bowl: Vector3 = hc + Vector3(0, -0.14, 0)
	match load:
		"rebar":
			var ly := TC_LOAD_Y
			for sx in [-1.0, 1.0]:
				var end := Vector3(sx * 2.0, ly + 0.17, tz)
				_rope(pk, kit, "steel", [bowl, end], 0.022, 5, Color(0.2, 0.19, 0.18))
				# The chain's loop round the bundle.
				var ring: Array = []
				for k in range(9):
					var a2: float = TAU * float(k) / 8.0
					ring.append(Vector3(sx * 2.0, ly + sin(a2) * 0.19, tz + cos(a2) * 0.19))
				_rope(pk, kit, "steel", ring, 0.018, 4, Color(0.2, 0.19, 0.18))
			_box(pk, kit, "steel", Vector3(0, ly, tz), Basis(), Vector3(6.0, 0.24, 0.24), Color(0.28, 0.16, 0.1))
			for k in range(12):
				var a3: float = TAU * float(k) / 12.0
				var o := Vector3(0, sin(a3) * 0.14, cos(a3) * 0.14)
				var dx: float = 0.05 * float((k * 7) % 5)
				pk.beam(kit, "steel", Vector3(-3.05 + dx, ly, tz) + o, Vector3(3.05 - dx * 0.6, ly, tz) + o, 0.028, 0.028, RUST.darkened(0.05 * float(k % 3)), Vector3.FORWARD)
			for wx in [-2.6, -0.8, 0.8, 2.6]:
				_rod(pk, kit, "steel", Vector3(wx - 0.02, ly, tz), Vector3(wx + 0.02, ly, tz), 0.17, 8, Color(0.3, 0.3, 0.3))
		"skip":
			var sy := hy - 1.35
			var by := sy - 2.4
			pk.lathe(kit, "bpaint", Vector3(0, by, tz), [Vector2(0.2, -0.25), Vector2(0.2, 0.0), Vector2(0.72, 1.35), Vector2(0.76, 1.95), Vector2(0.8, 2.0),
					Vector2(0.7, 2.0)], 16, Color(0.55, 0.55, 0.53))
			pk.lathe(kit, "bpaint", Vector3(0, by, tz), [Vector2(0.68, 1.98), Vector2(0.68, 1.4), Vector2(0.2, 0.05)], 16, Color(0.42, 0.42, 0.4))
			_flat(pk, kit, "brubble", _rect(0.0, tz, 0.5, 0.5), by + 1.7, true, Color(0.62, 0.61, 0.58))
			_blk(pk, kit, "bpaint", Vector3(-0.16, by - 0.4, tz - 0.16), Vector3(0.16, by - 0.25, tz + 0.16), DARK)
			for sx in [-1.0, 1.0]:
				_rod(pk, kit, "steel", Vector3(sx * 0.8, by + 1.6, tz), Vector3(sx * 0.9, by + 1.6, tz), 0.06, 8, DARK)
			_rope(pk, kit, "bpaint", [Vector3(-0.88, by + 1.6, tz), Vector3(-0.8, by + 2.6, tz), Vector3(-0.3, bowl.y - 0.1, tz), Vector3(0.3, bowl.y - 0.1, tz),
					Vector3(0.8, by + 2.6, tz), Vector3(0.88, by + 1.6, tz)], 0.05, 6, CRANE_YELLOW.darkened(0.2))


# ======================================================================================
#  The excavator
# ======================================================================================

## The slewing ring's top over the ground: the upper (excavator_upper) turns about the y axis through (0, EXC_RING_Y, 0).
const EXC_RING_Y := 1.15
const EXC_TRACK_X := 1.2      # the tracks' middles (gauge 2.4), shoes 0.6 wide: 3.0 over the tracks
const EXC_TRACK_L := 4.6      # over the tracks' ends
const EXC_TAIL_R := 2.75      # the counterweight's tail swing radius (the upper's frame)
const EXC_BOOM_X := 0.25      # the arm's plane, a little right of the middle
## The arm's pins in the upper's frame (origin on the ring's top, the boom toward -z): the boom's foot, its knee and tip
## (the stick's pivot), the stick's top end and its lower end (the bucket's pin).
const EXC_F := Vector3(0.25, 0.95, -1.3)
const EXC_K := Vector3(0.25, 4.3, -4.0)
const EXC_T := Vector3(0.25, 4.044, -6.953)
const EXC_S := Vector3(0.25, 1.45, -8.25)
## The bucket: its shell is an arc of radius EXC_BUCKET_R round EXC_BUCKET (the upper's frame), its lowest point 0.9 over the
## base's ground (y -0.25 here, 0.25 under the ring's top... EXC_RING_Y - 0.25 = 0.9 over the ground) and 8.42 out.
const EXC_BUCKET := Vector3(0.25, 0.37, -8.42)
const EXC_BUCKET_R := 0.62
## A box round the bucket and the stick's low end (centre and half size, the upper's frame) for the hit test.
const EXC_HIT_C := Vector3(0.25, 0.85, -8.44)
const EXC_HIT_HALF := Vector3(0.68, 1.12, 0.64)


## A 26-tonne crawler excavator's undercarriage (an original design, the maker KALMBERG): two tracks of shoes round a
## sprocket (rear, +z) and an idler (front, -z) at x ±1.2 (EXC_TRACK_L 4.6 long, 3.0 over the tracks, 1.07 high), seven
## bottom rollers and two carriers each, the track frames, the carbody between them and the slewing ring's fixed race, its
## top at EXC_RING_Y (1.15). The upper (excavator_upper) goes on at (0, EXC_RING_Y, 0). The maker's name on the track frames.
static func excavator(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	for sx in [-1.0, 1.0]:
		_exc_track(pk, kit, sx * EXC_TRACK_X)
	var fc := UNDERCARRIAGE
	# The carbody: a centre box with sloping sides into the track frames, the ring's fixed race on top.
	var ol := PackedVector2Array([Vector2(-1.25, 0.45), Vector2(1.25, 0.45), Vector2(1.0, 0.98), Vector2(-1.0, 0.98)])
	pk.extrude(kit, "bpaint", ol, -0.95, 0.95, 0.04, fc)
	_blk(pk, kit, "bpaint", Vector3(-0.55, 0.38, -1.25), Vector3(0.55, 0.9, 1.25), fc.darkened(0.1))
	pk.lathe(kit, "bpaint", Vector3(0, 0.95, 0), [Vector2(0.75, 0.0), Vector2(0.95, 0.0), Vector2(0.95, EXC_RING_Y - 0.95), Vector2(0.7, EXC_RING_Y - 0.95)], 24, Color(0.18, 0.18, 0.18))
	for sx in [-1.0, 1.0]:
		_lbl(labels, "KALMBERG", Vector3(sx * (EXC_TRACK_X + 0.26), 0.66, -0.2), Vector3(sx, 0, 0), 0.13, EXC_YELLOW, 1.4)


## One track at x = sx: shoes with grousers round the sprocket and idler, the frame between the runs, rollers, guards.
static func _exc_track(pk: PropKit, kit: Dictionary, sx: float) -> void:
	var r := 0.42
	var yc := 0.535
	var hw := 0.3
	var zf: float = -EXC_TRACK_L * 0.5 + r + 0.1
	var zr: float = EXC_TRACK_L * 0.5 - r - 0.1
	var run: float = zr - zf
	var perim: float = 2.0 * run + TAU * r
	var n: int = int(round(perim / 0.2))
	var shoe := Color(0.17, 0.17, 0.16)
	var out: float = signf(sx)
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
		pk.box(kit, "steel", Transform3D(b, p + nrm * 0.03), Vector3(hw * 2.0, 0.07, 0.185), col)
		pk.box(kit, "steel", Transform3D(b, p + nrm * 0.085), Vector3(hw * 2.0 - 0.03, 0.045, 0.05), col.darkened(0.1))
	var fc := UNDERCARRIAGE
	# The frame between the runs (sloping at its ends), its top guard, the rollers under it and the two carriers.
	var fo := PackedVector2Array([Vector2(zf + 0.1, yc - 0.22), Vector2(zr - 0.1, yc - 0.22), Vector2(zr + 0.15, yc + 0.05), Vector2(zr - 0.05, yc + 0.3),
			Vector2(zf + 0.05, yc + 0.3), Vector2(zf - 0.15, yc + 0.05)])
	_side_prism(pk, kit, "bpaint", fo, sx - 0.24, sx + 0.24, fc, 0.03)
	for k in range(7):
		var zz: float = lerpf(zf + 0.3, zr - 0.3, float(k) / 6.0)
		_rod(pk, kit, "metal", Vector3(sx - 0.22, yc - r + 0.17, zz), Vector3(sx + 0.22, yc - r + 0.17, zz), 0.1, 10, Color(0.24, 0.24, 0.23))
	for zz in [lerpf(zf, zr, 0.3), lerpf(zf, zr, 0.7)]:
		_rod(pk, kit, "metal", Vector3(sx - 0.12, yc + r - 0.14, zz), Vector3(sx + 0.12, yc + r - 0.14, zz), 0.085, 10, Color(0.24, 0.24, 0.23))
		_blk(pk, kit, "bpaint", Vector3(sx - 0.05, yc + 0.28, zz - 0.06), Vector3(sx + 0.05, yc + r - 0.14, zz + 0.06), fc)
	# The idler (front) and the sprocket (rear, teeth showing, the travel motor beside it).
	for wz in [zf, zr]:
		_rod(pk, kit, "steel", Vector3(sx - 0.2, yc, wz), Vector3(sx + 0.2, yc, wz), r - 0.07, 16, Color(0.2, 0.2, 0.2))
		_rod(pk, kit, "metal", Vector3(sx + out * 0.2, yc, wz), Vector3(sx + out * 0.27, yc, wz), 0.16, 10, Color(0.3, 0.3, 0.29))
	for kt in range(11):
		var at: float = TAU * float(kt) / 11.0
		var tp := Vector3(sx - out * 0.02, yc + sin(at) * (r - 0.04), zr + cos(at) * (r - 0.04))
		pk.box(kit, "metal", Transform3D(Basis(Vector3.RIGHT, -at), tp), Vector3(0.1, 0.09, 0.1), Color(0.32, 0.31, 0.29))
	_rod(pk, kit, "bpaint", Vector3(sx - out * 0.24, yc + 0.02, zr - 0.05), Vector3(sx - out * 0.55, yc + 0.02, zr - 0.05), 0.24, 12, fc.lightened(0.05))


static func excavator_solids() -> Array:
	var s: Array = []
	for sx in [-1.0, 1.0]:
		_solid_blk(s, Vector3(sx * EXC_TRACK_X - 0.31, 0.0, -EXC_TRACK_L * 0.5), Vector3(sx * EXC_TRACK_X + 0.31, 1.07, EXC_TRACK_L * 0.5))
	_solid_blk(s, Vector3(-0.95, 0.4, -1.25), Vector3(0.95, EXC_RING_Y, 1.25))
	return s


## The excavator's upper, built about its slewing axis (the y axis through the origin, which goes on the ring's top at
## EXC_RING_Y): the turning race, the frame, the cab front left (x -1.45..-0.5, its roof 2.0 up, 3.15 over the ground), the
## tank box front right, the engine house and the rounded counterweight behind (tail radius EXC_TAIL_R 2.75), handrails, an
## exhaust and a beacon, and the digging arm in the plane x = EXC_BOOM_X reaching toward -z, posed low: the banana boom from
## EXC_F through EXC_K to EXC_T, the stick from its top end down to EXC_S, the bucket on it (its shell round EXC_BUCKET, the
## lowest point 0.9 over the base's ground at about 8.4 from the axis), the two boom cylinders, the stick cylinder over the
## boom and the bucket cylinder with its linkage on the stick's front, chrome rods, hoses along the boom.
static func excavator_upper(pk: PropKit, kit: Dictionary) -> void:
	var body := EXC_YELLOW
	var frame := Color(0.17, 0.17, 0.17)
	pk.lathe(kit, "steel", Vector3(0, 0.0, 0), [Vector2(0.7, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.12), Vector2(0.7, 0.12)], 24, Color(0.2, 0.2, 0.2))
	_blk(pk, kit, "bpaint", Vector3(-1.45, 0.12, -1.75), Vector3(1.45, 0.42, 2.0), frame)
	# The boom's foot brackets and the boom cylinders' lugs at the frame's front.
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "bpaint", Vector3(EXC_BOOM_X + sx * 0.33, 0.3, -1.8), Vector3(EXC_BOOM_X + sx * 0.45, 1.35, -0.7), frame)
		_blk(pk, kit, "bpaint", Vector3(EXC_BOOM_X + sx * 0.52 - 0.12, 0.3, -2.05), Vector3(EXC_BOOM_X + sx * 0.52 + 0.12, 0.75, -1.7), frame)
	_exc_cab(pk, kit, body)
	# The tank box front right: fuel and hydraulic oil, steps on its front, the caps on top.
	_blk(pk, kit, "bpaint", Vector3(0.75, 0.42, -1.75), Vector3(1.45, 1.3, 0.35), body)
	for k in range(2):
		_blk(pk, kit, "steel", Vector3(0.82, 0.62 + 0.36 * float(k), -1.785), Vector3(1.38, 0.68 + 0.36 * float(k), -1.73), DARK)
	_rod(pk, kit, "bpaint", Vector3(1.15, 1.3, -0.6), Vector3(1.15, 1.38, -0.6), 0.09, 10, DARK)
	_rod(pk, kit, "bpaint", Vector3(1.15, 1.3, 0.05), Vector3(1.15, 1.36, 0.05), 0.07, 10, DARK)
	# The engine house: louvres on its right side, a raised hood, the exhaust and the air cleaner.
	_blk(pk, kit, "bpaint", Vector3(-1.45, 0.42, 0.35), Vector3(1.45, 1.45, 2.05), body)
	_blk(pk, kit, "bpaint", Vector3(-0.4, 1.44, 0.55), Vector3(1.3, 1.53, 1.85), body.darkened(0.05))
	for k in range(5):
		var gz: float = 0.6 + 0.24 * float(k)
		_blk(pk, kit, "bpaint", Vector3(1.45, 0.65, gz), Vector3(1.475, 1.25, gz + 0.16), DARK)
	for k in range(3):
		_blk(pk, kit, "bpaint", Vector3(-1.475, 0.7, 0.75 + 0.3 * float(k)), Vector3(-1.45, 1.2, 0.95 + 0.3 * float(k)), DARK)
	_rod(pk, kit, "steel", Vector3(0.95, 1.5, 1.35), Vector3(0.95, 2.05, 1.35), 0.06, 8, Color(0.22, 0.22, 0.22))
	_rod(pk, kit, "bpaint", Vector3(0.3, 1.5, 1.6), Vector3(0.3, 1.75, 1.6), 0.13, 10, DARK)
	# Handrails along the top's right edge and round the hood.
	SW._railing(pk, kit, [Vector3(1.38, 1.45, -1.6), Vector3(1.38, 1.45, 1.9)], 0.8, body.darkened(0.1), "paint")
	# The counterweight: rounded behind on the tail radius, a reflective band and lamps, the lifting eyes.
	var cw := PackedVector2Array([Vector2(-1.45, 1.95), Vector2(1.45, 1.95)])
	var z_edge: float = sqrt(EXC_TAIL_R * EXC_TAIL_R - 1.45 * 1.45)
	cw.append(Vector2(1.45, z_edge))
	for k in range(1, 8):
		var x: float = lerpf(1.45, -1.45, float(k) / 8.0)
		cw.append(Vector2(x, sqrt(EXC_TAIL_R * EXC_TAIL_R - x * x)))
	cw.append(Vector2(-1.45, z_edge))
	_plan_prism(pk, kit, "bpaint", cw, 0.2, 1.38, body, 0.05)
	for k in range(8):
		var xa: float = lerpf(1.3, -1.3, float(k) / 8.0)
		var xb: float = lerpf(1.3, -1.3, float(k + 1) / 8.0)
		var za: float = sqrt(EXC_TAIL_R * EXC_TAIL_R - xa * xa) + 0.03
		var zb: float = sqrt(EXC_TAIL_R * EXC_TAIL_R - xb * xb) + 0.03
		var o := Vector3((xa + xb) * 0.5, 0, (za + zb) * 0.5).normalized()
		pk.quad(kit, "bpaint", [Vector3(xa, 0.62, za), Vector3(xb, 0.62, zb), Vector3(xb, 0.8, zb), Vector3(xa, 0.8, za)], o, _a(EXC_YELLOW, HAZ))
	for sx in [-1.0, 1.0]:
		var lz: float = sqrt(EXC_TAIL_R * EXC_TAIL_R - 1.0) + 0.02
		_box(pk, kit, "lens", Vector3(sx * 1.0, 1.05, lz), Basis(UP, -sx * 0.37), Vector3(0.2, 0.1, 0.04), Color(0.7, 0.08, 0.05))
		_rod(pk, kit, "steel", Vector3(sx * 0.7, 1.38, 2.3), Vector3(sx * 0.7, 1.5, 2.3), 0.06, 8, DARK)
	# The beacon on the cab's roof, a work light on the boom.
	pk.lathe(kit, "lamp", Vector3(-0.68, 2.03, 0.15), [Vector2(0.001, 0.0), Vector2(0.075, 0.0), Vector2(0.07, 0.13), Vector2(0.001, 0.15)], 10, AMBER)
	_exc_arm(pk, kit, body)


## The cab front left: a shell with a raked windscreen, glass all round, the roof overhanging, a grab rail and the mirror.
static func _exc_cab(pk: PropKit, kit: Dictionary, body: Color) -> void:
	var x0 := -1.45
	var x1 := -0.5
	var ol := PackedVector2Array([Vector2(0.35, 0.42), Vector2(0.35, 1.95), Vector2(-1.42, 1.95), Vector2(-1.52, 1.88), Vector2(-1.75, 0.85), Vector2(-1.75, 0.42)])
	_side_prism(pk, kit, "bpaint", ol, x0, x1, body.darkened(0.06), 0.03)
	_blk(pk, kit, "bpaint", Vector3(x0 - 0.03, 1.93, -1.62), Vector3(x1 + 0.03, 2.0, 0.38), DARK)
	# The windscreen on the raked face.
	var a := Vector3(0, 0.85, -1.75)
	var b := Vector3(0, 1.88, -1.52)
	var along: Vector3 = (b - a).normalized()
	var nrm: Vector3 = Vector3(0, -along.z, along.y)
	if nrm.z > 0.0:
		nrm = -nrm
	var mid: Vector3 = a.lerp(b, 0.5) + nrm * 0.025
	_pane(pk, kit, Vector3((x0 + x1) * 0.5, mid.y, mid.z), Vector3.RIGHT, along, nrm, 0.8, 0.92)
	_pane(pk, kit, Vector3((x0 + x1) * 0.5, 0.62, -1.775), Vector3.RIGHT, UP, Vector3.FORWARD, 0.75, 0.3)
	# The door's glass and the rear quarter on the left side, the right side, the rear.
	_pane(pk, kit, Vector3(x0 - 0.025, 1.38, -0.88), Vector3.BACK, UP, Vector3.LEFT, 1.0, 0.95)
	_pane(pk, kit, Vector3(x0 - 0.025, 1.42, 0.0), Vector3.BACK, UP, Vector3.LEFT, 0.5, 0.82)
	_pane(pk, kit, Vector3(x1 + 0.025, 1.45, -0.85), Vector3.BACK, UP, Vector3.RIGHT, 1.1, 0.8)
	_pane(pk, kit, Vector3((x0 + x1) * 0.5, 1.6, 0.375), Vector3.RIGHT, UP, Vector3.BACK, 0.72, 0.55)
	_blk(pk, kit, "bpaint", Vector3(x0 - 0.04, 0.95, -0.36), Vector3(x0 - 0.01, 1.05, -0.3), DARK)
	_rod(pk, kit, "steel", Vector3(x0 - 0.06, 0.7, -1.6), Vector3(x0 - 0.06, 1.7, -1.4), 0.02, 5, DARK)
	_rod(pk, kit, "steel", Vector3(1.4, 1.3, -1.7), Vector3(1.55, 1.9, -1.78), 0.015, 4, DARK)
	_box(pk, kit, "bpaint", Vector3(1.57, 1.95, -1.78), Basis(UP, 0.4), Vector3(0.24, 0.32, 0.04), DARK)


## A hydraulic cylinder from a (its base) to b (the rod's eye): the barrel over `share` of it, the chrome rod, end eyes.
static func _cylinder(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, r: float, col: Color, share := 0.58) -> void:
	var d: Vector3 = b - a
	var m: Vector3 = a + d * share
	_rod(pk, kit, "bpaint", a + d.normalized() * 0.08, m, r, 10, col)
	_rod(pk, kit, "bpaint", m - d.normalized() * 0.02, m + d.normalized() * 0.06, r * 1.12, 10, col.darkened(0.2))
	_rod(pk, kit, "chrome", m, b - d.normalized() * 0.08, r * 0.58, 8, Color(0.85, 0.86, 0.87), false)
	for e in [a, b]:
		_rod(pk, kit, "steel", e + Vector3(-r * 0.6, 0, 0), e + Vector3(r * 0.6, 0, 0), r * 0.85, 8, col.darkened(0.25))


## The boom, the stick, the bucket and its linkage, the cylinders and the hoses.
static func _exc_arm(pk: PropKit, kit: Dictionary, body: Color) -> void:
	var bx := EXC_BOOM_X
	# The boom: a banana of varying depth through F, K and T, extruded across its 0.62 width.
	var cs: Array = [EXC_F, (EXC_F + EXC_K) * 0.5, EXC_K, (EXC_K + EXC_T) * 0.5, EXC_T]
	var hh: Array = [0.32, 0.42, 0.48, 0.38, 0.3]
	var tops := PackedVector2Array()
	var bots := PackedVector2Array()
	for i in range(cs.size()):
		var prev: Vector3 = cs[maxi(i - 1, 0)]
		var nxt: Vector3 = cs[mini(i + 1, cs.size() - 1)]
		var d: Vector3 = (nxt - prev).normalized()
		var n := Vector3(0, -d.z, d.y)
		if n.y < 0.0:
			n = -n
		var c: Vector3 = cs[i]
		var t: Vector3 = c + n * float(hh[i])
		var u: Vector3 = c - n * float(hh[i])
		tops.append(Vector2(t.z, t.y))
		bots.append(Vector2(u.z, u.y))
	var ol := PackedVector2Array()
	for i in range(bots.size()):
		ol.append(bots[i])
	for i in range(tops.size() - 1, -1, -1):
		ol.append(tops[i])
	_side_prism(pk, kit, "bpaint", ol, bx - 0.31, bx + 0.31, body, 0.04)
	_rod(pk, kit, "bpaint", Vector3(bx - 0.31, EXC_F.y, EXC_F.z), Vector3(bx + 0.31, EXC_F.y, EXC_F.z), 0.33, 14, body.darkened(0.05))
	_rod(pk, kit, "steel", Vector3(bx - 0.5, EXC_F.y, EXC_F.z), Vector3(bx + 0.5, EXC_F.y, EXC_F.z), 0.07, 8, DARK)
	_rod(pk, kit, "bpaint", Vector3(bx - 0.33, EXC_T.y, EXC_T.z), Vector3(bx + 0.33, EXC_T.y, EXC_T.z), 0.29, 14, body.darkened(0.05))
	# The stick: from its top end R down to the bucket's pin S.
	var dir: Vector3 = (EXC_T - EXC_S).normalized()
	var nf := Vector3(0, -dir.z, dir.y)
	if nf.z > 0.0:
		nf = -nf
	var R: Vector3 = EXC_T + dir * 0.75
	var sp: Array = [R, EXC_T, EXC_S]
	var sh: Array = [0.26, 0.3, 0.2]
	var so := PackedVector2Array()
	for i in range(3):
		var c2: Vector3 = sp[i] - nf * float(sh[i])
		so.append(Vector2(c2.z, c2.y))
	for i in range(2, -1, -1):
		var c3: Vector3 = sp[i] + nf * float(sh[i])
		so.append(Vector2(c3.z, c3.y))
	_side_prism(pk, kit, "bpaint", so, bx - 0.225, bx + 0.225, body.darkened(0.03), 0.03)
	for p in [R, EXC_S]:
		_rod(pk, kit, "bpaint", Vector3(bx - 0.25, (p as Vector3).y, (p as Vector3).z), Vector3(bx + 0.25, (p as Vector3).y, (p as Vector3).z), 0.17, 12, body.darkened(0.1))
	# The bucket.
	_exc_bucket(pk, kit, body)
	# The linkage: side links from the stick to the joint J, the H-link from J to the bucket's ear.
	var P2: Vector3 = EXC_S + dir * 0.5
	var J: Vector3 = EXC_S + dir * 0.25 + nf * 0.35
	var Lb := Vector3(bx, 1.08, -8.72)
	for sx in [-1.0, 1.0]:
		_bar(pk, kit, "bpaint", P2 + Vector3(sx * 0.27, 0, 0), J + Vector3(sx * 0.27, 0, 0), 0.06, 0.16, frame_col(), Vector3.RIGHT)
		_bar(pk, kit, "bpaint", J + Vector3(sx * 0.2, 0, 0), Lb + Vector3(sx * 0.2, 0, 0), 0.05, 0.18, frame_col(), Vector3.RIGHT)
	for p2 in [P2, J, Lb]:
		_rod(pk, kit, "steel", (p2 as Vector3) + Vector3(-0.32, 0, 0), (p2 as Vector3) + Vector3(0.32, 0, 0), 0.06, 8, DARK)
	# The cylinders: two for the boom outside its sides, the stick's over the boom, the bucket's on the stick's front.
	var bk: Vector3 = EXC_F.lerp(EXC_K, 0.72)
	var d1: Vector3 = (EXC_K - EXC_F).normalized()
	var nb := Vector3(0, -d1.z, d1.y)
	if nb.y < 0.0:
		nb = -nb
	var rod_end: Vector3 = bk - nb * 0.46
	for sx in [-1.0, 1.0]:
		var o := Vector3(sx * 0.52, 0, 0)
		_cylinder(pk, kit, Vector3(bx, 0.55, -1.88) + o, Vector3(bx, rod_end.y, rod_end.z) + o, 0.11, body)
		_blk(pk, kit, "bpaint", Vector3(bx + sx * 0.31, rod_end.y - 0.15, rod_end.z - 0.2), Vector3(bx + sx * 0.46, rod_end.y + 0.25, rod_end.z + 0.2), body.darkened(0.08))
	var B := Vector3(bx, 5.15, -3.75)
	_blk(pk, kit, "bpaint", Vector3(bx - 0.2, 4.55, -3.95), Vector3(bx + 0.2, 5.2, -3.55), body.darkened(0.08))
	_cylinder(pk, kit, B, R, 0.12, body)
	var Bc0: Vector3 = EXC_T + dir * 0.45 + nf * 0.38
	_blk(pk, kit, "bpaint", Vector3(bx - 0.16, Bc0.y - 0.18, Bc0.z - 0.12), Vector3(bx + 0.16, Bc0.y + 0.12, Bc0.z + 0.25), body.darkened(0.08))
	_cylinder(pk, kit, Bc0, J, 0.1, body)
	# Hoses along the boom's top from the house to the stick, a work light on the boom's left side.
	for hx in [-0.12, 0.12]:
		var hp: Array = [Vector3(bx + hx, 1.45, -0.9)]
		for i in range(tops.size()):
			hp.append(Vector3(bx + hx, tops[i].y + 0.05, tops[i].x))
		hp.append(Vector3(bx + hx * 0.6, R.y + 0.1, R.z + 0.15))
		_rope(pk, kit, "rubber", hp, 0.03, 5, Color(0.05, 0.05, 0.05))
	var wl: Vector3 = EXC_F.lerp(EXC_K, 0.5) + Vector3(-0.36, 0.2, 0)
	_box(pk, kit, "bpaint", wl, Basis(), Vector3(0.1, 0.16, 0.2), DARK)
	_box(pk, kit, "lens", wl + Vector3(0, 0, -0.105), Basis(), Vector3(0.08, 0.12, 0.02), Color(0.9, 0.9, 0.85))


static func frame_col() -> Color:
	return Color(0.2, 0.2, 0.2)


## The bucket: two side plates round its shell's arc, the shell (outside and in), the cutting edge and five teeth, wear
## strips under it and the ears up to the stick's pin and the linkage's.
static func _exc_bucket(pk: PropKit, kit: Dictionary, body: Color) -> void:
	var c := EXC_BUCKET
	var r := EXC_BUCKET_R
	var bx := EXC_BOOM_X
	var hw := 0.6
	var col: Color = body.darkened(0.15)
	var th0 := deg_to_rad(112.0)
	var th1 := deg_to_rad(-135.0)
	var segs := 12
	var pts: Array = []
	for k in range(segs + 1):
		var th: float = lerpf(th0, th1, float(k) / float(segs))
		pts.append(Vector2(c.z - r * cos(th), c.y + r * sin(th)))
	var plate := PackedVector2Array()
	for p in pts:
		plate.append(p)
	for sx in [-1.0, 1.0]:
		var xa: float = bx + sx * hw
		_side_prism(pk, kit, "bpaint", plate, minf(xa, xa + sx * 0.03), maxf(xa, xa + sx * 0.03), col, 0.0)
	for k in range(segs):
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[k + 1]
		var m := (p0 + p1) * 0.5
		var o := Vector3(0, m.y - c.y, m.x - c.z).normalized()
		var n0 := Vector3(0, p0.y - c.y, p0.x - c.z).normalized()
		var n1 := Vector3(0, p1.y - c.y, p1.x - c.z).normalized()
		var qa := Vector3(bx - hw, p0.y, p0.x)
		var qb := Vector3(bx + hw, p0.y, p0.x)
		var qc := Vector3(bx + hw, p1.y, p1.x)
		var qd := Vector3(bx - hw, p1.y, p1.x)
		pk.tri(kit, "bpaint", qa, qb, qc, n0, n0, n1, col, o)
		pk.tri(kit, "bpaint", qa, qc, qd, n0, n1, n1, col, o)
		var q0: Vector2 = Vector2(c.z, c.y) + (p0 - Vector2(c.z, c.y)) * ((r - 0.025) / r)
		var q1: Vector2 = Vector2(c.z, c.y) + (p1 - Vector2(c.z, c.y)) * ((r - 0.025) / r)
		pk.quad(kit, "bpaint", [Vector3(bx - hw, q0.y, q0.x), Vector3(bx + hw, q0.y, q0.x), Vector3(bx + hw, q1.y, q1.x), Vector3(bx - hw, q1.y, q1.x)], -o, col.darkened(0.35))
	# The lip: the cutting edge and the teeth, pointing on round the arc.
	var lip: Vector2 = pts[-1]
	# The arc's direction at the lip, carried on round (toward the machine and up).
	var tang := Vector3(0, -cos(th1), -sin(th1)).normalized()
	var lp := Vector3(bx, lip.y, lip.x)
	pk.beam(kit, "steel", lp - Vector3(hw + 0.03, 0, 0), lp + Vector3(hw + 0.03, 0, 0), 0.08, 0.04, Color(0.3, 0.3, 0.3), tang)
	for k in range(5):
		var tx: float = bx + lerpf(-0.48, 0.48, float(k) / 4.0)
		pk.tube(kit, "steel", Vector3(tx, lip.y, lip.x) - tang * 0.02, Vector3(tx, lip.y, lip.x) + tang * 0.2, 0.05, 0.015, 6, Color(0.42, 0.4, 0.37), true)
	# Wear strips under the bucket.
	for wx in [-0.4, 0.0, 0.4]:
		var wa: float = deg_to_rad(-60.0)
		var wb: float = deg_to_rad(-120.0)
		var pa := Vector3(bx + wx, c.y + (r + 0.01) * sin(wa), c.z - (r + 0.01) * cos(wa))
		var pb := Vector3(bx + wx, c.y + (r + 0.01) * sin(wb), c.z - (r + 0.01) * cos(wb))
		pk.beam(kit, "steel", pa, pb, 0.06, 0.025, Color(0.25, 0.25, 0.25), Vector3.RIGHT)
	# Ears from the shell's top up to the pins.
	for sx in [-1.0, 1.0]:
		var ex: float = bx + sx * 0.27
		var top_y: float = c.y + r * sin(deg_to_rad(80.0))
		var ear := PackedVector2Array([Vector2(EXC_S.z + 0.25, top_y - 0.1), Vector2(-8.95, top_y - 0.15), Vector2(-8.85, 1.2), Vector2(-8.6, 1.22),
				Vector2(EXC_S.z - 0.1, EXC_S.y + 0.15), Vector2(EXC_S.z + 0.15, EXC_S.y + 0.1)])
		_side_prism(pk, kit, "bpaint", ear, ex - 0.03, ex + 0.03, col)


# ======================================================================================
#  The road roller
# ======================================================================================

const RR_DRUM_R := 0.6
const RR_DRUM_HW := 0.85      # the drums 1.7 wide
const RR_DRUM_Z := 1.65       # the drums' axles at z ∓1.65 (the front one toward -z)
const RR_ROPS_Y := 2.95       # the canopy's underside


## A tandem vibratory road roller (an original design, about 10 tonnes), its front toward -z: two smooth steel drums
## (radius 0.6, 1.7 wide) at z ∓1.65 in yokes, the front frame carrying the water tank and spray bar, the articulation joint
## in the middle, the rear frame with the engine hood over the rear drum, the operator's platform with a seat and steering
## console under a ROPS canopy on four posts (its roof 2.95 to 3.03 up) with an amber beacon, steps, rails, scrapers and
## lamps. Returns its size (x, y, z): 2.0 x 3.18 x 4.76, centred on the origin in plan.
static func road_roller(pk: PropKit, kit: Dictionary) -> Vector3:
	var body := ROLLER_ORANGE
	var frame := Color(0.16, 0.16, 0.16)
	var drum_col := Color(0.55, 0.56, 0.56)
	for dz in [-RR_DRUM_Z, RR_DRUM_Z]:
		var c := Vector3(0, RR_DRUM_R, dz)
		_rod(pk, kit, "metal", c + Vector3(-RR_DRUM_HW, 0, 0), c + Vector3(RR_DRUM_HW, 0, 0), RR_DRUM_R, 22, drum_col, false)
		for sx in [-1.0, 1.0]:
			var db := Basis(Vector3.BACK, -PI * 0.5 * sx)
			pk.lathe(kit, "steel", c + Vector3(sx * (RR_DRUM_HW - 0.06), 0, 0), [Vector2(RR_DRUM_R, 0.06), Vector2(RR_DRUM_R - 0.06, 0.06), Vector2(RR_DRUM_R - 0.08, 0.0),
					Vector2(0.001, 0.0)], 18, Color(0.32, 0.33, 0.33), false, db)
			_rod(pk, kit, "bpaint", c + Vector3(sx * 0.82, 0, 0), c + Vector3(sx * 0.98, 0, 0), 0.24, 12, frame)
		# Scrapers front and back of the drum.
		for side in [-1.0, 1.0]:
			var sp: Vector3 = c + Vector3(0, -0.05, side * (RR_DRUM_R + 0.07))
			_box(pk, kit, "steel", sp, Basis(Vector3.RIGHT, side * 0.5), Vector3(1.72, 0.05, 0.1), DARK)
	# The front yoke: plates either side of the front drum up to the tank, the tank, the spray bar.
	for sx in [-1.0, 1.0]:
		var yo := PackedVector2Array([Vector2(-1.05, 1.3), Vector2(-2.3, 1.3), Vector2(-2.3, 0.85), Vector2(-1.95, 0.36), Vector2(-1.35, 0.36), Vector2(-1.05, 0.7)])
		_side_prism(pk, kit, "bpaint", yo, sx * 0.98 - 0.04, sx * 0.98 + 0.04, body, 0.01)
	var tank := PackedVector2Array([Vector2(-0.95, 1.28), Vector2(-0.95, 1.78), Vector2(-1.12, 1.9), Vector2(-2.22, 1.9), Vector2(-2.38, 1.72), Vector2(-2.38, 1.28)])
	_side_prism(pk, kit, "bpaint", tank, -1.0, 1.0, body, 0.04)
	_rod(pk, kit, "bpaint", Vector3(0.6, 1.9, -1.6), Vector3(0.6, 1.98, -1.6), 0.1, 10, DARK)
	_rod(pk, kit, "steel", Vector3(-0.9, 1.22, -2.42), Vector3(0.9, 1.22, -2.42), 0.025, 6, GALV)
	for k in range(5):
		var nx: float = lerpf(-0.8, 0.8, float(k) / 4.0)
		_rod(pk, kit, "steel", Vector3(nx, 1.22, -2.42), Vector3(nx, 1.16, -2.46), 0.015, 4, DARK)
	_box(pk, kit, "lens", Vector3(-0.75, 1.62, -2.39), Basis(), Vector3(0.18, 0.12, 0.02), Color(0.9, 0.9, 0.85))
	_box(pk, kit, "lens", Vector3(0.75, 1.62, -2.39), Basis(), Vector3(0.18, 0.12, 0.02), Color(0.9, 0.9, 0.85))
	# The articulation joint and the rear frame's chassis under the platform.
	_blk(pk, kit, "bpaint", Vector3(-0.38, 0.5, -1.05), Vector3(0.38, 1.22, -0.5), frame)
	_rod(pk, kit, "steel", Vector3(0, 0.42, -0.78), Vector3(0, 1.3, -0.78), 0.11, 10, Color(0.3, 0.3, 0.3))
	_blk(pk, kit, "bpaint", Vector3(-0.9, 0.55, -0.5), Vector3(0.9, 1.28, 0.95), body.darkened(0.08))
	# The rear yoke and the engine hood over the rear drum, its grilles, the exhaust and the tail lamps.
	for sx in [-1.0, 1.0]:
		var ry := PackedVector2Array([Vector2(0.95, 1.3), Vector2(2.3, 1.3), Vector2(2.3, 0.85), Vector2(1.95, 0.36), Vector2(1.35, 0.36), Vector2(0.95, 0.7)])
		_side_prism(pk, kit, "bpaint", ry, sx * 0.98 - 0.04, sx * 0.98 + 0.04, body, 0.01)
	var hood := PackedVector2Array([Vector2(0.6, 1.28), Vector2(2.38, 1.28), Vector2(2.38, 1.85), Vector2(2.2, 2.05), Vector2(0.78, 2.05), Vector2(0.6, 1.92)])
	_side_prism(pk, kit, "bpaint", hood, -1.0, 1.0, body, 0.05)
	for sx in [-1.0, 1.0]:
		for k in range(4):
			var gz: float = 1.15 + 0.25 * float(k)
			_blk(pk, kit, "bpaint", Vector3(sx * 1.0 - 0.012, 1.45, gz), Vector3(sx * 1.0 + 0.012, 1.85, gz + 0.16), DARK)
		_box(pk, kit, "lens", Vector3(sx * 0.7, 1.7, 2.395), Basis(), Vector3(0.16, 0.1, 0.02), Color(0.75, 0.08, 0.05))
	_blk(pk, kit, "bpaint", Vector3(-0.55, 1.4, 2.375), Vector3(0.55, 1.85, 2.4), DARK)
	_rope(pk, kit, "steel", [Vector3(0.65, 2.0, 1.2), Vector3(0.65, 2.45, 1.2), Vector3(0.65, 2.52, 1.12)], 0.05, 8, Color(0.2, 0.2, 0.2))
	# The platform, the seat facing -z, the steering console.
	_blk(pk, kit, "steel", Vector3(-0.98, 1.28, -0.98), Vector3(0.98, 1.34, 0.62), Color(0.25, 0.25, 0.25))
	_blk_nb(pk, kit, "bpaint", Vector3(-0.2, 1.34, 0.1), Vector3(0.2, 1.62, 0.5), DARK)
	_blk(pk, kit, "matte", Vector3(-0.28, 1.62, -0.05), Vector3(0.28, 1.74, 0.5), Color(0.08, 0.08, 0.08))
	_box(pk, kit, "matte", Vector3(0, 2.0, 0.5), Basis(Vector3.RIGHT, -0.18), Vector3(0.52, 0.55, 0.1), Color(0.08, 0.08, 0.08))
	for sx in [-0.3, 0.3]:
		_box(pk, kit, "matte", Vector3(sx, 1.8, 0.18), Basis(), Vector3(0.06, 0.06, 0.4), Color(0.08, 0.08, 0.08))
	_blk(pk, kit, "bpaint", Vector3(-0.22, 1.34, -0.82), Vector3(0.22, 1.95, -0.6), body.darkened(0.1))
	_box(pk, kit, "bpaint", Vector3(0, 1.98, -0.62), Basis(Vector3.RIGHT, 0.5), Vector3(0.5, 0.06, 0.32), DARK)
	var wb := Basis(Vector3.RIGHT, -0.6)
	pk.tyre(kit, "rubber", Vector3(0, 2.12, -0.55), 0.14, 0.19, 0.035, 14, Color(0.06, 0.06, 0.06), wb)
	_rod(pk, kit, "steel", Vector3(0, 1.95, -0.65), Vector3(0, 2.12, -0.55), 0.025, 6, DARK)
	# The ROPS canopy on four posts, its roof, the beacon and work lamps.
	for sx in [-1.0, 1.0]:
		for pz in [-0.88, 0.52]:
			_bar(pk, kit, "bpaint", Vector3(sx * 0.9, 1.34, pz), Vector3(sx * 0.9, RR_ROPS_Y, pz), 0.08, 0.08, frame)
	_blk(pk, kit, "bpaint", Vector3(-1.0, RR_ROPS_Y, -1.0), Vector3(1.0, RR_ROPS_Y + 0.08, 0.65), body)
	pk.lathe(kit, "lamp", Vector3(0.55, RR_ROPS_Y + 0.08, 0.35), [Vector2(0.001, 0.0), Vector2(0.075, 0.0), Vector2(0.07, 0.13), Vector2(0.001, 0.15)], 10, AMBER)
	for sx in [-0.7, 0.7]:
		_box(pk, kit, "bpaint", Vector3(sx, RR_ROPS_Y - 0.08, -0.98), Basis(), Vector3(0.16, 0.12, 0.1), DARK)
		_box(pk, kit, "lens", Vector3(sx, RR_ROPS_Y - 0.08, -1.035), Basis(), Vector3(0.12, 0.08, 0.01), Color(0.9, 0.9, 0.85))
	# Steps and the rails round the platform's open sides.
	for sx in [-1.0, 1.0]:
		for sy in [0.55, 0.95]:
			_blk(pk, kit, "steel", Vector3(sx * 1.0 - 0.18, sy - 0.03, -0.35), Vector3(sx * 1.0 + 0.04, sy, 0.05), DARK)
		_rope(pk, kit, "paint", [Vector3(sx * 0.95, 1.34, -0.95), Vector3(sx * 0.95, 2.25, -0.95), Vector3(sx * 0.95, 2.25, -0.55)], 0.022, 5, Color(0.85, 0.85, 0.82))
	return Vector3(2.0, RR_ROPS_Y + 0.23, 4.76)


static func road_roller_solids() -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-1.0, 0.0, -2.4), Vector3(1.0, 2.05, 2.4))
	return s


# ======================================================================================
#  The Bauzaun
# ======================================================================================

const FENCE_PANEL := 3.5      # a panel's nominal length (they are stretched a little to fill the run)
const FENCE_TOP := 2.15       # the panels' top tube
## The privacy banner: its size (the bnet material's selvedge needs it), the middle of its foot over the ground.
const BANNER_W := 3.3
const BANNER_H := 1.7
const BANNER_Y := 0.36


## A Bauzaun (mobile site fence) along +x from x = 0 to `length`: welded mesh panels about 3.5 x 2.0 in galvanised tube
## frames (top 2.15), their legs in concrete feet (0.72 x 0.22 x 0.14) at every joint, two couplers clamping the panels at
## each joint, a brace with its own foot on the -z side every fourth joint, and on some panels (by `seed_v`, about 45%) the
## green privacy banner on the +z side carrying BUILDER's name: labels on it toward +z (`name_sides` 1), -z (-1) or both (0).
## The mesh ("bmesh") and banner ("bnet") are one quad each, two-sided. About 23 triangles a metre.
static func site_fence(pk: PropKit, kit: Dictionary, length: float, seed_v: int, labels: Array = [], name_sides := 0) -> void:
	var n: int = maxi(1, int(round(length / FENCE_PANEL)))
	var step: float = length / float(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + seed_v
	for j in range(n + 1):
		_fence_foot(pk, kit, Vector3(step * float(j), 0, 0), 0.0)
	for k in range(n):
		var x0: float = step * float(k) + 0.065
		var x1: float = step * float(k + 1) - 0.065
		for x in [x0, x1]:
			_rod(pk, kit, "metal", Vector3(x, 0.06, 0), Vector3(x, FENCE_TOP, 0), 0.02, 5, GALV, false)
		for y in [0.22, FENCE_TOP - 0.02]:
			_rod(pk, kit, "metal", Vector3(x0, y, 0), Vector3(x1, y, 0), 0.02, 5, GALV, false)
		_panel(pk, kit, "bmesh", Vector3(x0 + 0.02, 0.24, 0), Vector3.RIGHT, UP, Vector3.BACK, x1 - x0 - 0.04, FENCE_TOP - 0.28, GALV)
		if rng.randf() < 0.45:
			var bw: float = minf(BANNER_W, x1 - x0 - 0.12)
			var bxm: float = (x0 + x1) * 0.5
			var p0 := Vector3(bxm - bw * 0.5, BANNER_Y, 0.06)
			pk.quad(kit, "bnet", [p0, p0 + Vector3(bw, 0, 0), p0 + Vector3(bw, BANNER_H, 0), p0 + Vector3(0, BANNER_H, 0)], Vector3.BACK, NET_GREEN,
					[Vector2(0, 0), Vector2(BANNER_W, 0), Vector2(BANNER_W, BANNER_H), Vector2(0, BANNER_H)])
			var ly: float = BANNER_Y + BANNER_H * 0.5
			if name_sides >= 0:
				_lbl(labels, BUILDER, Vector3(bxm, ly, 0.09), Vector3.BACK, 0.3, Color(0.96, 0.96, 0.94), bw - 0.4)
			if name_sides <= 0:
				_lbl(labels, BUILDER, Vector3(bxm, ly, 0.03), Vector3.FORWARD, 0.3, Color(0.96, 0.96, 0.94), bw - 0.4)
	for j in range(1, n):
		var x2: float = step * float(j)
		for cy in [0.55, 1.85]:
			_blk(pk, kit, "steel", Vector3(x2 - 0.11, cy - 0.04, -0.035), Vector3(x2 + 0.11, cy + 0.04, 0.035), Color(0.55, 0.56, 0.57))
		if j % 4 == 2:
			_rod(pk, kit, "metal", Vector3(x2 + 0.1, 1.7, -0.02), Vector3(x2 + 0.1, 0.16, -1.68), 0.02, 5, GALV)
			_rod(pk, kit, "metal", Vector3(x2 + 0.1, 0.7, -0.02), Vector3(x2 + 0.1, 0.16, -1.2), 0.016, 5, GALV)
			_fence_foot(pk, kit, Vector3(x2 + 0.1, 0, -1.7), PI * 0.5)


## A Bauzaun foot at `p`, along x (or turned by `yaw`): a concrete block 0.72 long with a chamfered top.
static func _fence_foot(pk: PropKit, kit: Dictionary, p: Vector3, yaw: float) -> void:
	var saved := _push(pk, Transform3D(Basis(UP, yaw), p))
	_side_prism(pk, kit, "concrete", PackedVector2Array([Vector2(-0.11, -0.03), Vector2(0.11, -0.03), Vector2(0.085, 0.14), Vector2(-0.085, 0.14)]), -0.36, 0.36,
			Color(0.6, 0.6, 0.58), 0.0, uvk)
	_pop(pk, saved)


static func site_fence_solids(length: float) -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-0.36, 0.0, -0.12), Vector3(length + 0.36, FENCE_TOP, 0.12))
	var n: int = maxi(1, int(round(length / FENCE_PANEL)))
	var step: float = length / float(n)
	for j in range(1, n):
		if j % 4 == 2:
			_solid_blk(s, Vector3(step * float(j) - 0.12, 0.0, -1.8), Vector3(step * float(j) + 0.32, 1.7, -0.12))
	return s


# ======================================================================================
#  Site office containers
# ======================================================================================

const CABIN_HX := 3.03        # 6.06 long (x)
const CABIN_HZ := 1.22        # 2.44 wide (z), the doors and windows toward +z
const CABIN_H := 2.6
const CABIN_Y0 := 0.2         # the lower container's floor frame stands on blocks
const CABIN_STAIR := 4.1      # the stack's stair runs down along +x from the walkway's end to x = CABIN_HX + 4.1
const CABIN_WALK := 1.2       # the walkway's depth in front of the upper container


## Site office containers (Bürocontainer, 6.06 x 2.44 x 2.6, x along, the front toward +z) on concrete blocks: an anthracite
## frame, light grey corrugated walls, white-framed windows with shutter boxes, a steel door, an air conditioner on the +x
## end, the BAULEITUNG sign by the door and the site's name; `stacked` puts a second one on top with a walkway along its
## front (z 1.27..2.47 at y 2.8, on posts) and a steel stair down along +x to x = 7.13.
static func site_cabin(pk: PropKit, kit: Dictionary, labels: Array, stacked := false) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "concrete", Vector3(sx * 2.75 - 0.22, -0.15, sz * 0.95 - 0.22), Vector3(sx * 2.75 + 0.22, CABIN_Y0, sz * 0.95 + 0.22), CONC)
	_container(pk, kit, CABIN_Y0, 0)
	var y1: float = CABIN_Y0 + CABIN_H
	_lbl(labels, "BAULEITUNG", Vector3(0.62, CABIN_Y0 + 1.85, CABIN_HZ + 0.04), Vector3.BACK, 0.09, Color(0.1, 0.1, 0.1), 0.6)
	_blk(pk, kit, "enamel", Vector3(0.3, CABIN_Y0 + 1.75, CABIN_HZ - 0.02), Vector3(0.94, CABIN_Y0 + 1.95, CABIN_HZ + 0.02), WHITE)
	if stacked:
		_container(pk, kit, y1, 1)
		_cabin_gallery(pk, kit)
		_cabin_board(pk, kit, labels, y1)
	else:
		_cabin_board(pk, kit, labels, CABIN_Y0)


## The board along a container's front: BUILDER on the blue, the site's name under it.
static func _cabin_board(pk: PropKit, kit: Dictionary, labels: Array, y0: float) -> void:
	var y: float = y0 + CABIN_H - 0.48
	_blk(pk, kit, "enamel", Vector3(-2.6, y - 0.22, CABIN_HZ + 0.0), Vector3(0.4, y + 0.22, CABIN_HZ + 0.04), KB_BLUE)
	_blk(pk, kit, "enamel", Vector3(-2.6, y - 0.22, CABIN_HZ + 0.0), Vector3(-2.2, y + 0.22, CABIN_HZ + 0.05), KB_YELLOW)
	_lbl(labels, BUILDER, Vector3(-0.9, y + 0.06, CABIN_HZ + 0.07), Vector3.BACK, 0.17, Color(0.97, 0.97, 0.95), 2.4)
	_lbl(labels, "Baustelle Parkhaus Hafen-Ost", Vector3(-0.9, y - 0.13, CABIN_HZ + 0.07), Vector3.BACK, 0.06, KB_YELLOW, 2.4)


## One container whose floor frame is at y0: `level` 0 has the door at x 1.6 and windows at -1.6 and 0; level 1 the door at
## x 2.0 (the walkway's end by the stair) and windows at -1.8 and -0.2.
static func _container(pk: PropKit, kit: Dictionary, y0: float, level: int) -> void:
	var hx := CABIN_HX
	var hz := CABIN_HZ
	var y1: float = y0 + CABIN_H
	var fr := Color(0.22, 0.24, 0.26)
	var wall := Color(0.84, 0.85, 0.84)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "bpaint", Vector3(sx * hx - sx * 0.16, y0, sz * hz - sz * 0.16), Vector3(sx * hx, y1, sz * hz), fr)
	for yy in [y0, y1 - 0.18]:
		var th: float = 0.18
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "bpaint", Vector3(-hx + 0.16, yy, sz * hz - sz * 0.14), Vector3(hx - 0.16, yy + th, sz * hz), fr)
		for sx in [-1.0, 1.0]:
			_blk(pk, kit, "bpaint", Vector3(sx * hx - sx * 0.14, yy, -hz + 0.16), Vector3(sx * hx, yy + th, hz - 0.16), fr)
	# The roof, a little below the top rails, and the floor's underside.
	pk.quad(kit, "bclad", [Vector3(-hx + 0.1, y1 - 0.03, hz - 0.1), Vector3(hx - 0.1, y1 - 0.03, hz - 0.1), Vector3(hx - 0.1, y1 - 0.03, -hz + 0.1),
			Vector3(-hx + 0.1, y1 - 0.03, -hz + 0.1)], UP, wall.darkened(0.1), [Vector2(0, 0), Vector2(2 * hx, 0) * uvk, Vector2(2 * hx, 2 * hz) * uvk, Vector2(0, 2 * hz) * uvk])
	pk.quad(kit, "bpaint", [Vector3(-hx + 0.1, y0 + 0.02, -hz + 0.1), Vector3(hx - 0.1, y0 + 0.02, -hz + 0.1), Vector3(hx - 0.1, y0 + 0.02, hz - 0.1),
			Vector3(-hx + 0.1, y0 + 0.02, hz - 0.1)], Vector3.DOWN, fr.darkened(0.3))
	# Fork pockets in the bottom rails.
	for sz in [-1.0, 1.0]:
		for px in [-0.9, 0.9]:
			_blk(pk, kit, "matte", Vector3(px - 0.18, y0 + 0.04, sz * hz - 0.01), Vector3(px + 0.18, y0 + 0.14, sz * hz + 0.01), BLACK)
	var vb: float = y0 + 0.18
	var vt: float = y1 - 0.18
	var door_x: float = 1.6 if level == 0 else 2.0
	var wins: Array = [-1.6, 0.0] if level == 0 else [-1.8, -0.2]
	# The front: corrugated walls round the openings, 4cm behind the frame's faces.
	var fz: float = hz - 0.04
	var holes: Array = [[Rect2(hx + door_x - 0.45, vb, 0.9, 2.02), false]]
	for wx in wins:
		holes.append([Rect2(hx + float(wx) - 0.6, y0 + 0.95, 1.2, 1.1), false])
	SW._wall_holes(pk, kit, "bclad", Vector3(-hx, 0, fz), Vector3.RIGHT, Vector3.BACK, 0.16, 2.0 * hx - 0.16, vb, vt, holes, wall, 0.0)
	_cabin_door(pk, kit, Vector3(door_x, vb, fz), Vector3.RIGHT, Vector3.BACK)
	for wx in wins:
		_cabin_window(pk, kit, Vector3(float(wx), y0 + 1.5, fz), Vector3.RIGHT, Vector3.BACK, 1.2, 1.1)
	# The back: two windows.
	var bholes: Array = []
	for wx in [-1.2, 1.4]:
		bholes.append([Rect2(hx - float(wx) - 0.6, y0 + 0.95, 1.2, 1.1), false])
	SW._wall_holes(pk, kit, "bclad", Vector3(hx, 0, -fz), Vector3.LEFT, Vector3.FORWARD, 0.16, 2.0 * hx - 0.16, vb, vt, bholes, wall, 0.0)
	for wx in [-1.2, 1.4]:
		_cabin_window(pk, kit, Vector3(float(wx), y0 + 1.5, -fz), Vector3.LEFT, Vector3.FORWARD, 1.2, 1.1)
	# The ends: a window on the -x end, the air conditioner on the +x end.
	var ex: float = hx - 0.04
	SW._wall_holes(pk, kit, "bclad", Vector3(-ex, 0, -hz), Vector3.BACK, Vector3.LEFT, 0.16, 2.0 * hz - 0.16, vb, vt, [[Rect2(hz - 0.5, y0 + 0.95, 1.0, 1.1), false]], wall, 0.0)
	_cabin_window(pk, kit, Vector3(-ex, y0 + 1.5, 0.0), Vector3.FORWARD, Vector3.LEFT, 1.0, 1.1)
	SW._wall_holes(pk, kit, "bclad", Vector3(ex, 0, hz), Vector3.FORWARD, Vector3.RIGHT, 0.16, 2.0 * hz - 0.16, vb, vt, [], wall, 0.0)
	var ac := Vector3(ex + 0.18, y0 + 1.55, -0.3)
	_box(pk, kit, "plastic", ac, Basis(), Vector3(0.32, 0.55, 0.8), Color(0.9, 0.9, 0.88))
	pk.tube(kit, "matte", ac + Vector3(0.16, 0, 0), ac + Vector3(0.18, 0, 0), 0.2, 0.2, 14, Color(0.15, 0.15, 0.15), true)
	_rope(pk, kit, "plastic", [ac + Vector3(-0.05, -0.28, 0.2), Vector3(ex + 0.06, y0 + 0.4, -0.1), Vector3(ex + 0.06, y0 + 0.25, -0.1)], 0.025, 5, Color(0.9, 0.9, 0.88))


## A container's window in a wall's hole: white frame bars 3cm proud, the glass 2cm behind the wall's face, a shutter box.
static func _cabin_window(pk: PropKit, kit: Dictionary, c: Vector3, along: Vector3, out: Vector3, w: float, h: float) -> void:
	var b := Basis(along, UP, out)
	_pane(pk, kit, c - out * 0.02, along, UP, out, w, h)
	var fw := 0.07
	for sy in [-1.0, 1.0]:
		_box(pk, kit, "plastic", c + UP * (sy * (h * 0.5 - fw * 0.5)) + out * 0.0, b, Vector3(w, fw, 0.07), WHITE)
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "plastic", c + along * (sx * (w * 0.5 - fw * 0.5)) + out * 0.0, b, Vector3(fw, h - fw * 2.0, 0.07), WHITE)
	_box(pk, kit, "plastic", c, b, Vector3(0.05, h - fw * 2.0, 0.05), WHITE)
	_box(pk, kit, "plastic", c + UP * (h * 0.5 + 0.08) + out * 0.03, b, Vector3(w + 0.06, 0.16, 0.12), Color(0.62, 0.63, 0.64))


## A container's steel door in its hole (0.9 x 2.02, its foot at p, middle on `along`), a handle and a step.
static func _cabin_door(pk: PropKit, kit: Dictionary, p: Vector3, along: Vector3, out: Vector3) -> void:
	var b := Basis(along, UP, out)
	_box(pk, kit, "bpaint", p + UP * 1.01 - out * 0.02, b, Vector3(0.9, 2.02, 0.04), Color(0.72, 0.73, 0.74))
	_box(pk, kit, "bpaint", p + UP * 1.0 + out * 0.01, b, Vector3(0.78, 1.9, 0.02), Color(0.66, 0.67, 0.68))
	_box(pk, kit, "steel", p + UP * 1.02 + along * 0.3 + out * 0.05, b, Vector3(0.14, 0.03, 0.05), DARK)
	_box(pk, kit, "steel", p + UP * 0.12 - UP * 0.2 + out * 0.3, b, Vector3(1.0, 0.04, 0.5), DARK)
	_box(pk, kit, "bpaint", p + UP * -0.05 + out * 0.3, b, Vector3(0.9, 0.12, 0.42), DARK)


## The stack's walkway along the upper container's front on posts, its rails, and the stair down along +x.
static func _cabin_gallery(pk: PropKit, kit: Dictionary) -> void:
	var hx := CABIN_HX
	var z0: float = CABIN_HZ + 0.05
	var z1: float = z0 + CABIN_WALK
	var yf: float = CABIN_Y0 + CABIN_H
	var col := Color(0.32, 0.33, 0.34)
	_blk(pk, kit, "steel", Vector3(-hx, yf - 0.06, z0), Vector3(hx + 0.05, yf, z1), col)
	_blk(pk, kit, "bpaint", Vector3(-hx, yf - 0.2, z1 - 0.1), Vector3(hx + 0.05, yf - 0.06, z1), col.darkened(0.2))
	for px in [-hx + 0.1, 0.0, hx - 0.05]:
		_blk(pk, kit, "bpaint", Vector3(px - 0.05, 0.0, z1 - 0.1), Vector3(px + 0.05, yf - 0.2, z1), col.darkened(0.2))
		_blk(pk, kit, "steel", Vector3(px - 0.15, -0.02, z1 - 0.2), Vector3(px + 0.15, 0.02, z1 + 0.1), DARK)
	SW._railing(pk, kit, [Vector3(-hx + 0.03, yf, z0), Vector3(-hx + 0.03, yf, z1 - 0.04), Vector3(hx, yf, z1 - 0.04)], 1.1, Color(0.85, 0.86, 0.85), "paint")
	var wz: float = (z0 + z1) * 0.5
	SW._stair(pk, kit, Vector3(hx + CABIN_STAIR, 0.0, wz), Vector3(hx + 0.05, yf, wz), 1.0, col, Color(0.85, 0.86, 0.85))
	_blk(pk, kit, "steel", Vector3(hx + CABIN_STAIR - 0.3, -0.02, wz - 0.6), Vector3(hx + CABIN_STAIR + 0.3, 0.05, wz + 0.6), CONC)


static func site_cabin_solids(stacked := false) -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-CABIN_HX, 0.0, -CABIN_HZ), Vector3(CABIN_HX, CABIN_Y0 + CABIN_H * (2.0 if stacked else 1.0), CABIN_HZ))
	_solid_blk(s, Vector3(CABIN_HX, 0.0, -0.6), Vector3(CABIN_HX + 0.22, CABIN_Y0 + 1.85, 0.0))
	if stacked:
		var z1: float = CABIN_HZ + 0.05 + CABIN_WALK
		for px in [-CABIN_HX + 0.1, 0.0, CABIN_HX - 0.05]:
			_solid_blk(s, Vector3(px - 0.08, 0.0, z1 - 0.12), Vector3(px + 0.08, CABIN_Y0 + CABIN_H, z1 + 0.02))
		_solid_blk(s, Vector3(CABIN_HX, 0.0, CABIN_HZ + 0.05), Vector3(CABIN_HX + CABIN_STAIR, CABIN_Y0 + CABIN_H, z1))
	else:
		_solid_blk(s, Vector3(1.05, 0.0, CABIN_HZ), Vector3(2.15, 0.16, CABIN_HZ + 0.55))
	return s


# ======================================================================================
#  Small things
# ======================================================================================

const SKIP_COLOURS := [Color(0.13, 0.30, 0.58), Color(0.90, 0.45, 0.08), Color(0.95, 0.75, 0.10), Color(0.20, 0.40, 0.22), Color(0.45, 0.46, 0.47)]


## A skip (Absetzmulde, 7 cubic metres) along x: 3.0 x 1.7 at its floor flaring to 3.9 x 1.8 at the rim (1.5 high), ends
## sloping, ribs down its sides, lifting pins at the ends' tops, on two skids; painted by `seed_v` (blue, orange, yellow,
## green, grey) and heaped with rubble, bits of timber and a broken board. Footprint 3.9 x 1.85.
static func skip(pk: PropKit, kit: Dictionary, seed_v := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3100 + seed_v
	var col: Color = SKIP_COLOURS[absi(seed_v) % SKIP_COLOURS.size()]
	var y0 := 0.14
	var y1 := 1.5
	var ob := _rect(0, 0, 1.5, 0.85)
	var ot := _rect(0, 0, 1.95, 0.9)
	var ib := _rect(0, 0, 1.46, 0.81)
	var it := _rect(0, 0, 1.91, 0.86)
	_loft(pk, kit, "bpaint", ob, y0, ot, y1, col)
	_flat(pk, kit, "bpaint", ob, y0, false, col.darkened(0.4))
	_loft(pk, kit, "bpaint", ib, y0 + 0.05, it, y1, col.darkened(0.3), true)
	_flat(pk, kit, "bpaint", ib, y0 + 0.05, true, col.darkened(0.35))
	for k in range(4):
		var j: int = (k + 1) % 4
		pk.quad(kit, "bpaint", [Vector3(it[k].x, y1, it[k].y), Vector3(it[j].x, y1, it[j].y), Vector3(ot[j].x, y1, ot[j].y), Vector3(ot[k].x, y1, ot[k].y)], UP, col.darkened(0.1))
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "bpaint", Vector3(-1.45, 0.0, sz * 0.55 - 0.07), Vector3(1.45, y0, sz * 0.55 + 0.07), DARK)
		for x in [-1.0, -0.33, 0.33, 1.0]:
			pk.beam(kit, "bpaint", Vector3(x, y0, sz * 0.86), Vector3(x * 1.0, y1 - 0.06, sz * 0.92), 0.1, 0.06, col.darkened(0.12), Vector3.RIGHT)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pp := Vector3(sx * 1.62, 1.2, sz * 0.88)
			_rod(pk, kit, "steel", pp, pp + Vector3(0, 0, sz * 0.14), 0.05, 8, DARK)
			_rod(pk, kit, "steel", pp + Vector3(0, 0, sz * 0.12), pp + Vector3(0, 0, sz * 0.15), 0.09, 8, DARK)
	_heap(pk, kit, "brubble", Vector3(0, 0, 0), 1.72, 0.78, 0.62, 7, 4, Color(0.66, 0.6, 0.55), rng, 1.02)
	for k in range(4):
		var a: float = rng.randf_range(-1.2, 1.2)
		var c := Vector3(rng.randf_range(-1.2, 1.2), 1.45 + rng.randf() * 0.2, rng.randf_range(-0.5, 0.5))
		_box(pk, kit, "timber", c, Basis(UP, a) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)), Vector3(rng.randf_range(0.8, 1.6), 0.04, 0.12), TIMBER.darkened(rng.randf() * 0.3))
	_box(pk, kit, "painted", Vector3(-0.9, 1.75, 0.3), Basis(Vector3.BACK, 0.6) * Basis(UP, 0.3), Vector3(1.1, 0.02, 0.6), Color(0.85, 0.83, 0.78))


static func skip_solids() -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-1.95, 0.0, -0.92), Vector3(1.95, 1.55, 0.92))
	return s


## A portable toilet (1.16 x 1.16 x 2.38): a blue ribbed cabin on its dark base tray, a translucent white roof, the door
## toward +z with its handle, the occupied/free indicator and vent slots.
static func portable_toilet(pk: PropKit, kit: Dictionary) -> void:
	var col := Color(0.12, 0.32, 0.62)
	_blk(pk, kit, "plastic", Vector3(-0.58, 0.0, -0.58), Vector3(0.58, 0.12, 0.58), Color(0.2, 0.21, 0.22))
	_blk(pk, kit, "plastic", Vector3(-0.55, 0.12, -0.55), Vector3(0.55, 2.12, 0.55), col)
	for k in range(4):
		var b := Basis(UP, PI * 0.5 * float(k))
		var out: Vector3 = b * Vector3.BACK
		var along: Vector3 = b * Vector3.RIGHT
		for rx in ([-0.36, 0.0, 0.36] if k != 0 else [-0.47, 0.47]):
			_box(pk, kit, "plastic", along * float(rx) + out * 0.565 + UP * 1.12, b, Vector3(0.07, 1.9, 0.03), col.darkened(0.08))
	_blk(pk, kit, "plastic", Vector3(-0.6, 2.12, -0.6), Vector3(0.6, 2.2, 0.6), Color(0.88, 0.88, 0.86))
	var apex := Vector3(0, 2.38, 0)
	var rc: Array = [Vector3(-0.6, 2.2, 0.6), Vector3(0.6, 2.2, 0.6), Vector3(0.6, 2.2, -0.6), Vector3(-0.6, 2.2, -0.6)]
	for k in range(4):
		var a: Vector3 = rc[k]
		var c: Vector3 = rc[(k + 1) % 4]
		var o: Vector3 = ((a + c) * 0.5 - Vector3(0, 2.2, 0)).normalized() + UP * 0.9
		pk.tri(kit, "plastic", a, c, apex, o.normalized(), o.normalized(), o.normalized(), Color(0.9, 0.9, 0.88), o.normalized())
	_blk(pk, kit, "plastic", Vector3(-0.42, 0.2, 0.55), Vector3(0.42, 2.02, 0.585), col.darkened(0.12))
	_blk(pk, kit, "plastic", Vector3(-0.38, 1.85, 0.585), Vector3(0.38, 1.95, 0.6), Color(0.08, 0.1, 0.12))
	_blk(pk, kit, "plastic", Vector3(0.22, 1.02, 0.585), Vector3(0.34, 1.12, 0.63), Color(0.85, 0.85, 0.83))
	_blk(pk, kit, "plastic", Vector3(0.24, 1.16, 0.585), Vector3(0.32, 1.2, 0.6), Color(0.1, 0.65, 0.2))


static func portable_toilet_solids() -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-0.6, 0.0, -0.6), Vector3(0.6, 2.38, 0.6))
	return s


## A stack of reinforcing bar in bundles along x (`length` long, centred on the origin) on three timber bearers: four
## bundles side by side and two on top, each bar rusty, wire ties round each bundle. Footprint `length` x 1.6.
static func rebar_stack(pk: PropKit, kit: Dictionary, length: float) -> void:
	var hl: float = length * 0.5
	for bx in [-hl + 0.6, 0.0, hl - 0.6]:
		_blk(pk, kit, "timber", Vector3(bx - 0.06, 0.0, -0.8), Vector3(bx + 0.06, 0.12, 0.8), TIMBER.darkened(0.2))
	var spots: Array = [Vector2(-0.51, 0.21), Vector2(-0.17, 0.21), Vector2(0.17, 0.21), Vector2(0.51, 0.21), Vector2(-0.34, 0.51), Vector2(0.34, 0.51)]
	var k := 0
	for sp in spots:
		var c: Vector2 = sp
		var shift: float = 0.08 * float((k * 5) % 3) - 0.08
		_box(pk, kit, "rusty", Vector3(shift, c.y, c.x), Basis(), Vector3(length - 0.1, 0.17, 0.17), RUST.darkened(0.25))
		for j in range(8):
			var a: float = TAU * float(j) / 8.0
			var o := Vector3(0, sin(a) * 0.1, cos(a) * 0.1)
			var dx: float = 0.04 * float((j * 3 + k) % 4)
			pk.beam(kit, "rusty", Vector3(-hl + dx + shift, c.y, c.x) + o, Vector3(hl - dx * 0.5 + shift, c.y, c.x) + o, 0.028, 0.028, RUST.darkened(0.05 * float(j % 3)), Vector3.FORWARD)
		for tx in [-hl + 1.0, 0.0, hl - 1.0]:
			_rod(pk, kit, "steel", Vector3(tx - 0.01, c.y, c.x), Vector3(tx + 0.01, c.y, c.x), 0.125, 8, Color(0.3, 0.3, 0.3))
		k += 1


static func rebar_stack_solids(length: float) -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-length * 0.5, 0.0, -0.8), Vector3(length * 0.5, 0.65, 0.8))
	return s


## A stack of nine frame formwork panels (2.7 x 1.35, red steel frames with yellow plywood faces) lying flat on two
## bearers, a little out of line, and three leaning against it on its -z side. Footprint 2.8 x 1.9.
static func formwork_stack(pk: PropKit, kit: Dictionary) -> void:
	for bx in [-0.9, 0.9]:
		_blk(pk, kit, "timber", Vector3(bx - 0.06, 0.0, -0.7), Vector3(bx + 0.06, 0.1, 0.7), TIMBER.darkened(0.2))
	var frame := Color(0.72, 0.14, 0.08)
	for k in range(9):
		var y: float = 0.1 + 0.125 * float(k)
		var off := Vector3(0.03 * float((k * 7) % 5 - 2), 0, 0.02 * float((k * 3) % 5 - 2))
		_formwork_panel(pk, kit, Transform3D(Basis(UP, 0.012 * float((k * 5) % 3 - 1)), Vector3(0, y, 0) + off), frame)
	for k in range(3):
		var t := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.22) , Vector3(0.1 * float(k) - 0.1, 0.0, -0.78 - 0.13 * float(k)))
		_formwork_panel(pk, kit, t * Transform3D(Basis(), Vector3(0, 0, 0.675)), frame)


## One formwork panel lying in the x-z plane, its foot (underside) at y 0 of `t`: the frame 0.12 deep, the face on top.
static func _formwork_panel(pk: PropKit, kit: Dictionary, t: Transform3D, frame: Color) -> void:
	var saved := _push(pk, t)
	_blk(pk, kit, "bpaint", Vector3(-1.35, 0.0, -0.675), Vector3(1.35, 0.1, 0.675), frame)
	_blk(pk, kit, "timber", Vector3(-1.31, 0.09, -0.635), Vector3(1.31, 0.115, 0.635), PLY_YELLOW)
	_pop(pk, saved)


static func formwork_stack_solids() -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-1.45, 0.0, -0.8), Vector3(1.45, 1.25, 0.8))
	_solid_blk(s, Vector3(-1.45, 0.0, -1.2), Vector3(1.45, 1.3, -0.8))
	return s


## A masonry block with its sides' UVs running along each face (u) and up (v), in metres times `uvs`, its top too.
static func _mblock(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color, uvs: float) -> void:
	var dx: float = hi.x - lo.x
	var dz: float = hi.z - lo.z
	var faces: Array = [[Vector3(lo.x, 0, hi.z), Vector3.RIGHT, Vector3.BACK, dx], [Vector3(hi.x, 0, lo.z), Vector3.LEFT, Vector3.FORWARD, dx],
			[Vector3(hi.x, 0, hi.z), Vector3.FORWARD, Vector3.RIGHT, dz], [Vector3(lo.x, 0, lo.z), Vector3.BACK, Vector3.LEFT, dz]]
	for f in faces:
		var p0: Vector3 = f[0]
		var along: Vector3 = f[1]
		var w: float = f[3]
		pk.quad(kit, key, [p0 + along * 0.0 + UP * lo.y, p0 + along * w + UP * lo.y, p0 + along * w + UP * hi.y, p0 + UP * hi.y], f[2], col,
				[Vector2(0, lo.y) * uvs, Vector2(w, lo.y) * uvs, Vector2(w, hi.y) * uvs, Vector2(0, hi.y) * uvs])
	pk.quad(kit, key, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], UP, col.darkened(0.05),
			[Vector2(lo.x, lo.z) * uvs, Vector2(hi.x, lo.z) * uvs, Vector2(hi.x, hi.z) * uvs, Vector2(lo.x, hi.z) * uvs])


## A pallet (1.2 x 1.0) with its top boards, blocks and bottom boards, its top at y 0.144.
static func _pallet(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	var wood := Color(0.74, 0.62, 0.45)
	for bz in [-0.4, 0.0, 0.4]:
		_blk(pk, kit, "timber", c + Vector3(-0.6, 0.0, bz - 0.07), c + Vector3(0.6, 0.022, bz + 0.07), wood.darkened(0.15))
		for bx in [-0.53, 0.0, 0.53]:
			_blk(pk, kit, "timber", c + Vector3(bx - 0.07, 0.022, bz - 0.07), c + Vector3(bx + 0.07, 0.122, bz + 0.07), wood.darkened(0.08))
	for k in range(5):
		var tz: float = lerpf(-0.44, 0.44, float(k) / 4.0)
		_blk(pk, kit, "timber", c + Vector3(-0.6, 0.122, tz - 0.055), c + Vector3(0.6, 0.144, tz + 0.055), wood)


## `n` pallets of building blocks in a row along x (1.35 apart, centred on the origin): sand-lime blocks and clay blocks in
## turn, 1.15 x 0.95 x 0.9 on their pallets, two straps round each. Footprint (1.35 n - 0.15) x 1.0.
static func brick_pallets(pk: PropKit, kit: Dictionary, n: int) -> void:
	for k in range(n):
		var x: float = (float(k) - float(n - 1) * 0.5) * 1.35
		var c := Vector3(x, 0, 0)
		_pallet(pk, kit, c)
		var col: Color = Color(0.88, 0.87, 0.83) if k % 2 == 0 else Color(0.78, 0.42, 0.28)
		var y0 := 0.144
		var y1: float = y0 + (0.9 if k % 3 != 2 else 0.65)
		_mblock(pk, kit, "ashlar", c + Vector3(-0.575, y0, -0.475), c + Vector3(0.575, y1, 0.475), col, uvk * 1.55)
		for sx in [-0.3, 0.3]:
			_blk(pk, kit, "plastic", c + Vector3(sx - 0.016, y0 - 0.005, -0.485), c + Vector3(sx + 0.016, y1 + 0.006, 0.485), Color(0.08, 0.08, 0.08))


static func brick_pallets_solids(n: int) -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-0.675 * float(n) + 0.075, 0.0, -0.5), Vector3(0.675 * float(n) - 0.075, 1.05, 0.5))
	return s


## `n` concrete pipes (DN 1000: 1.2 across, 1.45 at the socket, 2.5 long) along x, up to three side by side on timber
## chocks and the rest in the grooves on top. The origin under the middle of the bottom row.
static func concrete_pipes(pk: PropKit, kit: Dictionary, n: int) -> void:
	var spots: Array = _pipe_spots(n)
	for k in range(spots.size()):
		var p: Vector3 = spots[k]
		var flip: float = 1.0 if k % 2 == 0 else -1.0
		var saved := _push(pk, Transform3D(Basis(Vector3.BACK, -PI * 0.5 * flip), p))
		SW._lathe_uv(pk, kit, "concrete", Vector3.ZERO, [Vector2(0.5, -1.25), Vector2(0.6, -1.25), Vector2(0.6, 0.85), Vector2(0.73, 0.92), Vector2(0.73, 1.25),
				Vector2(0.6, 1.25)], 16, CONC.darkened(0.03 * float(k % 3)))
		SW._lathe_uv(pk, kit, "concrete", Vector3.ZERO, [Vector2(0.6, 1.25), Vector2(0.6, 0.97), Vector2(0.5, 0.94), Vector2(0.5, -1.25)], 16, CONC.darkened(0.25), true)
		_pop(pk, saved)
		if p.y < 1.0:
			for cx in [-0.8, 0.8]:
				for sz in [-1.0, 1.0]:
					var cc := Vector3(cx, 0.06, p.z + sz * 0.5)
					_box(pk, kit, "timber", cc, Basis(Vector3.RIGHT, sz * 0.35), Vector3(0.12, 0.12, 0.3), TIMBER.darkened(0.2))


static func _pipe_spots(n: int) -> Array:
	var out: Array = []
	var bottom: int = mini(n, 3)
	for k in range(bottom):
		out.append(Vector3(0, 0.73, (float(k) - float(bottom - 1) * 0.5) * 1.5))
	var rest: int = n - bottom
	for k in range(mini(rest, bottom - 1)):
		out.append(Vector3(0, 0.73 + 1.25, (float(k) - float(bottom - 2) * 0.5) * 1.5))
	return out


static func concrete_pipes_solids(n: int) -> Array:
	var s: Array = []
	var bottom: int = mini(n, 3)
	var hz: float = float(bottom) * 0.75
	_solid_blk(s, Vector3(-1.3, 0.0, -hz), Vector3(1.3, 1.46 if n <= 3 else 2.7, hz))
	return s


## A wooden cable drum (1.4m across, its axis along x) standing on its flanges, half wound with black cable, the loose end
## out toward +z. The origin on the ground under its middle.
static func cable_drum(pk: PropKit, kit: Dictionary) -> void:
	var r := 0.7
	var c := Vector3(0, r, 0)
	var wb := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
	var wood := Color(0.58, 0.45, 0.30)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "wood", c + Vector3(sx * 0.4, 0, 0), c + Vector3(sx * 0.46, 0, 0), r, r, 16, wood, true)
		for k in range(3):
			var a: float = TAU * float(k) / 6.0 + 0.3
			var d := Vector3(0, cos(a), sin(a))
			pk.beam(kit, "wood", c + Vector3(sx * 0.48, 0, 0) - d * 0.62, c + Vector3(sx * 0.48, 0, 0) + d * 0.62, 0.1, 0.035, wood.darkened(0.15), Vector3(0, -sin(a), cos(a)))
		pk.tube(kit, "steel", c + Vector3(sx * 0.46, 0, 0), c + Vector3(sx * 0.5, 0, 0), 0.12, 0.12, 10, DARK, true)
	var prof: Array = []
	for k in range(7):
		prof.append(Vector2(0.5 if k % 2 == 0 else 0.53, lerpf(-0.4, 0.4, float(k) / 6.0)))
	pk.lathe(kit, "rubber", c, prof, 16, Color(0.05, 0.05, 0.05), false, wb)
	_rope(pk, kit, "rubber", [c + Vector3(0.2, -0.52, 0.0), Vector3(0.2, 0.04, 1.2), Vector3(-0.1, 0.04, 2.0)], 0.03, 6, Color(0.05, 0.05, 0.05))


static func cable_drum_solids() -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-0.5, 0.0, -0.7), Vector3(0.5, 1.4, 0.7))
	return s


## A heap of building sand of radius `r` and height `h` round the origin: a mound of facets, a little wandering at its foot
## (which reaches 12cm under the ground).
static func sand_pile(pk: PropKit, kit: Dictionary, r: float, h: float, seed_v := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5300 + seed_v
	var segs := 18
	var rings := 5
	var jit: Array = []
	for j in range(segs):
		jit.append(1.0 + rng.randf_range(-0.1, 0.12))
	var pts: Array = []
	for i in range(rings + 1):
		var row: Array = []
		var f: float = float(i) / float(rings)
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			var rr: float = r * (1.0 - f) * float(jit[j])
			var y: float = h * (1.0 - pow(1.0 - f, 1.7)) * (0.94 + 0.12 * rng.randf()) - 0.12 * (1.0 - f) * float(i == 0)
			if i == rings:
				y = h
				rr = 0.0
			row.append(Vector3(cos(a) * rr, y if i > 0 else -0.12, sin(a) * rr))
		pts.append(row)
	var col := Color(0.80, 0.69, 0.49)
	for i in range(rings):
		for j in range(segs):
			var j1: int = (j + 1) % segs
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j1]
			var c: Vector3 = pts[i + 1][j1]
			var d: Vector3 = pts[i + 1][j]
			var n1: Vector3 = (c - a).cross(b - a).normalized()
			if n1.y < 0.0:
				n1 = -n1
			pk.tri(kit, "bsand", a, b, c, n1, n1, n1, col, n1)
			if i < rings - 1:
				var n2: Vector3 = (d - a).cross(c - a).normalized()
				if n2.y < 0.0:
					n2 = -n2
				pk.tri(kit, "bsand", a, c, d, n2, n2, n2, col.darkened(0.04), n2)


## Three stacked boxes standing in for the sand pile's mound (approximate: a convex hull of the mesh fits it better).
static func sand_pile_solids(r: float, h: float) -> Array:
	var s: Array = []
	for k in range(3):
		var f: float = float(k) / 3.0
		var hw: float = r * (1.0 - f) * 0.75
		_solid_blk(s, Vector3(-hw, h * f, -hw), Vector3(hw, h * (f + 1.0 / 3.0), hw))
	return s


# ======================================================================================
#  The mixer truck and the dumper
# ======================================================================================

const MIXER_DRUM_A := Vector3(0, 1.78, -1.95)   # the drum's axis: its front end (the gearbox) ...
const MIXER_DRUM_LEN := 5.3                      # ... and its length along the axis, rising 10.8 degrees to the rear
const MIXER_TILT := 0.1885


## A concrete mixer truck (three axles, about 8.8 x 2.5 x 3.75, an original design), its front toward -z: a cab-over cab in
## white with its windscreen, grille, bumper, lamps and mirrors, the chassis, the water tank behind the cab, the drum (white
## with KRONBAU's blue and yellow bands) rising toward the rear on its pedestals, the charging hopper, the chute and its
## ladder, side guards, fuel tank, mudguards and tail lamps. Static.
static func mixer_truck(pk: PropKit, kit: Dictionary) -> void:
	var cab_col := Color(0.92, 0.92, 0.90)
	var chassis := Color(0.12, 0.12, 0.13)
	var rim := Color(0.75, 0.76, 0.76)
	# Wheels: the front axle single, the rear tandem in twins.
	for sx in [-1.0, 1.0]:
		_wheel(pk, kit, Vector3(sx * 1.0, 0.53, -2.75), 0.29, 0.53, 0.32, sx, rim, 12, 8)
		for wz in [1.55, 2.9]:
			_wheel(pk, kit, Vector3(sx * 1.08, 0.53, wz), 0.29, 0.53, 0.29, sx, rim, 12, 8)
			_wheel(pk, kit, Vector3(sx * 0.76, 0.53, wz), 0.29, 0.53, 0.29, -sx, rim.darkened(0.3), 12, 0)
		_rod(pk, kit, "steel", Vector3(sx * 0.45, 0.53, -2.75), Vector3(sx * 0.85, 0.53, -2.75), 0.06, 6, chassis)
	for wz in [1.55, 2.9]:
		_rod(pk, kit, "steel", Vector3(-0.62, 0.53, wz), Vector3(0.62, 0.53, wz), 0.12, 8, chassis)
	# The chassis rails and cross members.
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "bpaint", Vector3(sx * 0.43 - 0.05, 0.82, -3.95), Vector3(sx * 0.43 + 0.05, 1.12, 4.0), chassis)
	for cz in [-3.6, -1.9, 0.2, 2.2, 3.8]:
		_blk(pk, kit, "bpaint", Vector3(-0.38, 0.86, cz - 0.06), Vector3(0.38, 1.08, cz + 0.06), chassis)
	# The cab.
	var ol := PackedVector2Array([Vector2(-2.35, 1.12), Vector2(-2.35, 3.05), Vector2(-2.45, 3.15), Vector2(-3.98, 3.15), Vector2(-4.12, 3.0), Vector2(-4.24, 1.95),
			Vector2(-4.22, 1.12)])
	_side_prism(pk, kit, "bpaint", ol, -1.24, 1.24, cab_col, 0.06)
	var a := Vector3(0, 1.98, -4.24)
	var b := Vector3(0, 2.98, -4.12)
	var along: Vector3 = (b - a).normalized()
	var nrm := Vector3(0, -along.z, along.y)
	if nrm.z > 0.0:
		nrm = -nrm
	var mid: Vector3 = a.lerp(b, 0.5) + nrm * 0.025
	_pane(pk, kit, Vector3(0, mid.y, mid.z), Vector3.RIGHT, along, nrm, 2.25, 0.95)
	for sx in [-1.0, 1.0]:
		_pane(pk, kit, Vector3(sx * 1.265, 2.45, -3.45), Vector3.BACK, UP, Vector3(sx, 0, 0), 1.05, 0.95)
		_box(pk, kit, "bpaint", Vector3(sx * 1.265, 1.6, -3.45), Basis(), Vector3(0.02, 0.04, 1.1), cab_col.darkened(0.2))
		# Steps under the door, the mirror on its arm.
		for sy in [0.62, 0.98]:
			_blk(pk, kit, "steel", Vector3(sx * 1.25 - 0.22, sy - 0.03, -3.85), Vector3(sx * 1.25 + 0.02, sy, -3.2), DARK)
		_rope(pk, kit, "steel", [Vector3(sx * 1.24, 2.8, -4.0), Vector3(sx * 1.5, 2.85, -4.15), Vector3(sx * 1.52, 2.6, -4.15)], 0.02, 5, DARK)
		_box(pk, kit, "bpaint", Vector3(sx * 1.52, 2.35, -4.15), Basis(UP, sx * 0.3), Vector3(0.2, 0.5, 0.06), DARK)
		_box(pk, kit, "lens", Vector3(sx * 0.82, 0.78, -4.395), Basis(), Vector3(0.36, 0.14, 0.02), Color(0.9, 0.9, 0.85))
		_box(pk, kit, "lamp", Vector3(sx * 0.9, 3.2, -3.9), Basis(), Vector3(0.12, 0.06, 0.06), AMBER)
	_blk(pk, kit, "bpaint", Vector3(-0.85, 1.3, -4.25), Vector3(0.85, 1.85, -4.21), Color(0.15, 0.15, 0.16))
	for k in range(5):
		_blk(pk, kit, "bpaint", Vector3(-0.8, 1.37 + 0.1 * float(k), -4.27), Vector3(0.8, 1.41 + 0.1 * float(k), -4.24), Color(0.55, 0.56, 0.57))
	_blk(pk, kit, "bpaint", Vector3(-1.25, 0.55, -4.38), Vector3(1.25, 0.98, -4.1), Color(0.3, 0.31, 0.32))
	_blk(pk, kit, "bpaint", Vector3(-1.2, 3.02, -3.95), Vector3(1.2, 3.1, -3.85), DARK)
	# The front mudguards over the front wheels.
	for sx in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for k in range(6):
			var ang: float = lerpf(PI * 0.15, PI * 0.85, float(k) / 5.0)
			var p := Vector3(sx * 1.0, 0.53 + cos(ang - PI * 0.5) * 0.62, -2.75 - sin(ang - PI * 0.5) * 0.62)
			if k > 0:
				pk.beam(kit, "bpaint", prev, p, 0.36, 0.03, BLACK, Vector3.RIGHT)
			prev = p
	# The water tank behind the cab, the air tanks, the fuel tank, the side guards.
	_rod(pk, kit, "bpaint", Vector3(0.45, 1.15, -2.05), Vector3(0.45, 2.55, -2.05), 0.28, 14, cab_col)
	_rod(pk, kit, "steel", Vector3(0.95, 0.85, -1.4), Vector3(0.95, 0.85, -0.6), 0.12, 10, Color(0.3, 0.3, 0.3))
	_rod(pk, kit, "steel", Vector3(-0.9, 0.78, -1.6), Vector3(-0.9, 0.78, -0.5), 0.26, 14, Color(0.7, 0.71, 0.72))
	for sx in [-1.0, 1.0]:
		for gy in [0.5, 0.82]:
			_blk(pk, kit, "bpaint", Vector3(sx * 1.2 - 0.02, gy - 0.05, -1.95), Vector3(sx * 1.2 + 0.02, gy + 0.05, 0.95), _a(DUMPER_YELLOW, HAZ))
		_blk(pk, kit, "bpaint", Vector3(sx * 1.25 - 0.55, 1.08, 1.0), Vector3(sx * 1.25, 1.12, 3.45), BLACK)
	# The drum's pedestals: an A-frame at the front with the gearbox, legs to the roller track at the rear.
	var ax := Vector3(0, sin(MIXER_TILT), cos(MIXER_TILT))
	var pa := MIXER_DRUM_A
	for sx in [-1.0, 1.0]:
		_bar(pk, kit, "bpaint", Vector3(sx * 0.42, 1.1, -2.2), pa + Vector3(sx * 0.12, 0.25, 0.1), 0.14, 0.14, chassis)
		var rt: Vector3 = pa + ax * 4.05 + Vector3(sx * 0.62, -0.75, 0)
		_bar(pk, kit, "bpaint", Vector3(sx * 0.42, 1.1, rt.z - 0.3), rt, 0.16, 0.16, chassis)
		_rod(pk, kit, "steel", rt + Vector3(-0.08, 0.1, 0), rt + Vector3(0.08, 0.1, 0), 0.14, 10, DARK)
	_box(pk, kit, "bpaint", pa + Vector3(0, 0, -0.12), Basis(), Vector3(0.6, 0.6, 0.3), DARK)
	_mixer_drum(pk, kit, pa, ax)
	# The hopper over the drum's mouth, the chute under it, the ladder up to it.
	var mouth: Vector3 = pa + ax * MIXER_DRUM_LEN
	var hb := Basis(Vector3.RIGHT, -0.25)
	pk.lathe(kit, "bpaint", mouth + Vector3(0, 0.35, 0.15), [Vector2(0.28, 0.0), Vector2(0.72, 0.62), Vector2(0.76, 0.66), Vector2(0.68, 0.66), Vector2(0.24, 0.02)], 14, cab_col.darkened(0.08), false, hb)
	var ch0: Vector3 = mouth + Vector3(0, -0.55, 0.25)
	var ch1: Vector3 = ch0 + Vector3(0, -0.55, 1.05)
	pk.beam(kit, "bpaint", ch0, ch1, 0.5, 0.04, Color(0.55, 0.56, 0.57), Vector3.RIGHT)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "bpaint", ch0 + Vector3(sx * 0.25, 0.1, 0), ch1 + Vector3(sx * 0.25, 0.1, 0), 0.03, 0.22, Color(0.55, 0.56, 0.57), Vector3.RIGHT)
	for sx in [-1.0, 1.0]:
		_rod(pk, kit, "steel", Vector3(0.95 + sx * 0.2, 0.45, 4.05), Vector3(0.95 + sx * 0.2, 2.95, 3.75), 0.025, 5, GALV)
	for k in range(1, 9):
		var ly: float = 0.45 + 0.28 * float(k)
		var lz: float = 4.05 - 0.3 * float(k) / 9.0
		_rod(pk, kit, "steel", Vector3(0.75, ly, lz), Vector3(1.15, ly, lz), 0.018, 4, GALV)
	_blk(pk, kit, "steel", Vector3(0.55, 2.85, 3.3), Vector3(1.2, 2.9, 3.8), DARK)
	# The rear: bumper, lamps, the underrun bar.
	_blk(pk, kit, "bpaint", Vector3(-1.2, 0.45, 4.0), Vector3(1.2, 0.62, 4.12), _a(Color(0.85, 0.12, 0.08), 0.2))
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "lens", Vector3(sx * 1.0, 0.75, 4.06), Basis(), Vector3(0.3, 0.12, 0.04), Color(0.75, 0.08, 0.05))


## The drum: a lathe about its tilted axis from the gearbox (`a`) back to the mouth, painted in bands; the ring track.
static func _mixer_drum(pk: PropKit, kit: Dictionary, a: Vector3, ax: Vector3) -> void:
	var b := Basis(Vector3.RIGHT, PI * 0.5 - MIXER_TILT)   # the lathe's y onto the axis
	var white := Color(0.93, 0.93, 0.91)
	var prof: Array = [[0.001, 0.0, white], [0.32, 0.0, white], [0.78, 0.4, white], [1.06, 1.15, KB_BLUE], [1.14, 1.8, KB_BLUE], [1.15, 2.3, white],
			[1.14, 2.9, KB_YELLOW], [1.1, 3.25, white], [0.95, 3.95, white], [0.68, 4.75, KB_BLUE], [0.52, 5.15, KB_BLUE], [0.52, MIXER_DRUM_LEN, white],
			[0.44, MIXER_DRUM_LEN, white]]
	for k in range(prof.size() - 1):
		var p0: Array = prof[k]
		var p1: Array = prof[k + 1]
		pk.lathe(kit, "bpaint", a, [Vector2(float(p0[0]), float(p0[1])), Vector2(float(p1[0]), float(p1[1]))], 20, p0[2], false, b)
	pk.lathe(kit, "bpaint", a, [Vector2(0.44, MIXER_DRUM_LEN), Vector2(0.44, MIXER_DRUM_LEN - 0.5), Vector2(0.001, MIXER_DRUM_LEN - 0.6)], 14, Color(0.25, 0.25, 0.24), false, b)
	pk.lathe(kit, "steel", a, [Vector2(0.98, 3.85), Vector2(1.04, 3.85), Vector2(1.04, 4.0), Vector2(0.96, 4.0)], 20, DARK, false, b)


static func mixer_truck_solids() -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-1.27, 0.0, -4.4), Vector3(1.27, 3.15, -2.3))
	_solid_blk(s, Vector3(-1.27, 0.0, -2.3), Vector3(1.27, 1.2, 4.15))
	var ax := Vector3(0, sin(MIXER_TILT), cos(MIXER_TILT))
	_solid(s, MIXER_DRUM_A + ax * (MIXER_DRUM_LEN * 0.5), Vector3(2.3, 2.3, MIXER_DRUM_LEN), Basis(Vector3.RIGHT, -MIXER_TILT))
	return s


## A site dumper (front tipping skip, about 6 tonnes, an original design), its front toward -z: the skip over the front axle
## heaped with soil, the articulated frame, the engine hood behind the seat, a folding ROPS hoop with a beacon, four big
## tyres. About 4.4 x 2.1 x 2.95.
static func dumper(pk: PropKit, kit: Dictionary) -> void:
	var body := DUMPER_YELLOW
	var frame := Color(0.15, 0.15, 0.15)
	var rim := Color(0.95, 0.75, 0.12)
	for sx in [-1.0, 1.0]:
		for wz in [-1.05, 0.95]:
			_wheel(pk, kit, Vector3(sx * 0.82, 0.6, wz), 0.32, 0.6, 0.42, sx, rim, 12, 6)
			# Mudguards over the rear wheels.
			if wz > 0.0:
				_box(pk, kit, "bpaint", Vector3(sx * 0.82, 1.27, wz), Basis(), Vector3(0.5, 0.04, 1.2), BLACK)
	_blk(pk, kit, "bpaint", Vector3(-0.42, 0.45, -1.65), Vector3(0.42, 1.12, -0.3), frame)
	_rod(pk, kit, "steel", Vector3(-0.62, 0.6, -1.05), Vector3(0.62, 0.6, -1.05), 0.1, 8, frame)
	_rod(pk, kit, "steel", Vector3(-0.62, 0.6, 0.95), Vector3(0.62, 0.6, 0.95), 0.1, 8, frame)
	_rod(pk, kit, "steel", Vector3(0, 0.55, -0.22), Vector3(0, 1.15, -0.22), 0.1, 8, Color(0.3, 0.3, 0.3))
	# The skip: side plates round a floor, a back wall and a sloping front lip, then soil heaped in it.
	var side := PackedVector2Array([Vector2(-0.28, 1.32), Vector2(-1.35, 1.32), Vector2(-2.25, 1.92), Vector2(-2.25, 2.0), Vector2(-1.3, 2.08), Vector2(-0.28, 2.12)])
	for sx in [-1.0, 1.0]:
		_side_prism(pk, kit, "bpaint", side, minf(sx * 1.0, sx * 1.04), maxf(sx * 1.0, sx * 1.04), body, 0.0)
	var shell: Array = [Vector2(-2.25, 1.96), Vector2(-1.35, 1.32), Vector2(-0.28, 1.32), Vector2(-0.28, 2.12)]
	for k in range(shell.size() - 1):
		var p0: Vector2 = shell[k]
		var p1: Vector2 = shell[k + 1]
		var e: Vector2 = p1 - p0
		var o := Vector3(0, -e.x, e.y).normalized()
		if Vector3(0, (p0.y + p1.y) * 0.5 - 1.75, (p0.x + p1.x) * 0.5 + 1.25).dot(o) < 0.0:
			o = -o
		pk.quad(kit, "bpaint", [Vector3(-1.0, p0.y, p0.x), Vector3(1.0, p0.y, p0.x), Vector3(1.0, p1.y, p1.x), Vector3(-1.0, p1.y, p1.x)], o, body.darkened(0.05))
		var ip0: Vector2 = p0 + Vector2(0.0, 0.0)
		pk.quad(kit, "bpaint", [Vector3(-1.0, ip0.y, ip0.x) - o * 0.03, Vector3(1.0, ip0.y, ip0.x) - o * 0.03, Vector3(1.0, p1.y, p1.x) - o * 0.03,
				Vector3(-1.0, p1.y, p1.x) - o * 0.03], -o, body.darkened(0.4))
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	_heap(pk, kit, "brubble", Vector3(0, 0, -1.15), 0.95, 0.8, 0.45, 5, 4, Color(0.45, 0.36, 0.27), rng, 1.6)
	# The rear frame: the seat on its box, the steering wheel, the engine hood, the ROPS, the beacon.
	_blk(pk, kit, "bpaint", Vector3(-0.75, 0.75, -0.1), Vector3(0.75, 1.22, 0.45), body.darkened(0.1))
	_blk(pk, kit, "matte", Vector3(-0.25, 1.22, 0.0), Vector3(0.25, 1.34, 0.42), Color(0.08, 0.08, 0.08))
	_box(pk, kit, "matte", Vector3(0, 1.62, 0.44), Basis(Vector3.RIGHT, -0.15), Vector3(0.48, 0.55, 0.08), Color(0.08, 0.08, 0.08))
	_rod(pk, kit, "steel", Vector3(0, 1.05, -0.32), Vector3(0, 1.5, -0.2), 0.03, 6, DARK)
	pk.tyre(kit, "rubber", Vector3(0, 1.52, -0.2), 0.13, 0.18, 0.03, 12, Color(0.06, 0.06, 0.06), Basis(Vector3.RIGHT, -0.7))
	var hood := PackedVector2Array([Vector2(0.45, 0.85), Vector2(1.78, 0.85), Vector2(1.78, 1.45), Vector2(1.6, 1.62), Vector2(0.45, 1.62)])
	_side_prism(pk, kit, "bpaint", hood, -0.72, 0.72, body, 0.05)
	for sx in [-1.0, 1.0]:
		for k in range(3):
			_blk(pk, kit, "bpaint", Vector3(sx * 0.72 - 0.012, 1.05, 0.75 + 0.25 * float(k)), Vector3(sx * 0.72 + 0.012, 1.45, 0.9 + 0.25 * float(k)), DARK)
		_box(pk, kit, "lens", Vector3(sx * 0.5, 1.3, 1.795), Basis(), Vector3(0.12, 0.08, 0.02), Color(0.75, 0.08, 0.05))
		_bar(pk, kit, "bpaint", Vector3(sx * 0.78, 0.9, 0.55), Vector3(sx * 0.78, 2.72, 0.55), 0.09, 0.09, body)
	_bar(pk, kit, "bpaint", Vector3(-0.82, 2.72, 0.55), Vector3(0.82, 2.72, 0.55), 0.1, 0.1, body)
	pk.lathe(kit, "lamp", Vector3(0.5, 2.77, 0.55), [Vector2(0.001, 0.0), Vector2(0.07, 0.0), Vector2(0.065, 0.12), Vector2(0.001, 0.14)], 10, AMBER)
	_rope(pk, kit, "steel", [Vector3(0.45, 1.62, 1.45), Vector3(0.45, 2.05, 1.45)], 0.04, 6, Color(0.2, 0.2, 0.2))


static func dumper_solids() -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-1.05, 0.0, -2.25), Vector3(1.05, 2.1, 1.8))
	return s


# ======================================================================================
#  The Bauschild, Leitbaken, warning lamps, scaffolding
# ======================================================================================

## The Bauschild: a 4.2 x 2.8 board (y 1.4 to 4.2) on two steel posts in concrete feet, facing +z, the middle of its foot
## at the origin: the project's title on a blue band, a picture of the car park to come, who is building it (fictional),
## the logos along its foot. Labels on the front.
static func site_sign(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var y0 := 1.4
	var y1 := 4.2
	var hw := 2.1
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "bpaint", Vector3(sx * 1.75 - 0.05, -0.4, -0.07), Vector3(sx * 1.75 + 0.05, y1 - 0.1, 0.03), Color(0.4, 0.42, 0.43))
		_blk(pk, kit, "concrete", Vector3(sx * 1.75 - 0.3, -0.5, -0.32), Vector3(sx * 1.75 + 0.3, 0.12, 0.28), CONC)
	for by in [y0 + 0.4, y1 - 0.4]:
		_blk(pk, kit, "timber", Vector3(-hw + 0.1, by - 0.05, 0.03), Vector3(hw - 0.1, by + 0.05, 0.07), TIMBER)
	_blk(pk, kit, "enamel", Vector3(-hw, y0, 0.07), Vector3(hw, y1, 0.1), WHITE)
	var fz := 0.11
	_blk(pk, kit, "enamel", Vector3(-hw + 0.06, y1 - 0.62, 0.1), Vector3(hw - 0.06, y1 - 0.06, fz), KB_BLUE)
	_lbl(labels, "NEUBAU PARKHAUS HAFEN-OST", Vector3(0, y1 - 0.34, fz + 0.02), Vector3.BACK, 0.22, Color(0.98, 0.98, 0.96), 3.9)
	# The picture: sky, the car park's decks in bands with green planters, the harbour's water.
	var px0 := -hw + 0.12
	var px1 := -0.2
	var py0 := y0 + 0.55
	var py1 := y1 - 0.75
	_blk(pk, kit, "enamel", Vector3(px0, py0, 0.1), Vector3(px1, py1, fz), Color(0.62, 0.78, 0.92))
	_blk(pk, kit, "enamel", Vector3(px0, py0, 0.1), Vector3(px1, py0 + 0.2, fz + 0.004), Color(0.25, 0.42, 0.55))
	for k in range(4):
		var dy: float = py0 + 0.24 + 0.27 * float(k)
		_blk(pk, kit, "enamel", Vector3(px0 + 0.15, dy, 0.1), Vector3(px1 - 0.25, dy + 0.06, fz + 0.008), Color(0.72, 0.72, 0.7))
		_blk(pk, kit, "enamel", Vector3(px0 + 0.15, dy + 0.06, 0.1), Vector3(px1 - 0.25, dy + 0.21, fz + 0.006), Color(0.38, 0.42, 0.45))
		_blk(pk, kit, "enamel", Vector3(px0 + 0.15, dy + 0.06, 0.1), Vector3(px1 - 0.25, dy + 0.09, fz + 0.01), Color(0.3, 0.55, 0.25))
	_blk(pk, kit, "enamel", Vector3(px1 - 0.55, py0 + 0.24, 0.1), Vector3(px1 - 0.3, py1 - 0.05, fz + 0.012), Color(0.85, 0.85, 0.82))
	var lines: Array = [["Bauherr:", "Stadt Kronburg · Tiefbauamt"], ["Entwurf:", "Dahlmann Grothe Architekten"], ["Tragwerk:", "Ingenieurbüro Brakemeier + Voss"],
			["Rohbau:", "KRONBAU GmbH, Kronburg"], ["Fertigstellung:", "Herbst 2027"]]
	for k in range(lines.size()):
		var ly: float = y1 - 0.88 - 0.3 * float(k)
		_lbl(labels, lines[k][0], Vector3(0.95, ly + 0.07, fz + 0.02), Vector3.BACK, 0.05, Color(0.35, 0.35, 0.37), 2.0)
		_lbl(labels, lines[k][1], Vector3(0.95, ly - 0.06, fz + 0.02), Vector3.BACK, 0.085, Color(0.08, 0.1, 0.16), 2.1)
	# The logos along the foot: the city's crown, the architects', the engineers', KRONBAU's.
	var logos: Array = [[Color(0.75, 0.6, 0.12), "Kronburg"], [Color(0.2, 0.2, 0.22), "DG"], [Color(0.55, 0.12, 0.12), "B+V"], [KB_BLUE, "KRONBAU"]]
	for k in range(logos.size()):
		var lx: float = -1.6 + 1.07 * float(k)
		_blk(pk, kit, "enamel", Vector3(lx - 0.42, y0 + 0.1, 0.1), Vector3(lx + 0.42, y0 + 0.44, fz), logos[k][0])
		_lbl(labels, logos[k][1], Vector3(lx, y0 + 0.27, fz + 0.02), Vector3.BACK, 0.1, Color(0.97, 0.97, 0.95), 0.75)
	_blk(pk, kit, "enamel", Vector3(-1.6 + 3.21 + 0.2, y0 + 0.1, 0.1), Vector3(-1.6 + 3.21 + 0.42, y0 + 0.44, fz + 0.005), KB_YELLOW)


static func site_sign_solids() -> Array:
	var s: Array = []
	for sx in [-1.0, 1.0]:
		_solid_blk(s, Vector3(sx * 1.75 - 0.3, 0.0, -0.32), Vector3(sx * 1.75 + 0.3, 1.45, 0.28))
	_solid_blk(s, Vector3(-2.1, 1.4, -0.07), Vector3(2.1, 4.2, 0.12))
	return s


## The Leitbake's board's top over the ground: a warning lamp (warning_lamp) sits there.
const LEITBAKE_TOP := 1.0


## A Leitbake: a red-and-white striped warning board 0.25 wide (y 0.2 to 1.0, its faces toward ±z, stripes on both) on a
## stem in a black rubber foot (0.8 x 0.4, along x). 48 triangles; its pattern rides with it (bpaint, UV), so it can be
## knocked about.
static func leitbake(pk: PropKit, kit: Dictionary) -> void:
	pk.extrude(kit, "rubber", PackedVector2Array([Vector2(-0.4, 0.0), Vector2(0.4, 0.0), Vector2(0.33, 0.09), Vector2(-0.33, 0.09)]), -0.2, 0.2, 0.0, Color(0.07, 0.07, 0.07))
	_blk(pk, kit, "bpaint", Vector3(-0.05, 0.08, -0.04), Vector3(0.05, 0.22, 0.04), Color(0.1, 0.1, 0.1))
	pk.box(kit, "bpaint", Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(0.25, 0.8, 0.045), WARN_RED, 1.0)
	_blk(pk, kit, "bpaint", Vector3(-0.135, LEITBAKE_TOP - 0.03, -0.03), Vector3(0.135, LEITBAKE_TOP, 0.03), Color(0.85, 0.85, 0.83))


static func leitbake_solids() -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-0.4, 0.0, -0.2), Vector3(0.4, 0.1, 0.2))
	_solid_blk(s, Vector3(-0.13, 0.1, -0.03), Vector3(0.13, LEITBAKE_TOP, 0.03))
	return s


## A battery warning lamp: a black housing with a round amber lens on both faces (±z, lit), on a clamp whose foot is at the
## origin (put it at y LEITBAKE_TOP on a Leitbake). About 0.3 tall.
static func warning_lamp(pk: PropKit, kit: Dictionary) -> void:
	_blk(pk, kit, "matte", Vector3(-0.04, 0.0, -0.04), Vector3(0.04, 0.07, 0.04), Color(0.1, 0.1, 0.1))
	_rod(pk, kit, "steel", Vector3(-0.06, 0.035, 0), Vector3(0.06, 0.035, 0), 0.012, 5, GALV)
	_blk(pk, kit, "plastic", Vector3(-0.1, 0.07, -0.055), Vector3(0.1, 0.29, 0.055), Color(0.08, 0.08, 0.08))
	for sz in [-1.0, 1.0]:
		var c := Vector3(0, 0.18, sz * 0.055)
		pk.lathe(kit, "lamp", c, [Vector2(0.088, 0.0), Vector2(0.088, 0.018), Vector2(0.06, 0.03), Vector2(0.001, 0.032)], 12, AMBER, false, Basis(Vector3.RIGHT, sz * PI * 0.5))
	_blk(pk, kit, "plastic", Vector3(-0.03, 0.29, -0.02), Vector3(0.03, 0.31, 0.02), Color(0.08, 0.08, 0.08))


## Tube-and-board scaffolding along +x from x = 0 to `w`, against a wall in the plane z = 0 (the scaffold stands from z 0.25
## to 0.25 + `d`), `h` high: standards every 2.5m or so on base plates and sole boards, ledgers and transoms every 2m, steel
## decks at every lift with toe boards and two guard rails on the outside and the ends, a rail round the top, and diagonal
## bracing across every third bay of the outer face.
static func scaffold(pk: PropKit, kit: Dictionary, w: float, h: float, d: float) -> void:
	var nb: int = maxi(1, int(round(w / 2.5)))
	var bay: float = w / float(nb)
	var zi := 0.25
	var zo: float = 0.25 + d
	var r := 0.024
	var lifts: Array = []
	var ly := 2.0
	while ly <= h + 0.01:
		lifts.append(ly)
		ly += 2.0
	var top: float = (float(lifts[-1]) if lifts.size() > 0 else 0.0) + 1.0
	for k in range(nb + 1):
		var x: float = bay * float(k)
		for z in [zi, zo]:
			_rod(pk, kit, "metal", Vector3(x, 0.05, z), Vector3(x, top, z), r, 6, GALV, false)
			_blk(pk, kit, "steel", Vector3(x - 0.075, 0.03, z - 0.075), Vector3(x + 0.075, 0.05, z + 0.075), GALV.darkened(0.2))
		_blk(pk, kit, "timber", Vector3(x - 0.12, 0.0, zi - 0.25), Vector3(x + 0.12, 0.03, zo + 0.25), TIMBER.darkened(0.25))
	var nplanks: int = maxi(2, int(floor(d / 0.32)))
	for l in lifts:
		var y: float = l
		for z in [zi, zo]:
			_rod(pk, kit, "metal", Vector3(-0.1, y, z), Vector3(w + 0.1, y, z), r, 6, GALV, false)
		for k in range(nb + 1):
			_rod(pk, kit, "metal", Vector3(bay * float(k), y + 0.05, zi - 0.15), Vector3(bay * float(k), y + 0.05, zo + 0.1), r, 6, GALV, false)
		for p in range(nplanks):
			var pz: float = zi + 0.04 + (d - 0.08) * (float(p) + 0.5) / float(nplanks)
			_blk(pk, kit, "steel", Vector3(0.02, y + 0.08, pz - 0.15), Vector3(w - 0.02, y + 0.13, pz + 0.15), Color(0.6, 0.62, 0.62).darkened(0.05 * float(p % 2)))
		_blk(pk, kit, "timber", Vector3(0.0, y + 0.13, zo - 0.04), Vector3(w, y + 0.28, zo - 0.01), TIMBER.darkened(0.1))
		for gy in [0.55, 1.0]:
			_rod(pk, kit, "metal", Vector3(-0.1, y + gy, zo + 0.05), Vector3(w + 0.1, y + gy, zo + 0.05), r, 6, GALV, false)
			for x in [0.0, w]:
				_rod(pk, kit, "metal", Vector3(x, y + gy, zi - 0.05), Vector3(x, y + gy, zo + 0.08), r, 6, GALV, false)
	# Bracing across every third bay of the outer face, zigzagging up.
	var k2 := 0
	while k2 < nb:
		var xa: float = bay * float(k2)
		var xb: float = bay * float(k2 + 1)
		var yb := 0.2
		var flip := false
		for l in lifts:
			var yt: float = l
			if flip:
				_rod(pk, kit, "metal", Vector3(xb, yb, zo + 0.05), Vector3(xa, yt, zo + 0.05), r, 6, GALV, false)
			else:
				_rod(pk, kit, "metal", Vector3(xa, yb, zo + 0.05), Vector3(xb, yt, zo + 0.05), r, 6, GALV, false)
			flip = not flip
			yb = yt
		k2 += 3


static func scaffold_solids(w: float, h: float, d: float) -> Array:
	var s: Array = []
	_solid_blk(s, Vector3(-0.1, 0.0, 0.15), Vector3(w + 0.1, h + 1.0, 0.35 + d))
	return s


# ======================================================================================
#  The car park under construction (the route drives through it)
# ======================================================================================

const CP_COL := 0.5           # the columns 0.5 x 0.5 ...
const CP_COL_H := 3.2         # ... 3.2 high: the first deck's underside
const CP_DECK_T := 0.25       # the deck's top at 3.45
const CP_DZ := 8.0            # the column grid along z ...
const CP_DX := 7.5            # ... and across x
const CP_SLAB_TOP := 0.06     # the ground slab's top over the ground
const CP_OPEN := 0.6          # nothing at all within road_half + 0.6 of x = 0, at any height
const CP_DECK_IN := 2.5       # the deck's inner edges at |x| = road_half + 2.5
const CP_CORE := 5.1          # the stair core's size in plan
const CP_CORE_TOP := 6.9      # its walls' top (two storeys)
const CP_PROP_DZ := 2.4       # the slab props along z


## The column lines on the +x side (mirrored on -x): the first with its inner face 0.05 past the clear corridor, then every
## CP_DX while a column fits inside the footprint.
static func _cp_col_xs(width: float, road_half: float) -> Array:
	var out: Array = []
	var x: float = road_half + CP_OPEN + 0.05 + CP_COL * 0.5
	while x <= width * 0.5 - CP_COL * 0.5 + 0.001:
		out.append(x)
		x += CP_DX
	return out


## The column rows along z (every CP_DZ, centred in the length).
static func _cp_col_zs(length: float) -> Array:
	var n: int = int(floor((length - 1.0) / CP_DZ)) + 1
	var z0: float = -(length - float(n - 1) * CP_DZ) * 0.5
	var out: Array = []
	for k in range(n):
		out.append(z0 - CP_DZ * float(k))
	return out


## The stair core's rectangle in plan (x, z): in the +x side's far corner (toward -length), or an empty Rect2 when the
## footprint has no room for it beside the deck's inner edge.
static func _cp_core(length: float, width: float, road_half: float) -> Rect2:
	var hw: float = width * 0.5
	var x0: float = hw - 1.3 - CP_CORE
	if length < CP_CORE + 4.0 or x0 < road_half + CP_DECK_IN + 1.0:
		return Rect2()
	return Rect2(x0, -length + 1.3, CP_CORE, CP_CORE)


## The deck's slabs in plan as [x0, x1, z0, z1] (both sides; the +x side's far corner left open round the stair core).
static func _cp_decks(length: float, width: float, road_half: float) -> Array:
	var hw: float = width * 0.5
	var xin: float = road_half + CP_DECK_IN
	if hw < xin + 1.0:
		return []
	var out: Array = [[-hw, -xin, -length, 0.0]]
	var core := _cp_core(length, width, road_half)
	if core.size.x <= 0.0:
		out.append([xin, hw, -length, 0.0])
	else:
		var cz1: float = core.position.y + core.size.y
		out.append([xin, hw, cz1 - 0.1, 0.0])
		out.append([xin, core.position.x + 0.1, -length, cz1 - 0.1])
	return out


## The slab props' positions in plan under the deck's cantilevered inner part (between its inner edge and the second column
## line), on both sides.
static func _cp_props(length: float, width: float, road_half: float) -> Array:
	var xs: Array = _cp_col_xs(width, road_half)
	var xin: float = road_half + CP_DECK_IN
	var hw: float = width * 0.5
	if hw < xin + 1.0:
		return []
	var x_end: float = (float(xs[1]) - CP_COL * 0.5 - 0.5) if xs.size() > 1 else hw - 0.6
	var rows: Array = []
	var x: float = xin + 0.45
	while x <= x_end:
		rows.append(x)
		x += 2.6
	var out: Array = []
	var n: int = maxi(1, int(floor((length - 1.0) / CP_PROP_DZ)))
	for sx in [-1.0, 1.0]:
		for rx in rows:
			for k in range(n + 1):
				var z: float = -0.5 - (length - 1.0) * float(k) / float(n)
				out.append(Vector3(sx * float(rx), 0.0, z))
	return out


## The multi-storey car park under construction that the route drives through along -z from z 0 to -`length` on x = 0:
## ground slabs either side of the road (top CP_SLAB_TOP 0.06, from |x| road_half + 0.6 out to width / 2: the road between
## is the level's), 0.5 x 0.5 concrete columns 3.2 high on a 8.0 x 7.5 grid with starter bars, the first deck (0.25 thick,
## top 3.45) poured only where |x| > road_half + 2.5, its inner edges with their formwork and guard rails over props and H20
## girders, guard rails round its other edges, rebar mats laid out and stacked on it, a formwork stack and block pallets,
## and in the +x side's far corner (toward -length) a stair core of blockwork two storeys high (CP_CORE_TOP 6.9) with its
## stairs and scaffolding on its two outer faces. Nothing at all stands within |x| < road_half + 0.6 at any height (the
## race camera rides 10m over the car). KRONBAU's banner on each inner rail, facing the road.
static func carpark_frame(pk: PropKit, kit: Dictionary, labels: Array, length: float, width: float, road_half: float) -> void:
	var hw: float = width * 0.5
	var xin: float = road_half + CP_DECK_IN
	var top: float = CP_COL_H + CP_DECK_T
	var xs: Array = _cp_col_xs(width, road_half)
	var zs: Array = _cp_col_zs(length)
	var core := _cp_core(length, width, road_half)
	var decks: Array = _cp_decks(length, width, road_half)
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "concrete", Vector3(sx * (road_half + CP_OPEN), -0.3, -length), Vector3(sx * hw, CP_SLAB_TOP, 0.0), CONC_FRESH)
	# Columns, their tops under the deck or free with starter bars.
	for sx in [-1.0, 1.0]:
		for x in xs:
			for z in zs:
				var p := Vector3(sx * float(x), 0.0, float(z))
				if sx > 0.0 and core.size.x > 0.0 and core.grow(0.6).has_point(Vector2(p.x, p.z)):
					continue
				var under: bool = absf(p.x) - CP_COL * 0.5 > xin - 0.01
				var ct: float = CP_COL_H + (0.02 if under else 0.0)
				_blk_nb(pk, kit, "concrete", p + Vector3(-0.25, CP_SLAB_TOP - 0.02, -0.25), p + Vector3(0.25, ct, 0.25), CONC)
				var by: float = top if under else CP_COL_H
				for cx in [-0.17, 0.17]:
					for cz in [-0.17, 0.17]:
						var bp: Vector3 = p + Vector3(cx, by - 0.05, cz)
						pk.beam(kit, "rusty", bp, bp + Vector3(0.0, 0.95, 0.0) + Vector3(cx, 0, cz) * 0.15, 0.025, 0.025, RUST)
	# The deck.
	for d in decks:
		_blk(pk, kit, "concrete", Vector3(d[0], CP_COL_H, d[2]), Vector3(d[1], top, d[3]), CONC.lightened(0.04))
	if decks.is_empty():
		return
	# Under the cantilevered inner part: H20 girders along z on props.
	var props: Array = _cp_props(length, width, road_half)
	var rows := {}
	for p in props:
		rows[snappedf((p as Vector3).x, 0.01)] = true
	for rx in rows.keys():
		var x: float = rx
		var z1: float = -length
		if x > 0.0 and core.size.x > 0.0 and x > core.position.x - 0.5:
			z1 = core.position.y + core.size.y + 0.4
		SW._ibeam(pk, kit, "bpaint", Vector3(x, CP_COL_H - 0.1, 0.0), Vector3(x, CP_COL_H - 0.1, z1), 0.21, 0.08, Color(0.95, 0.78, 0.15), UP, 0.03, 0.04)
	for p in props:
		_slab_prop(pk, kit, p)
	# The inner edges' formwork boards and brackets, and the guard rails round every edge.
	for sx in [-1.0, 1.0]:
		var ex: float = sx * xin - sx * 0.045
		_blk(pk, kit, "timber", Vector3(ex - 0.0125, CP_COL_H - 0.05, -length), Vector3(ex + 0.0125, top + 0.12, 0.0), TIMBER)
		var zb := -1.0
		while zb > -length + 0.5:
			_blk(pk, kit, "bpaint", Vector3(sx * xin - sx * 0.08, top + 0.12, zb - 0.03), Vector3(sx * xin + sx * 0.25, top + 0.16, zb + 0.03), Color(0.2, 0.35, 0.6))
			zb -= 2.4
		_cp_rail(pk, kit, Vector3(sx * (xin + 0.12), top, -0.15), Vector3(sx * (xin + 0.12), top, -length + 0.15), Vector3(-sx, 0, 0))
		_cp_rail(pk, kit, Vector3(sx * (hw - 0.12), top, -0.15), Vector3(sx * (hw - 0.12), top, -length + 0.15 if sx < 0.0 or core.size.x <= 0.0 else core.position.y + core.size.y), Vector3(sx, 0, 0))
		_cp_rail(pk, kit, Vector3(sx * (xin + 0.12), top, -0.12), Vector3(sx * (hw - 0.12), top, -0.12), Vector3.BACK)
		var far_x: float = hw - 0.12 if sx < 0.0 or core.size.x <= 0.0 else core.position.x - 0.1
		_cp_rail(pk, kit, Vector3(sx * (xin + 0.12), top, -length + 0.12), Vector3(sx * far_x, top, -length + 0.12), Vector3.FORWARD)
		# KRONBAU's banner on the inner rail, facing the road.
		var bz: float = -length * 0.5
		var bxf: float = sx * (xin + 0.12) - sx * 0.07
		_blk(pk, kit, "enamel", Vector3(bxf - 0.015, top + 0.2, bz - 3.0), Vector3(bxf + 0.015, top + 1.05, bz + 3.0), KB_BLUE)
		_blk(pk, kit, "enamel", Vector3(bxf - 0.02, top + 0.2, bz - 3.0), Vector3(bxf + 0.02, top + 0.32, bz + 3.0), KB_YELLOW)
		_lbl(labels, "KRONBAU", Vector3(bxf - sx * 0.04, top + 0.68, bz), Vector3(-sx, 0, 0), 0.42, Color(0.98, 0.98, 0.96), 5.6)
	if core.size.x > 0.0:
		var cz1: float = core.position.y + core.size.y
		_cp_rail(pk, kit, Vector3(core.position.x + CP_CORE, top, cz1 - 0.22), Vector3(hw - 0.12, top, cz1 - 0.22), Vector3.FORWARD)
	# Rebar mats laid out by the inner edges and stacked on bearers, a formwork stack and block pallets.
	for sx in [-1.0, 1.0]:
		var mx: float = sx * (xin + 1.85)
		var k := 0
		var mz := -3.0
		while mz - 6.0 > -length * 0.45 and k < 3:
			var p0 := Vector3(mx - 1.15, top + 0.05, mz)
			pk.quad(kit, "brebar", [p0, p0 + Vector3(2.3, 0, 0), p0 + Vector3(2.3, 0, -6.0), p0 + Vector3(0, 0, -6.0)], UP, Color(0.55, 0.3, 0.18),
					[Vector2(0, 0), Vector2(2.3, 0), Vector2(2.3, 6.0), Vector2(0, 6.0)])
			mz -= 6.6
			k += 1
		var sz: float = -length * 0.62
		var sxm: float = sx * (xin + 5.0)
		if absf(sxm) + 1.3 < hw:
			for bz in [-2.0, 2.0]:
				_blk(pk, kit, "timber", Vector3(sxm - 1.2, top, sz + bz - 0.06), Vector3(sxm + 1.2, top + 0.1, sz + bz + 0.06), TIMBER.darkened(0.2))
			for j in range(6):
				var y: float = top + 0.11 + 0.03 * float(j)
				var p1 := Vector3(sxm - 1.15, y, sz + 3.0)
				pk.quad(kit, "brebar", [p1, p1 + Vector3(2.3, 0, 0), p1 + Vector3(2.3, 0, -6.0), p1 + Vector3(0, 0, -6.0)], UP, Color(0.55, 0.3, 0.18),
						[Vector2(0.03 * float(j), 0), Vector2(2.3 + 0.03 * float(j), 0), Vector2(2.3 + 0.03 * float(j), 6.0), Vector2(0.03 * float(j), 6.0)])
	if hw - xin > 6.5:
		var saved := _push(pk, Transform3D(Basis(UP, PI * 0.5), Vector3(-(hw - 2.0), top, -length * 0.3)))
		formwork_stack(pk, kit)
		_pop(pk, saved)
		var saved2 := _push(pk, Transform3D(Basis(UP, PI * 0.5), Vector3(hw - 2.0, top, -length * 0.25)))
		brick_pallets(pk, kit, 3)
		_pop(pk, saved2)
	if core.size.x > 0.0:
		_cp_core_build(pk, kit, core)


## A slab prop (Deckenstütze) at `p` (on the ground slab) up to the H20 girder's underside: a base plate, the painted outer
## tube, the galvanised inner tube with its pin, the fork head.
static func _slab_prop(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	var y0: float = CP_SLAB_TOP
	var y1: float = CP_COL_H - 0.205
	_blk(pk, kit, "steel", p + Vector3(-0.075, y0, -0.075), p + Vector3(0.075, y0 + 0.02, 0.075), Color(0.6, 0.15, 0.08))
	_rod(pk, kit, "bpaint", p + Vector3(0, y0 + 0.02, 0), p + Vector3(0, 1.95, 0), 0.03, 6, Color(0.75, 0.2, 0.08), false)
	_rod(pk, kit, "metal", p + Vector3(0, 1.95, 0), p + Vector3(0, y1 - 0.08, 0), 0.023, 6, GALV, false)
	_blk(pk, kit, "steel", p + Vector3(-0.05, 1.95, -0.05), p + Vector3(0.05, 2.0, 0.05), Color(0.6, 0.15, 0.08))
	_blk(pk, kit, "steel", p + Vector3(-0.08, y1 - 0.08, -0.06), p + Vector3(0.08, y1, 0.06), Color(0.6, 0.15, 0.08))


## A guard rail (Seitenschutz) on the deck from a to b: posts every 2.4m or so and three boards (toe, knee, top) on the
## posts' side toward `out`.
static func _cp_rail(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, out: Vector3) -> void:
	var l: float = a.distance_to(b)
	if l < 0.5:
		return
	var n: int = maxi(1, int(ceil(l / 2.4)))
	for k in range(n + 1):
		var p: Vector3 = a.lerp(b, float(k) / float(n))
		_blk(pk, kit, "bpaint", p + Vector3(-0.025, 0.0, -0.025), p + Vector3(0.025, 1.1, 0.025), Color(0.75, 0.2, 0.08))
	for by in [0.08, 0.55, 1.02]:
		var o: Vector3 = out * 0.04 + UP * by
		pk.beam(kit, "timber", a + o, b + o, 0.15, 0.03, TIMBER.darkened(0.08), out)


## The stair core: blockwork walls 0.24 thick round `core` (x, z) from the ground slab to CP_CORE_TOP (the +x wall a course
## lower and racked back), doorways toward the drive at the ground and the deck, concrete lintels, the flights and landings
## inside, and scaffolding on its +x and -z faces.
static func _cp_core_build(pk: PropKit, kit: Dictionary, core: Rect2) -> void:
	var x0: float = core.position.x
	var x1: float = x0 + core.size.x
	var z0: float = core.position.y
	var z1: float = z0 + core.size.y
	var t := 0.24
	var y0 := CP_SLAB_TOP - 0.02
	var yt := CP_CORE_TOP
	var deck: float = CP_COL_H + CP_DECK_T
	var ks := Color(0.86, 0.85, 0.81)
	var uvs: float = uvk * 1.55
	var zm: float = (z0 + z1) * 0.5
	# The -x wall (toward the drive): doorways at the ground and at the deck.
	_mblock(pk, kit, "ashlar", Vector3(x0, y0, z0), Vector3(x0 + t, yt, zm - 0.55), ks, uvs)
	_mblock(pk, kit, "ashlar", Vector3(x0, y0, zm + 0.55), Vector3(x0 + t, yt, z1), ks, uvs)
	_blk(pk, kit, "concrete", Vector3(x0 - 0.01, 2.3, zm - 0.7), Vector3(x0 + t + 0.01, 2.5, zm + 0.7), CONC)
	_mblock(pk, kit, "ashlar", Vector3(x0, 2.5, zm - 0.55), Vector3(x0 + t, deck, zm + 0.55), ks, uvs)
	_blk(pk, kit, "concrete", Vector3(x0 - 0.01, deck + 2.25, zm - 0.7), Vector3(x0 + t + 0.01, deck + 2.45, zm + 0.7), CONC)
	_mblock(pk, kit, "ashlar", Vector3(x0, deck + 2.45, zm - 0.55), Vector3(x0 + t, yt, zm + 0.55), ks, uvs)
	# The +z wall, the -z wall, and the +x wall stepped down a course and racked back toward -z.
	_mblock(pk, kit, "ashlar", Vector3(x0 + t, y0, z1 - t), Vector3(x1, yt, z1), ks, uvs)
	_mblock(pk, kit, "ashlar", Vector3(x0 + t, y0, z0), Vector3(x1, yt - 0.5, z0 + t), ks, uvs)
	_mblock(pk, kit, "ashlar", Vector3(x1 - t, y0, z0 + t), Vector3(x1, yt - 1.0, z1 - t), ks, uvs)
	for k in range(3):
		var zk: float = z1 - t - (core.size.y - 2.0 * t) * (0.25 + 0.25 * float(k))
		_mblock(pk, kit, "ashlar", Vector3(x1 - t, yt - 1.0, zk), Vector3(x1, yt - 1.0 + 0.25 * float(3 - k), z1 - t), ks, uvs)
	# The flights and landings inside: up along +z on the -x half, back along -z on the +x half, twice.
	var ix0: float = x0 + t
	var ix1: float = x1 - t
	var iz0: float = z0 + t
	var iz1: float = z1 - t
	var land := 1.15
	var w: float = (ix1 - ix0) * 0.5 - 0.05
	for storey in range(2):
		var yb: float = y0 + 0.02 + deck * float(storey)
		var ym: float = yb + deck * 0.5
		_flight(pk, kit, Vector2(iz0 + land, yb), Vector2(iz1 - land, ym), ix0, ix0 + w)
		_blk(pk, kit, "concrete", Vector3(ix0, ym - 0.2, iz1 - land), Vector3(ix1, ym, iz1), CONC)
		_flight(pk, kit, Vector2(iz1 - land, ym), Vector2(iz0 + land, yb + deck), ix1 - w, ix1)
		_blk(pk, kit, "concrete", Vector3(ix0, yb + deck - 0.2, iz0), Vector3(ix1, yb + deck, iz0 + land), CONC)
	# Scaffolding on the +x face and on the -z face.
	var s1 := _push(pk, Transform3D(Basis(Vector3(0, 0, -1), UP, Vector3(1, 0, 0)), Vector3(x1, CP_SLAB_TOP, z1)))
	scaffold(pk, kit, z1 - z0, yt, 0.8)
	_pop(pk, s1)
	var s2 := _push(pk, Transform3D(Basis(Vector3(-1, 0, 0), UP, Vector3(0, 0, -1)), Vector3(x1, CP_SLAB_TOP, z0)))
	scaffold(pk, kit, x1 - x0, yt, 0.8)
	_pop(pk, s2)


## A flight of concrete stairs from `a` to `b` (Vector2(z, y): the foot's nosing line to the head's), across x from x0 to x1:
## risers of about 0.17, the soffit 0.25 under the nosings.
static func _flight(pk: PropKit, kit: Dictionary, a: Vector2, b: Vector2, x0: float, x1: float) -> void:
	var n: int = maxi(2, int(round((b.y - a.y) / 0.17)))
	var tread: float = (b.x - a.x) / float(n)
	var rise: float = (b.y - a.y) / float(n)
	var ol := PackedVector2Array()
	ol.append(Vector2(a.x, a.y - 0.25))
	ol.append(a)
	for k in range(n):
		ol.append(Vector2(a.x + tread * float(k), a.y + rise * float(k + 1)))
		ol.append(Vector2(a.x + tread * float(k + 1), a.y + rise * float(k + 1)))
	ol.append(Vector2(b.x, b.y - 0.25))
	_side_prism(pk, kit, "concrete", ol, x0, x1, CONC, 0.0, uvk)


static func carpark_frame_solids(length: float, width: float, road_half: float) -> Array:
	var s: Array = []
	var xin: float = road_half + CP_DECK_IN
	var top: float = CP_COL_H + CP_DECK_T
	var core := _cp_core(length, width, road_half)
	for sx in [-1.0, 1.0]:
		for x in _cp_col_xs(width, road_half):
			for z in _cp_col_zs(length):
				var p := Vector3(sx * float(x), 0.0, float(z))
				if sx > 0.0 and core.size.x > 0.0 and core.grow(0.6).has_point(Vector2(p.x, p.z)):
					continue
				_solid_blk(s, p + Vector3(-0.25, 0.0, -0.25), p + Vector3(0.25, CP_COL_H, 0.25))
	for d in _cp_decks(length, width, road_half):
		_solid_blk(s, Vector3(d[0], CP_COL_H, d[2]), Vector3(d[1], top, d[3]))
	for p in _cp_props(length, width, road_half):
		_solid_blk(s, (p as Vector3) + Vector3(-0.06, 0.0, -0.06), (p as Vector3) + Vector3(0.06, CP_COL_H, 0.06))
	if core.size.x > 0.0:
		_solid_blk(s, Vector3(core.position.x, 0.0, core.position.y), Vector3(core.position.x + core.size.x, CP_CORE_TOP, core.position.y + core.size.y))
		_solid_blk(s, Vector3(core.position.x + core.size.x, 0.0, core.position.y), Vector3(core.position.x + core.size.x + 1.15, CP_CORE_TOP + 1.0,
				core.position.y + core.size.y))
		_solid_blk(s, Vector3(core.position.x, 0.0, core.position.y - 1.15), Vector3(core.position.x + core.size.x, CP_CORE_TOP + 1.0, core.position.y))
	return s
