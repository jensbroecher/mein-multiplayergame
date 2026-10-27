# SandstormBuilder.gd
#
# The Sandstorm: a rally-raid buggy. A long wheelbase with short overhangs; a short bonnet with a
# power bulge sloping down to a flat nose, a raked windscreen, a compact closed cab with a sloping
# rear window and an engine cover falling to the tail, with two sand ladders strapped on it.
# Body-colour flares swell out of the bonnet's and the deck's shoulders over all-terrain tyres on grey ten-spoke rims; a painted intake scoop
# rides on the roof. Twin shocks at every corner (a coil-over in the accent colour and a bypass
# shock), a black tubular bull bar with two spot lamps over a skid plate, slim rectangular LED
# headlamps, black rocker panels along the sills.
#
# The shell, wheel parts and detail map come from CarDesign.gd. The section above the side is the
# Titan's (a rounded rim, a wall, a corner, a crowned top with the bonnet's bulge), keyed along the
# car in one table (KEYS): over the cab the wall is the side glass leaning in and the corner the roof
# rail; on the bonnet and the deck both lie flat along the top. The arches are cut by lifting the
# shell's bottom in a circle round each hub (_bot_knots); the flares sweep along that outline and
# fade into the body at both ends (_build_flare).
extends "res://CarDesign.gd"

const WHEEL_X := 0.640
const AXLE_F := -0.700
const AXLE_R := 0.660
const HUB_Y := 0.290               # the tyre's radius over its tread: it stands on y = 0
const ARCH_R := 0.355              # the arches' radius about the hub (6.5cm over the tyre)
const SILL_Y := 0.400              # the body's bottom between the arches
const END_SILL_Y := 0.480          # and under the nose and the tail
const NOSE_TIP := -1.060
const TAIL_TIP := 1.000

# Half-width of the body's side in plan: pinched at the nose and tail, swelling over the wheels, a
# waist at the doors.
const W_KNOTS := [[-1.06, 0.500], [-0.97, 0.565], [-0.86, 0.598], [-0.56, 0.598], [-0.40, 0.575], [0.32, 0.575],
	[0.46, 0.598], [0.88, 0.598], [0.97, 0.570], [1.00, 0.550]]

# The section above the side, keyframed along the car. Per row: z; belt (top of the side, where the
# rim's rounding starts); rim_w (the rim, its rounding included); wall_dx (how far the wall leans in:
# the cab's tumblehome); edge (the top beside the crown: bonnet, roof, deck); cx, cy (the corner from
# the wall onto the top: cy > 0 a roof corner, 0 flat); crown; the bonnet bulge's half-width and
# height (it ramps up from the nose and drops off before the cowl).
const KEYS := [
	# z       belt   rim_w  wall_dx edge   cx     cy     crown  dome_w dome_h
	[-1.060, 0.640, 0.050, 0.030, 0.680, 0.030, 0.000, 0.010, 0.170, 0.000],
	[-0.980, 0.655, 0.050, 0.030, 0.698, 0.030, 0.000, 0.010, 0.175, 0.000],
	[-0.840, 0.680, 0.050, 0.030, 0.726, 0.030, 0.000, 0.012, 0.185, 0.020],
	[-0.520, 0.712, 0.050, 0.030, 0.762, 0.030, 0.000, 0.012, 0.195, 0.026],
	[-0.420, 0.717, 0.050, 0.030, 0.769, 0.030, 0.000, 0.012, 0.195, 0.000],
	[-0.330, 0.720, 0.050, 0.030, 0.774, 0.030, 0.000, 0.012, 0.195, 0.000],
	[-0.300, 0.720, 0.052, 0.042, 0.796, 0.040, 0.014, 0.013, 0.195, 0.000],
	[-0.265, 0.720, 0.052, 0.058, 0.832, 0.050, 0.030, 0.014, 0.195, 0.000],
	[-0.040, 0.720, 0.052, 0.075, 1.045, 0.075, 0.062, 0.020, 0.195, 0.000],
	[-0.005, 0.720, 0.052, 0.075, 1.070, 0.075, 0.062, 0.020, 0.195, 0.000],
	[0.040, 0.720, 0.052, 0.075, 1.080, 0.075, 0.062, 0.020, 0.195, 0.000],
	[0.360, 0.722, 0.052, 0.075, 1.080, 0.075, 0.062, 0.020, 0.195, 0.000],
	[0.400, 0.724, 0.052, 0.074, 1.064, 0.072, 0.060, 0.020, 0.195, 0.000],
	[0.580, 0.735, 0.052, 0.045, 0.885, 0.045, 0.020, 0.012, 0.195, 0.000],
	[0.620, 0.738, 0.050, 0.030, 0.860, 0.030, 0.000, 0.010, 0.195, 0.000],
	[0.960, 0.738, 0.050, 0.030, 0.826, 0.030, 0.000, 0.010, 0.195, 0.000],
	[1.000, 0.735, 0.050, 0.030, 0.820, 0.030, 0.000, 0.010, 0.195, 0.000],
]
const KEY_NAMES := ["belt", "rim_w", "wall_dx", "edge", "cx", "cy", "crown", "dome_w", "dome_h"]
const RIM_R := 0.045               # the rounding of the side's top edge into the bonnet, the cab and the deck

