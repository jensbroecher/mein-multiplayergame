extends RefCounted
## Marina Nights' set pieces (regenerate_marina_nights.gd), built through a PropKit at life size (y up, the front toward
## -z) unless said otherwise, and grown by the caller: the fountain on its steps in the plaza, planters, lit bollards,
## café tables under parasols, benches, lantern posts, the promenade's kiosks, and the ferris wheel's parts (in metres).
## On top of ArabianKit's keys (its materials, shared), the keys here: "marble" (polished stone in vertex colour),
## "tile" (glazed tiles), "soil", "led" (light in the vertex colour, marina_led.gdshader: blooms), "ledchase" (the same,
## its colours drifting along the strip, UV.x metres along it), "glasslit" (a lit cabin's or shop's glass, softer),
## "paintsteel", and the glass tube's "ribsteel", "ribled", "tubeglass".

const PropKit = preload("res://PropKit.gd")
const ArabianKit = preload("res://ArabianKit.gd")
const CampKit = preload("res://CampKit.gd")
const ShipKit = preload("res://ShipKit.gd")

static var _mats := {}

const MARBLE := Color(0.90, 0.87, 0.82)
const MARBLE_DARK := Color(0.40, 0.38, 0.36)
const GOLD := Color(0.86, 0.66, 0.28)
const STEEL := Color(0.80, 0.82, 0.85)
const WARM := Color(1.0, 0.80, 0.52)


static func make_material(key: String) -> Material:
	match key:
		"marble":
			var m := CampKit.make_material("gloss")
			m.roughness = 0.28
			m.metallic = 0.0
			return m
		"tile":
			var t := CampKit.make_material("gloss")
			t.roughness = 0.12
			return t
		"soil":
			var s := CampKit.make_material("matte")
			return s
		"led":
			var l := ShaderMaterial.new()
			l.shader = load("res://marina_led.gdshader")
			l.set_shader_parameter("energy", 3.2)
			return l
		"ledchase":
			var c := ShaderMaterial.new()
			c.shader = load("res://marina_led.gdshader")
			c.set_shader_parameter("mode", 1)
			c.set_shader_parameter("energy", 3.6)
			return c
		"lamp":
			# ArabianKit's lamps (lanterns, lamp lenses, the dhows' and the yachts' lights) glowing in their vertex colour.
			# CampKit's "lamp" (emission MULTIPLY with no emission texture, whose default is black) gives off no light.
			var lm := ShaderMaterial.new()
			lm.shader = load("res://marina_led.gdshader")
			lm.set_shader_parameter("energy", 2.4)
			return lm
		"glasslit":
			var g := ShaderMaterial.new()
			g.shader = load("res://marina_led.gdshader")
			g.set_shader_parameter("energy", 1.3)
			return g
		"paintsteel":
			var p := CampKit.make_material("steel")
			p.roughness = 0.42
			return p
		"hull":
			var hm := CampKit.make_material("gloss")
			hm.roughness = 0.16
			hm.metallic = 0.12
			hm.clearcoat_enabled = true
			hm.clearcoat = 0.6
			return hm
		"teak":
			var tk := CampKit.make_material("wood")
			tk.roughness = 0.62
			return tk
		"yglass":
			# A yacht's glazing: opaque, dark, mirror-like (no sorting against the sea).
			var yg := CampKit.make_material("gloss")
			yg.metallic = 0.75
			yg.roughness = 0.04
			return yg
		"chrome":
			return CampKit.make_material("chrome")
		"ribsteel":
			var rs := ShaderMaterial.new()
			rs.shader = load("res://marina_rib.gdshader")
			return rs
		"ribled":
			var rl := ShaderMaterial.new()
			rl.shader = load("res://marina_led.gdshader")
			rl.set_shader_parameter("energy", 2.8)
			rl.set_shader_parameter("cam_fade_near", 2.5)
			rl.set_shader_parameter("cam_fade_far", 6.0)
			return rl
		"tubeglass":
			var tgm := ShaderMaterial.new()
			tgm.shader = load("res://marina_glass.gdshader")
			tgm.render_priority = 2
			return tgm
		"lattice":
			# The covered arcade's vaults and screens: mashrabiya cut through, backlit (UV in metres).
			var lt := ShaderMaterial.new()
			lt.shader = load("res://marina_lattice.gdshader")
			lt.set_shader_parameter("cell", 2.4)
			lt.set_shader_parameter("glow", 1.5)
			return lt
		"lattice_big":
			# Burj al-Fanous's lantern: bigger stars.
			var lb := ShaderMaterial.new()
			lb.shader = load("res://marina_lattice.gdshader")
			# Dark burnished bars against the bright core behind them (the light through the holes), their edges
			# catching it.
			lb.set_shader_parameter("cell", 8.0)
			lb.set_shader_parameter("bar", 0.12)
			lb.set_shader_parameter("stone", Color(0.42, 0.30, 0.15))
			lb.set_shader_parameter("glow", 0.55)
			lb.set_shader_parameter("glow_base", 0.04)
			lb.set_shader_parameter("min_px", 2.5)
			return lb
	return ArabianKit.make_material(key)


static func new_kit(scale: float) -> PropKit:
	var pk := ArabianKit.new_kit(scale)
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	return pk


static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	return ArabianKit.commit(pk, kit)


# ======================================================================================
#  The fountain plaza
# ======================================================================================

## The plaza's fountain, its middle at the origin on the ground: three marble steps up from `r_out` to a basin of
## blue tiles behind a moulded rim, blue lights in a ring under the water, and in the middle a column with three
## bowls (their lips at the heights and radii FountainShow's sheets fall from: [2.2, 6.0], [5.8, 3.8], [9.4, 2.2] over
## the basin's floor, which lies `floor_y` up). Returns the water's height (FountainShow.water_y) and radius.
static func plaza_fountain(pk: PropKit, kit: Dictionary, r_out: float) -> Vector2:
	var step_w := 1.1
	var step_h := 0.3
	var prof: Array = [Vector2(r_out, -0.3), Vector2(r_out, step_h)]
	for i in range(1, 3):
		prof.append(Vector2(r_out - step_w * i, step_h * i))
		prof.append(Vector2(r_out - step_w * i, step_h * (i + 1)))
	var top: float = step_h * 3.0
	var rw: float = r_out - step_w * 3.0          # the rim wall's outside
	prof.append(Vector2(rw, top))
	pk.lathe(kit, "marble", Vector3.ZERO, prof, 96, MARBLE)
	# Gold inlay along each step's nosing.
	for i in range(3):
		var rr: float = r_out - step_w * i
		pk.lathe(kit, "metal", Vector3.ZERO, [Vector2(rr + 0.012, step_h * (i + 1) - 0.06), Vector2(rr + 0.012, step_h * (i + 1) + 0.004)], 96, GOLD)
	# The rim: a moulded coping over the wall, its inside face down to the floor.
	var floor_y: float = top - 0.35
	var water_y: float = top + 0.35
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(rw, top), Vector2(rw, top + 0.45), Vector2(rw + 0.12, top + 0.52), Vector2(rw + 0.12, top + 0.66),
			Vector2(rw - 0.75, top + 0.7), Vector2(rw - 0.8, top + 0.62)], 96, MARBLE)
	var ri: float = rw - 0.8
	pk.lathe(kit, "tile", Vector3.ZERO, [Vector2(ri, top + 0.62), Vector2(ri, floor_y)], 96, Color(0.10, 0.34, 0.55))
	pk.lathe(kit, "tile", Vector3.ZERO, [Vector2(ri, floor_y), Vector2(0.0, floor_y)], 96, Color(0.08, 0.26, 0.42))
	# A ring of blue lights under the water, round the inside of the wall, and a white ring round the column.
	for k in range(36):
		var a: float = TAU * k / 36.0
		pk.box(kit, "led", Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * (ri - 0.08) + Vector3(0, floor_y + 0.35, 0)),
				Vector3(0.1, 0.18, 0.6), Color(0.35, 0.65, 1.0))
	for k in range(16):
		var a3: float = TAU * k / 16.0
		pk.box(kit, "led", Transform3D(Basis(Vector3.UP, -a3), Vector3(cos(a3), 0, sin(a3)) * 3.2 + Vector3(0, floor_y + 0.05, 0)),
				Vector3(0.4, 0.06, 0.4), Color(0.8, 0.9, 1.0))
	# The column and the three bowls, from the basin's floor.
	var f := Vector3(0, floor_y, 0)
	pk.lathe(kit, "marble", f, [Vector2(2.8, 0.0), Vector2(2.6, 0.7), Vector2(1.3, 1.3), Vector2(0.95, 2.2), Vector2(0.85, 6.5), Vector2(0.62, 11.0)], 28, MARBLE)
	for t in [[2.2, 6.0, 0.8], [5.8, 3.8, 0.6], [9.4, 2.2, 0.45]]:
		var y: float = t[0]
		var br: float = t[1]
		var dep: float = t[2]
		pk.lathe(kit, "marble", f + Vector3(0, y, 0), [Vector2(0.6, -dep), Vector2(br * 0.7, -dep * 0.6), Vector2(br, 0.0), Vector2(br + 0.15, 0.12),
				Vector2(br - 0.05, 0.16), Vector2(0.0, 0.0)], 40, MARBLE)
		pk.lathe(kit, "metal", f + Vector3(0, y, 0), [Vector2(br + 0.16, 0.02), Vector2(br + 0.16, 0.1)], 40, GOLD)
		for k in range(20):
			var a2: float = TAU * k / 20.0
			pk.box(kit, "led", Transform3D(Basis(Vector3.UP, -a2), Vector3(cos(a2), 0, sin(a2)) * (br - 0.15) + f + Vector3(0, y - dep * 0.45, 0)),
					Vector3(0.25, 0.08, 0.25), Color(1.0, 0.9, 0.7))
	pk.lathe(kit, "metal", f + Vector3(0, 11.0, 0), [Vector2(0.0, 0.0), Vector2(0.55, 0.3), Vector2(0.32, 1.0), Vector2(0.12, 1.7), Vector2(0.0, 2.4)], 16, ArabianKit.BRASS)
	return Vector2(water_y, ri - 0.05)


