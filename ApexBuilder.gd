# ApexBuilder.gd
#
# The Apex: a short-course race truck. A long bonnet between box-flared fenders, with a scoop; a
# compact cab with its windows closed and a visor over the windscreen carrying an LED bar; and an
# open bed showing off the running gear: a clean bed cage (two bars from the roof down to the
# tailgate, braced across, chase lights on the back bar), the rear shocks standing on a hoop (a
# coil-over and a bypass shock a side), a fuel cell, and the radiators laid back with their fans.
# A pre-runner tube bumper, nerf bars along the doors, an LED tail bar and twin exhausts; all-terrain
# tyres on six-spoke beadlock rims. Rebuilt in code from its Hunyuan model (the wheels where its
# wheels were); that model's cage was a tangle of tubes and its bed carried a spare, both gone.
#
# The section (section(), overridden) carries the wheel wells: below the side, the shell steps in
# to the well's inner wall and up under the arch, so the wells are openings under the fenders instead
# of the whole bottom lifting over the wheel, and the bed's floor can sit low between the rear wells.
# Above the side it is keyed like the Strikeforce's (KEYS): a roll over the side's top edge, a wall
# (the cab's side glass, the bed's inner wall, the fender tops lying flat beside the bonnet), a corner
# (the A-pillar and roof rail; the bed floor's fillet) and a crowned top (the bonnet, dished between
# the fender tops; the windscreen; the roof; the bed floor). The glass sits on the wall and on the
# top either side of the corner, so the A-pillars are that corner (_upper_s), and they run on down
# into the bonnet's shut lines.
extends "res://CarDesign.gd"

# Wheels: the Hunyuan model's positions (tyres 0.245 wide).
const WHEEL_X := 0.530
const AXLE_F := -0.663
const AXLE_R := 0.563
const HUB_Y := 0.2575

# The side (w), the bottom (bot) along the car: the fenders as wide as the bonnet and the bed, the cab
# narrower between them.
const W_KNOTS := [[-1.090, 0.560], [-1.040, 0.585], [-0.450, 0.585], [-0.430, 0.560], [-0.405, 0.482],
	[-0.390, 0.475], [0.240, 0.475], [0.255, 0.482], [0.275, 0.560], [0.290, 0.585], [1.100, 0.585],
	[1.150, 0.560]]
const BOT_KNOTS := [[-1.090, 0.380], [-1.040, 0.350], [-0.990, 0.310], [-0.900, 0.255], [-0.450, 0.255],
	[-0.400, 0.275], [0.250, 0.275], [0.300, 0.300], [0.850, 0.300], [0.950, 0.335], [1.050, 0.375],
	[1.150, 0.395]]

# The section above the side, keyframed along the car. Per row: z; belt (the top of the vertical
# side); rr (the roll over its top edge); rim_w (from the side in to A, where the wall starts: the
# roll, or the roll and the bed rail); bx (B's x, where the wall ends: on the bonnet the fender tops'
# inner edge); edge (the top beside the crown: bonnet, windscreen, roof, bed floor, tailgate); cx, cy
# (the corner from B onto the top at C: cy > 0 the roof's corner, < 0 the bed floor's fillet, 0
# flat); crown (< 0 dishes the bonnet between the fender tops).
# Where the bonnet turns up into the windscreen, B and C keep their x (the bonnet's crowned panel ends
# at its shut lines, x 0.392, which run on into the A-pillars) and the crown is 0, growing only slowly
# up the glass, so the windscreen's base is a straight line across the car. A crown that turned from
# the bonnet's dish to the windscreen's dome within 3cm stood a steep triangular prow under the glass,
# and the bonnet's wider panel narrowing there flared the A-pillars' feet.
const KEYS := [
	# z       belt   rr     rim_w  bx     edge   cx     cy      crown
	[-1.090, 0.600, 0.040, 0.045, 0.412, 0.640, 0.020, 0.000, -0.008],
	[-1.040, 0.615, 0.045, 0.050, 0.412, 0.660, 0.020, 0.000, -0.010],
	[-0.950, 0.630, 0.045, 0.050, 0.412, 0.675, 0.020, 0.000, -0.014],
	[-0.800, 0.640, 0.045, 0.050, 0.412, 0.685, 0.020, 0.000, -0.016],
	[-0.650, 0.640, 0.045, 0.050, 0.412, 0.685, 0.020, 0.000, -0.010],
	[-0.550, 0.640, 0.045, 0.050, 0.412, 0.685, 0.020, 0.000, 0.000],
	[-0.470, 0.640, 0.045, 0.050, 0.412, 0.685, 0.020, 0.000, 0.000],
	[-0.440, 0.640, 0.045, 0.050, 0.414, 0.696, 0.022, 0.002, 0.000],
	[-0.400, 0.620, 0.012, 0.020, 0.414, 0.728, 0.026, 0.014, 0.002],
	[-0.300, 0.620, 0.012, 0.020, 0.409, 0.812, 0.030, 0.026, 0.008],
	[-0.220, 0.620, 0.012, 0.020, 0.405, 0.875, 0.030, 0.030, 0.012],
	[0.240, 0.620, 0.012, 0.020, 0.405, 0.875, 0.030, 0.030, 0.012],
	[0.258, 0.620, 0.012, 0.020, 0.405, 0.875, 0.030, 0.030, 0.012],
	[0.285, 0.640, 0.040, 0.205, 0.375, 0.440, 0.020, -0.020, 0.000],
	[1.075, 0.640, 0.040, 0.205, 0.375, 0.440, 0.020, -0.020, 0.000],
	[1.098, 0.640, 0.040, 0.205, 0.375, 0.680, 0.020, 0.000, 0.000],
	[1.150, 0.620, 0.040, 0.205, 0.350, 0.680, 0.020, 0.000, 0.000],
]
const KEY_NAMES := ["belt", "rr", "rim_w", "bx", "edge", "cx", "cy", "crown"]

