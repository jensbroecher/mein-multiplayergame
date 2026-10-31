extends RefCounted
## The roadside stop's furniture and fittings (the Canyon Course's Parador del Viento, regenerate_canyon.gd),
## built at life size through a PropKit (y up, front toward -z, the origin on the ground under the middle)
## and placed by the generator at PROP_SCALE: the café's patio tables under market umbrellas and its chrome
## diner chairs, the fuel pumps, the islands' bins and squeegee buckets, the ice chest, the gas-bottle cage,
## a bench, a picnic table, the air and water post, oil drums and stacks of old tyres. They replaced boxes
## and flat slabs (a chair was two slabs, a pump a red box).
##
## Material keys (the generator's _prop_material): "paint", "metal", "chrome", "matte", "rubber", "glass",
## "lamp", "plastic", "canvas" (double sided), "timber" (hut_wood.gdshader, UVs in metres through
## VenueKit.timber), "tyre" (tyre_wall.gdshader, PropKit.painted_tyre).

const PropKit = preload("res://PropKit.gd")
const VenueKit = preload("res://VenueKit.gd")

const CHROME := Color(0.82, 0.83, 0.85)
const IRON := Color(0.12, 0.12, 0.13)
const RUBBER := Color(0.07, 0.07, 0.08)

var _kit: PropKit
var _venue: VenueKit


func _init(kit: PropKit) -> void:
	_kit = kit
	_venue = VenueKit.new(kit)


# ======================================================================================
#  Helpers
# ======================================================================================

## A rounded rectangle, counter-clockwise, `steps` points a corner.
static func rrect(x0: float, x1: float, y0: float, y1: float, r: float, steps := 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr := minf(r, minf((x1 - x0) * 0.5, (y1 - y0) * 0.5))
	var corners := [[x1 - rr, y0 + rr, -PI * 0.5], [x1 - rr, y1 - rr, 0.0], [x0 + rr, y1 - rr, PI * 0.5], [x0 + rr, y0 + rr, PI]]
	for c in corners:
		for i in range(steps + 1):
			var a: float = float(c[2]) + PI * 0.5 * float(i) / steps
			pts.append(Vector2(float(c[0]) + cos(a) * rr, float(c[1]) + sin(a) * rr))
	return pts


## A slab with rounded corners lying flat: `size` across x and z, `thick` high, its middle at `c`, tipped
## back about x by `tilt` (a seat back), bevelled edges. Cushions, table tops, lids.
func slab(kit: Dictionary, key: String, c: Vector3, size: Vector2, thick: float, r: float, col: Color, tilt := 0.0) -> void:
	var saved: Transform3D = _kit.xf
	_kit.set_frame(saved * Transform3D(Basis(Vector3.RIGHT, tilt) * Basis(Vector3.RIGHT, PI * 0.5), c))
	_kit.extrude(kit, key, rrect(-size.x * 0.5, size.x * 0.5, -size.y * 0.5, size.y * 0.5, r), -thick * 0.5, thick * 0.5, minf(thick * 0.3, 0.02), col)
	_kit.set_frame(saved)


## A box with rounded vertical edges standing on y0: cabinets, bins, pumps.
func cabinet(kit: Dictionary, key: String, lo: Vector3, hi: Vector3, r: float, col: Color) -> void:
	var saved: Transform3D = _kit.xf
	# The outline is the footprint (x, z): turned so the extrusion runs up.
	_kit.set_frame(saved * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, (lo.y + hi.y) * 0.5, 0)))
	_kit.extrude(kit, key, rrect(lo.x, hi.x, lo.z, hi.z, r), -(hi.y - lo.y) * 0.5, (hi.y - lo.y) * 0.5, minf(r * 0.5, 0.02), col)
	_kit.set_frame(saved)


## A hose or a cable: a cubic from a through handles b and c to d, as joined tubes.
func hose(kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, r: float, col: Color, n := 12) -> void:
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		var p: Vector3 = a * (u * u * u) + b * (3.0 * u * u * t) + c * (3.0 * u * t * t) + d * (t * t * t)
		_kit.tube(kit, key, prev, p, r, r, 6, col, i == 1 or i == n)
		prev = p


# ======================================================================================
#  The café's patio
# ======================================================================================

const TABLE_TOP := 0.74
const TABLE_R := 0.55

