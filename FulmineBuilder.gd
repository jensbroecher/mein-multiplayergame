# FulmineBuilder.gd
#
# The Fulmine: a fictional mid-engined hypercar. A low nose between two front fenders that stand up
# as humps either side of a sunken bonnet with two louvred vents; slim swept LED lamps (a black
# housing, a light strip, two projector lenses) on the fenders' front slopes; a black mouth with
# vanes and an intake with strakes under each lamp, a splitter with a lip in the accent colour. A
# see-through glass canopy (build_glass()) stands on the door tops from the cowl to the engine cover,
# framed by a seal round its foot, two pillars sweeping up from the cowl's corners and a hoop behind
# the seats; under it the cockpit: two bucket seats, the steering wheel, the tunnel. The waist
# pinches in at the doors, and a deep, dark intake is carved into each flank ahead of the rear wheel,
# under the broad haunches. A low spine runs from the canopy's tail down the engine cover, louvres
# either side of it, and a swan-neck wing hangs over the tail; across the tail a lip, a full-width
# light bar over a black fascia, two diffuser fins a side and twin exhausts. The mirrors and the
# wing's endplates are in the accent colour. Low-profile tyres, broader at the back
# (build_rear_wheel), on rims of five pairs of slim spokes with a centre-lock nut.
#
# The section (section(), overridden) carries the wheel wells like the Nocturne's: below the side,
# the shell steps in to the well's inner wall and up under the arch, its ceiling sloping down inward
# so it stays under the fender tops. The side carries the flank intake (_scoop(), as on the Inferno):
# a recess deepening toward the rear wheel that ends in a wall facing forward, shaded dark and matte
# inside (_shell_shade). Above the side, keyed along the car (KEYS): a roll onto the fender's crest,
# the fender top falling inward to A, a wall from A to B, and the top from B to the centre line.
# Over the bonnet and the tail B lies a little below A (the wall is the fender's inner flank, the top
# the valley between the humps); beside the cockpit B lies deep below A (the wall is the door's inner
# side, the top the cockpit's floor), with a dash in front and a bulkhead behind; over the deck behind
# it B lies above A (the wall is the sail panel up to the deck). Between them B passes A's height
# well inboard of it, so the wall never vanishes and the regions blend without a fold.
extends "res://CarDesign.gd"

# Wheels: staggered, the rears broader and taller (hub height = tyre radius).
const AXLE_F := -0.680
const AXLE_R := 0.650
const WHEEL_X_F := 0.455
const WHEEL_X_R := 0.462
const TYRE_R_F := 0.160
const TYRE_R_R := 0.175

# The side (w) and the bottom (bot) along the car: the nose nearly as broad as the front fenders,
# a waist at the doors, the widest point over the rear wheels; the bottom rises into a diffuser.
const W_KNOTS := [[-1.170, 0.430], [-1.110, 0.490], [-1.040, 0.522], [-0.950, 0.542], [-0.820, 0.552],
	[-0.680, 0.555], [-0.560, 0.550], [-0.450, 0.537], [-0.330, 0.522], [-0.200, 0.515], [-0.050, 0.515],
	[0.100, 0.525], [0.250, 0.545], [0.400, 0.566], [0.550, 0.577], [0.650, 0.580], [0.800, 0.579],
	[0.950, 0.574], [1.060, 0.566], [1.130, 0.560]]
const BOT_KNOTS := [[-1.170, 0.082], [-1.100, 0.074], [-1.000, 0.066], [-0.850, 0.056], [-0.400, 0.050],
	[0.400, 0.050], [0.850, 0.066], [1.000, 0.115], [1.080, 0.165], [1.130, 0.180]]

# The section above the side, keyframed along the car. Per row: z; belt (the top of the vertical
# side); rr (the roll over it: the crest is at belt + rr); ax, adrop (A: the fender top's inner end,
# adrop below the crest); bx, by (B: where the wall meets the top); top (the centre line); ra, rb
# (the rounding at A and at B).
const KEYS := [
	# z       belt   rr     ax     adrop  bx     by     top    ra     rb
	[-1.170, 0.162, 0.018, 0.320, 0.004, 0.240, 0.172, 0.176, 0.018, 0.022],
	[-1.090, 0.184, 0.022, 0.335, 0.010, 0.250, 0.188, 0.192, 0.020, 0.026],
	[-1.010, 0.220, 0.028, 0.345, 0.020, 0.258, 0.208, 0.213, 0.022, 0.030],
	[-0.930, 0.266, 0.034, 0.350, 0.028, 0.262, 0.232, 0.238, 0.022, 0.032],
	[-0.850, 0.314, 0.038, 0.350, 0.032, 0.265, 0.258, 0.264, 0.022, 0.032],
	[-0.760, 0.349, 0.040, 0.348, 0.028, 0.268, 0.278, 0.284, 0.022, 0.032],
	[-0.680, 0.362, 0.040, 0.348, 0.024, 0.270, 0.292, 0.298, 0.022, 0.032],
	[-0.590, 0.356, 0.039, 0.350, 0.024, 0.270, 0.302, 0.308, 0.022, 0.032],
	[-0.500, 0.334, 0.037, 0.355, 0.022, 0.268, 0.312, 0.318, 0.022, 0.032],
	[-0.420, 0.304, 0.035, 0.372, 0.016, 0.262, 0.324, 0.330, 0.020, 0.030],
	[-0.370, 0.290, 0.034, 0.385, 0.012, 0.330, 0.300, 0.306, 0.016, 0.020],
	[-0.300, 0.276, 0.033, 0.398, 0.010, 0.348, 0.236, 0.236, 0.014, 0.016],
	[-0.240, 0.268, 0.032, 0.405, 0.008, 0.352, 0.140, 0.130, 0.014, 0.016],
	[-0.060, 0.260, 0.032, 0.410, 0.008, 0.352, 0.140, 0.130, 0.014, 0.016],
	[0.060, 0.268, 0.034, 0.404, 0.008, 0.350, 0.142, 0.132, 0.014, 0.016],
	[0.110, 0.278, 0.035, 0.398, 0.009, 0.345, 0.150, 0.140, 0.014, 0.016],
	[0.170, 0.292, 0.037, 0.392, 0.010, 0.300, 0.300, 0.310, 0.016, 0.020],
	[0.230, 0.310, 0.039, 0.386, 0.012, 0.236, 0.402, 0.412, 0.018, 0.030],
	[0.300, 0.330, 0.041, 0.380, 0.014, 0.222, 0.410, 0.420, 0.020, 0.034],
	[0.420, 0.366, 0.044, 0.372, 0.018, 0.226, 0.416, 0.426, 0.022, 0.034],
	[0.540, 0.390, 0.046, 0.370, 0.022, 0.234, 0.418, 0.428, 0.024, 0.034],
	[0.650, 0.398, 0.047, 0.372, 0.026, 0.244, 0.412, 0.422, 0.024, 0.034],
	[0.780, 0.398, 0.047, 0.380, 0.026, 0.262, 0.402, 0.410, 0.024, 0.034],
	[0.900, 0.394, 0.044, 0.395, 0.022, 0.290, 0.392, 0.398, 0.024, 0.032],
	[1.020, 0.388, 0.040, 0.415, 0.018, 0.320, 0.388, 0.392, 0.022, 0.028],
	[1.130, 0.380, 0.034, 0.430, 0.012, 0.340, 0.392, 0.396, 0.018, 0.022],
]
const KEY_NAMES := ["belt", "rr", "ax", "adrop", "bx", "by", "top", "ra", "rb"]

