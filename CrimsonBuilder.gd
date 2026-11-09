# CrimsonBuilder.gd
#
# The Crimson: a two-seat speedster built like a racing car for the road (an original design with a made-up
# name, after a mid-1990s concept car the user liked: its shape, no maker's badge or name). Open front wheels
# on exposed wishbones under black cycle fenders; a black front wing across the nose ahead of them, an LED
# line along its leading edge, amber markers at its upturned tips; a pointed nose under a black shield-shaped
# hood that widens up to a wraparound windscreen with a black hoop for its top; a short open cockpit with two
# black buckets and two black headrest humps behind them; LED headlamps in pods on stalks at the screen's
# corners. From the cockpit back the body is a wedge: a crease along the side (the lower side tucked under),
# the upper side leaning in, and the deck's outer edges rising into two broad blades over the rear wheels that
# run on past the tail as pointed fins with a wing between them, over a black louvred engine cover; under them
# a black fascia with louvres and two pairs of oval tailpipes. The rear wheels sit tight beside the body under
# deep black fenders. Cross-spoke mesh wheels with a polished lip, wide tyres at the back.
#
# What sets it apart from the fleet: the only car with open front wheels and a front wing (the Meteor's are
# open too, but it is a 1930s single-seater with a bonnet and a boat tail), and the only one whose tail splits
# into fins. The Nocturne and the Fulmine are closed-wheel coupés with canopies.
#
# The shell's section (section(), _segments()): a flat bottom, a rounded sill, the lower side leaning out to
# the crease (the widest line, w), the upper side leaning in (lean) to the belt, then (keyed along the car in
# KEYS, as on the Meteor) a shoulder, a rim, a wall, a corner and a crowned top: over the nose the shoulder is
# the hood's dome; over the cockpit the wall runs down inside to the floor; behind it the rim is the blade's
# broad top and the wall drops to the engine cover between the blades. The tail is a flat black face (no cap):
# the blades carry on past it as fins (_fin) whose first ring is the shell's last.
extends "res://CarDesign.gd"

const WHEEL_X_F := 0.500
const WHEEL_X_R := 0.502
const AXLE_F := -0.580
const AXLE_R := 0.720
const HUB_Y := 0.195

const NOSE_TIP := -1.020
const TAIL_TIP := 0.960
const FIN_TIP := 1.110
const FIN_TOP := 0.575
const FIN_X_TIP := 0.400
## The section's ring points the fins are lofted from: the upper side's top two thirds up to the deck's corner.
## Toward its tip a fin sweeps out to FIN_X_TIP, over the rear tyre's inner half.
const FIN_FROM := 10
const FIN_TO := 30
const COCKPIT_Z := Vector2(-0.235, 0.290)
const SEAT_X := 0.128
const ENGINE_COVER_Z := Vector2(0.575, 0.945)

# The section above the belt, keyframed along the car: z; belt (the upper side's top); lean (how far the upper
# side leans in from the crease to the belt); sx, sy (the shoulder's quarter ellipse); rim_w (a flat rim inward
# from the shoulder: the cockpit's edge, the blades' top); wall_dx (how far the wall leans in); edge (the top's
# height at its corner: the hood, the cockpit floor, the engine cover); cx, cy (the corner onto the top: cy < 0
# a fillet below the wall); crown (the top's rise to the centre line).
const KEYS := [
	# z       belt   lean   sx     sy     rim_w  wall   edge   cx     cy      crown
	[-1.020, 0.178, 0.010, 0.040, 0.022, 0.002, 0.002, 0.203, 0.004, 0.000, 0.006],
	[-0.900, 0.207, 0.016, 0.060, 0.028, 0.002, 0.002, 0.238, 0.004, 0.000, 0.008],
	[-0.700, 0.250, 0.022, 0.085, 0.037, 0.002, 0.002, 0.290, 0.004, 0.000, 0.010],
	[-0.500, 0.292, 0.028, 0.115, 0.046, 0.002, 0.002, 0.341, 0.004, 0.000, 0.012],
	[-0.330, 0.330, 0.034, 0.150, 0.060, 0.002, 0.002, 0.393, 0.004, 0.000, 0.014],
	[-0.245, 0.345, 0.036, 0.165, 0.066, 0.002, 0.002, 0.414, 0.004, 0.000, 0.016],
	[-0.235, 0.350, 0.036, 0.040, 0.064, 0.012, 0.020, 0.120, 0.020, -0.015, 0.000],
	[0.000, 0.385, 0.040, 0.040, 0.052, 0.012, 0.020, 0.120, 0.020, -0.015, 0.000],
	[0.280, 0.405, 0.044, 0.036, 0.044, 0.012, 0.020, 0.120, 0.020, -0.015, 0.000],
	[0.290, 0.408, 0.044, 0.032, 0.040, 0.050, 0.010, 0.432, 0.015, -0.008, 0.010],
	[0.600, 0.462, 0.050, 0.028, 0.036, 0.090, 0.020, 0.440, 0.018, -0.012, 0.008],
	[0.940, 0.515, 0.056, 0.025, 0.034, 0.125, 0.030, 0.418, 0.020, -0.014, 0.006],
	[0.960, 0.518, 0.056, 0.025, 0.034, 0.126, 0.030, 0.416, 0.020, -0.014, 0.006],
]
const KEY_NAMES := ["belt", "lean", "sx", "sy", "rim_w", "wall_dx", "edge", "cx", "cy", "crown"]
# The lower body: the crease's half width (the widest line) and height, the sill tucked in under it, the bottom.
const W_KNOTS := [[-1.02, 0.075], [-0.95, 0.115], [-0.85, 0.155], [-0.70, 0.195], [-0.58, 0.215], [-0.46, 0.245],
	[-0.38, 0.300], [-0.30, 0.350], [-0.20, 0.380], [0.00, 0.390], [0.40, 0.388], [0.60, 0.378], [0.80, 0.362],
	[0.96, 0.345]]
