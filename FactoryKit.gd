extends "res://YardKit.gd"
## Freight Line's grain cooperative (Cooperativa Granera), built through a PropKit at life size like YardKit's station
## and grown by the caller (PROP_SCALE). The frame: the head house's middle on the ground at the origin, x along the
## factory track, +z toward it (the track's centre line is at z = TRACK_Z), y up.
##
## West of the head house two rows of four slip-formed concrete silos (flat roofs with a parapet, hatches and vents,
## pilasters and ring beams, ladders) carry an enclosed conveyor gallery along the junction of the rows, which runs
## into the head house (a board-formed concrete tower with bands, slit windows, a penthouse in corrugated iron, a
## bucket elevator duct up its back); from its front a short gallery runs on to the loadout, a steel portal gantry over
## the track with a bin, a funnel and a telescopic spout over the hopper cars. Further west a warehouse (iron-clad,
## roller doors on a loading dock with a canopy), two steel tanks, a control hut and light masts.
##
## Everything rests on what carries it: gallery floors on the silo decks, posts cut to the underside above them,
## girders on the legs' tops.

const TRACK_Z := 14.0
const SILO_R := 4.4
const SILO_H := 20.0
const SILO_X := [-10.4, -19.2, -28.0, -36.8]
const HH_W := 12.0
const HH_D := 12.0
const HH_H := 26.0
const GY := 10.0
const WH_X0 := -100.0
const WH_X1 := -60.0
const WH_Z0 := -4.0
const WH_Z1 := 8.5
const DOCK_H := 1.2

const SILO_CONC := Color(0.74, 0.69, 0.60)
const SHEET := Color(0.66, 0.64, 0.56)
const SHEET_GREEN := Color(0.30, 0.43, 0.37)
const STEELWORK := Color(0.28, 0.31, 0.32)
const SAFETY_YELLOW := Color(0.93, 0.76, 0.12)
const GRAIN := Color(0.80, 0.66, 0.30)


# ======================================================================================
#  Small parts
# ======================================================================================

## A four-sided frustum (a hopper or a funnel): the rectangle of half sizes (hx0, hz0) at y0 narrowing to (hx1, hz1)
## at y1, centred on (cx, cz), faces outward.
static func frustum(pk: PropKit, kit: Dictionary, key: String, cx: float, cz: float, y0: float, hx0: float, hz0: float, y1: float, hx1: float, hz1: float, col: Color) -> void:
	var lo: Array = [Vector2(-hx0, -hz0), Vector2(hx0, -hz0), Vector2(hx0, hz0), Vector2(-hx0, hz0)]
	var hi: Array = [Vector2(-hx1, -hz1), Vector2(hx1, -hz1), Vector2(hx1, hz1), Vector2(-hx1, hz1)]
	for i in range(4):
		var j: int = (i + 1) % 4
		var a0 := Vector3(cx + lo[i].x, y0, cz + lo[i].y)
		var b0 := Vector3(cx + lo[j].x, y0, cz + lo[j].y)
		var b1 := Vector3(cx + hi[j].x, y1, cz + hi[j].y)
		var a1 := Vector3(cx + hi[i].x, y1, cz + hi[i].y)
		var n: Vector3 = (b0 - a0).cross(a1 - a0).normalized()
		var mid: Vector3 = (a0 + b0 + b1 + a1) * 0.25 - Vector3(cx, (y0 + y1) * 0.5, cz)
		if n.dot(mid) < 0.0:
			n = -n
		pk.quad(kit, key, [a0, b0, b1, a1], n, col)


## A slit window in a tall wall: dark glass in a steel frame with a mullion and a transom, `c` its middle on the wall's
## face, `out` the wall's outward normal.
static func slit_window(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	box_at(pk, kit, "glass", c + out * 0.03, basis, Vector3(w, h, 0.05), GLASS_COL)
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "steel", c + across * (sx * (w * 0.5 + 0.06)) + out * 0.06, basis, Vector3(0.12, h + 0.24, 0.12), STEELWORK)
	for sy in [-1.0, 1.0]:
		box_at(pk, kit, "steel", c + Vector3(0, sy * (h * 0.5 + 0.06), 0) + out * 0.06, basis, Vector3(w + 0.24, 0.12, 0.12), STEELWORK)
	box_at(pk, kit, "steel", c + out * 0.07, basis, Vector3(0.06, h, 0.06), STEELWORK)
	box_at(pk, kit, "steel", c + Vector3(0, h * 0.15, 0) + out * 0.07, basis, Vector3(w, 0.06, 0.06), STEELWORK)
	box_at(pk, kit, "concrete", c - Vector3(0, h * 0.5 + 0.2, 0) + out * 0.1, basis, Vector3(w + 0.5, 0.12, 0.26), CONCRETE.lightened(0.08))


## A pair of floodlight heads (a box with a glowing lens) at `p`, aimed `down` (unit, mostly downward) toward `out`.
static func floodlight(pk: PropKit, kit: Dictionary, p: Vector3, out: Vector3) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	basis = basis * Basis(Vector3.RIGHT, deg_to_rad(28.0))
	box_at(pk, kit, "steel", p, basis, Vector3(0.7, 0.5, 0.32), STEELWORK)
	box_at(pk, kit, "lamp", p + basis * Vector3(0, 0, 0.17), basis, Vector3(0.58, 0.4, 0.04), Color(1.0, 0.95, 0.80))
	box_at(pk, kit, "steel", p + basis * Vector3(0, 0.27, 0.12), basis, Vector3(0.74, 0.04, 0.3), STEELWORK.darkened(0.2))


## A lattice light mast: a tapering triangular tower to `h`, a cage ladder, a crossbar with four floodlights.
static func light_mast(pk: PropKit, kit: Dictionary, p: Vector3, h: float, out: Vector3) -> void:
	var legs: Array = []
	for k in range(3):
		var a: float = TAU * float(k) / 3.0 + 0.5
		legs.append(Vector2(cos(a), sin(a)))
	var r0 := 0.9
	var r1 := 0.35
	for lg in legs:
		pk.beam(kit, "steel", p + Vector3(lg.x * r0, 0, lg.y * r0), p + Vector3(lg.x * r1, h, lg.y * r1), 0.1, 0.1, STEELWORK)
	var y := 0.0
	while y < h - 1.2:
		var f0: float = lerpf(r0, r1, y / h)
		var f1: float = lerpf(r0, r1, (y + 1.2) / h)
		for k in range(3):
			var l0: Vector2 = legs[k]
			var l1: Vector2 = legs[(k + 1) % 3]
			pk.beam(kit, "steel", p + Vector3(l0.x * f0, y, l0.y * f0), p + Vector3(l1.x * f1, y + 1.2, l1.y * f1), 0.05, 0.05, STEELWORK)
			pk.beam(kit, "steel", p + Vector3(l0.x * f1, y + 1.2, l0.y * f1), p + Vector3(l1.x * f0, y, l1.y * f0), 0.05, 0.05, STEELWORK)
		y += 1.2
	pk.beam(kit, "steel", p + Vector3(-1.5, h, 0), p + Vector3(1.5, h, 0), 0.12, 0.12, STEELWORK, Vector3.UP)
	blk(pk, kit, "steel", p + Vector3(-0.5, h - 0.1, -0.5), p + Vector3(0.5, h + 0.05, 0.5), STEELWORK)
	for sx in [-1.2, -0.4, 0.4, 1.2]:
		floodlight(pk, kit, p + Vector3(sx, h + 0.4, 0) + out * 0.2, out)
	ladder(pk, kit, p + Vector3(0, 0, -r0 * 0.5), p + Vector3(0, h - 0.4, -r0 * 0.5), Vector3(0, 0, -1), true)


