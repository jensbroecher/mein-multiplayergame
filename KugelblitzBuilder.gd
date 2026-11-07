# KugelblitzBuilder.gd
#
# The Kugelblitz ("ball lightning"): a 1950s-style bubble car (an original design with a made-up name).
# An egg of a body in two-tone paint, a chrome spear along each side, wheel arches over tiny whitewall
# wheels with big chrome hubcaps; a round-eyed nose (two headlamps under painted brows, a chrome grille
# smiling under them, a badge, chrome bumpers with overriders front and back); and, sitting on the body's
# rim, a see-through glass bubble (build_glass()) framed in chrome, with the cabin inside: a two-tone
# bench seat, a cream steering wheel and a big speedo, a gear lever, and a pair of fuzzy dice hanging
# from the bubble's frame. Behind it the tail rises into two little fins carrying the taillamps, a
# chrome luggage rack with a strapped suitcase on the engine cover, louvres either side.
#
# The shell's section above the side is the Meteor's (_upper_segments: shoulder, rim, wall, corner,
# top, keyed along the car): over the nose and the tail the shoulder is nearly all of it, a dome; under
# the bubble the rim is where the glass sits and the wall runs down inside to the floor (a trough), so
# the cabin is open under the glass. The arches are lifted into the bottom over each wheel (_bot_knots,
# as on the Interceptor), with dark liners inside.
extends "res://CarDesign.gd"

const FRONT_X := 0.340
const REAR_X := 0.320
const AXLE_F := -0.580
const AXLE_R := 0.500
const HUB_Y := 0.150
const ARCH_RZ := 0.170
const ARCH_CY := 0.100
const ARCH_RY := 0.235
const ARCH_E := 2.4
const BASE_BOT := 0.110

# The section above the side, keyframed (see MeteorBuilder): z; belt; sx, sy (the shoulder); rim_w;
# wall_dx; edge; cx, cy; crown. Under the bubble (CABIN_Z) the shoulder is short and the wall runs down
# to the floor.
const KEYS := [
	# z       belt   sx     sy     rim_w  wall_dx edge   cx     cy      crown
	[-0.880, 0.300, 0.130, 0.090, 0.003, 0.002, 0.394, 0.004, 0.000, 0.006],
	[-0.780, 0.330, 0.240, 0.140, 0.003, 0.002, 0.474, 0.004, 0.000, 0.008],
	[-0.640, 0.360, 0.300, 0.170, 0.003, 0.002, 0.534, 0.004, 0.000, 0.010],
	[-0.500, 0.390, 0.335, 0.170, 0.003, 0.002, 0.564, 0.004, 0.000, 0.010],
	[-0.410, 0.400, 0.348, 0.165, 0.003, 0.002, 0.568, 0.004, 0.000, 0.010],
	[-0.395, 0.410, 0.030, 0.062, 0.022, 0.010, 0.165, 0.020, -0.020, 0.000],
	[0.270, 0.420, 0.030, 0.062, 0.022, 0.010, 0.165, 0.020, -0.020, 0.000],
	[0.285, 0.420, 0.345, 0.175, 0.003, 0.002, 0.598, 0.004, 0.000, 0.012],
	[0.450, 0.410, 0.335, 0.170, 0.003, 0.002, 0.583, 0.004, 0.000, 0.012],
	[0.620, 0.390, 0.300, 0.150, 0.003, 0.002, 0.543, 0.004, 0.000, 0.010],
	[0.760, 0.360, 0.230, 0.110, 0.003, 0.002, 0.473, 0.004, 0.000, 0.008],
	[0.860, 0.330, 0.120, 0.065, 0.003, 0.002, 0.398, 0.004, 0.000, 0.005],
]
const KEY_NAMES := ["belt", "sx", "sy", "rim_w", "wall_dx", "edge", "cx", "cy", "crown"]
const W_KNOTS := [[-0.88, 0.160], [-0.80, 0.270], [-0.68, 0.335], [-0.50, 0.375], [-0.20, 0.392], [0.10, 0.392],
	[0.40, 0.378], [0.62, 0.330], [0.76, 0.262], [0.86, 0.150]]