const FLARE_OUT := 0.790
const FLARE_EXP := 2.6             # the flare's superelliptic swell: 2 a quarter ellipse, higher squarer

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.21, 0.21, 0.22)
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

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.06, "tail_z": 1.00, "belt_y": 0.72, "side_x": 0.575,
	"door_z": -0.03, "door_y": 0.61, "roundel_r": 0.10,
	"hood_z": -0.74, "hood_r": 0.09, "stripe_w": 0.07, "stripe_gap": 0.025,
}
const ANTENNA_POS := Vector3(0.30, 1.085, 0.34)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}
# The tyre's half profile [[x, r], ...], inner bead to the middle of the tread.
const TYRE_HALF := [[-0.118, 0.172], [-0.126, 0.182], [-0.131, 0.200], [-0.132, 0.225], [-0.129, 0.247],
	[-0.121, 0.261], [-0.104, 0.268], [-0.070, 0.2715], [-0.025, 0.2725]]


func _init() -> void:
	nose_tip = NOSE_TIP
	nose_cap = 0.065
	nose_cap_y = 0.570
	nose_cap_exp = Vector2(3.5, 4.0)
	tail_tip = TAIL_TIP
	tail_cap = 0.055
	tail_cap_y = 0.620
	tail_cap_exp = Vector2(3.5, 4.0)
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
	var n := 206
	for k in n + 1:
		var z: float = lerpf(NOSE_TIP, TAIL_TIP, float(k) / n)
		var sill: float = SILL_Y if z > AXLE_F and z < AXLE_R else END_SILL_Y
		var arch := 0.0
		for axle in [AXLE_F, AXLE_R]:
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
## (x_in, d), level there so it runs on into the bonnet's (or the deck's) shoulder; the liner runs
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
## door end round to the outer end, its section shrinking into the body over `taper_door` and
## `taper_end` metres of the spine (an elliptical taper), so the swell rises out of the door and runs
## out into the nose or the tail instead of ending in a flat cap.
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
## normal there and `out` metres proud of it: lamps, the grille and the vent.
func _on_face(b, x: float, y: float, front: bool, h: Vector3, r: float, mat: int, col: Color, out: float) -> void:
	var f: Array = face_frame(x, y, front)
	var nrm: Vector3 = f[1]
	b.rbox(Transform3D(facing(nrm), (f[0] as Vector3) + nrm * out), h, r, 2, mat, col)


