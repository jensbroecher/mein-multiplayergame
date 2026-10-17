# CenturionBuilder.gd
#
# The Centurion: a sand rail. A slim armoured tub slung between long A-arms, an open cockpit under a
# tube cage (in the paint job's accent colour) with a roof panel, the engine behind the seats under a
# slatted cover, a big rear wing, and paddle tyres on all four corners. Rebuilt in code from its
# Hunyuan model, which stood on narrow front wheels like a dragster; here the fronts match the rears.
#
# The shell's section is keyed like the Strikeforce's (KEYS, keyed_knots()): a crowned deck over the
# nose and over the engine, and over the cockpit a trough (the wall runs down inside the side armour
# to the floor), so the dash and the firewall are clean walls between the regions. The wheels stand
# well outboard of the tub, so it needs no wheel arches.
extends "res://CarDesign.gd"

# Wheels: the Hunyuan model's rear positions; the fronts at its front axle, on the same track.
const WHEEL_X := 0.61
const AXLE_F := -0.90
const AXLE_R := 0.48
const HUB_Y := 0.254

const W_KNOTS := [[-1.12, 0.075], [-1.06, 0.12], [-0.98, 0.18], [-0.86, 0.24], [-0.72, 0.29], [-0.60, 0.33],
	[-0.45, 0.355], [-0.10, 0.365], [0.20, 0.36], [0.28, 0.34], [0.36, 0.305], [0.45, 0.30], [0.875, 0.30]]
const BOT_KNOTS := [[-1.12, 0.33], [-1.07, 0.27], [-1.00, 0.20], [-0.93, 0.17], [0.70, 0.17], [0.77, 0.19],
	[0.84, 0.25], [0.875, 0.28]]

# The section above the side, keyframed along the car (see StrikeforceBuilder): z; belt (top of the
# side, where the rim's rounding starts); rim_w (the deck's edge, the top of the cockpit's side
# armour); wall_dx; edge (deck, cockpit floor, engine cover); cx, cy (the corner onto the top: < 0
# the cockpit floor's fillet, 0 flat); crown.
const KEYS := [
	# z       belt   rim_w  wall_dx edge   cx     cy      crown
	[-1.120, 0.362, 0.012, 0.010, 0.372, 0.010, 0.000, 0.005],
	[-1.000, 0.405, 0.018, 0.015, 0.417, 0.015, 0.000, 0.010],
	[-0.860, 0.462, 0.024, 0.022, 0.474, 0.022, 0.000, 0.014],
	[-0.720, 0.530, 0.030, 0.028, 0.542, 0.028, 0.000, 0.016],
	[-0.630, 0.570, 0.035, 0.030, 0.582, 0.030, 0.000, 0.016],
	[-0.605, 0.552, 0.040, 0.000, 0.235, 0.014, -0.014, 0.000],
	[0.270, 0.480, 0.040, 0.000, 0.235, 0.014, -0.014, 0.000],
	[0.295, 0.585, 0.035, 0.030, 0.597, 0.030, 0.000, 0.010],
	[0.875, 0.585, 0.035, 0.030, 0.597, 0.030, 0.000, 0.010],
]
const KEY_NAMES := ["belt", "rim_w", "wall_dx", "edge", "cx", "cy", "crown"]
const RIM_R := 0.012

# Tyres: a balloon carcass (half its profile, bead to tread centre) and the paddles on it.
const TYRE_HALF := [[-0.110, 0.150], [-0.122, 0.161], [-0.131, 0.177], [-0.134, 0.194], [-0.131, 0.209],
	[-0.121, 0.219], [-0.098, 0.2245], [-0.050, 0.2265], [0.0, 0.227]]
