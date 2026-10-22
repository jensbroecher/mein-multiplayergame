# NocturneBuilder.gd
#
# The Nocturne: a long-distance prototype from the classic era of the 24-hour race, a short-tail
# coupé after the 917K's lines (not its badge). A low shovel nose, two round lamps in a black recess
# on each front fender, a valley bonnet between the rounded fender humps; a narrow bubble canopy with
# a wraparound windscreen and a single wiper; the rear fenders rising into two fins with a concave
# deck between them, a louvred engine cover, and a lip across the tail. Slick tyres, narrow at the
# front and broad at the back (build_rear_wheel), on five-spoke centre-lock rims.
#
# The section (section(), overridden) carries the wheel wells like the Inferno's: below the side,
# the shell steps in to the well's inner wall and up under the arch, its ceiling sloping down inward
# so it stays under the low fender tops. Above the side, keyed along the car (KEYS): a roll onto the
# fender's crest, the fender top falling inward to A, a wall from A to B, and the top from B to the
# centre line (a parabola). Over the bonnet and the engine deck B lies below A (the wall is the
# fender's inner flank and the top the valley between the humps); over the cockpit B lies above A
# (the wall is the side glass and the top the windscreen and roof). Between them B passes A's height
# well inboard of it, so the wall never vanishes and the regions blend without a fold.
extends "res://CarDesign.gd"

# Wheels: staggered, the rears broader and a little taller (hub height = tyre radius).
const AXLE_F := -0.665
const AXLE_R := 0.625
const WHEEL_X_F := 0.440
const WHEEL_X_R := 0.445
const TYRE_R_F := 0.160
const TYRE_R_R := 0.178

# The side (w) and the bottom (bot) along the car.
const W_KNOTS := [[-1.200, 0.440], [-1.120, 0.495], [-1.040, 0.525], [-0.940, 0.543], [-0.800, 0.551],
	[-0.665, 0.553], [-0.520, 0.548], [-0.380, 0.535], [-0.200, 0.525], [0.000, 0.527], [0.200, 0.538],
	[0.400, 0.553], [0.625, 0.563], [0.850, 0.563], [1.050, 0.556], [1.200, 0.548]]
const BOT_KNOTS := [[-1.200, 0.095], [-1.120, 0.086], [-1.000, 0.072], [-0.850, 0.058], [-0.400, 0.052],
	[0.400, 0.052], [0.850, 0.070], [1.000, 0.125], [1.120, 0.185], [1.200, 0.200]]

