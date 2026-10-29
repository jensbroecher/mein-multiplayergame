# ObsidianBuilder.gd
#
# The Obsidian: a matte-black desert raider (an original design with a made-up name). A long, low,
# sculpted matte-black body slung between towering mud-terrain tyres that stand clear outboard of it:
# a low tapering hood with recessed extractors and an LED headlamp bar, a raked windscreen framed
# by chrome A-pillars that run on back as the roof rails and down the B-pillars, two tan bucket
# seats in the cockpit, a central cylindrical roof pod on the roll hoop, and a sculpted rear cowl
# that arches over the front and top of the rear wheels, ending in a ducktail with twin aerodynamic
# winglet fins. Under the tub the chassis shows: frame rails, a bronze power cylinder down each side
# held by black clamps over a skid plate, long A-arms out to the hubs, coil-overs, and massive
# directional mud-terrain tyres on gold/bronze beadlock rims.
#
# The shell, wheel parts and detail map come from CarDesign.gd. Its section above the side is keyed
# along the car in one table (KEYS): a rounded rim, a wall, a corner, a crowned top. Over the
# cockpit the tub is open (cy < 0, dropping inside the rim to the floor pan); behind the cockpit
# the shell flares outward and its bottom lifts in a smooth arch over each rear tyre (BOT_KNOTS).
# The windscreen is drawn with glass UVs (M_BODY with _glass_uv).
extends "res://CarDesign.gd"

const WHEEL_X := 0.660
const AXLE_F := -0.740
const AXLE_R := 0.720
const HUB_Y := 0.300               # the tyre's radius over its lugs: it stands on y = 0
const ARCH_R := 0.345              # rear arch radius over the hub
const NOSE_TIP := -0.880
const TAIL_TIP := 0.980
const GLASS_Z := 0.0               # the windscreen's patch of glass on the tub's flat bottom

# Half-width of the body in plan: slender at the front hood, expanding at the cowl, open cockpit,
# then flaring out into the rear cowl arching over the rear tyres.
const W_KNOTS := [
	[-0.880, 0.220], [-0.740, 0.280], [-0.580, 0.325], [-0.440, 0.360], [-0.340, 0.380],
	[0.180, 0.400], [0.280, 0.440], [0.450, 0.670], [0.720, 0.690], [0.900, 0.670], [0.980, 0.620]
]

# The section above the side, keyframed along the car. Per row: z; belt (top of the side, where the
# rim's rounding starts); rim_w (the rim, its rounding included); wall_dx (how far the wall leans in);
# edge (the top beside the crown: the nose deck, the cockpit floor, the rear cowl); cx, cy (the corner
# from the wall onto the top: cy > 0 rising to a deck, < 0 a fillet down onto the floor); crown.
const KEYS := [
	# z       belt   rim_w  wall_dx edge   cx     cy      crown
	[-0.880, 0.330, 0.035, 0.010, 0.355, 0.040, 0.008, 0.008],
	[-0.740, 0.385, 0.038, 0.010, 0.415, 0.045, 0.008, 0.010],
	[-0.580, 0.435, 0.040, 0.010, 0.470, 0.050, 0.008, 0.010],
	[-0.440, 0.465, 0.040, 0.010, 0.505, 0.050, 0.008, 0.010],
	[-0.350, 0.480, 0.040, 0.010, 0.522, 0.050, 0.008, 0.010],
	[-0.320, 0.485, 0.040, 0.000, 0.410, 0.030, -0.030, 0.000],
	[0.180, 0.500, 0.040, 0.000, 0.410, 0.030, -0.030, 0.000],
	[0.240, 0.525, 0.042, 0.004, 0.430, 0.034, -0.020, 0.000],
	[0.320, 0.590, 0.046, 0.012, 0.620, 0.060, 0.020, 0.006],
	[0.450, 0.645, 0.050, 0.020, 0.725, 0.080, 0.040, 0.012],
	[0.720, 0.665, 0.050, 0.020, 0.742, 0.085, 0.045, 0.015],
	[0.880, 0.655, 0.050, 0.020, 0.732, 0.080, 0.040, 0.012],
	[0.980, 0.635, 0.050, 0.020, 0.710, 0.075, 0.035, 0.010],
]
const KEY_NAMES := ["belt", "rim_w", "wall_dx", "edge", "cx", "cy", "crown"]
const RIM_R := 0.032               # the rounding of the side's top edge

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.16, 0.16, 0.17)
const C_DARK := Color(0.07, 0.07, 0.075)
const C_DARKER := Color(0.035, 0.035, 0.04)
const C_PLASTIC := Color(0.10, 0.10, 0.105)
const C_ALLOY := Color(0.78, 0.79, 0.80)
const C_ALLOY_DARK := Color(0.40, 0.41, 0.43)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.57)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)
const C_TAN := Color(0.74, 0.62, 0.46)
const C_TAN_DARK := Color(0.56, 0.45, 0.32)
const C_BRONZE := Color(0.70, 0.48, 0.30)
const C_BRONZE_DARK := Color(0.42, 0.28, 0.17)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -0.88, "tail_z": 0.98, "belt_y": 0.64, "side_x": 0.67,
	"door_z": 0.60, "door_y": 0.65, "roundel_r": 0.055,
	"hood_z": -0.62, "hood_r": 0.08, "stripe_w": 0.06, "stripe_gap": 0.02,
}
const ANTENNA_POS := Vector3(0.30, 0.745, 0.70)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}
# The tyre's half profile [[x, r], ...], inner bead to the middle of the tread:
# Starts at inner bead (-0.125, 0.160), swells through sidewall and shoulder, ends exactly at center (0.0, 0.279).
const TYRE_HALF := [
	[-0.125, 0.160],
	[-0.138, 0.174],
	[-0.148, 0.198],
	[-0.152, 0.226],
	[-0.148, 0.252],
	[-0.138, 0.268],
	[-0.116, 0.275],
	[-0.070, 0.278],
	[0.000, 0.279]
]

