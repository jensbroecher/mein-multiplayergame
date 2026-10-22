# VortexBuilder.gd
#
# The Vortex: a high-downforce aero truggy / hypercar crossover, shaped after its reference photo:
# - Very low, wide slab nose with a raised centre power dome and hood V-creases
# - 4 circular RC pin clip holes flush on the hood
# - A big black double-deck front aero wing swallowed under the nose: its outboard tips curl up,
#   with vertical endplates between the wing's two blades, a shark-fin chin plate and strakes
#   under the nose
# - Steeply raked cockpit: one continuous tinted glass bubble canopy wrapping from the cowl over
#   the roof and down the sides (no separate side windows), plus a louvred glass hatch panel on
#   the rear deck
# - Big black fender flares sweeping over the wide-track front and rear tires
# - Tubular side nerf bars with step rungs under the sills
# - Vertical side-pod intake slots ahead of the rear arches
# - High-mounted GT gull-wing rear wing on twin raked struts over a triangular roll cage
# - Wide-track all-terrain stadium truck tires with aggressive tread blocks
# - Deep-dish black multi-spoke rims with a signature crisp white outer lip ring
# - Exposed double wishbone suspension with tall coilover dampers tucked under the hood
extends "res://CarDesign.gd"

# Wheels: wide stadium truck track with generous body clearance (WHEEL_X = 0.830,
# tire inner face at 0.702 vs body flank at 0.420) so the front wheels can steer freely at full lock
const WHEEL_X := 0.830
const AXLE_F := -0.743
const AXLE_R := 0.620
const HUB_Y := 0.260

# Tub half-width (w) along the car (z): a wide slab nose, pinched at the doors, and the wheel
# zones kept well inside the tires' inner faces (0.512) so they stand clear of the body; the black
# flares, held on stays, carry the track's muscle over the wheel tops.
const W_KNOTS := [
	[-1.140, 0.335], [-1.000, 0.375], [-0.900, 0.405], [-0.800, 0.418],
	[-0.680, 0.428], [-0.560, 0.430], [-0.440, 0.428], [-0.300, 0.405],
	[-0.100, 0.412], [ 0.060, 0.418], [ 0.220, 0.428], [ 0.370, 0.418],
	[ 0.500, 0.415], [ 0.620, 0.415], [ 0.760, 0.425], [ 0.880, 0.400],
	[ 0.960, 0.330]
]

# Tub bottom (bot) along the car:
# A low nose lip (0.195) for the front wing to swallow, the belly under the doors at 0.24-0.25,
# and the rear tail sweeping up into the diffuser (0.31).
const BOT_KNOTS := [
	[-1.140, 0.195], [-1.000, 0.225], [-0.860, 0.235], [-0.740, 0.240],
	[-0.580, 0.245], [-0.440, 0.245], [-0.100, 0.245], [ 0.200, 0.248],
	[ 0.440, 0.252], [ 0.620, 0.258], [ 0.800, 0.272], [ 0.900, 0.292],
	[ 0.960, 0.312]
]

# Section keyframes along the car:
# z: position along car
# belt: height of vertical side / rocker top
# sx, sy: shoulder crease position (wide hip / hood edge)
# rx, ry: roof rail / inner hood crease position
# top: centre line top height
# crown: dome / dish of top surface (+ dome, - dish)
const KEYS := [
	# z       belt    sx     sy     rx     ry     top    crown
	[-1.140, 0.215, 0.300, 0.260, 0.170, 0.262, 0.278, 0.024], # slab nose tip, hood raised a touch
	[-1.000, 0.245, 0.365, 0.320, 0.230, 0.335, 0.354, 0.036], # hood rising over the fenders
	[-0.860, 0.282, 0.400, 0.384, 0.260, 0.408, 0.422, 0.042], # front fender plane
	[-0.740, 0.330, 0.415, 0.426, 0.270, 0.462, 0.488, 0.044], # front axle plane (fender crest)
	[-0.580, 0.360, 0.420, 0.454, 0.282, 0.494, 0.530, 0.038], # cowl ramp
	[-0.440, 0.380, 0.420, 0.476, 0.300, 0.540, 0.560, 0.028], # windshield base / cowl edge
	[-0.260, 0.405, 0.380, 0.525, 0.270, 0.625, 0.645, 0.014], # windshield mid
	[-0.100, 0.415, 0.385, 0.535, 0.258, 0.655, 0.675, 0.012], # roof header
	[ 0.060, 0.425, 0.390, 0.545, 0.250, 0.660, 0.680, 0.012], # roof peak
	[ 0.220, 0.440, 0.405, 0.555, 0.242, 0.650, 0.658, 0.010], # C-pillar drop
	[ 0.440, 0.455, 0.430, 0.565, 0.225, 0.610, 0.622, 0.006], # haunch rise / deck
	[ 0.620, 0.465, 0.450, 0.578, 0.212, 0.588, 0.590, 0.004], # rear axle haunch (under the flare)
	[ 0.800, 0.455, 0.405, 0.570, 0.192, 0.578, 0.580, 0.002], # rear deck
	[ 0.900, 0.435, 0.335, 0.552, 0.170, 0.560, 0.562, 0.002], # tail transition
	[ 0.960, 0.405, 0.275, 0.530, 0.145, 0.538, 0.538, 0.000], # tail blade
]
const KEY_NAMES := ["belt", "sx", "sy", "rx", "ry", "top", "crown"]

# Mudguard arches over the wide-track stadium tires
const REAR_LIP := [
	[0.255, 0.395], [0.330, 0.455], [0.430, 0.520], [0.560, 0.548], [0.660, 0.550],
	[0.760, 0.540], [0.855, 0.520], [0.925, 0.485], [0.955, 0.452]
]
const FRONT_LIP := [
	[-0.378, 0.395], [-0.453, 0.455], [-0.553, 0.520], [-0.683, 0.548], [-0.783, 0.550],
	[-0.883, 0.535], [-0.965, 0.490], [-1.030, 0.425], [-1.085, 0.350]
]
const FENDER_IN := 0.690
const FENDER_OUT := 0.970
const FENDER_DEPTH := 0.035

