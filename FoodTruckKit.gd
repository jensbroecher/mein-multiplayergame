extends "res://MatatuKit.gd"
## A food truck at life size, for Nyota Stadium's fan zone: a van cab (MatatuKit's HiAce front, wheels, lamps and
## lettering) with a box body behind it: a serving hatch on the +x side with an open striped awning, a stainless
## counter, shelves of bottles under a lamp, a menu board, a lit roof sign, an air-conditioner and a chimney on the
## roof, rear doors, gas bottles and a generator. The nose is toward -z like the matatu; the caller scales it.
## Five material keys, as for the matatu (`make_material`).

const BOX_Z0 := -0.82
const BOX_Z1 := 3.06
const BOX_Y0 := 0.80
const BOX_Y1 := 3.05
const BOX_HW := 1.05
const CAB_END := -0.85

## `liv` is the cab's livery (the matatu's fields: base, upper, roof, neon, plate); the rest is the truck's.
##   name, tag     the big lettering and the line under it
##   box           the body's colour        stripe, accent   artwork colours       txt, shd   lettering and its shadow
##   menu          the lines on the board   art              "stripes", "flames" or "stars"
const TRUCKS := [
	{"name": "CHAI NA MANDAZI", "tag": "TEA - COFFEE - SNACKS", "box": Color(0.97, 0.78, 0.10), "stripe": Color(0.45, 0.22, 0.08), "accent": Color(0.95, 0.45, 0.10),
			"txt": Color(0.30, 0.14, 0.05), "shd": Color(1.0, 0.95, 0.75), "art": "stripes", "menu": ["CHAI 50", "KAHAWA 80", "MANDAZI 20", "SAMOSA 30"],
			"liv": {"base": Color(0.93, 0.93, 0.91), "upper": Color(0.93, 0.93, 0.91), "roof": Color(0.93, 0.93, 0.91), "neon": Color(1.0, 0.6, 0.15), "plate": "KDD 612N", "slogan": "KARIBU CHAI"}},
	{"name": "NYAMA CHOMA", "tag": "GRILL EXPRESS", "box": Color(0.78, 0.11, 0.09), "stripe": Color(0.98, 0.80, 0.10), "accent": Color(1.0, 0.55, 0.08),
			"txt": Color(1.0, 0.92, 0.55), "shd": Color(0.18, 0.02, 0.02), "art": "flames", "menu": ["NYAMA 350", "UGALI 80", "KACHUMBARI 60", "SODA 50"],
			"liv": {"base": Color(0.06, 0.06, 0.07), "upper": Color(0.06, 0.06, 0.07), "roof": Color(0.06, 0.06, 0.07), "neon": Color(1.0, 0.35, 0.05), "plate": "KCC 305J", "slogan": "MOTO MOTO"}},
	{"name": "PIZZA SAFARI", "tag": "WOOD FIRED", "box": Color(0.12, 0.40, 0.78), "stripe": Color(0.95, 0.95, 0.93), "accent": Color(1.0, 0.55, 0.12),
			"txt": Color(1.0, 0.97, 0.90), "shd": Color(0.03, 0.12, 0.30), "art": "stars", "menu": ["PIZZA 500", "CHEESE 450", "NYAMA 600", "SODA 50"],
			"liv": {"base": Color(0.93, 0.93, 0.91), "upper": Color(0.93, 0.93, 0.91), "roof": Color(0.93, 0.93, 0.91), "neon": Color(0.30, 0.65, 1.0), "plate": "KDA 918C", "slogan": "SAFARI NJEMA"}},
]

var _spec := {}


func _init(kit: PropKit) -> void:
	super(kit)


## The cab ends behind the doors; the box carries on. Stations stop at CAB_END.
func _station_zs() -> Array:
	var zs: Array = super()
	var out: Array = []
	for z in zs:
		if float(z) <= CAB_END:
			out.append(float(z))
	if out[out.size() - 1] < CAB_END - 0.011:
		out.append(CAB_END)
	return out


## Only the nose is rounded: the cab's back is closed flat against the box.
func _cap_scale(z: float) -> float:
	var t := clampf((z - Z_NOSE) / 0.045, 0.0, 1.0)
	return 0.91 + 0.09 * pow(1.0 - pow(1.0 - t, 4.0), 0.25)


