extends "res://YardKit.gd"
## The Test Track's buildings (regenerate_test_track.gd): the RC Vibe GP proving ground's pit building, its control
## tower (the 3D logo turns on its roof: the generator puts it there, `TOWER_TOP`), the workshop hangar (the Tech
## Centre), the engineering office, and light masts. Built at life size through a PropKit (YardKit's helpers and
## materials, UVs in metres times `uvk`) and grown by the caller's PROP_SCALE.
##
## Each building is laid out round its footprint's middle on the ground: x along its front, +z out of its front (toward
## the road), y up. `footprint(name)` gives its extent [x0, x1, z0, z1, height] for colliders and keeping trees off.
##
## Material keys besides YardKit's ("concrete" board-formed, "zinc" standing seam, "plaster", "timber", ...): "pane"
## (ridgecrest_glass.gdshader: opaque glass reflecting a made-up sky, COLOR the tint), "clad" (hut_roof_iron without
## rust: ribbed metal cladding), "alu" (painted aluminium panels), "epoxy" (garage floors), "glow" (unshaded vertex
## colour: LED strips, the beacon), and CampKit's "steel", "metal", "chrome", "glass" (see-through), "plastic", "rubber",
## "matte", "lamp". Labels: [text, position, outward normal, cap height, colour, board width] in kit units.

const YK = preload("res://YardKit.gd")

const NAVY := Color(0.07, 0.11, 0.26)
const ORANGE := Color(0.96, 0.45, 0.07)
const WHITE := Color(0.93, 0.94, 0.95)
const GREY := Color(0.62, 0.64, 0.66)
const DARK := Color(0.16, 0.17, 0.19)
const FRAME := Color(0.22, 0.24, 0.27)
const PANE := Color(0.10, 0.16, 0.22, 1.0)
const BAL_GLASS := Color(0.70, 0.82, 0.88, 0.28)
const CONC := Color(0.80, 0.79, 0.76)

const BAY := 6.0
const PIT_D := 12.0
## The control tower's turntable top (life metres), and the foot of the logo, which turns on a post over it.
const TOWER_TOP := 35.4
const TOWER_LOGO_Y := 37.6
const TOWER_CAB_Y := 30.0

static var _pg_mats := {}


static func make_material(key: String) -> Material:
	match key:
		"pane":
			var g := ShaderMaterial.new()
			g.shader = load("res://ridgecrest_glass.gdshader")
			return g
		"clad":
			var i := ShaderMaterial.new()
			i.shader = load("res://hut_roof_iron.gdshader")
			i.set_shader_parameter("rust_amount", 0.0)
			return i
		"alu", "epoxy":
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.metallic = 0.25 if key == "alu" else 0.0
			m.roughness = 0.38 if key == "alu" else 0.3
			return m
		"glow":
			var e := StandardMaterial3D.new()
			e.vertex_color_use_as_albedo = true
			e.vertex_color_is_srgb = true
			e.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			return e
		"logo":
			var l := StandardMaterial3D.new()
			l.albedo_texture = load("res://images/logo_transparent.png")
			l.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			l.alpha_scissor_threshold = 0.5
			l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			l.roughness = 0.4
			return l
	return YK.make_material(key)


static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _pg_mats.has(k):
			_pg_mats[k] = make_material(k)
		return _pg_mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	return pk


static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in ["concrete", "zinc", "clad", "plaster"]:
		if kit.has(key):
			var s: SurfaceTool = kit[key]
			s.index()
			s.generate_tangents()
	return pk.commit(kit)


## [x0, x1, z0, z1, height] of a building in its own frame (life metres).
static func footprint(name: String, bays := 10) -> Array:
	match name:
		"pit":
			var hl: float = bays * BAY * 0.5
			return [-hl - 2.2, hl + 0.4, -6.3, 7.0, 12.8]
		"tower":
			return [-9.6, 9.6, -8.0, 9.6, TOWER_TOP]
		"workshop":
			return [-12.3, 18.4, -15.4, 15.4, 10.0]
		"office":
			return [-13.2, 17.0, -7.2, 10.2, 12.6]
	return [0, 0, 0, 0, 0]


# ======================================================================================
#  Helpers
# ======================================================================================

## A wall quad from a to b (xz), y0..y1, facing `out`, UVs in metres.
static func _w(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, y0: float, y1: float, col: Color, out: Vector3) -> void:
	wall(pk, kit, key, a, b, y0, y1, col, out)


## A convex polygon (xz, counter-clockwise or not) extruded from y0 to y1: sides, top and bottom, UVs in metres.
static func prism(pk: PropKit, kit: Dictionary, key: String, poly: Array, y0: float, y1: float, col: Color, bottom := true) -> void:
	var n: int = poly.size()
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(n)
	var u := 0.0
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var mid: Vector2 = (a + b) * 0.5
		var out := Vector3(mid.x - c.x, 0.0, mid.y - c.y)
		var e := b - a
		var nrm := Vector3(e.y, 0.0, -e.x).normalized()
		if nrm.dot(out) < 0.0:
			nrm = -nrm
		var l: float = e.length()
		pk.quad(kit, key, [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)], nrm, col,
				[Vector2(u, y0) * uvk, Vector2(u + l, y0) * uvk, Vector2(u + l, y1) * uvk, Vector2(u, y1) * uvk])
		u += l
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		pk.tri(kit, key, Vector3(c.x, y1, c.y), Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3.UP, Vector3.UP, Vector3.UP, col,
				Vector3.UP, c * uvk, a * uvk, b * uvk)
		if bottom:
			pk.tri(kit, key, Vector3(c.x, y0, c.y), Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3.DOWN, Vector3.DOWN,
					Vector3.DOWN, col, Vector3.DOWN, c * uvk, a * uvk, b * uvk)


## The ring between two horizontal polygons with the same number of corners (a frustum's sides), facing out.
static func ring(pk: PropKit, kit: Dictionary, key: String, lo: Array, y0: float, hi: Array, y1: float, col: Color) -> void:
	var n: int = lo.size()
	for i in n:
		var a := Vector3(lo[i].x, y0, lo[i].y)
		var b := Vector3(lo[(i + 1) % n].x, y0, lo[(i + 1) % n].y)
		var d := Vector3(hi[i].x, y1, hi[i].y)
		var e := Vector3(hi[(i + 1) % n].x, y1, hi[(i + 1) % n].y)
		var mid: Vector3 = (a + b + d + e) * 0.25
		var nrm: Vector3 = (b - a).cross(d - a).normalized()
		if nrm.dot(Vector3(mid.x, 0.0, mid.z)) < 0.0:
			nrm = -nrm
		var l: float = (b - a).length()
		var h: float = (d - a).length()
		pk.quad(kit, key, [a, b, e, d], nrm, col, [Vector2.ZERO, Vector2(l, 0) * uvk, Vector2(l, h) * uvk, Vector2(0, h) * uvk])


## A regular polygon of `n` corners, radius r (to the corners), turned so a flat side faces +z.
static func ngon(n: int, r: float, c := Vector2.ZERO) -> Array:
	var out: Array = []
	for i in n:
		var a: float = (float(i) + 0.5) * TAU / float(n) + PI * 0.5
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## A square with its corners cut off by `ch`, centred on c, `w` x `d`.
static func chamfered(c: Vector2, w: float, d: float, ch: float) -> Array:
	var hx := w * 0.5
	var hz := d * 0.5
	return [c + Vector2(-hx + ch, -hz), c + Vector2(hx - ch, -hz), c + Vector2(hx, -hz + ch), c + Vector2(hx, hz - ch),
		c + Vector2(hx - ch, hz), c + Vector2(-hx + ch, hz), c + Vector2(-hx, hz - ch), c + Vector2(-hx, -hz + ch)]


## A curtain wall: glass from a to b (xz) between y0 and y1 facing `out`, with mullions every `step` and transoms at
## `transoms` (heights), a frame round it, all 8cm proud of the glass.
static func curtain(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, y0: float, y1: float, out: Vector3, step := 1.5,
		transoms: Array = [], tint := PANE, fcol := FRAME) -> void:
	_w(pk, kit, "pane", a, b, y0, y1, tint, out)
	var l: float = Vector2(b.x - a.x, b.z - a.z).length()
	var dir: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z) / maxf(l, 0.001)
	var n: int = maxi(1, int(round(l / step)))
	var o: Vector3 = out * 0.05
	for i in n + 1:
		var p: Vector3 = Vector3(a.x, 0.0, a.z) + dir * (l * float(i) / float(n)) + o
		var w := 0.12 if i == 0 or i == n else 0.07
		pk.beam(kit, "alu", Vector3(p.x, y0, p.z), Vector3(p.x, y1, p.z), w, 0.1, fcol, dir)
	for y in [y0 + 0.04, y1 - 0.04] + transoms:
		pk.beam(kit, "alu", Vector3(a.x, y, a.z) + o, Vector3(b.x, y, b.z) + o, 0.08, 0.1, fcol, Vector3.UP)


