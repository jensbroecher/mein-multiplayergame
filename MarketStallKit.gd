extends "res://MatatuKit.gd"
## A market stall of Nairobi's street markets at life size (3 x 2.2m, 2.3m at the front), for Nyota Stadium's Soko
## Street: a rough timber frame with lashings under a tarpaulin or corrugated iron, a table or shelves, and the
## goods of a trade, with a painted sign. The front (the customers' side) is +z; the caller scales and turns it.
## Six trades (`KINDS`): vegetables, second-hand clothes (mitumba), shoes, fruit under an umbrella with a
## handcart, grains and spices, and an airtime and phone-accessories kiosk. `variant` changes the colours.
## Materials (`make_stall_material`): wood, tin (corrugated iron), cloth (tarps, clothes: double sided), plastic
## (crates), produce and paint (signs, tags).

const SW := 3.0
const SD := 2.2
const HF := 2.3
const HB := 2.0

const KINDS := ["MBOGA", "MITUMBA", "VIATU", "MATUNDA", "NAFAKA", "AIRTIME"]
const SIGNS := [["MAMA MBOGA", "FRESH DAILY"], ["MITUMBA BORA", "NGUO NZURI"], ["VIATU", "ALL SIZES"], ["MATUNDA SAFI", "TAMU SANA"], ["NAFAKA", "UNGA - MCHELE"], ["AIRTIME", "CHARGERS - COVERS"]]
const TARPS := [Color(0.85, 0.18, 0.12), Color(0.12, 0.40, 0.75), Color(0.95, 0.62, 0.12), Color(0.10, 0.52, 0.28), Color(0.95, 0.85, 0.20), Color(0.55, 0.18, 0.60)]
const WOOD := Color(0.42, 0.30, 0.18)
const WOOD_DARK := Color(0.28, 0.20, 0.12)
const PINE := Color(0.62, 0.48, 0.30)
const ROPE := Color(0.72, 0.64, 0.42)

var _rng := RandomNumberGenerator.new()
var _tarp := Color.WHITE
var _tarp2 := Color.WHITE


func _init(kit: PropKit) -> void:
	super(kit)


