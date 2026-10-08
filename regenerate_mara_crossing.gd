# regenerate_mara_crossing.gd
#
# Builds levels/MaraCrossingLevel.tscn - the first stage of the Matumaini GP: a red murram road
# across the East African savanna at golden hour, with the volcano on the skyline.
#
# The lap: the start/finish straight runs north past the safari bandas. A fast right-hander
# opens onto the Migration Plain, where a wildebeest herd streams across the road in waves
# (WildebeestHerd.gd) - time the gap or thread the animals. The road climbs onto a granite kopje
# and leaves it off Pride Rock, a ledge jump into the low sun, then runs west to the Mara river.
# The main road wades the ford, which halves your speed unless you hit it on boost. The Croc
# Jump line branches off before it and leaps the deep croc pool upstream: much faster, but come
# up short and you are in the river. Home runs south past the hippo lake and round Baobab Bend.
#
# Things worth knowing before editing this file:
#
# 1. There is no road mesh. The heightfield is graded flat under every road centreline and the
#    shader (savanna_ground.gdshader) paints the murram from the signed distance across the road
#    baked into the vertex colour. The road is therefore seamless with the savanna: no lip for
#    the cart's sphere to pop on. The ground's collision is split in two bodies: triangles on the
#    road go in MurramRoad (PlayerCart counts anything named "road" as track), the rest in
#    SavannaGround (off-road).
#
# 2. The heightfield is built in layers, in this order:
#      base landscape (plain, kopjes, floodplain, far hills) -> clamp between every road's fill
#      and cut bounds -> carve the river and lake -> put the road strip back where a road runs
#      through water (the ford).
#    The jump spans (JUMP spans on the road samples) are left out of the grading, so the river
#    carve opens the croc pool under the Croc Jump.
#
# 3. The jumps are measured, not guessed: _verify_jumps() flies a cart (30 m/s^2 gravity, no air
#    control, same as PlayerCart) off both kickers against the built ground and push_errors when
#    a cart at the stated speed cannot make the landing.
#
# The menu tiles (images/menu/tile_mara_crossing.jpg and tile_matumaini_gp.jpg) are renders of
# this level taken windowed with scratch/mara_shots.gd; the generator runs headless and cannot
# render.
extends Node

const LEVEL_NAME := "MaraCrossingLevel"
const LEVEL_PATH := "res://levels/MaraCrossingLevel.tscn"
const RES_PREFIX := "mara_"
const MeshChunker = preload("res://MeshChunker.gd")
const RiverWaterScript = preload("res://RiverWater.gd")
const HerdScript = preload("res://WildebeestHerd.gd")

const MESH_CHUNK_CELL := 80.0
const BAKE_INTERVAL := 0.5
const TRACK_MIN_RADIUS := 30.0

## Painted murram half width (the shader's road_half_width).
const ROAD_HALF := 7.0
## Ground within this of a road centreline goes into the MurramRoad collision body.
const ROAD_COLLIDE := 7.8
## Half width of the strip graded flat to road height.
const ROAD_FLAT := 8.6
## Embankment slopes beside the flat strip: rise per metre of a cutting, drop per metre of a fill.
const CUT_SLOPE := 0.55
const FILL_SLOPE := 0.6
const GRADE_REACH := 70.0
## Road samples are bucketed in CELL x CELL squares for the lookups.
const CELL := 40.0
const SAMPLE_STEP := 2.0

const PLAIN_Y := 6.2
const WATER_Y := 0.0
const FLOOD_Y := 1.8

## The river, north to south into the hippo lake: centre, half width, depth at the centre, bank
## steepness (rise per metre beside the water) and how much the floodplain is lowered around it.
const RIVER := [
	[Vector2(-5.0, -1700.0), 22.0, 3.0, 0.5, 0.8],
	[Vector2(-25.0, -1050.0), 18.0, 3.0, 0.6, 0.8],
	[Vector2(-50.0, -650.0), 15.0, 3.2, 0.9, 0.6],
	# The croc pool: narrow, deep and sheer-sided. The Croc Jump crosses it.
	[Vector2(-46.0, -500.0), 11.0, 3.8, 3.0, 0.25],
	[Vector2(-45.0, -440.0), 11.0, 3.8, 3.0, 0.25],
	[Vector2(-50.0, -400.0), 13.0, 3.0, 1.2, 0.6],
	# The ford: wide and shallow.
	[Vector2(-62.0, -352.0), 17.0, 1.4, 0.18, 1.0],
	[Vector2(-80.0, -300.0), 15.0, 2.2, 0.5, 0.9],
	[Vector2(-108.0, -240.0), 16.0, 2.4, 0.5, 0.9],
	[Vector2(-135.0, -185.0), 20.0, 2.4, 0.5, 0.9],
]
const LAKE_CENTER := Vector2(-150.0, -150.0)
const LAKE_RADIUS := Vector2(85.0, 60.0)
const LAKE_DEPTH := 2.6

## Kopjes: granite tors rising out of the plain. Centre, radius, height. The first carries the
## road and Pride Rock.
const KOPJES := [
	[Vector2(345.0, -286.0), 72.0, 12.0],
	[Vector2(130.0, 150.0), 30.0, 7.0],
	[Vector2(-430.0, 170.0), 38.0, 9.0],
	[Vector2(-175.0, 70.0), 24.0, 6.0],
	[Vector2(560.0, -430.0), 45.0, 11.0],
	[Vector2(250.0, -480.0), 30.0, 8.0],
	[Vector2(-380.0, -470.0), 40.0, 10.0],
]

## Pride Rock: the ledge jump off the west end of the kopje, into the low sun.
const PR_LIP := Vector3(296.0, 16.0, -316.0)
const PR_DIR := Vector2(-0.979, -0.2025)
const PR_KICK_H := 1.4
const PR_KICK_DEG := 13.0
const PR_RUN_UP := 60.0
const PR_UNDER_LIP := 4.0
const PR_HILL_LEN := 140.0
const PR_OUT_Y := 6.2

## The Croc Jump: the alternative line's leap over the croc pool.
const CROC_LIP := Vector3(-31.5, 5.0, -437.0)
const CROC_DIR := Vector2(-1.0, 0.05)
const CROC_GAP := 28.0
const CROC_LAND_DROP := 2.5
const CROC_KICK_H := 1.6
const CROC_KICK_DEG := 16.0

## The migration: where the herd's stream crosses the Migration Plain, and which way it runs.
const HERD_CROSS := Vector2(190.0, -55.0)
const HERD_DIR := Vector2(-0.42, -0.91)
const HERD_BEFORE := 150.0
const HERD_AFTER := 140.0
const HERD_HALF_W := 11.0

## Terrain grid: fine around the lap, cells growing outward to the horizon.
const FINE_X := Vector2(-340.0, 480.0)
const FINE_Z := Vector2(-500.0, 360.0)
const FINE_STEP := 2.5
const OUTER_X := Vector2(-3200.0, 3200.0)
const OUTER_Z := Vector2(-3400.0, 3000.0)
const COARSE_GROWTH := 1.18
const COARSE_MAX := 80.0

const VOLCANO_AT := Vector3(1750.0, -60.0, -2850.0)
const VOLCANO_H := 1250.0
const VOLCANO_R := 2400.0

var main_curve: Curve3D
var croc_curve: Curve3D
var _base_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _lump_noise := FastNoiseLite.new()
var _far_noise := FastNoiseLite.new()

# Road samples every SAMPLE_STEP metres along both roads.
var _rs_pos := PackedVector3Array()
var _rs_right := PackedVector3Array()
## Index of the next sample on the same road, -1 at the open end of the croc line.
var _rs_next := PackedInt32Array()
## 1 inside a jump's flight: not graded, not road.
var _rs_gap := PackedByteArray()
var _rs_cells := {}

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()

var _pr: Dictionary = {}
var _croc: Dictionary = {}
var _herd_start := Vector3.ZERO
var _herd_end := Vector3.ZERO


# ======================================================================================
#  Track
# ======================================================================================

## Height of the Pride Rock landing hill `x` metres past the lip, relative to the kicker top.
func _pr_hill(x: float) -> float:
	var drop: float = (PR_LIP.y + PR_KICK_H) - PR_OUT_Y
	if x <= 0.0:
		return -PR_KICK_H
	if x < 8.0:
		return lerpf(-PR_KICK_H - 0.6, -PR_UNDER_LIP, pow(x / 8.0, 0.6))
	var u: float = clampf((x - 8.0) / (PR_HILL_LEN - 8.0), 0.0, 1.0)
	var s: float = u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
	return -PR_UNDER_LIP - (drop - PR_UNDER_LIP) * s


func _pr_dir3() -> Vector3:
	var d: Vector2 = PR_DIR.normalized()
	return Vector3(d.x, 0.0, d.y)


func _croc_dir3() -> Vector3:
	var d: Vector2 = CROC_DIR.normalized()
	return Vector3(d.x, 0.0, d.y)


## Control points of the closed lap, starting at the finish line, running north.
func _track_points() -> Array:
	var pts: Array = []
	# --- Start / finish straight, north past the bandas ---
	pts.append(Vector3(0.0, PLAIN_Y, 200.0))
	pts.append(Vector3(0.0, PLAIN_Y, 120.0))
	pts.append(Vector3(0.0, PLAIN_Y, 50.0))
	# --- Right-hander onto the Migration Plain ---
	pts.append(Vector3(14.0, PLAIN_Y, -4.0))
	pts.append(Vector3(62.0, 6.4, -38.0))
	pts.append(Vector3(140.0, 7.0, -54.0))
	pts.append(Vector3(230.0, 7.0, -56.0))
	pts.append(Vector3(318.0, 7.4, -50.0))
	# --- Left, north, and up onto the kopje ---
	pts.append(Vector3(382.0, 8.0, -74.0))
	pts.append(Vector3(416.0, 9.0, -128.0))
	pts.append(Vector3(420.0, 11.5, -200.0))
	pts.append(Vector3(400.0, 14.5, -258.0))
	# --- Across the top and off Pride Rock ---
	var d: Vector3 = _pr_dir3()
	var top_y: float = PR_LIP.y + PR_KICK_H
	pts.append(PR_LIP - d * PR_RUN_UP)
	pts.append(PR_LIP - d * (PR_RUN_UP * 0.5))
	pts.append(PR_LIP)
	for x in [10.0, 25.0, 45.0, 70.0, 100.0, PR_HILL_LEN]:
		var p: Vector3 = PR_LIP + d * x
		p.y = top_y + _pr_hill(x)
		pts.append(p)
	var out: Vector3 = PR_LIP + d * (PR_HILL_LEN + 35.0)
	out.y = PR_OUT_Y
	pts.append(out)
	# --- West to the Mara, through the ford ---
	pts.append(Vector3(80.0, 5.4, -351.0))
	pts.append(Vector3(38.0, 4.4, -351.0))
	pts.append(Vector3(5.0, 2.8, -351.5))
	pts.append(Vector3(-35.0, -0.15, -352.0))
	pts.append(Vector3(-62.0, -0.7, -352.0))
	pts.append(Vector3(-89.0, -0.15, -352.0))
	pts.append(Vector3(-125.0, 3.0, -349.0))
	pts.append(Vector3(-175.0, 5.6, -338.0))
	# --- South past the hippo lake ---
	pts.append(Vector3(-240.0, 6.3, -306.0))
	pts.append(Vector3(-282.0, 6.5, -240.0))
	pts.append(Vector3(-294.0, 6.2, -140.0))
	pts.append(Vector3(-288.0, 5.8, -30.0))
	pts.append(Vector3(-274.0, 5.5, 80.0))
	# --- Baobab Bend and home ---
	pts.append(Vector3(-248.0, 5.2, 170.0))
	pts.append(Vector3(-200.0, 5.2, 245.0))
	pts.append(Vector3(-135.0, 5.6, 290.0))
	pts.append(Vector3(-70.0, PLAIN_Y, 305.0))
	pts.append(Vector3(-22.0, PLAIN_Y, 285.0))
	pts.append(Vector3(0.0, PLAIN_Y, 250.0))
	return pts


## The Croc Jump line, between two points on the main road.
func _croc_points() -> Array:
	var d: Vector3 = _croc_dir3()
	var lip := CROC_LIP
	var land: Vector3 = lip + d * CROC_GAP + Vector3(0, -CROC_LAND_DROP, 0)
	var pts: Array = []
	pts.append(Vector3(85.0, 5.6, -366.0))
	pts.append(Vector3(55.0, 5.4, -398.0))
	pts.append(Vector3(36.0, 5.2, -428.0))
	pts.append(lip - d * 45.0)
	pts.append(lip - d * 18.0)
	pts.append(lip)
	pts.append(land)
	pts.append(land + d * 22.0 + Vector3(0, 0.3, 0))
	pts.append(Vector3(-118.0, 4.5, -405.0))
	pts.append(Vector3(-150.0, 5.4, -366.0))
	return pts


## Handles for one control point from the directions and lengths of the segments either side
## (as Frostfall Gorge: tangent bisects the turn, length from Catmull-Rom or the turn radius,
## capped so the control polygon cannot fold).
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
	var curve := Curve3D.new()
	curve.bake_interval = BAKE_INTERVAL
	var handles: Array = []
	for i in range(n):
		var h: Array = _handles_for(points[i] - points[(i - 1 + n) % n], points[(i + 1) % n] - points[i], TRACK_MIN_RADIUS)
		handles.append(h)
		if h[2]:
			push_warning("Control point %d (%.0f, %.0f) wants a %.0fm radius but its chord only allows it" % [
				i, points[i].x, points[i].z, TRACK_MIN_RADIUS])
	for i in range(n + 1):
		var idx: int = i % n
		curve.add_point(points[idx], handles[idx][0], handles[idx][1])
	_straighten_jump_handles(curve)
	return curve


