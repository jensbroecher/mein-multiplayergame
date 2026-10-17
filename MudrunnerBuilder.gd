# MudrunnerBuilder.gd
#
# The Mudrunner: a Baja Bug body on a monster-truck RC chassis, rebuilt in code from the Hunyuan
# model (models/cars/20260618232844_3429272f.fbx, ~590k triangles) at about 34k. The proportions
# were measured off that mesh: the wheels sit exactly where they did, so PlayerCart plants the car
# at the same height and its wheel pivots, drift and boost particles land in the same places.
#
# Cart frame: metres, X right, Y up, front at -Z, the ground at y = 0 (CarBuilder.gd).
#
# The body is a loft: one cross-section per station along Z (flat bottom, rounded corner,
# vertical side up to the beltline, then a cubic over the top), with every parameter of the
# section a smooth curve along the car (TOP, BOT, W, ...). Its UVs are (along the car, around the
# section), and the detail map in that space draws the windows, their seals, the panel gaps and
# the trim (build_detail_map), so they stay sharp without extra geometry. Fenders are separate
# sweeps along the wheel-arch lip, with their inner edge buried in the body.
extends RefCounted

const CB = preload("res://CarBuilder.gd")

# --------------------------------------------------------------------------------------------
#  Layout
# --------------------------------------------------------------------------------------------

# Wheels: the Hunyuan model's positions.
const WHEEL_X := 0.603
const AXLE_F := -0.654
const AXLE_R := 0.717
const HUB_Y := 0.252

# Body ends: the loft closes with an elliptical cap of this length round (0, CAP_Y).
const NOSE_TIP := -0.814
const NOSE_CAP := 0.05
const NOSE_CAP_Y := 0.475
const TAIL_TIP := 0.944
const TAIL_CAP := 0.035
const TAIL_CAP_Y := 0.405
const HALF_RING := 28            # section points from the bottom of the centre line to its top

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
# The cubic over the top: P0 = (w, belt), P1 = (w - tumble, belt + ka (top - belt)),
# P2 = (kb w, top), P3 = (0, top). Tumble pulls the glass inward; kb flattens the roof.
const TUMBLE_KNOTS := [[-0.82, 0.0], [-0.30, 0.010], [-0.22, 0.050], [-0.14, 0.075], [0.45, 0.075],
	[0.60, 0.050], [0.80, 0.020], [0.944, 0.0]]
const KA_KNOTS := [[-0.82, 0.50], [-0.30, 0.55], [-0.18, 0.80], [0.45, 0.85], [0.65, 0.65], [0.944, 0.50]]
const KB_KNOTS := [[-0.82, 0.55], [-0.30, 0.60], [-0.15, 0.55], [0.45, 0.55], [0.944, 0.50]]

# Fenders: the wheel-arch lip in side view (z, y), listed from the end at the doors round to the
# outer end. The fender is a shelf `depth` thick standing on the lip, out to x_out. Baja-cut: the
# front fenders stop short of the tyres' fronts, the rear ones above the axle line.
const FRONT_LIP := [[-0.318, 0.305], [-0.340, 0.385], [-0.378, 0.462], [-0.425, 0.522], [-0.480, 0.556],
	[-0.550, 0.570], [-0.608, 0.566], [-0.648, 0.550], [-0.671, 0.520], [-0.680, 0.482], [-0.682, 0.455]]
const REAR_LIP := [[0.392, 0.300], [0.418, 0.380], [0.452, 0.448], [0.500, 0.505], [0.560, 0.545],
	[0.630, 0.566], [0.700, 0.566], [0.760, 0.540], [0.805, 0.500], [0.835, 0.455]]
const FRONT_FENDER_OUT := 0.44
const REAR_FENDER_OUT := 0.45
const FRONT_FENDER_DEPTH := 0.052
const REAR_FENDER_DEPTH := 0.050

# Palette (sRGB; the shader linearises vertex colours).
const C_PAINT := Color(1, 1, 1)
const C_RUBBER := Color(0.25, 0.25, 0.25)
const C_DARK := Color(0.07, 0.07, 0.075)
const C_DARKER := Color(0.035, 0.035, 0.04)
const C_ALLOY := Color(0.78, 0.79, 0.80)
const C_ALLOY_DARK := Color(0.55, 0.56, 0.58)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.56)

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