# The wheel wells: per axle, its z, the arch's half-length, its base and rise (a superellipse of
# exponent e), and the well's inner wall. Long and high enough for the front tyres at full lock
# (0.5 rad), whose corners sweep in to x 0.30 and out along the car to 0.285 from the axle.
const WELLS := [
	# axle    half_l base  rise   e    inner x
	[AXLE_F, 0.330, 0.10, 0.50, 2.4, 0.285],
	[AXLE_R, 0.310, 0.10, 0.50, 2.4, 0.385],
]
const LIP_R := 0.020
# Points per segment of the half-section: bottom, the tub's edge, the well's wall, its top corner,
# the ceiling, the fender's lip, the side; the roll, the rail, the wall, the corner, the top.
const SEGMENTS := [3, 2, 3, 2, 4, 3, 4, 4, 2, 6, 5, 10]

# Glass: the side windows stop PILLAR_PAD short of the corner (the A-pillar and roof rail), the
# windscreen starts PILLAR_PAD inboard of it; the windscreen runs from the cowl to the header (WS_Z),
# the side window from SIDE_FRONT, where the cab's side has turned up out of the fender top, back to
# SIDE_BACK.
const PILLAR_PAD := 0.004
const WS_Z := Vector2(-0.428, -0.236)
const SIDE_FRONT := -0.400
const SIDE_BACK := 0.195

# Tyres: an all-terrain carcass (half its profile, bead to tread centre) under staggered blocks.
const TYRE_HALF := [[-0.104, 0.150], [-0.114, 0.163], [-0.120, 0.180], [-0.122, 0.198], [-0.120, 0.215],
	[-0.112, 0.229], [-0.096, 0.238], [-0.060, 0.2425], [0.0, 0.2435]]
const TREAD_ROWS := 24
const BLOCK_H := 0.014

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.21, 0.21, 0.22)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_CAGE := Color(0.08, 0.08, 0.085)
const C_MESH := Color(0.18, 0.18, 0.19)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.78, 0.79, 0.81)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.57)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.09, "tail_z": 1.15, "belt_y": 0.62, "side_x": 0.585,
	"door_z": -0.10, "door_y": 0.45, "roundel_r": 0.09,
	"hood_z": -0.78, "hood_r": 0.075, "stripe_w": 0.075, "stripe_gap": 0.03,
}
const ANTENNA_POS := Vector3(0.30, 0.885, 0.14)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}

var _curve_cache := {}                    # z -> the upper section's samples, for _upper_s()


func _init() -> void:
	nose_tip = -1.090
	nose_cap = 0.050
	nose_cap_y = 0.500
	nose_cap_exp = Vector2(5.0, 3.0)
	tail_tip = 1.150
	tail_cap = 0.040
	tail_cap_y = 0.540
	tail_cap_exp = Vector2(6.0, 5.0)
	half_ring = 0
	for n in SEGMENTS:
		half_ring += n
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[5] + key[8]])
	setup_shell(knots)


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


static func _line(a: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, c])


