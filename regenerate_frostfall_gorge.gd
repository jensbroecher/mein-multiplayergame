# regenerate_frostfall_gorge.gd
#
# Builds levels/FrostfallGorgeLevel.tscn - an Arctic Cup off-road stage. There is no road: the
# whole lap is driven on snow, rock and lake ice, so every metre counts as off-road and cars
# with a good off-road stat have the edge.
#
# The lap: the start/finish straight runs north up the valley beside a frozen lake. The trail
# climbs onto the east rim of a river gorge and follows it upstream on a ledge, the river below
# on the left and the hillside rising on the right. It jumps two side gullies (fall short and
# you land in the river), climbs past a 25m waterfall, crosses a frozen tarn at the head of the
# river, and comes back down the gorge's high west rim - one more gully jump, 40m above the
# water - to the end of the plateau, where a mega-jump launches the field down a 200m landing
# hill into the valley. The way home crosses the frozen lake the river runs into.
#
# Things worth knowing before editing this file:
#
# 1. The water is not one flat plane. The river falls 34m from the tarn to the lake, so it is
#    described as strips and pools (RIVER_UPPER, RIVER_LOWER, POOL) and saved into a RiverWater
#    node, which PlayerCart asks for the water height under the car. The same data carves the
#    gorge, builds the water meshes and paints the spray zone, so they cannot disagree.
#
# 2. The heightfield is built in layers, in this order, and the order matters:
#      base landscape -> clamp between the trail's fill and cut bounds -> carve the gorge ->
#      carve the gully slots -> flatten the frozen lakes.
#    The trail bounds only keep the ground at trail height along the racing line. The gorge and
#    the gullies are carved after them, so a trail bound can never fill the river back in.
#
# 3. The jumps are measured, not guessed. Gravity in this game is 30 m/s^2, three times real,
#    and the carts have no air control, so _verify_jumps() flies a cart over every gap and the
#    mega-jump at a range of speeds against the heightfield that was actually built and prints
#    where it lands. A gap the slowest cart cannot clear is a push_error.
#
# The menu tile (images/menu/tile_frostfall_gorge.jpg) is a render of the falls, not generated
# here: the generator runs headless and cannot render. Retake it windowed with a Camera3D at
# (24, 19, -296) looking at (2, 21, -352), cropped to 1376x768.
extends Node

const LEVEL_NAME := "FrostfallGorgeLevel"
const LEVEL_PATH := "res://levels/FrostfallGorgeLevel.tscn"
const RES_PREFIX := "frostfall_"
const MeshChunker = preload("res://MeshChunker.gd")
const RiverWaterScript = preload("res://RiverWater.gd")
## See CLAUDE.md, "Large meshes are chunked".
const MESH_CHUNK_CELL := 80.0
const BAKE_INTERVAL := 0.5
const TRACK_MIN_RADIUS := 26.0

# --- The trail ----------------------------------------------------------------------------
## Half width of the dead-flat graded strip under the racing line.
const TRAIL_FLAT := 8.5
## Packed-snow tyre-track band painted on the ground (shader mask), half width.
const TRAIL_PAINT := 8.0
## Uphill side: the cut bank rises at this slope past the flat strip, so the hillside next to
## the trail stays climbable for a cart that runs wide (normal.y ~0.8 at 0.75).
const CUT_SLOPE := 0.75
## River side: the ledge between trail and gorge falls away at this slope.
const LEDGE_SLOPE := 0.06
## Embankment slope where the trail runs above the natural ground.
const FILL_SLOPE := 0.9
## Within this distance of the river, a trail sample treats the river side as a ledge.
const RIVER_SIDE_REACH := 75.0

# --- River ----------------------------------------------------------------------------------
## (x, water surface y, z, half width). Upper river: tarn outlet down to the falls lip.
const RIVER_UPPER := [
	Vector4(-6.0, 34.30, -640.0, 6.0),
	Vector4(8.0, 33.90, -590.0, 7.0),
	Vector4(-6.0, 33.30, -530.0, 8.0),
	Vector4(6.0, 32.60, -460.0, 9.0),
	Vector4(0.0, 31.90, -392.0, 10.0),
	Vector4(0.0, 31.60, -351.0, 10.0),
]
## Lower river: plunge pool down to the frozen lake, where it runs out under the ice.
const RIVER_LOWER := [
	Vector4(0.0, 7.00, -318.0, 11.0),
	Vector4(-8.0, 6.30, -270.0, 11.0),
	Vector4(8.0, 5.40, -210.0, 11.0),
	Vector4(-4.0, 4.50, -150.0, 12.0),
	Vector4(6.0, 3.60, -90.0, 12.0),
	Vector4(4.0, 2.80, -40.0, 13.0),
	Vector4(14.0, 2.00, 30.0, 13.0),
	Vector4(28.0, 1.40, 100.0, 14.0),
	Vector4(38.0, 1.00, 160.0, 15.0),
	Vector4(44.0, 0.70, 214.0, 16.0),
]
## The falls drop off a lip running east-west at this z. Everything north of it (and on it) is
## the upper river, everything south the pool and lower river. It sits exactly on a terrain grid
## row (FINE_Z.x + 3 * 123), so the rock brink is where the water leaves: between rows the
## heightfield can only slope, and the brink would end up a cell behind and below the falls.
const FALLS_LIP_Z := -351.0
## Over the last stretch above the falls the river bed rises into a rock sill just under the
## water, so the river visibly runs up to the brink instead of ending over a deep channel.
const FALLS_SILL_LEN := 26.0
const FALLS_HALF_W := 10.0
## (x, water y, z, radius).
const POOL := Vector4(0.0, 7.0, -330.0, 22.0)
## River bed depth below the water surface at mid channel. Deeper than a cart is tall, so a
## cart in the river is in deep water and drowns rather than driving up the river bed.
const RIVER_DEPTH := 3.2
## Gorge wall steepness (rise per metre) from the water's edge up to the rims.
const GORGE_WALL := 3.2

## Frozen lakes: the valley lake the river runs into, and the tarn it comes out of.
const LAKE_CENTER := Vector2(60.0, 270.0)
const LAKE_RADIUS := Vector2(118.0, 74.0)
const LAKE_ICE_Y := 0.95
const TARN_CENTER := Vector2(-12.0, -680.0)
const TARN_RADIUS := Vector2(84.0, 38.0)
const TARN_ICE_Y := 34.55
const ICE_FEATHER := 22.0

## Plateau the west rim sits on, and the valley floor it ends above.
const VALLEY_Y := 1.7
const PLATEAU_Y := 52.0
## Where the west plateau ends in the escarpment the mega-jump goes off.
const ESCARPMENT_Z := -26.0

# --- Jumps ----------------------------------------------------------------------------------
## Side-gully gaps. `lip` is the take-off edge on the trail centreline, `dir` the travel
## direction (normalised at build time). The gully is GAP_LEN wide at trail level.
const GAPS := [
	{"name": "LowerGully", "lip": Vector3(40.0, 12.0, -205.0), "dir": Vector2(-0.03, -1.0)},
	{"name": "UpperGully", "lip": Vector3(46.0, 41.0, -540.0), "dir": Vector2(-0.10, -1.0)},
	{"name": "HighGully", "lip": Vector3(-51.0, 49.2, -290.0), "dir": Vector2(-0.02, 1.0)},
]
const GAP_LEN := 14.0
## Trail drop from the lip to the landing edge, on top of the kicker height.
const GAP_LANDING_DROP := 3.0
const GAP_RUN_IN := 48.0
const GAP_RUN_OUT := 70.0
const GAP_KICKER_H := 1.6
const GAP_KICKER_DEG := 14.0

## The mega-jump off the end of the plateau.
const MEGA_LIP := Vector3(-75.0, 48.0, -24.0)
const MEGA_DIR := Vector2(-0.14, 1.0)
const MEGA_KICKER_H := 2.5
const MEGA_KICKER_DEG := 16.0
## Landing hill, measured from the top of the kicker: a drop under the lip, then a smootherstep
## down to the valley floor over MEGA_HILL_LEN. Tuned by flying carts at 26..54 m/s with this
## game's 30 m/s^2 gravity: they land 24..96m out with at most ~21 m/s of impact into the
## slope, the same as Frostpeak's Super-Leap onto flat ground.
const MEGA_UNDER_LIP := 7.0
const MEGA_HILL_LEN := 200.0
const MEGA_RUN_UP := 150.0

# --- Terrain grid ---------------------------------------------------------------------------
## The heightfield has 3m cells over the course and stretches to coarse cells toward the edges.
## Rows and columns are spaced independently, so the fine band needs no seams.
const FINE_X := Vector2(-150.0, 220.0)
const FINE_Z := Vector2(-720.0, 360.0)
const FINE_STEP := 3.0
const OUTER_X := Vector2(-760.0, 820.0)
const OUTER_Z := Vector2(-1400.0, 1000.0)
const COARSE_GROWTH := 1.22
const COARSE_MAX := 32.0
## Spatial hash for the trail samples.
const CELL := 40.0
## Forest layout: detailed trees within FOREST_NEAR of the camera, grouped in FOREST_CELL squares;
## low-detail stand-ins beyond, grouped in bigger squares.
const FOREST_NEAR := 240.0
const FOREST_CELL := 160.0
const FOREST_FAR_CELL := 400.0

var main_curve: Curve3D
var _base_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _rock_noise := FastNoiseLite.new()

# Trail samples (every 2m along the racing line) and their hash.
var _ts_pos := PackedVector3Array()
var _ts_right := PackedVector3Array()
var _ts_off := PackedFloat32Array()
## +1 if the river is on the sample's right, -1 left, 0 none near.
var _ts_river_side := PackedFloat32Array()
## Horizontal distance from the sample to the river centreline on that side.
var _ts_river_dist := PackedFloat32Array()
var _ts_cells := {}

# River elements, flattened for the carve: segments (a, b) with surface y and half width.
var _river_segs: Array = []

# Gaps resolved against the built curve.
var _gaps: Array = []
var _mega: Dictionary = {}

# The finished heightfield, so later passes (props, checks) can sample the real ground.
var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
## 1 where the gorge or a gully carve set the height: those faces are rock, however gentle.
var _carved := PackedByteArray()


# ======================================================================================
#  Track
# ======================================================================================

## Control points of the closed lap. Gap and mega-jump stretches are inserted from GAPS and
## MEGA_* so their points sit exactly on one straight line.
func _track_points() -> Array:
	var pts: Array = []
	# --- Start / finish, valley floor east of the frozen lake, running north ---
	pts.append(Vector3(190.0, 1.75, 168.0))   # finish line
	pts.append(Vector3(190.0, 2.0, 96.0))
	pts.append(Vector3(168.0, 3.0, 26.0))
	pts.append(Vector3(122.0, 4.4, -32.0))
	# --- Onto the gorge's east rim, river below on the left ---
	pts.append(Vector3(72.0, 6.4, -92.0))
	_append_gap(pts, 0)
	# --- Past the falls: the trail swings out around a spur to climb above them ---
	pts.append(Vector3(55.0, 12.0, -318.0))
	pts.append(Vector3(95.0, 18.5, -345.0))
	pts.append(Vector3(112.0, 25.0, -395.0))
	pts.append(Vector3(92.0, 31.0, -440.0))
	_append_gap(pts, 1)
	# --- Round the head of the river across the frozen tarn ---
	pts.append(Vector3(38.0, 35.0, -650.0))
	pts.append(Vector3(-20.0, TARN_ICE_Y + 0.05, -702.0))
	pts.append(Vector3(-80.0, 34.9, -690.0))
	pts.append(Vector3(-100.0, 37.5, -640.0))
	# --- Back down the high west rim, river below on the left ---
	pts.append(Vector3(-72.0, 41.5, -585.0))
	pts.append(Vector3(-56.0, 45.5, -520.0))
	pts.append(Vector3(-50.0, 48.0, -450.0))
	pts.append(Vector3(-50.0, 49.0, -380.0))
	_append_gap(pts, 2)
	# --- The mega-jump: run-up, kicker, landing hill, outrun ---
	_append_mega(pts)
	# --- Home across the frozen lake ---
	pts.append(Vector3(-90.0, VALLEY_Y + 0.1, 262.0))
	pts.append(Vector3(-30.0, LAKE_ICE_Y + 0.05, 300.0))
	pts.append(Vector3(60.0, LAKE_ICE_Y + 0.05, 318.0))
	pts.append(Vector3(140.0, LAKE_ICE_Y + 0.05, 300.0))
	pts.append(Vector3(182.0, 1.5, 252.0))
	return pts


func _append_gap(pts: Array, i: int) -> void:
	var g: Dictionary = GAPS[i]
	var d2: Vector2 = (g["dir"] as Vector2).normalized()
	var d := Vector3(d2.x, 0.0, d2.y)
	var lip: Vector3 = g["lip"]
	pts.append(lip - d * GAP_RUN_IN + Vector3(0, -0.9, 0))
	pts.append(lip - d * (GAP_RUN_IN * 0.4) + Vector3(0, -0.35, 0))
	pts.append(lip)
	pts.append(lip + d * GAP_LEN + Vector3(0, -GAP_LANDING_DROP, 0))
	pts.append(lip + d * (GAP_LEN + 28.0) + Vector3(0, -GAP_LANDING_DROP - 0.7, 0))
	pts.append(lip + d * GAP_RUN_OUT + Vector3(0, -GAP_LANDING_DROP - 0.6, 0))


## Height of the mega-jump landing hill `x` metres past the lip, relative to the kicker top.
func _mega_hill(x: float) -> float:
	var drop: float = (MEGA_LIP.y + MEGA_KICKER_H) - VALLEY_Y
	if x <= 0.0:
		return -MEGA_KICKER_H
	if x < 6.0:
		return lerpf(-MEGA_KICKER_H - 1.0, -MEGA_UNDER_LIP, pow(x / 6.0, 0.6))
	var u: float = clampf((x - 6.0) / (MEGA_HILL_LEN - 6.0), 0.0, 1.0)
	var s: float = u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
	return -MEGA_UNDER_LIP - (drop - MEGA_UNDER_LIP) * s


func _append_mega(pts: Array) -> void:
	var d2: Vector2 = MEGA_DIR.normalized()
	var d := Vector3(d2.x, 0.0, d2.y)
	var lip := MEGA_LIP
	var top_y: float = lip.y + MEGA_KICKER_H
	pts.append(lip - d * MEGA_RUN_UP + Vector3(0, -0.6, 0))
	pts.append(lip - d * (MEGA_RUN_UP * 0.5) + Vector3(0, -0.3, 0))
	pts.append(lip)
	for x in [10.0, 30.0, 55.0, 80.0, 105.0, 130.0, 155.0, 180.0, MEGA_HILL_LEN]:
		var p: Vector3 = lip + d * x
		p.y = top_y + _mega_hill(x)
		pts.append(p)
	# Outrun, still on the jump line, before the trail turns for the lake.
	var run: Vector3 = lip + d * (MEGA_HILL_LEN + 34.0)
	run.y = VALLEY_Y + 0.1
	pts.append(run)


