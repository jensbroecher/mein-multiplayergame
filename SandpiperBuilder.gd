# SandpiperBuilder.gd
#
# The Sandpiper: a 1960s-style beach buggy (an original design with a made-up name). A one-piece
# fibreglass tub: rounded front fenders standing up as humps either side of a low domed bonnet, two
# chrome bucket headlamps on their crests; behind the front wheels the fenders sweep down into the low,
# door-less sides of an open two-seat cockpit, and rise again into broad rear fenders over fat tyres,
# which curl down at the back into a low tail. Between the rear fenders the engine bay is open: an
# air-cooled flat-four on show, its chrome fan shroud and alternator on top, twin carburettors under
# chrome air cleaners, finned cylinders and chrome rocker covers out at the sides, the crank pulley and
# its belt hanging out over the tail above a muffler with two upswept chrome pipes. A low windscreen in
# a chrome frame on the cowl, a padded roll bar in the accent colour with braces back over the engine,
# white tuck-and-roll buckets, a wood-rimmed wheel, chrome nerf bars front, back and along the sills.
# Narrow ribbed front tyres, fat block-tread rears (build_rear_wheel), both on eight-spoke rims with
# polished lips, the rears deep-dished. The car rakes forward: the front hubs are lower.
#
# What sets it apart from the other buggies (the Shadow, the Centurion, the Vortex): no cage, no wing,
# no flares; rounded and low, the fenders part of the body, the engine bare at the back.
#
# The section (section(), overridden, after the Nocturne's) cuts the wheel wells as notches below the
# side: the bottom steps up the well's inner wall and out under the arch. Above the side, keyed along
# the car (KEYS): a roll onto the fender's crest, the fender top falling inward to A, a wall from A to
# B, and the top from B to the centre line. Over the bonnet B lies in the valley below A and the top is
# the bonnet's dome; over the cowl B rises above A; in the cockpit the wall runs down inside the tub to
# B on the floor and the top is the floor (a trough); behind the seats the rear deck, then the engine
# bay, another trough between the rear fenders. The tail cap (_cap(), overridden) only squashes the
# section toward the engine bay's floor line, so the rear fenders curl down to it and the bay stays open
# behind, instead of closing over it toward a point.
extends "res://CarDesign.gd"

# Wheels: narrow fronts, fat rears, each hub at its tyre's radius.
const AXLE_F := -0.640
const AXLE_R := 0.600
const WHEEL_X_F := 0.488
const WHEEL_X_R := 0.520
const TYRE_R_F := 0.215
const TYRE_R_R := 0.255

# The side (w) and the bottom (bot) along the car.
const W_KNOTS := [[-1.060, 0.330], [-1.020, 0.430], [-0.960, 0.505], [-0.880, 0.552], [-0.780, 0.574],
	[-0.640, 0.580], [-0.520, 0.576], [-0.440, 0.562], [-0.370, 0.528], [-0.300, 0.494], [-0.200, 0.474],
	[-0.050, 0.468], [0.100, 0.472], [0.200, 0.492], [0.290, 0.548], [0.380, 0.602], [0.480, 0.626],
	[0.600, 0.632], [0.740, 0.628], [0.860, 0.612], [0.950, 0.592]]
const BOT_KNOTS := [[-1.060, 0.250], [-1.000, 0.215], [-0.900, 0.195], [-0.700, 0.185], [-0.400, 0.172],
	[0.300, 0.172], [0.600, 0.190], [0.800, 0.205], [0.950, 0.215]]

# The section above the side, keyframed along the car. Per row: z; belt (the top of the vertical side);
# rr (the roll over it: the crest is at belt + rr); ax, adrop (A: the fender top's inner end, adrop
# below the crest); bx, by (B: where the wall meets the top); top (the centre line); ra, rb (the
# rounding at A and at B).
const KEYS := [
	# z       belt   rr     ax     adrop  bx     by     top    ra     rb
	[-1.060, 0.250, 0.030, 0.240, 0.002, 0.180, 0.272, 0.280, 0.020, 0.020],  # nose tip (capped)
	[-0.990, 0.300, 0.040, 0.310, 0.015, 0.235, 0.300, 0.312, 0.030, 0.030],  # the fenders rise off the nose
	[-0.900, 0.380, 0.045, 0.355, 0.035, 0.262, 0.345, 0.365, 0.040, 0.040],
	[-0.800, 0.450, 0.045, 0.365, 0.043, 0.272, 0.392, 0.414, 0.045, 0.045],
	[-0.720, 0.488, 0.040, 0.368, 0.045, 0.276, 0.420, 0.444, 0.045, 0.045],
	[-0.640, 0.498, 0.034, 0.370, 0.045, 0.278, 0.438, 0.462, 0.045, 0.045],  # front axle: the crest
	[-0.560, 0.488, 0.036, 0.372, 0.040, 0.280, 0.452, 0.475, 0.045, 0.045],
	[-0.480, 0.455, 0.038, 0.380, 0.025, 0.290, 0.466, 0.486, 0.040, 0.040],  # B passes A's height
	[-0.410, 0.415, 0.040, 0.395, 0.008, 0.305, 0.480, 0.495, 0.030, 0.035],  # the fender sweeps down
	[-0.360, 0.385, 0.040, 0.420, 0.005, 0.330, 0.488, 0.500, 0.020, 0.030],  # the cowl
	[-0.346, 0.378, 0.040, 0.430, 0.005, 0.340, 0.488, 0.500, 0.018, 0.022],  # the dash's top edge
	[-0.330, 0.372, 0.036, 0.452, 0.008, 0.436, 0.200, 0.200, 0.015, 0.030],  # cockpit: rim, wall to the floor
	[-0.250, 0.352, 0.034, 0.434, 0.008, 0.418, 0.200, 0.200, 0.015, 0.030],
	[-0.100, 0.338, 0.034, 0.420, 0.008, 0.404, 0.200, 0.200, 0.015, 0.030],  # the low waist
	[0.060, 0.340, 0.034, 0.419, 0.008, 0.403, 0.200, 0.200, 0.015, 0.030],
	[0.180, 0.360, 0.034, 0.436, 0.008, 0.420, 0.200, 0.200, 0.015, 0.030],
	[0.268, 0.397, 0.035, 0.481, 0.008, 0.462, 0.200, 0.200, 0.015, 0.030],  # the seats' bulkhead
	[0.283, 0.405, 0.035, 0.440, 0.010, 0.330, 0.452, 0.462, 0.020, 0.025],  # rear deck
	[0.360, 0.470, 0.035, 0.380, 0.010, 0.310, 0.458, 0.466, 0.030, 0.030],
	[0.430, 0.522, 0.032, 0.350, 0.024, 0.300, 0.462, 0.468, 0.035, 0.025],  # the deck's back edge
	[0.445, 0.528, 0.032, 0.345, 0.026, 0.305, 0.285, 0.285, 0.035, 0.022],  # engine bay
	[0.520, 0.556, 0.030, 0.340, 0.030, 0.302, 0.285, 0.285, 0.040, 0.022],
	[0.600, 0.568, 0.028, 0.340, 0.030, 0.302, 0.285, 0.285, 0.040, 0.022],  # rear axle: the crest
	[0.700, 0.560, 0.030, 0.340, 0.030, 0.302, 0.285, 0.285, 0.040, 0.022],
	[0.780, 0.538, 0.034, 0.340, 0.028, 0.302, 0.285, 0.285, 0.040, 0.022],
	[0.860, 0.500, 0.038, 0.340, 0.026, 0.302, 0.285, 0.285, 0.040, 0.022],
	[0.950, 0.440, 0.040, 0.340, 0.022, 0.302, 0.285, 0.285, 0.040, 0.022],  # tail (capped)
]
const KEY_NAMES := ["belt", "rr", "ax", "adrop", "bx", "by", "top", "ra", "rb"]

