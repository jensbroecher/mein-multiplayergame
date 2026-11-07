# MeteorBuilder.gd
#
# The Meteor: a Grand Prix single-seater in the manner of the 1930s (an original design with a made-up
# name). A long rounded bonnet held down by two leather straps, louvred along its sides, an upright
# chrome-edged radiator grille on its nose; the body swells at the scuttle round an open cockpit with a
# padded, chrome-beaded rim, a little curved aero screen (see-through, build_glass()), a big wood-rimmed
# steering wheel and a leather seat; behind the driver a headrest fairing rises out of the tail and runs
# back with it to a pointed boat tail carrying a chrome filler cap. On the left four exhaust stubs leave
# the bonnet's side and sweep down into one big pipe running back along the body to a fishtail. Tall
# narrow tyres on wire wheels (forty laced spokes, two-eared knock-off spinners), big finned drums
# showing through the spokes; a beam axle on leaf springs with friction dampers at the front, a live
# axle out to the rear wheels.
#
# The shell's section above the side (_upper_segments, keyed along the car in KEYS): a round shoulder
# from the belt, a rim, a wall, a corner and a crowned top. Over the bonnet the shoulder does nearly
# all of it (an elliptical dome); over the cockpit the rim is the padded edge and the wall runs down
# inside to the floor (a trough, as on the Centurion), so the dash and the seat back are clean walls;
# behind it the wall rises inward as the headrest fairing's flank and the corner rounds its top.
extends "res://CarDesign.gd"

const WHEEL_X := 0.420
const REAR_X := 0.430
const AXLE_F := -0.800
const AXLE_R := 0.620
const HUB_Y := 0.215

# The section above the side, keyframed along the car: z; belt (top of the vertical side); sx, sy
# (the shoulder's quarter ellipse, across and up); rim_w (a flat rim inward from the shoulder's top);
# wall_dx (how far the wall leans in); edge (the top's height at the corner: the bonnet's top, the
# cockpit floor, the headrest's top); cx, cy (the corner onto the top: cy < 0 the floor's fillet);
# crown (the top's rise to the centre line).
const KEYS := [
	# z       belt   sx     sy     rim_w  wall_dx edge   cx     cy      crown
	[-1.180, 0.262, 0.088, 0.122, 0.003, 0.002, 0.388, 0.004, 0.000, 0.004],
	[-1.000, 0.268, 0.100, 0.140, 0.003, 0.002, 0.412, 0.004, 0.000, 0.004],
	[-0.700, 0.272, 0.112, 0.150, 0.003, 0.002, 0.426, 0.004, 0.000, 0.004],
	[-0.420, 0.280, 0.130, 0.160, 0.003, 0.002, 0.444, 0.004, 0.000, 0.004],
	[-0.250, 0.288, 0.152, 0.172, 0.003, 0.002, 0.464, 0.004, 0.000, 0.004],
	[-0.160, 0.292, 0.160, 0.176, 0.003, 0.002, 0.472, 0.004, 0.000, 0.004],
	[-0.150, 0.296, 0.050, 0.098, 0.012, 0.008, 0.190, 0.020, -0.015, 0.000],
	[0.212, 0.300, 0.044, 0.096, 0.012, 0.008, 0.190, 0.020, -0.015, 0.000],
	[0.222, 0.300, 0.070, 0.082, 0.003, 0.046, 0.536, 0.034, 0.030, 0.012],
	[0.400, 0.298, 0.068, 0.080, 0.003, 0.044, 0.512, 0.033, 0.029, 0.012],
	[0.620, 0.292, 0.062, 0.072, 0.003, 0.040, 0.462, 0.030, 0.026, 0.011],
	[0.850, 0.284, 0.050, 0.058, 0.003, 0.026, 0.402, 0.022, 0.018, 0.008],
	[1.000, 0.278, 0.034, 0.042, 0.002, 0.012, 0.352, 0.012, 0.010, 0.004],
	[1.100, 0.272, 0.014, 0.026, 0.002, 0.004, 0.312, 0.004, 0.004, 0.002],
]
const KEY_NAMES := ["belt", "sx", "sy", "rim_w", "wall_dx", "edge", "cx", "cy", "crown"]
const W_KNOTS := [[-1.18, 0.122], [-1.00, 0.138], [-0.70, 0.148], [-0.42, 0.165], [-0.25, 0.196], [-0.12, 0.212],
	[0.15, 0.214], [0.40, 0.200], [0.62, 0.178], [0.85, 0.132], [1.00, 0.082], [1.10, 0.034]]
