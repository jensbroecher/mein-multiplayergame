# BootleggerBuilder.gd
#
# The Bootlegger: a hot rod (an original design with a made-up name), a chopped three-window coupé
# body on a highboy chassis: no fenders, no bonnet. Its cab and turtle deck sit on painted frame rails
# that run on forward, bare, past the engine to a tall chrome grille shell with two chrome bucket
# headlamps on a bar beside it. Everything ahead of the firewall is on show: a V8 with chrome finned
# valve covers, a roots blower on the intake with its drive belt down to the crank, a chrome "bug
# catcher" injector scoop on top, red plug wires, and four chrome zoomie pipes a side curling back and
# up out of the heads. Skinny front tyres with a thin whitewall on a dropped chrome I-beam axle
# (transverse leaf spring, hairpin radius rods, tube shocks), huge rear slicks on a quick-change rear
# end with ladder bars and coil-overs; steel wheels in the rim colour with chrome trim rings and caps.
# The '32-style fuel tank shows under the tail between two small taillamps on stalks. The car rakes
# forward: the front hubs are lower than the rear ones (the tyres' radii), and so is the frame.
#
# The shell is only the cab and the deck: the firewall is its nose cap (flat), the tail its rounded
# tail cap. Above the vertical side the section (_upper_segments) runs: the glass, leaning in from
# the belt; the roof corner's rounding; a crowned top. Over the cowl and the turtle deck the glass
# shrinks to nothing and the corner is the panels' rounded shoulder; the windscreen is where the top
# climbs from the cowl to the roof (KEYS). The detail map paints the chopped windows by height on that
# glass band, the windscreen and the small oval rear window by their faces, the black roof insert,
# the suicide doors' gaps and the deck lid.
extends "res://CarDesign.gd"

# Wheels: big and little. The front hubs sit at the skinny tyres' radius, the rear at the slicks'.
const FRONT_X := 0.500
const REAR_X := 0.560
const AXLE_F := -0.980
const AXLE_R := 0.550
const HUB_F := 0.165
const HUB_R := 0.270

# The section above the side along the car: z; top (the centre line); belt (the top of the vertical
# side); tuck (how far the glass leans in from the belt to the roof corner); rr (the roof corner's
# rounding across); crown (how much the top rises toward the centre line).
const KEYS := [
	# z       top    belt   tuck   rr     crown
	[-0.330, 0.628, 0.585, 0.004, 0.028, 0.010],
	[-0.250, 0.636, 0.590, 0.005, 0.028, 0.012],
	[-0.178, 0.642, 0.594, 0.006, 0.028, 0.012],
	[-0.160, 0.664, 0.596, 0.012, 0.030, 0.013],
	[-0.145, 0.714, 0.598, 0.020, 0.032, 0.014],
	[-0.130, 0.758, 0.600, 0.026, 0.034, 0.015],
	[-0.116, 0.784, 0.602, 0.030, 0.035, 0.015],
	[-0.095, 0.792, 0.603, 0.032, 0.035, 0.015],
	[0.050, 0.796, 0.606, 0.033, 0.036, 0.015],
	[0.150, 0.792, 0.607, 0.033, 0.038, 0.016],
	[0.210, 0.774, 0.607, 0.032, 0.045, 0.018],
	[0.270, 0.738, 0.605, 0.028, 0.055, 0.022],
	[0.330, 0.698, 0.600, 0.020, 0.062, 0.026],
	[0.400, 0.670, 0.595, 0.014, 0.066, 0.029],
	[0.550, 0.652, 0.588, 0.010, 0.068, 0.031],
	[0.700, 0.618, 0.570, 0.008, 0.062, 0.029],
	[0.845, 0.548, 0.520, 0.006, 0.050, 0.020],
]
const KEY_NAMES := ["top", "belt", "tuck", "rr", "crown"]
const W_KNOTS := [[-0.33, 0.250], [-0.24, 0.272], [-0.14, 0.292], [-0.05, 0.303], [0.20, 0.310], [0.50, 0.306],
	[0.70, 0.294], [0.845, 0.275]]
const BOT_KNOTS := [[-0.33, 0.262], [0.00, 0.282], [0.25, 0.296], [0.40, 0.318], [0.845, 0.322]]

# The chopped windows (in z, y on the side), the windscreen and the rear window.
const SIDE_WIN := [-0.090, 0.150, 0.620, 0.738]
const WS_Y := Vector2(0.658, 0.770)
const WS_HALF := 0.212
const DOOR_Z := Vector2(-0.112, 0.172)

# Tyres (half profiles, bead to tread centre): a skinny bias-ply front, a big rear slick.
const TYRE_F := [[-0.044, 0.108], [-0.048, 0.118], [-0.050, 0.132], [-0.049, 0.146], [-0.044, 0.156],
	[-0.034, 0.162], [-0.018, 0.165], [0.0, 0.165]]
const TYRE_R := [[-0.130, 0.170], [-0.138, 0.180], [-0.143, 0.198], [-0.144, 0.222], [-0.140, 0.243],
	[-0.130, 0.258], [-0.112, 0.266], [-0.070, 0.2695], [0.0, 0.270]]

