# InfernoBuilder.gd
#
# The Inferno: a dune supercar, a mid-engined sports car's body on balloon sand tyres. Tall round
# front fenders stand either side of a sunken bonnet with a black extractor panel, three round lamps
# a side under their brows, a black jaw and a silver splitter below. The cockpit is open behind a
# wraparound visor, its black roof frame carried back on painted buttresses to the rear haunches. A
# scoop is carved into each flank ahead of the rear wheel, the arches wear black flares, and the
# engine deck between the haunches is louvred, over round tail lamps and a diffuser. Star rims of
# five faceted arms, the running gear seen through the open arches.
#
# The section (section(), overridden) carries the wheel wells like the Apex's: below the side, the
# shell steps in to the well's inner wall and up under the arch. The side carries the flank scoop
# (_scoop()): a recess deepening toward the rear wheel that ends in a wall facing forward. Above the
# side, keyed along the car (KEYS): a roll over the side's top edge onto the fender top, which falls
# inward to the recess's edge A, then a wall down and a fillet onto the floor. That floor is the
# bonnet's sunken panel between the fenders, the dash under the visor, the cockpit floor between the
# doors and the engine deck between the haunches.
#
# The visor is its own panel. car_body.gdshader only draws glass through the body's detail map, so
# the visor samples a patch of the map kept glass on the flat bottom under the cockpit (GLASS_Z),
# where nobody looks.
extends "res://CarDesign.gd"

# Wheels: balloon tyres 0.54 across, on a wide track.
const WHEEL_X := 0.560
const AXLE_F := -0.700
const AXLE_R := 0.680
const HUB_Y := 0.270

# The side (w) and the bottom (bot) along the car: widest over the wheels, pinched at the doors.
const W_KNOTS := [[-1.070, 0.330], [-1.030, 0.420], [-0.970, 0.485], [-0.880, 0.525], [-0.780, 0.548],
	[-0.700, 0.555], [-0.600, 0.550], [-0.500, 0.530], [-0.400, 0.500], [-0.300, 0.478], [-0.150, 0.468],
	[0.050, 0.472], [0.200, 0.500], [0.380, 0.540], [0.540, 0.565], [0.680, 0.570], [0.840, 0.562],
	[0.960, 0.540], [1.030, 0.510], [1.065, 0.490]]
const BOT_KNOTS := [[-1.070, 0.345], [-1.020, 0.320], [-0.950, 0.295], [-0.850, 0.280], [-0.400, 0.275],
	[0.300, 0.275], [0.800, 0.290], [0.950, 0.315], [1.065, 0.345]]

# The section above the side, keyframed along the car. Per row: z; belt (the top of the vertical
# side); rr (the roll over its top edge: the fender's crest is at belt + rr); ax (A, the fender top's
# inner edge, where the wall goes down); adrop (how far A lies below the crest: the fender top falls
# inward); edge (the floor's height); crown (> 0 domes the floor).
# The bonnet's panel narrows to a groove at the nose; the dash under the visor is a shallow step; the
# cockpit floor drops 22cm below the doors' tops; the engine deck sits a little below the haunches.
const KEYS := [
	# z       belt   rr     ax     adrop  edge   crown
	[-1.070, 0.410, 0.030, 0.020, 0.018, 0.412, 0.000],
	[-1.030, 0.445, 0.040, 0.030, 0.030, 0.447, 0.000],
	[-0.970, 0.490, 0.050, 0.045, 0.042, 0.490, 0.000],
	[-0.880, 0.560, 0.055, 0.080, 0.055, 0.545, 0.000],
	[-0.790, 0.592, 0.058, 0.130, 0.068, 0.555, 0.000],
	[-0.700, 0.600, 0.060, 0.190, 0.070, 0.556, 0.000],
	[-0.600, 0.596, 0.058, 0.245, 0.068, 0.553, 0.000],
	[-0.500, 0.574, 0.054, 0.290, 0.060, 0.548, 0.000],
	[-0.430, 0.553, 0.050, 0.320, 0.050, 0.540, 0.000],
	[-0.370, 0.535, 0.045, 0.345, 0.033, 0.537, 0.000],
	[-0.310, 0.512, 0.038, 0.380, 0.012, 0.528, 0.000],
	[-0.280, 0.500, 0.036, 0.392, 0.008, 0.315, 0.000],
	[0.070, 0.500, 0.036, 0.398, 0.008, 0.315, 0.000],
	[0.120, 0.512, 0.038, 0.392, 0.010, 0.325, 0.000],
	[0.165, 0.535, 0.042, 0.360, 0.012, 0.552, 0.002],
	[0.300, 0.565, 0.050, 0.330, 0.025, 0.575, 0.003],
	[0.500, 0.590, 0.058, 0.310, 0.035, 0.595, 0.004],
	[0.680, 0.602, 0.060, 0.300, 0.040, 0.603, 0.004],
	[0.860, 0.598, 0.056, 0.290, 0.038, 0.600, 0.004],
	[0.980, 0.590, 0.050, 0.280, 0.032, 0.596, 0.003],
	[1.065, 0.580, 0.045, 0.270, 0.025, 0.590, 0.000],
]
const KEY_NAMES := ["belt", "rr", "ax", "adrop", "edge", "crown"]
const EDGE_R := 0.008                     # the rounding over A
const FILLET_R := 0.012                   # the fillet at the wall's foot
const WALL_LEAN := 0.004                  # the wall's foot stands this far inboard of A

# The wheel wells: per axle, its z, the arch's half-length, its base and rise (a superellipse of
# exponent e), and the well's inner wall. The front tyres at full lock (0.5 rad) sweep in to x 0.31
# and 0.30 along the car either side of the axle; the arches' tops clear the tyres by 3cm.
const WELLS := [
	# axle    half_l base  rise   e    inner x
	[AXLE_F, 0.335, 0.10, 0.47, 2.4, 0.300],
	[AXLE_R, 0.320, 0.10, 0.47, 2.4, 0.395],
]
const LIP_R := 0.020