# Tires: High-traction stadium truck carcass with aggressive tread blocks
const TYRE_HALF := [
	[-0.112, 0.155], [-0.122, 0.168], [-0.128, 0.188], [-0.128, 0.208], [-0.125, 0.228],
	[-0.116, 0.244], [-0.098, 0.255], [-0.060, 0.259], [0.0, 0.260]
]
const TREAD_ROWS := 24
const BLOCK_H := 0.015

# Palette (sRGB; shader linearises vertex colours)
const C_RUBBER := Color(0.18, 0.18, 0.19)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.022, 0.022, 0.025)
const C_CARBON := Color(0.075, 0.075, 0.08)
const C_STEEL := Color(0.14, 0.14, 0.15)
const C_ALLOY := Color(0.82, 0.83, 0.85)
const C_ALLOY_DARK := Color(0.44, 0.45, 0.47)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(0.06, 0.06, 0.07)
const C_RIM_BARREL := Color(0.03, 0.03, 0.035)
const C_WHITE_RING := Color(0.98, 0.98, 1.0)
const C_TAILLAMP := Color(0.98, 0.04, 0.03)

## Paint layout for car_body.gdshader's patterns
const PAINT_LAYOUT := {
	"nose_z": -1.14, "tail_z": 0.96, "belt_y": 0.44, "side_x": 0.45,
	"door_z": -0.05, "door_y": 0.40, "roundel_r": 0.075,
	"hood_z": -0.78, "hood_r": 0.065, "stripe_w": 0.065, "stripe_gap": 0.022,
}
const ANTENNA_POS := Vector3(0.18, 0.672, 0.16)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.140
	nose_cap = 0.030
	nose_cap_y = 0.242
	nose_cap_exp = Vector2(5.2, 3.2)
	tail_tip = 0.960
	tail_cap = 0.025
	tail_cap_y = 0.470
	tail_cap_exp = Vector2(4.5, 3.0)
	# Half-ring segment counts: [bottom, corner, side, lower_shoulder, upper_shoulder, roof_corner, top]
	segment_counts = [2, 3, 4, 4, 5, 5, 8]
	half_ring = 31
	bottom_radius = 0.025
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	setup_shell(knots)


## The section above the beltline: sculpted shoulder crease, raked glass tumblehome,
## rounded roof rail, crowned canopy/hood with center spine.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var sx: float = minf(prof["sx"].at(z), w - 0.005)
	var sy: float = maxf(prof["sy"].at(z), belt + 0.005)
	var rx: float = minf(prof["rx"].at(z), sx - 0.015)
	var ry: float = maxf(prof["ry"].at(z), sy + 0.010)
	var crown: float = prof["crown"].at(z)

	# 1. Belt to shoulder crease: angled muscular tumble
	var shoulder := PackedVector2Array()
	for k in 5:
		var t: float = float(k) / 4.0
		shoulder.append(Vector2(lerpf(w, sx, t), lerpf(belt, sy, t)))

	# 2. Shoulder to roof corner / upper rail: raked side glass / A-pillar
	var glass_side := PackedVector2Array()
	for k in 6:
		var t: float = float(k) / 5.0
		glass_side.append(Vector2(lerpf(sx, rx, t), lerpf(sy, ry, t)))

	# 3. Roof corner / rail rounding
	var r_fillet := 0.018
	var rail := PackedVector2Array()
	for k in 6:
		var a: float = PI * 0.5 * k / 5.0
		rail.append(Vector2(rx - r_fillet * (1.0 - cos(a)), ry + r_fillet * sin(a)))

	# 4. Crowned top from rail in to centreline (0, top), with pronounced center power spine
	var top_pts := PackedVector2Array()
	var x_in: float = rx - r_fillet
	for k in 9:
		var t: float = float(k) / 8.0
		var x: float = lerpf(x_in, 0.0, t)
		var bump: float = crown * sin(t * PI * 0.5)
		top_pts.append(Vector2(x, lerpf(ry + r_fillet, top, t) + bump))

	return [
		PackedVector2Array([shoulder[0], shoulder[2], shoulder[4]]),
		glass_side,
		rail,
		top_pts
	]


## Body mesh: lofts shell, builds splitter, nerf bars, rear wing, suspension, lamps, intake pods.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)
	_cockpit(b)


## Dedicated 3D curved mudguard arch over a wide-track tire, with downturned inner and outer
## lips, crowned top, and inner liner.
func _build_truggy_fender(b, lip: Array, hub_z: float, hub_y: float, x_in: float, x_out: float, depth: float) -> void:
	var spine: PackedVector2Array = _spine(lip, 36)
	var n: int = spine.size()
	var outer_rows := []
	var liner_rows := []
	var x_mid := (x_in + x_out) * 0.5

	for k in n:
		var t2: Vector2 = (spine[mini(k + 1, n - 1)] - spine[maxi(k - 1, 0)]).normalized()
		var n2 := Vector2(t2.y, -t2.x)
		if n2.dot(spine[k] - Vector2(hub_z, hub_y)) < 0.0:
			n2 = -n2

		var end_dist: float = minf(float(k), float(n - 1 - k))
		var sc: float = clampf(end_dist / 2.0, 0.70, 1.0)
		var d: float = depth * sc
		var xi: float = lerpf(x_mid, x_in, sc)
		var xo: float = lerpf(x_mid, x_out, sc)

		# 6-point profile across the tire: outer downturned lip, outer shoulder, crowned center, inner shoulder, inner downturned lip
		var p_outer: Array = [
			Vector2(xo, -0.024 * sc),
			Vector2(xo - 0.012, 0.003),
			Vector2(lerpf(xi, xo, 0.68), d * 0.35),
			Vector2(lerpf(xi, xo, 0.32), d * 0.35),
			Vector2(xi + 0.012, 0.003),
			Vector2(xi, -0.020 * sc)
		]

		var out_row := PackedVector3Array()
		var in_row := PackedVector3Array()
		for pt in p_outer:
			var disp: float = pt.y
			out_row.append(Vector3(pt.x, spine[k].y + disp * n2.y, spine[k].x + disp * n2.x))
			in_row.append(Vector3(pt.x, spine[k].y + (disp - 0.006) * n2.y, spine[k].x + (disp - 0.006) * n2.x))

		outer_rows.append(out_row)
		liner_rows.append(in_row)

	var base: int = b.vertex_count()
	var ibase: int = b.index_count()
	b.grid(outer_rows, CB.M_DARK, C_DARK, false, false)
	b.orient_away_from(base, ibase, Vector3(x_mid, hub_y, hub_z))

	base = b.vertex_count()
	ibase = b.index_count()
	b.grid(liner_rows, CB.M_DARK, Color(0.025, 0.025, 0.03), false, false)
	b.orient_toward(base, ibase, Vector3(x_mid, hub_y, hub_z))

	# End caps closing the front and rear tips
	for end_idx in [0, n - 1]:
		var r_out: PackedVector3Array = outer_rows[end_idx]
		var r_in: PackedVector3Array = liner_rows[end_idx]
		var cap := PackedVector3Array()
		for pt in r_out:
			cap.append(pt)
		for j in range(r_in.size() - 1, -1, -1):
			cap.append(r_in[j])
		var end_t := (spine[1] - spine[0]).normalized() if end_idx == 0 else (spine[n - 1] - spine[n - 2]).normalized()
		var cap_norm := Vector3(0.0, -end_t.y, -end_t.x) if end_idx == 0 else Vector3(0.0, end_t.y, end_t.x)
		b.poly(cap, cap_norm, CB.M_DARK, C_DARK)


