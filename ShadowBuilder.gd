# ShadowBuilder.gd
#
# The Shadow: a stealth desert buggy. A faceted tub (a raised ridge down the bonnet, angular side
# pods sprouting behind the front wheels, an open single-seat cockpit, a spine along the rear deck)
# under a blacked-out tube cage with a faceted roof panel and a three-lamp light bar; the engine
# bare behind the cockpit with twin exhausts, a kicked-up wing on swan struts with hex endplates,
# a curved skid plate up front. Wide diamond-block tyres on twelve turbine spokes. Rebuilt in code
# from its Hunyuan model, after its proportions rather than its every panel; the wheels sit where
# its wheels did.
#
# The section is faceted: straight runs between corners with small fillets (_upper_segments). Above
# the tub's side it runs: a chamfer in to the pod's shoulder, the pod's top, a wall (up the
# bonnet's side, down into the cockpit, or lying flat on the deck), then the top: a chamfer up to
# the ridge (bonnet, deck spine) or the cockpit floor. On the nose the pod is a ledge a centimetre
# wide, so the bonnet's side is the same wall all the way back and the pods grow out from under it.
# Every corner's parameters come from one keyframe table (KEYS), so the dash and the firewall are
# clean walls between the regions.
extends "res://CarDesign.gd"

# Wheels: the Hunyuan model's positions (tyres 0.30 wide, outer faces at x 0.70).
const WHEEL_X := 0.549
const AXLE_F := -0.689
const AXLE_R := 0.628
const HUB_Y := 0.2755

const W_KNOTS := [[-1.00, 0.095], [-0.85, 0.115], [-0.70, 0.135], [-0.55, 0.160], [-0.48, 0.165], [-0.40, 0.25],
	[-0.32, 0.34], [-0.26, 0.37], [-0.225, 0.375], [0.06, 0.395], [0.095, 0.40], [0.25, 0.41], [0.35, 0.39],
	[0.42, 0.375], [0.52, 0.33]]
# The tub's bottom, lifting toward the tail like a diffuser (clear of the rear tyres).
const BOT_KNOTS := [[-1.00, 0.30], [-0.88, 0.275], [-0.60, 0.27], [0.25, 0.27], [0.40, 0.30], [0.52, 0.35]]

# The section above the side, keyframed along the car. Per row: z; belt (top of the vertical
# side); ch_dx, ch_dy (the chamfer in to the pod's shoulder); in_x, in_dy (the pod top's inner
# edge: the cockpit's rim, the foot of the bonnet's side); edge (the wall's other end: the
# bonnet's edge, the cockpit floor, the deck); wall_dx; ridge_x, top (the ridge's flat, or the
# floor's middle).
const KEYS := [
	# z       belt   ch_dx  ch_dy  in_x   in_dy  edge   wall_dx ridge_x top
	[-1.000, 0.330, 0.008, 0.006, 0.075, 0.000, 0.462, 0.012, 0.030, 0.490],
	[-0.850, 0.335, 0.008, 0.006, 0.095, 0.000, 0.535, 0.012, 0.040, 0.575],
	[-0.700, 0.340, 0.008, 0.006, 0.115, 0.000, 0.590, 0.012, 0.055, 0.640],
	[-0.550, 0.345, 0.008, 0.006, 0.140, 0.000, 0.625, 0.012, 0.070, 0.685],
	[-0.480, 0.350, 0.008, 0.006, 0.145, 0.000, 0.640, 0.012, 0.075, 0.700],
	[-0.400, 0.400, 0.050, 0.035, 0.165, 0.010, 0.650, 0.015, 0.080, 0.710],
	[-0.320, 0.450, 0.085, 0.060, 0.180, 0.020, 0.660, 0.015, 0.080, 0.715],
	[-0.260, 0.470, 0.095, 0.068, 0.185, 0.025, 0.660, 0.015, 0.080, 0.715],
	[-0.225, 0.480, 0.095, 0.068, 0.250, 0.012, 0.300, 0.020, 0.060, 0.300],
	[0.060, 0.520, 0.090, 0.060, 0.260, 0.010, 0.300, 0.020, 0.060, 0.300],
	[0.095, 0.550, 0.080, 0.050, 0.250, 0.010, 0.626, 0.030, 0.100, 0.645],
	[0.300, 0.570, 0.080, 0.050, 0.250, 0.008, 0.644, 0.030, 0.100, 0.665],
	[0.420, 0.560, 0.070, 0.045, 0.230, 0.006, 0.627, 0.030, 0.090, 0.645],
	[0.520, 0.530, 0.060, 0.040, 0.210, 0.005, 0.590, 0.030, 0.080, 0.605],
]
const KEY_NAMES := ["belt", "ch_dx", "ch_dy", "in_x", "in_dy", "edge", "wall_dx", "ridge_x", "top"]
# Fillet radii at the section's corners: the side's top, the shoulder, the pod top's inner edge,
# the wall's foot (the cockpit floor's fillet), the ridge.
const FILLETS := [0.012, 0.010, 0.008, 0.012, 0.010]

