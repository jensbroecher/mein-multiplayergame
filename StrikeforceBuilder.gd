# StrikeforceBuilder.gd
#
# The Strikeforce: a short off-roader with a pickup bed (a Scrambler-style jeep). A black hardtop
# over a painted tub, a bonnet with a cowl-induction dome, wide flat flares in black plastic, a
# winch bumper, a sport bar over the bed with the spare lying in it, a five-lamp light bar on the
# roof; solid axles on coil-overs, wide mud tyres on beadlock rims. Rebuilt in code from its Hunyuan
# model; proportions measured off that mesh, the wheels where its wheels were.
#
# The shell, flares, wheel parts and detail map come from CarDesign.gd. Above the tub's side the
# section runs: a rounded rim, a "wall", a corner, then the top (crowned, with the bonnet's dome).
# Over the cab the wall is the hardtop's side and the corner its roof corner; over the bed the wall
# runs down the bed's inside and the corner is the floor's fillet; on the bonnet and the tailgate
# both lie flat along the top. Every one of these profiles takes its knots from one table (KEYS),
# so they change together: the windscreen, the cab's back and the tailgate's inside are clean
# transitions between regions instead of folds. The arches are cut by lifting the shell's bottom
# over each wheel (BOT_KNOTS), as on the Phantom.
extends "res://CarDesign.gd"

# Wheels: the Hunyuan model's positions.
const WHEEL_X := 0.481
const AXLE_F := -0.718
const AXLE_R := 0.632
const HUB_Y := 0.281

const W_KNOTS := [[-1.07, 0.39], [1.025, 0.39]]
# The bottom of the shell: the sills at 0.40, lifted over each wheel to cut a squared arch.
const BOT_KNOTS := [[-1.07, 0.605], [-0.54, 0.605], [-0.515, 0.598], [-0.49, 0.565], [-0.45, 0.49],
	[-0.425, 0.43], [-0.405, 0.405], [-0.39, 0.40], [0.325, 0.40], [0.34, 0.405], [0.36, 0.43], [0.385, 0.49],
	[0.425, 0.565], [0.45, 0.598], [0.475, 0.605], [0.79, 0.605], [0.815, 0.598], [0.84, 0.565], [0.88, 0.49],
	[0.905, 0.43], [0.925, 0.415], [1.025, 0.415]]

# The section above the tub's side, keyframed along the car. Per row: z; belt (top of the side,
# where the rim's rounding starts); rim_w (the bonnet's edge, the shelf under the hardtop, the bed
# rail); wall_dx (how far the wall leans in); edge (the top beside the crown: bonnet, roof, bed
# floor, tailgate); cx, cy (the corner from the wall onto the top: cy > 0 a roof corner, < 0 the bed
# floor's fillet, 0 flat); crown; the bonnet dome's half-width and height.
const KEYS := [
	# z       belt   rim_w  wall_dx edge   cx     cy      crown  dome_w dome_h
	[-1.070, 0.738, 0.025, 0.030, 0.750, 0.030, 0.000, 0.008, 0.160, 0.000],
	[-0.985, 0.742, 0.025, 0.030, 0.754, 0.030, 0.000, 0.008, 0.165, 0.000],
	[-0.945, 0.744, 0.025, 0.030, 0.756, 0.030, 0.000, 0.008, 0.170, 0.024],
	[-0.465, 0.765, 0.025, 0.030, 0.777, 0.030, 0.000, 0.008, 0.200, 0.026],
	[-0.440, 0.766, 0.025, 0.030, 0.778, 0.030, 0.000, 0.008, 0.200, 0.000],
	[-0.395, 0.766, 0.027, 0.030, 0.784, 0.030, 0.000, 0.008, 0.200, 0.000],
	[-0.370, 0.766, 0.027, 0.030, 0.847, 0.030, 0.008, 0.009, 0.200, 0.000],
	[-0.335, 0.728, 0.028, 0.030, 0.936, 0.030, 0.019, 0.011, 0.200, 0.000],
	[-0.300, 0.728, 0.028, 0.030, 1.025, 0.030, 0.030, 0.012, 0.200, 0.000],
	[-0.280, 0.728, 0.028, 0.030, 1.032, 0.030, 0.030, 0.012, 0.200, 0.000],
	[0.255, 0.728, 0.028, 0.030, 1.032, 0.030, 0.030, 0.012, 0.200, 0.000],
	[0.275, 0.768, 0.040, 0.000, 0.655, 0.012, -0.012, 0.000, 0.200, 0.000],
	[0.955, 0.768, 0.040, 0.000, 0.655, 0.012, -0.012, 0.000, 0.200, 0.000],
	[0.975, 0.768, 0.040, 0.030, 0.780, 0.030, 0.000, 0.000, 0.200, 0.000],
	[1.025, 0.768, 0.040, 0.030, 0.780, 0.030, 0.000, 0.000, 0.200, 0.000],
]
const KEY_NAMES := ["belt", "rim_w", "wall_dx", "edge", "cx", "cy", "crown", "dome_w", "dome_h"]
const RIM_R := 0.012               # the rounding of the tub side's top edge