var _glass_uv := Vector2.ZERO


func _init() -> void:
	nose_tip = NOSE_TIP
	nose_cap = 0.045
	nose_cap_y = 0.335
	nose_cap_exp = Vector2(2.6, 2.4)
	tail_tip = TAIL_TIP
	tail_cap = 0.080
	tail_cap_y = 0.660
	tail_cap_exp = Vector2(2.6, 2.2)
	# Bottom, bottom corner, side; rim, wall, corner, top.
	segment_counts = [2, 5, 4, 6, 5, 7, 7]
	half_ring = 36
	bottom_radius = 0.030
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[4] + key[7]])
	setup_shell(knots)
	_glass_uv = Vector2(u_of_z(GLASS_Z), 1.5 / half_ring)


## The shell's bottom: rising under the nose, flat under the cockpit, smoothly arching over each rear tyre.
static func _bot_knots() -> Array:
	var out := []
	var n := 180
	for k in n + 1:
		var z: float = lerpf(NOSE_TIP, TAIL_TIP, float(k) / n)
		var sill: float
		if z < -0.380:
			var t: float = clampf((z - NOSE_TIP) / (-0.380 - NOSE_TIP), 0.0, 1.0)
			sill = lerpf(0.280, 0.392, t)
		elif z < 0.280:
			sill = 0.392
		else:
			sill = 0.440
		var arch := 0.0
		var dz: float = z - AXLE_R
		if absf(dz) < ARCH_R:
			arch = HUB_Y + sqrt(ARCH_R * ARCH_R - dz * dz)
		var kk := 0.030
		out.append([z, 0.5 * (sill + arch + sqrt((sill - arch) * (sill - arch) + kk * kk)) - kk * 0.5])
	return out


## Above the side: the rim (the side's top edge rounding over onto a flat rim_w wide), the wall
## (from the rim's inner edge to B: up to a deck, or down into the cockpit), the corner (B onto the
## top at C), then the top, crowned toward the centre line.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var rim_w: float = maxf(prof["rim_w"].at(z), RIM_R + 0.004)
	var edge: float = prof["edge"].at(z)
	var cx: float = maxf(prof["cx"].at(z), 0.004)
	var cy: float = prof["cy"].at(z)
	var crown: float = maxf(prof["crown"].at(z), 0.0)
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
	var top := PackedVector2Array()
	for k in 13:
		var x: float = lerpf(x0, 0.0, k / 12.0)
		top.append(Vector2(x, edge + crown * 0.5 * (1.0 - cos((1.0 - x / x0) * PI))))
	return [rim, PackedVector2Array([a_pt, b_pt]), corner, top]


## A rounded box set on the nose's (front) or the tail's face at (x, y), turned with the face's
## normal there and `out` metres proud of it.
func _on_face(b, x: float, y: float, front: bool, h: Vector3, r: float, mat: int, col: Color, out: float) -> void:
	var f: Array = face_frame(x, y, front)
	var nrm: Vector3 = f[1]
	b.rbox(Transform3D(facing(nrm), (f[0] as Vector3) + nrm * out), h, r, 2, mat, col)


## Body mesh: shell, the right-hand parts mirrored, then the parts on the centre line.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	_seat(b, 0.175)
	_cage_side(b)
	_suspension(b, AXLE_F, true)
	_suspension(b, AXLE_R, false)
	_frame_side(b)
	_fin(b, 0.280)
	b.mirror_x(v0, i0)
	_cage_centre(b)
	_windscreen(b)
	_cockpit(b)
	_chassis(b)
	_front_parts(b)
	_rear_parts(b)