var _top := CB.Profile.new(TOP_KNOTS)
var _bot := CB.Profile.new(BOT_KNOTS)
var _w := CB.Profile.new(W_KNOTS)
var _belt := CB.Profile.new(BELT_KNOTS)
var _tumble := CB.Profile.new(TUMBLE_KNOTS)
var _ka := CB.Profile.new(KA_KNOTS)
var _kb := CB.Profile.new(KB_KNOTS)


# ============================================================================================
#  Body shell
# ============================================================================================

## The right half of the body's cross-section at z, from the bottom of the centre line up the
## side and over to the top of the centre line: HALF_RING + 1 points (x, y), caps applied.
func section(z: float) -> PackedVector2Array:
	var bot: float = _bot.at(z)
	var top: float = _top.at(z)
	var w: float = _w.at(z)
	var belt: float = _belt.at(z)
	var rb: float = minf(0.035, (belt - bot) * 0.4)
	var dense := PackedVector2Array()
	for k in 6:
		dense.append(Vector2((w - rb) * k / 6.0, bot))
	for k in 9:
		var a: float = -PI * 0.5 + PI * 0.5 * k / 8.0
		dense.append(Vector2(w - rb + rb * cos(a), bot + rb + rb * sin(a)))
	for k in range(1, 10):
		dense.append(Vector2(w, lerpf(bot + rb, belt, k / 9.0)))
	var p0 := Vector2(w, belt)
	var p1 := Vector2(w - _tumble.at(z), belt + _ka.at(z) * (top - belt))
	var p2 := Vector2(_kb.at(z) * w, top)
	var p3 := Vector2(0.0, top)
	for k in range(1, 49):
		dense.append(p0.bezier_interpolate(p1, p2, p3, k / 48.0))
	var sec: PackedVector2Array = CB.resample(dense, HALF_RING + 1, 0.03)
	# Elliptical caps: the section shrinks toward (0, CAP_Y) over the last CAP of each end, faster
	# across the car than up it, so the nose stays broad in plan and rounds over in profile.
	var cap := Vector2.ONE
	var cy := 0.0
	if z < NOSE_TIP + NOSE_CAP:
		var t: float = clampf((NOSE_TIP + NOSE_CAP - z) / NOSE_CAP, 0.0, 1.0)
		cap = Vector2(pow(1.0 - pow(t, 4.0), 0.25), sqrt(1.0 - t * t))
		cy = NOSE_CAP_Y
	elif z > TAIL_TIP - TAIL_CAP:
		var t: float = clampf((z - TAIL_TIP + TAIL_CAP) / TAIL_CAP, 0.0, 1.0)
		cap = Vector2(pow(1.0 - pow(t, 3.0), 1.0 / 3.0), sqrt(1.0 - t * t))
		cy = TAIL_CAP_Y
	if cap != Vector2.ONE:
		for k in sec.size():
			sec[k] = Vector2(sec[k].x * cap.x, cy + (sec[k].y - cy) * cap.y)
	return sec


## Stations along the car: dense through the caps (where the section changes fastest), every
## 2.5cm between.
func stations() -> PackedFloat32Array:
	var zs := PackedFloat32Array()
	for k in 9:
		zs.append(NOSE_TIP + NOSE_CAP * (1.0 - cos(PI * 0.5 * k / 9.0)))
	var z0: float = NOSE_TIP + NOSE_CAP
	var z1: float = TAIL_TIP - TAIL_CAP
	var n: int = ceili((z1 - z0) / 0.025)
	for k in n + 1:
		zs.append(lerpf(z0, z1, float(k) / n))
	for k in range(8, -1, -1):
		zs.append(TAIL_TIP - TAIL_CAP * (1.0 - cos(PI * 0.5 * k / 9.0)))
	zs[zs.size() - 1] = TAIL_TIP
	zs[0] = NOSE_TIP
	return zs


func body_u(z: float) -> float:
	return (z - NOSE_TIP) / (TAIL_TIP - NOSE_TIP)