## A steel tank: a concrete ring, a welded shell with seams, a shallow cone roof with a catwalk and rail, a cage ladder,
## a manway, and a pipe with a valve wheel at the foot. `c` on the ground.
static func tank(pk: PropKit, kit: Dictionary, c: Vector3, r: float, h: float, col: Color) -> void:
	pk.tube(kit, "concrete", c, c + Vector3(0, 0.5, 0), r + 0.35, r + 0.35, 24, CONCRETE.darkened(0.1), false, uvk)
	pk.lathe(kit, "concrete", c, [Vector2(r + 0.35, 0.5), Vector2(r - 0.1, 0.5)], 24, CONCRETE.darkened(0.1), true)
	var y0 := 0.5
	pk.tube(kit, "paint", c + Vector3(0, y0, 0), c + Vector3(0, y0 + h, 0), r, r, 24, col, false)
	var y := y0 + 1.5
	while y < y0 + h - 0.3:
		pk.tube(kit, "paint", c + Vector3(0, y - 0.03, 0), c + Vector3(0, y + 0.03, 0), r + 0.04, r + 0.04, 24, col.darkened(0.2), false)
		y += 1.5
	pk.lathe(kit, "paint", c + Vector3(0, y0 + h, 0), [Vector2(r + 0.18, -0.05), Vector2(r + 0.18, 0.12), Vector2(r * 0.5, 0.7), Vector2(0.001, 1.0)], 24, col.lightened(0.08), false)
	# Eaves rail and the roof catwalk.
	var rim := y0 + h + 0.12
	var prev := Vector3.ZERO
	for k in range(25):
		var a: float = TAU * float(k) / 24.0
		var p: Vector3 = c + Vector3(cos(a) * (r + 0.18), rim, sin(a) * (r + 0.18))
		if k > 0:
			pk.beam(kit, "steel", prev + Vector3(0, 1.0, 0), p + Vector3(0, 1.0, 0), 0.05, 0.05, STEELWORK, Vector3.UP)
		if k % 3 == 0 and k < 24:
			pk.beam(kit, "steel", p, p + Vector3(0, 1.0, 0), 0.05, 0.05, STEELWORK)
		prev = p
	# Manway, pipe and valve at the foot, a ladder on the south side.
	box_at(pk, kit, "steel", c + Vector3(-r + 0.0, y0 + 1.0, 0), Basis(Vector3.UP, PI * 0.5), Vector3(0.9, 0.9, 0.3), STEELWORK)
	pk.tube(kit, "steel", c + Vector3(r - 0.1, y0 + 0.6, 1.0), c + Vector3(r + 1.6, y0 + 0.6, 1.0), 0.17, 0.17, 10, STEELWORK, true)
	pk.tube(kit, "steel", c + Vector3(r + 1.6, y0 + 0.6, 1.0), c + Vector3(r + 1.6, 0.0, 1.0), 0.17, 0.17, 10, STEELWORK, true)
	pk.tube(kit, "steel", c + Vector3(r + 1.6, y0 + 1.0, 1.0), c + Vector3(r + 1.6, y0 + 1.05, 1.0), 0.28, 0.28, 12, Color(0.7, 0.12, 0.1), true)
	ladder(pk, kit, c + Vector3(0, 0.5, r), c + Vector3(0, y0 + h + 0.12, r), Vector3(0, 0, 1), true)


## A pallet stack of sacks: `n` layers of 2 x 2 sacks on a pallet, `p` the middle of the base.
static func sack_stack(pk: PropKit, kit: Dictionary, p: Vector3, yaw: float, n: int, col := Color(0.82, 0.74, 0.55)) -> void:
	var basis := Basis(Vector3.UP, yaw)
	box_at(pk, kit, "timber", p + basis * Vector3(0, 0.07, 0), basis, Vector3(1.2, 0.14, 1.0), Color(0.55, 0.40, 0.25))
	for l in range(n):
		for sx in [-0.3, 0.3]:
			for sz in [-0.22, 0.22]:
				var off := 0.04 if (l % 2 == 0) else -0.04
				box_at(pk, kit, "paint", p + basis * Vector3(sx + off, 0.14 + 0.15 + 0.3 * float(l), sz - off), basis, Vector3(0.56, 0.28, 0.42), col.darkened(0.05 * float(l % 2)))


# ======================================================================================
#  The silos and their gallery
# ======================================================================================

## One silo: a stone footing, a slip-formed shaft with eight pilasters and two ring beams, a flat roof deck with a
## parapet (deck at h + 0.4, parapet to h + 0.8), a roof hatch and a vent. `c` on the ground.
static func silo(pk: PropKit, kit: Dictionary, c: Vector3, r: float, h: float, tone: float, with_ladder: bool, out: Vector3) -> void:
	var col := SILO_CONC.darkened(tone)
	pk.tube(kit, "concrete", c, c + Vector3(0, 1.15, 0), r + 0.3, r + 0.3, 28, SILO_CONC.darkened(0.22), false, uvk)
	pk.lathe(kit, "concrete", c, [Vector2(r + 0.3, 1.15), Vector2(r, 1.15)], 28, SILO_CONC.darkened(0.22), true)
	pk.tube(kit, "concrete", c + Vector3(0, 1.15, 0), c + Vector3(0, h, 0), r, r, 28, col, false, uvk)
	for k in range(8):
		var a: float = TAU * (float(k) + 0.5) / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		box_at(pk, kit, "concrete", c + d * (r + 0.01) + Vector3(0, (1.15 + h - 0.5) * 0.5, 0), Basis(Vector3.UP, PI * 0.5 - a), Vector3(0.55, h - 0.5 - 1.15, 0.3), col.darkened(0.05))
	for y in [h * 0.36, h * 0.7]:
		pk.tube(kit, "concrete", c + Vector3(0, y, 0), c + Vector3(0, y + 0.45, 0), r + 0.09, r + 0.09, 28, col.darkened(0.1), false, uvk)
	# The roof: a cornice overhanging the shaft, a low parapet, the deck and a slight crown.
	pk.lathe(kit, "concrete", c, [Vector2(r, h - 0.5), Vector2(r + 0.4, h - 0.5), Vector2(r + 0.4, h + 0.8), Vector2(r + 0.1, h + 0.8), Vector2(r + 0.1, h + 0.4), Vector2(2.0, h + 0.4),
			Vector2(0.9, h + 0.5), Vector2(0.001, h + 0.5)], 28, col.darkened(0.04), true)
	# Hatch, vent and a lightning rod on the deck.
	var hatch := c + Vector3(2.2, h + 0.4, 1.5)
	blk(pk, kit, "steel", hatch + Vector3(-0.5, 0, -0.5), hatch + Vector3(0.5, 0.55, 0.5), STEELWORK)
	blk(pk, kit, "steel", hatch + Vector3(-0.58, 0.55, -0.58), hatch + Vector3(0.58, 0.62, 0.58), STEELWORK.lightened(0.1))
	var vent := c + Vector3(-2.0, h + 0.4, -1.4)
	pk.tube(kit, "steel", vent, vent + Vector3(0, 1.1, 0), 0.22, 0.22, 10, STEELWORK, true)
	pk.lathe(kit, "steel", vent + Vector3(0, 1.1, 0), [Vector2(0.4, 0.0), Vector2(0.3, 0.16), Vector2(0.001, 0.3)], 10, STEELWORK.lightened(0.08), false)
	if with_ladder:
		ladder(pk, kit, c + out * (r - 0.02) + Vector3(0, 1.15, 0), c + out * (r - 0.02) + Vector3(0, h + 0.8, 0), out, true)
		# A railing round the top of the ladder.
		var across: Vector3 = out.cross(Vector3.UP).normalized()
		railing(pk, kit, c + out * (r - 0.7) + across * -1.0 + Vector3(0, h + 0.4, 0), c + out * (r - 0.7) + across * 1.0 + Vector3(0, h + 0.4, 0), 0.5)