func build_truck(spec: Dictionary) -> ArrayMesh:
	_spec = spec
	_liv = spec["liv"]
	_kit = {}
	_build_shell()
	_build_liners()
	for az in [AXLE_F, AXLE_R]:
		for side in [-1.0, 1.0]:
			_wheel(az, side)
	_cab_glass()
	_cab_doors()
	_build_front()
	_build_box()
	_build_art_panels()
	_build_hatch()
	_build_menu()
	_build_roof()
	_build_rear_end()
	_build_underbody()
	return _k.commit(_kit)


# ---------------------------------------------------------------------------------------------
#  The cab
# ---------------------------------------------------------------------------------------------

func _cab_glass() -> void:
	var glass := Color(0.03, 0.045, 0.06)
	var wn := _windscreen_normal()
	var ws_surface := func(x0: float, x1: float, z0: float, z1: float, lift: float) -> Callable:
		return func(u: float, v: float) -> Vector3:
			return _roof_pt(lerpf(x0, x1, u), lerpf(z0, z1, v)) + wn * lift
	_grid("matte", ws_surface.call(-0.78, 0.78, -1.935, -1.265, 0.007), 6, 1, func(_u: float, _v: float) -> Color: return RUBBER, wn)
	_grid("glass", ws_surface.call(-0.745, 0.745, -1.915, -1.285, 0.013), 6, 1, func(_u: float, v: float) -> Color: return glass.lerp(Color(0.10, 0.15, 0.22), v * 0.5), wn)
	# Door windows (the front edge follows the A-pillar, the back is the cab's end).
	for side in [-1.0, 1.0]:
		_side_window(side, [Vector2(-1.50, 1.28), Vector2(-0.98, 1.28), Vector2(-0.98, 1.96), Vector2(-1.22, 1.96)])


func _cab_doors() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * (HW + 0.022)
		_seam(side, -0.99, 0.42, -0.99, 1.26)
		_seam(side, -1.56, 0.95, -1.56, 1.26)
		_seam(side, -1.56, 1.26, -0.99, 1.26)
		_k.beam(_kit, "chrome", Vector3(x, 1.10, -1.14), Vector3(x, 1.10, -1.00), 0.026, 0.02, CHROME, Vector3.UP)
		var mx: float = side * 1.045
		_k.beam(_kit, "matte", Vector3(side * 0.92, 1.30, -1.42), Vector3(side * 1.03, 1.36, -1.40), 0.035, 0.03, BLACK, Vector3.UP)
		_prism("matte", _rrect(minf(side * 1.00, side * 1.09), maxf(side * 1.00, side * 1.09), -1.50, -1.34, 0.04, 3), 1.28, 1.48, BLACK)
		_k.quad(_kit, "glass", [Vector3(mx - 0.036, 1.30, -1.338), Vector3(mx + 0.036, 1.30, -1.338), Vector3(mx + 0.036, 1.46, -1.338), Vector3(mx - 0.036, 1.46, -1.338)], Vector3(0, 0, 1), Color(0.18, 0.22, 0.27))
		_k.block(_kit, "lamp", Vector3(side * (HW - 0.004), 0.70, -2.18), Vector3(side * (HW + 0.02), 0.76, -2.06), Color(1.0, 0.55, 0.05))


# ---------------------------------------------------------------------------------------------
#  The box
# ---------------------------------------------------------------------------------------------

## A flat paint shape on a side of the box (z, y points), `off` proud.
func _bpoly(side: float, poly: PackedVector2Array, col: Color, off: float, key := "paint") -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	var n := Vector3(side, 0, 0)
	var x: float = side * (BOX_HW + off)
	for i in range(0, tris.size(), 3):
		var a := poly[tris[i]]
		var b := poly[tris[i + 1]]
		var c := poly[tris[i + 2]]
		_k.tri(_kit, key, Vector3(x, a.y, a.x), Vector3(x, b.y, b.x), Vector3(x, c.y, c.x), n, n, n, col, n)


func _brect(side: float, z0: float, y0: float, z1: float, y1: float, col: Color, off: float, key := "paint") -> void:
	_bpoly(side, PackedVector2Array([Vector2(z0, y0), Vector2(z1, y0), Vector2(z1, y1), Vector2(z0, y1)]), col, off, key)