const CABIN_Z := Vector2(-0.400, 0.278)

# The bubble: its crown along the car (it sits on the cabin's rim; its ends meet the nose's and the
# tail's domes), and where its frame runs.
const BUBBLE_Z := Vector2(-0.420, 0.290)
const BUBBLE_TOP := [[-0.420, 0.572], [-0.340, 0.790], [-0.220, 0.895], [-0.050, 0.932], [0.100, 0.918],
	[0.200, 0.850], [0.290, 0.604]]
const GLASS_TINT := Color(0.62, 0.74, 0.78, 0.17)

# A small whitewall tyre (half its profile, bead to tread centre).
const TYRE_HALF := [[-0.040, 0.095], [-0.046, 0.104], [-0.050, 0.118], [-0.050, 0.132], [-0.045, 0.142],
	[-0.034, 0.148], [-0.018, 0.150], [0.0, 0.150]]

const C_RUBBER := Color(0.15, 0.15, 0.16)
const C_WHITEWALL := Color(0.92, 0.92, 0.89)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_STEEL := Color(0.15, 0.15, 0.16)
const C_CHROME := Color(0.93, 0.94, 0.96)
const C_RIM := Color(1, 1, 1)
const C_SEAT := Color(0.66, 0.10, 0.08)
const C_CREAM := Color(0.93, 0.89, 0.78)
const C_CASE := Color(0.46, 0.26, 0.12)
const C_STRAP := Color(0.22, 0.12, 0.05)
const C_DICE := Color(0.96, 0.42, 0.64)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)
const C_GAUGE := Color(0.92, 0.89, 0.80)

const PAINT_LAYOUT := {
	"nose_z": -0.88, "tail_z": 0.86, "belt_y": 0.392, "side_x": 0.30,
	"door_z": -0.080, "door_y": 0.262, "roundel_r": 0.072,
	"hood_z": -0.640, "hood_r": 0.050, "stripe_w": 0.045, "stripe_gap": 0.016,
}
const ANTENNA_POS := Vector3(-0.17, 0.571, 0.36)
const WHEEL_POSITIONS := {
	"FL": Vector3(-FRONT_X, HUB_Y, AXLE_F), "FR": Vector3(FRONT_X, HUB_Y, AXLE_F),
	"RL": Vector3(-REAR_X, HUB_Y, AXLE_R), "RR": Vector3(REAR_X, HUB_Y, AXLE_R),
}

var _bubble_top: CB.Profile


func _init() -> void:
	nose_tip = -0.880
	nose_cap = 0.090
	nose_cap_y = 0.300
	nose_cap_exp = Vector2(2.2, 2.0)
	tail_tip = 0.860
	tail_cap = 0.080
	tail_cap_y = 0.300
	tail_cap_exp = Vector2(2.2, 2.0)
	segment_counts = [2, 3, 4, 8, 2, 5, 4, 6]
	half_ring = 34
	bottom_radius = 0.040
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[6] + key[9]])
	setup_shell(knots)
	_bubble_top = CB.Profile.new(BUBBLE_TOP)


## The bottom: flat, rising into the egg's ends, lifted in a rounded arch over each wheel.
static func _bot_knots() -> Array:
	var k := [[-0.880, 0.200], [-0.800, 0.140], [AXLE_F - ARCH_RZ - 0.060, BASE_BOT]]
	for az in [AXLE_F, AXLE_R]:
		k.append([az - ARCH_RZ - 0.012, BASE_BOT])
		for s in 21:
			var t: float = s / 10.0 - 1.0
			k.append([az + ARCH_RZ * t, ARCH_CY + ARCH_RY * pow(maxf(1.0 - pow(absf(t), ARCH_E), 0.0), 1.0 / ARCH_E)])
		k.append([az + ARCH_RZ + 0.012, BASE_BOT])
	k.append([0.780, 0.150])
	k.append([0.860, 0.210])
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