static func _arc(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 7:
		var a: float = lerpf(a0, a1, k / 6.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## The right half of the section at z (half_ring + 1 points, bottom of the centre line to its top),
## caps applied. Below the side: the bottom out to the well's inner wall, up it, out along the
## arch's ceiling and round the fender's lip onto the side; away from the wheels the well has no
## height and the ceiling is the bottom.
func section(z: float) -> PackedVector2Array:
	var bot: float = prof["bot"].at(z)
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var well: Array = _well(z)
	var xw: float = well[0]
	var h: float = clampf(float(well[1]) - bot, 0.0, belt - bot - 0.03)
	var ceil_y: float = bot + h
	var ri: float = minf(0.012, h * 0.3)
	var rl: float = minf(LIP_R, (belt - ceil_y) * 0.45)
	var segs := [
		_line(Vector2(0.0, bot), Vector2(xw - ri, bot)),
		_arc(Vector2(xw - ri, bot + ri), ri, -PI * 0.5, 0.0),
		_line(Vector2(xw, bot + ri), Vector2(xw, ceil_y - ri)),
		_arc(Vector2(xw + ri, ceil_y - ri), ri, PI, PI * 0.5),
		_line(Vector2(xw + ri, ceil_y), Vector2(w - rl, ceil_y)),
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


## Above the side: the roll (the side's top edge rounding over), the flat on to A (the bed's rail),
## the wall (A to B), the corner (B onto the top at C) and the top, crowned toward the centre line.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var rim_w: float = prof["rim_w"].at(z)
	var rr: float = clampf(prof["rr"].at(z), 0.004, rim_w * 0.95)
	var edge: float = prof["edge"].at(z)
	var cx: float = maxf(prof["cx"].at(z), 0.003)
	var cy: float = prof["cy"].at(z)
	var crown: float = prof["crown"].at(z)
	var roll := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.5 * k / 8.0
		roll.append(Vector2(w - rr + rr * cos(a), belt + rr * sin(a)))
	var a_pt := Vector2(w - rim_w, belt + rr)
	# B is keyed by its own x, not off A, so it holds steady while the side steps in from the fender to
	# the cab; it never passes A, or the wall would lean outward.
	var b_pt := Vector2(minf(prof["bx"].at(z), a_pt.x - 0.002), edge - cy)
	var c_pt := Vector2(b_pt.x - cx, edge)
	var corner := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.5 * k / 8.0
		corner.append(Vector2(b_pt.x + (c_pt.x - b_pt.x) * (1.0 - cos(a)), b_pt.y + (c_pt.y - b_pt.y) * sin(a)))
	var x0: float = maxf(c_pt.x, 0.001)
	var top := PackedVector2Array()
	for k in 17:
		var x: float = x0 * (1.0 - k / 16.0)
		top.append(Vector2(x, edge + crown * 0.5 * (1.0 - cos((1.0 - x / x0) * PI))))
	return [roll, _line(roll[roll.size() - 1], a_pt), _line(a_pt, b_pt), corner, top]


## Body mesh: shell, lamps and grille, bumpers, nerf bars, the bed's cage, shocks, fuel cell and
## radiators, and the running gear seen in the wells.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Headlamp in the fender's front corner: a dark housing, an LED strip, an amber marker under it.
	var hl: Array = face_frame(0.43, 0.555, true)
	var hb: Basis = facing(hl[1])
	b.rbox(Transform3D(hb, hl[0]), Vector3(0.085, 0.030, 0.010), 0.010, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(hb, (hl[0] as Vector3) + hb.y * 0.006 + hb.z * 0.008), Vector3(0.072, 0.010, 0.004), 0.004, 1,
			CB.M_HEADLAMP, Color(1, 1, 1))
	b.rbox(Transform3D(hb, (hl[0] as Vector3) - hb.y * 0.016 + hb.z * 0.007), Vector3(0.060, 0.004, 0.004), 0.002, 1,
			CB.M_TAILLAMP, C_AMBER)
	# Mirror on a stalk from the door's front corner.
	b.tube(PackedVector3Array([Vector3(0.470, 0.640, -0.375), Vector3(0.545, 0.665, -0.360)]), 0.007, 6, CB.M_DARK,
			C_DARK, false, false)
	var mb := Basis(Vector3.UP, 0.18)
	b.rbox(Transform3D(mb, Vector3(0.560, 0.672, -0.348)), Vector3(0.040, 0.026, 0.020), 0.012, 2, CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(mb, Vector3(0.563, 0.672, -0.328)), Vector3(0.033, 0.019, 0.002), 0.002, 1, CB.M_CHROME, C_CHROME)
	# Door handle; a nerf bar along the sill on two mounts.
	b.rbox(Transform3D(Basis(), Vector3(0.478, 0.585, 0.13)), Vector3(0.006, 0.008, 0.032), 0.004, 1, CB.M_DARK, C_DARK)
	b.tube(_rounded([Vector3(0.43, 0.245, -0.33), Vector3(0.515, 0.232, -0.28), Vector3(0.515, 0.232, 0.17),
			Vector3(0.43, 0.245, 0.22)], 0.045), 0.016, 10, CB.M_DARK, C_CAGE, true, true)
	for z in [-0.14, 0.06]:
		b.tube(PackedVector3Array([Vector3(0.515, 0.232, z), Vector3(0.45, 0.262, z)]), 0.012, 8, CB.M_DARK, C_CAGE,
				false, false)
	# Hood pin at the bonnet's front corner.
	var pin_y: float = top_y(0.40, -0.985)
	b.rbox(Transform3D(Basis(), Vector3(0.40, pin_y + 0.003, -0.985)), Vector3(0.010, 0.005, 0.030), 0.003, 1, CB.M_DARK,
			C_DARK)
	b.tube(PackedVector3Array([Vector3(0.40, pin_y + 0.005, -1.008), Vector3(0.40, pin_y + 0.014, -1.008)]), 0.004, 6,
			CB.M_CHROME, C_CHROME, false, true)
	# Fog lamp on the front bumper.
	round_lamp(b, Vector3(0.30, 0.402, -1.153), Vector3.FORWARD, 0.024, CB.M_HEADLAMP, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.30, 0.402, -1.135)), Vector3(0.030, 0.030, 0.014), 0.010, 2, CB.M_DARK, C_DARK)
	# Tail: a lamp in each corner of the tailgate.
	var tl: Array = face_frame(0.50, 0.605, false)
	b.rbox(Transform3D(facing(tl[1]), tl[0]), Vector3(0.030, 0.050, 0.008), 0.008, 2, CB.M_TAILLAMP, C_TAILLAMP)
	# Front suspension: long A-arms out to the hub carrier, the coil-over up into the well, the
	# driveshaft and the steering link.
	var kx := 0.430
	for dz in [-0.09, 0.09]:
		b.tube(PackedVector3Array([Vector3(0.20, 0.235, AXLE_F + dz), Vector3(kx - 0.012, 0.205, AXLE_F)]), 0.012, 8,
				CB.M_DARK, C_STEEL, true, true)
	for dz in [-0.07, 0.07]:
		b.tube(PackedVector3Array([Vector3(0.22, 0.380, AXLE_F + dz), Vector3(kx - 0.014, 0.335, AXLE_F)]), 0.010, 8,
				CB.M_DARK, C_STEEL, true, true)
	b.rbox(Transform3D(Basis(), Vector3(kx, HUB_Y, AXLE_F)), Vector3(0.018, 0.072, 0.030), 0.009, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, AXLE_F), Vector3(0.53, HUB_Y, AXLE_F)]), 0.016, 10, CB.M_ALLOY,
			C_ALLOY_DARK, false, true)
	b.tube(PackedVector3Array([Vector3(0.15, 0.270, AXLE_F), Vector3(kx - 0.01, HUB_Y, AXLE_F)]), 0.010, 8, CB.M_ALLOY,
			C_ALLOY_DARK, false, false)
	b.tube(PackedVector3Array([Vector3(0.20, 0.310, AXLE_F + 0.075), Vector3(kx - 0.01, 0.300, AXLE_F + 0.045)]), 0.007,
			6, CB.M_DARK, C_STEEL, false, false)
	coilover(b, Vector3(0.380, 0.215, AXLE_F + 0.01), Vector3(0.305, 0.555, AXLE_F + 0.05), 0.017, 0.028, 7.0, C_ALLOY,
			C_ALLOY_DARK, C_CHROME, C_DARK)
	# The rear axle's end out to the wheel.
	b.tube(PackedVector3Array([Vector3(0.40, HUB_Y, AXLE_R), Vector3(0.53, HUB_Y, AXLE_R)]), 0.016, 10, CB.M_ALLOY,
			C_ALLOY_DARK, false, true)
	# The bed: a cage bar from the roof's back corner down to the tailgate; on the shock hoop a
	# coil-over and a bypass shock with its reservoir, standing up out of the floor.
	b.tube(_rounded([Vector3(0.330, 0.840, 0.240), Vector3(0.330, 0.865, 0.360), Vector3(0.310, 0.780, 0.920),
			Vector3(0.310, 0.690, 1.070)], 0.07), 0.016, 10, CB.M_DARK, C_CAGE, false, false)
	coilover(b, Vector3(0.300, 0.445, 0.550), Vector3(0.245, 0.790, 0.615), 0.016, 0.026, 7.0, C_ALLOY, C_ALLOY_DARK,
			C_CHROME, C_DARK)
	_bypass_shock(b, Vector3(0.305, 0.445, 0.710), Vector3(0.240, 0.790, 0.645))
	# Exhaust tip under the tailgate.
	b.tube(PackedVector3Array([Vector3(0.16, 0.318, 0.95), Vector3(0.16, 0.318, 1.175)]), 0.022, 14, CB.M_ALLOY,
			C_ALLOY_DARK, false, false)
	b.disc(Vector3(0.16, 0.318, 1.174), Vector3.BACK, 0.018, 0.0, 14, CB.M_DARK, C_DARKER)