## The enclosed conveyor gallery along the tops of the silos: a floor on the decks, corrugated sheet walls with a row of
## windows, a pitched sheet roof, concrete plugs over the star bins between the silos. It runs from the last silo into
## the head house's west wall.
static func top_gallery(pk: PropKit, kit: Dictionary) -> void:
	var x0: float = SILO_X[SILO_X.size() - 1] - 3.2
	var x1: float = -HH_W * 0.5
	var z: float = -SILO_R
	var deck: float = SILO_H + 0.4
	var hw := 1.5
	var wall_h := 2.5
	var y_base: float = deck + 0.3
	# Plugs over the interstices between each pair of silos and the base the gallery stands on.
	for k in range(SILO_X.size() - 1):
		var xj: float = (float(SILO_X[k]) + float(SILO_X[k + 1])) * 0.5
		blk(pk, kit, "concrete", Vector3(xj - 2.2, deck - 0.4, z - 2.2), Vector3(xj + 2.2, deck, z + 2.2), SILO_CONC.darkened(0.06))
	blk(pk, kit, "concrete", Vector3(x0, deck, z - hw - 0.15), Vector3(x1, y_base, z + hw + 0.15), CONCRETE.darkened(0.14))
	# Walls.
	wall(pk, kit, "iron", Vector3(x0, 0, z + hw), Vector3(x1, 0, z + hw), y_base, y_base + wall_h, SHEET, Vector3(0, 0, 1))
	wall(pk, kit, "iron", Vector3(x1, 0, z - hw), Vector3(x0, 0, z - hw), y_base, y_base + wall_h, SHEET, Vector3(0, 0, -1))
	wall(pk, kit, "iron", Vector3(x0, 0, z - hw), Vector3(x0, 0, z + hw), y_base, y_base + wall_h, SHEET, Vector3(-1, 0, 0))
	# The roof: planes from each eave to a ridge 0.5 above the wall tops; gable at the west end.
	var ridge: float = y_base + wall_h + 0.5
	var pitch: float = 0.5 / hw
	var oh := 0.35
	var ey: float = y_base + wall_h - pitch * oh
	pk.tri(kit, "iron", Vector3(x0, y_base + wall_h, z - hw), Vector3(x0, y_base + wall_h, z + hw), Vector3(x0, ridge, z), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), SHEET, Vector3(-1, 0, 0),
			Vector2(0, y_base + wall_h) * uvk, Vector2(2.0 * hw, y_base + wall_h) * uvk, Vector2(hw, ridge) * uvk)
	roof(pk, kit, "iron", Vector3(x0 - 0.3, ey, z + hw + oh), Vector3(x1, ey, z + hw + oh), Vector3(x1, ridge, z), Vector3(x0 - 0.3, ridge, z), SHEET_GREEN, Vector3(0, 1.0, pitch).normalized())
	roof(pk, kit, "iron", Vector3(x1, ey, z - hw - oh), Vector3(x0 - 0.3, ey, z - hw - oh), Vector3(x0 - 0.3, ridge, z), Vector3(x1, ridge, z), SHEET_GREEN, Vector3(0, 1.0, -pitch).normalized())
	# Windows along both sides, every 3m; a door at the west end with a stair landing.
	var x: float = x0 + 2.5
	while x < x1 - 1.0:
		for sg in [-1.0, 1.0]:
			slit_window(pk, kit, Vector3(x, y_base + 1.45, z + sg * hw), Vector3(0, 0, sg), 1.1, 0.8)
		x += 3.0
	var dc := Vector3(x0, y_base, z)
	box_at(pk, kit, "painted", dc + Vector3(-0.04, 1.0, 0), Basis(), Vector3(0.08, 2.0, 1.0), Color(0.35, 0.37, 0.36))
	blk(pk, kit, "steel", Vector3(x0 - 1.2, y_base - 0.1, z - 0.9), Vector3(x0, y_base, z + 0.9), STEELWORK)
	railing(pk, kit, Vector3(x0 - 1.2, y_base, z - 0.9), Vector3(x0 - 1.2, y_base, z + 0.9), 1.0)
	railing(pk, kit, Vector3(x0 - 1.2, y_base, z - 0.9), Vector3(x0, y_base, z - 0.9), 1.0)
	railing(pk, kit, Vector3(x0 - 1.2, y_base, z + 0.9), Vector3(x0, y_base, z + 0.9), 1.0)
	# A ridge vent along the middle and a dust hood.
	pk.beam(kit, "steel", Vector3(x0 + 3.0, ridge + 0.08, z), Vector3(x1 - 3.0, ridge + 0.08, z), 0.5, 0.28, SHEET_GREEN.darkened(0.3), Vector3(0, 0, 1))


# ======================================================================================
#  The head house
# ======================================================================================