const CREASE_KNOTS := [[-1.02, 0.145], [-0.75, 0.165], [-0.40, 0.190], [0.0, 0.205], [0.50, 0.225], [0.96, 0.250]]
const TUCK_KNOTS := [[-1.02, 0.018], [-0.70, 0.032], [-0.30, 0.055], [0.60, 0.055], [0.96, 0.042]]
const BOT_KNOTS := [[-1.02, 0.105], [-0.92, 0.088], [-0.75, 0.075], [-0.45, 0.058], [0.75, 0.058], [0.90, 0.068],
	[0.96, 0.075]]

# The wraparound windscreen: its foot across the hood at SCREEN_FRONT_Z, round corners onto the cockpit's rim at
# SCREEN_SIDE_X, back along it to SCREEN_END_Z; its top edge SCREEN_TOP_Y up in front, its top edge coming down to the rim at
# the ends; the front raked back SCREEN_RAKE over its height, the sides leaning in SCREEN_LEAN.
const SCREEN_FRONT_Z := -0.268
const SCREEN_SIDE_X := 0.306
const SCREEN_END_Z := 0.110
const SCREEN_CORNER_R := 0.055
const SCREEN_TOP_Y := 0.598
const SCREEN_RAKE := 0.135
const SCREEN_LEAN := 0.035

# The front wing: its chord's middle at WING_Z, WING_Y up; flat to WING_FLAT, then curling up to its tips.
const WING_Y := 0.188
const WING_Z := -1.030
const WING_FLAT := 0.330
const WING_HALF := 0.405
const WING_PROFILE := [[-0.066, 0.000], [-0.060, 0.007], [-0.040, 0.012], [0.000, 0.013], [0.040, 0.009],
	[0.066, 0.002], [0.066, -0.002], [0.030, -0.004], [-0.030, -0.004], [-0.060, -0.003]]
# The rear wing between the fins.
const REAR_WING_Z := 1.015
const REAR_WING_Y := 0.545
const REAR_WING_HALF := 0.250
const REAR_WING_PROFILE := [[-0.030, 0.000], [-0.026, 0.006], [-0.010, 0.010], [0.012, 0.012], [0.030, 0.016],
	[0.030, 0.012], [0.010, 0.004], [-0.016, -0.002], [-0.029, -0.002]]

# Low-profile tyres (half their profile, bead to tread centre), the rear ones broader, on cross-spoke rims.
const TYRE_FRONT := [[-0.072, 0.132], [-0.078, 0.138], [-0.080, 0.150], [-0.080, 0.170], [-0.077, 0.184],
	[-0.068, 0.192], [-0.045, 0.1945], [0.0, 0.195]]
const TYRE_REAR := [[-0.104, 0.134], [-0.110, 0.140], [-0.112, 0.152], [-0.112, 0.171], [-0.109, 0.185],
	[-0.099, 0.192], [-0.070, 0.1945], [0.0, 0.195]]
const RIM_R_F := 0.132
const RIM_R_R := 0.134
const MESH_SPOKES := 12
const MESH_TWIST := 0.40

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.16, 0.16, 0.17)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_FENDER := Color(0.045, 0.045, 0.05)
const C_ARM := Color(0.11, 0.11, 0.12)
const C_SEAT := Color(0.075, 0.075, 0.08)
const C_LOUVRE := Color(0.13, 0.13, 0.14)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.55, 0.55, 0.57)
const C_LED := Color(0.42, 0.74, 1.0)
const C_AMBER := Color(1.0, 0.56, 0.08)
const C_TAILLAMP := Color(0.92, 0.05, 0.03)
const GLASS_TINT := Color(0.50, 0.58, 0.64, 0.30)

const PAINT_LAYOUT := {
	"nose_z": -1.02, "tail_z": 0.96, "belt_y": 0.235, "side_x": 0.38,
	"door_z": 0.03, "door_y": 0.25, "roundel_r": 0.060,
	"hood_z": -0.620, "hood_r": 0.050, "stripe_w": 0.035, "stripe_gap": 0.012,
}
const ANTENNA_POS := Vector3(0.250, 0.512, 0.740)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X_F, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X_F, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X_R, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X_R, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = NOSE_TIP
	nose_cap = 0.070
	nose_cap_y = 0.150
	nose_cap_exp = Vector2(2.4, 2.2)
	tail_tip = TAIL_TIP
	# The tail is a flat face of its own (build_shell); this only spaces the last stations.
	tail_cap = 0.010
	tail_cap_y = 0.30
	tail_cap_exp = Vector2(2.0, 2.0)
	# Bottom, sill, lower side, upper side; shoulder, rim, wall, corner, top.
	segment_counts = [2, 3, 3, 3, 8, 2, 5, 4, 6]
	half_ring = 36
	bottom_radius = 0.030
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["crease"] = CREASE_KNOTS
	knots["tuck"] = TUCK_KNOTS
	knots["bot"] = BOT_KNOTS
	knots["top"] = []
	for key in KEYS:
		(knots["top"] as Array).append([key[0], key[7] + key[10]])
	setup_shell(knots)


# ============================================================================================
#  Section
# ============================================================================================

func section(z: float) -> PackedVector2Array:
	var segs: Array = _segments(z)
	var sec := PackedVector2Array()
	sec.append((segs[0] as PackedVector2Array)[0])
	for k in segs.size():
		var rs: PackedVector2Array = CB.resample(segs[k], int(segment_counts[k]) + 1, 0.0)
		for m in range(1, rs.size()):
			sec.append(rs[m])
	var c: Array = _cap(z)
	var cap: Vector2 = c[0]
	if cap != Vector2.ONE:
		var cy: float = c[1]
		for k in sec.size():
			sec[k] = Vector2(sec[k].x * cap.x, cy + (sec[k].y - cy) * cap.y)
	return sec