# The section above the side, keyframed along the car. Per row: z; belt (the top of the vertical
# side); rr (the roll over it: the crest is at belt + rr); ax, adrop (A: the fender top's inner end,
# adrop below the crest); bx, by (B: where the wall meets the top); top (the centre line); ra, rb
# (the rounding at A and at B).
const KEYS := [
	# z       belt   rr     ax     adrop  bx     by     top    ra     rb
	[-1.200, 0.152, 0.024, 0.330, 0.004, 0.250, 0.170, 0.170, 0.030, 0.030],
	[-1.110, 0.168, 0.030, 0.340, 0.010, 0.258, 0.180, 0.181, 0.035, 0.035],
	[-1.030, 0.208, 0.040, 0.345, 0.022, 0.262, 0.205, 0.207, 0.040, 0.040],
	[-0.950, 0.258, 0.048, 0.345, 0.035, 0.265, 0.232, 0.235, 0.045, 0.045],
	[-0.850, 0.310, 0.054, 0.342, 0.040, 0.268, 0.260, 0.263, 0.045, 0.045],
	[-0.750, 0.342, 0.055, 0.340, 0.030, 0.270, 0.281, 0.284, 0.045, 0.045],
	[-0.665, 0.353, 0.055, 0.340, 0.025, 0.272, 0.292, 0.295, 0.045, 0.045],
	[-0.560, 0.347, 0.053, 0.342, 0.028, 0.272, 0.303, 0.306, 0.045, 0.045],
	[-0.460, 0.325, 0.048, 0.345, 0.030, 0.270, 0.318, 0.322, 0.040, 0.040],
	[-0.380, 0.298, 0.040, 0.365, 0.018, 0.262, 0.335, 0.343, 0.032, 0.035],
	[-0.300, 0.282, 0.036, 0.400, 0.010, 0.252, 0.385, 0.398, 0.025, 0.030],
	[-0.180, 0.278, 0.035, 0.412, 0.008, 0.224, 0.458, 0.475, 0.022, 0.035],
	[-0.050, 0.280, 0.035, 0.412, 0.008, 0.206, 0.500, 0.518, 0.022, 0.040],
	[0.080, 0.287, 0.036, 0.402, 0.008, 0.200, 0.505, 0.522, 0.022, 0.040],
	[0.200, 0.305, 0.040, 0.385, 0.010, 0.205, 0.478, 0.496, 0.025, 0.040],
	[0.320, 0.338, 0.046, 0.372, 0.018, 0.222, 0.432, 0.446, 0.035, 0.040],
	[0.450, 0.372, 0.052, 0.368, 0.025, 0.240, 0.402, 0.410, 0.040, 0.040],
	[0.625, 0.392, 0.055, 0.370, 0.030, 0.262, 0.384, 0.392, 0.040, 0.040],
	[0.800, 0.398, 0.055, 0.378, 0.030, 0.285, 0.375, 0.380, 0.035, 0.035],
	[0.950, 0.405, 0.050, 0.405, 0.020, 0.330, 0.362, 0.362, 0.028, 0.030],
	[1.080, 0.412, 0.044, 0.432, 0.016, 0.360, 0.360, 0.358, 0.022, 0.025],
	[1.200, 0.405, 0.036, 0.440, 0.012, 0.370, 0.372, 0.372, 0.018, 0.020],
]
const KEY_NAMES := ["belt", "rr", "ax", "adrop", "bx", "by", "top", "ra", "rb"]

# The wheel wells: per axle, its z, the arch's half-length, its base and rise (a superellipse of
# exponent e, concentric with the tyre), the well's inner wall and how far the ceiling slopes down
# to it. The front tyres at full lock (0.5 rad) reach 0.18 along the car at hub height.
const WELLS := [
	# axle    half_l base  rise   e    inner x slant
	[AXLE_F, 0.212, 0.00, 0.338, 2.2, 0.300, 0.030],
	[AXLE_R, 0.222, 0.00, 0.376, 2.2, 0.322, 0.026],
]
const LIP_R := 0.014                      # the arch's rolled edge
const SILL_R := 0.055                     # the sill's tuck under the body, between the arches

# Points per segment of the half-section: below the side, the bottom, the well's inner corner, its
# wall, its top corner, the ceiling, the lip, the side; above it, the roll, the fender top, the
# rounding at A, the wall, the rounding at B, the top.
const SEGMENTS := [3, 2, 2, 2, 3, 3, 3, 6, 8, 4, 6, 5, 12]

# The windscreen's foot on the centre line (it sweeps back toward the pillars), the roof's front and
# back, the rear window's foot; the door's front and rear edges and the sill.
const SCREEN_Z := -0.372
const ROOF_Z := Vector2(-0.040, 0.205)
const REAR_GLASS_Z := 0.380
const DOOR_Z := Vector2(-0.405, 0.170)
const SILL_Y := 0.112
# The brake duct in each flank ahead of the rear wheel: z from, to; its centre height; its half-height
# at the front (a slot) and at the back (the mouth).
const DUCT := [0.215, 0.360, 0.232, 0.006, 0.030]
# The engine cover's louvred panel (z from, to) and half-width.
const DECK_PANEL := Vector3(0.430, 0.640, 0.165)
# The headlamps: two a side on the fender's front slope (x, radius), at LAMP_Y.
const LAMPS := [[0.358, 0.036], [0.448, 0.029]]
const LAMP_Y := 0.250

# Tyres: slicks (half the profile, bead to tread centre).
const TYRE_FRONT := [[-0.062, 0.106], [-0.072, 0.114], [-0.077, 0.128], [-0.077, 0.142], [-0.073, 0.152],
	[-0.064, 0.1575], [-0.045, 0.1597], [0.0, 0.160]]
