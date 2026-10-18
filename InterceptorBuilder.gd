# InterceptorBuilder.gd
#
# The Interceptor: a five-door hot hatch in full rally trim (a WRC car, not a road car). Box flares
# over every wheel, a raised wing on swan necks with big endplates, a roof scoop, louvred bonnet, a
# four-lamp rally pod over the grille, a splitter and mesh intakes, side skirts, mud flaps at every
# wheel, a diffuser and a big single exhaust; gravel tyres on split-spoke rims with the brake discs
# and calipers behind them. Rebuilt in code from its Hunyuan model (proportions measured off it,
# the wheels where its wheels were) and taken further.
#
# The shell, flares, wheel parts and detail map come from CarDesign.gd. Above the side the section
# has a real greenhouse corner (_upper_segments): the side glass leans in from the window line, the
# corner is rounded off (the A-pillar, the roof rail, the D-pillar), and the top is crowned across
# to the centre line (bonnet, windscreen, roof, rear glass). Over the bonnet and the tail the same
# corner is the panels' rolled edge. Its parameters are keyframed together (KEYS). The detail map
# puts the pillars on that corner (_upper_s), so the windscreen spans the cabin between narrow
# pillars; on one smooth dome it had nowhere to stop and wrapped round into the side glass. The
# arches are cut by lifting the shell's bottom over each wheel in a squared arch (_bot_knots); the
# flares sweep along the same outline, and dark liners close the arches inside. Parts on the nose
# and tail are placed on the shell's surface (shell_z), since the caps squeeze those faces into few
# texels of the detail map.
extends "res://CarDesign.gd"

# Wheels: the Hunyuan model's positions (tyres 0.22 wide).
const WHEEL_X := 0.512
const AXLE_F := -0.656
const AXLE_R := 0.677
const HUB_Y := 0.235

# The section along the car: z; the top of the centre line; belt (the top of the vertical side); px,
# edge (the greenhouse corner: the A-pillar over the windscreen, the roof rail over the cabin, the
# bonnet's and the tail's rolled edges); fillet (how far the corner is rounded off along each side
# of it); bow (the side glass bulging out). As on the Hunyuan model, the A-pillars stand at x ~0.41
# from the cowl to the roof, and the windscreen is crowned 3.5cm between them.
const KEYS := [
	# z       top    belt   px     edge   fillet bow
	[-1.160, 0.330, 0.300, 0.280, 0.318, 0.020, 0.000],
	[-1.120, 0.390, 0.350, 0.355, 0.375, 0.030, 0.000],
	[-1.080, 0.435, 0.395, 0.425, 0.418, 0.040, 0.002],
	[-1.040, 0.462, 0.425, 0.475, 0.443, 0.045, 0.002],
	[-1.000, 0.481, 0.445, 0.505, 0.461, 0.045, 0.002],
	[-0.920, 0.518, 0.472, 0.515, 0.492, 0.045, 0.002],
	[-0.840, 0.543, 0.490, 0.500, 0.515, 0.045, 0.002],
	[-0.760, 0.562, 0.502, 0.490, 0.532, 0.045, 0.002],
	[-0.700, 0.575, 0.508, 0.475, 0.544, 0.042, 0.003],
	[-0.640, 0.590, 0.513, 0.430, 0.556, 0.034, 0.004],
	[-0.550, 0.627, 0.520, 0.415, 0.592, 0.032, 0.006],
	[-0.450, 0.667, 0.530, 0.410, 0.632, 0.032, 0.008],
	[-0.350, 0.706, 0.540, 0.408, 0.672, 0.032, 0.010],
	[-0.250, 0.745, 0.545, 0.406, 0.712, 0.032, 0.010],
	[-0.170, 0.776, 0.549, 0.405, 0.745, 0.032, 0.010],
	[-0.100, 0.800, 0.552, 0.410, 0.776, 0.032, 0.010],
	[-0.040, 0.810, 0.555, 0.415, 0.787, 0.032, 0.010],
	[0.300, 0.809, 0.565, 0.420, 0.788, 0.032, 0.010],
	[0.600, 0.800, 0.580, 0.420, 0.780, 0.032, 0.010],
	[0.800, 0.780, 0.590, 0.415, 0.762, 0.032, 0.010],
	[0.900, 0.762, 0.592, 0.410, 0.745, 0.034, 0.008],
	[0.950, 0.715, 0.588, 0.400, 0.700, 0.036, 0.006],
	[1.000, 0.655, 0.565, 0.385, 0.645, 0.038, 0.004],
	[1.050, 0.615, 0.520, 0.360, 0.605, 0.040, 0.003],
	[1.090, 0.560, 0.460, 0.330, 0.552, 0.040, 0.002],
	[1.130, 0.430, 0.380, 0.280, 0.425, 0.030, 0.000],
]
const KEY_NAMES := ["top", "belt", "px", "edge", "fillet", "bow"]
# The bumpers are as wide as the flares, so the flares' ends run into their corners.
const W_KNOTS := [[-1.16, 0.32], [-1.12, 0.40], [-1.08, 0.48], [-1.04, 0.545], [-1.00, 0.585], [-0.96, 0.600],
	[-0.93, 0.598], [-0.88, 0.560], [-0.82, 0.535], [0.84, 0.535], [0.90, 0.560], [0.95, 0.598], [0.99, 0.600],
	[1.03, 0.580], [1.07, 0.52], [1.10, 0.45], [1.13, 0.36]]

