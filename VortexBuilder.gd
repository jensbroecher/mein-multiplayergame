# VortexBuilder.gd
#
# The Vortex: a high-downforce aero truggy / hypercar crossover.
# A razor-sharp, low-slung modern supercar coupe body grafted onto a wide-track stadium
# truck chassis with massive aerodynamic elements:
# - Low wedge front nose with raised center power dome spine
# - 4 circular RC body pin clip holes flush on the hood
# - Massive front aerodynamic splitter with 4 vertical diffuser strakes and outer canards
# - Steeply raked cockpit canopy with dual-channel aerodynamic roof runners
# - Heavy-duty tubular side nerf bars / rock sliders under the sills with step rungs
# - Sculpted side pod air intakes with vertical vents ahead of the rear wheels
# - Flared muscular rear haunches over wide-track tires
# - High-mounted GT gull-wing rear wing with downturned winglets on twin raked struts
# - Triangular rear roll cage / chassis brace structure under the wing
# - Wide-track all-terrain stadium truck tires with aggressive tread blocks
# - Deep-dish black multi-spoke rims with signature crisp white outer lip ring
# - Exposed double wishbone suspension with tall coilover dampers tucked under the hood
extends "res://CarDesign.gd"

# Wheels: wide stadium truck track, long-travel clearance
const WHEEL_X := 0.565
const AXLE_F := -0.740
const AXLE_R := 0.620
const HUB_Y := 0.260

# Tub half-width (w) along the car (z):
# Broad, muscular front hood matching the aggressive supercar proportions in the photo,
# pinched at doors, and flaring out aggressively at the rear haunches over the tires.
const W_KNOTS := [
	[-1.140, 0.320], [-1.000, 0.360], [-0.860, 0.395], [-0.740, 0.420], [-0.580, 0.425],
	[-0.440, 0.425], [-0.200, 0.395], [ 0.050, 0.400], [ 0.320, 0.445], [ 0.620, 0.485],
	[ 0.800, 0.435], [ 0.900, 0.360], [ 0.960, 0.300]
]

# Tub bottom (bot) along the car:
# Front nose sits close to the splitter (Y = 0.21), center belly has high clearance (0.24-0.25),
# and rear tail sweeps up into the diffuser (0.30).
const BOT_KNOTS := [
	[-1.140, 0.210], [-1.000, 0.220], [-0.860, 0.235], [-0.740, 0.245], [-0.580, 0.245],
	[-0.440, 0.245], [-0.100, 0.245], [ 0.200, 0.245], [ 0.440, 0.250], [ 0.620, 0.260],
	[ 0.800, 0.275], [ 0.900, 0.295], [ 0.960, 0.315]
]

