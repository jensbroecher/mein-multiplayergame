# HexapodBuilder.gd
#
# The Hexapod: a six-wheeled exploration rover, an original design. A cab-forward body (a short sloping nose, a tall
# glazed cabin with a roof rack and a light bar, a flat cargo deck behind it) on three axles of the Titan's chassis
# parts: A-arms and big-bore shocks in the accent colour at all six corners, swelling flares over each of the six tall
# chevron tyres on five-spoke beadlock rims. On the deck: a dish aerial on a mast, a tilted solar panel, two strapped
# equipment cases and jerrycans. The middle wheels (EXTRA_WHEELS) are nodes of their own that turn with the rear pair
# (CarAxleFollower.gd: the game drives four wheels).
#
# Built like the Titan (CarDesign's keyed section, KEYS; arches lifted into the shell's bottom round each hub,
# _bot_knots; flares swept along them, _build_flare): its heights are the Titan's, its length a third axle more.
extends "res://CarDesign.gd"

const WHEEL_X := 0.660
const AXLE_F := -0.860
const AXLE_M := 0.0
const AXLE_R := 0.860
const HUB_Y := 0.345               # the tyre's radius over its tread: it stands on y = 0
const ARCH_R := 0.410              # the arches' radius about the hub (8cm over the tyre)
const SILL_Y := 0.500              # the body's bottom between the arches
const END_SILL_Y := 0.585          # and under the nose and the tail
const NOSE_TIP := -1.300
const TAIL_TIP := 1.300

# Half-width of the body's side in plan: pinched at the nose and tail, swelling over the wheels, a
# waist at the doors.
const W_KNOTS := [[-1.30, 0.560], [-1.18, 0.615], [-1.04, 0.645], [1.06, 0.645], [1.20, 0.615], [1.30, 0.600]]

# The section above the side, keyframed along the car. Per row: z; belt (top of the side, where the
# rim's rounding starts); rim_w (the rim, its rounding included: the shelf along the bonnet's edge,
# under the cab, along the bed); wall_dx (how far the wall leans in: the cab's tumblehome); edge (the
# top beside the crown: bonnet, roof, the bed's floor, the tailgate); cx, cy (the corner from the
# wall onto the top: cy > 0 a roof corner, < 0 the bed floor's fillet, 0 flat); crown; the bonnet bulge's half-width and height (it ramps up from the nose
# and drops off at a scoop before the windscreen).
const KEYS := [
	# z       belt   rim_w  wall_dx edge   cx     cy     crown  dome_w dome_h
	[-1.300, 0.750, 0.055, 0.030, 0.800, 0.030, 0.000, 0.012, 0.190, 0.000],
	[-1.200, 0.770, 0.055, 0.030, 0.820, 0.030, 0.000, 0.012, 0.190, 0.000],
	[-1.040, 0.800, 0.055, 0.030, 0.850, 0.030, 0.000, 0.012, 0.215, 0.000],
	[-0.960, 0.815, 0.055, 0.030, 0.865, 0.030, 0.000, 0.012, 0.215, 0.000],
	[-0.935, 0.819, 0.056, 0.042, 0.889, 0.040, 0.014, 0.013, 0.215, 0.000],
	[-0.900, 0.819, 0.056, 0.058, 0.925, 0.050, 0.028, 0.014, 0.215, 0.000],
	[-0.640, 0.819, 0.056, 0.085, 1.140, 0.070, 0.060, 0.018, 0.215, 0.000],
	[-0.600, 0.819, 0.056, 0.085, 1.168, 0.070, 0.060, 0.018, 0.215, 0.000],
	[-0.550, 0.819, 0.056, 0.085, 1.180, 0.070, 0.060, 0.018, 0.215, 0.000],
	[0.100, 0.819, 0.056, 0.085, 1.180, 0.070, 0.060, 0.018, 0.215, 0.000],
	[0.150, 0.819, 0.056, 0.082, 1.150, 0.070, 0.060, 0.018, 0.215, 0.000],
	[0.200, 0.819, 0.055, 0.030, 0.869, 0.030, 0.000, 0.006, 0.215, 0.000],
	[1.200, 0.819, 0.055, 0.030, 0.869, 0.030, 0.000, 0.006, 0.215, 0.000],
	[1.300, 0.810, 0.055, 0.030, 0.860, 0.030, 0.000, 0.006, 0.215, 0.000],
]
const KEY_NAMES := ["belt", "rim_w", "wall_dx", "edge", "cx", "cy", "crown", "dome_w", "dome_h"]
const RIM_R := 0.050               # the rounding of the side's top edge into the bonnet, roof rail and bed

const DECK_Y := 0.869             # the cargo deck's top

const FLARE_OUT := 0.800
const FLARE_EXP := 2.4             # the flare's superelliptic swell: 2 a quarter ellipse, higher squarer

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.22, 0.22, 0.23)
const C_DARK := Color(0.07, 0.07, 0.075)
const C_DARKER := Color(0.035, 0.035, 0.04)
const C_PLASTIC := Color(0.10, 0.10, 0.105)
const C_ALLOY := Color(0.78, 0.79, 0.80)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.6, 0.6, 0.62)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)
const C_REVERSE := Color(0.85, 0.85, 0.82)
const C_STRAP := Color(0.95, 0.45, 0.08)
const C_CAN := Color(0.62, 0.08, 0.05)
const C_PANEL := Color(0.05, 0.09, 0.20)
const C_CASE := Color(0.70, 0.71, 0.72)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.30, "tail_z": 1.30, "belt_y": 0.83, "side_x": 0.645,
	"door_z": -0.53, "door_y": 0.826, "roundel_r": 0.045,
	"hood_z": -1.13, "hood_r": 0.07, "stripe_w": 0.08, "stripe_gap": 0.03,
}
const ANTENNA_POS := Vector3(0.50, 0.866, 1.16)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}
## The middle axle's wheels: [position, the wheel node they turn with].
const EXTRA_WHEELS := {
	"ML": [Vector3(-WHEEL_X, HUB_Y, AXLE_M), "RL"], "MR": [Vector3(WHEEL_X, HUB_Y, AXLE_M), "RR"],
}