const PADDLES := 12
const PADDLE_H := 0.027
const PADDLE_T := 0.020
const PADDLE_SPAN := 0.126
const PADDLE_SWEEP := 0.11       # radians the paddle's ends trail its middle by: a shallow V

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.20, 0.20, 0.21)
const C_DARK := Color(0.07, 0.07, 0.075)
const C_DARKER := Color(0.035, 0.035, 0.04)
const C_SEAT := Color(0.10, 0.10, 0.11)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.80, 0.81, 0.83)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.12, "tail_z": 0.875, "belt_y": 0.56, "side_x": 0.36,
	"door_z": -0.18, "door_y": 0.40, "roundel_r": 0.105,
	"hood_z": -0.86, "hood_r": 0.075, "stripe_w": 0.055, "stripe_gap": 0.022,
}
const ANTENNA_POS := Vector3(0.29, 0.715, 0.25)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.120
	nose_cap = 0.035
	nose_cap_y = 0.360
	nose_cap_exp = Vector2(2.5, 2.0)
	tail_tip = 0.875
	tail_cap = 0.020
	tail_cap_y = 0.450
	tail_cap_exp = Vector2(6.0, 6.0)
	# Bottom, bottom corner, side; rim, wall, corner, top.
	segment_counts = [2, 3, 5, 5, 4, 4, 9]
	half_ring = 32
	bottom_radius = 0.02
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[4] + key[7]])
	setup_shell(knots)


## Above the side: the rim (the side's top edge rounding over onto a flat rim_w wide), the wall
## (down into the cockpit, or lying flat on a deck), the corner onto the top, and the top, crowned
## toward the centre line by a cosine bump (level at both ends, so no crease).
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var rim_w: float = prof["rim_w"].at(z)
	var rr: float = minf(RIM_R, rim_w * 0.7)
	var edge: float = prof["edge"].at(z)
	var cx: float = maxf(prof["cx"].at(z), 0.003)
	var cy: float = prof["cy"].at(z)
	var crown: float = maxf(prof["crown"].at(z), 0.0)
	var rim := PackedVector2Array()
	for k in 7:
		var a: float = PI * 0.5 * k / 6.0
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


## Body mesh: shell, cage and roof, cockpit, wing, lamps, suspension and running gear.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)
	_seat(b, -0.155)
	_seat(b, 0.155)
	_steering(b, -0.155)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	var tube_r := 0.017
	# Cage: an A-pillar sweeping from the nose up to the roof, the roof rail, the main hoop's leg,
	# a brace back to the engine cover, a door bar along the cockpit's edge, a nerf bar low down.
	b.tube(_rounded([Vector3(0.16, 0.38, -1.00), Vector3(0.29, 0.56, -0.74), Vector3(0.285, 0.745, -0.43)], 0.09),
			tube_r, 10, CB.M_ANODISED, Color(1, 1, 1), true, false)
	b.tube(PackedVector3Array([Vector3(0.285, 0.745, -0.43), Vector3(0.30, 0.705, 0.25)]), tube_r, 10, CB.M_ANODISED,
			Color(1, 1, 1), false, false)
	b.tube(_rounded([Vector3(0.30, 0.705, 0.25), Vector3(0.335, 0.56, 0.25), Vector3(0.335, 0.49, 0.25)], 0.05),
			tube_r, 10, CB.M_ANODISED, Color(1, 1, 1), false, true)
	b.tube(PackedVector3Array([Vector3(0.30, 0.705, 0.25), Vector3(0.25, 0.60, 0.79)]), 0.015, 10, CB.M_ANODISED,
			Color(1, 1, 1), false, true)
	b.tube(PackedVector3Array([Vector3(0.315, 0.62, -0.66), Vector3(0.345, 0.545, 0.25)]), 0.014, 10, CB.M_ANODISED,
			Color(1, 1, 1), true, false)
	b.tube(_rounded([Vector3(0.30, 0.21, -0.62), Vector3(0.39, 0.21, -0.52), Vector3(0.39, 0.21, 0.16),
			Vector3(0.30, 0.21, 0.27)], 0.07), 0.016, 10, CB.M_ANODISED, Color(1, 1, 1), true, true)
	# Lamp pod on the roof's front corner.
	_lamp_pod(b, Vector3(0.20, 0.802, -0.40))
	# Wing endplate and swan-neck strut.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0.468, 0.708, 0.778)), Vector3(0.006, 0.036, 0.122), 0.004, 1,
			CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0.17, 0.655, 0.77)), Vector3(0.008, 0.05, 0.045), 0.004, 1,
			CB.M_DARK, C_DARK)
	# Taillamp on the rear face; an exhaust tip under it.
	b.rbox(Transform3D(Basis(), Vector3(0.205, 0.535, tail_tip + 0.006)), Vector3(0.055, 0.016, 0.006), 0.004, 1,
			CB.M_TAILLAMP, C_TAILLAMP)
	b.tube(PackedVector3Array([Vector3(0.10, 0.335, 0.84), Vector3(0.10, 0.335, 0.93)]), 0.022, 14, CB.M_CHROME, C_CHROME,
			false, false)
	b.disc(Vector3(0.10, 0.335, 0.929), Vector3.BACK, 0.018, 0.0, 14, CB.M_DARK, C_DARKER)
	# Bolt heads down the armour's seams.
	for zs in [-0.20, 0.29]:
		var w: float = prof["w"].at(zs)
		for k in 5:
			var y: float = 0.215 + 0.06 * k
			if y < prof["belt"].at(zs) - 0.02:
				for side in [-1.0, 1.0]:
					bar(b, Vector3(w + 0.003, y, zs + 0.016 * side), Vector3(0.003, 0.0045, 0.0045), CB.M_ALLOY, C_ALLOY)
	# Amber marker on the nose's flank.
	b.rbox(Transform3D(Basis(Vector3.UP, -0.55), Vector3(0.155, 0.36, -1.02)), Vector3(0.004, 0.012, 0.03), 0.003, 1,
			CB.M_TAILLAMP, C_AMBER)
	_suspension(b, AXLE_F, 1.0)
	_suspension(b, AXLE_R, -1.0)