# The wheel wells: per axle, its z, the arch's half-length, its base and rise (a superellipse of exponent
# e round the tyre), the well's inner wall and how far the ceiling slopes down to it. The front tyres at
# full lock (0.5 rad) reach in to x 0.335.
const WELLS := [
	# axle    half_l base  rise   e    inner x slant
	[AXLE_F, 0.275, 0.00, 0.470, 2.2, 0.312, 0.035],
	[AXLE_R, 0.310, 0.00, 0.550, 2.2, 0.372, 0.026],
]
const LIP_R := 0.012                      # the arch's rolled edge
const SILL_R := 0.040                     # the sill's tuck under the tub, between the arches

# Points per segment of the half-section: below the side, the bottom, the well's inner corner, its
# wall, its top corner, the ceiling, the lip, the side; above it, the roll, the fender top, the
# rounding at A, the wall, the rounding at B, the top.
const SEGMENTS := [3, 2, 2, 2, 4, 3, 3, 6, 10, 4, 5, 5, 10]

# Regions along the car: the cockpit (dash to the seats' bulkhead), the rear deck, the engine bay.
const COCKPIT_Z := Vector2(-0.338, 0.276)
const DECK_Z := Vector2(0.276, 0.438)
const BAY_Z := 0.438
const FLOOR_Y := 0.200
const BAY_FLOOR_Y := 0.285
# The tail cap squashes the section toward this height (the engine bay's floor line, a little under).
const TAIL_LINE_Y := 0.262

# The windscreen: its foot on the cowl (z at the centre line), its top's height, its half-width, the
# rake (radians back from upright).
const SCREEN_FOOT_Z := -0.372
const SCREEN_TOP_Y := 0.715
const SCREEN_HALF := 0.395
const SCREEN_RAKE := 0.48

# The roll bar: its hoop's z at the feet and at the top, its feet's half-width, its top's height and
# half-width; where the braces land on the rear fenders.
const HOOP_Z := Vector2(0.322, 0.352)
const HOOP_FOOT_X := 0.432
const HOOP_TOP := Vector2(0.395, 0.835)
const BRACE_FOOT := Vector3(0.352, 0.0, 0.760)

# The engine: an air-cooled flat-four across the bay, its cylinders' axes along x.
const ENG_Z := 0.810
const ENG_Y := 0.330
const BORES := [0.755, 0.865]

# Tyres (half profiles, bead to tread centre): a narrow ribbed front, a fat rear carcass under blocks.
const TYRE_F := [[-0.054, 0.124], [-0.059, 0.134], [-0.062, 0.152], [-0.062, 0.176], [-0.058, 0.195],
	[-0.051, 0.206], [-0.044, 0.2120], [-0.040, 0.2050], [-0.033, 0.2050], [-0.029, 0.2148], [-0.016, 0.2150],
	[-0.012, 0.2070], [-0.006, 0.2070], [-0.003, 0.2150], [0.0, 0.2150]]
const TYRE_R := [[-0.096, 0.132], [-0.102, 0.142], [-0.106, 0.162], [-0.106, 0.190], [-0.103, 0.211],
	[-0.096, 0.226], [-0.084, 0.235], [-0.060, 0.2395], [0.0, 0.2400]]