static func head_house(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hx: float = HH_W * 0.5
	var hz: float = HH_D * 0.5
	var pl := 1.5
	var tone := SILO_CONC.lightened(0.02)
	blk(pk, kit, "concrete", Vector3(-hx - 0.25, 0, -hz - 0.25), Vector3(hx + 0.25, pl, hz + 0.25), SILO_CONC.darkened(0.25))
	wall(pk, kit, "concrete", Vector3(-hx, 0, hz), Vector3(hx, 0, hz), pl, HH_H, tone, Vector3(0, 0, 1))
	wall(pk, kit, "concrete", Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz), pl, HH_H, tone, Vector3(0, 0, -1))
	wall(pk, kit, "concrete", Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz), pl, HH_H, tone, Vector3(-1, 0, 0))
	wall(pk, kit, "concrete", Vector3(hx, 0, hz), Vector3(hx, 0, -hz), pl, HH_H, tone, Vector3(1, 0, 0))
	# Pilasters up the corners and the middle of the long faces; courses round the tower every 6.5m.
	for px in [-hx, -2.0, 2.0, hx]:
		for sg in [-1.0, 1.0]:
			blk(pk, kit, "concrete", Vector3(px - 0.35, pl, sg * hz - (0.0 if sg > 0.0 else 0.18)), Vector3(px + 0.35, HH_H - 0.4, sg * hz + (0.18 if sg > 0.0 else 0.0)), tone.darkened(0.06))
	for pz in [-hz, 0.0, hz]:
		for sg in [-1.0, 1.0]:
			blk(pk, kit, "concrete", Vector3(sg * hx - (0.0 if sg > 0.0 else 0.18), pl, pz - 0.35), Vector3(sg * hx + (0.18 if sg > 0.0 else 0.0), HH_H - 0.4, pz + 0.35), tone.darkened(0.06))
	for y in [6.5, 13.0, 19.5]:
		blk(pk, kit, "concrete", Vector3(-hx - 0.14, y, -hz - 0.14), Vector3(hx + 0.14, y + 0.4, hz + 0.14), tone.darkened(0.1))
	# Slit windows: two columns on each long face at four levels, one column on the short faces.
	for y in [4.2, 9.8, 16.2, 22.6]:
		for px in [-3.5, 3.5]:
			slit_window(pk, kit, Vector3(px, y, hz), Vector3(0, 0, 1), 1.2, 2.3)
			slit_window(pk, kit, Vector3(px, y, -hz), Vector3(0, 0, -1), 1.2, 2.3)
		slit_window(pk, kit, Vector3(hx, y, 0), Vector3(1, 0, 0), 1.2, 2.3)
		if y > 5.0:
			slit_window(pk, kit, Vector3(-hx, y, 3.0), Vector3(-1, 0, 0), 1.2, 2.3)
	# The big sign across the front: a dark green board, cream letters.
	box_at(pk, kit, "paint", Vector3(0, 19.2, hz + 0.18), Basis(), Vector3(10.4, 2.1, 0.12), Color(0.10, 0.27, 0.19))
	box_at(pk, kit, "paint", Vector3(0, 19.2, hz + 0.22), Basis(), Vector3(10.1, 1.8, 0.06), Color(0.82, 0.74, 0.50))
	box_at(pk, kit, "paint", Vector3(0, 19.2, hz + 0.26), Basis(), Vector3(9.9, 1.6, 0.04), Color(0.10, 0.27, 0.19))
	labels.append(["COOPERATIVA GRANERA", Vector3(0, 19.2, hz + 0.3), Vector3(0, 0, 1), 0.85, Color(0.95, 0.90, 0.72)])
	# The loading door at the foot of the front (for sacks): a roller door under a lintel.
	sliding_door(pk, kit, Vector3(-3.5, pl, hz), Vector3(0, 0, 1), 3.2, 3.6, Color(0.5, 0.52, 0.5))
	door(pk, kit, Vector3(3.2, pl, hz), Vector3(0, 0, 1), 1.6, 2.6, true)
	# The roof deck and parapet.
	blk(pk, kit, "concrete", Vector3(-hx - 0.3, HH_H, -hz - 0.3), Vector3(hx + 0.3, HH_H + 0.4, hz + 0.3), tone.darkened(0.1))
	blk(pk, kit, "concrete", Vector3(-hx - 0.3, HH_H + 0.4, hz - 0.1), Vector3(hx + 0.3, HH_H + 1.1, hz + 0.3), tone.darkened(0.04))
	blk(pk, kit, "concrete", Vector3(-hx - 0.3, HH_H + 0.4, -hz - 0.3), Vector3(hx + 0.3, HH_H + 1.1, -hz + 0.1), tone.darkened(0.04))
	blk(pk, kit, "concrete", Vector3(-hx - 0.3, HH_H + 0.4, -hz + 0.1), Vector3(-hx - 0.0 + 0.1, HH_H + 1.1, hz - 0.1), tone.darkened(0.04))
	blk(pk, kit, "concrete", Vector3(hx - 0.1, HH_H + 0.4, -hz + 0.1), Vector3(hx + 0.3, HH_H + 1.1, hz - 0.1), tone.darkened(0.04))
	# The penthouse: sheet walls with windows and louvres, a pitched roof overhanging them, a hoist beam out of its front.
	var px0 := -4.5
	var px1 := 4.5
	var pz0 := -3.5
	var pz1 := 3.5
	var py0: float = HH_H + 0.4
	var py1: float = py0 + 4.4
	wall(pk, kit, "iron", Vector3(px0, 0, pz1), Vector3(px1, 0, pz1), py0, py1, SHEET, Vector3(0, 0, 1))
	wall(pk, kit, "iron", Vector3(px1, 0, pz0), Vector3(px0, 0, pz0), py0, py1, SHEET, Vector3(0, 0, -1))
	wall(pk, kit, "iron", Vector3(px0, 0, pz0), Vector3(px0, 0, pz1), py0, py1, SHEET, Vector3(-1, 0, 0))
	wall(pk, kit, "iron", Vector3(px1, 0, pz1), Vector3(px1, 0, pz0), py0, py1, SHEET, Vector3(1, 0, 0))
	for wx in [-2.8, -0.9, 0.9, 2.8]:
		slit_window(pk, kit, Vector3(wx, py0 + 2.3, pz1), Vector3(0, 0, 1), 1.0, 1.0)
		slit_window(pk, kit, Vector3(wx, py0 + 2.3, pz0), Vector3(0, 0, -1), 1.0, 1.0)
	var pitch := 0.32
	var ridge: float = py1 + pitch * (pz1 + 0.0)
	var oh := 0.6
	var ey: float = py1 - pitch * oh
	pk.tri(kit, "iron", Vector3(px0, py1, pz0), Vector3(px0, py1, pz1), Vector3(px0, ridge, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), SHEET, Vector3(-1, 0, 0),
			Vector2(0, py1) * uvk, Vector2(7.0, py1) * uvk, Vector2(3.5, ridge) * uvk)
	pk.tri(kit, "iron", Vector3(px1, py1, pz1), Vector3(px1, py1, pz0), Vector3(px1, ridge, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), SHEET, Vector3(1, 0, 0),
			Vector2(0, py1) * uvk, Vector2(7.0, py1) * uvk, Vector2(3.5, ridge) * uvk)
	roof(pk, kit, "iron", Vector3(px0 - 0.5, ey, pz1 + oh), Vector3(px1 + 0.5, ey, pz1 + oh), Vector3(px1 + 0.5, ridge, 0), Vector3(px0 - 0.5, ridge, 0), SHEET_GREEN, Vector3(0, 1.0, pitch).normalized())
	roof(pk, kit, "iron", Vector3(px1 + 0.5, ey, pz0 - oh), Vector3(px0 - 0.5, ey, pz0 - oh), Vector3(px0 - 0.5, ridge, 0), Vector3(px1 + 0.5, ridge, 0), SHEET_GREEN, Vector3(0, 1.0, -pitch).normalized())
	pk.beam(kit, "steel", Vector3(px0 - 0.6, ridge + 0.06, 0), Vector3(px1 + 0.6, ridge + 0.06, 0), 0.5, 0.24, SHEET_GREEN.darkened(0.3), Vector3(0, 0, 1))
	# Beacon mast and aviation lamp on the ridge.
	pk.tube(kit, "steel", Vector3(0, ridge + 0.1, 0), Vector3(0, ridge + 3.2, 0), 0.09, 0.05, 8, STEELWORK, true)
	pk.lathe(kit, "lamp", Vector3(0, ridge + 3.2, 0), [Vector2(0.001, 0.0), Vector2(0.22, 0.05), Vector2(0.22, 0.25), Vector2(0.001, 0.34)], 10, Color(1.0, 0.18, 0.12), false)
	# The bucket elevator's duct up the back: a galvanised box with seams and a rounded cap, tied to the wall.
	var ex0 := -1.1
	var ex1 := 1.1
	var ez0: float = -hz - 2.0
	var ez1: float = -hz
	var eh: float = HH_H + 4.0
	blk(pk, kit, "steel", Vector3(ex0, 0, ez0), Vector3(ex1, eh, ez1), Color(0.60, 0.62, 0.62))
	for y in range(1, int(eh / 3.0) + 1):
		blk(pk, kit, "steel", Vector3(ex0 - 0.07, float(y) * 3.0 - 0.1, ez0 - 0.07), Vector3(ex1 + 0.07, float(y) * 3.0 + 0.1, ez1), Color(0.50, 0.52, 0.52))
	pk.beam(kit, "steel", Vector3(-1.6, 8.0, ez1), Vector3(-1.6, 8.0, ez0 - 0.0), 0.1, 0.1, STEELWORK)
	for y in [8.0, 17.0, 26.0]:
		pk.beam(kit, "steel", Vector3(ex0 - 0.2, y, ez1), Vector3(ex1 + 0.2, y, ez1), 0.18, 0.18, STEELWORK)
		pk.beam(kit, "steel", Vector3(ex0 - 0.2, y, ez0), Vector3(ex0 - 0.2, y, ez1), 0.16, 0.16, STEELWORK)
		pk.beam(kit, "steel", Vector3(ex1 + 0.2, y, ez0), Vector3(ex1 + 0.2, y, ez1), 0.16, 0.16, STEELWORK)
	pk.lathe(kit, "steel", Vector3(0, eh, (ez0 + ez1) * 0.5), [Vector2(1.3, 0.0), Vector2(1.3, 0.3), Vector2(0.9, 0.75), Vector2(0.001, 1.1)], 12, Color(0.60, 0.62, 0.62), false)
	ladder(pk, kit, Vector3(ex1 + 0.0, 1.5, ez0 + 1.0), Vector3(ex1 + 0.0, HH_H + 1.1, ez0 + 1.0), Vector3(1, 0, 0), true)