## Tubular steel support structures firmly anchoring the front and rear mudguards to the chassis.
func _fender_supports(b) -> void:
	var f_in := FENDER_IN
	# -------------------------------------------------------------------------
	# Front Fender Supports
	# -------------------------------------------------------------------------
	# 1. Front stanchion arm (nose frame -> front of fender)
	var f_nose_chassis := Vector3(0.360, 0.260, -0.980)
	var f_fender_front := Vector3(f_in + 0.020, 0.365, -1.020)
	b.rbox(Transform3D(Basis(), f_nose_chassis), Vector3(0.016, 0.020, 0.020), 0.004, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), f_fender_front), Vector3(0.014, 0.016, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([f_nose_chassis, Vector3(0.520, 0.315, -1.000), f_fender_front]), 0.010, 8, CB.M_DARK, C_DARK, true, true)

	# 2. Main A-frame center truss (chassis cowl/shock tower -> fender apex)
	var f_chassis_mid := Vector3(0.390, 0.430, AXLE_F)
	var f_fender_apex_f := Vector3(f_in + 0.030, 0.540, AXLE_F - 0.110)
	var f_fender_apex_r := Vector3(f_in + 0.030, 0.540, AXLE_F + 0.110)
	b.rbox(Transform3D(Basis(), f_chassis_mid), Vector3(0.018, 0.025, 0.035), 0.005, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), f_fender_apex_f), Vector3(0.014, 0.016, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), f_fender_apex_r), Vector3(0.014, 0.016, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([f_chassis_mid, f_fender_apex_f]), 0.009, 8, CB.M_DARK, C_DARK, true, true)
	b.tube(PackedVector3Array([f_chassis_mid, f_fender_apex_r]), 0.009, 8, CB.M_DARK, C_DARK, true, true)
	b.tube(PackedVector3Array([Vector3(0.540, 0.485, AXLE_F - 0.055), Vector3(0.540, 0.485, AXLE_F + 0.055)]), 0.007, 6, CB.M_DARK, C_DARK, false, false)

	# 3. Rear trailing arm (chassis sill/firewall -> rear of front fender)
	var f_sill_rear := Vector3(0.405, 0.355, -0.460)
	var f_fender_rear := Vector3(f_in + 0.020, 0.405, -0.435)
	b.rbox(Transform3D(Basis(), f_sill_rear), Vector3(0.016, 0.020, 0.020), 0.004, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), f_fender_rear), Vector3(0.014, 0.016, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([f_sill_rear, Vector3(0.540, 0.380, -0.450), f_fender_rear]), 0.010, 8, CB.M_DARK, C_DARK, true, true)

	# -------------------------------------------------------------------------
	# Rear Fender Supports
	# -------------------------------------------------------------------------
	var r_in := FENDER_IN
	# 1. Front leading arm (side pod/sill -> front of rear fender)
	var r_sill_front := Vector3(0.420, 0.380, 0.290)
	var r_fender_front := Vector3(r_in + 0.020, 0.410, 0.300)
	b.rbox(Transform3D(Basis(), r_sill_front), Vector3(0.016, 0.020, 0.020), 0.004, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), r_fender_front), Vector3(0.014, 0.016, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([r_sill_front, Vector3(0.550, 0.395, 0.295), r_fender_front]), 0.010, 8, CB.M_DARK, C_DARK, true, true)

	# 2. Main A-frame center truss (rear haunch/deck -> fender apex)
	var r_chassis_mid := Vector3(0.420, 0.530, AXLE_R)
	var r_fender_apex_f := Vector3(r_in + 0.030, 0.545, AXLE_R - 0.110)
	var r_fender_apex_r := Vector3(r_in + 0.030, 0.545, AXLE_R + 0.110)
	b.rbox(Transform3D(Basis(), r_chassis_mid), Vector3(0.018, 0.025, 0.035), 0.005, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), r_fender_apex_f), Vector3(0.014, 0.016, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), r_fender_apex_r), Vector3(0.014, 0.016, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([r_chassis_mid, r_fender_apex_f]), 0.009, 8, CB.M_DARK, C_DARK, true, true)
	b.tube(PackedVector3Array([r_chassis_mid, r_fender_apex_r]), 0.009, 8, CB.M_DARK, C_DARK, true, true)
	b.tube(PackedVector3Array([Vector3(0.555, 0.538, AXLE_R - 0.055), Vector3(0.555, 0.538, AXLE_R + 0.055)]), 0.007, 6, CB.M_DARK, C_DARK, false, false)

	# 3. Rear trailing arm (rear taillight frame -> rear of fender)
	var r_frame_rear := Vector3(0.350, 0.440, 0.920)
	var r_fender_rear := Vector3(r_in + 0.020, 0.440, 0.940)
	b.rbox(Transform3D(Basis(), r_frame_rear), Vector3(0.016, 0.020, 0.020), 0.004, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), r_fender_rear), Vector3(0.014, 0.016, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([r_frame_rear, Vector3(0.535, 0.440, 0.930), r_fender_rear]), 0.010, 8, CB.M_DARK, C_DARK, true, true)