## A glass balustrade from a to b: posts every ~1.5m, a handrail, see-through glass between.
static func glass_rail(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 1.1) -> void:
	var l: float = a.distance_to(b)
	var n: int = maxi(1, int(ceil(l / 1.6)))
	var dir: Vector3 = (b - a) / maxf(l, 0.001)
	var out := Vector3(dir.z, 0.0, -dir.x)
	for i in n + 1:
		var p: Vector3 = a + dir * (l * float(i) / float(n))
		pk.beam(kit, "metal", p, p + Vector3(0, h, 0), 0.05, 0.05, Color(0.75, 0.77, 0.80), dir)
	pk.beam(kit, "metal", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.07, 0.05, Color(0.75, 0.77, 0.80), Vector3.UP)
	pk.panel(kit, "glass", [a + Vector3(0, 0.08, 0), b + Vector3(0, 0.08, 0), b + Vector3(0, h - 0.06, 0), a + Vector3(0, h - 0.06, 0)],
			out, BAL_GLASS, BAL_GLASS)


## A steel tube railing (two rails) from a to b.
static func tube_rail(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 1.1, col := Color(0.85, 0.86, 0.87)) -> void:
	var l: float = a.distance_to(b)
	var n: int = maxi(1, int(ceil(l / 1.8)))
	var dir: Vector3 = (b - a) / maxf(l, 0.001)
	for i in n + 1:
		var p: Vector3 = a + dir * (l * float(i) / float(n))
		pk.tube(kit, "metal", p, p + Vector3(0, h, 0), 0.025, 0.025, 6, col)
	for y in [h, h * 0.5]:
		pk.tube(kit, "metal", a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.022, 0.022, 6, col, false)


## A logo panel (the RC Vibe GP artwork, images/logo_transparent.png) centred at c on a wall facing `out`, `w` wide.
static func logo_panel(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float) -> void:
	var across: Vector3 = Vector3.UP.cross(out).normalized()
	var h: float = w / 2.613
	var hw: Vector3 = across * w * 0.5
	var hh := Vector3(0, h * 0.5, 0)
	var p := c + out * 0.03
	pk.quad(kit, "logo", [p - hw - hh, p + hw - hh, p + hw + hh, p - hw + hh], out, Color.WHITE,
			[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])


## A flush door (two leaves of glass in an aluminium frame, or one solid leaf) in a wall at c facing `out`.
static func glass_door(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, steps := false, ground_y := NAN) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var base := c + out * 0.04
	var hw: Vector3 = across * w * 0.5
	_w(pk, kit, "pane", base - hw, base + hw, c.y, c.y + h, Color(0.08, 0.10, 0.12, 1.0), out)
	for s in [-1.0, 0.0, 1.0]:
		var p: Vector3 = base + across * (w * 0.5 * s) + out * 0.03
		pk.beam(kit, "alu", p, p + Vector3(0, h, 0), 0.09 if s != 0.0 else 0.06, 0.08, FRAME, across)
	pk.beam(kit, "alu", base - hw + out * 0.03 + Vector3(0, h, 0), base + hw + out * 0.03 + Vector3(0, h, 0), 0.1, 0.08, FRAME, Vector3.UP)
	for s in [-1.0, 1.0]:
		var hp: Vector3 = base + across * (0.1 * s) + out * 0.1 + Vector3(0, 1.05, 0)
		pk.beam(kit, "chrome", hp - Vector3(0, 0.4, 0), hp + Vector3(0, 0.4, 0), 0.03, 0.03, Color(0.8, 0.8, 0.8), across)