const BOT_KNOTS := [[-1.18, 0.205], [-1.06, 0.172], [-0.90, 0.158], [0.50, 0.150], [0.80, 0.170], [1.00, 0.205],
	[1.10, 0.235]]

const COCKPIT_Z := Vector2(-0.150, 0.212)
const STRAPS := [-0.860, -0.520]
const STUBS := [-0.560, -0.480, -0.400, -0.320]
const SCREEN_Z := -0.215

# A tall, narrow ribbed tyre (half its profile, bead to tread centre) and the wire wheel in it.
const TYRE_HALF := [[-0.044, 0.150], [-0.050, 0.160], [-0.055, 0.176], [-0.056, 0.192], [-0.052, 0.204],
	[-0.042, 0.211], [-0.025, 0.2145], [0.0, 0.215]]
const RIM_R := 0.148
const SPOKES := 40

const C_RUBBER := Color(0.17, 0.17, 0.18)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_STEEL := Color(0.15, 0.15, 0.16)
const C_LEATHER := Color(0.36, 0.17, 0.07)
const C_STRAP := Color(0.24, 0.12, 0.05)
const C_WOOD := Color(0.48, 0.27, 0.11)
const C_ALLOY := Color(0.80, 0.81, 0.83)
const C_ALLOY_DARK := Color(0.46, 0.47, 0.49)
const C_EXHAUST := Color(0.66, 0.56, 0.44)
const C_CHROME := Color(0.93, 0.94, 0.96)
const C_RIM := Color(1, 1, 1)
const C_GAUGE := Color(0.88, 0.86, 0.78)
const GLASS_TINT := Color(0.70, 0.78, 0.80, 0.16)

const PAINT_LAYOUT := {
	"nose_z": -1.18, "tail_z": 1.10, "belt_y": 0.30, "side_x": 0.20,
	"door_z": 0.40, "door_y": 0.245, "roundel_r": 0.062,
	"hood_z": -0.700, "hood_r": 0.050, "stripe_w": 0.032, "stripe_gap": 0.010,
}
const ANTENNA_POS := Vector3(0.0, 0.456, 0.66)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-REAR_X, HUB_Y, AXLE_R), "RR": Vector3(REAR_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.180
	nose_cap = 0.050
	nose_cap_y = 0.300
	nose_cap_exp = Vector2(4.0, 3.5)
	tail_tip = 1.100
	tail_cap = 0.045
	tail_cap_y = 0.282
	tail_cap_exp = Vector2(2.0, 2.0)
	# Bottom, bottom corner, side; shoulder, rim, wall, corner, top.
	segment_counts = [2, 3, 4, 8, 2, 5, 4, 6]
	half_ring = 34
	bottom_radius = 0.030
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[6] + key[9]])
	setup_shell(knots)


## Above the side: the shoulder (a quarter ellipse from the belt up and in), the rim (flat, inward),
## the wall (to the corner's start: up over the bonnet and tail, down into the cockpit), the corner,
## the crowned top.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var sx: float = prof["sx"].at(z)
	var sy: float = prof["sy"].at(z)
	var rim_w: float = maxf(prof["rim_w"].at(z), 0.001)
	var edge: float = prof["edge"].at(z)
	var cx: float = maxf(prof["cx"].at(z), 0.002)
	var cy: float = prof["cy"].at(z)
	var crown: float = maxf(prof["crown"].at(z), 0.0)
	var shoulder := PackedVector2Array()
	for k in 13:
		var a: float = PI * 0.5 * k / 12.0
		shoulder.append(Vector2(w - sx * (1.0 - cos(a)), belt + sy * sin(a)))
	var s_pt: Vector2 = shoulder[12]
	var r_pt := Vector2(s_pt.x - rim_w, s_pt.y)
	var b_pt := Vector2(r_pt.x - maxf(prof["wall_dx"].at(z), 0.001), edge - cy)
	if absf(b_pt.y - r_pt.y) < 0.002:
		b_pt.y = r_pt.y + 0.002
	var c_pt := Vector2(b_pt.x - cx, edge)
	var corner := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.5 * k / 8.0
		corner.append(Vector2(b_pt.x + (c_pt.x - b_pt.x) * (1.0 - cos(a)), b_pt.y + (c_pt.y - b_pt.y) * sin(a)))
	var x0: float = maxf(c_pt.x, 0.001)
	var top_pts := PackedVector2Array()
	for k in 17:
		var x: float = x0 * (1.0 - k / 16.0)
		top_pts.append(Vector2(x, edge + crown * 0.5 * (1.0 - cos((1.0 - x / x0) * PI))))
	return [shoulder, PackedVector2Array([s_pt, r_pt]), PackedVector2Array([r_pt, b_pt]), corner, top_pts]