# The wheel wells: per axle, its z, the arch's half-length, its base and rise (a superellipse of
# exponent e, concentric with the tyre), the well's inner wall and how far the ceiling slopes down
# to it. The front tyres at full lock (0.5 rad) reach 0.18 along the car at hub height.
const WELLS := [
	# axle    half_l base  rise   e    inner x slant
	[AXLE_F, 0.215, 0.00, 0.340, 2.2, 0.300, 0.030],
	[AXLE_R, 0.228, 0.00, 0.372, 2.2, 0.335, 0.026],
]
const LIP_R := 0.012                      # the arch's rolled edge
const SILL_R := 0.050                     # the sill's tuck under the body, between the arches

# The flank intake: from SCOOP_Z.x, just behind the door, it deepens to SCOOP_DEPTH and ends in a
# wall at SCOOP_Z.y, just ahead of the rear arch. Its top runs SCOOP_TOP under the side's top edge;
# its bottom falls from there to SCOOP_LOW, so it opens up toward the wheel. Inside it the shell is
# shaded dark and matte (_shell_shade), deepest at its back, so it reads as a cavity.
const SCOOP_Z := Vector2(-0.030, 0.405)
const SCOOP_DEPTH := 0.100
const SCOOP_TOP := 0.022
const SCOOP_LOW := 0.120

# Points per segment of the half-section: below the side, the bottom, the well's inner corner, its
# wall, its top corner, the ceiling, the lip; the side up to the intake, the intake's lower step, its
# back, its upper step, the side above it; above the side, the roll, the fender top, the rounding at
# A, the wall, the rounding at B, the top.
const SEGMENTS := [3, 2, 2, 2, 3, 3, 2, 1, 2, 1, 2, 8, 12, 5, 11, 5, 14]

# The canopy (build_glass(), see-through): it stands on the cowl at CANOPY_Z.x and sinks into the
# engine cover at CANOPY_Z.y. Its foot's x along the car (on the door tops beside the cockpit, then
# up the sail panels behind it) and its roof's height; it sits CANOPY_SINK into the shell. The hoop
# behind the seats is a frame across it; GLASS_TINT is the smoked
# tint, its alpha how much the glass dims what is behind it face on.
const CANOPY_Z := Vector2(-0.425, 0.370)
const CANOPY_X := [[-0.425, 0.330], [-0.400, 0.362], [-0.370, 0.389], [-0.300, 0.402], [-0.240, 0.409],
	[-0.060, 0.414], [0.060, 0.408], [0.110, 0.402], [0.170, 0.385], [0.230, 0.335], [0.280, 0.265],
	[0.320, 0.180], [0.350, 0.100], [0.370, 0.040]]
const CANOPY_Y := [[-0.425, 0.320], [-0.390, 0.372], [-0.340, 0.410], [-0.270, 0.446], [-0.180, 0.473],
	[-0.080, 0.491], [0.020, 0.498], [0.110, 0.493], [0.190, 0.475], [0.260, 0.453], [0.320, 0.433],
	[0.370, 0.418]]
const CANOPY_SINK := 0.003
const CANOPY_HOOP_Z := 0.115
# The pillars run along the glass at ring point CANOPY_PILLAR_J of 2 * CANOPY_RING_HALF (from the foot).
const CANOPY_RING_HALF := 25
const CANOPY_PILLAR_J := 10
const GLASS_TINT := Color(0.05, 0.07, 0.09, 0.30)
# The seats' centres either side of the tunnel; the driver sits on the left.
const SEAT_X := 0.168
# The door's front and rear edges and the sill line, below which the body is black.
const DOOR_Z := Vector2(-0.420, -0.050)
const SILL_Y := 0.118
# The engine cover's louvred panels either side of the spine: z from, to; x from, to.
const DECK_PANEL := Vector4(0.420, 0.830, 0.026, 0.168)
const LOUVRES := 9
# The spine down the engine cover: from under the canopy's tail (z) to where it has sunk into the
# deck (z).
const SPINE_FROM_Z := 0.330
const SPINE_END_Z := 0.960
# The rear wing: its plane's leading-edge height and chord centre (z), its half-span; the swan necks'
# x.
const WING_Y := 0.515
const WING_Z := 1.045
const WING_SPAN := 0.405
const WING_NECK_X := 0.200
# The headlamp: its housing in front view (x, y) on the fender's front slope, the DRL along its top
# edge, the two projector lenses in it.
const LAMP := [Vector2(0.300, 0.220), Vector2(0.505, 0.264), Vector2(0.517, 0.296), Vector2(0.478, 0.306),
	Vector2(0.304, 0.246)]
const LAMP_DRL := [Vector2(0.316, 0.247), Vector2(0.476, 0.301), Vector2(0.507, 0.294)]
const LAMP_LENSES := [Vector3(0.364, 0.240, 0.012), Vector3(0.418, 0.255, 0.012)]
# The bonnet's two extractor vents: |x| from, to; z from, to.
const BONNET_VENT := Vector4(0.070, 0.205, -0.960, -0.860)
# The tail: the light bar's height (the tail's face is black from just over it down).
const TAIL_LAMP_Y := 0.358

# Tyres: low-profile (half the profile, bead to tread centre).
const TYRE_FRONT := [[-0.072, 0.116], [-0.080, 0.121], [-0.084, 0.130], [-0.085, 0.142], [-0.082, 0.152],
	[-0.074, 0.1575], [-0.052, 0.1595], [0.0, 0.160]]