# Section keyframes along the car:
# z: position along car
# belt: height of vertical side / rocker top
# sx, sy: shoulder crease position (wide hip / hood edge)
# rx, ry: roof rail / inner hood crease position
# top: center line top height
# crown: dome / dish of top surface (+ dome, - dish)
const KEYS := [
	# z       belt    sx     sy     rx     ry     top    crown
	[-1.140, 0.230, 0.295, 0.240, 0.150, 0.250, 0.260, 0.015], # Low chiseled wedge nose tip
	[-1.000, 0.250, 0.335, 0.275, 0.190, 0.295, 0.315, 0.020],
	[-0.860, 0.285, 0.370, 0.330, 0.225, 0.360, 0.390, 0.024], # Front hood clip area
	[-0.740, 0.315, 0.395, 0.375, 0.255, 0.410, 0.445, 0.024], # Front axle plane
	[-0.580, 0.350, 0.405, 0.425, 0.275, 0.465, 0.500, 0.020], # Rear hood clip area
	[-0.440, 0.385, 0.410, 0.465, 0.285, 0.510, 0.540, 0.014], # Windshield cowl
	[-0.260, 0.420, 0.385, 0.495, 0.255, 0.615, 0.645, 0.010], # Windshield mid
	[-0.100, 0.435, 0.390, 0.510, 0.235, 0.665, 0.685, 0.008], # Roof header
	[ 0.060, 0.445, 0.395, 0.520, 0.230, 0.675, 0.690, 0.008], # Roof peak
	[ 0.220, 0.455, 0.410, 0.530, 0.225, 0.655, 0.670, 0.006], # Fastback slope start
	[ 0.440, 0.470, 0.435, 0.545, 0.220, 0.610, 0.625, 0.004], # Rear window mid / haunch rise
	[ 0.620, 0.480, 0.465, 0.555, 0.210, 0.575, 0.585, 0.004], # Rear axle plane (muscular haunch peak)
	[ 0.800, 0.475, 0.420, 0.555, 0.190, 0.555, 0.560, 0.002], # Rear deck
	[ 0.900, 0.455, 0.350, 0.545, 0.170, 0.540, 0.545, 0.002], # Tail transition
	[ 0.960, 0.425, 0.290, 0.530, 0.145, 0.530, 0.535, 0.000], # Tail trailing edge
]
const KEY_NAMES := ["belt", "sx", "sy", "rx", "ry", "top", "crown"]

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
const ANTENNA_POS := Vector3(0.18, 0.690, 0.16)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.140
	nose_cap = 0.025
	nose_cap_y = 0.235
	nose_cap_exp = Vector2(5.5, 3.2)
	tail_tip = 0.960
	tail_cap = 0.025
	tail_cap_y = 0.460
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
	# Coilover shock tucked inside wheel well under the hood (mount at Y = 0.340)
	coilover(b, Vector3(0.360, 0.220, k_front), Vector3(0.260, 0.340, k_front), 0.017, 0.028, 6.5, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)

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
	# Rear coilover shock under the haunch (mount at Y = 0.420)
	coilover(b, Vector3(0.370, 0.235, k_rear + 0.02), Vector3(0.280, 0.420, k_rear - 0.02), 0.018, 0.030, 7.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)

	# -------------------------------------------------------------------------
	# 3. Tubular Side Nerf Bars / Rock Sliders (Signature Feature from Photo)
	# -------------------------------------------------------------------------
	# Outboard tubular rock slider with rectangular drop steps
	var nerf_y := 0.180
	var nerf_outer_x := 0.485
	var nerf_inner_x := 0.370
	var nerf_path := PackedVector3Array([
		Vector3(nerf_inner_x, nerf_y, -0.220),
		Vector3(nerf_outer_x, nerf_y, -0.170),
		Vector3(nerf_outer_x, nerf_y,  0.220),
		Vector3(nerf_inner_x, nerf_y,  0.270)
	])
	b.tube(_rounded(nerf_path, 0.04), 0.015, 8, CB.M_DARK, C_DARK, true, true)
	# Two rectangular step rungs connecting outer rail to chassis tub
	for r_z in [-0.050, 0.140]:
		b.tube(PackedVector3Array([Vector3(nerf_inner_x - 0.04, nerf_y, r_z), Vector3(nerf_outer_x - 0.005, nerf_y, r_z)]), 0.013, 6, CB.M_DARK, C_DARK, false, false)

	# -------------------------------------------------------------------------
	# 4. Sculpted Side Pod Air Intake & Vertical Extractor Vent
	# -------------------------------------------------------------------------
	# Flank intake recess ahead of rear wheel (Z = 0.15 to 0.45)
	var pod_c := Vector3(0.425, 0.400, 0.300)
	b.rbox(Transform3D(Basis(Vector3.UP, -0.10), pod_c), Vector3(0.018, 0.048, 0.080), 0.006, 1, CB.M_DARK, C_DARKER)
	# Vertical black air extractor vent slit (clearly visible on rear quarter in photo)
	b.rbox(Transform3D(Basis(), Vector3(0.460, 0.430, 0.460)), Vector3(0.008, 0.045, 0.012), 0.002, 1, CB.M_DARK, C_DARKER)

	# -------------------------------------------------------------------------
	# 5. Flush RC Body Pin Holes (4 Recessed Round Dark Holes on Hood)
	# -------------------------------------------------------------------------
	var post_f := Vector3(0.185, 0.370, -0.840)
	b.disc(post_f + Vector3(0, 0.001, 0), Vector3.UP, 0.018, 0.000, 16, CB.M_DARK, C_DARKER)
	var post_r := Vector3(0.215, 0.470, -0.560)
	b.disc(post_r + Vector3(0, 0.001, 0), Vector3.UP, 0.018, 0.000, 16, CB.M_DARK, C_DARKER)

	# -------------------------------------------------------------------------
	# 6. Sleek Wing Mirrors
	# -------------------------------------------------------------------------
	var mir_c := Vector3(0.360, 0.520, -0.200)
	b.tube(PackedVector3Array([Vector3(0.320, 0.495, -0.200), mir_c]), 0.007, 6, CB.M_DARK, C_CARBON, true, false)
	var mir_xf := Transform3D(Basis(Vector3.UP, -0.16) * Basis(Vector3.RIGHT, 0.05), mir_c + Vector3(0.030, 0.008, 0.0))
	b.rbox(mir_xf, Vector3(0.028, 0.014, 0.018), 0.005, 1, CB.M_PAINT, Color(1, 1, 1))
	b.rbox(mir_xf * Transform3D(Basis(), Vector3(0.0, 0.0, 0.014)), Vector3(0.022, 0.010, 0.003), 0.002, 1, CB.M_CHROME, C_CHROME)

	# -------------------------------------------------------------------------
	# 7. Rear Corner Taillight Blade & Exhaust
	# -------------------------------------------------------------------------
	b.rbox(Transform3D(Basis(), Vector3(0.240, 0.490, 0.950)), Vector3(0.035, 0.012, 0.006), 0.003, 1, CB.M_TAILLAMP, C_TAILLAMP)
	var ex_c := Vector3(0.105, 0.340, 0.955)
	b.tube(PackedVector3Array([ex_c + Vector3(0, 0, -0.06), ex_c + Vector3(0, 0, 0.025)]), 0.018, 12, CB.M_ALLOY, C_ALLOY, false, false)
	b.tube(PackedVector3Array([ex_c + Vector3(0, 0, -0.05), ex_c + Vector3(0, 0, 0.026)]), 0.015, 10, CB.M_DARK, C_DARKER, false, false)