const FRONT_FLARE_OUT := 0.485
const REAR_FLARE_OUT := 0.49
const FLARE_DEPTH := 0.075

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.24, 0.24, 0.25)
const C_DARK := Color(0.07, 0.07, 0.075)
const C_DARKER := Color(0.035, 0.035, 0.04)
const C_FLARE := Color(0.075, 0.075, 0.08)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.78, 0.79, 0.80)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.6, 0.6, 0.62)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)
const C_REVERSE := Color(0.85, 0.85, 0.82)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.07, "tail_z": 1.025, "belt_y": 0.75, "side_x": 0.39,
	"door_z": -0.05, "door_y": 0.575, "roundel_r": 0.112,
	"hood_z": -0.72, "hood_r": 0.10, "stripe_w": 0.075, "stripe_gap": 0.03,
}
const ANTENNA_POS := Vector3(0.364, 0.782, 0.94)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.070
	nose_cap = 0.018
	nose_cap_y = 0.680
	nose_cap_exp = Vector2(8.0, 8.0)
	tail_tip = 1.025
	tail_cap = 0.018
	tail_cap_y = 0.600
	tail_cap_exp = Vector2(8.0, 8.0)
	# Bottom, bottom corner, side; rim, wall, corner, outer top, dome step, dome top.
	segment_counts = [2, 3, 5, 5, 5, 5, 4, 4, 4]
	half_ring = 37
	bottom_radius = 0.02
	fender_mat = CB.M_DARK
	fender_col = C_FLARE
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[4] + key[7] + key[9]])
	setup_shell(knots)


## Above the side: the rim (the side's top edge rounding over onto a flat rim_w wide), the wall
## (from the rim's inner edge to B), the corner (B onto the top at C), then the top: crowned toward
## the centre line, with the bonnet's dome raised on it by a rounded step at dome_w.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var rim_w: float = prof["rim_w"].at(z)
	var edge: float = prof["edge"].at(z)
	var cx: float = maxf(prof["cx"].at(z), 0.004)
	var cy: float = prof["cy"].at(z)
	var crown: float = maxf(prof["crown"].at(z), 0.0)
	var dome_h: float = maxf(prof["dome_h"].at(z), 0.0)
	var rim := PackedVector2Array()
	for k in 7:
		var a: float = PI * 0.5 * k / 6.0
		rim.append(Vector2(w - RIM_R + RIM_R * cos(a), belt + RIM_R * sin(a)))
	var a_pt := Vector2(w - rim_w, belt + RIM_R)
	rim.append(a_pt)
	var b_pt := Vector2(a_pt.x - prof["wall_dx"].at(z), edge - cy)
	var c_pt := Vector2(b_pt.x - cx, edge)
	var corner := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.5 * k / 8.0
		corner.append(Vector2(b_pt.x + (c_pt.x - b_pt.x) * (1.0 - cos(a)), b_pt.y + (c_pt.y - b_pt.y) * sin(a)))
	var x0: float = c_pt.x
	var dome_w: float = minf(prof["dome_w"].at(z), x0 - 0.06)
	var xr: float = minf(dome_w + 0.035, x0 - 0.02)
	# A cosine bump: level where it leaves the corner (whose arc ends level) and at the centre line.
	var crown_y := func(x: float) -> float: return edge + crown * 0.5 * (1.0 - cos((1.0 - x / x0) * PI))
	var outer := PackedVector2Array()
	var step := PackedVector2Array()
	var dome := PackedVector2Array()
	for k in 9:
		var t: float = k / 8.0
		var xo: float = lerpf(x0, xr, t)
		outer.append(Vector2(xo, crown_y.call(xo)))
		var xd: float = lerpf(xr, dome_w, t)
		step.append(Vector2(xd, crown_y.call(xd) + dome_h * t * t * (3.0 - 2.0 * t)))
		var xc: float = lerpf(dome_w, 0.0, t)
		dome.append(Vector2(xc, crown_y.call(xc) + dome_h))
	return [rim, PackedVector2Array([a_pt, b_pt]), corner, outer, step, dome]