const TYRE_REAR := [[-0.094, 0.124], [-0.103, 0.130], [-0.107, 0.140], [-0.108, 0.155], [-0.104, 0.166],
	[-0.095, 0.1725], [-0.068, 0.1745], [0.0, 0.175]]

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.16, 0.16, 0.17)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_TRIM := Color(0.10, 0.10, 0.11)
const C_STEEL := Color(0.30, 0.30, 0.32)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.57)
const C_TAILLAMP := Color(0.92, 0.05, 0.03)
const C_SEAT := Color(0.30, 0.30, 0.32)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.17, "tail_z": 1.13, "belt_y": 0.27, "side_x": 0.52,
	"door_z": -0.235, "door_y": 0.190, "roundel_r": 0.062,
	"hood_z": -0.800, "hood_r": 0.055, "stripe_w": 0.064, "stripe_gap": 0.020,
}
const ANTENNA_POS := Vector3(0.44, 0.428, 0.92)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X_F, TYRE_R_F, AXLE_F), "FR": Vector3(WHEEL_X_F, TYRE_R_F, AXLE_F),
	"RL": Vector3(-WHEEL_X_R, TYRE_R_R, AXLE_R), "RR": Vector3(WHEEL_X_R, TYRE_R_R, AXLE_R),
}


var _canopy_x: CB.Profile
var _canopy_y: CB.Profile


func _init() -> void:
	nose_tip = -1.170
	nose_cap = 0.130
	nose_cap_y = 0.180
	nose_cap_exp = Vector2(2.6, 2.2)
	tail_tip = 1.130
	tail_cap = 0.035
	tail_cap_y = 0.250
	tail_cap_exp = Vector2(5.0, 3.0)
	station_step = 0.03
	half_ring = 0
	for n in SEGMENTS:
		half_ring += n
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	setup_shell(knots)
	_canopy_x = CB.Profile.new(CANOPY_X)
	_canopy_y = CB.Profile.new(CANOPY_Y)


## The wheel well at z: [its inner wall's x, the arch's height there (-1: none), the ceiling's slope
## down to the inner wall]. Between the axles the inner wall's x blends from one well's to the
## other's, so the section's points move smoothly along the car.
static func _well(z: float) -> Array:
	for w in WELLS:
		var t: float = absf(z - w[0]) / w[1]
		if t < 1.0:
			return [w[5], w[2] + w[3] * pow(1.0 - pow(t, w[4]), 1.0 / w[4]), w[6]]
	var f: float = smoothstep(WELLS[0][0] + WELLS[0][1], WELLS[1][0] - WELLS[1][1], z)
	return [lerpf(WELLS[0][5], WELLS[1][5], f), -1.0, 0.0]


## The arch's lip height at z, kept 1.5cm under the side's top (the bottom where there is no well).
func _ceiling(z: float) -> float:
	var bot: float = prof["bot"].at(z)
	return bot + clampf(float(_well(z)[1]) - bot, 0.0, prof["belt"].at(z) - bot - 0.015)


