# ViperBuilder.gd
#
# The Viper: a desert trophy truck. A short bonnet on a narrow chassis (its rolled edges come down
# as fender skirts over long-travel A-arms), a dark face with two round lamps and a mesh grille
# behind a tube bumper; flat slab doors on an open two-seat cockpit under a tube cage and a roof
# panel with a light bar; a bed behind the cab between swept fins, carrying a strapped fuel cell
# under a bed cage with amber chase lights; a solid rear axle on coil-overs. Big mud tyres on black
# rims with beadlock rings in the accent colour. Rebuilt in code from its Hunyuan model (the wheels
# where its wheels were); the spare tyre that model carried in the bed is gone.
#
# The section is keyframed like the Centurion's (KEYS, keyed_knots()): above the side, a rounded rim,
# a wall, a corner and a crowned top. Over the bonnet the rim is a big roll and the wall lies flat;
# over the cockpit the wall drops inside the door to the floor; over the bed it drops inside the
# fins to the deck. The dash and the bulkhead behind the seats are clean walls between those
# regions. The wheels stand outboard of the body, so it needs no arches.
extends "res://CarDesign.gd"

# Wheels: the Hunyuan model's positions (tyres 0.234 wide).
const WHEEL_X := 0.527
const AXLE_F := -0.758
const AXLE_R := 0.650
const HUB_Y := 0.279

const W_KNOTS := [[-1.04, 0.26], [-1.00, 0.30], [-0.95, 0.335], [-0.90, 0.355], [-0.80, 0.368], [-0.60, 0.375],
	[-0.475, 0.378], [-0.435, 0.385], [0.95, 0.385], [0.99, 0.372]]
# The bottom: the face down to the bumper, the fender skirts high over the front wheels (clear of
# the tyres at full lock) and lower behind them, the sills, the bed's floor rising behind the cab.
const BOT_KNOTS := [[-1.04, 0.330], [-1.00, 0.320], [-0.96, 0.400], [-0.92, 0.520], [-0.88, 0.570],
	[-0.64, 0.580], [-0.56, 0.540], [-0.50, 0.500], [-0.47, 0.460], [-0.45, 0.300], [-0.43, 0.240], [-0.40, 0.225],
	[0.20, 0.225], [0.26, 0.270], [0.32, 0.400], [0.38, 0.450], [0.99, 0.480]]

# The section above the side, keyframed along the car. Per row: z; belt (the top of the vertical
# side); rr (the rim's rounding); rim_w (the rim's width, from the side in); wall_dx; edge (the
# bonnet, the cockpit floor, the bulkhead, the bed's deck); cx, cy (the corner from the wall onto the
# top: < 0 a floor's fillet, 0 flat); crown.
const KEYS := [
	# z       belt   rr     rim_w  wall_dx edge   cx     cy      crown
	[-1.040, 0.580, 0.040, 0.045, 0.010, 0.625, 0.020, 0.000, 0.010],
	[-1.000, 0.590, 0.045, 0.050, 0.015, 0.640, 0.020, 0.000, 0.012],
	[-0.900, 0.615, 0.055, 0.060, 0.015, 0.672, 0.020, 0.000, 0.015],
	[-0.750, 0.635, 0.058, 0.062, 0.015, 0.695, 0.020, 0.000, 0.016],
	[-0.550, 0.645, 0.058, 0.062, 0.015, 0.705, 0.020, 0.000, 0.016],
	[-0.475, 0.650, 0.058, 0.062, 0.015, 0.712, 0.020, 0.000, 0.016],
	[-0.435, 0.588, 0.012, 0.026, 0.004, 0.270, 0.020, -0.020, 0.000],
	[0.205, 0.588, 0.012, 0.026, 0.004, 0.270, 0.020, -0.020, 0.000],
	[0.245, 0.600, 0.012, 0.026, 0.004, 0.300, 0.020, -0.020, 0.000],
	[0.300, 0.665, 0.012, 0.028, 0.004, 0.500, 0.018, -0.018, 0.000],
	[0.360, 0.760, 0.012, 0.030, 0.004, 0.680, 0.015, -0.015, 0.000],
	[0.420, 0.818, 0.012, 0.030, 0.004, 0.712, 0.015, -0.015, 0.000],
	[0.470, 0.828, 0.012, 0.030, 0.004, 0.720, 0.015, -0.015, 0.000],
	[0.560, 0.828, 0.012, 0.030, 0.004, 0.725, 0.015, -0.015, 0.000],
	[0.605, 0.805, 0.012, 0.030, 0.004, 0.727, 0.015, -0.015, 0.000],
	[0.640, 0.755, 0.012, 0.030, 0.004, 0.729, 0.015, -0.015, 0.000],
	[0.680, 0.743, 0.012, 0.030, 0.004, 0.730, 0.015, -0.015, 0.000],
	[0.950, 0.743, 0.012, 0.030, 0.004, 0.730, 0.015, -0.015, 0.000],
	[0.990, 0.700, 0.012, 0.030, 0.004, 0.700, 0.015, -0.015, 0.000],
]
const KEY_NAMES := ["belt", "rr", "rim_w", "wall_dx", "edge", "cx", "cy", "crown"]