## Right-hand trim on the body: lamps, inner wheel well liner.
func _side_parts(b) -> void:
	# Slim LED taillamps across the rear cowl corner.
	_on_face(b, 0.280, 0.655, false, Vector3(0.080, 0.012, 0.008), 0.006, CB.M_DARK, C_DARKER, 0.0)
	_on_face(b, 0.280, 0.657, false, Vector3(0.070, 0.006, 0.004), 0.003, CB.M_TAILLAMP, C_TAILLAMP, 0.006)
	# Inner arch liner wall inside the rear cowl, so nothing looks through.
	b.rbox(Transform3D(Basis(), Vector3(0.440, 0.585, AXLE_R)), Vector3(0.008, 0.090, 0.240), 0.005, 1, CB.M_DARK,
			C_DARKER)


## A sleek curved aerodynamic fin on the rear deck.
func _fin(b, x: float) -> void:
	var pts := PackedVector2Array([
		Vector2(0.820, top_y(x, 0.820) - 0.004),
		Vector2(0.965, top_y(x, 0.965) - 0.004),
		Vector2(0.975, 0.795),
		Vector2(0.920, 0.805),
		Vector2(0.850, 0.775),
	])
	slab(b, pts, x, 0.014, CB.M_PAINT, Color(1, 1, 1))


## A tan bucket seat centred at x: a cushion with side bolsters, a reclined back with bolsters and
## a headrest, piped in a darker tan.
func _seat(b, x: float) -> void:
	var floor_y := 0.410
	b.rbox(Transform3D(Basis(), Vector3(x, floor_y + 0.018, 0.075)), Vector3(0.090, 0.018, 0.085), 0.010, 1,
			CB.M_DARK, C_DARK)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.06), Vector3(x, floor_y + 0.050, 0.070)), Vector3(0.082, 0.018, 0.090),
			0.016, 2, CB.M_DARK, C_TAN)
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(Vector3.BACK, 0.25 * s), Vector3(x + 0.085 * s, floor_y + 0.062, 0.075)),
				Vector3(0.018, 0.026, 0.088), 0.014, 2, CB.M_DARK, C_TAN)
	var lean := Basis(Vector3.RIGHT, 0.32)
	var bc := Vector3(x, floor_y + 0.135, 0.190)
	b.rbox(Transform3D(lean, bc), Vector3(0.082, 0.105, 0.022), 0.016, 2, CB.M_DARK, C_TAN)
	b.rbox(Transform3D(lean, bc + lean.z * 0.022), Vector3(0.088, 0.108, 0.010), 0.008, 1, CB.M_DARK, C_DARK)
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(lean * Basis(Vector3.UP, -0.30 * s), bc + lean.x * 0.085 * s - lean.z * 0.010),
				Vector3(0.016, 0.098, 0.030), 0.013, 2, CB.M_DARK, C_TAN)
	var hc: Vector3 = bc + lean.y * 0.140
	b.rbox(Transform3D(lean, hc), Vector3(0.060, 0.038, 0.024), 0.018, 2, CB.M_DARK, C_TAN)
	b.rbox(Transform3D(lean, bc + lean.y * 0.103), Vector3(0.050, 0.004, 0.020), 0.003, 1, CB.M_DARK, C_TAN_DARK)
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(lean, bc + lean.x * 0.035 * s - lean.z * 0.024 + lean.y * 0.010), Vector3(0.010, 0.090, 0.002),
				0.002, 1, CB.M_DARK, C_DARKER)


## Right half of the cage & window frame: chrome A-pillar tube rising from the hood shoulder,
## along the roof, down the B-pillar, and framing the window sill.
func _cage_side(b) -> void:
	var foot := Vector3(0.280, top_y(0.280, -0.420) - 0.002, -0.420)
	# Chrome upper rail: A-pillar and roof rail to the hoop.
	b.tube(_rounded([foot, Vector3(0.300, 0.690, -0.165), Vector3(0.300, 0.692, 0.285)], 0.06, 6), 0.012, 10,
			CB.M_CHROME, C_CHROME, true, false)
	# Roll hoop leg, rising from the sill to the top.
	var leg_foot := Vector3(0.370, prof["belt"].at(0.285) + RIM_R - 0.004, 0.285)
	b.tube(_rounded([leg_foot, Vector3(0.340, 0.700, 0.285), Vector3(0.250, 0.760, 0.285)], 0.07, 6), 0.016, 10,
			CB.M_DARK, C_DARK, true, false)
	# Chrome window perimeter loop: A-pillar -> roof rail -> B-pillar -> lower sill -> back to foot.
	var win_loop := _rounded([
		foot + Vector3(0.004, 0.0, 0.0),
		Vector3(0.304, 0.686, -0.165),
		Vector3(0.304, 0.688, 0.282),
		Vector3(0.345, 0.535, 0.355),
		Vector3(0.345, 0.470, 0.020),
		foot + Vector3(0.004, 0.0, 0.0)
	], 0.04, 5)
	b.tube(win_loop, 0.006, 6, CB.M_CHROME, C_CHROME, false, false)
	# Brace from the hoop back down into the rear cowl.
	b.tube(PackedVector3Array([Vector3(0.300, 0.730, 0.285), Vector3(0.380, top_y(0.380, 0.460) - 0.006, 0.460)]),
			0.012, 8, CB.M_DARK, C_DARK, true, true)