const TREAD_H := 0.015

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.15, 0.15, 0.16)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_STEEL := Color(0.20, 0.20, 0.21)
const C_ALLOY := Color(0.74, 0.75, 0.77)
const C_ALLOY_DARK := Color(0.42, 0.43, 0.45)
const C_CHROME := Color(0.93, 0.94, 0.96)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.58, 0.58, 0.60)
const C_TAILLAMP := Color(0.88, 0.06, 0.04)
const C_AMBER := Color(0.96, 0.55, 0.08)
const C_SEAT := Color(0.93, 0.91, 0.85)
const C_SEAT_PLEAT := Color(0.72, 0.70, 0.65)
const C_WOOD := Color(0.42, 0.22, 0.10)
const C_GAUGE := Color(0.92, 0.90, 0.84)
const C_WIRE := Color(0.10, 0.10, 0.11)
const C_PLUG := Color(0.78, 0.10, 0.06)
const C_BELT := Color(0.10, 0.10, 0.10)
const C_PAD := Color(0.07, 0.07, 0.075)
const GLASS_TINT := Color(0.60, 0.72, 0.76, 0.16)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.06, "tail_z": 0.95, "belt_y": 0.34, "side_x": 0.47,
	"door_z": -0.040, "door_y": 0.262, "roundel_r": 0.062,
	"hood_z": -0.700, "hood_r": 0.058, "stripe_w": 0.045, "stripe_gap": 0.016,
}
const ANTENNA_POS := Vector3(0.47, 0.585, 0.660)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X_F, TYRE_R_F, AXLE_F), "FR": Vector3(WHEEL_X_F, TYRE_R_F, AXLE_F),
	"RL": Vector3(-WHEEL_X_R, TYRE_R_R, AXLE_R), "RR": Vector3(WHEEL_X_R, TYRE_R_R, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.060
	nose_cap = 0.100
	nose_cap_y = 0.262
	nose_cap_exp = Vector2(2.4, 1.8)
	tail_tip = 0.950
	tail_cap = 0.130
	tail_cap_y = TAIL_LINE_Y
	tail_cap_exp = Vector2(6.0, 2.0)
	station_step = 0.025
	half_ring = 0
	for n in SEGMENTS:
		half_ring += n
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	setup_shell(knots)


## The nose cap as usual; the tail's squashes the section toward TAIL_LINE_Y and narrows it only a
## little at the very end, so the rear fenders curl down to the line and the engine bay stays open.
func _cap(z: float) -> Array:
	if z > tail_tip - tail_cap:
		var t: float = clampf((z - tail_tip + tail_cap) / tail_cap, 0.0, 1.0)
		return [Vector2(lerpf(1.0, 0.94, pow(t, 4.0)), _superellipse(t, tail_cap_exp.y)), tail_cap_y]
	return super._cap(z)


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
## ceiling (sloping up to the arch's lip) and round the lip onto the side; away from the wheels the
## well has no height, the ceiling is the bottom and the lip is the sill's tuck.
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
	var segs := [
		_line(Vector2(0.0, bot), Vector2(xw - ri, bot)),
		_arc(Vector2(xw - ri, bot + ri), ri, -PI * 0.5, 0.0),
		_line(Vector2(xw, bot + ri), Vector2(xw, c_in - ri)),
		_bezier(Vector2(xw, c_in - ri), Vector2(xw, c_in), Vector2(xw, c_in) + ceil_dir * ri, 4),
		_line(Vector2(xw, c_in) + ceil_dir * ri, Vector2(w - rl, ceil_y)),
		_arc(Vector2(w - rl, ceil_y + rl), rl, -PI * 0.5, 0.0),
		_line(Vector2(w, ceil_y + rl), Vector2(w, belt)),
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
## fender humps stand over the valleys between them, so the section's outline isn't monotonic in y
## (CarDesign's test assumes it is): this tests the whole half-section, then bisects to the surface.
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


## The cockpit's and the engine bay's insides read a little darker, as cavities.
func _shell_shade(p: Vector3) -> float:
	var x: float = absf(p.x)
	if p.z > COCKPIT_Z.x + 0.004 and p.z < COCKPIT_Z.y - 0.004:
		var a_x: float = prof["ax"].at(p.z)
		if x < a_x - 0.006 and p.y < prof["belt"].at(p.z):
			return 0.82
	if p.z > BAY_Z + 0.004 and x < prof["ax"].at(p.z) - 0.006 and p.y < prof["belt"].at(p.z) - 0.01:
		return 0.78
	return 1.0


# ============================================================================================
#  Body
# ============================================================================================

func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_windscreen_frame(b)
	_roll_bar(b)
	_cockpit(b)
	_engine(b)
	_nerf_bars(b)
	_running_gear(b)


## Right-hand parts, mirrored to the left by build_body(): the headlamp on the fender's crest, the
## indicator under it, the taillamp, the sill's nerf bar, the suspension in the wells.
func _side_parts(b) -> void:
	# Headlamp: a chrome bucket on a stalk on top of the front fender, looking ahead.
	var hz := -0.840
	var hx := 0.452
	var base := Vector3(hx, top_y(hx, hz), hz)
	var lc := base + Vector3(0.0, 0.074, -0.014)
	b.tube(PackedVector3Array([base - Vector3(0.0, 0.012, 0.0), lc - Vector3(0.0, 0.030, -0.016)]), 0.0095, 8,
			CB.M_CHROME, C_CHROME, false, true)
	b.rbox(Transform3D(Basis(), base + Vector3(0.0, 0.002, 0.0)), Vector3(0.022, 0.006, 0.026), 0.005, 1, CB.M_CHROME,
			C_CHROME)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(lc, Vector3.FORWARD, PackedVector2Array([Vector2(-0.062, 0.0), Vector2(-0.060, 0.020),
			Vector2(-0.050, 0.038), Vector2(-0.030, 0.051), Vector2(-0.008, 0.056), Vector2(0.000, 0.056)]), 22,
			CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, lc + Vector3(0.0, 0.0, 0.02))
	round_lamp(b, lc + Vector3(0.0, 0.0, -0.002), Vector3.FORWARD, 0.051, CB.M_HEADLAMP, Color(1, 1, 1))
	# Indicator: a small amber lamp on the fender's front face, low.
	var ind: Array = face_frame(0.430, 0.330, true)
	var fwd: Vector3 = ((ind[1] as Vector3) + Vector3(0.0, 0.0, -0.6)).normalized()
	round_lamp(b, (ind[0] as Vector3) + (ind[1] as Vector3) * 0.004, fwd, 0.018, CB.M_TAILLAMP, C_AMBER)
	# Taillamp: a round red lamp on the rear fender's end, looking back.
	var tl: Array = face_frame(0.470, 0.392, false)
	var back: Vector3 = ((tl[1] as Vector3) + Vector3(0.0, 0.0, 0.8)).normalized()
	var tc: Vector3 = (tl[0] as Vector3) + (tl[1] as Vector3) * 0.010
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(tc, back, PackedVector2Array([Vector2(-0.018, 0.034), Vector2(-0.004, 0.039), Vector2(0.004, 0.039),
			Vector2(0.006, 0.035)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, tc - back * 0.01)
	round_lamp(b, tc + back * 0.004, back, 0.034, CB.M_TAILLAMP, C_TAILLAMP)
	# The sill's nerf bar: a chrome tube along the side between the wheels, its ends bent in to brackets.
	var sy := 0.212
	var wx: float = prof["w"].at(-0.05)
	var bar_x: float = wx + 0.045
	var path: PackedVector3Array = _rounded([Vector3(prof["w"].at(-0.32) - 0.02, sy, -0.330),
			Vector3(bar_x, sy, -0.270), Vector3(bar_x, sy, 0.180), Vector3(prof["w"].at(0.24) - 0.02, sy, 0.245)], 0.05, 5)
	b.tube(path, 0.016, 12, CB.M_CHROME, C_CHROME, true, true)
	for z in [-0.150, 0.060]:
		b.tube(PackedVector3Array([Vector3(prof["w"].at(z) - 0.02, sy - 0.004, z), Vector3(bar_x, sy - 0.004, z)]),
				0.008, 8, CB.M_DARK, C_STEEL, false, false)
	# Front suspension: the beam's trailing arms out to the spindle, a coil-over standing in the well.
	for y in [0.168, 0.232]:
		b.tube(PackedVector3Array([Vector3(0.300, y, AXLE_F + 0.080), Vector3(0.410, y, AXLE_F + 0.050),
				Vector3(0.440, y, AXLE_F)]), 0.010, 8, CB.M_DARK, C_STEEL, true, true)
	b.rbox(Transform3D(Basis(), Vector3(0.440, 0.200, AXLE_F)), Vector3(0.018, 0.050, 0.020), 0.008, 1, CB.M_ALLOY,
			C_ALLOY_DARK)
	coilover(b, Vector3(0.400, 0.180, AXLE_F + 0.060), Vector3(0.345, 0.410, AXLE_F + 0.075), 0.018, 0.026, 6.0,
			C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)
	# Rear: the swing axle's tube out to the hub, a coil-over behind it.
	b.tube(PackedVector3Array([Vector3(0.150, TYRE_R_R, AXLE_R), Vector3(0.410, TYRE_R_R, AXLE_R)]), 0.024, 12,
			CB.M_DARK, C_STEEL, true, true)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(0.405, TYRE_R_R, AXLE_R), Vector3.RIGHT, PackedVector2Array([Vector2(-0.010, 0.040),
			Vector2(0.000, 0.042), Vector2(0.008, 0.040)]), 16, CB.M_DARK, C_STEEL)
	b.orient_away_from(vb, ib, Vector3(0.405, TYRE_R_R, AXLE_R))
	coilover(b, Vector3(0.392, TYRE_R_R - 0.010, AXLE_R + 0.070), Vector3(0.360, 0.500, AXLE_R + 0.130), 0.018,
			0.027, 6.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)


## The windscreen's frame: chrome posts from the cowl, a top rail, a rail along its foot, a mirror.
func _windscreen_frame(b) -> void:
	var left := PackedVector3Array()
	for k in 2:
		var sx: float = -1.0 if k == 0 else 1.0
		var foot: Vector3 = _screen_point(SCREEN_HALF * sx, 0.0)
		var top: Vector3 = _screen_point(SCREEN_HALF * sx, 1.0)
		b.tube(PackedVector3Array([foot - Vector3(0.0, 0.012, 0.0), top]), 0.011, 10, CB.M_CHROME, C_CHROME, true, false)
		# A hinge block at the foot.
		b.rbox(Transform3D(Basis(), foot + Vector3(0.0, 0.004, 0.0)), Vector3(0.016, 0.010, 0.020), 0.005, 1, CB.M_CHROME,
				C_CHROME)
		left.append(top)
	var rail := PackedVector3Array()
	for k in 17:
		rail.append(_screen_point(lerpf(-SCREEN_HALF, SCREEN_HALF, k / 16.0), 1.0))
	b.tube(_rounded([rail[0] + Vector3(0.0, -0.020, 0.0), rail[0], rail[16], rail[16] + Vector3(0.0, -0.020, 0.0)], 0.02,
			4), 0.011, 10, CB.M_CHROME, C_CHROME, false, false)
	var foot_rail := PackedVector3Array()
	for k in 25:
		foot_rail.append(_screen_point(lerpf(-SCREEN_HALF, SCREEN_HALF, k / 24.0), 0.0) + Vector3(0.0, 0.004, 0.0))
	b.tube(foot_rail, 0.008, 8, CB.M_CHROME, C_CHROME, true, true)
	# The rear-view mirror on a stalk from the top rail.
	var mt: Vector3 = _screen_point(0.0, 1.0)
	var mc: Vector3 = mt + Vector3(0.0, -0.040, 0.030)
	b.tube(PackedVector3Array([mt, mc]), 0.005, 6, CB.M_CHROME, C_CHROME, false, false)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.15), mc), Vector3(0.060, 0.020, 0.008), 0.008, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.15), mc + Vector3(0.0, 0.0, 0.0085)), Vector3(0.054, 0.015, 0.0015), 0.0015,
			1, CB.M_CHROME, C_CHROME)