## A bypass shock from lo to hi: a chrome shaft, an alloy body with its bypass lines alongside and a
## reservoir, an end cap in the accent colour.
func _bypass_shock(b, lo: Vector3, hi: Vector3) -> void:
	var ax: Vector3 = (hi - lo).normalized()
	var side: Vector3 = ax.cross(Vector3.RIGHT).normalized()
	var body_lo: Vector3 = lo.lerp(hi, 0.36)
	b.tube(PackedVector3Array([lo, body_lo]), 0.007, 6, CB.M_CHROME, C_CHROME, true, false)
	b.tube(PackedVector3Array([body_lo, hi]), 0.017, 12, CB.M_ALLOY, C_ALLOY, true, true)
	for k in 3:
		var off: Vector3 = side * 0.021 + Vector3.RIGHT * (0.008 * (k - 1))
		b.tube(PackedVector3Array([body_lo.lerp(hi, 0.08) + off, body_lo.lerp(hi, 0.92) + off]), 0.0035, 5, CB.M_DARK,
				C_DARK, true, true)
	var res_c: Vector3 = body_lo.lerp(hi, 0.75) - side * 0.032
	b.tube(PackedVector3Array([res_c - ax * 0.07, res_c + ax * 0.07]), 0.012, 10, CB.M_ALLOY, C_ALLOY, true, true)
	b.tube(PackedVector3Array([hi - ax * 0.012, hi + ax * 0.004]), 0.019, 12, CB.M_ANODISED, Color(1, 1, 1), true, true)