## The cage's parts on the centre line: the hoop's top bar, header, and central cylindrical roof pod.
func _cage_centre(b) -> void:
	b.tube(_rounded([Vector3(-0.250, 0.760, 0.285), Vector3(-0.200, 0.768, 0.285), Vector3(0.200, 0.768, 0.285),
			Vector3(0.250, 0.760, 0.285)], 0.05), 0.016, 10, CB.M_DARK, C_DARK, false, false)
	b.tube(PackedVector3Array([Vector3(-0.300, 0.690, -0.165), Vector3(0.300, 0.690, -0.165)]), 0.011, 10,
			CB.M_CHROME, C_CHROME, false, false)
	# Diagonal brace behind the seats.
	b.tube(PackedVector3Array([Vector3(-0.330, 0.560, 0.295), Vector3(0.220, 0.762, 0.295)]), 0.010, 8, CB.M_DARK,
			C_DARK, false, false)
	# The central roof cylinder pod.
	var pc := Vector3(0.0, 0.750, 0.285)
	b.tube(PackedVector3Array([pc, pc + Vector3(0.0, 0.070, 0.0)]), 0.032, 18, CB.M_CHROME, C_CHROME, true, true)
	b.tube(PackedVector3Array([pc + Vector3(0.0, 0.024, 0.0), pc + Vector3(0.0, 0.046, 0.0)]), 0.0335, 18, CB.M_DARK,
			C_DARK, false, false)
	b.rbox(Transform3D(Basis(), pc + Vector3(0.0, 0.035, -0.032)), Vector3(0.018, 0.008, 0.003), 0.003, 1,
			CB.M_HEADLAMP, Color(1, 1, 1))


## A point on the windscreen: s across (-1 left to 1 right), t up (0 at foot, 1 at header).
func _screen_point(s: float, t: float) -> Vector3:
	var xb: float = 0.270 * s
	var zb := -0.380
	var yb: float = top_y(xb, zb) + 0.003
	var xt: float = 0.290 * s
	var zt := -0.170
	var yt := 0.684
	return Vector3(lerpf(xb, xt, t), lerpf(yb, yt, t), lerpf(zb, zt, t) - 0.012 * sin(PI * t))


## The windscreen: glass both ways round with a black seal along its foot.
func _windscreen(b) -> void:
	var rows := []
	var uvs := []
	for i in 7:
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		for j in 17:
			row.append(_screen_point(lerpf(-1.0, 1.0, j / 16.0), i / 6.0))
			uv.append(_glass_uv)
		rows.append(row)
		uvs.append(uv)
	for dir in [Vector3(0.0, 0.7, -1.0), Vector3(0.0, -0.7, 1.0)]:
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.grid(rows, CB.M_BODY, Color(1, 1, 1), false, false, uvs)
		b.orient_toward(vb, ib, dir)
	var seal := PackedVector3Array()
	for j in 17:
		seal.append(_screen_point(lerpf(-1.0, 1.0, j / 16.0), 0.0) + Vector3(0.0, 0.002, 0.0))
	b.tube(seal, 0.006, 6, CB.M_DARK, C_DARKER, true, true)


## Cockpit fittings: tan dash, steering wheel, centre tunnel and shifter.
func _cockpit(b) -> void:
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.468, -0.300)), Vector3(0.340, 0.060, 0.032), 0.020, 2, CB.M_DARK, C_TAN)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.0, 0.528, -0.282)), Vector3(0.330, 0.006, 0.028), 0.005,
			1, CB.M_DARK, C_DARK)
	for dx in [-0.035, 0.035]:
		b.disc(Vector3(-0.175 + dx, 0.495, -0.267), Vector3(0.0, 0.25, 1.0).normalized(), 0.018, 0.0, 12, CB.M_DARK,
				C_DARKER)
	var wc := Vector3(-0.175, 0.520, -0.205)
	var tilt := Basis(Vector3.RIGHT, -0.45)
	var ring := PackedVector3Array()
	for k in 17:
		var a: float = TAU * k / 16.0
		ring.append(wc + tilt * Vector3(cos(a) * 0.050, sin(a) * 0.050, 0.0))
	b.tube(ring, 0.008, 6, CB.M_DARK, C_DARKER, false, false)
	b.tube(PackedVector3Array([wc, wc + tilt * Vector3(0.0, 0.0, -0.085)]), 0.008, 6, CB.M_DARK, C_DARK, true, true)
	for a in [PI * 0.5, PI * 1.17, PI * 1.83]:
		b.tube(PackedVector3Array([wc, wc + tilt * Vector3(cos(a) * 0.046, sin(a) * 0.046, 0.0)]), 0.005, 5, CB.M_DARK,
				C_DARK, false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.432, 0.020)), Vector3(0.040, 0.024, 0.230), 0.012, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(0.0, 0.450, -0.040), Vector3(0.0, 0.505, -0.020)]), 0.005, 6, CB.M_CHROME,
			C_CHROME, false, true)
	b.lathe(Vector3(0.0, 0.512, -0.018), Vector3.UP, PackedVector2Array([Vector2(-0.010, 0.0), Vector2(-0.007, 0.010),
			Vector2(0.006, 0.010), Vector2(0.010, 0.0)]), 10, CB.M_DARK, C_TAN)