## Where the bubble sits at z: the middle of the cabin's rim (x, y).
func _bubble_base(z: float) -> Vector2:
	var t: float = clampf((z - BUBBLE_Z.x) / (BUBBLE_Z.y - BUBBLE_Z.x), 0.0, 1.0)
	return Vector2(prof["w"].at(z) - 0.030 - 0.011, lerpf(0.475, 0.485, t))


## A ring of the bubble at z, `m` + 1 points from its base on the left over the crown to the right
## (a cubic each side, as the Fulmine's canopy), pushed `out` along its normal.
func _bubble_ring(z: float, m: int, out := 0.0) -> PackedVector3Array:
	var base: Vector2 = _bubble_base(z)
	var yr: float = maxf(_bubble_top.at(z), base.y + 0.004)
	var h: float = yr - base.y
	var p0 := base
	var p1 := Vector2(base.x + 0.02 * h, base.y + 0.70 * h)
	var p2 := Vector2(0.62 * base.x, yr)
	var p3 := Vector2(0.0, yr)
	var half: int = m / 2
	var pts := PackedVector3Array()
	for j in m + 1:
		var t: float = 1.0 - absf(float(j - half)) / half
		var q: Vector2 = p0.bezier_interpolate(p1, p2, p3, t)
		if out != 0.0:
			var tan2: Vector2 = p0.bezier_derivative(p1, p2, p3, clampf(t, 0.001, 0.999))
			var nrm := Vector2(tan2.y, -tan2.x).normalized()
			if nrm.dot(q - Vector2(0.0, base.y)) < 0.0:
				nrm = -nrm
			q += nrm * out
		pts.append(Vector3(-q.x if j <= half else q.x, q.y, z))
	return pts


func build_glass(b) -> void:
	var n := 44
	var m := 32
	var rows := []
	for i in n + 1:
		rows.append(_bubble_ring(lerpf(BUBBLE_Z.x, BUBBLE_Z.y, float(i) / n), m))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_DARK, GLASS_TINT, false, false)
	if b._n[vb + (n / 2) * (m + 1) + m / 2].y < 0.0:
		b.flip(vb, ib)


# ============================================================================================
#  Body
# ============================================================================================

func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_bubble_frame(b)
	_nose(b)
	_bumper(b, true)
	_bumper(b, false)
	_cabin(b)
	_luggage(b)
	# The exhaust's chrome tip under the rear bumper, on the right.
	b.tube(PackedVector3Array([Vector3(0.16, 0.135, 0.70), Vector3(0.16, 0.135, 0.885)]), 0.016, 12, CB.M_CHROME, C_CHROME,
			false, true)
	b.disc(Vector3(0.16, 0.135, 0.8858), Vector3.BACK, 0.011, 0.0, 12, CB.M_DARK, C_DARKER)