func _bribbon(side: float, z0: float, z1: float, y_c: Callable, w: Callable, col: Color, off: float, steps := 24) -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in range(steps + 1):
		var s := float(i) / float(steps)
		var z := lerpf(z0, z1, s)
		var yc: float = y_c.call(s)
		var hw: float = w.call(s)
		top.append(Vector2(z, yc + hw))
		bot.append(Vector2(z, yc - hw))
	bot.reverse()
	top.append_array(bot)
	_bpoly(side, top, col, off)


## Lettering on the box's side, reading toward the nose on +x and toward the tail on -x.
func _btext(side: float, zc: float, yc: float, cell: float, text: String, col: Color, shadow: Color, slant := 0.12, key := "paint", lift := 0.0) -> void:
	var right := Vector3(0, 0, -side)
	var n := Vector3(side, 0, 0)
	var base := Vector3(side * BOX_HW, yc, zc)
	if shadow.a > 0.0:
		_text(key, base + n * (L4 + lift) - right * cell * 0.30 - Vector3(0, cell * 0.30, 0), right, Vector3.UP, cell, text, shadow, slant)
	_text(key, base + n * (L5 + lift), right, Vector3.UP, cell, text, col, slant)


func _build_box() -> void:
	var box_col: Color = _spec["box"]
	_prism("paint", _rrect(-BOX_HW, BOX_HW, BOX_Z0, BOX_Z1, 0.14, 4), BOX_Y0, BOX_Y1, box_col)
	# A rain gutter round the roof, a dark sill, and the joint against the cab.
	_prism("matte", _rrect(-BOX_HW - 0.018, BOX_HW + 0.018, BOX_Z0 - 0.018, BOX_Z1 + 0.018, 0.15, 4), BOX_Y1 - 0.06, BOX_Y1 + 0.025, Color(0.55, 0.57, 0.6))
	_prism("matte", _rrect(-BOX_HW - 0.015, BOX_HW + 0.015, BOX_Z0 - 0.015, BOX_Z1 + 0.015, 0.15, 4), BOX_Y0, BOX_Y0 + 0.16, Color(0.10, 0.10, 0.11))


func _build_art_panels() -> void:
	var stripe: Color = _spec["stripe"]
	var accent: Color = _spec["accent"]
	var box_col: Color = _spec["box"]
	var name_s: String = _spec["name"]
	var tag: String = _spec["tag"]
	for side in [-1.0, 1.0]:
		# A band along the bottom of the body, and a thin line over it.
		_brect(side, BOX_Z0 + 0.12, 0.98, BOX_Z1 - 0.12, 1.20, stripe, L0)
		_brect(side, BOX_Z0 + 0.12, 1.24, BOX_Z1 - 0.12, 1.28, accent, L0)
		if side > 0.0:
			continue
		match _spec["art"]:
			"flames":
				var k := 0
				var z0 := BOX_Z0 + 0.15
				while z0 < BOX_Z1 - 0.4:
					var h := 0.30 + 0.12 * sin(float(k) * 2.3)
					_bpoly(side, _flame_poly(z0, 1.28, 0.30, h, 0.30), accent, L1)
					_bpoly(side, _flame_poly(z0 + 0.04, 1.28, 0.21, h * 0.7, 0.2), Color(1.0, 0.85, 0.20), L2)
					z0 += 0.30
					k += 1
			"stars":
				for st in [[0.0, 1.62, 0.10], [0.9, 1.50, 0.07], [2.0, 1.66, 0.09], [2.65, 1.52, 0.07], [-0.4, 1.46, 0.06]]:
					_bpoly(side, _star_poly(Vector2(float(st[0]), float(st[1])), float(st[2])), accent, L1)
			_:
				_bribbon(side, BOX_Z0 + 0.12, BOX_Z1 - 0.12, func(s: float) -> float: return 1.56 + 0.05 * sin(s * TAU), func(_s: float) -> float: return 0.035, accent, L1)
	# The name big on the left (kerb) side, the tag under it; the serving side has the name over the hatch, smaller.
	var cell := minf(0.072, 3.5 / float(text_cells(name_s)))
	_btext(-1.0, 1.15, 2.50, cell, name_s, _spec["txt"], _spec["shd"])
	_btext(-1.0, 1.15, 2.14, cell * 0.5, tag, _spec["txt"], Color(0, 0, 0, 0), 0.0)
	_btext(1.0, 1.52, 2.90, minf(0.040, 2.2 / float(text_cells(name_s))), name_s, _spec["txt"], _spec["shd"])
	# A service door on the kerb side, with its handle.
	var door_col := Color(0.05, 0.05, 0.06)
	_brect(-1.0, 1.90, 0.95, 2.86, 0.975, door_col, 0.004, "matte")
	_brect(-1.0, 1.90, 1.975, 2.86, 2.0, door_col, 0.004, "matte")
	_brect(-1.0, 1.90, 0.95, 1.925, 2.0, door_col, 0.004, "matte")
	_brect(-1.0, 2.835, 0.95, 2.86, 2.0, door_col, 0.004, "matte")
	_k.beam(_kit, "chrome", Vector3(-BOX_HW - 0.03, 1.35, 2.05), Vector3(-BOX_HW - 0.03, 1.65, 2.05), 0.03, 0.03, CHROME, Vector3(1, 0, 0))