func _centre_parts(b) -> void:
	var tube_r := 0.016
	# Grille: a dark panel across the face with a mesh of bars, a bar in the accent colour under it.
	var gr: Array = face_frame(0.0, 0.505, true)
	var gb: Basis = facing(gr[1])
	b.rbox(Transform3D(gb, gr[0]), Vector3(0.300, 0.062, 0.012), 0.016, 2, CB.M_DARK, C_DARKER)
	for k in 5:
		bar(b, (gr[0] as Vector3) + gb.y * (-0.044 + 0.022 * k) + gb.z * 0.011, Vector3(0.285, 0.0028, 0.003), CB.M_DARK,
				C_MESH)
	for k in 17:
		bar(b, (gr[0] as Vector3) + gb.x * (-0.272 + 0.034 * k) + gb.z * 0.011, Vector3(0.0028, 0.052, 0.003), CB.M_DARK,
				C_MESH)
	b.rbox(Transform3D(gb, (gr[0] as Vector3) - gb.y * 0.075 + gb.z * 0.004), Vector3(0.24, 0.004, 0.006), 0.003, 1,
			CB.M_ANODISED, Color(1, 1, 1))
	# Pre-runner bumper: the main tube round the front, two uprights to the face; a skid plate under
	# the nose; tow hooks.
	b.tube(_rounded([Vector3(-0.480, 0.375, -1.030), Vector3(-0.420, 0.375, -1.135), Vector3(0.420, 0.375, -1.135),
			Vector3(0.480, 0.375, -1.030)], 0.07), 0.021, 12, CB.M_DARK, C_CAGE, true, true)
	for x in [-0.17, 0.17]:
		b.tube(_rounded([Vector3(x, 0.375, -1.135), Vector3(x, 0.445, -1.128), Vector3(x, 0.455, -1.085)], 0.03), 0.014,
				8, CB.M_DARK, C_CAGE, false, true)
	var skid := PackedVector3Array()
	for p in [[-1.125, 0.345], [-1.095, 0.310], [-1.040, 0.272], [-0.960, 0.240], [-0.880, 0.232]]:
		skid.append(Vector3(0.0, p[1], p[0]))
	sweep(b, skid, Vector3.RIGHT, Vector3.FORWARD, PackedVector2Array([Vector2(-0.22, -0.005), Vector2(0.22, -0.005),
			Vector2(0.22, 0.005), Vector2(-0.22, 0.005)]), CB.M_ALLOY, C_ALLOY_DARK)
	for x in [-0.10, 0.10]:
		b.tube(_rounded([Vector3(x - 0.022, 0.335, -1.10), Vector3(x - 0.022, 0.335, -1.15), Vector3(x + 0.022, 0.335, -1.15),
				Vector3(x + 0.022, 0.335, -1.10)], 0.015), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)
	# Bonnet scoop: a raised duct down the middle, sinking into the bonnet toward the back, its mouth
	# facing forward.
	var scoop := PackedVector3Array()
	for k in 9:
		var z: float = lerpf(-0.880, -0.600, k / 8.0)
		scoop.append(Vector3(0.0, top_y(0.0, z) - 0.030 * k / 8.0, z))
	sweep(b, scoop, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.120, -0.004), Vector2(0.120, -0.004),
			Vector2(0.095, 0.036), Vector2(-0.095, 0.036)]), CB.M_PAINT, Color(1, 1, 1))
	var mouth_y: float = top_y(0.0, -0.880)
	b.rbox(Transform3D(Basis(), Vector3(0.0, mouth_y + 0.017, -0.881)), Vector3(0.088, 0.013, 0.003), 0.003, 1, CB.M_DARK,
			C_DARKER)
	# Roof: a visor over the windscreen's top with an LED bar under it, a vent, a lip at the back. The
	# roof is crowned, so the visor, the bar and the lip follow its curve across the car (straight, the
	# bar's ends came up through the visor and the lip's ends stood off the roof).
	var visor := PackedVector3Array()
	var bar_path := PackedVector3Array()
	var lip := PackedVector3Array()
	for k in 9:
		var f: float = k / 8.0
		visor.append(Vector3(lerpf(-0.372, 0.372, f), top_y(lerpf(-0.372, 0.372, f), -0.19) + 0.004, 0.0))
		bar_path.append(Vector3(lerpf(-0.300, 0.300, f), top_y(lerpf(-0.300, 0.300, f), -0.19) + 0.004, 0.0))
		lip.append(Vector3(lerpf(-0.330, 0.330, f), top_y(lerpf(-0.330, 0.330, f), 0.24), 0.0))
	sweep(b, visor, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.312, 0.000), Vector2(-0.298, -0.008),
			Vector2(-0.180, -0.004), Vector2(-0.168, 0.004), Vector2(-0.298, 0.010)]), CB.M_PAINT, Color(1, 1, 1))
	sweep(b, bar_path, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.295, -0.036), Vector2(-0.271, -0.036),
			Vector2(-0.271, -0.006), Vector2(-0.295, -0.006)]), CB.M_DARK, C_DARK)
	for k in 8:
		var x: float = -0.262 + 0.075 * k
		round_lamp(b, Vector3(x, top_y(x, -0.19) - 0.017, -0.296), Vector3.FORWARD, 0.0115, CB.M_HEADLAMP, Color(1, 1, 1))
	var vent_y: float = top_y(0.0, -0.02)
	b.rbox(Transform3D(Basis(), Vector3(0.0, vent_y + 0.008, -0.02)), Vector3(0.065, 0.012, 0.075), 0.010, 2, CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, vent_y + 0.010, -0.096)), Vector3(0.050, 0.007, 0.003), 0.002, 1, CB.M_DARK,
			C_DARKER)
	sweep(b, lip, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(0.228, -0.002), Vector2(0.262, -0.002),
			Vector2(0.272, 0.014), Vector2(0.262, 0.016), Vector2(0.232, 0.004)]), CB.M_DARK, C_DARK)
	# The bed cage across the car: the back bar with the chase lights; the shock hoop.
	b.tube(PackedVector3Array([Vector3(-0.310, 0.780, 0.920), Vector3(0.310, 0.780, 0.920)]), tube_r, 10, CB.M_DARK, C_CAGE,
			false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.801, 0.926)), Vector3(0.150, 0.014, 0.012), 0.006, 1, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.801, 0.939)), Vector3(0.136, 0.007, 0.003), 0.003, 1, CB.M_TAILLAMP, C_AMBER)
	b.tube(_rounded([Vector3(-0.338, 0.442, 0.630), Vector3(-0.312, 0.808, 0.630), Vector3(0.312, 0.808, 0.630),
			Vector3(0.338, 0.442, 0.630)], 0.05), tube_r, 10, CB.M_DARK, C_CAGE, false, false)
	# The fuel cell behind the cab, strapped down.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.485, 0.420)), Vector3(0.230, 0.045, 0.085), 0.020, 2, CB.M_ALLOY, C_ALLOY)
	for dz in [-0.050, 0.050]:
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.487, 0.420 + dz)), Vector3(0.234, 0.048, 0.009), 0.006, 1,
				CB.M_ANODISED, Color(1, 1, 1))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(-0.14, 0.534, 0.42), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.026), Vector2(0.010, 0.026),
			Vector2(0.014, 0.020), Vector2(0.015, 0.0)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(-0.14, 0.53, 0.42))
	_radiators(b)
	# Tail: the LED bar across the tailgate; a tube bumper under it; a tow hook.
	var tb: Array = face_frame(0.0, 0.605, false)
	b.rbox(Transform3D(facing(tb[1]), tb[0]), Vector3(0.360, 0.012, 0.008), 0.006, 1, CB.M_TAILLAMP, C_TAILLAMP)
	b.tube(_rounded([Vector3(-0.470, 0.365, 1.090), Vector3(-0.420, 0.365, 1.180), Vector3(0.420, 0.365, 1.180),
			Vector3(0.470, 0.365, 1.090)], 0.06), 0.018, 10, CB.M_DARK, C_CAGE, true, true)
	b.tube(_rounded([Vector3(-0.025, 0.36, 1.17), Vector3(-0.025, 0.36, 1.22), Vector3(0.025, 0.36, 1.22),
			Vector3(0.025, 0.36, 1.17)], 0.015), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)
	# Rear axle under the bed: the tube and the diff with its cover.
	b.tube(PackedVector3Array([Vector3(-0.40, HUB_Y, AXLE_R), Vector3(0.40, HUB_Y, AXLE_R)]), 0.026, 12, CB.M_DARK,
			C_STEEL, true, true)
	b.rbox(Transform3D(Basis(), Vector3(0.0, HUB_Y, AXLE_R)), Vector3(0.075, 0.066, 0.060), 0.05, 3, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.0, HUB_Y, AXLE_R + 0.063)), Vector3(0.055, 0.048, 0.008), 0.024, 2,
			CB.M_ANODISED, Color(1, 1, 1))