## The flank intake at z, on a side running from s0 up to the belt: [depth, its bottom, its top].
## Away from it the (empty) steps rest at one height on the side; they move to the intake's edges
## over 6cm either side of it, while it has no depth.
func _scoop(z: float, s0: float, belt: float) -> Array:
	var rest: float = lerpf(s0, belt, 0.55)
	var y_hi: float = belt - SCOOP_TOP
	var f: float = clampf((z - SCOOP_Z.x) / (SCOOP_Z.y - SCOOP_Z.x), 0.0, 1.0)
	var y_lo: float = lerpf(y_hi - 0.010, SCOOP_LOW, f * (2.0 - f))
	var d: float
	if z <= SCOOP_Z.y:
		d = SCOOP_DEPTH * smoothstep(SCOOP_Z.x, SCOOP_Z.x + 0.24, z)
	else:
		d = SCOOP_DEPTH * clampf(1.0 - (z - SCOOP_Z.y) / 0.006, 0.0, 1.0)
	var k: float = smoothstep(SCOOP_Z.x - 0.06, SCOOP_Z.x, z) * (1.0 - smoothstep(SCOOP_Z.y + 0.006, SCOOP_Z.y + 0.066, z))
	y_lo = clampf(lerpf(rest, y_lo, k), s0, belt)
	y_hi = clampf(lerpf(rest, y_hi, k), y_lo, belt)
	return [minf(d, (y_hi - y_lo) / 0.6), y_lo, y_hi]


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
## caps applied. Below the side: the bottom out to the well's inner wall, up it, out along the
## ceiling (sloping up to the arch's lip) and round the lip onto the side, which steps in and out
## round the intake; away from the wheels the well has no height, the ceiling is the bottom and the
## lip is the sill's tuck.
func section(z: float) -> PackedVector2Array:
	var bot: float = prof["bot"].at(z)
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var well: Array = _well(z)
	var xw: float = well[0]
	var ceil_y: float = _ceiling(z)
	var h: float = ceil_y - bot
	var c_in: float = ceil_y - minf(float(well[2]), h * 0.5)
	var ri: float = minf(0.012, (c_in - bot) * 0.3)
	var rl: float = minf(lerpf(SILL_R, LIP_R, clampf(h / 0.03, 0.0, 1.0)), (belt - ceil_y) * 0.45)
	var ceil_dir: Vector2 = (Vector2(w - rl, ceil_y) - Vector2(xw, c_in)).normalized()
	var sc: Array = _scoop(z, ceil_y + rl, belt)
	var d: float = sc[0]
	var y_lo: float = sc[1]
	var y_hi: float = sc[2]
	var segs := [
		_line(Vector2(0.0, bot), Vector2(xw - ri, bot)),
		_arc(Vector2(xw - ri, bot + ri), ri, -PI * 0.5, 0.0),
		_line(Vector2(xw, bot + ri), Vector2(xw, c_in - ri)),
		_bezier(Vector2(xw, c_in - ri), Vector2(xw, c_in), Vector2(xw, c_in) + ceil_dir * ri, 4),
		_line(Vector2(xw, c_in) + ceil_dir * ri, Vector2(w - rl, ceil_y)),
		_arc(Vector2(w - rl, ceil_y + rl), rl, -PI * 0.5, 0.0),
		_line(Vector2(w, ceil_y + rl), Vector2(w, y_lo)),
		_line(Vector2(w, y_lo), Vector2(w - d, y_lo + d * 0.30)),
		_line(Vector2(w - d, y_lo + d * 0.30), Vector2(w - d, y_hi - d * 0.15)),
		_line(Vector2(w - d, y_hi - d * 0.15), Vector2(w, y_hi)),
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


## Where the body's surface is at (x, y), searching from the nose (or from the tail): its z. The
## fender humps stand over the valleys between them and the intake cuts into the side, so the
## section's outline isn't monotonic in y (CarDesign's test assumes it is): this tests the whole
## half-section, then bisects to the surface.
func shell_z(x: float, y: float, from_front: bool) -> float:
	var q := Vector2(absf(x), y)
	var z: float = nose_tip if from_front else tail_tip
	var dz: float = 0.004 if from_front else -0.004
	for k in 600:
		if Geometry2D.is_point_in_polygon(q, section(z)):
			var lo: float = z - dz
			var hi: float = z
			for m in 12:
				var mid: float = (lo + hi) * 0.5
				if Geometry2D.is_point_in_polygon(q, section(mid)):
					hi = mid
				else:
					lo = mid
			return hi
		z += dz
	return z


## The corners of the section above the side at z: {crest, a, b, top}.
func _corners(z: float, w: float, belt: float) -> Dictionary:
	var rr: float = prof["rr"].at(z)
	var crest := Vector2(w - rr, belt + rr)
	return {
		"crest": crest, "rr": rr,
		"a": Vector2(prof["ax"].at(z), crest.y - prof["adrop"].at(z)),
		"b": Vector2(prof["bx"].at(z), prof["by"].at(z)),
		"top": prof["top"].at(z),
	}


## Above the side: the roll onto the crest, the fender top falling inward to A (level at the crest,
## so the hump reads round), the rounding at A, the wall to B, the rounding at B and the top: a
## parabola from B to the centre line, level there.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var c: Dictionary = _corners(z, w, belt)
	var rr: float = c["rr"]
	var crest: Vector2 = c["crest"]
	var a: Vector2 = c["a"]
	var bq: Vector2 = c["b"]
	var top: float = c["top"]
	var wall: float = a.distance_to(bq)
	var ra: float = minf(prof["ra"].at(z), minf(wall * 0.4, crest.distance_to(a) * 0.4))
	var rb: float = minf(prof["rb"].at(z), minf(wall * 0.4, bq.x * 0.3))
	var roll := PackedVector2Array()
	for k in 9:
		var ang: float = PI * 0.5 * k / 8.0
		roll.append(Vector2(w - rr + rr * cos(ang), belt + rr * sin(ang)))
	var q := Vector2(lerpf(crest.x, a.x, 0.5), crest.y)
	var a1: Vector2 = a + (q - a).normalized() * ra
	var a2: Vector2 = a + (bq - a).normalized() * ra
	var b1: Vector2 = bq + (a - bq).normalized() * rb
	var p1 := Vector2(bq.x * 0.5, top)
	var b2: Vector2 = bq + (p1 - bq).normalized() * rb
	return [roll, _bezier(crest, q, a1, 16), _bezier(a1, a, a2, 6), _line(a2, b1), _bezier(b1, bq, b2, 6),
		_bezier(b2, p1, Vector2(0.0, top), 24)]


# ============================================================================================
#  Body
# ============================================================================================

## Body mesh: shell, lamps, mirrors, the vents and vanes, the cockpit and the canopy's frame (its
## glass is build_glass()'s), the spine and louvres, the splitter, the wing, the tail's lamp bar,
## diffuser and exhausts.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Points on the nose (or tail) at the front-view (x, y) points of `line`, `out` proud of the surface
## along its normal, `n` samples along it.
func _on_face_line(line: Array, front: bool, out: float, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var total := 0.0
	for k in range(1, line.size()):
		total += (line[k] as Vector2).distance_to(line[k - 1])
	for s in n:
		var target: float = total * s / (n - 1)
		var k := 1
		var acc := 0.0
		while k < line.size() - 1 and acc + (line[k] as Vector2).distance_to(line[k - 1]) < target:
			acc += (line[k] as Vector2).distance_to(line[k - 1])
			k += 1
		var seg: float = (line[k] as Vector2).distance_to(line[k - 1])
		var p2: Vector2 = (line[k - 1] as Vector2).lerp(line[k], clampf((target - acc) / maxf(seg, 1e-6), 0.0, 1.0))
		var f: Array = face_frame(p2.x, p2.y, front)
		pts.append((f[0] as Vector3) + (f[1] as Vector3) * out)
	return pts


## A lamp tube: its UVs zeroed, so the headlamp material's reflector rings (drawn round the UV
## origin) stay off it.
func _lamp_tube(b, path: PackedVector3Array, r: float, mat: int, col: Color) -> void:
	var vb: int = b.vertex_count()
	b.tube(path, r, 8, mat, col, true, true)
	for k in range(vb, b.vertex_count()):
		b._uv[k] = Vector2.ZERO


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Headlamp: the black housing is the detail map's; an LED strip along its top edge and two
	# projector lenses in it.
	_lamp_tube(b, _on_face_line(LAMP_DRL, true, 0.003, 14), 0.0042, CB.M_HEADLAMP, Color(1, 1, 1))
	for l in LAMP_LENSES:
		var f: Array = face_frame(l.x, l.y, true)
		var fwd: Vector3 = ((f[1] as Vector3) + Vector3(0.0, 0.0, -0.6)).normalized()
		round_lamp(b, (f[0] as Vector3) + (f[1] as Vector3) * 0.002, fwd, l.z, CB.M_HEADLAMP, Color(1, 1, 1))
	# Mirror: a pod in the accent colour on a slim stalk from the door's top by the windscreen's foot.
	var foot := Vector3(0.448, 0.0, -0.300)
	foot.y = top_y(foot.x, foot.z) - 0.004
	var head := Vector3(0.500, foot.y + 0.040, -0.318)
	b.tube(PackedVector3Array([foot, foot.lerp(head, 0.5) + Vector3(0.0, 0.006, 0.0), head]), 0.0050, 6,
			CB.M_DARK, C_DARK, false, false)
	var mb := Basis(Vector3.UP, -0.10) * Basis(Vector3.BACK, 0.06)
	b.rbox(Transform3D(mb, head + Vector3(0.010, 0.004, 0.0)), Vector3(0.036, 0.015, 0.014), 0.010, 2,
			CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(mb, head + Vector3(0.012, 0.004, 0.0145)), Vector3(0.030, 0.011, 0.002), 0.002, 1,
			CB.M_CHROME, C_CHROME)
	# Strakes standing in the intake under the lamp.
	for k in 3:
		var sx: float = 0.320 + 0.045 * k
		var top: Array = face_frame(sx, 0.168, true)
		var low: Array = face_frame(sx, 0.112, true)
		b.tube(PackedVector3Array([(top[0] as Vector3) + (top[1] as Vector3) * 0.002,
				(low[0] as Vector3) + (low[1] as Vector3) * 0.002]), 0.0030, 6, CB.M_ALLOY, C_ALLOY_DARK, true, true)
	# Bonnet vents: painted slats across the black openings.
	var vx: float = (BONNET_VENT.x + BONNET_VENT.y) * 0.5
	for k in 5:
		var z: float = lerpf(BONNET_VENT.z + 0.012, BONNET_VENT.w - 0.012, k / 4.0)
		var y: float = top_y(vx, z)
		var slope: float = (top_y(vx, z + 0.01) - top_y(vx, z - 0.01)) / 0.02
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.40 - atan(slope)), Vector3(vx, y + 0.004, z)),
				Vector3((BONNET_VENT.y - BONNET_VENT.x) * 0.5 - 0.006, 0.0022, 0.009), 0.002, 1, CB.M_PAINT, Color(1, 1, 1))
	# Tail lamp ends: the light bar turns down the tail's corner a little.
	var corner: PackedVector3Array = _on_face_line([Vector2(0.505, TAIL_LAMP_Y), Vector2(0.540, TAIL_LAMP_Y - 0.010),
			Vector2(0.548, TAIL_LAMP_Y - 0.050)], false, 0.002, 8)
	_lamp_tube(b, corner, 0.0055, CB.M_TAILLAMP, C_TAILLAMP)
	# Diffuser fins under the tail, inside its outline.
	for x in [0.170, 0.330]:
		slab(b, PackedVector2Array([Vector2(0.950, 0.088), Vector2(1.118, 0.098), Vector2(1.118, 0.172),
				Vector2(1.040, 0.136)]), x, 0.005, CB.M_DARK, C_DARK)
	# Exhausts: a big round pipe a side of the centre, in the black panel.
	var ep := Vector3(0.072, 0.212, tail_tip + 0.012)
	b.tube(PackedVector3Array([Vector3(0.072, 0.200, 0.94), ep - Vector3(0.0, 0.0, 0.08), ep]), 0.030, 18,
			CB.M_ALLOY, C_STEEL, false, false)
	b.disc(ep - Vector3(0.0, 0.0, 0.006), Vector3.BACK, 0.025, 0.0, 18, CB.M_DARK, C_DARKER)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(ep, Vector3.BACK, PackedVector2Array([Vector2(-0.004, 0.0315), Vector2(0.0, 0.0315),
			Vector2(0.0, 0.026), Vector2(-0.004, 0.0255)]), 18, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, ep - Vector3(0.0, 0.0, 0.02))


