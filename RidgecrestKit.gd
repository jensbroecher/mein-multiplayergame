extends RefCounted
## Ridgecrest, the Bloombay district on Pinecrest Ridge's summit: upscale houses among the pines, a mix
## of traditional alpine buildings (chalets with stone or white-washed ground floors and timber upper
## floors under wide slate roofs, the Hotel Ridgecrest in an old farmhouse with its barn glazed over,
## the chapel on the peak) and modern ones (concrete and timber villas with walls of glass and a pool,
## a glass-gabled house under standing-seam zinc, the clubhouse pavilion on the lip over the course).
## Built in code at life size through a PropKit (front toward -z, y up, origin at the footprint's middle
## on the ground); regenerate_pinecrest_ridge.gd places each at PROP_SCALE on a graded pad.
##
## Every builder takes two kits: `kit` for what reads from across the valley (walls, roofs, windows) and
## `fine` for the small things (shutters, flower boxes, railings' boards, garden furniture, lamps), drawn
## nearer. It returns {"boxes": [[centre, size]...] (its solid parts in its own frame, for colliders),
## "labels": [[text, position, outward normal, letter height, colour (optional: painted on, lit)]...]
## (signs, which the generator letters with Label3Ds)}.
##
## Material keys (the generator's _material): "plaster" (hut_masonry.gdshader style 4, the vertex
## colour the wash), "stone" (0), "slate" (6), "zinc" (7), "concrete" (8), "timber", "lapboards",
## "battens", "painted" (hut_wood.gdshader 2, 1, 0, 3), "pane" (ridgecrest_glass.gdshader: COLOR the
## glass's tint, its alpha 1 less the curtain drawn across it), "glass" (see-through: balustrades),
## "hedge" (hedge.gdshader), "pool", and CampKit's "metal", "steel", "matte", "lamp". UVs are in metres,
## u along a wall (or the ridge) and v up it, which all of those shaders read.

const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")

const WHITE_WASH := Color(0.95, 0.93, 0.88)
const CREAM := Color(0.94, 0.89, 0.77)
const STONE := Color(0.74, 0.71, 0.66)
const LARCH := Color(0.66, 0.48, 0.30)
const DARK_WOOD := Color(0.42, 0.28, 0.17)
const HONEY := Color(0.58, 0.39, 0.22)
const CHARRED := Color(0.20, 0.19, 0.18)
const SLATE := Color(0.33, 0.34, 0.37)
const SHINGLE := Color(0.46, 0.38, 0.30)
const ZINC := Color(0.45, 0.47, 0.49)
const COPPER := Color(0.36, 0.58, 0.50)
const CONCRETE := Color(0.74, 0.73, 0.70)
const FRAME_DARK := Color(0.13, 0.13, 0.14)
const GLASS := Color(0.34, 0.42, 0.46)
const SHUTTERS := [Color(0.20, 0.40, 0.25), Color(0.55, 0.20, 0.14), Color(0.32, 0.37, 0.46), Color(0.47, 0.32, 0.19)]
const BLOOMS := [Color(0.88, 0.10, 0.12), Color(0.96, 0.32, 0.48), Color(0.98, 0.95, 0.95), Color(0.80, 0.14, 0.36)]
const LEAF := Color(0.18, 0.36, 0.14)

## The keys this kit's builders use and the hut shaders' styles behind them.
const MASONRY := {"stone": 0, "plaster": 4, "slate": 6, "zinc": 7, "concrete": 8}
const WOOD := {"battens": 0, "lapboards": 1, "timber": 2, "painted": 3}

var _kit: PropKit


func _init(kit: PropKit) -> void:
	_kit = kit


## Commits `kit` like PropKit.commit, with tangents on the surfaces whose shaders read a normal map
## (the slate, the zinc, the hedges).
func finish(kit: Dictionary) -> ArrayMesh:
	for key in ["slate", "zinc", "hedge"]:
		if kit.has(key):
			var st: SurfaceTool = kit[key]
			st.index()
			st.generate_tangents()
	return _kit.commit(kit)


## A fresh material for one of the kit's keys (the generator saves and shares them); CampKit's for the
## rest.
static func make_material(key: String) -> Material:
	if MASONRY.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://hut_masonry.gdshader")
		m.set_shader_parameter("style", MASONRY[key])
		return m
	if WOOD.has(key):
		var w := ShaderMaterial.new()
		w.shader = load("res://hut_wood.gdshader")
		w.set_shader_parameter("style", WOOD[key])
		w.set_shader_parameter("weathering", 0.35)
		return w
	match key:
		"pane":
			var g := ShaderMaterial.new()
			g.shader = load("res://ridgecrest_glass.gdshader")
			return g
		"hedge":
			var h := ShaderMaterial.new()
			h.shader = load("res://hedge.gdshader")
			return h
		"pool":
			var p := StandardMaterial3D.new()
			p.vertex_color_use_as_albedo = true
			p.vertex_color_is_srgb = true
			p.roughness = 0.04
			p.metallic = 0.15
			p.metallic_specular = 0.8
			return p
	return CampKit.make_material(key)


# ======================================================================================
#  Walls, roofs and openings
# ======================================================================================

## The outward normal of a wall from a to b. Walls go round clockwise seen from above: the front (-z)
## left to right, then back along the right side, the back right to left, the left side to the front.
static func _out(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(b.z - a.z, 0.0, -(b.x - a.x)).normalized()


## A wall from a to b (their y is ignored) between y0 and y1, UVs in metres: u along it from u0, v up.
func wall(kit: Dictionary, key: String, a: Vector3, b: Vector3, y0: float, y1: float, col: Color, u0 := 0.0) -> void:
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	_kit.quad(kit, key, [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)],
			_out(a, b), col, [Vector2(u0, y0), Vector2(u0 + l, y0), Vector2(u0 + l, y1), Vector2(u0, y1)])


## The four walls of a box over x0..x1, z0..z1 between y0 and y1 (no floor, no lid).
func walls(kit: Dictionary, key: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, col: Color) -> void:
	var c := [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]
	var u := 0.0
	for i in range(4):
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		wall(kit, key, a, b, y0, y1, col, u)
		u += a.distance_to(b)


## The triangle over a wall from a to b: its feet at y0, its apex over the middle at y1.
func gable(kit: Dictionary, key: String, a: Vector3, b: Vector3, y0: float, y1: float, col: Color) -> void:
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	var m := (a + b) * 0.5
	var n := _out(a, b)
	_kit.tri(kit, key, Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(m.x, y1, m.z), n, n, n, col, n,
			Vector2(0, y0), Vector2(l, y0), Vector2(l * 0.5, y1))


## A flat lid over x0..x1, z0..z1 at y (facing down with `down`), UVs in metres.
func lid(kit: Dictionary, key: String, x0: float, x1: float, z0: float, z1: float, y: float, col: Color, down := false) -> void:
	_kit.quad(kit, key, [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)],
			Vector3.DOWN if down else Vector3.UP, col, [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])


## A box between two corners with UVs in metres on every face.
func slab(kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	_kit.block(kit, key, lo, hi, col, 1.0)


## A pitched roof over x0..x1, z0..z1 whose walls stop at eave_y: the ridge along z (gables front and
## back) or, with ridge_x, along x. Slopes `t` thick at `pitch`, boarded underneath, the eaves
## `over_eave` past the side walls and the verges `over_gable` past the gables, a fascia round the edge
## and a cap along the ridge. Returns the ridge's height (under the slopes' thickness).
func roof(kit: Dictionary, key: String, x0: float, x1: float, z0: float, z1: float, eave_y: float, pitch: float,
		over_eave: float, over_gable: float, col: Color, under_col: Color, fascia_col: Color, ridge_x := false, t := 0.22) -> float:
	var base := _kit.xf
	var half_len: float
	var half_dep: float
	if ridge_x:
		half_len = (x1 - x0) * 0.5
		half_dep = (z1 - z0) * 0.5
		_kit.set_frame(base * Transform3D(Basis(), Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)))
	else:
		half_len = (z1 - z0) * 0.5
		half_dep = (x1 - x0) * 0.5
		_kit.set_frame(base * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)))
	# Here the ridge runs along x over z = 0 and the slopes fall to -z and +z.
	var tn := tan(pitch)
	var ridge_y := eave_y + half_dep * tn
	var ll := half_len + over_gable
	var dz := half_dep + over_eave
	var ye := eave_y - over_eave * tn
	var slope_len := dz / cos(pitch)
	for side in [-1.0, 1.0]:
		var n := Vector3(0.0, cos(pitch), side * sin(pitch))
		var lift := n * t
		var r0 := Vector3(-ll, ridge_y, 0.0)
		var r1 := Vector3(ll, ridge_y, 0.0)
		var e0 := Vector3(-ll, ye, side * dz)
		var e1 := Vector3(ll, ye, side * dz)
		var uv := [Vector2(-ll, 0.0), Vector2(ll, 0.0), Vector2(ll, slope_len), Vector2(-ll, slope_len)]
		_kit.quad(kit, key, [e0 + lift, e1 + lift, r1 + lift, r0 + lift], n, col, uv)
		_kit.quad(kit, "lapboards", [e0, e1, r1, r0], -n, under_col, uv)
		var down_slope := Vector3(0.0, -sin(pitch), side * cos(pitch))
		_kit.quad(kit, "painted", [e0, e1, e1 + lift, e0 + lift], down_slope, fascia_col)
		for g in [-1.0, 1.0]:
			var gx: float = g * ll
			var a := Vector3(gx, ye, side * dz)
			var b := Vector3(gx, ridge_y, 0.0)
			_kit.quad(kit, "painted", [a, b, b + lift, a + lift], Vector3(g, 0.0, 0.0), fascia_col)
	_kit.beam(kit, key, Vector3(-ll, ridge_y + t * cos(pitch), 0.0), Vector3(ll, ridge_y + t * cos(pitch), 0.0), 0.3, 0.12, col.darkened(0.2))
	_kit.set_frame(base)
	return ridge_y