## Handles for one control point from the directions and lengths of the segments either side
## (same rules as Northlight Caverns: tangent bisects the turn, length from Catmull-Rom or the
## turn radius, capped so the control polygon cannot fold).
func _handles_for(seg_in: Vector3, seg_out: Vector3, min_radius: float) -> Array:
	var l_in: float = seg_in.length()
	var l_out: float = seg_out.length()
	var u_in: Vector3 = seg_in / l_in if l_in > 0.001 else (seg_out.normalized() if l_out > 0.001 else Vector3.FORWARD)
	var u_out: Vector3 = seg_out / l_out if l_out > 0.001 else u_in
	var dir: Vector3 = u_in + u_out
	if dir.length_squared() < 0.02:
		var perp := Vector3(-u_in.z, 0.0, u_in.x)
		dir = perp.normalized()
		if dir.dot(seg_in + seg_out) < 0.0:
			dir = -dir
	else:
		dir = dir.normalized()
	var theta: float = u_in.angle_to(u_out)
	var needed: float = (4.0 / 3.0) * tan(theta * 0.25) * min_radius
	var catmull: float = (l_in + l_out) / 6.0
	var ceiling: float = 0.45 * minf(l_in, l_out)
	var h: float = clampf(maxf(needed, catmull), 2.0, maxf(ceiling, 2.0))
	return [dir * -h, dir * h, needed > ceiling]


func _build_closed_loop(points: Array) -> Curve3D:
	var n: int = points.size()
	var handles: Array = []
	for i in range(n):
		var prev: Vector3 = points[(i - 1 + n) % n]
		var cur: Vector3 = points[i]
		var nxt: Vector3 = points[(i + 1) % n]
		var h: Array = _handles_for(cur - prev, nxt - cur, TRACK_MIN_RADIUS)
		handles.append(h)
		if h[2]:
			push_warning("Control point %d (%.0f, %.0f) wants a %.0fm radius but its chord only allows it" % [
				i, cur.x, cur.z, TRACK_MIN_RADIUS])
	var curve := Curve3D.new()
	curve.bake_interval = BAKE_INTERVAL
	for i in range(n + 1):
		var idx: int = i % n
		curve.add_point(points[idx], handles[idx][0], handles[idx][1])
	return curve


func _frame_at_offset(curve: Curve3D, off: float) -> Dictionary:
	var length: float = curve.get_baked_length()
	off = fposmod(off, length)
	var c: Vector3 = curve.sample_baked(off)
	var nxt: Vector3 = curve.sample_baked(fposmod(off + 1.0, length))
	var fwd: Vector3 = nxt - c
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	return {"pos": c, "fwd": fwd, "right": right, "off": off}


