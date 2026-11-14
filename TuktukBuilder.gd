# TuktukBuilder.gd
#
# The Tuk-Tuk: a three-wheeled auto-rickshaw. A tall, narrow cowl at the front carries one big round headlamp and
# leans over a single front wheel on a fork; behind it the driver's open cab (a floor, a low sill, a seat with a short
# backrest), then the passengers' compartment (side panels rising to the bench, a bench in red vinyl, grab poles) and
# the rear body over the engine, its flanks louvred, a spare wheel on its back between the taillamps. A canopy roof on
# pillars over all of it: a windscreen with a wiper and a marigold garland inside, the hood coming down at the back with
# a little rear window, the side curtains rolled up under the eaves and a fringe of tassels all round.
#
# The front wheel is one wheel on the centre line. The game drives four corners, so the front pair share it: Wheel_FR
# is the whole wheel and Wheel_FL an empty mesh whose bounds are the wheel's (a degenerate triangle corner to corner),
# both at the same hub, so PlayerCart puts both pivots there and steers and spins them alike. The fork with its
# mudguard and the handlebars steer with it (STEERED_PARTS, CarSteerFollower.gd); the mudguard turns with the wheel.
#
# The shell's section above the side is the Meteor's (_upper_segments: shoulder, rim, wall, corner, top, keyed along
# the car), as the Kugelblitz's: closed over the cowl and the rear body, a trough (the wall running down inside to a
# floor) through the cab and the passengers' footwell, a low deck under the bench. The bottom rises over the front wheel
# (the cowl stands clear of it) and is lifted in an arch over each rear wheel.
extends "res://CarDesign.gd"

const AXLE_F := -0.700
const AXLE_R := 0.500
const REAR_X := 0.345
const HUB_Y := 0.155
const ARCH_RZ := 0.195
const ARCH_CY := 0.130
const ARCH_RY := 0.225
const ARCH_E := 2.4
const BASE_BOT := 0.140

# The section above the side, keyframed: z; belt; sx, sy (the shoulder); rim_w; wall_dx; edge; cx, cy; crown.
# Closed (the cowl, the deck, the rear body): the shoulder is the top's rounded edge and edge = belt + sy + 0.004.
# A trough (the cab, the footwell): a short shoulder (the sill), the rim, the wall down inside to the floor at edge.
const KEYS := [
	# z       belt   sx     sy     rim_w  wall_dx edge   cx     cy      crown
	[-0.880, 0.540, 0.090, 0.070, 0.003, 0.002, 0.614, 0.004, 0.000, 0.004],
	[-0.800, 0.580, 0.120, 0.090, 0.003, 0.002, 0.674, 0.004, 0.000, 0.006],
	[-0.680, 0.600, 0.130, 0.090, 0.003, 0.002, 0.694, 0.004, 0.000, 0.008],
	[-0.560, 0.610, 0.130, 0.090, 0.003, 0.002, 0.704, 0.004, 0.000, 0.008],
	[-0.485, 0.610, 0.130, 0.090, 0.003, 0.002, 0.704, 0.004, 0.000, 0.008],
	[-0.475, 0.250, 0.030, 0.045, 0.022, 0.010, 0.205, 0.020, -0.020, 0.000],
	[-0.060, 0.250, 0.030, 0.045, 0.022, 0.010, 0.205, 0.020, -0.020, 0.000],
	[0.050, 0.410, 0.030, 0.045, 0.022, 0.010, 0.205, 0.020, -0.020, 0.000],
	[0.300, 0.410, 0.030, 0.045, 0.022, 0.010, 0.205, 0.020, -0.020, 0.000],
	[0.310, 0.410, 0.035, 0.045, 0.003, 0.002, 0.459, 0.004, 0.000, 0.000],
	[0.535, 0.410, 0.035, 0.045, 0.003, 0.002, 0.459, 0.004, 0.000, 0.000],
	[0.550, 0.500, 0.070, 0.070, 0.003, 0.002, 0.574, 0.004, 0.000, 0.004],
	[0.760, 0.500, 0.080, 0.070, 0.003, 0.002, 0.574, 0.004, 0.000, 0.004],
	[0.860, 0.460, 0.070, 0.060, 0.003, 0.002, 0.524, 0.004, 0.000, 0.004],
]
const KEY_NAMES := ["belt", "sx", "sy", "rim_w", "wall_dx", "edge", "cx", "cy", "crown"]
const W_KNOTS := [[-0.880, 0.140], [-0.830, 0.210], [-0.760, 0.255], [-0.650, 0.285], [-0.540, 0.300],
	[-0.470, 0.315], [-0.300, 0.330], [-0.050, 0.345], [0.100, 0.385], [0.250, 0.405], [0.700, 0.410],
	[0.800, 0.400], [0.860, 0.375]]
# The troughs: the cab and the passengers' footwell (z from, to).
const CAB_Z := Vector2(-0.478, 0.305)
const COWL_BACK_Z := -0.480

# The canopy: the roof's underside at its edge, its extent, the pillars.
const ROOF_Y := 1.030
const ROOF_Z := Vector2(-0.575, 0.880)
const ROOF_HW := 0.415
const ROOF_TH := 0.026
const ROOF_CROWN := 0.026
const ROOF_RF := 0.090                          # the roof's corners' radii in plan, front and back
const ROOF_RB := 0.030
const SCREEN_LO := [0.215, 0.700, -0.503]       # the windscreen's bottom corner (x, y, z)
const SCREEN_HI := [0.262, 1.027, -0.468]       # and its top corner
const POLE_Z := 0.075
const HOOD_X := 0.370
const HOOD_Y0 := 0.515
const HOOD_BACK_Z := 0.830
const REAR_WIN := [0.200, 0.715, 0.925]         # half width, bottom, top

# The parts that steer with the front wheel: [origin, rake (radians, the column's top leaning back), gain].
const BAR_O := Vector3(0.0, 0.716, -0.458)
const BAR_RAKE := 0.42
const STEERED_PARTS := {
	"Fork": [Vector3(0.0, HUB_Y, AXLE_F), 0.0, 1.0],
	"Handlebar": [BAR_O, BAR_RAKE, 0.55],
}

# A small scooter tyre (half its profile, bead to tread centre).
const TYRE_HALF := [[-0.036, 0.096], [-0.043, 0.104], [-0.047, 0.118], [-0.047, 0.133], [-0.042, 0.146],
	[-0.031, 0.153], [-0.015, 0.155], [0.0, 0.155]]

const C_RUBBER := Color(0.13, 0.13, 0.14)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_STEEL := Color(0.16, 0.16, 0.17)
const C_CHROME := Color(0.93, 0.94, 0.96)
const C_POLE := Color(0.62, 0.63, 0.66)
const C_RIM := Color(1, 1, 1)
const C_VINYL := Color(0.62, 0.07, 0.06)
const C_VINYL_DARK := Color(0.10, 0.07, 0.06)
const C_CREAM := Color(0.93, 0.89, 0.78)
const C_PLATE := Color(0.95, 0.93, 0.86)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)
const C_GAUGE := Color(0.92, 0.89, 0.80)
const C_HEADLINER := Color(0.30, 0.28, 0.25)
const TASSELS := [Color(0.85, 0.10, 0.08), Color(0.98, 0.72, 0.10), Color(0.10, 0.55, 0.30), Color(0.95, 0.35, 0.60),
	Color(0.15, 0.35, 0.80)]
