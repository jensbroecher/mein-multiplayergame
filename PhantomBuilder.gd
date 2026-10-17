# PhantomBuilder.gd
#
# The Phantom: a first-generation Bronco-style crawler (boxy two-door body, hardtop with ribs,
# domed bonnet, squared wheel arches with flares) on solid axles and crawler tyres, rebuilt in code
# from its Hunyuan model (~810k triangles). Proportions measured off that mesh; the wheels sit where
# its wheels did.
#
# The shell, flares, wheel parts and detail map come from CarDesign.gd. This file gives the shape
# and builds what is the Phantom's own. Its section is boxy (_upper: straight glass, a tight roof
# corner, a crowned roof, the bonnet's raised dome), and the wheel arches are cut by lifting the
# shell's bottom over each wheel (BOT_KNOTS); dark liners close the arches inside, and the flares
# follow the same outline. Front and rear faces carry their details as parts (grille insert,
# lamps), since the shell's caps squeeze those faces into few texels of the detail map.
extends "res://CarDesign.gd"

# Wheels: the Hunyuan model's positions (track measured to the tyres' outer faces at 0.575).
const WHEEL_X := 0.4575
const AXLE_F := -0.741
const AXLE_R := 0.685
const HUB_Y := 0.27

# Section parameters along the car, (z, value) knots. Measured off the Hunyuan mesh.
# top: the top of the centre line (the bonnet dome, the roof); edge: the top surface beside it.
const TOP_KNOTS := [[-1.06, 0.750], [-0.92, 0.750], [-0.88, 0.765], [-0.82, 0.785], [-0.78, 0.800],
	[-0.72, 0.808], [-0.60, 0.812], [-0.48, 0.816], [-0.41, 0.818], [-0.38, 0.822], [-0.36, 0.840],
	[-0.336, 0.862], [-0.30, 0.940], [-0.27, 1.005], [-0.242, 1.070], [-0.225, 1.094], [-0.20, 1.106],
	[-0.10, 1.110], [0.90, 1.110], [0.96, 1.108], [0.98, 1.100], [0.995, 1.050], [1.005, 0.970],
	[1.013, 0.930], [1.022, 0.890], [1.033, 0.850], [1.042, 0.810], [1.060, 0.775], [1.075, 0.755],
	[1.100, 0.750]]
const EDGE_KNOTS := [[-1.06, 0.750], [-0.80, 0.756], [-0.60, 0.765], [-0.45, 0.775], [-0.40, 0.790],
	[-0.38, 0.805], [-0.36, 0.832], [-0.336, 0.855], [-0.30, 0.932], [-0.27, 0.997], [-0.242, 1.062],
	[-0.225, 1.085], [-0.20, 1.097], [-0.10, 1.100], [0.90, 1.100], [0.96, 1.098], [0.98, 1.090],
	[0.995, 1.042], [1.005, 0.962], [1.013, 0.922], [1.022, 0.882], [1.033, 0.842], [1.042, 0.803],
	[1.060, 0.768], [1.075, 0.749], [1.100, 0.744]]
# The bonnet's dome: its half-width (kept continuous, so its ring points never jump) and its
# height (0 where there is none). The rest of top over edge is the roof's crown.
const DOME_W_KNOTS := [[-1.06, 0.12], [-0.78, 0.15], [-0.60, 0.22], [-0.42, 0.29], [1.10, 0.29]]
const DOME_H_KNOTS := [[-1.06, 0.0], [-0.92, 0.0], [-0.88, 0.012], [-0.82, 0.030], [-0.78, 0.042],
	[-0.72, 0.046], [-0.60, 0.046], [-0.45, 0.044], [-0.41, 0.040], [-0.39, 0.020], [-0.375, 0.0], [1.10, 0.0]]
const W_KNOTS := [[-1.06, 0.445], [-0.47, 0.445], [-0.43, 0.470], [1.10, 0.470]]
const BELT_KNOTS := [[-1.06, 0.728], [-0.44, 0.735], [-0.40, 0.745], [-0.34, 0.790], [0.97, 0.790],
	[0.99, 0.760], [1.02, 0.700], [1.10, 0.700]]