func _init() -> void:
	nose_tip = NOSE_TIP
	nose_cap = 0.070
	nose_cap_y = 0.700
	nose_cap_exp = Vector2(4.0, 5.0)
	tail_tip = TAIL_TIP
	tail_cap = 0.060
	tail_cap_y = 0.700
	tail_cap_exp = Vector2(4.0, 5.0)
	# Bottom, bottom corner, side; rim, wall, corner, outer top, bulge step, bulge top.
	segment_counts = [2, 5, 5, 7, 6, 5, 4, 4, 4]
	half_ring = 42
	bottom_radius = 0.06
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[4] + key[7] + key[9]])
	setup_shell(knots)


## The shell's bottom along the car: the sills, lifted over each wheel in a circle round the hub,
## the two blended over a few centimetres so the arch's foot is rounded, not a notch.
static func _bot_knots() -> Array:
	var out := []
	var n := 260
	for k in n + 1:
		var z: float = lerpf(NOSE_TIP, TAIL_TIP, float(k) / n)
		var sill: float = SILL_Y if z > AXLE_F and z < AXLE_R else END_SILL_Y
		var arch := 0.0
		for axle in [AXLE_F, AXLE_M, AXLE_R]:
			var dz: float = z - axle
			if absf(dz) < ARCH_R:
				arch = maxf(arch, HUB_Y + sqrt(ARCH_R * ARCH_R - dz * dz))
		var kk := 0.035
		out.append([z, 0.5 * (sill + arch + sqrt((sill - arch) * (sill - arch) + kk * kk)) - kk * 0.5])
	return out


## Above the side: the rim (the side's top edge rounding over onto a flat rim_w wide), the wall
## (from the rim's inner edge to B), the corner (B onto the top at C), then the top: crowned toward
## the centre line, with the bonnet's bulge raised on it by a rounded step at dome_w.
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
	var xr: float = minf(dome_w + 0.04, x0 - 0.02)
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


## A swelling flare's section in (x, height above the lip): [skin, liner]. The skin starts at a
## rolled lip out over the tyre and rises in a superelliptic quarter round to the top at the body
## (x_in, d), level there so it runs on into the bonnet's (or the bed's) shoulder; the liner runs
## flat from the lip in to the body side.
func _fender_section(xo: float, x_in: float, d: float) -> Array:
	var skin := [Vector2(xo - 0.016, 0.0), Vector2(xo - 0.004, 0.006)]
	for k in 13:
		var a: float = PI * 0.5 * k / 12.0
		skin.append(Vector2(x_in + (xo - x_in) * pow(cos(a), 2.0 / FLARE_EXP),
				0.016 + (d - 0.016) * pow(sin(a), 2.0 / FLARE_EXP)))
	return [skin, [Vector2(xo - 0.016, 0.0), Vector2(x_in + 0.037, 0.0)]]


## The outline of a wheel arch as a flare's lip: the shell's bottom from the sill at the door end
## round over the wheel to the outer end, as 18 points spaced along it.
func _arch_lip(z_door: float, z_end: float) -> Array:
	var dense := PackedVector2Array()
	for k in 201:
		var z: float = lerpf(z_door, z_end, k / 200.0)
		dense.append(Vector2(z, prof["bot"].at(z)))
	var pts: PackedVector2Array = CB.resample(dense, 18, 0.0)
	var lip := []
	for p in pts:
		lip.append([p.x, p.y])
	return lip


## One flare (right side; the caller mirrors it), swept along a wheel-arch lip [[z, y], ...] from the
## door end round to the outer end: CarDesign.build_fender's sweep, but the section shrinks into the
## body over `taper_door` and `taper_end` metres of the spine (an elliptical taper), so the swell
## rises out of the door and runs out into the nose or the tail instead of ending in a flat cap.
func _build_flare(b, lip: Array, hub_z: float, d: float, taper_door: float, taper_end: float) -> void:
	var spine: PackedVector2Array = _spine(lip, 48)
	var n: int = spine.size()
	var acc := PackedFloat32Array([0.0])
	for k in range(1, n):
		acc.append(acc[k - 1] + spine[k].distance_to(spine[k - 1]))
	var total: float = acc[n - 1]
	var skin_rows := []
	var liner_rows := []
	for k in n:
		var t2: Vector2 = (spine[mini(k + 1, n - 1)] - spine[maxi(k - 1, 0)]).normalized()
		var n2 := Vector2(t2.y, -t2.x)
		if n2.dot(spine[k] - Vector2(hub_z, HUB_Y)) < 0.0:
			n2 = -n2
		var x_in: float = prof["w"].at(spine[k].x) - 0.035
		var sc: float = minf(_taper_scale(acc[k], taper_door), _taper_scale(total - acc[k], taper_end))
		# What the section shrinks toward: inside the body side, a little up from the lip.
		var into := Vector2(x_in - 0.03, d * 0.3)
		var rows := []
		for profile in _fender_section(FLARE_OUT, x_in, d):
			var row := PackedVector3Array()
			for p in profile:
				var q: Vector2 = into + (p - into) * sc
				row.append(Vector3(q.x, spine[k].y + q.y * n2.y, spine[k].x + q.y * n2.x))
			rows.append(row)
		skin_rows.append(rows[0])
		liner_rows.append(rows[1])
	var base: int = b.vertex_count()
	var ibase: int = b.index_count()
	b.grid(skin_rows, CB.M_PAINT, Color(1, 1, 1), false, false)
	# The skin faces outward: over the middle of the arch, its outermost point's normal is along +x.
	var mid: int = n / 2
	var row_m: PackedVector3Array = skin_rows[mid]
	var far := 0
	for j in row_m.size():
		if row_m[j].x > row_m[far].x:
			far = j
	if b._n[base + mid * row_m.size() + far].dot(Vector3.RIGHT) < 0.0:
		b.flip(base, ibase)
	base = b.vertex_count()
	ibase = b.index_count()
	b.grid(liner_rows, CB.M_DARK, C_DARKER, false, false)
	b.orient_toward(base, ibase, Vector3.DOWN)