# The bottom of the shell: the splitter line, the sills, the rear bumper; squared arches lifted
# over each wheel (half-length ARCH_RZ, from ARCH_CY up to ARCH_CY + ARCH_RY, superellipse ARCH_E).
const NOSE_BOT := 0.140
const SILL_Y := 0.165
const TAIL_BOT := 0.220
const ARCH_RZ := 0.270
const ARCH_CY := 0.200
const ARCH_RY := 0.290
const ARCH_E := 2.6
const FLARE_OUT := 0.615
# The glass round the greenhouse's corner: the side glass stops PILLAR_PAD short of the corner's
# rounding, the windscreen and rear glass start PILLAR_PAD inboard of it, and the pillar between
# is body colour. The windscreen runs from the cowl to the header (WS_Z), the rear glass from the
# roof's end down the tailgate (RG_Z).
const PILLAR_PAD := 0.004
const WS_Z := Vector2(-0.632, -0.172)
const RG_Z := Vector2(0.918, 1.040)
const FRONT_FLARE_DEPTH := 0.055
const REAR_FLARE_DEPTH := 0.060

# Tyres: a gravel tyre's carcass (half its profile, bead to tread centre) under small blocks.
const TYRE_HALF := [[-0.098, 0.145], [-0.105, 0.155], [-0.110, 0.172], [-0.111, 0.188], [-0.108, 0.202],
	[-0.100, 0.212], [-0.085, 0.219], [-0.050, 0.2225], [0.0, 0.223]]
const TREAD_ROWS := 30
const BLOCK_H := 0.012

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.22, 0.22, 0.23)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_MESH := Color(0.20, 0.20, 0.21)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.78, 0.79, 0.81)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_TITANIUM := Color(0.62, 0.58, 0.66)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.60, 0.60, 0.62)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.16, "tail_z": 1.13, "belt_y": 0.56, "side_x": 0.535,
	"door_z": -0.06, "door_y": 0.31, "roundel_r": 0.085,
	"hood_z": -0.85, "hood_r": 0.08, "stripe_w": 0.075, "stripe_gap": 0.03,
}
const ANTENNA_POS := Vector3(0.16, 0.805, 0.55)
var _curve_cache := {}                    # z -> the upper curve's samples, for _upper_s()

const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.160
	nose_cap = 0.060
	nose_cap_y = 0.270
	nose_cap_exp = Vector2(4.0, 3.0)
	tail_tip = 1.130
	tail_cap = 0.050
	tail_cap_y = 0.330
	tail_cap_exp = Vector2(3.0, 2.5)
	# Bottom, bottom corner, side; then the glass, the corner's rounding, the crowned top.
	segment_counts = [2, 3, 4, 7, 6, 9]
	half_ring = 31
	bottom_radius = 0.025
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	setup_shell(knots)


## The shell's bottom: flat along the splitter, sills and rear bumper, stepping up into a squared
## arch over each wheel.
static func _bot_knots() -> Array:
	var k := [[-1.16, NOSE_BOT + 0.01], [-1.06, NOSE_BOT]]
	for arch in [[AXLE_F, NOSE_BOT, SILL_Y], [AXLE_R, SILL_Y, TAIL_BOT]]:
		var az: float = arch[0]
		k.append([az - ARCH_RZ - 0.012, arch[1]])
		for s in 21:
			var t: float = s / 10.0 - 1.0
			k.append([az + ARCH_RZ * t, ARCH_CY + ARCH_RY * pow(maxf(1.0 - pow(absf(t), ARCH_E), 0.0), 1.0 / ARCH_E)])
		k.append([az + ARCH_RZ + 0.012, arch[2]])
	k.append([1.13, TAIL_BOT + 0.01])
	return k