## One corner's suspension (right side): double A-arms out to the hub carrier, a coil-over leaning
## in to the body, the driveshaft. `fz` points toward the middle of the car.
func _suspension(b, az: float, fz: float) -> void:
	var kx := 0.50
	for dz in [-0.09, 0.09]:
		b.tube(PackedVector3Array([Vector3(0.15, 0.205, az + dz), Vector3(kx - 0.012, 0.19, az)]), 0.012, 8,
				CB.M_ALLOY, C_ALLOY, true, true)
	for dz in [-0.065, 0.065]:
		b.tube(PackedVector3Array([Vector3(0.16, 0.345, az + dz), Vector3(kx - 0.016, 0.325, az)]), 0.010, 8,
				CB.M_ALLOY, C_ALLOY, true, true)
	b.rbox(Transform3D(Basis(), Vector3(kx, HUB_Y, az)), Vector3(0.018, 0.078, 0.032), 0.009, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, az), Vector3(0.565, HUB_Y, az)]), 0.016, 10, CB.M_ALLOY, C_ALLOY_DARK,
			false, true)
	b.tube(PackedVector3Array([Vector3(0.11, 0.255, az), Vector3(kx - 0.01, HUB_Y, az)]), 0.010, 8, CB.M_ALLOY,
			C_ALLOY_DARK, false, false)
	coilover(b, Vector3(0.40, 0.21, az + 0.03 * fz), Vector3(0.21, 0.50, az + 0.05 * fz), 0.017, 0.028, 7.0,
			C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)