const TYRE_REAR := [[-0.092, 0.112], [-0.102, 0.120], [-0.107, 0.135], [-0.107, 0.155], [-0.103, 0.167],
	[-0.094, 0.1752], [-0.070, 0.1777], [0.0, 0.178]]

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.16, 0.16, 0.17)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_TRIM := Color(0.09, 0.09, 0.10)
const C_STEEL := Color(0.30, 0.30, 0.32)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.57)
const C_TAILLAMP := Color(0.90, 0.05, 0.03)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.20, "tail_z": 1.20, "belt_y": 0.30, "side_x": 0.52,
	"door_z": -0.115, "door_y": 0.190, "roundel_r": 0.078,
	"hood_z": -0.880, "hood_r": 0.068, "stripe_w": 0.070, "stripe_gap": 0.020,
}
const ANTENNA_POS := Vector3(0.44, 0.448, 0.90)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X_F, TYRE_R_F, AXLE_F), "FR": Vector3(WHEEL_X_F, TYRE_R_F, AXLE_F),
	"RL": Vector3(-WHEEL_X_R, TYRE_R_R, AXLE_R), "RR": Vector3(WHEEL_X_R, TYRE_R_R, AXLE_R),
}

var _lamp_z := 0.0                        # where the lamps' recess centres on the fender's slope


func _init() -> void:
	nose_tip = -1.200
	nose_cap = 0.150
	nose_cap_y = 0.155
	nose_cap_exp = Vector2(2.6, 1.6)
	tail_tip = 1.200
	tail_cap = 0.035
	tail_cap_y = 0.240
	tail_cap_exp = Vector2(5.0, 3.0)
	station_step = 0.03
	half_ring = 0
	for n in SEGMENTS:
		half_ring += n
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	setup_shell(knots)
	_lamp_z = shell_z(0.403, LAMP_Y, true)


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


# ============================================================================================
#  Body
# ============================================================================================

## Body mesh: shell, lamps, mirrors, the wiper, the engine cover's louvres, the tail.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Headlamps: two round lamps a side on the fender's front slope, in the black recess the detail
	# map draws round them, turned to look ahead rather than up the slope.
	for lamp in LAMPS:
		var f: Array = face_frame(lamp[0], LAMP_Y, true)
		var nrm: Vector3 = f[1]
		var fwd: Vector3 = (nrm + Vector3(0.0, 0.0, -0.4)).normalized()
		round_lamp(b, (f[0] as Vector3) + nrm * 0.004, fwd, lamp[1], CB.M_HEADLAMP, Color(1, 1, 1))
	# Mirror: a small painted pod on a stalk from the door's shoulder by the windscreen.
	var foot := Vector3(0.455, top_y(0.455, -0.335), -0.335)
	var head := Vector3(0.472, foot.y + 0.032, -0.325)
	b.tube(PackedVector3Array([foot - Vector3(0.0, 0.008, 0.0), head]), 0.0055, 6, CB.M_DARK, C_DARK, false, false)
	var mb := Basis(Vector3.UP, -0.12)
	b.rbox(Transform3D(mb, head + Vector3(0.008, 0.006, 0.004)), Vector3(0.034, 0.018, 0.016), 0.012, 2, CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(mb, head + Vector3(0.010, 0.006, 0.0205)), Vector3(0.028, 0.013, 0.002), 0.002, 1, CB.M_CHROME,
			C_CHROME)
	# Tail lamps: two round lamps a side on the tail's face, over the black panel.
	for x in [0.372, 0.462]:
		var tl: Array = face_frame(x, 0.332, false)
		round_lamp(b, (tl[0] as Vector3) + (tl[1] as Vector3) * 0.004, tl[1], 0.030, CB.M_TAILLAMP, C_TAILLAMP)
	# Exhausts: two pipes a side from under the body, out past the tail under the grille.
	for x in [0.085, 0.160]:
		var ep := Vector3(x, 0.150, tail_tip + 0.015)
		b.tube(PackedVector3Array([Vector3(x, 0.135, 0.90), ep - Vector3(0.0, 0.0, 0.10), ep]), 0.018, 14,
				CB.M_ALLOY, C_STEEL, false, false)
		b.disc(ep - Vector3(0.0, 0.0, 0.004), Vector3.BACK, 0.014, 0.0, 14, CB.M_DARK, C_DARKER)