## The greenhouse corner at z: [the sharp corner K, where its rounding starts on the glass (T1),
## where it ends on the top (T2), the top's crown].
func _corner(z: float, w: float, belt: float, top: float) -> Array:
	var px: float = minf(prof["px"].at(z), w - 0.005)
	var edge: float = clampf(prof["edge"].at(z), belt + 0.003, top)
	var crown: float = top - edge
	var k := Vector2(px, edge)
	var s := Vector2(w, belt)
	var f: float = prof["fillet"].at(z)
	var t1: Vector2 = k + (s - k).normalized() * minf(f, 0.45 * s.distance_to(k))
	var tx: float = minf(f, 0.45 * px)
	return [k, t1, Vector2(px - tx, _crown_y(px - tx, k, crown)), crown]


## The crowned top's height at x: level at the centre line, down to the corner's height at its x.
static func _crown_y(x: float, k: Vector2, crown: float) -> float:
	return k.y + crown * (1.0 - (x / k.x) * (x / k.x))


## Above the side, as segments with fixed point counts (segment_counts): the glass leaning in from
## the side's top to the corner's rounding, bowed out a little; the rounding (a quadratic through
## the sharp corner, so it meets both tangentially); the crowned top across to the centre line.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var c: Array = _corner(z, w, belt, top)
	var k: Vector2 = c[0]
	var t1: Vector2 = c[1]
	var t2: Vector2 = c[2]
	var s := Vector2(w, belt)
	var dir: Vector2 = (t1 - s).normalized()
	var mid: Vector2 = (s + t1) * 0.5 + Vector2(dir.y, -dir.x) * prof["bow"].at(z)
	var glass := PackedVector2Array()
	var rounding := PackedVector2Array()
	for i in 13:
		var u: float = i / 12.0
		glass.append(s.lerp(mid, u).lerp(mid.lerp(t1, u), u))
		rounding.append(t1.lerp(k, u).lerp(k.lerp(t2, u), u))
	var crowned := PackedVector2Array()
	for i in 17:
		var x: float = t2.x * (1.0 - i / 16.0)
		crowned.append(Vector2(x, _crown_y(x, k, c[3])))
	return [glass, rounding, crowned]


## The flare's section: a lip, a flat outer face standing proud of the body, a rounded shoulder,
## the top sloping back into the body side; underneath, a flat liner in to the body side.
func _fender_section(xo: float, x_in: float, d: float) -> Array:
	var w: float = x_in + 0.035
	return [
		[Vector2(xo - 0.012, 0.0), Vector2(xo - 0.002, 0.006), Vector2(xo + 0.002, 0.02), Vector2(xo + 0.002, 0.5 * d),
			Vector2(xo - 0.006, 0.8 * d), Vector2(xo - 0.025, d), Vector2(w + 0.004, d + 0.006), Vector2(x_in, d + 0.006)],
		[Vector2(xo - 0.012, 0.0), Vector2(w + 0.002, 0.0)],
	]


## A wheel arch's outline as a flare's lip: the shell's bottom from the sill at the door end round
## over the wheel to the outer end, as 18 points spaced along it.
func _arch_lip(z_door: float, z_end: float) -> Array:
	var dense := PackedVector2Array()
	for k in 241:
		var z: float = lerpf(z_door, z_end, k / 240.0)
		dense.append(Vector2(z, prof["bot"].at(z)))
	var pts: PackedVector2Array = CB.resample(dense, 18, 0.0)
	var lip := []
	for p in pts:
		lip.append([p.x, p.y])
	return lip


## A point on the nose (or tail) at (x, y) and the shell's outward normal there: [point, normal].
func _face_frame(x: float, y: float, front: bool) -> Array:
	var z: float = shell_z(x, y, front)
	var e := 0.01
	var dzdx: float = (shell_z(x + e, y, front) - shell_z(x - e, y, front)) / (2.0 * e)
	var dzdy: float = (shell_z(x, y + e, front) - shell_z(x, y - e, front)) / (2.0 * e)
	var nrm := Vector3(dzdx, dzdy, -1.0 if front else 1.0).normalized()
	if (nrm.z < 0.0) != front:
		nrm = -nrm
	return [Vector3(x, y, z), nrm]


## A basis whose z axis is `fwd` and y axis as near to up as it allows.
static func _facing(fwd: Vector3) -> Basis:
	var zb: Vector3 = fwd.normalized()
	var xb: Vector3 = Vector3.UP.cross(zb).normalized()
	return Basis(xb, zb.cross(xb).normalized(), zb)