func _centre_parts(b) -> void:
	var tube_r := 0.017
	# Cage across the car: the front hoop's top, the main hoop's top, the windscreen's centre bar.
	b.tube(PackedVector3Array([Vector3(-0.285, 0.745, -0.43), Vector3(0.285, 0.745, -0.43)]), tube_r, 10, CB.M_ANODISED,
			Color(1, 1, 1), false, false)
	b.tube(PackedVector3Array([Vector3(-0.30, 0.705, 0.25), Vector3(0.30, 0.705, 0.25)]), tube_r, 10, CB.M_ANODISED,
			Color(1, 1, 1), false, false)
	b.tube(PackedVector3Array([Vector3(0.0, 0.575, -0.665), Vector3(0.0, 0.75, -0.43)]), 0.014, 10, CB.M_ANODISED,
			Color(1, 1, 1), true, false)
	# Front bumper hoop round the nose; a skid plate under it.
	b.tube(_rounded([Vector3(-0.15, 0.25, -1.02), Vector3(-0.10, 0.27, -1.17), Vector3(0.10, 0.27, -1.17),
			Vector3(0.15, 0.25, -1.02)], 0.06), 0.017, 10, CB.M_ANODISED, Color(1, 1, 1), true, true)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0.0, 0.215, -1.02)), Vector3(0.12, 0.005, 0.10), 0.004, 1,
			CB.M_ALLOY, C_ALLOY_DARK)
	# Roof panel on the cage, slightly lower at the back, with a scoop over the windscreen.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.058), Vector3(0.0, 0.744, -0.09)), Vector3(0.305, 0.007, 0.36), 0.006, 2,
			CB.M_PAINT, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.058), Vector3(0.0, 0.774, -0.33)), Vector3(0.085, 0.017, 0.075), 0.012, 2,
			CB.M_PAINT, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.058), Vector3(0.0, 0.778, -0.406)), Vector3(0.066, 0.010, 0.003), 0.002, 1,
			CB.M_DARK, C_DARKER)
	# Rear wing: the plane (in the paint), raised at its trailing edge, with a gurney lip.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0.0, 0.715, 0.775)), Vector3(0.465, 0.009, 0.115), 0.007, 2,
			CB.M_PAINT, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.752, 0.886)), Vector3(0.465, 0.012, 0.004), 0.003, 1, CB.M_DARK, C_DARK)
	# Rear face: a grille between the lamps, a tow loop.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.445, tail_tip + 0.004)), Vector3(0.16, 0.055, 0.006), 0.006, 1,
			CB.M_DARK, C_DARKER)
	for k in 4:
		bar(b, Vector3(0.0, 0.412 + 0.022 * k, tail_tip + 0.012), Vector3(0.15, 0.0045, 0.004), CB.M_ALLOY, C_ALLOY_DARK)
	b.tube(_rounded([Vector3(-0.035, 0.30, 0.86), Vector3(-0.035, 0.30, 0.92), Vector3(0.035, 0.30, 0.92),
			Vector3(0.035, 0.30, 0.86)], 0.02), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)
	# Running gear: transaxle with its cover, a belly skid plate.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.265, AXLE_R + 0.03)), Vector3(0.11, 0.07, 0.09), 0.025, 2, CB.M_DARK,
			C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.265, AXLE_R + 0.123)), Vector3(0.07, 0.05, 0.006), 0.02, 2, CB.M_ANODISED,
			Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.160, -0.22)), Vector3(0.24, 0.004, 0.48), 0.003, 1, CB.M_ALLOY,
			C_ALLOY_DARK)


## A round lamp pod facing forward: a dark can, a chrome bezel, the lens.
func _lamp_pod(b, c: Vector3) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, Vector3.FORWARD, PackedVector2Array([Vector2(-0.055, 0.0), Vector2(-0.053, 0.026), Vector2(-0.045, 0.038),
			Vector2(-0.030, 0.043), Vector2(-0.004, 0.044), Vector2(0.002, 0.041)]), 18, CB.M_DARK, C_DARK)
	b.orient_away_from(vb, ib, c + Vector3.BACK * 0.025)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(c, Vector3.FORWARD, PackedVector2Array([Vector2(-0.004, 0.0445), Vector2(0.005, 0.0445),
			Vector2(0.008, 0.041), Vector2(0.006, 0.037)]), 18, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, c + Vector3.BACK * 0.02)
	lens(b, c + Vector3.FORWARD * 0.002, Vector3.FORWARD, 0.0375, 0.008, 18)
	# Its bracket down to the roof.
	b.rbox(Transform3D(Basis(), c + Vector3(0.0, -0.040, 0.025)), Vector3(0.008, 0.016, 0.012), 0.003, 1, CB.M_DARK, C_DARK)