func build_shell(b) -> void:
	var rows := []
	var uvs := []
	for z in stations():
		var sec: PackedVector2Array = section(z)
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		var u: float = body_u(z)
		# Right half bottom to top, then the left half back down (mirror), as one closed ring.
		for j in HALF_RING + 1:
			row.append(Vector3(sec[j].x, sec[j].y, z))
			uv.append(Vector2(u, float(j) / HALF_RING))
		for j in range(HALF_RING - 1, 0, -1):
			row.append(Vector3(-sec[j].x, sec[j].y, z))
			uv.append(Vector2(u, float(j) / HALF_RING))
		rows.append(row)
		uvs.append(uv)
	# Rows run nose to tail (+z) and each ring goes up the right side first, so d/dj x d/di
	# already points outward.
	b.grid(rows, CB.M_BODY, C_PAINT, false, true, uvs)


## Where the body's surface is at (x, y), searching from the nose (or from the tail): its z.
func shell_z(x: float, y: float, from_front: bool) -> float:
	var z: float = NOSE_TIP if from_front else TAIL_TIP
	var dz: float = 0.002 if from_front else -0.002
	for k in 400:
		var sec: PackedVector2Array = section(z)
		if _inside_half(sec, absf(x), y):
			return z
		z += dz
	return z


## Is (x, y) inside the half-section (x >= 0)? Its outline rises monotonically from the bottom
## corner to the top of the centre line, so the edge at height y is one crossing.
static func _inside_half(sec: PackedVector2Array, x: float, y: float) -> bool:
	if y < sec[0].y or y > sec[sec.size() - 1].y:
		return false
	for k in range(1, sec.size()):
		var a: Vector2 = sec[k - 1]
		var c: Vector2 = sec[k]
		if absf(c.y - a.y) < 1e-9:
			continue
		if y >= minf(a.y, c.y) and y <= maxf(a.y, c.y):
			return x <= lerpf(a.x, c.x, (y - a.y) / (c.y - a.y))
	return false


# ============================================================================================
#  Fenders
# ============================================================================================

## Height of a wheel-arch lip at z (for the detail map's wheel wells), or -1 outside it.
func _lip_y(lip: Array, z: float) -> float:
	var best := -1.0
	for k in range(1, lip.size()):
		var a: Array = lip[k - 1]
		var c: Array = lip[k]
		var lo: float = minf(a[0], c[0])
		var hi: float = maxf(a[0], c[0])
		if z >= lo and z <= hi and hi - lo > 1e-6:
			var t: float = (z - a[0]) / (c[0] - a[0])
			best = maxf(best, lerpf(a[1], c[1], t))
	return best