# The bottom of the shell: the sills at 0.38, lifted over each wheel to cut its arch.
const BOT_KNOTS := [[-1.06, 0.450], [-1.00, 0.450], [-0.985, 0.480], [-0.96, 0.555], [-0.93, 0.600],
	[-0.89, 0.615], [-0.55, 0.615], [-0.51, 0.600], [-0.48, 0.555], [-0.455, 0.480], [-0.43, 0.405],
	[-0.41, 0.380], [0.41, 0.380], [0.43, 0.405], [0.455, 0.480], [0.48, 0.555], [0.51, 0.600],
	[0.55, 0.615], [0.86, 0.615], [0.90, 0.600], [0.93, 0.555], [0.955, 0.480], [0.97, 0.450],
	[1.10, 0.450]]
# Glass leaning in above the beltline, and the roof corner's radius.
const TUMBLE_KNOTS := [[-1.06, 0.0], [-0.40, 0.0], [-0.30, 0.045], [-0.20, 0.055], [0.98, 0.055],
	[1.06, 0.040], [1.10, 0.025]]
const R_KNOTS := [[-1.06, 0.022], [-0.40, 0.022], [-0.30, 0.030], [-0.20, 0.035], [1.00, 0.035],
	[1.10, 0.030]]

const FRONT_FLARE_OUT := 0.535
const REAR_FLARE_OUT := 0.545
const FLARE_DEPTH := 0.055

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.24, 0.24, 0.25)
const C_DARK := Color(0.07, 0.07, 0.075)
const C_DARKER := Color(0.035, 0.035, 0.04)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.78, 0.79, 0.80)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.6, 0.6, 0.62)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.04, "tail_z": 1.095, "belt_y": 0.79, "side_x": 0.47,
	"door_z": -0.04, "door_y": 0.58, "roundel_r": 0.12,
	"hood_z": -0.62, "hood_r": 0.10, "stripe_w": 0.085, "stripe_gap": 0.035,
}
const ANTENNA_POS := Vector3(0.37, 1.115, 0.90)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.040
	nose_cap = 0.018
	nose_cap_y = 0.600
	nose_cap_exp = Vector2(8.0, 8.0)
	tail_tip = 1.095
	tail_cap = 0.018
	tail_cap_y = 0.600
	tail_cap_exp = Vector2(8.0, 8.0)
	# Bottom, bottom corner, side; glass, roof corner, outer top, dome step, dome top.
	segment_counts = [3, 3, 4, 4, 6, 4, 4, 4]
	half_ring = 32
	bottom_radius = 0.02
	setup_shell({"top": TOP_KNOTS, "edge": EDGE_KNOTS, "dome_w": DOME_W_KNOTS, "dome_h": DOME_H_KNOTS,
		"w": W_KNOTS, "belt": BELT_KNOTS, "bot": BOT_KNOTS, "tumble": TUMBLE_KNOTS, "r": R_KNOTS})


## A boxy top, as segments with fixed point counts (segment_counts): the glass straight up from
## the beltline (leaning in by tumble), a tight corner of radius r, then the top: crowned toward
## the centre line, with the bonnet's dome raised on it by a rounded step at dome_w.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var edge: float = minf(prof["edge"].at(z), top)
	var r: float = clampf(prof["r"].at(z), 0.004, maxf(edge - belt, 0.008) * 0.9)
	var xs: float = w - prof["tumble"].at(z)
	var x0: float = xs - r
	var dome_w: float = minf(prof["dome_w"].at(z), x0 - 0.05)
	var dome_h: float = clampf(prof["dome_h"].at(z), 0.0, top - edge)
	var crown: float = maxf(top - edge - dome_h, 0.0)
	var xr: float = minf(dome_w + 0.035, x0 - 0.01)
	var glass := PackedVector2Array([Vector2(w, belt), Vector2(xs, edge - r)])
	var corner := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.5 * k / 8.0
		corner.append(Vector2(xs - r + r * cos(a), edge - r + r * sin(a)))
	var crown_y := func(x: float) -> float: return edge + crown * sin((1.0 - x / x0) * PI * 0.5)
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
	return [glass, corner, outer, step, dome]