## A round patio table for four: an enamelled top with a rolled edge on four splayed legs joined by a ring,
## a hole in the middle for the umbrella, and what stands on a diner's table (a napkin box, salt and pepper,
## a sugar pourer, ketchup and mustard).
func patio_table(kit: Dictionary, top: Color, rng: RandomNumberGenerator) -> void:
	var k := _kit
	var y := TABLE_TOP
	var r := TABLE_R
	k.lathe(kit, "paint", Vector3.ZERO, [Vector2(0.03, y - 0.035), Vector2(r - 0.03, y - 0.035), Vector2(r, y - 0.025),
			Vector2(r + 0.008, y - 0.008), Vector2(r, y + 0.006), Vector2(r - 0.02, y + 0.01), Vector2(0.03, y + 0.01)], 28, top)
	k.lathe(kit, "metal", Vector3.ZERO, [Vector2(0.03, y + 0.01), Vector2(0.03, y - 0.035)], 10, IRON)
	k.lathe(kit, "metal", Vector3.ZERO, [Vector2(0.0, y - 0.07), Vector2(0.09, y - 0.07), Vector2(0.09, y - 0.035), Vector2(0.0, y - 0.035)], 12, IRON, true)
	for i in range(4):
		var a := TAU * (float(i) + 0.5) / 4.0
		var d := Vector3(cos(a), 0.0, sin(a))
		k.tube(kit, "metal", d * 0.08 + Vector3(0, y - 0.06, 0), d * 0.42, 0.016, 0.014, 6, IRON)
		k.lathe(kit, "rubber", d * 0.42, [Vector2(0.0, 0.0), Vector2(0.025, 0.0), Vector2(0.02, 0.02), Vector2(0.0, 0.02)], 8, RUBBER)
	k.tyre(kit, "metal", Vector3(0, 0.26, 0), 0.25, 0.27, 0.012, 20, IRON)
	# On the table.
	var off := Vector3(0.18, y + 0.01, 0.12).rotated(Vector3.UP, rng.randf() * TAU)
	k.block(kit, "chrome", off + Vector3(-0.06, 0.0, -0.03), off + Vector3(0.06, 0.11, 0.03), CHROME)
	k.block(kit, "paint", off + Vector3(-0.055, 0.025, -0.032), off + Vector3(0.055, 0.105, 0.032), Color(0.95, 0.95, 0.93))
	var side := off.rotated(Vector3.UP, 0.6)
	for j in range(2):
		var p: Vector3 = side + Vector3(0.0, 0.0, -0.04 + j * 0.08).rotated(Vector3.UP, rng.randf() * 0.3)
		k.lathe(kit, "glass", p, [Vector2(0.0, 0.0), Vector2(0.02, 0.0), Vector2(0.022, 0.05), Vector2(0.018, 0.065)], 8, Color(0.85, 0.88, 0.9))
		k.lathe(kit, "chrome", p + Vector3(0, 0.065, 0), [Vector2(0.018, 0.0), Vector2(0.018, 0.012), Vector2(0.0, 0.022)], 8, CHROME)
	var sug := off.rotated(Vector3.UP, -0.7)
	k.lathe(kit, "glass", sug, [Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.038, 0.09), Vector2(0.03, 0.1)], 10, Color(0.9, 0.9, 0.88))
	k.lathe(kit, "chrome", sug + Vector3(0, 0.1, 0), [Vector2(0.03, 0.0), Vector2(0.03, 0.015), Vector2(0.008, 0.045), Vector2(0.0, 0.05)], 10, CHROME)
	for j in range(2):
		var b: Vector3 = off.rotated(Vector3.UP, 1.5 + j * 0.25)
		var col: Color = Color(0.78, 0.08, 0.06) if j == 0 else Color(0.95, 0.75, 0.10)
		k.lathe(kit, "plastic", b, [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.032, 0.14), Vector2(0.015, 0.17), Vector2(0.006, 0.2), Vector2(0.0, 0.2)], 10, col)