## A smooth spine through the lip points (Catmull-Rom), `n` samples, as (z, y).
static func _spine(lip: Array, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in lip:
		pts.append(Vector2(k[0], k[1]))
	var out := PackedVector2Array()
	var segs: int = pts.size() - 1
	for s in n:
		var f: float = float(s) / (n - 1) * segs
		var i: int = mini(int(f), segs - 1)
		var t: float = f - i
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		if i == 0:
			p0 = p1 * 2.0 - p2
		if i + 2 > pts.size() - 1:
			p3 = p2 * 2.0 - p1
		var t2: float = t * t
		var t3: float = t2 * t
		out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


## One fender (right side; the caller mirrors it). The section in (x, height above the lip):
## a lip, a slightly bulged outer face, a rounded shoulder and a flat top running inward into the
## body; under it a dark liner. The outer end rounds off (an elliptical taper over `taper_len`
## of the spine; 0 leaves it blunt, capped like the door end, where it meets the body's lower edge).
## Returns where a taillamp would sit on it: [point, normal, along the spine].
func build_fender(b, lip: Array, hub_z: float, x_out: float, depth: float, taper_len: float) -> Array:
	var spine: PackedVector2Array = _spine(lip, 40)
	var n: int = spine.size()
	# Arc length along the spine, for the taper.
	var acc := PackedFloat32Array([0.0])
	for k in range(1, n):
		acc.append(acc[k - 1] + spine[k].distance_to(spine[k - 1]))
	var total: float = acc[n - 1]
	var outer_rows := []
	var liner_rows := []
	var ends := []
	var lamp_mark := []
	for k in n:
		var t2: Vector2 = (spine[mini(k + 1, n - 1)] - spine[maxi(k - 1, 0)]).normalized()
		# The section stands on the side of the lip away from the wheel's hub.
		var n2 := Vector2(t2.y, -t2.x)
		if n2.dot(spine[k] - Vector2(hub_z, HUB_Y)) < 0.0:
			n2 = -n2
		var z: float = spine[k].x
		var x_in: float = _w.at(z) - 0.035
		var d: float = depth
		var xo: float = x_out
		# Taper the outer end: shrink the section toward its middle.
		var into_end: float = total - acc[k]
		var sc := 1.0
		if taper_len > 0.0 and into_end < taper_len:
			var t: float = 1.0 - into_end / taper_len
			sc = sqrt(maxf(1.0 - t * t, 0.0))
		var prof := [
			Vector2(xo - 0.010, 0.0), Vector2(xo - 0.001, 0.08 * d), Vector2(xo + 0.004, 0.32 * d),
			Vector2(xo + 0.003, 0.55 * d), Vector2(xo - 0.006, 0.78 * d), Vector2(xo - 0.024, 0.95 * d),
			Vector2(xo - 0.055, d), Vector2(x_in + 0.03, d), Vector2(x_in, d - 0.002)]
		var liner := [Vector2(xo - 0.010, 0.0), Vector2(xo - 0.026, 0.35 * d), Vector2(x_in, 0.6 * d)]
		var mid := Vector2(lerpf(x_in, xo, 0.55), d * 0.5)
		var orow := PackedVector3Array()
		for p in prof:
			var q: Vector2 = _taper(p, mid, sc)
			orow.append(Vector3(q.x, spine[k].y + q.y * n2.y, spine[k].x + q.y * n2.x))
		outer_rows.append(orow)
		var lrow := PackedVector3Array()
		for p in liner:
			var q: Vector2 = _taper(p, mid, sc)
			lrow.append(Vector3(q.x, spine[k].y + q.y * n2.y, spine[k].x + q.y * n2.x))
		liner_rows.append(lrow)
		if k == 0:
			ends.append([orow, lrow, Vector3(0.0, -t2.y, -t2.x)])
		elif k == n - 1 and taper_len <= 0.0:
			ends.append([orow, lrow, Vector3(0.0, t2.y, t2.x)])
		if k == int(n * 0.80):
			# The taillamp spot: on the top near the outer end, toward the outer edge.
			var tx: float = lerpf(x_in, xo, 0.72)
			lamp_mark = [Vector3(tx, spine[k].y + d * n2.y, spine[k].x + d * n2.x), Vector3(0.0, n2.y, n2.x),
				Vector3(0.0, t2.y, t2.x)]
	var base: int = b.vertex_count()
	var ibase: int = b.index_count()
	b.grid(outer_rows, CB.M_PAINT, C_PAINT, false, false)
	# The skin faces outward: check the outer face at the door end against +x.
	if b._n[base + 2].dot(Vector3.RIGHT) < 0.0:
		b.flip(base, ibase)
	base = b.vertex_count()
	ibase = b.index_count()
	b.grid(liner_rows, CB.M_DARK, C_DARKER, false, false)
	b.orient_toward(base, ibase, Vector3.DOWN)
	# Square caps where the fender isn't tapered: the section outline closed through the body.
	for e in ends:
		var cap := PackedVector3Array()
		for p in e[0]:
			cap.append(p)
		var lr: PackedVector3Array = e[1]
		for k in range(lr.size() - 1, 0, -1):
			cap.append(lr[k])
		b.poly(cap, e[2], CB.M_PAINT, C_PAINT)
	return lamp_mark


## A fender section point shrunk toward the section's middle by `sc` (1 = untouched): faster in
## height than across, so the outer end rounds off in plan as well as in profile.
static func _taper(p: Vector2, mid: Vector2, sc: float) -> Vector2:
	if sc >= 1.0:
		return p
	return Vector2(mid.x + (p.x - mid.x) * sqrt(sc), mid.y + (p.y - mid.y) * sc)


# ============================================================================================
#  Lamps, mirrors, bumpers, chassis
# ============================================================================================

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
			CB.M_TAILLAMP, Color(1, 1, 1))