## A point on the windscreen's plane: x across, f from its foot (0) to its top (1). The foot follows the
## cowl's curve; the plane leans back by SCREEN_RAKE.
func _screen_point(x: float, f: float) -> Vector3:
	var y0: float = top_y(0.0, SCREEN_FOOT_Z)
	var foot_y: float = _screen_foot_y(x)
	var y: float = lerpf(foot_y, SCREEN_TOP_Y, f)
	return Vector3(x, y, SCREEN_FOOT_Z + (y - y0) * tan(SCREEN_RAKE))


## The cowl's height under the windscreen's foot at x, found on the plane (a few steps).
func _screen_foot_y(x: float) -> float:
	var y0: float = top_y(0.0, SCREEN_FOOT_Z)
	var y: float = y0
	for k in 6:
		var z: float = SCREEN_FOOT_Z + (y - y0) * tan(SCREEN_RAKE)
		y = top_y(x, z)
	return y + 0.002


## The windscreen's glass: a flat pane inside the frame, both faces (car_glass culls back faces).
func build_glass(b) -> void:
	var rows := []
	for i in 13:
		var f: float = lerpf(0.02, 0.97, i / 12.0)
		var row := PackedVector3Array()
		for j in 17:
			var x: float = lerpf(-SCREEN_HALF + 0.008, SCREEN_HALF - 0.008, j / 16.0)
			row.append(_screen_point(x, f))
		rows.append(row)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_DARK, GLASS_TINT, false, false)
	b.orient_toward(vb, ib, Vector3(0.0, 0.3, -1.0))
	vb = b.vertex_count()
	ib = b.index_count()
	b.grid(rows, CB.M_DARK, GLASS_TINT, false, false)
	b.orient_toward(vb, ib, Vector3(0.0, -0.3, 1.0))


## The roll bar in the accent colour: a hoop behind the seats from the rear deck, a padded top, braces
## back over the engine to the rear fenders, a cross bar between them.
func _roll_bar(b) -> void:
	var r := 0.020
	var feet := []
	for sx in [-1.0, 1.0]:
		var fx: float = HOOP_FOOT_X * sx
		feet.append(Vector3(fx, top_y(fx, HOOP_Z.x) - 0.006, HOOP_Z.x))
	var t_l := Vector3(-HOOP_TOP.x, HOOP_TOP.y, HOOP_Z.y)
	var t_r := Vector3(HOOP_TOP.x, HOOP_TOP.y, HOOP_Z.y)
	b.tube(_rounded([feet[0], t_l, t_r, feet[1]], 0.10, 6), r, 12, CB.M_ANODISED, Color(1, 1, 1), true, true)
	# Base plates on the deck.
	for f in feet:
		b.rbox(Transform3D(Basis(), (f as Vector3) + Vector3(0.0, 0.004, 0.0)), Vector3(0.032, 0.005, 0.032), 0.004, 1,
				CB.M_DARK, C_STEEL)
	# Foam pad on the top bar.
	b.tube(PackedVector3Array([Vector3(-0.240, HOOP_TOP.y, HOOP_Z.y), Vector3(0.240, HOOP_TOP.y, HOOP_Z.y)]), 0.032, 14,
			CB.M_DARK, C_PAD, true, true)
	# Braces from the hoop's shoulders back down to the rear fenders' tops, a cross bar between them.
	var mids := []
	for sx in [-1.0, 1.0]:
		var top_c := Vector3((HOOP_TOP.x - 0.060) * sx, HOOP_TOP.y - 0.012, HOOP_Z.y)
		var bx: float = BRACE_FOOT.x * sx
		var foot := Vector3(bx, top_y(bx, BRACE_FOOT.z) - 0.006, BRACE_FOOT.z)
		b.tube(PackedVector3Array([top_c, foot]), r * 0.85, 10, CB.M_ANODISED, Color(1, 1, 1), false, true)
		b.rbox(Transform3D(Basis(), foot + Vector3(0.0, 0.004, 0.0)), Vector3(0.026, 0.005, 0.030), 0.004, 1, CB.M_DARK,
				C_STEEL)
		mids.append(top_c.lerp(foot, 0.35))
	b.tube(PackedVector3Array([mids[0], mids[1]]), r * 0.75, 10, CB.M_ANODISED, Color(1, 1, 1), false, false)