## The half-section's pieces at z, each a polyline starting where the last ended: the bottom, the sill's
## rounding, the lower side out to the crease, the upper side in to the belt, then the shoulder, rim, wall,
## corner and crowned top.
func _segments(z: float) -> Array:
	var bot: float = prof["bot"].at(z)
	var w: float = prof["w"].at(z)
	var tuck: float = prof["tuck"].at(z)
	var crease: float = prof["crease"].at(z)
	var belt: float = prof["belt"].at(z)
	var lean: float = prof["lean"].at(z)
	var wb: float = w - tuck
	var rb: float = minf(bottom_radius, (crease - bot) * 0.35)
	var sill := Vector2(wb, bot)
	var up: Vector2 = Vector2(tuck, crease - bot).normalized()
	var bottom := PackedVector2Array()
	for k in 7:
		bottom.append(Vector2((wb - rb) * k / 6.0, bot))
	var ca: Vector2 = sill - Vector2(rb, 0.0)
	var cb: Vector2 = sill + up * rb
	var corner := PackedVector2Array()
	for k in 9:
		var t: float = k / 8.0
		corner.append(ca.lerp(sill, t).lerp(sill.lerp(cb, t), t))
	var cr := Vector2(w, crease)
	var bp := Vector2(w - lean, belt)
	var out: Array = [bottom, corner, PackedVector2Array([cb, cr]), PackedVector2Array([cr, bp])]
	out.append_array(_top_segments(z, bp.x, belt))
	return out


## Above the belt (from (bx, belt)): the shoulder (a quarter ellipse up and in), the rim (flat, inward), the
## wall (to the corner: down into the cockpit and onto the engine cover, a few millimetres over the hood),
## the corner, the crowned top.
func _top_segments(z: float, bx: float, belt: float) -> Array:
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
		shoulder.append(Vector2(bx - sx * (1.0 - cos(a)), belt + sy * sin(a)))
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


## Only the nose has a cap; the tail is a flat face.
func _cap(z: float) -> Array:
	if z < nose_tip + nose_cap:
		return super(z)
	return [Vector2.ONE, 0.0]


## The shoulder's top at z (the hood's dome, the cockpit's rim, the blade's outer top edge).
func _shoulder_top(z: float) -> Vector2:
	return Vector2(prof["w"].at(z) - prof["lean"].at(z) - prof["sx"].at(z), prof["belt"].at(z) + prof["sy"].at(z))


## The rim's inner end at z (the cockpit's inner edge, the blade's inner top edge).
func _rim_inner(z: float) -> float:
	return _shoulder_top(z).x - prof["rim_w"].at(z)


## Half the width of the top inside the corner at z (the cockpit floor, the engine cover).
func _deck_half(z: float) -> float:
	return _rim_inner(z) - prof["wall_dx"].at(z) - prof["cx"].at(z)


## The body's outermost x at height y at z (where the wishbones meet it).
func _body_x(y: float, z: float) -> float:
	var sec: PackedVector2Array = section(z)
	var best := 0.0
	for k in range(1, sec.size()):
		var a: Vector2 = sec[k - 1]
		var c: Vector2 = sec[k]
		if (y - a.y) * (y - c.y) <= 0.0 and absf(c.y - a.y) > 1e-9:
			best = maxf(best, lerpf(a.x, c.x, (y - a.y) / (c.y - a.y)))
	return best


# ============================================================================================
#  Body
# ============================================================================================

func build_shell(b) -> void:
	super(b)
	# The tail: one flat face over the last ring (black, the fascia; the fins start on its upper corners).
	var sec: PackedVector2Array = section(TAIL_TIP)
	var poly := PackedVector2Array()
	for p in sec:
		poly.append(p)
	for k in range(sec.size() - 2, 0, -1):
		poly.append(Vector2(-sec[k].x, sec[k].y))
	var clean := PackedVector2Array()
	for p in poly:
		if clean.is_empty() or p.distance_to(clean[clean.size() - 1]) > 1e-5:
			clean.append(p)
	if clean[0].distance_to(clean[clean.size() - 1]) < 1e-5:
		clean.remove_at(clean.size() - 1)
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(clean)
	if tris.is_empty():
		push_error("CrimsonBuilder: the tail face didn't triangulate")
		return
	var ids := []
	for p in clean:
		ids.append(b.vertex(Vector3(p.x, p.y, TAIL_TIP), Vector3.BACK, CB.M_DARK, C_DARKER))
	for k in range(0, tris.size(), 3):
		b.tri(ids[tris[k]], ids[tris[k + 1]], ids[tris[k + 2]])


func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_fin(b)
	_front_fender(b)
	_rear_fender(b)
	_front_suspension(b)
	_rear_suspension(b)
	_lamp_pod(b)
	_headrest(b)
	_seat(b, SEAT_X)
	_exhaust_pair(b, 0.122)
	b.mirror_x(v0, i0)
	_front_wing(b)
	_rear_wing(b)
	_screen_frame(b)
	_steering_wheel(b)
	_engine_cover(b)
	_fascia(b)
	_nose_details(b)
	# The filler cap on the deck between the headrests.
	var fz := 0.420
	var fy: float = top_y(0.0, fz)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.0, fy - 0.003, fz), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.026), Vector2(0.004, 0.026),
			Vector2(0.007, 0.020), Vector2(0.008, 0.0)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(0.0, fy - 0.01, fz))