# The flank scoop: from SCOOP_Z.x it deepens to SCOOP_DEPTH and ends in a wall at SCOOP_Z.y, just
# ahead of the rear arch's flare. Its top runs under the doors' roll; its bottom falls from there
# to SCOOP_LOW, so it opens up toward the wheel.
const SCOOP_Z := Vector2(0.045, 0.335)
const SCOOP_DEPTH := 0.050
const SCOOP_LOW := 0.370

# Points per segment of the half-section: below the side, the bottom, the well's inner corner, its
# wall, its top corner, the ceiling, the lip; the side up to the sill line, on to the scoop, the
# scoop's lower step, its back, its upper step, the side above it; above the side, the roll, the
# fender top, the rounding over A, the wall, the fillet, the floor. The sill line is a ring point,
# so the black below it has a clean edge.
const SEGMENTS := [3, 2, 3, 2, 4, 3, 2, 2, 1, 2, 1, 2, 6, 8, 2, 3, 3, 10]

# Black arch flares: their outer face stands FLARE_OUT proud of the side, FLARE_D deep.
const FLARE_OUT := 0.030
const FLARE_D := 0.034

# The body's paint scheme: black below the sills, across the jaw (up to JAW_Y) and the tail (up to
# TAIL_Y); the bonnet's panel from HOOD_FRONT back to the visor.
const SILL_Y := 0.362
const JAW_Y := 0.402
const TAIL_Y := 0.505
const HOOD_FRONT := -0.815
# The headlamps: three in a row a side from LAMP_X, at LAMP_Y.
const LAMP_X := 0.285
const LAMP_Y := 0.442
const LAMP_STEP := 0.060
# The visor's glass patch on the bottom, round this z (the cockpit's flat floor).
const GLASS_Z := -0.06
# The rear window's foot on the deck; the louvred panel behind it (z from, to).
const REAR_GLASS_Z := 0.530
const DECK_PANEL := Vector2(0.560, 0.880)

# Tyres: a balloon carcass (half its profile, bead to tread centre) under paddle lugs.
const TYRE_HALF := [[-0.098, 0.150], [-0.116, 0.158], [-0.130, 0.175], [-0.136, 0.196], [-0.134, 0.216],
	[-0.124, 0.233], [-0.104, 0.245], [-0.066, 0.251], [0.0, 0.2525]]
const TREAD_ROWS := 18
const LUG_H := 0.0175

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.20, 0.20, 0.21)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_TRIM := Color(0.09, 0.09, 0.10)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.80, 0.81, 0.83)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.57)
const C_LEATHER := Color(0.55, 0.06, 0.05)
const C_TAILLAMP := Color(0.90, 0.05, 0.03)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.07, "tail_z": 1.065, "belt_y": 0.55, "side_x": 0.50,
	"door_z": -0.16, "door_y": 0.43, "roundel_r": 0.058,
	"hood_z": -0.94, "hood_r": 0.050, "stripe_w": 0.060, "stripe_gap": 0.022,
}
const ANTENNA_POS := Vector3(0.33, 0.62, 0.85)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}

var _glass_uv := Vector2.ZERO


func _init() -> void:
	nose_tip = -1.070
	nose_cap = 0.040
	nose_cap_y = 0.400
	nose_cap_exp = Vector2(4.0, 2.5)
	tail_tip = 1.065
	tail_cap = 0.035
	# The tail shrinks toward the top of its black fascia, which then lies on the same ring points
	# all over the tail's face (the cap's rings are scaled copies of the section about this height).
	tail_cap_y = TAIL_Y
	tail_cap_exp = Vector2(5.0, 3.0)
	half_ring = 0
	for n in SEGMENTS:
		half_ring += n
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[5] + key[6]])
	setup_shell(knots)
	_glass_uv = Vector2(u_of_z(GLASS_Z), 1.5 / half_ring)


## The wheel well at z: [its inner wall's x, the arch's height there] (an arch under the bottom is
## no well). Between the axles the inner wall's x blends from one well's to the other's, so the
## section's points move smoothly along the car.
static func _well(z: float) -> Array:
	for w in WELLS:
		var t: float = absf(z - w[0]) / w[1]
		if t < 1.0:
			return [w[5], w[2] + w[3] * pow(1.0 - pow(t, w[4]), 1.0 / w[4])]
	var f: float = smoothstep(WELLS[0][0] + WELLS[0][1], WELLS[1][0] - WELLS[1][1], z)
	return [lerpf(WELLS[0][5], WELLS[1][5], f), -1.0]


## The well's ceiling at z: the arch's height, kept 3cm under the side's top (the bottom where there
## is no well).
func _ceiling(z: float) -> float:
	var bot: float = prof["bot"].at(z)
	return bot + clampf(float(_well(z)[1]) - bot, 0.0, prof["belt"].at(z) - bot - 0.03)


## The flank scoop at z, on a side running from s0 up to the belt: [depth, its bottom, its top].
## Away from it the (empty) steps rest at one height on the side; they move to the scoop's edges over
## 6cm either side of it, while it has no depth.
func _scoop(z: float, s0: float, belt: float) -> Array:
	var rest: float = lerpf(s0, belt, 0.55)
	var y_hi: float = belt - 0.022
	var f: float = clampf((z - SCOOP_Z.x) / (SCOOP_Z.y - SCOOP_Z.x), 0.0, 1.0)
	var y_lo: float = lerpf(y_hi - 0.012, SCOOP_LOW, f)
	var d: float
	if z <= SCOOP_Z.y:
		d = SCOOP_DEPTH * smoothstep(SCOOP_Z.x, SCOOP_Z.x + 0.20, z)
	else:
		d = SCOOP_DEPTH * clampf(1.0 - (z - SCOOP_Z.y) / 0.006, 0.0, 1.0)
	var k: float = smoothstep(SCOOP_Z.x - 0.06, SCOOP_Z.x, z) * (1.0 - smoothstep(SCOOP_Z.y + 0.006, SCOOP_Z.y + 0.066, z))
	y_lo = clampf(lerpf(rest, y_lo, k), s0, belt)
	y_hi = clampf(lerpf(rest, y_hi, k), y_lo, belt)
	return [minf(d, (y_hi - y_lo) / 1.2), y_lo, y_hi]