# ---------------------------------------------------------------------------------------------
#  The serving hatch
# ---------------------------------------------------------------------------------------------

func _build_hatch() -> void:
	var x := BOX_HW
	var z0 := 0.15
	var z1 := 2.55
	var y0 := 1.46
	var y1 := 2.52
	# The opening: a dark interior with a stainless frame; the shelves and bottles stand in it.
	_blk("chrome", Vector3(x + 0.004, y0 - 0.06, z0 - 0.06), Vector3(x + 0.03, y1 + 0.06, z0), CHROME)
	_blk("chrome", Vector3(x + 0.004, y0 - 0.06, z1), Vector3(x + 0.03, y1 + 0.06, z1 + 0.06), CHROME)
	_blk("chrome", Vector3(x + 0.004, y1, z0), Vector3(x + 0.03, y1 + 0.06, z1), CHROME)
	_k.quad(_kit, "matte", [Vector3(x + 0.008, y0, z0), Vector3(x + 0.008, y0, z1), Vector3(x + 0.008, y1, z1), Vector3(x + 0.008, y1, z0)], Vector3(1, 0, 0), Color(0.07, 0.07, 0.08))
	# Inside: a back wall of warm light, shelves, bottles and tins.
	_blk("lamp", Vector3(x + 0.010, y1 - 0.10, z0 + 0.06), Vector3(x + 0.022, y1 - 0.04, z1 - 0.06), Color(1.0, 0.92, 0.72))
	for sy in [1.86, 2.16]:
		_blk("chrome", Vector3(x + 0.010, sy, z0 + 0.04), Vector3(x + 0.18, sy + 0.025, z1 - 0.04), Color(0.70, 0.72, 0.74))
		var k := 0
		var zz := z0 + 0.14
		while zz < z1 - 0.12:
			var bcol: Color = [Color(0.85, 0.12, 0.10), Color(0.95, 0.55, 0.10), Color(0.10, 0.55, 0.25), Color(0.93, 0.93, 0.90), Color(0.15, 0.30, 0.70)][(k + int(sy * 10.0)) % 5]
			var hgt := 0.16 + 0.05 * float((k * 7) % 3)
			_k.tube(_kit, "paint", Vector3(x + 0.10, sy + 0.025, zz), Vector3(x + 0.10, sy + 0.025 + hgt, zz), 0.032, 0.026, 6, bcol)
			zz += 0.17
			k += 1
	# Counter: a stainless slab out from the wall, with a lip, and a till.
	_blk("chrome", Vector3(x, y0 - 0.06, z0 - 0.12), Vector3(x + 0.42, y0 - 0.02, z1 + 0.12), Color(0.80, 0.82, 0.84))
	_blk("chrome", Vector3(x + 0.40, y0 - 0.02, z0 - 0.12), Vector3(x + 0.42, y0 + 0.025, z1 + 0.12), Color(0.80, 0.82, 0.84))
	_blk("matte", Vector3(x + 0.08, y0 - 0.02, 0.45), Vector3(x + 0.34, y0 + 0.14, 0.85), Color(0.12, 0.12, 0.13))
	_blk("lamp", Vector3(x + 0.10, y0 + 0.06, 0.47), Vector3(x + 0.21, y0 + 0.12, 0.62), Color(0.55, 1.0, 0.65))
	# Under the counter: a skirt in the livery's stripe colour, with a service shelf.
	# The awning: striped, propped out over the counter on two stainless arms, with a valance.
	var stripes := 8
	var a_in_y := 2.72
	var a_out_y := 2.46
	var a_out_x := x + 0.95
	var accent: Color = _spec["accent"]
	var cloth: Array = [Color(0.96, 0.95, 0.92), accent]
	for i in range(stripes):
		var za := z0 - 0.15 + (z1 - z0 + 0.30) * float(i) / float(stripes)
		var zb := z0 - 0.15 + (z1 - z0 + 0.30) * float(i + 1) / float(stripes)
		var c: Color = cloth[i % 2]
		var n := Vector3(0.28, 1.0, 0.0).normalized()
		_k.quad(_kit, "paint", [Vector3(x + 0.01, a_in_y, za), Vector3(a_out_x, a_out_y, za), Vector3(a_out_x, a_out_y, zb), Vector3(x + 0.01, a_in_y, zb)], n, c)
		_k.quad(_kit, "matte", [Vector3(x + 0.01, a_in_y - 0.012, zb), Vector3(a_out_x, a_out_y - 0.012, zb), Vector3(a_out_x, a_out_y - 0.012, za), Vector3(x + 0.01, a_in_y - 0.012, za)], -n, c * 0.7)
		# The valance hanging from the edge.
		_k.quad(_kit, "paint", [Vector3(a_out_x, a_out_y, za), Vector3(a_out_x + 0.02, a_out_y - 0.18, za), Vector3(a_out_x + 0.02, a_out_y - 0.18, zb), Vector3(a_out_x, a_out_y, zb)], Vector3(1, 0, 0), c)
	for zarm in [z0 - 0.10, z1 + 0.10]:
		_k.beam(_kit, "chrome", Vector3(x + 0.02, 2.50, zarm), Vector3(a_out_x - 0.03, a_out_y - 0.015, zarm), 0.04, 0.03, CHROME, Vector3(0, 0, 1))
	# String lights along the awning's edge.
	for i in range(9):
		var zl := z0 - 0.05 + (z1 - z0 + 0.10) * float(i) / 8.0
		_k.tube(_kit, "lamp", Vector3(a_out_x + 0.02, a_out_y - 0.22, zl), Vector3(a_out_x + 0.02, a_out_y - 0.27, zl), 0.032, 0.026, 6, Color(1.0, 0.88, 0.55))