const MARIGOLD := [Color(0.98, 0.52, 0.04), Color(0.99, 0.78, 0.10)]
const GLASS_TINT := Color(0.60, 0.72, 0.76, 0.16)

const PAINT_LAYOUT := {
	"nose_z": -0.88, "tail_z": 0.86, "belt_y": 0.640, "side_x": 0.38,
	"door_z": 0.180, "door_y": 0.300, "roundel_r": 0.062,
	"hood_z": -0.640, "hood_r": 0.042, "stripe_w": 0.040, "stripe_gap": 0.014,
}
const ANTENNA_POS := Vector3(0.30, 1.075, 0.74)
const WHEEL_POSITIONS := {
	"FL": Vector3(0.0, HUB_Y, AXLE_F), "FR": Vector3(0.0, HUB_Y, AXLE_F),
	"RL": Vector3(-REAR_X, HUB_Y, AXLE_R), "RR": Vector3(REAR_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -0.880
	nose_cap = 0.075
	nose_cap_y = 0.520
	nose_cap_exp = Vector2(3.0, 2.2)
	tail_tip = 0.860
	tail_cap = 0.050
	tail_cap_y = 0.360
	tail_cap_exp = Vector2(3.5, 3.0)
	segment_counts = [2, 3, 4, 8, 2, 5, 4, 6]
	half_ring = 34
	bottom_radius = 0.030
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[6] + key[9]])
	setup_shell(knots)


## The bottom: high under the cowl (clear of the front wheel), sweeping down behind it to the floor pan, lifted in a
## rounded arch over the rear wheels.
static func _bot_knots() -> Array:
	var k := [[-0.880, 0.470], [-0.850, 0.400], [-0.800, 0.375], [-0.620, 0.370], [-0.575, 0.340], [-0.545, 0.250],
		[-0.515, 0.160], [-0.490, BASE_BOT]]
	k.append([AXLE_R - ARCH_RZ - 0.012, BASE_BOT])
	for s in 21:
		var t: float = s / 10.0 - 1.0
		k.append([AXLE_R + ARCH_RZ * t, ARCH_CY + ARCH_RY * pow(maxf(1.0 - pow(absf(t), ARCH_E), 0.0), 1.0 / ARCH_E)])
	k.append([AXLE_R + ARCH_RZ + 0.012, BASE_BOT])
	k.append([0.800, 0.170])
	k.append([0.860, 0.240])
	return k


## Above the side (as MeteorBuilder's): shoulder, rim, wall, corner, crowned top.
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


## The sill's inner edge at z (x, y): where the trough's wall starts down.
func _sill(z: float) -> Vector2:
	return Vector2(prof["w"].at(z) - prof["sx"].at(z) - prof["rim_w"].at(z), prof["belt"].at(z) + prof["sy"].at(z))


# ============================================================================================
#  Body
# ============================================================================================

func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_cowl(b)
	_roof(b)
	_hood(b)
	_screen_frame(b)
	_cab(b)
	_rear(b)