## The right fin: the blade (the upper side's top third, the shoulder, the blade's top and its inner wall down to
## the engine cover, as the shell's last ring has them) lofted on past the tail, rising to FIN_TOP and narrowing
## to a point at FIN_TIP, its underside closed by a face from the inner foot to the outer one.
func _fin(b) -> void:
	var root: PackedVector2Array = section(TAIL_TIP)
	var pts: PackedVector2Array = root.slice(FIN_FROM, FIN_TO + 1)
	# The blade's top (the rim, flat across): the fin closes onto the middle of it.
	var top0 := -1.0
	for p in pts:
		top0 = maxf(top0, p.y)
	var xs := 0.0
	var count := 0
	for p in pts:
		if p.y > top0 - 1e-4:
			xs += p.x
			count += 1
	var xc: float = xs / count
	var rows := []
	var unders := []
	var n := 20
	for s in n + 1:
		var t: float = float(s) / n
		var z: float = lerpf(TAIL_TIP, FIN_TIP, t)
		var top: float = lerpf(top0, FIN_TOP, t)
		var d: float = 1.0 - t
		var th: float = pow(1.0 - t, 0.6)
		var xt: float = lerpf(xc, FIN_X_TIP, pow(t, 1.3))
		var row := PackedVector3Array()
		for p in pts:
			row.append(Vector3(xt + (p.x - xc) * th, top - (top0 - p.y) * d, z))
		rows.append(row)
		unders.append(PackedVector3Array([row[row.size() - 1], row[0]]))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_PAINT, Color(1, 1, 1), false, false)
	b.orient_away_from(vb, ib, Vector3(xc - 0.06, top0 - 0.06, lerpf(TAIL_TIP, FIN_TIP, 0.35)))
	vb = b.vertex_count()
	ib = b.index_count()
	b.grid(unders, CB.M_PAINT, Color(1, 1, 1), false, false)
	b.orient_toward(vb, ib, Vector3.DOWN)


## A shell round the axis along x through c (a fender): its cross-section across the tyre `sect` ([x, radial
## offset] from the inner edge to the outer) at radius r, from th0 to th1 (radians from straight up, positive
## toward the rear), `thick` thick: the outer skin, the underside, both edges and both ends closed.
func _band_shell(b, c: Vector3, r: float, th0: float, th1: float, n: int, sect: PackedVector2Array, thick: float,
		mat: int, col: Color) -> void:
	var outer := []
	var inner := []
	for k in n + 1:
		var a: float = lerpf(th0, th1, float(k) / n)
		var rad := Vector3(0.0, cos(a), sin(a))
		var ro := PackedVector3Array()
		var ri := PackedVector3Array()
		for q in sect:
			ro.append(Vector3(q.x, c.y, c.z) + rad * (r + q.y))
			ri.append(Vector3(q.x, c.y, c.z) + rad * (r + q.y - thick))
		outer.append(ro)
		inner.append(ri)
	var axis_mid := Vector3((sect[0].x + sect[sect.size() - 1].x) * 0.5, c.y, c.z)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(outer, mat, col, false, false)
	b.orient_away_from(vb, ib, axis_mid)
	vb = b.vertex_count()
	ib = b.index_count()
	b.grid(inner, mat, col, false, false)
	b.orient_away_from(vb, ib, axis_mid)
	b.flip(vb, ib)
	var last: int = sect.size() - 1
	for side in [[0, Vector3.LEFT], [last, Vector3.RIGHT]]:
		var rows := []
		for k in n + 1:
			rows.append(PackedVector3Array([(outer[k] as PackedVector3Array)[side[0]], (inner[k] as PackedVector3Array)[side[0]]]))
		vb = b.vertex_count()
		ib = b.index_count()
		b.grid(rows, mat, col, false, false)
		b.orient_toward(vb, ib, side[1])
	for end in [[0, th0, -1.0], [n, th1, 1.0]]:
		var tang: Vector3 = Vector3(0.0, -sin(end[1]), cos(end[1])) * float(end[2])
		vb = b.vertex_count()
		ib = b.index_count()
		b.grid([outer[end[0]], inner[end[0]]], mat, col, false, false)
		b.orient_toward(vb, ib, tang)


## A front cycle fender: a rounded black hood over the top of the tyre from ahead of it to behind the top, its
## edges curling down. Mounted on the body, so it stands clear of the tyre at full lock (the tread only swings
## sideways under it); a stay down to the upper wishbone.
func _front_fender(b) -> void:
	var r := 0.219
	var half := 0.104
	var sect := PackedVector2Array()
	for k in 15:
		var u: float = lerpf(-1.0, 1.0, k / 14.0)
		sect.append(Vector2(WHEEL_X_F + half * u, 0.012 - 0.036 * pow(absf(u), 4.0)))
	_band_shell(b, Vector3(0.0, HUB_Y, AXLE_F), r, -0.88, 0.55, 26, sect, 0.006, CB.M_DARK, C_FENDER)
	b.tube(PackedVector3Array([Vector3(WHEEL_X_F - half + 0.010, HUB_Y + r - 0.020, AXLE_F - 0.020),
			Vector3(0.335, 0.276, AXLE_F - 0.012)]), 0.0065, 8, CB.M_DARK, C_ARM, true, true)


## A rear fender: a deep black shell over the tyre from ahead of the top round to below the hub behind it, its
## inner edge buried in the body, its outer edge rolling down over the tyre's shoulder.
func _rear_fender(b) -> void:
	var x0 := 0.322
	var x1: float = WHEEL_X_R + 0.120
	var sect := PackedVector2Array()
	for k in 15:
		var u: float = k / 14.0
		sect.append(Vector2(lerpf(x0, x1, u), 0.014 - 0.058 * pow(u, 6.0)))
	_band_shell(b, Vector3(0.0, HUB_Y, AXLE_R), 0.215, -1.05, 1.85, 40, sect, 0.006, CB.M_DARK, C_FENDER)