## Right-hand parts, mirrored by build_body(): arch liners, the headlamp and its brow, an indicator,
## the tail fin with its lamp, the door handle.
func _side_parts(b) -> void:
	b.rbox(Transform3D(Basis(), Vector3(0.205, 0.215, AXLE_F)), Vector3(0.004, 0.115, ARCH_RZ), 0.003, 1, CB.M_DARK,
			C_DARKER)
	b.rbox(Transform3D(Basis(), Vector3(0.245, 0.215, AXLE_R)), Vector3(0.004, 0.115, ARCH_RZ), 0.003, 1, CB.M_DARK,
			C_DARKER)
	# The headlamp: a chrome bezel and lens on the nose's corner, a painted brow over it.
	var hl: Array = face_frame(0.215, 0.440, true)
	var c: Vector3 = hl[0] + (hl[1] as Vector3) * 0.006
	var fwd: Vector3 = hl[1]
	round_lamp(b, c, fwd, 0.050, CB.M_HEADLAMP, Color(1, 1, 1))
	var hb: Basis = facing(fwd)
	var brow := PackedVector3Array()
	for k in 13:
		var a: float = PI * (0.08 + 0.84 * k / 12.0)
		brow.append(c + hb.x * cos(a) * 0.062 + hb.y * sin(a) * 0.062 - fwd * 0.004)
	b.tube(brow, 0.011, 8, CB.M_PAINT, Color(1, 1, 1), true, true)
	# Indicator beside the grille.
	var ind: Array = face_frame(0.255, 0.300, true)
	b.rbox(Transform3D(facing(ind[1]), ind[0]), Vector3(0.026, 0.014, 0.008), 0.006, 1, CB.M_TAILLAMP, C_AMBER)
	# Tail fin: a slab rising out of the tail's shoulder, the taillamp at its end in a chrome cup.
	var fx := 0.238
	slab(b, _fin_outline(), fx, 0.016, CB.M_PAINT, Color(1, 1, 1))
	var lamp := Vector3(fx, 0.515, 0.802)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(lamp, Vector3.BACK, PackedVector2Array([Vector2(-0.030, 0.0), Vector2(-0.026, 0.016), Vector2(-0.012, 0.026),
			Vector2(0.000, 0.028)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, lamp + Vector3.BACK * 0.01)
	round_lamp(b, lamp, Vector3.BACK, 0.024, CB.M_TAILLAMP, C_TAILLAMP)
	# Door handle under the bubble's rim.
	var wd: float = prof["w"].at(0.140)
	b.rbox(Transform3D(Basis(), Vector3(wd + 0.005, 0.395, 0.140)), Vector3(0.006, 0.007, 0.030), 0.005, 1, CB.M_CHROME,
			C_CHROME)


## The tail fin's side outline (z, y): its foot buried in the tail's shoulder, its top edge rising back
## to a point over the taillamp.
static func _fin_outline() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.400, 0.500), Vector2(0.740, 0.390), Vector2(0.800, 0.470),
		Vector2(0.795, 0.560), Vector2(0.520, 0.548)])


## The bubble's chrome frame: rails along its foot, its front and back edges, a strip over the crown.
func _bubble_frame(b) -> void:
	for sx in [-1.0, 1.0]:
		var rail := PackedVector3Array()
		for k in 37:
			var z: float = lerpf(BUBBLE_Z.x + 0.004, BUBBLE_Z.y - 0.004, k / 36.0)
			var base: Vector2 = _bubble_base(z)
			rail.append(Vector3(base.x * sx, base.y + 0.003, z))
		b.tube(rail, 0.0075, 8, CB.M_CHROME, C_CHROME, true, true)
	b.tube(_bubble_ring(BUBBLE_Z.x + 0.004, 28, 0.003), 0.0075, 8, CB.M_CHROME, C_CHROME, true, true)
	b.tube(_bubble_ring(BUBBLE_Z.y - 0.004, 28, 0.003), 0.0075, 8, CB.M_CHROME, C_CHROME, true, true)
	var strip := PackedVector3Array()
	for k in 37:
		var z: float = lerpf(BUBBLE_Z.x + 0.004, BUBBLE_Z.y - 0.004, k / 36.0)
		strip.append(Vector3(0.0, _bubble_top.at(z) + 0.004, z))
	b.oval_tube(strip, 0.012, 0.004, Vector3.UP, 8, CB.M_CHROME, C_CHROME, true)
	# A hoop across the bubble's middle (where the roof lifts off).
	b.tube(_bubble_ring(-0.020, 28, 0.003), 0.0060, 8, CB.M_CHROME, C_CHROME, true, true)