## Side components built on +X then mirrored across X = 0
func _side_parts(b) -> void:
	var knuckle_x := WHEEL_X - 0.065

	# -------------------------------------------------------------------------
	# 1. Front Suspension & Steering (Wishbones & Coilover Tucked Safely Under Hood)
	# -------------------------------------------------------------------------
	var k_front := AXLE_F
	# Lower A-arm
	b.tube(PackedVector3Array([Vector3(0.18, 0.220, k_front - 0.14), Vector3(knuckle_x - 0.01, 0.210, k_front)]), 0.012, 8, CB.M_DARK, C_STEEL, true, true)
	b.tube(PackedVector3Array([Vector3(0.18, 0.220, k_front + 0.12), Vector3(knuckle_x - 0.01, 0.210, k_front)]), 0.012, 8, CB.M_DARK, C_STEEL, true, true)
	# Upper A-arm
	b.tube(PackedVector3Array([Vector3(0.22, 0.315, k_front - 0.10), Vector3(knuckle_x - 0.01, 0.295, k_front)]), 0.010, 8, CB.M_DARK, C_STEEL, true, true)
	b.tube(PackedVector3Array([Vector3(0.22, 0.315, k_front + 0.09), Vector3(knuckle_x - 0.01, 0.295, k_front)]), 0.010, 8, CB.M_DARK, C_STEEL, true, true)
	# Upright / knuckle & hub
	b.rbox(Transform3D(Basis(), Vector3(knuckle_x, HUB_Y, k_front)), Vector3(0.018, 0.075, 0.034), 0.008, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(knuckle_x, HUB_Y, k_front), Vector3(WHEEL_X - 0.02, HUB_Y, k_front)]), 0.016, 10, CB.M_ALLOY, C_ALLOY_DARK, false, true)
	# Tie rod
	b.tube(PackedVector3Array([Vector3(0.18, 0.235, k_front + 0.08), Vector3(knuckle_x - 0.01, 0.225, k_front + 0.04)]), 0.009, 6, CB.M_DARK, C_STEEL, false, false)
	# Coilover shock tucked inside wheel well under the hood
	coilover(b, Vector3(0.515, 0.215, k_front), Vector3(0.260, 0.340, k_front), 0.017, 0.028, 6.5, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)

	# -------------------------------------------------------------------------
	# 2. Rear Suspension (Trailing Arms & Coilovers)
	# -------------------------------------------------------------------------
	var k_rear := AXLE_R
	# Lower trailing wishbone
	b.tube(PackedVector3Array([Vector3(0.18, 0.235, k_rear - 0.18), Vector3(knuckle_x - 0.01, 0.225, k_rear)]), 0.013, 8, CB.M_DARK, C_STEEL, true, true)
	b.tube(PackedVector3Array([Vector3(0.18, 0.235, k_rear + 0.11), Vector3(knuckle_x - 0.01, 0.225, k_rear)]), 0.013, 8, CB.M_DARK, C_STEEL, true, true)
	# Upper camber link
	b.tube(PackedVector3Array([Vector3(0.22, 0.340, k_rear - 0.09), Vector3(knuckle_x - 0.01, 0.320, k_rear)]), 0.011, 8, CB.M_DARK, C_STEEL, true, true)
	# Knuckle & axle
	b.rbox(Transform3D(Basis(), Vector3(knuckle_x, HUB_Y, k_rear)), Vector3(0.018, 0.076, 0.034), 0.008, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(knuckle_x, HUB_Y, k_rear), Vector3(WHEEL_X - 0.02, HUB_Y, k_rear)]), 0.016, 10, CB.M_ALLOY, C_ALLOY_DARK, false, true)
	# Rear coilover shock under the haunch
	coilover(b, Vector3(0.525, 0.230, k_rear + 0.02), Vector3(0.280, 0.420, k_rear - 0.02), 0.018, 0.030, 7.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)

	# -------------------------------------------------------------------------
	# 3. Big black front and rear fender flares & structural support trusses
	# -------------------------------------------------------------------------
	_build_truggy_fender(b, FRONT_LIP, AXLE_F, HUB_Y, FENDER_IN, FENDER_OUT, FENDER_DEPTH)
	_build_truggy_fender(b, REAR_LIP, AXLE_R, HUB_Y, FENDER_IN, FENDER_OUT, FENDER_DEPTH)
	_fender_supports(b)

	# -------------------------------------------------------------------------
	# 5. Tubular Side Nerf Bar (Signature Feature from Photo) — the rail's own tips and
	# two angled braces anchor up into the tub floor so it hangs off the chassis
	# -------------------------------------------------------------------------
	var nerf_y := 0.175
	var nerf_outer_x := 0.520
	var nerf_path := PackedVector3Array([
		Vector3(0.368, prof["bot"].at(-0.240) - 0.002, -0.240),
		Vector3(nerf_outer_x, nerf_y, -0.170),
		Vector3(nerf_outer_x, nerf_y,  0.220),
		Vector3(0.368, prof["bot"].at(0.290) - 0.002,  0.290)
	])
	b.tube(_rounded(nerf_path, 0.04), 0.015, 8, CB.M_DARK, C_DARK, true, true)
	# Two angled braces tying the rail up into the tub floor between the anchored tips
	for r_z in [-0.050, 0.140]:
		var brace_bot: float = prof["bot"].at(r_z)
		b.tube(PackedVector3Array([
			Vector3(nerf_outer_x - 0.004, nerf_y + 0.004, r_z),
			Vector3(0.426, nerf_y + 0.042, r_z),
			Vector3(0.370, brace_bot - 0.001, r_z)
		]), 0.011, 6, CB.M_DARK, C_DARK, false, false)

	# -------------------------------------------------------------------------
	# 6. Side pod intakes: tall vertical slot at the rear quarter + small lower vent
	# -------------------------------------------------------------------------
	var slot_c := Vector3(0.448, 0.522, 0.470)
	b.rbox(Transform3D(Basis(Vector3.UP, -0.30), slot_c), Vector3(0.011, 0.046, 0.030), 0.004, 1, CB.M_DARK, C_DARKER)
	for k in 2:
		bar(b, Vector3(0.452, 0.522, 0.448 + 0.026 * k), Vector3(0.010, 0.036, 0.0025), CB.M_DARK, C_DARK)
	var low_c := Vector3(0.446, 0.385, 0.300)
	b.rbox(Transform3D(Basis(Vector3.UP, -0.12), low_c), Vector3(0.012, 0.040, 0.024), 0.004, 1, CB.M_DARK, C_DARKER)
	bar(b, low_c + Vector3(0.002, 0.0, -0.012), Vector3(0.010, 0.030, 0.0025), CB.M_DARK, C_DARK)

	# -------------------------------------------------------------------------
	# 7. Flush RC Body Pin Holes (4 Recessed Round Dark Holes on Hood)
	# -------------------------------------------------------------------------
	var post_f := Vector3(0.185, top_y(0.185, -0.845) + 0.002, -0.845)
	b.disc(post_f + Vector3(0, 0.001, 0), Vector3.UP, 0.018, 0.000, 16, CB.M_DARK, C_DARKER)
	var post_r := Vector3(0.205, top_y(0.205, -0.565) + 0.002, -0.565)
	b.disc(post_r + Vector3(0, 0.001, 0), Vector3.UP, 0.018, 0.000, 16, CB.M_DARK, C_DARKER)

	# -------------------------------------------------------------------------
	# 8. Sleek Wing Mirrors
	# -------------------------------------------------------------------------
	var mir_c := Vector3(0.368, 0.515, -0.240)
	b.tube(PackedVector3Array([Vector3(0.320, 0.488, -0.240), mir_c]), 0.007, 6, CB.M_DARK, C_CARBON, true, false)
	var mir_xf := Transform3D(Basis(Vector3.UP, -0.16) * Basis(Vector3.RIGHT, 0.05), mir_c + Vector3(0.030, 0.008, 0.0))
	b.rbox(mir_xf, Vector3(0.028, 0.014, 0.018), 0.005, 1, CB.M_PAINT, Color(1, 1, 1))
	b.rbox(mir_xf * Transform3D(Basis(), Vector3(0.0, 0.0, 0.014)), Vector3(0.022, 0.010, 0.003), 0.002, 1, CB.M_CHROME, C_CHROME)

	# -------------------------------------------------------------------------
	# 9. Rear Corner Taillight Blade & Exhaust
	# -------------------------------------------------------------------------
	b.rbox(Transform3D(Basis(), Vector3(0.245, 0.486, 0.954)), Vector3(0.038, 0.012, 0.007), 0.003, 1, CB.M_TAILLAMP, C_TAILLAMP)
	b.rbox(Transform3D(Basis(), Vector3(0.215, 0.452, 0.956)), Vector3(0.024, 0.008, 0.007), 0.003, 1, CB.M_TAILLAMP, C_TAILLAMP)
	var ex_c := Vector3(0.105, 0.350, 0.948)
	b.tube(PackedVector3Array([ex_c + Vector3(0, 0, -0.06), ex_c + Vector3(0, 0, 0.038)]), 0.018, 12, CB.M_ALLOY, C_ALLOY, false, false)
	b.tube(PackedVector3Array([ex_c + Vector3(0, 0, -0.05), ex_c + Vector3(0, 0, 0.039)]), 0.015, 10, CB.M_DARK, C_DARKER, false, false)