# ======================================================================================
#  The loadout
# ======================================================================================

## The loadout over the factory track: a gallery out of the head house's front on a trestle into the bin of a steel portal
## gantry (four legs, two portals joined by beams, a bin with a funnel and a telescopic spout), with a ladder, rails on
## the bin's roof and a hut. The gantry stands on both sides of the track (z = TRACK_Z), 4.4 either side.
static func loadout(pk: PropKit, kit: Dictionary) -> void:
	var zt := TRACK_Z
	var zn: float = zt - 4.4
	var zs: float = zt + 4.4
	var gx := 3.2
	# Legs, the portals' crossbeams on them, the beams along.
	for sx in [-gx, gx]:
		for z in [zn, zs]:
			column(pk, kit, Vector3(sx, 0, z), 0.0, GY, 0.5, STEELWORK)
		girder(pk, kit, Vector3(sx, GY + 0.8, zn - 0.6), Vector3(sx, GY + 0.8, zs + 0.6), 0.8, 0.3, STEELWORK.darkened(0.05))
		# Knee braces at each leg top, in the portal's plane.
		pk.beam(kit, "steel", Vector3(sx, GY - 1.6, zn), Vector3(sx, GY, zn + 1.6), 0.14, 0.14, STEELWORK)
		pk.beam(kit, "steel", Vector3(sx, GY - 1.6, zs), Vector3(sx, GY, zs - 1.6), 0.14, 0.14, STEELWORK)
	for z in [zn, zs]:
		girder(pk, kit, Vector3(-gx - 0.6, GY + 0.5, z), Vector3(gx + 0.6, GY + 0.5, z), 0.5, 0.25, STEELWORK.darkened(0.05))
		# X bracing between the two legs on the same side (the opening between the portals' legs stays clear).
		pk.beam(kit, "steel", Vector3(-gx, 0.8, z), Vector3(gx, GY - 1.2, z), 0.12, 0.12, STEELWORK)
		pk.beam(kit, "steel", Vector3(gx, 0.8, z), Vector3(-gx, GY - 1.2, z), 0.12, 0.12, STEELWORK)
	for z in [zt - 2.6, zt + 2.6]:
		girder(pk, kit, Vector3(-gx, GY + 0.5, z), Vector3(gx, GY + 0.5, z), 0.5, 0.25, STEELWORK)
	# The bin: sheet box on the beams, a funnel down through the opening, the spout.
	var bin_y0: float = GY + 0.5
	var bin_y1: float = GY + 4.2
	var bx := 2.6
	var bz := 2.8
	wall(pk, kit, "iron", Vector3(-bx, 0, zt + bz), Vector3(bx, 0, zt + bz), bin_y0, bin_y1, SHEET, Vector3(0, 0, 1))
	wall(pk, kit, "iron", Vector3(bx, 0, zt - bz), Vector3(-bx, 0, zt - bz), bin_y0, bin_y1, SHEET, Vector3(0, 0, -1))
	wall(pk, kit, "iron", Vector3(-bx, 0, zt - bz), Vector3(-bx, 0, zt + bz), bin_y0, bin_y1, SHEET, Vector3(-1, 0, 0))
	wall(pk, kit, "iron", Vector3(bx, 0, zt + bz), Vector3(bx, 0, zt - bz), bin_y0, bin_y1, SHEET, Vector3(1, 0, 0))
	frustum(pk, kit, "steel", 0.0, zt, bin_y0, bx, bz, GY - 2.2, 0.45, 0.45, Color(0.45, 0.48, 0.48))
	# Bin roof: a flat sheet with a hatch, a rail round it and a stiffening band.
	blk(pk, kit, "steel", Vector3(-bx - 0.15, bin_y1, zt - bz - 0.15), Vector3(bx + 0.15, bin_y1 + 0.18, zt + bz + 0.15), STEELWORK)
	blk(pk, kit, "steel", Vector3(-0.6, bin_y1 + 0.18, zt - 0.6), Vector3(0.6, bin_y1 + 0.7, zt + 0.6), Color(0.5, 0.52, 0.52))
	var rt: float = bin_y1 + 0.18
	railing(pk, kit, Vector3(-bx, rt, zt - bz), Vector3(bx, rt, zt - bz), 1.0)
	railing(pk, kit, Vector3(bx, rt, zt - bz), Vector3(bx, rt, zt + bz), 1.0)
	railing(pk, kit, Vector3(bx, rt, zt + bz), Vector3(-bx, rt, zt + bz), 1.0)
	railing(pk, kit, Vector3(-bx, rt, zt + bz), Vector3(-bx, rt, zt - bz), 1.0)
	for k in range(3):
		var bf: float = bin_y0 + 1.0 + float(k) * 1.2
		blk(pk, kit, "steel", Vector3(-bx - 0.06, bf, zt - bz - 0.06), Vector3(bx + 0.06, bf + 0.12, zt + bz + 0.06), STEELWORK.lightened(0.05))
	# The spout: three telescoping sections with collars, a trimmer at the foot, a chain.
	var sy0: float = GY - 2.2
	var sy1 := 5.6
	var seg: float = (sy0 - sy1) / 3.0
	for k in range(3):
		var ya: float = sy0 - seg * float(k)
		var yb: float = ya - seg
		var ra: float = 0.46 - 0.07 * float(k)
		pk.tube(kit, "steel", Vector3(0, yb, zt), Vector3(0, ya, zt), ra - 0.05, ra, 12, Color(0.55, 0.57, 0.57), false)
		pk.tube(kit, "steel", Vector3(0, ya - 0.14, zt), Vector3(0, ya + 0.04, zt), ra + 0.05, ra + 0.05, 12, STEELWORK, false)
	pk.tube(kit, "steel", Vector3(0, sy1 - 0.02, zt), Vector3(0, sy1 + 0.1, zt), 0.3, 0.3, 12, SAFETY_YELLOW, false)
	pk.beam(kit, "steel", Vector3(0.0, sy1 + 0.1, zt), Vector3(0.0, sy1 - 0.5, zt + 0.55), 0.5, 0.06, STEELWORK, Vector3(1, 0, 0))
	pk.beam(kit, "steel", Vector3(0.3, GY - 2.0, zt + 0.5), Vector3(0.3, sy1 + 0.5, zt + 0.5), 0.04, 0.04, STEELWORK)
	# The gallery from the head house's front (z = hz) to the bin's north wall: floor on a trestle.
	var hz: float = HH_D * 0.5
	var gal_y: float = GY + 2.2
	var gal_w := 1.0
	var gal_z0: float = hz
	var gal_z1: float = zt - bz
	blk(pk, kit, "steel", Vector3(-gal_w - 0.15, gal_y - 0.3, gal_z0), Vector3(gal_w + 0.15, gal_y, gal_z1), STEELWORK)
	wall(pk, kit, "iron", Vector3(gal_w + 0.15, 0, gal_z0), Vector3(gal_w + 0.15, 0, gal_z1), gal_y, gal_y + 1.9, SHEET, Vector3(1, 0, 0))
	wall(pk, kit, "iron", Vector3(-gal_w - 0.15, 0, gal_z1), Vector3(-gal_w - 0.15, 0, gal_z0), gal_y, gal_y + 1.9, SHEET, Vector3(-1, 0, 0))
	blk(pk, kit, "steel", Vector3(-gal_w - 0.3, gal_y + 1.9, gal_z0), Vector3(gal_w + 0.3, gal_y + 2.1, gal_z1), SHEET_GREEN)
	for zz in [gal_z0 + 1.4, gal_z1 - 1.4]:
		for sg in [-1.0, 1.0]:
			slit_window(pk, kit, Vector3(sg * (gal_w + 0.15), gal_y + 1.1, zz), Vector3(sg, 0, 0), 0.8, 0.7)
	# The trestle: two posts at mid-run, cut to the floor's underside, with a cross girder.
	var tz: float = (gal_z0 + gal_z1) * 0.5
	for sx in [-gal_w, gal_w]:
		column(pk, kit, Vector3(sx, 0, tz), 0.0, gal_y - 0.3, 0.4, STEELWORK)
	girder(pk, kit, Vector3(-gal_w - 0.6, gal_y - 0.3, tz), Vector3(gal_w + 0.6, gal_y - 0.3, tz), 0.4, 0.25, STEELWORK)
	pk.beam(kit, "steel", Vector3(-gal_w, 0.8, tz), Vector3(gal_w, gal_y - 0.9, tz), 0.1, 0.1, STEELWORK)
	pk.beam(kit, "steel", Vector3(gal_w, 0.8, tz), Vector3(-gal_w, gal_y - 0.9, tz), 0.1, 0.1, STEELWORK)
	# The ladder up the north-west leg to the beams and on to the bin roof, with its cage.
	ladder(pk, kit, Vector3(-gx - 0.5, 0.0, zn), Vector3(-gx - 0.5, GY + 0.9, zn), Vector3(-1, 0, 0), true)
	# A platform on the south side of the bin with a rail (for the man at the spout).
	blk(pk, kit, "steel", Vector3(-bx, GY + 0.5, zt + bz), Vector3(bx, GY + 0.62, zt + bz + 1.0), STEELWORK)
	railing(pk, kit, Vector3(-bx, GY + 0.62, zt + bz + 1.0), Vector3(bx, GY + 0.62, zt + bz + 1.0), 1.0)
	railing(pk, kit, Vector3(bx, GY + 0.62, zt + bz), Vector3(bx, GY + 0.62, zt + bz + 1.0), 1.0)
	railing(pk, kit, Vector3(-bx, GY + 0.62, zt + bz), Vector3(-bx, GY + 0.62, zt + bz + 1.0), 1.0)
	# The columns that hold the platform: two posts cut to its underside.
	for sx in [-bx + 0.2, bx - 0.2]:
		column(pk, kit, Vector3(sx, 0, zt + bz + 0.8), 0.0, GY + 0.5, 0.3, STEELWORK)