# The engine: a V8 along the car between the rails, its banks leaning out 45 degrees.
const ENG_Z := -0.620
const ENG_LEN := 0.190
const PORTS := [-0.730, -0.640, -0.550, -0.460]

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.16, 0.16, 0.17)
const C_WHITEWALL := Color(0.90, 0.90, 0.87)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_STEEL := Color(0.14, 0.14, 0.15)
const C_ALLOY := Color(0.80, 0.81, 0.83)
const C_ALLOY_DARK := Color(0.46, 0.47, 0.49)
const C_CHROME := Color(0.93, 0.94, 0.96)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.62, 0.62, 0.64)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_WIRE := Color(0.72, 0.07, 0.04)
const C_PLATE := Color(0.95, 0.80, 0.18)
const C_RADIATOR := Color(0.10, 0.10, 0.11)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame. The flames
## start at the firewall and lick back along the cab.
const PAINT_LAYOUT := {
	"nose_z": -0.33, "tail_z": 0.845, "belt_y": 0.60, "side_x": 0.31,
	"door_z": 0.03, "door_y": 0.45, "roundel_r": 0.085,
	"hood_z": -0.255, "hood_r": 0.05, "stripe_w": 0.05, "stripe_gap": 0.02,
}
const ANTENNA_POS := Vector3(0.20, 0.595, 0.66)
const WHEEL_POSITIONS := {
	"FL": Vector3(-FRONT_X, HUB_F, AXLE_F), "FR": Vector3(FRONT_X, HUB_F, AXLE_F),
	"RL": Vector3(-REAR_X, HUB_R, AXLE_R), "RR": Vector3(REAR_X, HUB_R, AXLE_R),
}


func _init() -> void:
	nose_tip = -0.330
	nose_cap = 0.014
	nose_cap_y = 0.440
	nose_cap_exp = Vector2(8.0, 8.0)
	tail_tip = 0.845
	tail_cap = 0.110
	tail_cap_y = 0.400
	tail_cap_exp = Vector2(2.4, 2.0)
	# Bottom, bottom corner, side; the glass, the roof corner, the crowned top.
	segment_counts = [2, 3, 5, 5, 6, 9]
	half_ring = 30
	bottom_radius = 0.018
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	setup_shell(knots)


## Above the side: the glass (straight, leaning in by `tuck`), the roof corner (a quarter ellipse,
## rr across), the top (crowned toward the centre line by a cosine bump). Where the top is too low for
## glass (cowl, deck) the glass shrinks to a few millimetres and the corner is the panel's shoulder.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var tuck: float = prof["tuck"].at(z)
	var rr: float = prof["rr"].at(z)
	var crown: float = maxf(prof["crown"].at(z), 0.0)
	var edge: float = top - crown
	var by: float = maxf(edge - rr, belt + 0.003)
	var a_pt := Vector2(w, belt)
	var b_pt := Vector2(w - tuck, by)
	var c_pt := Vector2(b_pt.x - rr, edge)
	var corner := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.5 * k / 8.0
		corner.append(Vector2(b_pt.x - rr * (1.0 - cos(a)), b_pt.y + (c_pt.y - b_pt.y) * sin(a)))
	var x0: float = maxf(c_pt.x, 0.001)
	var top_pts := PackedVector2Array()
	for k in 17:
		var x: float = x0 * (1.0 - k / 16.0)
		top_pts.append(Vector2(x, edge + crown * 0.5 * (1.0 - cos((1.0 - x / x0) * PI))))
	return [PackedVector2Array([a_pt, b_pt]), corner, top_pts]


## Where the glass band ends at z (the roof corner's start): the side window lies under it.
func _glass_top(z: float) -> float:
	var edge: float = prof["top"].at(z) - maxf(prof["crown"].at(z), 0.0)
	return maxf(edge - prof["rr"].at(z), prof["belt"].at(z) + 0.003)


# ============================================================================================
#  Body
# ============================================================================================