## A Jeep flare: a lip, a flat outer face standing well proud of the body, a top rising a little
## toward the body; underneath, a flat liner from the lip in to the body side.
func _fender_section(xo: float, x_in: float, d: float) -> Array:
	var w: float = x_in + 0.035
	return [
		[Vector2(xo - 0.010, 0.0), Vector2(xo - 0.001, 0.006), Vector2(xo + 0.002, 0.022), Vector2(xo + 0.002, d - 0.014),
			Vector2(xo - 0.002, d - 0.003), Vector2(xo - 0.012, d), Vector2(w + 0.004, d + 0.012), Vector2(x_in, d + 0.012)],
		[Vector2(xo - 0.010, 0.0), Vector2(w + 0.002, 0.0)],
	]


## The outline of a wheel arch as a flare's lip: the shell's bottom (BOT_KNOTS) from the sill at
## the door end round over the wheel to the outer end, as 16 points spaced along it.
func _arch_lip(z_door: float, z_end: float) -> Array:
	var dense := PackedVector2Array()
	for k in 201:
		var z: float = lerpf(z_door, z_end, k / 200.0)
		dense.append(Vector2(z, prof["bot"].at(z)))
	var pts: PackedVector2Array = CB.resample(dense, 16, 0.0)
	var lip := []
	for p in pts:
		lip.append([p.x, p.y])
	return lip


## Bolt heads along a flare's outer face, every 85mm of its lip.
func _flare_bolts(b, lip: Array, hub_z: float, xo: float) -> void:
	var spine: PackedVector2Array = _spine(lip, 60)
	var total := 0.0
	for k in range(1, spine.size()):
		total += spine[k].distance_to(spine[k - 1])
	var acc := 0.0
	var next := 0.035
	for k in range(1, spine.size() - 1):
		acc += spine[k].distance_to(spine[k - 1])
		if acc < next or acc > total - 0.03:
			continue
		next += 0.085
		var t2: Vector2 = (spine[k + 1] - spine[k - 1]).normalized()
		var n2 := Vector2(t2.y, -t2.x)
		if n2.dot(spine[k] - Vector2(hub_z, HUB_Y)) < 0.0:
			n2 = -n2
		var h: float = FLARE_DEPTH * 0.52
		bar(b, Vector3(xo + 0.004, spine[k].y + n2.y * h, spine[k].x + n2.x * h), Vector3(0.003, 0.0045, 0.0045),
				CB.M_ALLOY, C_ALLOY_DARK)