func _centre_parts(b) -> void:
	# The tail's light bar across its face, over the black panel.
	var bar_pts: PackedVector3Array = _on_face_line([Vector2(-0.505, TAIL_LAMP_Y), Vector2(0.505, TAIL_LAMP_Y)], false,
			0.002, 33)
	_lamp_tube(b, bar_pts, 0.0055, CB.M_TAILLAMP, C_TAILLAMP)
	# Vanes across the mouth, so it reads as an opening: dark alloy blades following the nose's face.
	for y in [0.120, 0.140]:
		var vane: PackedVector3Array = _on_face_line([Vector2(-0.215, y), Vector2(0.215, y)], true, 0.002, 13)
		b.tube(vane, 0.0032, 6, CB.M_ALLOY, C_ALLOY_DARK, true, true)
	# Splitter: a black blade under the nose, following its plan, its lip just ahead of it.
	var path := PackedVector3Array()
	for k in 17:
		var x: float = lerpf(-0.455, 0.455, k / 16.0)
		path.append(Vector3(x, 0.070, shell_z(x, 0.090, true) - 0.004))
	sweep(b, path, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.002, 0.004), Vector2(0.080, 0.004),
			Vector2(0.080, -0.004), Vector2(-0.002, -0.004)]), CB.M_DARK, C_DARK)
	# Its leading edge in the accent colour.
	var lip_edge := PackedVector3Array()
	for p in path:
		lip_edge.append(p + Vector3(0.0, 0.0, -0.002))
	b.tube(lip_edge, 0.0045, 6, CB.M_ANODISED, Color(1, 1, 1), true, true)
	_cockpit(b)
	_canopy_frame(b)
	_deck_spine(b)
	# Engine cover: painted slats across the black panels either side of the spine.
	var mid_x: float = (DECK_PANEL.z + DECK_PANEL.w) * 0.5
	var half_x: float = (DECK_PANEL.w - DECK_PANEL.z) * 0.5 - 0.008
	for sx in [-1.0, 1.0]:
		for k in LOUVRES:
			var z: float = DECK_PANEL.x + 0.020 + (DECK_PANEL.y - DECK_PANEL.x - 0.040) * k / (LOUVRES - 1)
			var y: float = top_y(mid_x, z)
			var slope: float = (top_y(mid_x, z + 0.01) - top_y(mid_x, z - 0.01)) / 0.02
			b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.40 - atan(slope)), Vector3(mid_x * sx, y + 0.005, z)),
					Vector3(half_x, 0.0025, 0.012), 0.002, 1, CB.M_PAINT, Color(1, 1, 1))
	# The lip across the tail between the haunches, kicked up.
	var lip := PackedVector3Array()
	for k in 13:
		var x: float = lerpf(-0.420, 0.420, k / 12.0)
		lip.append(Vector3(x, top_y(x, 1.105) - 0.003, 1.105))
	sweep(b, lip, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(0.0, -0.004), Vector2(0.044, 0.014),
			Vector2(0.044, 0.019), Vector2(0.0, 0.001)]), CB.M_PAINT, Color(1, 1, 1))
	_wing(b)


## The deck's spine: a low rounded ridge along the centre line from under the canopy's tail down the engine
## cover, its foot buried in it, sinking into the deck by SPINE_END_Z.
func _deck_spine(b) -> void:
	var n := 40
	var m := 12
	var rows := []
	for i in n + 1:
		var z: float = lerpf(SPINE_FROM_Z, SPINE_END_Z, float(i) / n)
		var base: float = top_y(0.0, z) - 0.010
		var h: float = 0.010 + 0.020 * smoothstep(SPINE_FROM_Z, SPINE_FROM_Z + 0.08, z) \
				* (1.0 - smoothstep(SPINE_END_Z - 0.12, SPINE_END_Z, z))
		var row := PackedVector3Array()
		for j in m + 1:
			var a: float = PI * j / m
			var ca: float = cos(a)
			row.append(Vector3(0.011 * signf(ca) * pow(absf(ca), 0.55), base + h * pow(sin(a), 0.55), z))
		rows.append(row)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_PAINT, Color(1, 1, 1), false, false)
	if b._n[vb + (n / 2) * (m + 1) + m / 2].y < 0.0:
		b.flip(vb, ib)