func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)
	_engine(b)
	_grille_shell(b)
	_front_axle(b)
	_rear_end(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	_frame_rail(b)
	# Zoomies: four chrome pipes out of the head, curling back and up past the frame.
	for zp in PORTS:
		var path: PackedVector3Array = _rounded([Vector3(0.140, 0.352, zp), Vector3(0.265, 0.352, zp),
				Vector3(0.340, 0.385, zp + 0.035), Vector3(0.368, 0.455, zp + 0.125), Vector3(0.378, 0.500, zp + 0.200)],
				0.045, 5)
		b.tube(path, 0.0145, 10, CB.M_CHROME, C_CHROME, false, true)
		var end: Vector3 = path[path.size() - 1]
		var dir: Vector3 = (end - path[path.size() - 2]).normalized()
		b.disc(end + dir * 0.0008, dir, 0.0105, 0.0, 10, CB.M_DARK, C_DARKER)
		# The flange where it leaves the head.
		b.rbox(Transform3D(Basis(), Vector3(0.150, 0.352, zp)), Vector3(0.006, 0.022, 0.022), 0.003, 1, CB.M_CHROME,
				C_CHROME)
	# Plug wires: from the distributor at the back of the engine over the valve cover to each plug.
	for zp in PORTS:
		var plug := Vector3(0.168, 0.372, zp + 0.045)
		b.tube(_rounded([Vector3(0.012, 0.478, -0.395), Vector3(0.110, 0.505, -0.430), Vector3(0.200, 0.440, zp + 0.045),
				plug], 0.04, 4), 0.0042, 5, CB.M_DARK, C_WIRE, false, true)
		b.rbox(Transform3D(Basis(Vector3.BACK, -PI * 0.25), plug), Vector3(0.008, 0.012, 0.008), 0.003, 1, CB.M_DARK,
				C_WIRE)
	# Headlamps: chrome buckets on the bar beside the grille shell.
	_headlamp(b, Vector3(0.275, 0.505, -1.000))
	# Hairpin radius rods from the axle back to the frame rail, a tube shock up to the frame horn.
	var pin := Vector3(0.215, 0.232, -0.600)
	b.tube(PackedVector3Array([Vector3(0.360, 0.180, AXLE_F + 0.012), pin]), 0.0085, 8, CB.M_CHROME, C_CHROME, true, true)
	b.tube(PackedVector3Array([Vector3(0.300, 0.150, AXLE_F + 0.012), pin]), 0.0085, 8, CB.M_CHROME, C_CHROME, true, true)
	b.rbox(Transform3D(Basis(), pin), Vector3(0.016, 0.014, 0.020), 0.005, 1, CB.M_DARK, C_STEEL)
	_tube_shock(b, Vector3(0.395, 0.195, AXLE_F - 0.018), Vector3(0.222, 0.318, -1.000))
	b.rbox(Transform3D(Basis(), Vector3(0.222, 0.318, -1.000)), Vector3(0.020, 0.012, 0.014), 0.004, 1, CB.M_DARK, C_STEEL)
	# Kingpin and spindle.
	b.tube(PackedVector3Array([Vector3(0.445, 0.140, AXLE_F), Vector3(0.445, 0.232, AXLE_F)]), 0.016, 10, CB.M_DARK, C_STEEL,
			true, true)
	b.tube(PackedVector3Array([Vector3(0.430, HUB_F, AXLE_F), Vector3(0.462, HUB_F, AXLE_F)]), 0.013, 10, CB.M_ALLOY,
			C_ALLOY_DARK, true, true)
	# Rear: ladder bars from the axle forward under the body, a coil-over at each corner.
	for yy in [0.235, 0.300]:
		b.tube(PackedVector3Array([Vector3(0.318, yy, AXLE_R - 0.01), Vector3(0.300, 0.250, 0.060)]), 0.0095, 8,
				CB.M_CHROME, C_CHROME, true, true)
	for k in 3:
		var t: float = 0.25 + 0.25 * k
		var a: Vector3 = Vector3(0.318, 0.235, AXLE_R - 0.01).lerp(Vector3(0.300, 0.250, 0.060), t)
		var c: Vector3 = Vector3(0.318, 0.300, AXLE_R - 0.01).lerp(Vector3(0.300, 0.250, 0.060), t)
		b.tube(PackedVector3Array([a, c]), 0.006, 6, CB.M_CHROME, C_CHROME, false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.300, 0.252, 0.060)), Vector3(0.014, 0.016, 0.022), 0.004, 1, CB.M_DARK, C_STEEL)
	coilover(b, Vector3(0.365, 0.215, AXLE_R + 0.060), Vector3(0.352, 0.468, AXLE_R + 0.095), 0.017, 0.029, 7.0,
			C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.330, 0.478, AXLE_R + 0.095)), Vector3(0.032, 0.010, 0.022), 0.004, 1, CB.M_DARK,
			C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.365, 0.235, AXLE_R + 0.035)), Vector3(0.010, 0.026, 0.034), 0.004, 1, CB.M_DARK,
			C_STEEL)
	# Taillamp on a chrome stalk off the tank's corner.
	var lamp := Vector3(0.232, 0.318, 0.872)
	b.tube(_rounded([Vector3(0.200, 0.290, 0.800), Vector3(0.232, 0.300, 0.835), lamp + Vector3(0.0, 0.0, -0.022)], 0.02),
			0.0075, 8, CB.M_CHROME, C_CHROME, true, false)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(lamp, Vector3.BACK, PackedVector2Array([Vector2(-0.030, 0.0), Vector2(-0.027, 0.018), Vector2(-0.016, 0.029),
			Vector2(0.000, 0.033)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, lamp + Vector3.BACK * 0.01)
	round_lamp(b, lamp, Vector3.BACK, 0.030, CB.M_TAILLAMP, C_TAILLAMP)
	# Cab: the suicide door's handle at its front edge, its hinges at the back; a peep mirror.
	var wd: float = prof["w"].at(-0.08)
	b.rbox(Transform3D(Basis(), Vector3(wd + 0.006, 0.545, -0.080)), Vector3(0.006, 0.006, 0.026), 0.004, 1, CB.M_CHROME,
			C_CHROME)
	for hy in [0.395, 0.535]:
		var wh: float = prof["w"].at(DOOR_Z.y)
		b.rbox(Transform3D(Basis(), Vector3(wh + 0.004, hy, DOOR_Z.y)), Vector3(0.005, 0.014, 0.012), 0.004, 1,
				CB.M_CHROME, C_CHROME)
	var wm: float = prof["w"].at(-0.150)
	b.tube(PackedVector3Array([Vector3(wm - 0.010, 0.640, -0.150), Vector3(wm + 0.045, 0.680, -0.150)]), 0.004, 6,
			CB.M_CHROME, C_CHROME, false, false)
	var mc := Vector3(wm + 0.052, 0.684, -0.150)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(mc, Vector3.BACK, PackedVector2Array([Vector2(-0.010, 0.0), Vector2(-0.008, 0.018), Vector2(0.002, 0.022),
			Vector2(0.004, 0.0)]), 14, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, mc)


## The frame rail (right side): a boxed rail under the body, its outer face in the paint, running on
## forward bare past the engine to the front crossmember, and kicking up into the body over the axle.
func _frame_rail(b) -> void:
	var path := PackedVector3Array()
	var z := -1.050
	while z <= 0.30:
		var xo: float
		var ytop: float
		if z < -0.33:
			var t: float = (z + 1.050) / 0.72
			xo = lerpf(0.200, prof["w"].at(-0.33) - 0.012, smoothstep(0.0, 1.0, t))
			ytop = lerpf(0.290, prof["bot"].at(-0.33) - 0.001, t)
		else:
			xo = prof["w"].at(z) - 0.012
			ytop = prof["bot"].at(z) - 0.001
		path.append(Vector3(xo - 0.0175, ytop - 0.035, z))
		z += 0.05
	path.append(Vector3(prof["w"].at(0.36) - 0.030, prof["bot"].at(0.36) - 0.020, 0.360))
	path.append(Vector3(prof["w"].at(0.42) - 0.035, prof["bot"].at(0.42) + 0.030, 0.420))
	sweep(b, path, Vector3.UP, Vector3.RIGHT, PackedVector2Array([Vector2(-0.035, -0.0175), Vector2(0.035, -0.0175),
			Vector2(0.035, 0.0175), Vector2(-0.035, 0.0175)]), CB.M_PAINT, Color(1, 1, 1))


## A chrome headlamp bucket facing forward at c: an egg-shaped shell, the bezel and lens, its stand.
func _headlamp(b, c: Vector3) -> void:
	var r := 0.056
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, Vector3.FORWARD, PackedVector2Array([Vector2(-0.090, 0.0), Vector2(-0.084, 0.024), Vector2(-0.068, 0.042),
			Vector2(-0.042, 0.054), Vector2(-0.016, 0.059), Vector2(-0.002, 0.059)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, c + Vector3.BACK * 0.04)
	round_lamp(b, c, Vector3.FORWARD, r, CB.M_HEADLAMP, Color(1, 1, 1))
	# The stand under the bucket and the bar back to the grille shell.
	b.tube(PackedVector3Array([c + Vector3(0.0, -0.050, 0.040), Vector3(c.x, 0.440, c.z + 0.030)]), 0.009, 8, CB.M_CHROME,
			C_CHROME, false, false)
	b.tube(_rounded([Vector3(c.x, 0.440, c.z + 0.030), Vector3(c.x - 0.03, 0.428, c.z + 0.032),
			Vector3(0.0, 0.428, c.z + 0.032)], 0.03), 0.010, 8, CB.M_CHROME, C_CHROME, false, false)


## A tube shock from `lo` up to `hi`: a chrome rod into a black body with chrome ends.
func _tube_shock(b, lo: Vector3, hi: Vector3) -> void:
	var mid: Vector3 = lo.lerp(hi, 0.40)
	b.tube(PackedVector3Array([lo, mid]), 0.0065, 8, CB.M_CHROME, C_CHROME, true, false)
	b.tube(PackedVector3Array([mid, hi]), 0.016, 10, CB.M_DARK, C_DARK, true, true)
	b.tube(PackedVector3Array([hi.lerp(mid, 0.12), hi]), 0.0175, 10, CB.M_CHROME, C_CHROME, false, false)


func _centre_parts(b) -> void:
	# Front crossmember between the rails, under the grille shell.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.248, -1.030)), Vector3(0.200, 0.022, 0.020), 0.006, 1, CB.M_PAINT,
			Color(1, 1, 1))
	# Cowl: the fuel filler cap (on a '32 the tank fills through the cowl).
	var cy: float = top_y(0.0, -0.255)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.0, cy, -0.255), Vector3.UP, PackedVector2Array([Vector2(-0.004, 0.034), Vector2(0.004, 0.034),
			Vector2(0.008, 0.028), Vector2(0.010, 0.0)]), 18, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.0, cy - 0.01, -0.255))
	# The deck lid's handle.
	var dy: float = top_y(0.0, 0.700)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0.0, dy + 0.004, 0.700)), Vector3(0.030, 0.005, 0.008), 0.004, 1,
			CB.M_CHROME, C_CHROME)
	# The fuel tank under the tail, in the paint, with its rear face's licence plate.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.272, 0.735)), Vector3(0.235, 0.052, 0.082), 0.024, 2, CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.268, 0.819)), Vector3(0.072, 0.036, 0.004), 0.004, 1, CB.M_CHROME,
			C_CHROME)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.268, 0.822)), Vector3(0.064, 0.029, 0.003), 0.003, 1, CB.M_DARK, C_PLATE)
	# A chrome nerf bar round the tank's back, under the taillamps.
	b.tube(_rounded([Vector3(-0.200, 0.232, 0.790), Vector3(-0.200, 0.232, 0.880), Vector3(0.200, 0.232, 0.880),
			Vector3(0.200, 0.232, 0.790)], 0.04, 5), 0.011, 10, CB.M_CHROME, C_CHROME, true, true)
	# Rear crossmember and the rails' ends inside the body.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.318, 0.640)), Vector3(0.250, 0.016, 0.018), 0.005, 1, CB.M_DARK, C_STEEL)