## The flare's section: a lip, a rounded outer face standing proud of the body, sloping back into
## the body side; underneath, a flat liner from the lip in to just outside the body side.
func _fender_section(xo: float, x_in: float, d: float) -> Array:
	var w: float = x_in + 0.035
	return [
		[Vector2(xo - 0.012, 0.0), Vector2(xo - 0.002, 0.006), Vector2(xo + 0.002, 0.02), Vector2(xo + 0.002, 0.5 * d),
			Vector2(xo - 0.006, 0.8 * d), Vector2(xo - 0.025, d), Vector2(w + 0.004, d + 0.004), Vector2(x_in, d + 0.004)],
		[Vector2(xo - 0.012, 0.0), Vector2(w + 0.002, 0.0)],
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


## Body mesh: shell, flares and liners, lamps, grille, bumpers, roof ribs, chassis and axles.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	build_fender(b, _arch_lip(-0.41, -0.995), AXLE_F, HUB_Y, FRONT_FLARE_OUT, FLARE_DEPTH, 0.0)
	build_fender(b, _arch_lip(0.41, 0.975), AXLE_R, HUB_Y, REAR_FLARE_OUT, FLARE_DEPTH, 0.0)
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inside each arch, so it doesn't look through the car.
	for arch in [[-0.98, -0.46], [0.46, 0.96]]:
		var zc: float = (arch[0] + arch[1]) * 0.5
		var hz: float = (arch[1] - arch[0]) * 0.5
		b.rbox(Transform3D(Basis(), Vector3(0.25, 0.505, zc)), Vector3(0.004, 0.11, hz), 0.003, 1, CB.M_DARK, C_DARKER)
	# Headlamp: chrome bezel and lens, set in the grille insert.
	var lamp_c := Vector3(0.31, 0.617, nose_tip - 0.020)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(lamp_c, Vector3.FORWARD, PackedVector2Array([Vector2(-0.012, 0.064), Vector2(0.008, 0.064),
			Vector2(0.013, 0.060), Vector2(0.014, 0.054)]), 24, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, lamp_c + Vector3.BACK * 0.05)
	lens(b, lamp_c + Vector3.FORWARD * 0.008, Vector3.FORWARD, 0.055, 0.011, 24)
	# Taillamps: two stacked red lenses at each rear corner; an amber side marker up front.
	for y in [0.611, 0.678]:
		b.rbox(Transform3D(Basis(), Vector3(0.414, y, tail_tip + 0.004)), Vector3(0.062, 0.030, 0.010), 0.005, 1,
				CB.M_TAILLAMP, C_TAILLAMP)
	b.rbox(Transform3D(Basis(), Vector3(0.447, 0.700, -0.37)), Vector3(0.006, 0.009, 0.026), 0.003, 1,
			CB.M_TAILLAMP, C_AMBER)
	# Mirror on an arm from the door, and the long door handle.
	b.tube(PackedVector3Array([Vector3(0.462, 0.800, -0.265), Vector3(0.500, 0.830, -0.235)]), 0.008, 6,
			CB.M_DARK, C_DARK, false, true)
	b.rbox(Transform3D(Basis(Vector3.UP, 0.15), Vector3(0.508, 0.862, -0.222)), Vector3(0.036, 0.046, 0.012),
			0.009, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.476, 0.727, 0.069)), Vector3(0.007, 0.0065, 0.145), 0.004, 1,
			CB.M_DARK, C_DARK)
	# Chassis: a frame rail, the links and coil-overs of both axles.
	b.rbox(Transform3D(Basis(), Vector3(0.205, 0.448, 0.02)), Vector3(0.018, 0.026, 1.06), 0.006, 1, CB.M_DARK, C_STEEL)
	for axle in [[AXLE_F, 1.0], [AXLE_R, -1.0]]:
		var az: float = axle[0]
		var fz: float = axle[1]
		# Lower and upper links running toward the middle of the car, to the frame.
		b.tube(PackedVector3Array([Vector3(0.17, 0.235, az), Vector3(0.19, 0.40, az + 0.40 * fz)]), 0.011, 6,
				CB.M_DARK, C_STEEL)
		b.tube(PackedVector3Array([Vector3(0.10, 0.33, az), Vector3(0.16, 0.43, az + 0.30 * fz)]), 0.009, 6,
				CB.M_DARK, C_STEEL)
		# C-hub at the axle's end and the stub to the wheel.
		b.rbox(Transform3D(Basis(), Vector3(0.355, HUB_Y, az)), Vector3(0.022, 0.05, 0.032), 0.01, 1, CB.M_DARK, C_STEEL)
		b.tube(PackedVector3Array([Vector3(0.355, HUB_Y, az), Vector3(0.42, HUB_Y, az)]), 0.016, 8, CB.M_ALLOY,
				C_ALLOY_DARK, false, true)
		coilover(b, Vector3(0.30, 0.30, az + 0.07 * fz), Vector3(0.27, 0.60, az + 0.04 * fz), 0.017, 0.027, 7.0,
				C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)