# Tyres: a wide balloon carcass (half its profile, bead to tread centre) under diamond blocks.
const TYRE_HALF := [[-0.130, 0.152], [-0.141, 0.166], [-0.149, 0.186], [-0.152, 0.205], [-0.150, 0.222],
	[-0.143, 0.236], [-0.130, 0.247], [-0.105, 0.255], [-0.060, 0.2585], [0.0, 0.2595]]
const TREAD_ROWS := 26
const BLOCK_H := 0.0155

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.20, 0.20, 0.21)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_CAGE := Color(0.075, 0.075, 0.08)
const C_SEAT := Color(0.09, 0.09, 0.10)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.78, 0.79, 0.81)
const C_ALLOY_DARK := Color(0.42, 0.43, 0.45)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.57)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.00, "tail_z": 0.98, "belt_y": 0.50, "side_x": 0.40,
	"door_z": -0.06, "door_y": 0.39, "roundel_r": 0.075,
	"hood_z": -0.62, "hood_r": 0.065, "stripe_w": 0.045, "stripe_gap": 0.018,
}
const ANTENNA_POS := Vector3(0.15, 0.85, 0.40)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}

# The roof panel's spine in side view (z, y): level over the cockpit, sloping down behind.
const ROOF_PATH := [[-0.250, 0.872], [-0.200, 0.892], [0.180, 0.897], [0.300, 0.874], [0.600, 0.784]]


func _init() -> void:
	nose_tip = -1.000
	nose_cap = 0.020
	nose_cap_y = 0.400
	nose_cap_exp = Vector2(6.0, 6.0)
	tail_tip = 0.520
	tail_cap = 0.020
	tail_cap_y = 0.470
	tail_cap_exp = Vector2(6.0, 6.0)
	# Bottom, bottom corner, side; then fillet and straight in turn: the side's top, chamfer,
	# shoulder, pod top, rim, wall, wall's foot, top chamfer (or floor), ridge, ridge flat.
	segment_counts = [2, 3, 4, 3, 3, 3, 3, 3, 4, 3, 3, 3, 3]
	half_ring = 40
	bottom_radius = 0.02
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	setup_shell(knots)


## Above the side: straight runs between five corners (the side's top, the pod's shoulder, its
## inner edge, the wall's foot, the ridge), each rounded by a small fillet, ending at (0, top).
## The first fillet starts at (w, belt), tangent to the side.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var ch_dx: float = prof["ch_dx"].at(z)
	var ch_dy: float = prof["ch_dy"].at(z)
	var sh := Vector2(w - ch_dx, belt + FILLETS[0] + ch_dy)
	var inner := Vector2(minf(prof["in_x"].at(z), sh.x - 0.006), sh.y + prof["in_dy"].at(z))
	var wall_foot := Vector2(inner.x - maxf(prof["wall_dx"].at(z), 0.01), prof["edge"].at(z))
	var ridge := Vector2(minf(prof["ridge_x"].at(z), wall_foot.x - 0.01), top)
	var start := Vector2(w, belt)
	var end := Vector2(0.0, top)
	var corners := [Vector2(w, belt + FILLETS[0]), sh, inner, wall_foot, ridge]
	# The first corner sits one fillet above the side's top, so its fillet starts there.
	var t0: float = minf(FILLETS[0], 0.5 * (sh - corners[0]).length())
	corners[0] = Vector2(w, belt + t0)
	var segs := []
	var cur: Vector2 = start
	for k in corners.size():
		var c: Vector2 = corners[k]
		var prev: Vector2 = start if k == 0 else corners[k - 1]
		var next: Vector2 = end if k == corners.size() - 1 else corners[k + 1]
		var t: float = t0 if k == 0 else minf(FILLETS[k], minf(0.5 * (c - prev).length(), 0.5 * (next - c).length()))
		var a: Vector2 = c + (prev - c).normalized() * t
		var e: Vector2 = c + (next - c).normalized() * t
		if k > 0:
			segs.append(PackedVector2Array([cur, a]))
		var fillet := PackedVector2Array()
		for s in 5:
			var u: float = s / 4.0
			fillet.append(a.lerp(c, u).lerp(c.lerp(e, u), u))
		segs.append(fillet)
		cur = e
	segs.append(PackedVector2Array([cur, end]))
	return segs