## Body mesh: shell, flares, liners, lamps, aero, bumpers and the running gear seen in the arches.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	build_fender(b, _arch_lip(AXLE_F + ARCH_RZ + 0.012, AXLE_F - ARCH_RZ - 0.012), AXLE_F, HUB_Y, FLARE_OUT,
			FRONT_FLARE_DEPTH, 0.0)
	build_fender(b, _arch_lip(AXLE_R - ARCH_RZ - 0.012, AXLE_R + ARCH_RZ + 0.012), AXLE_R, HUB_Y, FLARE_OUT,
			REAR_FLARE_DEPTH, 0.0)
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inside each arch (clear of the front tyre at full lock).
	for arch in [[AXLE_F, 0.29], [AXLE_R, 0.37]]:
		b.rbox(Transform3D(Basis(), Vector3(arch[1], 0.35, arch[0])), Vector3(0.004, 0.14, ARCH_RZ), 0.003, 1, CB.M_DARK,
				C_DARKER)
	# Headlamp at the nose's corner: a dark housing on the surface, twin projector lenses.
	var hl: Array = _face_frame(0.33, 0.425, true)
	var hb: Basis = _facing(hl[1])
	b.rbox(Transform3D(hb, hl[0]), Vector3(0.095, 0.036, 0.012), 0.014, 2, CB.M_DARK, C_DARK)
	for dx in [-0.045, 0.045]:
		lens(b, hl[0] + hb.x * dx + hb.z * 0.010, hl[1], 0.027, 0.008, 18)
	b.rbox(Transform3D(hb, hl[0] + hb.y * -0.030 + hb.z * 0.006), Vector3(0.085, 0.004, 0.006), 0.002, 1,
			CB.M_TAILLAMP, C_AMBER)
	# Side intake in the bumper's corner.
	var si: Array = _face_frame(0.36, 0.235, true)
	b.rbox(Transform3D(_facing(si[1]), si[0]), Vector3(0.075, 0.045, 0.012), 0.012, 2, CB.M_DARK, C_MESH)
	# Taillamps: a long red bar across the tail's corner, an amber block at its outer end, a
	# reversing lamp low on the valance.
	for k in 4:
		var tl: Array = _face_frame(0.25 + 0.06 * k, 0.575 - 0.008 * k, false)
		var tb: Basis = _facing(tl[1])
		b.rbox(Transform3D(tb, tl[0]), Vector3(0.034, 0.034, 0.010), 0.008, 2, CB.M_TAILLAMP,
				C_AMBER if k == 3 else C_TAILLAMP)
	var rv: Array = _face_frame(0.30, 0.275, false)
	b.rbox(Transform3D(_facing(rv[1]), rv[0]), Vector3(0.03, 0.012, 0.012), 0.006, 1, CB.M_TAILLAMP, Color(0.85, 0.85, 0.82))
	# Mirror on a stalk from the panel ahead of the side glass, the glass at its back.
	b.tube(PackedVector3Array([Vector3(0.508, 0.570, -0.375), Vector3(0.585, 0.600, -0.355)]), 0.008, 6, CB.M_DARK, C_DARK,
			false, false)
	var mb := Basis(Vector3.UP, 0.18)
	b.rbox(Transform3D(mb, Vector3(0.600, 0.612, -0.340)), Vector3(0.048, 0.030, 0.024), 0.014, 2, CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(mb, Vector3(0.604, 0.612, -0.316)), Vector3(0.040, 0.023, 0.002), 0.002, 1, CB.M_CHROME, C_CHROME)
	# Door handles; a side skirt between the arches.
	for z in [-0.05, 0.47]:
		b.rbox(Transform3D(Basis(), Vector3(0.538, 0.525, z)), Vector3(0.006, 0.008, 0.035), 0.004, 1, CB.M_DARK, C_DARK)
	var skirt_z0: float = AXLE_F + ARCH_RZ + 0.02
	var skirt_z1: float = AXLE_R - ARCH_RZ - 0.02
	b.rbox(Transform3D(Basis(), Vector3(0.538, 0.185, (skirt_z0 + skirt_z1) * 0.5)),
			Vector3(0.016, 0.028, (skirt_z1 - skirt_z0) * 0.5), 0.010, 2, CB.M_DARK, C_DARK)
	# Mud flaps behind each wheel, an accent strip low on each.
	for arch in [[AXLE_F, SILL_Y + 0.03], [AXLE_R, TAIL_BOT + 0.02]]:
		var fz: float = arch[0] + ARCH_RZ + 0.004
		var top: float = arch[1]
		var bottom := 0.035
		var fb := Basis(Vector3.RIGHT, -0.08)
		b.rbox(Transform3D(fb, Vector3(WHEEL_X, (top + bottom) * 0.5, fz)), Vector3(0.10, (top - bottom) * 0.5, 0.004),
				0.003, 1, CB.M_DARK, C_DARK)
		b.rbox(Transform3D(fb, Vector3(WHEEL_X, bottom + 0.03, fz + 0.004)), Vector3(0.085, 0.011, 0.0015), 0.001, 1,
				CB.M_ANODISED, Color(1, 1, 1))
	# Running gear in each arch: lower arm, hub carrier, a strut, the caliper on the disc.
	for az in [AXLE_F, AXLE_R]:
		for dz in [-0.08, 0.08]:
			b.tube(PackedVector3Array([Vector3(0.20, 0.215, az + dz), Vector3(0.43, 0.185, az)]), 0.011, 8, CB.M_DARK,
					C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(0.45, HUB_Y, az)), Vector3(0.016, 0.06, 0.03), 0.008, 1, CB.M_DARK, C_STEEL)
		coilover(b, Vector3(0.345, 0.215, az), Vector3(0.318, 0.46, az + 0.02), 0.014, 0.024, 6.0, C_ALLOY, C_ALLOY_DARK,
				C_CHROME, C_DARK)
		var ca: float = 0.75
		var cp := Vector3(WHEEL_X - 0.017, HUB_Y + cos(ca) * 0.105, az + sin(ca) * 0.105)
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -ca), cp), Vector3(0.018, 0.022, 0.04), 0.008, 2, CB.M_ANODISED,
				Color(1, 1, 1))
	# Exhaust: one big titanium can out under the right of the bumper.
	b.tube(PackedVector3Array([Vector3(0.25, 0.205, 0.98), Vector3(0.25, 0.205, 1.155)]), 0.036, 18, CB.M_ALLOY, C_TITANIUM,
			false, false)
	b.disc(Vector3(0.25, 0.205, 1.154), Vector3.BACK, 0.030, 0.0, 18, CB.M_DARK, C_DARKER)
	# Wing endplate and its swan neck from the roof's end.
	slab(b, PackedVector2Array([Vector2(0.915, 0.830), Vector2(0.950, 0.790), Vector2(1.120, 0.800), Vector2(1.155, 0.860),
			Vector2(1.145, 0.912), Vector2(0.985, 0.902)]), 0.470, 0.010, CB.M_DARK, C_DARK)
	slab(b, PackedVector2Array([Vector2(1.000, 0.888), Vector2(1.130, 0.893), Vector2(1.142, 0.906),
			Vector2(1.010, 0.900)]), 0.4765, 0.003, CB.M_ANODISED, Color(1, 1, 1))
	slab(b, PackedVector2Array([Vector2(0.860, 0.760), Vector2(0.925, 0.745), Vector2(1.025, 0.850), Vector2(0.990, 0.862)]),
			0.22, 0.012, CB.M_DARK, C_DARK)
	# Tow hook at the front.
	b.tube(_rounded([Vector3(0.20, 0.17, -1.10), Vector3(0.20, 0.17, -1.17), Vector3(0.25, 0.17, -1.17),
			Vector3(0.25, 0.17, -1.10)], 0.018), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)