## A bucket seat on the cockpit floor: cushion, raked back with side bolsters and a head surround,
## harness straps in the accent colour.
func _seat(b, x: float) -> void:
	var floor_y := 0.235
	b.rbox(Transform3D(Basis(), Vector3(x, floor_y + 0.04, -0.01)), Vector3(0.112, 0.035, 0.13), 0.02, 2, CB.M_DARK, C_SEAT)
	var rake := Basis(Vector3.RIGHT, 0.24)
	var back_c := Vector3(x, floor_y + 0.22, 0.16)
	b.rbox(Transform3D(rake, back_c), Vector3(0.112, 0.17, 0.032), 0.02, 2, CB.M_DARK, C_SEAT)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.10 * sx, -0.03, -0.035)), Vector3(0.018, 0.14, 0.045), 0.014, 2,
				CB.M_DARK, C_SEAT)
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.045 * sx, 0.0, -0.036)), Vector3(0.012, 0.15, 0.003), 0.002, 1,
				CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, 0.185, -0.01)), Vector3(0.075, 0.05, 0.03), 0.02, 2, CB.M_DARK,
			C_SEAT)


## The steering wheel before the driver's seat, on a column into the dash.
func _steering(b, x: float) -> void:
	var c := Vector3(x, 0.505, -0.34)
	var tilt := Basis(Vector3.RIGHT, -0.45)
	var ring := PackedVector3Array()
	for k in 25:
		var a: float = TAU * k / 24.0
		ring.append(c + tilt * Vector3(cos(a) * 0.072, sin(a) * 0.072, 0.0))
	b.tube(ring, 0.009, 6, CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([c + tilt * Vector3(-0.07, 0.0, 0.0), c + tilt * Vector3(0.07, 0.0, 0.0)]), 0.007, 6,
			CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([c, c + Vector3(0.0, -0.05, -0.20)]), 0.012, 8, CB.M_DARK, C_DARK, true, false)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## a balloon paddle tyre round a six-spoke rim.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 44, C_RUBBER)
	for k in PADDLES:
		_paddle(b, TAU * k / PADDLES)
	# Rim: the outer lip, a dark well behind six spokes, the hub and its nut.
	wheel_lathe(b, PackedVector2Array([Vector2(0.104, 0.151), Vector2(0.116, 0.154), Vector2(0.123, 0.149),
			Vector2(0.124, 0.128), Vector2(0.118, 0.123)]), 44, CB.M_RIM, C_RIM, "out", Vector3(0.09, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.118, 0.123), Vector2(0.104, 0.120), Vector2(0.092, 0.112)]), 44,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.092, 0.112), Vector2(0.084, 0.140), Vector2(-0.100, 0.146),
			Vector2(-0.110, 0.150)]), 44, CB.M_RIM, Color(0.6, 0.6, 0.62), "in")
	b.disc(Vector3(0.06, 0.0, 0.0), Vector3.RIGHT, 0.14, 0.0, 32, CB.M_DARK, C_DARKER)
	wheel_lathe(b, PackedVector2Array([Vector2(0.070, 0.046), Vector2(0.100, 0.046), Vector2(0.104, 0.040)]), 20,
			CB.M_RIM, C_RIM, "out", Vector3(0.085, 0.0, 0.0))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.104, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.040), Vector2(0.004, 0.034),
			Vector2(0.008, 0.022), Vector2(0.010, 0.0)]), 16, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.085, 0.0, 0.0))
	for k in 6:
		spoke(b, TAU * k / 6.0, 0.0, 0.040, 0.118, 0.098, 0.092, 0.016, 0.030, 0.014, CB.M_RIM, C_RIM)
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