# Tyres: a mud tyre's carcass (half its profile, bead to tread centre) under deep blocks.
const TYRE_HALF := [[-0.103, 0.165], [-0.112, 0.180], [-0.117, 0.200], [-0.118, 0.222], [-0.114, 0.240],
	[-0.105, 0.252], [-0.088, 0.259], [-0.050, 0.2625], [0.0, 0.263]]
const TREAD_ROWS := 22
const BLOCK_H := 0.016

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.21, 0.21, 0.22)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_CAGE := Color(0.10, 0.10, 0.11)
const C_SEAT := Color(0.09, 0.09, 0.10)
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
	"nose_z": -1.04, "tail_z": 0.99, "belt_y": 0.60, "side_x": 0.385,
	"door_z": -0.10, "door_y": 0.42, "roundel_r": 0.085,
	"hood_z": -0.80, "hood_r": 0.065, "stripe_w": 0.06, "stripe_gap": 0.02,
}
const ANTENNA_POS := Vector3(0.22, 0.945, 0.12)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}

# The cage's corners: the roof's front and back (x, y, z of the right-hand tube).
const CAGE_FRONT := Vector3(0.320, 0.925, -0.285)
const CAGE_BACK := Vector3(0.320, 0.925, 0.200)


func _init() -> void:
	nose_tip = -1.040
	nose_cap = 0.040
	nose_cap_y = 0.480
	nose_cap_exp = Vector2(5.0, 4.0)
	tail_tip = 0.990
	tail_cap = 0.030
	tail_cap_y = 0.620
	tail_cap_exp = Vector2(5.0, 4.0)
	# Bottom, bottom corner, side; rim, wall, corner, top.
	segment_counts = [2, 3, 6, 6, 5, 4, 9]
	half_ring = 35
	bottom_radius = 0.02
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[5] + key[8]])
	setup_shell(knots)


## Above the side: the rim (the side's top edge rounding over onto a flat rim_w wide), the wall
## (down into the cockpit or the bed, or lying flat on the bonnet), the corner onto the top, and
## the top, crowned toward the centre line.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var rim_w: float = prof["rim_w"].at(z)
	var rr: float = clampf(prof["rr"].at(z), 0.004, rim_w * 0.95)
	var edge: float = prof["edge"].at(z)
	var cx: float = maxf(prof["cx"].at(z), 0.003)
	var cy: float = prof["cy"].at(z)
	var crown: float = maxf(prof["crown"].at(z), 0.0)
	var rim := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.5 * k / 8.0
		rim.append(Vector2(w - rr + rr * cos(a), belt + rr * sin(a)))
	var a_pt := Vector2(w - rim_w, belt + rr)
	rim.append(a_pt)
	var b_pt := Vector2(a_pt.x - prof["wall_dx"].at(z), edge - cy)
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
	return [rim, PackedVector2Array([a_pt, b_pt]), corner, top]