## Body mesh: shell, chassis plate, cage and roof, cockpit, light bar, wing, engine bay, bumpers
## and suspension.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)
	_seat(b)
	_steering(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	var tube_r := 0.016
	# Cage: the A-pillar from the bonnet's side up to the roof, the roof rail, the main hoop's leg
	# down onto the pod, the rear stay over the engine down to the bumper.
	b.tube(_rounded([Vector3(0.150, 0.628, -0.50), Vector3(0.168, 0.80, -0.30), Vector3(0.170, 0.855, -0.22)], 0.06),
			tube_r, 10, CB.M_DARK, C_CAGE, true, false)
	b.tube(_rounded([Vector3(0.170, 0.855, -0.22), Vector3(0.170, 0.872, 0.18), Vector3(0.150, 0.852, 0.30),
			Vector3(0.140, 0.765, 0.58)], 0.06), tube_r, 10, CB.M_DARK, C_CAGE, false, false)
	b.tube(PackedVector3Array([Vector3(0.170, 0.872, 0.18), Vector3(0.290, 0.640, 0.22)]), tube_r, 10, CB.M_DARK, C_CAGE,
			false, true)
	b.tube(_rounded([Vector3(0.140, 0.765, 0.58), Vector3(0.150, 0.660, 0.84), Vector3(0.150, 0.425, 0.865)], 0.05),
			tube_r, 10, CB.M_DARK, C_CAGE, false, true)
	# A grab bar along the cockpit's rim, from the dash to the main hoop.
	b.tube(PackedVector3Array([Vector3(0.262, 0.600, -0.24), Vector3(0.284, 0.648, 0.20)]), 0.010, 8, CB.M_DARK, C_CAGE,
			true, true)
	# Front bumper horn: a loop out from the skid plate, in the accent colour.
	b.tube(_rounded([Vector3(0.18, 0.445, -1.030), Vector3(0.30, 0.425, -0.975), Vector3(0.30, 0.355, -0.960),
			Vector3(0.18, 0.330, -1.005)], 0.035), 0.013, 10, CB.M_ANODISED, Color(1, 1, 1), true, true)
	# Shock tower on the bonnet's side, the rear tower on the engine frame.
	b.rbox(Transform3D(Basis(), Vector3(0.150, 0.590, AXLE_F - 0.05)), Vector3(0.022, 0.035, 0.026), 0.006, 1, CB.M_DARK,
			C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.160, 0.560, AXLE_R - 0.06)), Vector3(0.025, 0.035, 0.022), 0.006, 1, CB.M_DARK,
			C_STEEL)
	# Wing: endplate (hex, black) with an accent flash, its strut from the cage's rear bar.
	var plate := PackedVector2Array([Vector2(0.700, 0.800), Vector2(0.735, 0.745), Vector2(0.930, 0.755),
			Vector2(1.035, 0.860), Vector2(1.030, 0.930), Vector2(0.860, 0.920)])
	_slab(b, plate, 0.415, 0.012, CB.M_DARK, C_DARK)
	_slab(b, PackedVector2Array([Vector2(0.870, 0.888), Vector2(1.000, 0.893), Vector2(1.020, 0.908),
			Vector2(0.885, 0.903)]), 0.4225, 0.003, CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.09, 0.735, 0.842)), Vector3(0.006, 0.072, 0.03), 0.004, 1,
			CB.M_DARK, C_DARK)
	# Taillamp: a round red lens in a chrome bezel on the bumper's back face.
	_round_lamp(b, Vector3(0.150, 0.345, 0.926), Vector3.BACK, 0.026, CB.M_TAILLAMP, C_TAILLAMP)
	# Exhaust: from the engine's flank back over the gearbox, out above the bumper.
	b.tube(_rounded([Vector3(0.095, 0.400, 0.68), Vector3(0.13, 0.42, 0.74), Vector3(0.07, 0.49, 0.85),
			Vector3(0.07, 0.535, 0.95)], 0.04), 0.017, 12, CB.M_CHROME, C_CHROME, false, false)
	b.disc(Vector3(0.07, 0.535, 0.95), Vector3(0.0, 0.4, 1.0).normalized(), 0.0165, 0.0, 12, CB.M_DARK, C_DARKER)
	# Bolts down the pod's front seam.
	for k in 4:
		var z: float = -0.34 + 0.012 * k
		var w: float = prof["w"].at(z)
		bar(b, Vector3(w + 0.002, 0.30 + 0.035 * k, z), Vector3(0.003, 0.004, 0.004), CB.M_ALLOY, C_ALLOY)
	_suspension(b, AXLE_F, 1.0)
	_suspension(b, AXLE_R, -1.0)