func build_details(b) -> void:
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	# --- Right-hand parts, mirrored to the left afterwards ---
	# Headlamp on the nose: chrome bezel sunk into the panel, domed lens.
	var hx := 0.138
	var hy := 0.540
	var hz: float = shell_z(hx, hy, true)
	var fwd: Vector3 = Vector3(0.12, 0.22, -1.0).normalized()
	var lamp_c := Vector3(hx, hy, hz)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(lamp_c, fwd, PackedVector2Array([Vector2(-0.03, 0.060), Vector2(0.010, 0.060),
			Vector2(0.016, 0.057), Vector2(0.017, 0.052)]), 24, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, lamp_c - fwd * 0.05)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(lamp_c + fwd * 0.012, fwd, PackedVector2Array([Vector2(0.0, 0.0525), Vector2(0.006, 0.047),
			Vector2(0.011, 0.033), Vector2(0.014, 0.0)]), 24, CB.M_HEADLAMP, Color(1, 1, 1))
	b.orient_away_from(vb, ib, lamp_c - fwd * 0.03)
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
	# Lower wishbone: two arms from the chassis to the bottom of the knuckle.
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
	var lo := Vector3(0.36, 0.188, axle_z + 0.035 * fz)
	var hi := Vector3(0.300, 0.505, axle_z + 0.010 * fz)
	var ax: Vector3 = (hi - lo).normalized()
	var body_lo: Vector3 = lo.lerp(hi, 0.42)
	b.tube(PackedVector3Array([lo, body_lo]), 0.0075, 6, CB.M_CHROME, C_CHROME, true, false)
	b.tube(PackedVector3Array([body_lo, hi]), 0.0175, 10, CB.M_ALLOY, C_ALLOY, true, true)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(lo.lerp(hi, 0.16), ax, PackedVector2Array([Vector2(-0.004, 0.0), Vector2(-0.004, 0.034),
			Vector2(0.004, 0.034), Vector2(0.004, 0.0)]), 12, CB.M_ALLOY, C_ALLOY_DARK)
	b.orient_away_from(vb, ib, lo.lerp(hi, 0.16))
	b.spring(lo.lerp(hi, 0.18), lo.lerp(hi, 0.94), 0.028, 0.0058, 6.5, CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), hi + Vector3(-0.01, 0.012, 0.0)), Vector3(0.03, 0.01, 0.03), 0.006, 1, CB.M_DARK, C_DARK)


# ============================================================================================
#  Wheels
# ============================================================================================

## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1):
## a studded tyre round a turbine-spoked rim.
func build_wheel(b, side: float) -> void:
	var ax := Vector3.RIGHT
	# Tyre carcass: bead to bead over the tread.
	var tyre := PackedVector2Array()
	var half := [[-0.098, 0.166], [-0.112, 0.178], [-0.1195, 0.194], [-0.121, 0.211], [-0.117, 0.227],
		[-0.106, 0.238], [-0.086, 0.2445], [-0.050, 0.2465], [-0.016, 0.247]]
	for p in half:
		tyre.append(Vector2(p[0], p[1]))
	for k in range(half.size() - 1, -1, -1):
		tyre.append(Vector2(-half[k][0], half[k][1]))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3.ZERO, ax, tyre, 40, CB.M_RUBBER, C_RUBBER)
	b.orient_away_from(vb, ib, Vector3.ZERO)
	# Tread: two staggered rows of paddle lugs, and studs along both shoulders.
	var lugs := 20
	for k in lugs:
		for row in 2:
			var a: float = TAU * (k + 0.5 * row) / lugs
			var xr: float = -0.052 if row == 0 else 0.052
			var tilt: float = 0.30 if row == 0 else -0.30
			_lug(b, a, xr, tilt)
		for row in 2:
			var a: float = TAU * (k + 0.25 + 0.5 * row) / lugs
			var sx: float = -1.0 if row == 0 else 1.0
			_stud(b, a, sx)
	# Rim: outer lip, dished face down to the spokes, barrel inside the tyre.
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3.ZERO, ax, PackedVector2Array([Vector2(0.086, 0.168), Vector2(0.099, 0.171),
			Vector2(0.107, 0.166), Vector2(0.106, 0.156), Vector2(0.097, 0.151)]), 40, CB.M_RIM, C_RIM)
	b.orient_away_from(vb, ib, Vector3(0.05, 0.0, 0.0))
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3.ZERO, ax, PackedVector2Array([Vector2(0.097, 0.151), Vector2(0.084, 0.146),
			Vector2(0.070, 0.136)]), 40, CB.M_RIM, C_RIM_BARREL)
	b.orient_toward(vb, ib, Vector3.RIGHT)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3.ZERO, ax, PackedVector2Array([Vector2(0.070, 0.136), Vector2(0.060, 0.150),
			Vector2(-0.090, 0.160), Vector2(-0.098, 0.168)]), 40, CB.M_RIM, C_RIM_BARREL)
	# The barrel is seen from inside: its normals point at the axle.
	var radial := 0.0
	for k in range(vb, b.vertex_count()):
		radial += b._n[k].dot(Vector3(0.0, b._v[k].y, b._v[k].z))
	if radial > 0.0:
		b.flip(vb, ib)
	# Back wall behind the spokes, so the wheel reads solid.
	b.disc(Vector3(0.045, 0.0, 0.0), ax, 0.152, 0.03, 32, CB.M_DARK, C_DARKER)
	# Hub and cap.
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3.ZERO, ax, PackedVector2Array([Vector2(0.040, 0.046), Vector2(0.078, 0.046),
			Vector2(0.083, 0.041)]), 20, CB.M_RIM, C_RIM)
	b.orient_away_from(vb, ib, Vector3(0.06, 0.0, 0.0))
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(0.083, 0.0, 0.0), ax, PackedVector2Array([Vector2(0.0, 0.041), Vector2(0.004, 0.036),
			Vector2(0.009, 0.024), Vector2(0.012, 0.0)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.06, 0.0, 0.0))
	# Eight turbine spokes, twisted a little toward the rim.
	for k in 8:
		_spoke(b, TAU * k / 8.0)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