## Body mesh: shell, flares, lamps, mirrors, the chassis and its suspension, the ends, the roof
## scoop and the sand ladders on the deck.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_build_flare(b, _arch_lip(-0.330, -1.000), AXLE_F, 0.075, 0.18, 0.10)
	_build_flare(b, _arch_lip(0.320, 0.950), AXLE_R, 0.100, 0.18, 0.10)
	_side_parts(b)
	_suspension(b, AXLE_F, 1.0)
	_suspension(b, AXLE_R, -1.0)
	b.mirror_x(v0, i0)
	_front_parts(b)
	_rear_parts(b)
	_chassis(b)
	_roof_scoop(b)
	_deck_load(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inboard of each arch, so it doesn't look through the car. They stop
	# short of the nose and the tail.
	for arch in [[nose_tip + 0.07, AXLE_F + 0.33], [AXLE_R - 0.33, tail_tip - 0.07]]:
		b.rbox(Transform3D(Basis(), Vector3(0.250, 0.550, (arch[0] + arch[1]) * 0.5)),
				Vector3(0.004, 0.140, (arch[1] - arch[0]) * 0.5), 0.003, 1, CB.M_DARK, C_DARKER)
	# Mirror on a stalk at the foot of the A-pillar, its shell in the body colour.
	b.tube(PackedVector3Array([Vector3(0.515, 0.775, -0.270), Vector3(0.600, 0.815, -0.262)]), 0.008, 6, CB.M_DARK,
			C_DARK, false, true)
	b.rbox(Transform3D(Basis(Vector3.UP, -0.12), Vector3(0.628, 0.828, -0.258)), Vector3(0.042, 0.030, 0.014), 0.011, 2,
			CB.M_PAINT, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(Vector3.UP, -0.12), Vector3(0.630, 0.828, -0.244)), Vector3(0.036, 0.024, 0.002), 0.004, 1,
			CB.M_CHROME, C_CHROME)
	# Headlamp: a slim LED strip over three square LED eyes, in a dark housing on the nose's face;
	# an amber marker out on the corner.
	_on_face(b, 0.345, 0.625, true, Vector3(0.078, 0.030, 0.010), 0.008, CB.M_DARK, C_DARK, 0.0)
	_on_face(b, 0.345, 0.638, true, Vector3(0.066, 0.008, 0.004), 0.003, CB.M_HEADLAMP, Color(1, 1, 1), 0.008)
	for x in [0.305, 0.345, 0.385]:
		_on_face(b, x, 0.613, true, Vector3(0.013, 0.009, 0.004), 0.003, CB.M_HEADLAMP, Color(1, 1, 1), 0.008)
	_on_face(b, 0.460, 0.600, true, Vector3(0.022, 0.010, 0.005), 0.004, CB.M_TAILLAMP, C_AMBER, 0.003)
	# Taillamps: an upright red strip in a dark surround on each of the tail's corners, the reverse
	# lamp under it.
	_on_face(b, 0.455, 0.745, false, Vector3(0.034, 0.068, 0.010), 0.010, CB.M_DARK, C_DARK, 0.0)
	_on_face(b, 0.455, 0.760, false, Vector3(0.024, 0.048, 0.004), 0.004, CB.M_TAILLAMP, C_TAILLAMP, 0.008)
	_on_face(b, 0.455, 0.697, false, Vector3(0.024, 0.010, 0.004), 0.004, CB.M_TAILLAMP, C_REVERSE, 0.008)
	# Body posts: from the chassis up into the body, front and rear; the front ones come through the
	# bonnet, each held by an R-clip.
	for z in [-0.93, 0.90]:
		b.tube(PackedVector3Array([Vector3(0.10, 0.23, z), Vector3(0.10, END_SILL_Y + 0.01, z)]), 0.010, 8, CB.M_DARK, C_DARK,
				false, false)
	var py: float = top_y(0.10, -0.93)
	b.tube(PackedVector3Array([Vector3(0.10, py - 0.01, -0.93), Vector3(0.10, py + 0.026, -0.93)]), 0.0075, 8, CB.M_DARK,
			C_DARK, false, true)
	_r_clip(b, Vector3(0.10, py + 0.016, -0.93), py + 0.005)


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
## from the gearbox, and twin shocks from a web on the lower arm up under the arch: a coil-over on
## the side of the axle toward the middle of the car (`fz`), a bypass shock on the other.
func _suspension(b, axle_z: float, fz: float) -> void:
	var kx: float = WHEEL_X - 0.095
	for dz in [-0.090, 0.090]:
		b.tube(PackedVector3Array([Vector3(0.130, 0.170, axle_z + dz), Vector3(kx - 0.012, 0.210, axle_z)]), 0.014, 8,
				CB.M_ALLOY, C_ALLOY_DARK, true, true)
		b.tube(PackedVector3Array([Vector3(0.160, 0.330, axle_z + dz * 0.6), Vector3(kx - 0.015, 0.370, axle_z)]), 0.010,
				6, CB.M_ALLOY, C_ALLOY_DARK, true, true)
	# A web across the lower arm, under the shocks' feet.
	b.rbox(Transform3D(Basis(Vector3.BACK, 0.10), Vector3(0.405, 0.195, axle_z)), Vector3(0.085, 0.006, 0.090), 0.005, 1,
			CB.M_DARK, C_PLASTIC)
	# Hub carrier, the stub axle out to the wheel.
	b.rbox(Transform3D(Basis(), Vector3(kx, HUB_Y, axle_z)), Vector3(0.016, 0.085, 0.030), 0.009, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, axle_z), Vector3(0.60, HUB_Y, axle_z)]), 0.015, 10, CB.M_ALLOY,
			C_ALLOY_DARK, false, true)
	# CV driveshaft from the gearbox, its boots at both ends.
	var d0 := Vector3(0.110, 0.250, axle_z)
	var d1 := Vector3(kx - 0.02, HUB_Y, axle_z)
	b.tube(PackedVector3Array([d0, d1]), 0.009, 8, CB.M_ALLOY, C_ALLOY_DARK, false, false)
	for t in [0.06, 0.94]:
		b.tube(PackedVector3Array([d0.lerp(d1, t - 0.05), d0.lerp(d1, t + 0.05)]), 0.017, 10, CB.M_DARK, C_DARKER,
				true, true, PackedFloat32Array([0.012, 0.017]) if t < 0.5 else PackedFloat32Array([0.017, 0.012]))
	# The coil-over and the bypass shock, both leaning in to their towers under the arch.
	coilover(b, Vector3(0.430, 0.205, axle_z + 0.072 * fz), Vector3(0.330, 0.600, axle_z + 0.085 * fz), 0.021, 0.033,
			7.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)
	_bypass(b, Vector3(0.420, 0.205, axle_z - 0.070 * fz), Vector3(0.335, 0.595, axle_z - 0.085 * fz))
	b.rbox(Transform3D(Basis(), Vector3(0.320, 0.618, axle_z)), Vector3(0.050, 0.010, 0.120), 0.005, 1, CB.M_DARK, C_DARK)