func _build_menu() -> void:
	var x := BOX_HW
	# A blackboard by the hatch with the day's menu and prices in chalk.
	_blk("matte", Vector3(x, 1.50, -0.62), Vector3(x + 0.035, 2.50, -0.04), Color(0.09, 0.10, 0.10))
	_blk("chrome", Vector3(x, 1.46, -0.66), Vector3(x + 0.045, 1.50, -0.00), Color(0.60, 0.62, 0.64))
	_blk("chrome", Vector3(x, 2.50, -0.66), Vector3(x + 0.045, 2.54, -0.00), Color(0.60, 0.62, 0.64))
	var menu: Array = _spec["menu"]
	_btext(1.0, -0.33, 2.38, 0.030, "MENU", Color(1.0, 0.92, 0.55), Color(0, 0, 0, 0), 0.0, "matte", 0.04)
	for i in range(menu.size()):
		var line: String = menu[i]
		var cell := minf(0.022, 0.50 / float(text_cells(line)))
		_btext(1.0, -0.33, 2.20 - 0.14 * float(i), cell, line, Color(0.96, 0.96, 0.92), Color(0, 0, 0, 0), 0.0, "matte", 0.04)


# ---------------------------------------------------------------------------------------------
#  Roof, rear, underbody
# ---------------------------------------------------------------------------------------------