## The shoulder's top at z (the bonnet's dome, the cockpit's padded rim, the tail's shoulder).
func _shoulder_top(z: float) -> Vector2:
	return Vector2(prof["w"].at(z) - prof["sx"].at(z), prof["belt"].at(z) + prof["sy"].at(z))


# ============================================================================================
#  Body
# ============================================================================================

func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_grille(b)
	for z in STRAPS:
		_strap(b, z)
	_exhaust(b)
	_cockpit(b)
	_screen_frame(b)
	_front_axle(b)
	_rear_axle(b)
	# Filler cap on the tail, on the headrest fairing's top.
	var fz := 0.840
	var fy: float = top_y(0.0, fz)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.0, fy - 0.004, fz), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.034), Vector2(0.010, 0.034),
			Vector2(0.016, 0.026), Vector2(0.019, 0.010), Vector2(0.020, 0.0)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.0, fy - 0.01, fz))
	b.rbox(Transform3D(Basis(), Vector3(0.0, fy + 0.020, fz)), Vector3(0.026, 0.004, 0.006), 0.003, 1, CB.M_CHROME, C_CHROME)


## Right-hand parts, mirrored by build_body(): the front spring and friction damper, the rear damper,
## a mirror on the scuttle.
func _side_parts(b) -> void:
	# Front leaf spring along the chassis, its middle clamped on the axle, its ends up to the body.
	var sx := 0.130
	for k in 3:
		var half: float = 0.180 - 0.045 * k
		var leaf := PackedVector3Array()
		for s in 11:
			var dz: float = lerpf(-half, half, float(s) / 10.0)
			var y: float = 0.150 + 0.040 * pow(dz / 0.180, 2.0) - 0.008 * k
			leaf.append(Vector3(sx, y, AXLE_F + dz))
		b.oval_tube(leaf, 0.016, 0.0040, Vector3.UP, 8, CB.M_DARK, C_STEEL, true)
	b.rbox(Transform3D(Basis(), Vector3(sx, 0.140, AXLE_F)), Vector3(0.022, 0.016, 0.026), 0.004, 1, CB.M_DARK, C_STEEL)
	# Friction damper: a pair of discs on the chassis side, an arm down to the axle.
	_damper(b, Vector3(0.200, 0.186, AXLE_F + 0.045), Vector3(0.240, 0.150, AXLE_F))
	_damper(b, Vector3(0.200, 0.200, AXLE_R - 0.050), Vector3(0.250, HUB_Y - 0.020, AXLE_R))
	# Kingpin and spindle at the axle's end.
	b.tube(PackedVector3Array([Vector3(0.360, 0.180, AXLE_F), Vector3(0.360, 0.250, AXLE_F)]), 0.013, 10, CB.M_DARK, C_STEEL,
			true, true)
	b.tube(PackedVector3Array([Vector3(0.350, HUB_Y, AXLE_F), Vector3(0.375, HUB_Y, AXLE_F)]), 0.011, 10, CB.M_ALLOY,
			C_ALLOY_DARK, true, true)
	# Rear spring under the body (its ends show), the live axle's tube to the hub.
	b.tube(PackedVector3Array([Vector3(0.370, HUB_Y, AXLE_R), Vector3(0.392, HUB_Y, AXLE_R)]), 0.016, 10, CB.M_ALLOY,
			C_ALLOY_DARK, true, true)
	# A small round mirror on a stalk on the scuttle.
	var mz := -0.300
	var mx: float = prof["w"].at(mz) - 0.035
	var my: float = top_y(mx, mz)
	b.tube(PackedVector3Array([Vector3(mx, my - 0.004, mz), Vector3(mx + 0.030, my + 0.050, mz + 0.010)]), 0.0035, 6,
			CB.M_CHROME, C_CHROME, false, false)
	var mc := Vector3(mx + 0.034, my + 0.058, mz + 0.012)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(mc, Vector3.BACK, PackedVector2Array([Vector2(-0.010, 0.0), Vector2(-0.008, 0.018), Vector2(0.002, 0.022),
			Vector2(0.004, 0.0)]), 14, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, mc)


