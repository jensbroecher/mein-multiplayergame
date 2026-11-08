# NinjaBuilder.gd
#
# The Ninja: a compact modern Japanese track car, an original design with a made-up name, the Samurai's
# opposite (small, dark, smooth and quiet-looking where the Samurai is wide, chrome-covered and loud). Its
# front reads as a masked face: the roof and sides wrap down over the cabin in one smooth shell like a
# ninja's hood, and the glass is only a narrow wrap-round visor of smoked glass, the eye slit; a single
# thin light slit runs across the nose over a black lower face, with a line in the accent colour under it.
# A long blade fin with a polished edge runs down the middle from the roof to the tail like a sword worn on
# the back, between two vented engine covers; a single red light slit across the tail over a black diffuser
# and one centre exhaust; a diagonal intake slashed into each rear haunch; tiny camera-pod mirrors. Its
# wheels are throwing stars: four curved blades tapering to points at the rim, round a hole in the middle.
#
# What sets it apart from the fleet: it is short (1.96m, the shortest after the Kugelblitz) on a short
# wheelbase with the wheels pushed out to the corners, and rounded and hooded where the other dark cars are
# angular (the Shadow's faceted buggy, the Obsidian's open-wheeled raider) and the hypercars long and low
# (Fulmine, Nocturne, Inferno). No other car has the visor band, the blade fin or the star wheels.
#
# The shell is CarDesign's own section: a vertical side to the belt, then one cubic over the top (_upper:
# "tumble" pulls the shoulder in, "ka"/"kb" shape the dome), low and wide over the bonnet and the engine
# deck, a tall round dome over the cabin. The body's half width ("w") swells over each wheel and pinches
# at the doors, so the haunches carry the arches; the arches are cut by lifting the shell's bottom over
# each wheel (_bot_knots), with dark liners inside. The visor is the detail map's glass in a band of
# height round the cabin (_visor_d) that narrows to a point behind the doors.
extends "res://CarDesign.gd"

const WHEEL_X := 0.500
const AXLE_F := -0.600
const AXLE_R := 0.580
const HUB_Y := 0.195

# The section along the car (CarDesign's _upper cubic): z, the top of the centre line, the belt (top of
# the vertical side), tumble, ka, kb. Low and wide over the bonnet and the deck, a tall dome over the cabin.
const KEYS := [
	# z       top    belt   tumble ka     kb
	[-1.000, 0.300, 0.280, 0.020, 0.50, 0.70],
	[-0.950, 0.380, 0.350, 0.025, 0.50, 0.70],
	[-0.850, 0.435, 0.405, 0.030, 0.50, 0.72],
	[-0.700, 0.470, 0.445, 0.035, 0.50, 0.72],
	[-0.580, 0.488, 0.455, 0.040, 0.50, 0.72],
	[-0.420, 0.535, 0.462, 0.070, 0.50, 0.66],
	[-0.300, 0.605, 0.466, 0.115, 0.53, 0.60],
	[-0.180, 0.675, 0.469, 0.150, 0.55, 0.56],
	[-0.050, 0.720, 0.471, 0.170, 0.55, 0.55],
	[0.080, 0.732, 0.472, 0.170, 0.55, 0.55],
	[0.200, 0.720, 0.473, 0.165, 0.55, 0.56],
	[0.320, 0.675, 0.474, 0.140, 0.54, 0.58],
	[0.450, 0.610, 0.476, 0.090, 0.50, 0.64],
	[0.600, 0.566, 0.476, 0.055, 0.50, 0.70],
	[0.750, 0.546, 0.472, 0.045, 0.50, 0.70],
	[0.880, 0.530, 0.458, 0.040, 0.50, 0.70],
	[0.960, 0.470, 0.420, 0.035, 0.50, 0.70],
]
const KEY_NAMES := ["top", "belt", "tumble", "ka", "kb"]
const W_KNOTS := [[-1.00, 0.30], [-0.97, 0.42], [-0.92, 0.50], [-0.82, 0.56], [-0.68, 0.595], [-0.58, 0.600],
	[-0.48, 0.590], [-0.35, 0.565], [-0.15, 0.550], [0.10, 0.550], [0.30, 0.570], [0.45, 0.595], [0.58, 0.605],
	[0.72, 0.600], [0.84, 0.585], [0.91, 0.55], [0.94, 0.50], [0.96, 0.44]]

# The bottom of the shell, and round arches lifted over each wheel (as the Samurai's, rounder).
const NOSE_BOT := 0.140
const SILL_Y := 0.130
const TAIL_BOT := 0.180
const ARCH_RZ := 0.245
const ARCH_CY := 0.150
const ARCH_RY := 0.262
const ARCH_E := 2.2

