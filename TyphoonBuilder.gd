# TyphoonBuilder.gd
#
# The Typhoon: a fan buggy, a dune skimmer pushed along (to look at) by a big ducted propeller. An original design with
# a made-up name, picked to stand apart from the other buggies (the Shadow, the Centurion, the Vortex: caged and
# winged; the Sandpiper: a rounded beach buggy): a slim single-seat kayak of a tub, skinny front wheels on long
# wishbones splayed out ahead of it, fat smooth sand tyres on trailing arms behind, a roll hoop over the driver, and
# behind the hoop a twin-cylinder aero engine driving a three-bladed propeller inside a round duct (in the paint), two
# rudders in the paint behind it. The duct stands on struts from the hoop and the frame's rails; the propeller is its
# own mesh (build_prop(), regenerate_cars.gd's "Prop" node, CarSpinner.gd), spinning faster the faster the car goes.
#
# The tub's section is the Centurion's (KEYS, keyed_knots(), _upper_segments()): a crowned deck over the nose, a trough
# over the cockpit (the wall runs down to the floor), a short deck behind the seat. No wheel arches: every wheel stands
# well outboard of the tub.
extends "res://CarDesign.gd"

const AXLE_F := -0.820
const AXLE_R := 0.400
const WHEEL_X_F := 0.600
const WHEEL_X_R := 0.580
const TYRE_R_F := 0.200
const TYRE_R_R := 0.255

const W_KNOTS := [[-1.100, 0.050], [-1.050, 0.100], [-0.960, 0.150], [-0.820, 0.192], [-0.620, 0.222], [-0.380, 0.240],
	[-0.050, 0.244], [0.120, 0.236], [0.220, 0.220]]
const BOT_KNOTS := [[-1.100, 0.300], [-1.050, 0.255], [-0.960, 0.215], [-0.820, 0.195], [0.100, 0.195], [0.220, 0.212]]

# The section above the side (see CenturionBuilder): z; belt; rim_w; wall_dx; edge; cx, cy; crown.
const KEYS := [
	# z       belt   rim_w  wall_dx edge   cx     cy      crown
	[-1.100, 0.322, 0.010, 0.008, 0.330, 0.008, 0.000, 0.004],
	[-1.000, 0.352, 0.016, 0.012, 0.364, 0.012, 0.000, 0.010],
	[-0.850, 0.388, 0.022, 0.018, 0.403, 0.018, 0.000, 0.016],
	[-0.650, 0.424, 0.026, 0.022, 0.442, 0.022, 0.000, 0.020],
	[-0.500, 0.440, 0.028, 0.024, 0.458, 0.024, 0.000, 0.020],
	[-0.478, 0.436, 0.034, 0.000, 0.228, 0.014, -0.014, 0.000],
	[0.110, 0.416, 0.034, 0.000, 0.228, 0.014, -0.014, 0.000],
	[0.135, 0.452, 0.030, 0.024, 0.466, 0.024, 0.000, 0.012],
	[0.220, 0.452, 0.030, 0.024, 0.466, 0.024, 0.000, 0.012],
]
const KEY_NAMES := ["belt", "rim_w", "wall_dx", "edge", "cx", "cy", "crown"]
const RIM_R := 0.012

# The duct round the propeller: its centre, radius and depth (along z); the propeller's radius.
const DUCT_C := Vector3(0.0, 0.600, 0.800)
const DUCT_R := 0.455
const DUCT_D := 0.170
const PROP_R := 0.425
const PROP_POS := Vector3(0.0, 0.600, 0.790)
# The roll hoop over the seat.
const HOOP_Z := 0.160
const HOOP_TOP := 0.840
const HOOP_X := 0.205
## Where the hoop's forward brace is bolted down on the cowl.
const BRACE_FOOT := Vector3(0.195, 0.449, -0.575)

# Tyres: half their profile, bead to tread centre: skinny ribbed fronts, smooth balloon sand tyres behind.
const TYRE_F := [[-0.040, 0.130], [-0.044, 0.142], [-0.046, 0.160], [-0.045, 0.178], [-0.040, 0.192], [-0.028, 0.198],
	[-0.012, 0.2], [0.0, 0.2]]
const TYRE_R := [[-0.112, 0.150], [-0.122, 0.165], [-0.128, 0.190], [-0.127, 0.214], [-0.120, 0.234], [-0.104, 0.248],
	[-0.070, 0.2545], [-0.030, 0.255], [0.0, 0.255]]

## The mirrors' turn in about y: -0.45 puts the glass's normal halfway between straight back and the driver's head.
const MIRROR_YAW := -0.45
## And tipped up (the glass's normal 13 degrees over level): the eye, the driver's or the chase camera's, looks down on
## it, and a level glass reflected the sky's dark ground, so it read as a black panel; tipped, it shows the sky.
const MIRROR_TILT := -0.22

const C_RUBBER := Color(0.17, 0.17, 0.18)
const C_DARK := Color(0.07, 0.07, 0.075)
const C_DARKER := Color(0.035, 0.035, 0.04)
const C_STEEL := Color(0.16, 0.165, 0.175)
const C_ALLOY := Color(0.78, 0.79, 0.81)
const C_ALLOY_DARK := Color(0.44, 0.45, 0.47)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_TAILLAMP := Color(0.86, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)
const C_SEAT := Color(0.10, 0.10, 0.11)
const C_CARBON := Color(0.09, 0.09, 0.10)
const C_FILTER := Color(0.75, 0.10, 0.06)