## The engine: block and oil pan, the heads with chrome finned valve covers, the intake and the roots
## blower with its belt drive, the bug catcher scoop, the distributor; radiator and hose.
func _engine(b) -> void:
	var accent := Color(1, 1, 1)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.300, ENG_Z)), Vector3(0.118, 0.068, ENG_LEN + 0.010), 0.020, 2,
			CB.M_ANODISED, accent)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.205, ENG_Z + 0.020)), Vector3(0.098, 0.042, ENG_LEN - 0.030), 0.016, 2,
			CB.M_CHROME, C_CHROME)
	# Front cover and timing case, crank pulley.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.330, ENG_Z - ENG_LEN - 0.012)), Vector3(0.070, 0.060, 0.012), 0.012, 2,
			CB.M_ANODISED, accent)
	for sd in [-1.0, 1.0]:
		var side: float = sd
		var up := Vector3(0.7071 * side, 0.7071, 0.0)
		var across: Vector3 = Vector3(0.7071, -0.7071 * side, 0.0) * side
		var basis := Basis(across, up, Vector3.BACK)
		var hc := Vector3(0.100 * side, 0.392, ENG_Z)
		b.rbox(Transform3D(basis, hc), Vector3(0.050, 0.034, ENG_LEN - 0.005), 0.010, 1, CB.M_ANODISED, accent)
		var vc: Vector3 = hc + up * 0.054
		b.rbox(Transform3D(basis, vc), Vector3(0.046, 0.021, ENG_LEN - 0.012), 0.016, 2, CB.M_CHROME, C_CHROME)
		# Fins along the cover's top, and its breather.
		for k in 5:
			var fc: Vector3 = vc + up * 0.021 + across * (-0.028 + 0.014 * k)
			b.rbox(Transform3D(basis, fc), Vector3(0.0028, 0.006, ENG_LEN - 0.040), 0.0018, 1, CB.M_CHROME, C_CHROME)
		var br: Vector3 = vc + up * 0.026 + Vector3(0.0, 0.0, -ENG_LEN + 0.045)
		b.tube(PackedVector3Array([br, br + up * 0.030]), 0.016, 12, CB.M_CHROME, C_CHROME, false, true)
	# Intake manifold in the V, the blower on it.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.432, ENG_Z)), Vector3(0.066, 0.030, ENG_LEN - 0.010), 0.010, 1, CB.M_ALLOY,
			C_ALLOY)
	var bc := Vector3(0.0, 0.512, ENG_Z - 0.012)
	b.rbox(Transform3D(Basis(), bc), Vector3(0.085, 0.056, ENG_LEN), 0.030, 3, CB.M_ALLOY, C_ALLOY)
	for side in [-1.0, 1.0]:
		for k in 4:
			bar(b, Vector3(0.0865 * side, 0.486 + 0.017 * k, bc.z), Vector3(0.0035, 0.0028, ENG_LEN - 0.040), CB.M_ALLOY,
					C_ALLOY_DARK)
	# The blower's snout and its drive: a toothed pulley over the crank's, a belt round both.
	var fz: float = ENG_Z - ENG_LEN - 0.025
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.520, fz + 0.012)), Vector3(0.042, 0.036, 0.020), 0.010, 1, CB.M_ALLOY,
			C_ALLOY)
	var pz: float = fz - 0.020
	_pulley(b, Vector3(0.0, 0.520, pz), 0.046)
	_pulley(b, Vector3(0.0, 0.300, pz), 0.054)
	var belt := PackedVector3Array()
	for k in 13:
		var a: float = PI * k / 12.0
		belt.append(Vector3(0.050 * cos(a), 0.520 + 0.050 * sin(a), pz))
	for k in 13:
		var a: float = PI + PI * k / 12.0
		belt.append(Vector3(0.058 * cos(a), 0.300 + 0.058 * sin(a), pz))
	belt.append(belt[0])
	b.tube(belt, 0.0065, 6, CB.M_DARK, C_DARK, false, false)
	# Bug catcher: a base plate, the chrome scoop, its dark mouth with two butterflies.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.574, ENG_Z + 0.015)), Vector3(0.072, 0.008, 0.082), 0.004, 1, CB.M_ALLOY,
			C_ALLOY_DARK)
	# The injector's throttle body on the plate, the tall scoop on it leaning back a little.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.600, ENG_Z + 0.015)), Vector3(0.058, 0.022, 0.066), 0.010, 1, CB.M_ALLOY,
			C_ALLOY)
	var tilt := Basis(Vector3.RIGHT, 0.10)
	var sc := Vector3(0.0, 0.672, ENG_Z + 0.020)
	b.rbox(Transform3D(tilt, sc), Vector3(0.072, 0.052, 0.086), 0.020, 3, CB.M_CHROME, C_CHROME)
	var mouth: Vector3 = sc + tilt * Vector3(0.0, 0.004, -0.088)
	b.rbox(Transform3D(tilt, mouth), Vector3(0.058, 0.038, 0.004), 0.008, 1, CB.M_DARK, C_DARKER)
	for k in 3:
		b.rbox(Transform3D(tilt, mouth + tilt * Vector3(0.0, -0.022 + 0.022 * k, -0.003)),
				Vector3(0.052, 0.0025, 0.003), 0.002, 1, CB.M_CHROME, C_CHROME)
	# Distributor at the back of the engine, its cap in red.
	b.tube(PackedVector3Array([Vector3(0.0, 0.410, -0.395), Vector3(0.0, 0.462, -0.395)]), 0.014, 10, CB.M_DARK, C_STEEL,
			false, false)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.0, 0.462, -0.395), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.026), Vector2(0.018, 0.026),
			Vector2(0.026, 0.016), Vector2(0.028, 0.0)]), 14, CB.M_DARK, C_WIRE)
	b.orient_away_from(vb, ib, Vector3(0.0, 0.470, -0.395))
	# Radiator behind the grille shell, the top hose to the engine.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.430, -0.975)), Vector3(0.112, 0.158, 0.018), 0.006, 1, CB.M_DARK, C_RADIATOR)
	b.tube(_rounded([Vector3(0.050, 0.555, -0.957), Vector3(0.060, 0.560, -0.900), Vector3(0.070, 0.450, -0.830)], 0.03),
			0.013, 8, CB.M_DARK, C_DARK, false, false)