# The visor: a band of smoked glass round the cabin, VISOR_Y high at the front, rising a little toward the
# back, VISOR_H either side of that, narrowing from VISOR_TAPER to a point at VISOR_END.
const VISOR_Y := 0.606
const VISOR_RISE := 0.026
const VISOR_H := 0.028
const VISOR_START := -0.46
const VISOR_TAPER := 0.06
const VISOR_END := 0.36
const DOOR_Z := Vector2(-0.335, 0.305)
# The blade fin down the middle: from flush with the roof at FIN_Z.x to its back end at FIN_Z.y, standing
# up to FIN_H over the deck.
const FIN_Z := Vector2(0.06, 0.885)
const FIN_H := 0.095
const FIN_DEPTH := 0.13

# Tyres: a low performance tyre (half its profile, bead to tread centre), one groove each side.
const TYRE_HALF := [[-0.104, 0.142], [-0.110, 0.149], [-0.113, 0.160], [-0.113, 0.174], [-0.109, 0.185],
	[-0.100, 0.1925], [-0.085, 0.1945], [-0.055, 0.1950], [-0.050, 0.1918], [-0.040, 0.1918], [-0.035, 0.1950],
	[0.0, 0.1950]]

const C_RUBBER := Color(0.19, 0.19, 0.20)
const C_DARK := Color(0.05, 0.05, 0.055)
const C_DARKER := Color(0.025, 0.025, 0.03)
const C_MESH := Color(0.15, 0.15, 0.16)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.78, 0.79, 0.81)
const C_ALLOY_DARK := Color(0.42, 0.43, 0.45)
const C_TITANIUM := Color(0.36, 0.34, 0.40)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.57)
const C_HEAD := Color(0.86, 0.93, 1.0)
const C_TAILLAMP := Color(0.88, 0.05, 0.06)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame. belt_y puts the
## Side Stripe's band (belt_y - 0.075) round the waist, like a sash.
const PAINT_LAYOUT := {
	"nose_z": -1.00, "tail_z": 0.96, "belt_y": 0.435, "side_x": 0.56,
	"door_z": -0.02, "door_y": 0.300, "roundel_r": 0.062,
	"hood_z": -0.74, "hood_r": 0.062, "stripe_w": 0.06, "stripe_gap": 0.035,
}
const ANTENNA_POS := Vector3(0.20, 0.700, 0.16)

const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.000
	nose_cap = 0.060
	nose_cap_y = 0.270
	nose_cap_exp = Vector2(3.5, 2.5)
	tail_tip = 0.960
	tail_cap = 0.050
	tail_cap_y = 0.360
	tail_cap_exp = Vector2(3.5, 2.5)
	half_ring = 30
	bottom_radius = 0.030
	# Bottom, bottom corner, side, then the dome as one segment: fixed counts, so each ring point stays on
	# its part of the section from station to station (resampled as one curve, the points slid and the
	# shell crumpled like a cloth cover).
	segment_counts = [3, 4, 4, 19]
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	setup_shell(knots)


## Above the side: CarDesign's cubic dome, as one segment from the side's top.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var pts := PackedVector2Array([Vector2(w, belt)])
	pts.append_array(_upper(z, w, belt, top))
	return [pts]


## Where the body's surface is at (x, y) from the nose (or the tail): CarDesign's 3mm march, then bisected
## to the surface, so a thin strip laid on a nearly flat face (the light slits) doesn't sink into it.
func shell_z(x: float, y: float, from_front: bool) -> float:
	var ax: float = absf(x)
	var z: float = nose_tip if from_front else tail_tip
	var dz: float = 0.003 if from_front else -0.003
	for k in 800:
		if _inside_half(section(z), ax, y):
			if k == 0:
				return z
			var lo: float = z - dz
			var hi: float = z
			for m in 16:
				var mid: float = (lo + hi) * 0.5
				if _inside_half(section(mid), ax, y):
					hi = mid
				else:
					lo = mid
			return hi
		z += dz
	return z


static func _bot_knots() -> Array:
	var k := [[-1.00, NOSE_BOT + 0.015], [-0.90, NOSE_BOT]]
	for arch in [[AXLE_F, NOSE_BOT, SILL_Y], [AXLE_R, SILL_Y, TAIL_BOT]]:
		var az: float = arch[0]
		k.append([az - ARCH_RZ - 0.012, arch[1]])
		for s in 21:
			var t: float = s / 10.0 - 1.0
			k.append([az + ARCH_RZ * t, ARCH_CY + ARCH_RY * pow(maxf(1.0 - pow(absf(t), ARCH_E), 0.0), 1.0 / ARCH_E)])
		k.append([az + ARCH_RZ + 0.012, arch[2]])
	k.append([0.96, TAIL_BOT + 0.01])
	return k