## A raised stone planter `r` across its flats (octagonal), `h` tall, soil at its top for a palm; a lit band round
## its foot.
static func planter(pk: PropKit, kit: Dictionary, r: float, h: float) -> void:
	var sand := Color(0.80, 0.72, 0.60)
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(r, -0.2), Vector2(r, h), Vector2(r - 0.28, h), Vector2(r - 0.28, h - 0.12)], 8, sand, true)
	pk.lathe(kit, "soil", Vector3.ZERO, [Vector2(r - 0.28, h - 0.12), Vector2(0.0, h - 0.1)], 8, Color(0.15, 0.11, 0.08), true)
	pk.lathe(kit, "led", Vector3.ZERO, [Vector2(r + 0.02, 0.1), Vector2(r + 0.02, 0.16)], 8, WARM, true)


## A bollard: a stone post with a glowing cap.
static func bollard(pk: PropKit, kit: Dictionary) -> void:
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(0.2, -0.1), Vector2(0.2, 0.12), Vector2(0.15, 0.2), Vector2(0.13, 0.85)], 10, Color(0.82, 0.76, 0.66))
	pk.lathe(kit, "led", Vector3.ZERO, [Vector2(0.13, 0.85), Vector2(0.13, 0.98), Vector2(0.0, 1.02)], 10, WARM)


## A café table under a parasol, with `chairs` chairs round it (facing in) and a candle lantern on it. The parasol's
## canopy in `cloth`, its colour `col`, a light hung under it.
static func cafe_set(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, col: Color, chairs := 4, parasol := true) -> void:
	var dark := Color(0.12, 0.12, 0.13)
	pk.tube(kit, "metal", Vector3(0, 0, 0), Vector3(0, 0.72, 0), 0.05, 0.05, 6, dark)
	pk.lathe(kit, "metal", Vector3.ZERO, [Vector2(0.32, 0.0), Vector2(0.3, 0.04), Vector2(0.0, 0.05)], 12, dark)
	pk.lathe(kit, "marble", Vector3(0, 0.72, 0), [Vector2(0.0, 0.0), Vector2(0.42, 0.0), Vector2(0.42, 0.04), Vector2(0.0, 0.04)], 16, Color(0.92, 0.90, 0.86))
	pk.box(kit, "led", Transform3D(Basis(), Vector3(0, 0.84, 0)), Vector3(0.08, 0.14, 0.08), WARM)
	var a0: float = rng.randf() * TAU
	for k in range(chairs):
		var a: float = a0 + TAU * k / float(chairs)
		var o := Vector3(cos(a), 0, sin(a))
		var c: Vector3 = o * 0.72
		var basis := Basis.looking_at(-o, Vector3.UP)
		pk.box(kit, "timber", Transform3D(basis, c + Vector3(0, 0.45, 0)), Vector3(0.44, 0.05, 0.42), ArabianKit.TEAK)
		pk.box(kit, "timber", Transform3D(basis, c + o * 0.2 + Vector3(0, 0.72, 0)), Vector3(0.44, 0.5, 0.04), ArabianKit.TEAK)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var leg: Vector3 = c + basis * Vector3(sx * 0.19, 0, sz * 0.18)
				pk.beam(kit, "metal", leg, leg + Vector3(0, 0.45, 0), 0.03, 0.03, dark)
	if parasol:
		pk.tube(kit, "metal", Vector3(0, 0.76, 0), Vector3(0, 2.5, 0), 0.025, 0.025, 6, Color(0.85, 0.85, 0.82))
		var n := 8
		var rr := 1.35
		for k in range(n):
			var b0: float = TAU * k / n
			var b1: float = TAU * (k + 1) / n
			var e0 := Vector3(cos(b0) * rr, 2.12, sin(b0) * rr)
			var e1 := Vector3(cos(b1) * rr, 2.12, sin(b1) * rr)
			var apex := Vector3(0, 2.55, 0)
			var nn: Vector3 = (e0 - apex).cross(e1 - apex).normalized()
			if nn.y < 0.0:
				nn = -nn
			pk.tri(kit, "awning", apex, e0, e1, nn, nn, nn, col, nn)
			pk.tri(kit, "awning", apex, e1, e0, -nn, -nn, -nn, col.darkened(0.35), -nn)
			# A valance round its edge.
			pk.quad(kit, "cloth", [e0, e1, e1 - Vector3(0, 0.18, 0), e0 - Vector3(0, 0.18, 0)], ((e0 + e1) * 0.5 * Vector3(1, 0, 1)).normalized(), col.lightened(0.1))
		pk.box(kit, "led", Transform3D(Basis(), Vector3(0, 2.05, 0)), Vector3(0.16, 0.12, 0.16), WARM)


## A bench: stone ends, timber slats and a back, facing -z.
static func bench(pk: PropKit, kit: Dictionary, w := 2.0) -> void:
	var stone := Color(0.80, 0.74, 0.64)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "marble", Vector3(sx * w * 0.5 - 0.12, 0.0, -0.25), Vector3(sx * w * 0.5 + 0.12, 0.42, 0.25), stone)
	for k in range(4):
		var z: float = -0.22 + k * 0.13
		pk.box(kit, "timber", Transform3D(Basis(), Vector3(0, 0.45, z)), Vector3(w + 0.1, 0.04, 0.1), ArabianKit.TEAK)
	for k in range(3):
		pk.box(kit, "timber", Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, 0.65 + k * 0.14, 0.27)), Vector3(w + 0.1, 0.09, 0.03), ArabianKit.TEAK)


## A lantern post `h` tall: an octagonal plinth, a fluted shaft, a collar, and an octagonal lantern with pointed
## openings under a little dome and a crescent-free finial (a ball and a spike).
static func lantern_post(pk: PropKit, kit: Dictionary, h := 4.6) -> void:
	var dark := Color(0.10, 0.10, 0.11)
	var sand := Color(0.80, 0.72, 0.60)
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(0.45, -0.1), Vector2(0.45, 0.5), Vector2(0.32, 0.6), Vector2(0.3, 0.9)], 8, sand, true)
	pk.lathe(kit, "metal", Vector3(0, 0.9, 0), [Vector2(0.14, 0.0), Vector2(0.11, h - 1.6), Vector2(0.16, h - 1.5), Vector2(0.16, h - 1.4)], 8, dark, true)
	var ly: float = 0.9 + h - 1.4
	# The lantern: a frame round a glowing core, a dome.
	pk.lathe(kit, "metal", Vector3(0, ly, 0), [Vector2(0.2, 0.0), Vector2(0.34, 0.08), Vector2(0.34, 0.12)], 8, dark, true)
	pk.lathe(kit, "led", Vector3(0, ly + 0.12, 0), [Vector2(0.3, 0.0), Vector2(0.34, 0.55), Vector2(0.0, 0.6)], 8, WARM, true)
	for k in range(8):
		var a: float = TAU * (float(k) + 0.5) / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * 0.35
		pk.beam(kit, "metal", Vector3(0, ly + 0.1, 0) + p, Vector3(0, ly + 0.7, 0) + p * 1.05, 0.04, 0.04, dark)
	pk.lathe(kit, "metal", Vector3(0, ly + 0.68, 0), [Vector2(0.42, 0.0), Vector2(0.38, 0.06), Vector2(0.26, 0.24), Vector2(0.1, 0.38), Vector2(0.0, 0.42)], 8, dark, true)
	pk.lathe(kit, "metal", Vector3(0, ly + 1.1, 0), [Vector2(0.0, 0.0), Vector2(0.08, 0.06), Vector2(0.0, 0.14), Vector2(0.02, 0.2), Vector2(0.0, 0.42)], 8, ArabianKit.BRASS)


## A promenade kiosk: hexagonal, glazed and lit inside, a striped awning round it, a little dome. Faces -z.
static func kiosk(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var r := 1.7
	var h := 2.6
	var col: Color = [Color(0.15, 0.36, 0.44), Color(0.55, 0.16, 0.14), Color(0.20, 0.36, 0.22)][rng.randi() % 3]
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(r + 0.15, -0.1), Vector2(r + 0.15, 0.25), Vector2(0.0, 0.25)], 6, Color(0.78, 0.72, 0.62), true)
	pk.lathe(kit, "glasslit", Vector3(0, 0.25, 0), [Vector2(r - 0.05, 0.9), Vector2(r - 0.05, h - 0.3)], 6, Color(1.0, 0.86, 0.6), true)
	pk.lathe(kit, "painted", Vector3(0, 0.25, 0), [Vector2(r, 0.0), Vector2(r, 0.9), Vector2(r - 0.05, 0.9)], 6, col, true)
	pk.lathe(kit, "painted", Vector3(0, 0.25, 0), [Vector2(r - 0.05, h - 0.3), Vector2(r, h - 0.3), Vector2(r, h)], 6, col, true)
	for k in range(6):
		var a: float = TAU * k / 6.0
		var p := Vector3(cos(a), 0, sin(a)) * r
		pk.beam(kit, "painted", p + Vector3(0, 0.25, 0), p + Vector3(0, h + 0.25, 0), 0.1, 0.1, col.darkened(0.3))
	# The awning: stripes round all six faces.
	for k in range(6):
		var a0: float = TAU * k / 6.0
		var a1: float = TAU * (k + 1) / 6.0
		var e0 := Vector3(cos(a0), 0, sin(a0))
		var e1 := Vector3(cos(a1), 0, sin(a1))
		var stripe: Color = Color(0.95, 0.93, 0.88) if k % 2 == 0 else col
		var p0: Vector3 = e0 * r + Vector3(0, h + 0.25, 0)
		var p1: Vector3 = e1 * r + Vector3(0, h + 0.25, 0)
		var q0: Vector3 = e0 * (r + 0.9) + Vector3(0, h - 0.3, 0)
		var q1: Vector3 = e1 * (r + 0.9) + Vector3(0, h - 0.3, 0)
		var nn: Vector3 = ((e0 + e1) * 0.5 + Vector3(0, 1.5, 0)).normalized()
		pk.panel(kit, "awning", [p0, p1, q1, q0], nn, stripe, stripe.darkened(0.3))
	pk.lathe(kit, "painted", Vector3(0, h + 0.25, 0), [Vector2(r + 0.05, 0.0), Vector2(r * 0.9, 0.35), Vector2(r * 0.55, 0.95), Vector2(0.2, 1.25), Vector2(0.0, 1.3)], 12, Color(0.95, 0.93, 0.88))
	pk.lathe(kit, "metal", Vector3(0, h + 1.55, 0), [Vector2(0.0, 0.0), Vector2(0.08, 0.1), Vector2(0.0, 0.5)], 6, ArabianKit.BRASS)