## A pulley facing forward (its axis along z) at c: a disc with a rim and a hub.
func _pulley(b, c: Vector3, r: float) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, Vector3.FORWARD, PackedVector2Array([Vector2(-0.016, r), Vector2(0.016, r), Vector2(0.018, r - 0.006),
			Vector2(0.010, r * 0.45), Vector2(0.020, r * 0.35), Vector2(0.022, 0.0)]), 20, CB.M_ALLOY, C_ALLOY)
	b.orient_away_from(vb, ib, c)


## The grille shell: a tall arched chrome shell in front of the radiator, vertical bars in its dark
## insert, the radiator cap on top.
func _grille_shell(b) -> void:
	var outline := _grille_outline()
	var n: int = outline.size()
	var zf := -1.045
	var zb := -0.995
	var inner := PackedVector2Array()
	for k in n:
		var a: Vector2 = outline[(k - 1 + n) % n]
		var c: Vector2 = outline[(k + 1) % n]
		var t: Vector2 = (c - a).normalized()
		inner.append(outline[k] + Vector2(-t.y, t.x) * 0.018)
	# The outline runs anticlockwise in (x, y), so the left normal (-t.y, t.x) points inward. The
	# shell's side wall, faced outward.
	var rows := []
	for k in n + 1:
		var p: Vector2 = outline[k % n]
		rows.append(PackedVector3Array([Vector3(p.x, p.y, zf), Vector3(p.x, p.y, zb)]))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_CHROME, C_CHROME, false, false)
	b.orient_away_from(vb, ib, Vector3(0.0, 0.42, (zf + zb) * 0.5))
	# The front rim, between the outline and the inner one.
	for k in n:
		var k2: int = (k + 1) % n
		face(b, [Vector3(outline[k].x, outline[k].y, zf), Vector3(outline[k2].x, outline[k2].y, zf),
				Vector3(inner[k2].x, inner[k2].y, zf), Vector3(inner[k].x, inner[k].y, zf)], Vector3.FORWARD, CB.M_CHROME,
				C_CHROME)
	# The inner wall back to the insert, faced inward, and the dark insert.
	var zi: float = zf + 0.016
	rows = []
	for k in n + 1:
		var p: Vector2 = inner[k % n]
		rows.append(PackedVector3Array([Vector3(p.x, p.y, zf), Vector3(p.x, p.y, zi)]))
	vb = b.vertex_count()
	ib = b.index_count()
	b.grid(rows, CB.M_CHROME, C_CHROME, false, false)
	b.orient_away_from(vb, ib, Vector3(0.0, 0.42, zf - 0.5))
	var ins := PackedVector3Array()
	for p in inner:
		ins.append(Vector3(p.x, p.y, zi))
	b.poly(ins, Vector3.FORWARD, CB.M_DARK, C_DARKER)
	# Vertical bars across the insert, each as tall as the opening at its x.
	var bars := 9
	for k in bars:
		var x: float = lerpf(-0.104, 0.104, float(k) / (bars - 1))
		var y_top: float = _grille_top(inner, x) - 0.004
		var y_bot: float = inner[0].y + 0.004
		bar(b, Vector3(x, (y_top + y_bot) * 0.5, zi - 0.006), Vector3(0.0045, (y_top - y_bot) * 0.5, 0.006), CB.M_CHROME,
				C_CHROME)
	# Radiator cap and a little ornament on the shell's crown.
	var top := 0.0
	for p in outline:
		top = maxf(top, p.y)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(0.0, top - 0.004, (zf + zb) * 0.5), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.020),
			Vector2(0.010, 0.020), Vector2(0.016, 0.014), Vector2(0.020, 0.0)]), 14, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.0, top, (zf + zb) * 0.5))