func _centre_parts(b) -> void:
	# Splitter under the nose; a diffuser with fins under the tail.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.130, -1.095)), Vector3(0.52, 0.007, 0.06), 0.005, 1, CB.M_DARK, C_DARK)
	# Rear valance in black.
	var va: Array = _face_frame(0.0, 0.27, false)
	b.rbox(Transform3D(_facing(va[1]), va[0]), Vector3(0.34, 0.045, 0.012), 0.012, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(0.0, 0.200, 1.080)), Vector3(0.36, 0.006, 0.075), 0.004, 1,
			CB.M_DARK, C_DARK)
	for k in 5:
		b.rbox(Transform3D(Basis(), Vector3(-0.16 + 0.08 * k, 0.215, 1.085)), Vector3(0.004, 0.025, 0.065), 0.002, 1,
				CB.M_DARK, C_DARKER)
	# Main intake: a mesh panel with a grid of bars across the nose's lower face.
	var mi: Array = _face_frame(0.0, 0.245, true)
	var mb: Basis = _facing(mi[1])
	b.rbox(Transform3D(mb, mi[0]), Vector3(0.235, 0.060, 0.014), 0.016, 2, CB.M_DARK, C_DARKER)
	for k in 4:
		bar(b, mi[0] + mb.y * (-0.036 + 0.024 * k) + mb.z * 0.012, Vector3(0.22, 0.003, 0.003), CB.M_DARK, C_MESH)
	for k in 13:
		bar(b, mi[0] + mb.x * (-0.198 + 0.033 * k) + mb.z * 0.012, Vector3(0.003, 0.052, 0.003), CB.M_DARK, C_MESH)
	# Upper grille slot, and the rally pod over it: four lamps in a dark bar.
	var ug: Array = _face_frame(0.0, 0.345, true)
	b.rbox(Transform3D(_facing(ug[1]), ug[0]), Vector3(0.20, 0.022, 0.012), 0.010, 2, CB.M_DARK, C_DARKER)
	var pod: Array = _face_frame(0.0, 0.385, true)
	var pc: Vector3 = pod[0] + Vector3(0.0, 0.0, -0.035)
	b.rbox(Transform3D(Basis(), pc), Vector3(0.31, 0.040, 0.026), 0.014, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(), pc + Vector3(0.0, -0.042, 0.0)), Vector3(0.29, 0.003, 0.02), 0.002, 1, CB.M_ANODISED,
			Color(1, 1, 1))
	for x in [-0.225, -0.075, 0.075, 0.225]:
		round_lamp(b, pc + Vector3(x, 0.0, -0.028), Vector3.FORWARD, 0.033, CB.M_HEADLAMP, Color(1, 1, 1))
	for x in [-0.15, 0.15]:
		b.tube(PackedVector3Array([pc + Vector3(x, 0.0, 0.02), pc + Vector3(x, -0.01, 0.06)]), 0.007, 6, CB.M_DARK, C_DARK,
				false, false)
	# Roof scoop, its dark mouth facing forward.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.822, -0.025)), Vector3(0.075, 0.017, 0.08), 0.012, 2, CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.825, -0.104)), Vector3(0.055, 0.009, 0.003), 0.002, 1, CB.M_DARK, C_DARKER)
	# Wing: the plane (in the paint) and its gurney flap.
	sweep(b, PackedVector3Array([Vector3(-0.470, 0.855, 0.0), Vector3(0.470, 0.855, 0.0)]), Vector3.BACK, Vector3.UP,
			PackedVector2Array([Vector2(0.950, 0.000), Vector2(0.970, -0.010), Vector2(1.050, -0.008), Vector2(1.135, 0.022),
			Vector2(1.140, 0.030), Vector2(1.100, 0.030), Vector2(1.000, 0.017), Vector2(0.965, 0.010)]), CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.896, 1.141)), Vector3(0.465, 0.012, 0.003), 0.002, 1, CB.M_DARK, C_DARK)
	# High brake light under the wing; a tow hook at the back.
	var bl: Array = _face_frame(0.0, 0.745, false)
	b.rbox(Transform3D(_facing(bl[1]), bl[0]), Vector3(0.09, 0.006, 0.005), 0.003, 1, CB.M_TAILLAMP, C_TAILLAMP)
	b.tube(_rounded([Vector3(-0.025, 0.215, 1.10), Vector3(-0.025, 0.215, 1.16), Vector3(0.025, 0.215, 1.16),
			Vector3(0.025, 0.215, 1.10)], 0.018), 0.008, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## a gravel tyre round an eight-pair split-spoke rim, the brake disc behind it.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 44, C_RUBBER)
	for row in TREAD_ROWS:
		var odd: bool = row % 2 == 1
		var f: Array = wheel_frame(TAU * (row + (0.5 if odd else 0.0)) / TREAD_ROWS)
		var r_dir: Vector3 = f[0]
		var t_dir: Vector3 = f[1]
		var xs: Array = [-0.064, 0.0, 0.064] if odd else [-0.032, 0.032]
		for x in xs:
			var rc: float = carcass_r(TYRE_HALF, x) - 0.002
			block(b, r_dir * (rc + 0.4 * BLOCK_H) + Vector3(x, 0.0, 0.0), Vector3.RIGHT, t_dir, r_dir, 0.017, BLOCK_H, 0.011,
					0.8, CB.M_RUBBER, C_RUBBER)
		# Shoulder blocks, leaning out over the sidewalls.
		for sx in [-1.0, 1.0]:
			var up: Vector3 = (r_dir * 0.8 + Vector3(0.6 * sx, 0.0, 0.0)).normalized()
			block(b, r_dir * 0.209 + Vector3(0.098 * sx, 0.0, 0.0), up.cross(t_dir).normalized(), t_dir, up, 0.010, 0.011,
					0.011, 0.8, CB.M_RUBBER, C_RUBBER)
	# Rim: the lip, a step in to the spoke face, the barrel.
	wheel_lathe(b, PackedVector2Array([Vector2(0.082, 0.146), Vector2(0.090, 0.152), Vector2(0.097, 0.150),
			Vector2(0.099, 0.142), Vector2(0.094, 0.137)]), 44, CB.M_RIM, C_RIM, "out", Vector3(0.07, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.094, 0.137), Vector2(0.080, 0.135), Vector2(0.072, 0.134)]), 44,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.072, 0.134), Vector2(0.066, 0.141), Vector2(-0.090, 0.142),
			Vector2(-0.100, 0.146)]), 44, CB.M_RIM, C_RIM_BARREL, "in")
	# Brake disc behind the spokes, a dark well behind that.
	b.disc(Vector3(-0.010, 0.0, 0.0), Vector3.RIGHT, 0.122, 0.048, 36, CB.M_ALLOY, C_ALLOY_DARK)
	b.disc(Vector3(-0.026, 0.0, 0.0), Vector3.LEFT, 0.122, 0.048, 36, CB.M_ALLOY, C_ALLOY_DARK)
	wheel_lathe(b, PackedVector2Array([Vector2(-0.026, 0.122), Vector2(-0.010, 0.122)]), 36, CB.M_ALLOY, C_ALLOY_DARK,
			"out", Vector3(-0.018, 0.0, 0.0))
	b.disc(Vector3(-0.055, 0.0, 0.0), Vector3.RIGHT, 0.142, 0.0, 32, CB.M_DARK, C_DARKER)
	# Hub: the centre with five studs and a nut in the accent colour.
	wheel_lathe(b, PackedVector2Array([Vector2(0.040, 0.040), Vector2(0.076, 0.040), Vector2(0.082, 0.034)]), 20,
			CB.M_RIM, C_RIM, "out", Vector3(0.06, 0.0, 0.0))
	b.disc(Vector3(0.082, 0.0, 0.0), Vector3.RIGHT, 0.034, 0.0, 20, CB.M_RIM, C_RIM)
	for k in 5:
		var g: Array = wheel_frame(TAU * k / 5.0)
		bar(b, (g[0] as Vector3) * 0.022 + Vector3(0.086, 0.0, 0.0), Vector3(0.004, 0.004, 0.004), CB.M_CHROME, C_CHROME)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.082, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.012), Vector2(0.008, 0.012),
			Vector2(0.011, 0.007), Vector2(0.012, 0.0)]), 12, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.075, 0.0, 0.0))
	# Eight pairs of split spokes.
	for k in 8:
		for da in [-0.085, 0.085]:
			spoke(b, TAU * k / 8.0 + da, 0.0, 0.036, 0.136, 0.078, 0.072, 0.0045, 0.0065, 0.012, CB.M_RIM, C_RIM)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Side glass in side view (z, y): from the front door's leading edge (behind the mirror's sail)
	# back to the pointed quarter window. Its top is the A-pillar and the roof rail (_upper_s), so
	# the polygon reaches above them.
	shapes["side"] = _inset(PackedVector2Array([Vector2(-0.355, 0.545), Vector2(0.72, 0.600), Vector2(0.80, 0.655),
			Vector2(0.73, 0.82), Vector2(-0.355, 0.82)]), 0.015)
	shapes["tailgate"] = _inset(PackedVector2Array([Vector2(-0.40, 0.42), Vector2(0.40, 0.42), Vector2(0.38, 0.76),
			Vector2(-0.38, 0.76)]), 0.03)
	return shapes