func _build_roof() -> void:
	var y := BOX_Y1 + 0.025
	# An air-conditioner with its fan, a chimney with a cap, a vent, and a lit roof sign along the serving side.
	_prism("matte", _rrect(-0.55, 0.45, 1.00, 1.75, 0.08, 3), y, y + 0.30, Color(0.84, 0.85, 0.86))
	_k.lathe(_kit, "matte", Vector3(-0.05, y + 0.30, 1.375), [Vector2(0.28, 0.0), Vector2(0.26, 0.012), Vector2(0.0, 0.012)], 14, Color(0.10, 0.10, 0.11))
	for fi in range(4):
		var a := PI * 0.25 + PI * 0.5 * float(fi)
		_k.beam(_kit, "matte", Vector3(-0.05, y + 0.32, 1.375), Vector3(-0.05 + cos(a) * 0.26, y + 0.32, 1.375 + sin(a) * 0.26), 0.02, 0.012, Color(0.2, 0.2, 0.22), Vector3.UP)
	_k.tube(_kit, "chrome", Vector3(-0.60, y, 0.35), Vector3(-0.60, y + 0.85, 0.35), 0.11, 0.11, 10, Color(0.75, 0.77, 0.80))
	_k.lathe(_kit, "chrome", Vector3(-0.60, y + 0.85, 0.35), [Vector2(0.0, 0.0), Vector2(0.20, 0.0), Vector2(0.18, 0.08), Vector2(0.0, 0.16)], 10, Color(0.75, 0.77, 0.80))
	_blk("matte", Vector3(0.45, y, 0.30), Vector3(0.85, y + 0.20, 0.70), Color(0.62, 0.64, 0.66))
	# The sign: a dark box with the name in glowing letters, readable from the serving side.
	var name_s: String = _spec["name"]
	_blk("matte", Vector3(0.80, y, 0.20), Vector3(0.90, y + 0.50, 2.80), Color(0.07, 0.07, 0.08))
	_blk("matte", Vector3(0.80, y + 0.50, 0.20), Vector3(0.96, y + 0.54, 2.80), Color(0.5, 0.52, 0.55))
	var cell := minf(0.04, 2.3 / float(text_cells(name_s)))
	_text("lamp", Vector3(0.915, y + 0.25, 1.50), Vector3(0, 0, -1), Vector3.UP, cell, name_s, _spec["accent"], 0.0)
	# Pennants on a string over the sign, between two poles.
	var py := y + 0.78
	for zp in [0.20, 2.80]:
		_k.tube(_kit, "matte", Vector3(0.93, y + 0.50, zp), Vector3(0.93, py + 0.04, zp), 0.014, 0.014, 5, Color(0.15, 0.15, 0.16))
	_k.beam(_kit, "matte", Vector3(0.93, py, 0.20), Vector3(0.93, py, 2.80), 0.012, 0.012, Color(0.15, 0.15, 0.16), Vector3(1, 0, 0))
	for i in range(12):
		var zz := 0.30 + 0.205 * float(i)
		var pc: Color = [Color(0.95, 0.42, 0.06), Color(0.96, 0.78, 0.12), Color(0.08, 0.45, 0.22), Color(0.85, 0.15, 0.12)][i % 4]
		var nn := Vector3(1, 0, 0)
		_k.tri(_kit, "paint", Vector3(0.93, py, zz), Vector3(0.93, py, zz + 0.16), Vector3(0.93, py - 0.20, zz + 0.08), nn, nn, nn, pc, nn)