## The grille shell's outline: (x, y), anticlockwise in that plane from its bottom left (along the
## bottom, up the +x side, over the arch, down the -x side). A slightly flared base and an elliptical
## arch on top.
func _grille_outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y0 := 0.225
	var ys := 0.505
	var hw0 := 0.150
	var hw1 := 0.136
	var arch_h := 0.130
	pts.append(Vector2(-hw0, y0))
	pts.append(Vector2(hw0, y0))
	for k in 6:
		var t: float = float(k + 1) / 6.0
		pts.append(Vector2(lerpf(hw0, hw1, t), lerpf(y0, ys, t)))
	for k in range(1, 16):
		var a: float = PI * k / 16.0
		pts.append(Vector2(hw1 * cos(a), ys + arch_h * sin(a)))
	for k in 6:
		var t: float = float(k) / 6.0
		pts.append(Vector2(-lerpf(hw1, hw0, t), lerpf(ys, y0, t)))
	return pts


## The top of an outline (its arch) at x, for the bars.
static func _grille_top(outline: PackedVector2Array, x: float) -> float:
	var best := -1.0
	for k in outline.size():
		var a: Vector2 = outline[k]
		var c: Vector2 = outline[(k + 1) % outline.size()]
		if (x - a.x) * (x - c.x) <= 0.0 and absf(c.x - a.x) > 1e-6:
			best = maxf(best, lerpf(a.y, c.y, (x - a.x) / (c.x - a.x)))
	return best