## The front suspension: upper and lower wishbones from the body's side out to the upright inside the wheel, a
## pushrod up to the nose, the track rod.
func _front_suspension(b) -> void:
	var z := AXLE_F
	var hx: float = WHEEL_X_F - 0.058
	var yu := 0.276
	var yl := 0.108
	var xu: float = _body_x(yu, z) - 0.012
	var xl: float = _body_x(yl, z) - 0.012
	b.tube(PackedVector3Array([Vector3(xu, yu, z - 0.095), Vector3(hx, yu + 0.004, z), Vector3(xu, yu, z + 0.085)]),
			0.0075, 8, CB.M_DARK, C_ARM, true, true)
	b.tube(PackedVector3Array([Vector3(xl, yl, z - 0.115), Vector3(hx, yl - 0.004, z), Vector3(xl, yl, z + 0.105)]),
			0.0085, 8, CB.M_DARK, C_ARM, true, true)
	var yp := 0.300
	b.tube(PackedVector3Array([Vector3(hx - 0.012, yl + 0.006, z + 0.012), Vector3(_body_x(yp, z + 0.035) - 0.010,
			yp, z + 0.035)]), 0.0060, 8, CB.M_DARK, C_ARM, true, true)
	var yt := 0.180
	b.tube(PackedVector3Array([Vector3(_body_x(yt, z + 0.070) - 0.012, yt, z + 0.070), Vector3(hx, yt, z + 0.072)]),
			0.0055, 8, CB.M_ALLOY, C_ALLOY_DARK, true, true)
	# The upright, inside the rim.
	b.rbox(Transform3D(Basis(), Vector3(hx + 0.006, (yu + yl) * 0.5, z)), Vector3(0.012, (yu - yl) * 0.5 + 0.01, 0.022),
			0.006, 1, CB.M_DARK, C_ARM)


## The rear suspension, mostly under the fender: wishbones and the half shaft to the hub.
func _rear_suspension(b) -> void:
	var z := AXLE_R
	var hx: float = WHEEL_X_R - 0.088
	var yl := 0.105
	var xl: float = _body_x(yl, z) - 0.012
	b.tube(PackedVector3Array([Vector3(xl, yl, z - 0.115), Vector3(hx, yl - 0.004, z), Vector3(xl, yl, z + 0.100)]),
			0.0085, 8, CB.M_DARK, C_ARM, true, true)
	b.tube(PackedVector3Array([Vector3(_body_x(HUB_Y, z) - 0.015, HUB_Y, z), Vector3(hx, HUB_Y, z)]), 0.012, 10, CB.M_ALLOY,
			C_ALLOY_DARK, true, true)


## The LED headlamp pod at the screen's front corner, on a stalk from the shoulder: a black teardrop, a glowing
## blue lens facing forward and a mirror glass on its back.
func _lamp_pod(b) -> void:
	var c := Vector3(0.405, 0.478, -0.240)
	var fwd: Vector3 = Vector3(0.10, 0.02, -1.0).normalized()
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, fwd, PackedVector2Array([Vector2(-0.064, 0.0), Vector2(-0.056, 0.013), Vector2(-0.038, 0.025),
			Vector2(-0.011, 0.030), Vector2(0.016, 0.028), Vector2(0.029, 0.023), Vector2(0.032, 0.0)]), 18, CB.M_DARK,
			C_DARK)
	b.orient_away_from(vb, ib, c)
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(c + fwd * 0.031, fwd, PackedVector2Array([Vector2(0.0, 0.0195), Vector2(0.004, 0.014), Vector2(0.0055, 0.0)]),
			18, CB.M_TAILLAMP, C_LED)
	b.orient_away_from(vb, ib, c)
	b.tube(PackedVector3Array([c + Vector3(-0.016, -0.014, 0.016), Vector3(0.322, 0.405, -0.208)]), 0.0065, 8, CB.M_DARK,
			C_DARK, false, true)


## The headrest hump behind the right seat: black, standing out of the deck, tapering back to nothing.
func _headrest(b) -> void:
	var z0 := 0.282
	var z1 := 0.640
	var rows := []
	var n := 14
	for s in n + 1:
		var t: float = float(s) / n
		var z: float = lerpf(z0, z1, t)
		var hh: float = 0.105 * pow(1.0 - t, 0.55) + 0.001
		var hw: float = 0.070 * pow(1.0 - t, 0.30) + 0.001
		var row := PackedVector3Array()
		for k in 13:
			var a: float = PI * k / 12.0
			var x: float = SEAT_X + hw * cos(a)
			row.append(Vector3(x, top_y(x, z) - 0.008 + (hh + 0.008) * sin(a), z))
		rows.append(row)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_DARK, C_SEAT, false, false)
	b.orient_away_from(vb, ib, Vector3(SEAT_X, 0.40, (z0 + z1) * 0.5))
	b.poly(rows[0], Vector3.FORWARD, CB.M_DARK, C_SEAT)


## A black bucket seat: cushion, raked back rising over the rim, side bolsters, the harness in the accent colour.
func _seat(b, sx: float) -> void:
	var floor_y := 0.120
	b.rbox(Transform3D(Basis(), Vector3(sx, floor_y + 0.035, 0.160)), Vector3(0.090, 0.030, 0.085), 0.020, 2, CB.M_DARK,
			C_SEAT)
	var rake := Basis(Vector3.RIGHT, 0.22)
	var back_c := Vector3(sx, floor_y + 0.215, 0.252)
	b.rbox(Transform3D(rake, back_c), Vector3(0.092, 0.180, 0.024), 0.020, 2, CB.M_DARK, C_SEAT)
	for side in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(side * 0.088, -0.03, -0.030)), Vector3(0.014, 0.130, 0.030),
				0.010, 1, CB.M_DARK, C_SEAT)
		b.rbox(Transform3D(Basis(), Vector3(sx + side * 0.086, floor_y + 0.060, 0.150)), Vector3(0.012, 0.025, 0.075),
				0.008, 1, CB.M_DARK, C_SEAT)
	# Harness: two shoulder straps down the back's face.
	for side in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(side * 0.034, 0.02, -0.026)), Vector3(0.011, 0.150, 0.003),
				0.002, 1, CB.M_ANODISED, Color(1, 1, 1))