static func _line(a: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, c])


static func _arc(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 7:
		var a: float = lerpf(a0, a1, k / 6.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## A quadratic Bézier from a over c to e, n + 1 points.
static func _bezier(a: Vector2, c: Vector2, e: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var t: float = float(k) / n
		pts.append(a.lerp(c, t).lerp(c.lerp(e, t), t))
	return pts


## The right half of the section at z (half_ring + 1 points, bottom of the centre line to its top),
## caps applied. Below the side: the bottom out to the well's inner wall, up it, out along the arch's
## ceiling and round the lip onto the side, which steps in and out round the scoop; away from the
## wheels the well has no height and the ceiling is the bottom.
func section(z: float) -> PackedVector2Array:
	var bot: float = prof["bot"].at(z)
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var xw: float = _well(z)[0]
	var ceil_y: float = _ceiling(z)
	var h: float = ceil_y - bot
	var ri: float = minf(0.012, h * 0.3)
	var rl: float = minf(LIP_R, (belt - ceil_y) * 0.45)
	var sc: Array = _scoop(z, ceil_y + rl, belt)
	var d: float = sc[0]
	var y_lo: float = sc[1]
	var y_hi: float = sc[2]
	var segs := [
		_line(Vector2(0.0, bot), Vector2(xw - ri, bot)),
		_arc(Vector2(xw - ri, bot + ri), ri, -PI * 0.5, 0.0),
		_line(Vector2(xw, bot + ri), Vector2(xw, ceil_y - ri)),
		_arc(Vector2(xw + ri, ceil_y - ri), ri, PI, PI * 0.5),
		_line(Vector2(xw + ri, ceil_y), Vector2(w - rl, ceil_y)),
		_arc(Vector2(w - rl, ceil_y + rl), rl, -PI * 0.5, 0.0),
		_line(Vector2(w, ceil_y + rl), Vector2(w, clampf(SILL_Y, ceil_y + rl, y_lo))),
		_line(Vector2(w, clampf(SILL_Y, ceil_y + rl, y_lo)), Vector2(w, y_lo)),
		_line(Vector2(w, y_lo), Vector2(w - d, y_lo + d * 0.9)),
		_line(Vector2(w - d, y_lo + d * 0.9), Vector2(w - d, y_hi - d * 0.25)),
		_line(Vector2(w - d, y_hi - d * 0.25), Vector2(w, y_hi)),
		_line(Vector2(w, y_hi), Vector2(w, belt)),
	]
	segs.append_array(_upper_segments(z, w, belt, 0.0))
	var sec := PackedVector2Array([(segs[0] as PackedVector2Array)[0]])
	for k in segs.size():
		var rs: PackedVector2Array = CB.resample(segs[k], int(SEGMENTS[k]) + 1, 0.0)
		for m in range(1, rs.size()):
			sec.append(rs[m])
	var c: Array = _cap(z)
	var cap: Vector2 = c[0]
	if cap != Vector2.ONE:
		var cy: float = c[1]
		for k in sec.size():
			sec[k] = Vector2(sec[k].x * cap.x, cy + (sec[k].y - cy) * cap.y)
	return sec


## Above the side: the roll onto the crest, the fender top falling inward to A (its tangent at the
## crest level, so the fender reads round), the rounding over A, the wall down (leaning inboard a
## little), the fillet onto the floor and the floor to the centre line.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var rr: float = prof["rr"].at(z)
	var crest := Vector2(w - rr, belt + rr)
	var ax: float = prof["ax"].at(z)
	var ay: float = crest.y - prof["adrop"].at(z)
	var floor_y: float = minf(prof["edge"].at(z), ay - 0.004)
	var depth: float = ay - floor_y
	var ar: float = minf(EDGE_R, depth * 0.4)
	var fr: float = minf(FILLET_R, depth * 0.4)
	var lean: float = minf(WALL_LEAN, depth * 0.2)
	var roll := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.5 * k / 8.0
		roll.append(Vector2(w - rr + rr * cos(a), belt + rr * sin(a)))
	var corner_a := Vector2(ax, ay)
	var corner_b := Vector2(ax - lean, floor_y)
	var q := Vector2(lerpf(crest.x, ax, 0.5), crest.y)
	var a1: Vector2 = corner_a + (q - corner_a).normalized() * ar
	var a2: Vector2 = corner_a + (corner_b - corner_a).normalized() * ar
	var b1: Vector2 = corner_b + (corner_a - corner_b).normalized() * fr
	var c1 := Vector2(corner_b.x - fr, floor_y)
	var crown: float = prof["crown"].at(z)
	var flr := PackedVector2Array()
	for k in 17:
		var x: float = c1.x * (1.0 - k / 16.0)
		flr.append(Vector2(x, floor_y + crown * (1.0 - (x / c1.x) * (x / c1.x))))
	return [roll, _bezier(crest, q, a1, 16), _bezier(a1, corner_a, a2, 6), _line(a2, b1), _bezier(b1, corner_b, c1, 6),
		flr]


# ============================================================================================
#  Body
# ============================================================================================

## Body mesh: shell, flares, lamps, the visor and roof frame, the cockpit, the running gear seen in
## the arches, the aero and the tail.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_flare(b, AXLE_F, WELLS[0][1])
	_flare(b, AXLE_R, WELLS[1][1])
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## A black flare round a wheel arch (right side): a band standing proud of the side along the arch's
## lip (the well's ceiling), FLARE_OUT out and FLARE_D deep, its top running back into the body, a
## liner under it slanting up into the body, its ends cut square at the sill.
func _flare(b, axle_z: float, half_l: float) -> void:
	var dense := PackedVector2Array()
	for k in 481:
		var z: float = lerpf(axle_z - half_l, axle_z + half_l, k / 480.0)
		var c: float = _ceiling(z)
		if c > prof["bot"].at(z) + 0.003:
			dense.append(Vector2(z, c))
	var spine: PackedVector2Array = CB.resample(dense, 30, 0.0)
	var n: int = spine.size()
	var hub := Vector2(axle_z, HUB_Y)
	var outer_rows := []
	var liner_rows := []
	var ends := []
	for k in n:
		var t2: Vector2 = (spine[mini(k + 1, n - 1)] - spine[maxi(k - 1, 0)]).normalized()
		var n2 := Vector2(t2.y, -t2.x)
		if n2.dot(spine[k] - hub) < 0.0:
			n2 = -n2
		var w: float = prof["w"].at(spine[k].x)
		var xo: float = w + FLARE_OUT
		var outer := [Vector2(xo - 0.010, 0.0), Vector2(xo - 0.001, 0.007), Vector2(xo + 0.002, 0.020),
			Vector2(xo, 0.6 * FLARE_D), Vector2(xo - 0.008, 0.9 * FLARE_D), Vector2(xo - 0.022, FLARE_D),
			Vector2(w - 0.012, FLARE_D + 0.003)]
		var liner := [Vector2(xo - 0.010, 0.0), Vector2(w - 0.018, 0.022)]
		var rows := []
		for profile in [outer, liner]:
			var row := PackedVector3Array()
			for p in profile:
				row.append(Vector3(p.x, spine[k].y + p.y * n2.y, spine[k].x + p.y * n2.x))
			rows.append(row)
		outer_rows.append(rows[0])
		liner_rows.append(rows[1])
		if k == 0:
			ends.append([rows[0], rows[1], Vector3(0.0, -t2.y, -t2.x)])
		elif k == n - 1:
			ends.append([rows[0], rows[1], Vector3(0.0, t2.y, t2.x)])
	var base: int = b.vertex_count()
	var ibase: int = b.index_count()
	b.grid(outer_rows, CB.M_DARK, C_DARK, false, false)
	# The skin faces outward: at the outer face's middle the normal points along +x.
	if b._n[base + 3].dot(Vector3.RIGHT) < 0.0:
		b.flip(base, ibase)
	base = b.vertex_count()
	ibase = b.index_count()
	b.grid(liner_rows, CB.M_DARK, C_DARKER, false, false)
	var toward_hub := 0.0
	for k in range(base, b.vertex_count()):
		toward_hub += b._n[k].dot(Vector3(WHEEL_X, HUB_Y, axle_z) - b._v[k])
	if toward_hub < 0.0:
		b.flip(base, ibase)
	for e in ends:
		var cap := PackedVector3Array()
		for p in e[0]:
			cap.append(p)
		cap.append((e[1] as PackedVector3Array)[1])
		b.poly(cap, e[2], CB.M_DARK, C_DARK)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Headlamps: three round lamps in a row in a black pod under the fender's brow, an LED strip
	# under them. The pod lies along the face, which curves back toward the side.
	var lamps := []
	for k in 3:
		lamps.append(face_frame(LAMP_X + LAMP_STEP * k, LAMP_Y, true))
	var p0: Vector3 = lamps[0][0]
	var p2: Vector3 = lamps[2][0]
	var fwd: Vector3 = ((lamps[1][1] as Vector3) + Vector3(0.15, 0.0, 0.0)).normalized()
	var px: Vector3 = (p2 - p0).normalized()
	var pz: Vector3 = (fwd - px * fwd.dot(px)).normalized()
	var pod := Basis(px, pz.cross(px), pz)
	var pc: Vector3 = (p0 + p2) * 0.5 + pz * 0.004
	b.rbox(Transform3D(pod, pc), Vector3(0.100, 0.032, 0.016), 0.014, 2, CB.M_DARK, C_DARKER)
	for lamp in lamps:
		var lc: Vector3 = (lamp[0] as Vector3) + pod.y * 0.004
		lc += pz * (pz.dot(pc - lc) + 0.017)
		round_lamp(b, lc, pz, 0.0215, CB.M_HEADLAMP, Color(1, 1, 1))
	b.rbox(Transform3D(pod, pc - pod.y * 0.028 + pz * 0.012), Vector3(0.088, 0.0028, 0.004), 0.002, 1, CB.M_HEADLAMP,
			Color(1, 1, 1))
	# Mirror on a stalk from the door's top beside the visor.
	var foot := Vector3(0.425, top_y(0.425, -0.290), -0.290)
	b.tube(PackedVector3Array([foot - Vector3(0.0, 0.01, 0.0), Vector3(0.495, 0.598, -0.286)]), 0.0065, 6, CB.M_DARK,
			C_DARK, false, false)
	var mb := Basis(Vector3.UP, -0.15)
	b.rbox(Transform3D(mb, Vector3(0.520, 0.606, -0.280)), Vector3(0.042, 0.024, 0.018), 0.012, 2, CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(mb, Vector3(0.523, 0.606, -0.2615)), Vector3(0.035, 0.018, 0.002), 0.002, 1, CB.M_CHROME, C_CHROME)
	# Roof rail from the visor's header back to the hoop over the buttress.
	var corner: Vector3 = _visor_point(1.0, 1.0)
	b.tube(_rounded([corner + Vector3(-0.004, 0.004, 0.0), Vector3(0.344, 0.795, 0.030), Vector3(0.336, 0.795, 0.180)],
			0.08, 6), 0.012, 8, CB.M_DARK, C_TRIM, false, true)
	# Flying buttress: a painted bar from the hoop behind the seats down onto the haunch, a quarter
	# window under it.
	slab(b, PackedVector2Array([Vector2(0.150, 0.770), Vector2(0.165, 0.798), Vector2(0.205, 0.800),
			Vector2(0.560, 0.622), Vector2(0.560, 0.598), Vector2(0.470, 0.598)]), 0.336, 0.030, CB.M_PAINT, Color(1, 1, 1))
	_pane(b, PackedVector3Array([Vector3(0.333, 0.535, 0.172), Vector3(0.333, 0.775, 0.156),
			Vector3(0.333, 0.606, 0.480), Vector3(0.333, 0.590, 0.480)]))
	# A bright strip along the top of the black sill.
	var strip := PackedVector3Array()
	for k in 25:
		var z: float = lerpf(-0.405, 0.375, k / 24.0)
		strip.append(Vector3(prof["w"].at(z) + 0.0015, SILL_Y + 0.008, z))
	b.tube(strip, 0.0042, 6, CB.M_ALLOY, C_ALLOY, true, true)
	_seat(b, 0.165)
	_running_gear(b)
	# Tail: two round lamps a side; an exhaust tip under them.
	for x in [0.235, 0.360]:
		var tl: Array = face_frame(x, 0.548, false)
		round_lamp(b, (tl[0] as Vector3) + (tl[1] as Vector3) * 0.006, tl[1], 0.036, CB.M_TAILLAMP, C_TAILLAMP)
	var ex: Array = face_frame(0.085, 0.405, false)
	var ep: Vector3 = ex[0]
	b.tube(PackedVector3Array([ep - Vector3(0.0, 0.0, 0.06), ep + Vector3(0.0, 0.0, 0.028)]), 0.025, 16, CB.M_CHROME,
			C_CHROME, false, false)
	b.disc(ep + Vector3(0.0, 0.0, 0.020), Vector3.BACK, 0.021, 0.0, 16, CB.M_DARK, C_DARKER)
	# Splitter fence at the jaw's corner.
	var fence: Array = face_frame(0.40, 0.33, true)
	var fp: Vector3 = fence[0]
	slab(b, PackedVector2Array([Vector2(fp.z - 0.045, 0.316), Vector2(fp.z + 0.04, 0.316), Vector2(fp.z + 0.04, 0.37),
			Vector2(fp.z - 0.005, 0.37)]), 0.40, 0.010, CB.M_DARK, C_DARK)


## A racing bucket seat at x: a black shell with red inserts, bolsters, the back leaning against the
## bulkhead.
func _seat(b, x: float) -> void:
	var pan := Basis(Vector3.RIGHT, 0.10)
	b.rbox(Transform3D(pan, Vector3(x, 0.338, -0.020)), Vector3(0.078, 0.022, 0.092), 0.014, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(pan, Vector3(x, 0.362, -0.026)), Vector3(0.050, 0.008, 0.078), 0.006, 2, CB.M_DARK, C_LEATHER)
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(pan, Vector3(x + s * 0.064, 0.368, -0.020)), Vector3(0.014, 0.018, 0.085), 0.010, 2,
				CB.M_DARK, C_DARK)
	var back := Basis(Vector3.RIGHT, 0.24)
	var bc := Vector3(x, 0.530, 0.092)
	b.rbox(Transform3D(back, bc), Vector3(0.080, 0.175, 0.022), 0.016, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(back, bc - back.z * 0.020), Vector3(0.050, 0.150, 0.008), 0.006, 2, CB.M_DARK, C_LEATHER)
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(back, bc + back.x * (s * 0.066) - back.z * 0.022 - back.y * 0.02), Vector3(0.014, 0.130, 0.018),
				0.010, 2, CB.M_DARK, C_DARK)


## The suspension seen through the arches (right side): long A-arms to the hub carriers, coil-overs
## with springs in the accent colour, the drive shafts and the steering link.
func _running_gear(b) -> void:
	var kx := 0.465
	for axle in [AXLE_F, AXLE_R]:
		var x_in: float = 0.20 if axle == AXLE_F else 0.25
		for dz in [-0.09, 0.09]:
			b.tube(PackedVector3Array([Vector3(x_in, 0.235, axle + dz), Vector3(kx - 0.012, 0.212, axle)]), 0.012, 8,
					CB.M_DARK, C_STEEL, true, true)
		for dz in [-0.07, 0.07]:
			b.tube(PackedVector3Array([Vector3(x_in + 0.02, 0.385, axle + dz), Vector3(kx - 0.014, 0.335, axle)]), 0.010,
					8, CB.M_DARK, C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(kx, HUB_Y, axle)), Vector3(0.018, 0.072, 0.030), 0.009, 1, CB.M_DARK, C_STEEL)
		b.tube(PackedVector3Array([Vector3(kx, HUB_Y, axle), Vector3(WHEEL_X - 0.04, HUB_Y, axle)]), 0.016, 10,
				CB.M_ALLOY, C_ALLOY_DARK, false, true)
		b.tube(PackedVector3Array([Vector3(0.15, 0.27, axle), Vector3(kx - 0.01, HUB_Y, axle)]), 0.010, 8, CB.M_ALLOY,
				C_ALLOY_DARK, false, false)
	b.tube(PackedVector3Array([Vector3(0.20, 0.310, AXLE_F + 0.075), Vector3(kx - 0.01, 0.300, AXLE_F + 0.045)]), 0.007,
			6, CB.M_DARK, C_STEEL, false, false)
	coilover(b, Vector3(0.400, 0.222, AXLE_F + 0.01), Vector3(0.330, 0.545, AXLE_F + 0.05), 0.017, 0.028, 7.0, C_ALLOY,
			C_ALLOY_DARK, C_CHROME, C_DARK)
	coilover(b, Vector3(0.425, 0.222, AXLE_R - 0.01), Vector3(0.430, 0.548, AXLE_R - 0.06), 0.017, 0.028, 7.0, C_ALLOY,
			C_ALLOY_DARK, C_CHROME, C_DARK)