## A friction damper: two discs (dark, a bright bolt) at `c` facing along x, an arm to `to`.
func _damper(b, c: Vector3, to: Vector3) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, Vector3.RIGHT, PackedVector2Array([Vector2(-0.012, 0.0), Vector2(-0.012, 0.032), Vector2(-0.006, 0.034),
			Vector2(0.006, 0.034), Vector2(0.012, 0.032), Vector2(0.012, 0.0)]), 16, CB.M_DARK, C_STEEL)
	b.orient_away_from(vb, ib, c)
	b.disc(c + Vector3(0.0125, 0.0, 0.0), Vector3.RIGHT, 0.010, 0.0, 10, CB.M_CHROME, C_CHROME)
	b.tube(PackedVector3Array([c + Vector3(0.006, 0.0, 0.0), to]), 0.006, 6, CB.M_DARK, C_STEEL, true, true)


## The radiator grille on the nose: a chrome tube round a shield, a dark recessed core, vertical slats.
func _grille(b) -> void:
	var outline := PackedVector2Array()
	var y0 := 0.232
	var ys := 0.318
	var hw := 0.080
	outline.append(Vector2(0.0, y0 - 0.012))
	for k in 6:
		var t: float = float(k + 1) / 6.0
		outline.append(Vector2(hw * sin(t * PI * 0.5), y0 - 0.012 * cos(t * PI * 0.5)))
	for k in 4:
		outline.append(Vector2(hw, lerpf(y0, ys, float(k + 1) / 4.0)))
	for k in range(1, 12):
		var a: float = PI * k / 12.0
		outline.append(Vector2(hw * cos(a), ys + 0.046 * sin(a)))
	for k in 4:
		outline.append(Vector2(-hw, lerpf(ys, y0, float(k) / 4.0)))
	for k in 6:
		var t: float = float(k) / 6.0
		outline.append(Vector2(-hw * cos(t * PI * 0.5), y0 - 0.012 * sin(t * PI * 0.5)))
	var zc: float = shell_z(0.0, 0.30, true)
	var ring := PackedVector3Array()
	for p in outline:
		ring.append(Vector3(p.x, p.y, minf(shell_z(p.x, p.y, true), zc + 0.006) - 0.004))
	ring.append(ring[0])
	b.tube(ring, 0.0075, 8, CB.M_CHROME, C_CHROME, false, false)
	var core := PackedVector3Array()
	for p in outline:
		core.append(Vector3(p.x * 0.97, 0.298 + (p.y - 0.298) * 0.97, zc - 0.002))
	b.poly(core, Vector3.FORWARD, CB.M_DARK, C_DARKER)
	for k in 11:
		var x: float = lerpf(-0.070, 0.070, k / 10.0)
		var top: float = ys + 0.046 * sqrt(maxf(1.0 - pow(x / hw, 2.0), 0.0)) - 0.010
		bar(b, Vector3(x, (top + y0 + 0.004) * 0.5, zc - 0.005), Vector3(0.0022, (top - y0 - 0.004) * 0.5, 0.003),
				CB.M_CHROME, C_CHROME)
	# The starting-handle boss under it.
	b.tube(PackedVector3Array([Vector3(0.0, 0.212, zc + 0.01), Vector3(0.0, 0.212, zc - 0.022)]), 0.009, 10, CB.M_CHROME,
			C_CHROME, false, true)


## A leather strap over the bonnet at z: a band lying on the shell from belt to belt over the top, a
## chrome buckle on the right side.
func _strap(b, z: float) -> void:
	var sec: PackedVector2Array = section(z)
	var belt: float = prof["belt"].at(z)
	var pts := []
	for k in sec.size():
		if sec[k].y >= belt - 0.030:
			pts.append(sec[k])
	# Up the left side to the top's centre, then down the right.
	var line2 := []
	for k in pts.size():
		line2.append(Vector2(-pts[k].x, pts[k].y))
	for k in range(pts.size() - 2, -1, -1):
		line2.append(pts[k])
	# Offset outward along each point's normal (the section runs up the right side to the top).
	var rows := []
	for k in line2.size():
		var a: Vector2 = line2[maxi(k - 1, 0)]
		var c: Vector2 = line2[mini(k + 1, line2.size() - 1)]
		var t: Vector2 = (c - a).normalized()
		var n2 := Vector2(t.y, -t.x)
		if n2.dot(line2[k] - Vector2(0.0, 0.30)) < 0.0:
			n2 = -n2
		var p: Vector2 = line2[k] + n2 * 0.0035
		rows.append(PackedVector3Array([Vector3(p.x, p.y, z - 0.013), Vector3(p.x, p.y, z + 0.013)]))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_DARK, C_STRAP, false, false)
	b.orient_away_from(vb, ib, Vector3(0.0, 0.30, z))
	var w: float = prof["w"].at(z)
	b.rbox(Transform3D(Basis(), Vector3(w + 0.006, belt + 0.020, z)), Vector3(0.004, 0.012, 0.016), 0.003, 1, CB.M_CHROME,
			C_CHROME)