## Centerline components: Front splitter with strakes and canards, rear wing, diffuser, roof runners
func _centre_parts(b) -> void:
	# -------------------------------------------------------------------------
	# 1. Massive Front Aerodynamic Splitter Assembly (Signature Feature from Photo)
	# -------------------------------------------------------------------------
	var split_y := 0.135
	# Main horizontal splitter plate extending forward under the nose (Z from -1.00 to -1.26, X from -0.42 to +0.42)
	b.rbox(Transform3D(Basis(), Vector3(0.0, split_y, -1.130)), Vector3(0.390, 0.008, 0.130), 0.005, 1, CB.M_DARK, C_DARK)
	# Forward extension blade
	b.rbox(Transform3D(Basis(), Vector3(0.0, split_y, -1.240)), Vector3(0.330, 0.007, 0.025), 0.004, 1, CB.M_DARK, C_DARK)

	# 4 Vertical Diffuser Strakes connecting splitter plate up to nose chin
	for x in [-0.220, -0.075, 0.075, 0.220]:
		var strake_h := 0.085
		var strake_c := Vector3(x, split_y + strake_h * 0.5, -1.130)
		b.rbox(Transform3D(Basis(), strake_c), Vector3(0.005, strake_h * 0.5, 0.095), 0.002, 1, CB.M_DARK, C_DARK)

	# Large Outer Canards / Dive Planes at the splitter tips (X = ±0.415)
	for sx in [-1.0, 1.0]:
		var canard_c := Vector3(0.415 * sx, split_y + 0.065, -1.130)
		b.rbox(Transform3D(Basis(Vector3.UP, -0.20 * sx) * Basis(Vector3.FORWARD, 0.18 * sx), canard_c), Vector3(0.006, 0.065, 0.105), 0.003, 1, CB.M_DARK, C_DARK)
		b.rbox(Transform3D(Basis(), Vector3(0.380 * sx, split_y, -1.130)), Vector3(0.040, 0.007, 0.090), 0.003, 1, CB.M_DARK, C_DARK)

	# Lower central intake cavity under nose
	var mesh_c := Vector3(0.0, 0.210, -1.100)
	b.rbox(Transform3D(Basis(), mesh_c), Vector3(0.180, 0.018, 0.015), 0.005, 1, CB.M_DARK, C_DARKER)

	# -------------------------------------------------------------------------
	# 2. Dual Aerodynamic Roof Runners / Air Channels (Along Canopy)
	# -------------------------------------------------------------------------
	for sx in [-1.0, 1.0]:
		var runner_x: float = 0.075 * sx
		b.rbox(Transform3D(Basis(), Vector3(runner_x, 0.692, 0.040)), Vector3(0.014, 0.006, 0.160), 0.003, 1, CB.M_PAINT, Color(1, 1, 1))

	# -------------------------------------------------------------------------
	# 3. High-Mounted GT Gull-Wing Rear Wing & Struts (Signature Feature from Photo)
	# -------------------------------------------------------------------------
	var wing_y := 0.810
	var wing_z := 0.930
	var wing_basis := Basis(Vector3.RIGHT, 0.14)

	# Center section of wing blade (span X = -0.22 to +0.22)
	b.rbox(Transform3D(wing_basis, Vector3(0.0, wing_y, wing_z)), Vector3(0.220, 0.009, 0.075), 0.005, 1, CB.M_DARK, C_DARK)

	# Outer wing panels kicking slightly upward (gull-wing dihedral) and downturned tips
	for sx in [-1.0, 1.0]:
		var out_c := Vector3(0.335 * sx, wing_y + 0.012, wing_z)
		b.rbox(Transform3D(Basis(Vector3.FORWARD, 0.08 * sx) * wing_basis, out_c), Vector3(0.125, 0.008, 0.075), 0.004, 1, CB.M_DARK, C_DARK)
		# Downturned Winglet Endplates at X = ±0.465 (curve down and back as in photo)
		var ep_c := Vector3(0.465 * sx, wing_y - 0.028, wing_z + 0.010)
		b.rbox(Transform3D(Basis(Vector3.FORWARD, 0.35 * sx) * wing_basis, ep_c), Vector3(0.006, 0.048, 0.090), 0.003, 1, CB.M_DARK, C_DARK)

	# Gurney flap along rear trailing edge
	b.rbox(Transform3D(wing_basis, Vector3(0.0, wing_y + 0.012, wing_z + 0.065)), Vector3(0.450, 0.008, 0.004), 0.002, 1, CB.M_DARK, C_DARK)

	# Twin Swan-Neck Vertical Wing Mounting Struts (Raked rearward)
	for sx in [-1.0, 1.0]:
		var strut_x: float = 0.165 * sx
		var strut_path := PackedVector3Array([
			Vector3(strut_x, 0.540, 0.770),
			Vector3(strut_x, 0.680, 0.840),
			Vector3(strut_x, wing_y - 0.008, wing_z - 0.020),
			Vector3(strut_x, wing_y - 0.008, wing_z + 0.030)
		])
		b.tube(_rounded(strut_path, 0.03), 0.012, 8, CB.M_DARK, C_DARK, true, true)

	# Rear Triangular Roll Cage / Chassis Frame Structure behind canopy under wing
	b.tube(_rounded([
		Vector3(-0.190, 0.520, 0.730),
		Vector3(-0.135, 0.650, 0.800),
		Vector3( 0.135, 0.650, 0.800),
		Vector3( 0.190, 0.520, 0.730)
	], 0.03), 0.011, 6, CB.M_DARK, C_DARK, true, true)
	b.tube(PackedVector3Array([Vector3(-0.135, 0.650, 0.800), Vector3(0.0, 0.540, 0.810)]), 0.009, 6, CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([Vector3( 0.135, 0.650, 0.800), Vector3(0.0, 0.540, 0.810)]), 0.009, 6, CB.M_DARK, C_DARK, false, false)

	# -------------------------------------------------------------------------
	# 4. Rear Diffuser
	# -------------------------------------------------------------------------
	var diff_angle := -0.22
	var diff_c := Vector3(0.0, 0.270, 0.900)
	var diff_xf := Transform3D(Basis(Vector3.RIGHT, diff_angle), diff_c)
	b.rbox(diff_xf, Vector3(0.240, 0.007, 0.090), 0.004, 1, CB.M_DARK, C_CARBON)
	for x in [-0.150, -0.050, 0.050, 0.150]:
		b.rbox(diff_xf * Transform3D(Basis(), Vector3(x, -0.020, 0.0)), Vector3(0.003, 0.020, 0.080), 0.002, 1, CB.M_DARK, C_DARK)