## Spots along the lap: position, yaw facing travel, and the frame.
func _spot(off: float, lat: float, lift: float) -> Dictionary:
	var f: Dictionary = _frame_at_offset(main_curve, off)
	var p: Vector3 = f["pos"] + f["right"] * lat
	p.y = _ground_at(p.x, p.z) + lift
	var fwd: Vector3 = f["fwd"]
	return {"pos": p, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": f["right"]}


# ======================================================================================
#  Self-checks
# ======================================================================================

func _verify_plan(curve: Curve3D) -> void:
	var length: float = curve.get_baked_length()
	var step := 3.0
	var n: int = int(length / step)
	var worst := 1e9
	var bad := 0
	for i in range(n):
		var a: Vector3 = curve.sample_baked(float(i) * step)
		for j in range(i + 1, n):
			var raw: int = j - i
			if mini(raw, n - raw) * step < 160.0:
				continue
			var b: Vector3 = curve.sample_baked(float(j) * step)
			var d := Vector2(a.x - b.x, a.z - b.z).length()
			worst = minf(worst, d)
			if d < 40.0:
				bad += 1
				if bad <= 6:
					push_error("Trail runs within %.1fm of itself at %.0fm (%.0f, %.0f) and %.0fm (%.0f, %.0f)" % [
						d, i * step, a.x, a.z, j * step, b.x, b.z])
	print("  plan: tightest self-approach %.1fm (%d close samples)" % [worst, bad])


func _verify_min_radius(curve: Curve3D) -> void:
	var length: float = curve.get_baked_length()
	var window := 8.0
	var worst := 1e9
	var worst_at := 0.0
	for i in range(int(length)):
		var d := float(i)
		var a: Vector3 = curve.sample_baked(fposmod(d - window, length))
		var b: Vector3 = curve.sample_baked(d)
		var c: Vector3 = curve.sample_baked(fposmod(d + window, length))
		a.y = 0.0
		b.y = 0.0
		c.y = 0.0
		var v1: Vector3 = b - a
		var v2: Vector3 = c - b
		var area2: float = v1.cross(v2).length()
		if area2 < 1e-6:
			continue
		var r: float = (v1.length() * v2.length() * (v1 + v2).length()) / (2.0 * area2)
		if r < worst:
			worst = r
			worst_at = d
	var at: Vector3 = curve.sample_baked(worst_at)
	if worst < 18.0:
		push_error("Trail turns to R=%.1fm at %.0fm (%.0f, %.0f)" % [worst, worst_at, at.x, at.z])
	else:
		print("  plan: min radius %.1fm at %.0fm (%.0f, %.0f)" % [worst, worst_at, at.x, at.z])


## Steepest grade along the trail and steepest cross slope of the built ground beside it.
## Past ~31 degrees (normal.y 0.85) off-road carts start sliding, so the flat strip has to stay
## well under that everywhere except the mega-jump hill, which is driven downhill on purpose.
func _verify_trail_ground() -> void:
	var length: float = main_curve.get_baked_length()
	var worst_grade := 0.0
	var worst_grade_at := 0.0
	var worst_cross := 0.0
	var worst_cross_at := Vector3.ZERO
	var buried := 0
	var d := 0.0
	while d < length:
		var in_gap: bool = _in_gap_span(d) or _in_gap_span(d + 4.0)
		var on_hill: bool = d > _mega["lip_off"] - 2.0 and d < _mega["hill_end_off"]
		if not in_gap and not on_hill:
			var f: Dictionary = _frame_at_offset(main_curve, d)
			var p: Vector3 = f["pos"]
			var ahead: Dictionary = _frame_at_offset(main_curve, d + 4.0)
			var p2: Vector3 = ahead["pos"]
			var g0: float = _ground_at(p.x, p.z)
			var g1: float = _ground_at(p2.x, p2.z)
			var grade: float = absf(g1 - g0) / 4.0
			if grade > worst_grade:
				worst_grade = grade
				worst_grade_at = d
			var r: Vector3 = f["right"]
			var gl: float = _ground_at(p.x - r.x * 6.0, p.z - r.z * 6.0)
			var gr: float = _ground_at(p.x + r.x * 6.0, p.z + r.z * 6.0)
			var cross: float = absf(gr - gl) / 12.0
			if cross > worst_cross:
				worst_cross = cross
				worst_cross_at = p
			if absf(g0 - p.y) > 0.6:
				buried += 1
				if buried <= 5:
					push_error("Ground at %.0fm (%.0f, %.0f) is %.2fm off the trail" % [d, p.x, p.z, g0 - p.y])
		d += 2.0
	print("  trail: steepest grade %.1f%% at %.0fm, steepest cross slope %.1f%% at (%.0f, %.0f), %d samples off the ground" % [
		worst_grade * 100.0, worst_grade_at, worst_cross * 100.0, worst_cross_at.x, worst_cross_at.z, buried])
	if worst_grade > 0.30 or worst_cross > 0.30:
		push_error("Trail ground is too steep for off-road carts (grade %.0f%%, cross %.0f%%)" % [worst_grade * 100.0, worst_cross * 100.0])


## Flies a cart over each gap and the mega-jump at a range of take-off speeds, against the
## ground that was built (kicker included), and reports landing distance and impact.
func _verify_jumps() -> void:
	const G := 30.0       # PlayerCart.GRAVITY
	const VCAP := 48.0    # PlayerCart MAX_FALL_SPEED
	var jumps: Array = []
	for g in _gaps:
		jumps.append({"name": g["name"], "lip": g["lip_top"], "dir": g["dir"], "deg": GAP_KICKER_DEG,
				"min_land": GAP_LEN + 1.0, "speeds": [18.0, 22.0, 26.0, 32.0, 40.0, 50.0], "must": 22.0})
	jumps.append({"name": "MegaJump", "lip": _mega["lip_top"], "dir": _mega["dir"], "deg": MEGA_KICKER_DEG,
			"min_land": 6.0, "speeds": [26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 54.0], "must": 26.0})
	for j in jumps:
		var line := ""
		var th: float = deg_to_rad(j["deg"])
		var dir: Vector3 = j["dir"]
		for v in j["speeds"]:
			var pos: Vector3 = j["lip"] + Vector3(0, 0.45, 0)
			var vel: Vector3 = dir * (v * cos(th)) + Vector3(0, v * sin(th), 0)
			var t := 0.0
			var dt := 1.0 / 120.0
			var landed := false
			var x := 0.0
			var impact := 0.0
			var max_clear := 0.0
			while t < 8.0:
				vel.y = maxf(vel.y - G * dt, -VCAP)
				pos += vel * dt
				t += dt
				x = Vector2(pos.x - j["lip"].x, pos.z - j["lip"].z).length()
				var gy: float = _ground_at(pos.x, pos.z)
				if pos.y - 0.45 <= gy:
					var e := 0.6
					var gx1: float = _ground_at(pos.x + dir.x * e, pos.z + dir.z * e)
					var gx0: float = _ground_at(pos.x - dir.x * e, pos.z - dir.z * e)
					var slope: float = atan2(gx1 - gx0, 2.0 * e)
					var vh: float = Vector2(vel.x, vel.z).length()
					var ang: float = atan2(vel.y, vh)
					impact = vel.length() * sin(absf(ang - slope))
					landed = true
					break
				max_clear = maxf(max_clear, pos.y - 0.45 - gy)
			line += "  %d m/s -> %.0fm (impact %.0f, clear %.1fm)" % [int(v), x, impact, max_clear]
			if v >= j["must"] and (not landed or x < j["min_land"]):
				push_error("%s: a cart at %d m/s comes down %.1fm out, short of the landing (needs %.0fm)" % [j["name"], int(v), x, j["min_land"]])
		print("  %s:%s" % [j["name"], line])


func _in_gap_span(off: float) -> bool:
	for g in _gaps:
		if off > g["lip_off"] - 1.0 and off < g["land_off"] + 1.0:
			return true
	return false


# ======================================================================================
#  Trail samples and the river
# ======================================================================================

func _init_noise() -> void:
	_base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base_noise.seed = 81723
	_base_noise.frequency = 0.0045
	_base_noise.fractal_octaves = 4
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.seed = 1904
	_detail_noise.frequency = 0.03
	_detail_noise.fractal_octaves = 2
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridge_noise.seed = 44021
	_ridge_noise.frequency = 0.0036
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_noise.fractal_octaves = 5
	_ridge_noise.fractal_gain = 0.52
	_rock_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_rock_noise.seed = 5512
	_rock_noise.frequency = 0.06
	_rock_noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB


func _build_river_segments() -> void:
	_river_segs.clear()
	for strip in [RIVER_UPPER, RIVER_LOWER]:
		for i in range(strip.size() - 1):
			var a: Vector4 = strip[i]
			var b: Vector4 = strip[i + 1]
			_river_segs.append({"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "ya": a.y, "yb": b.y,
					"wa": a.w, "wb": b.w, "upper": strip == RIVER_UPPER})


## Nearest river element to (x, z): {d, y, hw}. `side` restricts to the upper river (north of the
## falls lip) or lower (south), so the two never carve into each other across the falls.
func _river_at(x: float, z: float) -> Dictionary:
	var upper_side: bool = z <= FALLS_LIP_Z + 0.01
	var best := {"d": 1e9, "y": 0.0, "hw": 1.0}
	var p := Vector2(x, z)
	for s in _river_segs:
		if s["upper"] != upper_side and absf(x) < 120.0 and absf(z - FALLS_LIP_Z) < 120.0:
			continue
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		if d < best["d"]:
			best = {"d": d, "y": lerpf(s["ya"], s["yb"], t), "hw": lerpf(s["wa"], s["wb"], t)}
	if not upper_side or absf(x) >= 120.0:
		var pd: float = p.distance_to(Vector2(POOL.x, POOL.z))
		if pd - POOL.w < best["d"] - best["hw"]:
			best = {"d": pd, "y": POOL.y, "hw": POOL.w}
	return best


func _build_trail_samples() -> void:
	var length: float = main_curve.get_baked_length()
	_ts_pos = PackedVector3Array()
	_ts_right = PackedVector3Array()
	_ts_off = PackedFloat32Array()
	_ts_river_side = PackedFloat32Array()
	_ts_river_dist = PackedFloat32Array()
	_ts_cells.clear()
	var d := 0.0
	while d < length:
		var f: Dictionary = _frame_at_offset(main_curve, d)
		var p: Vector3 = f["pos"]
		var r: Vector3 = f["right"]
		var rv: Dictionary = _river_at(p.x, p.z)
		var side := 0.0
		var rdist := 0.0
		if rv["d"] < RIVER_SIDE_REACH and not _on_ice(p.x, p.z):
			# Which side the river is on: probe both ways.
			var right_d: float = _river_at(p.x + r.x * 20.0, p.z + r.z * 20.0)["d"]
			var left_d: float = _river_at(p.x - r.x * 20.0, p.z - r.z * 20.0)["d"]
			side = 1.0 if right_d < left_d else -1.0
			rdist = rv["d"]
		var idx: int = _ts_pos.size()
		_ts_pos.append(p)
		_ts_right.append(r)
		_ts_off.append(d)
		_ts_river_side.append(side)
		_ts_river_dist.append(rdist)
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		var bucket: PackedInt32Array = _ts_cells.get(key, PackedInt32Array())
		bucket.append(idx)
		_ts_cells[key] = bucket
		d += 2.0
	print("  trail samples: %d" % _ts_pos.size())


func _on_ice(x: float, z: float) -> bool:
	return _ice_mask(x, z) > 0.5


## 1 on a frozen lake, feathered to 0 at the shore.
func _ice_mask(x: float, z: float) -> float:
	var m := 0.0
	for e in [[LAKE_CENTER, LAKE_RADIUS], [TARN_CENTER, TARN_RADIUS]]:
		var c: Vector2 = e[0]
		var rad: Vector2 = e[1]
		var q: Vector2 = (Vector2(x, z) - c) / rad
		var wobble: float = _detail_noise.get_noise_2d(x * 0.4, z * 0.4) * 0.06
		m = maxf(m, 1.0 - smoothstep(1.0 - ICE_FEATHER / rad.x * 0.5, 1.0 + wobble, q.length()))
	return m


# ======================================================================================
#  Terrain
# ======================================================================================

## The landscape before the trail and the gorge: a valley in the south, the plateau west of the
## river, the hillside rising east of it, mountains around the tarn, and a ring of peaks at the
## edge of the map.
func _base_height(x: float, z: float) -> float:
	var n: float = _base_noise.get_noise_2d(x, z)
	var ridge: float = clampf(_ridge_noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var valley: float = VALLEY_Y + n * 1.2 + _detail_noise.get_noise_2d(x, z) * 0.35

	# Which bank of the river: the plateau lies west of the river line, the hillside east.
	var river_x: float = _river_line_x(z)
	var west: float = smoothstep(10.0, -30.0, x - river_x)

	# West plateau, ending at the escarpment. The escarpment line wanders with noise so it is
	# not ruled straight across the map.
	var esc_z: float = ESCARPMENT_Z + _base_noise.get_noise_2d(x * 2.0, 400.0) * 18.0
	var plateau_on: float = 1.0 - smoothstep(esc_z - 6.0, esc_z + 34.0, z)
	var plateau: float = PLATEAU_Y + n * 4.0 + ridge * 10.0
	# Mountains behind the plateau.
	plateau += smoothstep(-110.0, -330.0, x) * (40.0 + ridge * 120.0)

	# East hillside: climbs north (the trail climbs with it) and east, away from the river.
	var east_rise: float = clampf((-z + 40.0) / 640.0, 0.0, 1.0)
	var hill: float = 14.0 + east_rise * 38.0 + maxf(0.0, x - river_x - 40.0) * 0.22 + n * 6.0 + ridge * 16.0
	hill += smoothstep(170.0, 420.0, x) * (50.0 + ridge * 110.0)
	var hill_on: float = 1.0 - smoothstep(-90.0, 30.0, z)

	var west_h: float = lerpf(valley, plateau, plateau_on)
	var east_h: float = lerpf(valley, hill, hill_on)
	var h: float = lerpf(east_h, west_h, west)

	# Valley hills to the east and south of the lake, so the valley has walls.
	var south_ring: float = smoothstep(380.0, 620.0, z) + smoothstep(260.0, 520.0, x) * smoothstep(-80.0, 40.0, z)
	h += clampf(south_ring, 0.0, 1.0) * (30.0 + ridge * 120.0)

	# Cirque around the tarn: mountains close in north of it.
	var north: float = smoothstep(-700.0, -900.0, z)
	h = lerpf(h, maxf(h, 60.0 + ridge * 170.0 + n * 20.0), north)

	# Close the horizon at the edge of the map.
	var ex: float = maxf(smoothstep(OUTER_X.x + 260.0, OUTER_X.x, x), smoothstep(OUTER_X.y - 260.0, OUTER_X.y, x))
	var ez: float = maxf(smoothstep(OUTER_Z.x + 300.0, OUTER_Z.x, z), smoothstep(OUTER_Z.y - 300.0, OUTER_Z.y, z))
	h += maxf(ex, ez) * (90.0 + ridge * 60.0)
	return h


## The river's x at a given z, for telling the banks apart. Past either end it carries on
## straight.
func _river_line_x(z: float) -> float:
	var all: Array = RIVER_UPPER + RIVER_LOWER
	if z <= all[0].z:
		return all[0].x
	for i in range(all.size() - 1):
		var a: Vector4 = all[i]
		var b: Vector4 = all[i + 1]
		if z >= a.z and z <= b.z:
			return lerpf(a.x, b.x, (z - a.z) / maxf(b.z - a.z, 0.001))
	return all[all.size() - 1].x


## Clamps the ground between the trail's fill and cut bounds: dead flat across the trail, a cut
## bank on the uphill side, a ledge falling gently toward the river on the river side, and an
## embankment wherever the trail runs above the natural ground.
##
## Every bound is measured from the point's foot on the trail polyline, never radially from a
## sample: on a 10% climb a radial bound from a sample 8m back would cut the trail ahead 0.8m into
## the ground. Past either end of a 2m segment, the excess runs along the trail and is charged
## at the cut slope, which is steeper than any grade, so the segment the point actually sits
## beside always sets the bound.
func _apply_trail(h: float, x: float, z: float) -> float:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var n: int = _ts_pos.size()
	# The lowest a river-side ledge may cut here: just above the water of the river at this spot.
	# Without it, the trail climbing past the plunge pool (at ~12m) planed the bank of the river
	# above the falls (water at 31.6m) down to its own height, leaving that river perched 20m over
	# a pit. Looked up lazily: most points never meet a ledge bound.
	var ledge_floor := NAN
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _ts_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var a: Vector3 = _ts_pos[i]
				var dx: float = x - a.x
				var dz: float = z - a.z
				if dx * dx + dz * dz > 92.0 * 92.0:
					continue
				var b: Vector3 = _ts_pos[(i + 1) % n]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = sx * sx + sz * sz
				if l2 < 1e-6:
					continue
				var t_raw: float = (dx * sx + dz * sz) / l2
				var t: float = clampf(t_raw, 0.0, 1.0)
				var excess: float = absf(t_raw - t) * sqrt(l2)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var lateral: float = sqrt(fx * fx + fz * fz)
				var foot_y: float = lerpf(a.y, b.y, t)
				var over: float = maxf(0.0, lateral - TRAIL_FLAT)
				# Soften the shoulder so there is no crease at the edge of the flat strip.
				var soft: float = over * over / (over + 4.0)
				# Which side of travel: +1 right.
				var sgn: float = signf(sx * dz - sz * dx)
				var side: float = _ts_river_side[i]
				if side != 0.0 and sgn == side:
					# River side: a ledge, but only as far as the river - past it the other bank's own
					# trail decides.
					if lateral < _ts_river_dist[i]:
						if is_nan(ledge_floor):
							ledge_floor = float(_river_at(x, z)["y"]) + 1.5
						upper = minf(upper, maxf(foot_y - soft * LEDGE_SLOPE + excess * CUT_SLOPE, ledge_floor))
				else:
					upper = minf(upper, foot_y + soft * CUT_SLOPE + excess * CUT_SLOPE)
				lower = maxf(lower, foot_y - soft * FILL_SLOPE - excess * FILL_SLOPE)
				touched = true
	if not touched:
		return h
	if lower > upper:
		return upper
	return clampf(h, lower, upper)


## The gorge: a river bed under the water and steep rock walls up to the rims.
func _gorge_height(x: float, z: float) -> float:
	var r: Dictionary = _river_at(x, z)
	var d: float = r["d"]
	var hw: float = r["hw"]
	var y: float = r["y"]
	if d < hw:
		var t: float = d / hw
		var depth: float = RIVER_DEPTH
		if z <= FALLS_LIP_Z + 0.01 and absf(x) < 40.0:
			depth *= lerpf(0.35, 1.0, smoothstep(0.0, FALLS_SILL_LEN, FALLS_LIP_Z - z))
		return y - depth * (1.0 - t * t) - lerpf(0.05, 0.6, smoothstep(0.0, FALLS_SILL_LEN, FALLS_LIP_Z - z) if z <= FALLS_LIP_Z + 0.01 else 1.0)
	# Ragged walls: the rise rate varies along the gorge, and blocky cellular noise breaks the
	# face into buttresses and ledges.
	var wall: float = GORGE_WALL * (0.8 + 0.4 * (_detail_noise.get_noise_2d(x * 0.3, z * 0.3) * 0.5 + 0.5))
	var blocks: float = _rock_noise.get_noise_2d(x, z) * 4.0
	return y - 0.6 + (d - hw) * wall + blocks


## A gully slot across the trail at each gap: vertical-ish walls, floor below the river so the
## river floods it, and the slot climbing into the hillside on the uphill side.
func _gully_height(h: float, x: float, z: float) -> float:
	for g in _gaps:
		var c: Vector3 = g["center"]
		var along: Vector3 = g["dir"]          # trail direction
		var axis: Vector3 = g["axis"]          # across the trail, pointing away from the river
		var dx: float = x - c.x
		var dz: float = z - c.z
		var u: float = dx * axis.x + dz * axis.z     # + uphill, - toward the river
		var v: float = absf(dx * along.x + dz * along.z)
		if u < -g["river_reach"] or v >= GAP_LEN * 0.5:
			continue
		var floor_y: float = g["water_y"] - 2.6
		# Inland the slot floor climbs out of the water into a stream ravine.
		var inland: float = maxf(0.0, u - g["inland_reach"])
		floor_y += inland * inland * 0.035 + inland * 0.5
		# The slot is exactly GAP_LEN wide at the rim, so the kicker lip and the landing edge are
		# where the jump says they are, and narrows as it goes down. Wall steepness wanders a
		# little so the faces are not ruled planes.
		var steep: float = 9.0 + _detail_noise.get_noise_2d(u * 1.3, float(g["seed"]) + v) * 3.0
		h = minf(h, maxf(floor_y, h - (GAP_LEN * 0.5 - v) * steep))
	return h


func _grid_axis(fine: Vector2, outer: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	# Coarse cells growing outward from the fine band, on both sides.
	var left := PackedFloat32Array()
	var step: float = FINE_STEP
	var x: float = fine.x
	while x > outer.x:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x -= step
		left.append(maxf(x, outer.x))
	left.reverse()
	out.append_array(left)
	var n: int = int(round((fine.y - fine.x) / FINE_STEP))
	for i in range(n + 1):
		out.append(fine.x + float(i) * FINE_STEP)
	step = FINE_STEP
	x = fine.y
	while x < outer.y:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x += step
		out.append(minf(x, outer.y))
	return out


func _build_heights() -> void:
	_grid_x = _grid_axis(FINE_X, OUTER_X)
	_grid_z = _grid_axis(FINE_Z, OUTER_Z)
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	print("  terrain grid %d x %d = %d vertices" % [nx, nz, nx * nz])
	_heights = PackedFloat32Array()
	_heights.resize(nx * nz)
	_carved = PackedByteArray()
	_carved.resize(nx * nz)
	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var h: float = _base_height(x, z)
			h = _apply_trail(h, x, z)
			var uncut: float = h
			h = minf(h, _gorge_height(x, z))
			h = _gully_height(h, x, z)
			_carved[iz * nx + ix] = 1 if h < uncut - 0.3 else 0
			var ice: float = _ice_mask(x, z)
			if ice > 0.0:
				var ice_y: float = LAKE_ICE_Y if z > 0.0 else TARN_ICE_Y
				var ripple: float = _detail_noise.get_noise_2d(x * 2.0, z * 2.0) * 0.05
				# The ice sheet is flat; the shore rises out of it, never dips under it.
				h = lerpf(h, ice_y + ripple, ice) if h > ice_y else lerpf(h, ice_y + ripple, minf(ice * 2.0, 1.0))
				# Open water where the river runs out under the lake ice.
				var r: Dictionary = _river_at(x, z)
				if r["d"] < r["hw"] and ice < 0.98:
					h = minf(h, _gorge_height(x, z))
			_heights[iz * nx + ix] = h


## Ground height at any (x, z) from the built heightfield, bilinear like the triangles (close
## enough for placing props and flying test carts).
func _ground_at(x: float, z: float) -> float:
	var ix: int = _bsearch(_grid_x, x)
	var iz: int = _bsearch(_grid_z, z)
	var nx: int = _grid_x.size()
	var x0: float = _grid_x[ix]
	var x1: float = _grid_x[ix + 1]
	var z0: float = _grid_z[iz]
	var z1: float = _grid_z[iz + 1]
	var tx: float = clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	var tz: float = clampf((z - z0) / (z1 - z0), 0.0, 1.0)
	var h00: float = _heights[iz * nx + ix]
	var h10: float = _heights[iz * nx + ix + 1]
	var h01: float = _heights[(iz + 1) * nx + ix]
	var h11: float = _heights[(iz + 1) * nx + ix + 1]
	# Same diagonal split as the mesh (i, i+1, i+nx | i+1, i+nx+1, i+nx).
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func _bsearch(arr: PackedFloat32Array, v: float) -> int:
	var lo := 0
	var hi: int = arr.size() - 2
	if v <= arr[0]:
		return 0
	if v >= arr[arr.size() - 1]:
		return hi
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if arr[mid] <= v:
			lo = mid
		else:
			hi = mid - 1
	return lo


## Builds the terrain mesh with the shader masks in the vertex colour, and its collision.
func _build_terrain(parent: Node, mat: Material) -> void:
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	uvs.resize(nx * nz)
	for iz in range(nz):
		for ix in range(nx):
			var i: int = iz * nx + ix
			var x: float = _grid_x[ix]
			var z: float = _grid_z[iz]
			var h: float = _heights[i]
			verts[i] = Vector3(x, h, z)
			uvs[i] = Vector2(x, z)
			var ixl: int = maxi(ix - 1, 0)
			var ixr: int = mini(ix + 1, nx - 1)
			var izd: int = maxi(iz - 1, 0)
			var izu: int = mini(iz + 1, nz - 1)
			var dhdx: float = (_heights[iz * nx + ixr] - _heights[iz * nx + ixl]) / maxf(_grid_x[ixr] - _grid_x[ixl], 0.01)
			var dhdz: float = (_heights[izu * nx + ix] - _heights[izd * nx + ix]) / maxf(_grid_z[izu] - _grid_z[izd], 0.01)
			normals[i] = Vector3(-dhdx, 1.0, -dhdz).normalized()
			colors[i] = _terrain_masks(x, z, h, _carved[i] == 1)
	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var w := 0
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var i: int = iz * nx + ix
			indices[w] = i
			indices[w + 1] = i + 1
			indices[w + 2] = i + nx
			indices[w + 3] = i + 1
			indices[w + 4] = i + nx + 1
			indices[w + 5] = i + nx
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)

	# Collision over the whole map. This is an off-road stage: carts can and do drive up any slope
	# they can climb, and a collision sheet that stopped short of the visible ground (it once
	# ended 90m east of the finish line, halfway up the valley wall) drops them through it.
	var cfaces := PackedVector3Array()
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var i: int = iz * nx + ix
			cfaces.append(verts[i])
			cfaces.append(verts[i + 1])
			cfaces.append(verts[i + nx])
			cfaces.append(verts[i + 1])
			cfaces.append(verts[i + nx + 1])
			cfaces.append(verts[i + nx])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(cfaces)
	shape.backface_collision = true

	# Named so PlayerCart's surface checks find neither a road nor the old unified terrain: every
	# metre of this ground is off-road.
	var body := StaticBody3D.new()
	body.name = "GorgeGround"
	parent.add_child(body)
	var inst := MeshInstance3D.new()
	inst.name = "GorgeGroundMesh"
	inst.mesh = _save_baked_resource(mesh, "ground_visual")
	body.add_child(inst)
	var col := CollisionShape3D.new()
	col.name = "GorgeGroundShape"
	col.shape = _save_baked_resource(shape, "ground_collision_shape")
	body.add_child(col)


## Vertex-colour masks for frostfall_ground.gdshader: ice, racing line, spray zone, and alpha:
## lateral across the racing line on it, carved-rock flag off it.
func _terrain_masks(x: float, z: float, h: float, carved: bool) -> Color:
	var ice_y: float = LAKE_ICE_Y if z > 0.0 else TARN_ICE_Y
	var ice: float = _ice_mask(x, z) * (1.0 - smoothstep(0.3, 1.5, h - ice_y))
	var line := 0.0
	var lat := 0.0
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e9
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var bucket: PackedInt32Array = _ts_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var p: Vector3 = _ts_pos[i]
				var dx: float = x - p.x
				var dz: float = z - p.z
				var d2: float = dx * dx + dz * dz
				if d2 < best and absf(h - p.y) < 4.0:
					best = d2
					lat = dx * _ts_right[i].x + dz * _ts_right[i].z
	if best < 1e8:
		var d: float = sqrt(best)
		line = 1.0 - smoothstep(TRAIL_PAINT - 3.0, TRAIL_PAINT + 2.0, d)
	# Spray: close above open water. Ice-glazed rock reads as a dark band along the waterline.
	var spray := 0.0
	var r: Dictionary = _river_at(x, z)
	if r["d"] < r["hw"] + 26.0 and ice < 0.5:
		var above: float = h - r["y"]
		# A narrow band at the waterline only. Reaching tens of metres out, it glazed whole low
		# benches (the shelf beside the plunge pool) into one glossy blue expanse.
		spray = (1.0 - smoothstep(0.3, 3.0, above)) * (1.0 - smoothstep(r["hw"] + 2.0, r["hw"] + 8.0, r["d"]))
		# The falls soak everything around the pool.
		var pd: float = Vector2(x - POOL.x, z - POOL.z).length()
		# Only low down, near the waterline: soaked all the way up, a whole cliff face turns into
		# one glossy blue sheet.
		spray = maxf(spray, (1.0 - smoothstep(POOL.w, POOL.w + 14.0, pd)) * (1.0 - smoothstep(2.0, 10.0, above)) * 0.6)
		# Above water the glaze tops out below 0.9: the shader reads 0.92+ as submerged river bed
		# and paints it flat dark stone, which on a dry cliff is a featureless blue sheet.
		spray = minf(spray, 0.85)
		# The river bed under the water: wet dark stone, never snow showing through the surface.
		if above < 0.2:
			spray = 1.0
	# Alpha carries the lateral across the racing line; off the line it is free, and marks the
	# faces the gorge and gully carves cut (0 there), which the shader keeps as bare rock.
	var alpha: float = clampf(lat / 24.0 + 0.5, 0.0, 1.0) if line > 0.0 else (0.0 if carved else 1.0)
	return Color(ice, line, clampf(spray, 0.0, 1.0), alpha)


# ======================================================================================
#  Water
# ======================================================================================

## The RiverWater node PlayerCart reads, from the same strips that carve the gorge.
func _build_river_water_node(parent: Node) -> void:
	var node := Node3D.new()
	node.name = "RiverWater"
	node.set_script(RiverWaterScript)
	var pts := PackedVector3Array()
	var hws := PackedFloat32Array()
	var starts := PackedInt32Array()
	var bounds := Rect2(Vector2(RIVER_UPPER[0].x, RIVER_UPPER[0].z), Vector2.ZERO)
	for strip in [RIVER_UPPER, RIVER_LOWER]:
		starts.append(pts.size())
		for p in strip:
			pts.append(Vector3(p.x, p.y, p.z))
			hws.append(p.w + 1.5)
			bounds = bounds.expand(Vector2(p.x - p.w - 4.0, p.z - p.w - 4.0))
			bounds = bounds.expand(Vector2(p.x + p.w + 4.0, p.z + p.w + 4.0))
	# Each gully is a flooded inlet of the river.
	for g in _gaps:
		starts.append(pts.size())
		var mouth: Vector3 = g["mouth"]
		var head: Vector3 = g["head"]
		pts.append(Vector3(mouth.x, g["water_y"], mouth.z))
		pts.append(Vector3(head.x, g["water_y"], head.z))
		hws.append(GAP_LEN * 0.5 + 2.0)
		hws.append(GAP_LEN * 0.5 + 2.0)
		for q in [mouth, head]:
			bounds = bounds.expand(Vector2(q.x - 14.0, q.z - 14.0))
			bounds = bounds.expand(Vector2(q.x + 14.0, q.z + 14.0))
	var pools: Array[Vector4] = [POOL]
	bounds = bounds.expand(Vector2(POOL.x - POOL.w, POOL.z - POOL.w))
	bounds = bounds.expand(Vector2(POOL.x + POOL.w, POOL.z + POOL.w))
	node.set("strip_points", pts)
	node.set("strip_half_widths", hws)
	node.set("strip_starts", starts)
	node.set("pools", pools)
	node.set("water_bounds", bounds)
	parent.add_child(node)


func _water_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://river_water.gdshader")
	var n := FastNoiseLite.new()
	n.seed = 3301
	n.frequency = 0.035
	n.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	nt.noise = n
	nt.width = 256
	nt.height = 256
	mat.set_shader_parameter("noise_tex", nt)
	var f := FastNoiseLite.new()
	f.seed = 919
	f.frequency = 0.05
	f.fractal_octaves = 4
	f.noise_type = FastNoiseLite.TYPE_CELLULAR
	f.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	var ft := NoiseTexture2D.new()
	ft.seamless = true
	ft.noise = f
	ft.width = 256
	ft.height = 256
	mat.set_shader_parameter("foam_noise", ft)
	return mat


## River surface ribbons. Turbulence (vertex red) follows how steeply the water is falling, so
## the reaches between pools run white and the falls lip boils.
func _build_river_meshes(parent: Node, mat: Material) -> void:
	var root := Node3D.new()
	root.name = "RiverSurface"
	parent.add_child(root)
	var strips := [["UpperRiver", RIVER_UPPER, true], ["LowerRiver", RIVER_LOWER, false]]
	for s in strips:
		var pts: Array = s[1]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Resample the strip every 2m.
		var samples: Array = []
		var along := 0.0
		for i in range(pts.size() - 1):
			var a: Vector4 = pts[i]
			var b: Vector4 = pts[i + 1]
			var seg_len: float = Vector2(b.x - a.x, b.z - a.z).length()
			var steps: int = maxi(int(seg_len / 2.0), 1)
			for k in range(steps):
				var t: float = float(k) / float(steps)
				var drop: float = (a.y - b.y) / maxf(seg_len, 0.01)
				samples.append([Vector3(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t), lerpf(a.z, b.z, t)),
						lerpf(a.w, b.w, t) + 2.0, along + seg_len * t, drop])
			along += seg_len
		var last: Vector4 = pts[pts.size() - 1]
		samples.append([Vector3(last.x, last.y, last.z), last.w + 2.0, along, 0.0])
		var across := 8
		var n: int = samples.size()
		for i in range(n):
			var p: Vector3 = samples[i][0]
			var prv: Vector3 = samples[maxi(i - 1, 0)][0]
			var nxt: Vector3 = samples[mini(i + 1, n - 1)][0]
			var fwd := Vector3(nxt.x - prv.x, 0.0, nxt.z - prv.z).normalized()
			var right := Vector3(-fwd.z, 0.0, fwd.x)
			var hw: float = samples[i][1]
			var drop: float = samples[i][3]
			var turb: float = clampf(drop * 18.0, 0.0, 0.85)
			# The last 25m above the falls lip accelerate into white water.
			if s[2]:
				turb = maxf(turb, smoothstep(along - 22.0, along, samples[i][2]) * 0.6)
			# Below the falls, the pool's outflow is churned for the first stretch.
			if not s[2]:
				turb = maxf(turb, (1.0 - smoothstep(0.0, 40.0, samples[i][2])) * 0.7)
			var current: float = clampf(0.3 + drop * 25.0, 0.3, 1.4)
			# The lower river starts under the plunge pool; fade its first metres so its square
			# end never shows through the pool.
			var fade: float = 0.0
			if not s[2]:
				fade = 1.0 - smoothstep(0.0, 14.0, samples[i][2])
			for k in range(across + 1):
				var u: float = float(k) / float(across)
				var q: Vector3 = p + right * lerpf(-hw, hw, u)
				st.set_color(Color(turb, current, fade, 1.0))
				st.set_uv(Vector2(u, samples[i][2]))
				st.set_normal(Vector3.UP)
				st.add_vertex(q)
		for i in range(n - 1):
			for k in range(across):
				var a0: int = i * (across + 1) + k
				var b0: int = a0 + across + 1
				# Front face up: (c - a) x (b - a) must point +Y (CLAUDE.md winding note).
				st.add_index(a0)
				st.add_index(b0)
				st.add_index(a0 + 1)
				st.add_index(a0 + 1)
				st.add_index(b0)
				st.add_index(b0 + 1)
		var mesh: ArrayMesh = st.commit()
		var mi := MeshInstance3D.new()
		mi.name = s[0]
		mi.mesh = _save_baked_resource(mesh, "water_" + str(s[0]).to_lower())
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

	# The plunge pool: a disc, foaming hardest under the falls.
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var segs := 40
	var impact := Vector2(0.0, FALLS_LIP_Z + 8.0)
	for ri in range(rings + 1):
		var rr: float = (POOL.w + 1.5) * float(ri) / float(rings)
		for si in range(segs + 1):
			var a: float = TAU * float(si) / float(segs)
			var q := Vector3(POOL.x + cos(a) * rr, POOL.y, POOL.z + sin(a) * rr)
			var di: float = Vector2(q.x, q.z).distance_to(impact)
			var turb: float = 1.0 - smoothstep(4.0, 24.0, di)
			# The rim melts into the river ribbon running out of the pool.
			var rim: float = smoothstep(POOL.w - 7.0, POOL.w + 1.5, rr)
			st2.set_color(Color(clampf(turb, 0.12, 1.0), 0.6, rim, 1.0))
			# Pool UVs: around the rim, and outward from the falls for the flow direction.
			st2.set_uv(Vector2(float(si) / float(segs), di * 1.0))
			st2.set_normal(Vector3.UP)
			st2.add_vertex(q)
	for ri in range(rings):
		for si in range(segs):
			var a0: int = ri * (segs + 1) + si
			var b0: int = a0 + segs + 1
			st2.add_index(a0)
			st2.add_index(b0)
			st2.add_index(a0 + 1)
			st2.add_index(a0 + 1)
			st2.add_index(b0)
			st2.add_index(b0 + 1)
	var pool_mi := MeshInstance3D.new()
	pool_mi.name = "PlungePool"
	pool_mi.mesh = st2.commit()
	pool_mi.material_override = mat
	pool_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A hair above the river ribbon where they overlap.
	pool_mi.position.y = 0.02
	root.add_child(pool_mi)

	# Gully inlets: calm flat water in each slot, at river level. Each starts well inside the
	# river and fades in over its first metres there (vertex blue = edge fade), so the river and
	# the inlet melt into each other instead of meeting along a line. Built with vertex colours:
	# a mesh without them reads as COLOR = 1 in the shader, which is full white-water foam.
	for g in _gaps:
		var gaxis: Vector3 = g["axis"]
		var mouth: Vector3 = g["center"]
		for k in range(200):
			var q: Vector3 = g["center"] - gaxis * float(k)
			var rq: Dictionary = _river_at(q.x, q.z)
			if rq["d"] < maxf(rq["hw"] - 6.0, 1.0):
				mouth = q
				break
		var head: Vector3 = g["head"] + gaxis * 8.0
		var length_g: float = Vector2(head.x - mouth.x, head.z - mouth.z).length()
		var side := Vector3(-gaxis.z, 0.0, gaxis.x) * (GAP_LEN * 0.5 + 3.0)
		# A few centimetres under the river surface, so where they overlap the river draws on top.
		var y: float = g["water_y"] - 0.04
		var st3 := SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rows := 12
		for ri in range(rows + 1):
			# Rows bunched toward the mouth, where the fade happens.
			var f: float = pow(float(ri) / float(rows), 1.6)
			var along: float = f * length_g
			var c: Vector3 = mouth + gaxis * along
			var fade: float = 1.0 - smoothstep(0.0, 8.0, along)
			for k in range(2):
				var q2: Vector3 = c + side * (-1.0 if k == 0 else 1.0)
				st3.set_color(Color(0.12, 0.3, fade, 1.0))
				st3.set_uv(Vector2(float(k), along))
				st3.set_normal(Vector3.UP)
				st3.add_vertex(Vector3(q2.x, y, q2.z))
		for ri in range(rows):
			var p00: int = ri * 2
			var p01: int = p00 + 1
			var p10: int = p00 + 2
			var p11: int = p00 + 3
			# Front face up: (c - a) x (b - a) must point +Y. With a = p00, b = p10, c = p01 that is
			# side x axis, so the order flips when that cross product points down.
			if side.cross(gaxis).y > 0.0:
				st3.add_index(p00)
				st3.add_index(p10)
				st3.add_index(p01)
				st3.add_index(p01)
				st3.add_index(p10)
				st3.add_index(p11)
			else:
				st3.add_index(p00)
				st3.add_index(p01)
				st3.add_index(p10)
				st3.add_index(p01)
				st3.add_index(p11)
				st3.add_index(p10)
		var pm := MeshInstance3D.new()
		pm.name = "GullyWater_" + str(g["name"])
		pm.mesh = st3.commit()
		pm.material_override = mat
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pm)