## A chrome diner chair facing -z (its sitter looks along -z): bent tube legs, a padded vinyl seat with a
## chrome band, a padded back on two uprights.
func diner_chair(kit: Dictionary, vinyl: Color) -> void:
	var k := _kit
	var seat_y := 0.46
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.19
		# Front leg up into the seat rail, back leg on up as the back's upright.
		k.tube(kit, "chrome", Vector3(x * 1.08, 0.0, -0.2), Vector3(x, seat_y - 0.06, -0.18), 0.012, 0.012, 8, CHROME)
		k.tube(kit, "chrome", Vector3(x * 1.08, 0.0, 0.22), Vector3(x, seat_y - 0.06, 0.18), 0.012, 0.012, 8, CHROME)
		k.tube(kit, "chrome", Vector3(x, seat_y - 0.06, 0.18), Vector3(x, 0.92, 0.25), 0.012, 0.012, 8, CHROME)
		k.tube(kit, "chrome", Vector3(x, seat_y - 0.06, -0.18), Vector3(x, seat_y - 0.06, 0.18), 0.01, 0.01, 6, CHROME)
		for z in [-0.2, 0.22]:
			k.lathe(kit, "rubber", Vector3(x * 1.08, 0.0, z), [Vector2(0.0, 0.0), Vector2(0.016, 0.0), Vector2(0.014, 0.015), Vector2(0.0, 0.015)], 6, RUBBER)
	k.tube(kit, "chrome", Vector3(-0.2, 0.18, 0.2), Vector3(0.2, 0.18, 0.2), 0.009, 0.009, 6, CHROME)
	k.tube(kit, "chrome", Vector3(-0.2, 0.18, -0.19), Vector3(0.2, 0.18, -0.19), 0.009, 0.009, 6, CHROME)
	slab(kit, "plastic", Vector3(0, seat_y - 0.045, 0), Vector2(0.44, 0.42), 0.03, 0.06, CHROME)
	slab(kit, "plastic", Vector3(0, seat_y - 0.005, 0), Vector2(0.42, 0.4), 0.06, 0.07, vinyl)
	slab(kit, "plastic", Vector3(0, 0.78, 0.232), Vector2(0.4, 0.06), 0.24, 0.05, vinyl, 0.14)
	slab(kit, "plastic", Vector3(0, 0.78, 0.262), Vector2(0.41, 0.025), 0.25, 0.05, CHROME, 0.14)


## A market umbrella: a pole with its crank over a weighted base, eight ribs from the hub, a canopy of eight
## gores sagging between them in two colours, a scalloped valance, a vent cap and finial on top, the
## stretchers from the runner up the pole. `height` is the hub's.
func market_umbrella(kit: Dictionary, col_a: Color, col_b: Color, radius := 1.35, height := 2.4) -> void:
	var k := _kit
	var white := Color(0.92, 0.92, 0.9)
	k.lathe(kit, "metal", Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.035), Vector2(0.1, 0.07), Vector2(0.04, 0.09), Vector2(0.0, 0.09)], 18, IRON)
	k.tube(kit, "metal", Vector3(0, 0.05, 0), Vector3(0, height + 0.05, 0), 0.022, 0.02, 8, white)
	k.block(kit, "metal", Vector3(-0.03, 1.32, -0.03), Vector3(0.03, 1.42, 0.05), white.darkened(0.2))
	k.tube(kit, "metal", Vector3(0, 1.37, 0.05), Vector3(0, 1.37, 0.12), 0.006, 0.006, 4, IRON)
	var droop := 0.32
	var rib_pt := func(a: float, t: float) -> Vector3:
		return Vector3(cos(a) * radius * t, height - droop * t * t - 0.06 * sin(PI * t), sin(a) * radius * t)
	var gores := 8
	var rows := 4
	for g in range(gores):
		var a0 := TAU * g / gores
		var a1 := TAU * (g + 1) / gores
		var col: Color = col_a if g % 2 == 0 else col_b
		var under: Color = col.darkened(0.35)
		for rrow in range(rows):
			var t0 := float(rrow) / rows
			var t1 := float(rrow + 1) / rows
			var l0: Vector3 = rib_pt.call(a0, t0)
			var r0: Vector3 = rib_pt.call(a1, t0)
			var l1: Vector3 = rib_pt.call(a0, t1)
			var r1: Vector3 = rib_pt.call(a1, t1)
			# The cloth sags between the ribs, more toward the edge.
			var m0: Vector3 = (l0 + r0) * 0.5 - Vector3(0, 0.035 * t0, 0)
			var m1: Vector3 = (l1 + r1) * 0.5 - Vector3(0, 0.035 * t1, 0)
			for q in [[l0, m0, m1, l1], [m0, r0, r1, m1]]:
				var nrm: Vector3 = ((q[2] - q[0]) as Vector3).cross((q[1] as Vector3) - (q[3] as Vector3)).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				k.panel(kit, "canvas", q, nrm, col, under)
		# The valance: a flap down from the edge, scalloped.
		var e0: Vector3 = rib_pt.call(a0, 1.0)
		var e1: Vector3 = rib_pt.call(a1, 1.0)
		var em: Vector3 = (e0 + e1) * 0.5 - Vector3(0, 0.035, 0)
		var out := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		for half in [[e0, em], [em, e1]]:
			var p0: Vector3 = half[0]
			var p1: Vector3 = half[1]
			k.panel(kit, "canvas", [p0, p1, p1 - Vector3(0, 0.12, 0), p0 - Vector3(0, 0.16, 0)], out, col, under)
		# The rib, and its stretcher from the runner.
		k.tube(kit, "metal", rib_pt.call(a0, 0.08), (rib_pt.call(a0, 1.0) as Vector3) - Vector3(0, 0.01, 0), 0.007, 0.006, 4, white)
		k.tube(kit, "metal", Vector3(0, height - 0.55, 0), (rib_pt.call(a0, 0.55) as Vector3) - Vector3(0, 0.02, 0), 0.006, 0.006, 4, white)
	k.lathe(kit, "metal", Vector3(0, height - 0.6, 0), [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.04, 0.08), Vector2(0.0, 0.08)], 10, white)
	k.lathe(kit, "canvas", Vector3(0, height - 0.02, 0), [Vector2(0.24, 0.0), Vector2(0.22, 0.06), Vector2(0.12, 0.12), Vector2(0.0, 0.14)], 16, col_a)
	k.lathe(kit, "metal", Vector3(0, height + 0.12, 0), [Vector2(0.0, 0.0), Vector2(0.03, 0.02), Vector2(0.035, 0.06), Vector2(0.0, 0.11)], 10, white)