## The front aero wing's swept blade path from left tip to right tip: the centre sits low under
## the nose and the outboard tips rise ("fangs"), pulling back only outboard of the tub's flank
## so the blades wrap clear of the body. `low` drops to the splitter deck below it and pulls
## forward; the low deck stays flatter.
func _wing_path(low: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var lift: float = 0.196 * (0.30 if low > 0.0 else 1.0)
	var y0: float = 0.148 if low > 0.0 else 0.204
	var pull: float = 0.24 if low > 0.0 else 0.27
	var zc: float = -1.262 if low > 0.0 else -1.226
	for k in 19:
		var f: float = k / 18.0
		var u: float = lerpf(-1.0, 1.0, f)
		var ax: float = absf(u)
		var p: float = pow(maxf(ax - 0.30, 0.0) / 0.70, 1.35)
		var z: float = zc + pull * pow(maxf(ax - 0.78, 0.0) / 0.22, 1.9 if low <= 0.0 else 1.7)
		out.append(Vector3(0.48 * u, y0 + lift * p, z))
	return out


## Centreline components: the double-deck front wing, roof runners, rear wing, roll cage, diffuser.
func _centre_parts(b) -> void:
	# -------------------------------------------------------------------------
	# 1. Massive Front Aero Wing Assembly (Signature Feature from Photo)
	# -------------------------------------------------------------------------
	# Upper main deck: a big swept blade wrapping round the nose, tips curling up
	sweep(b, _wing_path(0.0), Vector3.BACK, Vector3.UP,
		PackedVector2Array([Vector2(0.052, -0.006), Vector2(0.052, 0.006), Vector2(-0.052, 0.006),
			Vector2(-0.052, -0.006)]), CB.M_DARK, C_DARK)
	# Lower splitter deck: a slim second blade ahead of and below the main one
	sweep(b, _wing_path(1.0), Vector3.BACK, Vector3.UP,
		PackedVector2Array([Vector2(0.038, -0.004), Vector2(0.038, 0.004), Vector2(-0.038, 0.004),
			Vector2(-0.038, -0.004)]), CB.M_DARK, C_DARK)
	# Full-width flat splitter plate under the nose
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.146, -1.218)), Vector3(0.420, 0.007, 0.115), 0.005, 1, CB.M_DARK, C_DARK)
	# Shark-fin chin plate dropping from the nose's lower lip between the two decks
	slab(b, PackedVector2Array([Vector2(-1.030, 0.225), Vector2(-1.158, 0.205), Vector2(-1.190, 0.132),
		Vector2(-1.112, 0.108)]), 0.0, 0.010, CB.M_DARK, C_DARK)
	# Two wall strakes ramping from the wing decks up to the nose bottom
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.18) * Basis(Vector3.UP, 0.10 * sx), Vector3(0.105 * sx, 0.172, -1.098)),
			Vector3(0.005, 0.050, 0.080), 0.002, 1, CB.M_DARK, C_DARK)
	# Vertical endplates linking the two decks at each tip
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(Vector3.UP, -0.55 * sx), Vector3(0.495 * sx, 0.300, -1.018)),
			Vector3(0.006, 0.098, 0.042), 0.003, 1, CB.M_DARK, C_DARK)
	# Dark intake mesh in the gap between the nose bottom and the wing's upper deck
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.215, -1.092)), Vector3(0.215, 0.010, 0.016), 0.004, 1, CB.M_DARK, C_DARKER)
	for x in [-0.162, -0.054, 0.054, 0.162]:
		bar(b, Vector3(x, 0.215, -1.092), Vector3(0.0035, 0.010, 0.016), CB.M_DARK, C_DARK)
	# RC grille on the nose's shield face: two stepped black bars, their fronts landing right at the
	# tip plane (the superellipse cap keeps the face full-width almost to the tip, so a plane here
	# grazes the skin everywhere and reads as a proud inset grille — widths stay inside the shield)
	for grille in [[0.233, 0.300], [0.256, 0.280]]:
		b.rbox(Transform3D(Basis(), Vector3(0.0, grille[0], -1.130)),
			Vector3(grille[1], 0.0075, 0.010), 0.003, 1, CB.M_DARK, C_DARK)

	# (The two green roof runner tubes were removed: the canopy is one clean glass bubble.)

	# -------------------------------------------------------------------------
	# 3. High-Mounted GT Gull-Wing Rear Wing & Struts (Signature Feature from Photo)
	# -------------------------------------------------------------------------
	var wing_y := 0.835
	var wing_z := 0.925
	var wing_basis := Basis(Vector3.RIGHT, 0.14)

	# Center section of wing blade (span X = -0.22 to +0.22)
	b.rbox(Transform3D(wing_basis, Vector3(0.0, wing_y, wing_z)), Vector3(0.220, 0.009, 0.075), 0.005, 1, CB.M_DARK, C_DARK)

	# Outer wing panels kicking slightly upward (gull-wing dihedral) and downturned tips
	for sx in [-1.0, 1.0]:
		var out_c := Vector3(0.335 * sx, wing_y + 0.012, wing_z)
		b.rbox(Transform3D(Basis(Vector3.FORWARD, 0.08 * sx) * wing_basis, out_c), Vector3(0.125, 0.008, 0.075), 0.004, 1, CB.M_DARK, C_DARK)
		# Downturned Winglet Endplates at X = ±0.465 (curve down and back as in photo)
		var ep_c := Vector3(0.465 * sx, wing_y - 0.028, wing_z + 0.010)
		b.rbox(Transform3D(Basis(Vector3.FORWARD, 0.30 * sx) * wing_basis, ep_c), Vector3(0.006, 0.048, 0.070), 0.003, 1, CB.M_DARK, C_DARK)

	# Gurney flap along rear trailing edge
	b.rbox(Transform3D(wing_basis, Vector3(0.0, wing_y + 0.012, wing_z + 0.065)), Vector3(0.450, 0.008, 0.004), 0.002, 1, CB.M_DARK, C_DARK)

	# Twin Swan-Neck Vertical Wing Mounting Struts (Raked rearward)
	for sx in [-1.0, 1.0]:
		var strut_x: float = 0.165 * sx
		var strut_path := PackedVector3Array([
			Vector3(strut_x, 0.545, 0.770),
			Vector3(strut_x, 0.700, 0.845),
			Vector3(strut_x, wing_y - 0.008, wing_z - 0.020),
			Vector3(strut_x, wing_y - 0.008, wing_z + 0.030)
		])
		b.tube(_rounded(strut_path, 0.03), 0.012, 8, CB.M_DARK, C_DARK, true, true)

	# Rear Triangular Roll Cage / Chassis Frame Structure behind canopy under wing
	b.tube(_rounded([
		Vector3(-0.190, 0.530, 0.735),
		Vector3(-0.135, 0.655, 0.800),
		Vector3( 0.135, 0.655, 0.800),
		Vector3( 0.190, 0.530, 0.735)
	], 0.03), 0.011, 6, CB.M_DARK, C_DARK, true, true)
	b.tube(PackedVector3Array([Vector3(-0.135, 0.655, 0.800), Vector3(0.0, 0.550, 0.812)]), 0.009, 6, CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([Vector3( 0.135, 0.655, 0.800), Vector3(0.0, 0.550, 0.812)]), 0.009, 6, CB.M_DARK, C_DARK, false, false)

	# -------------------------------------------------------------------------
	# 4. Rear Diffuser
	# -------------------------------------------------------------------------
	var diff_angle := -0.22
	var diff_c := Vector3(0.0, 0.272, 0.900)
	var diff_xf := Transform3D(Basis(Vector3.RIGHT, diff_angle), diff_c)
	b.rbox(diff_xf, Vector3(0.240, 0.007, 0.090), 0.004, 1, CB.M_DARK, C_CARBON)
	for x in [-0.150, -0.050, 0.050, 0.150]:
		b.rbox(diff_xf * Transform3D(Basis(), Vector3(x, -0.020, 0.0)), Vector3(0.003, 0.020, 0.080), 0.002, 1, CB.M_DARK, C_DARK)

	# -------------------------------------------------------------------------
	# 5. Louvre slats over the deck hatch (the glass paint alone reads too flat)
	# -------------------------------------------------------------------------
	for lz in [0.355, 0.408, 0.460, 0.512]:
		b.tube(PackedVector3Array([
			Vector3(-0.140, top_y(-0.140, lz) + 0.003, lz),
			Vector3(0.0, top_y(0.0, lz) + 0.003, lz),
			Vector3(0.140, top_y(0.140, lz) + 0.003, lz)
		]), 0.0042, 8, CB.M_DARK, C_DARK, true, true)