func _wheel_frame(a: float) -> Array:
	# Radial direction at angle a round the X axis, and the tangent (rolling direction).
	var radial := Vector3(0.0, cos(a), sin(a))
	var tangent := Vector3(0.0, -sin(a), cos(a))
	return [radial, tangent]


## A paddle lug on the tread: a wedge across the tyre, tilted into a chevron.
func _lug(b, a: float, x: float, tilt: float) -> void:
	var f: Array = _wheel_frame(a)
	var r: Vector3 = f[0]
	var t: Vector3 = f[1]
	var across: Vector3 = (Vector3.RIGHT + t * tilt).normalized()
	var c: Vector3 = r * 0.2455 + Vector3(x, 0.0, 0.0)
	_block(b, c, across, t, r, 0.026, 0.010, 0.016, 0.85)


## A stud on a shoulder, pointing out and away from the tread.
func _stud(b, a: float, sx: float) -> void:
	var f: Array = _wheel_frame(a)
	var r: Vector3 = f[0]
	var t: Vector3 = f[1]
	var base: Vector3 = r * 0.236 + Vector3(0.107 * sx, 0.0, 0.0)
	var dir: Vector3 = (r * 0.8 + Vector3(0.6 * sx, 0.0, 0.0)).normalized()
	var side: Vector3 = dir.cross(t).normalized()
	var tip: Vector3 = base + dir * 0.018
	var s := 0.0085
	var corners := [base + t * s + side * s, base + t * s - side * s, base - t * s - side * s, base - t * s + side * s]
	for k in 4:
		var p0: Vector3 = corners[k]
		var p1: Vector3 = corners[(k + 1) % 4]
		var n: Vector3 = (p1 - p0).cross(tip - p0).normalized()
		if n.dot((p0 + p1) * 0.5 - base) < 0.0:
			n = -n
		var i0: int = b.vertex(p0, n, CB.M_RUBBER, C_RUBBER)
		var i1: int = b.vertex(p1, n, CB.M_RUBBER, C_RUBBER)
		var i2: int = b.vertex(tip, n, CB.M_RUBBER, C_RUBBER)
		b.tri(i0, i1, i2)