## Body mesh: shell, chassis, cage and roof, cockpit, bed, lamps, bumpers and suspension.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)
	_seat(b, -0.175)
	_seat(b, 0.175)
	_steering(b, -0.175)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	var tube_r := 0.016
	# Cage: the A-pillar from the door's front corner up to the roof, the roof rail, the main hoop's
	# leg down to the door's back corner, the bed cage's stay back to the tail.
	b.tube(_rounded([Vector3(0.352, 0.592, -0.418), Vector3(0.345, 0.70, -0.40), CAGE_FRONT], 0.05), tube_r, 10, CB.M_DARK,
			C_CAGE, true, false)
	b.tube(PackedVector3Array([CAGE_FRONT, CAGE_BACK]), tube_r, 10, CB.M_DARK, C_CAGE, false, false)
	b.tube(PackedVector3Array([CAGE_BACK, Vector3(0.350, 0.592, 0.212)]), tube_r, 10, CB.M_DARK, C_CAGE, false, true)
	b.tube(_rounded([CAGE_BACK, Vector3(0.335, 0.815, 0.86), Vector3(0.335, 0.745, 0.88)], 0.04), tube_r, 10, CB.M_DARK,
			C_CAGE, false, true)
	# Headlamp: a round lamp in a dark ring on the face.
	var hl: Array = face_frame(0.155, 0.555, true)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(hl[0], hl[1], PackedVector2Array([Vector2(-0.010, 0.056), Vector2(0.008, 0.056), Vector2(0.012, 0.050),
			Vector2(0.010, 0.044)]), 20, CB.M_DARK, C_DARKER)
	b.orient_away_from(vb, ib, (hl[0] as Vector3) - (hl[1] as Vector3) * 0.02)
	round_lamp(b, (hl[0] as Vector3) + (hl[1] as Vector3) * 0.004, hl[1], 0.040, CB.M_HEADLAMP, Color(1, 1, 1))
	# Bonnet: a hood pin strap either side of the raised panel.
	var pin_y: float = top_y(0.165, -0.80)
	b.rbox(Transform3D(Basis(), Vector3(0.165, pin_y + 0.004, -0.80)), Vector3(0.012, 0.006, 0.055), 0.004, 1, CB.M_DARK,
			C_DARK)
	b.tube(PackedVector3Array([Vector3(0.165, pin_y + 0.006, -0.855), Vector3(0.165, pin_y + 0.024, -0.855)]), 0.004, 6,
			CB.M_CHROME, C_CHROME, false, true)
	# Taillamp on the bed's back face.
	var tl: Array = face_frame(0.255, 0.640, false)
	round_lamp(b, tl[0], tl[1], 0.034, CB.M_TAILLAMP, C_TAILLAMP)
	# Door: a latch, bolts down its front and along its foot.
	b.rbox(Transform3D(Basis(), Vector3(0.388, 0.540, 0.140)), Vector3(0.004, 0.012, 0.030), 0.003, 1, CB.M_DARK, C_DARK)
	for k in 5:
		bar(b, Vector3(0.387, 0.27 + 0.075 * k, -0.395), Vector3(0.003, 0.004, 0.004), CB.M_ALLOY, C_ALLOY)
	for k in 6:
		bar(b, Vector3(0.387, 0.262, -0.33 + 0.10 * k), Vector3(0.003, 0.004, 0.004), CB.M_ALLOY, C_ALLOY)
	# Front suspension: long A-arms out to the hub carrier, the coil-over up to its tower under the
	# bonnet, the steering link and the driveshaft.
	var kx := 0.445
	for dz in [-0.09, 0.09]:
		b.tube(PackedVector3Array([Vector3(0.17, 0.255, AXLE_F + dz), Vector3(kx - 0.012, 0.225, AXLE_F)]), 0.012, 8,
				CB.M_DARK, C_STEEL, true, true)
	for dz in [-0.07, 0.07]:
		b.tube(PackedVector3Array([Vector3(0.18, 0.420, AXLE_F + dz), Vector3(kx - 0.014, 0.355, AXLE_F)]), 0.010, 8,
				CB.M_DARK, C_STEEL, true, true)
	b.rbox(Transform3D(Basis(), Vector3(kx, HUB_Y, AXLE_F)), Vector3(0.018, 0.075, 0.032), 0.009, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, AXLE_F), Vector3(0.53, HUB_Y, AXLE_F)]), 0.016, 10, CB.M_ALLOY,
			C_ALLOY_DARK, false, true)
	b.tube(PackedVector3Array([Vector3(0.10, 0.290, AXLE_F), Vector3(kx - 0.01, HUB_Y, AXLE_F)]), 0.010, 8, CB.M_ALLOY,
			C_ALLOY_DARK, false, false)
	b.tube(PackedVector3Array([Vector3(0.15, 0.330, AXLE_F + 0.07), Vector3(kx - 0.01, 0.315, AXLE_F + 0.04)]), 0.007, 6,
			CB.M_DARK, C_STEEL, false, false)
	coilover(b, Vector3(0.365, 0.245, AXLE_F - 0.015), Vector3(0.250, 0.560, AXLE_F + 0.035), 0.017, 0.028, 7.0, C_ALLOY,
			C_ALLOY_DARK, C_CHROME, C_DARK)
	# Rear suspension: two links forward to the chassis, the coil-over up to the bed's floor.
	for y in [0.235, 0.330]:
		b.tube(PackedVector3Array([Vector3(0.22, y + 0.02, AXLE_R - 0.42), Vector3(0.30, y, AXLE_R - 0.02)]), 0.011, 8,
				CB.M_DARK, C_STEEL, true, true)
	coilover(b, Vector3(0.300, 0.300, AXLE_R + 0.02), Vector3(0.260, 0.460, AXLE_R - 0.05), 0.017, 0.028, 6.0, C_ALLOY,
			C_ALLOY_DARK, C_CHROME, C_DARK)
	b.tube(PackedVector3Array([Vector3(0.36, HUB_Y, AXLE_R), Vector3(0.53, HUB_Y, AXLE_R)]), 0.016, 10, CB.M_ALLOY,
			C_ALLOY_DARK, false, true)
	# Tow hook at the front.
	b.tube(_rounded([Vector3(0.11, 0.425, -1.06), Vector3(0.11, 0.425, -1.11), Vector3(0.15, 0.425, -1.11),
			Vector3(0.15, 0.425, -1.06)], 0.015), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)