const PAINT_LAYOUT := {
	"nose_z": -1.10, "tail_z": 0.22, "belt_y": 0.42, "side_x": 0.24,
	"door_z": -0.20, "door_y": 0.33, "roundel_r": 0.075,
	"hood_z": -0.80, "hood_r": 0.06, "stripe_w": 0.045, "stripe_gap": 0.018,
}
const ANTENNA_POS := Vector3(0.20, HOOP_TOP + 0.01, HOOP_Z)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X_F, TYRE_R_F, AXLE_F), "FR": Vector3(WHEEL_X_F, TYRE_R_F, AXLE_F),
	"RL": Vector3(-WHEEL_X_R, TYRE_R_R, AXLE_R), "RR": Vector3(WHEEL_X_R, TYRE_R_R, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.100
	nose_cap = 0.030
	nose_cap_y = 0.315
	nose_cap_exp = Vector2(2.5, 2.0)
	tail_tip = 0.220
	tail_cap = 0.020
	tail_cap_y = 0.360
	tail_cap_exp = Vector2(6.0, 6.0)
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


## Above the side, as the Centurion's: the rim, the wall (down into the cockpit or flat on a deck), the corner onto
## the top, the top crowned toward the centre line.
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


func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)
	_seat(b)
	_steering(b)
	_engine(b)
	_duct(b)


## Right-hand parts, mirrored to the left.
func _side_parts(b) -> void:
	var frame_r := 0.015
	# The frame's lower rail along the tub's flank and on back under the engine to the duct.
	b.tube(_rounded([Vector3(0.12, 0.25, -1.00), Vector3(0.21, 0.24, -0.80), Vector3(0.255, 0.24, -0.40),
			Vector3(0.255, 0.25, 0.20), Vector3(0.22, 0.28, 0.62), Vector3(0.20, 0.30, 0.80)], 0.08), frame_r, 10,
			CB.M_DARK, C_STEEL, true, true)
	# The roll hoop's leg, down to the rail.
	b.tube(_rounded([Vector3(0.235, 0.26, HOOP_Z), Vector3(0.225, 0.62, HOOP_Z), Vector3(HOOP_X, HOOP_TOP, HOOP_Z)], 0.06),
			0.018, 12, CB.M_ANODISED, Color(1, 1, 1), true, false)
	# A brace from the hoop forward to the dash, one back down to the rail.
	# It lands on the cowl just ahead of the cockpit's opening (the deck there is about 0.447 up, 0.17-0.22 out), bolted
	# down through a foot plate: it had ended at the sill's height 2cm outboard of it, in the air.
	b.tube(_rounded([Vector3(0.22, 0.60, HOOP_Z), BRACE_FOOT + Vector3(0.002, 0.034, 0.024), BRACE_FOOT + Vector3(0, 0.002, -0.004)],
			0.025), 0.012, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)
	# A gusset welded under the bend onto the plate.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.5), BRACE_FOOT + Vector3(0.001, 0.014, 0.022)), Vector3(0.0025, 0.012, 0.014),
			0.002, 1, CB.M_ANODISED, Color(1, 1, 1))
	var foot_xf := Transform3D(Basis(Vector3.RIGHT, -0.06), BRACE_FOOT)
	b.rbox(foot_xf, Vector3(0.020, 0.004, 0.030), 0.003, 1, CB.M_DARK, C_STEEL)
	for bz in [-0.019, 0.019]:
		b.lathe(foot_xf * Vector3(0.0, 0.004, bz), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.0045), Vector2(0.003, 0.004),
				Vector2(0.004, 0.0)]), 8, CB.M_CHROME, C_CHROME)
	b.tube(PackedVector3Array([Vector3(0.21, 0.78, HOOP_Z + 0.01), Vector3(0.23, 0.30, 0.56)]), 0.012, 8, CB.M_DARK, C_STEEL,
			false, false)
	# The duct's struts: from the hoop's top back to its upper side, from the rail's end to its lower side.
	b.tube(PackedVector3Array([Vector3(HOOP_X - 0.01, HOOP_TOP - 0.01, HOOP_Z + 0.02), _duct_point(0.95, DUCT_C.z - DUCT_D * 0.5)]),
			0.013, 8, CB.M_DARK, C_STEEL, false, false)
	b.tube(PackedVector3Array([Vector3(0.21, 0.29, 0.66), _duct_point(-0.75, DUCT_C.z - DUCT_D * 0.4)]), 0.013, 8,
			CB.M_DARK, C_STEEL, false, false)
	b.tube(PackedVector3Array([Vector3(0.20, 0.30, 0.80), _duct_point(-1.35, DUCT_C.z)]), 0.013, 8, CB.M_DARK, C_STEEL,
			false, false)
	_front_suspension(b)
	_rear_suspension(b)
	# The headlamps: a round lamp standing on each side of the nose's bumper hoop (they had been tucked inside the nose,
	# out of sight); an amber marker on the flank.
	_spotlight(b, Vector3(0.056, 0.322, -1.158), 0.032, Vector3(0.056, 0.276, -1.15))
	b.rbox(Transform3D(Basis(Vector3.UP, -0.4), Vector3(0.150, 0.36, -0.95)), Vector3(0.004, 0.010, 0.026), 0.003, 1,
			CB.M_TAILLAMP, C_AMBER)
	# Two spotlights on the hoop's top bar, each on a bracket: a deep can behind a chrome bezel and a clear lens.
	_spotlight(b, Vector3(0.13, HOOP_TOP + 0.075, HOOP_Z - 0.012), 0.042, Vector3(0.13, HOOP_TOP + 0.010, HOOP_Z))
	# A taillamp on each side of the duct's foot.
	b.rbox(Transform3D(Basis(Vector3.BACK, -1.15 + PI * 0.5), _duct_point(-1.15, DUCT_C.z + DUCT_D * 0.5 + 0.008)),
			Vector3(0.050, 0.018, 0.008), 0.006, 1, CB.M_TAILLAMP, C_TAILLAMP)
	# Mirror on a stalk off the hoop's brace.
	b.tube(PackedVector3Array([Vector3(0.208, 0.528, -0.20), Vector3(0.30, 0.58, -0.24)]), 0.006, 6, CB.M_DARK, C_DARK, false,
			false)
	# The housing is turned in (MIRROR_YAW) halfway between straight back and the driver's head, so its glass, on the
	# back (+z) face, shows the driver what's behind; chrome, it reflects the sky and the country round it.
	var mir_xf := Transform3D(Basis(Vector3.UP, MIRROR_YAW) * Basis(Vector3.RIGHT, MIRROR_TILT), Vector3(0.315, 0.59, -0.245))
	b.rbox(mir_xf, Vector3(0.032, 0.021, 0.008), 0.006, 1, CB.M_PAINT, Color(1, 1, 1))
	b.rbox(mir_xf * Transform3D(Basis(), Vector3(0.0, 0.0, 0.0085)), Vector3(0.027, 0.016, 0.0015), 0.0015, 1,
			CB.M_CHROME, C_CHROME)