## 1 beyond `length` from an end, falling to 0 at the end along a quarter ellipse.
static func _taper_scale(dist: float, length: float) -> float:
	if length <= 0.0 or dist >= length:
		return 1.0
	var t: float = 1.0 - dist / length
	return sqrt(maxf(1.0 - t * t, 0.0))


## A rounded box set on the nose's (front) or the tail's face at (x, y), turned with the face's
## normal there and `out` metres proud of it: lamps and their surrounds on the rounded corners.
func _on_face(b, x: float, y: float, front: bool, h: Vector3, r: float, mat: int, col: Color, out: float) -> void:
	var f: Array = face_frame(x, y, front)
	var nrm: Vector3 = f[1]
	b.rbox(Transform3D(facing(nrm), (f[0] as Vector3) + nrm * out), h, r, 2, mat, col)


## Body mesh: shell, flares, lamps, mirrors, the chassis and its suspension, the ends, the roof rack and the deck's load.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_build_flare(b, _arch_lip(-0.435, -1.250), AXLE_F, 0.082, 0.12, 0.10)
	_build_flare(b, _arch_lip(-0.425, 0.425), AXLE_M, 0.088, 0.12, 0.12)
	_build_flare(b, _arch_lip(0.435, 1.250), AXLE_R, 0.088, 0.12, 0.10)
	_side_parts(b)
	_suspension(b, AXLE_F, 1.0)
	_suspension(b, AXLE_M, 1.0)
	_suspension(b, AXLE_R, -1.0)
	b.mirror_x(v0, i0)
	_front_parts(b)
	_rear_parts(b)
	_chassis(b)
	_roof_rack(b)
	_deck_load(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inboard of each arch, so it doesn't look through the car. They stop
	# short of the nose and the tail, or they stood out of the end faces.
	for arch in [[nose_tip + 0.07, tail_tip - 0.07]]:
		b.rbox(Transform3D(Basis(), Vector3(0.222, 0.635, (arch[0] + arch[1]) * 0.5)),
				Vector3(0.004, 0.140, (arch[1] - arch[0]) * 0.5), 0.003, 1, CB.M_DARK, C_DARKER)
	# Mirror on a short stalk at the foot of the A-pillar.
	b.tube(PackedVector3Array([Vector3(0.560, 0.878, -0.912), Vector3(0.612, 0.905, -0.908)]), 0.008, 6, CB.M_DARK,
			C_DARK, false, true)
	b.rbox(Transform3D(Basis(Vector3.UP, -0.15), Vector3(0.640, 0.912, -0.904)), Vector3(0.045, 0.032, 0.012), 0.010, 2,
			CB.M_DARK, C_PLASTIC)
	# A slim LED headlamp in a dark housing on the nose's rounded corner, turned with it; an amber
	# marker under it.
	_on_face(b, 0.400, 0.742, true, Vector3(0.082, 0.026, 0.010), 0.008, CB.M_DARK, C_DARK, 0.0)
	_on_face(b, 0.400, 0.744, true, Vector3(0.070, 0.014, 0.004), 0.004, CB.M_HEADLAMP, Color(1, 1, 1), 0.008)
	_on_face(b, 0.440, 0.690, true, Vector3(0.040, 0.009, 0.005), 0.004, CB.M_TAILLAMP, C_AMBER, 0.003)
	# Taillamps wrapping round the tail's corners: a tall lens in a dark surround, the reverse lamp
	# under it.
	_on_face(b, 0.485, 0.735, false, Vector3(0.050, 0.072, 0.010), 0.010, CB.M_DARK, C_DARK, 0.0)
	_on_face(b, 0.485, 0.752, false, Vector3(0.040, 0.048, 0.004), 0.004, CB.M_TAILLAMP, C_TAILLAMP, 0.008)
	_on_face(b, 0.485, 0.684, false, Vector3(0.040, 0.011, 0.004), 0.004, CB.M_TAILLAMP, C_REVERSE, 0.008)
	# Body posts: from the chassis up into the body, front and rear; the front ones come through the
	# bonnet, each held by an R-clip.
	for z in [-1.16, 1.18]:
		b.tube(PackedVector3Array([Vector3(0.10, 0.28, z), Vector3(0.10, END_SILL_Y + 0.01, z)]), 0.010, 8, CB.M_DARK, C_DARK,
				false, false)
	var py: float = top_y(0.10, -1.16)
	b.tube(PackedVector3Array([Vector3(0.10, py - 0.01, -1.16), Vector3(0.10, py + 0.026, -1.16)]), 0.0075, 8, CB.M_DARK,
			C_DARK, false, true)
	_r_clip(b, Vector3(0.10, py + 0.016, -1.16), py + 0.005)


## An R-clip through a body post at `pin` (its straight leg along z), the bent leg looping out
## toward +x and back along the body's top at `rest_y`.
func _r_clip(b, pin: Vector3, rest_y: float) -> void:
	var path := PackedVector3Array([pin + Vector3(0.0, 0.0, -0.022), pin + Vector3(0.0, 0.0, 0.016)])
	for k in range(1, 8):
		var a: float = PI * k / 8.0
		path.append(Vector3(pin.x + 0.011 - 0.011 * cos(a), lerpf(pin.y, rest_y, k / 8.0), pin.z + 0.016 + 0.011 * sin(a)))
	path.append(Vector3(pin.x + 0.026, rest_y, pin.z - 0.006))
	path.append(Vector3(pin.x + 0.020, rest_y, pin.z - 0.030))
	b.tube(path, 0.0022, 6, CB.M_CHROME, C_CHROME, true, true)


## One corner's suspension (right side): A-arms from the chassis to the hub carrier, a CV driveshaft
## from the gearbox, a big-bore shock from the lower arm up to its tower under the arch. `fz` puts
## the shock on the side of the axle toward the middle of the car.
func _suspension(b, axle_z: float, fz: float) -> void:
	var kx := 0.565
	# Lower arm: two thick legs from pivots on the chassis to the carrier's foot; upper arm above.
	for dz in [-0.095, 0.095]:
		b.tube(PackedVector3Array([Vector3(0.135, 0.215, axle_z + dz), Vector3(kx - 0.012, 0.262, axle_z)]), 0.017, 8,
				CB.M_DARK, C_PLASTIC, true, true)
		b.tube(PackedVector3Array([Vector3(0.165, 0.380, axle_z + dz * 0.6), Vector3(kx - 0.015, 0.428, axle_z)]), 0.011,
				6, CB.M_DARK, C_DARK, true, true)
	# A web across the lower arm, under the shock's foot.
	b.rbox(Transform3D(Basis(Vector3.BACK, 0.11), Vector3(0.40, 0.245, axle_z)), Vector3(0.10, 0.007, 0.075), 0.005, 1,
			CB.M_DARK, C_PLASTIC)
	# Hub carrier, the stub axle out to the wheel.
	b.rbox(Transform3D(Basis(), Vector3(kx, HUB_Y, axle_z)), Vector3(0.018, 0.098, 0.034), 0.010, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, axle_z), Vector3(0.62, HUB_Y, axle_z)]), 0.017, 10, CB.M_ALLOY,
			C_ALLOY_DARK, false, true)
	# CV driveshaft from the gearbox, its boots at both ends.
	var d0 := Vector3(0.115, 0.300, axle_z)
	var d1 := Vector3(kx - 0.02, HUB_Y, axle_z)
	b.tube(PackedVector3Array([d0, d1]), 0.010, 8, CB.M_ALLOY, C_ALLOY_DARK, false, false)
	for t in [0.06, 0.94]:
		b.tube(PackedVector3Array([d0.lerp(d1, t - 0.05), d0.lerp(d1, t + 0.05)]), 0.019, 10, CB.M_DARK, C_DARKER,
				true, true, PackedFloat32Array([0.013, 0.019]) if t < 0.5 else PackedFloat32Array([0.019, 0.013]))
	# The shock and its tower.
	# Nearly upright, just inboard of the tyre, so it shows in the gap under the flare.
	var lo := Vector3(0.455, 0.258, axle_z + 0.075 * fz)
	var hi := Vector3(0.345, 0.705, axle_z + 0.090 * fz)
	_big_shock(b, lo, hi)
	b.rbox(Transform3D(Basis(), hi + Vector3(-0.025, 0.030, 0.0)), Vector3(0.075, 0.012, 0.045), 0.006, 1, CB.M_DARK,
			C_DARK)