## The exhaust on the left: four stubs out of the bonnet side, curling down into a big pipe that runs
## back along the body to a fishtail behind the rear wheel.
func _exhaust(b) -> void:
	var px := -0.262
	var py := 0.218
	for zs in STUBS:
		var w: float = prof["w"].at(zs)
		b.tube(_rounded([Vector3(-w + 0.020, 0.318, zs), Vector3(-w - 0.040, 0.318, zs), Vector3(px + 0.004, py + 0.040,
				zs + 0.060), Vector3(px, py + 0.012, zs + 0.110)], 0.03, 4), 0.0145, 10, CB.M_ALLOY, C_EXHAUST, false, false)
		b.rbox(Transform3D(Basis(), Vector3(-w - 0.002, 0.318, zs)), Vector3(0.006, 0.024, 0.024), 0.003, 1, CB.M_ALLOY,
				C_ALLOY_DARK)
	var main := PackedVector3Array()
	var z0: float = STUBS[0] + 0.060
	for k in 21:
		var z: float = lerpf(z0, 0.980, k / 20.0)
		main.append(Vector3(px + 0.008 * smoothstep(0.7, 0.98, z), py, z))
	var radii := PackedFloat32Array()
	for k in main.size():
		radii.append(0.019 + 0.010 * smoothstep(z0, 0.0, main[k].z))
	b.tube(main, 0.028, 14, CB.M_ALLOY, C_EXHAUST, true, false, radii)
	# The fishtail: the pipe flattened and flared at its end, dark inside.
	var end: Vector3 = main[main.size() - 1]
	var fish := PackedVector3Array([end, end + Vector3(-0.004, 0.0, 0.050), end + Vector3(-0.008, 0.0, 0.085)])
	b.oval_tube(fish, 0.030, 0.012, Vector3.RIGHT, 12, CB.M_ALLOY, C_EXHAUST, false)
	b.rbox(Transform3D(Basis(), end + Vector3(-0.008, 0.0, 0.086)), Vector3(0.010, 0.026, 0.002), 0.002, 1, CB.M_DARK,
			C_DARKER)
	# Brackets to the body.
	for z in [-0.150, 0.300, 0.760]:
		var w: float = prof["w"].at(z)
		b.tube(PackedVector3Array([Vector3(-w + 0.01, 0.200, z), Vector3(px, py, z)]), 0.0055, 6, CB.M_DARK, C_STEEL, false,
				false)