## The radiators in the back of the bed, laid back with their faces to the sky behind: a dark core
## with fins, its frame, two fans on it, legs down to the floor.
func _radiators(b) -> void:
	var n := Vector3(0.0, 0.819, 0.574)              # the face's normal: up and back
	var basis := Basis(Vector3.RIGHT, n, Vector3.RIGHT.cross(n))   # x across, y out of the face, z down it
	var c := Vector3(0.0, 0.560, 0.862)
	b.rbox(Transform3D(basis, c), Vector3(0.280, 0.020, 0.135), 0.010, 2, CB.M_DARK, C_DARK)
	for k in 14:
		bar(b, c + n * 0.021 + basis.z * (-0.117 + 0.018 * k), Vector3(0.262, 0.002, 0.002), CB.M_DARK, C_MESH)
	for x in [-0.135, 0.135]:
		_fan(b, c + Vector3(x, 0.0, 0.0) + n * 0.030, n, 0.108)
	# The frame's top edge stands on two posts; its foot rests on the floor.
	for x in [-0.24, 0.24]:
		var post: Vector3 = c - basis.z * 0.125 - n * 0.012 + Vector3(x, 0.0, 0.0)
		b.tube(PackedVector3Array([post, Vector3(x, 0.442, post.z)]), 0.008, 6, CB.M_DARK, C_STEEL, false, false)