# ======================================================================================
#  The warehouse
# ======================================================================================

## The warehouse: x in [x0, x1], z in [z0, z1] with the dock on its +z side (toward the track). A concrete base course,
## corrugated sheet above, a pitched iron roof with ventilators, four roller doors on a raised dock under a canopy,
## a clerestory of windows on the back, a sign on the east gable.
static func warehouse(pk: PropKit, kit: Dictionary, x0: float, x1: float, z0: float, z1: float, labels: Array) -> void:
	var wall_h := 6.5
	var base_h := 1.4
	var pitch := 0.28
	var zm: float = (z0 + z1) * 0.5
	var ridge: float = wall_h + pitch * (z1 - z0) * 0.5
	var tone := Color(0.66, 0.62, 0.52)
	blk(pk, kit, "concrete", Vector3(x0 - 0.15, 0, z0 - 0.15), Vector3(x1 + 0.15, 0.4, z1 + 0.15), CONCRETE.darkened(0.1))
	# Base course (concrete) and sheet walls.
	for side in [[Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(0, 0, 1)], [Vector3(x1, 0, z0), Vector3(x0, 0, z0), Vector3(0, 0, -1)],
			[Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(-1, 0, 0)], [Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(1, 0, 0)]]:
		wall(pk, kit, "concrete", side[0], side[1], 0.4, base_h, CONCRETE.darkened(0.04), side[2])
		wall(pk, kit, "iron", side[0], side[1], base_h, wall_h, tone, side[2])
	# Gable ends of sheet.
	pk.tri(kit, "iron", Vector3(x0, wall_h, z0), Vector3(x0, wall_h, z1), Vector3(x0, ridge, zm), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), tone, Vector3(-1, 0, 0),
			Vector2(0, wall_h) * uvk, Vector2(z1 - z0, wall_h) * uvk, Vector2((z1 - z0) * 0.5, ridge) * uvk)
	pk.tri(kit, "iron", Vector3(x1, wall_h, z1), Vector3(x1, wall_h, z0), Vector3(x1, ridge, zm), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), tone, Vector3(1, 0, 0),
			Vector2(0, wall_h) * uvk, Vector2(z1 - z0, wall_h) * uvk, Vector2((z1 - z0) * 0.5, ridge) * uvk)
	# Corner and bay posts (the building frame showing through as lighter strips).
	var x: float = x0
	while x <= x1 + 0.01:
		for zz in [z0, z1]:
			var sg: float = 1.0 if zz == z1 else -1.0
			blk(pk, kit, "steel", Vector3(x - 0.17, base_h, zz - (0.0 if sg > 0.0 else 0.09)), Vector3(x + 0.17, wall_h, zz + (0.09 if sg > 0.0 else 0.0)), STEELWORK.lightened(0.12))
		x += 5.0
	# Roof.
	var oh := 0.7
	var ey: float = wall_h - pitch * oh
	var roof_col := Color(0.55, 0.57, 0.55)
	roof(pk, kit, "iron", Vector3(x0 - 0.7, ey, z1 + oh), Vector3(x1 + 0.7, ey, z1 + oh), Vector3(x1 + 0.7, ridge, zm), Vector3(x0 - 0.7, ridge, zm), roof_col, Vector3(0, 1.0, pitch).normalized())
	roof(pk, kit, "iron", Vector3(x1 + 0.7, ey, z0 - oh), Vector3(x0 - 0.7, ey, z0 - oh), Vector3(x0 - 0.7, ridge, zm), Vector3(x1 + 0.7, ridge, zm), roof_col, Vector3(0, 1.0, -pitch).normalized())
	pk.beam(kit, "steel", Vector3(x0 - 0.8, ridge + 0.06, zm), Vector3(x1 + 0.8, ridge + 0.06, zm), 0.55, 0.24, roof_col.darkened(0.3), Vector3(0, 0, 1))
	for zz in [z1 + oh, z0 - oh]:
		pk.beam(kit, "steel", Vector3(x0 - 0.8, ey - 0.04, zz), Vector3(x1 + 0.8, ey - 0.04, zz), 0.12, 0.3, STEELWORK, Vector3(0, 0, 1))
	# Wind-driven ventilators on the ridge: a drum with fins and a cap, their feet in the roof.
	var vx: float = x0 + 6.0
	while vx < x1 - 4.0:
		pk.tube(kit, "steel", Vector3(vx, ridge - 0.5, zm), Vector3(vx, ridge + 1.0, zm), 0.42, 0.42, 14, Color(0.72, 0.73, 0.72), false)
		for f in range(8):
			var a: float = TAU * float(f) / 8.0
			pk.beam(kit, "steel", Vector3(vx, ridge + 0.2, zm) + Vector3(cos(a) * 0.42, 0, sin(a) * 0.42), Vector3(vx, ridge + 0.9, zm) + Vector3(cos(a) * 0.5, 0, sin(a) * 0.5), 0.06, 0.1, Color(0.62, 0.63, 0.62), Vector3(-sin(a), 0, cos(a)))
		pk.lathe(kit, "steel", Vector3(vx, ridge + 1.0, zm), [Vector2(0.55, 0.0), Vector2(0.4, 0.18), Vector2(0.001, 0.32)], 14, Color(0.62, 0.63, 0.62), false)
		vx += 7.0
	# The dock: a raised concrete slab along the front with bumpers, a stair at each end, a yellow edge.
	var dz: float = z1 + 3.2
	blk(pk, kit, "concrete", Vector3(x0 - 0.2, 0, z1), Vector3(x1 + 0.2, DOCK_H, dz), CONCRETE.darkened(0.06))
	pk.quad(kit, "paint", [Vector3(x0 - 0.2, DOCK_H + 0.012, dz - 0.5), Vector3(x1 + 0.2, DOCK_H + 0.012, dz - 0.5), Vector3(x1 + 0.2, DOCK_H + 0.012, dz - 0.34), Vector3(x0 - 0.2, DOCK_H + 0.012, dz - 0.34)],
			Vector3.UP, SAFETY_YELLOW)
	var bxp: float = x0 + 2.0
	while bxp < x1:
		blk(pk, kit, "matte", Vector3(bxp - 0.3, 0.2, dz), Vector3(bxp + 0.3, 0.7, dz + 0.14), Color(0.07, 0.07, 0.08))
		bxp += 5.0
	for sx in [x0 - 2.4, x1 + 0.2]:
		for k in range(4):
			blk(pk, kit, "concrete", Vector3(sx, 0, z1 + 0.5), Vector3(sx + 2.2 - 0.5 * float(k), DOCK_H - 0.3 * float(k), z1 + 2.6), CONCRETE.darkened(0.04))
	# Four roller doors with a hood and a light over each.
	for k in range(4):
		var dx: float = x0 + 6.0 + 10.0 * float(k)
		sliding_door(pk, kit, Vector3(dx, DOCK_H, z1), Vector3(0, 0, 1), 3.6, 4.0, Color(0.20, 0.34, 0.28))
		floodlight(pk, kit, Vector3(dx, DOCK_H + 5.0, z1 + 0.3), Vector3(0, 0, 1))
		# Numbers over the doors.
		box_at(pk, kit, "paint", Vector3(dx, DOCK_H + 4.9, z1 + 0.06), Basis(), Vector3(0.6, 0.6, 0.04), SAFETY_YELLOW)
	# The canopy over the dock: its roof rests on the girder on posts standing on the dock slab.
	canopy(pk, kit, x0 + 0.5, x1 - 0.5, z1, wall_h - 0.8, 3.6, 0.45, 1.0, DOCK_H)
	# The back: clerestory windows and two man doors.
	var wx: float = x0 + 3.0
	while wx < x1 - 2.0:
		slit_window(pk, kit, Vector3(wx, 4.6, z0), Vector3(0, 0, -1), 1.6, 0.9)
		wx += 5.0
	door(pk, kit, Vector3(x0 + 12.0, 0.4, z0), Vector3(0, 0, -1), 1.6, 2.6, true)
	door(pk, kit, Vector3(x1 - 12.0, 0.4, z0), Vector3(0, 0, -1), 1.6, 2.6, true)
	# The sign on the east gable.
	box_at(pk, kit, "paint", Vector3(x1 + 0.1, 5.4, zm), Basis(Vector3.UP, PI * 0.5), Vector3(6.4, 1.3, 0.1), Color(0.10, 0.27, 0.19))
	labels.append(["ALMACEN", Vector3(x1 + 0.17, 5.4, zm), Vector3(1, 0, 0), 0.7, Color(0.95, 0.90, 0.72)])
	# Pallets of sacks on the dock.
	for k in range(5):
		sack_stack(pk, kit, Vector3(x0 + 3.0 + 7.6 * float(k), DOCK_H, z1 + 1.6), 0.1 * float(k), 3 + (k % 3))