## Right-hand parts, mirrored by build_body(): the rear arch's liner and mud flap, an indicator on the cowl, the
## taillamp, the pillars and grab pole, the hood's quarter, the rolled-up curtain, the mirror, the side step.
func _side_parts(b) -> void:
	b.rbox(Transform3D(Basis(), Vector3(0.288, 0.245, AXLE_R)), Vector3(0.004, 0.112, ARCH_RZ), 0.003, 1, CB.M_DARK,
			C_DARKER)
	# The mud flap behind the rear wheel, hanging from the body's bottom.
	b.rbox(Transform3D(Basis(), Vector3(REAR_X, 0.104, AXLE_R + ARCH_RZ + 0.022)), Vector3(0.052, 0.046, 0.004), 0.003, 1,
			CB.M_DARK, C_DARK)
	# The indicator on the cowl's front corner, in a chrome cup.
	var ind: Array = face_frame(0.175, 0.625, true)
	var ic: Vector3 = (ind[0] as Vector3) + (ind[1] as Vector3) * 0.004
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(ic, ind[1], PackedVector2Array([Vector2(-0.010, 0.0), Vector2(-0.008, 0.024), Vector2(0.006, 0.024),
			Vector2(0.008, 0.019)]), 14, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, ic - (ind[1] as Vector3) * 0.02)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(ic + (ind[1] as Vector3) * 0.006, ind[1], PackedVector2Array([Vector2(0.0, 0.019), Vector2(0.006, 0.014),
			Vector2(0.009, 0.0)]), 14, CB.M_TAILLAMP, C_AMBER)
	b.orient_away_from(vb, ib, ic)
	# The taillamp on the tail's corner: an amber cell over a red one in a chrome surround.
	var tl: Array = face_frame(0.318, 0.455, false)
	var tc: Vector3 = tl[0]
	var tb: Basis = facing(tl[1])
	b.rbox(Transform3D(tb, tc + tb.z * 0.002), Vector3(0.034, 0.056, 0.008), 0.008, 2, CB.M_CHROME, C_CHROME)
	b.rbox(Transform3D(tb, tc + tb.z * 0.008 + tb.y * -0.016), Vector3(0.027, 0.032, 0.006), 0.006, 2, CB.M_TAILLAMP,
			C_TAILLAMP)
	b.rbox(Transform3D(tb, tc + tb.z * 0.008 + tb.y * 0.032), Vector3(0.027, 0.014, 0.006), 0.005, 2, CB.M_TAILLAMP,
			C_AMBER)
	# The front pillar, from the cowl's top to the roof (the windscreen's frame, _screen_frame, runs along it).
	var lo := Vector3(SCREEN_LO[0] + 0.010, SCREEN_LO[1], SCREEN_LO[2])
	var hi := Vector3(SCREEN_HI[0] + 0.010, SCREEN_HI[1] + 0.006, SCREEN_HI[2])
	b.tube(PackedVector3Array([lo + Vector3(0, -0.012, 0), hi]), 0.0115, 8, CB.M_DARK, C_DARK, true, true)
	# The mirror: a stalk out of the pillar and a round chrome-backed head facing back.
	var mp: Vector3 = lo.lerp(hi, 0.28)
	var head := mp + Vector3(0.085, 0.045, 0.010)
	b.tube(_rounded([mp, mp + Vector3(0.050, 0.010, 0.0), head], 0.02), 0.0045, 6, CB.M_DARK, C_DARK, false, false)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(head, Vector3.BACK, PackedVector2Array([Vector2(-0.014, 0.0), Vector2(-0.012, 0.024), Vector2(0.002, 0.030),
			Vector2(0.004, 0.028)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, head + Vector3.BACK * 0.01)
	b.disc(head + Vector3.BACK * 0.0035, Vector3.BACK, 0.027, 0.0, 16, CB.M_CHROME, Color(0.70, 0.74, 0.78))
	# The grab pole at the passengers' doorway, which holds the roof up there.
	var sill: Vector2 = _sill(POLE_Z)
	var px: float = HOOD_X - 0.002
	b.tube(PackedVector3Array([Vector3(px, sill.y - 0.010, POLE_Z), Vector3(px, ROOF_Y + 0.004, POLE_Z)]), 0.011, 10,
			CB.M_ALLOY, C_POLE, false, false)
	for end in [[Vector3(px, sill.y, POLE_Z), Vector3.UP], [Vector3(px, ROOF_Y, POLE_Z), Vector3.DOWN]]:
		vb = b.vertex_count()
		ib = b.index_count()
		b.lathe(end[0], end[1], PackedVector2Array([Vector2(-0.004, 0.022), Vector2(0.006, 0.020), Vector2(0.014, 0.012)]),
				12, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, (end[0] as Vector3) - (end[1] as Vector3) * 0.02)
	# The hood's quarter, painted canvas on its frame, down to the rear body's shoulder.
	slab(b, PackedVector2Array([Vector2(0.560, HOOD_Y0), Vector2(HOOD_BACK_Z, HOOD_Y0), Vector2(HOOD_BACK_Z, ROOF_Y + 0.004),
			Vector2(0.700, ROOF_Y + 0.004), Vector2(0.612, 0.900)]), HOOD_X, 0.012, CB.M_PAINT, Color(1, 1, 1))
	# Its frame's front bow along the quarter's front edge.
	b.tube(PackedVector3Array([Vector3(HOOD_X + 0.003, HOOD_Y0 + 0.005, 0.560), Vector3(HOOD_X + 0.003, 0.900, 0.612),
			Vector3(HOOD_X + 0.003, ROOF_Y, 0.700)]), 0.0085, 8, CB.M_DARK, C_DARK, true, true)
	# The side curtain, rolled up under the eaves and tied in three places.
	var roll := PackedVector3Array()
	for k in 13:
		roll.append(Vector3(ROOF_HW - 0.024, ROOF_Y - 0.020, lerpf(-0.430, 0.530, k / 12.0)))
	b.tube(roll, 0.021, 12, CB.M_PAINT, Color(0.92, 0.92, 0.92), true, true)
	for z in [-0.300, 0.000, 0.300]:
		var tie := PackedVector3Array()
		for k in 13:
			var a: float = TAU * k / 12.0
			tie.append(Vector3(ROOF_HW - 0.024 + cos(a) * 0.0235, ROOF_Y - 0.020 + sin(a) * 0.0235, z))
		b.tube(tie, 0.0035, 5, CB.M_DARK, C_VINYL_DARK, false, false)


## The cowl's face: the headlamp under a chrome visor, the badge, the number plate, the horn.
func _cowl(b) -> void:
	var hl: Array = face_frame(0.0, 0.575, true)
	var fwd: Vector3 = hl[1]
	var c: Vector3 = (hl[0] as Vector3) + fwd * 0.012
	# The lamp's chrome bucket, then the lamp in it.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c - fwd * 0.016, fwd, PackedVector2Array([Vector2(-0.006, 0.050), Vector2(0.004, 0.066), Vector2(0.016, 0.074),
			Vector2(0.024, 0.074)]), 24, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, c - fwd * 0.05)
	round_lamp(b, c + fwd * 0.020, fwd, 0.066, CB.M_HEADLAMP, Color(1, 1, 1))
	# The visor over it.
	var hb: Basis = facing(fwd)
	var visor := PackedVector3Array()
	for k in 15:
		var a: float = PI * (0.10 + 0.80 * k / 14.0)
		visor.append(c + fwd * (0.004 + 0.018 * sin(a)) + hb.x * cos(a) * 0.074 + hb.y * sin(a) * 0.074)
	b.tube(visor, 0.0085, 8, CB.M_CHROME, C_CHROME, true, true)
	# The badge on the cowl's top front.
	var bf: Array = face_frame(0.0, 0.672, true)
	vb = b.vertex_count()
	ib = b.index_count()
	var bc: Vector3 = (bf[0] as Vector3) + (bf[1] as Vector3) * 0.002
	b.lathe(bc, bf[1], PackedVector2Array([Vector2(0.0, 0.022), Vector2(0.005, 0.020), Vector2(0.008, 0.012),
			Vector2(0.009, 0.0)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, bc - (bf[1] as Vector3) * 0.02)
	# A chrome moustache under the lamp, wings either side.
	for sx in [-1.0, 1.0]:
		var path := PackedVector3Array()
		for k in 9:
			var x: float = sx * lerpf(0.025, 0.150, k / 8.0)
			var y: float = 0.488 + 0.030 * pow(k / 8.0, 1.6)
			var fr: Array = face_frame(x, y, true)
			path.append((fr[0] as Vector3) + (fr[1] as Vector3) * 0.004)
		b.tube(path, 0.0055, 6, CB.M_CHROME, C_CHROME, true, true)
	# The number plate on the cowl's foot.
	var pf: Array = face_frame(0.0, 0.430, true)
	var pb: Basis = facing(pf[1])
	var pc: Vector3 = (pf[0] as Vector3) + pb.z * 0.004
	b.rbox(Transform3D(pb, pc), Vector3(0.078, 0.030, 0.004), 0.003, 1, CB.M_DARK, C_PLATE)
	_plate_text(b, pc + pb.z * 0.0045, pb, 0.062, 0.017)
	# The horn: a black trumpet under the cowl's lower edge on the left.
	var hc := Vector3(-0.150, 0.395, -0.760)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(hc, Vector3(0.0, -0.25, -1.0).normalized(), PackedVector2Array([Vector2(-0.030, 0.010), Vector2(0.0, 0.012),
			Vector2(0.020, 0.020), Vector2(0.030, 0.030)]), 12, CB.M_DARK, C_DARK)
	b.orient_away_from(vb, ib, hc)


## A plate's characters: dark bars in two groups, standing in for letters and digits.
func _plate_text(b, c: Vector3, pb: Basis, half_w: float, h: float) -> void:
	var n := 7
	for k in n:
		if k == 2:
			continue
		var x: float = lerpf(-half_w, half_w, (k + 0.5) / n)
		b.rbox(Transform3D(pb, c + pb.x * x), Vector3(half_w / n * 0.62, h * 0.5, 0.0012), 0.0008, 1, CB.M_DARK, C_DARKER)


## The roof: a crowned slab with rounded corners in plan, a headliner under it, a valance in the accent colour round
## its edge and the tassel fringe hanging from that.
func _roof(b) -> void:
	var zs: PackedFloat32Array = _roof_stations()
	var n: int = zs.size() - 1
	var m := 18
	var outer := []
	for i in n + 1:
		var z: float = zs[i]
		var hw: float = _roof_hw(z)
		var ring := PackedVector3Array()
		# Over the top from the left edge to the right, then the underside back (a closed ring).
		for j in m + 1:
			var x: float = lerpf(-hw, hw, float(j) / m)
			ring.append(Vector3(x, _roof_top(x, z), z))
		ring.append(Vector3(hw + 0.004, ROOF_Y + ROOF_TH * 0.5, z))
		ring.append(Vector3(hw, ROOF_Y, z))
		ring.append(Vector3(-hw, ROOF_Y, z))
		ring.append(Vector3(-hw - 0.004, ROOF_Y + ROOF_TH * 0.5, z))
		outer.append(ring)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(outer, CB.M_PAINT, Color(1, 1, 1), false, true)
	# Outward: over the middle of the roof the normal points up.
	if b._n[vb + (n / 2) * (m + 5) + m / 2].y < 0.0:
		b.flip(vb, ib)
	b.poly(outer[0], Vector3.FORWARD, CB.M_PAINT, Color(1, 1, 1))
	b.poly(outer[n], Vector3.BACK, CB.M_PAINT, Color(1, 1, 1))
	# The headliner, just under the underside.
	var rows := []
	for i in n + 1:
		var z: float = clampf(zs[i], ROOF_Z.x + 0.004, ROOF_Z.y - 0.004)
		var hw: float = _roof_hw(z) - 0.004
		rows.append(PackedVector3Array([Vector3(-hw, ROOF_Y - 0.002, z), Vector3(0.0, ROOF_Y - 0.002, z),
				Vector3(hw, ROOF_Y - 0.002, z)]))
	vb = b.vertex_count()
	ib = b.index_count()
	b.grid(rows, CB.M_DARK, C_HEADLINER, false, false)
	b.orient_toward(vb, ib, Vector3.DOWN)
	# The valance: a band hanging round the edge, front and sides (the hood closes the back).
	var edge := _roof_edge(0.004)
	var band_rows := []
	for p in edge:
		band_rows.append(PackedVector3Array([p + Vector3(0, 0.004, 0), p + Vector3(0, -0.030, 0)]))
	vb = b.vertex_count()
	ib = b.index_count()
	b.grid(band_rows, CB.M_ANODISED, Color(1, 1, 1), false, false)
	_orient_outward(b, vb, ib, edge)
	# Its inside face, darker.
	var in_rows := []
	var inner := _roof_edge(0.0005)
	for p in inner:
		in_rows.append(PackedVector3Array([p + Vector3(0, 0.004, 0), p + Vector3(0, -0.030, 0)]))
	vb = b.vertex_count()
	ib = b.index_count()
	b.grid(in_rows, CB.M_DARK, C_VINYL_DARK, false, false)
	_orient_outward(b, vb, ib, inner)
	b.flip(vb, ib)
	# The tassels: each on a short cord from the valance's hem, colours in turn.
	var spots: Array = []
	var acc := 0.0
	var step := 0.050
	var next := 0.020
	for k in range(1, edge.size()):
		var seg: float = edge[k].distance_to(edge[k - 1])
		while next <= acc + seg:
			var p: Vector3 = edge[k - 1].lerp(edge[k], (next - acc) / seg)
			spots.append(p)
			next += step
		acc += seg
	for k in spots.size():
		var top: Vector3 = (spots[k] as Vector3) + Vector3(0, -0.030, 0)
		_tassel(b, top, TASSELS[k % TASSELS.size()], 0.016 + 0.006 * float(k % 2))


## The roof's half width at z: rounded off at the front corners (and a little at the back).
func _roof_hw(z: float) -> float:
	if z < ROOF_Z.x + ROOF_RF:
		var t: float = (ROOF_Z.x + ROOF_RF - z) / ROOF_RF
		return ROOF_HW - ROOF_RF + ROOF_RF * sqrt(maxf(1.0 - t * t, 0.0))
	if z > ROOF_Z.y - ROOF_RB:
		var t: float = (z - ROOF_Z.y + ROOF_RB) / ROOF_RB
		return ROOF_HW - ROOF_RB + ROOF_RB * sqrt(maxf(1.0 - t * t, 0.0))
	return ROOF_HW


## The roof's stations along z: dense round its rounded corners, so the plan's curve is followed there.
func _roof_stations() -> PackedFloat32Array:
	var zs := PackedFloat32Array()
	for k in 10:
		zs.append(ROOF_Z.x + ROOF_RF * (1.0 - cos(PI * 0.5 * k / 10.0)))
	for k in 33:
		zs.append(lerpf(ROOF_Z.x + ROOF_RF, ROOF_Z.y - ROOF_RB, k / 32.0))
	for k in range(1, 6):
		zs.append(ROOF_Z.y - ROOF_RB + ROOF_RB * sin(PI * 0.5 * k / 5.0))
	return zs


## The roof's top over (x, z): crowned across, its front lip turned down a little over the windscreen.
func _roof_top(x: float, z: float) -> float:
	var hw: float = _roof_hw(z)
	var u: float = clampf(x / maxf(hw, 0.01), -1.0, 1.0)
	var lip: float = clampf((ROOF_Z.x + 0.070 - z) / 0.070, 0.0, 1.0)
	return ROOF_Y + ROOF_TH + ROOF_CROWN * (1.0 - u * u) * (1.0 - 0.6 * lip) - 0.008 * lip * lip


## The roof's edge, `out` metres outside it, from the right side's back end round the front to the left's: the line the
## valance and the tassels hang from.
func _roof_edge(out: float) -> PackedVector3Array:
	var right := PackedVector3Array()
	var z_end: float = ROOF_Z.y - ROOF_RB - 0.005
	for k in range(24, -1, -1):
		right.append(Vector3(ROOF_HW + out, ROOF_Y, lerpf(ROOF_Z.x + ROOF_RF, z_end, k / 24.0)))
	# Round the corner: about its centre, out along its radius.
	var cc := Vector2(ROOF_HW - ROOF_RF, ROOF_Z.x + ROOF_RF)
	for k in range(9, -1, -1):
		var a: float = PI * 0.5 * k / 10.0
		right.append(Vector3(cc.x + (ROOF_RF + out) * sin(a), ROOF_Y, cc.y - (ROOF_RF + out) * cos(a)))
	var pts := PackedVector3Array(right)
	for k in range(1, 12):
		pts.append(Vector3(lerpf(cc.x, -cc.x, k / 12.0), ROOF_Y, ROOF_Z.x - out))
	for k in range(right.size() - 1, -1, -1):
		var p: Vector3 = right[k]
		pts.append(Vector3(-p.x, p.y, p.z))
	return pts


## Flips the band added since (vb, ib) to face away from the roof's middle.
func _orient_outward(b, vb: int, ib: int, _edge: PackedVector3Array) -> void:
	var s := 0.0
	var mid := Vector3(0.0, ROOF_Y, (ROOF_Z.x + ROOF_Z.y) * 0.5)
	for k in range(vb, b.vertex_count()):
		var d: Vector3 = b._v[k] - mid
		d.y = 0.0
		s += b._n[k].dot(d)
	if s < 0.0:
		b.flip(vb, ib)


## A tassel: a cord, a knot and a flared skirt of threads, hanging from `top`.
func _tassel(b, top: Vector3, col: Color, cord: float) -> void:
	b.tube(PackedVector3Array([top + Vector3(0, 0.002, 0), top - Vector3(0, cord, 0)]), 0.0016, 4, CB.M_DARK,
			col * 0.8, false, false)
	var k := top - Vector3(0, cord, 0)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(k, Vector3.DOWN, PackedVector2Array([Vector2(-0.001, 0.0), Vector2(0.002, 0.0055), Vector2(0.006, 0.0050),
			Vector2(0.008, 0.0035), Vector2(0.026, 0.0080), Vector2(0.027, 0.0)]), 7, CB.M_DARK, col)
	b.orient_away_from(vb, ib, k + Vector3(0, -0.010, 0))


## The hood's back: painted canvas round a little rear window (build_glass), its frame.
func _hood(b) -> void:
	var z: float = HOOD_BACK_Z
	var th := 0.006
	var hw: float = HOOD_X + 0.006
	var wx: float = REAR_WIN[0]
	var wy0: float = REAR_WIN[1]
	var wy1: float = REAR_WIN[2]
	var top: float = ROOF_Y + 0.004
	var col := Color(1, 1, 1)
	b.rbox(Transform3D(Basis(), Vector3(0.0, (HOOD_Y0 + wy0) * 0.5, z)), Vector3(hw, (wy0 - HOOD_Y0) * 0.5, th), 0.003, 1,
			CB.M_PAINT, col)
	b.rbox(Transform3D(Basis(), Vector3(0.0, (wy1 + top) * 0.5, z)), Vector3(hw, (top - wy1) * 0.5, th), 0.003, 1,
			CB.M_PAINT, col)
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (wx + hw) * 0.5
		b.rbox(Transform3D(Basis(), Vector3(cx, (wy0 + wy1) * 0.5, z)), Vector3((hw - wx) * 0.5, (wy1 - wy0) * 0.5, th),
				0.003, 1, CB.M_PAINT, col)
	# The window's rubber seal.
	var seal := PackedVector3Array()
	var corners := [Vector2(-wx, wy0), Vector2(wx, wy0), Vector2(wx, wy1), Vector2(-wx, wy1)]
	for k in 5:
		var q: Vector2 = corners[k % 4]
		seal.append(Vector3(q.x, q.y, z + th + 0.001))
	b.tube(_rounded(Array(seal), 0.02), 0.0055, 6, CB.M_DARK, C_DARK, false, false)
	# The frame's top rail, along the hood's top under the roof.
	b.tube(PackedVector3Array([Vector3(-HOOD_X, ROOF_Y - 0.006, z - 0.010), Vector3(HOOD_X, ROOF_Y - 0.006, z - 0.010)]),
			0.008, 8, CB.M_DARK, C_DARK, true, true)


## The windscreen's frame: a dark seal round the glass (the pillars are _side_parts'), the wiper.
func _screen_frame(b) -> void:
	var ring := PackedVector3Array()
	for k in 25:
		ring.append(_screen_pt(-1.0 + 2.0 * k / 24.0, 0.0, 0.006))
	b.tube(ring, 0.0075, 6, CB.M_DARK, C_DARK, true, true)
	var ring2 := PackedVector3Array()
	for k in 25:
		ring2.append(_screen_pt(-1.0 + 2.0 * k / 24.0, 1.0, 0.006))
	b.tube(ring2, 0.0075, 6, CB.M_DARK, C_DARK, true, true)
	# The wiper, parked across the glass's foot from its spindle on the left.
	var s0: Vector3 = _screen_pt(-0.55, 0.03, 0.010)
	var s1: Vector3 = _screen_pt(0.40, 0.10, 0.010)
	b.tube(PackedVector3Array([s0, s1]), 0.0035, 5, CB.M_DARK, C_DARKER, true, true)
	var blade_a: Vector3 = _screen_pt(-0.15, 0.06, 0.013)
	var blade_b: Vector3 = _screen_pt(0.55, 0.11, 0.013)
	b.tube(PackedVector3Array([blade_a, blade_b]), 0.0045, 5, CB.M_DARK, C_DARKER, true, true)
	_knob(b, s0)


## A little black knob (the wiper's spindle, the charm's hook).
func _knob(b, c: Vector3) -> void:
	b.rbox(Transform3D(Basis(), c), Vector3(0.010, 0.010, 0.006), 0.005, 2, CB.M_DARK, C_DARKER)


## A point on the windscreen: u across (-1 left .. 1 right), v up (0 at the cowl, 1 at the roof), `out` in front of
## the glass. It bows forward a little in plan.
func _screen_pt(u: float, v: float, out: float) -> Vector3:
	var hw: float = lerpf(SCREEN_LO[0], SCREEN_HI[0], v)
	var y: float = lerpf(SCREEN_LO[1], SCREEN_HI[1], v)
	var z: float = lerpf(SCREEN_LO[2], SCREEN_HI[2], v) - 0.022 * (1.0 - u * u)
	return Vector3(u * hw, y, z - out)


func build_glass(b) -> void:
	# The windscreen.
	var rows := []
	for i in 13:
		var row := PackedVector3Array()
		for j in 17:
			row.append(_screen_pt(-1.0 + 2.0 * j / 16.0, float(i) / 12.0, 0.0))
		rows.append(row)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_DARK, GLASS_TINT, false, false)
	b.orient_toward(vb, ib, Vector3.FORWARD)
	# The hood's rear window.
	var wx: float = REAR_WIN[0]
	var z: float = HOOD_BACK_Z + 0.002
	var win := PackedVector3Array([Vector3(-wx, REAR_WIN[1], z), Vector3(wx, REAR_WIN[1], z),
		Vector3(wx, REAR_WIN[2], z), Vector3(-wx, REAR_WIN[2], z)])
	b.poly(win, Vector3.BACK, CB.M_DARK, GLASS_TINT)


## The cab and the passengers' compartment: the driver's seat and backrest, the grab rail, the bench, the garland.
func _cab(b) -> void:
	var floor_y := 0.205
	# The driver's seat on its box.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.290, -0.080)), Vector3(0.175, 0.086, 0.125), 0.012, 1, CB.M_PAINT,
			Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.398, -0.088)), Vector3(0.165, 0.030, 0.118), 0.022, 2, CB.M_DARK,
			C_VINYL_DARK)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.0, 0.490, 0.040)), Vector3(0.160, 0.072, 0.020), 0.016, 2,
			CB.M_DARK, C_VINYL_DARK)
	# The rail across behind it, between the grab poles, the passengers' handhold.
	var px: float = HOOD_X - 0.002
	b.tube(PackedVector3Array([Vector3(-px, 0.600, POLE_Z), Vector3(px, 0.600, POLE_Z)]), 0.0085, 8, CB.M_ALLOY, C_POLE,
			false, false)
	# The bench: a cushion in red vinyl on the deck, cream piping, a pleated backrest.
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.490, 0.425)), Vector3(0.360, 0.032, 0.125), 0.024, 2, CB.M_DARK, C_VINYL)
	b.tube(PackedVector3Array([Vector3(-0.350, 0.514, 0.302), Vector3(0.350, 0.514, 0.302)]), 0.0050, 6, CB.M_DARK,
			C_CREAM, true, true)
	var rake := Basis(Vector3.RIGHT, 0.16)
	var back_c := Vector3(0.0, 0.640, 0.545)
	b.rbox(Transform3D(rake, back_c), Vector3(0.360, 0.120, 0.026), 0.022, 2, CB.M_DARK, C_VINYL)
	for k in 6:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(-0.300 + 0.120 * k, 0.0, -0.026)), Vector3(0.0035, 0.100, 0.003),
				0.002, 1, CB.M_DARK, C_CREAM)
	# The floors' ribbed mats.
	for z in [-0.420, -0.360, -0.300, -0.240]:
		b.rbox(Transform3D(Basis(), Vector3(0.0, floor_y + 0.003, z)), Vector3(0.160, 0.0025, 0.012), 0.002, 1, CB.M_DARK,
				C_DARK)
	# The marigold garland across the top of the windscreen, inside, a little charm at its middle.
	var g0: Vector3 = _screen_pt(-0.88, 0.92, -0.030)
	var g1: Vector3 = _screen_pt(0.88, 0.92, -0.030)
	var count := 19
	var cord := PackedVector3Array([_screen_pt(-1.0, 0.95, -0.010)])
	for k in 25:
		var t: float = float(k) / 24.0
		cord.append(g0.lerp(g1, t) + Vector3(0, -0.070 * 4.0 * t * (1.0 - t), 0.006 * sin(t * PI)))
	cord.append(_screen_pt(1.0, 0.95, -0.010))
	b.tube(cord, 0.0016, 4, CB.M_DARK, C_DARK, false, false)
	for k in count:
		var t: float = float(k) / (count - 1)
		var p: Vector3 = g0.lerp(g1, t) + Vector3(0, -0.070 * 4.0 * t * (1.0 - t), 0.006 * sin(t * PI))
		b.rbox(Transform3D(Basis(Vector3.UP, t * 5.0), p), Vector3(0.011, 0.011, 0.011), 0.010, 1, CB.M_DARK,
				MARIGOLD[k % 2])
	var gm: Vector3 = g0.lerp(g1, 0.5) + Vector3(0, -0.070, 0.006)
	b.tube(PackedVector3Array([gm, gm + Vector3(0, -0.050, 0)]), 0.0015, 4, CB.M_DARK, C_DARK, false, false)
	_knob(b, gm + Vector3(0, -0.060, 0))
	b.rbox(Transform3D(Basis(), gm + Vector3(0, -0.060, 0)), Vector3(0.012, 0.014, 0.004), 0.004, 2, CB.M_CHROME,
			Color(0.95, 0.75, 0.30))