func _centre_parts(b) -> void:
	var tube_r := 0.016
	# Cage across the car: the roof's front and back bars, a harness bar behind the seats, the bed
	# cage's back bar with two amber chase lights.
	for bar_pts in [[Vector3(-CAGE_FRONT.x, CAGE_FRONT.y, CAGE_FRONT.z), CAGE_FRONT],
			[Vector3(-CAGE_BACK.x, CAGE_BACK.y, CAGE_BACK.z), CAGE_BACK],
			[Vector3(-0.335, 0.760, 0.205), Vector3(0.335, 0.760, 0.205)],
			[Vector3(-0.335, 0.815, 0.86), Vector3(0.335, 0.815, 0.86)]]:
		b.tube(PackedVector3Array(bar_pts), tube_r, 10, CB.M_DARK, C_CAGE, false, false)
	for x in [-0.10, 0.10]:
		b.rbox(Transform3D(Basis(), Vector3(x, 0.840, 0.868)), Vector3(0.032, 0.026, 0.014), 0.008, 2, CB.M_DARK, C_DARK)
		round_lamp(b, Vector3(x, 0.840, 0.884), Vector3.BACK, 0.020, CB.M_TAILLAMP, C_AMBER)
	# Roof panel (in the paint), its back edge kicked up; a light bar under its front edge.
	var roof := PackedVector3Array()
	for p in [[-0.312, 0.938], [0.170, 0.942], [0.210, 0.952], [0.232, 0.972]]:
		roof.append(Vector3(0.0, p[1], p[0]))
	sweep(b, roof, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.338, -0.006), Vector2(0.338, -0.006),
			Vector2(0.338, 0.004), Vector2(0.315, 0.010), Vector2(-0.315, 0.010), Vector2(-0.338, 0.004)]), CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.902, -0.296)), Vector3(0.255, 0.022, 0.018), 0.008, 2, CB.M_DARK, C_DARK)
	for k in 6:
		round_lamp(b, Vector3(-0.20 + 0.08 * k, 0.902, -0.315), Vector3.FORWARD, 0.016, CB.M_HEADLAMP, Color(1, 1, 1))
	# The face: a mesh grille between the lamps.
	var gr: Array = face_frame(0.0, 0.555, true)
	var gb: Basis = facing(gr[1])
	b.rbox(Transform3D(gb, gr[0]), Vector3(0.085, 0.048, 0.010), 0.012, 2, CB.M_DARK, C_DARKER)
	for k in 5:
		bar(b, (gr[0] as Vector3) + gb.y * (-0.036 + 0.018 * k) + gb.z * 0.009, Vector3(0.078, 0.003, 0.003), CB.M_DARK,
				C_MESH)
	for k in 9:
		bar(b, (gr[0] as Vector3) + gb.x * (-0.072 + 0.018 * k) + gb.z * 0.009, Vector3(0.003, 0.042, 0.003), CB.M_DARK,
				C_MESH)
	# Bonnet: a raised panel down its middle (in the paint).
	var bulge := PackedVector3Array()
	for k in 9:
		var z: float = lerpf(-0.975, -0.56, k / 8.0)
		bulge.append(Vector3(0.0, top_y(0.0, z) - 0.004, z))
	sweep(b, bulge, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.125, 0.0), Vector2(0.125, 0.0),
			Vector2(0.100, 0.024), Vector2(-0.100, 0.024)]), CB.M_PAINT, Color(1, 1, 1))
	# The chassis under the bonnet, a skid plate under it, the tube bumper in front.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.400, -0.71)), Vector3(0.19, 0.180, 0.29), 0.02, 2, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.30), Vector3(0.0, 0.245, -1.02)), Vector3(0.17, 0.005, 0.07), 0.004, 1,
			CB.M_ALLOY, C_ALLOY_DARK)
	b.tube(_rounded([Vector3(-0.30, 0.470, -1.01), Vector3(-0.27, 0.470, -1.075), Vector3(0.27, 0.470, -1.075),
			Vector3(0.30, 0.470, -1.01)], 0.04), 0.021, 12, CB.M_DARK, C_STEEL, true, true)
	b.tube(_rounded([Vector3(-0.18, 0.395, -1.03), Vector3(-0.16, 0.395, -1.065), Vector3(0.16, 0.395, -1.065),
			Vector3(0.18, 0.395, -1.03)], 0.03), 0.016, 10, CB.M_DARK, C_STEEL, true, true)
	for x in [-0.09, 0.09]:
		b.tube(PackedVector3Array([Vector3(x, 0.395, -1.068), Vector3(x, 0.470, -1.078)]), 0.013, 8, CB.M_DARK, C_STEEL,
				false, false)
	# The rear axle: tube, diff with its cover; a tube bumper under the bed's back, a tow hook.
	b.tube(PackedVector3Array([Vector3(-0.37, HUB_Y, AXLE_R), Vector3(0.37, HUB_Y, AXLE_R)]), 0.026, 12, CB.M_DARK, C_STEEL,
			true, true)
	b.rbox(Transform3D(Basis(), Vector3(0.0, HUB_Y, AXLE_R)), Vector3(0.075, 0.068, 0.062), 0.05, 3, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.0, HUB_Y, AXLE_R + 0.065)), Vector3(0.055, 0.05, 0.008), 0.024, 2,
			CB.M_ANODISED, Color(1, 1, 1))
	b.tube(PackedVector3Array([Vector3(0.0, HUB_Y + 0.01, AXLE_R - 0.06), Vector3(0.0, 0.32, -0.40)]), 0.013, 8,
			CB.M_ALLOY, C_ALLOY_DARK, false, false)
	b.tube(_rounded([Vector3(-0.30, 0.440, 0.95), Vector3(-0.27, 0.440, 1.015), Vector3(0.27, 0.440, 1.015),
			Vector3(0.30, 0.440, 0.95)], 0.04), 0.018, 10, CB.M_DARK, C_STEEL, true, true)
	b.tube(_rounded([Vector3(-0.025, 0.43, 1.00), Vector3(-0.025, 0.43, 1.05), Vector3(0.025, 0.43, 1.05),
			Vector3(0.025, 0.43, 1.00)], 0.015), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)
	# The bed: a fuel cell strapped down on the deck, its filler cap.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.782, 0.52)), Vector3(0.21, 0.055, 0.12), 0.022, 2, CB.M_ALLOY, C_ALLOY)
	for dz in [-0.065, 0.065]:
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.784, 0.52 + dz)), Vector3(0.214, 0.058, 0.010), 0.006, 1, CB.M_ANODISED,
				Color(1, 1, 1))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.12, 0.836, 0.47), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.032), Vector2(0.012, 0.032),
			Vector2(0.016, 0.026), Vector2(0.017, 0.0)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.12, 0.83, 0.47))
	# The dash: a panel under the cowl, a switch strip on it.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.0, 0.56, -0.415)), Vector3(0.34, 0.05, 0.012), 0.008, 1,
			CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.10, 0.575, -0.405)), Vector3(0.07, 0.012, 0.004), 0.002, 1,
			CB.M_ANODISED, Color(1, 1, 1))