func _centre_parts(b) -> void:
	# The jaw: an intake grille in the black under the nose; the silver splitter along its foot.
	var gr: Array = face_frame(0.0, 0.358, true)
	var gb: Basis = facing(gr[1])
	b.rbox(Transform3D(gb, gr[0]), Vector3(0.175, 0.030, 0.010), 0.012, 2, CB.M_DARK, C_DARKER)
	for k in 3:
		bar(b, (gr[0] as Vector3) + gb.y * (-0.016 + 0.016 * k) + gb.z * 0.009, Vector3(0.165, 0.0025, 0.003), CB.M_DARK,
				C_TRIM)
	var splitter := PackedVector3Array()
	for k in 17:
		var x: float = lerpf(-0.44, 0.44, k / 16.0)
		splitter.append(Vector3(x, 0.312, shell_z(x, 0.330, true) - 0.006))
	sweep(b, splitter, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.040, -0.004), Vector2(0.040, -0.004),
			Vector2(0.040, 0.004), Vector2(-0.040, 0.004)]), CB.M_ALLOY, C_ALLOY)
	# Bonnet: louvres across the extractor panel.
	for k in 6:
		var z: float = -0.765 + 0.058 * k
		var half: float = prof["ax"].at(z) - 0.030
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.45), Vector3(0.0, top_y(0.0, z) + 0.006, z)),
				Vector3(half, 0.003, 0.014), 0.002, 1, CB.M_DARK, C_TRIM)
	_visor(b)
	# The hoop over the buttresses behind the seats; the rear window from it down to the deck between
	# them, sealed along its foot.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.792, 0.183)), Vector3(0.352, 0.012, 0.030), 0.008, 2, CB.M_DARK, C_TRIM)
	_pane(b, PackedVector3Array([Vector3(-0.322, 0.786, 0.205), Vector3(0.322, 0.786, 0.205),
			Vector3(0.322, 0.600, REAR_GLASS_Z), Vector3(-0.322, 0.600, REAR_GLASS_Z)]))
	b.tube(PackedVector3Array([Vector3(-0.322, 0.601, REAR_GLASS_Z), Vector3(0.322, 0.601, REAR_GLASS_Z)]), 0.006, 6,
			CB.M_DARK, C_TRIM, true, true)
	# Engine deck: painted louvres over the black panel between the haunches, behind the window.
	for k in 6:
		var z: float = DECK_PANEL.x + 0.030 + 0.054 * k
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.40), Vector3(0.0, top_y(0.0, z) + 0.007, z)),
				Vector3(0.150, 0.003, 0.016), 0.002, 1, CB.M_PAINT, Color(1, 1, 1))
	# Tail: a grille in the black fascia over the exhausts.
	var tg: Array = face_frame(0.0, 0.458, false)
	var tb: Basis = facing(tg[1])
	b.rbox(Transform3D(tb, tg[0]), Vector3(0.150, 0.026, 0.008), 0.010, 2, CB.M_DARK, C_DARKER)
	for k in 3:
		bar(b, (tg[0] as Vector3) + tb.y * (-0.013 + 0.013 * k) + tb.z * 0.007, Vector3(0.140, 0.0022, 0.003), CB.M_DARK,
				C_TRIM)
	# The cockpit: dash binnacle before the driver (left), the steering wheel, a console between the
	# seats with the gear lever.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(-0.165, 0.560, -0.335)), Vector3(0.068, 0.018, 0.034), 0.010,
			2, CB.M_DARK, C_DARK)
	_steering_wheel(b, Vector3(-0.165, 0.512, -0.238))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.360, -0.10)), Vector3(0.045, 0.048, 0.185), 0.014, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(0.0, 0.405, -0.13), Vector3(0.0, 0.452, -0.115)]), 0.005, 6, CB.M_CHROME, C_CHROME,
			false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.458, -0.114)), Vector3(0.011, 0.011, 0.011), 0.010, 2, CB.M_DARK, C_DARK)
	# Diffuser under the tail: a plate rising to the back, five fins under it.
	var dpath := PackedVector3Array()
	for k in 5:
		var z: float = lerpf(0.80, 1.058, k / 4.0)
		dpath.append(Vector3(0.0, prof["bot"].at(z) - 0.005, z))
	sweep(b, dpath, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.32, -0.004), Vector2(0.32, -0.004),
			Vector2(0.32, 0.004), Vector2(-0.32, 0.004)]), CB.M_DARK, C_DARK)
	for x in [-0.24, -0.12, 0.0, 0.12, 0.24]:
		slab(b, PackedVector2Array([Vector2(0.86, 0.300), Vector2(1.056, 0.344), Vector2(1.056, 0.305),
				Vector2(0.92, 0.278)]), x, 0.008, CB.M_DARK, C_DARK)