## Body mesh: shell, flares, lamps, grille and bumpers, the bed's sport bar and spare, the light
## bar, chassis and axles.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	var front_lip: Array = _arch_lip(-0.392, -1.068)
	var rear_lip: Array = _arch_lip(0.328, 0.93)
	build_fender(b, front_lip, AXLE_F, HUB_Y, FRONT_FLARE_OUT, FLARE_DEPTH, 0.0)
	build_fender(b, rear_lip, AXLE_R, HUB_Y, REAR_FLARE_OUT, FLARE_DEPTH, 0.0)
	_flare_bolts(b, front_lip, AXLE_F, FRONT_FLARE_OUT)
	_flare_bolts(b, rear_lip, AXLE_R, REAR_FLARE_OUT)
	_side_parts(b)
	b.mirror_x(v0, i0)
	_front_parts(b)
	_rear_parts(b)
	_roof_parts(b)
	_chassis(b)
	_spare(b)
	# One side only: the fuel filler on the right of the bed, the exhaust down the left.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.39, 0.698, 0.872), Vector3.RIGHT, PackedVector2Array([Vector2(-0.004, 0.036), Vector2(0.005, 0.036),
			Vector2(0.008, 0.032), Vector2(0.009, 0.0)]), 20, CB.M_DARK, C_DARK)
	b.orient_away_from(vb, ib, Vector3(0.37, 0.698, 0.872))
	b.tube(PackedVector3Array([Vector3(-0.12, 0.372, -0.30), Vector3(-0.13, 0.372, 0.30), Vector3(-0.14, 0.38, 0.85),
			Vector3(-0.14, 0.385, 1.00)]), 0.016, 8, CB.M_DARK, C_STEEL, true, false)
	b.tube(PackedVector3Array([Vector3(-0.14, 0.385, 0.99), Vector3(-0.14, 0.385, 1.06)]), 0.021, 12, CB.M_CHROME,
			C_CHROME, false, false)
	b.disc(Vector3(-0.14, 0.385, 1.059), Vector3.BACK, 0.017, 0.0, 12, CB.M_DARK, C_DARKER)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inside each arch, so it doesn't look through the car.
	for arch in [[-1.06, -0.43], [0.35, 0.92]]:
		var zc: float = (arch[0] + arch[1]) * 0.5
		var hz: float = (arch[1] - arch[0]) * 0.5
		b.rbox(Transform3D(Basis(), Vector3(0.232, 0.503, zc)), Vector3(0.004, 0.103, hz), 0.003, 1, CB.M_DARK, C_DARKER)
	# Bonnet latches: rubber straps from the wing over the bonnet's edge.
	for z in [-0.93, -0.56]:
		var top: float = prof["belt"].at(z) + RIM_R
		b.rbox(Transform3D(Basis(), Vector3(0.394, top - 0.032, z)), Vector3(0.004, 0.026, 0.011), 0.003, 1,
				CB.M_DARK, C_DARK)
		b.rbox(Transform3D(Basis(), Vector3(0.381, top + 0.003, z)), Vector3(0.014, 0.004, 0.011), 0.003, 1,
				CB.M_DARK, C_DARK)
	# Door: hinges on its front edge, the handle; a mirror on an arm at its top corner.
	for y in [0.485, 0.675]:
		b.rbox(Transform3D(Basis(), Vector3(0.394, y, -0.304)), Vector3(0.006, 0.021, 0.017), 0.004, 1, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.394, 0.668, 0.118)), Vector3(0.005, 0.009, 0.033), 0.004, 1, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(0.384, 0.748, -0.268), Vector3(0.425, 0.790, -0.262)]), 0.007, 6, CB.M_DARK,
			C_DARK, false, true)
	b.rbox(Transform3D(Basis(Vector3.UP, -0.12), Vector3(0.452, 0.808, -0.258)), Vector3(0.040, 0.031, 0.011), 0.009, 2,
			CB.M_DARK, C_DARK)
	# Rock slider under the door, on two outriggers to the frame.
	b.rbox(Transform3D(Basis(), Vector3(0.362, 0.372, -0.035)), Vector3(0.030, 0.026, 0.352), 0.010, 2, CB.M_DARK, C_STEEL)
	for z in [-0.25, 0.18]:
		b.rbox(Transform3D(Basis(), Vector3(0.28, 0.372, z)), Vector3(0.06, 0.012, 0.016), 0.004, 1, CB.M_DARK, C_STEEL)
	# Amber marker on the front of the flare; the taillamp cluster at the top of the tailgate.
	b.rbox(Transform3D(Basis(), Vector3(0.44, 0.638, -1.071)), Vector3(0.026, 0.011, 0.005), 0.004, 1,
			CB.M_TAILLAMP, C_AMBER)
	b.rbox(Transform3D(Basis(), Vector3(0.330, 0.700, tail_tip + 0.008)), Vector3(0.050, 0.052, 0.010), 0.006, 2,
			CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.330, 0.715, tail_tip + 0.019)), Vector3(0.036, 0.026, 0.004), 0.003, 1,
			CB.M_TAILLAMP, C_TAILLAMP)
	b.rbox(Transform3D(Basis(), Vector3(0.330, 0.670, tail_tip + 0.019)), Vector3(0.036, 0.010, 0.004), 0.003, 1,
			CB.M_TAILLAMP, C_REVERSE)
	# Corner guards round the tub's rear corners, under the lamps: they frame the tailgate.
	b.rbox(Transform3D(Basis(), Vector3(0.365, 0.545, tail_tip + 0.004)), Vector3(0.027, 0.104, 0.006), 0.004, 1,
			CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.394, 0.545, 1.0)), Vector3(0.006, 0.104, 0.031), 0.004, 1, CB.M_DARK, C_DARK)
	# Chassis: a frame rail, the links and coil-overs of both axles, the hub at the axle's end.
	b.rbox(Transform3D(Basis(), Vector3(0.20, 0.385, -0.02)), Vector3(0.020, 0.027, 1.05), 0.006, 1, CB.M_DARK, C_STEEL)
	for axle in [[AXLE_F, 1.0], [AXLE_R, -1.0]]:
		var az: float = axle[0]
		var fz: float = axle[1]
		b.tube(PackedVector3Array([Vector3(0.18, 0.24, az), Vector3(0.195, 0.37, az + 0.42 * fz)]), 0.012, 6,
				CB.M_DARK, C_STEEL)
		b.tube(PackedVector3Array([Vector3(0.10, 0.33, az), Vector3(0.16, 0.39, az + 0.32 * fz)]), 0.010, 6,
				CB.M_DARK, C_STEEL)
		b.rbox(Transform3D(Basis(), Vector3(0.365, HUB_Y, az)), Vector3(0.024, 0.055, 0.035), 0.011, 1, CB.M_DARK, C_STEEL)
		b.tube(PackedVector3Array([Vector3(0.365, HUB_Y, az), Vector3(0.43, HUB_Y, az)]), 0.018, 8, CB.M_ALLOY,
				C_ALLOY_DARK, false, true)
		coilover(b, Vector3(0.285, 0.305, az + 0.075 * fz), Vector3(0.268, 0.585, az + 0.045 * fz), 0.018, 0.027, 7.0,
				C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)