# ======================================================================================
#  The control hut and the whole complex
# ======================================================================================

## A small hut by the track: plaster walls, an iron roof, a door and two windows, a stove pipe, a sign.
static func hut(pk: PropKit, kit: Dictionary, x0: float, x1: float, z0: float, z1: float, labels: Array) -> void:
	var wall_h := 3.7
	var pitch := 0.3
	var zm: float = (z0 + z1) * 0.5
	var ridge: float = wall_h + pitch * (z1 - z0) * 0.5
	var col := Color(0.88, 0.82, 0.66)
	blk(pk, kit, "concrete", Vector3(x0 - 0.1, 0, z0 - 0.1), Vector3(x1 + 0.1, 0.35, z1 + 0.1), SILO_CONC.darkened(0.2))
	wall(pk, kit, "plaster", Vector3(x0, 0, z1), Vector3(x1, 0, z1), 0.35, wall_h, col, Vector3(0, 0, 1))
	wall(pk, kit, "plaster", Vector3(x1, 0, z0), Vector3(x0, 0, z0), 0.35, wall_h, col, Vector3(0, 0, -1))
	wall(pk, kit, "plaster", Vector3(x0, 0, z0), Vector3(x0, 0, z1), 0.35, wall_h, col, Vector3(-1, 0, 0))
	wall(pk, kit, "plaster", Vector3(x1, 0, z1), Vector3(x1, 0, z0), 0.35, wall_h, col, Vector3(1, 0, 0))
	gable(pk, kit, "plaster", Vector3(x0, wall_h, z0), Vector3(x0, wall_h, z1), Vector3(x0, ridge, zm), col, Vector3(-1, 0, 0))
	gable(pk, kit, "plaster", Vector3(x1, wall_h, z1), Vector3(x1, wall_h, z0), Vector3(x1, ridge, zm), col, Vector3(1, 0, 0))
	var oh := 0.5
	var ey: float = wall_h - pitch * oh
	roof(pk, kit, "iron", Vector3(x0 - 0.5, ey, z1 + oh), Vector3(x1 + 0.5, ey, z1 + oh), Vector3(x1 + 0.5, ridge, zm), Vector3(x0 - 0.5, ridge, zm), SHEET_GREEN, Vector3(0, 1.0, pitch).normalized())
	roof(pk, kit, "iron", Vector3(x1 + 0.5, ey, z0 - oh), Vector3(x0 - 0.5, ey, z0 - oh), Vector3(x0 - 0.5, ridge, zm), Vector3(x1 + 0.5, ridge, zm), SHEET_GREEN, Vector3(0, 1.0, -pitch).normalized())
	pk.beam(kit, "steel", Vector3(x0 - 0.6, ridge + 0.05, zm), Vector3(x1 + 0.6, ridge + 0.05, zm), 0.4, 0.2, SHEET_GREEN.darkened(0.3), Vector3(0, 0, 1))
	door(pk, kit, Vector3(x0 + 1.2, 0.35, z1), Vector3(0, 0, 1), 0.9, 2.1, true)
	window(pk, kit, Vector3((x0 + x1) * 0.5 + 0.4, 1.9, z1), Vector3(0, 0, 1), 1.2, 1.1, Color(0, 0, 0, 0))
	window(pk, kit, Vector3(x1 - 1.2, 1.9, z1), Vector3(0, 0, 1), 1.0, 1.1, Color(0, 0, 0, 0))
	window(pk, kit, Vector3(x1, 1.9, zm), Vector3(1, 0, 0), 1.0, 1.1, Color(0, 0, 0, 0))
	pk.tube(kit, "steel", Vector3(x0 + 1.0, ridge - 1.2, z0 + 0.8), Vector3(x0 + 1.0, ridge + 1.0, z0 + 0.8), 0.13, 0.13, 8, STEELWORK, true)
	box_at(pk, kit, "paint", Vector3((x0 + x1) * 0.5 + 0.4, wall_h - 0.32, z1 + 0.06), Basis(), Vector3(2.6, 0.42, 0.06), Color(0.10, 0.27, 0.19))
	labels.append(["BASCULA", Vector3((x0 + x1) * 0.5 + 0.4, wall_h - 0.32, z1 + 0.1), Vector3(0, 0, 1), 0.26, Color(0.95, 0.90, 0.72)])