# ============================================================================================
#  Canopy and cockpit
# ============================================================================================

## The canopy's cross-section at z, m + 1 points from its foot on the right over the roof to its
## foot on the left, `out` outside the glass (for the frames): either half a cubic that leaves the
## foot steeply, leaning in, and comes level over the roof. Where the roof is no higher than the foot
## (the cowl, the tail) it is a flat line along the shell.
func _canopy_ring(z: float, m: int, out := 0.0) -> PackedVector3Array:
	var xb: float = _canopy_x.at(z)
	var yb: float = top_y(xb, z) - CANOPY_SINK
	var yr: float = maxf(_canopy_y.at(z), yb)
	var h: float = yr - yb
	var p0 := Vector2(xb, yb)
	var p1 := Vector2(xb - 0.16 * h, yb + 0.72 * h)
	var p2 := Vector2(0.58 * xb, yr)
	var p3 := Vector2(0.0, yr)
	var half: int = m / 2
	var pts := PackedVector3Array()
	for j in m + 1:
		var t: float = 1.0 - absf(float(j - half)) / half
		var q: Vector2 = p0.bezier_interpolate(p1, p2, p3, t)
		if out != 0.0:
			var tan2: Vector2 = p0.bezier_derivative(p1, p2, p3, clampf(t, 0.001, 0.999))
			var nrm := Vector2(tan2.y, -tan2.x).normalized()
			if nrm.y < 0.0 and h > 0.002:
				nrm = -nrm
			q += nrm * out
		pts.append(Vector3(q.x if j <= half else -q.x, q.y, z))
	return pts


## The canopy's glass (regenerate_cars.gd gives it car_glass.gdshader): the arch lofted from the
## cowl to where it sinks into the engine cover. The vertex colour is its tint; its material id is
## M_DARK, which a fade (car_body_fade.gdshader) draws it as.
func build_glass(b) -> void:
	var n := 48
	var m := 28
	var rows := []
	for i in n + 1:
		rows.append(_canopy_ring(lerpf(CANOPY_Z.x, CANOPY_Z.y, float(i) / n), m))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_DARK, GLASS_TINT, false, false)
	# Outward: over the roof its normal points up.
	if b._n[vb + (n / 2) * (m + 1) + m / 2].y < 0.0:
		b.flip(vb, ib)


## The canopy's frame, dark tubes just outside the glass: a seal along its foot either side and
## across the cowl, the hoop behind the seats, and a pillar either side sweeping up from the cowl's
## corner along the glass to the hoop (the frame of a door hinged on the roof).
func _canopy_frame(b) -> void:
	b.tube(_canopy_ring(CANOPY_HOOP_Z, 32, 0.007), 0.0090, 8, CB.M_DARK, C_TRIM, true, true)
	for j in [CANOPY_PILLAR_J, 2 * CANOPY_RING_HALF - CANOPY_PILLAR_J]:
		var pillar := PackedVector3Array()
		for k in 25:
			var z: float = lerpf(CANOPY_Z.x + 0.004, CANOPY_HOOP_Z, k / 24.0)
			pillar.append(_canopy_ring(z, 2 * CANOPY_RING_HALF, 0.005)[j])
		b.tube(pillar, 0.0060, 8, CB.M_DARK, C_TRIM, true, true)
	b.tube(_canopy_ring(CANOPY_Z.x + 0.003, 16, 0.003), 0.0050, 6, CB.M_DARK, C_TRIM, true, true)
	for sx in [-1.0, 1.0]:
		var seal := PackedVector3Array()
		for k in 33:
			var z: float = lerpf(CANOPY_Z.x + 0.003, CANOPY_Z.y - 0.02, k / 32.0)
			var xb: float = _canopy_x.at(z)
			seal.append(Vector3(xb * sx, top_y(xb, z) + 0.002, z))
		b.tube(seal, 0.0050, 6, CB.M_DARK, C_TRIM, true, true)


## The cockpit under the glass: two bucket seats, the steering wheel and its binnacle in front of the
## left one, the tunnel between them.
func _cockpit(b) -> void:
	for sx in [-1.0, 1.0]:
		_seat(b, SEAT_X * sx)
	_steering_wheel(b, Vector3(-SEAT_X, 0.258, -0.175))
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(-SEAT_X, 0.300, -0.350)), Vector3(0.046, 0.012, 0.022),
			0.008, 2, CB.M_DARK, C_TRIM)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.158, -0.110)), Vector3(0.040, 0.030, 0.180), 0.012, 2, CB.M_DARK, C_TRIM)


## A bucket seat at x: a pan and a reclined back with bolsters, a stripe in the accent colour down
## its middle.
func _seat(b, x: float) -> void:
	var pan := Basis(Vector3.RIGHT, -0.08)
	b.rbox(Transform3D(pan, Vector3(x, 0.158, -0.005)), Vector3(0.066, 0.014, 0.068), 0.010, 2, CB.M_DARK, C_SEAT)
	var back := Basis(Vector3.RIGHT, 0.30)
	var bc := Vector3(x, 0.246, 0.076)
	b.rbox(Transform3D(back, bc), Vector3(0.066, 0.092, 0.015), 0.012, 2, CB.M_DARK, C_SEAT)
	b.rbox(Transform3D(back, bc - back.z * 0.014), Vector3(0.014, 0.080, 0.003), 0.002, 1, CB.M_ANODISED, Color(1, 1, 1))
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(back, bc + back.x * (s * 0.056) - back.z * 0.016), Vector3(0.012, 0.078, 0.014), 0.008, 2,
				CB.M_DARK, C_TRIM)
		b.rbox(Transform3D(pan, Vector3(x + s * 0.056, 0.170, -0.005)), Vector3(0.012, 0.012, 0.060), 0.008, 2,
				CB.M_DARK, C_TRIM)