## Where p lies along its section's upper curve, in metres from the side's top: Vector3(s, s where
## the corner's rounding starts, s where it ends). The curve (_upper_segments) is sampled once per
## z, which is one column of the detail map.
func _upper_s(p: Vector3) -> Vector3:
	if not _curve_cache.has(p.z):
		var segs: Array = _upper_segments(p.z, prof["w"].at(p.z), prof["belt"].at(p.z), prof["top"].at(p.z))
		var pts := PackedVector2Array()
		var acc := PackedFloat32Array()
		var marks := PackedFloat32Array()
		for seg in segs:
			for q in (seg as PackedVector2Array):
				if not pts.is_empty() and q.distance_squared_to(pts[pts.size() - 1]) < 1e-14:
					continue
				acc.append(0.0 if pts.is_empty() else acc[acc.size() - 1] + q.distance_to(pts[pts.size() - 1]))
				pts.append(q)
			marks.append(acc[acc.size() - 1])
		_curve_cache[p.z] = [pts, acc, marks]
	var entry: Array = _curve_cache[p.z]
	var pts: PackedVector2Array = entry[0]
	var acc: PackedFloat32Array = entry[1]
	var marks: PackedFloat32Array = entry[2]
	var q := Vector2(absf(p.x), p.y)
	var best := 0.0
	var best_d := 1e9
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var e: Vector2 = pts[k + 1] - a
		var f: float = clampf((q - a).dot(e) / maxf(e.length_squared(), 1e-12), 0.0, 1.0)
		var dd: float = (a + e * f).distance_squared_to(q)
		if dd < best_d:
			best_d = dd
			best = lerpf(acc[k], acc[k + 1], f)
	return Vector3(best, marks[0], marks[1])