## Detailed cockpit interior with dual bucket seats and sports steering
func _cockpit(b) -> void:
	for sx in [-1.0, 1.0]:
		_seat(b, 0.140 * sx)
	# Digital dash binnacle
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0.0, 0.500, -0.275)), Vector3(0.230, 0.028, 0.014), 0.006, 1, CB.M_DARK, C_DARK)
	# Steering wheel on driver side (-X)
	_steering(b, -0.140)


## Racing bucket seat (kept clear of the low flat canopy: back top ≈0.640, roof ≈0.674)
func _seat(b, x: float) -> void:
	var floor_y := 0.250
	var rake := Basis(Vector3.RIGHT, 0.26)
	var seat_c := Vector3(x, floor_y + 0.038, -0.040)
	b.rbox(Transform3D(Basis(), seat_c), Vector3(0.100, 0.028, 0.115), 0.014, 2, CB.M_DARK, C_DARK)
	var back_c := Vector3(x, floor_y + 0.215, 0.095)
	b.rbox(Transform3D(rake, back_c), Vector3(0.100, 0.160, 0.025), 0.014, 2, CB.M_DARK, C_DARK)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.088 * sx, -0.035, -0.028)), Vector3(0.014, 0.125, 0.035), 0.010, 2, CB.M_DARK, C_CARBON)
	b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, 0.140, -0.008)), Vector3(0.060, 0.034, 0.026), 0.014, 2, CB.M_DARK, C_DARK)