## One corner's suspension (right side): long A-arms, hub, CV shaft, coil-overs.
func _suspension(b, axle_z: float, front: bool) -> void:
	var kx: float = WHEEL_X - 0.100
	for dz in [-0.095, 0.095]:
		b.tube(PackedVector3Array([Vector3(0.120, 0.190, axle_z + dz), Vector3(kx - 0.012, 0.215, axle_z)]), 0.014, 8,
				CB.M_DARK, C_PLASTIC, true, true)
		b.tube(PackedVector3Array([Vector3(0.150, 0.330 if front else 0.370, axle_z + dz * 0.6), Vector3(kx - 0.015, 0.385, axle_z)]),
				0.011, 6, CB.M_DARK, C_PLASTIC, true, true)
	b.rbox(Transform3D(Basis(), Vector3(kx, HUB_Y, axle_z)), Vector3(0.018, 0.098, 0.032), 0.010, 2, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, axle_z), Vector3(WHEEL_X - 0.02, HUB_Y, axle_z)]), 0.016, 10,
			CB.M_ALLOY, C_ALLOY_DARK, false, true)
	var d0 := Vector3(0.115, 0.255, axle_z)
	var d1 := Vector3(kx - 0.02, HUB_Y, axle_z)
	b.tube(PackedVector3Array([d0, d1]), 0.010, 8, CB.M_ALLOY, C_ALLOY_DARK, false, false)
	for t in [0.06, 0.94]:
		b.tube(PackedVector3Array([d0.lerp(d1, t - 0.05), d0.lerp(d1, t + 0.05)]), 0.018, 10, CB.M_DARK, C_DARKER,
				true, true, PackedFloat32Array([0.012, 0.018]) if t < 0.5 else PackedFloat32Array([0.018, 0.012]))
	var fz: float = 1.0 if front else -1.0
	b.rbox(Transform3D(Basis(Vector3.BACK, 0.06), Vector3(0.420, 0.205, axle_z)), Vector3(0.080, 0.006, 0.085), 0.005, 1,
			CB.M_DARK, C_PLASTIC)
	var lo := Vector3(0.450, 0.218, axle_z + 0.060 * fz)
	var hi := Vector3(0.220, 0.435, axle_z + 0.040) if front else Vector3(0.360, 0.585, axle_z - 0.090)
	coilover(b, lo, hi, 0.022, 0.035, 7.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)


## Right-hand frame under the tub: rails, posts, the bronze tank in its clamps.
func _frame_side(b) -> void:
	b.tube(_rounded([Vector3(0.120, 0.190, AXLE_F + 0.08), Vector3(0.300, 0.195, -0.420), Vector3(0.320, 0.195, 0.380),
			Vector3(0.140, 0.190, AXLE_R - 0.13)], 0.08), 0.013, 8, CB.M_DARK, C_PLASTIC, true, true)
	b.tube(PackedVector3Array([Vector3(0.330, 0.385, -0.400), Vector3(0.340, 0.385, 0.330)]), 0.012, 8, CB.M_ALLOY,
			C_ALLOY_DARK, true, true)
	for z in [-0.360, -0.020, 0.300]:
		b.tube(PackedVector3Array([Vector3(0.315, 0.195, z), Vector3(0.335, 0.385, z)]), 0.010, 8, CB.M_DARK, C_PLASTIC,
				false, false)
	# Bronze power cylinder down the side.
	var t0 := Vector3(0.300, 0.272, -0.270)
	var t1 := Vector3(0.300, 0.272, 0.250)
	b.tube(PackedVector3Array([t0, t1]), 0.040, 18, CB.M_ALLOY, C_BRONZE, true, true)
	for z in [-0.255, 0.235]:
		b.tube(PackedVector3Array([Vector3(0.300, 0.272, z - 0.015), Vector3(0.300, 0.272, z + 0.015)]), 0.043, 18,
				CB.M_ALLOY, C_BRONZE_DARK, true, true)
	for z in [-0.150, -0.050, 0.050, 0.150]:
		b.tube(PackedVector3Array([Vector3(0.300, 0.272, z - 0.003), Vector3(0.300, 0.272, z + 0.003)]), 0.0415, 18,
				CB.M_ALLOY, C_BRONZE_DARK, false, false)
	# Clamps.
	for z in [-0.120, 0.120]:
		b.tube(PackedVector3Array([Vector3(0.300, 0.272, z - 0.012), Vector3(0.300, 0.272, z + 0.012)]), 0.046, 18,
				CB.M_DARK, C_DARK, true, true)
		b.rbox(Transform3D(Basis(), Vector3(0.300, 0.205, z)), Vector3(0.010, 0.032, 0.012), 0.004, 1, CB.M_DARK, C_DARK)
		b.rbox(Transform3D(Basis(), Vector3(0.300, 0.322, z)), Vector3(0.012, 0.014, 0.014), 0.004, 1, CB.M_DARK,
				C_DARK)