func _centre_parts(b) -> void:
	# Grille insert on the front face: black surround, chrome bars between the headlamps.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.613, nose_tip - 0.006)), Vector3(0.400, 0.078, 0.012), 0.012, 2,
			CB.M_DARK, C_DARK)
	for y in [0.572, 0.598, 0.624, 0.650]:
		bar(b, Vector3(0.0, y, nose_tip - 0.020), Vector3(0.243, 0.004, 0.004), CB.M_ALLOY, C_ALLOY_DARK)
	for k in 9:
		bar(b, Vector3(-0.24 + 0.06 * k, 0.611, nose_tip - 0.021), Vector3(0.004, 0.048, 0.004), CB.M_ALLOY, C_ALLOY_DARK)
	# Bumpers: a heavy steel front bumper with mounts back to the frame; a plate at the back.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.463, -1.098)), Vector3(0.345, 0.052, 0.052), 0.012, 2, CB.M_DARK, C_STEEL)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.485, 1.118)), Vector3(0.345, 0.036, 0.026), 0.010, 2, CB.M_DARK, C_STEEL)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(), Vector3(0.205 * sx, 0.455, -1.035)), Vector3(0.016, 0.02, 0.03), 0.004, 1,
				CB.M_DARK, C_STEEL)
	# Tailgate: the amber lamp under a body-coloured boss.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.600, tail_tip + 0.003)), Vector3(0.044, 0.024, 0.007), 0.004, 1,
			CB.M_TAILLAMP, C_AMBER)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.648, tail_tip + 0.004)), Vector3(0.044, 0.020, 0.008), 0.005, 1,
			CB.M_PAINT, Color(1, 1, 1))
	# Hardtop ribs, sitting on the crowned roof.
	for k in 9:
		var x: float = -0.32 + 0.08 * k
		var y: float = top_y(x, 0.38)
		b.rbox(Transform3D(Basis(), Vector3(x, y + 0.002, 0.38)), Vector3(0.007, 0.005, 0.57), 0.004, 1,
				CB.M_PAINT, Color(1, 1, 1))
	# Axles: tube, diff pumpkin with its cover; driveshafts from the transfer case.
	for az in [AXLE_F, AXLE_R]:
		b.tube(PackedVector3Array([Vector3(-0.36, HUB_Y, az), Vector3(0.36, HUB_Y, az)]), 0.024, 10, CB.M_DARK,
				C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(0.05, HUB_Y, az)), Vector3(0.062, 0.058, 0.055), 0.045, 3, CB.M_DARK, C_STEEL)
		var dir: float = 1.0 if az < 0.0 else -1.0
		b.rbox(Transform3D(Basis(), Vector3(0.05, HUB_Y, az - 0.058 * dir)), Vector3(0.045, 0.042, 0.008), 0.02, 2,
				CB.M_ANODISED, Color(1, 1, 1))
		b.tube(PackedVector3Array([Vector3(0.05, HUB_Y + 0.01, az + 0.05 * dir), Vector3(0.02, 0.36, -0.05)]), 0.011, 8,
				CB.M_ALLOY, C_ALLOY_DARK, false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.38, -0.05)), Vector3(0.07, 0.05, 0.12), 0.015, 2, CB.M_DARK, C_STEEL)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## a crawler tyre with deep blocks round a twelve-spoke beadlock rim.