## A flat pane of glass (a convex outline), both faces drawn (see GLASS_Z).
func _pane(b, pts: PackedVector3Array) -> void:
	var nrm: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	for s in [1.0, -1.0]:
		var ci: int = b.vertex(c, nrm * s, CB.M_BODY, Color(1, 1, 1), _glass_uv)
		var ids := []
		for p in pts:
			ids.append(b.vertex(p, nrm * s, CB.M_BODY, Color(1, 1, 1), _glass_uv))
		for k in ids.size():
			b.tri(ci, ids[k], ids[(k + 1) % ids.size()])


## A point on the visor: s across (-1 left to 1 right), t up (0 at its foot on the body, 1 at the
## header). Its foot and header sweep back toward the sides (a wraparound), and it bows forward a
## little between them.
func _visor_point(s: float, t: float) -> Vector3:
	var e: float = pow(absf(s), 4.0)
	var xb: float = 0.405 * s
	var zb: float = -0.430 + 0.125 * e
	var yb: float = top_y(xb, zb) + 0.002
	var xt: float = 0.345 * s
	var zt: float = -0.150 + 0.075 * e
	var yt: float = 0.780 - 0.012 * s * s
	return Vector3(lerpf(xb, xt, t), lerpf(yb, yt, t), lerpf(zb, zt, t) - 0.018 * sin(PI * t))