## A big-bore shock from `lo` (the shaft's eyelet) to `hi`: a chrome shaft, a fat body in the
## accent colour (M_ANODISED) with a finned cap, a dark spring round it on a collar.
func _big_shock(b, lo: Vector3, hi: Vector3) -> void:
	var ax: Vector3 = (hi - lo).normalized()
	var body_lo: Vector3 = lo.lerp(hi, 0.40)
	b.tube(PackedVector3Array([lo, body_lo]), 0.012, 8, CB.M_CHROME, C_CHROME, true, false)
	b.tube(PackedVector3Array([body_lo, hi - ax * 0.03]), 0.034, 16, CB.M_ANODISED, Color(1, 1, 1), true, false)
	# Cap: a wider ring, then the eyelet block.
	b.tube(PackedVector3Array([hi - ax * 0.03, hi - ax * 0.005]), 0.039, 16, CB.M_ANODISED, Color(1, 1, 1), true, true)
	b.rbox(Transform3D(facing(Vector3.RIGHT), hi + ax * 0.008), Vector3(0.018, 0.016, 0.022), 0.006, 1,
			CB.M_DARK, C_DARK)
	b.rbox(Transform3D(facing(Vector3.RIGHT), lo - ax * 0.006), Vector3(0.015, 0.014, 0.020), 0.006, 1,
			CB.M_DARK, C_DARK)
	# Lower spring seat on the shaft, the spring up to the body's collar.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	var seat: Vector3 = lo.lerp(hi, 0.10)
	b.lathe(seat, ax, PackedVector2Array([Vector2(-0.005, 0.0), Vector2(-0.005, 0.050), Vector2(0.005, 0.050),
			Vector2(0.005, 0.0)]), 16, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, seat)
	b.spring(lo.lerp(hi, 0.12), lo.lerp(hi, 0.72), 0.046, 0.0065, 6.0, CB.M_DARK, C_DARK)


## The nose: a slatted grille, the bumper with its hoop, tow hooks and skid plate.
func _front_parts(b) -> void:
	var gz: float = nose_tip - 0.002
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.700, gz + 0.006)), Vector3(0.255, 0.064, 0.012), 0.010, 2, CB.M_DARK,
			C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.700, gz - 0.006)), Vector3(0.228, 0.048, 0.003), 0.003, 1, CB.M_DARK,
			C_DARKER)
	for k in 4:
		bar(b, Vector3(0.0, 0.664 + 0.024 * k, gz - 0.010), Vector3(0.222, 0.0055, 0.004), CB.M_ALLOY, C_ALLOY_DARK)
	bar(b, Vector3(0.0, 0.700, gz - 0.011), Vector3(0.006, 0.048, 0.004), CB.M_ALLOY, C_ALLOY_DARK)
	# Bumper: a deep beam with its wings swept back, a hoop over it, a skid plate under it back to
	# the chassis, mounts.
	var bz: float = nose_tip - 0.055
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.468, bz)), Vector3(0.330, 0.058, 0.048), 0.022, 3, CB.M_DARK, C_PLASTIC)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(Vector3.UP, 0.55 * sx), Vector3(0.375 * sx, 0.468, bz + 0.040)),
				Vector3(0.075, 0.050, 0.040), 0.020, 3, CB.M_DARK, C_PLASTIC)
		b.rbox(Transform3D(Basis(), Vector3(0.16 * sx, 0.400, nose_tip + 0.04)), Vector3(0.025, 0.030, 0.070), 0.008, 1, CB.M_DARK,
				C_DARK)
		_tow_hook(b, 0.24 * sx, bz - 0.04, -1.0)
	b.tube(_rounded([Vector3(-0.20, 0.515, bz - 0.020), Vector3(-0.17, 0.610, bz - 0.040),
			Vector3(0.17, 0.610, bz - 0.040), Vector3(0.20, 0.515, bz - 0.020)], 0.06), 0.016, 10, CB.M_DARK, C_PLASTIC,
			false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.600, bz - 0.040)), Vector3(0.10, 0.022, 0.012), 0.008, 2, CB.M_DARK,
			C_PLASTIC)
	# Skid plate: from under the bumper's beam, falling back to the chassis.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.55), Vector3(0.0, 0.335, nose_tip + 0.085)), Vector3(0.20, 0.010, 0.15), 0.008, 1,
			CB.M_DARK, C_PLASTIC)