## The nose: grille panel with its slots and round headlamps, the winch bumper.
func _front_parts(b) -> void:
	var gz: float = nose_tip - 0.013
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.612, gz + 0.025)), Vector3(0.388, 0.124, 0.025), 0.012, 2, CB.M_DARK,
			C_DARK)
	# Slots between the headlamps: a dark recess behind gunmetal bars.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.620, gz - 0.002)), Vector3(0.172, 0.088, 0.004), 0.004, 1, CB.M_DARK,
			C_DARKER)
	for k in 6:
		bar(b, Vector3(0.0, 0.548 + 0.0288 * k, gz - 0.008), Vector3(0.166, 0.0052, 0.004), CB.M_ALLOY, C_ALLOY_DARK)
	for sx in [-1.0, 1.0]:
		var lamp_c := Vector3(0.255 * sx, 0.616, gz)
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.lathe(lamp_c, Vector3.FORWARD, PackedVector2Array([Vector2(-0.010, 0.056), Vector2(0.009, 0.056),
				Vector2(0.013, 0.053), Vector2(0.014, 0.048), Vector2(0.007, 0.046)]), 28, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, lamp_c + Vector3.BACK * 0.05)
		lens(b, lamp_c + Vector3.FORWARD * 0.005, Vector3.FORWARD, 0.047, 0.012, 28)
		# Turn signal under the lamp.
		b.rbox(Transform3D(Basis(), Vector3(0.255 * sx, 0.530, gz - 0.003)), Vector3(0.030, 0.010, 0.005), 0.004, 1,
				CB.M_TAILLAMP, C_AMBER)
	# Bumper: a steel beam with a stinger hoop, a winch on it, red D-rings, a skid plate under.
	var bz := -1.122
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.452, bz)), Vector3(0.372, 0.046, 0.040), 0.012, 2, CB.M_DARK, C_STEEL)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(Vector3.UP, 0.5 * sx), Vector3(0.392 * sx, 0.452, bz + 0.03)), Vector3(0.03, 0.040, 0.030),
				0.010, 2, CB.M_DARK, C_STEEL)
		b.rbox(Transform3D(Basis(), Vector3(0.20 * sx, 0.42, -1.05)), Vector3(0.02, 0.025, 0.05), 0.005, 1, CB.M_DARK,
				C_STEEL)
		_shackle(b, Vector3(0.27 * sx, 0.432, bz - 0.048), Vector3.FORWARD)
	b.tube(_rounded([Vector3(-0.15, 0.495, bz - 0.012), Vector3(-0.115, 0.588, bz - 0.020), Vector3(0.115, 0.588, bz - 0.020),
			Vector3(0.15, 0.495, bz - 0.012)], 0.05), 0.013, 10, CB.M_DARK, C_STEEL, false, false)
	# Winch: drum between two end housings, the motor on the right, a fairlead and hook in front.
	var wy := 0.530
	var wz := bz + 0.004
	b.tube(PackedVector3Array([Vector3(-0.075, wy, wz), Vector3(0.075, wy, wz)]), 0.030, 16, CB.M_DARK, C_DARKER, false,
			false)
	for x in [-0.088, 0.088]:
		b.rbox(Transform3D(Basis(), Vector3(x, wy, wz)), Vector3(0.014, 0.040, 0.038), 0.008, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(0.102, wy, wz), Vector3(0.175, wy, wz)]), 0.034, 16, CB.M_DARK, C_DARK, false, true)
	b.rbox(Transform3D(Basis(), Vector3(0.0, wy + 0.044, wz + 0.016)), Vector3(0.05, 0.012, 0.022), 0.006, 1, CB.M_DARK,
			C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.462, bz - 0.042)), Vector3(0.062, 0.026, 0.005), 0.005, 1, CB.M_ALLOY,
			C_ALLOY)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.462, bz - 0.047)), Vector3(0.040, 0.0065, 0.002), 0.002, 1, CB.M_DARK,
			C_DARKER)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.452, bz - 0.058)), Vector3(0.012, 0.018, 0.010), 0.005, 1, CB.M_ANODISED,
			Color(1, 1, 1))
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(0.0, 0.36, -1.03)), Vector3(0.24, 0.008, 0.10), 0.006, 1,
			CB.M_DARK, C_STEEL)


## A D-ring shackle (accent colour) on a bumper: its pin across X through an ear at `at`, the bow
## hanging out along `out` and down.
func _shackle(b, at: Vector3, out: Vector3) -> void:
	var dir: Vector3 = (out + Vector3.DOWN * 0.7).normalized()
	var path := PackedVector3Array()
	for k in 13:
		var a: float = PI * k / 12.0
		path.append(at + Vector3(cos(a) * 0.017, 0.0, 0.0) + dir * (sin(a) * 0.034))
	b.tube(path, 0.0055, 8, CB.M_ANODISED, Color(1, 1, 1), true, true)
	b.tube(PackedVector3Array([at + Vector3(-0.024, 0.0, 0.0), at + Vector3(0.024, 0.0, 0.0)]), 0.0065, 8,
			CB.M_ALLOY, C_ALLOY_DARK, true, true)
	b.rbox(Transform3D(Basis(), at - out * 0.008), Vector3(0.005, 0.016, 0.014), 0.003, 1, CB.M_DARK, C_STEEL)