# ======================================================================================
#  The forecourt
# ======================================================================================

## A fuel dispenser on its island, serving both sides (its faces are ±z, its width along x): a plinth, a
## cabinet with rounded edges in `body`, a lit header with the brand's band in `trim`, and on each face a
## display (sale, litres, price), the grade buttons, a card reader, two nozzles in their holsters with
## coloured grips and their hoses looping down from the cabinet's shoulders.
func fuel_pump(kit: Dictionary, body: Color, trim: Color) -> void:
	var k := _kit
	var dark := Color(0.08, 0.08, 0.09)
	var white := Color(0.94, 0.94, 0.92)
	cabinet(kit, "paint", Vector3(-0.5, 0.0, -0.36), Vector3(0.5, 0.14, 0.36), 0.04, Color(0.32, 0.33, 0.34))
	cabinet(kit, "paint", Vector3(-0.45, 0.14, -0.27), Vector3(0.45, 1.72, 0.27), 0.07, body)
	cabinet(kit, "paint", Vector3(-0.48, 1.72, -0.3), Vector3(0.48, 2.12, 0.3), 0.05, white)
	cabinet(kit, "paint", Vector3(-0.5, 2.12, -0.32), Vector3(0.5, 2.16, 0.32), 0.05, body.darkened(0.2))
	for sz in [-1.0, 1.0]:
		var f: float = sz * 0.27
		var o: float = sz * 0.012
		# The header's band, lit, and the price board under it.
		k.block(kit, "lamp", Vector3(-0.44, 1.86, f * 1.11 - o), Vector3(0.44, 2.0, f * 1.11 + o), trim)
		# The display: a dark bezel, the glass, three rows of digits.
		k.block(kit, "matte", Vector3(-0.3, 1.18, f - o), Vector3(0.3, 1.64, f + o * 1.5), dark)
		for row in range(3):
			var y: float = 1.55 - row * 0.12
			k.block(kit, "lamp", Vector3(-0.05, y - 0.035, f + o * 1.6), Vector3(0.24, y + 0.035, f + o * 2.2), Color(0.35, 1.0, 0.45) if row < 2 else Color(1.0, 0.75, 0.25))
			k.block(kit, "paint", Vector3(-0.25, y - 0.02, f + o * 1.6), Vector3(-0.09, y + 0.02, f + o * 2.0), Color(0.75, 0.76, 0.74))
		# Grade buttons, the card reader and keypad.
		for gi in range(3):
			var gx: float = -0.2 + gi * 0.2
			k.block(kit, "lamp", Vector3(gx - 0.06, 1.06, f + o), Vector3(gx + 0.06, 1.12, f + o * 2.2), [Color(0.2, 0.75, 0.3), Color(0.95, 0.75, 0.15), Color(0.85, 0.15, 0.12)][gi])
		k.block(kit, "matte", Vector3(0.3, 1.2, f - o), Vector3(0.42, 1.48, f + o * 2.0), dark)
		k.block(kit, "chrome", Vector3(0.31, 1.42, f + o * 2.0), Vector3(0.41, 1.44, f + o * 2.6), CHROME)
		for kr in range(3):
			for kc in range(3):
				k.block(kit, "plastic", Vector3(0.315 + kc * 0.032, 1.24 + kr * 0.04, f + o * 2.0), Vector3(0.34 + kc * 0.032, 1.27 + kr * 0.04, f + o * 2.8), Color(0.7, 0.7, 0.72))
		# A chrome band round the waist.
		k.block(kit, "chrome", Vector3(-0.45, 0.9, f - o), Vector3(0.45, 0.94, f + o * 1.5), CHROME)
		for side in [-1.0, 1.0]:
			# A holster on the cabinet's edge, the nozzle hung in it, the hose from the shoulder.
			var hx: float = side * 0.36
			var holster := Vector3(hx, 0.98, f + sz * 0.05)
			k.block(kit, "matte", holster + Vector3(-0.06, -0.08, -0.05), holster + Vector3(0.06, 0.08, 0.05), dark)
			var grip: Color = Color(0.2, 0.7, 0.3) if side < 0.0 else Color(0.12, 0.12, 0.13)
			var hand := holster + Vector3(0, 0.02, sz * 0.09)
			k.beam(kit, "plastic", hand + Vector3(0, -0.02, 0), hand + Vector3(0, 0.16, sz * 0.05), 0.045, 0.06, grip)
			k.tube(kit, "chrome", hand + Vector3(0, -0.02, sz * 0.02), hand + Vector3(0, -0.2, sz * 0.02), 0.012, 0.01, 6, CHROME)
			k.tube(kit, "metal", hand + Vector3(0, 0.07, -sz * 0.03), hand + Vector3(0, -0.03, -sz * 0.03), 0.006, 0.006, 4, CHROME)
			var top := Vector3(side * 0.45, 1.6, f * 0.6)
			var end := hand + Vector3(0, 0.17, sz * 0.06)
			hose(kit, "rubber", top, top + Vector3(side * 0.25, -0.6, sz * 0.2), end + Vector3(side * 0.05, -0.9, sz * 0.25), end, 0.018, RUBBER)