## One corner's suspension (right side): double A-arms out to the hub carrier, a coil-over up to
## its tower, the driveshaft. `fz` points toward the middle of the car.
func _suspension(b, az: float, fz: float) -> void:
	var kx := 0.445
	for dz in [-0.085, 0.085]:
		b.tube(PackedVector3Array([Vector3(0.11, 0.245, az + dz), Vector3(kx - 0.012, 0.225, az)]), 0.012, 8,
				CB.M_DARK, C_STEEL, true, true)
	for dz in [-0.06, 0.06]:
		b.tube(PackedVector3Array([Vector3(0.13, 0.375, az + dz), Vector3(kx - 0.014, 0.335, az)]), 0.010, 8,
				CB.M_DARK, C_STEEL, true, true)
	b.rbox(Transform3D(Basis(), Vector3(kx, HUB_Y, az)), Vector3(0.018, 0.072, 0.03), 0.009, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, az), Vector3(0.53, HUB_Y, az)]), 0.016, 10, CB.M_ALLOY, C_ALLOY_DARK,
			false, true)
	b.tube(PackedVector3Array([Vector3(0.10, 0.27, az), Vector3(kx - 0.01, HUB_Y, az)]), 0.010, 8, CB.M_ALLOY,
			C_ALLOY_DARK, false, false)
	var top_z: float = az - 0.05 if fz > 0.0 else az - 0.06
	coilover(b, Vector3(0.335, 0.245, az + 0.01 * fz), Vector3(0.162, 0.565 if fz > 0.0 else 0.535, top_z), 0.017, 0.028,
			7.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)