## The tail: the bumper with its step and hitch, the tailgate's handle.
func _rear_parts(b) -> void:
	var bz := 1.062
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.452, bz)), Vector3(0.352, 0.040, 0.034), 0.011, 2, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.494, bz + 0.004)), Vector3(0.11, 0.004, 0.026), 0.003, 1, CB.M_ALLOY,
			C_ALLOY_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.402, bz + 0.012)), Vector3(0.026, 0.026, 0.05), 0.005, 1, CB.M_DARK,
			C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.402, bz + 0.062)), Vector3(0.018, 0.018, 0.002), 0.002, 1, CB.M_DARK,
			C_DARKER)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(), Vector3(0.20 * sx, 0.42, 1.0)), Vector3(0.02, 0.025, 0.05), 0.005, 1, CB.M_DARK,
				C_STEEL)
		_shackle(b, Vector3(0.27 * sx, 0.432, bz + 0.042), Vector3.BACK)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.712, tail_tip + 0.004)), Vector3(0.05, 0.008, 0.006), 0.004, 1, CB.M_DARK,
			C_DARK)


## The roof's light bar and ribs, the sport bar over the bed.
func _roof_parts(b) -> void:
	var lz := -0.165
	var ly := 1.113
	b.rbox(Transform3D(Basis(), Vector3(0.0, 1.068, lz + 0.012)), Vector3(0.296, 0.011, 0.020), 0.006, 1, CB.M_DARK, C_DARK)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(), Vector3(0.284 * sx, 1.049, lz + 0.012)), Vector3(0.012, 0.017, 0.034), 0.004, 1,
				CB.M_DARK, C_DARK)
	for k in 5:
		var c := Vector3((k - 2) * 0.112, ly, lz)
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.lathe(c, Vector3.FORWARD, PackedVector2Array([Vector2(-0.066, 0.0), Vector2(-0.064, 0.030), Vector2(-0.056, 0.046),
				Vector2(-0.040, 0.052), Vector2(-0.004, 0.053), Vector2(0.002, 0.050)]), 20, CB.M_DARK, C_DARK)
		b.orient_away_from(vb, ib, c + Vector3.BACK * 0.03)
		vb = b.vertex_count()
		ib = b.index_count()
		b.lathe(c, Vector3.FORWARD, PackedVector2Array([Vector2(-0.004, 0.0535), Vector2(0.006, 0.0535),
				Vector2(0.009, 0.050), Vector2(0.007, 0.045)]), 20, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, c + Vector3.BACK * 0.02)
		lens(b, c + Vector3.FORWARD * 0.002, Vector3.FORWARD, 0.0455, 0.009, 20)
	# Wipers parked along the foot of the windscreen.
	var wz := -0.377
	for x0 in [-0.255, 0.015]:
		var arm := PackedVector3Array()
		for k in 6:
			var x: float = x0 + 0.225 * k / 5.0
			arm.append(Vector3(x, top_y(x, wz) + 0.004, wz - 0.008))
		b.tube(arm, 0.0045, 6, CB.M_DARK, C_DARK, true, true)
		b.rbox(Transform3D(Basis(), arm[0] + Vector3(0.0, -0.006, 0.004)), Vector3(0.008, 0.008, 0.008), 0.004, 1,
				CB.M_DARK, C_DARK)
	# Hardtop ribs.
	for x in [-0.20, -0.08, 0.08, 0.20]:
		var y: float = top_y(x, 0.06)
		b.rbox(Transform3D(Basis(), Vector3(x, y + 0.002, 0.06)), Vector3(0.008, 0.005, 0.17), 0.004, 1, CB.M_DARK, C_DARK)
	# Sport bar: a hoop behind the cab, rails back from its top to the bed's rear corners, a cross
	# tube over the bed; a third brake lamp on the hoop.
	var hz := 0.325
	b.tube(_rounded([Vector3(-0.362, 0.776, hz), Vector3(-0.338, 1.058, hz), Vector3(0.338, 1.058, hz),
			Vector3(0.362, 0.776, hz)], 0.07), 0.017, 10, CB.M_DARK, C_DARK, false, false)
	for sx in [-1.0, 1.0]:
		b.tube(_rounded([Vector3(0.300 * sx, 1.052, hz + 0.01), Vector3(0.315 * sx, 1.035, 0.53),
				Vector3(0.362 * sx, 0.776, 0.80)], 0.08), 0.015, 10, CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([Vector3(-0.316, 1.030, 0.53), Vector3(0.316, 1.030, 0.53)]), 0.014, 10, CB.M_DARK, C_DARK,
			false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 1.058, hz + 0.022)), Vector3(0.075, 0.012, 0.008), 0.004, 1,
			CB.M_TAILLAMP, C_TAILLAMP)