## A tow hook (accent colour) from a bumper's face at (x, z), looping out along `dir` (-1 forward,
## 1 back).
func _tow_hook(b, x: float, z: float, dir: float) -> void:
	b.tube(_rounded([Vector3(x, 0.49, z), Vector3(x, 0.49, z + 0.045 * dir), Vector3(x, 0.43, z + 0.045 * dir),
			Vector3(x, 0.43, z + 0.005 * dir)], 0.02), 0.007, 8, CB.M_ANODISED, Color(1, 1, 1), true, true)


## The tail: the tailgate's seams and handle, the bumper with a step plate and tow hooks, the skid
## plate.
func _rear_parts(b) -> void:
	# Tailgate: its seams standing a hair proud of the tail's face, the handle in a dark recess.
	var sz: float = tail_tip + 0.0005
	for y in [0.615, 0.800]:
		bar(b, Vector3(0.0, y, sz), Vector3(0.36, 0.0022, 0.0025), CB.M_DARK, C_DARKER)
	for x in [-0.36, 0.36]:
		bar(b, Vector3(x, 0.7075, sz), Vector3(0.0022, 0.0925, 0.0025), CB.M_DARK, C_DARKER)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.772, tail_tip + 0.002)), Vector3(0.060, 0.013, 0.005), 0.004, 1,
			CB.M_DARK, C_DARKER)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.768, tail_tip + 0.006)), Vector3(0.048, 0.005, 0.004), 0.003, 1,
			CB.M_DARK, C_DARK)
	var bz: float = tail_tip + 0.055
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.500, bz)), Vector3(0.360, 0.055, 0.048), 0.022, 3, CB.M_DARK, C_PLASTIC)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.557, bz + 0.006)), Vector3(0.20, 0.004, 0.032), 0.003, 1, CB.M_ALLOY,
			C_ALLOY)
	for k in 7:
		bar(b, Vector3(-0.15 + 0.05 * k, 0.5625, bz + 0.006), Vector3(0.012, 0.0015, 0.026), CB.M_ALLOY, C_ALLOY_DARK)
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(Vector3.UP, -0.5 * sx), Vector3(0.39 * sx, 0.500, bz - 0.035)),
				Vector3(0.06, 0.048, 0.036), 0.018, 3, CB.M_DARK, C_PLASTIC)
		b.rbox(Transform3D(Basis(), Vector3(0.16 * sx, 0.430, tail_tip - 0.01)), Vector3(0.025, 0.030, 0.06), 0.008, 1, CB.M_DARK,
				C_DARK)
		_tow_hook(b, 0.26 * sx, bz + 0.04, 1.0)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0.0, 0.365, tail_tip - 0.065)), Vector3(0.19, 0.010, 0.14), 0.008, 1,
			CB.M_DARK, C_PLASTIC)


## The cabin's roof rack: two rails on four feet with cross bars, a light bar across its front, two spot lamps.
func _roof_rack(b) -> void:
	var z0 := -0.50
	var z1 := 0.06
	var rx := 0.40
	for sx in [-1.0, 1.0]:
		var ry: float = top_y(rx, -0.2) + 0.055
		b.tube(_rounded([Vector3(sx * rx, top_y(rx, z0) - 0.004, z0), Vector3(sx * rx, ry, z0 + 0.05), Vector3(sx * rx, ry, z1 - 0.05),
				Vector3(sx * rx, top_y(rx, z1) - 0.004, z1)], 0.03), 0.012, 8, CB.M_DARK, C_DARK, false, false)
	var ry2: float = top_y(rx, -0.2) + 0.055
	for z in [-0.40, -0.22, -0.04]:
		b.tube(PackedVector3Array([Vector3(-rx, ry2, z), Vector3(rx, ry2, z)]), 0.009, 8, CB.M_DARK, C_DARK, false, false)
	# The light bar on the rack's front, lenses toward the nose.
	var lz: float = z0 + 0.03
	var ly: float = ry2 + 0.032
	b.rbox(Transform3D(Basis(), Vector3(0.0, ly, lz)), Vector3(0.330, 0.024, 0.024), 0.010, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(), Vector3(0.0, ly, lz - 0.022)), Vector3(0.316, 0.014, 0.004), 0.003, 1, CB.M_HEADLAMP,
			Color(1, 1, 1))
	for k in 5:
		bar(b, Vector3(-0.252 + 0.126 * k, ly, lz - 0.027), Vector3(0.003, 0.015, 0.002), CB.M_DARK, C_DARK)
	# A rolled tarp and a case lashed on the rack.
	b.tube(PackedVector3Array([Vector3(-0.30, ry2 + 0.045, -0.13), Vector3(0.30, ry2 + 0.045, -0.13)]), 0.040, 12, CB.M_DARK,
			Color(0.30, 0.34, 0.24), true, true)
	for x in [-0.18, 0.18]:
		b.oval_tube(_ring(Vector3(x, ry2 + 0.045, -0.13), 0.043), 0.012, 0.002, Vector3.RIGHT, 6, CB.M_DARK, C_STRAP, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, ry2 + 0.050, -0.31)), Vector3(0.20, 0.040, 0.060), 0.012, 2, CB.M_ALLOY, C_CASE)