## A bypass shock from `lo` to `hi`: a chrome shaft, a long alloy body with its bypass tubes
## alongside, a piggyback reservoir in the accent colour.
func _bypass(b, lo: Vector3, hi: Vector3) -> void:
	var ax: Vector3 = (hi - lo).normalized()
	var body_lo: Vector3 = lo.lerp(hi, 0.30)
	b.tube(PackedVector3Array([lo, body_lo]), 0.008, 8, CB.M_CHROME, C_CHROME, true, false)
	b.tube(PackedVector3Array([body_lo, hi]), 0.019, 12, CB.M_ALLOY, C_ALLOY, true, true)
	var side: Vector3 = ax.cross(Vector3.BACK).normalized()
	for k in 3:
		var off: Vector3 = side * 0.022 + ax.cross(side) * (0.012 * (k - 1))
		b.tube(PackedVector3Array([body_lo.lerp(hi, 0.10) + off, body_lo.lerp(hi, 0.85) + off]), 0.0035, 6, CB.M_ALLOY,
				C_ALLOY_DARK, true, true)
	var res_lo: Vector3 = body_lo.lerp(hi, 0.45) - side * 0.034
	b.tube(PackedVector3Array([res_lo, res_lo + ax * 0.16]), 0.015, 12, CB.M_ANODISED, Color(1, 1, 1), true, true)
	b.rbox(Transform3D(facing(Vector3.RIGHT), lo - ax * 0.006), Vector3(0.013, 0.012, 0.018), 0.005, 1, CB.M_DARK, C_DARK)


## The nose: a vented intake, the tubular bull bar with two spot lamps, the skid plate, tow hooks.
func _front_parts(b) -> void:
	# Intake: a dark frame on the nose's face, a darker recess, vertical fins.
	_on_face(b, 0.0, 0.560, true, Vector3(0.200, 0.048, 0.012), 0.012, CB.M_DARK, C_DARK, 0.0)
	_on_face(b, 0.0, 0.560, true, Vector3(0.180, 0.034, 0.003), 0.004, CB.M_DARK, C_DARKER, 0.009)
	var gz: float = shell_z(0.0, 0.56, true) - 0.013
	for k in 11:
		bar(b, Vector3(-0.160 + 0.032 * k, 0.560, gz), Vector3(0.0035, 0.032, 0.006), CB.M_DARK, C_PLASTIC)
	# Bull bar: a hoop over the intake from the skid plate, a lower bar swept back round the corners,
	# braces back into the nose.
	var bz := -1.125
	b.tube(_rounded([Vector3(-0.25, 0.37, bz + 0.035), Vector3(-0.24, 0.585, bz - 0.010), Vector3(0.24, 0.585, bz - 0.010),
			Vector3(0.25, 0.37, bz + 0.035)], 0.07), 0.015, 10, CB.M_DARK, C_PLASTIC, false, false)
	b.tube(_rounded([Vector3(-0.42, 0.445, -1.010), Vector3(-0.34, 0.430, bz + 0.010), Vector3(0.34, 0.430, bz + 0.010),
			Vector3(0.42, 0.445, -1.010)], 0.08), 0.014, 10, CB.M_DARK, C_PLASTIC, false, false)
	b.tube(PackedVector3Array([Vector3(0.0, 0.585, bz - 0.010), Vector3(0.0, 0.430, bz + 0.010)]), 0.011, 8, CB.M_DARK,
			C_PLASTIC, false, false)
	for sx in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(0.245 * sx, 0.560, bz - 0.004), Vector3(0.245 * sx, 0.540,
				shell_z(0.245, 0.54, true) + 0.01)]), 0.010, 8, CB.M_DARK, C_PLASTIC, false, false)
		# Spot lamp on the hoop: a round lens in a dark can.
		var lc := Vector3(0.125 * sx, 0.618, bz - 0.022)
		b.tube(PackedVector3Array([lc + Vector3(0.0, 0.0, 0.032), lc]), 0.034, 16, CB.M_DARK, C_DARK, true, false)
		round_lamp(b, lc, Vector3.FORWARD, 0.029, CB.M_HEADLAMP, Color(1, 1, 1))
		b.rbox(Transform3D(Basis(), lc + Vector3(0.0, -0.030, 0.016)), Vector3(0.010, 0.012, 0.012), 0.004, 1, CB.M_DARK,
				C_DARK)
		_tow_hook(b, 0.30 * sx, -1.105, -1.0)
	# Skid plate: from under the bull bar, falling back to the chassis.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.50), Vector3(0.0, 0.305, -1.020)), Vector3(0.22, 0.010, 0.14), 0.008, 1,
			CB.M_ALLOY, C_ALLOY_DARK)
	for k in 4:
		var hx: float = -0.12 + 0.08 * k
		b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.50), Vector3(hx, 0.3105, -1.031)), Vector3(0.020, 0.0045, 0.020),
				0.006, 1, CB.M_DARK, C_DARKER)