static func make_stall_material(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.8
	match key:
		"wood":
			m.roughness = 0.9
		"tin":
			m.metallic = 0.55
			m.roughness = 0.45
		"cloth":
			m.roughness = 0.95
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"plastic":
			m.roughness = 0.42
		"produce":
			m.roughness = 0.55
		"paint":
			m.roughness = 0.5
	return m


func build_stall(kind: int, variant: int) -> ArrayMesh:
	_kit = {}
	_rng.seed = 5000 + kind * 37 + variant * 101
	_tarp = TARPS[(kind * 2 + variant) % TARPS.size()]
	_tarp2 = TARPS[(kind * 2 + variant + 3) % TARPS.size()]
	_frame(kind)
	match kind:
		0:
			_roof_tarp(true)
			_mboga()
		1:
			_roof_tarp(false)
			_mitumba()
		2:
			_roof_tin()
			_viatu()
		3:
			_matunda()
		4:
			_roof_tin()
			_nafaka()
		_:
			_duka()
	_sign(kind)
	return _k.commit(_kit)


# ---------------------------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------------------------

func _jit(a: float) -> float:
	return _rng.randf_range(-a, a)


func _post(a: Vector3, b: Vector3, r: float, col := WOOD) -> void:
	_k.tube(_kit, "wood", a, b, r, r * 0.92, 6, col * (0.9 + 0.2 * _rng.randf()))


func _plank(lo: Vector3, hi: Vector3, col := PINE) -> void:
	_k.block(_kit, "wood", lo, hi, col * (0.92 + 0.16 * _rng.randf()))


## A lashing: a dark band of rope round a post or joint at `p`.
func _lash(p: Vector3, r := 0.06, axis := Vector3.UP) -> void:
	_k.tube(_kit, "wood", p - axis * 0.03, p + axis * 0.03, r, r, 6, ROPE * 0.75)


func _crate(c: Vector3, size: Vector3, col: Color) -> void:
	# An open plastic crate: a floor, four walls, and a darker slatted band.
	var h := size * 0.5
	var t := 0.025
	_k.block(_kit, "plastic", Vector3(c.x - h.x, c.y - h.y, c.z - h.z), Vector3(c.x + h.x, c.y - h.y + t, c.z + h.z), col * 0.85)
	_k.block(_kit, "plastic", Vector3(c.x - h.x, c.y - h.y, c.z - h.z), Vector3(c.x + h.x, c.y + h.y, c.z - h.z + t), col)
	_k.block(_kit, "plastic", Vector3(c.x - h.x, c.y - h.y, c.z + h.z - t), Vector3(c.x + h.x, c.y + h.y, c.z + h.z), col)
	_k.block(_kit, "plastic", Vector3(c.x - h.x, c.y - h.y, c.z - h.z), Vector3(c.x - h.x + t, c.y + h.y, c.z + h.z), col)
	_k.block(_kit, "plastic", Vector3(c.x + h.x - t, c.y - h.y, c.z - h.z), Vector3(c.x + h.x, c.y + h.y, c.z + h.z), col)
	# Handle slots.
	_k.block(_kit, "plastic", Vector3(c.x - h.x * 0.3, c.y + h.y * 0.25, c.z + h.z + 0.002), Vector3(c.x + h.x * 0.3, c.y + h.y * 0.65, c.z + h.z + 0.01), col * 0.4)


## A heap: a dome of `lat` rings and `lon` sides whose faces take random colours from `cols`.
func _mound(c: Vector3, r: float, h: float, cols: Array, lat := 3, lon := 9, key := "produce") -> void:
	for i in range(lat):
		for j in range(lon):
			var t0 := float(i) / float(lat)
			var t1 := float(i + 1) / float(lat)
			var a0 := TAU * float(j) / float(lon)
			var a1 := TAU * float(j + 1) / float(lon)
			var r0 := r * cos(t0 * PI * 0.5) * (0.92 + 0.16 * _rng.randf())
			var r1 := r * cos(t1 * PI * 0.5) * (0.92 + 0.16 * _rng.randf())
			var y0 := h * sin(t0 * PI * 0.5)
			var y1 := h * sin(t1 * PI * 0.5)
			var p00 := c + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p01 := c + Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p11 := c + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var p10 := c + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var am := (a0 + a1) * 0.5
			var n := Vector3(cos(am) * 0.6, 0.8, sin(am) * 0.6)
			var col: Color = cols[_rng.randi() % cols.size()]
			_k.quad(_kit, key, [p00, p01, p11, p10], n, col * (0.86 + 0.28 * _rng.randf()))


func _sphere(c: Vector3, r: Vector3, cols: Array, lat := 4, lon := 8, key := "produce") -> void:
	for i in range(lat):
		for j in range(lon):
			var th0 := PI * float(i) / float(lat)
			var th1 := PI * float(i + 1) / float(lat)
			var ph0 := TAU * float(j) / float(lon)
			var ph1 := TAU * float(j + 1) / float(lon)
			var pts: Array = []
			for tp in [[th0, ph0], [th0, ph1], [th1, ph1], [th1, ph0]]:
				var th: float = tp[0]
				var ph: float = tp[1]
				pts.append(c + Vector3(sin(th) * cos(ph) * r.x, cos(th) * r.y, sin(th) * sin(ph) * r.z))
			var nm := ((pts[0] as Vector3) + (pts[2] as Vector3)) * 0.5 - c
			_k.quad(_kit, key, pts, nm, cols[(j + i) % cols.size()])


func _sack(c: Vector3, col: Color, open_mound: Color = Color(0, 0, 0, 0)) -> void:
	_k.lathe(_kit, "cloth", c, [Vector2(0.0, 0.0), Vector2(0.27, 0.0), Vector2(0.31, 0.14), Vector2(0.28, 0.42), Vector2(0.20, 0.62), Vector2(0.13, 0.70), Vector2(0.15, 0.76), Vector2(0.0, 0.78)], 8, col * (0.9 + 0.2 * _rng.randf()), false)
	if open_mound.a > 0.0:
		_mound(c + Vector3(0, 0.42, 0), 0.22, 0.12, [open_mound, open_mound * 0.85])


func _basket(c: Vector3, r: float, h: float, col := Color(0.66, 0.50, 0.28)) -> void:
	_k.lathe(_kit, "wood", c, [Vector2(0.0, 0.0), Vector2(r * 0.8, 0.0), Vector2(r, h * 0.5), Vector2(r * 1.05, h)], 10, col * (0.9 + 0.2 * _rng.randf()), false)
	_k.lathe(_kit, "wood", c, [Vector2(r * 1.05, h), Vector2(r * 0.9, h * 0.98), Vector2(r * 0.85, h * 0.5), Vector2(0.0, h * 0.2)], 10, col * 0.55, false)


## A price tag on a stake: a card with a number.
func _tag(c: Vector3, text: String) -> void:
	_k.tube(_kit, "wood", c, c + Vector3(0, 0.34, 0), 0.008, 0.008, 4, WOOD_DARK)
	var cc := c + Vector3(0, 0.40, 0)
	_k.quad(_kit, "paint", [cc + Vector3(-0.10, -0.06, 0), cc + Vector3(0.10, -0.06, 0), cc + Vector3(0.10, 0.06, 0), cc + Vector3(-0.10, 0.06, 0)], Vector3(0, 0, 1), Color(0.97, 0.96, 0.90))
	_text("paint", cc + Vector3(0, 0, 0.004), Vector3(1, 0, 0), Vector3.UP, minf(0.018, 0.17 / float(text_cells(text))), text, Color(0.7, 0.05, 0.05))


## A table: a plank top over four legs and a lower shelf.
func _table(x0: float, x1: float, z0: float, z1: float, y: float, col := PINE) -> void:
	_plank(Vector3(x0, y - 0.05, z0), Vector3(x1, y, z1), col)
	for lx in [x0 + 0.05, x1 - 0.05]:
		for lz in [z0 + 0.05, z1 - 0.05]:
			_post(Vector3(lx, 0.0, lz), Vector3(lx, y - 0.05, lz), 0.03, WOOD)
	_plank(Vector3(x0 + 0.03, 0.28, z0 + 0.03), Vector3(x1 - 0.03, 0.31, z1 - 0.03), WOOD)


## A sheet on a parametric surface f(u, v) in a double-sided material (tarps, clothes).
func _sheet(f: Callable, nu: int, nv: int, col_fn: Callable, up: Vector3, key := "cloth") -> void:
	_grid(key, f, nu, nv, col_fn, up)


# ---------------------------------------------------------------------------------------------
#  Frame and roof
# ---------------------------------------------------------------------------------------------

func _frame(kind: int) -> void:
	if kind == 5:
		return
	var hx := SW * 0.5
	var hz := SD * 0.5
	var umbrella := kind == 3
	for sx in [-1.0, 1.0]:
		var x: float = sx * hx
		if umbrella:
			continue
		_post(Vector3(x, 0.0, hz), Vector3(x + _jit(0.02), HF + _jit(0.04), hz), 0.05)
		_post(Vector3(x, 0.0, -hz), Vector3(x + _jit(0.02), HB + _jit(0.04), -hz), 0.05)
		# Side beam, sloping back, and a diagonal brace at each side.
		_post(Vector3(x, HF, hz), Vector3(x, HB, -hz), 0.035)
		_post(Vector3(x, 1.45, hz), Vector3(x, 1.95, hz * 0.2), 0.025)
		_post(Vector3(x, 0.4, -hz), Vector3(x, 1.3, -hz * 0.2), 0.025)
		for p in [Vector3(x, HF, hz), Vector3(x, HB, -hz), Vector3(x, 1.0, hz), Vector3(x, 1.0, -hz)]:
			_lash(p, 0.062, Vector3.UP)
	if umbrella:
		return
	# Front and back beams, and rafters across the roof.
	_post(Vector3(-hx - 0.1, HF, hz), Vector3(hx + 0.1, HF, hz), 0.04)
	_post(Vector3(-hx - 0.1, HB, -hz), Vector3(hx + 0.1, HB, -hz), 0.04)
	for i in range(4):
		var x2: float = lerpf(-hx, hx, float(i) / 3.0)
		_post(Vector3(x2, HF, hz), Vector3(x2, HB, -hz), 0.022)


func _roof_tarp(stripes: bool) -> void:
	var hx := SW * 0.5
	var hz := SD * 0.5
	var f := func(u: float, v: float) -> Vector3:
		var x := lerpf(-hx - 0.28, hx + 0.28, u)
		var z := lerpf(hz + 0.32, -hz - 0.18, v)
		var y := lerpf(HF + 0.04, HB + 0.04, v)
		# Sag between the rafters, and wrinkles.
		y -= 0.05 * sin(PI * clampf(u * 3.0 - floorf(u * 3.0), 0.0, 1.0)) * sin(PI * v) + 0.02 * sin(u * 31.0 + v * 7.0) + 0.012 * sin(v * 19.0 + u * 5.0)
		return Vector3(x, y, z)
	var tarp_col := func(u: float, _v: float) -> Color:
		if stripes:
			return _tarp if int(floor(u * 6.0)) % 2 == 0 else Color(0.95, 0.94, 0.90)
		return _tarp
	_sheet(f, 12, 5, tarp_col, Vector3.UP)
	# The front valance hangs from the edge with a wavy hem.
	var fv := func(u: float, v: float) -> Vector3:
		var x := lerpf(-hx - 0.28, hx + 0.28, u)
		var hem := 0.04 * sin(u * 24.0)
		return Vector3(x, HF + 0.04 - v * (0.26 + hem), hz + 0.32 + 0.04 * sin(v * 3.0) * 0.5 + v * 0.05)
	var hem_col := func(u: float, _v: float) -> Color:
		if stripes:
			return _tarp if int(floor(u * 6.0)) % 2 == 0 else Color(0.95, 0.94, 0.90)
		return _tarp * 0.92
	_sheet(fv, 14, 1, hem_col, Vector3(0, 0, 1))


## Corrugated iron: two overlapping sheets, a little rusty.
func _roof_tin() -> void:
	var hx := SW * 0.5
	var hz := SD * 0.5
	for sheet in range(2):
		var x0 := -hx - 0.12 + float(sheet) * (hx + 0.02)
		var x1 := x0 + hx + 0.14
		var rust := Color(0.62, 0.64, 0.66).lerp(Color(0.55, 0.33, 0.22), _rng.randf_range(0.1, 0.5))
		var f := func(u: float, v: float) -> Vector3:
			var x := lerpf(x0, x1, u)
			var z := lerpf(hz + 0.30, -hz - 0.20, v)
			var y := lerpf(HF + 0.06, HB + 0.06, v) + 0.022 * sin(x * TAU / 0.11)
			return Vector3(x, y, z)
		var tin_col := func(u: float, v: float) -> Color:
			return rust * (0.85 + 0.2 * sin(u * 40.0) * 0.5 + 0.1 * v)
		_grid("tin", f, 56, 1, tin_col, Vector3.UP)


# ---------------------------------------------------------------------------------------------
#  The sign
# ---------------------------------------------------------------------------------------------

func _sign(kind: int) -> void:
	var lines: Array = SIGNS[kind]
	var y := HF - 0.20 if kind != 3 and kind != 5 else 2.10
	var cx := 0.0
	var z := SD * 0.5 + 0.32 if kind != 3 and kind != 5 else SD * 0.5 + 0.05
	if kind == 0 or kind == 1:
		# Under the tarp's valance, clear of it.
		y = HF - 0.52
		z = SD * 0.5 + 0.42
	if kind == 5:
		y = 2.28
		z = SD * 0.5 + 0.25
	var board_col := Color(0.96, 0.94, 0.88) if kind % 2 == 0 else Color(0.08, 0.30, 0.16)
	var ink := Color(0.70, 0.06, 0.06) if kind % 2 == 0 else Color(0.98, 0.90, 0.40)
	var nm: String = lines[0]
	var cell := minf(0.046, 1.9 / float(text_cells(nm)))
	var w := float(text_cells(nm)) * cell + 0.20
	_plank(Vector3(cx - w * 0.5, y - 0.18, z), Vector3(cx + w * 0.5, y + 0.14, z + 0.03), board_col)
	_k.block(_kit, "wood", Vector3(cx - w * 0.5 - 0.03, y - 0.21, z - 0.005), Vector3(cx + w * 0.5 + 0.03, y - 0.18, z + 0.035), WOOD_DARK)
	_k.block(_kit, "wood", Vector3(cx - w * 0.5 - 0.03, y + 0.14, z - 0.005), Vector3(cx + w * 0.5 + 0.03, y + 0.17, z + 0.035), WOOD_DARK)
	_text("paint", Vector3(cx, y + 0.045, z + 0.035), Vector3(1, 0, 0), Vector3.UP, cell, nm, ink, 0.1)
	_text("paint", Vector3(cx, y - 0.10, z + 0.035), Vector3(1, 0, 0), Vector3.UP, cell * 0.45, lines[1], ink, 0.0)
	# Hung from the beam on two ropes.
	if kind != 3 and kind != 5:
		for sx in [-1.0, 1.0]:
			_k.tube(_kit, "wood", Vector3(cx + sx * (w * 0.5 - 0.1), y + 0.14, z + 0.015), Vector3(cx + sx * (w * 0.5 - 0.1), HF + 0.02, z + 0.015), 0.006, 0.006, 4, ROPE)


# ---------------------------------------------------------------------------------------------
#  Trades
# ---------------------------------------------------------------------------------------------

func _mboga() -> void:
	# Stepped tables of crates of tomatoes, onions, potatoes, greens, carrots and cabbages.
	_table(-1.35, 1.35, 0.30, 1.00, 0.80)
	_plank(Vector3(-1.35, 0.88, 0.30), Vector3(1.35, 0.93, 0.62), PINE)
	for sx in [-1.2, 1.2]:
		_post(Vector3(sx, 0.80, 0.46), Vector3(sx, 0.88, 0.46), 0.03, WOOD)
	var crates := [
		[Color(0.85, 0.12, 0.08), Color(0.93, 0.25, 0.12)], [Color(0.55, 0.20, 0.55), Color(0.78, 0.45, 0.28)],
		[Color(0.52, 0.38, 0.22), Color(0.64, 0.50, 0.32)], [Color(0.15, 0.50, 0.15), Color(0.32, 0.68, 0.22)],
		[Color(0.95, 0.50, 0.08), Color(0.98, 0.65, 0.18)], [Color(0.55, 0.75, 0.35), Color(0.40, 0.62, 0.25)],
	]
	var cc: Array = [Color(0.15, 0.35, 0.70), Color(0.80, 0.15, 0.10), Color(0.15, 0.55, 0.25), Color(0.90, 0.70, 0.10)]
	for i in range(6):
		var x := -1.1 + 0.44 * float(i)
		var front := i % 2 == 0
		var cz := 0.80 if front else 0.46
		var cy := 0.80 + 0.11 if front else 0.93 + 0.11
		_crate(Vector3(x, cy, cz), Vector3(0.40, 0.22, 0.30), cc[i % 4])
		_mound(Vector3(x, cy + 0.06, cz), 0.17, 0.14, crates[i])
	# A hanging scale, bananas hanging from the front beam, a basket and bags by the table.
	_k.tube(_kit, "wood", Vector3(0.85, HF - 0.02, 1.05), Vector3(0.85, 1.75, 1.05), 0.006, 0.006, 4, ROPE)
	_k.beam(_kit, "tin", Vector3(0.70, 1.75, 1.05), Vector3(1.00, 1.75, 1.05), 0.03, 0.02, Color(0.6, 0.6, 0.62), Vector3.UP)
	_k.lathe(_kit, "tin", Vector3(0.85, 1.42, 1.05), [Vector2(0.0, 0.0), Vector2(0.16, 0.02), Vector2(0.18, 0.05)], 10, Color(0.7, 0.7, 0.72), false)
	for k in range(3):
		_k.tube(_kit, "wood", Vector3(0.85 + (k - 1) * 0.15, 1.72, 1.05), Vector3(0.85 + (k - 1) * 0.15, 1.45, 1.05), 0.004, 0.004, 3, ROPE)
	for k in range(4):
		var bx := -0.70 + 0.07 * float(k)
		_k.tube(_kit, "produce", Vector3(bx, 2.15, 1.04), Vector3(bx + 0.015, 1.84, 1.04 + 0.04), 0.026, 0.02, 5, Color(0.97, 0.82, 0.12))
		_k.tube(_kit, "produce", Vector3(bx + 0.015, 1.84, 1.08), Vector3(bx + 0.02, 1.68, 1.04), 0.02, 0.012, 5, Color(0.55, 0.62, 0.15))
	_k.tube(_kit, "wood", Vector3(-0.62, HF - 0.02, 1.04), Vector3(-0.62, 2.18, 1.04), 0.008, 0.008, 4, ROPE)
	_sack(Vector3(-1.15, 0.0, -0.55), Color(0.85, 0.80, 0.62), Color(0.45, 0.30, 0.20))
	_sack(Vector3(-0.55, 0.0, -0.75), Color(0.78, 0.74, 0.58), Color(0.95, 0.78, 0.25))
	_sack(Vector3(-0.85, 0.0, -0.18), Color(0.92, 0.90, 0.82))
	_basket(Vector3(1.05, 0.0, -0.45), 0.30, 0.36)
	_mound(Vector3(1.05, 0.30, -0.45), 0.22, 0.14, [Color(0.85, 0.12, 0.08), Color(0.95, 0.30, 0.15)])
	_crate(Vector3(0.55, 0.14, -0.7), Vector3(0.42, 0.28, 0.32), Color(0.15, 0.35, 0.70))
	_crate(Vector3(0.55, 0.42, -0.7), Vector3(0.42, 0.28, 0.32), Color(0.80, 0.15, 0.10))
	# A stool for the seller, behind the table, and price tags.
	_post(Vector3(0.1, 0.0, -0.1), Vector3(0.1, 0.40, -0.1), 0.04, WOOD)
	_plank(Vector3(-0.08, 0.40, -0.28), Vector3(0.28, 0.44, 0.08), PINE)
	for i in range(4):
		_tag(Vector3(-1.05 + 0.60 * float(i), 0.93, 0.92), ["50", "100", "30", "20"][i])


func _mitumba() -> void:
	# Two rails of hung clothes, a table of folded piles, a bale, and shoes strung up.
	var cols: Array = [Color(0.85, 0.15, 0.12), Color(0.12, 0.40, 0.78), Color(0.95, 0.80, 0.15), Color(0.15, 0.55, 0.30), Color(0.92, 0.92, 0.90), Color(0.10, 0.10, 0.12), Color(0.85, 0.45, 0.65), Color(0.55, 0.25, 0.60), Color(0.95, 0.55, 0.10), Color(0.30, 0.65, 0.85)]
	for rail in range(2):
		var y := 1.95 - 0.55 * float(rail)
		var z := 0.95 - 0.55 * float(rail)
		_post(Vector3(-SW * 0.5, y, z), Vector3(SW * 0.5, y, z), 0.016, Color(0.55, 0.56, 0.58))
		var n := 17 - rail * 2
		for i in range(n):
			var x := -1.30 + 2.6 * float(i) / float(n - 1) + _jit(0.02)
			var col: Color = cols[_rng.randi() % cols.size()]
			var h := _rng.randf_range(0.50, 0.68)
			var w := _rng.randf_range(0.30, 0.38)
			var yaw := _jit(0.35)
			var dz := Vector3(sin(yaw), 0, cos(yaw)) * 0.0
			_garment(Vector3(x, y - 0.03, z), w, h, col, yaw, _rng.randi() % 3)
	_table(-1.35, 0.35, 0.10, 0.78, 0.78)
	var pile_cols := [Color(0.9, 0.9, 0.88), Color(0.15, 0.4, 0.8), Color(0.85, 0.2, 0.15), Color(0.2, 0.6, 0.3), Color(0.1, 0.1, 0.12)]
	for i in range(4):
		var px := -1.15 + 0.40 * float(i)
		for k in range(3):
			var pc: Color = pile_cols[(i + k) % pile_cols.size()]
			_k.block(_kit, "cloth", Vector3(px - 0.16, 0.78 + 0.08 * float(k), 0.20), Vector3(px + 0.16, 0.78 + 0.08 * float(k + 1) - 0.01, 0.68), pc * (0.9 + 0.2 * _rng.randf()))
	# A wrapped bale in blue plastic with a strap, and a bundle behind it.
	_k.block(_kit, "plastic", Vector3(0.70, 0.0, -0.85), Vector3(1.40, 0.62, -0.20), Color(0.14, 0.32, 0.72))
	_k.block(_kit, "plastic", Vector3(0.70, 0.30, -0.855), Vector3(1.40, 0.34, -0.195), Color(0.9, 0.9, 0.88))
	_k.block(_kit, "plastic", Vector3(0.80, 0.62, -0.75), Vector3(1.30, 1.0, -0.30), Color(0.92, 0.60, 0.12))
	# Shoes strung from the roof beam.
	for i in range(5):
		var sx := 0.55 + 0.20 * float(i)
		_k.tube(_kit, "wood", Vector3(sx, HF - 0.02, 1.02), Vector3(sx, 1.82, 1.02), 0.005, 0.005, 3, ROPE)
		_shoe(Vector3(sx, 1.72, 1.02), PI * 0.5, cols[(i * 3) % cols.size()], true)
	# The seller's stool.
	_post(Vector3(0.9, 0.0, 0.2), Vector3(0.9, 0.42, 0.2), 0.04, WOOD)
	_plank(Vector3(0.72, 0.42, 0.02), Vector3(1.08, 0.46, 0.38), PINE)


func _garment(top: Vector3, w: float, h: float, col: Color, yaw: float, style: int) -> void:
	# A shirt, a dress or a pair of trousers on a hanger: flat cloth quads facing the street.
	var bs := Basis(Vector3.UP, yaw)
	var n := bs * Vector3(0, 0, 1)
	_k.tube(_kit, "wood", top, top + Vector3(0, 0.04, 0), 0.004, 0.004, 3, Color(0.5, 0.5, 0.52))
	var hang := func(x: float, y: float) -> Vector3:
		return top + bs * Vector3(x, -y, 0.0)
	match style:
		0:
			# Shirt: body and two short sleeves.
			_k.quad(_kit, "cloth", [hang.call(-w * 0.45, 0.06), hang.call(w * 0.45, 0.06), hang.call(w * 0.5, h), hang.call(-w * 0.5, h)], n, col)
			_k.quad(_kit, "cloth", [hang.call(-w * 0.45, 0.06), hang.call(-w * 0.75, 0.22), hang.call(-w * 0.62, 0.30), hang.call(-w * 0.42, 0.18)], n, col * 0.92)
			_k.quad(_kit, "cloth", [hang.call(w * 0.45, 0.06), hang.call(w * 0.75, 0.22), hang.call(w * 0.62, 0.30), hang.call(w * 0.42, 0.18)], n, col * 0.92)
		1:
			# Dress: a flare.
			_k.quad(_kit, "cloth", [hang.call(-w * 0.25, 0.06), hang.call(w * 0.25, 0.06), hang.call(w * 0.6, h * 1.1), hang.call(-w * 0.6, h * 1.1)], n, col)
		_:
			# Trousers: two legs.
			_k.quad(_kit, "cloth", [hang.call(-w * 0.42, 0.06), hang.call(w * 0.42, 0.06), hang.call(w * 0.42, h * 0.35), hang.call(-w * 0.42, h * 0.35)], n, col)
			_k.quad(_kit, "cloth", [hang.call(-w * 0.42, h * 0.35), hang.call(-w * 0.02, h * 0.35), hang.call(-w * 0.04, h * 1.05), hang.call(-w * 0.40, h * 1.05)], n, col * 0.92)
			_k.quad(_kit, "cloth", [hang.call(w * 0.02, h * 0.35), hang.call(w * 0.42, h * 0.35), hang.call(w * 0.40, h * 1.05), hang.call(w * 0.04, h * 1.05)], n, col * 0.92)


func _shoe(c: Vector3, yaw: float, col: Color, hanging := false) -> void:
	# A shoe: a sole, an upper with a heel and a toe cap, lying (or hanging by its heel). Nose along +x rotated by yaw.
	var bs := Basis(Vector3.UP, yaw)
	if hanging:
		bs = bs * Basis(Vector3(0, 0, 1), 1.2)
	var p := func(v: Vector3) -> Vector3:
		return c + bs * v
	var parts := [
		[Vector3(-0.13, 0.0, -0.045), Vector3(0.13, 0.025, 0.045), Color(0.12, 0.12, 0.13)],
		[Vector3(-0.13, 0.025, -0.04), Vector3(0.02, 0.095, 0.04), col],
		[Vector3(0.02, 0.025, -0.04), Vector3(0.13, 0.060, 0.04), col * 0.9],
	]
	for pt in parts:
		var lo: Vector3 = pt[0]
		var hi: Vector3 = pt[1]
		var tc: Color = pt[2]
		var cen := (lo + hi) * 0.5
		var size := hi - lo
		_k.box(_kit, "plastic", Transform3D(bs, c + bs * cen), size, tc)


func _viatu() -> void:
	# Tiered shelves of shoes on the back and a table of pairs in front.
	var cols := [Color(0.12, 0.12, 0.13), Color(0.55, 0.25, 0.12), Color(0.85, 0.85, 0.83), Color(0.15, 0.30, 0.65), Color(0.80, 0.15, 0.12), Color(0.35, 0.18, 0.08)]
	for tier in range(4):
		var y := 0.35 + 0.42 * float(tier)
		_plank(Vector3(-1.4, y, -1.0), Vector3(1.4, y + 0.04, -0.62), PINE)
		for i in range(8):
			var x := -1.25 + 0.36 * float(i)
			_shoe(Vector3(x, y + 0.04, -0.80), PI * 0.5 + _jit(0.2), cols[_rng.randi() % cols.size()])
	for sx in [-1.4, 1.4]:
		_post(Vector3(sx, 0.0, -1.0), Vector3(sx, 1.9, -1.0), 0.035, WOOD)
	_table(-1.30, 1.30, 0.20, 0.90, 0.78)
	for i in range(7):
		var x := -1.15 + 0.38 * float(i)
		_shoe(Vector3(x, 0.78, 0.45 + _jit(0.12)), PI * 0.5 + _jit(0.5), cols[(i * 5) % cols.size()])
		_shoe(Vector3(x + 0.14, 0.78, 0.62 + _jit(0.1)), PI * 0.5 + _jit(0.5), cols[(i * 5 + 2) % cols.size()])
	# Sandals and slippers strung from the front beam, and a mirror.
	for i in range(8):
		var sx := -1.1 + 0.31 * float(i)
		_k.tube(_kit, "wood", Vector3(sx, HF - 0.02, 1.04), Vector3(sx, 1.78 + _jit(0.08), 1.04), 0.004, 0.004, 3, ROPE)
		_shoe(Vector3(sx, 1.70 + _jit(0.08), 1.04), PI * 0.5, cols[(i * 2) % cols.size()], true)
	_k.block(_kit, "paint", Vector3(1.10, 0.80, 0.66), Vector3(1.40, 1.10, 0.69), Color(0.78, 0.82, 0.85))
	_k.block(_kit, "wood", Vector3(1.09, 0.79, 0.65), Vector3(1.41, 0.81, 0.70), WOOD_DARK)


func _matunda() -> void:
	# A big umbrella over a fruit table and a handcart (mkokoteni) of watermelons and pineapples.
	var panels := 8
	var rim_y := 2.0
	var apex := Vector3(0.0, 2.75, 0.2)
	var rad := 1.9
	for i in range(panels):
		var a0 := TAU * float(i) / float(panels)
		var a1 := TAU * float(i + 1) / float(panels)
		var p0 := Vector3(cos(a0) * rad, rim_y, 0.2 + sin(a0) * rad)
		var p1 := Vector3(cos(a1) * rad, rim_y, 0.2 + sin(a1) * rad)
		var mid := Vector3(cos((a0 + a1) * 0.5) * rad * 0.55, 2.52, 0.2 + sin((a0 + a1) * 0.5) * rad * 0.55)
		var col := _tarp if i % 2 == 0 else Color(0.97, 0.96, 0.92)
		_k.tri(_kit, "cloth", apex, p0, mid, Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), col, Vector3(0, 1, 0))
		_k.tri(_kit, "cloth", apex, mid, p1, Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), col, Vector3(0, 1, 0))
		_k.tri(_kit, "cloth", mid, p0, p1, Vector3(0, 0.6, 0), Vector3(0, 0.6, 0), Vector3(0, 0.6, 0), col * 0.96, Vector3(0, 0.6, 0))
		# A short scalloped skirt.
		_k.quad(_kit, "cloth", [p0, p1, p1 + Vector3(0, -0.14, 0), p0 + Vector3(0, -0.14, 0)], Vector3((p0.x + p1.x) * 0.5, 0, (p0.z + p1.z) * 0.5 - 0.2), col)
	_k.tube(_kit, "tin", Vector3(0.0, 0.0, 0.2), Vector3(0.0, 2.80, 0.2), 0.035, 0.03, 8, Color(0.60, 0.62, 0.64))
	_k.lathe(_kit, "tin", Vector3(0, 0, 0.2), [Vector2(0.28, 0.0), Vector2(0.28, 0.06), Vector2(0.06, 0.10), Vector2(0.04, 0.2)], 10, Color(0.35, 0.36, 0.38), false)
	# A table ringed with fruit: watermelons, pineapples, oranges, mangoes.
	_table(-1.35, 1.35, 0.35, 1.05, 0.82)
	for i in range(4):
		var x := -1.0 + 0.62 * float(i)
		_sphere(Vector3(x, 0.82 + 0.17, 0.72), Vector3(0.19, 0.16, 0.16), [Color(0.12, 0.42, 0.18), Color(0.30, 0.62, 0.30)], 4, 8)
	for i in range(3):
		var x := -0.70 + 0.62 * float(i)
		_sphere(Vector3(x + 0.18, 0.82 + 0.40, 0.72), Vector3(0.17, 0.14, 0.14), [Color(0.12, 0.42, 0.18), Color(0.30, 0.62, 0.30)], 4, 8)
	for i in range(3):
		var px := -1.15 + 0.25 * float(i)
		_k.lathe(_kit, "produce", Vector3(px, 0.82, 0.48), [Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.095, 0.12), Vector2(0.07, 0.24), Vector2(0.0, 0.26)], 7, Color(0.95, 0.70, 0.15))
		for lf in range(5):
			var la := TAU * float(lf) / 5.0
			_k.tube(_kit, "produce", Vector3(px, 1.06, 0.48), Vector3(px + cos(la) * 0.09, 1.28, 0.48 + sin(la) * 0.09), 0.02, 0.003, 4, Color(0.25, 0.52, 0.18))
	_basket(Vector3(0.85, 0.82, 0.48), 0.26, 0.20)
	_mound(Vector3(0.85, 1.00, 0.48), 0.20, 0.13, [Color(0.98, 0.58, 0.08), Color(0.95, 0.45, 0.05)])
	_basket(Vector3(1.15, 0.82, 0.55), 0.20, 0.16)
	_mound(Vector3(1.15, 0.97, 0.55), 0.15, 0.11, [Color(0.90, 0.35, 0.10), Color(0.95, 0.75, 0.20), Color(0.35, 0.60, 0.20)])
	# The handcart: a plank deck, two big wheels and two handles, loaded with watermelons.
	var cx := -1.0
	var cz := -0.55
	_plank(Vector3(cx - 0.55, 0.52, cz - 0.30), Vector3(cx + 0.55, 0.58, cz + 0.30), PINE)
	_plank(Vector3(cx - 0.55, 0.58, cz - 0.30), Vector3(cx + 0.55, 0.78, cz - 0.27), WOOD)
	_plank(Vector3(cx - 0.55, 0.58, cz + 0.27), Vector3(cx + 0.55, 0.78, cz + 0.30), WOOD)
	for sx in [-1.0, 1.0]:
		var wc := Vector3(cx, 0.36, cz + sx * 0.38)
		_k.tyre(_kit, "wood", wc, 0.28, 0.38, 0.05, 14, Color(0.10, 0.10, 0.11), Basis(Vector3.RIGHT, PI * 0.5))
		_k.lathe(_kit, "tin", wc + Vector3(0, 0, sx * 0.015), [Vector2(0.28, 0.0), Vector2(0.06, 0.0)], 8, Color(0.55, 0.56, 0.58), false, Basis(Vector3.RIGHT, PI * 0.5))
		_post(Vector3(cx + 0.9, 0.5, cz + sx * 0.18), Vector3(cx + 0.55, 0.55, cz + sx * 0.28), 0.025, WOOD)
	for i in range(3):
		for j in range(2):
			_sphere(Vector3(cx - 0.32 + 0.30 * float(i), 0.78 + 0.14, cz - 0.10 + 0.20 * float(j)), Vector3(0.17, 0.14, 0.14), [Color(0.12, 0.42, 0.18), Color(0.30, 0.62, 0.30)], 4, 8)
	_sphere(Vector3(cx, 0.78 + 0.40, cz + 0.02), Vector3(0.17, 0.14, 0.14), [Color(0.12, 0.42, 0.18), Color(0.30, 0.62, 0.30)], 4, 8)
	_post(Vector3(0.9, 0.0, -0.6), Vector3(0.9, 0.40, -0.6), 0.04, WOOD)
	_plank(Vector3(0.72, 0.40, -0.78), Vector3(1.08, 0.44, -0.42), PINE)
	for i in range(3):
		_tag(Vector3(-0.85 + 0.9 * float(i), 0.82, 1.0), ["20", "150", "50"][i])