func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inside each arch (clear of the front tyre at full lock).
	for arch in [[AXLE_F, 0.29], [AXLE_R, 0.355]]:
		b.rbox(Transform3D(Basis(), Vector3(arch[1], 0.29, arch[0])), Vector3(0.004, 0.13, ARCH_RZ), 0.003, 1, CB.M_DARK,
				C_DARKER)
	# Hidden intakes in the black lower face, a splitter's end plate under each.
	var it: Array = face_frame(0.26, 0.205, true)
	var ib: Basis = facing(it[1])
	b.rbox(Transform3D(ib, it[0]), Vector3(0.105, 0.036, 0.008), 0.010, 1, CB.M_DARK, C_DARKER)
	for k in 4:
		bar(b, it[0] + ib.y * (-0.021 + 0.014 * k) + ib.z * 0.008, Vector3(0.095, 0.0018, 0.002), CB.M_DARK, C_MESH)
	# Camera-pod mirror on a short stalk from the door's top, ahead of the visor.
	var mz := -0.30
	var root := Vector3(prof["w"].at(mz) - 0.06, 0.495, mz)
	var pod := Vector3(prof["w"].at(mz) + 0.035, 0.520, mz + 0.015)
	b.tube(PackedVector3Array([root, pod - Vector3(0.012, 0.0, 0.0)]), 0.0055, 6, CB.M_DARK, C_DARK, false, false)
	b.rbox(Transform3D(Basis(Vector3.UP, -0.15), pod), Vector3(0.020, 0.012, 0.028), 0.010, 2, CB.M_DARK, C_DARK)
	b.disc(pod + Vector3(0.0, 0.0, 0.028), Vector3.BACK, 0.006, 0.0, 10, CB.M_HEADLAMP, Color(1, 1, 1))
	# Running gear in each arch: lower arms, hub carrier, a coil-over, the caliper in the accent colour.
	for az in [AXLE_F, AXLE_R]:
		for dz in [-0.08, 0.08]:
			b.tube(PackedVector3Array([Vector3(0.20, 0.175, az + dz), Vector3(0.42, 0.155, az)]), 0.010, 8, CB.M_DARK,
					C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(0.43, HUB_Y, az)), Vector3(0.015, 0.05, 0.028), 0.007, 1, CB.M_DARK, C_STEEL)
		coilover(b, Vector3(0.335, 0.175, az), Vector3(0.315, 0.390, az + 0.02), 0.013, 0.022, 5.0, C_ALLOY, C_ALLOY_DARK,
				C_CHROME, C_DARK)
		var ca: float = 0.85
		var cp := Vector3(WHEEL_X - 0.034, HUB_Y + cos(ca) * 0.088, az + sin(ca) * 0.088)
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -ca), cp), Vector3(0.015, 0.019, 0.036), 0.007, 2, CB.M_ANODISED,
				Color(1, 1, 1))
	# Diffuser strakes under the tail.
	for x in [0.10, 0.22, 0.34]:
		b.rbox(Transform3D(Basis(), Vector3(x, 0.205, 0.860)), Vector3(0.004, 0.026, 0.055), 0.002, 1, CB.M_DARK, C_DARKER)


