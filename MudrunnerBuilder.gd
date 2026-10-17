# MudrunnerBuilder.gd
#
# The Mudrunner: a Baja Bug body on a monster-truck RC chassis, rebuilt in code from the Hunyuan
# model it replaced (~590k triangles, now removed) at about 34k. The proportions were measured off
# that mesh: the wheels sit exactly where they did, so PlayerCart plants the car at the same height
# and its wheel pivots, drift and boost particles land in the same places.
#
# The shell, fenders, wheel parts and detail map come from CarDesign.gd; this file is the shape
# (profile knots, wheel-arch lips) and the parts that are the Mudrunner's own. The detail map
# draws the windows, their seals, the door and panel gaps and the trim.
extends "res://CarDesign.gd"

# Wheels: the Hunyuan model's positions.
const WHEEL_X := 0.603
const AXLE_F := -0.654
const AXLE_R := 0.717
const HUB_Y := 0.252

# Section parameters along the car, (z, value) knots. Measured off the Hunyuan mesh.
const TOP_KNOTS := [[-0.82, 0.585], [-0.76, 0.602], [-0.72, 0.628], [-0.672, 0.650], [-0.626, 0.670],
	[-0.571, 0.690], [-0.50, 0.704], [-0.40, 0.712], [-0.30, 0.718], [-0.235, 0.725], [-0.20, 0.758],
	[-0.16, 0.826], [-0.12, 0.884], [-0.08, 0.914], [-0.02, 0.928], [0.10, 0.932], [0.30, 0.930],
	[0.40, 0.922], [0.50, 0.900], [0.58, 0.872], [0.66, 0.832], [0.705, 0.795], [0.741, 0.756],
	[0.777, 0.716], [0.818, 0.670], [0.851, 0.630], [0.878, 0.590], [0.898, 0.552], [0.913, 0.515],
	[0.925, 0.480], [0.944, 0.450]]
const BOT_KNOTS := [[-0.82, 0.335], [-0.74, 0.322], [-0.66, 0.307], [-0.55, 0.300], [0.45, 0.300],
	[0.55, 0.310], [0.70, 0.328], [0.85, 0.343], [0.944, 0.350]]
const W_KNOTS := [[-0.82, 0.205], [-0.74, 0.218], [-0.66, 0.236], [-0.58, 0.260], [-0.50, 0.284],
	[-0.42, 0.306], [-0.34, 0.330], [-0.26, 0.352], [-0.18, 0.366], [-0.10, 0.375], [0.00, 0.380],
	[0.36, 0.380], [0.45, 0.374], [0.55, 0.360], [0.65, 0.336], [0.75, 0.302], [0.82, 0.268],
	[0.88, 0.230], [0.944, 0.190]]
const BELT_KNOTS := [[-0.82, 0.560], [-0.70, 0.598], [-0.55, 0.622], [-0.40, 0.634], [-0.28, 0.645],
	[-0.20, 0.658], [-0.12, 0.665], [0.40, 0.665], [0.50, 0.656], [0.60, 0.640], [0.75, 0.600],
	[0.85, 0.552], [0.944, 0.480]]
# The cubic over the top (CarDesign._upper): tumble pulls the glass inward, kb flattens the roof.
const TUMBLE_KNOTS := [[-0.82, 0.0], [-0.30, 0.010], [-0.22, 0.050], [-0.14, 0.075], [0.45, 0.075],
	[0.60, 0.050], [0.80, 0.020], [0.944, 0.0]]
const KA_KNOTS := [[-0.82, 0.50], [-0.30, 0.55], [-0.18, 0.80], [0.45, 0.85], [0.65, 0.65], [0.944, 0.50]]
const KB_KNOTS := [[-0.82, 0.55], [-0.30, 0.60], [-0.15, 0.55], [0.45, 0.55], [0.944, 0.50]]

# Fenders: the wheel-arch lip in side view (z, y), listed from the end at the doors round to the
# outer end. The fender is a shelf `depth` thick standing on the lip, out to x_out. Baja-cut: the
# front fenders stop short of the tyres' fronts, the rear ones above the axle line.
const FRONT_LIP := [[-0.318, 0.305], [-0.340, 0.385], [-0.378, 0.462], [-0.425, 0.522], [-0.480, 0.556],
	[-0.550, 0.572], [-0.620, 0.570], [-0.668, 0.557], [-0.700, 0.538], [-0.722, 0.518]]