## The cockpit: two tuck-and-roll buckets, the tunnel and its levers, the steering wheel and the
## gauges on the dash.
func _cockpit(b) -> void:
	for sx in [-1.0, 1.0]:
		_seat(b, Vector3(0.205 * sx, FLOOR_Y, 0.110))
	# The tunnel down the floor's middle, the gear lever, the handbrake.
	b.rbox(Transform3D(Basis(), Vector3(0.0, FLOOR_Y, -0.020)), Vector3(0.050, 0.030, 0.300), 0.020, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(0.0, FLOOR_Y + 0.026, -0.120), Vector3(0.0, 0.350, -0.150)]), 0.0055, 6,
			CB.M_CHROME, C_CHROME, false, false)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.0, 0.356, -0.152), Vector3.UP, PackedVector2Array([Vector2(-0.016, 0.0), Vector2(-0.010, 0.015),
			Vector2(0.008, 0.016), Vector2(0.016, 0.0)]), 12, CB.M_DARK, C_WOOD)
	b.orient_away_from(vb, ib, Vector3(0.0, 0.356, -0.152))
	b.tube(PackedVector3Array([Vector3(0.0, FLOOR_Y + 0.030, 0.020), Vector3(0.0, 0.300, 0.060)]), 0.0075, 6, CB.M_DARK,
			C_DARK, false, true)
	# The steering wheel (left-hand drive): a wood rim on three chrome spokes, dished, on its column.
	var c := Vector3(-0.205, 0.488, -0.210)
	var tilt := Basis(Vector3.RIGHT, -0.85)
	var rim := PackedVector3Array()
	for k in 33:
		var a: float = TAU * k / 32.0
		rim.append(c + tilt * Vector3(cos(a) * 0.078, sin(a) * 0.078, 0.0))
	b.tube(rim, 0.0085, 8, CB.M_DARK, C_WOOD, false, false)
	for k in 3:
		var a: float = -PI * 0.5 + TAU * k / 3.0
		b.tube(PackedVector3Array([c + tilt * Vector3(0.0, 0.0, -0.022), c + tilt * Vector3(cos(a) * 0.074,
				sin(a) * 0.074, 0.0)]), 0.0042, 6, CB.M_CHROME, C_CHROME, false, false)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(c + tilt * Vector3(0.0, 0.0, -0.022), tilt * Vector3.BACK, PackedVector2Array([Vector2(-0.010, 0.020),
			Vector2(0.004, 0.019), Vector2(0.008, 0.010), Vector2(0.009, 0.0)]), 14, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, c + tilt * Vector3(0.0, 0.0, -0.04))
	b.tube(PackedVector3Array([c + tilt * Vector3(0.0, 0.0, -0.025), c + tilt * Vector3(0.0, 0.0, -0.200)]), 0.012, 8,
			CB.M_DARK, C_DARK, false, true)
	# The dash: a pod of two gauges before the driver, on the dash's face.
	var gz: float = COCKPIT_Z.x + 0.012
	var gc := Vector3(-0.205, 0.420, gz)
	b.rbox(Transform3D(Basis(), gc), Vector3(0.090, 0.040, 0.014), 0.012, 2, CB.M_DARK, C_DARK)
	for gx in [-0.045, 0.045]:
		var dc: Vector3 = gc + Vector3(gx, 0.002, 0.0145)
		b.disc(dc, Vector3.BACK, 0.028, 0.0, 20, CB.M_DARK, C_GAUGE)
		vb = b.vertex_count()
		ib = b.index_count()
		b.lathe(dc, Vector3.BACK, PackedVector2Array([Vector2(-0.004, 0.034), Vector2(0.004, 0.033), Vector2(0.006, 0.028)]),
				20, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, dc - Vector3(0.0, 0.0, 0.01))
		bar(b, dc + Vector3(0.006, 0.006, 0.0012), Vector3(0.012, 0.0014, 0.0008), CB.M_TAILLAMP, C_TAILLAMP)


## A low-back bucket seat on the floor at `at` (x, floor y, z of the cushion's middle): a cushion and a
## raked back in white vinyl with pleats, side bolsters.
func _seat(b, at: Vector3) -> void:
	var cush := Vector3(at.x, at.y + 0.048, at.z)
	b.rbox(Transform3D(Basis(), cush), Vector3(0.140, 0.040, 0.130), 0.030, 2, CB.M_DARK, C_SEAT)
	for k in 5:
		var px: float = at.x - 0.092 + 0.046 * k
		b.rbox(Transform3D(Basis(), Vector3(px, cush.y + 0.039, cush.z)), Vector3(0.0025, 0.003, 0.110), 0.002, 1,
				CB.M_DARK, C_SEAT_PLEAT)
	var rake := Basis(Vector3.RIGHT, -0.24)
	var back_c := Vector3(at.x, at.y + 0.230, at.z + 0.150)
	b.rbox(Transform3D(rake, back_c), Vector3(0.140, 0.170, 0.034), 0.030, 2, CB.M_DARK, C_SEAT)
	for k in 5:
		var px: float = -0.092 + 0.046 * k
		b.rbox(Transform3D(rake, back_c + rake * Vector3(px, -0.010, -0.033)), Vector3(0.0025, 0.135, 0.003), 0.002, 1,
				CB.M_DARK, C_SEAT_PLEAT)
	# Bolsters along the cushion's and the back's sides, a shell behind.
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(), cush + Vector3(0.132 * s, 0.020, 0.0)), Vector3(0.022, 0.036, 0.128), 0.018, 2,
				CB.M_DARK, C_SEAT)
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.132 * s, 0.0, -0.012)), Vector3(0.022, 0.165, 0.030), 0.018, 2,
				CB.M_DARK, C_SEAT)
	b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, -0.005, 0.034)), Vector3(0.150, 0.160, 0.008), 0.008, 1,
			CB.M_DARK, C_DARK)