func _build_rear_end() -> void:
	var z := BOX_Z1
	# Bumper with a step, doors with handles, lamps, a plate and a welcome.
	_prism("matte", _rrect(-0.98, 0.98, z - 0.06, z + 0.20, 0.10, 4), 0.34, 0.68, BLACK)
	_k.beam(_kit, "chrome", Vector3(-0.78, 0.70, z + 0.20), Vector3(0.78, 0.70, z + 0.20), 0.04, 0.02, CHROME, Vector3.BACK)
	var rn := Vector3(0, 0, 1)
	# Door joints.
	_k.quad(_kit, "matte", [Vector3(-0.012, 0.88, z + 0.004), Vector3(0.012, 0.88, z + 0.004), Vector3(0.012, 2.90, z + 0.004), Vector3(-0.012, 2.90, z + 0.004)], rn, Color(0.06, 0.06, 0.07))
	for sx in [-1.0, 1.0]:
		_k.beam(_kit, "chrome", Vector3(sx * 0.10, 1.80, z + 0.03), Vector3(sx * 0.10, 2.15, z + 0.03), 0.035, 0.03, CHROME, Vector3(1, 0, 0))
		# Lamp clusters at the corners.
		var xa := minf(sx * 0.72, sx * 0.96)
		var xb := maxf(sx * 0.72, sx * 0.96)
		_blk("matte", Vector3(xa - 0.01, 0.92, z), Vector3(xb + 0.01, 1.62, z + 0.028), BLACK)
		_blk("lamp", Vector3(xa, 1.24, z + 0.026), Vector3(xb, 1.58, z + 0.038), Color(0.85, 0.04, 0.03))
		_blk("lamp", Vector3(xa, 1.06, z + 0.026), Vector3(xb, 1.22, z + 0.038), Color(1.0, 0.55, 0.05))
		_blk("lamp", Vector3(xa, 0.94, z + 0.026), Vector3(xb, 1.04, z + 0.038), Color(0.90, 0.90, 0.85))
	_k.quad(_kit, "matte", [Vector3(-0.27, 0.40, z + 0.2065), Vector3(0.27, 0.40, z + 0.2065), Vector3(0.27, 0.52, z + 0.2065), Vector3(-0.27, 0.52, z + 0.2065)], rn, Color(0.98, 0.80, 0.08))
	_text("matte", Vector3(0, 0.46, z + 0.212), Vector3(1, 0, 0), Vector3.UP, 0.0145, _liv["plate"], Color(0.05, 0.05, 0.06))
	var slogan: String = _liv["slogan"]
	_text("paint", Vector3(0, 2.45, z + 0.012), Vector3(1, 0, 0), Vector3.UP, minf(0.05, 1.6 / float(text_cells(slogan))), slogan, _spec["txt"], 0.12)
	_k.tube(_kit, "chrome", Vector3(0.55, 0.36, z + 0.05), Vector3(0.55, 0.36, z + 0.30), 0.04, 0.045, 10, CHROME)


func _build_underbody() -> void:
	# A dark undertray, and what a food truck carries: two gas bottles by the chassis and a generator.
	_blk("matte", Vector3(-0.80, 0.30, -0.80), Vector3(0.80, 0.80, 3.0), Color(0.035, 0.035, 0.04))
	# A rack hung from the body for them: a plate under, straps down from the floor.
	_blk("matte", Vector3(-1.20, 0.40, 1.95), Vector3(-0.80, 0.43, 2.85), Color(0.14, 0.14, 0.15))
	for zs in [2.00, 2.80]:
		_blk("matte", Vector3(-1.20, 0.43, zs - 0.015), Vector3(-1.17, BOX_Y0 + 0.02, zs + 0.015), Color(0.14, 0.14, 0.15))
	for i in range(2):
		var xx := -1.04 + 0.0
		var zz := 2.18 + 0.46 * float(i)
		_k.tube(_kit, "paint", Vector3(xx, 0.43, zz), Vector3(xx, 0.93, zz), 0.115, 0.115, 10, Color(0.85, 0.15, 0.10) if i == 0 else Color(0.95, 0.75, 0.10))
		_k.lathe(_kit, "paint", Vector3(xx, 0.93, zz), [Vector2(0.115, 0.0), Vector2(0.10, 0.05), Vector2(0.05, 0.08), Vector2(0.0, 0.085)], 10, Color(0.85, 0.15, 0.10) if i == 0 else Color(0.95, 0.75, 0.10))
		_k.tube(_kit, "chrome", Vector3(xx, 1.00, zz), Vector3(xx, 1.06, zz), 0.03, 0.03, 6, CHROME)
	_blk("matte", Vector3(-0.50, 0.34, 2.45), Vector3(0.40, 0.80, 3.0), Color(0.22, 0.24, 0.26))
	_blk("lamp", Vector3(-0.42, 0.62, 2.998), Vector3(-0.30, 0.68, 3.01), Color(0.4, 1.0, 0.5))