## A flat roof over x0..x1, z0..z1: its top at y, a fascia band `band` deep round the edge, the
## soffit under any overhang. `key` is the top's.
func flat_roof(kit: Dictionary, key: String, x0: float, x1: float, z0: float, z1: float, y: float, band: float,
		col: Color, fascia_key: String, fascia_col: Color) -> void:
	lid(kit, key, x0, x1, z0, z1, y, col)
	lid(kit, fascia_key, x0, x1, z0, z1, y - band, fascia_col, true)
	walls(kit, fascia_key, x0, x1, z0, z1, y - band, y + 0.06, fascia_col)


## A quad in a wall's plane: centre c, `along` and up its axes, w by h, facing n, UVs in metres (or,
## with `turn`, u up and v along, for boards that run across).
func _plate(kit: Dictionary, key: String, c: Vector3, along: Vector3, n: Vector3, w: float, h: float, col: Color, turn := false) -> void:
	var a := along * (w * 0.5)
	var u := Vector3.UP * (h * 0.5)
	var uv := [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	if turn:
		uv = [Vector2(0, 0), Vector2(0, w), Vector2(h, w), Vector2(h, 0)]
	_kit.quad(kit, key, [c - a - u, c + a - u, c + a + u, c - a + u], n, col, uv)


## A window in a wall: `c` the middle of the opening on the wall's face, `along` the wall, `n` out of it.
## The walls are solid, so the glass lies just proud of the face inside a casing that stands `depth`
## out (in the wall's own finish: a stone or plaster surround, or boards), whose inner faces are the
## reveals. A frame of `frame` paint splits it into `lights` across (a transom too when tall), a sill
## juts under it; with a `shutter` colour (alpha 0: none) a pair of louvred shutters is folded back
## beside it, and `flowers` puts a box of geraniums on the sill. Shutters and flowers go to `fine`.
func window(kit: Dictionary, fine: Dictionary, c: Vector3, along: Vector3, n: Vector3, w: float, h: float,
		frame: Color, rng: RandomNumberGenerator, lights := 2, shutter := Color(0, 0, 0, 0), depth := 0.14,
		wall_key := "plaster", wall_col := WHITE_WASH, flowers := false) -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	var up := Vector3.UP
	var curtain: float = 1.0 - (rng.randf_range(0.25, 0.6) if rng.randf() < 0.35 else 0.0)
	_plate(kit, "pane", c + n * 0.015, along, n, w, h, Color(GLASS.r, GLASS.g, GLASS.b, curtain))
	casing(kit, c, along, n, w, h, depth, 0.13, wall_key, wall_col.lightened(0.04))
	# Frame and glazing bars on the glass.
	var f := c + n * 0.045
	var ft := 0.07
	_kit.beam(kit, "painted", f - along * hw - up * hh, f + along * hw - up * hh, ft, 0.05, frame, n)
	_kit.beam(kit, "painted", f - along * hw + up * hh, f + along * hw + up * hh, ft, 0.05, frame, n)
	_kit.beam(kit, "painted", f - along * hw - up * hh, f - along * hw + up * hh, ft, 0.05, frame, n)
	_kit.beam(kit, "painted", f + along * hw - up * hh, f + along * hw + up * hh, ft, 0.05, frame, n)
	for i in range(1, lights):
		var x := -hw + w * float(i) / float(lights)
		_kit.beam(kit, "painted", f + along * x - up * hh, f + along * x + up * hh, 0.035, 0.035, frame, n)
	if h > 1.25:
		var ty := hh - h * 0.3
		_kit.beam(kit, "painted", f - along * hw + up * ty, f + along * hw + up * ty, 0.035, 0.035, frame, n)
	# The sill, out past the casing.
	var timber := wall_key == "battens" or wall_key == "lapboards"
	var sill_c := c - up * (hh + 0.165) + n * (depth * 0.5 + 0.04)
	_kit.box(kit, "timber" if timber else "stone", Transform3D(Basis(along, up, n), sill_c), Vector3(w + 0.42, 0.07, depth + 0.1),
			DARK_WOOD if timber else STONE, 1.0)
	if shutter.a > 0.0:
		for s in [-1.0, 1.0]:
			var sc: Vector3 = c + along * (s * (hw + 0.13 + w * 0.26 + 0.03)) + n * 0.035
			_plate(fine, "painted", sc, along, n, w * 0.52, h + 0.1, shutter, true)
			_plate(fine, "painted", sc - n * 0.03, along, -n, w * 0.52, h + 0.1, shutter.darkened(0.2), true)
	if flowers:
		flower_box(fine, c - up * (hh + 0.12) + n * (depth + 0.12), along, n, w + 0.1, rng)


## The casing round an opening w by h (its middle `c` on the wall's face): a border `cw` wide standing
## `depth` out of the wall, its inner faces the opening's reveals.
func casing(kit: Dictionary, c: Vector3, along: Vector3, n: Vector3, w: float, h: float, depth: float, cw: float,
		key: String, col: Color, bottom := true) -> void:
	var up := Vector3.UP
	var b := Basis(along, up, n)
	var mid := c + n * (depth * 0.5)
	_kit.box(kit, key, Transform3D(b, mid + up * (h * 0.5 + cw * 0.5)), Vector3(w + cw * 2.0, cw, depth), col, 1.0)
	if bottom:
		_kit.box(kit, key, Transform3D(b, mid - up * (h * 0.5 + cw * 0.5)), Vector3(w + cw * 2.0, cw, depth), col, 1.0)
	for s in [-1.0, 1.0]:
		_kit.box(kit, key, Transform3D(b, mid + along * (s * (w * 0.5 + cw * 0.5))), Vector3(cw, h, depth), col, 1.0)


## A door: `c` the middle of its foot on the wall's face. A leaf of boards (or glazed, `glazed`) just
## proud of the wall in a casing standing out round it, a frame, and a stone step.
func door(kit: Dictionary, c: Vector3, along: Vector3, n: Vector3, w: float, h: float, col: Color, frame: Color,
		glazed := false, wall_key := "plaster", wall_col := WHITE_WASH) -> void:
	var up := Vector3.UP
	var mid := c + up * (h * 0.5)
	if glazed:
		_plate(kit, "pane", mid + n * 0.015, along, n, w, h, Color(GLASS.r, GLASS.g, GLASS.b, 1.0))
	else:
		_plate(kit, "battens", mid + n * 0.015, along, n, w, h, col)
	casing(kit, mid, along, n, w, h, 0.18, 0.15, wall_key, wall_col.lightened(0.04), false)
	var f := c + n * 0.05
	_kit.beam(kit, "painted", f - along * (w * 0.5), f - along * (w * 0.5) + up * h, 0.08, 0.06, frame, n)
	_kit.beam(kit, "painted", f + along * (w * 0.5), f + along * (w * 0.5) + up * h, 0.08, 0.06, frame, n)
	_kit.beam(kit, "painted", f - along * (w * 0.5) + up * h, f + along * (w * 0.5) + up * h, 0.08, 0.06, frame, n)
	_kit.box(kit, "stone", Transform3D(Basis(along, up, n), c + n * 0.3 + up * 0.08), Vector3(w + 0.6, 0.16, 0.6), STONE, 1.0)


## A wall of glass from a to b between y0 and y1: panes with slim dark mullions every `bay` and a
## frame round it, the modern houses' way. In an opening it stands just behind the line; `proud` lays
## it over a wall instead (a window band on a solid wall).
func glazing(kit: Dictionary, a: Vector3, b: Vector3, y0: float, y1: float, bay := 1.4, frame := FRAME_DARK, proud := false) -> void:
	var n := _out(a, b)
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var l := along.length()
	along /= l
	var h := y1 - y0
	var mid := Vector3((a.x + b.x) * 0.5, (y0 + y1) * 0.5, (a.z + b.z) * 0.5)
	if proud:
		mid += n * 0.05
	_plate(kit, "pane", mid - n * 0.02, along, n, l, h, Color(GLASS.r * 0.85, GLASS.g * 0.9, GLASS.b, 1.0))
	var bays := maxi(1, int(round(l / bay)))
	for i in range(bays + 1):
		var x := -l * 0.5 + l * float(i) / float(bays)
		var p := mid + along * x
		_kit.beam(kit, "metal", Vector3(p.x, y0, p.z), Vector3(p.x, y1, p.z), 0.06, 0.1, frame, n)
	for y in [y0 + 0.03, y1 - 0.03]:
		_kit.beam(kit, "metal", Vector3(a.x, y, a.z), Vector3(b.x, y, b.z), 0.08, 0.1, frame, n)


## A timber balcony along a wall from a to b (left to right seen from outside) with its floor at y,
## `depth` out: boards on brackets, posts, a top rail and a balustrade of cut boards (fine), geraniums
## along the rail.
func balcony(kit: Dictionary, fine: Dictionary, a: Vector3, b: Vector3, y: float, depth: float, wood: Color,
		rng: RandomNumberGenerator, flowers := true) -> void:
	var n := _out(a, b)
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	var p0 := Vector3(a.x, y, a.z)
	var p1 := Vector3(b.x, y, b.z)
	var o0 := p0 + n * depth
	var o1 := p1 + n * depth
	var th := 0.16
	_kit.quad(kit, "lapboards", [p0, p1, o1, o0], Vector3.UP, wood, [Vector2(0, 0), Vector2(l, 0), Vector2(l, depth), Vector2(0, depth)])
	_kit.quad(kit, "lapboards", [p0 - Vector3(0, th, 0), p1 - Vector3(0, th, 0), o1 - Vector3(0, th, 0), o0 - Vector3(0, th, 0)], Vector3.DOWN, wood.darkened(0.25))
	_kit.quad(kit, "timber", [o0 - Vector3(0, th, 0), o1 - Vector3(0, th, 0), o1, o0], n, wood.darkened(0.1),
			[Vector2(0, 0), Vector2(0, l), Vector2(th, l), Vector2(th, 0)])
	for e in [[p0, o0, -along], [p1, o1, along]]:
		var q0: Vector3 = e[0]
		var q1: Vector3 = e[1]
		_kit.quad(kit, "timber", [q0 - Vector3(0, th, 0), q1 - Vector3(0, th, 0), q1, q0], e[2], wood.darkened(0.1))
	# Brackets under it, posts and rails.
	var nb := maxi(2, int(l / 2.2) + 1)
	for i in range(nb):
		var t := float(i) / float(nb - 1)
		var w0 := p0.lerp(p1, t) + along * (0.15 - 0.3 * t)
		_kit.beam(kit, "timber", w0 - Vector3(0, 1.0, 0) + n * 0.05, w0 + n * (depth * 0.85) - Vector3(0, th, 0), 0.12, 0.12, wood.darkened(0.2))
	var rail_h := 1.0
	var corners := [p0, o0, o1, p1]
	var np := maxi(2, int(l / 1.6) + 1)
	for i in range(np):
		var q := o0.lerp(o1, float(i) / float(np - 1))
		_kit.beam(kit, "timber", q + along * 0.0, q + Vector3(0, rail_h, 0), 0.11, 0.11, wood.darkened(0.15), along)
	for k in range(3):
		var r0: Vector3 = corners[k] + Vector3(0, rail_h, 0)
		var r1: Vector3 = corners[k + 1] + Vector3(0, rail_h, 0)
		_kit.beam(kit, "timber", r0, r1, 0.14, 0.07, wood.darkened(0.1), Vector3.UP)
		_kit.beam(fine, "timber", r0 - Vector3(0, rail_h - 0.12, 0), r1 - Vector3(0, rail_h - 0.12, 0), 0.08, 0.06, wood.darkened(0.1), Vector3.UP)
		# Cut boards between the rails, a gap between each.
		var seg := r1 - r0
		var sl := seg.length()
		var sd := seg / sl
		var sn: Vector3 = sd.cross(Vector3.UP).normalized()
		if sn.dot(((r0 + r1) * 0.5 - (p0 + p1) * 0.5)) < 0.0:
			sn = -sn
		var nboards := int(sl / 0.17)
		for j in range(nboards):
			var bc := r0 + sd * (0.17 * (j + 0.5)) - Vector3(0, rail_h * 0.5 - 0.04, 0)
			var bw := 0.12
			var bh := rail_h - 0.2
			# A waist cut into each board: two plates either side of a narrower middle.
			_kit.panel(fine, "battens", [bc - sd * (bw * 0.5) - Vector3(0, bh * 0.5, 0), bc + sd * (bw * 0.5) - Vector3(0, bh * 0.5, 0),
					bc + sd * (bw * 0.36) + Vector3(0, 0.0, 0), bc - sd * (bw * 0.36) + Vector3(0, 0.0, 0)], sn, wood, wood.darkened(0.2))
			_kit.panel(fine, "battens", [bc - sd * (bw * 0.36), bc + sd * (bw * 0.36), bc + sd * (bw * 0.5) + Vector3(0, bh * 0.5, 0),
					bc - sd * (bw * 0.5) + Vector3(0, bh * 0.5, 0)], sn, wood, wood.darkened(0.2))
		if flowers and k == 1:
			flower_box(fine, (r0 + r1) * 0.5 + sn * 0.16 - Vector3(0, 0.12, 0), sd, sn, sl - 0.3, rng)


## A flower box hanging off a sill or a rail: `c` the middle of its top, along `along`, its front `n`.
## Geraniums in clumps above it and trailing over its front.
func flower_box(fine: Dictionary, c: Vector3, along: Vector3, n: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var up := Vector3.UP
	_kit.box(fine, "painted", Transform3D(Basis(along, up, n), c - up * 0.1), Vector3(length, 0.2, 0.2), DARK_WOOD, 1.0)
	var bloom: Color = BLOOMS[rng.randi() % BLOOMS.size()]
	var clumps := int(length / 0.22)
	for i in range(clumps):
		var p := c + along * (-length * 0.5 + 0.11 + 0.22 * i) + n * rng.randf_range(-0.05, 0.05)
		_kit.box(fine, "matte", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + up * 0.06), Vector3(0.2, 0.12, 0.2), LEAF, 0.0)
		for k in range(3):
			var fp := p + Vector3(rng.randf_range(-0.09, 0.09), rng.randf_range(0.12, 0.26), rng.randf_range(-0.09, 0.09))
			_kit.box(fine, "matte", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), fp), Vector3.ONE * rng.randf_range(0.07, 0.1), bloom.lightened(rng.randf() * 0.15), 0.0)
		# Trailing leaves down the front.
		if rng.randf() < 0.6:
			var tp := p + n * 0.11
			_kit.quad(fine, "matte", [tp - along * 0.08, tp + along * 0.08, tp + along * 0.05 - up * rng.randf_range(0.2, 0.4), tp - along * 0.05 - up * 0.3], n, LEAF.darkened(0.1))