## The engine: an air-cooled flat-four across the bay. Finned cylinders out to each side under the
## chrome fan shroud, the heads with chrome rocker covers, the alternator on top with its pulley and
## the belt down to the crank pulley at the back, twin carburettors with chrome air cleaners over the
## heads, plug leads, and the exhaust: headers into a muffler under the tail, two upswept chrome pipes.
func _engine(b) -> void:
	# Crankcase: alloy, mostly under the bay's floor.
	b.rbox(Transform3D(Basis(), Vector3(0.0, ENG_Y - 0.010, ENG_Z)), Vector3(0.105, 0.070, 0.120), 0.030, 2, CB.M_ALLOY,
			C_ALLOY_DARK)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	# Right bank (mirrored): two finned barrels, the head, the rocker cover.
	for bz in BORES:
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		var fins := PackedVector2Array()
		var x0 := 0.095
		var x1 := 0.215
		var n := 9
		for k in n:
			var xa: float = lerpf(x0, x1, float(k) / n)
			var xb: float = lerpf(x0, x1, (k + 0.5) / n)
			fins.append(Vector2(xa, 0.040))
			fins.append(Vector2(xa + 0.002, 0.052))
			fins.append(Vector2(xb - 0.002, 0.052))
			fins.append(Vector2(xb, 0.040))
		fins.append(Vector2(x1, 0.040))
		b.lathe(Vector3(0.0, ENG_Y, bz), Vector3.RIGHT, fins, 20, CB.M_ALLOY, C_ALLOY_DARK)
		b.orient_away_from(vb, ib, Vector3(0.150, ENG_Y, bz))
	b.rbox(Transform3D(Basis(), Vector3(0.240, ENG_Y, ENG_Z)), Vector3(0.026, 0.058, 0.118), 0.016, 2, CB.M_ALLOY,
			C_ALLOY)
	b.rbox(Transform3D(Basis(), Vector3(0.274, ENG_Y + 0.004, ENG_Z)), Vector3(0.012, 0.046, 0.104), 0.010, 2, CB.M_CHROME,
			C_CHROME)
	for k in 4:
		bar(b, Vector3(0.287, ENG_Y + 0.004, ENG_Z - 0.060 + 0.040 * k), Vector3(0.0025, 0.036, 0.004), CB.M_CHROME, C_CHROME)
	# Carburettor on the head's intake, a chrome air cleaner on it, the manifold down into the head.
	var cb := Vector3(0.175, 0.505, ENG_Z)
	b.tube(PackedVector3Array([Vector3(0.215, ENG_Y + 0.040, ENG_Z), Vector3(0.200, 0.440, ENG_Z), cb - Vector3(0.0, 0.03, 0.0)]),
			0.015, 10, CB.M_ALLOY, C_ALLOY, false, false)
	b.rbox(Transform3D(Basis(), cb), Vector3(0.026, 0.030, 0.030), 0.010, 2, CB.M_ALLOY, C_ALLOY)
	var vb2: int = b.vertex_count()
	var ib2: int = b.index_count()
	var ac := cb + Vector3(0.0, 0.034, 0.0)
	b.lathe(ac, Vector3.UP, PackedVector2Array([Vector2(0.0, 0.020), Vector2(0.002, 0.058), Vector2(0.010, 0.062),
			Vector2(0.034, 0.062), Vector2(0.042, 0.058), Vector2(0.046, 0.040), Vector2(0.048, 0.0)]), 22, CB.M_CHROME,
			C_CHROME)
	b.orient_away_from(vb2, ib2, ac + Vector3(0.0, 0.02, 0.0))
	b.disc(ac + Vector3(0.0, 0.048, 0.0), Vector3.UP, 0.040, 0.0, 22, CB.M_CHROME, C_CHROME)
	# Plug leads from the distributor in the middle to the head.
	for bz in BORES:
		b.tube(_rounded([Vector3(0.030, 0.475, ENG_Z - 0.060), Vector3(0.150, 0.470, bz), Vector3(0.262, 0.395, bz),
				Vector3(0.262, ENG_Y + 0.040, bz)], 0.04, 4), 0.0045, 6, CB.M_DARK, C_PLUG, false, false)
		b.rbox(Transform3D(Basis(), Vector3(0.262, ENG_Y + 0.040, bz)), Vector3(0.008, 0.012, 0.008), 0.004, 1, CB.M_DARK,
				C_DARK)
	# Header from under the head, back to the muffler under the tail.
	b.tube(_rounded([Vector3(0.225, ENG_Y - 0.050, BORES[0]), Vector3(0.225, 0.220, BORES[0] + 0.040),
			Vector3(0.200, 0.205, 0.920), Vector3(0.130, 0.205, 0.990)], 0.05, 5), 0.0145, 10, CB.M_ALLOY, C_STEEL, false,
			false)
	b.tube(_rounded([Vector3(0.225, ENG_Y - 0.050, BORES[1]), Vector3(0.225, 0.220, BORES[1] + 0.030),
			Vector3(0.150, 0.215, 0.950), Vector3(0.130, 0.215, 0.990)], 0.04, 5), 0.0145, 10, CB.M_ALLOY, C_STEEL, false,
			false)
	b.mirror_x(v0, i0)
	# The distributor between the carburettors, its cap.
	var vb3: int = b.vertex_count()
	var ib3: int = b.index_count()
	b.lathe(Vector3(0.030, 0.400, ENG_Z - 0.060), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.018), Vector2(0.060, 0.018),
			Vector2(0.075, 0.026), Vector2(0.090, 0.022), Vector2(0.095, 0.0)]), 14, CB.M_DARK, C_DARK)
	b.orient_away_from(vb3, ib3, Vector3(0.030, 0.440, ENG_Z - 0.060))
	# The fan shroud: a rounded chrome housing over the barrels' tops, the fan's round housing at its back.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.420, ENG_Z + 0.040)), Vector3(0.150, 0.048, 0.085), 0.040, 3, CB.M_CHROME,
			C_CHROME)
	var vb4: int = b.vertex_count()
	var ib4: int = b.index_count()
	var fan_c := Vector3(0.0, 0.468, ENG_Z + 0.080)
	b.lathe(fan_c, Vector3.BACK, PackedVector2Array([Vector2(-0.090, 0.090), Vector2(0.020, 0.092), Vector2(0.034, 0.084),
			Vector2(0.040, 0.060), Vector2(0.042, 0.0)]), 24, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb4, ib4, fan_c)
	# The alternator on its stand above the fan, its pulley at the back, the belt down to the crank.
	var alt_c := Vector3(0.0, 0.565, ENG_Z + 0.020)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.520, ENG_Z + 0.020)), Vector3(0.030, 0.030, 0.040), 0.010, 1, CB.M_ALLOY,
			C_ALLOY_DARK)
	b.tube(PackedVector3Array([alt_c - Vector3(0.0, 0.0, 0.070), alt_c + Vector3(0.0, 0.0, 0.070)]), 0.046, 18, CB.M_DARK,
			C_DARK, true, true)
	for k in 6:
		var zz: float = alt_c.z - 0.055 + 0.022 * k
		b.tube(PackedVector3Array([Vector3(0.0, alt_c.y, zz - 0.004), Vector3(0.0, alt_c.y, zz + 0.004)]), 0.049, 18,
				CB.M_DARK, C_STEEL, false, false)
	var alt_p := Vector3(0.0, alt_c.y, ENG_Z + 0.150)
	_pulley(b, alt_p, 0.044)
	var crank_p := Vector3(0.0, 0.300, 0.960)
	_pulley(b, crank_p, 0.068)
	for s in [-1.0, 1.0]:
		var a := alt_p + Vector3(0.044 * s, 0.0, 0.0)
		var c := crank_p + Vector3(0.068 * s, 0.0, 0.0)
		b.rbox(Transform3D(_axes_y((a - c).normalized()), (a + c) * 0.5), Vector3(0.0045, (a - c).length() * 0.5, 0.009),
				0.003, 1, CB.M_DARK, C_BELT)
	# The oil filler on the right of the alternator stand.
	b.tube(PackedVector3Array([Vector3(0.060, 0.400, ENG_Z - 0.080), Vector3(0.068, 0.490, ENG_Z - 0.090)]), 0.012, 10,
			CB.M_ALLOY, C_ALLOY, false, true)
	b.disc(Vector3(0.068, 0.4905, ENG_Z - 0.090), Vector3.UP, 0.016, 0.0, 12, CB.M_CHROME, C_CHROME)
	# The muffler across the tail under the crank pulley, two upswept chrome pipes out of its ends.
	b.tube(PackedVector3Array([Vector3(-0.170, 0.200, 1.000), Vector3(0.170, 0.200, 1.000)]), 0.040, 18, CB.M_ALLOY, C_STEEL,
			true, true)
	for s in [-1.0, 1.0]:
		var p0 := Vector3(0.150 * s, 0.215, 1.020)
		var bend := Vector3(0.190 * s, 0.235, 1.050)
		var tip := Vector3(0.215 * s, 0.395, 1.100)
		b.tube(_rounded([p0, bend, tip], 0.04, 6), 0.0165, 14, CB.M_CHROME, C_CHROME, false, false)
		var d: Vector3 = (tip - bend).normalized()
		var vb5: int = b.vertex_count()
		var ib5: int = b.index_count()
		b.lathe(tip, d, PackedVector2Array([Vector2(-0.004, 0.0165), Vector2(0.012, 0.021), Vector2(0.014, 0.019)]), 14,
				CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb5, ib5, tip - d * 0.02)
		b.disc(tip + d * 0.0125, d, 0.016, 0.0, 14, CB.M_DARK, C_DARKER)