## The cockpit: the leather seat against the seat back, the wood-rimmed steering wheel on its column,
## the dash's gauges, the gear lever and the handbrake outboard on the right.
func _cockpit(b) -> void:
	var floor_y := 0.190
	var z1: float = COCKPIT_Z.y
	b.rbox(Transform3D(Basis(), Vector3(0.0, floor_y + 0.040, z1 - 0.115)), Vector3(0.118, 0.032, 0.090), 0.022, 2,
			CB.M_DARK, C_LEATHER)
	var rake := Basis(Vector3.RIGHT, 0.22)
	b.rbox(Transform3D(rake, Vector3(0.0, floor_y + 0.150, z1 - 0.030)), Vector3(0.120, 0.105, 0.028), 0.024, 2,
			CB.M_DARK, C_LEATHER)
	for k in 4:
		bar(b, Vector3(-0.075 + 0.05 * k, floor_y + 0.150, z1 - 0.059 + 0.0), Vector3(0.0016, 0.085, 0.003), CB.M_DARK,
				Color(0.20, 0.09, 0.03))
	# Steering wheel: a wood rim on four chrome spokes, tilted back, on a column into the dash.
	var c := Vector3(0.0, 0.405, -0.070)
	var tilt := Basis(Vector3.RIGHT, -0.38)
	var rim := PackedVector3Array()
	for k in 33:
		var a: float = TAU * k / 32.0
		rim.append(c + tilt * Vector3(cos(a) * 0.085, sin(a) * 0.085, 0.0))
	b.tube(rim, 0.0085, 8, CB.M_DARK, C_WOOD, false, false)
	for k in 4:
		var a: float = TAU * k / 4.0 + PI * 0.25
		b.tube(PackedVector3Array([c, c + tilt * Vector3(cos(a) * 0.080, sin(a) * 0.080, 0.0)]), 0.0035, 6, CB.M_CHROME,
				C_CHROME, false, false)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, tilt * Vector3.BACK, PackedVector2Array([Vector2(-0.010, 0.016), Vector2(0.004, 0.016), Vector2(0.008, 0.0)]), 12,
			CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, c + tilt * Vector3.FORWARD * 0.02)
	b.tube(PackedVector3Array([c, c + tilt * Vector3(0.0, 0.0, -0.10)]), 0.010, 8, CB.M_DARK, C_DARK, false, true)
	# Gauges on the dash face (the cockpit's front wall).
	var dz: float = COCKPIT_Z.x + 0.003
	for g in [[-0.090, 0.330, 0.024], [0.0, 0.312, 0.030], [0.090, 0.330, 0.024]]:
		var gc := Vector3(g[0], g[1], dz)
		var r: float = g[2]
		b.disc(gc, Vector3.BACK, r, 0.0, 18, CB.M_DARK, C_GAUGE)
		vb = b.vertex_count()
		ib = b.index_count()
		b.lathe(gc, Vector3.BACK, PackedVector2Array([Vector2(-0.002, r + 0.005), Vector2(0.004, r + 0.004),
				Vector2(0.005, r)]), 18, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, gc + Vector3.FORWARD * 0.01)
	# Gear lever and the handbrake on the right.
	b.tube(PackedVector3Array([Vector3(0.090, floor_y, 0.020), Vector3(0.105, 0.330, -0.010)]), 0.0045, 6, CB.M_CHROME,
			C_CHROME, false, false)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(0.105, 0.336, -0.012), Vector3.UP, PackedVector2Array([Vector2(-0.012, 0.0), Vector2(-0.008, 0.011),
			Vector2(0.004, 0.012), Vector2(0.012, 0.0)]), 12, CB.M_DARK, C_WOOD)
	b.orient_away_from(vb, ib, Vector3(0.105, 0.336, -0.012))
	var hx: float = prof["w"].at(0.05) + 0.012
	b.tube(PackedVector3Array([Vector3(hx - 0.010, 0.230, 0.090), Vector3(hx, 0.390, 0.020)]), 0.0055, 6, CB.M_CHROME,
			C_CHROME, false, true)


## The aero screen's chrome frame: along its top and down its sides.
func _screen_frame(b) -> void:
	var top := PackedVector3Array()
	for k in 17:
		var x: float = lerpf(-SCREEN_HALF, SCREEN_HALF, k / 16.0)
		top.append(_screen_pt(x, 1.0) + Vector3(0.0, 0.003, 0.0))
	b.tube(top, 0.0042, 6, CB.M_CHROME, C_CHROME, true, true)
	for sx in [-1.0, 1.0]:
		var side := PackedVector3Array()
		for k in 5:
			side.append(_screen_pt(SCREEN_HALF * sx, k / 4.0) + Vector3(0.002 * sx, 0.0, 0.0))
		b.tube(side, 0.0040, 6, CB.M_CHROME, C_CHROME, true, true)


const SCREEN_HALF := 0.112
const SCREEN_H := 0.068


## A point on the aero screen: across at x, up at t (0 its foot on the scuttle, 1 its top edge). It
## curves back at its ends and leans back a little.
func _screen_pt(x: float, t: float) -> Vector3:
	var z: float = SCREEN_Z + 0.028 * pow(x / SCREEN_HALF, 2.0)
	var foot: float = top_y(x, z) - 0.002
	var y: float = foot + (SCREEN_H + 0.010 * (1.0 - pow(x / SCREEN_HALF, 2.0))) * t
	return Vector3(x, y, z + 0.020 * t)


## The aero screen's glass, both faces (car_glass culls back faces).
func build_glass(b) -> void:
	for face_dir in [Vector3.FORWARD, Vector3.BACK]:
		var rows := []
		for i in 17:
			var x: float = lerpf(-SCREEN_HALF, SCREEN_HALF, i / 16.0)
			var row := PackedVector3Array()
			for j in 5:
				row.append(_screen_pt(x, j / 4.0) + (face_dir as Vector3) * 0.0006)
			rows.append(row)
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.grid(rows, CB.M_DARK, GLASS_TINT, false, false)
		b.orient_toward(vb, ib, face_dir)