## A steering wheel centred at c, facing the driver (up and back): a rim, three spokes, the hub with a
## badge in the accent colour, the column down into the dash.
func _steering_wheel(b, c: Vector3) -> void:
	var ax := Vector3(0.0, 0.55, 1.0).normalized()
	var r := 0.040
	var prof2 := PackedVector2Array()
	for k in 9:
		var a: float = TAU * k / 8.0
		prof2.append(Vector2(cos(a) * 0.0055, r + sin(a) * 0.0055))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, ax, prof2, 24, CB.M_DARK, C_TRIM)
	if b._n[vb].dot(ax) < 0.0:
		b.flip(vb, ib)
	var e1: Vector3 = Vector3.RIGHT
	var e2: Vector3 = ax.cross(e1).normalized()
	for d in [e1, -e1, e2 if e2.y < 0.0 else -e2]:
		b.tube(PackedVector3Array([c, c + d * (r - 0.004)]), 0.0045, 6, CB.M_DARK, C_TRIM, false, false)
	b.rbox(Transform3D(facing(ax), c + ax * 0.004), Vector3(0.014, 0.014, 0.007), 0.006, 2, CB.M_DARK, C_TRIM)
	b.disc(c + ax * 0.0115, ax, 0.007, 0.0, 12, CB.M_ANODISED, Color(1, 1, 1))
	b.tube(PackedVector3Array([c, c - ax * 0.09]), 0.007, 8, CB.M_DARK, C_DARK, false, false)


## The shell's shade (CarDesign): the flank intake's cavity darkens with depth, matte at the back;
## the cockpit's tub under the glass is dark and dull.
func _shell_shade(p: Vector3) -> float:
	var x: float = absf(p.x)
	var z: float = p.z
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	if z > CANOPY_Z.x and z < CANOPY_Z.y and x < _canopy_x.at(z) - 0.008:
		var a: Vector2 = _corners(z, w, belt)["a"]
		if p.y < a.y - 0.008:
			return 0.45
	if z > SCOOP_Z.x and z < SCOOP_Z.y + 0.007 and x < w - 0.002 and x > w - SCOOP_DEPTH - 0.010 \
			and p.y > SILL_Y - 0.02 and p.y < belt - 0.004:
		return lerpf(1.0, 0.16, smoothstep(0.0, 0.75, (w - x) / SCOOP_DEPTH))
	return 1.0


## A cubic Bézier through p0..p3 in (z, y), n + 1 points at x.
static func _cubic_yz(x: float, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for k in n + 1:
		var q: Vector2 = p0.bezier_interpolate(p1, p2, p3, float(k) / n)
		pts.append(Vector3(x, q.y, q.x))
	return pts


## The rear wing: a cambered plane over the tail between two endplates, hung from two swan necks
## that rise off the engine cover and hook over onto its top.
func _wing(b) -> void:
	var plane := PackedVector3Array()
	for k in 9:
		plane.append(Vector3(lerpf(-WING_SPAN, WING_SPAN, k / 8.0), WING_Y, WING_Z))
	sweep(b, plane, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.060, 0.000), Vector2(-0.054, 0.007),
			Vector2(-0.030, 0.0115), Vector2(0.010, 0.0145), Vector2(0.058, 0.0205), Vector2(0.062, 0.017),
			Vector2(0.020, 0.0065), Vector2(-0.025, -0.0030), Vector2(-0.052, -0.0035)]), CB.M_PAINT, Color(1, 1, 1))
	for sx in [-1.0, 1.0]:
		slab(b, PackedVector2Array([Vector2(WING_Z - 0.066, WING_Y - 0.018), Vector2(WING_Z + 0.068, WING_Y - 0.008),
				Vector2(WING_Z + 0.070, WING_Y + 0.036), Vector2(WING_Z - 0.050, WING_Y + 0.020)]),
				(WING_SPAN + 0.004) * sx, 0.006, CB.M_ANODISED, Color(1, 1, 1))
		var x: float = WING_NECK_X * sx
		var foot := Vector2(WING_Z - 0.245, top_y(absf(x), WING_Z - 0.245) - 0.006)
		var neck: PackedVector3Array = _cubic_yz(x, foot, foot + Vector2(0.050, 0.080),
				Vector2(WING_Z - 0.030, WING_Y + 0.052), Vector2(WING_Z + 0.010, WING_Y + 0.010), 16)
		sweep(b, neck, Vector3.RIGHT, Vector3(0.0, -1.0, 0.3), PackedVector2Array([Vector2(-0.005, -0.014),
				Vector2(0.005, -0.014), Vector2(0.005, 0.014), Vector2(-0.005, 0.014)]), CB.M_DARK, C_DARK)


# ============================================================================================
#  Wheels
# ============================================================================================

## A front wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1).
func build_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_FRONT, 0.116, 0.020)


## A rear wheel: the broader tyre, its rim's face set deeper (a deeper dish).
func build_rear_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_REAR, 0.124, 0.032)