## A shock's mounting eye at `c`: a short ring round a bolt along `axis`, the bolt's ends showing either side.
func _shock_eye(b, c: Vector3, axis: Vector3, r: float) -> void:
	b.tube(PackedVector3Array([c - axis * 0.014, c + axis * 0.014]), r, 10, CB.M_ALLOY, C_ALLOY_DARK, true, true)
	b.tube(PackedVector3Array([c - axis * 0.026, c + axis * 0.026]), 0.0045, 8, CB.M_CHROME, C_CHROME, true, true)


## A round spotlight facing forward, centre `c`, lens radius `r`: a deep dark can behind a chrome bezel and a clear lens,
## on a stem down to `foot` (the bar it stands on) with a bracket under the can.
func _spotlight(b, c: Vector3, r: float, foot: Vector3) -> void:
	b.tube(PackedVector3Array([foot, c + Vector3(0.0, -r * 0.9, r * 0.6)]), r * 0.2, 8, CB.M_DARK, C_DARK, false, false)
	b.rbox(Transform3D(Basis(), c + Vector3(0.0, -r * 1.02, r * 0.6)), Vector3(r * 0.25, r * 0.18, r * 0.4), 0.003, 1, CB.M_DARK,
			C_DARK)
	var vs: int = b.vertex_count()
	var is_: int = b.index_count()
	b.lathe(c, Vector3.BACK, PackedVector2Array([Vector2(r * 0.24, r * 1.10), Vector2(r * 0.76, r * 0.98),
			Vector2(r * 1.19, r * 0.62), Vector2(r * 1.33, 0.0)]), 18, CB.M_DARK, C_DARK)
	b.orient_away_from(vs, is_, c + Vector3(0, 0, r * 0.7))
	round_lamp(b, c, Vector3.FORWARD, r, CB.M_HEADLAMP, Color(1, 1, 1))


## A point on the duct's rim at angle `a` (0 to the right, PI/2 at the top), at z.
func _duct_point(a: float, z: float) -> Vector3:
	return Vector3(DUCT_C.x + cos(a) * DUCT_R, DUCT_C.y + sin(a) * DUCT_R, z)


## The front corner (right): long wishbones splayed forward out to the hub, a coil-over leaning in to the nose, the
## steering arm.
func _front_suspension(b) -> void:
	var az := AXLE_F
	var kx := WHEEL_X_F - 0.07
	for dz in [-0.10, 0.10]:
		b.tube(PackedVector3Array([Vector3(0.17, 0.215, az + dz + 0.04), Vector3(kx - 0.012, TYRE_R_F - 0.05, az)]), 0.011, 8,
				CB.M_ALLOY, C_ALLOY, true, true)
	for dz in [-0.07, 0.07]:
		b.tube(PackedVector3Array([Vector3(0.18, 0.34, az + dz + 0.04), Vector3(kx - 0.014, TYRE_R_F + 0.06, az)]), 0.009, 8,
				CB.M_ALLOY, C_ALLOY, true, true)
	b.rbox(Transform3D(Basis(), Vector3(kx, TYRE_R_F, az)), Vector3(0.014, 0.075, 0.024), 0.007, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(kx, TYRE_R_F, az), Vector3(WHEEL_X_F - 0.035, TYRE_R_F, az)]), 0.013, 8, CB.M_ALLOY,
			C_ALLOY_DARK, false, true)
	b.tube(PackedVector3Array([Vector3(0.14, 0.27, az + 0.07), Vector3(kx - 0.01, TYRE_R_F + 0.005, az + 0.05)]), 0.006, 6,
			CB.M_DARK, C_DARK, true, true)
	# The coil-over stands on a bar across the lower wishbone's legs (it had ended between them), an eye on a bolt, and
	# its top is bolted between two tabs on a shock tower: a plate down the cowl's flank from the deck to the frame rail
	# (a block on the deck's edge read as not fixed to anything).
	var shock_lo := Vector3(kx - 0.08, 0.169, az + 0.01)
	b.tube(PackedVector3Array([Vector3(shock_lo.x, 0.163, az - 0.036), Vector3(shock_lo.x, 0.163, az + 0.034)]), 0.008, 8,
			CB.M_ALLOY, C_ALLOY, true, true)
	var tz := az + 0.13
	var shock_hi := Vector3(0.250, 0.412, tz)
	coilover(b, shock_lo, shock_hi, 0.014, 0.024, 7.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK, false)
	_shock_eye(b, shock_lo, Vector3.BACK, 0.010)
	_shock_eye(b, shock_hi, Vector3.BACK, 0.013)
	b.rbox(Transform3D(Basis(), Vector3(0.219, 0.338, tz)), Vector3(0.004, 0.100, 0.032), 0.003, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.224, 0.436, tz)), Vector3(0.012, 0.004, 0.032), 0.003, 1, CB.M_DARK, C_STEEL)
	for side in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(), Vector3(0.240, 0.412, tz + side * 0.019)), Vector3(0.022, 0.016, 0.003), 0.003, 1,
				CB.M_DARK, C_STEEL)
	for by in [0.29, 0.38]:
		b.disc(Vector3(0.2235, by, tz), Vector3.RIGHT, 0.004, 0.0, 8, CB.M_CHROME, C_CHROME)