## Sports steering wheel
func _steering(b, x: float) -> void:
	var c := Vector3(x, 0.498, -0.185)
	var tilt := Basis(Vector3.RIGHT, -0.36)
	var ring := PackedVector3Array()
	for k in 21:
		var a: float = TAU * k / 20.0
		var r: float = 0.058
		var py: float = sin(a) * r
		if py < -0.028:
			py = -0.028
		ring.append(c + tilt * Vector3(cos(a) * r, py, 0.0))
	b.tube(ring, 0.007, 6, CB.M_DARK, C_CARBON, true, false)
	b.tube(PackedVector3Array([c + tilt * Vector3(-0.050, 0.0, 0.0), c + tilt * Vector3(0.050, 0.0, 0.0)]), 0.005, 6, CB.M_DARK, C_CARBON, false, false)
	b.rbox(Transform3D(tilt, c), Vector3(0.018, 0.015, 0.007), 0.004, 1, CB.M_ANODISED, Color(1, 1, 1))
	b.tube(PackedVector3Array([c, c + Vector3(0.0, 0.0, -0.08)]), 0.010, 8, CB.M_DARK, C_STEEL, true, false)


## Builds a wheel: rugged stadium truck tire around deep-dish black multi-spoke rim
## with the signature crisp white pinstripe ring on the outer lip bead!
func build_wheel(b, side: float) -> void:
	# -------------------------------------------------------------------------
	# 1. Tire Carcass & Chunky All-Terrain Tread
	# -------------------------------------------------------------------------
	tyre(b, TYRE_HALF, 44, C_RUBBER)
	for row in TREAD_ROWS:
		var odd: bool = row % 2 == 1
		var f: Array = wheel_frame(TAU * (row + (0.5 if odd else 0.0)) / TREAD_ROWS)
		var r_dir: Vector3 = f[0]
		var t_dir: Vector3 = f[1]
		var xs: Array = [-0.070, 0.0, 0.070] if odd else [-0.035, 0.035]
		for x in xs:
			var rc: float = carcass_r(TYRE_HALF, x) - 0.002
			var skew: Vector3 = (Vector3.RIGHT + t_dir * (0.28 if odd else -0.28)).normalized()
			block(b, r_dir * (rc + 0.4 * BLOCK_H) + Vector3(x, 0.0, 0.0), skew, t_dir, r_dir, 0.025, BLOCK_H, 0.022, 0.82, CB.M_RUBBER, C_RUBBER)
		# Aggressive sidewall shoulder lugs
		for sx in [-1.0, 1.0]:
			var up: Vector3 = (r_dir * 0.72 + Vector3(0.68 * sx, 0.0, 0.0)).normalized()
			var lug: float = 0.018 if odd else 0.012
			block(b, r_dir * 0.234 + Vector3(0.106 * sx, 0.0, 0.0), up.cross(t_dir).normalized(), t_dir, up, lug, 0.013, 0.020, 0.78, CB.M_RUBBER, C_RUBBER)

	# -------------------------------------------------------------------------
	# 2. Rim Barrel, Flange & Signature White Lip Ring
	# -------------------------------------------------------------------------
	# Outer rim flange (satin black)
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.092, 0.158), Vector2(0.102, 0.165), Vector2(0.108, 0.163),
		Vector2(0.108, 0.158)
	]), 44, CB.M_DARK, C_DARK, "out", Vector3(0.08, 0.0, 0.0))

	# SIGNATURE CRISP WHITE PINSTRIPE RING (prominent on outer lip bead in photo)
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.108, 0.158), Vector2(0.106, 0.150), Vector2(0.103, 0.144)
	]), 44, CB.M_DARK, C_WHITE_RING, "out", Vector3(0.08, 0.0, 0.0))

	# Stepped flange into concave well (satin black)
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.103, 0.144), Vector2(0.088, 0.142), Vector2(0.076, 0.140)
	]), 44, CB.M_DARK, C_DARK, "+x")

	# Inner rim barrel (deep dark charcoal)
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.076, 0.140), Vector2(0.070, 0.155), Vector2(-0.095, 0.158),
		Vector2(-0.104, 0.164)
	]), 44, CB.M_DARK, C_RIM_BARREL, "in")

	# -------------------------------------------------------------------------
	# 3. Brake Rotor & Caliper
	# -------------------------------------------------------------------------
	# Dark ventilated brake rotor
	b.disc(Vector3(0.025, 0.0, 0.0), Vector3.RIGHT, 0.134, 0.045, 32, CB.M_DARK, C_DARKER)
	# Racing caliper at 2 o'clock
	var cal_angle := PI * 0.35
	var cal_pos := Vector3(0.038, sin(cal_angle) * 0.115, cos(cal_angle) * 0.115)
	var cal_xf := Transform3D(Basis(Vector3.RIGHT, -cal_angle), cal_pos)
	b.rbox(cal_xf, Vector3(0.016, 0.038, 0.022), 0.008, 1, CB.M_DARK, C_STEEL)

	# -------------------------------------------------------------------------
	# 4. Deep Concave Multi-Spoke Wheel Face (5 Twin Thin Black Spokes)
	# -------------------------------------------------------------------------
	# Central recessed hub in satin black
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.048, 0.046), Vector2(0.068, 0.046), Vector2(0.072, 0.038)
	]), 24, CB.M_DARK, C_DARK, "out", Vector3(0.05, 0.0, 0.0))
	# Center hub nut
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.072, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.0, 0.036), Vector2(0.006, 0.030), Vector2(0.010, 0.018), Vector2(0.012, 0.0)
	]), 18, CB.M_DARK, C_STEEL)
	b.orient_away_from(vb, ib, Vector3(0.05, 0.0, 0.0))

	# 5 twin-spokes (10 thin black spokes paired) curving from outer rim into recessed hub
	for k in 5:
		var a: float = TAU * k / 5.0
		for da in [-0.070, 0.070]:
			spoke(b, a + da, 0.0, 0.042, 0.140, 0.066, 0.076, 0.006, 0.008, 0.010, CB.M_DARK, C_DARK)

	if side < 0.0:
		b.mirror_in_place()