## A low-profile tyre (half profile `half`) on a rim of radius rim_r with five pairs of slim spokes,
## the hub standing proud of their outer ends (a concave face) `dish` in from the rim's lip, and a
## centre-lock nut.
func _wheel(b, side: float, half: Array, rim_r: float, dish: float) -> void:
	tyre(b, half, 48, C_RUBBER)
	var hw: float = -float(half[0][0])
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - dish
	# Rim: the lip over the bead, the dish down to the spokes' ends, the barrel behind.
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.012, rim_r), Vector2(lip_x - 0.002, rim_r + 0.006),
			Vector2(lip_x + 0.003, rim_r + 0.004), Vector2(lip_x + 0.004, rim_r - 0.003),
			Vector2(lip_x, rim_r - 0.008)]), 48, CB.M_RIM, C_RIM, "out", Vector3(lip_x - 0.03, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x, rim_r - 0.008), Vector2(face_x + 0.004, rim_r - 0.012),
			Vector2(face_x, rim_r - 0.016)]), 48, CB.M_RIM, C_RIM_BARREL, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(face_x, rim_r - 0.016), Vector2(face_x - 0.006, rim_r - 0.006),
			Vector2(-hw + 0.012, rim_r - 0.004), Vector2(-hw + 0.004, rim_r + 0.002)]), 48, CB.M_RIM, C_RIM_BARREL, "in")
	# Behind the spokes: a dark back and the brake disc.
	b.disc(Vector3(face_x - 0.034, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.010, 0.0, 32, CB.M_DARK, C_DARKER)
	b.disc(Vector3(face_x - 0.024, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.022, 0.038, 32, CB.M_ALLOY, C_ALLOY_DARK)
	# Five pairs of spokes, each pair splitting from the hub toward the rim.
	for k in 5:
		for s in [-1.0, 1.0]:
			spoke(b, TAU * k / 5.0 + s * 0.055, s * 0.105, 0.034, rim_r - 0.011, face_x + 0.012, face_x, 0.0065,
					0.0085, 0.010, CB.M_RIM, C_RIM)
	# Hub, then the centre-lock nut: a hex in the accent colour, a chrome cap.
	wheel_lathe(b, PackedVector2Array([Vector2(face_x - 0.004, 0.040), Vector2(face_x + 0.014, 0.040),
			Vector2(face_x + 0.019, 0.033)]), 24, CB.M_RIM, C_RIM, "out", Vector3(face_x, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.019, 0.0, 0.0), Vector3.RIGHT, 0.033, 0.0, 24, CB.M_RIM, C_RIM)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(face_x + 0.019, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.025),
			Vector2(0.013, 0.025), Vector2(0.015, 0.021)]), 6, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(face_x + 0.012, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.034, 0.0, 0.0), Vector3.RIGHT, 0.021, 0.0, 6, CB.M_ANODISED, Color(1, 1, 1))
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(face_x + 0.034, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.011),
			Vector2(0.004, 0.010), Vector2(0.006, 0.0)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(face_x + 0.032, 0.0, 0.0))
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	return {"lamp": PackedVector2Array(LAMP)}


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var gap := 0.0
	var black := 0.0
	var chrome := 0.0
	var x: float = absf(p.x)
	var z: float = p.z
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var c: Dictionary = _corners(z, w, belt)
	var a: Vector2 = c["a"]
	var bq: Vector2 = c["b"]
	var well: Array = _well(z)
	# The wells' inner walls and ceilings; the underside.
	if n.x > 0.5 and x < float(well[0]) + 0.003 and p.y < _ceiling(z) + 0.004:
		black = 1.0
	if n.y < -0.55:
		black = 1.0
	# The sills, the nose's chin and the tail's lower corners: black below the sill line.
	if n.x > 0.25 or n.z < -0.25:
		black = maxf(black, _cover(p.y - SILL_Y, fp))
	# The intake: everything in the recess.
	if z > SCOOP_Z.x and z < SCOOP_Z.y + 0.007 and x < w - 0.0008 and p.y > SILL_Y - 0.01 and p.y < belt:
		black = 1.0
	# Under the canopy's glass: the dash, the cockpit's tub, the bulkhead and the deck behind it are
	# black trim.
	var under_glass: bool = z > CANOPY_Z.x - 0.004 and z < CANOPY_Z.y and x < _canopy_x.at(z) - 0.004
	if under_glass:
		black = 1.0
	# Engine cover: the black panels under the slats either side of the spine.
	if n.y > 0.5:
		var pz: float = (DECK_PANEL.x + DECK_PANEL.y) * 0.5
		var px: float = (DECK_PANEL.z + DECK_PANEL.w) * 0.5
		var d_deck: float = _sd_box(Vector2(x - px, z - pz), Vector2((DECK_PANEL.w - DECK_PANEL.z) * 0.5,
				(DECK_PANEL.y - DECK_PANEL.x) * 0.5)) - 0.006
		black = maxf(black, _cover(d_deck, fp))
		# Bonnet: two extractor vents either side of the centre, slotted.
		var vx: float = (BONNET_VENT.x + BONNET_VENT.y) * 0.5
		var vz: float = (BONNET_VENT.z + BONNET_VENT.w) * 0.5
		var d_vent: float = _sd_box(Vector2(x - vx, z - vz), Vector2((BONNET_VENT.y - BONNET_VENT.x) * 0.5,
				(BONNET_VENT.w - BONNET_VENT.z) * 0.5)) - 0.008
		if d_vent < 0.02:
			black = maxf(black, _cover(d_vent, fp))
			var slats: float = absf(fposmod(z - BONNET_VENT.z, 0.020) - 0.010) - 0.0035
			gap = maxf(gap, _cover(-slats, fp) * _cover(d_vent + 0.004, fp))
	# Headlamp: the black housing on the fender's front slope, a chrome reflector line in it.
	if n.z < -0.10 and z < -0.70:
		var d_lamp: float = _sd_poly(Vector2(x, p.y), sh["lamp"]) - 0.003
		black = maxf(black, _cover(d_lamp, fp))
		var line_d: float = absf(p.y - lerpf(0.233, 0.276, clampf((x - 0.330) / 0.165, 0.0, 1.0))) - 0.0025
		chrome = maxf(chrome, _cover(maxf(line_d, d_lamp + 0.006), fp) * float(x > 0.440))
	# The nose's mouth: a broad black intake under the nose's point, and one under each lamp.
	if n.z < -0.25 and z < -0.95:
		var mouth: float = maxf(absf(p.y - 0.134) - 0.030, x - 0.250 + (p.y - 0.104) * 0.5)
		var side_in: float = maxf(absf(p.y - 0.142) - 0.032 + (x - 0.290) * 0.12, maxf(0.288 - x, x - 0.462))
		black = maxf(black, _cover(minf(mouth, side_in), fp))
	# Tail: black from just over the light bar down.
	if n.z > 0.35:
		black = maxf(black, _cover(p.y - TAIL_LAMP_Y - 0.014, fp))
	# Door shut lines: front and rear edges and the sill on the side, the edges on across the
	# shoulder to the window.
	if n.x > 0.5 and x > w - 0.006:
		var dz: float = minf(absf(z - DOOR_Z.x), absf(z - DOOR_Z.y))
		var dd: float = maxf(dz, SILL_Y + 0.006 - p.y)
		if z > DOOR_Z.x and z < DOOR_Z.y:
			dd = minf(dd, absf(p.y - (SILL_Y + 0.006)))
		if z > DOOR_Z.x - 0.003 and z < DOOR_Z.y + 0.003:
			gap = maxf(gap, _cover(dd - 0.0022, fp))
	elif n.y > 0.3 and x > a.x and not under_glass:
		var dz2: float = minf(absf(z - DOOR_Z.x), absf(z - DOOR_Z.y))
		gap = maxf(gap, _cover(dz2 - 0.0022, fp))
	# Lids: the bonnet's edges along the valley beside the humps.
	if n.y > 0.5 and x < a.x and z > -1.04 and z < CANOPY_Z.x - 0.03:
		gap = maxf(gap, _cover(absf(x - (bq.x - 0.012)) - 0.0022, fp))
		gap = maxf(gap, _cover(absf(z + 1.020) - 0.0022, fp) * float(x < bq.x - 0.012))
	return Color(0.0, gap, chrome, black)