## The visor: glass both ways round (seen through the open cockpit from behind too), framed by a
## black header, pillars and a seal along its foot.
func _visor(b) -> void:
	var rows := []
	var uvs := []
	for i in 9:
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		for j in 33:
			row.append(_visor_point(lerpf(-1.0, 1.0, j / 32.0), i / 8.0))
			uv.append(_glass_uv)
		rows.append(row)
		uvs.append(uv)
	for dir in [Vector3(0.0, 0.6, -1.0), Vector3(0.0, -0.6, 1.0)]:
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.grid(rows, CB.M_BODY, Color(1, 1, 1), false, false, uvs)
		b.orient_toward(vb, ib, dir)
	var header := PackedVector3Array()
	var seal := PackedVector3Array()
	for j in 33:
		var s: float = lerpf(-1.0, 1.0, j / 32.0)
		header.append(_visor_point(s, 1.0) + Vector3(0.0, 0.004, 0.003))
		seal.append(_visor_point(s, 0.0))
	b.tube(header, 0.014, 8, CB.M_DARK, C_TRIM, true, true)
	b.tube(seal, 0.007, 6, CB.M_DARK, C_TRIM, true, true)
	for s in [-1.0, 1.0]:
		var pillar := PackedVector3Array()
		for i in 9:
			pillar.append(_visor_point(s, i / 8.0))
		b.tube(pillar, 0.010, 8, CB.M_DARK, C_TRIM, true, true)