## The front beam axle, dropped in the middle under the nose, and the drag link.
func _front_axle(b) -> void:
	var z := AXLE_F
	b.tube(_rounded([Vector3(-0.360, 0.212, z), Vector3(-0.270, 0.205, z), Vector3(-0.180, 0.132, z), Vector3(0.180, 0.132, z),
			Vector3(0.270, 0.205, z), Vector3(0.360, 0.212, z)], 0.05, 5), 0.0145, 10, CB.M_CHROME, C_CHROME, true, true)
	b.tube(PackedVector3Array([Vector3(-0.355, 0.225, z + 0.070), Vector3(-0.150, 0.190, z + 0.240)]), 0.0075, 8,
			CB.M_CHROME, C_CHROME, true, true)
	b.tube(PackedVector3Array([Vector3(-0.350, 0.140, z + 0.060), Vector3(0.350, 0.140, z + 0.060)]), 0.0060, 8,
			CB.M_CHROME, C_CHROME, true, true)


## The live rear axle: its tubes (into the body), the springs' ends under it.
func _rear_axle(b) -> void:
	b.tube(PackedVector3Array([Vector3(-0.385, HUB_Y, AXLE_R), Vector3(0.385, HUB_Y, AXLE_R)]), 0.024, 12, CB.M_DARK, C_DARK,
			true, true)
	for sx in [-1.0, 1.0]:
		for k in 2:
			var half: float = 0.200 - 0.050 * k
			var leaf := PackedVector3Array()
			for s in 11:
				var dz: float = lerpf(-half, half, float(s) / 10.0)
				leaf.append(Vector3(0.150 * sx, 0.170 + 0.030 * pow(dz / 0.2, 2.0) - 0.008 * k, AXLE_R + dz))
			b.oval_tube(leaf, 0.016, 0.004, Vector3.UP, 8, CB.M_DARK, C_STEEL, true)


# ============================================================================================
#  Wheels
# ============================================================================================