## The rear corner (right): a trailing arm from the frame back to the hub, a long coil-over up to the hoop's brace,
## the halfshaft out from the transaxle.
func _rear_suspension(b) -> void:
	var az := AXLE_R
	var kx := WHEEL_X_R - 0.13
	b.tube(PackedVector3Array([Vector3(0.25, 0.25, 0.02), Vector3(kx, TYRE_R_R - 0.03, az - 0.02)]), 0.020, 10, CB.M_DARK,
			C_STEEL, true, true)
	b.tube(PackedVector3Array([Vector3(0.24, 0.31, 0.06), Vector3(kx, TYRE_R_R + 0.04, az - 0.01)]), 0.012, 8, CB.M_ALLOY,
			C_ALLOY, true, true)
	# The upper link's clevis on the tub's flank.
	b.rbox(Transform3D(Basis(), Vector3(0.244, 0.31, 0.06)), Vector3(0.007, 0.020, 0.018), 0.003, 1, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(kx, TYRE_R_R, az)), Vector3(0.018, 0.07, 0.04), 0.009, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(0.07, TYRE_R_R + 0.01, az), Vector3(WHEEL_X_R - 0.10, TYRE_R_R, az)]), 0.014, 10,
			CB.M_ALLOY, C_ALLOY_DARK, false, true)
	# Its top is bolted between two tabs welded to the hoop's rear brace, 30% of the way down it (it had hung between the
	# brace and the hoop's leg under a loose block); its foot is an eye on the upper link.
	var brace_a := Vector3(0.21, 0.78, HOOP_Z + 0.01)
	var brace_p := brace_a.lerp(Vector3(0.23, 0.30, 0.56), 0.30)
	var rear_hi := brace_p + Vector3(0.036, -0.004, 0.0)
	var rear_lo := Vector3(kx - 0.02, TYRE_R_R + 0.03, az - 0.04)
	var link_dir := (Vector3(kx, TYRE_R_R + 0.04, az - 0.01) - Vector3(0.24, 0.31, 0.06)).normalized()
	_shock_eye(b, rear_hi, Vector3.BACK, 0.015)
	_shock_eye(b, rear_lo, link_dir.cross(Vector3.UP).normalized(), 0.012)
	for side in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(), brace_p + Vector3(0.020, -0.004, side * 0.021)), Vector3(0.030, 0.016, 0.003), 0.003, 1,
				CB.M_DARK, C_STEEL)
	coilover(b, rear_lo, rear_hi, 0.017, 0.028, 8.0,
			C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK, false)