func _centre_parts(b) -> void:
	var tube_r := 0.016
	# Cage across the car: under the roof's front edge, the main hoop's top, a shoulder bar behind
	# the seat, the rear stays' bar the wing struts stand on, the bumper's top bar.
	for bar_pts in [[Vector3(-0.170, 0.855, -0.22), Vector3(0.170, 0.855, -0.22)],
			[Vector3(-0.170, 0.872, 0.18), Vector3(0.170, 0.872, 0.18)],
			[Vector3(-0.250, 0.720, 0.207), Vector3(0.250, 0.720, 0.207)],
			[Vector3(-0.150, 0.660, 0.84), Vector3(0.150, 0.660, 0.84)],
			[Vector3(-0.150, 0.432, 0.865), Vector3(0.150, 0.432, 0.865)]]:
		b.tube(PackedVector3Array(bar_pts), tube_r, 10, CB.M_DARK, C_CAGE, false, false)
	# Roof panel (in the paint): a faceted hat over the cage.
	var roof := PackedVector3Array()
	for p in ROOF_PATH:
		roof.append(Vector3(0.0, p[1], p[0]))
	_sweep(b, roof, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.205, -0.020), Vector2(0.205, -0.020),
			Vector2(0.205, -0.012), Vector2(0.150, 0.008), Vector2(-0.150, 0.008), Vector2(-0.205, -0.012)]),
			CB.M_PAINT, Color(1, 1, 1))
	# Light bar under the roof's front edge: housing, accent trim, three lamps.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.835, -0.248)), Vector3(0.135, 0.022, 0.020), 0.006, 1, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.811, -0.262)), Vector3(0.128, 0.003, 0.004), 0.002, 1, CB.M_ANODISED,
			Color(1, 1, 1))
	for x in [-0.082, 0.0, 0.082]:
		_round_lamp(b, Vector3(x, 0.836, -0.268), Vector3.FORWARD, 0.019, CB.M_HEADLAMP, Color(1, 1, 1))
	# Front skid plate, curving under the nose to the chassis plate; bolts and a tow hook.
	var skid := PackedVector3Array()
	for p in [[-1.030, 0.505], [-1.045, 0.440], [-1.043, 0.360], [-1.022, 0.295], [-0.985, 0.255], [-0.940, 0.240]]:
		skid.append(Vector3(0.0, p[1], p[0]))
	_sweep(b, skid, Vector3.RIGHT, Vector3.FORWARD, PackedVector2Array([Vector2(-0.200, -0.006), Vector2(0.200, -0.006),
			Vector2(0.200, 0.006), Vector2(-0.200, 0.006)]), CB.M_DARK, C_STEEL)
	for x in [-0.13, 0.13]:
		bar(b, Vector3(x, 0.46, -1.049), Vector3(0.006, 0.006, 0.003), CB.M_ALLOY, C_ALLOY)
	b.tube(_rounded([Vector3(-0.03, 0.395, -1.04), Vector3(-0.03, 0.395, -1.085), Vector3(0.03, 0.395, -1.085),
			Vector3(0.03, 0.395, -1.04)], 0.02), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)
	# Chassis plate under the tub, kicked up at both ends.
	var chassis := PackedVector3Array()
	for p in [[-0.960, 0.262], [-0.900, 0.240], [-0.800, 0.230], [0.100, 0.255], [0.450, 0.245], [0.620, 0.232],
			[0.780, 0.236], [0.840, 0.262]]:
		chassis.append(Vector3(0.0, p[1], p[0]))
	_sweep(b, chassis, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.205, -0.005), Vector2(0.205, -0.005),
			Vector2(0.212, 0.0), Vector2(0.205, 0.005), Vector2(-0.205, 0.005), Vector2(-0.212, 0.0)]), CB.M_ALLOY,
			C_ALLOY_DARK)
	# Wing: the plane (in the paint), kinked up outboard, its trailing edge kicked up.
	var span := PackedVector3Array()
	for p in [[-0.410, 0.030], [-0.255, 0.030], [-0.170, 0.0], [0.170, 0.0], [0.255, 0.030], [0.410, 0.030]]:
		span.append(Vector3(p[0], 0.795 + p[1], 0.0))
	_sweep(b, span, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(0.735, 0.000), Vector2(0.750, -0.008),
			Vector2(0.890, -0.006), Vector2(0.990, 0.048), Vector2(0.985, 0.060), Vector2(0.880, 0.010),
			Vector2(0.750, 0.010)]), CB.M_PAINT, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.48), Vector3(0.0, 0.854, 0.991)), Vector3(0.405, 0.011, 0.003), 0.002, 1,
			CB.M_DARK, C_DARK)
	# Engine: block, cam cover in the accent, cooling fins, an air filter on top; the gearbox and
	# its cover at the rear axle.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.400, 0.705)), Vector3(0.105, 0.070, 0.085), 0.02, 2, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.482, 0.705)), Vector3(0.085, 0.016, 0.072), 0.012, 2, CB.M_ANODISED,
			Color(1, 1, 1))
	for k in 5:
		for sx in [-1.0, 1.0]:
			bar(b, Vector3(0.108 * sx, 0.355 + 0.02 * k, 0.705), Vector3(0.008, 0.003, 0.075), CB.M_ALLOY, C_ALLOY_DARK)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.0, 0.535, 0.640), Vector3.RIGHT, PackedVector2Array([Vector2(-0.075, 0.0), Vector2(-0.075, 0.036),
			Vector2(-0.068, 0.042), Vector2(0.068, 0.042), Vector2(0.075, 0.036), Vector2(0.075, 0.0)]), 16, CB.M_DARK,
			C_DARK)
	b.orient_away_from(vb, ib, Vector3(0.0, 0.535, 0.640))
	b.tube(PackedVector3Array([Vector3(0.0, 0.47, 0.66), Vector3(0.0, 0.50, 0.645)]), 0.022, 10, CB.M_DARK, C_DARK,
			false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.300, AXLE_R)), Vector3(0.10, 0.06, 0.07), 0.02, 2, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.300, AXLE_R + 0.074)), Vector3(0.06, 0.042, 0.006), 0.02, 2,
			CB.M_ANODISED, Color(1, 1, 1))
	# Rear bumper box: tow hook, a diffuser's fins under it.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.338, 0.870)), Vector3(0.240, 0.085, 0.055), 0.02, 2, CB.M_DARK, C_DARK)
	b.tube(_rounded([Vector3(-0.03, 0.30, 0.92), Vector3(-0.03, 0.30, 0.965), Vector3(0.03, 0.30, 0.965),
			Vector3(0.03, 0.30, 0.92)], 0.02), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)
	for k in 5:
		b.rbox(Transform3D(Basis(), Vector3(-0.16 + 0.08 * k, 0.262, 0.885)), Vector3(0.004, 0.012, 0.045), 0.002, 1,
				CB.M_DARK, C_DARKER)