# ======================================================================================
#  The ferris wheel (in metres)
# ======================================================================================

## The wheel's turning part in its own frame (axle along z through the origin): two rims `rr` across their centre
## line, 3.2m apart, braced between them, LED tubes round their outsides (ledchase), `n` pairs of cable spokes from the
## hub to the rims with lit lines along them, the hub. Its cabins are FerrisWheel.gd's (they stay level).
static func wheel_rotor(pk: PropKit, kit: Dictionary, rr: float, n: int) -> void:
	var segs := n * 2
	for zf in [-1.6, 1.6]:
		for i in range(segs):
			var a0: float = TAU * i / segs
			var a1: float = TAU * (i + 1) / segs
			var p0 := Vector3(cos(a0) * rr, sin(a0) * rr, zf)
			var p1 := Vector3(cos(a1) * rr, sin(a1) * rr, zf)
			pk.tube(kit, "paintsteel", p0, p1, 0.55, 0.55, 8, STEEL, false)
			# A band of LEDs on the rim's face (toward the axle's end, so the wheel's face shows it from afar), UV.x metres
			# round it for the chase.
			var o0 := Vector3(cos(a0), sin(a0), 0)
			var o1 := Vector3(cos(a1), sin(a1), 0)
			var zf2: float = zf + signf(zf) * 0.58
			var ax := Vector3(0, 0, signf(zf))
			var ia: Vector3 = Vector3(o0.x * (rr - 0.7), o0.y * (rr - 0.7), zf2)
			var ib: Vector3 = Vector3(o1.x * (rr - 0.7), o1.y * (rr - 0.7), zf2)
			var oa: Vector3 = Vector3(o0.x * (rr + 0.7), o0.y * (rr + 0.7), zf2)
			var ob: Vector3 = Vector3(o1.x * (rr + 0.7), o1.y * (rr + 0.7), zf2)
			var u0: float = a0 * rr
			var u1: float = a1 * rr
			pk.tri(kit, "ledchase", ia, ib, ob, ax, ax, ax, Color.WHITE, ax, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1))
			pk.tri(kit, "ledchase", ia, ob, oa, ax, ax, ax, Color.WHITE, ax, Vector2(u0, 0), Vector2(u1, 1), Vector2(u0, 1))
	# Bracing between the rims: struts across and diagonals.
	for i in range(segs):
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		var p0 := Vector3(cos(a0) * rr, sin(a0) * rr, 0)
		var p1 := Vector3(cos(a1) * rr, sin(a1) * rr, 0)
		pk.tube(kit, "paintsteel", p0 + Vector3(0, 0, -1.6), p0 + Vector3(0, 0, 1.6), 0.25, 0.25, 6, STEEL, false)
		pk.tube(kit, "paintsteel", p0 + Vector3(0, 0, -1.6), p1 + Vector3(0, 0, 1.6), 0.16, 0.16, 6, STEEL, false)
	# The hub and the spokes: cables from the hub's ends to each rim, crossing over.
	pk.tube(kit, "paintsteel", Vector3(0, 0, -4.5), Vector3(0, 0, 4.5), 2.6, 2.6, 20, STEEL)
	pk.lathe(kit, "led", Vector3(0, 0, 0), [Vector2(2.62, -0.25), Vector2(2.62, 0.25)], 24, Color(0.85, 0.9, 1.0), false, Basis(Vector3.RIGHT, PI * 0.5))
	for i in range(n):
		var a: float = TAU * (float(i) + 0.25) / n
		var rim := Vector3(cos(a) * rr, sin(a) * rr, 0)
		for side in [-1.0, 1.0]:
			var hub := Vector3(cos(a) * 2.4, sin(a) * 2.4, side * 4.2)
			var to := rim + Vector3(0, 0, -side * 1.6)
			pk.tube(kit, "paintsteel", hub, to, 0.07, 0.07, 4, STEEL, false)
			pk.tube(kit, "led", hub.lerp(to, 0.04), hub.lerp(to, 0.97), 0.16, 0.16, 4, Color(0.75, 0.85, 1.0), false)


## The wheel's stand in its own frame (the axle along z at `hub_y` over the ground at y 0): on each side an A of two
## raking legs from feet spread along x to the axle's bearing, cross-braced; the axle; the boarding platform round the
## wheel's foot and a glass pavilion beside it.
static func wheel_stand(pk: PropKit, kit: Dictionary, hub_y: float, rr: float) -> void:
	var white := Color(0.88, 0.89, 0.90)
	for side in [-1.0, 1.0]:
		var top := Vector3(0, hub_y, side * 6.0)
		for fx in [-1.0, 1.0]:
			var foot := Vector3(fx * hub_y * 0.42, 0.0, side * 15.0)
			pk.tube(kit, "paintsteel", foot, top, 1.6, 1.0, 12, white)
			pk.tube(kit, "led", foot.lerp(top, 0.02) + Vector3(0, 0, side * 1.3), foot.lerp(top, 0.97) + Vector3(0, 0, side * 0.9), 0.08, 0.08, 4, Color(0.8, 0.88, 1.0), false)
		# Bracing between the two legs of the A, at two heights.
		for t in [0.35, 0.65]:
			var l := Vector3(-hub_y * 0.42, 0, side * 15.0).lerp(top, t)
			var r := Vector3(hub_y * 0.42, 0, side * 15.0).lerp(top, t)
			pk.tube(kit, "paintsteel", l, r, 0.5, 0.5, 8, white)
		pk.block(kit, "marble", Vector3(-hub_y * 0.42 - 3.0, -1.0, side * 15.0 - 3.0), Vector3(-hub_y * 0.42 + 3.0, 0.8, side * 15.0 + 3.0), Color(0.75, 0.72, 0.68))
		pk.block(kit, "marble", Vector3(hub_y * 0.42 - 3.0, -1.0, side * 15.0 - 3.0), Vector3(hub_y * 0.42 + 3.0, 0.8, side * 15.0 + 3.0), Color(0.75, 0.72, 0.68))
	pk.tube(kit, "paintsteel", Vector3(0, hub_y, -7.0), Vector3(0, hub_y, 7.0), 1.4, 1.4, 16, white)
	# The boarding platform under the wheel's foot and the pavilion.
	# Under the lowest cabin (mounted 3.4m out from the rims, hanging 3.6m below its mount).
	var py: float = hub_y - rr - 7.4
	pk.block(kit, "marble", Vector3(-16.0, -1.0, -9.0), Vector3(16.0, maxf(py, 1.0), 9.0), Color(0.80, 0.76, 0.70))
	# The pavilion in front of the wheel, along the axle (clear of the legs' feet).
	pk.lathe(kit, "glasslit", Vector3(0, 0, 30.0), [Vector2(10.5, 0.0), Vector2(10.5, 6.0)], 24, Color(0.55, 0.75, 1.0))
	pk.lathe(kit, "marble", Vector3(0, 6.0, 30.0), [Vector2(12.0, 0.0), Vector2(12.0, 0.8), Vector2(0.0, 0.9)], 24, Color(0.92, 0.92, 0.94))
	pk.lathe(kit, "led", Vector3(0, 6.0, 30.0), [Vector2(12.05, 0.25), Vector2(12.05, 0.55)], 24, Color(0.4, 0.8, 1.0))


## A cabin in its own frame (hung from its mount at the origin, below it): an egg of lit glass on a steel ring.
static func cabin(pk: PropKit, kit: Dictionary) -> void:
	var prof: Array = []
	for k in range(9):
		var t: float = float(k) / 8.0
		var a: float = PI * (1.0 - t)
		prof.append(Vector2(sin(a) * 2.4, -3.6 + (cos(a) + 1.0) * 0.5 * 3.2))
	pk.lathe(kit, "glasslit", Vector3.ZERO, prof, 14, Color(0.55, 0.85, 1.0))
	pk.lathe(kit, "paintsteel", Vector3.ZERO, [Vector2(2.45, -2.12), Vector2(2.45, -1.88)], 14, STEEL)
	pk.tube(kit, "paintsteel", Vector3(0, -0.4, 0), Vector3(0, 0.2, 0), 0.3, 0.3, 6, STEEL)


# ======================================================================================
#  The souk
# ======================================================================================

## Souk al-Lulu, the market hall on the souk's long lane (life size, its front toward -z, `w` x `dep`, its middle at
## the origin): an arcade of pointed arches along the front with lit shops behind them and a lantern in each arch, the
## upper storey's windows over its cornice, a crenellated parapet, three domes on drums along the roof, wind towers at
## both ends.
static func souk_hall(pk: PropKit, kit: Dictionary, w: float, dep: float) -> void:
	var hw := w * 0.5
	var hd := dep * 0.5
	var col: Color = ArabianKit.LIME.lerp(ArabianKit.MUD_PALE, 0.3)
	ArabianKit.slab(pk, kit, "stone", Vector3(-hw - 0.15, -0.6, -hd - 0.15), Vector3(hw + 0.15, 0.4, hd + 0.15), Color(0.70, 0.62, 0.52), 0.0)
	# The block behind the arcade, its front 0.6m back from it.
	var fz: float = -hd + 0.6
	ArabianKit.slab(pk, kit, "lime", Vector3(-hw, 0.4, fz), Vector3(hw, 8.2, hd), col, 0.3)
	ArabianKit.arcade(pk, kit, "lime", -hw, hw, -hd, 0.4, 2.6, 3.2, col)
	# The shops glowing behind the arches, a lantern hung in each.
	var n: int = maxi(1, int(w / 3.2))
	var b: float = w / float(n)
	for i in range(n):
		var x: float = -hw + b * (float(i) + 0.5)
		pk.quad(kit, "glasslit", [Vector3(x - b * 0.5 + 0.4, 0.5, -hd + 0.22), Vector3(x + b * 0.5 - 0.4, 0.5, -hd + 0.22),
				Vector3(x + b * 0.5 - 0.4, 2.9, -hd + 0.22), Vector3(x - b * 0.5 + 0.4, 2.9, -hd + 0.22)], Vector3(0, 0, -1), Color(1.0, 0.74, 0.42))
		pk.beam(kit, "metal", Vector3(x, 3.6, -hd + 0.1), Vector3(x, 3.0, -hd + 0.1), 0.03, 0.03, Color(0.15, 0.15, 0.15))
		pk.box(kit, "led", Transform3D(Basis(), Vector3(x, 2.8, -hd + 0.1)), Vector3(0.3, 0.42, 0.3), Color(1.0, 0.7, 0.36))
		ArabianKit.window(pk, kit, Vector3(x, 6.7, fz), Vector3(0, 0, -1), 0.9, 1.1, i % 2 == 0)
	ArabianKit.parapet(pk, kit, "lime", Vector3(-hw, 8.2, fz), Vector3(hw, 8.2, hd), 1.0, col)
	var mz: float = (fz + hd) * 0.5
	for k in [-1.0, 0.0, 1.0]:
		ArabianKit.dome(pk, kit, "lime", Vector3(k * w * 0.27, 8.2, mz), 2.5 if k == 0.0 else 1.9, 1.5, col)
	for sx in [-1.0, 1.0]:
		ArabianKit.wind_tower(pk, kit, "lime", Vector3(sx * (hw - 1.7), 8.2, hd - 1.7), 2.6, 5.2, col)