## A tow hook (accent colour) from a bumper at (x, z), looping out along `dir` (-1 forward, 1 back).
func _tow_hook(b, x: float, z: float, dir: float) -> void:
	b.tube(_rounded([Vector3(x, 0.445, z), Vector3(x, 0.445, z + 0.040 * dir), Vector3(x, 0.390, z + 0.040 * dir),
			Vector3(x, 0.390, z + 0.004 * dir)], 0.018), 0.0065, 8, CB.M_ANODISED, Color(1, 1, 1), true, true)


## The tail: a slatted vent, the tubular bumper with tow hooks, the skid plate and the exhaust.
func _rear_parts(b) -> void:
	_on_face(b, 0.0, 0.660, false, Vector3(0.250, 0.055, 0.010), 0.012, CB.M_DARK, C_DARK, 0.0)
	_on_face(b, 0.0, 0.660, false, Vector3(0.232, 0.040, 0.003), 0.004, CB.M_DARK, C_DARKER, 0.008)
	var vz: float = shell_z(0.0, 0.66, false) + 0.012
	for k in 4:
		bar(b, Vector3(0.0, 0.632 + 0.019 * k, vz), Vector3(0.225, 0.0035, 0.005), CB.M_ALLOY, C_ALLOY_DARK)
	var bz := 1.060
	b.tube(_rounded([Vector3(-0.42, 0.465, 0.960), Vector3(-0.34, 0.450, bz), Vector3(0.34, 0.450, bz),
			Vector3(0.42, 0.465, 0.960)], 0.08), 0.015, 10, CB.M_DARK, C_PLASTIC, false, false)
	for sx in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(0.20 * sx, 0.450, bz), Vector3(0.20 * sx, 0.470, 0.975)]), 0.011, 8, CB.M_DARK,
				C_PLASTIC, false, false)
		_tow_hook(b, 0.27 * sx, bz + 0.005, 1.0)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.50), Vector3(0.0, 0.330, 0.950)), Vector3(0.20, 0.010, 0.12), 0.008, 1,
			CB.M_ALLOY, C_ALLOY_DARK)
	# Exhaust out of the tail's right side, under the vent.
	var ez: float = shell_z(0.20, 0.54, false)
	b.tube(PackedVector3Array([Vector3(0.20, 0.540, ez - 0.03), Vector3(0.20, 0.540, ez + 0.045)]), 0.022, 16, CB.M_ALLOY,
			C_ALLOY, false, false)
	b.disc(Vector3(0.20, 0.540, ez + 0.040), Vector3.BACK, 0.020, 0.0, 16, CB.M_DARK, C_DARKER)