## A ring of points round the x axis at c (a strap round a roll).
func _ring(c: Vector3, r: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in 17:
		var a: float = TAU * k / 16.0
		out.append(c + Vector3(0.0, cos(a) * r, sin(a) * r))
	return out


## What rides on the deck: a dish aerial on a mast behind the cabin, a solar panel tilted on a frame, two equipment
## cases strapped down, jerrycans, a rail round the deck's edge.
func _deck_load(b) -> void:
	# The rail: stanchions and a tube along each side and across the tail.
	var rx := 0.555
	var rail: PackedVector3Array = _rounded([Vector3(-rx, DECK_Y + 0.10, 0.30), Vector3(-rx, DECK_Y + 0.10, 1.22),
			Vector3(rx, DECK_Y + 0.10, 1.22), Vector3(rx, DECK_Y + 0.10, 0.30)], 0.06)
	b.tube(rail, 0.010, 8, CB.M_DARK, C_DARK, true, true)
	for p in [Vector3(-rx, 0, 0.30), Vector3(-rx, 0, 0.76), Vector3(-rx, 0, 1.16), Vector3(rx, 0, 0.30), Vector3(rx, 0, 0.76),
			Vector3(rx, 0, 1.16), Vector3(0, 0, 1.22)]:
		b.tube(PackedVector3Array([Vector3(p.x, DECK_Y - 0.004, p.z), Vector3(p.x, DECK_Y + 0.10, p.z)]), 0.008, 6, CB.M_DARK, C_DARK,
				false, false)
	# The dish: a mast on a foot, a yoke, the dish tipped back and turned a little, its feed on three struts.
	var foot := Vector3(0.30, DECK_Y, 0.40)
	b.rbox(Transform3D(Basis(), foot + Vector3(0, 0.012, 0)), Vector3(0.05, 0.012, 0.05), 0.006, 1, CB.M_DARK, C_DARK)
	var top := foot + Vector3(0, 0.46, 0)
	b.tube(PackedVector3Array([foot, top]), 0.014, 10, CB.M_ALLOY, C_ALLOY_DARK, false, true)
	var axis: Vector3 = Vector3(0.25, 0.75, -0.55).normalized()
	var hub: Vector3 = top + axis * 0.03
	b.rbox(Transform3D(facing(axis), top + axis * 0.012), Vector3(0.03, 0.03, 0.018), 0.008, 1, CB.M_DARK, C_DARK)
	var r := 0.21
	var depth := 0.075
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for k in 9:
		var t: float = k / 8.0
		inner.append(Vector2(depth * t * t, r * t))
		outer.append(Vector2(depth * t * t - 0.008, r * t))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(hub, axis, inner, 28, CB.M_ALLOY, C_ALLOY)
	b.orient_toward(vb, ib, axis)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(hub, axis, outer, 28, CB.M_ALLOY, C_ALLOY_DARK)
	b.orient_toward(vb, ib, -axis)
	# Its rim.
	var side: Vector3 = axis.cross(Vector3.UP).normalized()
	var up2: Vector3 = side.cross(axis).normalized()
	var ring := PackedVector3Array()
	for k in 29:
		var a: float = TAU * k / 28.0
		ring.append(hub + axis * depth + (side * cos(a) + up2 * sin(a)) * r)
	b.tube(ring, 0.006, 6, CB.M_DARK, C_DARK, false, false)
	var feed: Vector3 = hub + axis * 0.20
	for k in 3:
		var a: float = TAU * k / 3.0 + 0.5
		b.tube(PackedVector3Array([hub + axis * depth * 0.6 + (side * cos(a) + up2 * sin(a)) * r * 0.78, feed]), 0.004, 5, CB.M_DARK,
				C_DARK, false, false)
	b.tube(PackedVector3Array([feed - axis * 0.03, feed + axis * 0.012]), 0.017, 10, CB.M_ANODISED, Color(1, 1, 1), true, true)
	# The solar panel: on a frame along the left side, tilted toward it, cells divided by alloy lines.
	var pc := Vector3(-0.30, DECK_Y + 0.17, 0.52)
	var pb := Basis(Vector3.BACK, 0.42)
	b.rbox(Transform3D(pb, pc), Vector3(0.20, 0.008, 0.20), 0.004, 1, CB.M_ALLOY, C_ALLOY_DARK)
	b.rbox(Transform3D(pb, pc + pb * Vector3(0, 0.009, 0)), Vector3(0.19, 0.002, 0.19), 0.002, 1, CB.M_DARK, C_PANEL)
	for k in 3:
		b.rbox(Transform3D(pb, pc + pb * Vector3(-0.095 + 0.095 * k, 0.0115, 0.0)), Vector3(0.0025, 0.0012, 0.19), 0.0005, 1, CB.M_ALLOY, C_ALLOY)
		b.rbox(Transform3D(pb, pc + pb * Vector3(0.0, 0.0115, -0.095 + 0.095 * k)), Vector3(0.19, 0.0012, 0.0025), 0.0005, 1, CB.M_ALLOY, C_ALLOY)
	for dz in [-0.15, 0.15]:
		b.tube(PackedVector3Array([Vector3(-0.44, DECK_Y - 0.004, pc.z + dz), pc + pb * Vector3(-0.15, -0.008, dz)]), 0.007, 6,
				CB.M_DARK, C_DARK, false, false)
		b.tube(PackedVector3Array([Vector3(-0.14, DECK_Y - 0.004, pc.z + dz), pc + pb * Vector3(0.15, -0.008, dz)]), 0.007, 6,
				CB.M_DARK, C_DARK, false, false)
	# Two equipment cases across the rear deck, each with corner guards, latches and a strap over it.
	for c in [[Vector3(-0.22, DECK_Y, 0.98), Vector3(0.20, 0.085, 0.13), C_CASE], [Vector3(0.26, DECK_Y, 0.92), Vector3(0.15, 0.11, 0.15),
			Color(0.85, 0.48, 0.10)]]:
		var cc: Vector3 = c[0]
		var ch: Vector3 = c[1]
		b.rbox(Transform3D(Basis(), cc + Vector3(0, ch.y, 0)), ch, 0.012, 2, CB.M_DARK, c[2])
		b.rbox(Transform3D(Basis(), cc + Vector3(0, ch.y * 1.25, 0)), Vector3(ch.x + 0.003, 0.004, ch.z + 0.003), 0.002, 1, CB.M_DARK,
				C_DARK)
		for sx in [-0.5, 0.5]:
			b.rbox(Transform3D(Basis(), cc + Vector3(ch.x * sx, ch.y * 1.25, -ch.z - 0.003)), Vector3(0.014, 0.014, 0.003), 0.002, 1,
					CB.M_ALLOY, C_ALLOY)
		var strap: PackedVector3Array = _rounded([Vector3(cc.x, DECK_Y + 0.003, cc.z - ch.z - 0.03), Vector3(cc.x, DECK_Y + ch.y * 2.0 + 0.004, cc.z - ch.z - 0.004),
				Vector3(cc.x, DECK_Y + ch.y * 2.0 + 0.004, cc.z + ch.z + 0.004), Vector3(cc.x, DECK_Y + 0.003, cc.z + ch.z + 0.03)], 0.015)
		b.oval_tube(strap, 0.015, 0.0022, Vector3.RIGHT, 6, CB.M_DARK, C_STRAP, false)
	# Jerrycans against the cabin's back on the right.
	for cz in [0.300]:
		for cx in [0.42, 0.52]:
			_jerrycan(b, Vector3(cx, DECK_Y, cz))


## A jerrycan standing on the bed's floor at `foot`: a rounded body with a pressed band round it, a
## three-legged handle along its top and a spout cap at one corner.
func _jerrycan(b, foot: Vector3) -> void:
	var h := Vector3(0.042, 0.085, 0.064)
	var c: Vector3 = foot + Vector3(0.0, h.y, 0.0)
	b.rbox(Transform3D(Basis(), c), h, 0.012, 2, CB.M_DARK, C_CAN)
	b.rbox(Transform3D(Basis(), c + Vector3(0.0, 0.010, 0.0)), Vector3(h.x + 0.003, 0.007, h.z + 0.003), 0.004, 1,
			CB.M_DARK, C_CAN.darkened(0.25))
	var ty: float = c.y + h.y
	b.tube(_rounded([Vector3(c.x, ty, c.z - 0.045), Vector3(c.x, ty + 0.022, c.z - 0.035),
			Vector3(c.x, ty + 0.022, c.z + 0.020), Vector3(c.x, ty, c.z + 0.030)], 0.01), 0.006, 6, CB.M_DARK, C_CAN, false,
			false)
	b.tube(PackedVector3Array([Vector3(c.x, ty, c.z - 0.010), Vector3(c.x, ty + 0.022, c.z - 0.010)]), 0.005, 6,
			CB.M_DARK, C_CAN, false, false)
	b.tube(PackedVector3Array([Vector3(c.x, ty - 0.004, c.z + 0.046), Vector3(c.x, ty + 0.016, c.z + 0.048)]), 0.012, 10,
			CB.M_DARK, C_DARK, false, true)


## The chassis tub, the gearboxes, the centre driveshaft.
func _chassis(b) -> void:
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.235, 0.0)), Vector3(0.135, 0.045, 1.06), 0.020, 2, CB.M_DARK, C_PLASTIC)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.195, 0.0)), Vector3(0.10, 0.008, 1.00), 0.005, 1, CB.M_ALLOY, C_ALLOY_DARK)
	for az in [AXLE_F, AXLE_M, AXLE_R]:
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.305, az)), Vector3(0.115, 0.075, 0.085), 0.035, 3, CB.M_DARK, C_DARK)
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.305, az - 0.088 * (signf(az) if az != 0.0 else 1.0))), Vector3(0.060, 0.045, 0.006), 0.020, 2,
				CB.M_ANODISED, Color(1, 1, 1))
	b.tube(PackedVector3Array([Vector3(0.0, 0.30, AXLE_F + 0.09), Vector3(0.0, 0.30, AXLE_R - 0.09)]), 0.014, 10,
			CB.M_ALLOY, C_ALLOY_DARK, false, false)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1): a