## The back: the spare wheel on its carrier (the plate on its cover), the bumper, the exhaust.
func _rear(b) -> void:
	var sc := Vector3(0.0, 0.365, 0.0)
	var sf: Array = face_frame(0.0, sc.y, false)
	var z0: float = (sf[0] as Vector3).z
	sc.z = z0 + 0.046
	# The tyre (axis along z) and the cover over its face.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	var prof2 := PackedVector2Array()
	for p in TYRE_HALF:
		prof2.append(Vector2(p[0], p[1] * 0.88))
	for k in range(TYRE_HALF.size() - 1, -1, -1):
		prof2.append(Vector2(-TYRE_HALF[k][0], TYRE_HALF[k][1] * 0.88))
	b.lathe(sc, Vector3.BACK, prof2, 32, CB.M_RUBBER, C_RUBBER)
	b.orient_away_from(vb, ib, sc)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(sc + Vector3(0, 0, 0.040), Vector3.BACK, PackedVector2Array([Vector2(-0.010, 0.128), Vector2(0.000, 0.132),
			Vector2(0.008, 0.124), Vector2(0.012, 0.100), Vector2(0.014, 0.0)]), 32, CB.M_PAINT, Color(1, 1, 1))
	b.orient_away_from(vb, ib, sc)
	var ring := PackedVector3Array()
	for k in 33:
		var a: float = TAU * k / 32.0
		ring.append(sc + Vector3(cos(a) * 0.112, sin(a) * 0.112, 0.0525))
	b.tube(ring, 0.0045, 6, CB.M_ANODISED, Color(1, 1, 1), false, false)
	# The plate on the cover.
	var pb := Basis()
	var pc: Vector3 = sc + Vector3(0, -0.015, 0.0555)
	b.rbox(Transform3D(pb, pc), Vector3(0.075, 0.030, 0.003), 0.003, 1, CB.M_DARK, C_PLATE)
	_plate_text(b, pc + Vector3(0, 0, 0.0035), pb, 0.060, 0.017)
	# Its steel rim across the tyre's middle, a boss at the hub, and the carrier: two arms from the body to the boss.
	b.disc(sc + Vector3(0, 0, -0.004), Vector3.FORWARD, 0.104, 0.0, 28, CB.M_DARK, C_STEEL)
	b.disc(sc + Vector3(0, 0, -0.003), Vector3.BACK, 0.104, 0.0, 28, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([sc + Vector3(0, 0, -0.030), sc + Vector3(0, 0, 0.036)]), 0.026, 12, CB.M_DARK, C_STEEL,
			true, true)
	for sx in [-1.0, 1.0]:
		b.tube(PackedVector3Array([Vector3(sx * 0.060, sc.y + 0.050, z0 - 0.010), Vector3(sx * 0.018, sc.y + 0.012,
				sc.z - 0.020)]), 0.008, 6, CB.M_DARK, C_STEEL, false, true)
	# The bumper: a chrome bar on two brackets.
	var by := 0.205
	var path := PackedVector3Array()
	for k in 13:
		var x: float = lerpf(-0.330, 0.330, k / 12.0)
		path.append(Vector3(x, by, shell_z(x, 0.24, false) + 0.055))
	b.oval_tube(path, 0.015, 0.013, Vector3.UP, 10, CB.M_CHROME, C_CHROME, true)
	for sx in [-0.250, 0.250]:
		b.tube(PackedVector3Array([Vector3(sx, by, shell_z(sx, 0.24, false) + 0.050), Vector3(sx, by + 0.03,
				shell_z(sx, 0.24, false) - 0.04)]), 0.007, 6, CB.M_DARK, C_STEEL, false, false)
	# The exhaust: out under the left of the tail, turned down a little, a chrome tip.
	var e0 := Vector3(-0.200, 0.120, 0.640)
	var e1 := Vector3(-0.235, 0.112, 0.880)
	b.tube(PackedVector3Array([e0, e1]), 0.017, 10, CB.M_DARK, C_STEEL, false, false)
	b.tube(PackedVector3Array([e1, e1 + Vector3(-0.004, -0.003, 0.035)]), 0.020, 12, CB.M_CHROME, C_CHROME, false, true)
	b.disc(e1 + Vector3(-0.004, -0.003, 0.0355), Vector3.BACK, 0.013, 0.0, 12, CB.M_DARK, C_DARKER)