## The nose: the chrome grille's smile, the badge.
func _nose(b) -> void:
	# The smile: a squashed ellipse, deeper below, its dark core a patch lying on the curved nose.
	var outline := PackedVector3Array()
	for k in 25:
		var a: float = TAU * k / 24.0
		var x: float = cos(a) * 0.125
		var y: float = 0.270 + _smile_y(sin(a))
		outline.append(Vector3(x, y, shell_z(x, y, true) - 0.004))
	var rows := []
	for i in 13:
		var u: float = lerpf(-0.97, 0.97, i / 12.0)
		var x: float = u * 0.125
		var s: float = sqrt(maxf(1.0 - u * u, 0.0))
		var row := PackedVector3Array()
		for j in 5:
			var y: float = 0.270 + lerpf(_smile_y(-s), _smile_y(s), j / 4.0) * 0.92
			row.append(Vector3(x, y, shell_z(x, y, true) - 0.002))
		rows.append(row)
	var vbc: int = b.vertex_count()
	var ibc: int = b.index_count()
	b.grid(rows, CB.M_DARK, C_DARKER, false, false)
	b.orient_toward(vbc, ibc, Vector3.FORWARD)
	b.tube(outline, 0.0085, 8, CB.M_CHROME, C_CHROME, false, false)
	for k in 3:
		var y: float = 0.270 - 0.020 + 0.020 * k
		var hw: float = 0.118 * sqrt(maxf(1.0 - pow((y - 0.270) / 0.036, 2.0), 0.0))
		var bar_path := PackedVector3Array()
		for s in 9:
			var x: float = lerpf(-hw, hw, s / 8.0)
			bar_path.append(Vector3(x, y, shell_z(x, y, true) - 0.006))
		b.tube(bar_path, 0.0042, 6, CB.M_CHROME, C_CHROME, true, true)
	# The badge on the nose's top.
	var bz := -0.790
	var by: float = top_y(0.0, bz)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.0, by - 0.004, bz), Vector3(0.0, 0.8, -0.6).normalized(), PackedVector2Array([Vector2(0.0, 0.028),
			Vector2(0.006, 0.026), Vector2(0.009, 0.016), Vector2(0.010, 0.0)]), 18, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.0, by - 0.02, bz))


## The grille smile's height off its middle for sin(angle) s round it: deeper below than above.
static func _smile_y(s: float) -> float:
	return s * 0.036 - (0.010 * s * s if s < 0.0 else 0.0)


## A chrome bumper wrapped round the nose (or the tail) on its two overriders.
func _bumper(b, front: bool) -> void:
	var y := 0.205
	var path := PackedVector3Array()
	for k in 17:
		var x: float = lerpf(-0.240, 0.240, k / 16.0)
		var z: float = shell_z(x, y, front)
		path.append(Vector3(x, y, z + (-0.030 if front else 0.030)))
	b.oval_tube(path, 0.020, 0.016, Vector3.UP, 12, CB.M_CHROME, C_CHROME, true)
	for sx in [-1.0, 1.0]:
		var x: float = 0.140 * sx
		var z: float = shell_z(x, y, front) + (-0.044 if front else 0.044)
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.lathe(Vector3(x, 0.150, z), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.016), Vector2(0.060, 0.019),
				Vector2(0.095, 0.014), Vector2(0.110, 0.0)]), 12, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, Vector3(x, 0.20, z))
		# Its bracket back to the body.
		b.tube(PackedVector3Array([Vector3(x, 0.200, z), Vector3(x, 0.200, z + (0.06 if front else -0.06))]), 0.007, 6,
				CB.M_DARK, C_STEEL, false, false)