## A fan facing `ax` at c: its shroud ring, seven pitched blades, the hub.
func _fan(b, c: Vector3, ax: Vector3, r: float) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, ax, PackedVector2Array([Vector2(-0.012, r + 0.006), Vector2(0.014, r + 0.006), Vector2(0.014, r),
			Vector2(-0.012, r)]), 28, CB.M_DARK, C_DARK)
	b.orient_away_from(vb, ib, c)
	var e1: Vector3 = CB._perp(ax)
	var e2: Vector3 = ax.cross(e1).normalized()
	for k in 7:
		var a: float = TAU * k / 7.0
		var rd: Vector3 = e1 * cos(a) + e2 * sin(a)
		var tg: Vector3 = ax.cross(rd).normalized()
		var pitch := Basis(rd, 0.45)
		var bz: Vector3 = pitch * tg
		var by: Vector3 = pitch * ax
		b.rbox(Transform3D(Basis(rd, by, bz), c + rd * r * 0.56 + ax * 0.004), Vector3(r * 0.36, 0.003, 0.022), 0.002, 1,
				CB.M_ALLOY, C_ALLOY_DARK)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(c, ax, PackedVector2Array([Vector2(-0.006, 0.030), Vector2(0.010, 0.030), Vector2(0.016, 0.018),
			Vector2(0.018, 0.0)]), 16, CB.M_DARK, C_DARK)
	b.orient_away_from(vb, ib, c - ax * 0.02)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## an all-terrain tyre round a six-spoke rim with a beadlock ring in the accent colour.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 44, C_RUBBER)
	for row in TREAD_ROWS:
		var odd: bool = row % 2 == 1
		var f: Array = wheel_frame(TAU * row / TREAD_ROWS)
		var r_dir: Vector3 = f[0]
		var t_dir: Vector3 = f[1]
		# Two centre blocks, staggered and skewed in turn: a zig-zag down the middle.
		for x in ([-0.036, 0.048] if odd else [-0.048, 0.036]):
			var rc: float = carcass_r(TYRE_HALF, x) - 0.002
			var skew: Vector3 = (Vector3.RIGHT + t_dir * (0.35 if odd else -0.35)).normalized()
			block(b, r_dir * (rc + 0.4 * BLOCK_H) + Vector3(x, 0.0, 0.0), skew, t_dir, r_dir, 0.028, BLOCK_H, 0.017, 0.85,
					CB.M_RUBBER, C_RUBBER)
		# Shoulder blocks, long and short in turn, leaning out over the sidewalls.
		for sx in [-1.0, 1.0]:
			var lean: Vector3 = (r_dir * 0.78 + Vector3(0.63 * sx, 0.0, 0.0)).normalized()
			var reach: float = 0.020 if odd else 0.013
			var xs: float = 0.100 * sx
			block(b, r_dir * (carcass_r(TYRE_HALF, xs) - 0.004) + Vector3(xs, 0.0, 0.0) + lean * 0.004,
					lean.cross(t_dir).normalized(), t_dir, lean, reach, 0.013, 0.018, 0.82, CB.M_RUBBER, C_RUBBER)
	# Rim: the lip, its face stepping in to the spokes, the barrel, a dark well behind the spokes.
	wheel_lathe(b, PackedVector2Array([Vector2(0.094, 0.146), Vector2(0.103, 0.152), Vector2(0.109, 0.150),
			Vector2(0.111, 0.142), Vector2(0.105, 0.137)]), 44, CB.M_RIM, C_RIM, "out", Vector3(0.08, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.105, 0.137), Vector2(0.090, 0.134), Vector2(0.080, 0.132)]), 44,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.080, 0.132), Vector2(0.074, 0.142), Vector2(-0.098, 0.146),
			Vector2(-0.106, 0.150)]), 44, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(0.025, 0.0, 0.0), Vector3.RIGHT, 0.140, 0.0, 32, CB.M_DARK, C_DARKER)
	# Beadlock ring over the bead, bolted round.
	wheel_lathe(b, PackedVector2Array([Vector2(0.108, 0.140), Vector2(0.115, 0.141), Vector2(0.119, 0.147),
			Vector2(0.119, 0.160), Vector2(0.114, 0.165), Vector2(0.104, 0.166)]), 44, CB.M_ANODISED, Color(1, 1, 1), "out",
			Vector3(0.09, 0.0, 0.0))
	for k in 18:
		var g: Array = wheel_frame(TAU * (k + 0.5) / 18.0)
		bar(b, (g[0] as Vector3) * 0.153 + Vector3(0.121, 0.0, 0.0), Vector3(0.003, 0.004, 0.004), CB.M_CHROME, C_CHROME)
	# Hub with six lug nuts and a centre cap; six wide spokes, twisted a little.
	wheel_lathe(b, PackedVector2Array([Vector2(0.060, 0.046), Vector2(0.086, 0.046), Vector2(0.091, 0.040)]), 20,
			CB.M_RIM, C_RIM, "out", Vector3(0.07, 0.0, 0.0))
	b.disc(Vector3(0.091, 0.0, 0.0), Vector3.RIGHT, 0.040, 0.0, 20, CB.M_RIM, C_RIM)
	for k in 6:
		var g: Array = wheel_frame(TAU * (k + 0.5) / 6.0)
		bar(b, (g[0] as Vector3) * 0.027 + Vector3(0.095, 0.0, 0.0), Vector3(0.004, 0.0045, 0.0045), CB.M_CHROME, C_CHROME)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.091, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.014), Vector2(0.006, 0.014),
			Vector2(0.010, 0.008), Vector2(0.011, 0.0)]), 12, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.085, 0.0, 0.0))
	for k in 6:
		spoke(b, TAU * k / 6.0, 0.10, 0.042, 0.136, 0.088, 0.080, 0.014, 0.024, 0.014, CB.M_RIM, C_RIM)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# The cab's rear window in back view (x, y).
	shapes["rear"] = _inset(PackedVector2Array([Vector2(-0.300, 0.712), Vector2(0.300, 0.712), Vector2(0.285, 0.848),
			Vector2(-0.285, 0.848)]), 0.022)
	# The door in side view (z, y): from behind the front fender to the cab's back corner, the sill to
	# the window.
	shapes["door"] = PackedVector2Array([Vector2(-0.392, 0.290), Vector2(0.205, 0.290), Vector2(0.205, 0.632),
			Vector2(-0.392, 0.632)])
	return shapes