## A bucket seat on the cockpit floor: cushion, raked back with bolsters and a head surround,
## harness straps in the accent colour.
func _seat(b, x: float) -> void:
	var floor_y := 0.270
	b.rbox(Transform3D(Basis(), Vector3(x, floor_y + 0.045, -0.06)), Vector3(0.125, 0.04, 0.14), 0.02, 2, CB.M_DARK, C_SEAT)
	var rake := Basis(Vector3.RIGHT, 0.22)
	var back_c := Vector3(x, floor_y + 0.27, 0.11)
	b.rbox(Transform3D(rake, back_c), Vector3(0.125, 0.23, 0.035), 0.02, 2, CB.M_DARK, C_SEAT)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.112 * sx, -0.05, -0.04)), Vector3(0.02, 0.18, 0.05), 0.015, 2,
				CB.M_DARK, C_SEAT)
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.05 * sx, 0.0, -0.038)), Vector3(0.013, 0.20, 0.003), 0.002, 1,
				CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, 0.24, -0.012)), Vector3(0.08, 0.06, 0.035), 0.022, 2, CB.M_DARK,
			C_SEAT)


## The steering wheel before the driver's seat, on a column into the dash.
func _steering(b, x: float) -> void:
	var c := Vector3(x, 0.565, -0.30)
	var tilt := Basis(Vector3.RIGHT, -0.40)
	var ring := PackedVector3Array()
	for k in 25:
		var a: float = TAU * k / 24.0
		ring.append(c + tilt * Vector3(cos(a) * 0.075, sin(a) * 0.075, 0.0))
	b.tube(ring, 0.009, 6, CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([c + tilt * Vector3(-0.072, 0.0, 0.0), c + tilt * Vector3(0.072, 0.0, 0.0)]), 0.007, 6,
			CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([c, c + Vector3(0.0, 0.0, -0.11)]), 0.012, 8, CB.M_DARK, C_DARK, true, false)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## a mud tyre with deep blocks and shoulder lugs, round a ten-spoke rim with a beadlock ring in the