## A kicker throws the cart along the road's direction at the lip, so the run-up has to arrive
## straight: the handles either side of each lip point straight along the jump.
func _straighten_jump_handles(curve: Curve3D) -> void:
	for i in range(curve.point_count):
		var p: Vector3 = curve.get_point_position(i)
		var dir := Vector3.ZERO
		if p.distance_to(PR_LIP) < 0.01:
			dir = _pr_dir3()
		elif p.distance_to(CROC_LIP) < 0.01:
			dir = _croc_dir3()
		if dir == Vector3.ZERO:
			continue
		var hin: float = curve.get_point_in(i).length()
		var hout: float = curve.get_point_out(i).length()
		curve.set_point_in(i, -dir * hin)
		curve.set_point_out(i, dir * hout)


## The croc line as an open curve that leaves and rejoins the main road along its tangent.
func _build_croc_curve() -> Curve3D:
	var inner: Array = _croc_points()
	var start_off: float = main_curve.get_closest_offset(Vector3(124.0, 6.2, -351.4))
	var end_off: float = main_curve.get_closest_offset(Vector3(-182.0, 5.7, -336.0))
	var a: Dictionary = _frame_at_offset(main_curve, start_off)
	var b: Dictionary = _frame_at_offset(main_curve, end_off)
	var pts: Array = [a["pos"]]
	pts.append_array(inner)
	pts.append(b["pos"])
	var n: int = pts.size()
	var curve := Curve3D.new()
	curve.bake_interval = BAKE_INTERVAL
	for i in range(n):
		var hin := Vector3.ZERO
		var hout := Vector3.ZERO
		if i == 0:
			var l: float = (pts[1] - pts[0]).length() * 0.4
			hout = a["fwd"] * l
		elif i == n - 1:
			var l2: float = (pts[n - 1] - pts[n - 2]).length() * 0.4
			hin = -b["fwd"] * l2
		else:
			var h: Array = _handles_for(pts[i] - pts[i - 1], pts[i + 1] - pts[i], TRACK_MIN_RADIUS)
			hin = h[0]
			hout = h[1]
		curve.add_point(pts[i], hin, hout)
	_straighten_jump_handles(curve)
	return curve


func _frame_at(curve: Curve3D, off: float, closed: bool) -> Dictionary:
	var length: float = curve.get_baked_length()
	off = fposmod(off, length) if closed else clampf(off, 0.0, length)
	var c: Vector3 = curve.sample_baked(off)
	var a: float = off + 1.0
	var b: float = off
	if not closed and a > length:
		a = off
		b = off - 1.0
	var fwd: Vector3 = curve.sample_baked(fposmod(a, length) if closed else a) - curve.sample_baked(fposmod(b, length) if closed else b)
	fwd.y = 0.0
	fwd = fwd.normalized()
	return {"pos": c, "fwd": fwd, "right": Vector3(-fwd.z, 0.0, fwd.x), "off": off}


func _frame_at_offset(curve: Curve3D, off: float) -> Dictionary:
	return _frame_at(curve, off, curve == main_curve)