## Chassis spine, skid plate, gearboxes, driveshaft.
func _chassis(b) -> void:
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.215, 0.0)), Vector3(0.125, 0.040, 0.850), 0.020, 2, CB.M_DARK, C_PLASTIC)
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.168, -0.010)), Vector3(0.335, 0.008, 0.300), 0.005, 1, CB.M_ALLOY,
			C_ALLOY_DARK)
	for sx in [-1.0, 1.0]:
		for k in 6:
			bar(b, Vector3(0.315 * sx, 0.177, -0.270 + 0.104 * k), Vector3(0.006, 0.002, 0.006), CB.M_DARK, C_DARKER)
	for az in [AXLE_F, AXLE_R]:
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.258, az)), Vector3(0.105, 0.065, 0.078), 0.030, 3, CB.M_DARK, C_DARK)
		b.rbox(Transform3D(Basis(), Vector3(0.0, 0.258, az - 0.081 * signf(az))), Vector3(0.055, 0.040, 0.006), 0.018, 2,
				CB.M_ANODISED, Color(1, 1, 1))
	b.tube(PackedVector3Array([Vector3(0.0, 0.258, AXLE_F + 0.08), Vector3(0.0, 0.258, AXLE_R - 0.08)]), 0.012, 10,
			CB.M_ALLOY, C_ALLOY_DARK, false, false)


## Front nose tip: slim LED headlamp bar, front bumper, skid plate and tow hooks.
func _front_parts(b) -> void:
	# Front LED headlamp bar across the nose face.
	_on_face(b, 0.0, 0.340, true, Vector3(0.120, 0.012, 0.008), 0.006, CB.M_DARK, C_DARKER, 0.0)
	_on_face(b, 0.0, 0.340, true, Vector3(0.110, 0.006, 0.004), 0.003, CB.M_HEADLAMP, Color(1, 1, 1), 0.006)
	for sx in [-1.0, 1.0]:
		_on_face(b, 0.135 * sx, 0.338, true, Vector3(0.015, 0.005, 0.004), 0.002, CB.M_TAILLAMP, C_AMBER, 0.004)
	# Front tubular bumper.
	b.tube(_rounded([Vector3(-0.160, 0.260, -0.900), Vector3(-0.120, 0.250, -0.930), Vector3(0.120, 0.250, -0.930),
			Vector3(0.160, 0.260, -0.900)], 0.04), 0.013, 8, CB.M_DARK, C_PLASTIC, true, true)
	# Skid plate under the nose.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0.0, 0.220, -0.880)), Vector3(0.130, 0.007, 0.060), 0.004, 1,
			CB.M_ALLOY, C_ALLOY_DARK)
	# Tow hooks.
	for sx in [-1.0, 1.0]:
		b.tube(_rounded([Vector3(0.070 * sx, 0.260, -0.930), Vector3(0.070 * sx, 0.260, -0.965),
				Vector3(0.070 * sx, 0.220, -0.965), Vector3(0.070 * sx, 0.220, -0.935)], 0.015), 0.0055, 8, CB.M_ANODISED,
				Color(1, 1, 1), true, true)


## The tail: rear bumper under the cowl, twin bronze exhausts, diffuser.
func _rear_parts(b) -> void:
	b.tube(_rounded([Vector3(-0.300, 0.440, 0.820), Vector3(-0.260, 0.420, 0.940), Vector3(0.260, 0.420, 0.940),
			Vector3(0.300, 0.440, 0.820)], 0.07), 0.015, 10, CB.M_DARK, C_PLASTIC, true, true)
	for sx in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(0.200 * sx, 0.420, 0.940), Vector3(0.200 * sx, 0.560, 0.880)]), 0.011, 8,
				CB.M_DARK, C_PLASTIC, false, false)
		b.tube(PackedVector3Array([Vector3(0.100 * sx, 0.230, 0.880), Vector3(0.100 * sx, 0.420, 0.940)]), 0.010, 8,
				CB.M_DARK, C_PLASTIC, false, false)
		var ez: float = 0.950
		b.tube(_rounded([Vector3(0.090 * sx, 0.330, 0.700), Vector3(0.110 * sx, 0.480, 0.840),
				Vector3(0.110 * sx, 0.510, ez)], 0.05), 0.020, 14, CB.M_ALLOY, C_BRONZE, false, false)
		b.disc(Vector3(0.110 * sx, 0.510, ez - 0.004), Vector3.BACK, 0.018, 0.0, 14, CB.M_DARK, C_DARKER)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.45), Vector3(0.0, 0.240, 0.920)), Vector3(0.130, 0.008, 0.070), 0.005, 1,
			CB.M_ALLOY, C_ALLOY_DARK)