func _centre_parts(b) -> void:
	# The quick-fill cap on the right front fender, behind the wheel.
	var fc := Vector3(0.455, 0.0, -0.470)
	fc.y = top_y(fc.x, fc.z)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(fc, Vector3.UP, PackedVector2Array([Vector2(-0.004, 0.026), Vector2(0.003, 0.026), Vector2(0.006, 0.020),
			Vector2(0.007, 0.0)]), 18, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, fc - Vector3(0.0, 0.01, 0.0))
	# Wiper: one long arm parked along the windscreen's foot, from a pivot left of centre.
	var piv := Vector3(-0.060, 0.0, SCREEN_Z + 0.030)
	piv.y = top_y(piv.x, piv.z) + 0.006
	var tip := Vector3(0.200, 0.0, SCREEN_Z + 0.045)
	tip.y = top_y(tip.x, tip.z) + 0.006
	b.tube(PackedVector3Array([piv, tip]), 0.0035, 6, CB.M_DARK, C_DARK, true, true)
	b.rbox(Transform3D(Basis(), piv + Vector3(0.0, 0.002, 0.0)), Vector3(0.008, 0.005, 0.008), 0.004, 1, CB.M_DARK, C_DARK)
	# Engine cover: painted slats across the black panel behind the rear window.
	for k in 6:
		var z: float = DECK_PANEL.x + 0.022 + 0.034 * k
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0.0, top_y(0.0, z) + 0.006, z)),
				Vector3(DECK_PANEL.z - 0.012, 0.0025, 0.010), 0.002, 1, CB.M_PAINT, Color(1, 1, 1))
	# Tail: a black mesh panel across the lower face, bars across it.
	var tg: Array = face_frame(0.0, 0.262, false)
	var tb: Basis = facing(tg[1])
	b.rbox(Transform3D(tb, tg[0]), Vector3(0.300, 0.050, 0.008), 0.012, 2, CB.M_DARK, C_DARKER)
	for k in 5:
		bar(b, (tg[0] as Vector3) + tb.y * (-0.036 + 0.018 * k) + tb.z * 0.007, Vector3(0.288, 0.0022, 0.003), CB.M_DARK,
				C_TRIM)
	# The gearbox in the open tail under the body, a cross-member over it.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.130, 1.040)), Vector3(0.130, 0.050, 0.110), 0.025, 2, CB.M_ALLOY, C_STEEL)
	b.tube(PackedVector3Array([Vector3(-0.40, 0.165, 1.10), Vector3(0.40, 0.165, 1.10)]), 0.012, 8, CB.M_DARK, C_DARK,
			true, true)
	# The lip across the tail between the fins, kicked up.
	var lip := PackedVector3Array()
	for k in 9:
		var x: float = lerpf(-0.355, 0.355, k / 8.0)
		lip.append(Vector3(x, top_y(x, 1.150) - 0.002, 1.150))
	sweep(b, lip, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(0.0, -0.004), Vector2(0.056, 0.016),
			Vector2(0.056, 0.021), Vector2(0.0, 0.001)]), CB.M_PAINT, Color(1, 1, 1))


# ============================================================================================
#  Wheels
# ============================================================================================

## A front wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1).
func build_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_FRONT, 0.106, 0.018)


## A rear wheel: the broad slick, its rim's face set deeper (a deeper dish).
func build_rear_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_REAR, 0.112, 0.034)