## A pair of oval tailpipes out of the fascia's foot, at x and its neighbour.
func _exhaust_pair(b, x: float) -> void:
	for dx in [-0.028, 0.028]:
		var c := Vector3(x + dx, 0.150, TAIL_TIP)
		b.oval_tube(PackedVector3Array([c + Vector3(0.0, 0.0, -0.030), c, c + Vector3(0.0, 0.0, 0.030)]), 0.022, 0.014,
				Vector3.UP, 16, CB.M_CHROME, C_CHROME, false)
		b.oval_tube(PackedVector3Array([c + Vector3(0.0, 0.0, -0.020), c, c + Vector3(0.0, 0.0, 0.031)]), 0.017, 0.009,
				Vector3.UP, 16, CB.M_DARK, C_DARKER, false)


## The front wing: an airfoil across the nose, flat to WING_FLAT and curling up to its tips, bowed forward in the
## middle; an LED line along its leading edge, amber markers near its tips.
func _front_wing(b) -> void:
	var path := PackedVector3Array()
	var n := 33
	for k in n:
		var u: float = lerpf(-1.0, 1.0, float(k) / (n - 1))
		path.append(_wing_pt(u))
	var prof2 := PackedVector2Array()
	for p in WING_PROFILE:
		prof2.append(Vector2(p[0], p[1]))
	sweep(b, path, Vector3.BACK, Vector3.UP, prof2, CB.M_DARK, C_DARK)
	# LED line under the leading edge's lip, across the flat part.
	var led := PackedVector3Array()
	for k in 17:
		var u: float = lerpf(-0.78, 0.78, k / 16.0)
		led.append(_wing_pt(u) + Vector3(0.0, 0.001, -0.064))
	b.tube(led, 0.0038, 6, CB.M_TAILLAMP, C_LED, true, true)
	for s in [-1.0, 1.0]:
		var p: Vector3 = _wing_pt(0.86 * s)
		b.rbox(Transform3D(Basis(), p + Vector3(0.0, 0.003, -0.058)), Vector3(0.020, 0.004, 0.006), 0.003, 1, CB.M_TAILLAMP,
				C_AMBER)


## The wing's spine at u (-1 the left tip, 1 the right): flat across, bowed forward 2cm in the middle, the last
## stretch curling up to the tip.
func _wing_pt(u: float) -> Vector3:
	var x: float = u * WING_HALF
	var ax: float = absf(x)
	var z: float = WING_Z - 0.020 * (1.0 - pow(minf(ax / WING_FLAT, 1.0), 2.0))
	if ax <= WING_FLAT:
		return Vector3(x, WING_Y, z)
	var r := 0.070
	var a: float = (ax - WING_FLAT) / r
	var a_max: float = 1.15
	var aa: float = minf(a, a_max)
	var dx: float = r * sin(aa) + maxf(a - a_max, 0.0) * r * cos(a_max)
	var dy: float = r * (1.0 - cos(aa)) + maxf(a - a_max, 0.0) * r * sin(a_max)
	return Vector3(signf(x) * (WING_FLAT + dx), WING_Y + dy, z + 0.010 * (ax - WING_FLAT) / (WING_HALF - WING_FLAT))


## The rear wing between the fins, its ends inside them.
func _rear_wing(b) -> void:
	var path := PackedVector3Array()
	for k in 9:
		path.append(Vector3(lerpf(-REAR_WING_HALF, REAR_WING_HALF, k / 8.0), REAR_WING_Y, REAR_WING_Z))
	var prof2 := PackedVector2Array()
	for p in REAR_WING_PROFILE:
		prof2.append(Vector2(p[0], p[1]))
	sweep(b, path, Vector3.BACK, Vector3.UP, prof2, CB.M_PAINT, Color(1, 1, 1))


## The engine cover between the blades: black louvres across it, following its crown.
func _engine_cover(b) -> void:
	var z: float = ENGINE_COVER_Z.x + 0.03
	while z < ENGINE_COVER_Z.y - 0.015:
		var half: float = _deck_half(z) - 0.010
		var path := PackedVector3Array()
		for k in 9:
			var x: float = lerpf(-half, half, k / 8.0)
			path.append(Vector3(x, top_y(x, z) + 0.001, z))
		sweep(b, path, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.007, 0.0), Vector2(0.007, 0.0),
				Vector2(0.007, 0.004), Vector2(-0.005, 0.007)]), CB.M_DARK, C_LOUVRE)
		z += 0.026


## The tail's fascia: louvres across its upper half, a slim red lamp under the engine cover's edge, diffuser
## strakes under it.
func _fascia(b) -> void:
	for k in 5:
		var y: float = 0.268 + 0.022 * k
		var half: float = 0.200
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0.0, y, TAIL_TIP + 0.004)), Vector3(half, 0.004, 0.006),
				0.002, 1, CB.M_DARK, C_LOUVRE)
	var lamp := PackedVector3Array([Vector3(-0.230, 0.388, TAIL_TIP + 0.002), Vector3(0.230, 0.388, TAIL_TIP + 0.002)])
	b.oval_tube(lamp, 0.006, 0.004, Vector3.UP, 8, CB.M_TAILLAMP, C_TAILLAMP, true)
	for x in [-0.200, -0.065, 0.065, 0.200]:
		slab(b, PackedVector2Array([Vector2(0.80, 0.062), Vector2(TAIL_TIP + 0.010, 0.080), Vector2(TAIL_TIP + 0.010, 0.120),
				Vector2(0.86, 0.066)]), x, 0.006, CB.M_DARK, C_DARK)


## The nose under the wing: the intake's slats.
func _nose_details(b) -> void:
	for k in 3:
		var y: float = 0.118 + 0.014 * k
		var zf: float = shell_z(0.0, y, true)
		bar(b, Vector3(0.0, y, zf + 0.004), Vector3(0.050, 0.0018, 0.004), CB.M_DARK, C_LOUVRE)