const REAR_LIP := [[0.392, 0.300], [0.418, 0.380], [0.452, 0.448], [0.500, 0.505], [0.560, 0.545],
	[0.630, 0.566], [0.700, 0.566], [0.760, 0.540], [0.805, 0.500], [0.835, 0.455]]
const FRONT_FENDER_OUT := 0.44
const REAR_FENDER_OUT := 0.45
const FRONT_FENDER_DEPTH := 0.052
const REAR_FENDER_DEPTH := 0.050

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.25, 0.25, 0.25)
const C_DARK := Color(0.07, 0.07, 0.075)
const C_DARKER := Color(0.035, 0.035, 0.04)
const C_ALLOY := Color(0.78, 0.79, 0.80)
const C_ALLOY_DARK := Color(0.55, 0.56, 0.58)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.56)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -0.82, "tail_z": 0.95, "belt_y": 0.665, "side_x": 0.38,
	"door_z": 0.0, "door_y": 0.49, "roundel_r": 0.105,
	"hood_z": -0.50, "hood_r": 0.095, "stripe_w": 0.07, "stripe_gap": 0.028,
}
const ANTENNA_POS := Vector3(-0.10, 0.905, -0.10)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -0.814
	nose_cap = 0.05
	nose_cap_y = 0.475
	nose_cap_exp = Vector2(4.0, 2.0)
	tail_tip = 0.944
	tail_cap = 0.035
	tail_cap_y = 0.405
	tail_cap_exp = Vector2(3.0, 2.0)
	half_ring = 28
	setup_shell({"top": TOP_KNOTS, "bot": BOT_KNOTS, "w": W_KNOTS, "belt": BELT_KNOTS,
		"tumble": TUMBLE_KNOTS, "ka": KA_KNOTS, "kb": KB_KNOTS})


## Body mesh: shell, fenders (both sides), lamps, mirrors, bumpers, chassis and suspension.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	build_fender(b, FRONT_LIP, AXLE_F, HUB_Y, FRONT_FENDER_OUT, FRONT_FENDER_DEPTH, 0.045)
	_taillamp(b, build_fender(b, REAR_LIP, AXLE_R, HUB_Y, REAR_FENDER_OUT, REAR_FENDER_DEPTH, 0.06))
	b.mirror_x(v0, i0)
	build_details(b)


## A Beetle-style taillamp on the back slope of a rear fender: an oval red lens, half sunk.
func _taillamp(b, mark: Array) -> void:
	if mark.is_empty():
		return
	var p: Vector3 = mark[0]
	var up: Vector3 = (mark[1] as Vector3).normalized()
	var along: Vector3 = (mark[2] as Vector3).normalized()
	var across: Vector3 = up.cross(along).normalized()
	along = across.cross(up).normalized()
	b.rbox(Transform3D(Basis(across, up, along), p - up * 0.002), Vector3(0.020, 0.008, 0.034), 0.0075, 2,
			CB.M_TAILLAMP, C_TAILLAMP)