## Detailed cockpit interior with dual bucket seats and sports steering
func _cockpit(b) -> void:
	for sx in [-1.0, 1.0]:
		_seat(b, 0.140 * sx)
	# Digital dash binnacle
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0.0, 0.490, -0.260)), Vector3(0.230, 0.028, 0.014), 0.006, 1, CB.M_DARK, C_DARK)
	# Steering wheel on driver side (-X)
	_steering(b, -0.140)


## Racing bucket seat
func _seat(b, x: float) -> void:
	var floor_y := 0.250
	var rake := Basis(Vector3.RIGHT, 0.26)
	var seat_c := Vector3(x, floor_y + 0.038, -0.040)
	b.rbox(Transform3D(Basis(), seat_c), Vector3(0.100, 0.028, 0.115), 0.014, 2, CB.M_DARK, C_DARK)
	var back_c := Vector3(x, floor_y + 0.235, 0.095)
	b.rbox(Transform3D(rake, back_c), Vector3(0.100, 0.180, 0.025), 0.014, 2, CB.M_DARK, C_DARK)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.088 * sx, -0.035, -0.028)), Vector3(0.014, 0.140, 0.035), 0.010, 2, CB.M_DARK, C_CARBON)
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.038 * sx, 0.010, -0.026)), Vector3(0.010, 0.150, 0.003), 0.002, 1, CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, 0.190, -0.008)), Vector3(0.060, 0.040, 0.026), 0.014, 2, CB.M_DARK, C_DARK)