# ======================================================================================
#  Yachts (in metres: the bow toward +z, y = 0 the waterline, x = 0 the centre line: SeaBoat's convention)
# ======================================================================================

## [topsides, boot stripe, sheer stripe, superstructure]: white over navy; navy; gunmetal; white with a gold stripe.
const YACHT_STYLES := [
	[Color(0.95, 0.95, 0.96), Color(0.07, 0.11, 0.22), Color(0.82, 0.84, 0.86), Color(0.97, 0.97, 0.98)],
	[Color(0.06, 0.10, 0.20), Color(0.86, 0.87, 0.89), Color(0.94, 0.94, 0.95), Color(0.97, 0.97, 0.98)],
	[Color(0.36, 0.38, 0.41), Color(0.07, 0.07, 0.08), Color(0.78, 0.79, 0.81), Color(0.93, 0.93, 0.94)],
	[Color(0.95, 0.95, 0.96), Color(0.60, 0.46, 0.20), Color(0.82, 0.64, 0.30), Color(0.97, 0.97, 0.98)],
]
const YACHT_TEAK := Color(0.62, 0.45, 0.28)
const LED_WHITE := Color(0.85, 0.92, 1.0)


## A motor yacht `length` long (a 24m flybridge yacht, a 44m superyacht with three decks): ShipKit's hull lofted with a
## boot stripe and a sheer stripe, lit windows along its topsides, anchors in their pockets at the bow, a swim platform
## with steps up either side and the tender garage's door; a teak main deck with chrome rails; decks of rounded plan
## each over the one below (white fascias overhanging, LED lines under them), their sides and fronts glazed in dark
## glass with lit rooms behind some panes; a hardtop on slim pillars over the top deck with the mast (radar domes, a
## scanner, lights); a hot tub and sun pads on the foredeck; navigation lights, deck lights and blue lights under the
## stern. `style` picks the paint (YACHT_STYLES).
static func yacht(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, length: float, style := 0) -> void:
	var st: Array = YACHT_STYLES[style % YACHT_STYLES.size()]
	var big: bool = length > 32.0
	var L := length
	var hb: float = L * 0.104
	var fb: float = L * 0.068
	var bow_run := 0.36
	var bow_wl := 0.46
	var stern_run := 0.05
	var transom := 0.9
	var bands := [[-1.2, Color(0.14, 0.10, 0.10)], [0.18, Color(0.14, 0.10, 0.10)], [0.18, st[1]], [0.46, st[1]], [0.46, st[0]],
			[fb - 0.3, st[0]], [fb - 0.3, st[2]], [fb, st[2]]]
	var fc: float = L * 0.011
	var outline: PackedVector2Array = ShipKit.hull(pk, kit, L, hb, hb * 0.9, fb, bands, bow_run, bow_wl, stern_run, transom, fc, 0.62, 48,
			L * 0.004, 0.0, fb, st[2])
	ShipKit.deck(pk, kit, "teak", outline, fb - 0.02, YACHT_TEAK)
	var side_at := func(t: float, y: float) -> Vector3:
		return ShipKit.side_at(t, y, L, hb, hb * 0.9, fb, bow_run, bow_wl, stern_run, transom)
	# Windows along the topsides: long strips following the hull, some lit.
	var wy: float = fb * 0.5
	var spans: Array = [[0.22, 0.34], [0.37, 0.49], [0.52, 0.62]] if big else [[0.3, 0.42], [0.45, 0.56]]
	for sp in spans:
		var lit: bool = rng.randf() < 0.6
		for sd in [-1.0, 1.0]:
			var steps := 6
			for k in range(steps):
				var ta: float = lerpf(float(sp[0]), float(sp[1]), float(k) / steps)
				var tb: float = lerpf(float(sp[0]), float(sp[1]), float(k + 1) / steps)
				var hgt: float = 0.55 if big else 0.4
				var a0: Vector3 = side_at.call(ta, wy - hgt * 0.5)
				var a1: Vector3 = side_at.call(ta, wy + hgt * 0.5)
				var b0: Vector3 = side_at.call(tb, wy - hgt * 0.5)
				var b1: Vector3 = side_at.call(tb, wy + hgt * 0.5)
				var out := Vector3(sd, 0, 0)
				var q: Array = [Vector3(a0.x * sd + sd * 0.025, a0.y, a0.z), Vector3(b0.x * sd + sd * 0.025, b0.y, b0.z),
						Vector3(b1.x * sd + sd * 0.025, b1.y, b1.z), Vector3(a1.x * sd + sd * 0.025, a1.y, a1.z)]
				pk.quad(kit, "glasslit" if lit else "yglass", q, out, Color(1.0, 0.82, 0.58) if lit else Color(0.05, 0.07, 0.10))
	# Anchors in their pockets near the bow.
	for sd in [-1.0, 1.0]:
		var ap: Vector3 = side_at.call(0.9, fb * 0.72)
		var c := Vector3(ap.x * sd + sd * 0.02, ap.y, ap.z)
		var bs := Basis.looking_at(Vector3(sd, 0, 0.0), Vector3.UP)
		pk.box(kit, "matte", Transform3D(bs, c), Vector3(L * 0.03, L * 0.022, 0.04), Color(0.08, 0.08, 0.09))
		pk.box(kit, "chrome", Transform3D(bs, c + Vector3(sd * 0.03, -L * 0.003, 0)), Vector3(L * 0.012, L * 0.016, 0.06), Color(0.85, 0.86, 0.88))
	# The stern: a swim platform, steps up both sides, the garage door with an LED edge, a gold name bar.
	var hl := L * 0.5
	var tw: float = hb * transom * 0.96
	var plat_d: float = L * 0.055
	pk.block(kit, "teak", Vector3(-tw, 0.32, -hl - plat_d), Vector3(tw, 0.52, -hl + 0.05), YACHT_TEAK)
	pk.block(kit, "hull", Vector3(-tw, 0.0, -hl - plat_d + 0.1), Vector3(tw, 0.32, -hl + 0.05), st[0])
	for sd in [-1.0, 1.0]:
		var n_steps: int = int(ceil((fb - 0.52) / 0.3))
		for k in range(n_steps):
			var y0: float = 0.52 + float(k) * (fb - 0.52) / n_steps
			var y1: float = 0.52 + float(k + 1) * (fb - 0.52) / n_steps
			var x0: float = sd * (tw - 0.9)
			var z_in: float = -hl - plat_d * 0.6 + float(k + 1) * plat_d * 0.6 / n_steps
			pk.block(kit, "teak", Vector3(minf(x0, sd * tw), y0, -hl - plat_d * 0.6), Vector3(maxf(x0, sd * tw), y1, z_in), YACHT_TEAK)
	var gw: float = tw - 1.1
	pk.quad(kit, "matte", [Vector3(-gw, 0.62, -hl - 0.03), Vector3(gw, 0.62, -hl - 0.03), Vector3(gw, fb - 0.45, -hl - 0.03), Vector3(-gw, fb - 0.45, -hl - 0.03)],
			Vector3(0, 0, -1), Color(0.16, 0.17, 0.19))
	for e in [[Vector3(-gw, 0.6, -hl - 0.05), Vector3(gw, 0.6, -hl - 0.05)], [Vector3(-gw, fb - 0.43, -hl - 0.05), Vector3(gw, fb - 0.43, -hl - 0.05)]]:
		pk.beam(kit, "led", e[0], e[1], 0.04, 0.03, LED_WHITE)
	pk.box(kit, "metal", Transform3D(Basis(), Vector3(0, fb - 0.2, -hl - 0.04)), Vector3(tw * 0.9, 0.12, 0.03), Color(0.86, 0.68, 0.32))
	# Blue lights along the waterline aft. (A glowing quad under the stern, meant as underwater light, lay on the sea as
	# an opaque blue slab behind every yacht.)
	for sd in [-1.0, 1.0]:
		for t in [0.06, 0.12, 0.18]:
			var lp: Vector3 = side_at.call(t, 0.05)
			pk.box(kit, "led", Transform3D(Basis(), Vector3(lp.x * sd + sd * 0.03, 0.05, lp.z)), Vector3(0.04, 0.12, 0.3), Color(0.25, 0.55, 1.0))
	# Chrome rails along the main deck's edges, bow to the superstructure's end.
	for sd in [-1.0, 1.0]:
		var pts: Array = ShipKit.edge_points(L, hb, hb * 0.9, fb, sd, 0.12, 0.08, 0.97, 18, bow_run, bow_wl, stern_run, transom, L * 0.004, 0.0)
		for i in range(pts.size()):
			var p: Vector3 = pts[i]
			p.y += fc * smoothstep(0.62, 0.72, (p.z + hl) / L)
			pts[i] = p
		_rail(pk, kit, pts, 0.95)
	# The decks: [z aft, z front, half width, floor, height] for each house; the slab over each overhangs it.
	var decks: Array = []
	var slab_w: Array = []
	var y := fb
	if big:
		decks = [[-L * 0.30, L * 0.17, hb * 0.80, 2.45], [-L * 0.19, L * 0.08, hb * 0.76, 2.3], [-L * 0.08, L * 0.0, hb * 0.6, 2.15]]
	else:
		decks = [[-L * 0.24, L * 0.15, hb * 0.80, 2.1], [-L * 0.06, L * 0.05, hb * 0.66, 1.95]]
	for i in range(decks.size()):
		var dk: Array = decks[i]
		var za: float = dk[0]
		var zf: float = dk[1]
		var w: float = dk[2]
		var h: float = dk[3]
		var plan := _rounded_plan(w, za, zf)
		_house(pk, kit, rng, plan, y, y + h, st[3], i == 0, 1.5 if i == 0 else 1.25)
		y += h
		# The slab over it: wider, further aft (a covered deck behind the house), its teak top, white fascia, LEDs.
		var top_house: bool = i == decks.size() - 1
		var sw: float = minf(w + (0.55 if not top_house else 0.3), hb * 0.97)
		var sa: float = za - (L * 0.08 if i == 0 else L * 0.06) if not top_house else za - L * 0.09
		# Past the house's nose, so it roofs all of it.
		var sf: float = zf + 0.3
		slab_w.append(sw)
		var slab := _rounded_plan(sw, sa, sf)
		_slab(pk, kit, slab, y, 0.3, st[3], top_house)
		if not top_house:
			_rail(pk, kit, _plan_rail(slab, y + 0.3, 0.1), 0.95)
		else:
			# The hardtop's pillars at its aft corners.
			for sd in [-1.0, 1.0]:
				pk.tube(kit, "hull", Vector3(sd * (sw - 0.35), y - h, sa + 0.5), Vector3(sd * (sw - 0.35), y, sa + 0.5), 0.12, 0.12, 8, st[3])
		y += 0.3
	# The mast on the hardtop: raked, two radar domes, a scanner, the masthead light, antennas.
	var mz: float = float(decks[decks.size() - 1][0]) + 0.6
	var mtop := Vector3(0, y + (3.4 if big else 2.2), mz - 0.6)
	pk.beam(kit, "hull", Vector3(0, y, mz + 0.4), mtop, 0.5, 0.35, st[3])
	for sd in [-1.0, 1.0]:
		var dc := Vector3(sd * 0.7, y + (1.7 if big else 1.0), mz - 0.1)
		pk.beam(kit, "hull", Vector3(0, dc.y - 0.2, mz + 0.1), dc - Vector3(0, 0.25, 0), 0.12, 0.12, st[3])
		pk.lathe(kit, "plastic", dc - Vector3(0, 0.25, 0), [Vector2(0.001, 0.0), Vector2(0.42, 0.05), Vector2(0.46, 0.3), Vector2(0.35, 0.62), Vector2(0.001, 0.72)], 12, Color(0.95, 0.95, 0.95))
	ShipKit.radar(pk, kit, mtop + Vector3(0, 0.05, 0), 1.8 if big else 1.2, rng.randf_range(-0.5, 0.5))
	for k in range(2):
		pk.tube(kit, "chrome", mtop + Vector3(0.3 - 0.6 * k, 0.1, 0.2), mtop + Vector3(0.3 - 0.6 * k, 1.8, 0.4), 0.02, 0.01, 4, Color(0.85, 0.85, 0.87))
	pk.box(kit, "led", Transform3D(Basis(), mtop + Vector3(0, 0.75, 0)), Vector3(0.18, 0.18, 0.18), Color(1.0, 1.0, 1.0))
	# Navigation lights on the first upper deck's wings (starboard green on -x, the bow toward +z), the stern light.
	var wing_y: float = fb + float(decks[0][3]) + 0.5
	var wing_z: float = float(decks[1][1]) - 1.2
	var wing_x: float = float(slab_w[0]) - 0.12
	ShipKit.nav_light(pk, kit, Vector3(-wing_x, wing_y, wing_z), Color(0.1, 1.0, 0.25))
	ShipKit.nav_light(pk, kit, Vector3(wing_x, wing_y, wing_z), Color(1.0, 0.12, 0.1))
	pk.box(kit, "led", Transform3D(Basis(), Vector3(0, fb + 0.25, -hl + 0.02)), Vector3(0.2, 0.14, 0.06), Color(1.0, 1.0, 1.0))
	# The foredeck: a hot tub (on the big ones), sun pads, a cleat line.
	var fz: float = float(decks[0][1]) + L * 0.07
	var fdy: float = fb + fc * smoothstep(0.62, 0.72, (fz + hl) / L)
	if big:
		pk.lathe(kit, "hull", Vector3(0, fdy - 0.02, fz + L * 0.07), [Vector2(1.6, 0.0), Vector2(1.6, 0.55), Vector2(1.45, 0.6), Vector2(1.45, 0.5)], 24, st[3])
		pk.lathe(kit, "led", Vector3(0, fdy + 0.5, fz + L * 0.07), [Vector2(1.45, 0.0), Vector2(0.0, 0.0)], 24, Color(0.25, 0.65, 1.0))
	for sd in [-1.0, 1.0]:
		pk.box(kit, "plastic", Transform3D(Basis(), Vector3(sd * hb * 0.32, fdy + 0.2, fz)), Vector3(hb * 0.5, 0.36, L * 0.07), Color(0.92, 0.91, 0.88))
		pk.box(kit, "plastic", Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(sd * hb * 0.32, fdy + 0.42, fz + L * 0.035 + 0.1)), Vector3(hb * 0.5, 0.12, 0.6), Color(0.92, 0.91, 0.88))
	# The aft deck under the first slab: a table and a settee.
	var az: float = float(decks[0][0]) - L * 0.04
	pk.box(kit, "teak", Transform3D(Basis(), Vector3(0, fb + 0.72, az)), Vector3(hb * 0.7, 0.06, L * 0.035), YACHT_TEAK.darkened(0.15))
	pk.box(kit, "plastic", Transform3D(Basis(), Vector3(0, fb + 0.22, az - L * 0.03)), Vector3(hb * 1.2, 0.44, 0.7), Color(0.90, 0.88, 0.84))