## A wheel centred on the origin, axle along X: a tall mud-terrain tyre with aggressive directional
## lugs round a deep-dish rim: a wide bronze/gold outer beadlock ring with bolts, a dark centre and hub.
## Built with exact bead matching and embedded block bases so there are zero gaps.
func build_wheel(b, side: float) -> void:
	var half: Array = TYRE_HALF
	tyre(b, half, 56, C_RUBBER)
	var n := 14
	for k in n:
		for row in 2:
			var f: Array = wheel_frame(TAU * (k + 0.5 * row) / n)
			var r: Vector3 = f[0]
			var t: Vector3 = f[1]
			var sx: float = -1.0 if row == 0 else 1.0
			# Center / mid paddle embedded 3mm into carcass
			var x_mid: float = 0.048 * sx
			var rc: float = carcass_r(half, x_mid) - 0.003
			var across: Vector3 = (Vector3.RIGHT + t * 0.18 * sx).normalized()
			block(b, r * (rc + 0.4 * 0.024) + Vector3(x_mid, 0.0, 0.0), across, t, r, 0.058, 0.024, 0.028, 0.84,
					CB.M_RUBBER, C_RUBBER)
			# Shoulder block embedded 3mm into carcass
			var x_sh: float = -0.108 * sx
			var rs: float = carcass_r(half, x_sh) - 0.003
			block(b, r * (rs + 0.4 * 0.022) + Vector3(x_sh, 0.0, 0.0), Vector3.RIGHT, t, r, 0.028, 0.022, 0.032,
					0.84, CB.M_RUBBER, C_RUBBER)
			# Sidewall lug embedded 3mm into sidewall
			var x_lug: float = 0.136 * sx
			var r_lug: float = carcass_r(half, x_lug) - 0.003
			var up: Vector3 = (r * 0.65 + Vector3(0.75 * sx, 0.0, 0.0)).normalized()
			block(b, r * r_lug + Vector3(x_lug, 0.0, 0.0) + up * (0.4 * 0.020), up.cross(t).normalized(), t, up, 0.020, 0.020, 0.028,
					0.8, CB.M_RUBBER, C_RUBBER)
	# Beadlock ring wrapping over the outer tyre bead at x = 0.125, r = 0.160.
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.118, 0.168),
		Vector2(0.126, 0.172),
		Vector2(0.134, 0.168),
		Vector2(0.132, 0.155),
		Vector2(0.124, 0.148)
	]), 56, CB.M_RIM, C_RIM, "out", Vector3(0.09, 0.0, 0.0))
	# Dish face stepping into the center
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.124, 0.148),
		Vector2(0.114, 0.138),
		Vector2(0.105, 0.122),
		Vector2(0.098, 0.116)
	]), 56, CB.M_RIM, C_RIM, "+x")
	# Barrel running back inside to meet inner tyre bead at x = -0.125, r = 0.160
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.098, 0.116),
		Vector2(0.086, 0.118),
		Vector2(0.070, 0.140),
		Vector2(-0.110, 0.148),
		Vector2(-0.125, 0.160)
	]), 56, CB.M_RIM, C_RIM_BARREL, "in")
	# Outer surface of rim barrel (facing outward toward chassis)
	wheel_lathe(b, PackedVector2Array([
		Vector2(-0.125, 0.160),
		Vector2(-0.110, 0.148),
		Vector2(0.070, 0.140),
		Vector2(0.086, 0.118),
		Vector2(0.098, 0.116)
	]), 36, CB.M_DARK, C_DARK, "out")
	# Inboard rim flange / inner barrel lip facing inboard towards suspension
	b.disc(Vector3(-0.125, 0.0, 0.0), -Vector3.RIGHT, 0.166, 0.146, 36, CB.M_DARK, C_DARK)
	wheel_lathe(b, PackedVector2Array([
		Vector2(-0.120, 0.166),
		Vector2(-0.125, 0.166)
	]), 36, CB.M_DARK, C_DARK, "out")
	for k in 16:
		var f: Array = wheel_frame(TAU * (k + 0.5) / 16.0)
		bar(b, (f[0] as Vector3) * 0.160 + Vector3(0.130, 0.0, 0.0), Vector3(0.003, 0.004, 0.004), CB.M_DARK, C_DARK)
	# Dark centre disc with spoke cutouts and hub.
	b.disc(Vector3(0.080, 0.0, 0.0), Vector3.RIGHT, 0.118, 0.0, 32, CB.M_DARK, C_DARK)
	# Solid backface for the centre disc (facing inboard towards chassis)
	b.disc(Vector3(0.078, 0.0, 0.0), -Vector3.RIGHT, 0.118, 0.0, 32, CB.M_DARK, C_DARK)
	for k in 8:
		spoke(b, TAU * k / 8.0, 0.0, 0.055, 0.114, 0.090, 0.094, 0.008, 0.010, 0.010, CB.M_DARK, C_PLASTIC)
	wheel_lathe(b, PackedVector2Array([Vector2(0.080, 0.058), Vector2(0.100, 0.058), Vector2(0.104, 0.050)]), 24,
			CB.M_DARK, C_PLASTIC, "out", Vector3(0.090, 0.0, 0.0))
	b.disc(Vector3(0.104, 0.0, 0.0), Vector3.RIGHT, 0.050, 0.0, 24, CB.M_DARK, C_PLASTIC)
	for k in 6:
		var f: Array = wheel_frame(TAU * (k + 0.5) / 6.0)
		bar(b, (f[0] as Vector3) * 0.034 + Vector3(0.108, 0.0, 0.0), Vector3(0.005, 0.006, 0.006), CB.M_DARK, C_DARKER)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.104, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.020), Vector2(0.006, 0.018),
			Vector2(0.010, 0.010), Vector2(0.011, 0.0)]), 16, CB.M_DARK, C_DARK)
	b.orient_away_from(vb, ib, Vector3(0.100, 0.0, 0.0))
	# Dual-faced ventilated brake rotor (outboard + inboard friction faces):
	b.disc(Vector3(0.026, 0.0, 0.0), Vector3.RIGHT, 0.134, 0.045, 28, CB.M_ALLOY, C_ALLOY)
	b.disc(Vector3(0.016, 0.0, 0.0), -Vector3.RIGHT, 0.134, 0.045, 28, CB.M_ALLOY, C_ALLOY)
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.016, 0.134), Vector2(0.026, 0.134)
	]), 28, CB.M_ALLOY, C_ALLOY, "out")
	# Inboard brake dust shield / backing plate (protects rotor, completely seals inner cavity):
	b.disc(Vector3(0.010, 0.0, 0.0), -Vector3.RIGHT, 0.140, 0.036, 28, CB.M_DARK, C_DARKER)
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.010, 0.140), Vector2(0.016, 0.140)
	]), 28, CB.M_DARK, C_DARKER, "out")
	# Inboard hub sleeve / bearing collar meeting the suspension upright:
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.010, 0.036), Vector2(-0.035, 0.032), Vector2(-0.075, 0.024)
	]), 20, CB.M_DARK, C_DARK, "out")
	b.disc(Vector3(-0.075, 0.0, 0.0), -Vector3.RIGHT, 0.024, 0.0, 20, CB.M_DARK, C_DARK)
	# Heavy-duty off-road brake caliper straddling the rotor:
	var cal_xf := Transform3D(Basis(Vector3.RIGHT, 0.38), Vector3(0.021, 0.092, -0.038))
	b.rbox(cal_xf, Vector3(0.018, 0.036, 0.022), 0.005, 2, CB.M_DARK, C_DARKER)
	if side < 0.0:
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================