# ======================================================================================
#  The falls
# ======================================================================================

func _build_waterfall(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "Waterfall"
	parent.add_child(root)

	var streak := FastNoiseLite.new()
	streak.seed = 4417
	streak.frequency = 0.08
	streak.fractal_octaves = 3
	var streak_tex := NoiseTexture2D.new()
	streak_tex.seamless = true
	streak_tex.noise = streak
	streak_tex.width = 256
	streak_tex.height = 256

	var lip_y: float = RIVER_UPPER[RIVER_UPPER.size() - 1].y
	var drop: float = lip_y - POOL.y
	# The water leaves the lip at ~4 m/s and falls freely (real gravity: this is scenery).
	var v0 := 4.2
	var t_end: float = sqrt(2.0 * drop / 9.8)
	for layer in [["Curtain", 0.0, 1.0, 0.0], ["Veil", 0.9, 1.18, 1.0]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cols := 20
		# Row profile as (z, y, v): the main curtain first runs along the river surface for the
		# last metres before the brink and rolls over it, so the falls visibly pour out of the
		# river instead of starting in mid-air. Then the free-fall parabola down to the pool.
		var profile: Array = []
		if layer[3] == 0.0:
			for b in [[-2.4, 0.03], [-1.4, 0.03], [-0.6, 0.0], [-0.15, -0.12]]:
				profile.append(Vector3(FALLS_LIP_Z + b[0], lip_y + b[1], 0.0))
		var rows := 28
		for ri in range(rows + 1):
			var tt: float = float(ri) / float(rows)
			var t: float = tt * t_end
			# The roll over the brink: the first fraction of a second starts below the surface
			# line and curves down, rather than shooting out level.
			profile.append(Vector3(FALLS_LIP_Z + v0 * t + layer[1], lip_y - 0.25 - 4.9 * t * t - 0.4 * sin(minf(tt * 8.0, 1.0) * PI * 0.5) * (1.0 - tt), maxf(tt, 0.004)))
		for ri in range(profile.size()):
			var pr: Vector3 = profile[ri]
			var tt: float = pr.z
			var zz: float = pr.x
			var yy: float = pr.y
			# The curtain spreads a little as it falls.
			var spread: float = lerpf(1.0, layer[2], tt) * (1.0 + tt * 0.12)
			for ci in range(cols + 1):
				var u: float = float(ci) / float(cols)
				var xx: float = lerpf(-FALLS_HALF_W, FALLS_HALF_W, u) * spread
				# A slight bulge in the middle where the river runs deepest over the lip.
				var bulge: float = sin(u * PI) * 0.8 * tt
				st.set_uv(Vector2(u, tt))
				st.set_normal(Vector3(0, 0.3, 1).normalized())
				st.add_vertex(Vector3(xx, yy, zz + bulge))
		for ri in range(profile.size() - 1):
			for ci in range(cols):
				var a0: int = ri * (cols + 1) + ci
				var b0: int = a0 + cols + 1
				st.add_index(a0)
				st.add_index(a0 + 1)
				st.add_index(b0)
				st.add_index(a0 + 1)
				st.add_index(b0 + 1)
				st.add_index(b0)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://waterfall.gdshader")
		mat.set_shader_parameter("streak_noise", streak_tex)
		mat.set_shader_parameter("veil", layer[3])
		mat.set_shader_parameter("opacity", 0.95 if layer[3] == 0.0 else 0.55)
		mat.render_priority = 1 if layer[3] > 0.0 else 0
		var mi := MeshInstance3D.new()
		mi.name = "Falls" + str(layer[0])
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

	var impact := Vector3(0.0, POOL.y + 0.2, FALLS_LIP_Z + v0 * t_end + 0.5)
	root.add_child(_mist_particles(impact))
	root.add_child(_pool_fog_particles(Vector3(POOL.x, POOL.y + 1.6, POOL.z + 4.0)))
	root.add_child(_spray_particles(impact))
	root.add_child(_lip_spray_particles(Vector3(0.0, lip_y + 0.2, FALLS_LIP_Z + 0.4)))
	root.add_child(_rainbow(impact + Vector3(0.0, 5.0, 10.0)))
	root.add_child(_falls_icicles(lip_y))

	# The roar. Real falls are broadband noise with most of the energy low down, so the stream
	# is generated rather than shipped as a recording.
	var roar: AudioStream = _roar_stream()
	for spot in [[impact + Vector3(0, 2, 6), 0.0, 34.0, 320.0], [Vector3(0, lip_y + 1.0, FALLS_LIP_Z - 6.0), -9.0, 16.0, 140.0]]:
		var ap := AudioStreamPlayer3D.new()
		ap.name = "FallsRoar"
		ap.stream = roar
		ap.position = spot[0]
		ap.volume_db = spot[1]
		ap.unit_size = spot[2]
		ap.max_distance = spot[3]
		ap.autoplay = true
		ap.bus = &"SFX"
		ap.attenuation_filter_cutoff_hz = 6000.0
		root.add_child(ap)
	# Quieter rapids further down the gorge, with the same noise pitched up into a hiss.
	for z in [-210.0, -100.0, 20.0]:
		var ap2 := AudioStreamPlayer3D.new()
		ap2.name = "Rapids"
		ap2.stream = roar
		ap2.pitch_scale = 1.6
		ap2.position = Vector3(_river_line_x(z), _river_at(_river_line_x(z), z)["y"] + 1.0, z)
		ap2.volume_db = -10.0
		ap2.unit_size = 10.0
		ap2.max_distance = 110.0
		ap2.autoplay = true
		ap2.bus = &"SFX"
		root.add_child(ap2)


func _soft_particle_material(color: Color, tex_size: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.5
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = tex_size
	tex.height = tex_size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	m.albedo_texture = tex
	m.albedo_color = color
	return m


## A soft, irregular cloud sprite for the mist: noise shaped by a radial falloff, so every puff
## is a ragged wisp rather than a perfect disc. Generated once and saved under res://generated/.
var _mist_tex: Texture2D

func _mist_texture() -> Texture2D:
	if _mist_tex:
		return _mist_tex
	const SIZE := 128
	var n := FastNoiseLite.new()
	n.seed = 6604
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.035
	n.fractal_octaves = 4
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var d: float = Vector2(x - SIZE * 0.5, y - SIZE * 0.5).length() / (SIZE * 0.5)
			var cloud: float = n.get_noise_2d(x, y) * 0.5 + 0.5
			var a: float = clampf((1.0 - smoothstep(0.25, 1.0, d)) * smoothstep(0.25, 0.75, cloud + (1.0 - d) * 0.35), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_mist_tex = _save_baked_resource(ImageTexture.create_from_image(img), "mist_puff")
	return _mist_tex


func _mist_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Soft where a puff cuts into rock or water, and thinning out when the camera is inside it.
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 3.0
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.0
	m.distance_fade_max_distance = 7.0
	m.albedo_texture = _mist_texture()
	m.albedo_color = Color(0.94, 0.97, 1.0, 1.0)
	return m


## Spray mist from where the falls land: ragged puffs that billow up, spin slowly, grow and
## drift downstream with the air the falls drag along, densest at the impact line.
func _mist_particles(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "FallsMist"
	p.position = at
	p.amount = 260
	p.lifetime = 6.0
	p.preprocess = 8.0
	p.randomness = 0.7
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-45, -8, -30), Vector3(90, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(FALLS_HALF_W * 1.05, 1.2, 2.0)
	pm.direction = Vector3(0, 1, 0.9)
	pm.spread = 50.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.5
	# Rising warm-ish spray, carried downstream.
	pm.gravity = Vector3(0, 0.25, 0.55)
	pm.damping_min = 0.6
	pm.damping_max = 1.2
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -14.0
	pm.angular_velocity_max = 14.0
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(0.4, 0.8))
	sc.add_point(Vector2(1, 1.25))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var cr := Gradient.new()
	cr.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	cr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.42), Color(0.95, 0.97, 1.0, 0.22), Color(0.92, 0.95, 1, 0)])
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(7.5, 7.5)
	q.material = _mist_material()
	p.draw_pass_1 = q
	return p


## A low bank of fog lying on the plunge pool and rolling a little way down the river.
func _pool_fog_particles(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "PoolFog"
	p.position = at
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 10.0
	p.randomness = 0.5
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-40, -4, -30), Vector3(80, 20, 90))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(POOL.w * 0.7, 0.4, POOL.w * 0.6)
	pm.direction = Vector3(0, 0.1, 1)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.05, 0.25)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -5.0
	pm.angular_velocity_max = 5.0
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var cr := Gradient.new()
	cr.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	cr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.24), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(11.0, 11.0)
	q.material = _mist_material()
	p.draw_pass_1 = q
	return p