func build_details(b) -> void:
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	# --- Right-hand parts, mirrored to the left afterwards ---
	# Headlamp on the nose: chrome bezel sunk into the panel, domed lens.
	var hx := 0.138
	var hy := 0.540
	var lamp_c := Vector3(hx, hy, shell_z(hx, hy, true))
	var fwd: Vector3 = Vector3(0.12, 0.22, -1.0).normalized()
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(lamp_c, fwd, PackedVector2Array([Vector2(-0.03, 0.060), Vector2(0.010, 0.060),
			Vector2(0.016, 0.057), Vector2(0.017, 0.052)]), 24, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, lamp_c - fwd * 0.05)
	lens(b, lamp_c + fwd * 0.012, fwd, 0.0525, 0.014, 24)
	# Mirror on a short stalk at the base of the A-pillar.
	b.tube(PackedVector3Array([Vector3(0.355, 0.655, -0.212), Vector3(0.398, 0.688, -0.214)]), 0.0065, 6,
			CB.M_CHROME, C_CHROME, false, true)
	b.rbox(Transform3D(Basis(Vector3.UP, 0.12), Vector3(0.432, 0.705, -0.212)), Vector3(0.042, 0.031, 0.010),
			0.009, 2, CB.M_CHROME, C_CHROME)
	# Nerf bar under the doors.
	b.rbox(Transform3D(Basis(), Vector3(0.272, 0.245, 0.075)), Vector3(0.068, 0.050, 0.308), 0.022, 3,
			CB.M_ALLOY, C_ALLOY_DARK)
	_suspension(b, AXLE_F, 1.0)
	_suspension(b, AXLE_R, -1.0)
	b.mirror_x(v0, i0)
	# --- Centre parts ---
	# Front bumper: an aluminium plate; skid plate below it, mounts back to the chassis.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.287, -0.885)), Vector3(0.348, 0.047, 0.029), 0.014, 3,
			CB.M_ALLOY, C_ALLOY_DARK)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(0.0, 0.205, -0.80)), Vector3(0.20, 0.011, 0.085),
			0.008, 2, CB.M_ALLOY, C_ALLOY_DARK)
	for sx in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(0.11 * sx, 0.27, -0.86), Vector3(0.10 * sx, 0.225, -0.70)]), 0.012, 6,
				CB.M_DARK, C_DARK)
		b.tube(PackedVector3Array([Vector3(0.15 * sx, 0.31, 0.93), Vector3(0.12 * sx, 0.24, 0.80)]), 0.012, 6,
				CB.M_DARK, C_DARK)
	# Rear bumper: an oval aluminium bar.
	b.oval_tube(PackedVector3Array([Vector3(-0.32, 0.315, 0.950), Vector3(0.32, 0.315, 0.950)]), 0.028, 0.050,
			Vector3.UP, 16, CB.M_ALLOY, C_ALLOY)
	# Chassis plate, centre driveshaft, diffs.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.205, 0.03)), Vector3(0.13, 0.012, 0.74), 0.008, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(0.0, 0.232, AXLE_F + 0.07), Vector3(0.0, 0.240, AXLE_R - 0.09)]), 0.011, 8,
			CB.M_ALLOY, C_ALLOY_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.228, AXLE_F + 0.01)), Vector3(0.075, 0.048, 0.058), 0.018, 2,
			CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.245, AXLE_R - 0.02)), Vector3(0.092, 0.062, 0.072), 0.02, 2,
			CB.M_ANODISED, Color(1, 1, 1))