func _centre_parts(b) -> void:
	# The nose's light slit, and a line in the accent colour under it.
	face_strip(b, 0.322, true, 0.405, PackedVector2Array([Vector2(-0.0075, 0.0), Vector2(0.0075, 0.0), Vector2(0.0075, 0.0055),
			Vector2(-0.0075, 0.0055)]), CB.M_TAILLAMP, C_HEAD)
	face_strip(b, 0.300, true, 0.300, PackedVector2Array([Vector2(-0.0022, 0.0), Vector2(0.0022, 0.0), Vector2(0.0022, 0.004),
			Vector2(-0.0022, 0.004)]), CB.M_ANODISED, Color(1, 1, 1))
	# The tail's light slit.
	face_strip(b, 0.468, false, 0.420, PackedVector2Array([Vector2(-0.0080, 0.0), Vector2(0.0080, 0.0), Vector2(0.0080, 0.0055),
			Vector2(-0.0080, 0.0055)]), CB.M_TAILLAMP, C_TAILLAMP)
	# Splitter under the nose.
	var sz: float = shell_z(0.0, 0.16, true)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.122, sz + 0.035)), Vector3(0.43, 0.006, 0.055), 0.005, 1, CB.M_DARK, C_DARK)
	# One centre exhaust out of the black diffuser, titanium, dark inside.
	var ez: float = shell_z(0.0, 0.245, false)
	b.tube(PackedVector3Array([Vector3(0.0, 0.245, ez - 0.10), Vector3(0.0, 0.245, ez + 0.022)]), 0.030, 18, CB.M_ALLOY,
			C_TITANIUM, false, false)
	b.disc(Vector3(0.0, 0.245, ez + 0.021), Vector3.BACK, 0.025, 0.0, 18, CB.M_DARK, C_DARKER)
	# The blade fin down the middle: a thin plate standing up out of the roof and deck, growing taller toward
	# the tail, its edge polished.
	var spine := PackedVector3Array()
	for k in 33:
		var z: float = lerpf(FIN_Z.x, FIN_Z.y, k / 32.0)
		var t: float = smoothstep(FIN_Z.x, FIN_Z.x + 0.62, z)
		spine.append(Vector3(0.0, prof["top"].at(z) - 0.004 + FIN_H * t, z))
	sweep(b, spine, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.0065, -FIN_DEPTH), Vector2(0.0065, -FIN_DEPTH),
			Vector2(0.0065, -0.010), Vector2(0.0, 0.0), Vector2(-0.0065, -0.010)]), CB.M_PAINT, Color(1, 1, 1))
	var edge := PackedVector3Array()
	for k in range(4, spine.size()):
		edge.append(spine[k])
	sweep(b, edge, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.0028, -0.006), Vector2(0.0028, -0.006),
			Vector2(0.0, 0.0035)]), CB.M_CHROME, C_CHROME)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1): a low
## performance tyre round a rim whose face is a throwing star, four curved blades tapering to points at
## the rim round a hole in the middle; the brake disc behind.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 48, C_RUBBER)
	wheel_lathe(b, PackedVector2Array([Vector2(0.088, 0.146), Vector2(0.098, 0.1495), Vector2(0.106, 0.1478),
			Vector2(0.108, 0.1420), Vector2(0.102, 0.1385)]), 48, CB.M_RIM, C_RIM, "out", Vector3(0.08, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.102, 0.1385), Vector2(0.090, 0.1355)]), 48, CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.090, 0.1355), Vector2(0.078, 0.1365), Vector2(-0.090, 0.1380),
			Vector2(-0.100, 0.1440)]), 48, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(-0.004, 0.0, 0.0), Vector3.RIGHT, 0.112, 0.042, 36, CB.M_ALLOY, C_ALLOY_DARK)
	b.disc(Vector3(-0.018, 0.0, 0.0), Vector3.LEFT, 0.112, 0.042, 36, CB.M_ALLOY, C_ALLOY_DARK)
	wheel_lathe(b, PackedVector2Array([Vector2(-0.018, 0.112), Vector2(-0.004, 0.112)]), 36, CB.M_ALLOY, C_ALLOY_DARK,
			"out", Vector3(-0.011, 0.0, 0.0))
	b.disc(Vector3(-0.050, 0.0, 0.0), Vector3.RIGHT, 0.136, 0.0, 32, CB.M_DARK, C_DARKER)
	for k in 4:
		_star_blade(b, TAU * k / 4.0)
	# The star's middle: a boss with a hole through it (a dark ring), a nut in the centre.
	wheel_lathe(b, PackedVector2Array([Vector2(0.076, 0.040), Vector2(0.088, 0.038), Vector2(0.092, 0.032)]), 24,
			CB.M_RIM, C_RIM, "out", Vector3(0.07, 0.0, 0.0))
	b.disc(Vector3(0.092, 0.0, 0.0), Vector3.RIGHT, 0.032, 0.019, 24, CB.M_RIM, C_RIM)
	b.disc(Vector3(0.091, 0.0, 0.0), Vector3.RIGHT, 0.019, 0.0, 24, CB.M_DARK, C_DARKER)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.090, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.0105), Vector2(0.007, 0.0105),
			Vector2(0.010, 0.006), Vector2(0.011, 0.0)]), 6, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.084, 0.0, 0.0))
	if side < 0.0:
		b.mirror_in_place()