## A flat-shaded block with no bottom face: centre c, axes a1 (half-size h1), a2 (h2) and up
## (height, from c - up*h_up*0.4 to c + up*h_up*0.6), top shrunk by `top_scale`.
func _block(b, c: Vector3, a1: Vector3, a2: Vector3, up: Vector3, h1: float, h_up: float, h2: float, top_scale: float) -> void:
	var lo: Vector3 = c - up * h_up * 0.4
	var hi: Vector3 = c + up * h_up * 0.6
	var bl := [lo + a1 * h1 + a2 * h2, lo - a1 * h1 + a2 * h2, lo - a1 * h1 - a2 * h2, lo + a1 * h1 - a2 * h2]
	var tl := [hi + (a1 * h1 + a2 * h2) * top_scale, hi + (-a1 * h1 + a2 * h2) * top_scale,
		hi + (-a1 * h1 - a2 * h2) * top_scale, hi + (a1 * h1 - a2 * h2) * top_scale]
	b.poly(PackedVector3Array(tl), up, CB.M_RUBBER, C_RUBBER)
	for k in 4:
		var p0: Vector3 = bl[k]
		var p1: Vector3 = bl[(k + 1) % 4]
		var p2: Vector3 = tl[(k + 1) % 4]
		var p3: Vector3 = tl[k]
		var n: Vector3 = ((p0 + p1 + p2 + p3) * 0.25 - c).normalized()
		var ids := []
		for p in [p0, p1, p2, p3]:
			ids.append(b.vertex(p, n, CB.M_RUBBER, C_RUBBER))
		b.quad(ids[0], ids[1], ids[2], ids[3])


## A spoke from the hub to the rim, at angle a, its outer end twisted.
func _spoke(b, a: float) -> void:
	var f0: Array = _wheel_frame(a)
	var f1: Array = _wheel_frame(a + 0.16)
	var r0: Vector3 = f0[0]
	var t0: Vector3 = f0[1]
	var r1: Vector3 = f1[0]
	var t1: Vector3 = f1[1]
	var x0 := 0.074
	var x1 := 0.066
	var w0 := 0.014
	var w1 := 0.026
	var th := 0.011
	var inner := [r0 * 0.044 + t0 * w0, r0 * 0.044 - t0 * w0]
	var outer := [r1 * 0.146 + t1 * w1, r1 * 0.146 - t1 * w1]
	var pts := {
		"if": [inner[0] + Vector3(x0, 0, 0), inner[1] + Vector3(x0, 0, 0)],
		"ib": [inner[0] + Vector3(x0 - th, 0, 0), inner[1] + Vector3(x0 - th, 0, 0)],
		"of": [outer[0] + Vector3(x1, 0, 0), outer[1] + Vector3(x1, 0, 0)],
		"ob": [outer[0] + Vector3(x1 - th, 0, 0), outer[1] + Vector3(x1 - th, 0, 0)],
	}
	# Front face, two sides, back face (flat-shaded quads).
	_face(b, [pts["if"][0], pts["if"][1], pts["of"][1], pts["of"][0]], Vector3.RIGHT)
	_face(b, [pts["if"][0], pts["of"][0], pts["ob"][0], pts["ib"][0]], (t0 + t1).normalized())
	_face(b, [pts["if"][1], pts["of"][1], pts["ob"][1], pts["ib"][1]], -(t0 + t1).normalized())
	_face(b, [pts["ib"][0], pts["ib"][1], pts["ob"][1], pts["ob"][0]], -Vector3.RIGHT)


func _face(b, q: Array, hint: Vector3) -> void:
	var n: Vector3 = (q[2] - q[0]).cross(q[1] - q[0]).normalized()
	if n.dot(hint) < 0.0:
		n = -n
	var ids := []
	for p in q:
		ids.append(b.vertex(p, n, CB.M_RIM, C_RIM))
	b.quad(ids[0], ids[1], ids[2], ids[3])


# ============================================================================================
#  Detail map
# ============================================================================================