## A round lamp facing `fwd`: a chrome bezel round a lens (a headlamp's reflector lens, or a
## coloured one).
func _round_lamp(b, c: Vector3, fwd: Vector3, r: float, mat: int, col: Color) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, fwd, PackedVector2Array([Vector2(-0.012, r + 0.004), Vector2(0.002, r + 0.004), Vector2(0.005, r + 0.001),
			Vector2(0.004, r - 0.002)]), 18, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, c - fwd * 0.01)
	if mat == CB.M_HEADLAMP:
		lens(b, c + fwd * 0.001, fwd, r, r * 0.25, 18)
	else:
		vb = b.vertex_count()
		ib = b.index_count()
		b.lathe(c, fwd, PackedVector2Array([Vector2(0.0, r), Vector2(r * 0.15, r * 0.8), Vector2(r * 0.25, 0.0)]), 18,
				mat, col)
		b.orient_away_from(vb, ib, c - fwd * r)


## A single bucket seat on the cockpit floor: cushion, raked back with bolsters and a head
## surround, harness straps in the accent colour.
func _seat(b) -> void:
	var floor_y := 0.30
	b.rbox(Transform3D(Basis(), Vector3(0.0, floor_y + 0.035, -0.09)), Vector3(0.13, 0.032, 0.13), 0.02, 2, CB.M_DARK,
			C_SEAT)
	var rake := Basis(Vector3.RIGHT, 0.30)
	var back_c := Vector3(0.0, floor_y + 0.19, 0.03)
	b.rbox(Transform3D(rake, back_c), Vector3(0.13, 0.16, 0.03), 0.02, 2, CB.M_DARK, C_SEAT)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.115 * sx, -0.03, -0.035)), Vector3(0.02, 0.13, 0.05), 0.015,
				2, CB.M_DARK, C_SEAT)
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.05 * sx, 0.0, -0.034)), Vector3(0.013, 0.14, 0.003), 0.002, 1,
				CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, 0.17, -0.01)), Vector3(0.085, 0.05, 0.032), 0.02, 2, CB.M_DARK,
			C_SEAT)


## The steering wheel before the seat, on a column into the dash.
func _steering(b) -> void:
	var c := Vector3(0.0, 0.53, -0.20)
	var tilt := Basis(Vector3.RIGHT, -0.50)
	var ring := PackedVector3Array()
	for k in 25:
		var a: float = TAU * k / 24.0
		ring.append(c + tilt * Vector3(cos(a) * 0.075, sin(a) * 0.06, 0.0))
	b.tube(ring, 0.009, 6, CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([c + tilt * Vector3(-0.072, 0.0, 0.0), c + tilt * Vector3(0.072, 0.0, 0.0)]), 0.007, 6,
			CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([c, c + Vector3(0.0, 0.03, -0.07)]), 0.012, 8, CB.M_DARK, C_DARK, true, false)