## A plan for a deck: a rounded rectangle from z `za` (aft, its corners rounded a little) to `zf` (the front, a long
## half-ellipse), `w` either side. Points round it counter-clockwise seen from above.
static func _rounded_plan(w: float, za: float, zf: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var nose: float = minf(w * 1.6, (zf - za) * 0.45)
	var zs: float = zf - nose
	var r: float = minf(0.9, w * 0.25)
	# Aft edge, corners rounded.
	for k in range(5):
		var a: float = PI + PI * 0.5 * float(k) / 4.0
		pts.append(Vector2(-w + r + cos(a) * r, za + r + sin(a) * r))
	for k in range(5):
		var a: float = PI * 1.5 + PI * 0.5 * float(k) / 4.0
		pts.append(Vector2(w - r + cos(a) * r, za + r + sin(a) * r))
	# The front: from the starboard... the +x side round the nose to the -x side.
	for k in range(13):
		var a: float = PI * float(k) / 12.0
		pts.append(Vector2(cos(a) * w, zs + sin(a) * nose))
	return pts


## A deck house on `plan` from y0 to y1, its front raked back `rake` metres at the top: white walls, a glazed band round
## its sides and front (panes, a few of the side ones lit; the front's dark, a windscreen), the aft wall with glass doors.
static func _house(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, plan: PackedVector2Array, y0: float, y1: float, col: Color, main: bool,
		rake := 1.2) -> void:
	var n := plan.size()
	var g0: float = 0.42 if main else 0.5
	var g1: float = 0.3
	var c := Vector2.ZERO
	var zf := -INF
	var za := INF
	for p in plan:
		c += p
		zf = maxf(zf, p.y)
		za = minf(za, p.y)
	c /= float(n)
	var span: float = zf - za
	# The top's outline: the front pulled back.
	var top := PackedVector2Array()
	for p in plan:
		var f: float = clampf((p.y - (zf - span * 0.42)) / (span * 0.42), 0.0, 1.0)
		top.append(p - Vector2(0.0, rake * f * f * (3.0 - 2.0 * f)))
	for i in range(n):
		var a: Vector2 = plan[i]
		var b: Vector2 = plan[(i + 1) % n]
		var at: Vector2 = top[i]
		var bt: Vector2 = top[(i + 1) % n]
		var e: Vector2 = b - a
		if e.length() < 0.01:
			continue
		var out2 := Vector2(e.y, -e.x).normalized()
		if out2.dot((a + b) * 0.5 - c) < 0.0:
			out2 = -out2
		var A := Vector3(a.x, y0, a.y)
		var B := Vector3(b.x, y0, b.y)
		var AT := Vector3(at.x, y1, at.y)
		var BT := Vector3(bt.x, y1, bt.y)
		var nrm: Vector3 = (B - A).cross(AT - A).normalized()
		if nrm.dot(Vector3(out2.x, 0, out2.y)) < 0.0:
			nrm = -nrm
		pk.quad(kit, "hull", [A, B, BT, AT], nrm, col)
		# Glass: panes 2.5cm proud, a narrow white gap between them.
		var front: bool = out2.y > 0.55
		var length: float = e.length()
		var panes: int = maxi(1, int(round(length / 1.7)))
		var lo: float = g0 / (y1 - y0)
		var hi: float = 1.0 - g1 / (y1 - y0)
		for k in range(panes):
			var t0: float = (float(k) + 0.04) / panes
			var t1: float = (float(k) + 0.96) / panes
			var lit: bool = not front and rng.randf() < 0.35
			var q: Array = []
			for uv in [[t0, lo], [t1, lo], [t1, hi], [t0, hi]]:
				var bot: Vector3 = A.lerp(B, float(uv[0]))
				var tp: Vector3 = AT.lerp(BT, float(uv[0]))
				q.append(bot.lerp(tp, float(uv[1])) + nrm * 0.025)
			pk.quad(kit, "glasslit" if lit else "yglass", q, nrm, Color(1.0, 0.82, 0.56) if lit else Color(0.04, 0.06, 0.09))


## A deck's slab on `plan` from y to y + t: teak (or white, the top one a hardtop) on top, white underneath and round
## its edge, an LED line under the fascia.
static func _slab(pk: PropKit, kit: Dictionary, plan: PackedVector2Array, y: float, t: float, col: Color, hardtop: bool) -> void:
	var idx := Geometry2D.triangulate_polygon(plan)
	for i in range(0, idx.size(), 3):
		var a: Vector2 = plan[idx[i]]
		var b: Vector2 = plan[idx[i + 1]]
		var c: Vector2 = plan[idx[i + 2]]
		pk.tri(kit, "hull" if hardtop else "teak", Vector3(a.x, y + t, a.y), Vector3(b.x, y + t, b.y), Vector3(c.x, y + t, c.y), Vector3.UP, Vector3.UP, Vector3.UP,
				col if hardtop else YACHT_TEAK, Vector3.UP)
		pk.tri(kit, "hull", Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, col.darkened(0.1), Vector3.DOWN)
	var n := plan.size()
	var cc := Vector2.ZERO
	for p in plan:
		cc += p
	cc /= float(n)
	for i in range(n):
		var a: Vector2 = plan[i]
		var b: Vector2 = plan[(i + 1) % n]
		var e: Vector2 = b - a
		if e.length() < 0.01:
			continue
		var out2 := Vector2(e.y, -e.x).normalized()
		if out2.dot((a + b) * 0.5 - cc) < 0.0:
			out2 = -out2
		var out := Vector3(out2.x, 0, out2.y)
		pk.quad(kit, "hull", [Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(b.x, y + t, b.y), Vector3(a.x, y + t, a.y)], out, col)
		var la: Vector2 = a + out2 * 0.01
		var lb: Vector2 = b + out2 * 0.01
		pk.quad(kit, "led", [Vector3(la.x, y - 0.01, la.y), Vector3(lb.x, y - 0.01, lb.y), Vector3(lb.x, y + 0.05, lb.y), Vector3(la.x, y + 0.05, la.y)], out, LED_WHITE)


## Points round a plan's edge (all but the front's nose: a rail's run), `inset` in, at y.
static func _plan_rail(plan: PackedVector2Array, y: float, inset: float) -> Array:
	var cc := Vector2.ZERO
	for p in plan:
		cc += p
	cc /= float(plan.size())
	var out: Array = []
	for i in range(plan.size()):
		var p: Vector2 = plan[i]
		var q: Vector2 = p + (cc - p).normalized() * inset
		out.append(Vector3(q.x, y, q.y))
	out.append(out[0])
	return out


## A chrome rail along points: stanchions every point, a top rail and a mid rail.
static func _rail(pk: PropKit, kit: Dictionary, pts: Array, h: float) -> void:
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		pk.tube(kit, "chrome", p, p + Vector3(0, h, 0), 0.025, 0.025, 5, Color(0.86, 0.87, 0.89), false)
		if i > 0:
			var q: Vector3 = pts[i - 1]
			if q.distance_to(p) < 0.05:
				continue
			pk.tube(kit, "chrome", q + Vector3(0, h, 0), p + Vector3(0, h, 0), 0.03, 0.03, 5, Color(0.86, 0.87, 0.89), false)
			pk.tube(kit, "chrome", q + Vector3(0, h * 0.5, 0), p + Vector3(0, h * 0.5, 0), 0.015, 0.015, 4, Color(0.86, 0.87, 0.89), false)


# ======================================================================================
#  The start's promenade (life size, grown by the caller)
# ======================================================================================

## A race-day grandstand (its front toward -z, `length` along x, its front's middle at the origin): a navy front wall with
## an LED strip, `tiers` steps of treads, each with a bench along its back in the GP's colours, a steel frame under it,
## rails round its back and ends, and a white tensile canopy over it on masts behind. Returns the seat tops (life size,
## in its frame) for seated spectators, every 0.62m along each bench.
static func grandstand(pk: PropKit, kit: Dictionary, length := 24.0, tiers := 5) -> Array:
	var tread := 0.9
	var riser := 0.42
	var front_h := 1.0
	var hl := length * 0.5
	var steel := Color(0.58, 0.60, 0.63)
	var navy := Color(0.07, 0.10, 0.22)
	var orange := Color(1.0, 0.45, 0.08)
	var spots: Array = []
	# The front wall and its LED strip.
	pk.block(kit, "paintsteel", Vector3(-hl, 0.0, -0.08), Vector3(hl, front_h, 0.02), navy)
	pk.box(kit, "led", Transform3D(Basis(), Vector3(0, front_h - 0.12, -0.1)), Vector3(length - 0.4, 0.06, 0.03), Color(1.0, 0.55, 0.15))
	for t in range(tiers):
		var y: float = front_h + float(t) * riser
		var z0: float = float(t) * tread
		var z1: float = z0 + tread
		# The tread and the riser in front of it.
		pk.block(kit, "paintsteel", Vector3(-hl, y - 0.06, z0), Vector3(hl, y, z1), Color(0.70, 0.72, 0.74))
		if t > 0:
			pk.quad(kit, "paintsteel", [Vector3(-hl, y - riser, z0), Vector3(hl, y - riser, z0), Vector3(hl, y, z0), Vector3(-hl, y, z0)], Vector3(0, 0, -1),
					Color(0.62, 0.64, 0.67))
		# The bench along the back of the tread, in alternating colours by tier.
		var col: Color = orange if t % 2 == 0 else Color(0.93, 0.93, 0.95)
		pk.block(kit, "plastic", Vector3(-hl + 0.7, y, z1 - 0.48), Vector3(hl - 0.7, y + 0.42, z1 - 0.12), col)
		pk.block(kit, "plastic", Vector3(-hl + 0.7, y + 0.42, z1 - 0.14), Vector3(hl - 0.7, y + 0.82, z1 - 0.06), col.darkened(0.15))
		var x := -hl + 1.0
		while x < hl - 0.95:
			spots.append(Vector3(x, y + 0.42, z1 - 0.32))
			x += 0.62
	var top_y: float = front_h + float(tiers - 1) * riser
	var back_z: float = float(tiers) * tread
	# The frame under it: posts under each tread's back every 3m, a brace between them.
	var px := -hl
	while px <= hl + 0.01:
		for t in range(tiers):
			var y2: float = front_h + float(t) * riser - 0.06
			var z2: float = float(t + 1) * tread - 0.05
			pk.tube(kit, "paintsteel", Vector3(px, 0.0, z2), Vector3(px, y2, z2), 0.05, 0.05, 6, steel, false)
		pk.tube(kit, "paintsteel", Vector3(px, 0.2, tread), Vector3(px, top_y - 0.2, back_z), 0.035, 0.035, 5, steel, false)
		px += 3.0
	# The back wall (sponsor boards) and the rails at its ends.
	pk.block(kit, "paintsteel", Vector3(-hl, 0.0, back_z), Vector3(hl, top_y + 1.1, back_z + 0.06), navy)
	for sx in [-1.0, 1.0]:
		for t in range(tiers):
			var y3: float = front_h + float(t) * riser
			pk.tube(kit, "chrome", Vector3(sx * hl, y3, float(t) * tread), Vector3(sx * hl, y3 + 1.0, float(t) * tread), 0.025, 0.025, 5, Color(0.85, 0.86, 0.88), false)
		pk.tube(kit, "chrome", Vector3(sx * hl, front_h + 1.0, 0.0), Vector3(sx * hl, top_y + 1.0, back_z - tread), 0.03, 0.03, 5, Color(0.85, 0.86, 0.88), false)
	# The canopy: masts behind, a white membrane sloping down toward the front, an LED line along its leading edge.
	var mast_h: float = top_y + 4.2
	var n_m: int = maxi(2, int(length / 6.0))
	var edge_y: float = top_y + 2.6
	for k in range(n_m + 1):
		var mx: float = lerpf(-hl, hl, float(k) / n_m)
		pk.tube(kit, "paintsteel", Vector3(mx, 0.0, back_z + 0.4), Vector3(mx, mast_h, back_z + 0.4), 0.09, 0.07, 8, Color(0.92, 0.92, 0.94))
		# A strut from the mast's top out to the membrane's front edge.
		pk.tube(kit, "paintsteel", Vector3(mx, mast_h, back_z + 0.4), Vector3(mx, edge_y, 0.4), 0.04, 0.04, 5, Color(0.92, 0.92, 0.94), false)
	for k in range(n_m):
		var xa: float = lerpf(-hl, hl, float(k) / n_m)
		var xb: float = lerpf(-hl, hl, float(k + 1) / n_m)
		var sag := 0.25
		var a := Vector3(xa, mast_h - 0.05, back_z + 0.4)
		var b := Vector3(xb, mast_h - 0.05, back_z + 0.4)
		var c := Vector3(xb, edge_y, 0.4)
		var d := Vector3(xa, edge_y, 0.4)
		var m := (a + b + c + d) * 0.25 - Vector3(0, sag, 0)
		var nrm: Vector3 = (b - a).cross(d - a).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		for tri in [[a, b, m], [b, c, m], [c, d, m], [d, a, m]]:
			pk.tri(kit, "awning", tri[0], tri[1], tri[2], nrm, nrm, nrm, Color(0.96, 0.96, 0.95), nrm)
			pk.tri(kit, "awning", tri[0], tri[2], tri[1], -nrm, -nrm, -nrm, Color(0.86, 0.86, 0.88), -nrm)
		pk.box(kit, "led", Transform3D(Basis(), Vector3((xa + xb) * 0.5, edge_y - 0.05, 0.4)), Vector3(xb - xa - 0.1, 0.05, 0.05), Color(1.0, 0.9, 0.75))
	return spots


## A shade sail: a white triangle stretched between three masts at the points a, b, c (their feet on the ground at y 0,
## the corners at their heights), sagging a little.
static func shade_sail(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		pk.tube(kit, "paintsteel", Vector3(p.x, 0.0, p.z), p + Vector3(0, 0.3, 0), 0.07, 0.05, 8, Color(0.9, 0.9, 0.92))
		pk.box(kit, "led", Transform3D(Basis(), Vector3(p.x, 0.35, p.z)), Vector3(0.22, 0.12, 0.22), Color(1.0, 0.85, 0.6))
	var m: Vector3 = (a + b + c) / 3.0 - Vector3(0, 0.35, 0)
	for e in [[a, b], [b, c], [c, a]]:
		var p0: Vector3 = e[0]
		var p1: Vector3 = e[1]
		var nrm: Vector3 = (p1 - p0).cross(m - p0).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		pk.tri(kit, "awning", p0, p1, m, nrm, nrm, nrm, Color(0.97, 0.97, 0.96), nrm)
		pk.tri(kit, "awning", p0, m, p1, -nrm, -nrm, -nrm, Color(0.85, 0.85, 0.86), -nrm)


## A banner pole: a white pole `h` tall with a vertical banner (navy, an orange band, a white chequer at the foot) on an
## arm at its top; the banner faces ±z.
static func banner_pole(pk: PropKit, kit: Dictionary, h := 6.0) -> void:
	pk.tube(kit, "paintsteel", Vector3.ZERO, Vector3(0, h, 0), 0.06, 0.045, 8, Color(0.92, 0.92, 0.94))
	pk.tube(kit, "paintsteel", Vector3(0, h - 0.1, 0), Vector3(0.95, h - 0.1, 0), 0.025, 0.025, 5, Color(0.92, 0.92, 0.94))
	var navy := Color(0.07, 0.10, 0.24)
	var orange := Color(1.0, 0.48, 0.1)
	var bands := [[h - 0.15, h - 1.6, navy], [h - 1.6, h - 2.1, orange], [h - 2.1, h - 3.3, navy]]
	for bd in bands:
		var y0: float = bd[0]
		var y1: float = bd[1]
		pk.panel(kit, "awning", [Vector3(0.08, y1, 0), Vector3(0.9, y1, 0), Vector3(0.9, y0, 0), Vector3(0.08, y0, 0)], Vector3(0, 0, 1), bd[2], bd[2])
	# A chequered foot.
	for r in range(2):
		for cc in range(4):
			var col: Color = Color(0.95, 0.95, 0.95) if (r + cc) % 2 == 0 else Color(0.06, 0.06, 0.07)
			var x0: float = 0.08 + cc * 0.205
			var yy: float = h - 3.3 - r * 0.2
			pk.panel(kit, "awning", [Vector3(x0, yy - 0.2, 0.002), Vector3(x0 + 0.205, yy - 0.2, 0.002), Vector3(x0 + 0.205, yy, 0.002), Vector3(x0, yy, 0.002)],
					Vector3(0, 0, 1), col, col)


## A bunch of helium balloons on strings, held at `hand` (life size): `n` balloons in bright colours over it.
static func balloon_bunch(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, hand: Vector3, n := 11) -> void:
	var cols := [Color(1.0, 0.2, 0.25), Color(1.0, 0.8, 0.1), Color(0.2, 0.55, 1.0), Color(0.3, 0.9, 0.4), Color(1.0, 0.45, 0.9), Color(1.0, 0.55, 0.1)]
	for k in range(n):
		var c := hand + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(1.4, 2.4), rng.randf_range(-0.7, 0.7))
		pk.tube(kit, "matte", hand, c - Vector3(0, 0.25, 0), 0.006, 0.006, 3, Color(0.9, 0.9, 0.9), false)
		pk.lathe(kit, "plastic", c - Vector3(0, 0.3, 0), [Vector2(0.001, 0.0), Vector2(0.06, 0.02), Vector2(0.22, 0.18), Vector2(0.27, 0.36), Vector2(0.22, 0.52),
				Vector2(0.001, 0.6)], 10, cols[rng.randi() % cols.size()])


## A round flower bed: a low stone kerb round a mound of flowers (magenta, pink and white blooms over green).
static func flower_bed(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, r := 1.4) -> void:
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(r + 0.12, -0.05), Vector2(r + 0.12, 0.35), Vector2(r - 0.05, 0.35), Vector2(r - 0.05, 0.25)], 16, Color(0.82, 0.76, 0.66))
	pk.lathe(kit, "soil", Vector3(0, 0.25, 0), [Vector2(r - 0.05, 0.0), Vector2(r * 0.6, 0.25), Vector2(0.001, 0.4)], 12, Color(0.18, 0.32, 0.12))
	var cols := [Color(0.9, 0.12, 0.55), Color(1.0, 0.45, 0.7), Color(0.98, 0.96, 0.94), Color(0.75, 0.2, 0.75)]
	for k in range(int(r * r * 14.0)):
		var a: float = rng.randf() * TAU
		var rr: float = sqrt(rng.randf()) * (r - 0.15)
		var y: float = 0.25 + 0.4 * (1.0 - rr / r) + 0.06
		pk.box(kit, "plastic", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * rr, y, sin(a) * rr)), Vector3(0.13, 0.08, 0.13), cols[rng.randi() % cols.size()])