## The roof scoop: an intake on the roof's front, its mouth tall over the windscreen's top, the
## fairing behind it falling and narrowing back into the roof. Painted, a dark mouth with a lip.
func _roof_scoop(b) -> void:
	var z0 := 0.020
	var z1 := 0.350
	var n := 16
	var m := 20
	var rows := []
	for i in n + 1:
		var t: float = float(i) / n
		var z: float = lerpf(z0, z1, t)
		var base: float = top_y(0.0, z) - 0.012
		# Level over the mouth, then easing down into the roof.
		var h: float = 0.012 + 0.062 * pow(0.5 + 0.5 * cos(PI * t), 0.8)
		var half_w: float = 0.125 * (1.0 - 0.30 * t)
		var row := PackedVector3Array()
		for j in m:
			var a: float = TAU * j / m
			var ca: float = cos(a)
			var sa: float = sin(a)
			var x: float = half_w * signf(ca) * pow(absf(ca), 0.5)
			var y: float = base + h * (0.5 + 0.5 * signf(sa) * pow(absf(sa), 0.5))
			row.append(Vector3(x, y, z))
		rows.append(row)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_PAINT, Color(1, 1, 1), false, true)
	# Outward: on the top row its normal points up.
	var top_j: int = m / 4
	if b._n[vb + (n / 2) * m + top_j].y < 0.0:
		b.flip(vb, ib)
	# The mouth: a dark face a little inside the front ring, a rounded lip round it, a mesh of bars.
	var mouth := PackedVector3Array()
	var lip := PackedVector3Array()
	var front: PackedVector3Array = rows[0]
	var mc := Vector3.ZERO
	for p in front:
		mc += p
	mc /= front.size()
	for p in front:
		mouth.append(mc + (p - mc) * 0.92 + Vector3(0.0, 0.0, 0.010))
		lip.append(p)
	lip.append(front[0])
	b.poly(mouth, Vector3.FORWARD, CB.M_DARK, C_DARKER)
	b.tube(lip, 0.006, 6, CB.M_PAINT, Color(1, 1, 1), false, false)
	for k in 5:
		bar(b, Vector3(-0.080 + 0.040 * k, mc.y, z0 + 0.004), Vector3(0.0025, 0.030, 0.003), CB.M_DARK, C_PLASTIC)


## What rides on the engine cover: two sand ladders (accent-coloured recovery boards) lying side
## by side down its slope, studded, a grab slot at each end, held by a strap across both.
func _deck_load(b) -> void:
	var z0 := 0.660
	var z1 := 0.950
	for sx in [-1.0, 1.0]:
		_sand_ladder(b, 0.150 * sx, z0, z1, 0.125)
	var zs: float = (z0 + z1) * 0.5
	var ys: float = top_y(0.0, zs) + 0.023
	var strap: PackedVector3Array = _rounded([Vector3(-0.320, top_y(0.32, zs) + 0.003, zs), Vector3(-0.290, ys, zs),
			Vector3(0.290, ys, zs), Vector3(0.320, top_y(0.32, zs) + 0.003, zs)], 0.02)
	b.oval_tube(strap, 0.016, 0.0025, Vector3.UP, 8, CB.M_DARK, C_DARK, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, ys + 0.004, zs)), Vector3(0.024, 0.005, 0.020), 0.003, 1, CB.M_ALLOY,
			C_ALLOY_DARK)


## A sand ladder centred at x from z0 to z1, `w` wide, lying on the deck's slope.
func _sand_ladder(b, x: float, z0: float, z1: float, w: float) -> void:
	var y0: float = top_y(x, z0)
	var y1: float = top_y(x, z1)
	var pitch: float = atan2(y0 - y1, z1 - z0)
	var basis := Basis(Vector3.RIGHT, pitch)
	var half_len: float = Vector2(z1 - z0, y1 - y0).length() * 0.5
	var c := Vector3(x, (y0 + y1) * 0.5 + 0.010, (z0 + z1) * 0.5)
	b.rbox(Transform3D(basis, c), Vector3(w * 0.5, 0.007, half_len), 0.006, 1, CB.M_ANODISED, Color(1, 1, 1))
	var up: Vector3 = basis.y
	var along: Vector3 = basis.z
	# Grab slots near both ends, studs in staggered rows between.
	for e in [-1.0, 1.0]:
		b.rbox(Transform3D(basis, c + along * (half_len - 0.030) * e + up * 0.006), Vector3(w * 0.30, 0.002, 0.010),
				0.004, 1, CB.M_DARK, C_DARKER)
	for r in 9:
		var zr: float = -half_len + 0.065 + (2.0 * half_len - 0.13) * r / 8.0
		for k in 3 + r % 2:
			var xr: float = (k - (2.0 + r % 2) * 0.5) * w * 0.27
			var p: Vector3 = c + Vector3(xr, 0.0, 0.0) + along * zr + up * 0.009
			b.rbox(Transform3D(basis, p), Vector3(0.008, 0.004, 0.008), 0.003, 1, CB.M_ANODISED, Color(1, 1, 1))