## tall monster-truck tyre with chevron tread, shoulder blocks and sidewall lugs, round a split
## six-spoke beadlock rim with an accent hex hub nut.
func build_wheel(b, side: float) -> void:
	var half := [[-0.138, 0.196], [-0.147, 0.208], [-0.153, 0.230], [-0.1545, 0.258], [-0.151, 0.284],
		[-0.142, 0.303], [-0.124, 0.316], [-0.085, 0.3235], [-0.030, 0.326]]
	tyre(b, half, 52, C_RUBBER)
	var n := 15
	for k in n:
		for row in 2:
			var f: Array = wheel_frame(TAU * (k + 0.5 * row) / n)
			var r: Vector3 = f[0]
			var t: Vector3 = f[1]
			var sx: float = -1.0 if row == 0 else 1.0
			# Chevron half across the middle.
			var across: Vector3 = (Vector3.RIGHT + t * 0.36 * sx).normalized()
			block(b, r * (0.326 + 0.4 * 0.019) + Vector3(0.050 * sx, 0.0, 0.0), across, t, r, 0.050, 0.019, 0.027, 0.85,
					CB.M_RUBBER, C_RUBBER)
			# Shoulder block on the other side.
			var rs: float = carcass_r(half, 0.118)
			block(b, r * (rs + 0.4 * 0.019) + Vector3(-0.118 * sx, 0.0, 0.0), Vector3.RIGHT, t, r, 0.036, 0.019, 0.036,
					0.85, CB.M_RUBBER, C_RUBBER)
			# Sidewall lug below it.
			var up: Vector3 = (r * 0.70 + Vector3(-0.71 * sx, 0.0, 0.0)).normalized()
			block(b, r * 0.293 + Vector3(-0.145 * sx, 0.0, 0.0), up.cross(t).normalized(), t, up, 0.018, 0.024, 0.030,
					0.8, CB.M_RUBBER, C_RUBBER)
	# Rim: the beadlock ring with its bolts, the lip and barrel.
	wheel_lathe(b, PackedVector2Array([Vector2(0.128, 0.205), Vector2(0.139, 0.207), Vector2(0.146, 0.202),
			Vector2(0.147, 0.176), Vector2(0.141, 0.169)]), 52, CB.M_RIM, C_RIM, "out", Vector3(0.09, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.141, 0.169), Vector2(0.124, 0.164), Vector2(0.106, 0.153)]), 52,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.106, 0.153), Vector2(0.094, 0.168), Vector2(-0.128, 0.180),
			Vector2(-0.138, 0.196)]), 52, CB.M_RIM, C_RIM_BARREL, "in")
	for k in 18:
		var f: Array = wheel_frame(TAU * (k + 0.5) / 18.0)
		bar(b, (f[0] as Vector3) * 0.188 + Vector3(0.148, 0.0, 0.0), Vector3(0.003, 0.005, 0.005), CB.M_CHROME, C_CHROME)
	# Back wall behind the spokes, the hub, six split spokes.
	b.disc(Vector3(0.05, 0.0, 0.0), Vector3.RIGHT, 0.162, 0.03, 32, CB.M_DARK, C_DARKER)
	wheel_lathe(b, PackedVector2Array([Vector2(0.075, 0.060), Vector2(0.110, 0.060), Vector2(0.115, 0.053)]), 24,
			CB.M_RIM, C_RIM, "out", Vector3(0.095, 0.0, 0.0))
	for k in 5:
		spoke(b, TAU * k / 5.0, 0.05, 0.052, 0.160, 0.110, 0.104, 0.024, 0.030, 0.014, CB.M_RIM, C_RIM)
	# Hex hub nut in the accent colour, a chrome axle end in it.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.112, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.040), Vector2(0.026, 0.040),
			Vector2(0.029, 0.035), Vector2(0.030, 0.0)]), 6, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.10, 0.0, 0.0))
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(0.141, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.016), Vector2(0.004, 0.013),
			Vector2(0.006, 0.0)]), 12, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.13, 0.0, 0.0))
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================