func _centre_parts(b) -> void:
	# The hoop's top bar, its padded centre; the nose's bumper hoop and skid plate.
	b.tube(PackedVector3Array([Vector3(-HOOP_X, HOOP_TOP, HOOP_Z), Vector3(HOOP_X, HOOP_TOP, HOOP_Z)]), 0.018, 12,
			CB.M_ANODISED, Color(1, 1, 1), false, false)
	b.tube(PackedVector3Array([Vector3(-0.07, HOOP_TOP, HOOP_Z), Vector3(0.07, HOOP_TOP, HOOP_Z)]), 0.030, 12, CB.M_DARK,
			C_SEAT, true, true)
	b.tube(_rounded([Vector3(-0.12, 0.25, -1.00), Vector3(-0.08, 0.27, -1.15), Vector3(0.08, 0.27, -1.15),
			Vector3(0.12, 0.25, -1.00)], 0.05), 0.014, 10, CB.M_ANODISED, Color(1, 1, 1), true, true)
	# The skid plate guards the nose's underside on landings: tipped to the underside's slope and bolted flush to it
	# (it had hung 2-2.5cm under it and stuck out past the nose).
	var skid := Transform3D(Basis(Vector3.RIGHT, 0.406), Vector3(0.0, 0.229, -1.0))
	b.rbox(skid, Vector3(0.085, 0.004, 0.055), 0.003, 1, CB.M_ALLOY, C_ALLOY_DARK)
	for bx in [-0.06, 0.06]:
		for bz in [-0.035, 0.035]:
			b.disc(skid * Vector3(bx, -0.0045, bz), skid.basis * Vector3.DOWN, 0.005, 0.0, 8, CB.M_CHROME, C_CHROME)
	# Cross tubes: under the engine, at the hoop's foot, at the duct's foot.
	for z in [0.20, 0.62]:
		b.tube(PackedVector3Array([Vector3(-0.25, 0.26 if z < 0.5 else 0.285, z), Vector3(0.25, 0.26 if z < 0.5 else 0.285, z)]),
				0.014, 8, CB.M_DARK, C_STEEL, false, false)
	# The transaxle between the rear wheels.
	b.rbox(Transform3D(Basis(), Vector3(0.0, TYRE_R_R + 0.01, AXLE_R)), Vector3(0.075, 0.06, 0.07), 0.02, 2, CB.M_DARK,
			C_STEEL)
	# A belly pan, flush under the tub (it hung 6mm under it).
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.191, -0.30)), Vector3(0.20, 0.004, 0.55), 0.003, 1, CB.M_ALLOY, C_ALLOY_DARK)
	# A fuel tank across behind the hoop.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.0, 0.50, 0.29), Vector3.RIGHT, PackedVector2Array([Vector2(-0.15, 0.0), Vector2(-0.15, 0.045),
			Vector2(-0.14, 0.058), Vector2(0.14, 0.058), Vector2(0.15, 0.045), Vector2(0.15, 0.0)]), 18, CB.M_ALLOY, C_ALLOY)
	b.orient_away_from(vb, ib, Vector3(0.0, 0.50, 0.29))
	b.tube(PackedVector3Array([Vector3(0.08, 0.555, 0.29), Vector3(0.08, 0.575, 0.29)]), 0.016, 10, CB.M_DARK, C_DARK, false,
			true)
	# Its mounts (it floated 2cm clear of everything): a strap round it near each end and a bracket from each end cap
	# forward to the hoop's leg.
	for sx in [-1.0, 1.0]:
		var strap := PackedVector3Array()
		for k in 25:
			var a: float = TAU * k / 24.0
			strap.append(Vector3(0.10 * sx, 0.50 + sin(a) * 0.061, 0.29 + cos(a) * 0.061))
		b.tube(strap, 0.005, 5, CB.M_DARK, C_DARK, false, false)
		b.tube(PackedVector3Array([Vector3(0.145 * sx, 0.50, 0.29), Vector3(0.20 * sx, 0.50, 0.23),
				Vector3(0.228 * sx, 0.50, HOOP_Z + 0.004)]), 0.009, 8, CB.M_DARK, C_STEEL, false, false)


## A single bucket seat on the cockpit floor, harness in the accent colour.
func _seat(b) -> void:
	var floor_y := 0.230
	# The cushion sits on the floor (it hovered 5mm over it, and the seat with it).
	b.rbox(Transform3D(Basis(), Vector3(0.0, floor_y + 0.034, -0.02)), Vector3(0.115, 0.035, 0.13), 0.02, 2, CB.M_DARK,
			C_SEAT)
	var rake := Basis(Vector3.RIGHT, 0.26)
	var back_c := Vector3(0.0, floor_y + 0.22, 0.09)
	b.rbox(Transform3D(rake, back_c), Vector3(0.115, 0.17, 0.032), 0.02, 2, CB.M_DARK, C_SEAT)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.105 * sx, -0.03, -0.035)), Vector3(0.018, 0.14, 0.045), 0.014, 2,
				CB.M_DARK, C_SEAT)
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.048 * sx, 0.0, -0.036)), Vector3(0.012, 0.15, 0.003), 0.002, 1,
				CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, 0.19, -0.01)), Vector3(0.075, 0.05, 0.03), 0.02, 2, CB.M_DARK,
			C_SEAT)


## A small round wheel on a column into the dash, a gauge pod on the dash.
func _steering(b) -> void:
	var c := Vector3(0.0, 0.470, -0.360)
	var tilt := Basis(Vector3.RIGHT, -0.45)
	var ring := PackedVector3Array()
	for k in 25:
		var a: float = TAU * k / 24.0
		ring.append(c + tilt * Vector3(cos(a) * 0.068, sin(a) * 0.068, 0.0))
	b.tube(ring, 0.009, 6, CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([c + tilt * Vector3(-0.066, 0.0, 0.0), c + tilt * Vector3(0.066, 0.0, 0.0)]), 0.007, 6,
			CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([c, c + Vector3(0.0, -0.04, -0.17)]), 0.012, 8, CB.M_DARK, C_DARK, true, false)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.0, 0.478, -0.47)), Vector3(0.06, 0.025, 0.02), 0.01, 2,
			CB.M_DARK, C_DARK)
	b.disc(Vector3(0.0, 0.485, -0.452), Vector3(0.0, 0.48, 0.88).normalized(), 0.016, 0.0, 16, CB.M_HEADLAMP, Color(1, 1, 1))