## The cockpit's steering wheel, in front of the left seat on its column from the dash.
func _steering_wheel(b) -> void:
	var c := Vector3(-SEAT_X, 0.335, -0.085)
	var tilt := Basis(Vector3.RIGHT, -0.40)
	var rim := PackedVector3Array()
	for k in 25:
		var a: float = TAU * k / 24.0
		rim.append(c + tilt * Vector3(cos(a) * 0.050, sin(a) * 0.044, 0.0))
	b.tube(rim, 0.0065, 6, CB.M_DARK, C_SEAT, false, false)
	for a in [0.0, PI, PI * 1.5]:
		b.tube(PackedVector3Array([c, c + tilt * Vector3(cos(a) * 0.046, sin(a) * 0.040, 0.0)]), 0.0045, 6, CB.M_DARK,
				C_ARM, false, false)
	b.tube(PackedVector3Array([c, c + tilt * Vector3(0.0, 0.0, -0.14)]), 0.010, 8, CB.M_DARK, C_DARK, true, true)


# ============================================================================================
#  Windscreen
# ============================================================================================

## The screen's foot in plan (x, z) from its left end round the front to its right end, and each point's arc
## length from the middle.
func _screen_base() -> Array:
	var half := PackedVector2Array()
	var xs: float = SCREEN_SIDE_X
	var rc: float = SCREEN_CORNER_R
	var zf: float = SCREEN_FRONT_Z
	var xf: float = xs - rc
	for k in 8:
		var x: float = xf * k / 8.0
		half.append(Vector2(x, zf - 0.012 * (1.0 - pow(x / xf, 2.0))))
	for k in 7:
		var a: float = PI * 0.5 * k / 6.0
		half.append(Vector2(xf + rc * sin(a), zf + rc * (1.0 - cos(a))))
	for k in range(1, 10):
		half.append(Vector2(xs, lerpf(zf + rc, SCREEN_END_Z, k / 9.0)))
	var pts := PackedVector2Array()
	for k in range(half.size() - 1, 0, -1):
		pts.append(Vector2(-half[k].x, half[k].y))
	pts.append_array(half)
	var s := PackedFloat32Array()
	var mid: int = half.size() - 1
	var acc := 0.0
	s.resize(pts.size())
	s[mid] = 0.0
	for k in range(mid + 1, pts.size()):
		acc += pts[k].distance_to(pts[k - 1])
		s[k] = acc
	for k in range(mid - 1, -1, -1):
		s[k] = s[2 * mid - k]
	return [pts, s, acc]


## The screen's foot and top at base point k: [foot, top] in 3D. The whole top edge is raked back by its height
## (so it never doubles back round the corners), the sides leaning in.
func _screen_edge(base: Array, k: int) -> Array:
	var pts: PackedVector2Array = base[0]
	var s: PackedFloat32Array = base[1]
	var total: float = base[2]
	var p: Vector2 = pts[k]
	var foot := Vector3(p.x, top_y(p.x, p.y) + 0.002, p.y)
	var s_front: float = SCREEN_SIDE_X - SCREEN_CORNER_R
	var s_side: float = s_front + PI * 0.5 * SCREEN_CORNER_R
	var t_side: float = clampf((s[k] - s_side) / (total - s_side), 0.0, 1.0)
	var f: float = pow(cos(PI * 0.5 * t_side), 0.70)
	var turn: float = clampf((s[k] - s_front) / (s_side - s_front), 0.0, 1.0)
	var top := Vector3(foot.x - signf(p.x) * SCREEN_LEAN * f * turn, lerpf(foot.y, SCREEN_TOP_Y, f), foot.z + SCREEN_RAKE * f)
	return [foot, top]


## The glass, both faces (car_glass culls back faces), bowing out a little between its foot and top.
func build_glass(b) -> void:
	var base: Array = _screen_base()
	var count: int = (base[0] as PackedVector2Array).size()
	for face_dir in [1.0, -1.0]:
		var rows := []
		for k in count:
			var e: Array = _screen_edge(base, k)
			var foot: Vector3 = e[0]
			var top: Vector3 = e[1]
			var row := PackedVector3Array()
			for j in 6:
				var t: float = j / 5.0
				var p: Vector3 = foot.lerp(top, t)
				row.append(p + _screen_out(base, k) * (0.010 * sin(PI * t) + 0.0006 * face_dir))
			rows.append(row)
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.grid(rows, CB.M_DARK, GLASS_TINT, false, false)
		var mid: Vector3 = _screen_edge(base, count / 2)[0]
		if face_dir > 0.0:
			b.orient_away_from(vb, ib, Vector3(0.0, mid.y, mid.z + 0.25))
		else:
			b.orient_toward(vb, ib, Vector3(0.0, -0.2, 1.0))


## The outward direction (in plan) of the screen at base point k.
func _screen_out(base: Array, k: int) -> Vector3:
	var pts: PackedVector2Array = base[0]
	var a: Vector2 = pts[maxi(k - 1, 0)]
	var c: Vector2 = pts[mini(k + 1, pts.size() - 1)]
	var t: Vector2 = (c - a).normalized()
	var o := Vector2(t.y, -t.x)
	if o.dot(pts[k] - Vector2(0.0, -0.05)) < 0.0:
		o = -o
	return Vector3(o.x, 0.0, o.y)


## The screen's black hoop along its top edge and a thin seal along its foot.
func _screen_frame(b) -> void:
	var base: Array = _screen_base()
	var count: int = (base[0] as PackedVector2Array).size()
	var top := PackedVector3Array()
	var foot := PackedVector3Array()
	for k in count:
		var e: Array = _screen_edge(base, k)
		top.append((e[1] as Vector3) + _screen_out(base, k) * 0.001)
		foot.append((e[0] as Vector3) + _screen_out(base, k) * 0.002)
	b.tube(top, 0.0095, 8, CB.M_DARK, C_DARK, true, true)
	b.tube(foot, 0.0042, 6, CB.M_DARK, C_DARK, true, true)


# ============================================================================================
#  Wheels
# ============================================================================================

func build_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_FRONT, RIM_R_F)


func build_rear_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_REAR, RIM_R_R)