# ======================================================================================
#  Burj al-Fanous, the lantern tower on Jazirat al-Fanous (world metres)
# ======================================================================================

const FANOUS_BODY0 := 46.0
const FANOUS_BODY1 := 236.0
const FANOUS_DRUM_R := 31.0
const FANOUS_TOP := 306.0

## The lantern's radius (to the octagon's corners) at height h: a fanous's bulge, narrowing more to its top.
static func fanous_r(h: float) -> float:
	var t: float = clampf((h - FANOUS_BODY0) / (FANOUS_BODY1 - FANOUS_BODY0), 0.0, 1.0)
	return 30.0 + 20.0 * pow(sin(PI * t), 0.85) - 8.0 * t


## Burj al-Fanous, an original landmark: a 306m lantern of a tower, its foot's middle at the origin on the ground. An
## octagonal podium with steps all round; a drum of pale stone with three tall pointed windows to a face; the lantern
## itself, an octagonal body bulging like a fanous, its faces mashrabiya lattice ("lattice_big") over a glowing core,
## gold ribs up its corners and gold bands round it with lines of light; a ring of lit windows under an octagonal
## onion dome in gold; a spire with three gold orbs and a red beacon. Returns the beacon's height.
static func fanous_tower(pk: PropKit, kit: Dictionary) -> float:
	var pale := Color(0.93, 0.89, 0.81)
	var stone := Color(0.86, 0.76, 0.60)
	var warm := Color(1.0, 0.70, 0.38)
	# The podium: 74m to its corners, 6m high, in three broad steps.
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(78.0, -1.0), Vector2(78.0, 1.6), Vector2(75.0, 1.6), Vector2(75.0, 3.4),
			Vector2(72.0, 3.4), Vector2(72.0, 6.0), Vector2(0.0, 6.0)], 8, pale, true)
	pk.lathe(kit, "led", Vector3.ZERO, [Vector2(78.05, 1.0), Vector2(78.05, 1.3)], 8, warm, true)
	pk.lathe(kit, "led", Vector3.ZERO, [Vector2(72.05, 5.4), Vector2(72.05, 5.7)], 8, warm, true)
	# The drum.
	var dr: float = FANOUS_DRUM_R
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(dr, 6.0), Vector2(dr, 42.0), Vector2(dr + 1.6, 42.6), Vector2(dr + 1.6, 44.6),
			Vector2(fanous_r(FANOUS_BODY0) + 0.4, FANOUS_BODY0)], 8, stone, true)
	pk.lathe(kit, "metal", Vector3.ZERO, [Vector2(dr + 1.65, 43.0), Vector2(dr + 1.65, 44.2)], 8, GOLD, true)
	for k in range(8):
		var a0: float = TAU * float(k) / 8.0
		var a1: float = TAU * float(k + 1) / 8.0
		var c0 := Vector3(cos(a0), 0.0, sin(a0)) * dr
		var c1 := Vector3(cos(a1), 0.0, sin(a1)) * dr
		var mid: Vector3 = (c0 + c1) * 0.5
		var out: Vector3 = mid.normalized()
		var along: Vector3 = (c1 - c0).normalized()
		var face_w: float = c0.distance_to(c1)
		for wi in range(3):
			var cx: float = (float(wi) - 1.0) * face_w * 0.28
			var w: float = face_w * 0.085
			var base: Vector3 = mid + out * 0.08 + along * cx
			var y0 := 11.0
			var y1 := 31.0
			var top := 36.5
			var pts := [base + along * -w + Vector3(0, y0, 0), base + along * w + Vector3(0, y0, 0), base + along * w + Vector3(0, y1, 0),
					base + Vector3(0, top, 0), base + along * -w + Vector3(0, y1, 0)]
			pk.tri(kit, "glasslit", pts[0], pts[1], pts[2], out, out, out, warm, out)
			pk.tri(kit, "glasslit", pts[0], pts[2], pts[4], out, out, out, warm, out)
			pk.tri(kit, "glasslit", pts[4], pts[2], pts[3], out, out, out, warm, out)
			# A gold frame round it.
			for e in range(5):
				var pa: Vector3 = pts[e]
				var pb: Vector3 = pts[(e + 1) % 5]
				pk.beam(kit, "metal", pa + out * 0.1, pb + out * 0.1, 0.35, 0.25, GOLD, out)
	# The lantern: stations up its height, a lattice panel to each face between them, gold ribs and bands.
	var hs: Array = []
	var nst := 12
	for i in range(nst + 1):
		hs.append(lerpf(FANOUS_BODY0, FANOUS_BODY1, float(i) / float(nst)))
	var core_prof: Array = []
	for i in range(nst + 1):
		var h: float = hs[i]
		core_prof.append(Vector2(fanous_r(h) * 0.78, h))
	pk.lathe(kit, "led", Vector3.ZERO, core_prof, 8, Color(1.0, 0.62, 0.30), true)
	for k in range(8):
		var a0: float = TAU * float(k) / 8.0
		var a1: float = TAU * float(k + 1) / 8.0
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var v := 0.0
		for i in range(nst):
			var h0: float = hs[i]
			var h1: float = hs[i + 1]
			var r0: float = fanous_r(h0)
			var r1: float = fanous_r(h1)
			var p00: Vector3 = d0 * r0 + Vector3(0, h0, 0)
			var p01: Vector3 = d1 * r0 + Vector3(0, h0, 0)
			var p11: Vector3 = d1 * r1 + Vector3(0, h1, 0)
			var p10: Vector3 = d0 * r1 + Vector3(0, h1, 0)
			var w0: float = p00.distance_to(p01)
			var w1: float = p10.distance_to(p11)
			var dv: float = ((p00 + p01) * 0.5).distance_to((p10 + p11) * 0.5)
			var n: Vector3 = (p01 - p00).cross(p10 - p00).normalized()
			if n.dot((p00 + p01) * 0.5 - Vector3(0, h0, 0)) < 0.0:
				n = -n
			pk.quad(kit, "lattice_big", [p00, p01, p11, p10], n, Color(1, 1, 1),
					[Vector2(-w0 * 0.5, v), Vector2(w0 * 0.5, v), Vector2(w1 * 0.5, v + dv), Vector2(-w1 * 0.5, v + dv)])
			v += dv
			# The corner rib.
			pk.tube(kit, "metal", d0 * (r0 + 0.6) + Vector3(0, h0, 0), d0 * (r1 + 0.6) + Vector3(0, h1, 0), 1.25, 1.25, 8, GOLD, false)
	# Bands round it, each with a line of light.
	for i in range(0, nst + 1, 3):
		var h: float = hs[i]
		var r: float = fanous_r(h)
		pk.lathe(kit, "metal", Vector3.ZERO, [Vector2(r + 1.4, h - 1.6), Vector2(r + 1.4, h + 1.6)], 8, GOLD, true)
		pk.lathe(kit, "led", Vector3.ZERO, [Vector2(r + 1.45, h - 0.25), Vector2(r + 1.45, h + 0.25)], 8, warm, true)
	# Under the dome: a ring of lit windows; the dome, octagonal, an onion of gold.
	var rt: float = fanous_r(FANOUS_BODY1)
	pk.lathe(kit, "marble", Vector3.ZERO, [Vector2(rt + 0.5, FANOUS_BODY1), Vector2(rt - 1.0, FANOUS_BODY1 + 1.0), Vector2(rt - 1.0, FANOUS_BODY1 + 9.0)], 8, stone, true)
	pk.lathe(kit, "glasslit", Vector3.ZERO, [Vector2(rt - 0.95, FANOUS_BODY1 + 3.0), Vector2(rt - 0.95, FANOUS_BODY1 + 7.0)], 16, warm, true)
	var dome: Array = []
	var dome_h := 40.0
	# An onion: out past the drum, then in to a drawn-up point (radius and height as shares of the base's).
	var onion := [1.0, 1.12, 1.18, 1.14, 1.02, 0.84, 0.62, 0.40, 0.22, 0.09, 0.0]
	for i in range(onion.size()):
		var t: float = float(i) / float(onion.size() - 1)
		dome.append(Vector2((rt - 1.0) * float(onion[i]), FANOUS_BODY1 + 9.0 + dome_h * t))
	# Floodlit gold: it glows softly.
	pk.lathe(kit, "led", Vector3.ZERO, dome, 8, Color(0.30, 0.20, 0.07), true)
	var spire0: float = FANOUS_BODY1 + 9.0 + dome_h - 2.0
	pk.tube(kit, "metal", Vector3(0, spire0, 0), Vector3(0, FANOUS_TOP, 0), 1.5, 0.25, 8, GOLD, true)
	for o in [[spire0 + 6.0, 2.3], [spire0 + 13.0, 1.7], [spire0 + 19.0, 1.2]]:
		var oy: float = o[0]
		var orr: float = o[1]
		var prof: Array = []
		for i in range(9):
			var t2: float = PI * float(i) / 8.0
			prof.append(Vector2(sin(t2) * orr, oy - cos(t2) * orr))
		pk.lathe(kit, "metal", Vector3.ZERO, prof, 12, GOLD)
	var bprof: Array = []
	for i in range(7):
		var t3: float = PI * float(i) / 6.0
		bprof.append(Vector2(sin(t3) * 0.9, FANOUS_TOP + 0.9 - cos(t3) * 0.9))
	pk.lathe(kit, "led", Vector3.ZERO, bprof, 8, Color(1.0, 0.15, 0.1))
	return FANOUS_TOP + 0.9