## The dropped I-beam axle, the transverse leaf spring over it, its shackles, the drag link.
func _front_axle(b) -> void:
	var z := AXLE_F
	var path: PackedVector3Array = _rounded([Vector3(-0.445, 0.188, z), Vector3(-0.350, 0.188, z), Vector3(-0.240, 0.128, z),
			Vector3(0.240, 0.128, z), Vector3(0.350, 0.188, z), Vector3(0.445, 0.188, z)], 0.06, 5)
	b.oval_tube(path, 0.011, 0.020, Vector3.UP, 10, CB.M_CHROME, C_CHROME, true)
	# The spring: three leaves on an arch, the longest at the top, clamped to the crossmember.
	var zs := -0.968
	for k in 3:
		var half: float = 0.345 - 0.075 * k
		var leaf := PackedVector3Array()
		for s in 13:
			var x: float = lerpf(-half, half, float(s) / 12.0)
			var y: float = 0.218 + 0.040 * (1.0 - pow(x / 0.345, 2.0)) - 0.0105 * k
			leaf.append(Vector3(x, y, zs))
		b.oval_tube(leaf, 0.020, 0.0048, Vector3.UP, 8, CB.M_CHROME, C_CHROME, true)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.250, zs)), Vector3(0.030, 0.022, 0.026), 0.006, 1, CB.M_DARK, C_STEEL)
	for side in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(0.345 * side, 0.214, zs), Vector3(0.345 * side, 0.186, z)]), 0.007, 6,
				CB.M_DARK, C_STEEL, true, true)
	# Drag link from the steering box on the left rail to the left spindle's arm.
	b.tube(PackedVector3Array([Vector3(-0.440, 0.212, z + 0.060), Vector3(-0.222, 0.262, -0.680)]), 0.0085, 8,
			CB.M_CHROME, C_CHROME, true, true)
	b.rbox(Transform3D(Basis(), Vector3(-0.222, 0.268, -0.680)), Vector3(0.020, 0.026, 0.032), 0.006, 1, CB.M_DARK, C_STEEL)


## The quick-change rear end: axle tubes out to the drums, the chrome centre section and gear cover.
func _rear_end(b) -> void:
	b.tube(PackedVector3Array([Vector3(-0.428, HUB_R, AXLE_R), Vector3(0.428, HUB_R, AXLE_R)]), 0.027, 12, CB.M_DARK, C_DARK,
			true, true)
	var c := Vector3(0.0, HUB_R, AXLE_R)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, Vector3.BACK, PackedVector2Array([Vector2(-0.070, 0.0), Vector2(-0.064, 0.040), Vector2(-0.040, 0.068),
			Vector2(0.000, 0.078), Vector2(0.040, 0.068), Vector2(0.062, 0.042), Vector2(0.070, 0.0)]), 18, CB.M_CHROME,
			C_CHROME)
	b.orient_away_from(vb, ib, c)
	b.rbox(Transform3D(Basis(), c + Vector3(0.0, 0.010, 0.088)), Vector3(0.052, 0.058, 0.030), 0.018, 2, CB.M_CHROME,
			C_CHROME)
	for k in 4:
		bar(b, c + Vector3(0.0, -0.030 + 0.020 * k, 0.119), Vector3(0.038, 0.003, 0.002), CB.M_CHROME, C_ALLOY)


# ============================================================================================
#  Wheels
# ============================================================================================

## A front wheel: the skinny tyre with a thin whitewall, a steel wheel with a chrome trim ring and
## a dog-dish cap, a finned drum behind.
func build_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_F, 0.104, 0.058, true)


## A rear wheel: the slick on a deep steel wheel, a bigger cap, lug nuts and round vents.
func build_rear_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_R, 0.167, 0.078, false)


func _wheel(b, side: float, half: Array, rim_r: float, cap_r: float, whitewall: bool) -> void:
	tyre(b, half, 48, C_RUBBER)
	var hw: float = -float(half[0][0])
	if whitewall:
		# A thin whitewall band standing a hair proud of the outer sidewall.
		var x: float = hw + 0.0055
		var vb0: int = b.vertex_count()
		var ib0: int = b.index_count()
		b.lathe(Vector3.ZERO, Vector3.RIGHT, PackedVector2Array([Vector2(x - 0.001, 0.123), Vector2(x, 0.125),
				Vector2(x, 0.139), Vector2(x - 0.001, 0.141)]), 48, CB.M_RUBBER, C_WHITEWALL)
		b.orient_toward(vb0, ib0, Vector3.RIGHT)
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - 0.016
	# Rim lip over the bead, the chrome trim ring sloping in, the painted face, the barrel behind.
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.010, rim_r), Vector2(lip_x - 0.002, rim_r + 0.006),
			Vector2(lip_x + 0.003, rim_r + 0.004), Vector2(lip_x + 0.003, rim_r - 0.002)]), 48, CB.M_RIM, C_RIM, "out",
			Vector3(lip_x - 0.03, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x + 0.003, rim_r - 0.002), Vector2(lip_x + 0.002, rim_r - 0.010),
			Vector2(face_x + 0.004, rim_r * 0.80), Vector2(face_x, rim_r * 0.78)]), 48, CB.M_CHROME, C_CHROME, "+x")
	b.disc(Vector3(face_x, 0.0, 0.0), Vector3.RIGHT, rim_r * 0.785, cap_r * 0.9, 40, CB.M_RIM, C_RIM)
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.010, rim_r), Vector2(-hw + 0.010, rim_r - 0.002),
			Vector2(-hw + 0.002, rim_r + 0.002)]), 48, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(face_x - 0.004, 0.0, 0.0), Vector3.LEFT, rim_r * 0.80, 0.0, 32, CB.M_DARK, C_DARKER)
	if not whitewall:
		# Round vents in the face between the trim ring and the cap; lug nuts round the cap.
		for k in 8:
			var f: Array = wheel_frame(TAU * k / 8.0 + 0.2)
			b.disc(Vector3(face_x + 0.0012, 0.0, 0.0) + (f[0] as Vector3) * rim_r * 0.60, Vector3.RIGHT, 0.0135, 0.0, 12,
					CB.M_DARK, C_DARKER)
		for k in 5:
			var f: Array = wheel_frame(TAU * k / 5.0)
			var lc: Vector3 = Vector3(face_x, 0.0, 0.0) + (f[0] as Vector3) * (cap_r + 0.013)
			var vbn: int = b.vertex_count()
			var ibn: int = b.index_count()
			b.lathe(lc, Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.0075), Vector2(0.008, 0.0075),
					Vector2(0.010, 0.0)]), 6, CB.M_CHROME, C_CHROME)
			b.orient_away_from(vbn, ibn, lc)
	# The chrome cap: a shallow dome on the face.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	var cap_h: float = cap_r * 0.42
	b.lathe(Vector3(face_x, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(-0.002, cap_r), Vector2(cap_h * 0.35, cap_r * 0.92),
			Vector2(cap_h * 0.72, cap_r * 0.68), Vector2(cap_h * 0.93, cap_r * 0.36), Vector2(cap_h, 0.0)]), 32,
			CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(face_x - cap_r, 0.0, 0.0))
	# A finned brake drum on the inside of the wheel.
	var dr: float = rim_r * 0.82
	var dx: float = -hw + 0.004
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(dx, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(-0.040, 0.0), Vector2(-0.040, dr * 0.5),
			Vector2(-0.036, dr), Vector2(0.000, dr)]), 28, CB.M_ALLOY, C_ALLOY_DARK)
	b.orient_away_from(vb, ib, Vector3(dx - 0.02, 0.0, 0.0))
	for k in 12:
		var f: Array = wheel_frame(TAU * k / 12.0)
		var fc: Vector3 = Vector3(dx - 0.020, 0.0, 0.0) + (f[0] as Vector3) * (dr + 0.004)
		b.rbox(Transform3D(_fin_basis(f), fc),
				Vector3(0.017, 0.006, 0.0025), 0.0015, 1, CB.M_ALLOY, C_ALLOY_DARK)
	if side < 0.0:
		b.mirror_in_place()