## The cabin under the bubble: the bench seat, the steering wheel and speedo, the gear lever, the dice.
func _cabin(b) -> void:
	var floor_y := 0.165
	b.rbox(Transform3D(Basis(), Vector3(0.0, floor_y + 0.050, 0.120)), Vector3(0.270, 0.040, 0.105), 0.028, 2, CB.M_DARK,
			C_SEAT)
	var rake := Basis(Vector3.RIGHT, 0.20)
	var back_c := Vector3(0.0, floor_y + 0.200, 0.232)
	b.rbox(Transform3D(rake, back_c), Vector3(0.270, 0.135, 0.030), 0.028, 2, CB.M_DARK, C_SEAT)
	for k in 5:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, -0.090 + 0.045 * k, -0.031)), Vector3(0.250, 0.005, 0.003),
				0.002, 1, CB.M_DARK, C_CREAM)
	# Cream piping along the cushion's front edge.
	b.tube(PackedVector3Array([Vector3(-0.262, floor_y + 0.084, 0.018), Vector3(0.262, floor_y + 0.084, 0.018)]), 0.0050, 6,
			CB.M_DARK, C_CREAM, true, true)
	# Steering wheel (on the left), in cream bakelite with a chrome horn ring, on its column.
	var c := Vector3(-0.150, 0.425, -0.235)
	var tilt := Basis(Vector3.RIGHT, -0.62)
	var rim := PackedVector3Array()
	for k in 29:
		var a: float = TAU * k / 28.0
		rim.append(c + tilt * Vector3(cos(a) * 0.072, sin(a) * 0.072, 0.0))
	b.tube(rim, 0.0075, 8, CB.M_DARK, C_CREAM, false, false)
	var horn := PackedVector3Array()
	for k in 21:
		var a: float = TAU * k / 20.0
		horn.append(c + tilt * Vector3(cos(a) * 0.040, sin(a) * 0.040, -0.006))
	b.tube(horn, 0.0030, 6, CB.M_CHROME, C_CHROME, false, false)
	for k in 3:
		var a: float = PI * 0.5 + TAU * k / 3.0
		b.tube(PackedVector3Array([c, c + tilt * Vector3(cos(a) * 0.068, sin(a) * 0.068, 0.0)]), 0.0045, 6, CB.M_DARK,
				C_CREAM, false, false)
	b.tube(PackedVector3Array([c, c + tilt * Vector3(0.0, 0.0, -0.17)]), 0.011, 8, CB.M_DARK, C_DARK, false, true)
	# The speedo: a big round dial on a pod on the dash, before the wheel.
	var sc := Vector3(-0.150, 0.420, CABIN_Z.x + 0.020)
	b.rbox(Transform3D(Basis(), sc + Vector3(0.0, -0.030, -0.010)), Vector3(0.060, 0.030, 0.018), 0.014, 2, CB.M_PAINT,
			Color(1, 1, 1))
	b.disc(sc + Vector3(0.0, 0.0, 0.010), Vector3.BACK, 0.042, 0.0, 22, CB.M_DARK, C_GAUGE)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(sc + Vector3(0.0, 0.0, 0.010), Vector3.BACK, PackedVector2Array([Vector2(-0.006, 0.050), Vector2(0.004, 0.049),
			Vector2(0.006, 0.042)]), 22, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, sc + Vector3(0.0, 0.0, -0.01))
	bar(b, sc + Vector3(0.012, 0.012, 0.0115), Vector3(0.016, 0.0016, 0.001), CB.M_TAILLAMP, C_TAILLAMP)
	# Gear lever with a cream knob.
	b.tube(PackedVector3Array([Vector3(0.020, floor_y, -0.170), Vector3(0.030, 0.330, -0.210)]), 0.0045, 6, CB.M_CHROME,
			C_CHROME, false, false)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(0.030, 0.336, -0.212), Vector3.UP, PackedVector2Array([Vector2(-0.014, 0.0), Vector2(-0.010, 0.013),
			Vector2(0.006, 0.014), Vector2(0.014, 0.0)]), 12, CB.M_DARK, C_CREAM)
	b.orient_away_from(vb, ib, Vector3(0.030, 0.336, -0.212))
	# Fuzzy dice on a string from the bubble's crown strip.
	var dz := -0.300
	var top: float = _bubble_top.at(dz) - 0.004
	b.tube(PackedVector3Array([Vector3(0.0, top, dz), Vector3(0.0, top - 0.10, dz)]), 0.0018, 4, CB.M_DARK, C_DARK, false,
			false)
	for d in [[-0.020, 0.30], [0.016, -0.45]]:
		var dc := Vector3(d[0], top - 0.128 + absf(d[0]) * 0.6, dz)
		b.rbox(Transform3D(Basis(Vector3.UP, d[1]) * Basis(Vector3.RIGHT, 0.4), dc), Vector3(0.019, 0.019, 0.019), 0.007, 2,
				CB.M_DARK, C_DICE)
		b.tube(PackedVector3Array([Vector3(0.0, top - 0.10, dz), dc + Vector3(0.0, 0.016, 0.0)]), 0.0016, 4, CB.M_DARK,
				C_DARK, false, false)