## A litter bin for an island's end: a square body with rounded edges, its dome lid with a push flap,
## a paper-towel box on a post beside it and a bucket of washer fluid with a squeegee standing in it.
func island_bin(kit: Dictionary, body: Color) -> void:
	var k := _kit
	cabinet(kit, "paint", Vector3(-0.24, 0.0, -0.24), Vector3(0.24, 0.85, 0.24), 0.06, body)
	k.lathe(kit, "paint", Vector3(0, 0.85, 0), [Vector2(0.26, 0.0), Vector2(0.26, 0.04), Vector2(0.2, 0.14), Vector2(0.08, 0.2), Vector2(0.0, 0.21)], 16, body.darkened(0.15))
	k.block(kit, "matte", Vector3(-0.1, 0.92, -0.215), Vector3(0.1, 1.0, -0.15), Color(0.06, 0.06, 0.07))
	k.block(kit, "paint", Vector3(-0.2, 0.55, -0.245), Vector3(0.2, 0.68, -0.235), Color(0.92, 0.92, 0.88))
	# Paper towels on a post.
	k.tube(kit, "metal", Vector3(0.45, 0.0, 0.0), Vector3(0.45, 1.1, 0.0), 0.02, 0.02, 6, Color(0.5, 0.5, 0.52))
	cabinet(kit, "paint", Vector3(0.36, 1.1, -0.08), Vector3(0.54, 1.38, 0.08), 0.03, Color(0.85, 0.85, 0.83))
	k.block(kit, "paint", Vector3(0.4, 1.12, -0.085), Vector3(0.5, 1.15, -0.075), Color(0.95, 0.95, 0.93))
	# The bucket and its squeegee.
	var bc := Vector3(-0.48, 0.0, 0.05)
	k.lathe(kit, "plastic", bc, [Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.16, 0.32), Vector2(0.17, 0.34), Vector2(0.15, 0.34), Vector2(0.14, 0.3)], 14, Color(0.15, 0.35, 0.7))
	k.lathe(kit, "glass", bc + Vector3(0, 0.28, 0), [Vector2(0.145, 0.0), Vector2(0.0, 0.0)], 14, Color(0.25, 0.45, 0.55), true)
	var tip := bc + Vector3(0.04, 0.12, 0.0)
	var grip := bc + Vector3(-0.12, 0.85, 0.06)
	k.tube(kit, "metal", tip, grip, 0.014, 0.014, 6, Color(0.35, 0.36, 0.38))
	k.beam(kit, "rubber", tip + Vector3(0, 0.03, -0.12), tip + Vector3(0, 0.03, 0.12), 0.05, 0.03, RUBBER)