## A low-profile tyre on a cross-spoke rim: a polished lip and dish, twelve pairs of thin spokes crossing in a
## mesh, a hub with five bolts and a polished centre cap; a dark back and the brake disc behind.
func _wheel(b, side: float, half: Array, rim_r: float) -> void:
	tyre(b, half, 56, C_RUBBER)
	var hw: float = -float(half[0][0])
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - 0.020
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.012, rim_r), Vector2(lip_x - 0.002, rim_r + 0.006),
			Vector2(lip_x + 0.003, rim_r + 0.004), Vector2(lip_x + 0.004, rim_r - 0.003), Vector2(lip_x, rim_r - 0.010)]),
			56, CB.M_CHROME, C_CHROME, "out", Vector3(lip_x - 0.03, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x, rim_r - 0.010), Vector2(face_x + 0.004, rim_r - 0.014),
			Vector2(face_x, rim_r - 0.019)]), 56, CB.M_CHROME, C_CHROME, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(face_x, rim_r - 0.019), Vector2(face_x - 0.006, rim_r - 0.008),
			Vector2(-hw + 0.012, rim_r - 0.004), Vector2(-hw + 0.004, rim_r + 0.002)]), 56, CB.M_RIM, C_RIM_BARREL, "in")
	b.disc(Vector3(face_x - 0.042, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.010, 0.0, 40, CB.M_DARK, C_DARKER)
	b.disc(Vector3(face_x - 0.030, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.024, 0.042, 40, CB.M_ALLOY, C_ALLOY_DARK)
	# The mesh: from each of twelve points round the hub a spoke leans either way to the rim; neighbours cross.
	var r_out: float = rim_r - 0.017
	for k in MESH_SPOKES:
		var a: float = TAU * k / MESH_SPOKES
		spoke(b, a, MESH_TWIST, 0.036, r_out, face_x + 0.012, face_x + 0.001, 0.0050, 0.0056, 0.008, CB.M_RIM, C_RIM)
		spoke(b, a, -MESH_TWIST, 0.036, r_out, face_x + 0.009, face_x - 0.002, 0.0050, 0.0056, 0.008, CB.M_RIM, C_RIM)
	# Hub, bolts and the centre cap.
	wheel_lathe(b, PackedVector2Array([Vector2(face_x - 0.004, 0.044), Vector2(face_x + 0.014, 0.044),
			Vector2(face_x + 0.018, 0.038)]), 28, CB.M_RIM, C_RIM, "out", Vector3(face_x, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.018, 0.0, 0.0), Vector3.RIGHT, 0.038, 0.0, 28, CB.M_RIM, C_RIM)
	for k in 5:
		var f: Array = wheel_frame(TAU * k / 5.0 + 0.3)
		b.rbox(Transform3D(Basis(), Vector3(face_x + 0.021, 0.0, 0.0) + (f[0] as Vector3) * 0.027),
				Vector3(0.003, 0.0045, 0.0045), 0.002, 1, CB.M_CHROME, C_CHROME)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(face_x + 0.018, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.017),
			Vector2(0.006, 0.015), Vector2(0.010, 0.009), Vector2(0.012, 0.0)]), 20, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(face_x + 0.012, 0.0, 0.0))
	if side < 0.0:
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

## The hood's half width at z: a shield, wide at the screen and coming to a point at the nose.
static func _hood_half(z: float) -> float:
	var t: float = clampf((z - NOSE_TIP) / (COCKPIT_Z.x - NOSE_TIP), 0.0, 1.0)
	return 0.292 * pow(t, 0.85)


func _detail_at(p: Vector3, n: Vector3, fp: float, _sh: Dictionary) -> Color:
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var z: float = p.z
	var st: Vector2 = _shoulder_top(z)
	# The hood: black over the nose's top, inside the shield, a shut line round it.
	if z < COCKPIT_Z.x + 0.004 and n.y > 0.12:
		var d: float = p.x - _hood_half(z)
		black = maxf(black, _cover(d, fp))
		gap = maxf(gap, 0.85 * _cover(absf(d) - 0.0014, fp))
	# The cockpit: black inside the rim, and the dash's and the bulkhead's faces.
	if z > COCKPIT_Z.x - 0.012 and z < COCKPIT_Z.y + 0.012:
		if p.y < st.y - 0.004 and p.x < _rim_inner(z) + 0.002 and n.x < 0.6:
			black = 1.0
	if (n.z > 0.5 and absf(z - COCKPIT_Z.x) < 0.03) or (n.z < -0.5 and absf(z - COCKPIT_Z.y) < 0.03):
		if p.y < st.y - 0.002:
			black = 1.0
	# The engine cover between the blades.
	if z > ENGINE_COVER_Z.x and p.x < _deck_half(z) + 0.004 and n.y > 0.4:
		black = maxf(black, _cover(ENGINE_COVER_Z.x + 0.003 - z, fp))
	# The black tail under the fins, behind the rear wheels.
	var crease: float = prof["crease"].at(z)
	if z > AXLE_R + 0.18 and p.y < crease + (prof["belt"].at(z) - crease) * 0.62:
		black = maxf(black, _cover(AXLE_R + 0.19 - z, fp))
	# The doors (they open upward): shut lines behind the front wheel, at the cockpit's back and along the sill.
	if n.x > 0.3:
		var on_door: bool = p.y > 0.098 and p.y < st.y + 0.004
		for dz in [-0.200, 0.300]:
			if on_door:
				gap = maxf(gap, _cover(absf(z - dz) - 0.0015, fp))
		if z > -0.200 and z < 0.300:
			gap = maxf(gap, 0.8 * _cover(absf(p.y - 0.100) - 0.0014, fp))
	# The intake in the nose's face under the wing.
	if n.z < -0.4 and z < NOSE_TIP + 0.06:
		var d: float = _sd_box(Vector2(p.x, p.y - 0.132), Vector2(0.050, 0.020)) - 0.006
		black = maxf(black, _cover(d, fp))
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(0.0, gap, chrome, black)