## A chrome luggage rack on the engine cover, a suitcase strapped to it.
func _luggage(b) -> void:
	var z0 := 0.380
	var z1 := 0.660
	for sx in [-1.0, 1.0]:
		var x: float = 0.115 * sx
		var rail := PackedVector3Array()
		for k in 9:
			var z: float = lerpf(z0, z1, k / 8.0)
			rail.append(Vector3(x, top_y(x, z) + 0.040, z))
		b.tube(rail, 0.0060, 8, CB.M_CHROME, C_CHROME, true, true)
		for z in [z0 + 0.01, (z0 + z1) * 0.5, z1 - 0.01]:
			var y: float = top_y(x, z)
			b.tube(PackedVector3Array([Vector3(x, y - 0.004, z), Vector3(x, y + 0.040, z)]), 0.0050, 6, CB.M_CHROME,
					C_CHROME, false, false)
	for z in [z0 + 0.05, z0 + 0.14, z0 + 0.23]:
		var y: float = maxf(top_y(0.115, z), top_y(-0.115, z)) + 0.040
		b.tube(PackedVector3Array([Vector3(-0.115, y, z), Vector3(0.115, y, z)]), 0.0045, 6, CB.M_CHROME, C_CHROME, false,
				false)
	# The suitcase: a box with rounded edges, two straps over it, a chrome handle and catches.
	var cz := 0.505
	var cy: float = maxf(top_y(0.115, cz), top_y(0.0, cz)) + 0.040 + 0.050
	var tilt := Basis(Vector3.RIGHT, -atan2(top_y(0.0, cz + 0.05) - top_y(0.0, cz - 0.05), 0.10))
	b.rbox(Transform3D(tilt, Vector3(0.0, cy, cz)), Vector3(0.150, 0.046, 0.098), 0.014, 2, CB.M_DARK, C_CASE)
	for sx in [-0.075, 0.075]:
		b.rbox(Transform3D(tilt, Vector3(sx, cy, cz)), Vector3(0.012, 0.048, 0.100), 0.004, 1, CB.M_DARK, C_STRAP)
	var hc: Vector3 = Vector3(0.0, cy, cz) + tilt * Vector3(0.0, 0.0, -0.100)
	b.tube(_rounded([hc + tilt * Vector3(-0.030, 0.008, 0.0), hc + tilt * Vector3(-0.024, 0.008, -0.020),
			hc + tilt * Vector3(0.024, 0.008, -0.020), hc + tilt * Vector3(0.030, 0.008, 0.0)], 0.01), 0.0045, 6,
			CB.M_CHROME, C_CHROME, false, false)
	for sx in [-0.115, 0.115]:
		b.rbox(Transform3D(tilt, Vector3(sx, cy + 0.030, cz) + tilt * Vector3(0.0, 0.0, -0.099)), Vector3(0.010, 0.006, 0.003),
				0.002, 1, CB.M_CHROME, C_CHROME)


# ============================================================================================
#  Wheels
# ============================================================================================