## Droplets thrown out of the impact zone.
func _spray_particles(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "FallsSpray"
	p.position = at
	p.amount = 260
	p.lifetime = 1.6
	p.preprocess = 2.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-30, -4, -20), Vector3(60, 24, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(FALLS_HALF_W * 0.9, 0.3, 1.5)
	pm.direction = Vector3(0, 1, 0.4)
	pm.spread = 55.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var cr := Gradient.new()
	cr.colors = PackedColorArray([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = _soft_particle_material(Color(0.95, 0.98, 1.0, 1.0), 32)
	p.draw_pass_1 = q
	return p


## A thin smoke of spray where the river pours over the lip.
func _lip_spray_particles(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "LipSpray"
	p.position = at
	p.amount = 40
	p.lifetime = 2.5
	p.preprocess = 3.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-20, -30, -10), Vector3(40, 40, 30))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(FALLS_HALF_W, 0.2, 0.6)
	pm.direction = Vector3(0, -0.4, 1)
	pm.spread = 25.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var cr := Gradient.new()
	cr.colors = PackedColorArray([Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	q.material = _soft_particle_material(Color(0.95, 0.98, 1.0, 1.0), 32)
	p.draw_pass_1 = q
	return p


## A faint rainbow standing in the mist, facing down the gorge toward the climb.
func _rainbow(at: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 36
	var r_in := 13.0
	var r_out := 16.0
	for i in range(segs + 1):
		var a: float = lerpf(0.12, PI - 0.12, float(i) / float(segs))
		for k in range(2):
			var r: float = r_in if k == 0 else r_out
			st.set_uv(Vector2(float(i) / float(segs), float(k)))
			st.add_vertex(Vector3(cos(a) * r, sin(a) * r - 6.0, 0.0))
	for i in range(segs):
		var a0: int = i * 2
		st.add_index(a0)
		st.add_index(a0 + 2)
		st.add_index(a0 + 1)
		st.add_index(a0 + 1)
		st.add_index(a0 + 2)
		st.add_index(a0 + 3)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float strength = 0.08;
void fragment() {
	// Red on the outside of the bow, violet inside; fading out toward the feet of the arc.
	float h = UV.y;
	vec3 c = clamp(abs(fract(vec3(h * 0.78) + vec3(0.0, 0.666, 0.333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	float edge = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.65, UV.y);
	float feet = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	ALBEDO = c * strength * edge * feet;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var mi := MeshInstance3D.new()
	mi.name = "MistRainbow"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Frozen columns either side of the falls, where the spray freezes on the rock.
##
## Every column is fitted to the built cliff: its top and tip are each placed just in front of
## where the face actually is at that height (_falls_face_z), so the ice lies on the rock instead
## of hanging on a straight line in front of a face that is a few metres further back. The ones
## nearest the falls are long and thick, running most of the way to the pool.
func _falls_icicles(lip_y: float) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8812
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed := 0
	for side in [-1.0, 1.0]:
		for i in range(30):
			var off: float = rng.randf() * 9.5
			var x: float = side * (FALLS_HALF_W + 0.6 + off)
			var near_falls: float = 1.0 - off / 9.5
			var top: float = lip_y + rng.randf_range(-1.2, 0.8)
			var length: float = lerpf(rng.randf_range(3.0, 8.0), rng.randf_range(10.0, 20.0), near_falls * near_falls)
			length = minf(length, top - POOL.y - 1.0)
			var r: float = rng.randf_range(0.25, 0.5) + near_falls * 0.3 + length * 0.02
			var tip_y: float = top - length
			var z_top: float = _falls_face_z(x, top)
			var z_tip: float = _falls_face_z(x, tip_y)
			if is_nan(z_top) or is_nan(z_tip):
				continue
			# Just proud of the rock, by the column's own radius at each end.
			var top_c := Vector3(x, top, z_top + r * 0.7)
			var tip_c := Vector3(x + rng.randf_range(-0.2, 0.2), tip_y, z_tip + 0.25)
			var sides := 7
			for k in range(sides):
				var a0: float = TAU * float(k) / float(sides)
				var a1: float = TAU * float(k + 1) / float(sides)
				var p0: Vector3 = top_c + Vector3(cos(a0) * r, 0.0, sin(a0) * r)
				var p1: Vector3 = top_c + Vector3(cos(a1) * r, 0.0, sin(a1) * r)
				# A frozen bulge at the top, where the column grows out of the rock.
				var cap: Vector3 = top_c + Vector3(0.0, r * 0.9, -r * 0.4)
				for tri in [[p0, tip_c, p1], [p0, p1, cap]]:
					var faces: Array = []
					var mid: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
					var axis_pt := Vector3(x, mid.y, lerpf(top_c.z, tip_c.z, clampf((top - mid.y) / maxf(length, 0.1), 0.0, 1.0)))
					_tri_out(faces, tri[0], tri[1], tri[2], mid - axis_pt)
					var nrm: Vector3 = (faces[2] - faces[0]).cross(faces[1] - faces[0]).normalized()
					for v in faces:
						st.set_normal(nrm)
						st.add_vertex(v)
			placed += 1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://glacier_ice.gdshader")
	mat.set_shader_parameter("vein_density", 0.05)
	mat.set_shader_parameter("vein_glow", 0.05)
	mat.set_shader_parameter("frost_line", 200.0)
	mat.set_shader_parameter("ice_color", Color(0.80, 0.92, 0.98))
	var mi := MeshInstance3D.new()
	mi.name = "FallsIcicles"
	mi.mesh = st.commit()
	mi.material_override = mat
	print("  falls icicles: %d on the cliff" % placed)
	return mi


## Where the cliff face beside the falls is at height `y`: scanning south across the lip, the
## first z at which the built ground drops below `y`. NAN if the ground never rises that high.
func _falls_face_z(x: float, y: float) -> float:
	var z: float = FALLS_LIP_Z - 8.0
	if _ground_at(x, z) < y:
		return NAN
	while z < FALLS_LIP_Z + 12.0:
		var z2: float = z + 0.1
		if _ground_at(x, z2) < y:
			return z2
		z = z2
	return NAN


## A seamless loop of falling-water noise: brown noise for the roar, a little white for the hiss.
func _roar_stream() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 4.0
	var n: int = int(RATE * SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var samples := PackedFloat32Array()
	samples.resize(n)
	var brown := 0.0
	var low := 0.0
	for i in range(n):
		var white: float = rng.randf_range(-1.0, 1.0)
		brown = clampf(brown * 0.995 + white * 0.06, -1.0, 1.0)
		low += (white - low) * 0.18
		samples[i] = brown * 0.9 + low * 0.35
	# Crossfade the tail into the head so the loop point is inaudible.
	var fade: int = int(RATE * 0.5)
	for i in range(fade):
		var t: float = float(i) / float(fade)
		samples[i] = samples[i] * t + samples[n - fade + i] * (1.0 - t)
	var peak := 0.001
	for i in range(n - fade):
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize((n - fade) * 2)
	for i in range(n - fade):
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n - fade
	return _save_baked_resource(wav, "falls_roar") as AudioStreamWAV


# ======================================================================================
#  Kickers, markers and dressing
# ======================================================================================

## Appends triangle a-b-c to `faces`, ordered so its front face looks along `out_hint`. Godot
## front faces wind clockwise, with face normal (c - a) x (b - a) (CLAUDE.md, "Procedural mesh
## winding"), so the order is checked against the hint rather than trusted.
func _tri_out(faces: Array, a: Vector3, b: Vector3, c: Vector3, out_hint: Vector3) -> void:
	if (c - a).cross(b - a).dot(out_hint) < 0.0:
		faces.append_array([a, c, b])
	else:
		faces.append_array([a, b, c])


func _quad_out(faces: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out_hint: Vector3) -> void:
	_tri_out(faces, a, b, c, out_hint)
	_tri_out(faces, a, c, d, out_hint)


## Flat-shaded mesh from a triangle list, normals from the winding.
func _faces_to_mesh(faces: Array, uv_scale: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		var nrm: Vector3 = (c - a).cross(b - a).normalized()
		for v in [a, b, c]:
			st.set_normal(nrm)
			st.set_uv(Vector2(v.x + v.y, v.z + v.y) * uv_scale)
			st.add_vertex(v)
	return st.commit()


## A packed-snow kicker ending in a crisp lip: a circular-arc ramp rising to `height` at `deg`,
## with a sheer front face and sloped sides. Built in local space with travel along -Z: the
## ramp starts at the origin and the lip edge is `length` metres ahead.
func _kicker_mesh(height: float, deg: float, width: float) -> Array:
	var th: float = deg_to_rad(deg)
	var radius: float = height / (1.0 - cos(th))
	var length: float = radius * sin(th)
	var rows := 14
	var half: float = width * 0.5
	var flare := 2.2
	var foot := -0.6
	var top := PackedVector3Array()
	for i in range(rows + 1):
		var s: float = float(i) / float(rows)
		var a: float = s * th
		# The toe starts half a metre under the ground, so the ramp never begins with a step.
		top.append(Vector3(0, radius * (1.0 - cos(a)) - 0.5 * (1.0 - s), -radius * sin(a)))
	var faces: Array = []
	for i in range(rows):
		var p0: Vector3 = top[i]
		var p1: Vector3 = top[i + 1]
		_quad_out(faces, Vector3(-half, p0.y, p0.z), Vector3(half, p0.y, p0.z), Vector3(half, p1.y, p1.z), Vector3(-half, p1.y, p1.z), Vector3.UP)
		_quad_out(faces, Vector3(half, p0.y, p0.z), Vector3(half + flare, foot, p0.z), Vector3(half + flare, foot, p1.z), Vector3(half, p1.y, p1.z), Vector3(1, 1, 0))
		_quad_out(faces, Vector3(-half - flare, foot, p0.z), Vector3(-half, p0.y, p0.z), Vector3(-half, p1.y, p1.z), Vector3(-half - flare, foot, p1.z), Vector3(-1, 1, 0))
	var lip: Vector3 = top[rows]
	var deep := -6.0
	_quad_out(faces, Vector3(-half, lip.y, lip.z), Vector3(half, lip.y, lip.z), Vector3(half, deep, lip.z), Vector3(-half, deep, lip.z), Vector3.FORWARD)
	_quad_out(faces, Vector3(half, lip.y, lip.z), Vector3(half + flare, foot, lip.z), Vector3(half + flare, deep, lip.z), Vector3(half, deep, lip.z), Vector3.FORWARD)
	_quad_out(faces, Vector3(-half - flare, foot, lip.z), Vector3(-half, lip.y, lip.z), Vector3(-half, deep, lip.z), Vector3(-half - flare, deep, lip.z), Vector3.FORWARD)
	return [_faces_to_mesh(faces, 0.25), PackedVector3Array(faces), length]


func _place_kicker(parent: Node, kname: String, lip: Vector3, dir: Vector3, height: float, deg: float,
		width: float, mat: Material) -> void:
	var data: Array = _kicker_mesh(height, deg, width)
	var length: float = data[2]
	var body := StaticBody3D.new()
	body.name = kname
	# Local -Z onto the travel direction; the ramp starts `length` before the lip.
	body.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), lip - dir * length)
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "KickerMesh"
	mi.mesh = data[0]
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data[1])
	shape.backface_collision = true
	col.shape = shape
	body.add_child(col)


func _snow_kicker_material() -> StandardMaterial3D:
	# Packed snow, a shade bluer and glossier than the powder around it so the ramp reads.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.85, 0.94)
	m.roughness = 0.45
	m.rim_enabled = true
	m.rim = 0.3
	return m


## Orange-tipped snow poles, the way mountain roads are marked for ploughs. They run along the
## river side wherever the trail is on a ledge, and both sides elsewhere, and leave the gaps
## and the mega-jump hill clear. Carts knock them over (KnockablePoles.gd).
func _build_snow_poles(parent: Node) -> void:
	var length: float = main_curve.get_baked_length()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.07
	pole.height = 2.4
	pole.radial_segments = 6
	pole.rings = 4
	var pole_mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
void fragment() {
	// Alternating orange and black bands on the top half, white below.
	float y = UV.y;
	float band = step(0.5, fract((1.0 - y) * 4.0));
	vec3 c = (1.0 - y) > 0.5 ? mix(vec3(0.02), vec3(1.0, 0.36, 0.04), band) : vec3(0.92);
	ALBEDO = c;
	ROUGHNESS = 0.5;
	EMISSION = (1.0 - y) > 0.5 ? vec3(1.0, 0.36, 0.04) * band * 0.25 : vec3(0.0);
}
"""
	pole_mat.shader = sh
	pole.material = pole_mat
	var transforms: Array = []
	var d := 6.0
	while d < length - 4.0:
		if _in_gap_span(d) or _near_gap_lip(d, 6.0) or (d > _mega["lip_off"] - 4.0 and d < _mega["hill_end_off"]):
			d += 26.0
			continue
		var f: Dictionary = _frame_at_offset(main_curve, d)
		var p: Vector3 = f["pos"]
		if _on_ice(p.x, p.z):
			d += 26.0
			continue
		var idx: int = clampi(int(d / 2.0), 0, _ts_river_side.size() - 1)
		var side: float = _ts_river_side[idx]
		var sides: Array = [side] if side != 0.0 else [-1.0, 1.0]
		for s in sides:
			var q: Vector3 = p + f["right"] * s * (TRAIL_FLAT + 1.2)
			q.y = _ground_at(q.x, q.z) + 1.1
			transforms.append(Transform3D(Basis(), q))
		d += 26.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pole
	mm.instance_count = transforms.size()
	# The dummy renderer drops set_instance_transform(); write the buffer itself (CLAUDE.md).
	mm.buffer = _transform_buffer(transforms)
	# Carts knock them over: KnockablePoles.gd gives each pole a sleeping rigid body at runtime.
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "SnowPoles"
	mmi.set_script(load("res://KnockablePoles.gd"))
	var typed: Array[Transform3D] = []
	for t in transforms:
		typed.append(t)
	mmi.set("pole_transforms", typed)
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	print("  snow poles: %d" % transforms.size())


func _near_gap_lip(off: float, reach: float) -> bool:
	for g in _gaps:
		if off > g["lip_off"] - 20.0 - reach and off < g["land_off"] + reach:
			return true
	return false


func _transform_buffer(transforms: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(transforms.size() * 12)
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var b: Basis = t.basis
		var o: int = i * 12
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = t.origin.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = t.origin.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = t.origin.z
	return buf


## Waving pennants either side of each kicker, so a jump reads from a long way up the trail. The
## cloth is animated by flag_cloth.gdshader; every flag streams with the same wind, which blows
## across the gorge so the flags show their face to carts running up or down it.
func _build_jump_flags(parent: Node) -> void:
	const POST_H := 4.6
	const WIND := Vector3(1.0, 0.0, 0.3)
	var root := Node3D.new()
	root.name = "JumpFlags"
	parent.add_child(root)
	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.07
	post.height = POST_H
	post.radial_segments = 8
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.85, 0.86, 0.88)
	post_mat.metallic = 0.6
	post_mat.roughness = 0.35
	post.material = post_mat
	var cap := SphereMesh.new()
	cap.radius = 0.08
	cap.height = 0.16
	cap.radial_segments = 8
	cap.rings = 4
	cap.material = post_mat
	var cloth := PlaneMesh.new()
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.size = Vector2(1.6, 1.0)
	cloth.subdivide_width = 16
	cloth.subdivide_depth = 4
	# Hoist on the pole: the flag extends from x = 0 to 1.6.
	cloth.center_offset = Vector3(0.8, 0.0, 0.0)
	var cloth_mat := ShaderMaterial.new()
	cloth_mat.shader = load("res://flag_cloth.gdshader")
	cloth.material = cloth_mat
	var wind: Vector3 = WIND.normalized()
	# Local +X (out from the pole) along the wind.
	var flag_basis := Basis(Vector3.UP, atan2(-wind.z, wind.x))
	var jumps: Array = []
	for g in _gaps:
		jumps.append([g["lip"], g["dir"], 10.5, str(g["name"])])
	jumps.append([_mega["lip"], _mega["dir"], 11.5, "MegaJump"])
	for j in jumps:
		var lip: Vector3 = j[0]
		var dir: Vector3 = j[1]
		var right := Vector3(-dir.z, 0.0, dir.x)
		for s in [-1.0, 1.0]:
			for k in range(2):
				var p: Vector3 = lip - dir * (2.0 + k * 9.0) + right * s * j[2]
				p.y = _ground_at(p.x, p.z) - 0.2
				var mi := MeshInstance3D.new()
				mi.name = "%s_Post_%d_%d" % [j[3], int(s), k]
				mi.mesh = post
				mi.position = p + Vector3(0, POST_H * 0.5, 0)
				root.add_child(mi)
				var body := StaticBody3D.new()
				body.name = "%s_PostBody_%d_%d" % [j[3], int(s), k]
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				# Fatter than the drawn post, so a fast cart cannot slip past it between physics steps.
				cyl.radius = 0.15
				cyl.height = POST_H
				cs.shape = cyl
				body.add_child(cs)
				body.position = p + Vector3(0, POST_H * 0.5, 0)
				root.add_child(body)
				var top := MeshInstance3D.new()
				top.mesh = cap
				top.position = p + Vector3(0, POST_H, 0)
				root.add_child(top)
				var flag := MeshInstance3D.new()
				flag.name = "%s_Flag_%d_%d" % [j[3], int(s), k]
				flag.mesh = cloth
				flag.transform = Transform3D(flag_basis, p + Vector3(0, POST_H - 0.55, 0) + wind * 0.05)
				flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				root.add_child(flag)


## Procedural snowy spruce: a tapered trunk carrying drooping, star-shaped branch whorls that get
## smaller toward a pointed top, so the outline is ragged like a real spruce instead of a stack
## of smooth cones. Shaded by spruce.gdshader (vertex colour = needle colour, alpha = snow weight,
## UV = metres out along the branch and around the whorl, for the needle texture).
##
## Every whorl's apex is raised until it reaches above the drooping rim of the whorl over it, and
## the top whorl closes in a point at the full height. Without that, sparse whorls (the far mesh
## has only four) leave a gap where only the thin trunk shows and the crown appears to float.
##
## `variant` 0 is a tall mature tree, 1 a younger, bushier one. `lod` 0 is the near mesh (~330
## triangles), 1 the distant stand-in (~110) with the same outline in fewer whorls and points.
func _spruce_mesh(variant: int, lod: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + variant * 31
	var height: float = 11.0 if variant == 0 else 7.6
	var base_r: float = 3.0 if variant == 0 else 2.8
	var whorls: int = (9 if variant == 0 else 7) if lod == 0 else 4
	var points: int = 9 if lod == 0 else 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Vertices as [position, normal, colour, uv].
	var emit := func(a: Array, b: Array, c: Array, hint: Vector3) -> void:
		# Front face toward `hint` (Godot winds clockwise; face normal (c - a) x (b - a)).
		if (c[0] - a[0]).cross(b[0] - a[0]).dot(hint) < 0.0:
			var t: Array = b
			b = c
			c = t
		for v in [a, b, c]:
			st.set_normal(v[1])
			st.set_color(v[2])
			st.set_uv(v[3])
			st.add_vertex(v[0])

	# Whorl layout first, so each one can be sized against the one above it.
	var layers: Array = []
	for w in range(whorls):
		var t: float = float(w) / float(maxi(whorls - 1, 1))
		var y_base: float = lerpf(1.3, height * 0.80, pow(t, 0.92))
		var r: float = base_r * pow(1.0 - t * 0.9, 0.95) * rng.randf_range(0.92, 1.08) + 0.3
		layers.append({"y": y_base, "r": r, "droop": r * 0.42, "rot": rng.randf() * TAU})
	for w in range(whorls):
		var L: Dictionary = layers[w]
		var apex_y: float
		if w == whorls - 1:
			apex_y = height
		else:
			var above: Dictionary = layers[w + 1]
			apex_y = maxf(L["y"] + lerpf(1.7, 1.0, float(w) / float(whorls)), above["y"] - above["droop"] * 0.35 + 0.5)
		L["apex"] = apex_y

	# Trunk: visible under the lowest whorl, tapering up into the top whorl.
	var bark := Color(0.12, 0.085, 0.06, 0.0)
	var sides: int = 6 if lod == 0 else 4
	var trunk_top: float = height - 0.8
	for k in range(sides):
		var a0: float = TAU * float(k) / float(sides)
		var a1: float = TAU * float(k + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var b0: Vector3 = d0 * 0.34 + Vector3(0, -0.6, 0)
		var b1: Vector3 = d1 * 0.34 + Vector3(0, -0.6, 0)
		var t0: Vector3 = d0 * 0.06 + Vector3(0, trunk_top, 0)
		var t1: Vector3 = d1 * 0.06 + Vector3(0, trunk_top, 0)
		var out: Vector3 = (d0 + d1).normalized()
		var u0: float = float(k) / float(sides)
		var u1: float = float(k + 1) / float(sides)
		emit.call([b0, d0, bark, Vector2(u0, 0)], [t0, d0, bark * 0.8, Vector2(u0, trunk_top)], [b1, d1, bark, Vector2(u1, 0)], out)
		emit.call([b1, d1, bark, Vector2(u1, 0)], [t0, d0, bark * 0.8, Vector2(u0, trunk_top)], [t1, d1, bark * 0.8, Vector2(u1, trunk_top)], out)

	# The shaded core of the crown is darker than the sunlit tips.
	var core := Color(0.035, 0.075, 0.055, 0.9)
	var mid := Color(0.075, 0.150, 0.105, 1.0)
	var tip_col := Color(0.105, 0.195, 0.130, 0.75)
	for L in layers:
		var y_base: float = L["y"]
		var r: float = L["r"]
		var droop: float = L["droop"]
		var apex := Vector3(0, L["apex"], 0)
		var under := Vector3(0, lerpf(y_base, L["apex"], 0.15), 0)
		var ring: Array = []
		for k in range(points * 2):
			var ang: float = L["rot"] + PI * float(k) / float(points)
			var tip: bool = k % 2 == 0
			var rr: float = r * (rng.randf_range(0.9, 1.12) if tip else rng.randf_range(0.5, 0.62))
			var yy: float = y_base - (droop * rng.randf_range(0.85, 1.15) if tip else droop * 0.35)
			ring.append({"p": Vector3(cos(ang) * rr, yy, sin(ang) * rr), "ang": ang, "tip": tip})
		# Rounded normals: from a point below the whorl's centre, so the crown shades as a mass.
		var centre := Vector3(0, y_base - r * 0.9, 0)
		for k in range(points * 2):
			var e0: Dictionary = ring[k]
			var e1: Dictionary = ring[(k + 1) % (points * 2)]
			var p0: Vector3 = e0["p"]
			var p1: Vector3 = e1["p"]
			var c0: Color = tip_col if e0["tip"] else mid
			var c1: Color = tip_col if e1["tip"] else mid
			# UV: u runs out along the branch (metres from the trunk), v around the whorl (metres of
			# arc at the rim), so the needle texture lies along each branch at the same scale on every tree.
			var a1: float = e1["ang"] if k + 1 < points * 2 else float(e1["ang"]) + TAU
			var v0: float = float(e0["ang"]) * r
			var v1: float = a1 * r
			var uv0 := Vector2(Vector2(p0.x, p0.z).length(), v0)
			var uv1 := Vector2(Vector2(p1.x, p1.z).length(), v1)
			var uva := Vector2(0.0, (v0 + v1) * 0.5)
			var out: Vector3 = Vector3(p0.x + p1.x, 0.0, p0.z + p1.z).normalized() + Vector3.UP * 0.8
			emit.call([apex, Vector3.UP, core, uva], [p0, (p0 - centre).normalized(), c0, uv0],
					[p1, (p1 - centre).normalized(), c1, uv1], out)
			# Underside: dark, holds no snow, faces down and out.
			var dn0: Vector3 = (Vector3(p0.x, 0.0, p0.z).normalized() + Vector3.DOWN).normalized()
			var dn1: Vector3 = (Vector3(p1.x, 0.0, p1.z).normalized() + Vector3.DOWN).normalized()
			var dark := Color(core.r * 0.8, core.g * 0.8, core.b * 0.8, 0.0)
			emit.call([under, Vector3.DOWN, dark, uva],
					[p0, dn0, Color(c0.r * 0.6, c0.g * 0.6, c0.b * 0.6, 0.0), uv0],
					[p1, dn1, Color(c1.r * 0.6, c1.g * 0.6, c1.b * 0.6, 0.0), uv1],
					Vector3.DOWN + out * 0.1)

	var mesh: ArrayMesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://spruce.gdshader")
	mat.set_shader_parameter("needle_albedo", _needle_textures()[0])
	mat.set_shader_parameter("needle_normal", _needle_textures()[1])
	mesh.surface_set_material(0, mat)
	return mesh


var _needle_tex_cache: Array = []

## A tiling spruce-twig texture, generated: twigs run along U (out along the branch), each with
## short needles angled forward on both sides, with light and dark needles mixed and a height map
## turned into a normal map so the needles catch the light. Returns [albedo, normal], both saved
## under res://generated/ with mipmaps.
func _needle_textures() -> Array:
	if not _needle_tex_cache.is_empty():
		return _needle_tex_cache
	const SIZE := 256
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var hgt := PackedFloat32Array()
	hgt.resize(SIZE * SIZE)
	var lum := PackedFloat32Array()
	lum.resize(SIZE * SIZE)
	for i in range(SIZE * SIZE):
		lum[i] = 0.18
	# Twigs: horizontal rows across V, each wobbling a little; needles fan off them toward +U.
	var twigs := 7
	for tw in range(twigs):
		var v_base: float = (float(tw) + rng.randf_range(0.2, 0.8)) / float(twigs) * SIZE
		var wobble: float = rng.randf_range(2.0, 5.0)
		var phase: float = rng.randf() * TAU
		var x := 0.0
		while x < SIZE:
			var vy: float = v_base + sin(x / SIZE * TAU * 2.0 + phase) * wobble
			for side in [-1.0, 1.0]:
				var ang: float = deg_to_rad(rng.randf_range(35.0, 60.0)) * side
				var length: float = rng.randf_range(9.0, 15.0)
				var bright: float = rng.randf_range(0.55, 1.0)
				var steps: int = int(length * 2.0)
				for s2 in range(steps):
					var f: float = float(s2) / float(steps)
					var px: float = x + cos(ang) * length * f
					var py: float = vy + sin(ang) * length * f
					# Needles are 2px wide, taper at the tip, and wrap so the texture tiles.
					for wv in [0.0, 0.7]:
						var ix: int = posmod(int(px), SIZE)
						var iy: int = posmod(int(py + wv), SIZE)
						var idx: int = iy * SIZE + ix
						var h: float = (1.0 - f * 0.6) * bright
						if h > hgt[idx]:
							hgt[idx] = h
							lum[idx] = lerpf(0.45, 1.0, bright) * (1.0 - f * 0.25)
			x += rng.randf_range(2.2, 3.4)
		# The twig itself: a thin brown-dark ridge.
		for xi in range(SIZE):
			var vy2: float = v_base + sin(float(xi) / SIZE * TAU * 2.0 + phase) * wobble
			var idx2: int = posmod(int(vy2), SIZE) * SIZE + xi
			hgt[idx2] = maxf(hgt[idx2], 0.7)
			lum[idx2] = 0.32
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in range(SIZE):
		for x in range(SIZE):
			var i: int = y * SIZE + x
			var l: float = lum[i]
			albedo.set_pixel(x, y, Color(l, l, l))
			var hl: float = hgt[y * SIZE + posmod(x - 1, SIZE)]
			var hr: float = hgt[y * SIZE + posmod(x + 1, SIZE)]
			var hd: float = hgt[posmod(y - 1, SIZE) * SIZE + x]
			var hu: float = hgt[posmod(y + 1, SIZE) * SIZE + x]
			var n := Vector3((hl - hr) * 2.5, (hd - hu) * 2.5, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	_needle_tex_cache = [
		_save_baked_resource(ImageTexture.create_from_image(albedo), "spruce_needles_albedo"),
		_save_baked_resource(ImageTexture.create_from_image(normal), "spruce_needles_normal"),
	]
	return _needle_tex_cache


## Spruce stands on the gentle ground away from the trail, and rocks along the gorge rims. Tree
## trunks near the trail get collision so carts running wide meet them.
func _build_forest(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60411
	var trees: Array = []
	var variants: Array = []
	var tries := 0
	while trees.size() < 1400 and tries < 60000:
		tries += 1
		var x: float = rng.randf_range(FINE_X.x - 120.0, FINE_X.y + 180.0)
		var z: float = rng.randf_range(FINE_Z.x - 160.0, FINE_Z.y + 160.0)
		# Stands, not a uniform spray.
		if _base_noise.get_noise_2d(x * 2.5, z * 2.5) < 0.05:
			continue
		if _on_ice(x, z) or _ice_mask(x, z) > 0.05:
			continue
		var r: Dictionary = _river_at(x, z)
		if r["d"] < r["hw"] + 14.0:
			continue
		var trail_d: float = _trail_distance(x, z)
		if trail_d < TRAIL_FLAT + 7.0:
			continue
		# Keep the mega-jump's landing zone and the valley start area open.
		if _segment_distance(Vector2(x, z), Vector2(_mega["lip"].x, _mega["lip"].z), Vector2(_mega["hill_end"].x, _mega["hill_end"].z)) < 40.0:
			continue
		var y: float = _ground_at(x, z)
		var nx: float = _ground_at(x + 2.0, z) - _ground_at(x - 2.0, z)
		var nz: float = _ground_at(x, z + 2.0) - _ground_at(x, z - 2.0)
		if Vector2(nx, nz).length() / 4.0 > 0.7:
			continue
		var s: float = rng.randf_range(0.8, 1.45)
		# A slight lean, the way trees on a slope grow.
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.05))
		var basis: Basis = lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
		trees.append(Transform3D(basis, Vector3(x, y - 0.3, z)))
		# Mostly mature trees, with younger ones mixed in.
		variants.append(0 if rng.randf() < 0.65 else 1)
	_build_forest_cells(parent, trees, variants)
	print("  spruces: %d" % trees.size())


## Lays the forest out as MultiMeshes per map cell and per detail level, so cameras and shadow
## passes only draw the cells they can see, and the detailed trees only within FOREST_NEAR. Past
## that every tree is the low-detail stand-in, which casts no shadow.
func _build_forest_cells(parent: Node, trees: Array, variants: Array) -> void:
	var meshes := {}
	for v in [0, 1]:
		meshes[v] = _save_baked_resource(_spruce_mesh(v, 0), "spruce_near_%d" % v)
	var far_mesh: Mesh = _save_baked_resource(_spruce_mesh(0, 1), "spruce_far")
	# Near cells: per variant. Far cells: bigger, one mesh for both variants (the young trees are
	# simply scaled down), so the distant forest costs a handful of draw calls.
	var near := {}
	var far := {}
	for i in range(trees.size()):
		var xf: Transform3D = trees[i]
		var v: int = variants[i]
		var nk := Vector3i(floori(xf.origin.x / FOREST_CELL), floori(xf.origin.z / FOREST_CELL), v)
		if not near.has(nk):
			near[nk] = []
		near[nk].append(xf)
		var fk := Vector2i(floori(xf.origin.x / FOREST_FAR_CELL), floori(xf.origin.z / FOREST_FAR_CELL))
		if not far.has(fk):
			far[fk] = []
		far[fk].append(xf if v == 0 else xf.scaled_local(Vector3(0.75, 0.69, 0.75)))
	var root := Node3D.new()
	root.name = "SpruceForest"
	parent.add_child(root)
	for k in near.keys():
		var mmi := _forest_multimesh(meshes[k.z], near[k], "Near_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = FOREST_NEAR
		mmi.visibility_range_end_margin = 20.0
		root.add_child(mmi)
	for k in far.keys():
		var mmi := _forest_multimesh(far_mesh, far[k], "Far_%d_%d" % [k.x, k.y])
		mmi.visibility_range_begin = FOREST_NEAR
		mmi.visibility_range_begin_margin = 20.0
		mmi.visibility_range_end = 1100.0
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	# Every tree is solid, in one static body per cell. The collider is the trunk plus the dense
	# inner branches (about a third of the lowest whorl), so a cart stops in the branches rather
	# than passing through them to a pencil-thin trunk.
	var bodies := {}
	for i in range(trees.size()):
		var xf2: Transform3D = trees[i]
		var bk := Vector2i(floori(xf2.origin.x / FOREST_CELL), floori(xf2.origin.z / FOREST_CELL))
		if not bodies.has(bk):
			var body := StaticBody3D.new()
			body.name = "TreeTrunks_%d_%d" % [bk.x, bk.y]
			root.add_child(body)
			bodies[bk] = body
		var s: float = xf2.basis.get_scale().x * (1.0 if variants[i] == 0 else 0.85)
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 1.0 * s
		cyl.height = 7.0 * s
		col.shape = cyl
		col.position = xf2.origin + Vector3(0, cyl.height * 0.5 - 0.5, 0)
		bodies[bk].add_child(col)
	print("  forest: %d near cells, %d far cells, %d collision cells" % [near.size(), far.size(), bodies.size()])


func _forest_multimesh(mesh: Mesh, transforms: Array, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	# The dummy renderer drops set_instance_transform(); write the buffer itself (CLAUDE.md).
	mm.buffer = _transform_buffer(transforms)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	return mmi


func _trail_distance(x: float, z: float) -> float:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e9
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _ts_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var p: Vector3 = _ts_pos[i]
				best = minf(best, Vector2(x - p.x, z - p.z).length_squared())
	return sqrt(best)


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Snow-capped boulders scattered on the ledges and the gorge rims.
func _build_boulders(parent: Node, rock_mat: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7302
	var base := SphereMesh.new()
	base.radius = 1.0
	base.height = 1.6
	base.radial_segments = 9
	base.rings = 5
	# Lumpy rock from a squashed sphere, displaced once and reused.
	var arrays: Array = base.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 1.3
	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		verts[i] = v * (1.0 + noise.get_noise_3dv(v) * 0.35)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.generate_normals()
	var rock_mesh: ArrayMesh = st.commit()
	rock_mesh.surface_set_material(0, rock_mat)
	var transforms: Array = []
	var bodies := StaticBody3D.new()
	bodies.name = "BoulderRocks"
	parent.add_child(bodies)
	var tries := 0
	while transforms.size() < 260 and tries < 20000:
		tries += 1
		var i: int = rng.randi_range(0, _ts_pos.size() - 1)
		var p: Vector3 = _ts_pos[i]
		var r: Vector3 = _ts_right[i]
		var s: float = -1.0 if rng.randf() < 0.5 else 1.0
		var lat: float = s * rng.randf_range(TRAIL_FLAT + 4.0, TRAIL_FLAT + 34.0)
		var q: Vector3 = p + r * lat
		if _on_ice(q.x, q.z) or _trail_distance(q.x, q.z) < TRAIL_FLAT + 3.5:
			continue
		var rv: Dictionary = _river_at(q.x, q.z)
		if rv["d"] < rv["hw"] + 3.0:
			continue
		if _segment_distance(Vector2(q.x, q.z), Vector2(_mega["lip"].x, _mega["lip"].z), Vector2(_mega["hill_end"].x, _mega["hill_end"].z)) < 30.0:
			continue
		var size: float = rng.randf_range(0.8, 3.2)
		var y: float = _ground_at(q.x, q.z)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size * rng.randf_range(0.9, 1.5), size * rng.randf_range(0.6, 1.0), size))
		transforms.append(Transform3D(basis, Vector3(q.x, y + size * 0.15, q.z)))
		if _trail_distance(q.x, q.z) < TRAIL_FLAT + 14.0:
			var c := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = size * 0.85
			c.shape = sph
			c.position = Vector3(q.x, y + size * 0.15, q.z)
			bodies.add_child(c)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock_mesh
	mm.instance_count = transforms.size()
	mm.buffer = _transform_buffer(transforms)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "BoulderField"
	mmi.multimesh = _save_baked_resource(mm, "boulder_multimesh")
	parent.add_child(mmi)
	print("  boulders: %d" % transforms.size())


# ======================================================================================
#  Utilities
# ======================================================================================

func _save_baked_resource(res: Resource, res_name: String) -> Resource:
	if not DirAccess.dir_exists_absolute("res://generated/"):
		DirAccess.make_dir_absolute("res://generated/")
	var file_path: String = "res://generated/" + RES_PREFIX + res_name + ".res"
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	return load(file_path)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)


## Resolves the gaps and mega-jump against the built curve: offsets along the lap, the gully
## frame, and where each gully meets the river.
func _resolve_jumps() -> void:
	_gaps.clear()
	var seed_i := 0
	for g in GAPS:
		var d2: Vector2 = (g["dir"] as Vector2).normalized()
		var dir := Vector3(d2.x, 0.0, d2.y)
		var lip: Vector3 = g["lip"]
		var lip_off: float = main_curve.get_closest_offset(lip)
		var land: Vector3 = lip + dir * GAP_LEN
		var land_off: float = main_curve.get_closest_offset(land)
		var center: Vector3 = lip + dir * (GAP_LEN * 0.5)
		var right := Vector3(-dir.z, 0.0, dir.x)
		var rv_r: float = _river_at(center.x + right.x * 30.0, center.z + right.z * 30.0)["d"]
		var rv_l: float = _river_at(center.x - right.x * 30.0, center.z - right.z * 30.0)["d"]
		# Axis points away from the river (uphill).
		var axis: Vector3 = -right if rv_r < rv_l else right
		var rv: Dictionary = _river_at(center.x, center.z)
		# Walk toward the river until we are over water, to find the mouth.
		var mouth: Vector3 = center
		for k in range(200):
			var q: Vector3 = center - axis * float(k)
			var r2: Dictionary = _river_at(q.x, q.z)
			if r2["d"] < r2["hw"] * 0.5:
				mouth = q
				rv = r2
				break
		var river_reach: float = Vector2(center.x - mouth.x, center.z - mouth.z).length() + 6.0
		var inland: float = TRAIL_FLAT + 10.0
		var head: Vector3 = center + axis * inland
		_gaps.append({
			"name": g["name"], "lip": lip, "lip_top": lip + Vector3(0, GAP_KICKER_H, 0), "dir": dir,
			"axis": axis, "center": center, "lip_off": lip_off, "land_off": land_off,
			"water_y": rv["y"], "mouth": mouth, "head": head, "river_reach": river_reach,
			"inland_reach": inland, "seed": seed_i * 97,
		})
		print("  gap %s: lip %.0fm along, trail %.1fm above the water" % [g["name"], lip_off, lip.y - rv["y"]])
		seed_i += 1
	var md2: Vector2 = MEGA_DIR.normalized()
	var mdir := Vector3(md2.x, 0.0, md2.y)
	var hill_end: Vector3 = MEGA_LIP + mdir * MEGA_HILL_LEN
	_mega = {
		"lip": MEGA_LIP, "lip_top": MEGA_LIP + Vector3(0, MEGA_KICKER_H, 0), "dir": mdir,
		"lip_off": main_curve.get_closest_offset(MEGA_LIP),
		"hill_end": hill_end, "hill_end_off": main_curve.get_closest_offset(Vector3(hill_end.x, VALLEY_Y, hill_end.z)),
	}
	print("  mega-jump: lip %.0fm along, %.0fm above the valley" % [_mega["lip_off"], MEGA_LIP.y + MEGA_KICKER_H - VALLEY_Y])


# ======================================================================================
#  Level build
# ======================================================================================

func _ready() -> void:
	print("=== Frostfall Gorge Arctic Cup Level Generation ===")
	var t_start: int = Time.get_ticks_msec()

	var level_scene := Node3D.new()
	level_scene.name = LEVEL_NAME
	level_scene.set_script(load("res://levels/Level.gd"))

	var players_node := Node3D.new()
	players_node.name = "Players"
	level_scene.add_child(players_node)
	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	level_scene.add_child(p_spawner)
	var proj_spawner := MultiplayerSpawner.new()
	proj_spawner.name = "ProjectileSpawner"
	proj_spawner.spawn_path = NodePath(".")
	level_scene.add_child(proj_spawner)
	add_child(level_scene)

	_init_noise()
	_build_river_segments()

	# 1. Environment: a clear, cold afternoon. Same sky shader and fog recipe as Frostpeak Creek
	#    (see CLAUDE.md, "Frostpeak sky"), with the sun low in the south-west so it rakes across
	#    the gorge walls and lights the falls' mist from the side.
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_winter_cirrus.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.88, 0.93, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.12
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.80, 0.87, 0.95)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.10
	env.fog_density = 1.0
	env.fog_depth_begin = 140.0
	env.fog_depth_end = 1100.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.08
	env.fog_aerial_perspective = 0.25
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-34.0, -142.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 520.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)
	sky_mat.set_shader_parameter("horizon_haze", Color(0.80, 0.87, 0.95))

	var wind_stream = load("res://sounds/dragon-studio-winter-wind-402331.mp3")
	if wind_stream:
		var wind_player := AudioStreamPlayer.new()
		wind_player.name = "WinterWindAudio"
		wind_player.stream = wind_stream
		wind_player.volume_db = -15.0
		wind_player.autoplay = true
		level_scene.add_child(wind_player)

	var snow_particles := GPUParticles3D.new()
	snow_particles.name = "FallingSnow"
	var falling_snow_script = load("res://FallingSnow.gd")
	if falling_snow_script:
		snow_particles.set_script(falling_snow_script)
	snow_particles.amount = 1600
	snow_particles.lifetime = 3.6
	snow_particles.speed_scale = 0.5
	snow_particles.randomness = 0.8
	snow_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_particles.visibility_aabb = AABB(Vector3(-45, -35, -45), Vector3(90, 45, 90))
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(35.0, 1.0, 35.0)
	pmat.direction = Vector3(0.3, -1.0, 0.1)
	pmat.spread = 18.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 5.0
	pmat.gravity = Vector3(0, -3.0, 0)
	pmat.scale_min = 0.8
	pmat.scale_max = 1.3
	snow_particles.process_material = pmat
	var snow_quad := QuadMesh.new()
	snow_quad.size = Vector2(0.11, 0.11)
	var fall_snow_mat := StandardMaterial3D.new()
	fall_snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fall_snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fall_snow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fall_snow_mat.vertex_color_use_as_albedo = true
	fall_snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.95), Color(1.0, 1.0, 1.0, 0.0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 32
	grad_tex.height = 32
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	fall_snow_mat.albedo_texture = grad_tex
	fall_snow_mat.albedo_color = Color(0.96, 0.98, 1.0, 0.85)
	snow_quad.material = fall_snow_mat
	snow_particles.draw_pass_1 = snow_quad
	level_scene.add_child(snow_particles)

	# 2. The lap.
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	main_curve = _build_closed_loop(_track_points())
	track_path.curve = main_curve
	level_scene.add_child(track_path)
	var lap_len: float = main_curve.get_baked_length()
	print("  lap length %.0fm" % lap_len)
	_verify_min_radius(main_curve)
	_verify_plan(main_curve)
	_resolve_jumps()

	# 3. Terrain.
	_build_trail_samples()
	print("  building heightfield...")
	_build_heights()
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://frostfall_ground.gdshader")
	var rock_tex: Texture2D = load("res://materials/dark_rock.png") as Texture2D
	var rock_norm: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
	if rock_tex:
		ground_mat.set_shader_parameter("rock_albedo", rock_tex)
	if rock_norm:
		ground_mat.set_shader_parameter("rock_normal", rock_norm)
	var terrain_root := Node3D.new()
	terrain_root.name = "TerrainEnvironment"
	level_scene.add_child(terrain_root)
	_build_terrain(terrain_root, ground_mat)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_verify_trail_ground()

	# 4. Kickers on the gaps and the mega-jump.
	# Not "Snow...": PlayerCart treats anything under a node named snow as a snow drift.
	var kickers := Node3D.new()
	kickers.name = "JumpKickers"
	level_scene.add_child(kickers)
	var kicker_mat := _snow_kicker_material()
	for g in _gaps:
		_place_kicker(kickers, "Kicker_" + str(g["name"]), g["lip"], g["dir"], GAP_KICKER_H, GAP_KICKER_DEG, 19.0, kicker_mat)
	_place_kicker(kickers, "Kicker_MegaJump", _mega["lip"], _mega["dir"], MEGA_KICKER_H, MEGA_KICKER_DEG, 21.0, kicker_mat)
	_verify_jumps()

	# 5. Water and the falls.
	var water_root := Node3D.new()
	water_root.name = "Water"
	level_scene.add_child(water_root)
	_build_river_water_node(level_scene)
	_build_river_meshes(water_root, _water_material())
	_build_waterfall(water_root)

	# 6. Finish line and grid.
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var fl: Dictionary = _spot(2.0, 0.0, 0.06)
	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = fl["pos"]
	finish_line.rotation_degrees = Vector3(0, fl["yaw"], 0)
	finish_line.set("is_finish_line", true)
	level_scene.add_child(finish_line)
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)
	var grid_coords = [
		Vector3(-2.9, 0.05, 5.0), Vector3(2.9, 0.05, 5.0),
		Vector3(-2.9, 0.05, 12.5), Vector3(2.9, 0.05, 12.5),
		Vector3(-2.9, 0.05, 20.0), Vector3(2.9, 0.05, 20.0),
	]
	for i in range(grid_coords.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid_coords[i]
		sp.gizmo_extents = 0.3
		spawn_points.add_child(sp)
		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp.add_child(si)

	# 7. Checkpoints. One sits on the run-in to every jump, so a cart that falls into the river
	#    reappears with the whole run-up ahead of it, and the rest spread the lap out.
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)
	var cp_offs: Array = []
	for g in _gaps:
		cp_offs.append(g["lip_off"] - 85.0)
	cp_offs.append(_mega["lip_off"] - MEGA_RUN_UP + 10.0)
	# Fill the long stretches: the climb past the falls, the tarn, and the lake crossing.
	var extra := [_gaps[0]["land_off"] + 160.0, (_gaps[1]["land_off"] + _gaps[2]["lip_off"]) * 0.5, _mega["hill_end_off"] + 120.0]
	cp_offs.append_array(extra)
	cp_offs.sort()
	for i in range(cp_offs.size()):
		var c: Dictionary = _spot(cp_offs[i], 0.0, 0.1)
		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = c["pos"]
		gate.rotation_degrees = Vector3(0, c["yaw"], 0)
		checkpoints_container.add_child(gate)
		print("  checkpoint %d at %.0fm" % [i + 1, cp_offs[i]])

	# 8. Boost pads: a full-width lane before the mega-jump so the whole field flies it, and
	#    a few rewards on the climb.
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)
	var bp_defs: Array = []
	for lat in [-6.0, -2.0, 2.0, 6.0]:
		bp_defs.append(["Boost_MegaLane_%d" % int(lat), _mega["lip_off"] - 45.0, lat])
	bp_defs.append(["Boost_StartClimb", 0.10 * lap_len, -3.0])
	bp_defs.append(["Boost_FallsClimb", _gaps[0]["land_off"] + 120.0, 3.0])
	bp_defs.append(["Boost_Tarn", (_gaps[1]["land_off"] + _gaps[2]["lip_off"]) * 0.5 + 40.0, 0.0])
	bp_defs.append(["Boost_Lake", _mega["hill_end_off"] + 170.0, 2.0])
	for b in bp_defs:
		var bp = boost_scene.instantiate()
		bp.name = b[0]
		var s: Dictionary = _spot(b[1], b[2], 0.08)
		bp.position = s["pos"]
		bp.rotation_degrees = Vector3(0, s["yaw"], 0)
		boost_container.add_child(bp)

	# 9. Item boxes in rows on the calmer stretches (never on a run-in).
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)
	var item_rows := [0.06 * lap_len, _gaps[0]["land_off"] + 70.0, _gaps[1]["land_off"] + 60.0,
			_gaps[2]["land_off"] + 70.0, _mega["hill_end_off"] + 60.0]
	var item_idx := 1
	for off in item_rows:
		for lat in [-4.5, 0.0, 4.5]:
			var ib = item_scene.instantiate()
			ib.name = "ItemBox_%d" % item_idx
			var s2: Dictionary = _spot(off, lat, 1.4)
			ib.position = s2["pos"]
			item_container.add_child(ib)
			item_idx += 1

	# 10. Dressing.
	var props := Node3D.new()
	props.name = "TrailsideProps"
	level_scene.add_child(props)
	_build_snow_poles(props)
	_build_jump_flags(props)
	_build_forest(props)
	var boulder_mat := ShaderMaterial.new()
	boulder_mat.shader = load("res://alpine_snow.gdshader")
	if rock_tex:
		boulder_mat.set_shader_parameter("rock_albedo", rock_tex)
	if rock_norm:
		boulder_mat.set_shader_parameter("rock_normal", rock_norm)
	boulder_mat.set_shader_parameter("snow_slope", 0.55)
	_build_boulders(props, boulder_mat)

	# 11. Wiring and save.
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX + "ground", "res://generated/frostfall_chunks", MESH_CHUNK_CELL)
	print("  chunked %d large meshes" % chunked)
	_set_owner_recursive(level_scene, level_scene)
	remove_child(level_scene)
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack %s: %d" % [LEVEL_PATH, pack_err])
		get_tree().quit(1)
		return
	var save_err = ResourceSaver.save(packed_scene, LEVEL_PATH)
	if save_err != OK:
		push_error("Failed to save %s: %d" % [LEVEL_PATH, save_err])
		get_tree().quit(1)
		return
	print("Saved %s in %.1fs" % [LEVEL_PATH, (Time.get_ticks_msec() - t_start) / 1000.0])
	get_tree().quit(0)