## The aero engine behind the hoop: a crankcase, two finned cylinders out to the sides (a flat twin) with their heads,
## exhaust pipes curling down and back, red cone filters, the reduction drive's belt housing up to the prop's hub.
func _engine(b) -> void:
	var c := Vector3(0.0, 0.420, 0.560)
	b.rbox(Transform3D(Basis(), c), Vector3(0.085, 0.075, 0.075), 0.03, 2, CB.M_ALLOY, C_ALLOY_DARK)
	for sx in [-1.0, 1.0]:
		var axis := Vector3(sx, 0, 0)
		var base := c + axis * 0.085
		# The barrel's fins.
		for k in 7:
			var vb: int = b.vertex_count()
			var ib: int = b.index_count()
			var at := base + axis * (0.012 + 0.016 * k)
			b.lathe(at, axis, PackedVector2Array([Vector2(-0.004, 0.0), Vector2(-0.004, 0.060), Vector2(0.004, 0.060),
					Vector2(0.004, 0.0)]), 20, CB.M_ALLOY, C_ALLOY)
			b.orient_away_from(vb, ib, at)
		b.tube(PackedVector3Array([base, base + axis * 0.12]), 0.040, 16, CB.M_DARK, C_STEEL, false, false)
		# The head: a rounded block with its rocker cover.
		var head := base + axis * 0.135
		b.rbox(Transform3D(Basis(), head), Vector3(0.025, 0.055, 0.055), 0.018, 2, CB.M_ALLOY, C_ALLOY)
		b.rbox(Transform3D(Basis(), head + axis * 0.024), Vector3(0.006, 0.04, 0.04), 0.008, 2, CB.M_ANODISED, Color(1, 1, 1))
		# The exhaust: down out of the head, back under the duct.
		b.tube(_rounded([head + Vector3(0, -0.05, 0.0), head + Vector3(-0.02 * sx, -0.14, 0.02),
				Vector3(0.10 * sx, 0.24, 0.72), Vector3(0.10 * sx, 0.24, 0.98)], 0.06), 0.014, 10, CB.M_CHROME, C_CHROME, false,
				true)
		b.disc(Vector3(0.10 * sx, 0.24, 0.9805), Vector3.BACK, 0.010, 0.0, 10, CB.M_DARK, C_DARKER)
		# The carburettor's red cone filter on top of the head.
		var vb2: int = b.vertex_count()
		var ib2: int = b.index_count()
		b.lathe(head + Vector3(0, 0.055, -0.01), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.032), Vector2(0.05, 0.026),
				Vector2(0.075, 0.012), Vector2(0.080, 0.0)]), 14, CB.M_DARK, C_FILTER)
		b.orient_away_from(vb2, ib2, head + Vector3(0, 0.07, -0.01))
	# The reduction drive: a belt housing from the crank up to the prop's hub, its shaft back through the duct's middle.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.52, 0.665)), Vector3(0.05, 0.13, 0.03), 0.025, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(0.0, PROP_POS.y, 0.66), Vector3(0.0, PROP_POS.y, PROP_POS.z - 0.03)]), 0.022, 12,
			CB.M_ALLOY, C_ALLOY_DARK, false, true)


## The duct round the propeller (in the paint), its lips in chrome, a guard grille behind the blades, the two rudders
## behind it on their hinge posts.
func _duct(b) -> void:
	var z0: float = DUCT_C.z - DUCT_D * 0.5
	var z1: float = DUCT_C.z + DUCT_D * 0.5
	var th := 0.018
	# Outside and inside of the band, slightly bellied, flaring at the intake.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0, DUCT_C.y, DUCT_C.z), Vector3.BACK, PackedVector2Array([Vector2(-DUCT_D * 0.5, DUCT_R + th + 0.012),
			Vector2(-DUCT_D * 0.25, DUCT_R + th + 0.006), Vector2(DUCT_D * 0.2, DUCT_R + th),
			Vector2(DUCT_D * 0.5, DUCT_R + th * 0.6)]), 48, CB.M_PAINT, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0, DUCT_C.y, DUCT_C.z))
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(0, DUCT_C.y, DUCT_C.z), Vector3.BACK, PackedVector2Array([Vector2(-DUCT_D * 0.5, DUCT_R + 0.008),
			Vector2(-DUCT_D * 0.3, DUCT_R), Vector2(DUCT_D * 0.5, DUCT_R)]), 48, CB.M_DARK, C_DARK)
	b.orient_away_from(vb, ib, Vector3(0, DUCT_C.y, DUCT_C.z))
	b.flip(vb, ib)
	# The lips: a rounded chrome ring at the intake, a dark one at the exit.
	var ring_in := PackedVector3Array()
	var ring_out := PackedVector3Array()
	for k in 49:
		var a: float = TAU * k / 48.0
		ring_in.append(Vector3(cos(a) * (DUCT_R + th * 0.5 + 0.01), DUCT_C.y + sin(a) * (DUCT_R + th * 0.5 + 0.01), z0))
		ring_out.append(Vector3(cos(a) * (DUCT_R + th * 0.4), DUCT_C.y + sin(a) * (DUCT_R + th * 0.4), z1))
	b.tube(ring_in, 0.014, 8, CB.M_CHROME, C_CHROME, false, false)
	b.tube(ring_out, 0.010, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)
	# The guard grille behind the blades: spokes from a centre boss, two rings.
	var gz: float = z1 - 0.02
	for k in 12:
		var a: float = TAU * k / 12.0
		b.tube(PackedVector3Array([Vector3(cos(a) * 0.06, DUCT_C.y + sin(a) * 0.06, gz),
				Vector3(cos(a) * DUCT_R, DUCT_C.y + sin(a) * DUCT_R, gz)]), 0.004, 5, CB.M_DARK, C_DARK, false, false)
	for r in [0.22, 0.36]:
		var ring := PackedVector3Array()
		for k in 41:
			var a: float = TAU * k / 40.0
			ring.append(Vector3(cos(a) * r, DUCT_C.y + sin(a) * r, gz))
		b.tube(ring, 0.004, 5, CB.M_DARK, C_DARK, false, false)
	b.disc(Vector3(0, DUCT_C.y, gz + 0.003), Vector3.BACK, 0.065, 0.0, 20, CB.M_DARK, C_DARK)
	# Rudders: two vertical blades behind the duct, hinged on posts from its rim, in the paint.
	for sx in [-0.17, 0.17]:
		var outline := PackedVector2Array([Vector2(z1 + 0.035, 0.30), Vector2(z1 + 0.115, 0.32), Vector2(z1 + 0.13, 0.86),
				Vector2(z1 + 0.06, 0.90), Vector2(z1 + 0.035, 0.89)])
		slab(b, outline, sx, 0.010, CB.M_PAINT, Color(1, 1, 1))
		# The hinge post runs from the exit ring's bottom to its top, a short arm onto the ring at each end (it had stopped
		# 9cm short of the ring both ends, standing in the air behind the duct).
		var ring_r: float = DUCT_R + th * 0.4
		var dy: float = sqrt(ring_r * ring_r - sx * sx) - 0.004
		var y_lo: float = DUCT_C.y - dy
		var y_hi: float = DUCT_C.y + dy
		b.tube(PackedVector3Array([Vector3(sx, y_lo, z1 + 0.035), Vector3(sx, y_hi, z1 + 0.035)]), 0.008, 8, CB.M_DARK, C_STEEL,
				true, true)
		for y in [y_lo, y_hi]:
			b.tube(PackedVector3Array([Vector3(sx, y, z1), Vector3(sx, y, z1 + 0.035)]), 0.007, 8, CB.M_DARK, C_STEEL, true,
					true)