## One paddle at angle a0: a blade standing PADDLE_H off the carcass across the tread, following
## its curve and tapering down the shoulders, its ends swept back into a shallow V.
func _paddle(b, a0: float) -> void:
	var n := 9
	var faces := [[], [], []]    # front, top, back: rows of [inner, outer] points across the tread
	var mid := Vector3.ZERO
	for s in n:
		var t: float = float(s) / (n - 1) * 2.0 - 1.0
		var x: float = t * PADDLE_SPAN
		var f: Array = wheel_frame(a0 - absf(t) * PADDLE_SWEEP)
		var r_dir: Vector3 = f[0]
		var t_dir: Vector3 = f[1]
		var rc: float = _carcass_r(x) - 0.003
		# Stand up along the carcass's normal in its profile, so the ends lean out over the
		# shoulders with it instead of jutting from them like fins.
		var slope: float = (_carcass_r(x + 0.002) - _carcass_r(x - 0.002)) / 0.004
		var up: Vector3 = (r_dir - Vector3(slope, 0.0, 0.0)).normalized()
		var base_f: Vector3 = r_dir * rc + t_dir * (PADDLE_T * 0.5) + Vector3(x, 0.0, 0.0)
		var base_b: Vector3 = r_dir * rc - t_dir * (PADDLE_T * 0.5) + Vector3(x, 0.0, 0.0)
		# Full height across the tread, tapering into the shoulders.
		var h: float = PADDLE_H * (1.0 - 0.7 * pow(absf(t), 3.0)) + 0.003
		var tip_f: Vector3 = base_f + up * h - t_dir * 0.003
		var tip_b: Vector3 = base_b + up * h + t_dir * 0.003
		faces[0].append(PackedVector3Array([base_f, tip_f]))
		faces[1].append(PackedVector3Array([tip_f, tip_b]))
		faces[2].append(PackedVector3Array([tip_b, base_b]))
		mid += (base_f + base_b + tip_f + tip_b) * 0.25
		if s == 0 or s == n - 1:
			var cap_n: Vector3 = Vector3(-1.0 if s == 0 else 1.0, 0.0, 0.0)
			b.poly(PackedVector3Array([base_f, tip_f, tip_b, base_b]), cap_n, CB.M_RUBBER, C_RUBBER)
	mid /= n
	for rows in faces:
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.grid(rows, CB.M_RUBBER, C_RUBBER, false, false)
		b.orient_away_from(vb, ib, mid)


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	return {}


func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var gap := 0.0
	var black := 0.0
	var w: float = prof["w"].at(p.z)
	var outside: bool = n.x > 0.5 and p.x > w - 0.006
	# The cockpit tub: its floor, the inside of the armour, the dash's back and the firewall.
	if p.z > -0.635 and p.z < 0.30 and not outside and n.y < 0.95:
		if n.x < -0.45 or (n.y > 0.45 and p.y < 0.45) or (n.z > 0.4 and p.z < -0.55) or (n.z < -0.4 and p.z > 0.2):
			black = 1.0
	if p.z > -0.635 and p.z < 0.30 and n.y > 0.45 and p.y < 0.45:
		black = 1.0
	if outside:
		# Armour seams: the panels meet at the dash, mid-cockpit and the firewall; a lower strake.
		for zs in [-0.625, -0.20, 0.29]:
			gap = maxf(gap, _cover(absf(p.z - zs) - 0.0022, fp) * float(p.y > 0.18 and p.y < 0.6))
		if p.z > -0.62 and p.z < 0.86:
			gap = maxf(gap, 0.8 * _cover(absf(p.y - 0.30) - 0.0018, fp))
		# Engine bay vents on the flanks.
		if p.z > 0.40 and p.z < 0.78 and p.y > 0.37 and p.y < 0.53:
			var slots := 1e3
			for k in 4:
				slots = minf(slots, _sd_box(Vector2(p.z - 0.59, p.y - (0.392 + 0.036 * k)), Vector2(0.16, 0.0075)) - 0.004)
			black = maxf(black, _cover(slots, fp))
	# Engine cover: slats across it.
	if n.y > 0.8 and p.z > 0.38 and p.z < 0.82 and p.x < 0.225:
		var bars: float = absf(fposmod(p.z - 0.38, 0.055) - 0.0275) - 0.009
		black = maxf(black, _cover(-bars, fp) * _cover(p.x - 0.215, fp) * _cover(0.39 - p.z, fp) * _cover(p.z - 0.81, fp))
	# Nose deck: a panel seam round it, an intake ahead of the dash.
	if n.y > 0.4 and p.z < -0.62:
		gap = maxf(gap, _cover(absf(p.x - (prof["w"].at(p.z) - 0.035)) - 0.002, fp))
		if p.z > -0.80 and p.z < -0.69 and p.x > 0.05 and p.x < 0.20:
			var vent := 1e3
			for k in 3:
				vent = minf(vent, _sd_box(Vector2(p.x - 0.125, p.z + 0.775 - 0.03 * k), Vector2(0.065, 0.006)) - 0.003)
			black = maxf(black, _cover(vent, fp))
	# Underside.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(0.0, gap, 0.0, black)