# ============================================================================================
#  The parts that steer
# ============================================================================================

func build_steered(b, part: String) -> void:
	var v0: int = b.vertex_count()
	var entry: Array = STEERED_PARTS[part]
	if part == "Fork":
		_fork(b)
	elif part == "Handlebar":
		_handlebar(b)
	# Built in the cart frame: into the part's own (its origin, its y the steering axis).
	var xf := Transform3D(Basis(Vector3.RIGHT, entry[1]), entry[0])
	b.transform_from(v0, xf.affine_inverse())


## The fork: two legs (dark sliders, chrome stanchions) from the axle up to a crown under the cowl, the mudguard on
## its stays, the axle's nuts.
func _fork(b) -> void:
	var fx := 0.068
	var crown_y := 0.372
	for sx in [-1.0, 1.0]:
		var x: float = sx * fx
		b.tube(PackedVector3Array([Vector3(x, HUB_Y - 0.020, AXLE_F), Vector3(x, HUB_Y + 0.090, AXLE_F)]), 0.0155, 10,
				CB.M_DARK, C_DARK, true, true)
		b.tube(PackedVector3Array([Vector3(x, HUB_Y + 0.088, AXLE_F), Vector3(x, crown_y, AXLE_F)]), 0.0105, 10,
				CB.M_CHROME, C_CHROME, false, false)
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		var nut := Vector3(x + sx * 0.010, HUB_Y, AXLE_F)
		b.lathe(nut, Vector3(sx, 0, 0), PackedVector2Array([Vector2(-0.006, 0.011), Vector2(0.004, 0.011),
				Vector2(0.007, 0.006), Vector2(0.008, 0.0)]), 6, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, nut - Vector3(sx * 0.01, 0, 0))
	# The axle through the hub.
	b.tube(PackedVector3Array([Vector3(-fx, HUB_Y, AXLE_F), Vector3(fx, HUB_Y, AXLE_F)]), 0.0065, 8, CB.M_CHROME, C_CHROME,
			false, false)
	b.rbox(Transform3D(Basis(), Vector3(0.0, crown_y, AXLE_F)), Vector3(fx + 0.018, 0.012, 0.024), 0.008, 2, CB.M_DARK,
			C_DARK)
	b.tube(PackedVector3Array([Vector3(0.0, crown_y, AXLE_F), Vector3(0.0, crown_y + 0.04, AXLE_F)]), 0.016, 10,
			CB.M_DARK, C_DARK, false, false)
	# The mudguard: a crowned strip over the tyre, from in front of it round the top to behind it.
	var r := 0.181
	var path := PackedVector3Array()
	for k in 25:
		var th: float = deg_to_rad(lerpf(-48.0, 112.0, k / 24.0))
		path.append(Vector3(0.0, HUB_Y + r * cos(th), AXLE_F - r * sin(th)))
	var lens_prof := PackedVector2Array([Vector2(-0.057, 0.0), Vector2(-0.040, 0.007), Vector2(0.0, 0.011),
		Vector2(0.040, 0.007), Vector2(0.057, 0.0), Vector2(0.040, 0.002), Vector2(0.0, 0.004), Vector2(-0.040, 0.002)])
	sweep(b, path, Vector3.RIGHT, Vector3(0.0, 0.85, -0.53), lens_prof, CB.M_PAINT, Color(1, 1, 1))
	# A chrome tip on its front end.
	var tip: Vector3 = path[path.size() - 1]
	b.rbox(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(112.0)), tip), Vector3(0.050, 0.004, 0.010), 0.003, 1, CB.M_CHROME,
			C_CHROME)
	# Stays from the guard's sides to the sliders.
	for sx in [-1.0, 1.0]:
		for th_deg in [62.0, -20.0]:
			var th: float = deg_to_rad(th_deg)
			var p := Vector3(sx * 0.054, HUB_Y + (r + 0.004) * cos(th), AXLE_F - (r + 0.004) * sin(th))
			b.tube(PackedVector3Array([p, Vector3(sx * (fx - 0.004), HUB_Y + 0.060, AXLE_F)]), 0.0032, 5, CB.M_DARK,
					C_STEEL, false, false)