func build_wheel(b, side: float) -> void:
	tyre(b, [[-0.108, 0.150], [-0.115, 0.163], [-0.118, 0.185], [-0.118, 0.212], [-0.115, 0.232],
		[-0.107, 0.245], [-0.092, 0.2525], [-0.055, 0.2555], [-0.015, 0.256]], 40, C_RUBBER)
	# Tread: a centre row of blocks, staggered shoulder blocks, lugs down the sidewalls.
	var n := 18
	for k in n:
		var f: Array = wheel_frame(TAU * k / n)
		var r: Vector3 = f[0]
		var t: Vector3 = f[1]
		block(b, r * (0.256 + 0.4 * 0.0135), Vector3.RIGHT, t, r, 0.024, 0.0135, 0.017, 0.85, CB.M_RUBBER, C_RUBBER)
		var g: Array = wheel_frame(TAU * (k + 0.5) / n)
		var r2: Vector3 = g[0]
		var t2: Vector3 = g[1]
		for sx in [-1.0, 1.0]:
			var across: Vector3 = (Vector3.RIGHT + t2 * 0.25 * sx).normalized()
			block(b, r2 * (0.2545 + 0.4 * 0.0135) + Vector3(0.074 * sx, 0.0, 0.0), across, t2, r2, 0.03, 0.0135, 0.019,
					0.85, CB.M_RUBBER, C_RUBBER)
			var up: Vector3 = (r * 0.8 + Vector3(0.6 * sx, 0.0, 0.0)).normalized()
			block(b, r * 0.236 + Vector3(0.111 * sx, 0.0, 0.0), up.cross(t).normalized(), t, up, 0.012, 0.016, 0.017,
					0.8, CB.M_RUBBER, C_RUBBER)
	# Rim: beadlock ring and lip, dish, barrel; hub, spokes, bolts.
	wheel_lathe(b, PackedVector2Array([Vector2(0.094, 0.150), Vector2(0.104, 0.153), Vector2(0.110, 0.149),
			Vector2(0.110, 0.130), Vector2(0.104, 0.127)]), 40, CB.M_RIM, C_RIM, "out", Vector3(0.05, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.104, 0.127), Vector2(0.092, 0.123), Vector2(0.080, 0.113)]), 40,
			CB.M_RIM, C_RIM_BARREL, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.080, 0.113), Vector2(0.072, 0.136), Vector2(-0.098, 0.145),
			Vector2(-0.108, 0.150)]), 40, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(0.04, 0.0, 0.0), Vector3.RIGHT, 0.14, 0.03, 32, CB.M_DARK, C_DARKER)
	wheel_lathe(b, PackedVector2Array([Vector2(0.050, 0.042), Vector2(0.090, 0.042), Vector2(0.094, 0.037)]), 20,
			CB.M_RIM, C_RIM, "out", Vector3(0.07, 0.0, 0.0))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.094, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.037), Vector2(0.004, 0.032),
			Vector2(0.008, 0.020), Vector2(0.010, 0.0)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.07, 0.0, 0.0))
	for k in 12:
		spoke(b, TAU * k / 12.0, 0.0, 0.040, 0.125, 0.090, 0.084, 0.006, 0.0085, 0.012, CB.M_RIM, C_RIM)
	for k in 12:
		var f: Array = wheel_frame(TAU * (k + 0.5) / 12.0)
		bar(b, (f[0] as Vector3) * 0.139 + Vector3(0.112, 0.0, 0.0), Vector3(0.003, 0.004, 0.004), CB.M_CHROME, C_CHROME)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Side windows in side view (z, y): the door glass with its front edge along the A-pillar, and
	# the long quarter window.
	shapes["side_front"] = _inset(PackedVector2Array([Vector2(0.200, 0.795), Vector2(0.200, 0.992),
			Vector2(-0.212, 0.992), Vector2(-0.300, 0.810), Vector2(-0.300, 0.795)]), 0.014)
	shapes["side_rear"] = _inset(PackedVector2Array([Vector2(0.342, 0.842), Vector2(0.894, 0.842),
			Vector2(0.894, 0.992), Vector2(0.342, 0.992)]), 0.03)
	# Windscreen in front view (x, y) and rear window in back view.
	shapes["windscreen"] = _inset(PackedVector2Array([Vector2(-0.378, 0.866), Vector2(0.378, 0.866),
			Vector2(0.368, 1.022), Vector2(-0.368, 1.022)]), 0.02)
	shapes["rear"] = _inset(PackedVector2Array([Vector2(-0.306, 0.786), Vector2(0.306, 0.786),
			Vector2(0.306, 1.020), Vector2(-0.306, 1.020)]), 0.025)
	# Panels: the door in side view, the tailgate in back view.
	shapes["door"] = PackedVector2Array([Vector2(-0.324, 0.390), Vector2(0.246, 0.390), Vector2(0.246, 1.006),
			Vector2(-0.222, 1.006), Vector2(-0.316, 0.800), Vector2(-0.324, 0.780)])
	shapes["tailgate"] = _inset(PackedVector2Array([Vector2(-0.430, 0.470), Vector2(0.430, 0.470),
			Vector2(0.430, 0.775), Vector2(-0.430, 0.775)]), 0.012)
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var side: bool = n.x > 0.35
	var szy := Vector2(p.z, p.y)
	var sxy := Vector2(p.x, p.y)
	# Windows and their black seals.
	if side and p.y > 0.77 and p.z > -0.33 and p.z < 0.93:
		for key in ["side_front", "side_rear"]:
			var d: float = _sd_rounded(szy, sh[key])
			glass = maxf(glass, _cover(d, fp))
			black = maxf(black, _cover(d - 0.007, fp))
		# Vent window divider.
		if p.z > -0.15 and p.z < -0.11:
			black = maxf(black, _cover(absf(p.z + 0.130) - 0.005, fp) * _cover(p.y - 0.992, fp))
	if n.z < -0.3 and p.z > -0.36 and p.z < -0.21:
		var d: float = _sd_rounded(sxy, sh["windscreen"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.008, fp))
	if n.z > 0.25 and p.z > 0.97:
		var d: float = _sd_rounded(sxy, sh["rear"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.008, fp))
		gap = maxf(gap, _cover(absf(_sd_rounded(sxy, sh["tailgate"])) - 0.0022, fp))
	if side:
		# Door gaps, the hardtop's seam above the windows.
		if p.z > -0.34 and p.z < 0.27 and p.y > 0.39:
			gap = maxf(gap, _cover(absf(_sd_poly(szy, sh["door"])) - 0.0022, fp))
		if p.z > -0.23 and p.z < 0.99:
			gap = maxf(gap, 0.8 * _cover(absf(p.y - 1.042) - 0.0018, fp))
	# Bonnet: seams along the fenders and across the cowl.
	if n.y > 0.5 and p.z < -0.38:
		gap = maxf(gap, _cover(absf(absf(p.x) - 0.405) - 0.002, fp))
		gap = maxf(gap, _cover(absf(p.z + 0.392) - 0.002, fp))
	# Underside, and the arches' ceilings.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, chrome, black)