## The whole complex in its frame.
static func factory(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	for k in range(SILO_X.size()):
		var x: float = SILO_X[k]
		silo(pk, kit, Vector3(x, 0, 0), SILO_R, SILO_H, 0.02 * float(k % 3), k == 1 or k == 3, Vector3(0, 0, 1))
		silo(pk, kit, Vector3(x, 0, -2.0 * SILO_R), SILO_R, SILO_H, 0.03 * float((k + 1) % 3), k == 2, Vector3(0, 0, -1))
	top_gallery(pk, kit)
	head_house(pk, kit, labels)
	loadout(pk, kit)
	warehouse(pk, kit, WH_X0, WH_X1, WH_Z0, WH_Z1, labels)
	hut(pk, kit, 8.0, 12.2, 7.4, 10.4, labels)
	# Two tanks beyond the silos with a pipe rack between them and the track.
	tank(pk, kit, Vector3(-50.0, 0, 5.5), 3.2, 10.0, Color(0.80, 0.77, 0.68))
	tank(pk, kit, Vector3(-50.0, 0, -3.0), 3.2, 10.0, Color(0.52, 0.64, 0.58))
	# Light masts at each end of the track side.
	light_mast(pk, kit, Vector3(-3.0, 0, 11.0), 14.0, Vector3(0, 0, 1))
	light_mast(pk, kit, Vector3(-56.0, 0, 11.5), 13.0, Vector3(0, 0, 1))
	# A heap of grain by the head house with a drag conveyor, drums and a few pallets about.
	pk.lathe(kit, "matte", Vector3(7.5, 0, -1.5), [Vector2(2.4, 0.0), Vector2(1.7, 0.5), Vector2(0.9, 1.1), Vector2(0.001, 1.6)], 14, GRAIN, false)
	for k in range(4):
		drum(pk, kit, Vector3(-56.0 + 0.8 * float(k), 0, 2.4), Color(0.18, 0.28, 0.42) if k % 2 == 0 else Color(0.55, 0.2, 0.14))
	sack_stack(pk, kit, Vector3(-4.0, 0, 8.4), 0.3, 4)
	sack_stack(pk, kit, Vector3(-5.2, 0, 8.6), 0.0, 3, Color(0.78, 0.7, 0.5))