## A stone chimney through the roof from y0 to y1 at (x, z), w across.
func chimney(kit: Dictionary, x: float, z: float, y0: float, y1: float, w: float) -> void:
	slab(kit, "stone", Vector3(x - w * 0.5, y0, z - w * 0.5), Vector3(x + w * 0.5, y1, z + w * 0.5), STONE.darkened(0.08))
	slab(kit, "stone", Vector3(x - w * 0.5 - 0.08, y1, z - w * 0.5 - 0.08), Vector3(x + w * 0.5 + 0.08, y1 + 0.1, z + w * 0.5 + 0.08), STONE.darkened(0.2))
	for s in [-1.0, 1.0]:
		slab(kit, "stone", Vector3(x + s * w * 0.3 - 0.08, y1 + 0.1, z - 0.08), Vector3(x + s * w * 0.3 + 0.08, y1 + 0.35, z + 0.08), STONE.darkened(0.15))
	slab(kit, "stone", Vector3(x - w * 0.5 - 0.04, y1 + 0.35, z - w * 0.5 - 0.04), Vector3(x + w * 0.5 + 0.04, y1 + 0.42, z + w * 0.5 + 0.04), STONE.darkened(0.25))


## A see-through balustrade from a to b (feet at y): glass panels on posts under a slim rail.
func glass_rail(kit: Dictionary, a: Vector3, b: Vector3, h := 1.05) -> void:
	var n := _out(a, b)
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var l := along.length()
	along /= l
	_kit.panel(kit, "glass", [a + Vector3(0, 0.05, 0), b + Vector3(0, 0.05, 0), b + Vector3(0, h - 0.05, 0), a + Vector3(0, h - 0.05, 0)], n,
			Color(0.75, 0.85, 0.88, 0.22), Color(0.75, 0.85, 0.88, 0.22))
	_kit.beam(kit, "metal", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.06, 0.05, FRAME_DARK, n)
	var np := maxi(2, int(l / 1.5) + 1)
	for i in range(np):
		var p := a.lerp(b, float(i) / float(np - 1))
		_kit.beam(kit, "metal", p, p + Vector3(0, h, 0), 0.05, 0.05, FRAME_DARK, along)


# ======================================================================================
#  Traditional: chalets, the hotel, the chapel
# ======================================================================================

## An alpine chalet: a stone or white-washed ground floor on a stone plinth, a timber upper floor, the
## gable to the front under a wide slate or shingle roof, a balcony across the gable with geraniums,
## shuttered windows, a stone chimney, and on some a garage wing with a lean-to roof.
func chalet(kit: Dictionary, fine: Dictionary, rng: RandomNumberGenerator, variant: int) -> Dictionary:
	var w := 10.0 + float(variant % 3)
	var d := 8.0 + 1.5 * float((variant / 3) % 2)
	var hx := w * 0.5
	var hz := d * 0.5
	var stone_ground := variant % 2 == 0
	var wood: Color = [LARCH, DARK_WOOD, HONEY][variant % 3]
	var roof_col: Color = SLATE if variant % 2 == 0 else SHINGLE
	var shutter: Color = SHUTTERS[variant % SHUTTERS.size()]
	var gkey := "stone" if stone_ground else "plaster"
	var gcol := STONE if stone_ground else WHITE_WASH
	var g1 := 3.0
	var e := 5.7
	slab(kit, "stone", Vector3(-hx - 0.15, -1.4, -hz - 0.15), Vector3(hx + 0.15, 0.35, hz + 0.15), STONE.darkened(0.1))
	walls(kit, gkey, -hx, hx, -hz, hz, 0.35, g1, gcol)
	walls(kit, "timber", -hx - 0.07, hx + 0.07, -hz - 0.07, hz + 0.07, g1 - 0.08, g1 + 0.16, wood.darkened(0.25))
	walls(kit, "battens", -hx, hx, -hz, hz, g1 + 0.16, e, wood)
	var ridge := roof(kit, "slate", -hx, hx, -hz, hz, e, deg_to_rad(25.0), 1.3, 1.8, roof_col, wood.lightened(0.15), wood.darkened(0.4))
	gable(kit, "battens", Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), e, ridge, wood)
	gable(kit, "battens", Vector3(hx, 0, hz), Vector3(-hx, 0, hz), e, ridge, wood)
	chimney(kit, hx * 0.45, hz * 0.35, e - 0.5, ridge + 1.1, 0.75)
	var fr := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	# Front: the door between two windows below, a glazed door onto the balcony between two above,
	# a small window high in the gable.
	door(kit, Vector3(0.0, 0.35, -hz), right, fr, 1.05, 2.15, DARK_WOOD.darkened(0.1), wood.darkened(0.3), false, gkey, gcol)
	for s in [-1.0, 1.0]:
		window(kit, fine, Vector3(s * hx * 0.56, 1.75, -hz), right, fr, 1.1, 1.3, WHITE_WASH, rng, 2, shutter, 0.16, gkey, gcol, true)
		window(kit, fine, Vector3(s * hx * 0.56, g1 + 1.5, -hz), right, fr, 1.0, 1.25, wood.darkened(0.3), rng, 2, shutter, 0.1, "battens", wood)
	door(kit, Vector3(0.0, g1 + 0.16, -hz), right, fr, 1.1, 2.15, wood, wood.darkened(0.3), true, "battens", wood)
	window(kit, fine, Vector3(0.0, e + (ridge - e) * 0.42, -hz), right, fr, 0.75, 0.8, wood.darkened(0.3), rng, 1, Color(0, 0, 0, 0), 0.08, "battens", wood)
	balcony(kit, fine, Vector3(-hx - 0.6, 0, -hz), Vector3(hx + 0.6, 0, -hz), g1 + 0.16, 1.7, wood, rng)
	# Sides and back.
	for s in [-1.0, 1.0]:
		var sn := Vector3(s, 0, 0)
		var sa := Vector3(0, 0, s)
		for zz in [-hz * 0.45, hz * 0.45]:
			window(kit, fine, Vector3(s * hx, 1.75, zz), sa, sn, 1.0, 1.25, WHITE_WASH, rng, 2, shutter, 0.16, gkey, gcol, rng.randf() < 0.5)
			window(kit, fine, Vector3(s * hx, g1 + 1.5, zz), sa, sn, 1.0, 1.2, wood.darkened(0.3), rng, 2, shutter, 0.1, "battens", wood)
	for xx in [-hx * 0.5, hx * 0.5]:
		window(kit, fine, Vector3(xx, 1.75, hz), Vector3(-1, 0, 0), Vector3(0, 0, 1), 1.0, 1.2, WHITE_WASH, rng, 2, shutter, 0.16, gkey, gcol)
		window(kit, fine, Vector3(xx, g1 + 1.5, hz), Vector3(-1, 0, 0), Vector3(0, 0, 1), 1.0, 1.2, wood.darkened(0.3), rng, 2, Color(0, 0, 0, 0), 0.1, "battens", wood)
	var boxes: Array = [[Vector3(0, ridge * 0.5, 0), Vector3(w, ridge, d)]]
	if variant % 3 == 2:
		# A garage wing on the right under a lean-to roof.
		var x0 := hx
		var x1 := hx + 4.2
		var z0 := -hz + 0.6
		var z1 := hz - 0.6
		slab(kit, "stone", Vector3(x0, -1.4, z0 - 0.1), Vector3(x1 + 0.1, 0.25, z1 + 0.1), STONE.darkened(0.1))
		walls(kit, gkey, x0, x1, z0, z1, 0.25, 2.7, gcol)
		# The lean-to falls 0.75m from the house's wall to past the wing's outer wall.
		var rn := Vector3(0.75, x1 + 0.8 - x0, 0.0).normalized()
		_kit.quad(kit, "slate", [Vector3(x0, 3.25, z0 - 0.6), Vector3(x0, 3.25, z1 + 0.6), Vector3(x1 + 0.8, 2.5, z1 + 0.6), Vector3(x1 + 0.8, 2.5, z0 - 0.6)], rn, roof_col,
				[Vector2(z0 - 0.6, 4.9), Vector2(z1 + 0.6, 4.9), Vector2(z1 + 0.6, 0.0), Vector2(z0 - 0.6, 0.0)])
		_kit.quad(kit, "lapboards", [Vector3(x0, 3.1, z0 - 0.6), Vector3(x0, 3.1, z1 + 0.6), Vector3(x1 + 0.8, 2.35, z1 + 0.6), Vector3(x1 + 0.8, 2.35, z0 - 0.6)], -rn, wood)
		for zz2 in [z0, z1]:
			var sgn: float = -1.0 if zz2 == z0 else 1.0
			_kit.tri(kit, gkey, Vector3(x0, 2.7, zz2), Vector3(x1, 2.7, zz2), Vector3(x0, 3.2, zz2), Vector3(0, 0, sgn), Vector3(0, 0, sgn), Vector3(0, 0, sgn), gcol, Vector3(0, 0, sgn))
		_plate(kit, "battens", Vector3(x1, 1.3, 0.0), Vector3(0, 0, 1), Vector3(1, 0, 0), (z1 - z0) - 1.2, 2.1, wood.darkened(0.15))
		boxes.append([Vector3((x0 + x1) * 0.5, 1.5, 0.0), Vector3(x1 - x0, 3.0, z1 - z0)])
	return {"boxes": boxes, "labels": []}