## The chassis tub, the gearboxes, the centre driveshaft.
func _chassis(b) -> void:
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.190, -0.02)), Vector3(0.130, 0.040, 0.82), 0.020, 2, CB.M_DARK, C_PLASTIC)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.152, -0.02)), Vector3(0.100, 0.008, 0.76), 0.005, 1, CB.M_ALLOY, C_ALLOY_DARK)
	for az in [AXLE_F, AXLE_R]:
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.255, az)), Vector3(0.105, 0.065, 0.078), 0.030, 3, CB.M_DARK, C_DARK)
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.255, az - 0.081 * signf(az))), Vector3(0.055, 0.040, 0.006), 0.018, 2,
				CB.M_ANODISED, Color(1, 1, 1))
	b.tube(PackedVector3Array([Vector3(0.0, 0.25, AXLE_F + 0.08), Vector3(0.0, 0.25, AXLE_R - 0.08)]), 0.012, 10,
			CB.M_ALLOY, C_ALLOY_DARK, false, false)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1): an
## all-terrain tyre (staggered centre blocks, shoulder blocks, sidewall lugs) round a ten-spoke rim
## in the player's rim colour with an accent centre cap.
func build_wheel(b, side: float) -> void:
	var half: Array = TYRE_HALF
	tyre(b, half, 56, C_RUBBER)
	var n := 22
	var rc: float = carcass_r(half, 0.036)
	var rs: float = carcass_r(half, 0.095)
	for k in n:
		for row in 2:
			var f: Array = wheel_frame(TAU * (k + 0.5 * row) / n)
			var r: Vector3 = f[0]
			var t: Vector3 = f[1]
			var sx: float = -1.0 if row == 0 else 1.0
			# Centre block, staggered from one side of the middle to the other.
			block(b, r * (rc + 0.4 * 0.018) + Vector3(0.036 * sx, 0.0, 0.0), Vector3.RIGHT, t, r, 0.030, 0.018, 0.024,
					0.85, CB.M_RUBBER, C_RUBBER)
			# Shoulder block on the other side.
			block(b, r * (rs + 0.4 * 0.017) + Vector3(-0.095 * sx, 0.0, 0.0), Vector3.RIGHT, t, r, 0.026, 0.017, 0.028,
					0.85, CB.M_RUBBER, C_RUBBER)
			# Sidewall lug below it.
			var up: Vector3 = (r * 0.70 + Vector3(-0.71 * sx, 0.0, 0.0)).normalized()
			block(b, r * 0.250 + Vector3(-0.127 * sx, 0.0, 0.0), up.cross(t).normalized(), t, up, 0.014, 0.016, 0.022,
					0.8, CB.M_RUBBER, C_RUBBER)
	# Rim: the lip, the face's step down to the spokes, the barrel.
	wheel_lathe(b, PackedVector2Array([Vector2(0.100, 0.180), Vector2(0.110, 0.182), Vector2(0.115, 0.177),
			Vector2(0.114, 0.165), Vector2(0.108, 0.160)]), 56, CB.M_RIM, C_RIM, "out", Vector3(0.07, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.108, 0.160), Vector2(0.096, 0.156), Vector2(0.084, 0.148)]), 56,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.084, 0.148), Vector2(0.074, 0.160), Vector2(-0.110, 0.162),
			Vector2(-0.118, 0.172)]), 56, CB.M_RIM, C_RIM_BARREL, "in")
	# Back wall behind the spokes, the hub, ten spokes.
	b.disc(Vector3(0.030, 0.0, 0.0), Vector3.RIGHT, 0.150, 0.03, 32, CB.M_DARK, C_DARKER)
	wheel_lathe(b, PackedVector2Array([Vector2(0.060, 0.055), Vector2(0.090, 0.055), Vector2(0.094, 0.048)]), 24,
			CB.M_RIM, C_RIM, "out", Vector3(0.075, 0.0, 0.0))
	for k in 10:
		spoke(b, TAU * k / 10.0, 0.0, 0.048, 0.150, 0.092, 0.082, 0.010, 0.013, 0.013, CB.M_RIM, C_RIM)
	# Five chrome lug nuts round an accent centre cap.
	for k in 5:
		var f: Array = wheel_frame(TAU * (k + 0.5) / 5.0)
		bar(b, (f[0] as Vector3) * 0.034 + Vector3(0.097, 0.0, 0.0), Vector3(0.004, 0.006, 0.006), CB.M_CHROME, C_CHROME)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.094, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.022), Vector2(0.006, 0.020),
			Vector2(0.010, 0.012), Vector2(0.011, 0.0)]), 16, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.090, 0.0, 0.0))
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================