## The propeller, its own mesh about its hub (the Prop node spins it about z): three carbon blades, twisted from a
## steep root to a flat tip, their tips in the accent colour, a spinner over the hub.
func build_prop(b) -> void:
	for k in 3:
		var a0: float = TAU * k / 3.0
		var rows := []
		var n := 9
		for s in n:
			var t: float = float(s) / (n - 1)
			var r: float = lerpf(0.05, PROP_R, t)
			var chord: float = lerpf(0.075, 0.042, t) * (1.0 - 0.35 * pow(t, 6.0))
			var pitch: float = lerpf(0.75, 0.22, t)
			var radial := Vector3(cos(a0), sin(a0), 0.0)
			var tang := Vector3(-sin(a0), cos(a0), 0.0)
			var fwd := tang * cos(pitch) + Vector3(0, 0, -1) * sin(pitch)
			var mid := radial * r
			rows.append([mid - fwd * chord * 0.45, mid + fwd * chord * 0.55, t])
		var mid_row: Array = rows[n / 2]
		var mid: Vector3 = ((mid_row[0] as Vector3) + (mid_row[1] as Vector3)) * 0.5
		var mid_n: Vector3 = ((mid_row[1] as Vector3) - (mid_row[0] as Vector3)).cross(Vector3(cos(a0), sin(a0), 0.0)).normalized()
		for side in [1.0, -1.0]:
			var grid := []
			for row in rows:
				var thick: float = lerpf(0.010, 0.003, float(row[2]))
				var normal: Vector3 = ((row[1] as Vector3) - (row[0] as Vector3)).cross(Vector3(cos(a0), sin(a0), 0.0)).normalized()
				grid.append(PackedVector3Array([(row[0] as Vector3) + normal * thick * side * 0.5,
						(row[1] as Vector3) + normal * thick * side * 0.5]))
			# Each face looks out from the blade's middle plane.
			var inside: Vector3 = mid - mid_n * side * 0.1
			var tip_rows: Array = grid.slice(grid.size() - 3)
			var root_rows: Array = grid.slice(0, grid.size() - 2)
			var vb: int = b.vertex_count()
			var ib: int = b.index_count()
			b.grid(root_rows, CB.M_DARK, C_CARBON, false, false)
			b.orient_away_from(vb, ib, inside)
			vb = b.vertex_count()
			ib = b.index_count()
			b.grid(tip_rows, CB.M_ANODISED, Color(1, 1, 1), false, false)
			b.orient_away_from(vb, ib, inside)
	var vb2: int = b.vertex_count()
	var ib2: int = b.index_count()
	b.lathe(Vector3.ZERO, Vector3.FORWARD, PackedVector2Array([Vector2(-0.03, 0.0), Vector2(-0.03, 0.058),
			Vector2(0.0, 0.056), Vector2(0.04, 0.040), Vector2(0.075, 0.016), Vector2(0.09, 0.0)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb2, ib2, Vector3(0, 0, 0.02))


## Front wheels: a skinny ribbed tyre round a five-spoke alloy rim, the rim's face the same on both sides (built on
## the +x side, mirrored across), so the wheel reads alike from inside the car and out.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_F, 40, C_RUBBER)
	for k in 3:
		var x: float = (k - 1) * 0.022
		wheel_lathe(b, PackedVector2Array([Vector2(x - 0.004, 0.199), Vector2(x - 0.002, 0.204), Vector2(x + 0.002, 0.204),
				Vector2(x + 0.004, 0.199)]), 40, CB.M_RUBBER, C_RUBBER, "out")
	# The barrel between the two faces.
	wheel_lathe(b, PackedVector2Array([Vector2(-0.031, 0.105), Vector2(0.031, 0.105)]), 36, CB.M_RIM, Color(0.6, 0.6, 0.62),
			"in")
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	wheel_lathe(b, PackedVector2Array([Vector2(0.030, 0.128), Vector2(0.038, 0.130), Vector2(0.042, 0.124),
			Vector2(0.040, 0.110)]), 36, CB.M_RIM, C_RIM, "out", Vector3(0.02, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.040, 0.110), Vector2(0.030, 0.104)]), 36, CB.M_RIM, C_RIM, "+x")
	b.disc(Vector3(0.012, 0.0, 0.0), Vector3.RIGHT, 0.106, 0.0, 28, CB.M_DARK, C_DARKER)
	wheel_lathe(b, PackedVector2Array([Vector2(0.026, 0.034), Vector2(0.040, 0.032), Vector2(0.044, 0.026)]), 18, CB.M_RIM,
			C_RIM, "out", Vector3(0.03, 0.0, 0.0))
	b.disc(Vector3(0.0445, 0.0, 0.0), Vector3.RIGHT, 0.026, 0.0, 16, CB.M_ANODISED, Color(1, 1, 1))
	for k in 5:
		spoke(b, TAU * k / 5.0, 0.12, 0.030, 0.106, 0.040, 0.034, 0.012, 0.020, 0.010, CB.M_RIM, C_RIM)
	b.mirror_x(v0, i0)
	if side < 0.0:
		b.mirror_in_place()