func _nafaka() -> void:
	# Open sacks of rice, beans, maize and lentils with scoops, bowls of spices, jars and baskets.
	var grains := [Color(0.95, 0.93, 0.85), Color(0.55, 0.20, 0.12), Color(0.96, 0.80, 0.20), Color(0.85, 0.52, 0.18), Color(0.45, 0.30, 0.15), Color(0.80, 0.78, 0.72)]
	# Two stages of planks behind the counter, so the open sacks show over it.
	_plank(Vector3(-1.4, 0.30, 0.20), Vector3(1.4, 0.34, 0.72), PINE)
	_plank(Vector3(-1.4, 0.64, -0.46), Vector3(1.4, 0.68, 0.06), PINE)
	for sx in [-1.4, 1.4]:
		_post(Vector3(sx, 0.0, 0.70), Vector3(sx, 0.30, 0.70), 0.03, WOOD)
		_post(Vector3(sx, 0.0, -0.44), Vector3(sx, 0.64, -0.44), 0.03, WOOD)
	for i in range(6):
		var x := -1.15 + 0.46 * float(i)
		var upper := i % 2 == 1
		var z := -0.20 if upper else 0.46
		var y := 0.68 if upper else 0.34
		_sack(Vector3(x, y, z), Color(0.88, 0.84, 0.72) if i % 3 != 1 else Color(0.78, 0.70, 0.50), grains[i])
		_k.tube(_kit, "tin", Vector3(x + 0.1, y + 0.50, z + 0.05), Vector3(x + 0.30, y + 0.56, z + 0.15), 0.015, 0.015, 5, Color(0.7, 0.7, 0.72))
		_k.lathe(_kit, "tin", Vector3(x + 0.30, y + 0.50, z + 0.15), [Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.09, 0.05)], 8, Color(0.7, 0.7, 0.72), false)
	# A counter with bowls of spices and jars.
	_table(-1.35, 1.35, 0.85, 1.20, 0.82)
	var spice := [Color(0.80, 0.12, 0.08), Color(0.95, 0.72, 0.10), Color(0.20, 0.45, 0.18), Color(0.55, 0.30, 0.12), Color(0.9, 0.5, 0.1)]
	for i in range(8):
		var x := -1.2 + 0.34 * float(i)
		_k.lathe(_kit, "plastic", Vector3(x, 0.82, 1.02), [Vector2(0.0, 0.0), Vector2(0.10, 0.0), Vector2(0.13, 0.07)], 8, Color(0.85, 0.85, 0.82), false)
		_mound(Vector3(x, 0.89, 1.02), 0.115, 0.08, [spice[i % 5], spice[(i + 1) % 5]], 2, 8)
	for i in range(4):
		var x := -1.0 + 0.66 * float(i)
		_k.tube(_kit, "plastic", Vector3(x, 0.82, 0.92), Vector3(x, 1.0, 0.92), 0.06, 0.06, 8, Color(0.75, 0.85, 0.90))
		_k.tube(_kit, "plastic", Vector3(x, 1.0, 0.92), Vector3(x, 1.03, 0.92), 0.064, 0.064, 8, Color(0.85, 0.15, 0.12))
	_basket(Vector3(1.1, 0.0, -0.4), 0.28, 0.34)
	_mound(Vector3(1.1, 0.30, -0.4), 0.22, 0.12, [Color(0.55, 0.22, 0.12), Color(0.45, 0.30, 0.15)])
	# A set of scales on the counter.
	_k.tube(_kit, "tin", Vector3(1.12, 0.82, 1.05), Vector3(1.12, 1.18, 1.05), 0.012, 0.012, 5, Color(0.55, 0.56, 0.58))
	_k.beam(_kit, "tin", Vector3(0.90, 1.18, 1.05), Vector3(1.34, 1.18, 1.05), 0.03, 0.015, Color(0.55, 0.56, 0.58), Vector3.UP)
	for sx in [0.92, 1.32]:
		_k.lathe(_kit, "tin", Vector3(sx, 0.98, 1.05), [Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.13, 0.025)], 10, Color(0.7, 0.7, 0.72), false)
		_k.tube(_kit, "wood", Vector3(sx, 1.17, 1.05), Vector3(sx, 1.0, 1.05), 0.004, 0.004, 3, ROPE)
	for i in range(3):
		_tag(Vector3(-0.8 + 0.8 * float(i), 0.82, 1.15), ["120", "200", "90"][i])