## Sports steering wheel
func _steering(b, x: float) -> void:
	var c := Vector3(x, 0.485, -0.170)
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
#  Detail map: Windshield, canopy glass, panel shut lines, two-tone lower carbon panels
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Door shut line in side view (z, y)
	shapes["door"] = _inset(PackedVector2Array([
		Vector2(-0.350, 0.270), Vector2(0.150, 0.270),
		Vector2(0.180, 0.490), Vector2(-0.320, 0.470)
	]), 0.025)
	# Side intake duct opening polygon
	shapes["side_intake"] = PackedVector2Array([
		Vector2(0.120, 0.340), Vector2(0.340, 0.340),
		Vector2(0.340, 0.450), Vector2(0.160, 0.440)
	])
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
	# 1. Dark Tinted Canopy Glass (Windshield, Side Windows, Rear Hatch) -> R channel
	# -------------------------------------------------------------------------
	# Windshield: from cowl (z = -0.43) up to roof header (z = -0.11), inside A-pillars
	if p.z > -0.425 and p.z < -0.115:
		if p.x < rx - 0.018 and p.y > sy + 0.012:
			glass = 1.0
	# Side windows: between shoulder and roof rail
	if p.z >= -0.250 and p.z <= 0.160:
		if p.y > sy + 0.014 and p.y < ry - 0.010 and p.x > rx + 0.010:
			glass = 1.0
	# Rear fastback glass / engine viewing window
	if p.z > 0.240 and p.z < 0.480:
		if p.x < rx - 0.022 and p.y > 0.560 and n.y > 0.35:
			glass = 1.0

	# Black rubber window seals bordering glass
	if glass == 0.0:
		# Windshield rubber seal
		if p.z > -0.440 and p.z < -0.100 and p.x < rx and p.y > sy:
			if (p.x >= rx - 0.022 or p.z <= -0.415 or p.z >= -0.125):
				black = maxf(black, 0.95)
		# Side window rubber seal
		if p.z >= -0.270 and p.z <= 0.180 and p.x > rx and p.y > sy - 0.005 and p.y < ry + 0.015:
			if (p.y <= sy + 0.018 or p.y >= ry - 0.008 or p.z <= -0.240 or p.z >= 0.150):
				black = maxf(black, 0.95)

	# -------------------------------------------------------------------------
	# 2. Satin Black Lower Rockers, Diffuser & Body Post Circles -> A channel
	# -------------------------------------------------------------------------
	# Lower rockers
	if p.y < 0.280 and n.y < 0.6:
		black = maxf(black, 0.95)
	# Front chin spoiler area
	if p.z < -1.020 and p.y < 0.260:
		black = maxf(black, 0.95)
	# Rear recessed tail fascia
	if p.z > 0.860 and p.y < 0.520 and n.z > 0.4:
		black = maxf(black, 0.98)
	# Rear diffuser & lower bumper
	if p.z > 0.820 and p.y < 0.360:
		black = maxf(black, 0.95)
	# Underside
	if n.y < -0.45:
		black = maxf(black, 1.0)

	# Hood 4 RC body clip hole dark grommet circles
	for post_pt in [Vector2(0.185, -0.840), Vector2(0.215, -0.560)]:
		var dist: float = Vector2(p.x, p.z).distance_to(post_pt)
		if dist < 0.018 and p.y > 0.33:
			black = maxf(black, 0.98)

	# -------------------------------------------------------------------------
	# 3. Panel Gaps & Shut Lines -> G channel
	# -------------------------------------------------------------------------
	# Door shut lines on side panels
	if p.x > w - 0.020 and p.z > -0.38 and p.z < 0.20 and p.y < sy:
		gap = maxf(gap, _cover(absf(_sd_rounded(Vector2(p.z, p.y), sh["door"])) - 0.0022, fp))
	# Front hood shut lines
	if n.y > 0.5 and p.z > -1.00 and p.z < -0.44:
		var hood_edge := 0.270 + (p.z + 0.74) * 0.05
		gap = maxf(gap, _cover(absf(absf(p.x) - hood_edge) - 0.0020, fp))
		if absf(p.z - (-0.440)) < 0.012:
			gap = maxf(gap, _cover(absf(p.z - (-0.440)) - 0.0020, fp))

	return Color(glass, gap, chrome, black)