## A steering wheel at c, facing the driver: a rim, three spokes, the boss, the column into the dash.
func _steering_wheel(b, c: Vector3) -> void:
	var ax := Vector3(0.0, 0.55, 1.0).normalized()
	var r := 0.052
	var prof2 := PackedVector2Array()
	for k in 9:
		var a: float = TAU * k / 8.0
		prof2.append(Vector2(cos(a) * 0.0065, r + sin(a) * 0.0065))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, ax, prof2, 24, CB.M_DARK, C_DARK)
	# The profile's first point is the rim's face toward the driver: its normal points along ax.
	if b._n[vb].dot(ax) < 0.0:
		b.flip(vb, ib)
	var e1: Vector3 = Vector3.RIGHT
	var e2: Vector3 = ax.cross(e1).normalized()
	for d in [e1, -e1, e2 if e2.y < 0.0 else -e2]:
		b.tube(PackedVector3Array([c, c + d * (r - 0.004)]), 0.0055, 6, CB.M_DARK, C_DARK, false, false)
	b.rbox(Transform3D(facing(ax), c + ax * 0.004), Vector3(0.017, 0.017, 0.008), 0.007, 2, CB.M_DARK, C_DARK)
	b.disc(c + ax * 0.0125, ax, 0.008, 0.0, 12, CB.M_ANODISED, Color(1, 1, 1))
	b.tube(PackedVector3Array([c, c - ax * 0.10]), 0.009, 8, CB.M_DARK, C_DARK, false, false)


# ============================================================================================
#  Wheels
# ============================================================================================

## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1): a
## balloon sand tyre with paddle lugs round a star rim of five faceted arms.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 48, C_RUBBER)
	for row in TREAD_ROWS:
		var sgn: float = 1.0 if row % 2 == 0 else -1.0
		var g: Array = wheel_frame(TAU * row / TREAD_ROWS)
		var r_dir: Vector3 = g[0]
		var t_dir: Vector3 = g[1]
		# A paddle lug from just past the centre line out over one shoulder, in pieces that follow the
		# carcass, swept back toward the shoulder; rows alternate sides, a chevron down the tread.
		for x in [-0.030, 0.012, 0.054, 0.093, 0.124]:
			var xs: float = x * sgn
			var rc: float = carcass_r(TYRE_HALF, xs)
			var slope: float = (carcass_r(TYRE_HALF, xs + 0.004) - carcass_r(TYRE_HALF, xs - 0.004)) / 0.008
			var up: Vector3 = (r_dir - Vector3.RIGHT * slope).normalized()
			var c: Vector3 = r_dir * rc + Vector3(xs, 0.0, 0.0) + t_dir * (0.10 * absf(x)) + up * (0.4 * LUG_H - 0.002)
			var across: Vector3 = t_dir.cross(up).normalized()
			block(b, c, across, t_dir, up, 0.024, LUG_H, 0.017, 0.85, CB.M_RUBBER, C_RUBBER)
	# Rim: the lip, its face stepping in to the arms, the barrel, a dark well and the brake disc
	# behind the arms.
	wheel_lathe(b, PackedVector2Array([Vector2(0.090, 0.150), Vector2(0.100, 0.157), Vector2(0.107, 0.156),
			Vector2(0.110, 0.148), Vector2(0.104, 0.141)]), 48, CB.M_RIM, C_RIM, "out", Vector3(0.08, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.104, 0.141), Vector2(0.090, 0.138), Vector2(0.080, 0.136)]), 48,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.080, 0.136), Vector2(0.074, 0.146), Vector2(-0.096, 0.148),
			Vector2(-0.104, 0.153)]), 48, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(0.018, 0.0, 0.0), Vector3.RIGHT, 0.140, 0.0, 32, CB.M_DARK, C_DARKER)
	b.disc(Vector3(0.030, 0.0, 0.0), Vector3.RIGHT, 0.118, 0.052, 32, CB.M_ALLOY, C_ALLOY_DARK)
	for k in 5:
		_rim_arm(b, TAU * k / 5.0)
	# The boss and a cap in the accent colour.
	wheel_lathe(b, PackedVector2Array([Vector2(0.060, 0.050), Vector2(0.084, 0.050), Vector2(0.090, 0.044)]), 24,
			CB.M_RIM, C_RIM, "out", Vector3(0.07, 0.0, 0.0))
	b.disc(Vector3(0.090, 0.0, 0.0), Vector3.RIGHT, 0.044, 0.0, 24, CB.M_RIM, C_RIM)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.090, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.026), Vector2(0.006, 0.025),
			Vector2(0.010, 0.016), Vector2(0.012, 0.0)]), 20, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.085, 0.0, 0.0))
	for k in 5:
		var g: Array = wheel_frame(TAU * (k + 0.5) / 5.0)
		bar(b, (g[0] as Vector3) * 0.036 + Vector3(0.092, 0.0, 0.0), Vector3(0.004, 0.0045, 0.0045), CB.M_CHROME, C_CHROME)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