func _duka() -> void:
	# A small timber and iron kiosk with a hatch under a propped shutter: airtime, phone covers and chargers.
	var wall := Color(0.12, 0.45, 0.28) if _rng.randf() < 0.5 else Color(0.85, 0.65, 0.10)
	var hx := SW * 0.5 - 0.35
	var hz := SD * 0.5 - 0.25
	# Corner posts, side and back walls of corrugated iron, a plank front with an opening.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_post(Vector3(sx * hx, 0.0, sz * hz), Vector3(sx * hx, 2.2 + (0.1 if sz > 0.0 else 0.0), sz * hz), 0.05)
	var tin_wall := func(x0: float, z0: float, x1: float, z1: float, yb: float, yt: float) -> void:
		var ridges := int(maxf(absf(x1 - x0), absf(z1 - z0)) / 0.11)
		var f := func(u: float, v: float) -> Vector3:
			var along := lerpf(0.0, 1.0, u)
			var x := lerpf(x0, x1, along)
			var z := lerpf(z0, z1, along)
			var d := 0.02 * sin(along * float(ridges) * TAU)
			var nx := 0.0 if absf(x1 - x0) > absf(z1 - z0) else 1.0
			return Vector3(x + (d if nx > 0.5 else 0.0), lerpf(yb, yt, v), z + (d if nx < 0.5 else 0.0))
		var wall_col := func(u: float, _v: float) -> Color:
			return wall * (0.85 + 0.15 * sin(u * 60.0))
		_grid("tin", f, ridges * 3, 1, wall_col, Vector3(1, 0, 0) if absf(x1 - x0) < absf(z1 - z0) else Vector3(0, 0, 1))
	tin_wall.call(-hx, -hz, hx, -hz, 0.0, 2.2)
	tin_wall.call(-hx, -hz, -hx, hz, 0.0, 2.3)
	tin_wall.call(hx, -hz, hx, hz, 0.0, 2.3)
	# The front: planks below and above the hatch.
	_plank(Vector3(-hx, 0.0, hz - 0.03), Vector3(hx, 0.95, hz + 0.02), wall * 0.9)
	_plank(Vector3(-hx, 1.85, hz - 0.03), Vector3(hx, 2.3, hz + 0.02), wall * 0.9)
	_plank(Vector3(-hx, 0.95, hz - 0.03), Vector3(-hx + 0.12, 1.85, hz + 0.02), wall * 0.9)
	_plank(Vector3(hx - 0.12, 0.95, hz - 0.03), Vector3(hx, 1.85, hz + 0.02), wall * 0.9)
	# The counter, and a shutter propped open as an awning.
	_plank(Vector3(-hx, 0.92, hz), Vector3(hx, 0.97, hz + 0.42), PINE)
	_k.quad(_kit, "tin", [Vector3(-hx, 1.85, hz + 0.02), Vector3(hx, 1.85, hz + 0.02), Vector3(hx, 2.12, hz + 0.80), Vector3(-hx, 2.12, hz + 0.80)], Vector3(0, 0.6, 0.8), Color(0.62, 0.64, 0.66))
	_k.quad(_kit, "tin", [Vector3(hx, 1.85, hz + 0.02), Vector3(-hx, 1.85, hz + 0.02), Vector3(-hx, 2.12, hz + 0.80), Vector3(hx, 2.12, hz + 0.80)], Vector3(0, -0.6, -0.8), Color(0.45, 0.46, 0.48))
	for sx in [-1.0, 1.0]:
		_k.tube(_kit, "wood", Vector3(sx * (hx - 0.05), 0.97, hz + 0.80), Vector3(sx * (hx - 0.05), 2.12, hz + 0.80), 0.02, 0.02, 5, WOOD)
	# A tin roof, and inside: shelves of phone covers and a charging board with phones glowing.
	var f := func(u: float, v: float) -> Vector3:
		var x := lerpf(-hx - 0.1, hx + 0.1, u)
		var z := lerpf(hz + 0.15, -hz - 0.1, v)
		return Vector3(x, lerpf(2.38, 2.22, v) + 0.02 * sin(x * TAU / 0.11), z)
	var roof_col := func(u: float, _v: float) -> Color:
		return Color(0.58, 0.60, 0.62) * (0.9 + 0.1 * sin(u * 50.0))
	_grid("tin", f, 60, 1, roof_col, Vector3.UP)
	_plank(Vector3(-hx + 0.1, 1.40, -hz + 0.05), Vector3(hx - 0.1, 1.44, -hz + 0.35), PINE)
	_plank(Vector3(-hx + 0.1, 1.05, -hz + 0.05), Vector3(hx - 0.1, 1.09, -hz + 0.35), PINE)
	var packs := [Color(0.85, 0.15, 0.12), Color(0.12, 0.45, 0.78), Color(0.95, 0.80, 0.15), Color(0.15, 0.60, 0.30), Color(0.55, 0.20, 0.60), Color(0.95, 0.5, 0.1)]
	for row in range(2):
		for i in range(9):
			var px := -hx + 0.22 + (2.0 * hx - 0.44) * float(i) / 8.0
			var py := 1.44 if row == 0 else 1.09
			_k.block(_kit, "plastic", Vector3(px - 0.07, py, -hz + 0.10), Vector3(px + 0.07, py + 0.18, -hz + 0.13), packs[(i + row * 2) % packs.size()])
	_k.block(_kit, "paint", Vector3(-0.60, 1.52, -hz + 0.03), Vector3(0.60, 1.78, -hz + 0.05), Color(0.10, 0.10, 0.12))
	for i in range(6):
		var px := -0.50 + 0.2 * float(i)
		_k.block(_kit, "lamp", Vector3(px - 0.04, 1.58, -hz + 0.05), Vector3(px + 0.04, 1.72, -hz + 0.058), Color(0.5, 0.85, 1.0))
	# A stool inside and a lamp bulb.
	_post(Vector3(0.0, 0.0, -0.15), Vector3(0.0, 0.42, -0.15), 0.04, WOOD)
	_k.lathe(_kit, "lamp", Vector3(0, 2.14, 0.1), [Vector2(0.0, 0.0), Vector2(0.05, 0.03), Vector2(0.04, 0.09), Vector2(0.0, 0.11)], 8, Color(1.0, 0.92, 0.70), false)
	# A hand-painted board by the door with the day's airtime offers.
	_k.block(_kit, "paint", Vector3(hx + 0.02, 0.55, hz - 0.5), Vector3(hx + 0.05, 1.60, hz + 0.0), Color(0.97, 0.95, 0.88))
	_text("paint", Vector3(hx + 0.056, 1.42, hz - 0.25), Vector3(0, 0, -1), Vector3.UP, 0.02, "ALL NETWORKS", Color(0.7, 0.05, 0.05))
	_text("paint", Vector3(hx + 0.056, 1.20, hz - 0.25), Vector3(0, 0, -1), Vector3.UP, 0.02, "50 100 250", Color(0.1, 0.1, 0.5))