## An ice merchandiser: a white insulated cabinet with two doors, their chrome handles and hinges, a blue
## band ("HIELO" goes on it as a label), a compressor grille at the side and feet.
func ice_chest(kit: Dictionary) -> void:
	var k := _kit
	var white := Color(0.93, 0.94, 0.95)
	var blue := Color(0.15, 0.40, 0.78)
	cabinet(kit, "paint", Vector3(-0.85, 0.08, -0.4), Vector3(0.85, 1.25, 0.4), 0.05, white)
	slab(kit, "paint", Vector3(0, 1.27, 0), Vector2(1.72, 0.82), 0.04, 0.05, white.darkened(0.06))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.block(kit, "metal", Vector3(sx * 0.78 - 0.04, 0.0, sz * 0.33 - 0.04), Vector3(sx * 0.78 + 0.04, 0.08, sz * 0.33 + 0.04), Color(0.3, 0.3, 0.32))
	for dx in [-0.42, 0.42]:
		k.block(kit, "paint", Vector3(dx - 0.39, 0.2, -0.415), Vector3(dx + 0.39, 0.98, -0.4), white.darkened(0.03))
		k.block(kit, "matte", Vector3(dx - 0.4, 0.19, -0.405), Vector3(dx + 0.4, 0.2, -0.398), Color(0.4, 0.4, 0.42))
		k.tube(kit, "chrome", Vector3(dx + (0.3 if dx < 0.0 else -0.3), 0.5, -0.44), Vector3(dx + (0.3 if dx < 0.0 else -0.3), 0.75, -0.44), 0.012, 0.012, 6, CHROME)
		for hy in [0.3, 0.88]:
			k.block(kit, "chrome", Vector3(dx + (-0.39 if dx < 0.0 else 0.35), hy, -0.43), Vector3(dx + (-0.35 if dx < 0.0 else 0.39), hy + 0.06, -0.41), CHROME)
	k.block(kit, "paint", Vector3(-0.85, 1.0, -0.412), Vector3(0.85, 1.22, -0.402), blue)
	for wv in range(8):
		k.block(kit, "paint", Vector3(-0.82 + wv * 0.22, 1.03, -0.415), Vector3(-0.74 + wv * 0.22, 1.05, -0.41), Color(0.85, 0.92, 1.0))
	for g in range(7):
		k.block(kit, "matte", Vector3(0.851, 0.2 + g * 0.06, -0.25), Vector3(0.86, 0.23 + g * 0.06, 0.25), Color(0.15, 0.15, 0.16))