## A profile (across, out) swept along a path, flat-shaded round the profile and smooth along the
## path: plates, the roof panel, the wing. `across` is the profile's first axis (constant), the
## second is across x tangent, turned toward `up_hint`. The profile is convex; both ends capped.
func _sweep(b, path: PackedVector3Array, across: Vector3, up_hint: Vector3, profile: PackedVector2Array, mat: int,
		col: Color) -> void:
	var n: int = path.size()
	var m: int = profile.size()
	# The profile's winding, so each edge knows its outward side (a centroid test fails on a thin
	# bent plate such as the wing, whose centroid lies off the plate).
	var area := 0.0
	for k in m:
		area += profile[k].cross(profile[(k + 1) % m])
	var rings := []
	var normals := []
	var tangents := []
	for i in n:
		var t: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var nrm: Vector3 = across.cross(t).normalized()
		if nrm.dot(up_hint) < 0.0:
			nrm = -nrm
		var ring := PackedVector3Array()
		for p in profile:
			ring.append(path[i] + across * p.x + nrm * p.y)
		rings.append(ring)
		normals.append(nrm)
		tangents.append(t)
	for k in m:
		var k2: int = (k + 1) % m
		var e: Vector2 = profile[k2] - profile[k]
		var out2: Vector2 = Vector2(e.y, -e.x) * (1.0 if area > 0.0 else -1.0)
		var rows := []
		for i in n:
			rows.append(PackedVector3Array([rings[i][k], rings[i][k2]]))
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.grid(rows, mat, col, false, false)
		var s := 0.0
		for v in range(vb, b.vertex_count()):
			s += b._n[v].dot(across * out2.x + (normals[(v - vb) / 2] as Vector3) * out2.y)
		if s < 0.0:
			b.flip(vb, ib)
	b.poly(rings[0], -(tangents[0] as Vector3), mat, col)
	b.poly(rings[n - 1], tangents[n - 1], mat, col)


## A flat plate across x: a convex outline in side view (z, y), `th` thick, centred on x.
func _slab(b, outline: PackedVector2Array, x: float, th: float, mat: int, col: Color) -> void:
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	var c := Vector2.ZERO
	for p in outline:
		outer.append(Vector3(x + th * 0.5, p.y, p.x))
		inner.append(Vector3(x - th * 0.5, p.y, p.x))
		c += p
	c /= outline.size()
	b.poly(outer, Vector3.RIGHT, mat, col)
	b.poly(inner, Vector3.LEFT, mat, col)
	for k in outline.size():
		var k2: int = (k + 1) % outline.size()
		var mid: Vector2 = (outline[k] + outline[k2]) * 0.5 - c
		face(b, [outer[k], outer[k2], inner[k2], inner[k]], Vector3(0.0, mid.y, mid.x), mat, col)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## a wide balloon tyre with diamond blocks, round a rim sunk deep in it with twelve turbine spokes.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 44, C_RUBBER)
	var diag := 0.70710678
	for row in TREAD_ROWS:
		var odd: bool = row % 2 == 1
		var f: Array = wheel_frame(TAU * (row + (0.5 if odd else 0.0)) / TREAD_ROWS)
		var r_dir: Vector3 = f[0]
		var t_dir: Vector3 = f[1]
		var xs: Array = [-0.064, 0.0, 0.064] if odd else [-0.098, -0.033, 0.033, 0.098]
		var a1: Vector3 = (Vector3.RIGHT + t_dir) * diag
		var a2: Vector3 = (Vector3.RIGHT - t_dir) * diag
		for x in xs:
			var rc: float = _carcass_r(x) - 0.002
			block(b, r_dir * (rc + 0.4 * BLOCK_H) + Vector3(x, 0.0, 0.0), a1, a2, r_dir, 0.017, BLOCK_H, 0.017, 0.8,
					CB.M_RUBBER, C_RUBBER)
		if odd:
			# Shoulder blocks, leaning out over the sidewalls.
			for sx in [-1.0, 1.0]:
				var up: Vector3 = (r_dir * 0.8 + Vector3(0.6 * sx, 0.0, 0.0)).normalized()
				block(b, r_dir * 0.238 + Vector3(0.137 * sx, 0.0, 0.0), up.cross(t_dir).normalized(), t_dir, up, 0.013,
						0.014, 0.02, 0.8, CB.M_RUBBER, C_RUBBER)
	# Rim: the lip, its face stepping in to the spokes, the barrel, a dark well; the hub and nut.
	wheel_lathe(b, PackedVector2Array([Vector2(0.112, 0.150), Vector2(0.121, 0.157), Vector2(0.128, 0.155),
			Vector2(0.130, 0.146), Vector2(0.124, 0.139)]), 44, CB.M_RIM, C_RIM, "out", Vector3(0.09, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.124, 0.139), Vector2(0.104, 0.136), Vector2(0.086, 0.132)]), 44,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.086, 0.132), Vector2(0.080, 0.146), Vector2(-0.120, 0.149),
			Vector2(-0.130, 0.152)]), 44, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(0.035, 0.0, 0.0), Vector3.RIGHT, 0.14, 0.0, 32, CB.M_DARK, C_DARKER)
	wheel_lathe(b, PackedVector2Array([Vector2(0.066, 0.046), Vector2(0.090, 0.046), Vector2(0.094, 0.040)]), 20,
			CB.M_RIM, C_RIM, "out", Vector3(0.075, 0.0, 0.0))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.094, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.040), Vector2(0.004, 0.034),
			Vector2(0.008, 0.022), Vector2(0.010, 0.0)]), 16, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.075, 0.0, 0.0))
	for k in 12:
		spoke(b, TAU * k / 12.0, 0.38, 0.040, 0.134, 0.088, 0.080, 0.006, 0.0135, 0.014, CB.M_RIM, C_RIM)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