## The handlebars: a stem out of the dash, a chrome bar swept back to black grips, a brake lever, the speedo on the
## clamp, all about the raked column (BAR_O).
func _handlebar(b) -> void:
	var col := Vector3(0.0, cos(BAR_RAKE), sin(BAR_RAKE))
	var c: Vector3 = BAR_O + col * 0.030
	b.tube(PackedVector3Array([BAR_O - col * 0.070, c]), 0.012, 10, CB.M_DARK, C_DARK, false, false)
	b.rbox(Transform3D(Basis(Vector3.RIGHT, BAR_RAKE), c), Vector3(0.034, 0.014, 0.020), 0.007, 2, CB.M_DARK, C_DARK)
	var bar := []
	for x in [-0.230, -0.155, -0.085, 0.0, 0.085, 0.155, 0.230]:
		var ax: float = absf(x)
		bar.append(c + Vector3(x, 0.008 + 0.026 * pow(ax / 0.230, 2.0), 0.060 * pow(ax / 0.230, 1.6)))
	b.tube(_rounded(bar, 0.04), 0.0088, 8, CB.M_CHROME, C_CHROME, true, true)
	for sx in [-1.0, 1.0]:
		var g0: Vector3 = bar[3 + int(sx) * 2]
		var g1: Vector3 = bar[3 + int(sx) * 3]
		var d: Vector3 = (g1 - g0).normalized()
		b.tube(PackedVector3Array([g0 + d * 0.006, g1 + d * 0.008]), 0.0135, 10, CB.M_DARK, C_DARK, true, true)
		# The lever in front of the grip.
		var lp: Vector3 = g0 + Vector3(0, 0, -0.012)
		b.tube(PackedVector3Array([lp, lp + d * 0.050 + Vector3(0, -0.006, -0.020)]), 0.0035, 5, CB.M_ALLOY,
				Color(0.80, 0.81, 0.83), true, true)
	# The speedo: a dial facing the driver on the clamp.
	var face := Vector3(0.0, 0.55, 0.835).normalized()
	var sp: Vector3 = c + Vector3(0.0, 0.032, -0.006)
	b.rbox(Transform3D(facing(face), sp - face * 0.010), Vector3(0.040, 0.034, 0.016), 0.012, 2, CB.M_DARK, C_DARK)
	b.disc(sp + face * 0.0065, face, 0.026, 0.0, 20, CB.M_DARK, C_GAUGE)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(sp + face * 0.006, face, PackedVector2Array([Vector2(-0.003, 0.031), Vector2(0.003, 0.030),
			Vector2(0.004, 0.026)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, sp - face * 0.01)
	var fb: Basis = facing(face)
	b.rbox(Transform3D(fb * Basis(Vector3.BACK, 0.7), sp + face * 0.0072 + fb * Vector3(0.006, 0.006, 0.0)),
			Vector3(0.012, 0.0013, 0.0006), 0.0005, 1, CB.M_TAILLAMP, C_TAILLAMP)


# ============================================================================================
#  Wheels
# ============================================================================================

## The front pair: the whole wheel on the right; the left an empty mesh with the wheel's bounds (see the header).
func build_wheel(b, side: float) -> void:
	if side > 0.0:
		_wheel(b)
		return
	var hw: float = -float(TYRE_HALF[0][0]) - 0.011
	var r: float = TYRE_HALF[TYRE_HALF.size() - 1][1]
	var a: int = b.vertex(Vector3(-hw, -r, -r), Vector3.UP, CB.M_DARK, C_DARK)
	var c: int = b.vertex(Vector3(hw, r, r), Vector3.UP, CB.M_DARK, C_DARK)
	b._i.append(a)
	b._i.append(c)
	b._i.append(c)


func build_rear_wheel(b, side: float) -> void:
	_wheel(b)
	if side < 0.0:
		b.mirror_in_place()


## A small pressed-steel wheel: the tyre, a dished disc in the rim colour with its ring of nuts, a little chrome cap.
func _wheel(b) -> void:
	tyre(b, TYRE_HALF, 36, C_RUBBER)
	# The tread's blocks: little bars across the crown, staggered.
	for k in 30:
		var a: float = TAU * k / 30.0
		var fr: Array = wheel_frame(a)
		var rd: Vector3 = fr[0]
		var tg: Vector3 = fr[1]
		var x: float = 0.014 * (1.0 if k % 2 == 0 else -1.0)
		var c: Vector3 = rd * 0.1545 + Vector3(x, 0, 0)
		_box(b, Transform3D(Basis(Vector3.RIGHT, a), c), Vector3(0.016, 0.0028, 0.006), CB.M_RUBBER, C_RUBBER * 0.9)
	var hw: float = -float(TYRE_HALF[0][0])
	var rim_r := 0.096
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - 0.016
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.010, rim_r - 0.002), Vector2(lip_x - 0.002, rim_r + 0.004),
			Vector2(lip_x + 0.003, rim_r + 0.002), Vector2(lip_x + 0.003, rim_r - 0.004), Vector2(lip_x - 0.006, rim_r - 0.010),
			Vector2(face_x, 0.068), Vector2(face_x + 0.006, 0.040), Vector2(face_x + 0.004, 0.024)]), 32, CB.M_RIM, C_RIM,
			"out", Vector3(lip_x - 0.06, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.004, 0.0, 0.0), Vector3.RIGHT, 0.024, 0.0, 20, CB.M_RIM, C_RIM)
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.010, rim_r - 0.002), Vector2(-hw + 0.004, rim_r - 0.004),
			Vector2(-hw + 0.001, rim_r + 0.001)]), 32, CB.M_RIM, Color(0.6, 0.6, 0.62), "in")
	b.disc(Vector3(-hw + 0.004, 0.0, 0.0), Vector3.LEFT, rim_r - 0.004, 0.0, 24, CB.M_DARK, C_DARKER)
	# The nuts round the cap, and the cap.
	for k in 5:
		var a: float = TAU * k / 5.0 + 0.3
		var fr: Array = wheel_frame(a)
		var nc: Vector3 = Vector3(face_x + 0.006, 0, 0) + (fr[0] as Vector3) * 0.050
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.lathe(nc, Vector3.RIGHT, PackedVector2Array([Vector2(-0.002, 0.0062), Vector2(0.006, 0.0062), Vector2(0.008, 0.004),
				Vector2(0.0085, 0.0)]), 6, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, nc - Vector3(0.004, 0, 0))
	var vb2: int = b.vertex_count()
	var ib2: int = b.index_count()
	b.lathe(Vector3(face_x + 0.006, 0, 0), Vector3.RIGHT, PackedVector2Array([Vector2(-0.002, 0.026), Vector2(0.008, 0.024),
			Vector2(0.015, 0.016), Vector2(0.018, 0.0)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb2, ib2, Vector3(face_x - 0.01, 0, 0))


## A plain flat-shaded box (12 triangles): `xf` places it, `h` its half size.
func _box(b, xf: Transform3D, h: Vector3, mat: int, col: Color) -> void:
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var nrm := Vector3.ZERO
			nrm[axis] = sgn
			var u: int = (axis + 1) % 3
			var v: int = (axis + 2) % 3
			var ids := []
			for k in 4:
				var q := Vector3.ZERO
				q[axis] = sgn * h[axis]
				q[u] = h[u] * (1.0 if k < 2 else -1.0)
				q[v] = h[v] * (1.0 if k == 0 or k == 3 else -1.0)
				ids.append(b.vertex(xf * q, xf.basis * nrm, mat, col))
			b.quad(ids[0], ids[1], ids[2], ids[3])


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var z: float = p.z
	var w: float = prof["w"].at(z)
	# Inside the troughs: the floor, the walls' insides; the cowl's back (the dash) and the bench's front.
	if z > CAB_Z.x - 0.004 and z < CAB_Z.y + 0.004:
		var sill: Vector2 = _sill(z)
		if p.x < sill.x - 0.002 and p.y < sill.y - 0.004 and n.x < 0.6:
			black = 0.88
	if n.z > 0.5 and absf(z - COWL_BACK_Z) < 0.02 and p.y > 0.215:
		black = 0.92
	if n.z < -0.5 and absf(z - 0.305) < 0.02 and p.y < 0.47:
		black = 0.85
	var on_side: bool = n.x > 0.45 and p.x > w - 0.03
	if on_side:
		# A chrome strip low along the side, and the panel line of the rear body's flank.
		if z > -0.86 and z < 0.84:
			var sy: float = 0.215 if z > -0.50 else 0.400
			if z > -0.56 and z < -0.48:
				sy = lerpf(0.400, 0.215, (z + 0.56) / 0.08)
			chrome = maxf(chrome, _cover(absf(p.y - sy) - 0.0045, fp))
		# Louvres on the rear body's flank (the engine's air), above the arch.
		if z > 0.590 and z < 0.790 and p.y > 0.395 and p.y < 0.505:
			var lz: float = fposmod(z - 0.590, 0.025) - 0.0125
			var dd: float = maxf(absf(lz) - 0.0045, absf(p.y - 0.450) - 0.045)
			black = maxf(black, 0.9 * _cover(dd, fp))
		# The engine cover's outline round the louvres.
		var d: float = _sd_box(Vector2(z - 0.690, p.y - 0.450), Vector2(0.115, 0.068)) - 0.012
		gap = maxf(gap, _cover(absf(d) - 0.0015, fp))
	# A seam round the cowl's face and along the rear deck.
	if n.y > 0.5 and z > 0.56 and z < 0.84:
		gap = maxf(gap, _cover(absf(_sd_box(Vector2(p.x, z - 0.700), Vector2(0.250, 0.110)) - 0.03) - 0.0015, fp))
	# The rims of the passengers' side panels are capped in chrome.
	if n.y > 0.6 and z > 0.0 and z < 0.31:
		var sill: Vector2 = _sill(z)
		if p.y > sill.y - 0.006 and p.x > sill.x - 0.004:
			chrome = maxf(chrome, 1.0)
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(0.0, gap, chrome, black)