## A small steel wheel: the whitewall tyre, the rim in the rim colour, a big chrome hubcap.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 40, C_RUBBER)
	var hw: float = -float(TYRE_HALF[0][0])
	var x: float = hw + 0.0110
	var vb0: int = b.vertex_count()
	var ib0: int = b.index_count()
	b.lathe(Vector3.ZERO, Vector3.RIGHT, PackedVector2Array([Vector2(x - 0.002, 0.102), Vector2(x, 0.105),
			Vector2(x, 0.131), Vector2(x - 0.002, 0.134)]), 40, CB.M_RUBBER, C_WHITEWALL)
	b.orient_toward(vb0, ib0, Vector3.RIGHT)
	var rim_r := 0.093
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - 0.012
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.008, rim_r), Vector2(lip_x - 0.002, rim_r + 0.005),
			Vector2(lip_x + 0.003, rim_r + 0.003), Vector2(lip_x + 0.003, rim_r - 0.003), Vector2(face_x, rim_r * 0.82)]),
			40, CB.M_RIM, C_RIM, "out", Vector3(lip_x - 0.03, 0.0, 0.0))
	b.disc(Vector3(face_x, 0.0, 0.0), Vector3.RIGHT, rim_r * 0.82, 0.0, 32, CB.M_RIM, C_RIM)
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.008, rim_r), Vector2(-hw + 0.004, rim_r - 0.002),
			Vector2(-hw + 0.001, rim_r + 0.002)]), 40, CB.M_RIM, Color(0.6, 0.6, 0.62), "in")
	b.disc(Vector3(-hw + 0.004, 0.0, 0.0), Vector3.LEFT, rim_r, 0.0, 28, CB.M_DARK, C_DARKER)
	# The hubcap: a big chrome dome with a little dimple at its centre.
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	var cr := 0.068
	b.lathe(Vector3(face_x, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(-0.002, cr), Vector2(0.010, cr * 0.94),
			Vector2(0.020, cr * 0.74), Vector2(0.026, cr * 0.44), Vector2(0.028, cr * 0.18), Vector2(0.026, 0.0)]), 32,
			CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(face_x - cr, 0.0, 0.0))
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
	# The cabin under the bubble: dark inside the rim.
	if z > CABIN_Z.x - 0.012 and z < CABIN_Z.y + 0.012:
		var base: Vector2 = _bubble_base(z)
		if p.y < base.y - 0.010 and p.x < base.x - 0.004 and n.x < 0.6:
			black = 0.85
	if (n.z > 0.5 and absf(z - CABIN_Z.x) < 0.03) or (n.z < -0.5 and absf(z - CABIN_Z.y) < 0.03):
		if p.y < 0.46:
			black = 0.85
	var on_side: bool = n.x > 0.45 and p.x > w - 0.03
	if on_side:
		# The chrome spear along the side, tapering into points at both ends.
		var t: float = clampf((z + 0.80) / 1.58, 0.0, 1.0)
		var hw: float = 0.0075 * sin(PI * pow(t, 0.8))
		if z > -0.80 and z < 0.78:
			chrome = maxf(chrome, _cover(absf(p.y - (0.318 + 0.010 * t)) - hw, fp))
		# The door: an outline from under the rim down to the sill, rounded at its corners.
		var d: float = _sd_box(Vector2(z - (-0.090), p.y - 0.295), Vector2(0.230 - 0.04, 0.155 - 0.04)) - 0.04
		gap = maxf(gap, _cover(absf(d) - 0.0016, fp) * float(p.y < 0.468))
		# Louvres on the tail's flanks.
		if z > 0.560 and z < 0.700 and p.y > 0.250 and p.y < 0.345:
			var lz: float = fposmod(p.y - 0.250, 0.024) - 0.012
			var dd: float = maxf(absf(lz) - 0.0035, absf(z - 0.630) - 0.060 + 0.6 * (p.y - 0.25) * 0.0)
			black = maxf(black, 0.9 * _cover(dd, fp))
	# Bonnet seam over the nose and the engine cover's over the tail.
	if n.y > 0.4:
		if z < CABIN_Z.x - 0.04:
			gap = maxf(gap, _cover(absf(_sd_box(Vector2(p.x, z + 0.640), Vector2(0.200, 0.160)) - 0.06) - 0.0015, fp))
		elif z > CABIN_Z.y + 0.04:
			gap = maxf(gap, _cover(absf(_sd_box(Vector2(p.x, z - 0.520), Vector2(0.200, 0.150)) - 0.06) - 0.0015, fp))
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(0.0, gap, chrome, black)