func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Side windows in side view (z, y): the door glass, its front edge leaning back with the
	# A-pillar, and a rear quarter window behind the B-pillar, its back edge following the rear
	# window's slope. The glasshouse outline around both is black (the pillars and seals).
	shapes["side_front"] = _inset(PackedVector2Array([Vector2(-0.245, 0.795), Vector2(0.150, 0.795),
			Vector2(0.150, 1.000), Vector2(-0.030, 1.000)]), 0.016)
	shapes["side_rear"] = _inset(PackedVector2Array([Vector2(0.205, 0.795), Vector2(0.540, 0.795),
			Vector2(0.405, 1.000), Vector2(0.205, 1.000)]), 0.016)
	shapes["glasshouse"] = PackedVector2Array([Vector2(-0.275, 0.780), Vector2(0.570, 0.780),
			Vector2(0.420, 1.014), Vector2(-0.050, 1.014)])
	# Windscreen in front view (x, y); the rear window in back view.
	shapes["windscreen"] = _inset(PackedVector2Array([Vector2(-0.440, 0.790), Vector2(0.440, 0.790),
			Vector2(0.355, 1.055), Vector2(-0.355, 1.055)]), 0.026)
	shapes["rear"] = _inset(PackedVector2Array([Vector2(-0.370, 0.900), Vector2(0.370, 0.900),
			Vector2(0.340, 1.045), Vector2(-0.340, 1.045)]), 0.028)
	# The door in side view (its top hidden in the window frame).
	shapes["door"] = PackedVector2Array([Vector2(-0.255, 0.450), Vector2(0.185, 0.450), Vector2(0.185, 0.770),
			Vector2(-0.255, 0.770)])
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var outside: bool = n.x > 0.5 and p.x > 0.55
	var szy := Vector2(p.z, p.y)
	var sxy := Vector2(p.x, p.y)
	# Side windows and their black frame.
	if n.x > 0.3 and p.z > -0.30 and p.z < 0.60 and p.y > 0.76:
		for key in ["side_front", "side_rear"]:
			glass = maxf(glass, _cover(_sd_rounded(szy, sh[key]), fp))
		black = maxf(black, _cover(_sd_poly(szy, sh["glasshouse"]), fp))
	if n.z < -0.3 and p.z > -0.32 and p.z < 0.02:
		var d: float = _sd_rounded(sxy, sh["windscreen"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.012, fp))
	if n.z > 0.3 and p.z > 0.38 and p.z < 0.62 and p.y > 0.88:
		var d: float = _sd_rounded(sxy, sh["rear"])
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.010, fp))
	# Door gaps and handle; a fuel filler on the rear quarter.
	if outside and p.z > -0.28 and p.z < 0.21 and p.y > 0.44 and p.y < 0.78:
		gap = maxf(gap, _cover(absf(_sd_poly(szy, sh["door"])) - 0.0024, fp))
		black = maxf(black, _cover(_sd_box(szy - Vector2(0.120, 0.705), Vector2(0.030, 0.007)) - 0.003, fp))
	if outside and p.z > 0.22 and p.z < 0.32 and p.y > 0.60 and p.y < 0.72:
		var fd: float = (szy - Vector2(0.265, 0.665)).length()
		black = maxf(black, _cover(fd - 0.026, fp) * (1.0 - _cover(fd - 0.019, fp)))
		chrome = maxf(chrome, _cover(fd - 0.019, fp))
	# Black rocker panels along the sills.
	if n.x > 0.4 and p.y < 0.468:
		black = maxf(black, _cover(p.y - 0.462, fp))
	# Bonnet: seams along the wings; vents either side of the bulge's back; the cowl's vent.
	if n.y > 0.4 and p.z < -0.36:
		gap = maxf(gap, _cover(absf(p.x - (prof["w"].at(p.z) - 0.100)) - 0.0022, fp))
	if n.y > 0.7 and p.z > -0.66 and p.z < -0.50 and p.x > 0.24 and p.x < 0.40:
		var slot := 1e3
		for k in 5:
			slot = minf(slot, _sd_box(Vector2(p.x - 0.32, p.z + 0.640 - 0.030 * k), Vector2(0.060, 0.006)) - 0.003)
		black = maxf(black, _cover(slot, fp))
	if n.y > 0.5 and p.z > -0.345 and p.z < -0.305 and p.x < 0.44:
		black = maxf(black, _cover(_sd_box(Vector2(p.x, p.z + 0.325), Vector2(0.40, 0.009)) - 0.002, fp))
	# The rear deck's lid.
	if n.y > 0.5 and p.z > 0.63:
		gap = maxf(gap, _cover(absf(_sd_box(Vector2(p.x, p.z - 0.805), Vector2(0.430, 0.160))) - 0.0022, fp))
	# Underside and the arches' ceilings.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, chrome, black)