## A rounded intersection of two half-planes given as distances (negative inside), corner radius r.
static func _round_and(a: float, b: float, r: float) -> float:
	var q := Vector2(maxf(a + r, 0.0), maxf(b + r, 0.0))
	return q.length() + minf(maxf(a + r, b + r), 0.0) - r


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var black := 0.0
	var szy := Vector2(p.z, p.y)
	var sxy := Vector2(p.x, p.y)
	var side: bool = n.x > 0.3
	# The glass, cut by the greenhouse's corner: the side glass stops short of the corner's rounding
	# (the A-pillar, the roof rail), the windscreen and the rear glass start inboard of it (between
	# the A- and the D-pillars), and each glass is edged by its black seal.
	var below_rail := -1e3
	var ws_d := 1e3
	var rg_d := 1e3
	if p.y > 0.45 and p.z > WS_Z.x - 0.05 and p.z < RG_Z.y + 0.05:
		var u: Vector3 = _upper_s(p)
		below_rail = u.x - (u.y - PILLAR_PAD)
		var inboard: float = (u.z + PILLAR_PAD) - u.x
		ws_d = _round_and(inboard, maxf(WS_Z.x - p.z, p.z - WS_Z.y), 0.03)
		rg_d = _round_and(inboard, maxf(RG_Z.x - p.z, p.z - RG_Z.y), 0.03)
	# Side glass, its seals, the B- and C-pillars in satin black, the front door's vent divider.
	if n.x > 0.2 and p.y > 0.5:
		var d: float = maxf(_sd_rounded(szy, sh["side"]), below_rail)
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.008, fp))
		for pz in [0.215, 0.630]:
			black = maxf(black, _cover(absf(p.z - pz) - 0.02, fp) * _cover(d - 0.008, fp))
		glass *= 1.0 - _cover(absf(p.z - 0.215) - 0.02, fp)
		glass *= 1.0 - _cover(absf(p.z - 0.630) - 0.012, fp)
		black = maxf(black, _cover(absf(p.z + 0.300) - 0.005, fp) * _cover(d - 0.008, fp))
		glass *= 1.0 - _cover(absf(p.z + 0.300) - 0.005, fp)
	# Windscreen and rear glass.
	if n.z < -0.05:
		glass = maxf(glass, _cover(ws_d, fp))
		black = maxf(black, _cover(ws_d - 0.010, fp))
	if n.z > 0.05:
		glass = maxf(glass, _cover(rg_d, fp))
		black = maxf(black, _cover(rg_d - 0.010, fp))
	if n.z > 0.25 and p.z > 0.86:
		gap = maxf(gap, _cover(absf(_sd_rounded(sxy, sh["tailgate"])) - 0.0022, fp))
	if side:
		# Door shut lines from the sill to the window line; the rear door's back edge stops at the arch.
		if p.y > 0.19 and p.y < 0.585:
			for dz in [-0.355, 0.215]:
				gap = maxf(gap, _cover(absf(p.z - dz) - 0.0022, fp))
			if p.y > 0.48:
				gap = maxf(gap, _cover(absf(p.z - 0.640) - 0.0022, fp))
		# Fuel cap on the right rear quarter.
		if p.x > 0.0:
			gap = maxf(gap, _cover(absf(Vector2(p.z - 0.86, p.y - 0.53).length() - 0.03) - 0.002, fp))
	# Bonnet: its shut lines, the cowl, and two louvred vents.
	if n.y > 0.45 and p.z < -0.62:
		gap = maxf(gap, _cover(absf(p.x - 0.405) - 0.002, fp) * float(p.z > -1.06))
		gap = maxf(gap, _cover(absf(p.z + 0.665) - 0.002, fp))
		if p.z > -1.0 and p.z < -0.76 and p.x > 0.14 and p.x < 0.31:
			var vent := _sd_box(Vector2(p.x - 0.225, p.z + 0.88), Vector2(0.07, 0.10)) - 0.01
			var slots: float = absf(fposmod(p.z + 0.98, 0.028) - 0.014) - 0.0055
			black = maxf(black, _cover(vent, fp) * _cover(slots, fp))
			gap = maxf(gap, _cover(absf(vent) - 0.002, fp))
	# Underside, and the arches' ceilings.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, 0.0, black)