## A V-belt pulley facing back (along +z) at c.
func _pulley(b, c: Vector3, r: float) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, Vector3.BACK, PackedVector2Array([Vector2(-0.012, r), Vector2(-0.006, r - 0.008), Vector2(0.006, r - 0.008),
			Vector2(0.012, r)]), 22, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, c)
	b.disc(c + Vector3(0.0, 0.0, 0.012), Vector3.BACK, r, r * 0.25, 22, CB.M_CHROME, C_CHROME)
	b.disc(c + Vector3(0.0, 0.0, 0.014), Vector3.BACK, r * 0.25, 0.0, 12, CB.M_DARK, C_DARK)


## A basis whose y axis is `up` (for a part laid along a direction).
static func _axes_y(up: Vector3) -> Basis:
	var x: Vector3 = up.cross(Vector3.BACK)
	if x.length_squared() < 1e-6:
		x = up.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, up, x.cross(up).normalized())


## Chrome tube bumpers: across the nose on two brackets, and a hoop behind the engine.
func _nerf_bars(b) -> void:
	var fy := 0.232
	var fz := -1.115
	b.tube(_rounded([Vector3(-0.380, 0.208, -0.960), Vector3(-0.395, fy, fz + 0.040), Vector3(-0.330, fy, fz),
			Vector3(0.330, fy, fz), Vector3(0.395, fy, fz + 0.040), Vector3(0.380, 0.208, -0.960)], 0.05, 5), 0.019, 14,
			CB.M_CHROME, C_CHROME, true, true)
	# A lower bar and two uprights tying it to the top one.
	b.tube(_rounded([Vector3(-0.250, 0.150, -1.020), Vector3(-0.250, 0.150, fz + 0.015), Vector3(0.250, 0.150, fz + 0.015),
			Vector3(0.250, 0.150, -1.020)], 0.04, 4), 0.014, 12, CB.M_CHROME, C_CHROME, true, true)
	for s in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(0.200 * s, 0.150, fz + 0.012), Vector3(0.200 * s, fy, fz)]), 0.012, 10,
				CB.M_CHROME, C_CHROME, false, false)
	# Rear: a hoop round the engine's back, from under the rear fenders.
	var ry := 0.300
	var rz := 1.135
	b.tube(_rounded([Vector3(-0.330, 0.215, 0.900), Vector3(-0.330, ry, 1.020), Vector3(-0.270, ry, rz),
			Vector3(0.270, ry, rz), Vector3(0.330, ry, 1.020), Vector3(0.330, 0.215, 0.900)], 0.06, 5), 0.018, 14,
			CB.M_CHROME, C_CHROME, true, true)
	# Its stays down to the frame horns under the engine.
	for s in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(0.230 * s, ry - 0.004, rz - 0.008), Vector3(0.200 * s, 0.180, 0.960)]), 0.010,
				8, CB.M_DARK, C_STEEL, false, false)