# ============================================================================================
#  Detail map: Canopy glass, roof runner channels, hood V-lines, louvred deck hatch,
#  panel shut lines, two-tone lower carbon panels
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Door shut line in side view (z, y)
	shapes["door"] = _inset(PackedVector2Array([
		Vector2(-0.350, 0.300), Vector2(0.160, 0.310),
		Vector2(0.195, 0.545), Vector2(-0.320, 0.525)
	]), 0.025)
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0

	var w: float = prof["w"].at(p.z)
	var sx: float = prof["sx"].at(p.z)
	var sy: float = prof["sy"].at(p.z)
	var rx: float = prof["rx"].at(p.z)
	var ry: float = prof["ry"].at(p.z)

	# -------------------------------------------------------------------------
	# 1. Dark Tinted Canopy Glass (one wrap-around bubble canopy + Louvred Deck Hatch)
	#    -> R channel
	# -------------------------------------------------------------------------
	var on_top := n.y > 0.55
	# One continuous tinted glass bubble: everything above the shoulder line between the cowl and
	# the C-pillar drop is glass, over the roof and straight down the raked sides (no separate
	# windshield / side windows, no pillars, no centre spine)
	var canopy_z: bool = p.z > -0.440 and p.z < 0.205
	if canopy_z and p.y > sy + 0.014 and n.y > -0.2:
		glass = 1.0
	# Rear deck's louvred glass hatch panel behind the canopy
	if p.z > 0.310 and p.z < 0.525 and absf(p.x) < 0.150 and p.y > sy - 0.012 and on_top:
		glass = 1.0

	# Thin black rubber seal framing the canopy: cowl edge, rear edge and the shoulder line
	if glass == 0.0 and p.z > -0.470 and p.z < 0.235 and p.y > sy - 0.004:
		if p.z <= -0.440 or p.z >= 0.205 or p.y <= sy + 0.014:
			black = maxf(black, 0.95)

	# -------------------------------------------------------------------------
	# 2. Satin Black Trim -> A channel
	# -------------------------------------------------------------------------
	# Lower rockers / sills two-tone band (kept off the nose tip: its face is dominated by
	# the grille zone and the tip's degenerate bake vectors would smear the boundary)
	if p.y < 0.298 and n.y < 0.55 and p.z > -1.045:
		black = maxf(black, 0.95)
	# Nose under-lip and front face: the black jaw below the grille bars (feathered boundary: the
	# unpainted green gap above it kept crisp at texel scale)
	if p.z < -1.045 and p.y < 0.216:
		black = maxf(black, _cover(0.216 - p.y, fp))
	# Rear recessed tail fascia
	if p.z > 0.872 and p.y < 0.475 and n.z > 0.4:
		black = maxf(black, 0.98)
	# Rear lower bumper & diffuser zone
	if p.z > 0.830 and p.y < 0.360:
		black = maxf(black, 0.95)
	# Underside
	if n.y < -0.45:
		black = maxf(black, 1.0)

	# Hood 4 RC body clip hole dark grommet circles
	for post_pt in [Vector2(0.185, -0.845), Vector2(0.205, -0.565)]:
		var dist: float = Vector2(p.x, p.z).distance_to(post_pt)
		if dist < 0.019 and p.y > 0.33:
			black = maxf(black, 0.98)

	# -------------------------------------------------------------------------
	# 3. Panel Gaps & Shut Lines -> G channel
	# -------------------------------------------------------------------------
	# Door shut lines on side panels
	if p.x > w - 0.020 and p.z > -0.38 and p.z < 0.20 and p.y < sy:
		gap = maxf(gap, _cover(absf(_sd_rounded(Vector2(p.z, p.y), sh["door"])) - 0.0022, fp))
	# Hood's chevron shut lines flanking the centre power dome, opening toward the nose
	if on_top and p.z > -1.100 and p.z < -0.500:
		var hood_edge := 0.220 + (-p.z - 0.5) * 0.133
		gap = maxf(gap, _cover(absf(p.x - hood_edge) - 0.0035, fp))
	# Cowl cross seam
	if on_top and absf(p.z + 0.452) < 0.007 and p.y > 0.5:
		gap = maxf(gap, _cover(absf(p.z + 0.452) - 0.0025, fp))
	# The deck hatch's four louvre bars
	if glass > 0.99 and p.z > 0.310 and p.z < 0.525:
		for lz in [0.355, 0.408, 0.460, 0.512]:
			if absf(p.z - lz) < 0.010:
				black = maxf(black, 0.9)
				break

	return Color(glass, gap, chrome, black)