## Spots along a road: position on the ground, yaw facing travel, and the frame.
func _spot(curve: Curve3D, off: float, lat: float, lift: float) -> Dictionary:
	var f: Dictionary = _frame_at_offset(curve, off)
	var p: Vector3 = f["pos"] + f["right"] * lat
	p.y = _ground_at(p.x, p.z) + lift
	var fwd: Vector3 = f["fwd"]
	return {"pos": p, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": f["right"]}


func _main_off(p: Vector3) -> float:
	return main_curve.get_closest_offset(p)


## Offsets of the jumps, the croc line's junctions and the herd crossing.
func _resolve_features() -> void:
	var pd: Vector3 = _pr_dir3()
	_pr = {
		"lip": PR_LIP, "dir": pd, "lip_top": PR_LIP + Vector3(0, PR_KICK_H, 0),
		"lip_off": _main_off(PR_LIP),
		"hill_end_off": _main_off(PR_LIP + pd * PR_HILL_LEN),
	}
	var cd: Vector3 = _croc_dir3()
	var land: Vector3 = CROC_LIP + cd * CROC_GAP + Vector3(0, -CROC_LAND_DROP, 0)
	_croc = {
		"lip": CROC_LIP, "dir": cd, "lip_top": CROC_LIP + Vector3(0, CROC_KICK_H, 0), "land": land,
		"lip_off": croc_curve.get_closest_offset(CROC_LIP),
		"land_off": croc_curve.get_closest_offset(land),
		"start_off": _main_off(croc_curve.get_point_position(0)),
		"end_off": _main_off(croc_curve.get_point_position(croc_curve.point_count - 1)),
	}
	var hd: Vector2 = HERD_DIR.normalized()
	var c := Vector3(HERD_CROSS.x, 0.0, HERD_CROSS.y)
	var d3 := Vector3(hd.x, 0.0, hd.y)
	_herd_start = c - d3 * HERD_BEFORE
	_herd_end = c + d3 * HERD_AFTER
	print("  pride rock lip %.0fm along, croc line %.0fm..%.0fm (lip %.0fm along it), herd crossing %.0fm" % [
		_pr["lip_off"], _croc["start_off"], _croc["end_off"], _croc["lip_off"], _main_off(c + Vector3(0, 7, 0))])


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
			var dd := Vector2(a.x - b.x, a.z - b.z).length()
			worst = minf(worst, dd)
			if dd < 45.0:
				bad += 1
				if bad <= 6:
					push_error("Road runs within %.1fm of itself at %.0fm (%.0f, %.0f) and %.0fm (%.0f, %.0f)" % [
						dd, i * step, a.x, a.z, j * step, b.x, b.z])
	print("  plan: tightest self-approach %.1fm (%d close samples)" % [worst, bad])


## The croc line may only meet the main road at its two ends.
func _verify_croc_plan() -> void:
	var length: float = croc_curve.get_baked_length()
	var worst := 1e9
	var d := 70.0
	while d < length - 70.0:
		var p: Vector3 = croc_curve.sample_baked(d)
		var m: Vector3 = main_curve.get_closest_point(p)
		var dd: float = Vector2(p.x - m.x, p.z - m.z).length()
		worst = minf(worst, dd)
		if dd < 30.0:
			push_error("Croc line comes within %.1fm of the main road at %.0fm (%.0f, %.0f)" % [dd, d, p.x, p.z])
			break
		d += 4.0
	print("  croc line: %.0fm long, closest %.1fm to the main road between its junctions" % [length, worst])


func _verify_min_radius(curve: Curve3D, label: String, closed: bool) -> void:
	var length: float = curve.get_baked_length()
	var window := 8.0
	var worst := 1e9
	var worst_at := 0.0
	var start: int = 0 if closed else int(window)
	var stop: int = int(length) if closed else int(length - window)
	for i in range(start, stop):
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
	if worst < 22.0:
		push_error("%s turns to R=%.1fm at %.0fm (%.0f, %.0f)" % [label, worst, worst_at, at.x, at.z])
	else:
		print("  %s: min radius %.1fm at %.0fm (%.0f, %.0f)" % [label, worst, worst_at, at.x, at.z])


## Steepest grade along the main road and steepest cross slope beside it, and road samples the
## ground does not match (the landing hill and the croc gap are left out).
func _verify_road_ground() -> void:
	var length: float = main_curve.get_baked_length()
	var worst_grade := 0.0
	var worst_grade_at := 0.0
	var worst_cross := 0.0
	var worst_cross_at := Vector3.ZERO
	var off_ground := 0
	var d := 0.0
	while d < length:
		var on_hill: bool = d > _pr["lip_off"] - 2.0 and d < _pr["lip_off"] + 14.0
		if not on_hill:
			var f: Dictionary = _frame_at_offset(main_curve, d)
			var p: Vector3 = f["pos"]
			var p2: Vector3 = _frame_at_offset(main_curve, d + 4.0)["pos"]
			var g0: float = _ground_at(p.x, p.z)
			var grade: float = absf(_ground_at(p2.x, p2.z) - g0) / 4.0
			if grade > worst_grade:
				worst_grade = grade
				worst_grade_at = d
			var r: Vector3 = f["right"]
			var cross: float = absf(_ground_at(p.x + r.x * 6.0, p.z + r.z * 6.0) - _ground_at(p.x - r.x * 6.0, p.z - r.z * 6.0)) / 12.0
			if cross > worst_cross:
				worst_cross = cross
				worst_cross_at = p
			if absf(g0 - p.y) > 0.35:
				off_ground += 1
				if off_ground <= 5:
					push_error("Ground at %.0fm (%.0f, %.0f) is %.2fm off the road" % [d, p.x, p.z, g0 - p.y])
		d += 2.0
	print("  road: steepest grade %.1f%% at %.0fm, steepest cross slope %.1f%% at (%.0f, %.0f), %d samples off the ground" % [
		worst_grade * 100.0, worst_grade_at, worst_cross * 100.0, worst_cross_at.x, worst_cross_at.z, off_ground])
	if worst_grade > 0.18 or worst_cross > 0.08:
		push_error("Road ground too steep (grade %.0f%%, cross %.0f%%)" % [worst_grade * 100.0, worst_cross * 100.0])


## The ford has to be wet enough that PlayerCart wades (water contact: the water surface less
## than 0.8m below the cart's centre, which rides 1.35m over the road) and never deep (0.75m
## above the centre drowns it).
func _verify_ford() -> void:
	var length: float = main_curve.get_baked_length()
	var wet := 0.0
	var deepest := -INF
	var d := 0.0
	while d < length:
		var p: Vector3 = main_curve.sample_baked(d)
		var r: Dictionary = _river_at(p.x, p.z)
		if r["d"] < r["hw"]:
			var cart_y: float = _ground_at(p.x, p.z) + 1.35
			var depth: float = WATER_Y - cart_y
			if depth >= -0.8:
				wet += 2.0
			deepest = maxf(deepest, depth)
		d += 2.0
	print("  ford: %.0fm of the road wades the river, water %.2fm above the cart centre at the deepest" % [wet, deepest])
	if wet < 12.0:
		push_error("The ford is too shallow for the carts to wade it (%.0fm wet)" % wet)
	if deepest >= 0.7:
		push_error("The ford is deep enough to drown a cart")


## Flies a cart off each kicker at a range of speeds against the built ground.
func _verify_jumps() -> void:
	const G := 30.0
	const VCAP := 48.0
	var jumps: Array = [
		{"name": "PrideRock", "lip": _pr["lip_top"], "dir": _pr["dir"], "deg": PR_KICK_DEG, "min_land": 10.0,
			"speeds": [16.0, 22.0, 28.0, 34.0, 40.0, 48.0], "must": 16.0, "water": false},
		{"name": "CrocJump", "lip": _croc["lip_top"], "dir": _croc["dir"], "deg": CROC_KICK_DEG, "min_land": CROC_GAP - 1.0,
			"speeds": [24.0, 28.0, 30.0, 32.0, 36.0, 42.0, 50.0], "must": 32.0, "water": true},
	]
	for j in jumps:
		var line := ""
		var th: float = deg_to_rad(j["deg"])
		var dir: Vector3 = j["dir"]
		for v in j["speeds"]:
			var pos: Vector3 = j["lip"] + Vector3(0, 0.45, 0)
			var vel: Vector3 = dir * (v * cos(th)) + Vector3(0, v * sin(th), 0)
			var t := 0.0
			var dt := 1.0 / 120.0
			var x := 0.0
			var impact := 0.0
			var wet := false
			while t < 8.0:
				vel.y = maxf(vel.y - G * dt, -VCAP)
				pos += vel * dt
				t += dt
				x = Vector2(pos.x - j["lip"].x, pos.z - j["lip"].z).length()
				var gy: float = _ground_at(pos.x, pos.z)
				if j["water"] and pos.y - 0.45 <= WATER_Y and gy < WATER_Y:
					wet = true
					break
				if pos.y - 0.45 <= gy:
					var e := 0.6
					var slope: float = atan2(_ground_at(pos.x + dir.x * e, pos.z + dir.z * e) - _ground_at(pos.x - dir.x * e, pos.z - dir.z * e), 2.0 * e)
					var ang: float = atan2(vel.y, Vector2(vel.x, vel.z).length())
					impact = vel.length() * sin(absf(ang - slope))
					break
			if wet:
				line += "  %d m/s -> SPLASH at %.0fm" % [int(v), x]
			else:
				line += "  %d m/s -> %.0fm (impact %.0f)" % [int(v), x, impact]
			if v >= j["must"] and (wet or x < j["min_land"]):
				push_error("%s: a cart at %d m/s comes down %.1fm out, short of the landing (needs %.0fm)" % [j["name"], int(v), x, j["min_land"]])
		print("  %s:%s" % [j["name"], line])


## The herd must cross the road only on the Migration Plain.
func _verify_herd() -> void:
	var length: float = (_herd_end - _herd_start).length()
	var dir: Vector3 = (_herd_end - _herd_start) / length
	var crossings := 0
	var s := 0.0
	var was_on := false
	while s <= length:
		var p: Vector3 = _herd_start + dir * s
		var on: bool = _road_distance(p.x, p.z) < ROAD_FLAT + HERD_HALF_W
		if on and not was_on:
			crossings += 1
		was_on = on
		s += 2.0
	if crossings != 1:
		push_error("The herd's stream crosses a road %d times (should be once, on the plain)" % crossings)
	else:
		print("  herd: stream crosses the road once, %.0fm long" % length)


# ======================================================================================
#  Ground
# ======================================================================================

func _init_noise() -> void:
	_base_noise.seed = 4471
	_base_noise.frequency = 0.0035
	_base_noise.fractal_octaves = 3
	_detail_noise.seed = 913
	_detail_noise.frequency = 0.03
	_detail_noise.fractal_octaves = 2
	_lump_noise.seed = 2206
	_lump_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_lump_noise.frequency = 0.06
	_lump_noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	_far_noise.seed = 77
	_far_noise.frequency = 0.0011
	_far_noise.fractal_octaves = 4


## Nearest point of the river: distance, and the river's half width, depth, bank steepness and
## floodplain weight there.
func _river_at(x: float, z: float) -> Dictionary:
	var q := Vector2(x, z)
	var best_d := 1e9
	var best_i := 0
	var best_t := 0.0
	for i in range(RIVER.size() - 1):
		var a: Vector2 = RIVER[i][0]
		var b: Vector2 = RIVER[i + 1][0]
		var ab: Vector2 = b - a
		var t: float = clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var dd: float = q.distance_to(a + ab * t)
		if dd < best_d:
			best_d = dd
			best_i = i
			best_t = t
	var r0: Array = RIVER[best_i]
	var r1: Array = RIVER[best_i + 1]
	return {
		"d": best_d,
		"hw": lerpf(r0[1], r1[1], best_t),
		"depth": lerpf(r0[2], r1[2], best_t),
		"bank": lerpf(r0[3], r1[3], best_t),
		"flood": lerpf(r0[4], r1[4], best_t),
	}


func _lake_e(x: float, z: float) -> float:
	var e: float = Vector2((x - LAKE_CENTER.x) / LAKE_RADIUS.x, (z - LAKE_CENTER.y) / LAKE_RADIUS.y).length()
	# A ragged shore, with bays and spits, rather than a drawn ellipse.
	return e + _base_noise.get_noise_2d(x * 6.0, z * 6.0) * 0.16


func _in_water(x: float, z: float) -> bool:
	var r: Dictionary = _river_at(x, z)
	return r["d"] < r["hw"] + 1.0 or _lake_e(x, z) < 1.02


## Kopje lift and rockiness at (x, z): tors with a flat top and steep granite flanks.
func _kopje(x: float, z: float) -> Vector2:
	var lift := 0.0
	var rock := 0.0
	for k in KOPJES:
		var c: Vector2 = k[0]
		var r: float = k[1]
		var dd: float = Vector2(x, z).distance_to(c)
		if dd >= r * 1.15:
			continue
		var kk: float = clampf(1.0 - pow(dd / r, 2.0), 0.0, 1.0)
		var top: float = smoothstep(0.0, 0.6, kk)
		# Rounded boulders heaped on the top and flanks.
		var lumps: float = (1.0 - _lump_noise.get_noise_2d(x, z)) * 0.5
		lift = maxf(lift, float(k[2]) * top + lumps * lumps * 4.5 * smoothstep(0.0, 0.3, kk))
		rock = maxf(rock, smoothstep(0.02, 0.22, kk))
	return Vector2(lift, rock)


## The landscape before any road or water: a gently rolling plain, kopjes, the floodplain of the
## river and lake, and hills and the Rift escarpment far out on the horizon.
func _base_height(x: float, z: float) -> float:
	var h: float = PLAIN_Y + _base_noise.get_noise_2d(x, z) * 2.6 + _detail_noise.get_noise_2d(x, z) * 0.25
	h += _kopje(x, z).x
	var r: Dictionary = _river_at(x, z)
	var wf: float = (1.0 - smoothstep(r["hw"] + 15.0, r["hw"] + 150.0, r["d"])) * r["flood"]
	wf = maxf(wf, 1.0 - smoothstep(1.15, 3.0, _lake_e(x, z)))
	h = lerpf(h, FLOOD_Y + _detail_noise.get_noise_2d(x * 0.5, z * 0.5) * 0.4, wf * 0.9)
	# The horizon: rolling hills beyond the plain, the Rift escarpment rising in the west.
	var far: float = Vector2(x - 70.0, z + 70.0).length()
	var hills: float = smoothstep(650.0, 1700.0, far)
	h += hills * (_far_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 120.0
	h += smoothstep(-1100.0, -2300.0, x) * 260.0 * (0.8 + _far_noise.get_noise_2d(x * 0.3, z * 2.0) * 0.4)
	return h


## Height the river and lake allow at (x, z): their beds, and banks rising at their steepness.
func _water_cap(x: float, z: float) -> float:
	var r: Dictionary = _river_at(x, z)
	var cap: float
	var hw: float = r["hw"]
	if r["d"] < hw:
		cap = WATER_Y - 0.25 - r["depth"] * (1.0 - pow(r["d"] / hw, 2.0))
	else:
		cap = WATER_Y - 0.25 + (r["d"] - hw) * r["bank"]
	var e: float = _lake_e(x, z)
	var lake_cap: float
	if e < 1.0:
		lake_cap = WATER_Y - 0.25 - LAKE_DEPTH * (1.0 - e * e)
	else:
		lake_cap = WATER_Y - 0.25 + (e - 1.0) * minf(LAKE_RADIUS.x, LAKE_RADIUS.y) * 0.3
	return minf(cap, lake_cap)


func _add_road_samples(curve: Curve3D, closed: bool, gap_from: float, gap_to: float) -> void:
	var length: float = curve.get_baked_length()
	var first: int = _rs_pos.size()
	var n: int = int(floor(length / SAMPLE_STEP)) + (0 if closed else 1)
	for k in range(n):
		var d: float = minf(float(k) * SAMPLE_STEP, length)
		var f: Dictionary = _frame_at(curve, d, closed)
		var idx: int = _rs_pos.size()
		_rs_pos.append(f["pos"])
		_rs_right.append(f["right"])
		_rs_gap.append(1 if d > gap_from and d < gap_to else 0)
		_rs_next.append(idx + 1)
		var key := Vector2i(floori(f["pos"].x / CELL), floori(f["pos"].z / CELL))
		var bucket: PackedInt32Array = _rs_cells.get(key, PackedInt32Array())
		bucket.append(idx)
		_rs_cells[key] = bucket
	var last: int = _rs_pos.size() - 1
	_rs_next[last] = first if closed else -1


func _build_road_samples() -> void:
	_rs_pos = PackedVector3Array()
	_rs_right = PackedVector3Array()
	_rs_next = PackedInt32Array()
	_rs_gap = PackedByteArray()
	_rs_cells.clear()
	_add_road_samples(main_curve, true, -1.0, -1.0)
	_add_road_samples(croc_curve, false, _croc["lip_off"] - 0.5, _croc["land_off"] + 0.5)
	print("  road samples: %d" % _rs_pos.size())


## Clamps `h` between the fill and cut bounds of every road segment within reach. Returns the
## graded height and, where (x, z) lies beside a segment inside the flat strip, that segment's
## road height (else NAN), which the ford puts back after the river is carved.
func _grade(h: float, x: float, z: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = _rs_next[i]
				if j < 0 or _rs_gap[i] == 1 or _rs_gap[j] == 1:
					continue
				var a: Vector3 = _rs_pos[i]
				var dx: float = x - a.x
				var dz: float = z - a.z
				if dx * dx + dz * dz > GRADE_REACH * GRADE_REACH:
					continue
				var b: Vector3 = _rs_pos[j]
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
				var over: float = maxf(0.0, lateral - ROAD_FLAT)
				# Rounded shoulder, so there is no crease at the edge of the flat strip.
				var soft: float = over * over / (over + 4.0)
				upper = minf(upper, foot_y + soft * CUT_SLOPE + excess * CUT_SLOPE)
				lower = maxf(lower, foot_y - soft * FILL_SLOPE - excess * FILL_SLOPE)
				touched = true
				if excess < 0.01 and lateral <= ROAD_FLAT and lateral < flat_lat:
					flat_lat = lateral
					flat_y = foot_y
	if not touched:
		return Vector2(h, NAN)
	if lower > upper:
		return Vector2(upper, flat_y)
	return Vector2(clampf(h, lower, upper), flat_y)


## Distance to the nearest road centreline (any road, jump flights excluded), and the signed
## lateral across it (+ right of travel).
func _road_lat(x: float, z: float, reach: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e9
	var lat := 0.0
	var span: int = 1 if reach <= CELL else 2
	for gz in range(cz - span, cz + span + 1):
		for gx in range(cx - span, cx + span + 1):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = _rs_next[i]
				if j < 0 or _rs_gap[i] == 1 or _rs_gap[j] == 1:
					continue
				var a: Vector3 = _rs_pos[i]
				var b: Vector3 = _rs_pos[j]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = maxf(sx * sx + sz * sz, 1e-6)
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var dd: float = fx * fx + fz * fz
				if dd < best:
					best = dd
					lat = fx * _rs_right[i].x + fz * _rs_right[i].z
	return Vector2(sqrt(best), lat)


func _road_distance(x: float, z: float) -> float:
	return _road_lat(x, z, 80.0).x


func _grid_axis(fine: Vector2, outer: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
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
	_road_d = PackedFloat32Array()
	_road_d.resize(nx * nz)
	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var g: Vector2 = _grade(_base_height(x, z), x, z)
			var h: float = minf(g.x, _water_cap(x, z))
			if not is_nan(g.y):
				h = g.y
			_heights[iz * nx + ix] = h
			_road_d[iz * nx + ix] = _road_lat(x, z, 20.0).x


## Ground height at any (x, z) from the built heightfield, interpolated like the triangles.
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


## Vertex-colour masks for savanna_ground.gdshader: granite, road band, wet, lateral.
func _terrain_masks(x: float, z: float, h: float) -> Color:
	var rl: Vector2 = _road_lat(x, z, 20.0)
	var band: float = 1.0 - smoothstep(12.0, 14.0, rl.x)
	var kop: Vector2 = _kopje(x, z)
	var rock: float = kop.y
	# Rock shows where the ground is cut well below the kopje's natural surface (the road's
	# cuttings through the tor), never on the road itself.
	var natural: float = _base_height(x, z)
	if kop.y > 0.05 and natural - h > 1.2:
		rock = maxf(rock, smoothstep(1.2, 2.5, natural - h))
	rock *= smoothstep(ROAD_HALF + 0.5, ROAD_HALF + 2.5, rl.x)
	var wet := 0.0
	var r: Dictionary = _river_at(x, z)
	var near_water: bool = r["d"] < r["hw"] + 30.0 or _lake_e(x, z) < 1.5
	if near_water:
		wet = 1.0 - smoothstep(0.2, 1.6, h - WATER_Y)
		if h < WATER_Y - 0.15:
			wet = 1.0
	# The real lateral wherever it is known, even off the band: a vertex just outside it written
	# as 0 (the centreline) interpolates a ghost strip of road across the triangles in between.
	var lat_enc: float = clampf(rl.y / 24.0 + 0.5, 0.0, 1.0) if rl.x < 1000.0 else 1.0
	return Color(rock, band, wet, lat_enc)


## Terrain mesh with the shader masks in the vertex colour, and its collision split into the
## road and the savanna.
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
			colors[i] = _terrain_masks(x, z, h) if _road_d[i] < 60.0 or _near_detail(x, z) else Color(_kopje(x, z).y, 0.0, 0.0, 0.5)
	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var road_faces := PackedVector3Array()
	var ground_faces := PackedVector3Array()
	var w := 0
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var i: int = iz * nx + ix
			var tris := [[i, i + 1, i + nx], [i + 1, i + nx + 1, i + nx]]
			for tri in tris:
				indices[w] = tri[0]
				indices[w + 1] = tri[1]
				indices[w + 2] = tri[2]
				w += 3
				# Packed arrays are values: append to each by name, never through an alias.
				if _road_d[tri[0]] < ROAD_COLLIDE and _road_d[tri[1]] < ROAD_COLLIDE and _road_d[tri[2]] < ROAD_COLLIDE:
					road_faces.append(verts[tri[0]])
					road_faces.append(verts[tri[1]])
					road_faces.append(verts[tri[2]])
				else:
					ground_faces.append(verts[tri[0]])
					ground_faces.append(verts[tri[1]])
					ground_faces.append(verts[tri[2]])
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

	var ground_body := StaticBody3D.new()
	ground_body.name = "SavannaGround"
	parent.add_child(ground_body)
	var inst := MeshInstance3D.new()
	inst.name = "SavannaGroundMesh"
	inst.mesh = _save_baked_resource(mesh, "ground_visual")
	ground_body.add_child(inst)
	var gshape := ConcavePolygonShape3D.new()
	gshape.set_faces(ground_faces)
	gshape.backface_collision = true
	var gcol := CollisionShape3D.new()
	gcol.name = "SavannaGroundShape"
	gcol.shape = _save_baked_resource(gshape, "ground_collision_shape")
	ground_body.add_child(gcol)

	# Same surface, other body: the strip PlayerCart should count as road.
	var road_body := StaticBody3D.new()
	road_body.name = "MurramRoad"
	parent.add_child(road_body)
	var rshape := ConcavePolygonShape3D.new()
	rshape.set_faces(road_faces)
	rshape.backface_collision = true
	var rcol := CollisionShape3D.new()
	rcol.name = "MurramRoadShape"
	rcol.shape = _save_baked_resource(rshape, "road_collision_shape")
	road_body.add_child(rcol)
	print("  ground: %d triangles, %d of them road" % [indices.size() / 3, road_faces.size() / 3])


## The masks only matter where someone can see them closely: within the fine grid.
func _near_detail(x: float, z: float) -> bool:
	return x > FINE_X.x - 60.0 and x < FINE_X.y + 60.0 and z > FINE_Z.x - 60.0 and z < FINE_Z.y + 60.0


# ======================================================================================
#  Water
# ======================================================================================

func _build_river_water_node(parent: Node) -> void:
	var node := Node3D.new()
	node.name = "RiverWater"
	node.set_script(RiverWaterScript)
	var pts := PackedVector3Array()
	var hws := PackedFloat32Array()
	var starts := PackedInt32Array([0])
	var bounds := Rect2(RIVER[0][0], Vector2.ZERO)
	for r in RIVER:
		var c: Vector2 = r[0]
		var hw: float = r[1] + 1.0
		pts.append(Vector3(c.x, WATER_Y, c.y))
		hws.append(hw)
		bounds = bounds.expand(c - Vector2(hw + 4.0, hw + 4.0))
		bounds = bounds.expand(c + Vector2(hw + 4.0, hw + 4.0))
	# The lake as overlapping pools along its long axis.
	var pools: Array[Vector4] = []
	for k in range(-3, 4):
		var px: float = LAKE_CENTER.x + float(k) * LAKE_RADIUS.x * 0.22
		var ex: float = (px - LAKE_CENTER.x) / LAKE_RADIUS.x
		var rad: float = LAKE_RADIUS.y * sqrt(maxf(1.0 - ex * ex, 0.05)) + 1.0
		pools.append(Vector4(px, WATER_Y, LAKE_CENTER.y, rad))
		bounds = bounds.expand(Vector2(px - rad, LAKE_CENTER.y - rad))
		bounds = bounds.expand(Vector2(px + rad, LAKE_CENTER.y + rad))
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
	nt.bump_strength = 4.0
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
	# A brown savanna river: silty, warm, slow.
	mat.set_shader_parameter("deep_color", Vector3(0.06, 0.045, 0.025))
	mat.set_shader_parameter("shallow_color", Vector3(0.22, 0.15, 0.08))
	# Muddy scum at the waterline, not white surf.
	mat.set_shader_parameter("foam_color", Vector3(0.36, 0.30, 0.22))
	mat.set_shader_parameter("sky_tint", Vector3(0.42, 0.40, 0.36))
	mat.set_shader_parameter("flow_speed", 0.6)
	mat.set_shader_parameter("clarity_depth", 0.9)
	mat.set_shader_parameter("shore_foam_depth", 0.15)
	return mat


## One flat water sheet over the river and the lake: a grid clipped to where there is water.
func _build_water_mesh(parent: Node, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 4.0
	var x0 := -260.0
	var x1 := 60.0
	var z0 := -1750.0
	var z1 := -70.0
	var cols: int = int((x1 - x0) / step)
	var rows: int = int((z1 - z0) / step)
	var count := 0
	for iz in range(rows):
		for ix in range(cols):
			var ax: float = x0 + ix * step
			var az: float = z0 + iz * step
			var cxm: float = ax + step * 0.5
			var czm: float = az + step * 0.5
			var r: Dictionary = _river_at(cxm, czm)
			if r["d"] > r["hw"] + 3.5 and _lake_e(cxm, czm) > 1.08:
				continue
			var a := Vector3(ax, WATER_Y, az)
			var b := Vector3(ax + step, WATER_Y, az)
			var c := Vector3(ax + step, WATER_Y, az + step)
			var d := Vector3(ax, WATER_Y, az + step)
			for v in [a, b, c, a, c, d]:
				st.set_normal(Vector3.UP)
				st.set_color(Color(0.0, 0.0, 0.0, 1.0))
				st.set_uv(Vector2(v.x, v.z) * 0.05)
				st.add_vertex(v)
			count += 1
	var mesh: ArrayMesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "RiverSurface"
	mi.mesh = _save_baked_resource(mesh, "water_visual")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("water_surface_y", WATER_Y)
	parent.add_child(mi)
	print("  water: %d cells" % count)


# ======================================================================================
#  Mesh helpers
# ======================================================================================

## Appends triangle a-b-c to `faces`, ordered so its front face looks along `out_hint`. Godot
## front faces wind clockwise, with face normal (c - a) x (b - a) (CLAUDE.md, "Procedural mesh
## winding").
func _tri_out(faces: Array, a: Vector3, b: Vector3, c: Vector3, out_hint: Vector3) -> void:
	if (c - a).cross(b - a).dot(out_hint) < 0.0:
		faces.append_array([a, c, b])
	else:
		faces.append_array([a, b, c])


func _quad_out(faces: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out_hint: Vector3) -> void:
	_tri_out(faces, a, b, c, out_hint)
	_tri_out(faces, a, c, d, out_hint)


func _faces_to_mesh(faces: Array, uv_scale: float, color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		var nrm: Vector3 = (c - a).cross(b - a).normalized()
		for v in [a, b, c]:
			st.set_normal(nrm)
			st.set_color(color)
			st.set_uv(Vector2(v.x + v.y, v.z + v.y) * uv_scale)
			st.add_vertex(v)
	return st.commit()


## A vertex with every attribute the procedural meshes use.
class V:
	var p: Vector3
	var col: Color
	var uv: Vector2
	var uv2: Vector2
	func _init(pos: Vector3, c: Color, u: Vector2 = Vector2.ZERO, u2: Vector2 = Vector2.ZERO) -> void:
		p = pos
		col = c
		uv = u
		uv2 = u2


## Collects triangles of V with winding fixed against an outward hint, then builds one indexed,
## smooth-shaded ArrayMesh.
class MeshBuilder:
	var tris: Array = []

	func tri(a: V, b: V, c: V, out_hint: Vector3) -> void:
		if (c.p - a.p).cross(b.p - a.p).dot(out_hint) < 0.0:
			tris.append_array([a, c, b])
		else:
			tris.append_array([a, b, c])

	func quad(a: V, b: V, c: V, d: V, out_hint: Vector3) -> void:
		tri(a, b, c, out_hint)
		tri(a, c, d, out_hint)

	## A tapered tube along `path` (rings of `sides` vertices), capped at both ends. `attr` maps a
	## ring index to [Color, uv, uv2] so callers can rig legs, necks and tails.
	func tube(path: Array, radii: Array, sides: int, attr: Callable, cap_start := true, cap_end := true) -> void:
		var rings: Array = []
		for k in range(path.size()):
			var p: Vector3 = path[k]
			var t: Vector3
			if k == 0:
				t = path[1] - path[0]
			elif k == path.size() - 1:
				t = path[k] - path[k - 1]
			else:
				t = path[k + 1] - path[k - 1]
			t = t.normalized()
			var ref: Vector3 = Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
			var u: Vector3 = t.cross(ref).normalized()
			var v: Vector3 = t.cross(u).normalized()
			var a: Array = attr.call(k)
			var ring: Array = []
			for s in range(sides):
				var ang: float = TAU * float(s) / float(sides)
				var q: Vector3 = p + (u * cos(ang) + v * sin(ang)) * float(radii[k])
				ring.append(V.new(q, a[0], a[1], a[2]))
			rings.append(ring)
		for k in range(path.size() - 1):
			var mid: Vector3 = (path[k] + path[k + 1]) * 0.5
			for s in range(sides):
				var s2: int = (s + 1) % sides
				var a0: V = rings[k][s]
				var a1: V = rings[k][s2]
				var b0: V = rings[k + 1][s]
				var b1: V = rings[k + 1][s2]
				var hint: Vector3 = (a0.p + a1.p + b0.p + b1.p) * 0.25 - mid
				quad(a0, a1, b1, b0, hint)
		if cap_start:
			var c0: Array = attr.call(0)
			var centre := V.new(path[0], c0[0], c0[1], c0[2])
			var out0: Vector3 = (path[0] - path[1]).normalized()
			for s in range(sides):
				tri(centre, rings[0][s], rings[0][(s + 1) % sides], out0)
		if cap_end:
			var last: int = path.size() - 1
			var c1: Array = attr.call(last)
			var centre2 := V.new(path[last], c1[0], c1[1], c1[2])
			var out1: Vector3 = (path[last] - path[last - 1]).normalized()
			for s in range(sides):
				tri(centre2, rings[last][s], rings[last][(s + 1) % sides], out1)

	## A lumpy ellipsoid: `lon` x `lat` segments, radii `r`, each vertex pushed out by `jitter`
	## times noise.
	func blob(center: Vector3, r: Vector3, lon: int, lat: int, col: Color, noise: FastNoiseLite, jitter: float, flat_bottom := false) -> void:
		var grid: Array = []
		for j in range(lat + 1):
			var phi: float = PI * float(j) / float(lat)
			var row: Array = []
			for i in range(lon):
				var th: float = TAU * float(i) / float(lon)
				var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
				var bump: float = 1.0 + noise.get_noise_3dv(center + dir * 7.0) * jitter
				var p: Vector3 = center + Vector3(dir.x * r.x, dir.y * r.y, dir.z * r.z) * bump
				if flat_bottom and p.y < center.y - r.y * 0.35:
					p.y = center.y - r.y * 0.35
				var shade: float = 0.75 + 0.25 * (dir.y * 0.5 + 0.5)
				row.append(V.new(p, Color(col.r * shade, col.g * shade, col.b * shade, col.a)))
			grid.append(row)
		for j in range(lat):
			for i in range(lon):
				var i2: int = (i + 1) % lon
				var a: V = grid[j][i]
				var b: V = grid[j][i2]
				var c: V = grid[j + 1][i2]
				var d: V = grid[j + 1][i]
				var hint: Vector3 = (a.p + b.p + c.p + d.p) * 0.25 - center
				if j == 0:
					tri(a, c, d, hint)
				elif j == lat - 1:
					tri(a, b, c, hint)
				else:
					quad(a, b, c, d, hint)

	func commit(with_uv2 := false) -> ArrayMesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in tris:
			st.set_color(v.col)
			st.set_uv(v.uv)
			if with_uv2:
				st.set_uv2(v.uv2)
			st.add_vertex(v.p)
		st.index()
		st.generate_normals()
		return st.commit()


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


func _multimesh(mesh: Mesh, transforms: Array, node_name: String) -> MultiMeshInstance3D:
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


func _vertex_color_material(rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# The palettes here are picked as sRGB colours, like any albedo.
	m.vertex_color_is_srgb = true
	m.roughness = rough
	return m


# ======================================================================================
#  Kickers
# ======================================================================================

## A circular-arc kicker rising to `height` at `deg`, with a sheer front face and sloped sides.
## Built in local space with travel along -Z: the ramp starts at the origin and the lip edge is
## `length` metres ahead. Same shape as Frostfall Gorge's.
func _kicker_mesh(height: float, deg: float, width: float, color: Color) -> Array:
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
	return [_faces_to_mesh(faces, 0.25, color), PackedVector3Array(faces), length]


## Named "...Jump..." so PlayerCart counts the kicker as track.
func _place_kicker(parent: Node, kname: String, lip: Vector3, dir: Vector3, height: float, deg: float,
		width: float, mat: Material, color: Color) -> void:
	var data: Array = _kicker_mesh(height, deg, width, color)
	var length: float = data[2]
	var body := StaticBody3D.new()
	body.name = kname
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


# ======================================================================================
#  Wildlife
# ======================================================================================

## Wildebeest, facing -Z, hooves at y = 0, rigged for wildebeest.gdshader.
func _wildebeest_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var body_attr := func(_k: int) -> Array: return [Color(0, 0, 0, 1), Vector2(0.0, 0.0), Vector2.ZERO]
	# Body: rump to shoulder hump, sloping down to the rear like a real gnu.
	mb.tube([Vector3(0, 1.02, 0.95), Vector3(0, 1.08, 0.45), Vector3(0, 1.16, -0.1), Vector3(0, 1.28, -0.55), Vector3(0, 1.22, -0.8)],
			[0.22, 0.36, 0.42, 0.44, 0.3], 7, body_attr)
	# Neck and head: dark, nodding with the stride about the withers.
	var neck_pivot := Vector2(1.25, -0.7)
	var head_attr := func(_k: int) -> Array: return [Color(0, 0, 1, 1), Vector2(0.5, 0.0), neck_pivot]
	mb.tube([Vector3(0, 1.3, -0.7), Vector3(0, 1.22, -1.0), Vector3(0, 1.0, -1.22), Vector3(0, 0.74, -1.36), Vector3(0, 0.6, -1.42)],
			[0.26, 0.21, 0.17, 0.13, 0.1], 6, head_attr)
	# Mane along the top of the neck.
	mb.tube([Vector3(0, 1.48, -0.55), Vector3(0, 1.42, -0.85), Vector3(0, 1.25, -1.05)], [0.07, 0.08, 0.05], 4, head_attr)
	# Beard under the throat.
	mb.tube([Vector3(0, 1.02, -1.0), Vector3(0, 0.82, -1.08), Vector3(0, 0.66, -1.06)], [0.06, 0.07, 0.03], 4, head_attr)
	# Horns: out sideways, then up and in.
	var horn_attr := func(_k: int) -> Array: return [Color(0, 0, 1, 1), Vector2(1.0, 0.0), neck_pivot]
	for sx in [-1.0, 1.0]:
		mb.tube([Vector3(sx * 0.06, 1.12, -1.18), Vector3(sx * 0.22, 1.15, -1.16), Vector3(sx * 0.3, 1.28, -1.12), Vector3(sx * 0.24, 1.38, -1.14)],
				[0.05, 0.045, 0.035, 0.015], 4, horn_attr)
	# Legs: hip to hoof, the swing weight growing toward the hoof. Gallop phases per leg.
	var legs := [[-0.17, -0.55, 0.0], [0.17, -0.55, 0.12], [-0.15, 0.7, 0.5], [0.15, 0.7, 0.62]]
	for leg in legs:
		var lx: float = leg[0]
		var lz: float = leg[1]
		var ph: float = leg[2]
		var hip: float = 1.02
		var pivot := Vector2(hip, lz)
		var ys := [hip, 0.62, 0.3, 0.02]
		var leg_attr := func(k: int) -> Array:
			var wgt: float = clampf((hip - float(ys[k])) / hip, 0.0, 1.0)
			return [Color(wgt, ph, 0, 1), Vector2(0.0 if k < 2 else 0.5, 0.0), pivot]
		mb.tube([Vector3(lx, ys[0], lz), Vector3(lx, ys[1], lz + 0.03), Vector3(lx, ys[2], lz - 0.02), Vector3(lx, ys[3], lz)],
				[0.11, 0.07, 0.05, 0.05], 5, leg_attr)
	# Tail: swings like a leg.
	var tail_attr := func(k: int) -> Array: return [Color(0.25 * k, 0.3, 0, 1), Vector2(0.5, 0.0), Vector2(1.05, 0.98)]
	mb.tube([Vector3(0, 1.05, 0.98), Vector3(0, 0.85, 1.08), Vector3(0, 0.6, 1.1)], [0.04, 0.035, 0.06], 4, tail_attr)
	return mb.commit(true)


## Giraffe, facing -Z, hooves at y = 0. Vertex colour b weights the neck's slow browse sway
## (pivot at the withers in UV2), which the inline shader animates; the coat is drawn by the
## shader's reticulated patches.
func _giraffe_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var body := func(_k: int) -> Array: return [Color(0, 0, 0, 1), Vector2(0, 0), Vector2.ZERO]
	mb.tube([Vector3(0, 2.0, 0.75), Vector3(0, 2.15, 0.2), Vector3(0, 2.35, -0.45), Vector3(0, 2.45, -0.8)], [0.3, 0.42, 0.45, 0.32], 7, body)
	var pivot := Vector2(2.5, -0.75)
	var neck := func(_k: int) -> Array: return [Color(0, 0, 1, 1), Vector2(0, 0), pivot]
	mb.tube([Vector3(0, 2.45, -0.8), Vector3(0, 3.3, -1.15), Vector3(0, 4.2, -1.45), Vector3(0, 4.9, -1.6)], [0.3, 0.2, 0.15, 0.13], 6, neck)
	mb.tube([Vector3(0, 4.95, -1.5), Vector3(0, 4.85, -1.9), Vector3(0, 4.7, -2.15)], [0.15, 0.12, 0.08], 6, neck)
	var horn := func(_k: int) -> Array: return [Color(0, 0, 1, 1), Vector2(0.5, 0), pivot]
	for sx in [-0.07, 0.07]:
		mb.tube([Vector3(sx, 5.05, -1.55), Vector3(sx, 5.28, -1.5)], [0.035, 0.045], 4, horn)
	for leg in [[-0.2, -0.55], [0.2, -0.55], [-0.18, 0.62], [0.18, 0.62]]:
		var leg_a := func(k: int) -> Array: return [Color(0, 0, 0, 1), Vector2(0.5 if k >= 2 else 0.0, 0), Vector2.ZERO]
		mb.tube([Vector3(leg[0], 2.1, leg[1]), Vector3(leg[0], 1.1, leg[1] + 0.03), Vector3(leg[0], 0.45, leg[1] - 0.02), Vector3(leg[0], 0.02, leg[1])],
				[0.12, 0.08, 0.06, 0.06], 5, leg_a)
	mb.tube([Vector3(0, 2.05, 0.78), Vector3(0, 1.5, 0.9), Vector3(0, 1.1, 0.92)], [0.04, 0.03, 0.06], 4, body)
	return mb.commit(true)


func _giraffe_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
// Giraffe coat: tan lines between rust-brown patches (a Voronoi pattern on the model's own
// coordinates), dark lower legs and ossicones. The neck sways slowly as it browses.
varying vec3 lp;
varying float dark;
vec2 h2(vec2 p) { p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
void vertex() {
	lp = VERTEX;
	dark = UV.x;
	if (COLOR.b > 0.5) {
		float a = sin(TIME * 0.45 + float(INSTANCE_ID) * 1.7) * 0.10;
		float y = VERTEX.y - UV2.x;
		float z = VERTEX.z - UV2.y;
		VERTEX.y = UV2.x + y * cos(a) - z * sin(a);
		VERTEX.z = UV2.y + y * sin(a) + z * cos(a);
	}
}
void fragment() {
	vec2 p = vec2(lp.z * 3.2 + lp.x * 1.3, lp.y * 3.2);
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h2(i + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	float line = 1.0 - smoothstep(0.05, 0.12, d2 - d1);
	vec3 patch_col = vec3(0.50, 0.26, 0.10);
	vec3 line_col = vec3(0.90, 0.80, 0.60);
	vec3 c = mix(patch_col, line_col, line);
	c = mix(c, vec3(0.20, 0.14, 0.10), smoothstep(0.25, 0.5, dark));
	ALBEDO = c;
	ROUGHNESS = 0.8;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _rumble_stream() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 4.0
	var n: int = int(RATE * SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7181
	var samples := PackedFloat32Array()
	samples.resize(n)
	var brown := 0.0
	var thud := 0.0
	for i in range(n):
		var white: float = rng.randf_range(-1.0, 1.0)
		brown = clampf(brown * 0.993 + white * 0.07, -1.0, 1.0)
		# Hoofbeats: random low thuds, a few dozen a second across the herd.
		if rng.randf() < 0.0016:
			thud = rng.randf_range(0.5, 1.0)
		thud *= 0.9965
		var beat: float = sin(float(i) / RATE * TAU * rng.randf_range(38.0, 46.0)) * thud
		samples[i] = brown * 0.7 + beat * 0.6
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
	return _save_baked_resource(wav, "herd_rumble") as AudioStreamWAV


func _soft_dust_material() -> StandardMaterial3D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.albedo_color = Color(0.82, 0.58, 0.40, 0.42)
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.5
	return m


func _build_herd(parent: Node) -> void:
	var herd := Node3D.new()
	herd.name = "MigrationHerd"
	herd.set_script(HerdScript)
	var length: float = (_herd_end - _herd_start).length()
	var dir: Vector3 = (_herd_end - _herd_start) / length
	var right := Vector3(-dir.z, 0.0, dir.x)
	herd.set("path_start", _herd_start)
	herd.set("path_end", _herd_end)
	herd.set("half_width", HERD_HALF_W)
	herd.set("loop_length", length + 40.0)
	var step := 2.0
	var cols: int = int(ceil(2.0 * HERD_HALF_W / step)) + 3
	var rows := PackedFloat32Array()
	var s := 0.0
	while s <= length + step:
		for c in range(cols):
			var lat: float = -HERD_HALF_W - step + float(c) * step
			var p: Vector3 = _herd_start + dir * s + right * lat
			rows.append(_ground_at(p.x, p.z))
		s += step
	herd.set("ground_rows", rows)
	herd.set("ground_cols", cols)
	herd.set("ground_step", step)
	herd.set("rumble_stream", _rumble_stream())
	parent.add_child(herd)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _save_baked_resource(_wildebeest_mesh(), "wildebeest")
	mm.instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Animals"
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://wildebeest.gdshader")
	mmi.material_override = mat
	# Instances move every frame across a wide band; give the culler the whole stream.
	mmi.custom_aabb = AABB(Vector3(-400, -50, -400), Vector3(800, 120, 800))
	herd.add_child(mmi)
	for k in range(3):
		var dust := GPUParticles3D.new()
		dust.name = "Dust_%d" % k
		dust.amount = 70
		dust.lifetime = 3.2
		dust.local_coords = false
		dust.emitting = false
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dust.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 30, 80))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(HERD_HALF_W, 0.4, 16.0)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 50.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 2.2
		pm.gravity = Vector3(0, 0.25, 0)
		pm.damping_min = 0.4
		pm.damping_max = 0.8
		pm.scale_min = 3.0
		pm.scale_max = 6.5
		var alpha := Gradient.new()
		alpha.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		alpha.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		var at := GradientTexture1D.new()
		at.gradient = alpha
		pm.color_ramp = at
		dust.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		quad.material = _soft_dust_material()
		dust.draw_pass_1 = quad
		herd.add_child(dust)


## Hippos wallowing in the lake and crocodiles lying in the croc pool: low shapes at the
## waterline, there to be seen from the road.
func _build_water_wildlife(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "WaterWildlife"
	parent.add_child(root)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.5
	var hippo := MeshBuilder.new()
	var hc := Color(0.30, 0.25, 0.27)
	hippo.blob(Vector3(0, 0, 0.3), Vector3(0.95, 0.55, 1.5), 10, 6, hc, noise, 0.05)
	hippo.blob(Vector3(0, 0.05, -1.25), Vector3(0.55, 0.38, 0.6), 8, 5, hc, noise, 0.05)
	for sx in [-0.28, 0.28]:
		hippo.blob(Vector3(sx, 0.42, -1.05), Vector3(0.08, 0.1, 0.06), 5, 3, Color(0.22, 0.17, 0.18), noise, 0.0)
		hippo.blob(Vector3(sx * 0.7, 0.36, -1.32), Vector3(0.09, 0.07, 0.08), 5, 3, Color(0.15, 0.12, 0.12), noise, 0.0)
	var hippo_mesh: Mesh = _save_baked_resource(hippo.commit(), "hippo")
	var mat := _vertex_color_material(0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var placed: Array = []
	while placed.size() < 7:
		var a: float = rng.randf() * TAU
		var rr: float = sqrt(rng.randf()) * 0.75
		var p := Vector3(LAKE_CENTER.x + cos(a) * LAKE_RADIUS.x * rr, WATER_Y - 0.15, LAKE_CENTER.y + sin(a) * LAKE_RADIUS.y * rr)
		var ok := true
		for q in placed:
			if p.distance_to(q) < 5.0:
				ok = false
		if not ok:
			continue
		placed.append(p)
		var mi := MeshInstance3D.new()
		mi.name = "Hippo_%d" % placed.size()
		mi.mesh = hippo_mesh
		mi.material_override = mat
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.3, 1.6)), p)
		root.add_child(mi)
	var croc := MeshBuilder.new()
	var cc := Color(0.20, 0.23, 0.13)
	croc.blob(Vector3(0, 0, 0), Vector3(0.45, 0.22, 1.6), 8, 5, cc, noise, 0.08)
	croc.blob(Vector3(0, 0.0, -1.85), Vector3(0.22, 0.13, 0.75), 6, 4, cc, noise, 0.05)
	croc.tube([Vector3(0, 0, 1.4), Vector3(0, 0, 2.6), Vector3(0, 0, 3.4)], [0.28, 0.16, 0.03], 5, func(_k: int) -> Array: return [cc, Vector2.ZERO, Vector2.ZERO])
	for sx in [-0.12, 0.12]:
		croc.blob(Vector3(sx, 0.13, -1.45), Vector3(0.07, 0.06, 0.07), 5, 3, Color(0.42, 0.40, 0.12), noise, 0.0)
	var croc_mesh: Mesh = _save_baked_resource(croc.commit(), "croc")
	var croc_spots := [Vector3(-43.0, WATER_Y - 0.12, -455.0), Vector3(-49.0, WATER_Y - 0.12, -420.0), Vector3(-40.0, WATER_Y - 0.12, -478.0)]
	var k := 0
	for p in croc_spots:
		k += 1
		var mi2 := MeshInstance3D.new()
		mi2.name = "Croc_%d" % k
		mi2.mesh = croc_mesh
		mi2.material_override = mat
		mi2.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)
		root.add_child(mi2)


func _build_giraffes(parent: Node) -> void:
	var mesh: Mesh = _save_baked_resource(_giraffe_mesh(), "giraffe")
	var spots := [
		[Vector2(-120.0, 175.0), 0.6], [Vector2(-104.0, 190.0), 2.1], [Vector2(-140.0, 200.0), 4.0],
		[Vector2(470.0, -40.0), 1.2], [Vector2(462.0, -22.0), 3.3],
	]
	var transforms: Array = []
	for s in spots:
		var p: Vector2 = s[0]
		transforms.append(Transform3D(Basis(Vector3.UP, s[1]).scaled(Vector3.ONE * 1.1), Vector3(p.x, _ground_at(p.x, p.y) - 0.05, p.y)))
	var mmi := _multimesh(mesh, transforms, "Giraffes")
	mmi.material_override = _giraffe_material()
	parent.add_child(mmi)


# ======================================================================================
#  Vegetation and rocks
# ======================================================================================

## Umbrella-thorn acacia: a short forked trunk under a wide, flat-topped crown.
func _acacia_mesh(variant: int, lod: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 501 + variant * 37
	var noise := FastNoiseLite.new()
	noise.seed = 77 + variant
	noise.frequency = 0.9
	var bark := Color(0.30, 0.24, 0.19)
	var leaf := Color(0.34, 0.38, 0.15) if variant == 0 else Color(0.40, 0.40, 0.17)
	var sides: int = 6 if lod == 0 else 4
	var bark_attr := func(_k: int) -> Array: return [bark, Vector2.ZERO, Vector2.ZERO]
	var fork_y: float = 2.2 if variant == 0 else 1.6
	var crown_y: float = 5.6 if variant == 0 else 4.6
	var crown_r: float = 5.0 if variant == 0 else 3.8
	mb.tube([Vector3(0, -0.3, 0), Vector3(0.15, fork_y * 0.5, 0.05), Vector3(0.1, fork_y, 0)], [0.32, 0.24, 0.2], sides, bark_attr)
	var limbs: int = 4 if variant == 0 else 3
	var pads: Array = [Vector3(0, crown_y + 0.2, 0)]
	for i in range(limbs):
		var a: float = TAU * float(i) / float(limbs) + rng.randf_range(-0.3, 0.3)
		var reach: float = crown_r * rng.randf_range(0.55, 0.8)
		var tip := Vector3(cos(a) * reach, crown_y - rng.randf_range(0.0, 0.5), sin(a) * reach)
		var mid := Vector3(cos(a) * reach * 0.4, (fork_y + crown_y) * 0.5, sin(a) * reach * 0.4)
		mb.tube([Vector3(0.1, fork_y - 0.2, 0), mid, tip], [0.16, 0.11, 0.06], maxi(sides - 2, 3), bark_attr, false, true)
		pads.append(tip + Vector3(0, 0.3, 0))
	if lod == 0:
		for i in range(limbs):
			var a2: float = TAU * (float(i) + 0.5) / float(limbs)
			pads.append(Vector3(cos(a2) * crown_r * 0.5, crown_y + 0.25, sin(a2) * crown_r * 0.5))
	for p in pads:
		var pr: float = crown_r * (0.42 if p.x == 0.0 and p.z == 0.0 else rng.randf_range(0.34, 0.46))
		mb.blob(p, Vector3(pr, 0.55 if variant == 0 else 0.6, pr), 9 if lod == 0 else 6, 4 if lod == 0 else 3, leaf, noise, 0.22, true)
	return mb.commit()


## Baobab in the dry season: a bottle-shaped trunk and bare, root-like branches.
func _baobab_mesh(variant: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091 + variant * 13
	var bark := Color(0.52, 0.45, 0.42)
	var attr := func(_k: int) -> Array: return [bark, Vector2.ZERO, Vector2.ZERO]
	var h: float = 9.5 if variant == 0 else 7.5
	mb.tube([Vector3(0, -0.4, 0), Vector3(0, h * 0.15, 0), Vector3(0, h * 0.45, 0), Vector3(0, h * 0.8, 0), Vector3(0, h, 0)],
			[2.3, 2.5, 2.3, 1.6, 1.0], 12, attr, true, false)
	var branches: int = 7 if variant == 0 else 5
	for i in range(branches):
		var a: float = TAU * float(i) / float(branches) + rng.randf_range(-0.25, 0.25)
		var out: float = rng.randf_range(2.2, 4.0)
		var base := Vector3(cos(a) * 0.7, h - 0.3, sin(a) * 0.7)
		var mid := Vector3(cos(a) * out * 0.6, h + rng.randf_range(1.4, 2.2), sin(a) * out * 0.6)
		var tip := Vector3(cos(a) * out, h + rng.randf_range(2.4, 3.6), sin(a) * out)
		mb.tube([base, mid, tip], [0.45, 0.28, 0.08], 5, attr, false, true)
		for k in range(2):
			var b2: float = a + (0.5 if k == 0 else -0.5)
			var twig := mid + Vector3(cos(b2) * 1.2, rng.randf_range(0.8, 1.6), sin(b2) * 1.2)
			mb.tube([mid, twig], [0.18, 0.04], 4, attr, false, true)
	return mb.commit()


## A termite mound: a lumpy red-earth spire with a couple of smaller chimneys.
func _termite_mesh(variant: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040 + variant
	var col := Color(0.66, 0.38, 0.22)
	var attr := func(_k: int) -> Array: return [col, Vector2.ZERO, Vector2.ZERO]
	var h: float = 3.2 + variant * 0.9
	mb.tube([Vector3(0, -0.3, 0), Vector3(0.1, h * 0.3, 0), Vector3(-0.05, h * 0.7, 0.1), Vector3(0.1, h, 0)], [1.1, 0.75, 0.4, 0.08], 7, attr, true, false)
	for k in range(2):
		var a: float = rng.randf() * TAU
		var p := Vector3(cos(a) * 0.6, 0, sin(a) * 0.6)
		var hh: float = h * rng.randf_range(0.35, 0.55)
		mb.tube([p + Vector3(0, -0.2, 0), p + Vector3(0, hh * 0.6, 0), p + Vector3(0.05, hh, 0)], [0.45, 0.25, 0.05], 5, attr, true, false)
	return mb.commit()


## A rounded granite boulder, vertex colour set so savanna_ground.gdshader draws it as granite.
func _boulder_mesh(variant: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var noise := FastNoiseLite.new()
	noise.seed = 600 + variant
	noise.frequency = 0.25
	mb.blob(Vector3.ZERO, Vector3(1.0, 0.75, 0.9), 12, 8, Color(1, 0, 0, 0.5), noise, 0.22)
	return mb.commit()


## Dry grass tussock: a fan of blades. Vertex colour is the blade colour, UV.y the height up it.
func _grass_tuft_mesh(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 120 + variant
	var palette := [Color(0.78, 0.60, 0.32), Color(0.86, 0.72, 0.46), Color(0.66, 0.52, 0.28), Color(0.56, 0.52, 0.26)]
	var blades: int = 14
	for b in range(blades):
		var a: float = TAU * float(b) / float(blades) + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x)
		var base: Vector3 = out * rng.randf_range(0.02, 0.14)
		var h: float = rng.randf_range(0.6, 1.3) * (1.0 if variant == 0 else 0.7)
		var tip: Vector3 = base + out * rng.randf_range(0.15, 0.45) + Vector3(0, h, 0)
		var w: float = rng.randf_range(0.05, 0.085)
		var c: Color = palette[rng.randi() % palette.size()]
		var n: Vector3 = (out * 0.35 + Vector3.UP).normalized()
		var verts := [base - side * w, base + side * w, tip]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)]
		for k in range(3):
			st.set_color(c)
			st.set_normal(n)
			st.set_uv(uvs[k])
			st.add_vertex(verts[k])
	return st.commit()


func _jump_corridor_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var pr_a := Vector2(PR_LIP.x, PR_LIP.z)
	var pr_b: Vector2 = pr_a + PR_DIR.normalized() * 150.0
	var cr_a := Vector2(CROC_LIP.x, CROC_LIP.z)
	var cr_b: Vector2 = cr_a + CROC_DIR.normalized() * (CROC_GAP + 25.0)
	return minf(_segment_distance(p, pr_a, pr_b), _segment_distance(p, cr_a, cr_b))


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _herd_corridor_distance(x: float, z: float) -> float:
	return _segment_distance(Vector2(x, z), Vector2(_herd_start.x, _herd_start.z), Vector2(_herd_end.x, _herd_end.z))


func _slope_at(x: float, z: float) -> float:
	var gx: float = _ground_at(x + 2.0, z) - _ground_at(x - 2.0, z)
	var gz: float = _ground_at(x, z + 2.0) - _ground_at(x, z - 2.0)
	return Vector2(gx, gz).length() / 4.0


## Can a tree, mound or rock stand here? Clear of roads, water, the herd's path and the jumps.
func _clear_spot(x: float, z: float, road_clear: float) -> bool:
	if _road_distance(x, z) < road_clear:
		return false
	var r: Dictionary = _river_at(x, z)
	if r["d"] < r["hw"] + 6.0 or _lake_e(x, z) < 1.12:
		return false
	if _herd_corridor_distance(x, z) < HERD_HALF_W + 6.0:
		return false
	if _jump_corridor_distance(x, z) < 22.0:
		return false
	return _slope_at(x, z) < 0.45


func _build_trees(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "SavannaTrees"
	parent.add_child(root)
	var bark_mat := _vertex_color_material(0.9)
	var near_meshes: Array = [_save_baked_resource(_acacia_mesh(0, 0), "acacia_0"), _save_baked_resource(_acacia_mesh(1, 0), "acacia_1")]
	var far_mesh: Mesh = _save_baked_resource(_acacia_mesh(0, 1), "acacia_far")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var near := {}
	var far := {}
	var trunks: Array = []
	var count := 0
	var tries := 0
	# Acacias in loose groves across the plain, a few standing alone by the road.
	while count < 420 and tries < 40000:
		tries += 1
		var x: float = rng.randf_range(-650.0, 800.0)
		var z: float = rng.randf_range(-800.0, 650.0)
		var grove: float = _base_noise.get_noise_2d(x * 3.0 + 400.0, z * 3.0)
		if grove < 0.08 and rng.randf() > 0.12:
			continue
		if _kopje(x, z).y > 0.3:
			continue
		if not _clear_spot(x, z, 17.0):
			continue
		var v: int = 0 if rng.randf() < 0.6 else 1
		var s: float = rng.randf_range(0.8, 1.3)
		var y: float = _ground_at(x, z)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.1), s)), Vector3(x, y, z))
		var key := Vector3i(floori(x / 160.0), floori(z / 160.0), v)
		if not near.has(key):
			near[key] = []
		near[key].append(xf)
		var fk := Vector2i(floori(x / 400.0), floori(z / 400.0))
		if not far.has(fk):
			far[fk] = []
		far[fk].append(xf)
		if _road_distance(x, z) < 60.0:
			trunks.append([Vector3(x, y, z), 0.45 * s, 3.0 * s])
		count += 1
	# The horizon: sparse acacias out to the hills, far mesh only.
	var horizon := 0
	tries = 0
	while horizon < 700 and tries < 20000:
		tries += 1
		var x2: float = rng.randf_range(-2200.0, 2400.0)
		var z2: float = rng.randf_range(-2400.0, 2200.0)
		if absf(x2 - 70.0) < 760.0 and absf(z2 + 70.0) < 760.0:
			continue
		if _base_noise.get_noise_2d(x2 * 2.0, z2 * 2.0) < 0.0:
			continue
		if _in_water(x2, z2):
			continue
		var s2: float = rng.randf_range(0.9, 1.4)
		var xf2 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s2), Vector3(x2, _ground_at(x2, z2), z2))
		var fk2 := Vector2i(floori(x2 / 400.0), floori(z2 / 400.0))
		if not far.has(fk2):
			far[fk2] = []
		far[fk2].append(xf2)
		horizon += 1
	for k in near.keys():
		var mmi := _multimesh(near_meshes[k.z], near[k], "Acacia_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.material_override = bark_mat
		mmi.visibility_range_end = 420.0
		mmi.visibility_range_end_margin = 30.0
		root.add_child(mmi)
	for k in far.keys():
		var mmi2 := _multimesh(far_mesh, far[k], "AcaciaFar_%d_%d" % [k.x, k.y])
		mmi2.material_override = bark_mat
		mmi2.visibility_range_begin = 420.0
		mmi2.visibility_range_begin_margin = 30.0
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi2)
	# Baobabs: Baobab Bend's giant on the inside of the corner, more across the south.
	var baobab_meshes: Array = [_save_baked_resource(_baobab_mesh(0), "baobab_0"), _save_baked_resource(_baobab_mesh(1), "baobab_1")]
	var baobabs: Array = [[Vector2(-212.0, 185.0), 1.35, 0], [Vector2(-300.0, 250.0), 1.0, 1], [Vector2(-160.0, 330.0), 1.1, 0],
			[Vector2(-345.0, 60.0), 1.0, 1], [Vector2(60.0, 280.0), 1.15, 0], [Vector2(-60.0, 120.0), 0.9, 1],
			[Vector2(300.0, 130.0), 1.0, 0], [Vector2(460.0, -260.0), 1.05, 1], [Vector2(-390.0, -260.0), 1.1, 0]]
	var bt := {0: [], 1: []}
	for b in baobabs:
		var p: Vector2 = b[0]
		if _road_distance(p.x, p.y) < 20.0 or _herd_corridor_distance(p.x, p.y) < HERD_HALF_W + 6.0:
			push_warning("Baobab at (%.0f, %.0f) is too close to the road or the herd" % [p.x, p.y])
			continue
		var y2: float = _ground_at(p.x, p.y)
		var s3: float = b[1]
		bt[b[2]].append(Transform3D(Basis(Vector3.UP, p.x * 0.37).scaled(Vector3.ONE * s3), Vector3(p.x, y2, p.y)))
		trunks.append([Vector3(p.x, y2, p.y), 2.4 * s3, 9.0 * s3])
	for v2 in bt.keys():
		if bt[v2].is_empty():
			continue
		var mmi3 := _multimesh(baobab_meshes[v2], bt[v2], "Baobabs_%d" % v2)
		mmi3.material_override = bark_mat
		root.add_child(mmi3)
	# Termite mounds, some close enough to the verge to punish a cut corner.
	var mound_meshes: Array = [_save_baked_resource(_termite_mesh(0), "termite_0"), _save_baked_resource(_termite_mesh(1), "termite_1")]
	var mt := {0: [], 1: []}
	var mounds := 0
	tries = 0
	while mounds < 70 and tries < 8000:
		tries += 1
		var x3: float = rng.randf_range(FINE_X.x, FINE_X.y)
		var z3: float = rng.randf_range(FINE_Z.x, FINE_Z.y)
		if not _clear_spot(x3, z3, 11.0) or _kopje(x3, z3).y > 0.2:
			continue
		var y3: float = _ground_at(x3, z3)
		var v3: int = rng.randi() % 2
		var s4: float = rng.randf_range(0.8, 1.2)
		mt[v3].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s4), Vector3(x3, y3, z3)))
		trunks.append([Vector3(x3, y3, z3), 0.9 * s4, (3.2 + v3 * 0.9) * s4])
		mounds += 1
	for v4 in mt.keys():
		var mmi4 := _multimesh(mound_meshes[v4], mt[v4], "TermiteMounds_%d" % v4)
		mmi4.material_override = _vertex_color_material(0.95)
		root.add_child(mmi4)
	# Solid trunks, mounds and baobabs, per 160m cell.
	var bodies := {}
	for t in trunks:
		var p3: Vector3 = t[0]
		var bk := Vector2i(floori(p3.x / 160.0), floori(p3.z / 160.0))
		if not bodies.has(bk):
			var body := StaticBody3D.new()
			body.name = "TreeTrunks_%d_%d" % [bk.x, bk.y]
			root.add_child(body)
			bodies[bk] = body
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = t[1]
		cyl.height = t[2]
		cs.shape = cyl
		cs.position = p3 + Vector3(0, cyl.height * 0.5 - 0.3, 0)
		bodies[bk].add_child(cs)
	print("  trees: %d acacias, %d on the horizon, %d baobabs, %d termite mounds, %d colliders" % [count, horizon, baobabs.size(), mounds, trunks.size()])


## Granite boulders on the kopjes, and the two great boulders that make the gate on the run-up
## to Pride Rock.
func _build_boulders(parent: Node, mat: Material) -> void:
	var root := Node3D.new()
	root.name = "KopjeBoulders"
	parent.add_child(root)
	var meshes: Array = []
	for v in range(3):
		meshes.append(_save_baked_resource(_boulder_mesh(v), "boulder_%d" % v))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1357
	var sets := {0: [], 1: [], 2: []}
	var shapes: Array = []
	# The gate: two tall boulders either side of the run-up, and a pair at the lip.
	var pd: Vector3 = _pr_dir3()
	var pr_right := Vector3(-pd.z, 0, pd.x)
	var gate: Array = [
		[PR_LIP - pd * 40.0 + pr_right * 15.0, 5.5], [PR_LIP - pd * 46.0 - pr_right * 15.5, 6.0],
		[PR_LIP - pd * 4.0 + pr_right * 13.5, 3.6], [PR_LIP - pd * 6.0 - pr_right * 14.0, 4.0],
	]
	for g in gate:
		var p: Vector3 = g[0]
		p.y = _ground_at(p.x, p.z)
		sets[rng.randi() % 3].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * g[1]), p + Vector3(0, g[1] * 0.35, 0)))
		shapes.append([p + Vector3(0, g[1] * 0.35, 0), g[1] * 0.8])
	var n := 0
	var tries := 0
	while n < 160 and tries < 20000:
		tries += 1
		var k: Array = KOPJES[rng.randi() % KOPJES.size()]
		var c: Vector2 = k[0]
		var a: float = rng.randf() * TAU
		var rr: float = float(k[1]) * sqrt(rng.randf()) * 1.05
		var x: float = c.x + cos(a) * rr
		var z: float = c.y + sin(a) * rr
		if _road_distance(x, z) < 12.0 or _jump_corridor_distance(x, z) < 18.0:
			continue
		var s: float = rng.randf_range(1.0, 3.8)
		var y: float = _ground_at(x, z)
		sets[rng.randi() % 3].append(Transform3D(Basis(Vector3(rng.randf(), 1, rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y + s * 0.2, z)))
		if _road_distance(x, z) < 50.0:
			shapes.append([Vector3(x, y + s * 0.2, z), s * 0.78])
		n += 1
	for v2 in sets.keys():
		var mmi := _multimesh(meshes[v2], sets[v2], "Boulders_%d" % v2)
		mmi.material_override = mat
		root.add_child(mmi)
	var body := StaticBody3D.new()
	body.name = "BoulderRocks"
	root.add_child(body)
	for sh in shapes:
		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = sh[1]
		cs.shape = sphere
		cs.position = sh[0]
		body.add_child(cs)
	print("  boulders: %d (+%d at the gate), %d solid" % [n, gate.size(), shapes.size()])


## Dry grass tussocks near the roads, in MultiMesh cells that fade out with distance.
func _build_grass(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "SavannaGrass"
	parent.add_child(root)
	var meshes: Array = [_save_baked_resource(_grass_tuft_mesh(0), "grass_tuft_0"), _save_baked_resource(_grass_tuft_mesh(1), "grass_tuft_1")]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://savanna_grass.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9753
	var cells := {}
	var total := 0
	var cell := 40.0
	var x: float = FINE_X.x
	while x < FINE_X.y:
		var z: float = FINE_Z.x
		while z < FINE_Z.y:
			var cx: float = x + cell * 0.5
			var cz: float = z + cell * 0.5
			# Only cells someone driving can see closely.
			if _road_distance(cx, cz) < 140.0:
				for k in range(420):
					var px: float = x + rng.randf() * cell
					var pz: float = z + rng.randf() * cell
					var rd: float = _road_distance(px, pz)
					if rd < ROAD_HALF + 1.2 + rng.randf() * 1.5:
						continue
					if _in_water(px, pz) or _kopje(px, pz).y > 0.5:
						continue
					var clump: float = _detail_noise.get_noise_2d(px * 1.7, pz * 1.7)
					if clump < -0.15 and rng.randf() < 0.7:
						continue
					var v: int = 0 if rng.randf() < 0.7 else 1
					var s: float = rng.randf_range(0.8, 1.35)
					var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(px, _ground_at(px, pz) - 0.05, pz))
					var key := Vector3i(floori(x / cell), floori(z / cell), v)
					if not cells.has(key):
						cells[key] = []
					cells[key].append(xf)
					total += 1
			z += cell
		x += cell
	for k in cells.keys():
		var mmi := _multimesh(meshes[k.z], cells[k], "Grass_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 150.0
		mmi.visibility_range_end_margin = 25.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(mmi)
	print("  grass: %d tussocks in %d cells" % [total, cells.size()])


# ======================================================================================
#  Skyline
# ======================================================================================

## The volcano: a broad cone with a flat summit crater, radial gullies, a forest belt and a
## snowcap, plus a jagged second peak on its east shoulder.
func _volcano_mesh() -> ArrayMesh:
	const ANG := 120
	const RINGS := 44
	var noise := FastNoiseLite.new()
	noise.seed = 1977
	noise.frequency = 0.0018
	noise.fractal_octaves = 4
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var height_at := func(x: float, z: float) -> float:
		var r: float = Vector2(x, z).length()
		var u: float = clampf(r / VOLCANO_R, 0.0, 1.0)
		var ang: float = atan2(z, x)
		var h: float = VOLCANO_H * pow(1.0 - u, 1.65)
		# Flat-topped summit with a shallow crater.
		var rim: float = VOLCANO_H * pow(1.0 - 0.07, 1.65)
		if u < 0.07:
			h = rim - (1.0 - u / 0.07) * 25.0
		h *= 1.0 + 0.05 * sin(ang * 11.0 + noise.get_noise_2d(x, z) * 4.0) * smoothstep(0.08, 0.5, u)
		h += noise.get_noise_2d(x * 1.5, z * 1.5) * 70.0 * smoothstep(0.05, 0.3, u) * (1.0 - u)
		# Second peak on the east shoulder.
		var m: Vector2 = Vector2(x, z) - Vector2(VOLCANO_R * 0.42, VOLCANO_R * 0.06)
		var mu: float = clampf(m.length() / (VOLCANO_R * 0.32), 0.0, 1.0)
		var mh: float = VOLCANO_H * 0.68 * pow(1.0 - mu, 1.4) * (1.0 + noise.get_noise_2d(x * 4.0, z * 4.0) * 0.25)
		return maxf(h, mh)
	verts.append(Vector3(0, height_at.call(0.0, 0.0), 0))
	for j in range(1, RINGS + 1):
		var u: float = pow(float(j) / float(RINGS), 1.4)
		for i in range(ANG):
			var a: float = TAU * float(i) / float(ANG)
			var x: float = cos(a) * u * VOLCANO_R
			var z: float = sin(a) * u * VOLCANO_R
			verts.append(Vector3(x, height_at.call(x, z), z))
	for v in verts:
		var hf: float = v.y / VOLCANO_H
		var gully: float = noise.get_noise_2d(v.x * 3.0, v.z * 3.0)
		var c := Color(0.52, 0.45, 0.36)
		if hf > 0.12:
			c = c.lerp(Color(0.22, 0.27, 0.17), smoothstep(0.12, 0.25, hf))
		if hf > 0.36:
			c = c.lerp(Color(0.34, 0.29, 0.26), smoothstep(0.36, 0.48, hf))
		var snow: float = smoothstep(0.70, 0.78, hf + gully * 0.08)
		c = c.lerp(Color(0.96, 0.96, 1.0), snow)
		colors.append(c)
	var faces := PackedInt32Array()
	for i in range(ANG):
		faces.append_array([0, 1 + i, 1 + (i + 1) % ANG])
	for j in range(RINGS - 1):
		var r0: int = 1 + j * ANG
		var r1: int = 1 + (j + 1) * ANG
		for i in range(ANG):
			var i2: int = (i + 1) % ANG
			faces.append_array([r0 + i, r1 + i, r1 + i2, r0 + i, r1 + i2, r0 + i2])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, faces.size(), 3):
		var ia: int = faces[t]
		var ib: int = faces[t + 1]
		var ic: int = faces[t + 2]
		var a: Vector3 = verts[ia]
		var b: Vector3 = verts[ib]
		var c2: Vector3 = verts[ic]
		# Front face up (clockwise in Godot: normal (c - a) x (b - a)).
		if (c2 - a).cross(b - a).y < 0.0:
			var tmp: int = ib
			ib = ic
			ic = tmp
		for idx in [ia, ib, ic]:
			st.set_color(colors[idx])
			st.add_vertex(verts[idx])
	st.index()
	st.generate_normals()
	return st.commit()


func _build_volcano(parent: Node, haze: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Volcano"
	mi.mesh = _save_baked_resource(_volcano_mesh(), "volcano")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://distant_mountain.gdshader")
	# Distance turns a mountain blue-grey, not the dusty gold of the near haze.
	mat.set_shader_parameter("haze_color", haze.lerp(Color(0.66, 0.70, 0.80), 0.55))
	mat.set_shader_parameter("peak_height", VOLCANO_H)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = VOLCANO_AT
	parent.add_child(mi)


## Two safari balloons drifting over the plain.
func _build_balloons(parent: Node) -> void:
	var envelope := MeshBuilder.new()
	var gores := 16
	var profile := [[0.0, 0.0], [0.35, 3.0], [1.0, 6.5], [1.0, 11.0], [0.85, 14.0], [0.45, 16.5], [0.0, 17.2]]
	var rad := 8.0
	var colors := [Color(0.85, 0.16, 0.12), Color(0.98, 0.76, 0.12), Color(0.12, 0.38, 0.70), Color(0.98, 0.76, 0.12)]
	for g in range(gores):
		var a0: float = TAU * float(g) / float(gores)
		var a1: float = TAU * float(g + 1) / float(gores)
		var col: Color = colors[g % colors.size()]
		for k in range(profile.size() - 1):
			var p0: Array = profile[k]
			var p1: Array = profile[k + 1]
			var v00 := V.new(Vector3(cos(a0) * p0[0] * rad, p0[1], sin(a0) * p0[0] * rad), col)
			var v01 := V.new(Vector3(cos(a1) * p0[0] * rad, p0[1], sin(a1) * p0[0] * rad), col)
			var v10 := V.new(Vector3(cos(a0) * p1[0] * rad, p1[1], sin(a0) * p1[0] * rad), col)
			var v11 := V.new(Vector3(cos(a1) * p1[0] * rad, p1[1], sin(a1) * p1[0] * rad), col)
			var mid := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
			envelope.quad(v00, v01, v11, v10, mid)
	var basket := Color(0.42, 0.30, 0.18)
	var battr := func(_k: int) -> Array: return [basket, Vector2.ZERO, Vector2.ZERO]
	envelope.tube([Vector3(0, -4.0, 0), Vector3(0, -2.9, 0)], [0.9, 0.95], 8, battr)
	var rope := Color(0.2, 0.18, 0.15)
	var rattr := func(_k: int) -> Array: return [rope, Vector2.ZERO, Vector2.ZERO]
	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		envelope.tube([Vector3(cos(a) * 0.8, -2.9, sin(a) * 0.8), Vector3(cos(a) * 2.6, 0.2, sin(a) * 2.6)], [0.03, 0.03], 3, rattr, false, false)
	var mesh: Mesh = _save_baked_resource(envelope.commit(), "balloon")
	var mat := _vertex_color_material(0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var script: Script = load("res://SafariBalloon.gd")
	var spots := [[Vector3(150.0, 95.0, -200.0), 140.0, 0.010, 0.0], [Vector3(-200.0, 120.0, 40.0), 180.0, -0.008, 2.0]]
	var k := 0
	for s in spots:
		k += 1
		var mi := MeshInstance3D.new()
		mi.name = "SafariBalloon_%d" % k
		mi.mesh = mesh
		mi.material_override = mat
		mi.set_script(script)
		mi.set("centre", s[0])
		mi.set("radius", s[1])
		mi.set("angular_speed", s[2])
		mi.set("phase", s[3])
		mi.position = s[0] + Vector3(s[1], 0, 0)
		parent.add_child(mi)


# ======================================================================================
#  Trackside
# ======================================================================================

## White marker posts with a red band, along the verges and across the ford. Carts knock them
## over (KnockablePoles.gd).
func _build_marker_posts(parent: Node) -> void:
	var length: float = main_curve.get_baked_length()
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.08
	post.height = 1.6
	post.radial_segments = 6
	post.rings = 3
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
void fragment() {
	float y = 1.0 - UV.y;
	float band = step(0.72, y) * step(y, 0.88);
	ALBEDO = mix(vec3(0.92, 0.90, 0.86), vec3(0.85, 0.08, 0.06), band);
	ROUGHNESS = 0.55;
	EMISSION = vec3(0.85, 0.08, 0.06) * band * 0.25;
}
"""
	mat.shader = sh
	post.material = mat
	var transforms: Array = []
	var d := 8.0
	while d < length - 4.0:
		var f: Dictionary = _frame_at_offset(main_curve, d)
		var p: Vector3 = f["pos"]
		var skip: bool = d > _pr["lip_off"] - 70.0 and d < _pr["hill_end_off"] + 10.0
		skip = skip or _herd_corridor_distance(p.x, p.z) < HERD_HALF_W + 8.0
		skip = skip or d < 40.0 or d > length - 30.0
		var r: Dictionary = _river_at(p.x, p.z)
		var in_ford: bool = r["d"] < r["hw"] + 2.0
		if in_ford:
			# Depth posts every few metres along both edges of the ford.
			for s in [-1.0, 1.0]:
				var q: Vector3 = p + f["right"] * s * (ROAD_HALF + 0.6)
				q.y = _ground_at(q.x, q.z) + 0.7
				transforms.append(Transform3D(Basis(), q))
			d += 6.0
			continue
		if not skip:
			for s2 in [-1.0, 1.0]:
				var q2: Vector3 = p + f["right"] * s2 * (ROAD_HALF + 2.2)
				q2.y = _ground_at(q2.x, q2.z) + 0.7
				transforms.append(Transform3D(Basis(), q2))
		d += 30.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post
	mm.instance_count = transforms.size()
	mm.buffer = _transform_buffer(transforms)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "MarkerPosts"
	mmi.set_script(load("res://KnockablePoles.gd"))
	var typed: Array[Transform3D] = []
	for t in transforms:
		typed.append(t)
	mmi.set("pole_transforms", typed)
	mmi.set("pole_height", 1.6)
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	print("  marker posts: %d" % transforms.size())


## Waving pennants either side of both kickers (flag_cloth.gdshader), so the jumps read from far
## up the road.
func _build_jump_flags(parent: Node) -> void:
	const POST_H := 4.6
	const WIND := Vector3(0.8, 0.0, 0.6)
	var root := Node3D.new()
	root.name = "JumpFlags"
	parent.add_child(root)
	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.07
	post.height = POST_H
	post.radial_segments = 8
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.36, 0.26, 0.16)
	post_mat.roughness = 0.8
	post.material = post_mat
	var cloth := PlaneMesh.new()
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.size = Vector2(1.6, 1.0)
	cloth.subdivide_width = 16
	cloth.subdivide_depth = 4
	cloth.center_offset = Vector3(0.8, 0.0, 0.0)
	var cloth_mat := ShaderMaterial.new()
	cloth_mat.shader = load("res://flag_cloth.gdshader")
	cloth.material = cloth_mat
	var wind: Vector3 = WIND.normalized()
	var flag_basis := Basis(Vector3.UP, atan2(-wind.z, wind.x))
	var jumps := [[PR_LIP, _pr_dir3(), 11.0, "PrideRock"], [CROC_LIP, _croc_dir3(), 10.5, "CrocJump"]]
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
				cyl.radius = 0.15
				cyl.height = POST_H
				cs.shape = cyl
				body.add_child(cs)
				body.position = p + Vector3(0, POST_H * 0.5, 0)
				root.add_child(body)
				var flag := MeshInstance3D.new()
				flag.name = "%s_Flag_%d_%d" % [j[3], int(s), k]
				flag.mesh = cloth
				flag.transform = Transform3D(flag_basis, p + Vector3(0, POST_H - 0.55, 0) + wind * 0.05)
				root.add_child(flag)


## Safari bandas (round huts with thatched cones) beside the start, and the Matumaini GP banner
## across the straight.
func _build_start_area(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "SafariCamp"
	parent.add_child(root)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.78, 0.60, 0.40)
	wall_mat.roughness = 0.95
	var thatch_mat := StandardMaterial3D.new()
	thatch_mat.albedo_color = Color(0.62, 0.50, 0.30)
	thatch_mat.roughness = 1.0
	var wall := CylinderMesh.new()
	wall.top_radius = 3.0
	wall.bottom_radius = 3.0
	wall.height = 2.6
	wall.radial_segments = 14
	wall.material = wall_mat
	var roof := CylinderMesh.new()
	roof.top_radius = 0.1
	roof.bottom_radius = 4.0
	roof.height = 3.0
	roof.radial_segments = 14
	roof.material = thatch_mat
	var huts := [Vector2(-30.0, 140.0), Vector2(-36.0, 165.0), Vector2(-27.0, 188.0), Vector2(30.0, 226.0)]
	var body := StaticBody3D.new()
	body.name = "BandaHuts"
	root.add_child(body)
	for h in huts:
		var y: float = _ground_at(h.x, h.y)
		var w := MeshInstance3D.new()
		w.mesh = wall
		w.position = Vector3(h.x, y + 1.2, h.y)
		root.add_child(w)
		var r := MeshInstance3D.new()
		r.mesh = roof
		r.position = Vector3(h.x, y + 3.9, h.y)
		root.add_child(r)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 3.1
		cyl.height = 5.5
		cs.shape = cyl
		cs.position = Vector3(h.x, y + 2.7, h.y)
		body.add_child(cs)
	# Banner gantry across the straight, 30m past the line.
	var gz := 170.0
	var gy: float = _ground_at(0.0, gz)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.22
	pole.bottom_radius = 0.28
	pole.height = 9.0
	pole.radial_segments = 8
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.32, 0.22, 0.14)
	pole_mat.roughness = 0.85
	pole.material = pole_mat
	for sx in [-11.0, 11.0]:
		var pm := MeshInstance3D.new()
		pm.mesh = pole
		pm.position = Vector3(sx, gy + 4.5, gz)
		root.add_child(pm)
		var cs2 := CollisionShape3D.new()
		var cyl2 := CylinderShape3D.new()
		cyl2.radius = 0.35
		cyl2.height = 9.0
		cs2.shape = cyl2
		cs2.position = Vector3(sx, gy + 4.5, gz)
		body.add_child(cs2)
	var banner := MeshInstance3D.new()
	banner.name = "Banner"
	var bm := BoxMesh.new()
	bm.size = Vector3(21.6, 1.9, 0.12)
	banner.mesh = bm
	var bmat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
// A kanga-print banner: a bold border of triangles round a warm field.
void fragment() {
	vec2 uv = UV * vec2(3.0, 2.0);
	vec2 f = fract(uv * vec2(18.0, 6.0));
	float tri = step(f.x, f.y);
	float border = step(0.82, fract(uv.y)) + step(fract(uv.y), 0.18);
	vec3 field = vec3(0.86, 0.36, 0.08);
	vec3 a = vec3(0.10, 0.30, 0.18);
	vec3 b = vec3(0.98, 0.80, 0.18);
	ALBEDO = mix(field, mix(a, b, tri), clamp(border, 0.0, 1.0));
	ROUGHNESS = 0.8;
}
"""
	bmat.shader = sh
	banner.material_override = bmat
	banner.position = Vector3(0, gy + 7.6, gz)
	root.add_child(banner)
	for side in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = "MATUMAINI GP"
		label.font_size = 160
		label.pixel_size = 0.0075
		label.outline_size = 28
		label.modulate = Color(1.0, 0.97, 0.88)
		label.outline_modulate = Color(0.25, 0.10, 0.04)
		label.position = Vector3(0, gy + 7.6, gz + side * 0.08)
		label.rotation.y = 0.0 if side > 0.0 else PI
		root.add_child(label)


# ======================================================================================
#  Build
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


func _ready() -> void:
	print("=== Mara Crossing (Matumaini GP) Level Generation ===")
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

	# 1. Environment: golden hour. The sun is low in the west-south-west, so Pride Rock launches
	#    the field straight into it and the volcano in the north-east glows. Same sky shader and
	#    fog recipe as the Svartfjell stages, recoloured warm and dusty.
	var haze := Color(0.93, 0.76, 0.56)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_winter_cirrus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.18, 0.44, 0.78))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.90, 0.86, 0.74))
	sky_mat.set_shader_parameter("ground_horizon", Color(0.88, 0.72, 0.54))
	sky_mat.set_shader_parameter("ground_bottom", Color(0.55, 0.45, 0.34))
	sky_mat.set_shader_parameter("sky_curve", 0.35)
	sky_mat.set_shader_parameter("horizon_haze", haze)
	sky_mat.set_shader_parameter("haze_strength", 0.8)
	sky_mat.set_shader_parameter("haze_height", 0.2)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.84, 0.58))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.2)
	sky_mat.set_shader_parameter("sun_glow", 0.65)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.86, 0.70))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.66, 0.54, 0.56))
	sky_mat.set_shader_parameter("cloud_coverage", 0.30)
	sky_mat.set_shader_parameter("cloud_opacity", 0.6)
	sky_mat.set_shader_parameter("cloud_seed", 11.3)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(1.0, 0.88, 0.72)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.12
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = haze
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.22
	env.fog_density = 1.0
	env.fog_depth_begin = 260.0
	env.fog_depth_end = 2600.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.06
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-17.0, -69.0, 0.0)
	sun.light_color = Color(1.0, 0.83, 0.62)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)

	# 2. The roads.
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	main_curve = _build_closed_loop(_track_points())
	track_path.curve = main_curve
	level_scene.add_child(track_path)
	croc_curve = _build_croc_curve()
	var alt_root := Node3D.new()
	alt_root.name = "AlternativePaths"
	level_scene.add_child(alt_root)
	var croc_path := Path3D.new()
	croc_path.name = "CrocJumpPath"
	croc_path.curve = croc_curve
	alt_root.add_child(croc_path)
	var lap_len: float = main_curve.get_baked_length()
	print("  lap length %.0fm" % lap_len)
	_verify_min_radius(main_curve, "main road", true)
	_verify_min_radius(croc_curve, "croc line", false)
	_verify_plan(main_curve)
	_resolve_features()
	_verify_croc_plan()

	# 3. Ground.
	_build_road_samples()
	_verify_herd()
	print("  building heightfield...")
	_build_heights()
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://savanna_ground.gdshader")
	ground_mat.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	ground_mat.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	ground_mat.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	ground_mat.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	ground_mat.set_shader_parameter("rock_normal", load("res://materials/dark_canyon_rock_normal.png"))
	ground_mat.set_shader_parameter("road_half_width", ROAD_HALF)
	ground_mat.set_shader_parameter("horizon_color", haze)
	var terrain_root := Node3D.new()
	terrain_root.name = "TerrainEnvironment"
	level_scene.add_child(terrain_root)
	_build_terrain(terrain_root, ground_mat)
	print("  terrain built (%.1fs)" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	_verify_road_ground()
	_verify_ford()

	# 4. Kickers: Pride Rock is a granite slab, the Croc Jump a timber-and-earth ramp.
	var kickers := Node3D.new()
	# Not "...Ramp": Level.gd bakes a second trimesh collider for every node named that.
	kickers.name = "JumpKickers"
	level_scene.add_child(kickers)
	_place_kicker(kickers, "PrideRockJump", PR_LIP, _pr["dir"], PR_KICK_H, PR_KICK_DEG, 18.0, ground_mat, Color(1, 0, 0, 0.5))
	_place_kicker(kickers, "CrocJumpKicker", CROC_LIP, _croc["dir"], CROC_KICK_H, CROC_KICK_DEG, 17.0, ground_mat, Color(0, 1, 0, 0.5))
	_verify_jumps()

	# 5. Water.
	var water_root := Node3D.new()
	water_root.name = "Water"
	level_scene.add_child(water_root)
	_build_river_water_node(level_scene)
	_build_water_mesh(water_root, _water_material())

	# 6. Finish line and grid.
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var fl: Dictionary = _spot(main_curve, 0.0, 0.0, 0.06)
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

	# 7. Checkpoints. None between the croc line's junctions, which both lines must pass in the
	#    same order; one well before Pride Rock so a respawn has the whole run-up.
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)
	var cross_off: float = _main_off(Vector3(HERD_CROSS.x, 7.0, HERD_CROSS.y))
	var cp_offs: Array = [
		cross_off - 70.0,
		_main_off(Vector3(418.0, 10.0, -150.0)),
		_pr["lip_off"] - PR_RUN_UP - 20.0,
		_pr["hill_end_off"] + 5.0,
		_croc["end_off"] + 40.0,
		_main_off(Vector3(-290.0, 6.0, -60.0)),
		_main_off(Vector3(-200.0, 5.2, 245.0)),
	]
	cp_offs.sort()
	for i in range(cp_offs.size()):
		var off: float = cp_offs[i]
		if off > _croc["start_off"] - 10.0 and off < _croc["end_off"] + 10.0:
			push_error("Checkpoint %d at %.0fm sits between the croc line's junctions" % [i + 1, off])
		var c: Dictionary = _spot(main_curve, off, 0.0, 0.1)
		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = c["pos"]
		gate.rotation_degrees = Vector3(0, c["yaw"], 0)
		checkpoints_container.add_child(gate)
		print("  checkpoint %d at %.0fm" % [i + 1, off])

	# 8. Boost pads: a lane on the Pride Rock run-up and the croc run-in (which needs it to make
	#    the gap), one to blast through the ford, and a few rewards elsewhere.
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)
	var bp_defs: Array = []
	for lat in [-4.0, 0.0, 4.0]:
		bp_defs.append(["Boost_PrideRock_%d" % int(lat), main_curve, _pr["lip_off"] - 32.0, lat])
		bp_defs.append(["Boost_Croc_%d" % int(lat), croc_curve, _croc["lip_off"] - 40.0, lat])
	bp_defs.append(["Boost_StartStraight", main_curve, 90.0, -3.0])
	bp_defs.append(["Boost_Herd_L", main_curve, cross_off - 50.0, -3.0])
	bp_defs.append(["Boost_Herd_R", main_curve, cross_off - 50.0, 3.0])
	bp_defs.append(["Boost_Ford", main_curve, _main_off(Vector3(22.0, 3.6, -351.0)), 0.0])
	bp_defs.append(["Boost_Baobab", main_curve, _main_off(Vector3(-135.0, 5.6, 290.0)), 2.5])
	for b in bp_defs:
		var bp = boost_scene.instantiate()
		bp.name = b[0]
		var s: Dictionary = _spot(b[1], b[2], b[3], 0.08)
		bp.position = s["pos"]
		bp.rotation_degrees = Vector3(0, s["yaw"], 0)
		boost_container.add_child(bp)

	# 9. Item boxes in rows on calm stretches.
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)
	var item_rows := [cross_off + 70.0, _main_off(Vector3(420.0, 11.5, -190.0)), _pr["hill_end_off"] + 30.0,
			_main_off(Vector3(-294.0, 6.2, -140.0)), _main_off(Vector3(-70.0, 6.0, 305.0))]
	var item_idx := 1
	for off in item_rows:
		for lat in [-4.5, 0.0, 4.5]:
			var ib = item_scene.instantiate()
			ib.name = "ItemBox_%d" % item_idx
			var s2: Dictionary = _spot(main_curve, off, lat, 1.4)
			ib.position = s2["pos"]
			item_container.add_child(ib)
			item_idx += 1

	# 10. Wildlife and dressing. Not "Props"/"Vegetation"/"Environment": Level.gd bakes trimesh
	#     colliders for everything under those names at load.
	var dressing := Node3D.new()
	dressing.name = "SavannaDressing"
	level_scene.add_child(dressing)
	var boulder_mat := ShaderMaterial.new()
	boulder_mat.shader = ground_mat.shader
	for p in ["grass_tex", "dirt_tex", "dirt_normal", "rock_tex", "rock_normal"]:
		boulder_mat.set_shader_parameter(p, ground_mat.get_shader_parameter(p))
	_build_trees(dressing)
	_build_boulders(dressing, boulder_mat)
	_build_grass(dressing)
	_build_marker_posts(dressing)
	_build_jump_flags(dressing)
	_build_start_area(dressing)
	_build_water_wildlife(dressing)
	_build_giraffes(dressing)
	_build_balloons(dressing)
	_build_volcano(dressing, haze)
	_build_herd(level_scene)

	# 11. Wiring and save.
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX + "ground", "res://generated/mara_chunks", MESH_CHUNK_CELL)
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