## A box of HVAC plant on a roof: a casing, a fan grille on top, louvres down one side.
static func plant_unit(pk: PropKit, kit: Dictionary, c: Vector3, size: Vector3, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	box_at(pk, kit, "alu", c + Vector3(0, size.y * 0.5, 0), b, size, Color(0.80, 0.81, 0.80))
	var fans: int = maxi(1, int(size.x / 1.3))
	for i in fans:
		var fx: float = (float(i) + 0.5) / float(fans) - 0.5
		var fc: Vector3 = c + b * Vector3(fx * size.x, size.y + 0.02, 0)
		pk.lathe(kit, "matte", fc, [Vector2(0.0, 0.0), Vector2(0.48, 0.0), Vector2(0.5, 0.06), Vector2(0.0, 0.06)], 14, DARK)
		pk.beam(kit, "steel", fc + b * Vector3(-0.48, 0.08, 0), fc + b * Vector3(0.48, 0.08, 0), 0.03, 0.02, GREY)
		pk.beam(kit, "steel", fc + b * Vector3(0, 0.08, -0.48), fc + b * Vector3(0, 0.08, 0.48), 0.03, 0.02, GREY)
	for j in 6:
		var y: float = size.y * (0.2 + 0.12 * float(j))
		pk.beam(kit, "alu", c + b * Vector3(-size.x * 0.45, y, size.z * 0.5 + 0.02), c + b * Vector3(size.x * 0.45, y, size.z * 0.5 + 0.02),
				0.05, 0.02, Color(0.55, 0.57, 0.58), b * Vector3.UP)


## A tyre stack (life size, n tyres) standing at p.
static func tyre_stack(pk: PropKit, kit: Dictionary, p: Vector3, n: int, seed_v: float) -> void:
	for i in n:
		pk.tyre(kit, "rubber", p + Vector3(0, 0.12 + 0.24 * float(i), 0), 0.2, 0.34, 0.23, 14, Color(0.06, 0.06, 0.07))


## A red roll cabinet with drawers.
static func tool_chest(pk: PropKit, kit: Dictionary, p: Vector3, out: Vector3, col := Color(0.70, 0.08, 0.06)) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var b := Basis(across, Vector3.UP, out)
	box_at(pk, kit, "plastic", p + Vector3(0, 0.55, 0), b, Vector3(1.4, 0.95, 0.6), col)
	box_at(pk, kit, "metal", p + Vector3(0, 1.04, 0), b, Vector3(1.42, 0.03, 0.62), Color(0.7, 0.7, 0.72))
	for i in 5:
		var y: float = 0.2 + 0.17 * float(i)
		pk.beam(kit, "chrome", p + Vector3(0, y, 0) + out * 0.31 - across * 0.5, p + Vector3(0, y, 0) + out * 0.31 + across * 0.5,
				0.025, 0.02, Color(0.8, 0.8, 0.82), Vector3.UP)
	for s in [-0.55, 0.55]:
		for t in [-0.2, 0.2]:
			box_at(pk, kit, "rubber", p + across * s + out * t + Vector3(0, 0.05, 0), b, Vector3(0.05, 0.1, 0.1), DARK)


# ======================================================================================
#  The pit building
# ======================================================================================

## The pit building: `bays` garages (BAY wide) along the front under a glazed hospitality floor with a balcony, a roof
## terrace behind a glass balustrade with race control in a glass box, the name and logo on the roof's fascia, a steel
## stair up the east end. `open` lists the bays (0-based) whose roller doors are up, showing the garage inside.
static func pit_building(pk: PropKit, kit: Dictionary, labels: Array, bays := 10, open: Array = [1, 4, 8]) -> void:
	var hl: float = float(bays) * BAY * 0.5
	var d: float = PIT_D * 0.5
	var g_top := 4.4
	var f1 := 5.0
	var roof0 := 8.6
	var roof1 := 9.2
	# The slab under it all.
	blk(pk, kit, "concrete", Vector3(-hl - 0.4, -0.4, -d - 0.2), Vector3(hl + 0.4, 0.12, d + 0.5), CONC)
	# End walls and the back wall, concrete, full height.
	for sx in [-1.0, 1.0]:
		var x0: float = sx * hl
		blk(pk, kit, "concrete", Vector3(minf(x0, x0 + sx * 0.35), 0.0, -d - 0.2), Vector3(maxf(x0, x0 + sx * 0.35), roof0, d + 0.45), CONC)
		# Slot windows up the ends.
		for zz in [-3.5, -1.0, 1.5]:
			curtain(pk, kit, Vector3(x0 + sx * 0.36, 0, zz - 0.4), Vector3(x0 + sx * 0.36, 0, zz + 0.4), 5.6, 8.0, Vector3(sx, 0, 0), 0.8)
	blk(pk, kit, "concrete", Vector3(-hl, 0.0, -d - 0.2), Vector3(hl, roof0, -d + 0.15), CONC)
	# The back: personnel doors and windows between them.
	for i in bays:
		var bx: float = -hl + (float(i) + 0.5) * BAY
		if i % 2 == 0:
			glass_door(pk, kit, Vector3(bx, 0.12, -d - 0.2), Vector3(0, 0, -1), 1.1, 2.3)
		else:
			curtain(pk, kit, Vector3(bx + 1.6, 0, -d - 0.22), Vector3(bx - 1.6, 0, -d - 0.22), 1.6, 3.2, Vector3(0, 0, -1), 0.8)
		curtain(pk, kit, Vector3(bx + 2.2, 0, -d - 0.22), Vector3(bx - 2.2, 0, -d - 0.22), 5.8, 7.6, Vector3(0, 0, -1), 1.1)
	# The front: pilasters between the bays, a navy head panel over each door with its number.
	for i in bays + 1:
		var px: float = -hl + float(i) * BAY
		blk(pk, kit, "concrete", Vector3(px - 0.4, 0.0, d - 0.2), Vector3(px + 0.4, g_top, d + 0.35), CONC)
		# An orange LED strip up each pilaster's face.
		blk(pk, kit, "glow", Vector3(px - 0.04, 0.3, d + 0.35), Vector3(px + 0.04, g_top - 0.3, d + 0.37), ORANGE)
	for i in bays:
		var x0: float = -hl + float(i) * BAY + 0.4
		var x1: float = x0 + BAY - 0.8
		var cx: float = (x0 + x1) * 0.5
		blk(pk, kit, "alu", Vector3(x0, 3.85, d - 0.1), Vector3(x1, g_top, d + 0.12), NAVY)
		labels.append(["GARAGE %d" % (i + 1), Vector3(cx, 4.12, d + 0.14), Vector3(0, 0, 1), 0.3, WHITE, BAY - 1.6])
		# The roller door's guides and the housing over it.
		for gx in [x0 + 0.06, x1 - 0.06]:
			pk.beam(kit, "steel", Vector3(gx, 0.0, d + 0.02), Vector3(gx, 3.85, d + 0.02), 0.12, 0.1, FRAME, Vector3.RIGHT)
		blk(pk, kit, "steel", Vector3(x0, 3.55, d - 0.05), Vector3(x1, 3.85, d + 0.2), FRAME)
		if open.has(i):
			_open_garage(pk, kit, x0 + 0.12, x1 - 0.12, d, 3.55, i)
		else:
			# Closed: a slatted door, a vision strip of small windows, a handle bar along its foot.
			_w(pk, kit, "alu", Vector3(x0 + 0.12, 0, d), Vector3(x1 - 0.12, 0, d), 0.02, 3.55, Color(0.80, 0.82, 0.84), Vector3(0, 0, 1))
			var y := 0.1
			while y < 3.5:
				pk.beam(kit, "alu", Vector3(x0 + 0.13, y, d + 0.02), Vector3(x1 - 0.13, y, d + 0.02), 0.035, 0.03, Color(0.66, 0.68, 0.70), Vector3.UP)
				y += 0.12
			for k in 6:
				var wx: float = x0 + 0.5 + (x1 - x0 - 1.0) * (float(k) + 0.5) / 6.0
				_w(pk, kit, "pane", Vector3(wx - 0.28, 0, d + 0.035), Vector3(wx + 0.28, 0, d + 0.035), 2.1, 2.3, PANE, Vector3(0, 0, 1))
			pk.beam(kit, "metal", Vector3(x0 + 0.3, 0.35, d + 0.06), Vector3(x1 - 0.3, 0.35, d + 0.06), 0.06, 0.05, GREY, Vector3.UP)
		# Tyres stacked by every other door.
		if i % 2 == 1:
			tyre_stack(pk, kit, Vector3(x1 - 0.55, 0.12, d + 1.1), 4, float(i))
			tyre_stack(pk, kit, Vector3(x1 - 1.35, 0.12, d + 1.1), 3, float(i) + 0.5)
	# The first floor: its slab (the balcony, a white fascia with an orange line), glazing set back behind it.
	blk(pk, kit, "alu", Vector3(-hl, g_top, -d), Vector3(hl, f1, d + 0.55), WHITE)
	blk(pk, kit, "glow", Vector3(-hl, g_top + 0.18, d + 0.55), Vector3(hl, g_top + 0.26, d + 0.57), ORANGE)
	curtain(pk, kit, Vector3(-hl, 0, d - 1.5), Vector3(hl, 0, d - 1.5), f1, roof0, Vector3(0, 0, 1), 1.5, [f1 + 2.7])
	# The balcony's glass balustrade and steel columns up to the roof's edge.
	glass_rail(pk, kit, Vector3(-hl + 0.4, f1, d + 0.4), Vector3(hl - 0.4, f1, d + 0.4))
	for i in bays + 1:
		var px: float = -hl + float(i) * BAY
		pk.tube(kit, "steel", Vector3(px, f1, d + 0.25), Vector3(px, roof0, d + 0.25), 0.11, 0.11, 10, WHITE)
	# The roof slab, overhanging the balcony, its fascia with the name and the logo.
	blk(pk, kit, "alu", Vector3(-hl - 0.4, roof0, -d - 0.3), Vector3(hl + 0.4, roof1, d + 0.8), WHITE)
	blk(pk, kit, "alu", Vector3(-hl - 0.4, roof0 - 0.3, d + 0.8), Vector3(hl + 0.4, roof1 + 0.6, d + 0.95), NAVY)
	blk(pk, kit, "glow", Vector3(-hl - 0.4, roof0 - 0.22, d + 0.95), Vector3(hl + 0.4, roof0 - 0.14, d + 0.97), ORANGE)
	labels.append(["RC VIBE GP  PROVING GROUND", Vector3(-hl * 0.45, roof0 + 0.32, d + 0.97), Vector3(0, 0, 1), 0.62, WHITE, hl * 0.95])
	logo_panel(pk, kit, Vector3(0, roof0 + 0.45, d + 0.95), Vector3(0, 0, 1), 3.4)
	labels.append(["TEST . TUNE . RACE", Vector3(hl * 0.55, roof0 + 0.32, d + 0.97), Vector3(0, 0, 1), 0.5, ORANGE, hl * 0.7])
	# Downlights in the roof's soffit over the balcony.
	for i in bays * 2:
		var lx: float = -hl + (float(i) + 0.5) * BAY * 0.5
		pk.lathe(kit, "glow", Vector3(lx, roof0 - 0.02, d + 0.15), [Vector2(0, 0), Vector2(0.14, 0), Vector2(0.14, 0.02), Vector2(0, 0.02)], 10,
				Color(1.0, 0.95, 0.85))
	# The roof terrace: a glass balustrade along the front and the ends, a parapet at the back.
	glass_rail(pk, kit, Vector3(-hl, roof1, d + 0.6), Vector3(hl, roof1, d + 0.6))
	glass_rail(pk, kit, Vector3(-hl, roof1, -d), Vector3(-hl, roof1, d + 0.6))
	glass_rail(pk, kit, Vector3(hl, roof1, d + 0.6), Vector3(hl, roof1, -d))
	blk(pk, kit, "concrete", Vector3(-hl - 0.4, roof1, -d - 0.3), Vector3(hl + 0.4, roof1 + 0.9, -d + 0.05), CONC)
	# Decking on the terrace.
	blk(pk, kit, "timber", Vector3(-hl + 0.3, roof1, -d + 3.0), Vector3(hl - 0.3, roof1 + 0.06, d + 0.5), Color(0.62, 0.47, 0.33))
	# Race control: a glass box in the middle of the roof under an overhanging lid with its name.
	var rc0 := Vector3(-8.0, roof1, -3.0)
	var rc1 := Vector3(8.0, roof1 + 3.2, 3.0)
	curtain(pk, kit, Vector3(rc0.x, 0, rc1.z), Vector3(rc1.x, 0, rc1.z), rc0.y + 0.06, rc1.y, Vector3(0, 0, 1), 1.6, [rc0.y + 1.0])
	curtain(pk, kit, Vector3(rc1.x, 0, rc1.z), Vector3(rc1.x, 0, rc0.z), rc0.y + 0.06, rc1.y, Vector3(1, 0, 0), 1.6, [rc0.y + 1.0])
	curtain(pk, kit, Vector3(rc0.x, 0, rc0.z), Vector3(rc0.x, 0, rc1.z), rc0.y + 0.06, rc1.y, Vector3(-1, 0, 0), 1.6, [rc0.y + 1.0])
	_w(pk, kit, "alu", Vector3(rc1.x, 0, rc0.z), Vector3(rc0.x, 0, rc0.z), rc0.y, rc1.y, GREY, Vector3(0, 0, -1))
	blk(pk, kit, "alu", Vector3(rc0.x - 0.8, rc1.y, rc0.z - 0.6), Vector3(rc1.x + 0.8, rc1.y + 0.45, rc1.z + 1.0), NAVY)
	blk(pk, kit, "glow", Vector3(rc0.x - 0.8, rc1.y + 0.05, rc1.z + 1.0), Vector3(rc1.x + 0.8, rc1.y + 0.11, rc1.z + 1.02), ORANGE)
	labels.append(["RACE CONTROL", Vector3(0, rc1.y + 0.26, rc1.z + 1.03), Vector3(0, 0, 1), 0.28, WHITE, 8.0])
	# A clock and a timing screen on its roof, aerials.
	blk(pk, kit, "matte", Vector3(-2.6, rc1.y + 0.45, 0.6), Vector3(2.6, rc1.y + 2.0, 0.8), DARK)
	blk(pk, kit, "glow", Vector3(-2.45, rc1.y + 0.6, 0.8), Vector3(2.45, rc1.y + 1.85, 0.82), Color(0.05, 0.08, 0.12))
	labels.append(["P1  P2  P3  LAP", Vector3(0, rc1.y + 1.5, 0.83), Vector3(0, 0, 1), 0.22, ORANGE, 4.6])
	labels.append(["00:59.731", Vector3(0, rc1.y + 0.95, 0.83), Vector3(0, 0, 1), 0.34, Color(0.4, 1.0, 0.5), 4.6])
	for sx in [-1.8, 1.8]:
		pk.beam(kit, "steel", Vector3(sx, rc1.y + 0.45, 0.4), Vector3(sx, rc1.y + 0.7, 0.4), 0.12, 0.12, FRAME)
	for ax in [-6.5, 6.0]:
		pk.tube(kit, "metal", Vector3(ax, rc1.y + 0.45, -2.0), Vector3(ax, rc1.y + 4.5, -2.0), 0.05, 0.02, 6, GREY)
		pk.tube(kit, "glow", Vector3(ax, rc1.y + 4.5, -2.0), Vector3(ax, rc1.y + 4.62, -2.0), 0.06, 0.06, 8, Color(1.0, 0.15, 0.1))
	# Shade canopies over the terrace either side of race control: white sails on slender posts.
	for sx in [-1.0, 1.0]:
		var xa: float = sx * 10.5
		var xb: float = sx * (hl - 2.0)
		var lo_x: float = minf(xa, xb)
		var hi_x: float = maxf(xa, xb)
		var n: int = int((hi_x - lo_x) / 6.0)
		for k in n:
			var s0: float = lo_x + (hi_x - lo_x) * float(k) / float(n)
			var s1: float = lo_x + (hi_x - lo_x) * float(k + 1) / float(n)
			pk.panel(kit, "canvas", [Vector3(s0 + 0.2, roof1 + 3.0, 4.6), Vector3(s1 - 0.2, roof1 + 3.4, 4.6), Vector3(s1 - 0.2, roof1 + 2.7, -1.5),
					Vector3(s0 + 0.2, roof1 + 3.1, -1.5)], Vector3(0, 1, 0), Color(0.97, 0.97, 0.96), Color(0.82, 0.83, 0.84))
		for k in n + 1:
			var px: float = lerpf(lo_x + 0.2, hi_x - 0.2, float(k) / float(n))
			var t: float = float(k) / float(n)
			pk.tube(kit, "steel", Vector3(px, roof1, 4.6), Vector3(px, roof1 + 3.0 + 0.4 * fposmod(t * float(n), 1.0), 4.6), 0.07, 0.06, 8, GREY)
			pk.tube(kit, "steel", Vector3(px, roof1, -1.5), Vector3(px, roof1 + 2.7, -1.5), 0.07, 0.06, 8, GREY)
		# Tables and stools under them.
		for k in n:
			var tx: float = lo_x + (hi_x - lo_x) * (float(k) + 0.5) / float(n)
			pk.tube(kit, "metal", Vector3(tx, roof1, 1.6), Vector3(tx, roof1 + 1.05, 1.6), 0.04, 0.04, 8, GREY)
			pk.lathe(kit, "plastic", Vector3(tx, roof1 + 1.05, 1.6), [Vector2(0, 0), Vector2(0.45, 0), Vector2(0.45, 0.04), Vector2(0, 0.04)], 16, WHITE)
			for a in 3:
				var ang: float = float(a) * TAU / 3.0 + 0.4
				var sp := Vector3(tx + cos(ang) * 0.75, roof1, 1.6 + sin(ang) * 0.75)
				pk.tube(kit, "metal", sp, sp + Vector3(0, 0.75, 0), 0.03, 0.03, 6, GREY)
				pk.lathe(kit, "plastic", sp + Vector3(0, 0.75, 0), [Vector2(0, 0), Vector2(0.2, 0), Vector2(0.2, 0.05), Vector2(0, 0.05)], 12, ORANGE)
	# Plant on the roof behind race control.
	plant_unit(pk, kit, Vector3(-hl + 6.0, roof1, -d + 1.4), Vector3(3.2, 1.4, 1.6))
	plant_unit(pk, kit, Vector3(hl - 13.0, roof1, -d + 1.4), Vector3(4.4, 1.5, 1.8))
	# The stair up the east end: two flights with a landing, steel stringers, treads, railings.
	_stair(pk, kit, hl + 0.35, d - 1.0, roof1)


## An open garage: the roller door up in its housing, the room behind it (epoxy floor, walls, strip lights) with a car
## lift, a roll cabinet, a bench, wheels on a rack, the team's banner.
static func _open_garage(pk: PropKit, kit: Dictionary, x0: float, x1: float, d: float, h: float, i: int) -> void:
	var back: float = -d + 0.3
	var team: Color = [Color(0.85, 0.10, 0.08), Color(0.08, 0.40, 0.85), Color(0.10, 0.62, 0.30), Color(0.95, 0.70, 0.05)][i % 4]
	blk(pk, kit, "epoxy", Vector3(x0, 0.1, back), Vector3(x1, 0.13, d), Color(0.46, 0.49, 0.52))
	# Yellow lines round the lift.
	blk(pk, kit, "epoxy", Vector3(x0 + 0.6, 0.131, back + 2.0), Vector3(x0 + 0.68, 0.135, d - 1.5), Color(0.9, 0.75, 0.1))
	blk(pk, kit, "epoxy", Vector3(x1 - 0.68, 0.131, back + 2.0), Vector3(x1 - 0.6, 0.135, d - 1.5), Color(0.9, 0.75, 0.1))
	_w(pk, kit, "alu", Vector3(x0, 0, back), Vector3(x1, 0, back), 0.1, h, Color(0.86, 0.87, 0.88), Vector3(0, 0, 1))
	_w(pk, kit, "alu", Vector3(x0, 0, d), Vector3(x0, 0, back), 0.1, h, Color(0.80, 0.81, 0.82), Vector3(1, 0, 0))
	_w(pk, kit, "alu", Vector3(x1, 0, back), Vector3(x1, 0, d), 0.1, h, Color(0.80, 0.81, 0.82), Vector3(-1, 0, 0))
	pk.quad(kit, "alu", [Vector3(x0, h, back), Vector3(x1, h, back), Vector3(x1, h, d), Vector3(x0, h, d)], Vector3.DOWN, Color(0.75, 0.76, 0.77))
	# The rolled-up door in its housing (a drum seen from below).
	pk.tube(kit, "alu", Vector3(x0, h - 0.25, d - 0.2), Vector3(x1, h - 0.25, d - 0.2), 0.24, 0.24, 12, Color(0.72, 0.74, 0.76))
	# Strip lights.
	for lx in [x0 + 1.3, (x0 + x1) * 0.5, x1 - 1.3]:
		blk(pk, kit, "glow", Vector3(lx - 0.08, h - 0.06, back + 1.0), Vector3(lx + 0.08, h - 0.01, d - 1.0), Color(0.95, 0.97, 1.0))
	# The team's banner on the back wall, an orange-and-navy band under it.
	pk.quad(kit, "canvas", [Vector3(x0 + 0.8, 1.5, back + 0.02), Vector3(x1 - 0.8, 1.5, back + 0.02), Vector3(x1 - 0.8, 3.1, back + 0.02),
			Vector3(x0 + 0.8, 3.1, back + 0.02)], Vector3(0, 0, 1), team)
	pk.quad(kit, "canvas", [Vector3(x0 + 0.8, 2.0, back + 0.03), Vector3(x1 - 0.8, 2.0, back + 0.03), Vector3(x1 - 0.8, 2.25, back + 0.03),
			Vector3(x0 + 0.8, 2.25, back + 0.03)], Vector3(0, 0, 1), WHITE)
	# The two-post lift: posts, arms, the power pack.
	for sx in [x0 + 0.35, x1 - 0.35]:
		blk(pk, kit, "paint", Vector3(sx - 0.18, 0.1, -0.3), Vector3(sx + 0.18, 3.2, 0.3), Color(0.12, 0.28, 0.62))
		blk(pk, kit, "steel", Vector3(sx - 0.25, 0.1, -0.4), Vector3(sx + 0.25, 0.14, 0.4), FRAME)
		var dir: float = 1.0 if sx < (x0 + x1) * 0.5 else -1.0
		for az in [-0.25, 0.25]:
			pk.beam(kit, "steel", Vector3(sx, 0.5, az), Vector3(sx + dir * 1.3, 0.5, az + az * 3.0), 0.12, 0.1, Color(0.85, 0.65, 0.05))
	blk(pk, kit, "paint", Vector3(x0 + 0.15, 0.1, 0.4), Vector3(x0 + 0.5, 0.9, 0.8), Color(0.12, 0.28, 0.62))
	pk.beam(kit, "steel", Vector3(x0 + 0.35, 3.2, 0.0), Vector3(x1 - 0.35, 3.2, 0.0), 0.15, 0.2, Color(0.12, 0.28, 0.62))
	# A roll cabinet, a bench along the side, a wheel rack.
	tool_chest(pk, kit, Vector3(x1 - 1.0, 0.13, back + 1.0), Vector3(0, 0, 1))
	tool_chest(pk, kit, Vector3(x0 + 1.0, 0.13, back + 1.0), Vector3(0, 0, 1), Color(0.10, 0.10, 0.11))
	blk(pk, kit, "steel", Vector3(x0 + 0.05, 0.9, back + 2.2), Vector3(x0 + 0.75, 0.95, back + 4.6), Color(0.6, 0.62, 0.64))
	for bz in [back + 2.3, back + 4.5]:
		pk.beam(kit, "steel", Vector3(x0 + 0.4, 0.13, bz), Vector3(x0 + 0.4, 0.9, bz), 0.05, 0.05, FRAME)
	# Wheels on a rack along the other side.
	pk.beam(kit, "steel", Vector3(x1 - 0.35, 1.2, back + 2.2), Vector3(x1 - 0.35, 1.2, back + 5.2), 0.05, 0.05, FRAME, Vector3.UP)
	for k in 4:
		var wz: float = back + 2.5 + float(k) * 0.75
		pk.tyre(kit, "rubber", Vector3(x1 - 0.4, 0.95, wz), 0.18, 0.32, 0.24, 14, Color(0.06, 0.06, 0.07), Basis(Vector3.FORWARD, PI * 0.5))
		pk.lathe(kit, "chrome", Vector3(x1 - 0.4, 0.95, wz), [Vector2(0, -0.08), Vector2(0.18, -0.08), Vector2(0.18, 0.08), Vector2(0, 0.08)],
				12, Color(0.8, 0.8, 0.82), false, Basis(Vector3.FORWARD, PI * 0.5))


## A steel stair against an end wall at x (+x outward), from the ground at z0 back toward -z and up to `top` over a
## landing; the flights 1.3m wide.
static func _stair(pk: PropKit, kit: Dictionary, x: float, z0: float, top: float) -> void:
	var w := 1.3
	var xa: float = x + 0.05
	var xb: float = x + 0.05 + w
	var mid: float = top * 0.5
	var run: float = 7.0
	var zl: float = z0 - run
	var steps := 16
	# Flight 1: from z0 (ground) back to zl at mid, on the outer half; flight 2 back toward z0 on... the same line,
	# stacked: flight 2 from zl at mid to z0 at the top, outboard by another width.
	for f in 2:
		var x0: float = xa + float(f) * (w + 0.1)
		var x1: float = x0 + w
		var y0: float = 0.12 if f == 0 else mid
		var y1: float = mid if f == 0 else top
		var za: float = z0 if f == 0 else zl
		var zb: float = zl if f == 0 else z0
		for s in steps:
			var t: float = (float(s) + 0.5) / float(steps)
			var z: float = lerpf(za, zb, t)
			var y: float = lerpf(y0, y1, float(s + 1) / float(steps))
			blk(pk, kit, "steel", Vector3(x0, y - 0.04, z - 0.15), Vector3(x1, y, z + 0.15), GREY)
		for sx in [x0, x1]:
			pk.beam(kit, "steel", Vector3(sx, y0 - 0.15, za), Vector3(sx, y1 - 0.15, zb), 0.06, 0.3, ORANGE, Vector3.RIGHT)
		tube_rail(pk, kit, Vector3(x1, y0 + 0.1, za), Vector3(x1, y1 + 0.1, zb), 1.0)
	# The landing at mid height and the top landing, on posts.
	blk(pk, kit, "steel", Vector3(xa, mid - 0.12, zl - 1.4), Vector3(xa + 2 * w + 0.1, mid, zl), GREY)
	blk(pk, kit, "steel", Vector3(xa, top - 0.12, z0), Vector3(xa + 2 * w + 0.1, top, z0 + 1.4), GREY)
	tube_rail(pk, kit, Vector3(xa + 2 * w + 0.1, mid, zl - 1.4), Vector3(xa, mid, zl - 1.4), 1.0)
	tube_rail(pk, kit, Vector3(xa + 2 * w + 0.1, top, z0 + 1.4), Vector3(xa + 2 * w + 0.1, top, z0), 1.0)
	for pz in [zl - 1.3, zl - 0.1, z0 + 0.1, z0 + 1.3]:
		var py: float = mid if pz < zl + 0.5 else top
		pk.beam(kit, "steel", Vector3(xa + 2 * w, 0.1, pz), Vector3(xa + 2 * w, py - 0.12, pz), 0.12, 0.12, ORANGE)


# ======================================================================================
#  The control tower
# ======================================================================================

## The control tower: a glazed lobby, a chamfered concrete shaft with a strip of glass up its front and orange fins on
## its front corners, a navy skirt flaring out under the cab, the cab (eight panes leaning out in a ring), its roof
## with a railing, a beacon and aerials, and the turntable the logo turns on (`TOWER_TOP`).
static func control_tower(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	# The lobby.
	blk(pk, kit, "concrete", Vector3(-9.2, -0.4, -6.2), Vector3(9.2, 0.12, 6.2), CONC)
	blk(pk, kit, "concrete", Vector3(-9.0, 0.0, -6.0), Vector3(-7.2, 5.0, 6.0), CONC)
	blk(pk, kit, "concrete", Vector3(7.2, 0.0, -6.0), Vector3(9.0, 5.0, 6.0), CONC)
	curtain(pk, kit, Vector3(-7.2, 0, 5.8), Vector3(7.2, 0, 5.8), 0.12, 5.0, Vector3(0, 0, 1), 1.8, [3.4])
	curtain(pk, kit, Vector3(7.2, 0, -5.8), Vector3(-7.2, 0, -5.8), 0.12, 5.0, Vector3(0, 0, -1), 1.8, [3.4])
	glass_door(pk, kit, Vector3(0, 0.12, 5.86), Vector3(0, 0, 1), 2.4, 2.6)
	blk(pk, kit, "alu", Vector3(-9.6, 5.0, -6.6), Vector3(9.6, 5.6, 6.6), WHITE)
	blk(pk, kit, "glow", Vector3(-9.6, 5.1, 6.6), Vector3(9.6, 5.18, 6.62), ORANGE)
	labels.append(["CONTROL TOWER", Vector3(-4.0, 5.36, 6.63), Vector3(0, 0, 1), 0.3, NAVY, 7.0])
	# An entrance canopy on two columns.
	blk(pk, kit, "alu", Vector3(-3.4, 3.4, 5.8), Vector3(3.4, 3.7, 9.4), WHITE)
	for sx in [-3.0, 3.0]:
		pk.tube(kit, "steel", Vector3(sx, 0.12, 9.0), Vector3(sx, 3.4, 9.0), 0.1, 0.1, 10, WHITE)
	# The shaft.
	var shaft: Array = chamfered(Vector2(0, -0.5), 7.0, 7.0, 1.4)
	prism(pk, kit, "concrete", shaft, 5.6, 27.0, CONC, false)
	curtain(pk, kit, Vector3(-1.1, 0, 3.02), Vector3(1.1, 0, 3.02), 6.0, 26.5, Vector3(0, 0, 1), 2.2, [9.0, 12.0, 15.0, 18.0, 21.0, 24.0])
	curtain(pk, kit, Vector3(1.1, 0, -4.02), Vector3(-1.1, 0, -4.02), 6.0, 26.5, Vector3(0, 0, -1), 2.2, [9.0, 12.0, 15.0, 18.0, 21.0, 24.0])
	# Orange fins on the front chamfers.
	for sx in [-1.0, 1.0]:
		var a := Vector2(sx * 2.1, 3.0)
		var b := Vector2(sx * 3.5, 1.6)
		var m: Vector2 = (a + b) * 0.5
		var out: Vector2 = Vector2(sx, 1.0).normalized()
		pk.beam(kit, "alu", Vector3(m.x, 5.6, m.y) + Vector3(out.x, 0, out.y) * 0.25, Vector3(m.x, 27.0, m.y) + Vector3(out.x, 0, out.y) * 0.25,
				0.12, 0.5, ORANGE, Vector3(b.x - a.x, 0, b.y - a.y))
	# The skirt flaring from the shaft to the cab.
	var skirt_lo: Array = chamfered(Vector2(0, -0.5), 7.2, 7.2, 1.45)
	var cab_r := 7.0
	var oct: Array = ngon(8, cab_r, Vector2(0, -0.5))
	# Map the chamfered square's eight corners onto the octagon's: both start at the -z side.
	var oct_aligned: Array = []
	for p in oct:
		oct_aligned.append(p)
	oct_aligned.sort_custom(func(a: Vector2, b: Vector2) -> bool: return atan2(a.y + 0.5, a.x) < atan2(b.y + 0.5, b.x))
	var sq_sorted: Array = skirt_lo.duplicate()
	sq_sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return atan2(a.y + 0.5, a.x) < atan2(b.y + 0.5, b.x))
	ring(pk, kit, "alu", sq_sorted, 26.9, oct_aligned, TOWER_CAB_Y - 0.4, NAVY)
	prism(pk, kit, "alu", ngon(8, cab_r + 0.1, Vector2(0, -0.5)), TOWER_CAB_Y - 0.4, TOWER_CAB_Y + 0.4, WHITE)
	# The cab: panes leaning out, mullions on the corners, a sill band.
	var y0 := TOWER_CAB_Y + 0.4
	var y1 := TOWER_CAB_Y + 4.0
	var lo: Array = ngon(8, cab_r - 0.3, Vector2(0, -0.5))
	var hi: Array = ngon(8, cab_r + 0.35, Vector2(0, -0.5))
	ring(pk, kit, "pane", lo, y0, hi, y1, Color(0.10, 0.18, 0.24, 1.0))
	for i in 8:
		var a: Vector2 = lo[i]
		var b: Vector2 = hi[i]
		var o := Vector3(a.x, 0, a.y + 0.5).normalized() * 0.06
		pk.beam(kit, "alu", Vector3(a.x, y0, a.y) + o, Vector3(b.x, y1, b.y) + o, 0.14, 0.12, FRAME)
	# The cab's roof: a slab overhanging, a white fascia with the orange line, a railing round its top.
	prism(pk, kit, "alu", ngon(8, cab_r + 1.0, Vector2(0, -0.5)), y1, y1 + 0.7, WHITE)
	var band_lo: Array = ngon(8, cab_r + 1.02, Vector2(0, -0.5))
	ring(pk, kit, "glow", band_lo, y1 + 0.28, band_lo, y1 + 0.38, ORANGE)
	var rail: Array = ngon(8, cab_r + 0.7, Vector2(0, -0.5))
	for i in 8:
		var a: Vector2 = rail[i]
		var b: Vector2 = rail[(i + 1) % 8]
		tube_rail(pk, kit, Vector3(a.x, y1 + 0.7, a.y), Vector3(b.x, y1 + 0.7, b.y), 1.05)
	# The turntable for the logo, and a stand of aerials, a beacon.
	var top := Vector3(0, y1 + 0.7, -0.5)
	pk.lathe(kit, "steel", top, [Vector2(0, 0), Vector2(2.6, 0), Vector2(2.6, 0.5), Vector2(2.3, 0.7), Vector2(0, 0.7)], 24, FRAME)
	pk.lathe(kit, "glow", top + Vector3(0, 0.5, 0), [Vector2(2.61, 0.0), Vector2(2.62, 0.0), Vector2(2.62, 0.08), Vector2(2.61, 0.08)], 24, ORANGE)
	# The post the logo turns on, with a collar at its foot.
	pk.lathe(kit, "metal", Vector3(0, TOWER_TOP, -0.5), [Vector2(0, 0), Vector2(0.7, 0), Vector2(0.7, 0.25), Vector2(0.36, 0.4),
			Vector2(0.32, TOWER_LOGO_Y - TOWER_TOP + 0.3), Vector2(0, TOWER_LOGO_Y - TOWER_TOP + 0.3)], 16, Color(0.78, 0.80, 0.82))
	for ax in [Vector3(-4.6, 0, -2.5), Vector3(4.4, 0, -3.2)]:
		var base: Vector3 = top + ax
		pk.tube(kit, "metal", base, base + Vector3(0, 6.0, 0), 0.08, 0.03, 6, GREY)
		pk.beam(kit, "metal", base + Vector3(-0.7, 4.2, 0), base + Vector3(0.7, 4.2, 0), 0.03, 0.03, GREY)
		pk.tube(kit, "glow", base + Vector3(0, 6.0, 0), base + Vector3(0, 6.2, 0), 0.08, 0.08, 8, Color(1.0, 0.12, 0.08))
	# A radar dome on a short tripod.
	var rd := top + Vector3(4.5, 0, 2.2)
	for k in 3:
		var ang: float = float(k) * TAU / 3.0
		pk.tube(kit, "steel", rd + Vector3(cos(ang), 0, sin(ang)) * 0.5, rd + Vector3(0, 1.2, 0), 0.04, 0.04, 6, GREY)
	pk.lathe(kit, "plastic", rd + Vector3(0, 1.2, 0), [Vector2(0, 0), Vector2(0.65, 0), Vector2(0.6, 0.35), Vector2(0.4, 0.6), Vector2(0, 0.7)], 16, WHITE)


# ======================================================================================
#  The workshop hangar
# ======================================================================================

## The Tech Centre: a barrel-roofed steel shed (24 x 30m, the eaves at 6.5m, 3.5m of rise) clad in ribbed metal over a
## concrete plinth, big sliding doors in its front gable (one leaf slid back, the bay inside lit), glazing over them,
## the name on a navy band, ridge vents, a lean-to office along its east side.
static func workshop(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hw := 12.0
	var hd := 15.0
	var eave := 6.5
	var rise := 3.5
	var rr: float = (hw * hw + rise * rise) / (2.0 * rise)
	var cy: float = eave + rise - rr
	var arc := func(x: float) -> float: return cy + sqrt(maxf(rr * rr - x * x, 0.0))
	var segs := 14
	blk(pk, kit, "concrete", Vector3(-hw - 0.3, -0.4, -hd - 0.3), Vector3(hw + 0.3, 0.12, hd + 0.3), CONC)
	var clad := Color(0.78, 0.80, 0.82)
	# Side walls: a navy plinth, ribbed cladding, a ribbon of glazing high up.
	for sx in [-1.0, 1.0]:
		var x: float = sx * hw
		var out := Vector3(sx, 0, 0)
		var a := Vector3(x, 0, -hd if sx > 0 else hd)
		var b := Vector3(x, 0, hd if sx > 0 else -hd)
		blk(pk, kit, "concrete", Vector3(x - 0.2, 0.0, -hd), Vector3(x + 0.2, 1.2, hd), CONC)
		_w(pk, kit, "clad", a, b, 1.2, 4.2, clad, out)
		curtain(pk, kit, a + out * 0.02, b + out * 0.02, 4.2, 5.4, out, 2.5)
		_w(pk, kit, "clad", a, b, 5.4, eave, clad, out)
	# The roof: arc segments of standing seam, a darker underside, eaves gutters, barge trims along the gables.
	for i in segs:
		var x0: float = lerpf(-hw - 0.3, hw + 0.3, float(i) / float(segs))
		var x1: float = lerpf(-hw - 0.3, hw + 0.3, float(i + 1) / float(segs))
		var y0: float = arc.call(clampf(x0, -hw, hw)) + (0.0 if absf(x0) <= hw else -0.15)
		var y1: float = arc.call(clampf(x1, -hw, hw)) + (0.0 if absf(x1) <= hw else -0.15)
		var nrm: Vector3 = Vector3(x0 - x1, 0, 0).cross(Vector3(0, 0, 1)).normalized()
		nrm = Vector3(-(y1 - y0), x1 - x0, 0).normalized()
		var sl: float = Vector2(x1 - x0, y1 - y0).length()
		var s0: float = float(i) * sl
		var p := [Vector3(x0, y0, hd + 0.4), Vector3(x0, y0, -hd - 0.4), Vector3(x1, y1, -hd - 0.4), Vector3(x1, y1, hd + 0.4)]
		pk.quad(kit, "zinc", p, nrm, Color(0.55, 0.58, 0.62), [Vector2(0, s0) * uvk, Vector2(hd * 2 + 0.8, s0) * uvk,
				Vector2(hd * 2 + 0.8, s0 + sl) * uvk, Vector2(0, s0 + sl) * uvk])
		var dn := Vector3(0, -0.06, 0)
		pk.quad(kit, "alu", [p[0] + dn, p[1] + dn, p[2] + dn, p[3] + dn], -nrm, Color(0.36, 0.38, 0.40))
		for zz in [hd + 0.42, -hd - 0.42]:
			pk.beam(kit, "alu", Vector3(x0, y0 - 0.1, zz), Vector3(x1, y1 - 0.1, zz), 0.1, 0.3, NAVY, Vector3(0, 0, 1))
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "alu", Vector3(sx * (hw + 0.4), eave - 0.25, -hd - 0.4), Vector3(sx * (hw + 0.4), eave - 0.25, hd + 0.4), 0.18, 0.16, GREY, Vector3.UP)
		for zz in [-hd + 0.3, hd - 0.3]:
			pk.tube(kit, "metal", Vector3(sx * (hw + 0.4), eave - 0.3, zz), Vector3(sx * (hw + 0.4), 0.12, zz), 0.06, 0.06, 8, GREY)
	# Ridge ventilators.
	for zz in [-9.0, 0.0, 9.0]:
		var ry: float = eave + rise
		box_at(pk, kit, "alu", Vector3(0, ry + 0.35, zz), Basis(), Vector3(1.6, 0.7, 2.4), Color(0.70, 0.72, 0.74))
		box_at(pk, kit, "alu", Vector3(0, ry + 0.75, zz), Basis(), Vector3(2.0, 0.12, 2.8), Color(0.60, 0.62, 0.64))
	# The gables.
	for gz in [hd, -hd]:
		var out := Vector3(0, 0, signf(gz))
		var front: bool = gz > 0.0
		# The gable above the band, segment by segment up to the arc.
		for i in segs:
			var x0: float = lerpf(-hw, hw, float(i) / float(segs))
			var x1: float = lerpf(-hw, hw, float(i + 1) / float(segs))
			var pts := [Vector3(x0, 6.45, gz), Vector3(x1, 6.45, gz), Vector3(x1, arc.call(x1), gz), Vector3(x0, arc.call(x0), gz)]
			pk.quad(kit, "clad", pts, out, clad, [Vector2(x0, 6.45) * uvk, Vector2(x1, 6.45) * uvk, Vector2(x1, arc.call(x1)) * uvk,
					Vector2(x0, arc.call(x0)) * uvk])
		blk(pk, kit, "concrete", Vector3(-hw, 0.0, gz - 0.2), Vector3(-8.2, 1.2, gz + 0.2), CONC)
		blk(pk, kit, "concrete", Vector3(8.2, 0.0, gz - 0.2), Vector3(hw, 1.2, gz + 0.2), CONC)
		_w(pk, kit, "clad", Vector3(-hw if front else -8.2, 0, gz), Vector3(-8.2 if front else -hw, 0, gz), 1.2, 6.45, clad, out)
		_w(pk, kit, "clad", Vector3(8.2 if front else hw, 0, gz), Vector3(hw if front else 8.2, 0, gz), 1.2, 6.45, clad, out)
		var o: Vector3 = out * 0.05
		curtain(pk, kit, Vector3(-5.0 if front else 5.0, 0, gz) + o, Vector3(5.0 if front else -5.0, 0, gz) + o, 7.9, 9.3, out, 1.25)
		if front:
			# The navy band over the doors with the name, the door track.
			blk(pk, kit, "alu", Vector3(-hw, 6.3, gz), Vector3(hw, 7.6, gz + 0.12), NAVY)
			blk(pk, kit, "glow", Vector3(-hw, 6.38, gz + 0.12), Vector3(hw, 6.46, gz + 0.14), ORANGE)
			labels.append(["TECH CENTRE", Vector3(-3.5, 7.05, gz + 0.14), Vector3(0, 0, 1), 0.55, WHITE, 9.0])
			logo_panel(pk, kit, Vector3(6.2, 6.98, gz + 0.12), Vector3(0, 0, 1), 3.2)
			blk(pk, kit, "steel", Vector3(-8.4, 6.0, gz), Vector3(16.4, 6.3, gz + 0.35), FRAME)
			# Doors: the east leaf closed over x 0..8, the west leaf slid back over the cladding east of the opening.
			_slide_leaf(pk, kit, 0.0, 8.2, gz + 0.22)
			_slide_leaf(pk, kit, 8.2, 16.2, gz + 0.42)
			_open_bay(pk, kit, -8.2, 0.0, gz)
		else:
			_w(pk, kit, "clad", Vector3(8.2, 0, gz), Vector3(-8.2, 0, gz), 1.2, 6.45, clad, out)
			blk(pk, kit, "concrete", Vector3(-8.2, 0.0, gz - 0.2), Vector3(8.2, 1.2, gz + 0.2), CONC)
			glass_door(pk, kit, Vector3(-3.0, 0.12, gz - 0.22), out, 1.1, 2.3)
			blk(pk, kit, "alu", Vector3(-3.8, 2.6, gz - 1.4), Vector3(-2.2, 2.75, gz), WHITE)
	# The lean-to office along the east side.
	var ox0: float = hw
	var ox1: float = hw + 6.0
	var oz0 := -2.0
	var oz1 := 12.0
	blk(pk, kit, "concrete", Vector3(ox0, -0.4, oz0 - 0.3), Vector3(ox1 + 0.3, 0.12, oz1 + 0.3), CONC)
	_w(pk, kit, "plaster", Vector3(ox1, 0, oz0), Vector3(ox1, 0, oz1), 0.12, 3.7, WHITE, Vector3(1, 0, 0))
	_w(pk, kit, "plaster", Vector3(ox1, 0, oz1), Vector3(ox0, 0, oz1), 0.12, 3.7, WHITE, Vector3(0, 0, 1))
	_w(pk, kit, "plaster", Vector3(ox0, 0, oz0), Vector3(ox1, 0, oz0), 0.12, 3.7, WHITE, Vector3(0, 0, -1))
	for gzz in [oz0, oz1]:
		var gn := Vector3(0, 0, signf(gzz - 5.0))
		pk.tri(kit, "plaster", Vector3(ox0, 3.7, gzz), Vector3(ox1, 3.7, gzz), Vector3(ox0, 4.2, gzz), gn, gn, gn, WHITE, gn,
				Vector2(0, 3.7) * uvk, Vector2(ox1 - ox0, 3.7) * uvk, Vector2(0, 4.2) * uvk)
	for wz in [oz0 + 2.0, oz0 + 6.5, oz0 + 11.0]:
		curtain(pk, kit, Vector3(ox1 + 0.03, 0, wz - 1.4), Vector3(ox1 + 0.03, 0, wz + 1.4), 1.0, 2.7, Vector3(1, 0, 0), 0.9)
	glass_door(pk, kit, Vector3(ox0 + 3.0, 0.12, oz1 + 0.02), Vector3(0, 0, 1), 1.2, 2.3)
	curtain(pk, kit, Vector3(ox0 + 4.2, 0, oz1 + 0.03), Vector3(ox1 - 0.3, 0, oz1 + 0.03), 1.0, 2.7, Vector3(0, 0, 1), 0.9)
	var r0 := 4.2
	var r1 := 3.7
	roof(pk, kit, "zinc", Vector3(ox1 + 0.4, r1, oz1 + 0.4), Vector3(ox1 + 0.4, r1, oz0 - 0.4), Vector3(ox0, r0, oz0 - 0.4), Vector3(ox0, r0, oz1 + 0.4),
			Color(0.32, 0.34, 0.38), Vector3(r0 - r1, ox1 + 0.4 - ox0, 0).normalized())
	labels.append(["ENGINEERS", Vector3(ox0 + 3.0, 2.85, oz1 + 0.05), Vector3(0, 0, 1), 0.22, NAVY, 2.4])


## A sliding door leaf from x0 to x1 at z: ribbed panels in a frame, a strip of windows.
static func _slide_leaf(pk: PropKit, kit: Dictionary, x0: float, x1: float, z: float) -> void:
	_w(pk, kit, "clad", Vector3(x0, 0, z), Vector3(x1, 0, z), 0.12, 6.0, Color(0.88, 0.89, 0.90), Vector3(0, 0, 1))
	for x in [x0, x1]:
		pk.beam(kit, "steel", Vector3(x, 0.12, z + 0.04), Vector3(x, 6.0, z + 0.04), 0.16, 0.08, NAVY, Vector3.RIGHT)
	for y in [0.15, 3.0, 5.95]:
		pk.beam(kit, "steel", Vector3(x0, y, z + 0.04), Vector3(x1, y, z + 0.04), 0.16, 0.08, NAVY, Vector3.UP)
	curtain(pk, kit, Vector3(x0 + 0.5, 0, z + 0.03), Vector3(x1 - 0.5, 0, z + 0.03), 3.6, 4.4, Vector3(0, 0, 1), 1.2)
	blk(pk, kit, "glow", Vector3(x0 + 0.3, 1.6, z + 0.06), Vector3(x1 - 0.3, 1.75, z + 0.09), ORANGE)


## The lit bay behind the open door leaf: floor, walls, ceiling, a lift with a car frame on it, benches and tyres.
static func _open_bay(pk: PropKit, kit: Dictionary, x0: float, x1: float, gz: float) -> void:
	var back: float = gz - 12.0
	var h := 6.0
	blk(pk, kit, "epoxy", Vector3(x0, 0.1, back), Vector3(x1, 0.13, gz), Color(0.38, 0.42, 0.46))
	_w(pk, kit, "alu", Vector3(x0, 0, back), Vector3(x1, 0, back), 0.1, h, Color(0.86, 0.87, 0.88), Vector3(0, 0, 1))
	_w(pk, kit, "alu", Vector3(x0, 0, gz), Vector3(x0, 0, back), 0.1, h, Color(0.80, 0.81, 0.82), Vector3(1, 0, 0))
	_w(pk, kit, "alu", Vector3(x1, 0, back), Vector3(x1, 0, gz), 0.1, h, Color(0.80, 0.81, 0.82), Vector3(-1, 0, 0))
	pk.quad(kit, "alu", [Vector3(x0, h, back), Vector3(x1, h, back), Vector3(x1, h, gz), Vector3(x0, h, gz)], Vector3.DOWN, Color(0.6, 0.62, 0.64))
	for lx in [x0 + 2.0, (x0 + x1) * 0.5, x1 - 2.0]:
		blk(pk, kit, "glow", Vector3(lx - 0.1, h - 0.08, back + 1.0), Vector3(lx + 0.1, h - 0.01, gz - 1.0), Color(0.95, 0.97, 1.0))
	logo_panel(pk, kit, Vector3((x0 + x1) * 0.5, 3.6, back), Vector3(0, 0, 1), 5.0)
	for sx in [x0 + 1.2, x1 - 1.2]:
		blk(pk, kit, "paint", Vector3(sx - 0.2, 0.1, gz - 7.5), Vector3(sx + 0.2, 3.6, gz - 7.0), Color(0.12, 0.28, 0.62))
	tool_chest(pk, kit, Vector3(x0 + 1.5, 0.13, back + 0.7), Vector3(0, 0, 1))
	tool_chest(pk, kit, Vector3(x1 - 1.5, 0.13, back + 0.7), Vector3(0, 0, 1), Color(0.95, 0.45, 0.07))
	tyre_stack(pk, kit, Vector3(x1 - 0.8, 0.13, gz - 2.5), 5, 0.3)
	tyre_stack(pk, kit, Vector3(x1 - 0.8, 0.13, gz - 3.4), 4, 0.6)


# ======================================================================================
#  The engineering office
# ======================================================================================

## A three-storey office: ribbons of glass between white spandrels, timber fins in front of the glass, an entrance
## under a canopy at its west end, a glazed stair tower at its east end, plant and solar panels on the roof.
static func office(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hw := 13.0
	var hd := 7.0
	var fl := 3.6
	var floors := 3
	var top: float = fl * floors
	blk(pk, kit, "concrete", Vector3(-hw - 0.2, -0.4, -hd - 0.2), Vector3(hw + 0.2, 0.15, hd + 0.2), CONC)
	# Spandrels and floor bands all round, glazing between.
	for f in floors + 1:
		var y: float = fl * float(f)
		var y_lo: float = 0.0 if f == 0 else y - 0.35
		var y_hi: float = y + 0.6 if f < floors else top + 1.0
		blk(pk, kit, "alu", Vector3(-hw, y_lo, -hd), Vector3(hw, y_hi, hd), WHITE if f > 0 else CONC)
	for f in floors:
		var y0: float = fl * float(f) + 0.6
		var y1: float = fl * float(f + 1) - 0.35
		curtain(pk, kit, Vector3(-hw, 0, hd), Vector3(hw, 0, hd), y0, y1, Vector3(0, 0, 1), 1.5)
		curtain(pk, kit, Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd), y0, y1, Vector3(0, 0, -1), 1.5)
		curtain(pk, kit, Vector3(-hw, 0, -hd), Vector3(-hw, 0, hd), y0, y1, Vector3(-1, 0, 0), 1.5)
		curtain(pk, kit, Vector3(hw, 0, hd), Vector3(hw, 0, -hd), y0, y1, Vector3(1, 0, 0), 1.5)
	# Timber fins across the front, standing off it.
	var x := -hw + 0.75
	while x < hw:
		var fy: float = 3.6 if x > -hw + 0.5 and x < -hw + 7.5 else 0.6
		pk.beam(kit, "timber", Vector3(x, fy, hd + 0.45), Vector3(x, top - 0.25, hd + 0.45), 0.08, 0.6, Color(0.66, 0.48, 0.32), Vector3.RIGHT)
		x += 1.5
	pk.beam(kit, "alu", Vector3(-hw, top + 0.1, hd + 0.45), Vector3(hw, top + 0.1, hd + 0.45), 0.7, 0.7, WHITE, Vector3.UP)
	# The name along the parapet.
	blk(pk, kit, "glow", Vector3(-hw, top + 0.62, hd), Vector3(hw, top + 0.7, hd + 0.02), ORANGE)
	labels.append(["ENGINEERING", Vector3(-hw * 0.4, top + 0.1, hd + 0.81), Vector3(0, 0, 1), 0.45, NAVY, 10.0])
	logo_panel(pk, kit, Vector3(hw * 0.55, top + 0.1, hd + 0.8), Vector3(0, 0, 1), 1.6)
	# The entrance: a canopy on columns, doors.
	blk(pk, kit, "alu", Vector3(-hw + 1.0, 3.2, hd), Vector3(-hw + 7.0, 3.5, hd + 3.6), NAVY)
	blk(pk, kit, "glow", Vector3(-hw + 1.0, 3.25, hd + 3.6), Vector3(-hw + 7.0, 3.32, hd + 3.62), ORANGE)
	for cx in [-hw + 1.4, -hw + 6.6]:
		pk.tube(kit, "steel", Vector3(cx, 0.15, hd + 3.2), Vector3(cx, 3.2, hd + 3.2), 0.1, 0.1, 10, WHITE)
	glass_door(pk, kit, Vector3(-hw + 4.0, 0.15, hd + 0.06), Vector3(0, 0, 1), 2.4, 2.6)
	# The stair tower at the east end, glass all round.
	var sx0: float = hw
	var sx1: float = hw + 4.0
	var sz0 := -3.0
	var sz1 := 3.0
	var st_top: float = top + 1.8
	curtain(pk, kit, Vector3(sx1, 0, sz1), Vector3(sx1, 0, sz0), 0.15, st_top, Vector3(1, 0, 0), 1.0, [3.6, 7.2, 10.8])
	curtain(pk, kit, Vector3(sx0, 0, sz1), Vector3(sx1, 0, sz1), 0.15, st_top, Vector3(0, 0, 1), 1.0, [3.6, 7.2, 10.8])
	curtain(pk, kit, Vector3(sx1, 0, sz0), Vector3(sx0, 0, sz0), 0.15, st_top, Vector3(0, 0, -1), 1.0, [3.6, 7.2, 10.8])
	blk(pk, kit, "alu", Vector3(sx0, st_top, sz0 - 0.3), Vector3(sx1 + 0.3, st_top + 0.4, sz1 + 0.3), WHITE)
	blk(pk, kit, "concrete", Vector3(sx0, -0.4, sz0), Vector3(sx1, 0.15, sz1), CONC)
	# The roof: plant and solar panels.
	plant_unit(pk, kit, Vector3(-4.0, top + 0.25, -3.0), Vector3(4.0, 1.6, 2.0))
	plant_unit(pk, kit, Vector3(2.5, top + 0.25, -3.5), Vector3(2.6, 1.3, 1.6), 0.0)
	for i in 6:
		var px: float = -hw + 2.0 + float(i) * 3.6
		if px > -7.0 and px < 5.5:
			continue
		var b := Basis(Vector3.RIGHT, deg_to_rad(-25.0))
		box_at(pk, kit, "gloss", Vector3(px, top + 0.9, 2.5), b, Vector3(3.2, 0.05, 2.0), Color(0.08, 0.12, 0.22))
		for lx in [-1.4, 1.4]:
			pk.beam(kit, "steel", Vector3(px + lx, top + 0.25, 3.4), Vector3(px + lx, top + 0.6, 3.4), 0.05, 0.05, GREY)
			pk.beam(kit, "steel", Vector3(px + lx, top + 0.25, 1.6), Vector3(px + lx, top + 1.3, 1.6), 0.05, 0.05, GREY)


# ======================================================================================
#  Small things
# ======================================================================================

## A floodlight mast: a tapered pole on a base plate, a cross-arm with two LED heads.
static func light_mast(pk: PropKit, kit: Dictionary, h := 9.0) -> void:
	pk.lathe(kit, "concrete", Vector3.ZERO, [Vector2(0, -0.3), Vector2(0.45, -0.3), Vector2(0.45, 0.25), Vector2(0, 0.25)], 12, CONC)
	pk.tube(kit, "metal", Vector3(0, 0.25, 0), Vector3(0, h, 0), 0.13, 0.07, 10, Color(0.78, 0.80, 0.82))
	pk.beam(kit, "metal", Vector3(-0.9, h, 0), Vector3(0.9, h, 0), 0.08, 0.08, Color(0.78, 0.80, 0.82))
	for sx in [-0.8, 0.8]:
		box_at(pk, kit, "alu", Vector3(sx, h - 0.12, 0.15), Basis(Vector3.RIGHT, 0.35), Vector3(0.6, 0.12, 0.45), DARK)
		box_at(pk, kit, "glow", Vector3(sx, h - 0.19, 0.17), Basis(Vector3.RIGHT, 0.35), Vector3(0.5, 0.01, 0.36), Color(0.95, 0.96, 1.0))


## A bollard with a reflective band.
static func bollard(pk: PropKit, kit: Dictionary) -> void:
	pk.tube(kit, "metal", Vector3.ZERO, Vector3(0, 0.95, 0), 0.1, 0.1, 10, Color(0.20, 0.22, 0.24))
	pk.tube(kit, "glow", Vector3(0, 0.75, 0), Vector3(0, 0.82, 0), 0.105, 0.105, 10, ORANGE, false)