## The Hotel Ridgecrest: an old farmhouse, three floors of white-washed stone under a slate roof whose
## ridge runs along the front, painted surrounds and green shutters, a balcony over the arched door;
## its barn beside it glazed behind a timber screen (the restaurant), a flagged terrace in front with
## tables and parasols.
func hotel(kit: Dictionary, fine: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var x0 := -9.0
	var x1 := 7.0
	var z0 := -5.5
	var z1 := 5.5
	var g1 := 3.2
	var e := 8.8
	var shutter: Color = SHUTTERS[0]
	var fr := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	slab(kit, "stone", Vector3(x0 - 0.2, -1.6, z0 - 0.2), Vector3(x1 + 0.2, 0.3, z1 + 0.2), STONE.darkened(0.1))
	walls(kit, "stone", x0, x1, z0, z1, 0.3, g1, STONE)
	walls(kit, "plaster", x0, x1, z0, z1, g1, e, CREAM)
	walls(kit, "stone", x0 - 0.05, x1 + 0.05, z0 - 0.05, z1 + 0.05, g1 - 0.05, g1 + 0.12, STONE.darkened(0.12))
	var ridge := roof(kit, "slate", x0, x1, z0, z1, e, deg_to_rad(32.0), 1.2, 1.0, SLATE, CREAM.darkened(0.2), DARK_WOOD, true)
	gable(kit, "plaster", Vector3(x0, 0, z1), Vector3(x0, 0, z0), e, ridge, CREAM)
	gable(kit, "plaster", Vector3(x1, 0, z0), Vector3(x1, 0, z1), e, ridge, CREAM)
	chimney(kit, x0 + 3.0, 1.2, e, ridge + 0.9, 0.85)
	chimney(kit, x1 - 4.0, -1.0, e, ridge + 0.6, 0.85)
	var xs := [-7.2, -4.4, 1.6, 4.6]
	for x in xs:
		window(kit, fine, Vector3(x, 1.8, z0), right, fr, 1.0, 1.25, FRAME_DARK.lightened(0.3), rng, 2, Color(0, 0, 0, 0), 0.32, "stone", STONE, true)
	door(kit, Vector3(-1.4, 0.3, z0), right, fr, 1.6, 2.5, DARK_WOOD, STONE, false, "stone", STONE)
	for fl in [g1 + 1.5, g1 + 4.2]:
		for x in [-7.2, -4.4, -1.4, 1.6, 4.6]:
			var c := Vector3(x, fl, z0)
			window(kit, fine, c, right, fr, 1.05, 1.35, WHITE_WASH, rng, 2, shutter, 0.18, "plaster", CREAM, fl < g1 + 2.0 or absf(x + 1.4) > 0.1)
			# Painted surrounds, grey bands round each opening (the sgraffito frames of the old houses).
			_plate(kit, "plaster", c + fr * 0.012 + Vector3(0, 0.82, 0), right, fr, 1.6, 0.18, Color(0.62, 0.66, 0.70))
			_plate(kit, "plaster", c + fr * 0.012 - Vector3(0, 0.82, 0), right, fr, 1.4, 0.12, Color(0.62, 0.66, 0.70))
	balcony(kit, fine, Vector3(-3.4, 0, z0), Vector3(0.6, 0, z0), g1 + 2.95, 1.3, DARK_WOOD, rng)
	for s in [-1.0, 1.0]:
		var sx: float = x0 if s < 0.0 else x1
		var sn := Vector3(s, 0, 0)
		var sa := Vector3(0, 0, s)
		for zz in [-2.4, 2.4]:
			for fl in [1.8, g1 + 1.5, g1 + 4.2]:
				window(kit, fine, Vector3(sx, fl, zz), sa, sn, 1.0, 1.25, WHITE_WASH, rng, 2, shutter if fl > 2.0 else Color(0, 0, 0, 0), 0.24, "plaster" if fl > 2.0 else "stone", CREAM if fl > 2.0 else STONE)
		window(kit, fine, Vector3(sx, e + (ridge - e) * 0.35, 0.0), sa, sn, 0.9, 0.9, WHITE_WASH, rng, 2, shutter, 0.2, "plaster", CREAM)
	for x in xs:
		for fl in [1.8, g1 + 1.5, g1 + 4.2]:
			window(kit, fine, Vector3(x, fl, z1), Vector3(-1, 0, 0), Vector3(0, 0, 1), 1.0, 1.25, WHITE_WASH, rng, 2, Color(0, 0, 0, 0), 0.24, "plaster" if fl > 2.0 else "stone", CREAM if fl > 2.0 else STONE)
	# The barn, its front glazed behind a screen of boards.
	var bx0 := x1
	var bx1 := x1 + 9.0
	var bz0 := -5.0
	var bz1 := 5.0
	var be := 6.4
	slab(kit, "stone", Vector3(bx0, -1.6, bz0 - 0.2), Vector3(bx1 + 0.2, 0.3, bz1 + 0.2), STONE.darkened(0.1))
	walls(kit, "stone", bx0, bx1, bz0, bz1, 0.3, 3.0, STONE)
	walls(kit, "battens", bx0, bx1, bz0, bz1, 3.0, be, DARK_WOOD)
	var bridge := roof(kit, "slate", bx0 - 0.4, bx1, bz0, bz1, be, deg_to_rad(32.0), 1.1, 0.9, SLATE.darkened(0.06), DARK_WOOD, DARK_WOOD.darkened(0.3), true)
	gable(kit, "battens", Vector3(bx1, 0, bz0), Vector3(bx1, 0, bz1), be, bridge, DARK_WOOD)
	glazing(kit, Vector3(bx0 + 1.2, 0, bz0), Vector3(bx1 - 1.2, 0, bz0), 0.3, be - 0.3, 1.1, FRAME_DARK, true)
	for i in range(14):
		var sx2 := bx0 + 1.5 + i * 0.47
		_kit.beam(kit, "timber", Vector3(sx2, 3.1, bz0 - 0.25), Vector3(sx2, be - 0.2, bz0 - 0.25), 0.09, 0.14, HONEY, Vector3(1, 0, 0))
	_kit.beam(kit, "timber", Vector3(bx0 + 1.2, 3.05, bz0 - 0.25), Vector3(bx1 - 1.2, 3.05, bz0 - 0.25), 0.16, 0.2, HONEY.darkened(0.2), Vector3(1, 0, 0))
	# The terrace: flags, three tables under parasols, chairs.
	lid(kit, "stone", x0 - 0.5, bx1 + 0.5, z0 - 6.5, z0 - 0.2, 0.32, STONE.lightened(0.05))
	walls(kit, "stone", x0 - 0.5, bx1 + 0.5, z0 - 6.5, z0 - 0.2, -1.2, 0.32, STONE.darkened(0.1))
	for t in [Vector3(-6.0, 0.32, -9.0), Vector3(-1.0, 0.32, -9.5), Vector3(4.0, 0.32, -9.0), Vector3(10.5, 0.32, -9.2)]:
		table_set(fine, t, rng.randf() * TAU, rng)
		parasol(fine, t, Color(0.94, 0.92, 0.86), 1.4)
	var boxes: Array = [[Vector3((x0 + x1) * 0.5, ridge * 0.5, 0.0), Vector3(x1 - x0, ridge, z1 - z0)],
			[Vector3((bx0 + bx1) * 0.5, bridge * 0.5, 0.0), Vector3(bx1 - bx0, bridge, bz1 - bz0)]]
	return {"boxes": boxes, "labels": [["HOTEL RIDGECREST", Vector3(-1.4, 3.62, z0 - 0.02), fr, 0.42, Color(0.16, 0.30, 0.20)]]}


## The chapel on the peak: a white nave on a stone plinth under a steep slate roof, round-arched windows,
## a bell tower at the front with stone quoins, clocks, open arches for the bells and a copper spire.
func chapel(kit: Dictionary, fine: Dictionary, _rng: RandomNumberGenerator) -> Dictionary:
	var hx := 3.6
	var z0 := -5.0
	var z1 := 7.0
	var e := 6.0
	slab(kit, "stone", Vector3(-hx - 0.25, -1.6, z0 - 0.25), Vector3(hx + 0.25, 0.55, z1 + 0.25), STONE.darkened(0.1))
	walls(kit, "plaster", -hx, hx, z0, z1, 0.55, e, WHITE_WASH)
	var ridge := roof(kit, "slate", -hx, hx, z0, z1, e, deg_to_rad(48.0), 0.5, 0.45, SLATE.darkened(0.1), WHITE_WASH.darkened(0.3), FRAME_DARK)
	gable(kit, "plaster", Vector3(hx, 0, z1), Vector3(-hx, 0, z1), e, ridge, WHITE_WASH)
	gable(kit, "plaster", Vector3(-hx, 0, z0), Vector3(hx, 0, z0), e, ridge, WHITE_WASH)
	# An oculus in the back gable.
	var oc := Vector3(0, e + 1.4, z1 + 0.02)
	_kit.lathe(kit, "stone", oc, [Vector2(0.75, 0.0), Vector2(0.55, 0.0)], 16, STONE, true, Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)))
	_kit.lathe(kit, "pane", oc - Vector3(0, 0, 0.01), [Vector2(0.55, 0.0), Vector2(0.0, 0.0)], 16, Color(GLASS.r, GLASS.g, GLASS.b, 1.0), true, Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)))
	for s in [-1.0, 1.0]:
		for zz in [-2.0, 1.2, 4.4]:
			arched_window(kit, Vector3(s * hx, 2.2, zz), Vector3(0, 0, s), Vector3(s, 0, 0), 0.9, 2.3)
	# The tower.
	var tx := 1.8
	var tz0 := z0 - 3.6
	var tz1 := z0 + 0.2
	var th := 15.5
	var tcz := (tz0 + tz1) * 0.5
	slab(kit, "stone", Vector3(-tx - 0.25, -1.6, tz0 - 0.25), Vector3(tx + 0.25, 0.55, tz1), STONE.darkened(0.1))
	walls(kit, "plaster", -tx, tx, tz0, tz1, 0.55, th, WHITE_WASH)
	# Quoins: stones wrapping each corner, long on one face and short on the other by turns, 4cm proud.
	for cc in [Vector2(-tx, tz0), Vector2(tx, tz0), Vector2(tx, tz1), Vector2(-tx, tz1)]:
		var corner: Vector2 = cc
		var sx := signf(corner.x)
		var sz := signf(corner.y - tcz)
		var y := 0.55
		var k := 0
		while y < th - 0.3:
			var lx := 0.55 if k % 2 == 0 else 0.3
			var lz := 0.3 if k % 2 == 0 else 0.55
			var xa := corner.x - sx * lx
			var xb := corner.x + sx * 0.04
			var za := corner.y - sz * lz
			var zb := corner.y + sz * 0.04
			slab(kit, "stone", Vector3(minf(xa, xb), y, minf(za, zb)), Vector3(maxf(xa, xb), y + 0.42, maxf(za, zb)), STONE)
			y += 0.48
			k += 1
	for band in [11.0, th]:
		walls(kit, "stone", -tx - 0.12, tx + 0.12, tz0 - 0.12, tz1 + 0.12, band - 0.25, band + 0.05, STONE)
	lid(kit, "stone", -tx - 0.12, tx + 0.12, tz0 - 0.12, tz1 + 0.12, th + 0.05, STONE)
	var faces := [[Vector3(0, 0, tz0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(tx, 0, tcz), Vector3(0, 0, 1), Vector3(1, 0, 0)],
			[Vector3(-tx, 0, tcz), Vector3(0, 0, -1), Vector3(-1, 0, 0)], [Vector3(0, 0, tz1), Vector3(-1, 0, 0), Vector3(0, 0, 1)]]
	for fc in faces:
		var base: Vector3 = fc[0]
		var al: Vector3 = fc[1]
		var nn: Vector3 = fc[2]
		# Open arches for the bells: a dark opening in a stone surround, a bell's rim showing.
		var oc2 := base + Vector3(0, 12.0, 0)
		_plate(kit, "matte", oc2 + Vector3(0, 0.6, 0) + nn * 0.015, al, nn, 1.3, 1.2, Color(0.05, 0.05, 0.06))
		arch(kit, "matte", oc2 + Vector3(0, 1.2, 0) + nn * 0.015, al, nn, 0.65, Color(0.05, 0.05, 0.06))
		casing(kit, oc2 + Vector3(0, 0.6, 0), al, nn, 1.3, 1.2, 0.16, 0.16, "stone", STONE, false)
		for i in range(8):
			var a0 := PI * float(i) / 8.0
			var a1 := PI * float(i + 1) / 8.0
			var top := oc2 + Vector3(0, 1.2, 0) + nn * 0.08
			_kit.beam(kit, "stone", top + al * (cos(a0) * 0.73) + Vector3.UP * (sin(a0) * 0.73), top + al * (cos(a1) * 0.73) + Vector3.UP * (sin(a1) * 0.73), 0.16, 0.16, STONE, nn)
		_kit.beam(kit, "stone", oc2 - al * 0.8 + nn * 0.08, oc2 + al * 0.8 + nn * 0.08, 0.16, 0.2, STONE, nn)
		if nn.z < 0.5:
			# A clock below the arches (not on the back).
			var ck := base + Vector3(0, 9.6, 0) + nn * 0.03
			var cb := Basis(al, nn, al.cross(nn))
			_kit.lathe(kit, "stone", ck, [Vector2(0.85, 0.0), Vector2(0.72, 0.0)], 20, STONE.darkened(0.1), true, cb)
			_kit.lathe(kit, "painted", ck, [Vector2(0.72, 0.0), Vector2(0.0, 0.0)], 20, WHITE_WASH, true, cb)
			for hh in [[0.5, 0.0], [0.62, 1.9]]:
				var ang: float = hh[1]
				var hand := al * sin(ang) + Vector3.UP * cos(ang)
				_kit.beam(kit, "metal", ck + nn * 0.02, ck + nn * 0.02 + hand * float(hh[0]), 0.05, 0.02, FRAME_DARK, nn)
	# The spire: a tall four-sided pyramid in copper, a cross on top.
	var sp0 := th + 0.05
	var sp1 := th + 9.0
	var apex := Vector3(0, sp1, tcz)
	var ring := [Vector3(-tx - 0.1, sp0, tz0 - 0.1), Vector3(tx + 0.1, sp0, tz0 - 0.1), Vector3(tx + 0.1, sp0, tz1 + 0.1), Vector3(-tx - 0.1, sp0, tz1 + 0.1)]
	for i in range(4):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		var nrm := (b - a).cross(apex - a).normalized() * -1.0
		var l := a.distance_to(b)
		var slant := ((a + b) * 0.5).distance_to(apex)
		_kit.tri(kit, "zinc", a, b, apex, nrm, nrm, nrm, COPPER, nrm, Vector2(0, 0), Vector2(l, 0), Vector2(l * 0.5, slant))
	_kit.beam(fine, "metal", apex, apex + Vector3(0, 1.6, 0), 0.08, 0.08, Color(0.86, 0.70, 0.30))
	_kit.beam(fine, "metal", apex + Vector3(-0.45, 1.15, 0), apex + Vector3(0.45, 1.15, 0), 0.08, 0.08, Color(0.86, 0.70, 0.30))
	_kit.beam(kit, "metal", apex, apex + Vector3(0, 1.6, 0), 0.08, 0.08, Color(0.86, 0.70, 0.30))
	# The door into the tower, round-headed in stone.
	door(kit, Vector3(0, 0.55, tz0), Vector3(1, 0, 0), Vector3(0, 0, -1), 1.4, 2.4, DARK_WOOD.darkened(0.15), STONE, false, "plaster", WHITE_WASH)
	arch(kit, "stone", Vector3(0, 2.95, tz0 - 0.03), Vector3(1, 0, 0), Vector3(0, 0, -1), 0.85, STONE)
	arched_window(kit, Vector3(0, 6.0, tz0), Vector3(1, 0, 0), Vector3(0, 0, -1), 0.7, 1.6)
	var boxes: Array = [[Vector3(0, ridge * 0.5, (z0 + z1) * 0.5), Vector3(hx * 2.0, ridge, z1 - z0)],
			[Vector3(0, th * 0.5, tcz), Vector3(tx * 2.0, th, tz1 - tz0)]]
	return {"boxes": boxes, "labels": []}


## A half disc (an arch's head) on a wall: `c` the middle of its springing line, radius r.
func arch(kit: Dictionary, key: String, c: Vector3, along: Vector3, n: Vector3, r: float, col: Color) -> void:
	var segs := 10
	for i in range(segs):
		var a0 := PI * float(i) / segs
		var a1 := PI * float(i + 1) / segs
		var p0 := c + along * (cos(a0) * r) + Vector3.UP * (sin(a0) * r)
		var p1 := c + along * (cos(a1) * r) + Vector3.UP * (sin(a1) * r)
		_kit.tri(kit, key, c, p0, p1, n, n, n, col, n, Vector2(0, 0), Vector2(cos(a0) * r, sin(a0) * r), Vector2(cos(a1) * r, sin(a1) * r))


## A tall round-headed window: its sill's middle at `c` on the wall, w wide, h to the springing.
func arched_window(kit: Dictionary, c: Vector3, along: Vector3, n: Vector3, w: float, h: float) -> void:
	var glass := Color(GLASS.r * 0.9, GLASS.g, GLASS.b * 1.1, 1.0)
	_plate(kit, "pane", c + Vector3(0, h * 0.5, 0) + n * 0.015, along, n, w, h, glass)
	arch(kit, "pane", c + Vector3(0, h, 0) + n * 0.015, along, n, w * 0.5, glass)
	# A stone surround.
	for s in [-1.0, 1.0]:
		_kit.beam(kit, "stone", c + along * (s * (w * 0.5 + 0.08)) + n * 0.03, c + along * (s * (w * 0.5 + 0.08)) + Vector3(0, h, 0) + n * 0.03, 0.16, 0.08, STONE, n)
	for i in range(8):
		var a0 := PI * float(i) / 8.0
		var a1 := PI * float(i + 1) / 8.0
		var r := w * 0.5 + 0.08
		var top := c + Vector3(0, h, 0) + n * 0.03
		_kit.beam(kit, "stone", top + along * (cos(a0) * r) + Vector3.UP * (sin(a0) * r), top + along * (cos(a1) * r) + Vector3.UP * (sin(a1) * r), 0.16, 0.08, STONE, n)
	_kit.beam(kit, "painted", c + Vector3(0, h * 0.62, 0) + n * 0.03 - along * (w * 0.5), c + Vector3(0, h * 0.62, 0) + n * 0.03 + along * (w * 0.5), 0.04, 0.03, FRAME_DARK, n)
	_kit.box(kit, "stone", Transform3D(Basis(along, Vector3.UP, n), c - Vector3(0, 0.05, 0)), Vector3(w + 0.3, 0.1, 0.3), STONE, 1.0)


# ======================================================================================
#  Modern: the villas and the pavilion
# ======================================================================================

## A modern villa: a board-formed concrete ground floor glazed along its front, a timber-clad box on it
## cantilevered out over the terrace, glazed floor to ceiling toward the view, flat roofs with dark
## fascias and solar panels, a glass balustrade round the lower roof's terrace; in front a timber deck
## round an infinity pool, loungers. `variant` picks the cladding.
func villa_cube(kit: Dictionary, fine: Dictionary, rng: RandomNumberGenerator, variant: int) -> Dictionary:
	var clad: Color = [CHARRED, LARCH, Color(0.30, 0.26, 0.22)][variant % 3]
	var lx0 := -7.0
	var lx1 := 7.0
	var lz0 := -4.5
	var lz1 := 4.5
	var g1 := 3.2
	slab(kit, "concrete", Vector3(lx0 - 0.2, -1.6, lz0 - 0.2), Vector3(lx1 + 0.2, 0.15, lz1 + 0.2), CONCRETE.darkened(0.1))
	# The ground floor: concrete, its front mostly glass.
	wall(kit, "concrete", Vector3(lx1, 0, lz0), Vector3(lx1, 0, lz1), 0.15, g1, CONCRETE)
	wall(kit, "concrete", Vector3(lx1, 0, lz1), Vector3(lx0, 0, lz1), 0.15, g1, CONCRETE)
	wall(kit, "concrete", Vector3(lx0, 0, lz1), Vector3(lx0, 0, lz0), 0.15, g1, CONCRETE)
	glazing(kit, Vector3(lx0, 0, lz0), Vector3(3.0, 0, lz0), 0.15, g1, 1.45)
	wall(kit, "concrete", Vector3(3.0, 0, lz0), Vector3(lx1, 0, lz0), 0.15, g1, CONCRETE)
	glazing(kit, Vector3(lx1, 0, -1.5), Vector3(lx1, 0, 2.5), 1.3, 2.6, 1.0, FRAME_DARK, true)
	door(kit, Vector3(-2.0, 0.15, lz1), Vector3(-1, 0, 0), Vector3(0, 0, 1), 1.1, 2.3, CHARRED, FRAME_DARK, false, "concrete", CONCRETE)
	flat_roof(kit, "concrete", lx0, lx1, lz0, lz1, g1 + 0.35, 0.35, CONCRETE, "concrete", CONCRETE.darkened(0.05))
	glass_rail(kit, Vector3(lx0 + 0.15, g1 + 0.41, lz1 - 0.15), Vector3(lx0 + 0.15, g1 + 0.41, lz0 + 0.15))
	# The upper box, cantilevered toward the view and past the right side.
	var ux0 := -5.0
	var ux1 := 8.5
	var uz0 := -6.5
	var uz1 := 3.0
	var u0 := g1 + 0.41
	var u1 := u0 + 3.1
	wall(kit, "battens", Vector3(ux1, 0, uz0), Vector3(ux1, 0, uz1), u0, u1, clad)
	wall(kit, "battens", Vector3(ux1, 0, uz1), Vector3(ux0, 0, uz1), u0, u1, clad)
	wall(kit, "battens", Vector3(ux0, 0, uz1), Vector3(ux0, 0, uz0), u0, u1, clad)
	glazing(kit, Vector3(ux0, 0, uz0), Vector3(ux1, 0, uz0), u0, u1, 1.6)
	glazing(kit, Vector3(ux1, 0, uz0 + 0.6), Vector3(ux1, 0, uz0 + 4.2), u0 + 0.3, u1 - 0.3, 1.2, FRAME_DARK, true)
	lid(kit, "battens", ux0, ux1, uz0, lz0, u0, clad.darkened(0.2), true)
	lid(kit, "battens", lx1, ux1, lz0, uz1, u0, clad.darkened(0.2), true)
	flat_roof(kit, "concrete", ux0 - 0.3, ux1 + 0.3, uz0 - 0.3, uz1 + 0.3, u1 + 0.3, 0.32, CONCRETE.darkened(0.1), "metal", FRAME_DARK)
	# Solar panels on the roof.
	for i in range(4):
		for j in range(2):
			var pc := Vector3(ux0 + 1.8 + i * 2.6, u1 + 0.6, uz1 - 1.6 - j * 2.0)
			var pb := Basis(Vector3(1, 0, 0), deg_to_rad(-18.0))
			_kit.box(kit, "pane", Transform3D(pb, pc), Vector3(2.3, 0.05, 1.5), Color(0.10, 0.14, 0.26, 1.0))
			_kit.box(kit, "metal", Transform3D(pb, pc - Vector3(0, 0.04, 0)), Vector3(2.4, 0.04, 1.6), Color(0.62, 0.64, 0.66))
	# The deck and the pool.
	var dz0 := lz0 - 6.5
	var py0 := 0.15
	_kit.quad(kit, "lapboards", [Vector3(lx0, py0, dz0), Vector3(lx1 + 1.0, py0, dz0), Vector3(lx1 + 1.0, py0, lz0), Vector3(lx0, py0, lz0)], Vector3.UP, LARCH.lightened(0.05),
			[Vector2(lx0, dz0), Vector2(lx1 + 1.0, dz0), Vector2(lx1 + 1.0, lz0), Vector2(lx0, lz0)])
	walls(kit, "concrete", lx0, lx1 + 1.0, dz0, lz0, -1.6, py0, CONCRETE.darkened(0.08))
	var px0 := -6.4
	var px1 := 2.6
	var pz0 := dz0 + 0.6
	var pz1 := dz0 + 3.4
	_kit.quad(kit, "pool", [Vector3(px0, py0 + 0.02, pz0), Vector3(px1, py0 + 0.02, pz0), Vector3(px1, py0 + 0.02, pz1), Vector3(px0, py0 + 0.02, pz1)], Vector3.UP, Color(0.25, 0.65, 0.75),
			[Vector2(px0, pz0), Vector2(px1, pz0), Vector2(px1, pz1), Vector2(px0, pz1)])
	walls(kit, "stone", px0 - 0.25, px1 + 0.25, pz0 - 0.25, pz1 + 0.25, py0, py0 + 0.06, WHITE_WASH.darkened(0.05))
	lid(kit, "stone", px0 - 0.25, px1 + 0.25, pz0 - 0.25, pz0, py0 + 0.06, WHITE_WASH.darkened(0.05))
	lid(kit, "stone", px0 - 0.25, px1 + 0.25, pz1, pz1 + 0.25, py0 + 0.06, WHITE_WASH.darkened(0.05))
	lid(kit, "stone", px0 - 0.25, px0, pz0, pz1, py0 + 0.06, WHITE_WASH.darkened(0.05))
	lid(kit, "stone", px1, px1 + 0.25, pz0, pz1, py0 + 0.06, WHITE_WASH.darkened(0.05))
	glass_rail(kit, Vector3(lx1 + 1.0, py0, dz0), Vector3(lx0, py0, dz0))
	for i in range(3):
		lounger(fine, Vector3(3.6 + i * 1.2, py0, dz0 + 2.0), PI, Color(0.95, 0.94, 0.90))
	table_set(fine, Vector3(-4.0, py0, lz0 - 1.4), 0.0, rng)
	var boxes: Array = [[Vector3(0, 1.8, 0), Vector3(lx1 - lx0, 3.6, lz1 - lz0)],
			[Vector3((lx0 + lx1 + 1.0) * 0.5, -0.6, (dz0 + lz0) * 0.5), Vector3(lx1 + 1.0 - lx0, 1.5, lz0 - dz0)]]
	return {"boxes": boxes, "labels": []}


## A modern house in the old gable form: one long volume clad in larch (or black) boards under standing-
## seam zinc with no eaves, its front gable glass from the deck to the ridge, a slot of window along each
## side, a steel flue, a deck with a glass balustrade.
func villa_gable(kit: Dictionary, fine: Dictionary, rng: RandomNumberGenerator, variant: int) -> Dictionary:
	var clad: Color = [LARCH, CHARRED][variant % 2]
	var hx := 4.6
	var z0 := -7.5
	var z1 := 7.5
	var e := 4.3
	slab(kit, "concrete", Vector3(-hx - 0.1, -1.6, z0 - 0.1), Vector3(hx + 0.1, 0.3, z1 + 0.1), CONCRETE.darkened(0.12))
	wall(kit, "lapboards", Vector3(hx, 0, z0), Vector3(hx, 0, z1), 0.3, e, clad)
	wall(kit, "lapboards", Vector3(hx, 0, z1), Vector3(-hx, 0, z1), 0.3, e, clad)
	wall(kit, "lapboards", Vector3(-hx, 0, z1), Vector3(-hx, 0, z0), 0.3, e, clad)
	var ridge := roof(kit, "zinc", -hx, hx, z0, z1, e, deg_to_rad(40.0), 0.12, 0.2, ZINC, clad.darkened(0.3), ZINC.darkened(0.2), false, 0.14)
	gable(kit, "lapboards", Vector3(hx, 0, z1), Vector3(-hx, 0, z1), e, ridge, clad)
	# The glass gable: the rectangle under the eaves and the triangle over it, mullioned.
	glazing(kit, Vector3(-hx, 0, z0), Vector3(hx, 0, z0), 0.3, e, 1.5)
	var tri_n := Vector3(0, 0, -1)
	_kit.tri(kit, "pane", Vector3(-hx, e, z0 - 0.02), Vector3(hx, e, z0 - 0.02), Vector3(0, ridge, z0 - 0.02), tri_n, tri_n, tri_n,
			Color(GLASS.r * 0.85, GLASS.g * 0.9, GLASS.b, 1.0), tri_n)
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		var top_y: float = e + (ridge - e) * (1.0 - absf(x) / hx)
		_kit.beam(kit, "metal", Vector3(x, e, z0 - 0.03), Vector3(x, top_y, z0 - 0.03), 0.06, 0.1, FRAME_DARK, tri_n)
	for s in [-1.0, 1.0]:
		_kit.beam(kit, "metal", Vector3(s * hx, e, z0 - 0.03), Vector3(0, ridge, z0 - 0.03), 0.08, 0.1, FRAME_DARK, tri_n)
		# A slot of window along each side (walls run front to back on the right, back to front on the left).
		glazing(kit, Vector3(s * hx, 0, -4.0 * s), Vector3(s * hx, 0, 4.0 * s), 2.2, 3.0, 2.0, FRAME_DARK, true)
	door(kit, Vector3(hx, 0.3, 5.6), Vector3(0, 0, 1), Vector3(1, 0, 0), 1.1, 2.3, CHARRED, FRAME_DARK, true, "lapboards", clad)
	window(kit, fine, Vector3(0, 2.2, z1), Vector3(-1, 0, 0), Vector3(0, 0, 1), 2.6, 1.4, FRAME_DARK, rng, 2, Color(0, 0, 0, 0), 0.1, "lapboards", clad)
	_kit.tube(kit, "metal", Vector3(-hx * 0.5, ridge - 1.6, 3.0), Vector3(-hx * 0.5, ridge + 1.0, 3.0), 0.16, 0.16, 10, FRAME_DARK)
	var dz0 := z0 - 4.0
	_kit.quad(kit, "lapboards", [Vector3(-hx - 1.0, 0.3, dz0), Vector3(hx + 1.0, 0.3, dz0), Vector3(hx + 1.0, 0.3, z0), Vector3(-hx - 1.0, 0.3, z0)], Vector3.UP, LARCH,
			[Vector2(-hx, dz0), Vector2(hx, dz0), Vector2(hx, z0), Vector2(-hx, z0)])
	walls(kit, "concrete", -hx - 1.0, hx + 1.0, dz0, z0, -1.6, 0.3, CONCRETE.darkened(0.08))
	glass_rail(kit, Vector3(hx + 1.0, 0.3, dz0), Vector3(-hx - 1.0, 0.3, dz0))
	table_set(fine, Vector3(-2.0, 0.3, dz0 + 1.8), 0.4, rng)
	lounger(fine, Vector3(2.4, 0.3, dz0 + 1.6), PI + 0.2, Color(0.30, 0.32, 0.36))
	var boxes: Array = [[Vector3(0, ridge * 0.5, 0), Vector3(hx * 2.0, ridge, z1 - z0)],
			[Vector3(0, -0.6, (dz0 + z0) * 0.5), Vector3(hx * 2.0 + 2.0, 1.8, z0 - dz0)]]
	return {"boxes": boxes, "labels": []}


## The Ridgecrest Pavilion, the residents' clubhouse on the lip over the course: a glass room on a stone
## platform under a thin roof that reaches out on slender columns, a flagged viewing terrace in front
## with a glass balustrade, benches and two coin telescopes, the district's name on the platform's wall.
func pavilion(kit: Dictionary, fine: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var px := 11.0
	var pz0 := -9.0
	var pz1 := 5.0
	slab(kit, "stone", Vector3(-px, -2.8, pz0), Vector3(px, -0.05, pz1), STONE)
	lid(kit, "stone", -px, px, pz0, pz1, 0.0, STONE.lightened(0.08))
	walls(kit, "stone", -px - 0.15, px + 0.15, pz0 - 0.15, pz1 + 0.15, -0.05, 0.12, STONE.darkened(0.15))
	var gx := 8.0
	var gz0 := -2.5
	var gz1 := 3.5
	var h := 3.4
	glazing(kit, Vector3(-gx, 0, gz0), Vector3(gx, 0, gz0), 0.0, h, 1.6)
	glazing(kit, Vector3(gx, 0, gz0), Vector3(gx, 0, gz1), 0.0, h, 1.5)
	glazing(kit, Vector3(-gx, 0, gz1), Vector3(-gx, 0, gz0), 0.0, h, 1.5)
	wall(kit, "concrete", Vector3(gx, 0, gz1), Vector3(-gx, 0, gz1), 0.0, h, CONCRETE)
	slab(kit, "concrete", Vector3(-gx + 0.1, 0.0, 1.4), Vector3(-3.6, h, gz1 - 0.1), CONCRETE.darkened(0.05))
	flat_roof(kit, "concrete", -px + 0.5, px - 0.5, pz0 + 1.5, pz1 - 0.2, h + 0.4, 0.38, CONCRETE.lightened(0.05), "metal", FRAME_DARK)
	for c in [Vector3(-px + 1.0, 0, pz0 + 2.0), Vector3(px - 1.0, 0, pz0 + 2.0), Vector3(-px + 1.0, 0, pz1 - 0.7), Vector3(px - 1.0, 0, pz1 - 0.7)]:
		_kit.tube(kit, "metal", c, c + Vector3(0, h + 0.02, 0), 0.09, 0.09, 10, FRAME_DARK)
	glass_rail(kit, Vector3(px - 0.2, 0.0, pz0 + 0.2), Vector3(-px + 0.2, 0.0, pz0 + 0.2))
	glass_rail(kit, Vector3(-px + 0.2, 0.0, pz0 + 0.2), Vector3(-px + 0.2, 0.0, gz0))
	glass_rail(kit, Vector3(px - 0.2, 0.0, gz0), Vector3(px - 0.2, 0.0, pz0 + 0.2))
	for x in [-6.0, 0.0, 6.0]:
		bench(fine, Vector3(x, 0.0, pz0 + 2.6), PI)
	for x in [-3.0, 3.0]:
		telescope(fine, Vector3(x, 0.0, pz0 + 0.9))
	for i in range(3):
		table_set(fine, Vector3(-4.5 + i * 3.6, 0.0, 0.8), rng.randf() * TAU, rng)
	var boxes: Array = [[Vector3(0, -1.4, (pz0 + pz1) * 0.5), Vector3(px * 2.0, 2.8, pz1 - pz0)],
			[Vector3(0, h * 0.5, (gz0 + gz1) * 0.5), Vector3(gx * 2.0, h, gz1 - gz0)]]
	return {"boxes": boxes, "labels": [["RIDGECREST", Vector3(0, -1.35, pz0 - 0.03), Vector3(0, 0, -1), 1.15]]}


## The estate's gate on the lane up from the road: stone piers with lanterns, wrought-iron gates swung
## open, low stone walls curving away, the district's name on a slate in the left wall.
func estate_gate(kit: Dictionary, fine: Dictionary) -> Dictionary:
	var gap := 4.2
	var boxes: Array = []
	for s in [-1.0, 1.0]:
		var x: float = s * gap
		slab(kit, "stone", Vector3(x - 0.45, -1.0, -0.45), Vector3(x + 0.45, 2.7, 0.45), STONE)
		slab(kit, "stone", Vector3(x - 0.55, 2.7, -0.55), Vector3(x + 0.55, 2.9, 0.55), STONE.darkened(0.15))
		_kit.tube(fine, "metal", Vector3(x, 2.9, 0), Vector3(x, 3.05, 0), 0.12, 0.08, 8, FRAME_DARK)
		_kit.box(kit, "lamp", Transform3D(Basis(), Vector3(x, 3.3, 0)), Vector3(0.32, 0.45, 0.32), Color(1.0, 0.86, 0.6))
		_kit.lathe(kit, "metal", Vector3(x, 3.52, 0), [Vector2(0.26, 0.0), Vector2(0.0, 0.22)], 4, FRAME_DARK, true)
		boxes.append([Vector3(x, 1.0, 0), Vector3(0.9, 3.4, 0.9)])
		# The wall: straight out, then turning back from the lane.
		var w0 := Vector3(x + s * 0.45, 0, 0)
		var w1 := Vector3(x + s * 5.5, 0, 0)
		var w2 := Vector3(x + s * 8.0, 0, 2.6)
		for seg in [[w0, w1], [w1, w2]]:
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			var mid := (a + b) * 0.5 + Vector3(0, 0.15, 0)
			var dir := (b - a).normalized()
			var bas := Basis(dir.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, dir)
			_kit.box(kit, "stone", Transform3D(bas, mid), Vector3(0.55, 2.3, a.distance_to(b)), STONE, 1.0)
			_kit.box(kit, "stone", Transform3D(bas, mid + Vector3(0, 1.2, 0)), Vector3(0.7, 0.12, a.distance_to(b) + 0.1), STONE.darkened(0.2), 1.0)
			boxes.append([mid, Vector3(0.55, 2.3, a.distance_to(b)), bas])
		# The gate leaf, swung open toward the house.
		var hinge := Vector3(x - s * 0.5, 0, 0.1)
		var open := Vector3(-s * cos(deg_to_rad(70.0)), 0, sin(deg_to_rad(70.0)))
		var tip := hinge + open * (gap - 0.55)
		for y in [0.25, 1.95]:
			_kit.beam(kit, "metal", hinge + Vector3(0, y, 0), tip + Vector3(0, y, 0), 0.06, 0.06, FRAME_DARK)
		for i in range(10):
			var p := hinge.lerp(tip, (float(i) + 0.5) / 10.0)
			var top := 2.1 + 0.35 * sin(PI * (float(i) + 0.5) / 10.0)
			_kit.beam(fine, "metal", p + Vector3(0, 0.1, 0), p + Vector3(0, top, 0), 0.03, 0.03, FRAME_DARK)
			_kit.lathe(fine, "metal", p + Vector3(0, top, 0), [Vector2(0.04, 0.0), Vector2(0.0, 0.1)], 4, FRAME_DARK, true)
	_plate(kit, "stone", Vector3(-gap - 3.0, 1.25, -0.29), Vector3(1, 0, 0), Vector3(0, 0, -1), 3.6, 0.85, Color(0.20, 0.22, 0.25))
	return {"boxes": boxes, "labels": [["RIDGECREST", Vector3(-gap - 3.0, 1.38, -0.31), Vector3(0, 0, -1), 0.36],
			["A DISTRICT OF BLOOMBAY", Vector3(-gap - 3.0, 1.0, -0.31), Vector3(0, 0, -1), 0.14]]}


# ======================================================================================
#  Gardens
# ======================================================================================

## A clipped hedge from a to b (their feet on the ground), h tall and w thick, in the frame as it is.
func hedge(kit: Dictionary, a: Vector3, b: Vector3, h: float, w: float, col: Color, uv := 1.0) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var l := d.length()
	if l < 0.1:
		return
	d /= l
	var bas := Basis(d.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, d)
	var foot := minf(a.y, b.y)
	var top := maxf(a.y, b.y) + h
	var mid := Vector3((a.x + b.x) * 0.5, (foot - 0.3 + top) * 0.5, (a.z + b.z) * 0.5)
	_kit.box(kit, "hedge", Transform3D(bas, mid), Vector3(w, top - foot + 0.3, l), col, uv)


## A dry-stone wall from a to b (feet on the ground), h tall, w thick, capped with upright stones.
func stone_wall(kit: Dictionary, a: Vector3, b: Vector3, h: float, w: float, uv := 1.0) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var l := d.length()
	if l < 0.1:
		return
	d /= l
	var bas := Basis(d.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, d)
	var foot := minf(a.y, b.y)
	var top := maxf(a.y, b.y) + h
	_kit.box(kit, "stone", Transform3D(bas, Vector3((a.x + b.x) * 0.5, (foot - 0.4 + top) * 0.5, (a.z + b.z) * 0.5)), Vector3(w, top - foot + 0.4, l), STONE.darkened(0.05), uv)
	_kit.box(kit, "stone", Transform3D(bas, Vector3((a.x + b.x) * 0.5, top + w * 0.15, (a.z + b.z) * 0.5)), Vector3(w * 0.8, w * 0.3, l), STONE.darkened(0.2), uv)


## A lounger on a deck at `c` (its foot toward yaw's front): a frame, a cushion, the back raised.
func lounger(fine: Dictionary, c: Vector3, yaw: float, cushion: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	_kit.box(fine, "timber", Transform3D(b, c + b * Vector3(0, 0.28, 0.1)), Vector3(0.7, 0.06, 1.5), HONEY, 1.0)
	_kit.box(fine, "canvas", Transform3D(b, c + b * Vector3(0, 0.34, 0.15)), Vector3(0.64, 0.07, 1.3), cushion)
	_kit.box(fine, "canvas", Transform3D(b * Basis(Vector3(1, 0, 0), deg_to_rad(-55.0)), c + b * Vector3(0, 0.62, 0.88)), Vector3(0.64, 0.07, 0.7), cushion)
	for sx in [-0.3, 0.3]:
		for sz in [-0.55, 0.75]:
			_kit.box(fine, "timber", Transform3D(b, c + b * Vector3(sx, 0.13, sz)), Vector3(0.06, 0.26, 0.06), HONEY.darkened(0.2), 1.0)


## A teak table with four chairs round it at `c`.
func table_set(fine: Dictionary, c: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, yaw)
	_kit.box(fine, "timber", Transform3D(b, c + Vector3(0, 0.74, 0)), Vector3(1.4, 0.05, 0.85), HONEY, 1.0)
	for sx in [-0.62, 0.62]:
		for sz in [-0.36, 0.36]:
			_kit.box(fine, "timber", Transform3D(b, c + b * Vector3(sx, 0.36, sz)), Vector3(0.06, 0.72, 0.06), HONEY.darkened(0.2), 1.0)
	for k in range(4):
		var ang := yaw + PI * 0.5 * k
		var cb := Basis(Vector3.UP, ang)
		var cp := c + cb * Vector3(0, 0, 0.75 if k % 2 == 0 else 1.0) * (1.0 + rng.randf() * 0.1)
		_kit.box(fine, "timber", Transform3D(cb, cp + Vector3(0, 0.45, 0)), Vector3(0.46, 0.04, 0.44), HONEY, 1.0)
		_kit.box(fine, "timber", Transform3D(cb, cp + cb * Vector3(0, 0.72, 0.21)), Vector3(0.46, 0.5, 0.04), HONEY.darkened(0.1), 1.0)
		for sx in [-0.2, 0.2]:
			for sz in [-0.19, 0.19]:
				_kit.box(fine, "timber", Transform3D(cb, cp + cb * Vector3(sx, 0.22, sz)), Vector3(0.04, 0.45, 0.04), HONEY.darkened(0.2), 1.0)


## A market parasol at `c`: a pole and an eight-sided canopy.
func parasol(fine: Dictionary, c: Vector3, col: Color, r := 1.3) -> void:
	_kit.tube(fine, "metal", c, c + Vector3(0, 2.45, 0), 0.025, 0.025, 6, Color(0.85, 0.85, 0.82))
	_kit.lathe(fine, "canvas", c + Vector3(0, 2.0, 0), [Vector2(r, 0.0), Vector2(r * 0.95, 0.06), Vector2(0.05, 0.48)], 8, col, true)
	_kit.lathe(fine, "canvas", c + Vector3(0, 2.0, 0), [Vector2(0.05, 0.47), Vector2(r * 0.95, 0.05)], 8, col.darkened(0.25), true)


## A park bench at `c` facing yaw's front.
func bench(fine: Dictionary, c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	for k in range(3):
		_kit.box(fine, "timber", Transform3D(b, c + b * Vector3(0, 0.45, -0.18 + k * 0.17)), Vector3(1.8, 0.04, 0.14), HONEY, 1.0)
	for k in range(2):
		_kit.box(fine, "timber", Transform3D(b * Basis(Vector3(1, 0, 0), deg_to_rad(-12.0)), c + b * Vector3(0, 0.66 + k * 0.17, 0.25)), Vector3(1.8, 0.12, 0.04), HONEY, 1.0)
	for sx in [-0.75, 0.75]:
		_kit.box(fine, "metal", Transform3D(b, c + b * Vector3(sx, 0.22, 0.0)), Vector3(0.06, 0.44, 0.5), FRAME_DARK)
		_kit.box(fine, "metal", Transform3D(b, c + b * Vector3(sx, 0.6, 0.27)), Vector3(0.06, 0.5, 0.06), FRAME_DARK)


## A coin-operated telescope on a post at `c`, looking toward -z.
func telescope(fine: Dictionary, c: Vector3) -> void:
	_kit.tube(fine, "metal", c, c + Vector3(0, 1.05, 0), 0.06, 0.05, 8, Color(0.18, 0.40, 0.30))
	_kit.box(fine, "metal", Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(8.0)), c + Vector3(0, 1.25, 0)), Vector3(0.36, 0.32, 0.6), Color(0.18, 0.40, 0.30))
	for s in [-1.0, 1.0]:
		_kit.tube(fine, "metal", c + Vector3(s * 0.09, 1.3, -0.3), c + Vector3(s * 0.09, 1.34, -0.45), 0.06, 0.07, 8, FRAME_DARK)


## A garden lamp post at `c`: a slim dark post with a lantern.
func lamp_post(kit: Dictionary, fine: Dictionary, c: Vector3, h := 2.6) -> void:
	_kit.tube(kit, "metal", c, c + Vector3(0, h, 0), 0.05, 0.04, 6, FRAME_DARK)
	_kit.box(kit, "lamp", Transform3D(Basis(), c + Vector3(0, h + 0.2, 0)), Vector3(0.24, 0.32, 0.24), Color(1.0, 0.86, 0.62))
	_kit.lathe(fine, "metal", c + Vector3(0, h + 0.36, 0), [Vector2(0.2, 0.0), Vector2(0.0, 0.16)], 4, FRAME_DARK, true)


## The fountain on Ridgecrest's green: a stone basin, a column, a bowl.
func fountain(kit: Dictionary, c: Vector3) -> void:
	_kit.lathe(kit, "stone", c, [Vector2(2.2, -0.4), Vector2(2.2, 0.55), Vector2(2.4, 0.6), Vector2(2.4, 0.7), Vector2(2.0, 0.7), Vector2(2.0, 0.3)], 24, STONE)
	_kit.lathe(kit, "pool", c + Vector3(0, 0.5, 0), [Vector2(2.0, 0.0), Vector2(0.0, 0.0)], 24, Color(0.30, 0.55, 0.60), true)
	_kit.lathe(kit, "stone", c + Vector3(0, 0.5, 0), [Vector2(0.35, 0.0), Vector2(0.3, 1.2), Vector2(0.9, 1.5), Vector2(1.0, 1.65), Vector2(0.2, 1.7), Vector2(0.15, 2.3), Vector2(0.0, 2.45)], 16, STONE.lightened(0.05))