## A drum fin's basis: x along the axle, y out along the radius, z along the rolling direction.
static func _fin_basis(f: Array) -> Basis:
	return Basis(Vector3.RIGHT, f[0], f[1])


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var z: float = p.z
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var gt: float = _glass_top(z)
	# Side windows: the chopped glass on the band between the belt and the roof corner.
	if n.x > 0.3 and p.y > belt - 0.004:
		var c := Vector2((SIDE_WIN[0] + SIDE_WIN[1]) * 0.5, (SIDE_WIN[2] + SIDE_WIN[3]) * 0.5)
		var h := Vector2((SIDE_WIN[1] - SIDE_WIN[0]) * 0.5 - 0.016, (SIDE_WIN[3] - SIDE_WIN[2]) * 0.5 - 0.016)
		var d: float = _sd_box(Vector2(z, p.y) - c, h) - 0.016
		glass = maxf(glass, _cover(d, fp))
		chrome = maxf(chrome, _cover(d - 0.006, fp))
	# Windscreen: the steep face where the top climbs from the cowl to the roof.
	if n.z < -0.35 and z > -0.180 and z < -0.100:
		var d: float = _sd_box(Vector2(p.x, p.y - (WS_Y.x + WS_Y.y) * 0.5), Vector2(WS_HALF - 0.012,
				(WS_Y.y - WS_Y.x) * 0.5 - 0.012)) - 0.012
		glass = maxf(glass, _cover(d, fp))
		chrome = maxf(chrome, _cover(d - 0.008, fp))
	# Rear window: a small rounded slot on the back of the cab.
	if n.z > 0.30 and z > 0.180 and z < 0.360:
		var d: float = _sd_box(Vector2(p.x, p.y - 0.712), Vector2(0.098, 0.016)) - 0.020
		glass = maxf(glass, _cover(d, fp))
		chrome = maxf(chrome, _cover(d - 0.005, fp))
	# The roof's black insert.
	if n.y > 0.75 and z > -0.10 and z < 0.19:
		var d: float = _sd_box(Vector2(p.x, z - 0.045), Vector2(0.150, 0.085)) - 0.025
		black = maxf(black, _cover(d, fp))
		gap = maxf(gap, _cover(absf(d + 0.001) - 0.0016, fp))
	var on_side: bool = n.x > 0.45 and p.x > w - 0.02
	if on_side:
		# Suicide doors: the gaps at their front and back edges, up to the drip rail, and the drip rail.
		var bot: float = prof["bot"].at(z)
		for dz in [DOOR_Z.x, DOOR_Z.y]:
			gap = maxf(gap, _cover(absf(z - dz) - 0.0018, fp) * float(p.y > bot + 0.010 and p.y < gt + 0.002))
		if z > DOOR_Z.x and z < DOOR_Z.y:
			gap = maxf(gap, 0.8 * _cover(absf(p.y - (gt - 0.0015)) - 0.0015, fp))
		# The belt molding's reveal, all round.
		if p.y < belt:
			gap = maxf(gap, 0.7 * _cover(absf(p.y - (belt - 0.032)) - 0.0016, fp))
	# Deck lid on the turtle deck.
	if n.y > 0.2 and z > 0.36:
		var d: float = _sd_box(Vector2(p.x, z - 0.590), Vector2(0.165, 0.150)) - 0.035
		gap = maxf(gap, _cover(absf(d) - 0.0017, fp))
	# Cowl vent ahead of the windscreen: a chrome-edged slot.
	if n.y > 0.6 and z < -0.17:
		var d: float = _sd_box(Vector2(p.x, z + 0.205), Vector2(0.075, 0.010)) - 0.004
		black = maxf(black, _cover(d, fp))
		chrome = maxf(chrome, _cover(absf(d - 0.003) - 0.002, fp))
	# The firewall (the shell's flat nose) in satin black, so the engine stands out against it.
	if n.z < -0.6 and z < -0.300:
		black = maxf(black, 0.92)
	# Underside.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, chrome, black)