## One arm of the star rim at angle a: broad at the boss, narrowing to the lip, its face two facets
## meeting in a ridge down the middle, turned a little ahead toward the lip.
func _rim_arm(b, a: float) -> void:
	var f0: Array = wheel_frame(a)
	var f1: Array = wheel_frame(a + 0.10)
	var rd0: Vector3 = f0[0]
	var tg0: Vector3 = f0[1]
	var rd1: Vector3 = f1[0]
	var tg1: Vector3 = f1[1]
	var r0 := 0.046
	var r1 := 0.138
	var x0 := 0.080
	var x1 := 0.086
	var ridge := 0.007
	var th := 0.018
	var ic: Vector3 = rd0 * r0 + Vector3(x0 + ridge, 0.0, 0.0)
	var il: Vector3 = rd0 * r0 + tg0 * 0.031 + Vector3(x0, 0.0, 0.0)
	var ir: Vector3 = rd0 * r0 - tg0 * 0.031 + Vector3(x0, 0.0, 0.0)
	var oc: Vector3 = rd1 * r1 + Vector3(x1 + ridge * 0.5, 0.0, 0.0)
	var ol: Vector3 = rd1 * r1 + tg1 * 0.012 + Vector3(x1, 0.0, 0.0)
	var orr: Vector3 = rd1 * r1 - tg1 * 0.012 + Vector3(x1, 0.0, 0.0)
	var back := Vector3(-th, 0.0, 0.0)
	face(b, [ic, il, ol, oc], Vector3.RIGHT + tg0, CB.M_RIM, C_RIM)
	face(b, [ic, ir, orr, oc], Vector3.RIGHT - tg0, CB.M_RIM, C_RIM)
	face(b, [il, ol, ol + back, il + back], tg0, CB.M_RIM, C_RIM_BARREL)
	face(b, [ir, orr, orr + back, ir + back], -tg0, CB.M_RIM, C_RIM_BARREL)


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# The door in side view (z, y): from behind the front arch to the scoop, the sill up past the
	# door's top (so only its front, back and bottom show).
	shapes["door"] = _inset(PackedVector2Array([Vector2(-0.360, SILL_Y + 0.012), Vector2(0.040, SILL_Y + 0.012),
			Vector2(0.040, 0.640), Vector2(-0.360, 0.640)]), 0.028)
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	# The visor's patch of glass on the flat bottom under the cockpit (_glass_uv samples it).
	if n.y < -0.9 and absf(p.z - GLASS_Z) < 0.07:
		return Color(1.0, 0.0, 0.0, 0.0)
	var gap := 0.0
	var black := 0.0
	var x: float = absf(p.x)
	var w: float = prof["w"].at(p.z)
	var belt: float = prof["belt"].at(p.z)
	var well: Array = _well(p.z)
	var a_x: float = prof["ax"].at(p.z)
	var a_y: float = belt + prof["rr"].at(p.z) - prof["adrop"].at(p.z)
	var inside: bool = x < a_x + 0.002 and p.y < a_y - 0.003
	# The wells' inner walls; the ceilings and the underside.
	if n.x > 0.5 and x < float(well[0]) + 0.003 and p.y < float(well[1]) + 0.004:
		black = 1.0
	if n.y < -0.55:
		black = 1.0
	# Bonnet: the extractor panel on the sunken floor between the fenders, pointed toward the nose.
	if inside and n.y > 0.6 and p.z < -0.40:
		black = maxf(black, _cover(maxf(x - (a_x - 0.020), HOOD_FRONT - p.z + x * 0.45), fp))
	# Dash and cockpit: everything below the doors' tops from the visor back to the bulkhead.
	if inside and p.z > -0.44 and p.z < 0.19:
		black = 1.0
	# Engine deck: a black panel under the louvres; three vents in each haunch's top.
	if n.y > 0.6 and p.z > 0.30:
		var panel := Vector2((DECK_PANEL.x + DECK_PANEL.y) * 0.5, (DECK_PANEL.y - DECK_PANEL.x) * 0.5)
		black = maxf(black, _cover(_sd_box(Vector2(x, p.z - panel.x), Vector2(0.162, panel.y)) - 0.008, fp))
		if p.z > 0.37 and p.z < 0.53:
			var slots := 1e3
			for k in 3:
				slots = minf(slots, _sd_box(Vector2(x - 0.452, p.z - (0.400 + 0.045 * k)), Vector2(0.042, 0.007)) - 0.003)
			black = maxf(black, _cover(slots, fp))
	# Flank scoop: everything in the recess.
	if p.z > SCOOP_Z.x and p.z < SCOOP_Z.y + 0.007 and x < w - 0.0008 and p.y > SILL_Y and p.y < belt:
		black = 1.0
	# Lower body: the sills, the jaw and the tail black.
	if n.x > 0.3:
		black = maxf(black, _cover(p.y - SILL_Y, fp))
	if n.z < -0.3:
		# The jaw's top rises from under the nose's point to the lamps' brows.
		var jaw: float = JAW_Y + (LAMP_Y + 0.040 - JAW_Y) * smoothstep(0.05, LAMP_X - 0.03, x)
		black = maxf(black, _cover(p.y - jaw, fp))
	if n.z > 0.45:
		black = maxf(black, _cover(p.y - TAIL_Y, fp))
	# Door shut lines.
	if n.x > 0.5 and x > w - 0.006:
		gap = _cover(absf(_sd_rounded(Vector2(p.z, p.y), sh["door"])) - 0.0022, fp)
	return Color(0.0, gap, 0.0, black)