## A cage of gas bottles for exchange: a welded frame with mesh bars on three sides, a door of bars at the
## front with its padlock, a sloping sheet roof, and two rows of bottles inside (foot ring, body, collar,
## valve).
func gas_cage(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var k := _kit
	var frame := Color(0.55, 0.57, 0.58)
	var hw := 1.0
	var hd := 0.42
	var h := 1.35
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.block(kit, "metal", Vector3(sx * hw - 0.025, 0.0, sz * hd - 0.025), Vector3(sx * hw + 0.025, h + (0.08 if sz > 0.0 else 0.0), sz * hd + 0.025), frame)
	for y in [0.05, h * 0.5, h]:
		for sz in [-1.0, 1.0]:
			k.block(kit, "metal", Vector3(-hw, y - 0.015, sz * hd - 0.015), Vector3(hw, y + 0.015, sz * hd + 0.015), frame)
		for sx in [-1.0, 1.0]:
			k.block(kit, "metal", Vector3(sx * hw - 0.015, y - 0.015, -hd), Vector3(sx * hw + 0.015, y + 0.015, hd), frame)
	# Bars every 8cm: the back, the ends, the doors at the front.
	var x := -hw + 0.08
	while x < hw - 0.04:
		for sz in [-1.0, 1.0]:
			k.tube(kit, "metal", Vector3(x, 0.05, sz * hd), Vector3(x, h, sz * hd), 0.006, 0.006, 4, frame)
		x += 0.08
	var z := -hd + 0.08
	while z < hd - 0.04:
		for sx in [-1.0, 1.0]:
			k.tube(kit, "metal", Vector3(sx * hw, 0.05, z), Vector3(sx * hw, h, z), 0.006, 0.006, 4, frame)
		z += 0.08
	k.block(kit, "metal", Vector3(-0.02, 0.6, -hd - 0.05), Vector3(0.02, 0.74, -hd - 0.02), Color(0.75, 0.6, 0.2))
	var rn := Vector3(0, 1.0, 0.18).normalized()
	k.quad(kit, "metal", [Vector3(-hw - 0.06, h + 0.02, -hd - 0.08), Vector3(hw + 0.06, h + 0.02, -hd - 0.08), Vector3(hw + 0.06, h + 0.1, hd + 0.08), Vector3(-hw - 0.06, h + 0.1, hd + 0.08)], -rn, frame.darkened(0.1))
	k.quad(kit, "metal", [Vector3(-hw - 0.06, h + 0.02, -hd - 0.08), Vector3(-hw - 0.06, h + 0.1, hd + 0.08), Vector3(hw + 0.06, h + 0.1, hd + 0.08), Vector3(hw + 0.06, h + 0.02, -hd - 0.08)], rn, frame)
	for row in range(2):
		for i in range(5):
			var c := Vector3(-0.76 + i * 0.38 + rng.randf_range(-0.03, 0.03), 0.07 + row * h * 0.5, rng.randf_range(-0.08, 0.08))
			if row == 1 and rng.randf() < 0.3:
				continue
			bottle(kit, c, Color(0.92, 0.92, 0.9) if (i + row) % 3 != 0 else Color(0.2, 0.4, 0.75))


## A gas bottle standing at `c`: foot ring, rounded body, collar with its handle ring and valve.
func bottle(kit: Dictionary, c: Vector3, col: Color) -> void:
	var k := _kit
	var r := 0.15
	k.lathe(kit, "paint", c, [Vector2(r * 0.85, 0.0), Vector2(r * 0.9, 0.05), Vector2(r * 0.8, 0.06), Vector2(r * 0.95, 0.08),
			Vector2(r, 0.13), Vector2(r, 0.42), Vector2(r * 0.9, 0.5), Vector2(r * 0.55, 0.55), Vector2(0.0, 0.56)], 14, col)
	k.tyre(kit, "metal", c + Vector3(0, 0.6, 0), 0.07, 0.085, 0.07, 12, col.darkened(0.1))
	k.tube(kit, "chrome", c + Vector3(0, 0.55, 0), c + Vector3(0, 0.63, 0), 0.018, 0.018, 6, Color(0.75, 0.6, 0.3))
	k.tube(kit, "chrome", c + Vector3(0, 0.6, 0), c + Vector3(0.05, 0.6, 0), 0.01, 0.01, 6, Color(0.75, 0.6, 0.3))


## A park bench along x, facing -z: cast-iron ends with arms, four seat slats and three in the back.
func bench(kit: Dictionary, length := 1.8) -> void:
	var k := _kit
	var wood := Color(0.55, 0.38, 0.24)
	var hl := length * 0.5
	var leg := PackedVector2Array([Vector2(-0.28, 0.0), Vector2(-0.22, 0.0), Vector2(-0.18, 0.36), Vector2(0.14, 0.38), Vector2(0.24, 0.0),
			Vector2(0.3, 0.0), Vector2(0.22, 0.42), Vector2(0.3, 0.86), Vector2(0.25, 0.87), Vector2(0.17, 0.44), Vector2(-0.2, 0.44),
			Vector2(-0.26, 0.64), Vector2(-0.31, 0.62), Vector2(-0.24, 0.4)])
	for sx in [-1.0, 1.0]:
		var saved: Transform3D = k.xf
		# The end's profile runs front (-x) to back (+x): turned so its x runs along the bench's +z.
		k.set_frame(saved * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(sx * (hl - 0.12), 0, 0)))
		k.extrude(kit, "metal", leg, -0.02, 0.02, 0.006, IRON)
		k.set_frame(saved)
		k.tube(kit, "metal", Vector3(sx * (hl - 0.12), 0.62, -0.31), Vector3(sx * (hl - 0.12), 0.62, -0.05), 0.02, 0.02, 6, IRON)
	for i in range(4):
		var z := -0.24 + i * 0.12
		_venue.timber(kit, Vector3(-hl, 0.45, z), Vector3(hl, 0.45, z), 0.1, 0.03, wood, Vector3.BACK)
	for i in range(3):
		var y := 0.55 + i * 0.12
		var z2 := 0.18 + i * 0.045
		_venue.timber(kit, Vector3(-hl, y, z2), Vector3(hl, y, z2), 0.09, 0.025, wood, Vector3(0, 0.35, -1).normalized().cross(Vector3.RIGHT))


## A picnic table along x: five top planks on two A-frames, a bench plank either side, braces.
func picnic_table(kit: Dictionary) -> void:
	var wood := Color(0.52, 0.37, 0.24)
	var hl := 0.95
	for i in range(5):
		var z := -0.32 + i * 0.16
		_venue.timber(kit, Vector3(-hl, 0.76, z), Vector3(hl, 0.76, z), 0.14, 0.04, wood, Vector3.BACK)
	for sz in [-1.0, 1.0]:
		_venue.timber(kit, Vector3(-hl, 0.45, sz * 0.66), Vector3(hl, 0.45, sz * 0.66), 0.24, 0.04, wood, Vector3.BACK)
	for sx in [-0.7, 0.7]:
		_venue.timber(kit, Vector3(sx, 0.72, -0.36), Vector3(sx, 0.72, 0.36), 0.08, 0.06, wood.darkened(0.1), Vector3.RIGHT)
		_venue.timber(kit, Vector3(sx, 0.41, -0.8), Vector3(sx, 0.41, 0.8), 0.08, 0.06, wood.darkened(0.1), Vector3.RIGHT)
		for sz in [-1.0, 1.0]:
			_venue.timber(kit, Vector3(sx, 0.74, sz * 0.12), Vector3(sx, 0.0, sz * 0.62), 0.08, 0.06, wood.darkened(0.1), Vector3.RIGHT)
	_venue.timber(kit, Vector3(-0.68, 0.42, 0.0), Vector3(0.0, 0.72, 0.0), 0.07, 0.05, wood.darkened(0.15), Vector3.BACK)
	_venue.timber(kit, Vector3(0.68, 0.42, 0.0), Vector3(0.0, 0.72, 0.0), 0.07, 0.05, wood.darkened(0.15), Vector3.BACK)