## One corner's suspension (right side): double wishbones to the knuckle, a coil-over shock into
## the wheel well, the driveshaft out of the diff. `fz` turns the shock to lean toward the
## middle of the car.
func _suspension(b, axle_z: float, fz: float) -> void:
	var kx := 0.505
	# Lower and upper wishbones: two arms each from the chassis to the knuckle.
	for dz in [-0.065, 0.065]:
		b.tube(PackedVector3Array([Vector3(0.12, 0.200, axle_z + dz), Vector3(kx - 0.01, 0.172, axle_z)]), 0.011, 6,
				CB.M_DARK, C_DARK, true, true)
		b.tube(PackedVector3Array([Vector3(0.16, 0.335, axle_z + dz * 0.6), Vector3(kx - 0.015, 0.318, axle_z)]), 0.0085, 6,
				CB.M_DARK, C_DARK, true, true)
	# Knuckle and stub axle.
	b.rbox(Transform3D(Basis(), Vector3(kx, 0.245, axle_z)), Vector3(0.013, 0.088, 0.024), 0.008, 1, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, axle_z), Vector3(0.56, HUB_Y, axle_z)]), 0.013, 8,
			CB.M_ALLOY, C_ALLOY_DARK, false, true)
	# Driveshaft from the diff.
	b.tube(PackedVector3Array([Vector3(0.085, 0.236, axle_z), Vector3(kx - 0.012, HUB_Y, axle_z)]), 0.0095, 6,
			CB.M_ALLOY, C_ALLOY_DARK, false, false)
	# Coil-over: from the lower wishbone up into the wheel well, leaning in.
	coilover(b, Vector3(0.36, 0.188, axle_z + 0.035 * fz), Vector3(0.300, 0.505, axle_z + 0.010 * fz), 0.0175, 0.028,
			6.5, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## a studded tyre round a turbine-spoked rim.
func build_wheel(b, side: float) -> void:
	tyre(b, [[-0.098, 0.166], [-0.112, 0.178], [-0.1195, 0.194], [-0.121, 0.211], [-0.117, 0.227],
		[-0.106, 0.238], [-0.086, 0.2445], [-0.050, 0.2465], [-0.016, 0.247]], 40, C_RUBBER)
	# Tread: two staggered rows of paddle lugs tilted into chevrons, studs along both shoulders.
	var lugs := 20
	for k in lugs:
		for row in 2:
			var f: Array = wheel_frame(TAU * (k + 0.5 * row) / lugs)
			var r: Vector3 = f[0]
			var t: Vector3 = f[1]
			var tilt: float = 0.30 if row == 0 else -0.30
			var across: Vector3 = (Vector3.RIGHT + t * tilt).normalized()
			block(b, r * 0.2455 + Vector3(-0.052 if row == 0 else 0.052, 0.0, 0.0), across, t, r, 0.026, 0.010,
					0.016, 0.85, CB.M_RUBBER, C_RUBBER)
		for row in 2:
			var f: Array = wheel_frame(TAU * (k + 0.25 + 0.5 * row) / lugs)
			var r: Vector3 = f[0]
			var sx: float = -1.0 if row == 0 else 1.0
			spike(b, r * 0.236 + Vector3(0.107 * sx, 0.0, 0.0), (r * 0.8 + Vector3(0.6 * sx, 0.0, 0.0)).normalized(),
					f[1], 0.018, 0.0085, CB.M_RUBBER, C_RUBBER)
	# Rim: outer lip, dished face down to the spokes, barrel inside the tyre.
	wheel_lathe(b, PackedVector2Array([Vector2(0.086, 0.168), Vector2(0.099, 0.171), Vector2(0.107, 0.166),
			Vector2(0.106, 0.156), Vector2(0.097, 0.151)]), 40, CB.M_RIM, C_RIM, "out", Vector3(0.05, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.097, 0.151), Vector2(0.084, 0.146), Vector2(0.070, 0.136)]), 40,
			CB.M_RIM, C_RIM_BARREL, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.070, 0.136), Vector2(0.060, 0.150), Vector2(-0.090, 0.160),
			Vector2(-0.098, 0.168)]), 40, CB.M_RIM, C_RIM_BARREL, "in")
	# Back wall behind the spokes, so the wheel reads solid.
	b.disc(Vector3(0.045, 0.0, 0.0), Vector3.RIGHT, 0.152, 0.03, 32, CB.M_DARK, C_DARKER)
	# Hub and cap.
	wheel_lathe(b, PackedVector2Array([Vector2(0.040, 0.046), Vector2(0.078, 0.046), Vector2(0.083, 0.041)]), 20,
			CB.M_RIM, C_RIM, "out", Vector3(0.06, 0.0, 0.0))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.083, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.041), Vector2(0.004, 0.036),
			Vector2(0.009, 0.024), Vector2(0.012, 0.0)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.06, 0.0, 0.0))
	# Eight turbine spokes, twisted a little toward the rim.
	for k in 8:
		spoke(b, TAU * k / 8.0, 0.16, 0.044, 0.146, 0.074, 0.066, 0.014, 0.026, 0.011, CB.M_RIM, C_RIM)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Side windows in side view (z, y). Front: door glass and vent window, its front edge leaning
	# back along the A-pillar.
	shapes["side_front"] = _inset(PackedVector2Array([Vector2(0.188, 0.676), Vector2(0.188, 0.836),
			Vector2(-0.078, 0.836), Vector2(-0.168, 0.690), Vector2(-0.168, 0.676)]), 0.016)
	# Rear quarter window: straight front, rounded back.
	var rq := PackedVector2Array([Vector2(0.256, 0.676), Vector2(0.256, 0.836), Vector2(0.415, 0.836)])
	for k in range(1, 12):
		var a: float = PI * 0.5 * k / 12.0
		rq.append(Vector2(0.415 + 0.108 * sin(a), 0.700 + 0.136 * cos(a)))
	rq.append(Vector2(0.523, 0.676))
	shapes["side_rear"] = _inset(rq, 0.012)
	# Windscreen in front view (x, y), wider at the bottom.
	shapes["windscreen"] = _inset(PackedVector2Array([Vector2(-0.287, 0.703), Vector2(0.287, 0.703),
			Vector2(0.252, 0.868), Vector2(-0.252, 0.868)]), 0.036)
	# Rear window in back view (x, y).
	shapes["rear"] = _inset(PackedVector2Array([Vector2(-0.200, 0.686), Vector2(0.200, 0.686),
			Vector2(0.200, 0.790), Vector2(-0.200, 0.790)]), 0.046)
	# Panel outlines.
	shapes["door"] = PackedVector2Array([Vector2(-0.258, 0.300), Vector2(0.222, 0.300), Vector2(0.222, 0.851),
			Vector2(-0.072, 0.851), Vector2(-0.186, 0.672), Vector2(-0.258, 0.652)])
	shapes["hood"] = _inset(PackedVector2Array([Vector2(-0.300, -0.282), Vector2(0.300, -0.282),
			Vector2(0.185, -0.768), Vector2(-0.185, -0.768)]), 0.07)
	shapes["sunroof"] = _inset(PackedVector2Array([Vector2(-0.190, -0.040), Vector2(0.190, -0.040),
			Vector2(0.190, 0.180), Vector2(-0.190, 0.180)]), 0.04)
	shapes["lid"] = _inset(PackedVector2Array([Vector2(-0.150, 0.420), Vector2(0.150, 0.420),
			Vector2(0.165, 0.630), Vector2(-0.165, 0.630)]), 0.05)
	shapes["plate"] = _inset(PackedVector2Array([Vector2(-0.090, 0.382), Vector2(0.090, 0.382),
			Vector2(0.090, 0.468), Vector2(-0.090, 0.468)]), 0.01)
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var side: bool = n.x > 0.35
	var szy := Vector2(p.z, p.y)
	var sxy := Vector2(p.x, p.y)
	var sxz := Vector2(p.x, p.z)
	# Windows and their black seals (8mm round the glass).
	if side and p.y > 0.64 and p.z > -0.25 and p.z < 0.56:
		for key in ["side_front", "side_rear"]:
			var d: float = _sd_rounded(szy, sh[key])
			glass = maxf(glass, _cover(d, fp))
			black = maxf(black, _cover(d - 0.008, fp))
		# Vent window divider: a chrome bar.
		if p.z > -0.095 and p.z < -0.055 and p.y < 0.84:
			chrome = maxf(chrome, _cover(absf(p.z + 0.076) - 0.0045, fp))
	if n.z < -0.25 and p.z > -0.27 and p.z < -0.05:
		var d: float = _sd_rounded(sxy, sh["windscreen"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.009, fp))
	if n.z > 0.2 and p.z > 0.45 and p.y > 0.64:
		var d: float = _sd_rounded(sxy, sh["rear"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.008, fp))
	# Door gaps and handle, the beltline crease.
	if side:
		if p.z > -0.30 and p.z < 0.26 and p.y > 0.315:
			gap = maxf(gap, _cover(absf(_sd_poly(szy, sh["door"])) - 0.0022, fp))
		if p.z > 0.11 and p.z < 0.18 and p.y > 0.59 and p.y < 0.63:
			var hd: float = _sd_box(szy - Vector2(0.145, 0.609), Vector2(0.022, 0.0055)) - 0.003
			chrome = maxf(chrome, _cover(hd, fp))
			gap = maxf(gap, 0.6 * _cover(_sd_box(szy - Vector2(0.145, 0.601), Vector2(0.024, 0.004)), fp))
		if p.z > -0.32 and p.z < 0.60:
			gap = maxf(gap, 0.45 * _cover(absf(p.y - 0.643) - 0.0016, fp))
		# Wheel wells: the body's side inside the fender arches is in shadow.
		var fy: float = _lip_y(FRONT_LIP, p.z)
		if fy > 0.0 and p.y < fy + 0.02:
			black = maxf(black, 0.85)
		var ry: float = _lip_y(REAR_LIP, p.z)
		if ry > 0.0 and p.y < ry + 0.02:
			black = maxf(black, 0.85)
	# Hood, sunroof and engine lid outlines; number plate.
	if n.y > 0.35 and p.z < -0.24:
		gap = maxf(gap, _cover(absf(_sd_rounded(sxz, sh["hood"])) - 0.0022, fp))
	if n.y > 0.75 and p.z > -0.10 and p.z < 0.24:
		gap = maxf(gap, 0.8 * _cover(absf(_sd_rounded(sxz, sh["sunroof"])) - 0.002, fp))
	if n.z > 0.35 and p.z > 0.7:
		gap = maxf(gap, _cover(absf(_sd_rounded(sxy, sh["lid"])) - 0.002, fp))
	if n.z < -0.4 and p.z < -0.7:
		gap = maxf(gap, _cover(absf(_sd_rounded(sxy, sh["plate"])) - 0.0025, fp))
	# Underside.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, chrome, black)