## The carcass's radius at x across the tread (from TYRE_HALF, walked out from the centre, so the
## tread's side of the shoulder answers, not the sidewall's).
static func _carcass_r(x: float) -> float:
	var ax: float = absf(x)
	for k in range(TYRE_HALF.size() - 1, 0, -1):
		var xa: float = -float(TYRE_HALF[k][0])
		var xc: float = -float(TYRE_HALF[k - 1][0])
		if ax >= xa and ax <= xc:
			return lerpf(TYRE_HALF[k][1], TYRE_HALF[k - 1][1], (ax - xa) / (xc - xa))
	return TYRE_HALF[0][1]


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# The radiator intake on the pod's flank behind the cockpit (side view, z y), raked forward.
	shapes["intake"] = _inset(PackedVector2Array([Vector2(0.10, 0.33), Vector2(0.33, 0.33), Vector2(0.36, 0.46),
			Vector2(0.15, 0.46)]), 0.012)
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var gap := 0.0
	var black := 0.0
	var w: float = prof["w"].at(p.z)
	var outside: bool = n.x > 0.5 and p.x > w - 0.006
	# The cockpit: its floor, the inside of the pods, the dash's back and the firewall.
	if p.z > -0.245 and p.z < 0.092 and p.x < 0.262 and p.y < 0.60 and not outside:
		black = 1.0
	if outside:
		# The intake: a black mouth with slats across it.
		var d: float = _sd_rounded(Vector2(p.z, p.y), sh["intake"])
		var slats: float = absf(fposmod(p.y - 0.33 + 0.25 * (p.z - 0.10), 0.032) - 0.016) - 0.0045
		black = maxf(black, _cover(d, fp) * (1.0 - 0.75 * _cover(slats, fp)))
		gap = maxf(gap, _cover(absf(d - 0.012) - 0.0022, fp))
		# Panel seams: a raked one behind the front wheel, a strake low along the pod.
		if p.z > -0.40 and p.z < 0.45:
			gap = maxf(gap, _cover(absf(p.y - 0.305) - 0.0018, fp))
			gap = maxf(gap, _cover(absf((p.z + 0.26) - (p.y - 0.30) * 0.45) - 0.0022, fp) * float(p.y > 0.30))
	# Bonnet: vents in its chamfers, a seam round the ridge.
	if n.y > 0.4 and p.z < -0.26 and p.z > -0.95:
		var ridge: float = prof["ridge_x"].at(p.z)
		gap = maxf(gap, 0.8 * _cover(absf(p.x - ridge) - 0.0018, fp))
		if p.z > -0.66 and p.z < -0.50:
			var vent := 1e3
			for k in 3:
				vent = minf(vent, _sd_box(Vector2(p.x - (ridge + 0.045), p.z + 0.53 + 0.035 * k), Vector2(0.03, 0.006)) - 0.003)
			black = maxf(black, _cover(vent, fp))
	# Rear deck: louvres across the spine.
	if n.y > 0.6 and p.z > 0.22 and p.z < 0.48 and p.x < 0.085:
		var lou: float = absf(fposmod(p.z - 0.22, 0.04) - 0.02) - 0.007
		black = maxf(black, _cover(-lou, fp) * _cover(p.x - 0.075, fp) * _cover(0.235 - p.z, fp) * _cover(p.z - 0.465, fp))
	# Nose: a grille slot in its face.
	if n.z < -0.6:
		var d: float = _sd_box(Vector2(p.x, p.y - 0.405), Vector2(0.05, 0.022)) - 0.004
		var bars: float = absf(fposmod(p.y - 0.383, 0.011) - 0.0055) - 0.0018
		black = maxf(black, _cover(d, fp) * (1.0 - 0.7 * _cover(bars, fp)))
	# Underside.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(0.0, gap, 0.0, black)