## The body's detail map over its (u along the car, v round the half-section) UVs:
## R glass, G panel gaps, B chrome trim, A black (window seals, wheel wells, underside).
func build_detail_map(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	# Positions on the shell per texel, and normals from them.
	var pos := []
	for i in width:
		var u: float = (i + 0.5) / width
		var z: float = lerpf(NOSE_TIP, TAIL_TIP, u)
		var sec: PackedVector2Array = section(z)
		var col := PackedVector3Array()
		for j in height:
			var t: float = (j + 0.5) / height * HALF_RING
			var k: int = mini(int(t), HALF_RING - 1)
			var p2: Vector2 = sec[k].lerp(sec[k + 1], t - k)
			col.append(Vector3(p2.x, p2.y, z))
		pos.append(col)
	var windows: Dictionary = _window_shapes()
	for i in width:
		var col: PackedVector3Array = pos[i]
		var colp: PackedVector3Array = pos[maxi(i - 1, 0)]
		var coln: PackedVector3Array = pos[mini(i + 1, width - 1)]
		for j in height:
			var p: Vector3 = col[j]
			var du: Vector3 = coln[j] - colp[j]
			var dv: Vector3 = col[mini(j + 1, height - 1)] - col[maxi(j - 1, 0)]
			var n: Vector3 = dv.cross(du)
			# Outward: the right half's section runs counter-clockwise from the bottom.
			var sec_out := Vector2(dv.y, -dv.x)
			if Vector2(n.x, n.y).dot(sec_out) < 0.0 and sec_out.length_squared() > 1e-12:
				n = -n
			n = n.normalized()
			# Texel footprint in metres, for anti-aliasing.
			var fp: float = maxf(du.length() * 0.5, dv.length() * 0.5)
			fp = maxf(fp, 0.0008)
			var c: Color = _detail_at(p, n, fp, windows)
			img.set_pixel(i, j, c)
	img.generate_mipmaps()
	return img


func _window_shapes() -> Dictionary:
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
		if p.z > -0.095 and p.z < -0.055:
			var dd: float = absf(p.z + 0.076) - 0.0045
			if p.y < 0.84:
				chrome = maxf(chrome, _cover(dd, fp))
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
		if p.z > -0.30 and p.z < 0.26:
			var d: float = _sd_poly(szy, sh["door"])
			if p.y > 0.315:
				gap = maxf(gap, _cover(absf(d) - 0.0022, fp))
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


static func _cover(d: float, fp: float) -> float:
	return clampf(0.5 - d / fp, 0.0, 1.0)


static func _sd_box(p: Vector2, h: Vector2) -> float:
	var d := Vector2(absf(p.x), absf(p.y)) - h
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)


## Signed distance to a polygon (negative inside), after Inigo Quilez.
static func _sd_poly(p: Vector2, v: PackedVector2Array) -> float:
	var d: float = (p - v[0]).length_squared()
	var s := 1.0
	var n: int = v.size()
	var j: int = n - 1
	for i in n:
		var e: Vector2 = v[j] - v[i]
		var w: Vector2 = p - v[i]
		var bq: Vector2 = w - e * clampf(w.dot(e) / e.dot(e), 0.0, 1.0)
		d = minf(d, bq.length_squared())
		var c1: bool = p.y >= v[i].y
		var c2: bool = p.y < v[j].y
		var c3: bool = e.x * w.y > e.y * w.x
		if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
			s = -s
		j = i
	return s * sqrt(d)


## A rounded polygon: `shape` is [inset polygon, radius] from _inset().
static func _sd_rounded(p: Vector2, shape: Array) -> float:
	return _sd_poly(p, shape[0]) - shape[1]


## Insets a convex polygon by r (for rounded corners: the SDF of the inset minus r).
static func _inset(v: PackedVector2Array, r: float) -> Array:
	var n: int = v.size()
	var area := 0.0
	for k in n:
		area += v[k].cross(v[(k + 1) % n])
	var sgn: float = 1.0 if area > 0.0 else -1.0
	var lines := []
	for k in n:
		var a: Vector2 = v[k]
		var c: Vector2 = v[(k + 1) % n]
		var e: Vector2 = (c - a).normalized()
		var inward := Vector2(-e.y, e.x) * sgn
		lines.append([a + inward * r, e])
	var out := PackedVector2Array()
	for k in n:
		var l0: Array = lines[(k - 1 + n) % n]
		var l1: Array = lines[k]
		var p0: Vector2 = l0[0]
		var d0: Vector2 = l0[1]
		var p1: Vector2 = l1[0]
		var d1: Vector2 = l1[1]
		var den: float = d0.cross(d1)
		if absf(den) < 1e-9:
			out.append(p1)
		else:
			var t: float = (p1 - p0).cross(d1) / den
			out.append(p0 + d0 * t)
	return [out, r]


# ============================================================================================
#  Build
# ============================================================================================

## Body mesh: shell, fenders (both sides), lamps, mirrors, bumpers, chassis and suspension.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	build_fender(b, FRONT_LIP, AXLE_F, FRONT_FENDER_OUT, FRONT_FENDER_DEPTH, 0.0)
	_taillamp(b, build_fender(b, REAR_LIP, AXLE_R, REAR_FENDER_OUT, REAR_FENDER_DEPTH, 0.06))
	b.mirror_x(v0, i0)
	build_details(b)