## Where p lies along its section's upper curve, in metres from A (the wall's top): Vector3(s, s at
## B where the corner starts, s at C where it ends). Sampled once per z, one column of the map.
func _upper_s(p: Vector3) -> Vector3:
	if not _curve_cache.has(p.z):
		var segs: Array = _upper_segments(p.z, prof["w"].at(p.z), prof["belt"].at(p.z), 0.0)
		var pts := PackedVector2Array()
		var acc := PackedFloat32Array()
		var marks := PackedFloat32Array()
		for k in range(2, segs.size()):
			for q in (segs[k] as PackedVector2Array):
				if not pts.is_empty() and q.distance_squared_to(pts[pts.size() - 1]) < 1e-14:
					continue
				acc.append(0.0 if pts.is_empty() else acc[acc.size() - 1] + q.distance_to(pts[pts.size() - 1]))
				pts.append(q)
			marks.append(acc[acc.size() - 1])
		_curve_cache[p.z] = [pts, acc, marks]
	var entry: Array = _curve_cache[p.z]
	var pts: PackedVector2Array = entry[0]
	var acc: PackedFloat32Array = entry[1]
	var marks: PackedFloat32Array = entry[2]
	var q := Vector2(absf(p.x), p.y)
	var best := 0.0
	var best_d := 1e9
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var e: Vector2 = pts[k + 1] - a
		var f: float = clampf((q - a).dot(e) / maxf(e.length_squared(), 1e-12), 0.0, 1.0)
		var dd: float = (a + e * f).distance_squared_to(q)
		if dd < best_d:
			best_d = dd
			best = lerpf(acc[k], acc[k + 1], f)
	return Vector3(best, marks[0], marks[1])


## A rounded intersection of two half-planes given as distances (negative inside), corner radius r.
static func _round_and(a: float, c: float, r: float) -> float:
	var q := Vector2(maxf(a + r, 0.0), maxf(c + r, 0.0))
	return q.length() + minf(maxf(a + r, c + r), 0.0) - r


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var black := 0.0
	var sxy := Vector2(p.x, p.y)
	var w: float = prof["w"].at(p.z)
	var well: Array = _well(p.z)
	# The wells: their inner walls (the ceilings face down, black with the underside below).
	if n.x > 0.5 and absf(p.x) < float(well[0]) + 0.003 and p.y < float(well[1]) + 0.004:
		black = 1.0
	# Glass either side of the cab's corner: the side window on the wall below the A-pillar and the
	# roof rail, the windscreen on the top inboard of them, each edged by its black seal.
	if p.y > 0.62 and p.z > WS_Z.x - 0.03 and p.z < 0.25:
		var u: Vector3 = _upper_s(p)
		var below_rail: float = u.x - (u.y - PILLAR_PAD)
		var above_belt: float = 0.010 - u.x
		var side_d: float = _round_and(maxf(below_rail, above_belt), maxf(SIDE_FRONT - p.z, p.z - SIDE_BACK), 0.025)
		if n.x > 0.2:
			glass = maxf(glass, _cover(side_d, fp))
			black = maxf(black, _cover(side_d - 0.008, fp))
		var inboard: float = (u.z + PILLAR_PAD) - u.x
		var ws_d: float = _round_and(inboard, maxf(WS_Z.x - p.z, p.z - WS_Z.y), 0.03)
		if n.z < -0.05:
			glass = maxf(glass, _cover(ws_d, fp))
			black = maxf(black, _cover(ws_d - 0.010, fp))
	# Rear window in the cab's back.
	if n.z > 0.4 and p.z > 0.24 and p.z < 0.30 and p.y > 0.69:
		var d: float = _sd_rounded(sxy, sh["rear"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.010, fp))
	var outside: bool = n.x > 0.5 and absf(p.x) > w - 0.006
	if outside:
		# Door shut lines.
		if p.z > -0.40 and p.z < 0.215 and p.y > 0.28 and p.y < 0.64:
			gap = maxf(gap, _cover(absf(_sd_poly(Vector2(p.z, p.y), sh["door"])) - 0.0022, fp))
	# The bed's liner: its floor, the inside of its walls, the cab's back below the rail and the
	# tailgate's inside.
	if p.z > 0.26 and p.z < 1.105 and absf(p.x) < 0.383 and p.y < 0.676 and p.y > 0.40:
		if p.y < 0.70 and (n.y > 0.5 or n.x < -0.4 or n.z > 0.4 or n.z < -0.4):
			black = maxf(black, 1.0)
	# Bonnet: shut lines along the fenders and at the cowl; vents on the fender tops behind the wheels.
	if n.y > 0.5 and p.z < -0.43 and p.z > -1.05:
		gap = maxf(gap, _cover(absf(absf(p.x) - 0.392) - 0.002, fp))
		gap = maxf(gap, _cover(absf(p.z + 0.452) - 0.002, fp) * _cover(absf(p.x) - 0.392, fp))
		if p.z > -0.60 and p.z < -0.47 and absf(p.x) > 0.415 and absf(p.x) < 0.53:
			var slots := 1e3
			for k in 5:
				var zc: float = -0.583 + 0.026 * k
				slots = minf(slots, _sd_box(Vector2(absf(p.x) - 0.472, p.z - zc), Vector2(0.046, 0.0055)) - 0.003)
			black = maxf(black, _cover(slots, fp))
	# Underside, and the wells' ceilings.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, 0.0, black)