## A slick tyre (half profile `half`) on a five-spoke centre-lock rim of radius rim_r, its spokes
## set `dish` in from the rim's lip.
func _wheel(b, side: float, half: Array, rim_r: float, dish: float) -> void:
	tyre(b, half, 48, C_RUBBER)
	var hw: float = -float(half[0][0])
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - dish
	# Rim: the lip over the bead, the dish down to the spokes' face, the barrel behind.
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.012, rim_r), Vector2(lip_x - 0.002, rim_r + 0.006),
			Vector2(lip_x + 0.003, rim_r + 0.004), Vector2(lip_x + 0.004, rim_r - 0.003),
			Vector2(lip_x, rim_r - 0.008)]), 48, CB.M_RIM, C_RIM, "out", Vector3(lip_x - 0.03, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x, rim_r - 0.008), Vector2(face_x + 0.004, rim_r - 0.012),
			Vector2(face_x, rim_r - 0.016)]), 48, CB.M_RIM, C_RIM_BARREL, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(face_x, rim_r - 0.016), Vector2(face_x - 0.006, rim_r - 0.006),
			Vector2(-hw + 0.012, rim_r - 0.004), Vector2(-hw + 0.004, rim_r + 0.002)]), 48, CB.M_RIM, C_RIM_BARREL, "in")
	# Behind the spokes: a dark back, the drilled brake disc.
	b.disc(Vector3(face_x - 0.030, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.010, 0.0, 32, CB.M_DARK, C_DARKER)
	b.disc(Vector3(face_x - 0.022, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.026, 0.040, 32, CB.M_ALLOY, C_ALLOY_DARK)
	# Five spokes, broad at the rim, from a raised hub.
	for k in 5:
		spoke(b, TAU * k / 5.0, 0.0, 0.030, rim_r - 0.013, face_x + 0.008, face_x, 0.013, 0.026, 0.010, CB.M_RIM, C_RIM)
	wheel_lathe(b, PackedVector2Array([Vector2(face_x - 0.004, 0.040), Vector2(face_x + 0.010, 0.040),
			Vector2(face_x + 0.016, 0.034)]), 24, CB.M_RIM, C_RIM, "out", Vector3(face_x, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.016, 0.0, 0.0), Vector3.RIGHT, 0.034, 0.0, 24, CB.M_RIM, C_RIM)
	# The centre-lock nut: a hex in the accent colour with two ears, a chrome cap.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(face_x + 0.016, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.026),
			Vector2(0.014, 0.026), Vector2(0.016, 0.022)]), 6, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(face_x + 0.010, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.032, 0.0, 0.0), Vector3.RIGHT, 0.022, 0.0, 6, CB.M_ANODISED, Color(1, 1, 1))
	for s in [-1.0, 1.0]:
		bar(b, Vector3(face_x + 0.024, s * 0.034, 0.0), Vector3(0.006, 0.012, 0.005), CB.M_ANODISED, Color(1, 1, 1))
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(face_x + 0.032, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.012),
			Vector2(0.004, 0.011), Vector2(0.007, 0.0)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(face_x + 0.03, 0.0, 0.0))
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var black := 0.0
	var x: float = absf(p.x)
	var w: float = prof["w"].at(p.z)
	var belt: float = prof["belt"].at(p.z)
	var c: Dictionary = _corners(p.z, w, belt)
	var a: Vector2 = c["a"]
	var bq: Vector2 = c["b"]
	var well: Array = _well(p.z)
	# The wells' inner walls and ceilings; the underside.
	if n.x > 0.5 and x < float(well[0]) + 0.003 and p.y < _ceiling(p.z) + 0.004:
		black = 1.0
	if n.y < -0.55:
		black = 1.0
	# The canopy: above the door's shoulder and inboard of A.
	var canopy: bool = x < a.x - 0.004 and p.y > a.y + 0.006
	if canopy and p.z > SCREEN_Z - 0.03 and p.z < ROOF_Z.y + 0.25:
		# Windscreen: the top between the pillars, its foot sweeping back toward them.
		var pillar: float = bq.x - 0.034
		var foot: float = SCREEN_Z + 0.075 * pow(x / maxf(pillar, 0.05), 2.0)
		var d_screen: float = maxf(maxf(x - pillar, foot - p.z), p.z - ROOF_Z.x)
		glass = maxf(glass, _cover(d_screen, fp))
		# Side window: on the wall between the pillar and the shoulder, from behind the pillar's foot
		# to the door's rear edge, which leans forward toward the roof.
		var lo: float = a.y + 0.020
		var up: float = clampf((p.y - lo) / maxf(bq.y - lo, 0.01), 0.0, 1.0)
		var front: float = SCREEN_Z + 0.115 + 0.150 * up
		var back: float = DOOR_Z.y - 0.010 - 0.075 * up
		var d_side: float = maxf(maxf(maxf(lo - p.y, x - (a.x - 0.012)), (bq.x + 0.012) - x),
				maxf(front - p.z, p.z - back))
		if bq.y > a.y + 0.03:
			glass = maxf(glass, _cover(d_side, fp))
		# Rear window: the top from the roof's back edge down to the engine cover.
		var d_rear: float = maxf(maxf(x - (bq.x - 0.022), ROOF_Z.y - p.z), p.z - REAR_GLASS_Z)
		glass = maxf(glass, _cover(d_rear, fp))
	# Engine cover: a black panel under the slats.
	if n.y > 0.6:
		var mid := (DECK_PANEL.x + DECK_PANEL.y) * 0.5
		black = maxf(black, _cover(_sd_box(Vector2(x, p.z - mid), Vector2(DECK_PANEL.z, (DECK_PANEL.y - DECK_PANEL.x) * 0.5))
				- 0.006, fp))
	# The mouth: a black oval intake in the nose's face, under its lip.
	if n.z < -0.3 and p.z < -1.08:
		var m := Vector2(x / 0.165, (p.y - 0.124) / 0.020)
		black = maxf(black, _cover((m.length() - 1.0) * 0.02, fp))
	# The headlamps' recess: a black oval round both lamps on the fender's front slope.
	if n.z < -0.1 and p.z < -0.85:
		var q := Vector2((x - 0.403) / 0.088, (p.z - _lamp_z) / 0.052)
		black = maxf(black, _cover((q.length() - 1.0) * 0.05, fp))
	# Brake ducts: a slot in the flank widening back to its mouth.
	if n.x > 0.5 and x > w - 0.006 and p.z > DUCT[0] - 0.01 and p.z < DUCT[1] + 0.01:
		var f: float = clampf((p.z - DUCT[0]) / (DUCT[1] - DUCT[0]), 0.0, 1.0)
		var hh: float = lerpf(DUCT[3], DUCT[4], f * f * (3.0 - 2.0 * f))
		black = maxf(black, _cover(maxf(absf(p.y - DUCT[2]) - hh, maxf(DUCT[0] - p.z, p.z - DUCT[1])), fp))
	# Door shut lines: front and rear edges and the sill on the side, the edges on across the
	# shoulder to the window.
	if n.x > 0.5 and x > w - 0.006:
		var dz: float = minf(absf(p.z - DOOR_Z.x), absf(p.z - DOOR_Z.y))
		var d: float = maxf(dz, SILL_Y - p.y)
		if p.z > DOOR_Z.x and p.z < DOOR_Z.y:
			d = minf(d, absf(p.y - SILL_Y))
		if p.z > DOOR_Z.x - 0.003 and p.z < DOOR_Z.y + 0.003:
			gap = _cover(d - 0.0022, fp)
	elif n.y > 0.3 and x > a.x and not canopy:
		var dz2: float = minf(absf(p.z - DOOR_Z.x), absf(p.z - DOOR_Z.y))
		gap = _cover(dz2 - 0.0022, fp)
	# Lids: the bonnet's and the engine cover's edges along the valley beside the humps.
	if n.y > 0.5 and x < a.x and not canopy:
		var edge: float = absf(x - (bq.x - 0.012))
		if (p.z > -1.06 and p.z < SCREEN_Z - 0.03) or (p.z > REAR_GLASS_Z + 0.01 and p.z < 1.13):
			gap = maxf(gap, _cover(edge - 0.0022, fp))
	return Color(glass, gap, 0.0, black)