## The air and water post, facing -z: a rounded cabinet with its header (the words are a label), the
## pressure gauge, the coin box, two hoses coiled on their hooks.
func air_post(kit: Dictionary) -> void:
	var k := _kit
	var blue := Color(0.15, 0.32, 0.62)
	var red := Color(0.78, 0.14, 0.10)
	k.block(kit, "paint", Vector3(-0.32, 0.0, -0.26), Vector3(0.32, 0.08, 0.26), Color(0.4, 0.4, 0.42))
	cabinet(kit, "paint", Vector3(-0.24, 0.08, -0.18), Vector3(0.24, 1.38, 0.18), 0.05, blue)
	cabinet(kit, "paint", Vector3(-0.27, 1.38, -0.21), Vector3(0.27, 1.62, 0.21), 0.04, red)
	k.lathe(kit, "chrome", Vector3(0, 1.08, -0.18), [Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.09, 0.03), Vector2(0.0, 0.03)], 16, CHROME, false, Basis(Vector3.RIGHT, -PI * 0.5))
	k.lathe(kit, "paint", Vector3(0, 1.08, -0.212), [Vector2(0.075, 0.0), Vector2(0.0, 0.0)], 16, Color(0.95, 0.95, 0.92), true, Basis(Vector3.RIGHT, -PI * 0.5))
	k.beam(kit, "matte", Vector3(0, 1.08, -0.216), Vector3(0.05, 1.12, -0.216), 0.008, 0.004, Color(0.8, 0.1, 0.1))
	k.block(kit, "chrome", Vector3(-0.1, 0.72, -0.2), Vector3(0.1, 0.9, -0.17), CHROME)
	k.block(kit, "matte", Vector3(-0.03, 0.84, -0.205), Vector3(0.03, 0.85, -0.2), Color(0.05, 0.05, 0.05))
	for sx in [-1.0, 1.0]:
		var hook := Vector3(sx * 0.26, 0.9, 0.0)
		k.tube(kit, "metal", hook, hook + Vector3(sx * 0.08, 0.04, 0), 0.012, 0.012, 6, CHROME)
		for loop in range(3):
			k.tyre(kit, "rubber", hook + Vector3(sx * 0.1, -0.24 - loop * 0.01, loop * 0.015 - 0.015), 0.2, 0.22, 0.02, 16, RUBBER if sx < 0.0 else Color(0.15, 0.3, 0.6), Basis(Vector3.FORWARD, PI * 0.5))


## A 200-litre oil drum: rolled chimes top and bottom, two rolling hoops, a lid with its two bungs.
func oil_drum(kit: Dictionary, col: Color) -> void:
	var k := _kit
	var r := 0.29
	k.lathe(kit, "paint", Vector3.ZERO, [Vector2(r - 0.02, 0.0), Vector2(r + 0.005, 0.01), Vector2(r + 0.005, 0.03), Vector2(r - 0.005, 0.04),
			Vector2(r - 0.005, 0.28), Vector2(r + 0.008, 0.29), Vector2(r + 0.008, 0.31), Vector2(r - 0.005, 0.32), Vector2(r - 0.005, 0.56),
			Vector2(r + 0.008, 0.57), Vector2(r + 0.008, 0.59), Vector2(r - 0.005, 0.6), Vector2(r - 0.005, 0.84), Vector2(r + 0.005, 0.85),
			Vector2(r + 0.005, 0.875), Vector2(r - 0.02, 0.88), Vector2(r - 0.02, 0.865), Vector2(0.0, 0.865)], 18, col)
	for bp in [Vector3(0.17, 0.865, 0.0), Vector3(-0.17, 0.865, 0.04)]:
		k.lathe(kit, "metal", bp, [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.012), Vector2(0.0, 0.012)], 8, Color(0.45, 0.45, 0.46))


## A stack of `n` old tyres (tyre_wall.gdshader), each shifted and turned a little.
func tyre_stack(kit: Dictionary, n: int, rng: RandomNumberGenerator) -> void:
	for t in range(n):
		var c := Vector3(rng.randf_range(-0.04, 0.04), 0.13 + t * 0.255, rng.randf_range(-0.04, 0.04))
		_kit.painted_tyre(kit, "tyre", c, 0.22, 0.4, 0.25, Color(0, 0, 0), rng.randf(), Basis(Vector3.UP, rng.randf() * TAU))