func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Side windows in side view (z, y): the front one's edge leaning back with the A-pillar, a long one behind the
	# B-pillar.
	shapes["side_front"] = _inset(PackedVector2Array([Vector2(-0.872, 0.892), Vector2(-0.340, 0.892),
			Vector2(-0.340, 1.108), Vector2(-0.625, 1.108)]), 0.016)
	shapes["side_rear"] = _inset(PackedVector2Array([Vector2(-0.300, 0.892), Vector2(0.090, 0.892),
			Vector2(0.090, 1.108), Vector2(-0.300, 1.108)]), 0.016)
	# Windscreen in front view (x, y); the cabin's rear window in back view.
	shapes["windscreen"] = _inset(PackedVector2Array([Vector2(-0.410, 0.892), Vector2(0.410, 0.892),
			Vector2(0.360, 1.135), Vector2(-0.360, 1.135)]), 0.026)
	shapes["rear"] = _inset(PackedVector2Array([Vector2(-0.360, 0.930), Vector2(0.360, 0.930),
			Vector2(0.345, 1.110), Vector2(-0.345, 1.110)]), 0.028)
	# The door in side view (its top hidden in the window frame), over the gap between the front flares.
	shapes["door"] = PackedVector2Array([Vector2(-0.800, 0.772), Vector2(-0.320, 0.772), Vector2(-0.320, 0.880),
			Vector2(-0.800, 0.880)])
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var outside: bool = n.x > 0.5 and p.x > 0.58
	var szy := Vector2(p.z, p.y)
	var sxy := Vector2(p.x, p.y)
	# Windows and their black seals; the pillars between them black too.
	if n.x > 0.3 and p.z > -0.92 and p.z < 0.14 and p.y > 0.87:
		for key in ["side_front", "side_rear"]:
			var d: float = _sd_rounded(szy, sh[key])
			glass = maxf(glass, _cover(d, fp))
			black = maxf(black, _cover(d - 0.009, fp))
		black = maxf(black, _cover(maxf(0.882 - p.y, p.y - 1.118), fp) * _cover(maxf(-0.82 - p.z, p.z - 0.10), fp))
	if n.z < -0.3 and p.z > -0.99 and p.z < -0.52:
		var d: float = _sd_rounded(sxy, sh["windscreen"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.010, fp))
	if n.z > 0.3 and p.z > 0.09 and p.z < 0.22 and p.y > 0.90:
		var d: float = _sd_rounded(sxy, sh["rear"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.009, fp))
	# Door gaps and handle.
	if outside and p.z > -0.82 and p.z < -0.30 and p.y > 0.76 and p.y < 0.87:
		gap = maxf(gap, _cover(absf(_sd_poly(szy, sh["door"])) - 0.0024, fp))
		var hd: float = _sd_box(szy - Vector2(-0.385, 0.842), Vector2(0.032, 0.008)) - 0.003
		black = maxf(black, _cover(hd, fp))
	# The nose: seams along the wings; the cowl's vent across the foot of the windscreen.
	if n.y > 0.4 and p.z < -0.99:
		gap = maxf(gap, _cover(absf(p.x - (prof["w"].at(p.z) - 0.105)) - 0.0022, fp))
	if n.y > 0.5 and p.z > -0.985 and p.z < -0.945 and p.x < 0.46:
		black = maxf(black, _cover(_sd_box(Vector2(p.x, p.z + 0.965), Vector2(0.42, 0.010)) - 0.002, fp))
	# The deck: a dark anti-slip mat inside a painted border, tie-down slots along it.
	if n.y > 0.8 and p.z > 0.26 and p.z < 1.24 and p.y < 0.90:
		black = maxf(black, _cover(_sd_box(Vector2(p.x, p.z - 0.75), Vector2(0.50, 0.47)) - 0.012, fp) * 0.85)
	# Underside and the arches' ceilings.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, chrome, black)