## Rear wheels: a fat smooth sand tyre (two shallow grooves round it) on a deep-dished beadlock rim, the clamp ring's
## bolts round its face; the dish, bolts and cap the same on both sides (mirrored across).
func build_rear_wheel(b, side: float) -> void:
	tyre(b, TYRE_R, 48, C_RUBBER)
	for x in [-0.045, 0.045]:
		wheel_lathe(b, PackedVector2Array([Vector2(x - 0.006, 0.2552), Vector2(x - 0.003, 0.2525), Vector2(x + 0.003, 0.2525),
				Vector2(x + 0.006, 0.2552)]), 48, CB.M_DARK, C_DARKER, "out")
	# The barrel between the two dishes.
	wheel_lathe(b, PackedVector2Array([Vector2(-0.036, 0.145), Vector2(0.036, 0.145)]), 44, CB.M_RIM, Color(0.6, 0.6, 0.62),
			"in")
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	wheel_lathe(b, PackedVector2Array([Vector2(0.100, 0.150), Vector2(0.114, 0.153), Vector2(0.122, 0.147),
			Vector2(0.122, 0.128)]), 44, CB.M_RIM, C_RIM, "out", Vector3(0.09, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.122, 0.128), Vector2(0.104, 0.124), Vector2(0.040, 0.112)]), 44, CB.M_RIM,
			C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.040, 0.112), Vector2(0.036, 0.145)]), 44, CB.M_RIM, Color(0.6, 0.6, 0.62),
			"in")
	# The beadlock ring's bolts.
	for k in 16:
		var a: float = TAU * k / 16.0
		var f: Array = wheel_frame(a)
		var p: Vector3 = Vector3(0.123, 0.0, 0.0) + (f[0] as Vector3) * 0.139
		b.tube(PackedVector3Array([p, p + Vector3(0.007, 0, 0)]), 0.0045, 6, CB.M_CHROME, C_CHROME, false, true)
	# The dish's face: eight dark pockets round a hub cap.
	b.disc(Vector3(0.041, 0.0, 0.0), Vector3.RIGHT, 0.112, 0.04, 32, CB.M_RIM, C_RIM)
	for k in 8:
		var a: float = TAU * (k + 0.5) / 8.0
		var f: Array = wheel_frame(a)
		b.disc(Vector3(0.0415, 0.0, 0.0) + (f[0] as Vector3) * 0.078, Vector3.RIGHT, 0.017, 0.0, 12, CB.M_DARK, C_DARKER)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.042, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.040), Vector2(0.008, 0.034),
			Vector2(0.014, 0.020), Vector2(0.016, 0.0)]), 16, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.03, 0.0, 0.0))
	b.mirror_x(v0, i0)
	if side < 0.0:
		b.mirror_in_place()


func _detail_shapes() -> Dictionary:
	return {}


func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var gap := 0.0
	var black := 0.0
	var w: float = prof["w"].at(p.z)
	var outside: bool = n.x > 0.5 and p.x > w - 0.006
	# The cockpit: its floor, the inside of the tub, the dash's back and the bulkhead.
	if p.z > -0.49 and p.z < 0.125 and not outside and n.y < 0.95:
		if n.x < -0.45 or (n.y > 0.45 and p.y < 0.45) or (n.z > 0.4 and p.z < -0.40) or (n.z < -0.4 and p.z > 0.05):
			black = 1.0
	if p.z > -0.49 and p.z < 0.125 and n.y > 0.45 and p.y < 0.45:
		black = 1.0
	# A seam along the tub's flank, one round the nose's deck.
	if outside and p.z > -0.95 and p.z < 0.2:
		gap = maxf(gap, 0.8 * _cover(absf(p.y - 0.29) - 0.0018, fp))
	if n.y > 0.4 and p.z < -0.50:
		gap = maxf(gap, _cover(absf(p.x - (w - 0.03)) - 0.002, fp))
	# Two vents in the nose's deck.
	if n.y > 0.4 and p.z > -0.80 and p.z < -0.66:
		var vent := 1e3
		for k in 3:
			vent = minf(vent, _sd_box(Vector2(absf(p.x) - 0.09, p.z + 0.77 - 0.04 * k), Vector2(0.05, 0.007)) - 0.003)
		black = maxf(black, _cover(vent, fp))
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(0.0, gap, 0.0, black)