# ======================================================================================
#  The suspended railway's car (life size: the generator grows it by PS)
# ======================================================================================

const CAR_LEN := 10.6
const CAR_W := 2.25
const CAR_ROOF := -1.45
const CAR_FLOOR := -3.75
const CAR_BOTTOM := -4.05

## One car of the suspended railway's train, hanging from its rail: the origin is on the rail's running surface over
## the car's middle, the car below it, its length along z, a driver's cab at -z when `cab` (else a gangway). Two bogies
## run on the rail (wheels on top, the frame round it), each with a hanger arm down to the roof. A rounded body
## in white with a teal band and a gold line under a band of windows (lit: "glasslit"), sliding doors, a dark skirt;
## at the cab a raked windscreen, headlamps and the tail lamps. Pairs with the next car turned round, cab to cab
## outward.
static func hanging_car(pk: PropKit, kit: Dictionary, cab: bool) -> void:
	var white := Color(0.93, 0.94, 0.95)
	var teal := Color(0.05, 0.42, 0.46)
	var dark := Color(0.12, 0.13, 0.15)
	var steel := Color(0.55, 0.57, 0.6)
	var warm := Color(1.0, 0.82, 0.55)
	var hl: float = CAR_LEN * 0.5
	# Bogies and hangers.
	for bz in [-hl + 2.0, hl - 2.0]:
		pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(0.0, -0.12, bz)), Vector3(0.9, 0.5, 2.0), steel)
		for wz in [-0.55, 0.55]:
			pk.tyre(kit, "metal", Vector3(0.0, 0.32, bz + wz), 0.08, 0.32, 0.22, 12, dark, Basis(Vector3(0, 0, 1), PI * 0.5))
		pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(0.62, -0.62, bz)), Vector3(0.24, 1.2, 0.9), steel)
		pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(0.3, CAR_ROOF + 0.1, bz)), Vector3(0.9, 0.24, 0.9), steel)
		pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(0.62, CAR_ROOF + 0.45, bz)), Vector3(0.24, 0.9, 0.9), steel)
	# The body: a rounded section extruded along the car, bevelled at its ends.
	var sec := PackedVector2Array()
	var hw: float = CAR_W * 0.5
	var corners := [[Vector2(hw - 0.42, CAR_ROOF - 0.42), 0.42, 0.0], [Vector2(-hw + 0.42, CAR_ROOF - 0.42), 0.42, PI * 0.5],
			[Vector2(-hw + 0.3, CAR_BOTTOM + 0.3), 0.3, PI], [Vector2(hw - 0.3, CAR_BOTTOM + 0.3), 0.3, PI * 1.5]]
	for c in corners:
		for i in range(5):
			var a: float = float(c[2]) + PI * 0.5 * float(i) / 4.0
			sec.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * float(c[1]))
	var z0: float = -hl + (0.0 if not cab else 0.9)
	pk.extrude(kit, "hull", sec, z0, hl, 0.18, white)
	if cab:
		# The cab: the section narrowing and dropping to a raked nose, the windscreen across it.
		var nose := PackedVector2Array()
		for q in sec:
			nose.append(Vector2(q.x * 0.9, (q.y - (CAR_ROOF + CAR_BOTTOM) * 0.5) * 0.82 + (CAR_ROOF + CAR_BOTTOM) * 0.5 - 0.12))
		pk.extrude(kit, "hull", nose, -hl, z0 + 0.05, 0.3, white)
		# Within the nose's front face (the bevel's inset).
		var wy0: float = -2.18
		var wy1: float = -2.95
		var ws := [Vector3(-0.62, wy0, -hl - 0.01), Vector3(0.62, wy0, -hl - 0.01), Vector3(0.62, wy1, -hl - 0.01), Vector3(-0.62, wy1, -hl - 0.01)]
		pk.quad(kit, "yglass", ws, Vector3(0, 0, -1), dark)
		for sd in [-1.0, 1.0]:
			pk.box(kit, "led", Transform3D(Basis(), Vector3(sd * 0.36, -3.32, -hl - 0.02)), Vector3(0.3, 0.13, 0.05), warm)
			pk.box(kit, "led", Transform3D(Basis(), Vector3(sd * 0.6, -3.32, -hl - 0.02)), Vector3(0.1, 0.13, 0.05), Color(1.0, 0.1, 0.06))
	else:
		# A gangway's bellows to the next car.
		pk.box(kit, "matte", Transform3D(Basis(), Vector3(0.0, (CAR_ROOF + CAR_BOTTOM) * 0.5 + 0.1, -hl - 0.15)), Vector3(1.5, 2.0, 0.34), dark)
	# Livery and windows, each side.
	for sd in [-1.0, 1.0]:
		var x: float = sd * (hw + 0.012)
		var n := Vector3(sd, 0, 0)
		var zs: float = z0 + 0.4
		var ze: float = hl - 0.5
		pk.quad(kit, "hull", [Vector3(x, CAR_FLOOR, zs), Vector3(x, CAR_FLOOR, ze), Vector3(x, CAR_FLOOR + 0.28, ze), Vector3(x, CAR_FLOOR + 0.28, zs)], n, teal)
		pk.quad(kit, "metal", [Vector3(x + sd * 0.004, CAR_FLOOR + 0.3, zs), Vector3(x + sd * 0.004, CAR_FLOOR + 0.3, ze), Vector3(x + sd * 0.004, CAR_FLOOR + 0.36, ze),
				Vector3(x + sd * 0.004, CAR_FLOOR + 0.36, zs)], n, GOLD)
		# The window band, cut by two doors (their own windows taller).
		var wy0: float = CAR_FLOOR + 0.95
		var wy1: float = CAR_ROOF - 0.5
		var doors: Array = [-hl * 0.42, hl * 0.42]
		var z := zs + 0.2
		var edges: Array = [z]
		for dz in doors:
			edges.append(float(dz) - 0.75)
			edges.append(float(dz) + 0.75)
		edges.append(ze - 0.2)
		for e in range(0, edges.size(), 2):
			var za: float = edges[e]
			var zb: float = edges[e + 1]
			pk.quad(kit, "glasslit", [Vector3(x + sd * 0.006, wy0, za), Vector3(x + sd * 0.006, wy0, zb), Vector3(x + sd * 0.006, wy1, zb), Vector3(x + sd * 0.006, wy1, za)], n, warm)
		for dz in doors:
			var za2: float = float(dz) - 0.65
			var zb2: float = float(dz) + 0.65
			pk.quad(kit, "matte", [Vector3(x + sd * 0.005, CAR_FLOOR + 0.05, za2), Vector3(x + sd * 0.005, CAR_FLOOR + 0.05, zb2), Vector3(x + sd * 0.005, CAR_ROOF - 0.48, zb2),
					Vector3(x + sd * 0.005, CAR_ROOF - 0.48, za2)], n, Color(0.62, 0.64, 0.68))
			pk.quad(kit, "glasslit", [Vector3(x + sd * 0.01, CAR_FLOOR + 0.6, za2 + 0.12), Vector3(x + sd * 0.01, CAR_FLOOR + 0.6, zb2 - 0.12),
					Vector3(x + sd * 0.01, CAR_ROOF - 0.6, zb2 - 0.12), Vector3(x + sd * 0.01, CAR_ROOF - 0.6, za2 + 0.12)], n, warm)