## Under the car: the front beam's two torsion tubes across under the nose, the transaxle under the
## engine bay, the frame horns out to the engine's mounts.
func _running_gear(b) -> void:
	for y in [0.150, 0.214]:
		b.tube(PackedVector3Array([Vector3(-0.300, y, AXLE_F + 0.080), Vector3(0.300, y, AXLE_F + 0.080)]), 0.022, 12,
				CB.M_DARK, C_STEEL, true, true)
	b.rbox(Transform3D(Basis(), Vector3(0.0, TYRE_R_R - 0.005, AXLE_R - 0.020)), Vector3(0.120, 0.060, 0.090), 0.030, 2,
			CB.M_ALLOY, C_ALLOY_DARK)
	for s in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(0.220 * s, 0.180, 0.640), Vector3(0.200 * s, 0.180, 0.960)]), 0.014, 8, CB.M_DARK,
				C_STEEL, true, true)


# ============================================================================================
#  Wheels
# ============================================================================================

## A front wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## the narrow ribbed tyre on an eight-spoke rim, a shallow dish.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_F, 52, C_RUBBER)
	_rim(b, TYRE_F, 0.118, 0.016)
	if side < 0.0:
		b.mirror_in_place()


## A rear wheel: the fat tyre with a block tread, its rim's spokes set deep (a deep dish).
func build_rear_wheel(b, side: float) -> void:
	tyre(b, TYRE_R, 56, C_RUBBER)
	var n := 20
	var rc: float = carcass_r(TYRE_R, 0.030)
	var rs: float = carcass_r(TYRE_R, 0.080)
	for k in n:
		for row in 2:
			var f: Array = wheel_frame(TAU * (k + 0.5 * row) / n)
			var r: Vector3 = f[0]
			var t: Vector3 = f[1]
			var sx: float = -1.0 if row == 0 else 1.0
			# A centre block on one side of the middle, a shoulder block on the other, staggered round.
			block(b, r * (rc + 0.4 * TREAD_H) + Vector3(0.030 * sx, 0.0, 0.0), Vector3.RIGHT, t, r, 0.026, TREAD_H, 0.022,
					0.85, CB.M_RUBBER, C_RUBBER)
			block(b, r * (rs + 0.4 * TREAD_H) + Vector3(-0.078 * sx, 0.0, 0.0), Vector3.RIGHT, t, r, 0.024, TREAD_H, 0.024,
					0.85, CB.M_RUBBER, C_RUBBER)
	_rim(b, TYRE_R, 0.126, 0.050)
	if side < 0.0:
		b.mirror_in_place()


## An eight-spoke rim of radius rim_r in the tyre `half`: a polished chrome lip, the barrel down to the
## spokes' face `dish` in, eight spokes in the rim colour from a hub, a chrome cap and lug nuts.
func _rim(b, half: Array, rim_r: float, dish: float) -> void:
	var hw: float = -float(half[0][0])
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - dish
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.012, rim_r), Vector2(lip_x - 0.002, rim_r + 0.007),
			Vector2(lip_x + 0.003, rim_r + 0.005), Vector2(lip_x + 0.004, rim_r - 0.003),
			Vector2(lip_x, rim_r - 0.009)]), 52, CB.M_CHROME, C_CHROME, "out", Vector3(lip_x - 0.03, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x, rim_r - 0.009), Vector2(face_x + 0.004, rim_r - 0.012),
			Vector2(face_x, rim_r - 0.016)]), 52, CB.M_RIM, C_RIM_BARREL, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(face_x, rim_r - 0.016), Vector2(face_x - 0.006, rim_r - 0.006),
			Vector2(-hw + 0.012, rim_r - 0.004), Vector2(-hw + 0.004, rim_r + 0.002)]), 52, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(face_x - 0.024, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.010, 0.0, 32, CB.M_DARK, C_DARKER)
	# The brake drum behind the spokes.
	wheel_lathe(b, PackedVector2Array([Vector2(face_x - 0.022, rim_r * 0.62), Vector2(face_x - 0.012, rim_r * 0.62),
			Vector2(face_x - 0.008, rim_r * 0.55)]), 28, CB.M_ALLOY, C_ALLOY_DARK, "out", Vector3(face_x - 0.03, 0.0, 0.0))
	for k in 8:
		spoke(b, TAU * k / 8.0, 0.0, 0.034, rim_r - 0.014, face_x + 0.006, face_x, 0.010, 0.013, 0.010, CB.M_RIM, C_RIM)
	wheel_lathe(b, PackedVector2Array([Vector2(face_x - 0.004, 0.044), Vector2(face_x + 0.010, 0.044),
			Vector2(face_x + 0.014, 0.038)]), 24, CB.M_RIM, C_RIM, "out", Vector3(face_x, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.014, 0.0, 0.0), Vector3.RIGHT, 0.038, 0.0, 24, CB.M_RIM, C_RIM)
	for k in 5:
		var f: Array = wheel_frame(TAU * (k + 0.5) / 5.0)
		bar(b, (f[0] as Vector3) * 0.030 + Vector3(face_x + 0.018, 0.0, 0.0), Vector3(0.004, 0.0055, 0.0055), CB.M_CHROME,
				C_CHROME)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(face_x + 0.014, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.020),
			Vector2(0.010, 0.018), Vector2(0.016, 0.011), Vector2(0.018, 0.0)]), 18, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(face_x + 0.008, 0.0, 0.0))


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var gap := 0.0
	var black := 0.0
	var x: float = absf(p.x)
	var z: float = p.z
	var well: Array = _well(z)
	# The wells' inner walls and ceilings; the underside.
	if n.x > 0.5 and x < float(well[0]) + 0.003 and p.y < _ceiling(z) + 0.004:
		black = 1.0
	if n.y < -0.55:
		black = 1.0
	# The cockpit's floor: a rubber mat up to the walls' fillets.
	if z > COCKPIT_Z.x and z < COCKPIT_Z.y and n.y > 0.5 and p.y < FLOOR_Y + 0.012:
		black = maxf(black, 0.88 * _cover(x - (prof["bx"].at(z) - 0.035), fp))
	# The engine bay's floor: the engine tray, dark.
	if z > BAY_Z + 0.005 and n.y > 0.5 and p.y < BAY_FLOOR_Y + 0.010:
		black = maxf(black, 0.80 * _cover(x - (prof["bx"].at(z) - 0.020), fp))
	# The bonnet's lid: a rounded outline on the dome between the fender humps, a hinge line at the cowl.
	if n.y > 0.5 and z < -0.40 and z > -1.0:
		var d: float = _sd_box(Vector2(x, z + 0.700), Vector2(0.170, 0.250)) - 0.050
		gap = maxf(gap, _cover(absf(d) - 0.0018, fp))
	return Color(0.0, gap, 0.0, black)