func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	# Windscreen glass patch.
	if n.y < -0.9 and absf(p.z - GLASS_Z) < 0.07:
		return Color(1.0, 0.0, 0.0, 0.0)
	var gap := 0.0
	var black := 0.0
	var w: float = prof["w"].at(p.z)
	if n.y < -0.55:
		black = 0.9
	# Cockpit floor and inner tub: black.
	var inner: bool = p.x < w - prof["rim_w"].at(p.z) - 0.002
	if inner and p.z > -0.345 and p.z < 0.35:
		black = maxf(black, _cover(p.y - 0.600, fp))
	# Sill black band.
	if n.x > 0.4 and p.y < prof["bot"].at(p.z) + 0.050:
		black = maxf(black, _cover(p.y - (prof["bot"].at(p.z) + 0.040), fp) * 0.85)
	# Hood details:
	if n.y > 0.4 and p.z < -0.380:
		# Hood shut line across cowl ahead of windscreen:
		gap = maxf(gap, _cover(absf(p.z + 0.410) - 0.0024, fp))
		# Hood side shut lines:
		gap = maxf(gap, _cover(absf(p.x - (w - 0.035)) - 0.0020, fp))
		# Dual recessed hood extraction vents:
		if p.z > -0.720 and p.z < -0.520 and p.x > 0.040 and p.x < 0.200:
			var slot := 1e3
			for k in 4:
				slot = minf(slot, _sd_box(Vector2(p.x - 0.120, p.z + 0.680 - 0.045 * k), Vector2(0.065, 0.008)) - 0.003)
			black = maxf(black, _cover(slot, fp))
	# Rear cowl engine lid seams and louvres.
	if n.y > 0.5 and p.z > 0.42:
		gap = maxf(gap, _cover(absf(_sd_box(Vector2(p.x, p.z - 0.660), Vector2(0.320, 0.220))) - 0.0022, fp))
		if p.z > 0.52 and p.z < 0.76 and p.x < 0.22:
			var slot := 1e3
			for k in 7:
				slot = minf(slot, _sd_box(Vector2(p.x, p.z - 0.530 - 0.032 * k), Vector2(0.160, 0.006)) - 0.002)
			black = maxf(black, _cover(slot, fp))
	return Color(0.0, gap, 0.0, black)