## accent colour.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 44, C_RUBBER)
	for row in TREAD_ROWS:
		var odd: bool = row % 2 == 1
		var f: Array = wheel_frame(TAU * (row + (0.5 if odd else 0.0)) / TREAD_ROWS)
		var r_dir: Vector3 = f[0]
		var t_dir: Vector3 = f[1]
		var xs: Array = [-0.068, 0.0, 0.068] if odd else [-0.034, 0.034]
		for x in xs:
			var rc: float = carcass_r(TYRE_HALF, x) - 0.002
			var skew: Vector3 = (Vector3.RIGHT + t_dir * (0.25 if odd else -0.25)).normalized()
			block(b, r_dir * (rc + 0.4 * BLOCK_H) + Vector3(x, 0.0, 0.0), skew, t_dir, r_dir, 0.026, BLOCK_H, 0.020, 0.82,
					CB.M_RUBBER, C_RUBBER)
		# Shoulder lugs, long on alternate rows, leaning out over the sidewalls.
		for sx in [-1.0, 1.0]:
			var up: Vector3 = (r_dir * 0.75 + Vector3(0.66 * sx, 0.0, 0.0)).normalized()
			var lug: float = 0.020 if odd else 0.013
			block(b, r_dir * 0.236 + Vector3(0.105 * sx, 0.0, 0.0), up.cross(t_dir).normalized(), t_dir, up, lug, 0.014,
					0.020, 0.8, CB.M_RUBBER, C_RUBBER)
	# Rim: the lip, its face stepping in to the spokes, the barrel, a dark well behind the spokes.
	wheel_lathe(b, PackedVector2Array([Vector2(0.090, 0.160), Vector2(0.098, 0.166), Vector2(0.104, 0.164),
			Vector2(0.106, 0.156), Vector2(0.100, 0.151)]), 44, CB.M_RIM, C_RIM, "out", Vector3(0.08, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.100, 0.151), Vector2(0.088, 0.149), Vector2(0.078, 0.147)]), 44, CB.M_RIM,
			C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.078, 0.147), Vector2(0.072, 0.157), Vector2(-0.095, 0.160),
			Vector2(-0.103, 0.165)]), 44, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(0.030, 0.0, 0.0), Vector3.RIGHT, 0.150, 0.0, 32, CB.M_DARK, C_DARKER)
	# Beadlock ring over the tyre's bead, bolted round.
	wheel_lathe(b, PackedVector2Array([Vector2(0.104, 0.151), Vector2(0.112, 0.152), Vector2(0.116, 0.158),
			Vector2(0.116, 0.172), Vector2(0.111, 0.177), Vector2(0.100, 0.178)]), 44, CB.M_ANODISED, Color(1, 1, 1), "out",
			Vector3(0.09, 0.0, 0.0))
	for k in 16:
		var g: Array = wheel_frame(TAU * (k + 0.5) / 16.0)
		bar(b, (g[0] as Vector3) * 0.165 + Vector3(0.118, 0.0, 0.0), Vector3(0.003, 0.004, 0.004), CB.M_CHROME, C_CHROME)
	# Hub and nut; ten spokes.
	wheel_lathe(b, PackedVector2Array([Vector2(0.060, 0.044), Vector2(0.086, 0.044), Vector2(0.090, 0.038)]), 20, CB.M_RIM,
			C_RIM, "out", Vector3(0.07, 0.0, 0.0))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.090, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.038), Vector2(0.005, 0.032),
			Vector2(0.009, 0.020), Vector2(0.011, 0.0)]), 16, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.07, 0.0, 0.0))
	for k in 10:
		spoke(b, TAU * k / 10.0, 0.0, 0.040, 0.146, 0.084, 0.078, 0.008, 0.011, 0.014, CB.M_RIM, C_RIM)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# The door in side view (z, y).
	shapes["door"] = _inset(PackedVector2Array([Vector2(-0.405, 0.240), Vector2(0.200, 0.240), Vector2(0.200, 0.580),
			Vector2(-0.405, 0.580)]), 0.03)
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var gap := 0.0
	var black := 0.0
	var w: float = prof["w"].at(p.z)
	var outside: bool = n.x > 0.5 and p.x > w - 0.006
	var inner_x: float = w - prof["rim_w"].at(p.z) + 0.004
	# The cockpit: its floor, the insides of the doors, the dash's back and the bulkhead.
	if p.z > -0.445 and p.z < 0.37 and p.x < inner_x and p.y < 0.62 and not outside:
		black = 1.0
	# The bed: a liner over its deck.
	if p.z > 0.35 and p.z < tail_tip - 0.005 and p.x < inner_x and not outside and n.y > 0.5:
		black = 1.0
	if outside:
		# The door's shut line.
		if p.z > -0.44 and p.z < 0.24:
			gap = maxf(gap, _cover(absf(_sd_rounded(Vector2(p.z, p.y), sh["door"])) - 0.0022, fp))
		# A seam along the bed's flank.
		if p.z > 0.32:
			gap = maxf(gap, 0.8 * _cover(absf(p.y - 0.53) - 0.0018, fp))
	# The face: dark between the fender tips, behind the lamps and the grille.
	if n.z < -0.55 and p.z < -0.97:
		var d: float = _sd_box(Vector2(p.x, p.y - 0.555), Vector2(0.23, 0.075)) - 0.012
		black = maxf(black, _cover(d, fp))
	# Bonnet: a seam round it at the cowl.
	if n.y > 0.5 and p.z < -0.40 and p.z > -0.50:
		gap = maxf(gap, _cover(absf(p.z + 0.468) - 0.002, fp))
	# Underside.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(0.0, gap, 0.0, black)