## Axles, diffs, driveshafts, transfer case.
func _chassis(b) -> void:
	for az in [AXLE_F, AXLE_R]:
		b.tube(PackedVector3Array([Vector3(-0.37, HUB_Y, az), Vector3(0.37, HUB_Y, az)]), 0.026, 10, CB.M_DARK,
				C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(0.06, HUB_Y, az)), Vector3(0.066, 0.062, 0.058), 0.048, 3, CB.M_DARK, C_STEEL)
		var dir: float = 1.0 if az < 0.0 else -1.0
		b.rbox(Transform3D(Basis(), Vector3(0.06, HUB_Y, az - 0.060 * dir)), Vector3(0.048, 0.045, 0.008), 0.022, 2,
				CB.M_ANODISED, Color(1, 1, 1))
		b.tube(PackedVector3Array([Vector3(0.06, HUB_Y + 0.01, az + 0.05 * dir), Vector3(0.02, 0.37, -0.05)]), 0.012, 8,
				CB.M_ALLOY, C_ALLOY_DARK, false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.37, -0.05)), Vector3(0.07, 0.05, 0.13), 0.015, 2, CB.M_DARK, C_STEEL)


## The spare: one of the car's wheels lying in the bed, tilted up toward the cab, under the sport
## bar's cross tube.
func _spare(b) -> void:
	var vb: int = b.vertex_count()
	build_wheel(b, 1.0)
	var turn := Basis(Vector3.RIGHT, 0.14) * Basis(Vector3.BACK, PI * 0.5)
	b.transform_from(vb, Transform3D(turn * 0.88, Vector3(0.0, 0.835, 0.64)))


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## a wide mud tyre round a ten-spoke rim with a machined beadlock ring.
func build_wheel(b, side: float) -> void:
	tyre(b, [[-0.148, 0.188], [-0.158, 0.199], [-0.1645, 0.217], [-0.1655, 0.236], [-0.162, 0.250],
		[-0.152, 0.2585], [-0.128, 0.2635], [-0.075, 0.2655], [-0.025, 0.266]], 44, C_RUBBER)
	# Tread: zig-zag centre blocks, staggered shoulder blocks, lugs down the sidewalls.
	var n := 16
	for k in n:
		for row in 2:
			var f: Array = wheel_frame(TAU * (k + 0.5 * row) / n)
			var r: Vector3 = f[0]
			var t: Vector3 = f[1]
			var sx: float = -1.0 if row == 0 else 1.0
			var across: Vector3 = (Vector3.RIGHT + t * 0.24 * sx).normalized()
			block(b, r * (0.2655 + 0.4 * 0.016) + Vector3(0.040 * sx, 0.0, 0.0), across, t, r, 0.036, 0.016, 0.025, 0.85,
					CB.M_RUBBER, C_RUBBER)
			block(b, r * (0.2615 + 0.4 * 0.0155) + Vector3(-0.113 * sx, 0.0, 0.0), Vector3.RIGHT, t, r, 0.033, 0.0155,
					0.030, 0.85, CB.M_RUBBER, C_RUBBER)
			var up: Vector3 = (r * 0.75 + Vector3(-0.66 * sx, 0.0, 0.0)).normalized()
			block(b, r * 0.244 + Vector3(-0.158 * sx, 0.0, 0.0), up.cross(t).normalized(), t, up, 0.013, 0.017, 0.024,
					0.8, CB.M_RUBBER, C_RUBBER)
	# Rim: the beadlock ring with its bolts, the lip and barrel; hub, spokes.
	wheel_lathe(b, PackedVector2Array([Vector2(0.146, 0.191), Vector2(0.156, 0.193), Vector2(0.162, 0.188),
			Vector2(0.163, 0.166), Vector2(0.157, 0.160)]), 44, CB.M_ALLOY, C_ALLOY, "out", Vector3(0.10, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.157, 0.160), Vector2(0.140, 0.156), Vector2(0.124, 0.146)]), 44,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.124, 0.146), Vector2(0.112, 0.160), Vector2(-0.138, 0.170),
			Vector2(-0.148, 0.188)]), 44, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(0.07, 0.0, 0.0), Vector3.RIGHT, 0.152, 0.03, 32, CB.M_DARK, C_DARKER)
	wheel_lathe(b, PackedVector2Array([Vector2(0.090, 0.052), Vector2(0.126, 0.052), Vector2(0.131, 0.046)]), 20,
			CB.M_RIM, C_RIM, "out", Vector3(0.11, 0.0, 0.0))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.131, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.046), Vector2(0.004, 0.040),
			Vector2(0.009, 0.026), Vector2(0.011, 0.0)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.11, 0.0, 0.0))
	for k in 10:
		spoke(b, TAU * k / 10.0, 0.22, 0.046, 0.150, 0.124, 0.118, 0.012, 0.021, 0.012, CB.M_RIM, C_RIM)
	for k in 16:
		var f: Array = wheel_frame(TAU * (k + 0.5) / 16.0)
		bar(b, (f[0] as Vector3) * 0.177 + Vector3(0.164, 0.0, 0.0), Vector3(0.003, 0.0045, 0.0045), CB.M_CHROME, C_CHROME)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Door window in side view (z, y), its front edge leaning back with the A-pillar.
	shapes["side"] = _inset(PackedVector2Array([Vector2(-0.256, 0.776), Vector2(0.150, 0.776), Vector2(0.150, 0.988),
			Vector2(-0.172, 0.988), Vector2(-0.256, 0.800)]), 0.016)
	# Windscreen in front view (x, y); the cab's rear window in back view.
	shapes["windscreen"] = _inset(PackedVector2Array([Vector2(-0.300, 0.810), Vector2(0.300, 0.810),
			Vector2(0.288, 1.006), Vector2(-0.288, 1.006)]), 0.018)
	shapes["rear"] = _inset(PackedVector2Array([Vector2(-0.262, 0.842), Vector2(0.262, 0.842), Vector2(0.262, 0.992),
			Vector2(-0.262, 0.992)]), 0.022)
	# Panels: the door in side view (its top hidden in the hardtop's black), the tailgate in back view.
	shapes["door"] = PackedVector2Array([Vector2(-0.312, 0.415), Vector2(0.205, 0.415), Vector2(0.205, 0.760),
			Vector2(-0.312, 0.760)])
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var outside: bool = n.x > 0.5 and p.x > 0.37
	var szy := Vector2(p.z, p.y)
	var sxy := Vector2(p.x, p.y)
	# The hardtop, the cowl and the bed: black above the tub's shoulder line.
	if p.z > -0.43 and p.y > 0.725:
		black = _cover(maxf(-0.422 - p.z, 0.737 - p.y), fp)
	# The bed's liner: its floor, the inside of its walls, the cab's back and the tailgate's inside.
	if p.z > 0.25 and p.z < 0.99 and not outside and n.z < 0.6:
		if n.y > 0.45 or n.x < -0.45 or (n.z > 0.4 and p.z < 0.3) or (n.z < -0.4 and p.z > 0.9):
			black = 1.0
	if n.z > 0.4 and p.z > 0.24 and p.z < 0.3:
		black = 1.0
	# Windows.
	if n.x > 0.4 and p.z > -0.30 and p.z < 0.19 and p.y > 0.76:
		glass = maxf(glass, _cover(_sd_rounded(szy, sh["side"]), fp))
	if n.z < -0.3 and p.z > -0.41 and p.z < -0.27:
		glass = maxf(glass, _cover(_sd_rounded(sxy, sh["windscreen"]), fp))
	if n.z > 0.4 and p.z > 0.24 and p.z < 0.3 and p.y > 0.8:
		glass = maxf(glass, _cover(_sd_rounded(sxy, sh["rear"]), fp))
	# Door gaps. (No tailgate outline: the tail cap squeezes its face into a few texels, which
	# smeared a gap across the middle of it. The corner guards frame the tailgate instead.)
	if outside and p.z > -0.33 and p.z < 0.23 and p.y > 0.40 and p.y < 0.745:
		gap = maxf(gap, _cover(absf(_sd_poly(szy, sh["door"])) - 0.0022, fp))
	# Bonnet: seams along the wings; louvres on the dome; the cowl-induction vent at its back.
	if n.y > 0.4 and p.z < -0.42:
		gap = maxf(gap, _cover(absf(p.x - 0.371) - 0.002, fp))
	if n.y > 0.8 and p.z > -0.64 and p.z < -0.49 and p.x > 0.05 and p.x < 0.16:
		var slot := 1e3
		for k in 4:
			slot = minf(slot, _sd_box(Vector2(p.x - 0.105, p.z + 0.615 - 0.036 * k), Vector2(0.044, 0.0065)) - 0.003)
		black = maxf(black, _cover(slot, fp))
	if n.z > 0.3 and p.z > -0.48 and p.z < -0.43 and p.y > 0.77:
		var bars: float = absf(fposmod(p.x + 0.025, 0.05) - 0.025) - 0.0045
		black = maxf(black, _cover(p.x - 0.168, fp) * _cover(-bars, fp))
	# Underside, and the arches' ceilings.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, chrome, black)