## A wire wheel: the tall ribbed tyre on a well-base rim, forty spokes laced from the hub's two
## flanges, a two-eared knock-off spinner, the finned drum behind.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 48, C_RUBBER)
	# Three ribs round the tread: shallow dark grooves.
	for gx in [-0.020, 0.0, 0.020]:
		var vb0: int = b.vertex_count()
		var ib0: int = b.index_count()
		b.lathe(Vector3.ZERO, Vector3.RIGHT, PackedVector2Array([Vector2(gx - 0.003, 0.2152), Vector2(gx, 0.2135),
				Vector2(gx + 0.003, 0.2152)]), 48, CB.M_RUBBER, Color(0.07, 0.07, 0.075))
		b.orient_away_from(vb0, ib0, Vector3.ZERO)
	var hw: float = -float(TYRE_HALF[0][0])
	# The rim: lips over both beads, the well's inside facing the axle.
	wheel_lathe(b, PackedVector2Array([Vector2(hw - 0.008, RIM_R + 0.002), Vector2(hw + 0.001, RIM_R + 0.006),
			Vector2(hw + 0.004, RIM_R + 0.002), Vector2(hw + 0.003, RIM_R - 0.004)]), 48, CB.M_RIM, C_RIM, "out",
			Vector3(hw - 0.03, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(hw + 0.003, RIM_R - 0.004), Vector2(hw - 0.006, RIM_R - 0.006),
			Vector2(0.016, RIM_R - 0.008), Vector2(0.010, RIM_R - 0.016), Vector2(-0.010, RIM_R - 0.016),
			Vector2(-0.016, RIM_R - 0.008), Vector2(-hw + 0.006, RIM_R - 0.006), Vector2(-hw - 0.003, RIM_R - 0.004)]), 48,
			CB.M_RIM, Color(0.85, 0.85, 0.86), "in")
	# Hub barrel and its two flanges.
	wheel_lathe(b, PackedVector2Array([Vector2(-0.046, 0.0), Vector2(-0.046, 0.030), Vector2(-0.040, 0.040),
			Vector2(-0.032, 0.040), Vector2(-0.028, 0.030), Vector2(0.030, 0.026), Vector2(0.036, 0.034),
			Vector2(0.044, 0.034), Vector2(0.048, 0.024), Vector2(0.064, 0.020), Vector2(0.066, 0.0)]), 20, CB.M_CHROME,
			C_CHROME, "out", Vector3(0.0, 0.0, 0.0))
	# Spokes: half from each flange, laced tangentially (crossing), to the rim's well.
	for k in SPOKES:
		var outer: bool = k % 2 == 0
		var a: float = TAU * k / SPOKES
		var lead: float = 0.32 if (k / 2) % 2 == 0 else -0.32
		var fh: Array = wheel_frame(a)
		var fr: Array = wheel_frame(a + lead)
		var hub_pt: Vector3 = Vector3(0.040 if outer else -0.034, 0.0, 0.0) + (fh[0] as Vector3) * (0.034 if outer else 0.037)
		var rim_pt: Vector3 = Vector3(0.006 if outer else -0.006, 0.0, 0.0) + (fr[0] as Vector3) * (RIM_R - 0.017)
		b.tube(PackedVector3Array([hub_pt, rim_pt]), 0.0019, 4, CB.M_CHROME, C_CHROME, false, false)
	# The knock-off spinner: a chrome nut with two ears.
	var nx := 0.066
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(nx, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.026), Vector2(0.010, 0.024),
			Vector2(0.016, 0.016), Vector2(0.018, 0.0)]), 8, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(nx - 0.01, 0.0, 0.0))
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(), Vector3(nx + 0.008, 0.040 * s, 0.0)), Vector3(0.006, 0.024, 0.006), 0.004, 1,
				CB.M_CHROME, C_CHROME)
	# The finned drum inboard, seen through the spokes.
	var dx := -0.056
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(dx, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(-0.024, 0.0), Vector2(-0.024, 0.112),
			Vector2(0.010, 0.112), Vector2(0.014, 0.090), Vector2(0.014, 0.0)]), 32, CB.M_ALLOY, C_ALLOY_DARK)
	b.orient_away_from(vb, ib, Vector3(dx, 0.0, 0.0))
	for k in 16:
		var f: Array = wheel_frame(TAU * k / 16.0)
		b.rbox(Transform3D(Basis(Vector3.RIGHT, f[0], f[1]), Vector3(dx - 0.006, 0.0, 0.0) + (f[0] as Vector3) * 0.118),
				Vector3(0.015, 0.008, 0.0025), 0.0015, 1, CB.M_ALLOY, C_ALLOY_DARK)
	if side < 0.0:
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var z: float = p.z
	var w: float = prof["w"].at(z)
	var st: Vector2 = _shoulder_top(z)
	# The cockpit: black inside the rim, the rim beaded in chrome.
	if z > COCKPIT_Z.x - 0.012 and z < COCKPIT_Z.y + 0.012:
		if p.y < st.y - 0.004 and p.x < st.x + 0.002 and n.x < 0.6:
			black = 1.0
		chrome = maxf(chrome, _cover(absf(p.y - st.y) - 0.004, fp) * float(p.x < st.x + 0.012 and p.x > st.x - 0.020))
	# The dash's and the seat back's faces.
	if (n.z > 0.5 and z < COCKPIT_Z.x + 0.03 and z > COCKPIT_Z.x - 0.03) or (n.z < -0.5 and absf(z - COCKPIT_Z.y) < 0.03):
		if p.y < st.y - 0.002:
			black = 1.0
	var on_side: bool = n.x > 0.55
	if on_side and z > -1.10 and z < -0.30:
		# Louvres along the bonnet's sides: rows of narrow vertical slots, clear of the straps.
		var clear := true
		for sz in STRAPS:
			if absf(z - sz) < 0.040:
				clear = false
		if clear and p.y > 0.205 and p.y < 0.268:
			var lz: float = fposmod(z + 1.10, 0.026) - 0.013
			var d: float = maxf(absf(lz) - 0.0035, absf(p.y - 0.2365) - 0.026)
			black = maxf(black, 0.9 * _cover(d, fp))
	# The bonnet's split along its top (its hinge) and where it meets the scuttle.
	if z > -1.13 and z < -0.24 and n.y > 0.6:
		gap = maxf(gap, _cover(absf(p.x) - 0.0016, fp))
	if absf(z + 0.240) < 0.01:
		gap = maxf(gap, _cover(absf(z + 0.240) - 0.0016, fp) * float(n.y > -0.3))
	if on_side and z > -1.13 and z < -0.24:
		gap = maxf(gap, 0.8 * _cover(absf(p.y - prof["belt"].at(z) + 0.006) - 0.0014, fp))
	# The tail's panel where it bolts to the body behind the cockpit.
	if absf(z - 0.300) < 0.01 and n.y > -0.3:
		gap = maxf(gap, 0.7 * _cover(absf(z - 0.300) - 0.0014, fp))
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(0.0, gap, chrome, black)