## One blade of the throwing star: from the boss out to the rim, curving round ahead (the way the wheel
## turns forward) and tapering to a point, flat-faced, its front at x 0.086 and 1.2cm thick.
func _star_blade(b, a0: float) -> void:
	var n := 10
	var x_front := 0.086
	var th := 0.012
	var fl := []
	var fr := []
	var bl := []
	var br := []
	for i in n + 1:
		var t: float = float(i) / n
		var r: float = lerpf(0.030, 0.137, t)
		var a: float = a0 - 0.85 * pow(t, 1.4)
		var hw: float = lerpf(0.030, 0.0012, pow(t, 0.75))
		var f: Array = wheel_frame(a)
		var rd: Vector3 = f[0]
		var tg: Vector3 = f[1]
		var x0: float = x_front - 0.004 * t
		fl.append(rd * r + tg * hw + Vector3(x0, 0.0, 0.0))
		fr.append(rd * r - tg * hw + Vector3(x0, 0.0, 0.0))
		bl.append(rd * r + tg * hw + Vector3(x0 - th, 0.0, 0.0))
		br.append(rd * r - tg * hw + Vector3(x0 - th, 0.0, 0.0))
	for i in n:
		var side_dir: Vector3 = ((fl[i] + fl[i + 1]) * 0.5 - (fr[i] + fr[i + 1]) * 0.5).normalized()
		face(b, [fl[i], fr[i], fr[i + 1], fl[i + 1]], Vector3.RIGHT, CB.M_RIM, C_RIM)
		face(b, [bl[i], br[i], br[i + 1], bl[i + 1]], Vector3.LEFT, CB.M_RIM, C_RIM)
		face(b, [fl[i], fl[i + 1], bl[i + 1], bl[i]], side_dir, CB.M_RIM, C_RIM)
		face(b, [fr[i], fr[i + 1], br[i + 1], br[i]], -side_dir, CB.M_RIM, C_RIM)


# ============================================================================================
#  Detail map
# ============================================================================================

## Signed distance (in metres of height, negative inside) to the visor band at surface point p.
static func _visor_d(p: Vector3) -> float:
	var yc: float = VISOR_Y + VISOR_RISE * smoothstep(VISOR_START, VISOR_END, p.z)
	var h: float = VISOR_H * (1.0 - smoothstep(VISOR_TAPER, VISOR_END, p.z))
	var d: float = absf(p.y - yc) - h
	return maxf(d, VISOR_START - p.z)


## The diagonal intake slashed into the rear haunch (z, y): distance to its centre line, tapering at both
## ends.
static func _slash_d(p: Vector3) -> float:
	var a := Vector2(0.075, 0.255)
	var c := Vector2(0.285, 0.405)
	var q := Vector2(p.z, p.y)
	var e: Vector2 = c - a
	var t: float = clampf((q - a).dot(e) / e.length_squared(), 0.0, 1.0)
	var hw: float = 0.017 * sin(PI * clampf(t, 0.0, 1.0)) + 0.002
	return (a + e * t).distance_to(q) - hw


func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var black := 0.0
	var x: float = absf(p.x)
	# The visor: smoked glass in a black seal, wrapping the cabin.
	if n.y > -0.3 and p.y > 0.5:
		var d: float = _visor_d(p)
		glass = _cover(d, fp)
		black = _cover(d - 0.004, fp)
	var side: bool = n.x > 0.3
	if side:
		# Door shut lines from the sill up to the visor.
		if p.y > 0.16 and p.y < VISOR_Y:
			gap = maxf(gap, _cover(absf(p.z - DOOR_Z.x) - 0.0022, fp))
			gap = maxf(gap, _cover(absf(p.z - DOOR_Z.y) - 0.0022, fp))
		black = maxf(black, _cover(_slash_d(p), fp))
	# Bonnet shut lines and the cowl.
	if n.y > 0.5 and p.z < -0.40:
		gap = maxf(gap, _cover(absf(x - 0.33) - 0.002, fp) * float(p.z > -0.93))
		gap = maxf(gap, _cover(absf(p.z + 0.43) - 0.002, fp) * float(x < 0.33))
	# Engine covers either side of the fin: vents, slots across the car.
	if n.y > 0.5 and p.z > 0.46 and p.z < 0.86:
		var vent: float = _sd_box(Vector2(x - 0.155, p.z - 0.665), Vector2(0.105, 0.175)) - 0.012
		var slots: float = absf(fposmod(p.z - 0.49, 0.030) - 0.015) - 0.0065
		black = maxf(black, _cover(vent, fp) * _cover(slots, fp))
		gap = maxf(gap, _cover(absf(vent) - 0.002, fp))
	# The black lower face of the nose, and of the tail round the diffuser.
	if n.z < -0.35:
		black = maxf(black, _cover(p.y - 0.290, fp))
	if n.z > 0.35:
		black = maxf(black, _cover(p.y - 0.335, fp))
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, 0.0, black)
